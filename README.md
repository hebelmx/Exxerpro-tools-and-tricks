# Exxer Tools & Tricks

A curated, anonymized collection of **Windows tools, tricks, and fixes** — published as a
static site built with [Zensical](https://zensical.org) (by the Material for MkDocs team).

📖 **Live site:** https://hebelmx.github.io/Exxerpro-tools-and-tricks/

## What this is

Real, copy-pasteable Windows fixes distilled from day-to-day workstation maintenance —
PowerToys quirks, Docker/WSL recovery, performance tuning, and more. Everything is
**anonymized by default**: no machine-specific paths, hostnames, or personal data.

## Repo layout

```
docs/                  Markdown content (the site)
├── index.md
└── powertoys/
    └── zoomit-livezoom.md
mkdocs.yml             Zensical config (read for MkDocs compatibility)
AUTHORING.md           Anonymization rules + publishing checklist
```

## Build locally

```bash
uv venv && uv pip install zensical
uv run zensical build          # outputs the static site to ./site
uv run zensical serve          # live preview while editing
```

## Contributing notes

This is curated forward from a private maintenance repo — see [`AUTHORING.md`](AUTHORING.md)
for the anonymization rules. The golden rule: author clean, never import private history.

---

No warranty. Read before running anything that changes your system.
