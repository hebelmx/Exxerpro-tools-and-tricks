# Authoring & anonymization rules

This is a **public** repo. Source of truth for raw notes is the private
`WorkstationMaintenance` repo. Content is **anonymized by default** — nothing
machine-specific, personal, or client-related ever lands here.

## The one rule

**Author clean, curate forward.** Write/port a doc already scrubbed. Never rely on
fixing it up "later" — and never copy git *history* from the private repo (history
carries secrets even after files are cleaned). New, clean commits only.

## Redaction map (scrub these before publishing)

| Private / real                         | Public placeholder            |
|----------------------------------------|-------------------------------|
| Your real repo path (e.g. a drive dir) | `<repo>` or `C:\path\to\repo` |
| `C:\Users\<your-windows-name>`         | `C:\Users\<you>`              |
| Real name / email                      | "you" / omit                  |
| Specific hostnames, machine models     | "your machine" / generic      |
| Monitor serials, resolutions if unique | describe generically          |
| Your GitHub login in examples          | `<username>`                  |

> The concrete real→placeholder values for this machine live in the **private**
> maintenance repo, not here — this public file only documents the *pattern*.

## Never publish

- Anything under the private repo's `scripts/` touching **banking / client work**
  (e.g. geolocation policy scripts) — client-sensitive, hard stop.
- `registry-backups/` or any raw registry export (can contain SIDs, GUIDs, usernames).
- Credentials, tokens, API keys, license keys — obviously.

## Publishing checklist (per doc)

1. Copy the note into the right `docs/<topic>/` folder.
2. Apply the redaction map above; read the whole thing once more.
3. Add it to `nav:` in `mkdocs.yml`.
4. `uv run zensical build` locally and skim the rendered page.
5. Commit + push — the GitHub Action publishes to Pages.

> Promotion candidates come from running the scan script in the private repo
> (`Scan-PublishCandidates.ps1`), which lists new/changed notes and flags any that still
> contain personal data.
