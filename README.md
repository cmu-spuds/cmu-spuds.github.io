# CMU SPUD Lab Website

## Guide to Update Website Content

### Publications

Publications are automatically pulled from `https://sauvik.me/papers.json` during the build process. No local publication data file needs to be updated.

**Configuration**: See `_config.yml` → `jekyll_get_json` section.

### News

News items are managed via Google Sheets: [SPUD Lab News Sheet](https://docs.google.com/spreadsheets/d/1hjbkuxD2R-mZU4PkBJfvcV3QtldjzmIlqV8rP4M1CTY/edit?usp=sharing)

**To add news:**

1. Log in with `spudlab@andrew.cmu.edu`
2. Add a new row to the sheet with these columns:

| Column    | Description                                                       |
| --------- | ----------------------------------------------------------------- |
| `date`    | Date in `YYYY-MM-DD` format                                       |
| `title`   | News headline                                                     |
| `content` | Full news content (supports Markdown)                             |
| `inline`  | Set to `true` to show content on homepage, `false` for title only |
| `url`     | Optional link URL                                                 |

External publications and news are checked every 6 hours. A build is requested only
when their content differs from the last successful deployment. Repository changes
also trigger builds immediately.
The build renders fetched announcements immediately without changing source files.
Checked-in `gs_` news files provide fallback content if the sheet cannot be fetched
or parsed; manually maintained news files are preserved.

### Featured Projects

Edit [`_data/featured_projects.yml`](_data/featured_projects.yml) to add project links shown on the homepage.

```yaml
- title: Project Name
  url: https://project-url.com
```

### People

Edit [`_data/people.yml`](_data/people.yml) to update lab members.

```yaml
- name: Full Name
  image: filename.jpg # Place image in assets/img/
  role: Title/Position
  description: Research focus
  website: https://example.com
  years: 2023-present
```

### Adding Images

Place images in `assets/img/` and reference just the filename in the YAML files.

## Development

### Local Setup

```bash
bundle install
bundle exec jekyll serve
```

### Building

```bash
bundle exec jekyll build
```

The site will be generated in the `_site` directory.

### Tests

```bash
bundle exec ruby -e 'Dir["test/*_test.rb"].sort.each { |file| require_relative file }'
```

These tests check feed change detection and build temporary Jekyll sites with
simulated sheet responses. They run before deployment.

### Clear Cache and Rebuild

If you encounter build issues or need to force a fresh build with updated external data:

```bash
# Clear Jekyll cache
rm -rf .jekyll-cache

# Clear built site
rm -rf _site

# Rebuild
bundle exec jekyll build
```

Or to serve locally with a clean build:

```bash
rm -rf .jekyll-cache _site && bundle exec jekyll serve
```

## Deployment

The site is automatically built and deployed to GitHub Pages via GitHub Actions.

**Automatic builds happen when:**

- Any change is pushed to `main` or `master`
- The external content check detects changed publications or news
- Manually triggered from the Actions tab

The separate [external content workflow](.github/workflows/external-content.yml)
checks both feeds every 6 hours, at 00:17, 06:17, 12:17, and 18:17 UTC. GitHub may
delay scheduled runs. Unchanged feeds skip the build and its follow-up checks.
Publication download/like counters and JSON formatting are ignored because they
do not change the displayed content. Feed errors fail the check without changing
the saved state, so the next check can retry.

**Deployment process:**

1. GitHub Actions captures validated snapshots of Google Sheets and `sauvik.me/papers.json`.
2. Jekyll builds using those exact snapshots, without fetching either source again.
3. The built site and `external-content-state.json` are deployed together to `gh-pages`.
4. GitHub Pages serves the site. Future feed checks compare against the deployed state.

The state contains content hashes, not credentials. It changes only after a
successful build is deployed, so a failed build does not suppress retries.
The first deployment initializes this state. Manual builds remain available
through the **Deploy site** workflow; the **Check external content** workflow can
also be run manually to check without forcing a build.

**Configuration**: See `.github/workflows/deploy.yml` for the deployment workflow.

## Documentation

- [INSTALL.md](INSTALL.md) - Installation and setup instructions
- [CUSTOMIZE.md](CUSTOMIZE.md) - Customization guide
- [FAQ.md](FAQ.md) - Frequently asked questions
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines

## License

The theme is available as open source under the terms of the [MIT License](LICENSE).

Originally based on [al-folio](https://github.com/alshedivat/al-folio) theme.
