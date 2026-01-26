# CMU SPUD Lab Website

## Guide to Update Website Content

### Publications

Publications are automatically pulled from `https://sauvik.me/papers.json` during the build process. No local files need to be updated.

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

News updates automatically every 6 hours, or when the site is rebuilt.

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

- Code is pushed to `main` or `master` branch
- Every 6 hours (to pick up changes from Google Sheets and publications.json)
- Manually triggered from the Actions tab

**Deployment process:**

1. GitHub Actions builds the site (fetches external data from Google Sheets and `sauvik.me/papers.json`)
2. Deploys the built site to the `gh-pages` branch
3. GitHub Pages serves the site from `gh-pages` branch

**Configuration**: See `.github/workflows/deploy.yml` for the deployment workflow.

## Documentation

- [INSTALL.md](INSTALL.md) - Installation and setup instructions
- [CUSTOMIZE.md](CUSTOMIZE.md) - Customization guide
- [FAQ.md](FAQ.md) - Frequently asked questions
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines

## License

The theme is available as open source under the terms of the [MIT License](LICENSE).

Originally based on [al-folio](https://github.com/alshedivat/al-folio) theme.
