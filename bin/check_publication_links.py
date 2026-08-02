#!/usr/bin/env python3
"""Check that every publication artifact link (PDF / video / slides / DOI)
in the remote publications JSON resolves, after the same URL normalization
the site templates apply (relative paths resolve against the uploads host).

Exits non-zero and lists every broken link if any artifact is unreachable,
so CI catches broken "grab the paper" journeys before they ship.
"""

import json
import sys
import urllib.request

PUBLICATIONS_JSON = "https://sauvik.me/papers.json"
ASSET_HOST = "https://sauvik.me"
TIMEOUT_SECONDS = 30
USER_AGENT = "Mozilla/5.0 (compatible; spud-lab-link-check/1.0)"


def normalize(url: str, kind: str) -> str | None:
    if not url:
        return None
    url = url.strip()
    if not url:
        return None
    if url.startswith("//"):
        return "https:" + url
    if "://" not in url:
        if kind == "doi":
            return "https://doi.org/" + url.lstrip("/")
        return ASSET_HOST + (url if url.startswith("/") else "/" + url)
    return url


def check(url: str) -> tuple[bool, str]:
    for method in ("HEAD", "GET"):
        request = urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                if response.status < 400:
                    return True, str(response.status)
        except urllib.error.HTTPError as error:
            if method == "GET":
                return False, f"HTTP {error.code}"
        except Exception as error:  # URLError, timeout, TLS, ...
            if method == "GET":
                return False, str(error)
    return False, "unreachable"


def main() -> int:
    with urllib.request.urlopen(
        urllib.request.Request(PUBLICATIONS_JSON, headers={"User-Agent": USER_AGENT}), timeout=TIMEOUT_SECONDS
    ) as response:
        publications = json.load(response)

    failures = []
    checked = 0
    for publication in publications:
        artifacts = {
            "pdf": normalize(publication.get("pdf"), "pdf"),
            "video": normalize(publication.get("video_url"), "video"),
            "slides": normalize(publication.get("slides"), "slides"),
            "doi": normalize(publication.get("doi"), "doi"),
        }
        for kind, url in artifacts.items():
            if not url:
                continue
            checked += 1
            ok, detail = check(url)
            status = "ok" if ok else f"BROKEN ({detail})"
            print(f"[{status}] {kind}: {url}  —  {publication.get('title', '?')[:70]}")
            if not ok:
                failures.append((publication.get("title", "?"), kind, url, detail))

    print(f"\nChecked {checked} artifact links across {len(publications)} publications.")
    if failures:
        print(f"{len(failures)} broken artifact link(s):")
        for title, kind, url, detail in failures:
            print(f"  - {kind} for “{title}”: {url} ({detail})")
        return 1
    print("All artifact links resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
