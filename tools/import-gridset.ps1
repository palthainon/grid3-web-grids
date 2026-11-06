# Hands a built grid set to Grid 3 to import, the same way double-clicking a .gridset does
# (Windows opens .gridset with "Grid 3.exe" "%1"). Copying into the user's Grid Sets folder
# instead is undone by Grid 3's sync, so always import this way or through Grid Explorer.
#
# By default it rebuilds Muse (sites\muse), checks it, then opens it in Grid 3. Grid 3 then asks
# what to do with the file; answer in Grid 3. It never closes or restarts Grid 3, because
# that is how the user communicates. Each import adds a new copy ("Muse (2)").
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
$running = @(Get-Process -Name 'Grid 3' -ErrorAction SilentlyContinue).Count -gt 0
Start-Process -FilePath $gridExe -ArgumentList ('"{0}"' -f $GridSet)

Write-Output "Sent to Grid 3: $GridSet"
if ($running) { Write-Output 'Grid 3 was already running; look for its import prompt there.' }
else { Write-Output 'Grid 3 was not running and is starting; look for its import prompt.' }
Write-Output 'If no prompt appears, import through Grid Explorer instead and note it in the ticket.'
