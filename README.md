# Adaptadocx

[![QA](https://github.com/mikhail-marutyan/adaptadocx/actions/workflows/qa-checks.yml/badge.svg)](https://github.com/mikhail-marutyan/adaptadocx/actions/workflows/qa-checks.yml)
[![Security](https://github.com/mikhail-marutyan/adaptadocx/actions/workflows/security-audit.yml/badge.svg)](https://github.com/mikhail-marutyan/adaptadocx/actions/workflows/security-audit.yml)
[![Release](https://github.com/mikhail-marutyan/adaptadocx/actions/workflows/release.yml/badge.svg)](https://github.com/mikhail-marutyan/adaptadocx/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Live site:** **https://adaptadocx.netlify.app/**

Adaptadocx is a documentation-publishing system built on Antora. It assembles multilingual AsciiDoc sources and produces **HTML**, **PDF**, and **DOCX**. The project ships with built-in QA checks, automated security scans, and CI workflows.

---

## Key features

### Multiple output formats

| Format | Highlights |
| --- | --- |
| **HTML** | Static site with language/theme selection, Lunr search, per-version downloads |
| **PDF** | DejaVu fonts, custom theme |
| **DOCX** | Pandoc pipeline, auto cover page, SVG→PNG (optional) |

### Multilingual support
- Independent English / Russian components
- Per-locale builds and per-version downloads

### Quality assurance
- **Vale** style linting
- **htmltest** link validation
- **Shellcheck** script analysis
- CI pipelines for QA, security, and releases

---

## Installation

### Docker (recommended)

```bash
git clone https://github.com/mikhail-marutyan/adaptadocx.git
cd adaptadocx
docker build -t adaptadocx .
docker run --rm -v "$(pwd)":/work adaptadocx make build-all
````

Artifacts appear in `build/`.

### Local development (tooling)

* Node.js 20 LTS
* Ruby ≥ 2.7
* Graphviz
* Vale
* htmltest
* Shellcheck
* Git
* (Optional) Python 3.11+ for `build.py`

```bash
npm ci --no-audit --no-fund
make build-all
```

---

## Build modes

* **Local** (default): builds only the current ref (branch/commit).

  * Override ref with `BUILD_REF=<ref>` (e.g., a branch name).
* **Tags**: builds all versions from Git tags.

**Make examples**

```bash
# local mode (default): current ref
make build-all

# local mode for a specific branch
make build-all BUILD_REF=my-feature

# all tags (multiversion)
make build-all BUILD_SCOPE=tags
```

**Python examples**

```bash
# local mode (default)
python3 build.py build-all

# local mode for a specific ref
python3 build.py --scope local --ref my-feature build-site

# all tags (multiversion)
python3 build.py --scope tags build-all
```

Environment variables mirror Python flags: `BUILD_SCOPE=local|tags`, `BUILD_REF=<git-ref>`.

---

## Quick start

```bash
npm ci --no-audit --no-fund
make build-all
make test
```

Preview the site at:

* Local mode: `build/site/en/current/index.html` (and `ru/current/index.html`)
* Tags mode:  `build/site/<locale>/<tag>/index.html`

### Individual targets

```bash
make build-html     # HTML only (Antora)
make build-pdf      # PDF only (Asciidoctor PDF)
make build-docx     # DOCX only (Pandoc)
make clean          # Delete build/
make test           # QA checks: vale, htmltest (if site exists), shellcheck
make release        # Zip artifacts as adaptadocx-docs-<version>.zip
```

---

## Artifact layout

Per-locale, per-version outputs:

```
build/
├── site/
│   └── <locale>/<version>/_downloads/
│       ├── adaptadocx-<locale>.pdf
│       └── adaptadocx-<locale>.docx
├── pdf/
│   └── <locale>/<version>/adaptadocx-<locale>.pdf
└── docx/
    └── <locale>/<version>/adaptadocx-<locale>.docx
```

Notes:

* `build/asm/` contains intermediate assemblies exported by `@antora/pdf-extension`.
* Download links in the site header always point to the current version’s `_downloads`.

---

## Python-based build (alternative)

`build.py` mirrors the Makefile and supports the same modes.

```bash
# full site: HTML + PDF + DOCX
python3 build.py build-all

# single stages
python3 build.py build-html
python3 build.py build-pdf
python3 build.py build-docx
python3 build.py test
python3 build.py clean

# scope / ref control
python3 build.py --scope tags build-all
python3 build.py --scope local --ref my-feature build-site
```

---

## Architecture

### Components

| Area                    | Notes                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------- |
| **Antora core**         | EN/RU components, custom UI, playbooks                                                  |
| **Build orchestration** | Makefile (primary), `build.py` (alt)                                                    |
| **PDF**                 | Asciidoctor PDF + theme (`config/default-theme.yml`)                                    |
| **DOCX**                | Pandoc + Lua filters (`docx/coverpage.lua`, `docx/svg2png.lua`) + Asciidoctor extension |
| **Search**              | Lunr index (EN + RU)                                                                    |
| **QA**                  | Vale, htmltest, Shellcheck                                                              |
| **Security**            | OSV-Scanner, Sandworm, banned-pattern gate                                              |

### Pipeline

1. **Antora build** → HTML site to `build/site/` and assemblies to `build/asm/`
2. **PDF** → from `build/asm/…/_exports/index.adoc` to `build/pdf/<locale>/<version>/…`
3. **DOCX** → from the same assemblies to `build/docx/<locale>/<version>/…`
4. **Downloads** → copied into `build/site/<locale>/<version>/_downloads/`
5. **QA** → Vale, htmltest, Shellcheck
6. **Release** → `adaptadocx-docs-<version>.zip`

---

## Configuration

| File / Dir                                         | Purpose                     |
| -------------------------------------------------- | --------------------------- |
| `antora-playbook-en.yml`, `antora-playbook-ru.yml` | Site-level config           |
| `docs/*/antora.yml`                                | Component titles / versions |
| `config/default-theme.yml`                         | PDF theme                   |
| `custom-ui/`                                       | HTML templates, CSS, JS     |
| `.vale.ini`                                        | Style rules                 |
| `.htmltest.yml`                                    | Link validation             |

Version is auto-detected from Git tags (fallback: `package.json`) and used for output layout and metadata.

---

## Project structure

```text
adaptadocx/
├── docs/
│   ├── en/ …                     # English sources
│   └── ru/ …                     # Russian sources
├── config/                       # Themes and metadata
├── custom-ui/                    # Antora UI bundle + supplemental files
├── docx/                         # Pandoc filters (coverpage.lua, svg2png.lua)
├── extensions/                   # Asciidoctor extensions
├── scripts/                      # Helper scripts
├── .github/workflows/            # CI/CD workflows
│   ├── qa-checks.yml
│   ├── security-audit.yml
│   └── release.yml
├── Makefile / Dockerfile / package.json / build.py
└── build/                        # Generated outputs
    ├── site/
    ├── asm/
    ├── pdf/
    └── docx/
```

---

## CI/CD workflows

| Workflow           | Purpose                                                                  | Trigger                |
| ------------------ | ------------------------------------------------------------------------ | ---------------------- |
| **QA Checks**      | Vale, htmltest, Shellcheck                                               | `pull_request` (`main`) |
| **Security Audit** | OSV-Scanner, Sandworm, banned-patterns                                   | `pull_request` (`main`) |
| **Release**        | Docker build (with `BUILD_SCOPE=tags`), validate, zip, deploy to Netlify | `push` (tags)           |

---

## QA checks

```bash
make test
```

Outputs:

* `vale.xml` — style issues
* `htmltest.log` — link errors
* Shellcheck — console diagnostics

---

## Contributing

1. Fork → branch (`feature/*`)
2. Edit, run: `make build-all && make test`
3. Conventional commits
4. Open a PR

---

## License

Adaptadocx is released under the [MIT License](LICENSE).