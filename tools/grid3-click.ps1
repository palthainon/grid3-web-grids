# Presses a Grid 3 cell, for agents on a test machine. Needs tools\install-grid3-click.ps1 run once (admin).
# -X -Y: the screen point in physical pixels (from a computer use screenshot: scale by screen width / image width).
# No point: clicks where the pointer is. Prints the click log line.
# Exit 0 = clicked, 2 = refused (not over Grid 3), 3 = task missing or no answer.
# Usage: pwsh -File tools\grid3-click.ps1 -X 100 -Y 132
param([int]$X = -1, [int]$Y = -1)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'grid3-web-grids'
$log = Join-Path $dir 'grid3-click.log'
$before = if (Test-Path $log) { @(Get-Content $log).Count } else { 0 }
if ($X -ge 0) { Set-Content (Join-Path $dir 'grid3-click-request.txt') "$X $Y" -NoNewline }
schtasks.exe /run /tn 'grid3-web-grids click' | Out-Null
if ($LASTEXITCODE) { 'The task "grid3-web-grids click" is missing. A person runs tools\install-grid3-click.ps1 as administrator.'; exit 3 }
foreach ($i in 1..50) {
    Start-Sleep -Milliseconds 100
    if ((Test-Path $log) -and @(Get-Content $log).Count -gt $before) {
        $line = @(Get-Content $log)[-1]; $line
        exit $(if ($line -match ' clicked ') { 0 } else { 2 })
    }
}
'No answer from the task in 5 s.'; exit 3
