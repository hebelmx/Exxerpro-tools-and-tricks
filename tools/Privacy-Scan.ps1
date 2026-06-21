<#
.SYNOPSIS
    Privacy gate for this PUBLIC repo. Scans git-tracked files for sensitive content
    and exits non-zero if anything is found. Invoked by the pre-push hook.

.DESCRIPTION
    Two layers of rules:
      1. Generic, safe-to-publish patterns baked in below (keys, tokens, secrets).
      2. Person/machine-specific patterns loaded from tools/privacy-rules.local
         (gitignored — never committed, so the real names/paths don't leak via this file).

    Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.EXAMPLE
    pwsh -File tools/Privacy-Scan.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = (& git rev-parse --show-toplevel 2>$null))

if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
Set-Location $RepoRoot

$tracked = & git ls-files
if (-not $tracked) { Write-Host "[privacy] no tracked files."; exit 0 }

# --- Layer 1: generic high-confidence secrets (safe to keep public) ---
$rules = @(
    @{ Name = 'Private key block'; Pattern = 'BEGIN\s+[A-Z ]*PRIVATE KEY' }
    @{ Name = 'GitHub token';      Pattern = 'gh[pousr]_[A-Za-z0-9]{30,}' }
    @{ Name = 'AWS access key';    Pattern = 'AKIA[0-9A-Z]{16}' }
    @{ Name = 'Slack token';       Pattern = 'xox[baprs]-[A-Za-z0-9-]{10,}' }
    @{ Name = 'Secret assignment'; Pattern = '(?i)(password|passwd|secret|api[_-]?key|access[_-]?token)\s*[:=]\s*["'']?[^\s"''#]{8,}' }
)

# --- Layer 2: local-only person/machine rules (one regex per line, '#' = comment) ---
$localRulesFile = Join-Path $RepoRoot 'tools/privacy-rules.local'
if (Test-Path $localRulesFile) {
    Get-Content $localRulesFile |
        Where-Object { $_ -and ($_ -notmatch '^\s*#') } |
        ForEach-Object { $rules += @{ Name = 'Local rule'; Pattern = $_.Trim() } }
} else {
    Write-Host "[privacy] note: tools/privacy-rules.local not found — running generic rules only." -ForegroundColor DarkYellow
}

# Files the scanner should not flag on itself.
$selfSkip = @('tools/Privacy-Scan.ps1')

$findings = @()
foreach ($file in $tracked) {
    if ($selfSkip -contains $file) { continue }
    if (-not (Test-Path $file)) { continue }
    $content = Get-Content -Path $file -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    foreach ($r in $rules) {
        $m = [regex]::Matches($content, $r.Pattern)
        if ($m.Count -gt 0) {
            $sample = $m[0].Value; if ($sample.Length -gt 40) { $sample = $sample.Substring(0, 40) + '...' }
            $findings += [pscustomobject]@{ File = $file; Rule = $r.Name; Sample = $sample }
        }
    }
}

if ($findings.Count -gt 0) {
    Write-Host ""
    Write-Host "[privacy] BLOCKED - sensitive content in tracked files:" -ForegroundColor Red
    foreach ($f in $findings) {
        Write-Host ("  - {0}  [{1}]  ~ '{2}'" -f $f.File, $f.Rule, $f.Sample) -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Scrub per AUTHORING.md. If already committed, purge history per PRIVACY.md." -ForegroundColor Yellow
    exit 1
}

Write-Host "[privacy] clean - no sensitive tokens in tracked files." -ForegroundColor Green
exit 0
