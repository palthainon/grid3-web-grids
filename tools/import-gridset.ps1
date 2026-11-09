# Hands a built grid set to Grid 3 to import, the same way double-clicking a .gridset does
# (Windows opens .gridset with "Grid 3.exe" "%1"). Copying into the user's Grid Sets folder
# instead is undone by Grid 3's sync, so always import this way or through Grid Explorer.
#
# By default it rebuilds Muse (sites\muse), checks it, then opens it in Grid 3. Seen 2026-11-08 (Grid 3
# open on a user): Grid 3 adds the set at once, with no prompt, and shows "Added Muse (2)". Each import adds
# a new copy. To replace the old set, a person deletes it in Grid Explorer and renames the new copy.
# It never closes or restarts Grid 3, because that is how the user communicates.
#
# Usage (from the repo folder):
#   pwsh -NoProfile -File tools\import-gridset.ps1                 # build, check, import Muse
#   pwsh -NoProfile -File tools\import-gridset.ps1 -NoBuild        # import the existing build
#   pwsh -NoProfile -File tools\import-gridset.ps1 -GridSet grids\Other.gridset -NoBuild
param(
    [string]$GridSet = (Join-Path (Split-Path $PSScriptRoot -Parent) 'grids\Muse.gridset'),
    [switch]$NoBuild
)
$ErrorActionPreference = 'Stop'
$gridExe = 'C:\Program Files (x86)\Smartbox\Grid 3\Grid 3.exe'

if (-not $NoBuild) {
    $buildScript = Join-Path $PSScriptRoot 'build-site.ps1'
    & pwsh -NoProfile -File $buildScript -Site muse
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $buildScript" }
}

$GridSet = (Resolve-Path -LiteralPath $GridSet).Path
$global:LASTEXITCODE = 0
& (Join-Path $PSScriptRoot 'check-gridset.ps1') -GridSet $GridSet
if ($LASTEXITCODE -ne 0) { throw "Check failed, not importing: $GridSet" }

if (-not (Test-Path -LiteralPath $gridExe)) { throw "Grid 3 not found at $gridExe" }
# Never start Grid 3: it opens on its Users screen, where only a person can press Open, and a file sent then
# is not imported (seen 2026-11-06 and 2026-11-08).
if (-not @(Get-Process -Name 'Grid 3' -ErrorAction SilentlyContinue).Count) {
    throw "Grid 3 is not running. Ask a person to open Grid 3 on the user's profile, then run this again."
}
Start-Process -FilePath $gridExe -ArgumentList ('"{0}"' -f $GridSet)

Write-Output "Sent to Grid 3: $GridSet"
Write-Output 'Grid 3 adds the set as a new copy ("Added <name> (2)"). If nothing happens, Grid 3 may be on its Users screen:'
Write-Output 'a person opens the profile, then run this again, or imports through Grid Explorer.'
