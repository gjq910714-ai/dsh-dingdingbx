# Install dsh-dingdingbx into the user-level DSH skills directory.
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Dest "D:\custom\skills"

param(
    [string]$Dest = "$env:USERPROFILE\.dsh\skills\dsh-dingdingbx"
)

$ErrorActionPreference = "Stop"
$src = $PSScriptRoot

if (-not (Test-Path (Join-Path $src "SKILL.md"))) {
    throw "Run this from the repository root (SKILL.md not found in $src)."
}

if (Test-Path $Dest) {
    Write-Host "Destination exists, overwriting: $Dest"
    Remove-Item -Recurse -Force $Dest
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
foreach ($item in @("SKILL.md", "README.md", "references", "scripts", "LICENSE")) {
    $p = Join-Path $src $item
    if (Test-Path $p) {
        Copy-Item -Recurse -Force $p $Dest
    }
}

Write-Host "Installed to $Dest"
Write-Host ""
Write-Host "Check dependencies:"
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source -c "import fitz; print('pymupdf OK', fitz.__doc__)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  pymupdf missing -> python -m pip install pymupdf"
    }
} else {
    Write-Host "  python not found"
}
Write-Host ""
Write-Host "Restart DSH (or reload skills) so the skill is picked up."
