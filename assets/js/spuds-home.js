// Interactions for the SPUD Lab homepage: copy-to-clipboard chips, citation
// copying, the mailto-backed contact form, and selected-publications filtering.

(function () {
  "use strict";

  function copyToClipboard(text, onDone) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(onDone, onDone);
    } else {
      var helper = document.createElement("textarea");
      helper.value = text;
      helper.setAttribute("readonly", "");
      helper.style.position = "absolute";
      helper.style.left = "-9999px";
      document.body.appendChild(helper);
      helper.select();
      document.execCommand("copy");
      document.body.removeChild(helper);
      onDone();
    }
  }

  // Copy email chip.
  document.querySelectorAll(".copy-email").forEach(function (button) {
    button.addEventListener("click", function () {
      copyToClipboard(button.dataset.email, function () {
        var label = button.querySelector(".copy-email-text");
        if (!label) return;
        var original = label.textContent;
        label.textContent = "Copied!";
        button.classList.add("copied");
        setTimeout(function () {
          label.textContent = original;
          button.classList.remove("copied");
        }, 2000);
      });
    });
  });

  // Copy citation buttons.
  document.querySelectorAll(".pub-cite").forEach(function (button) {
    button.addEventListener("click", function () {
      copyToClipboard(button.dataset.citation, function () {
        var original = button.innerHTML;
        button.innerHTML = '<i class="ti ti-check" aria-hidden="true"></i> Copied!';
        setTimeout(function () {
          button.innerHTML = original;
        }, 2000);
      });
    });
  });

  // Contact form: compose an email in the visitor's mail client.
  var contactForm = document.getElementById("contact-form");
  if (contactForm) {
    contactForm.addEventListener("submit", function (event) {
      event.preventDefault();
      var email = (document.getElementById("contact-email").value || "").trim();
      var role = document.getElementById("contact-role").value;
      var message = (document.getElementById("contact-message").value || "").trim();
      var subject = "[SPUD Lab] Message from a " + role;
      var body = message + "\n\n— " + (email || "(no email given)");
      var mailto =
        "mailto:" +
        (contactForm.dataset.email || "spudlab@cmu.edu") +
        "?subject=" +
        encodeURIComponent(subject) +
        "&body=" +
        encodeURIComponent(body);
      window.location.href = mailto;
    });
  }

  // Selected publications: text search + filter chips.
  var searchInput = document.getElementById("selectedPubSearch");
  var chips = Array.prototype.slice.call(document.querySelectorAll("[data-pub-filter]"));
  var pubList = document.getElementById("selected-publications-list");

  function applyPublicationFilters() {
    if (!pubList) return;
    var query = searchInput ? searchInput.value.trim().toUpperCase() : "";
    var activeChip = chips.filter(function (chip) {
      return chip.classList.contains("active");
    })[0];
    var filter = activeChip ? activeChip.dataset.pubFilter : "all";
    var anyVisible = false;

    pubList.querySelectorAll(".publication").forEach(function (pub) {
      var matchesFilter =
        filter === "all" ||
        (filter === "awarded" && pub.dataset.awarded === "true") ||
        pub.dataset.venue === filter;
      var matchesQuery = query === "" || (pub.textContent || "").toUpperCase().indexOf(query) > -1;
      var visible = matchesFilter && matchesQuery;
      pub.hidden = !visible;
      if (visible) anyVisible = true;
    });

    var emptyState = document.getElementById("selected-pubs-empty");
    if (emptyState) emptyState.hidden = anyVisible;
  }

  chips.forEach(function (chip) {
    chip.addEventListener("click", function () {
      chips.forEach(function (other) {
        other.classList.toggle("active", other === chip);
        other.setAttribute("aria-pressed", other === chip ? "true" : "false");
      });
      applyPublicationFilters();
    });
  });

  if (searchInput) searchInput.addEventListener("input", applyPublicationFilters);

  // Floating back-to-top: appears once the visitor scrolls past the hero.
  var floatingTop = document.querySelector(".back-to-top-floating");
  if (floatingTop) {
    var toggleFloatingTop = function () {
      floatingTop.classList.toggle("is-visible", window.scrollY > 600);
    };
    window.addEventListener("scroll", toggleFloatingTop, { passive: true });
    toggleFloatingTop();
  }
})();
