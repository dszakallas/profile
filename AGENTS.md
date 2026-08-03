# AI Agent Guidelines for `profile` (`szakallas.net`)

Welcome! This document provides instructions for AI coding agents working on this codebase.

## Repository Overview

This repository powers [szakallas.net](https://szakallas.net), the personal website and portfolio of Dávid Szakállas.
It is built with **Jekyll**, **Nix**, **devenv.sh**, **Python (Jinja2)**, and **XeTeX**.

### Directory Structure

- `src/`: Source code for the Jekyll website.
  - `src/_posts/`: Blog posts in Markdown.
  - `src/_data/navigation.yml`: Navigation menu configuration.
  - `src/_includes/` & `src/_layouts/`: Jekyll templates and layouts.
  - `src/cv/`: CV source files.
    - `cv.yaml`: **Single source of truth** for personal info, experience, education, skills, and projects.
    - `cv.cls`: Custom LaTeX class definition.
    - `templates/cv.html.j2`: Jinja2 template for rendering the CV web page (`src/cv/index.html`).
    - `templates/david_szakallas.tex.j2`: Jinja2 template for rendering the LaTeX CV (`david_szakallas.tex`).
- `hack/`: Build and maintenance scripts.
  - `generate-cv.py`: Python script driving CV HTML and PDF generation.
  - `art.sh` & `optimize-images.sh`: Icon and image processing scripts.
- `devenv.nix`: Main `devenv` environment configuration.
- `devenv/`: Modular `devenv` profiles.
  - `tex.nix`: Profile containing `pkgs.texliveFull` (~4GB) for compiling the PDF CV.
- `site.nix`: Nix derivation packaging the website.

---

## Development Environment & Workflow

### Shell Execution

Commands must be executed within the `devenv` shell to ensure access to all required dependencies:

```bash
# Enter interactive devenv shell
devenv shell --no-tui --quiet

# Run one-off command inside devenv
devenv shell --no-tui --quiet -- <command>

# Include the tex profile for PDF compilation tasks
devenv shell --profile tex --no-tui --quiet -- <command>
```

> **Note**: Do not enter an ephemeral `devenv shell` for long-running processes.
> Run background services directly via `devenv up -d` from the host shell.

### Devenv Scripts

- `generate-cv`: Regenerates `src/cv/index.html` without PDF generation.
- `build-cv`: Compiles PDF via `xelatex` (requires `tex` profile), copies `david_szakallas.pdf` to assets,
  and renders `src/cv/index.html` with PDF download button enabled.
- `build`: Runs `generate-cv` and builds Jekyll site locally into `_site/`.

### CV Data Pipeline

All CV edits **must** be made in `src/cv/cv.yaml`.
Never manually edit `src/cv/index.html` or generated LaTeX/PDF files directly.

```bash
# 1. Edit source data
vim src/cv/cv.yaml

# 2. Regenerate web CV page (without PDF)
devenv shell --no-tui --quiet -- generate-cv

# 3. Regenerate web CV page AND compile PDF CV (requires tex profile)
devenv shell --profile tex --no-tui --quiet -- build-cv
```

The background process `watch-cv` automatically monitors `src/cv/cv.yaml` and `src/cv/templates/`
and re-runs `generate-cv` on changes when running `devenv up`.

---

## Building the Site with Nix

The site build is fully defined in `site.nix`.

```bash
# Build production site output (hermetic, includes PDF compilation)
devenv build outputs.production

# Build staging site output (--future enabled)
devenv build outputs.staging
```

`site.nix` supports the parameter `withoutCvPdf ? false`.
When set to `true`, `texliveFull` is excluded from dependencies and `generate-cv.py` is executed without `--with-latex`.

---

## Code Style & Git Conduct

- **Surgical Staging Only**: **NEVER** run blanket commands like `git add .` or `git add -A`.
  Surgically stage only the specific files modified for the task.
- **Pre-commit Hooks**: Do not bypass pre-commit hooks with `--no-verify`.
  Ensure `markdownlint`, `nixfmt-rfc-style`, and `bundix` pass cleanly.
- **No AI Attribution**: Do not add any AI attribution (e.g. `Co-Authored-By: ...`, "Written by AI")
  to commits, PR descriptions, or inline comments.
