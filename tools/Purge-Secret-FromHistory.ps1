<#
.SYNOPSIS
    Purge a file path or a literal secret string from the ENTIRE git history.

.DESCRIPTION
    Last-resort remediation when private data reached the public remote. Requires
    git-filter-repo (install: uv pip install git-filter-repo  OR  pip install git-filter-repo).

    THIS REWRITES HISTORY and requires a force-push. Anything already public must be
    considered COMPROMISED -> rotate/invalidate the secret regardless of this cleanup.

.PARAMETER Path
    File path to remove from all history (e.g. docs/leaked.md).

.PARAMETER Literal
    Literal string to redact from all history (replaced with ***REMOVED***).

.EXAMPLE
    .\Purge-Secret-FromHistory.ps1 -Path docs/oops.md

.EXAMPLE
    .\Purge-Secret-FromHistory.ps1 -Literal "super-secret-token"
#>
[CmdletBinding()]
param(
    [string]$Path,
    [string]$Literal
)

if (-not $Path -and -not $Literal) { Write-Error "Provide -Path or -Literal."; exit 2 }

& git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "Not inside a git repository."; exit 2 }

& git filter-repo --version 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "git-filter-repo not found. Install it: uv pip install git-filter-repo"
    exit 2
}

Write-Host "WARNING: this rewrites ALL history and will require a force-push." -ForegroundColor Yellow
Write-Host "The leaked data is likely already public -> ROTATE/INVALIDATE it regardless." -ForegroundColor Yellow

if ($Path) {
    & git filter-repo --path $Path --invert-paths --force
}
elseif ($Literal) {
    $tmp = New-TemporaryFile
    "literal:$Literal==>***REMOVED***" | Set-Content -Path $tmp -Encoding UTF8
    & git filter-repo --replace-text $tmp --force
    Remove-Item $tmp -Force
}

Write-Host ""
Write-Host "History rewritten. Next steps:" -ForegroundColor Cyan
Write-Host "  1) git remote add origin https://github.com/<user>/<repo>.git   # filter-repo drops origin"
Write-Host "  2) git push --force --all"
Write-Host "  3) git push --force --tags"
Write-Host "  4) Rotate the exposed secret; ask GitHub Support to purge cached views if needed."
