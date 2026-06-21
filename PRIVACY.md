# Privacy & leak prevention

This is a **public** repo. Protecting against accidentally publishing private,
machine-specific, or client data is enforced in layers.

## Layer 1 — anonymize by default

Author clean. Rules + redaction map + never-publish list live in
[`AUTHORING.md`](AUTHORING.md). Never import git history from the private repo.

## Layer 2 — automatic pre-push scan (the gate)

A git **pre-push hook** runs `tools/Privacy-Scan.ps1` on every push and **blocks** it if
anything sensitive is found in tracked files.

Enable it once after cloning:

```powershell
git config core.hooksPath .githooks
```

The scanner uses two rule sets:

- **Generic, committed** rules in `tools/Privacy-Scan.ps1` — private keys, GitHub/Slack
  tokens, AWS keys, and secret/password-style assignments. Safe to be public.
- **Local, gitignored** rules in `tools/privacy-rules.local` — your person/machine-specific
  patterns (real name, email, local paths, client names). **This file is never committed**,
  so the very things it protects don't leak through it. Recreate it on a new machine.

Run it manually anytime:

```powershell
pwsh -File tools/Privacy-Scan.ps1
```

> Bypassing the gate with `git push --no-verify` defeats the purpose — don't, unless you
> have re-scanned by hand.

## Layer 3 — if something private already leaked

If sensitive data reached the public remote, **two things must happen**:

### 1. Treat it as compromised — rotate it

Anything pushed publicly may already be cloned, cached, or indexed. Rewriting history
reduces *further* exposure; it does **not** un-leak. Rotate/invalidate the secret (change
the password, revoke the token) **regardless** of the cleanup below.

### 2. Purge it from history, then force-push

Use the helper (needs `git-filter-repo`: `uv pip install git-filter-repo`):

```powershell
# remove a whole file from all history
pwsh -File tools/Purge-Secret-FromHistory.ps1 -Path docs/oops.md

# or redact a literal string everywhere it appears
pwsh -File tools/Purge-Secret-FromHistory.ps1 -Literal "the-leaked-string"
```

Then:

```powershell
git remote add origin https://github.com/<user>/<repo>.git   # filter-repo drops the remote
git push --force --all
git push --force --tags
```

For content already served by GitHub Pages or cached in search engines, you may also need
to ask GitHub Support to purge cached views.
