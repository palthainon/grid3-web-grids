# Presses the Grid 3 cell under the cursor, for agents on a test machine. Move the pointer onto the cell first
# (computer use mouse_move works on Grid 3; its clicks do not). Needs tools\install-grid3-click.ps1 run once.
# Prints the click log line. Exit 0 = clicked, 2 = cursor not over Grid 3, 3 = task missing or no answer.
# Usage: pwsh -File tools\grid3-click.ps1
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:ProgramData 'grid3-web-grids\grid3-click.log'
$before = if (Test-Path $log) { @(Get-Content $log).Count } else { 0 }
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
