# Run once, as administrator, by a person: lets an agent press Grid 3 cells on a test machine.
# Builds tools\grid3-click.cs into %ProgramFiles%\grid3-web-grids (only admins can change it) and registers the
# scheduled task "grid3-web-grids click", which runs it elevated. The exe clicks only at a point over Grid 3.
# Run it again after a pull that changes grid3-click.cs.
# Remove: Unregister-ScheduledTask "grid3-web-grids click" -Confirm:$false; Remove-Item "$env:ProgramFiles\grid3-web-grids" -Recurse
# Not for Philip's own device: it lets any program of this user press Grid 3 cells.
$ErrorActionPreference = 'Stop'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if (-not $admin) { throw 'Run this from an administrator PowerShell.' }
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$dir = New-Item -ItemType Directory -Force (Join-Path $env:ProgramFiles 'grid3-web-grids')
$exe = Join-Path $dir 'grid3-click.exe'
& $csc /nologo /target:winexe /optimize "/out:$exe" (Join-Path $PSScriptRoot 'grid3-click.cs')
if ($LASTEXITCODE) { throw "csc failed ($LASTEXITCODE)" }
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
# The user writes click requests here without elevation; the elevated exe reads and deletes them.
$data = New-Item -ItemType Directory -Force (Join-Path $env:ProgramData 'grid3-web-grids')
icacls $data.FullName /grant "${user}:(OI)(CI)M" | Out-Null
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'grid3-web-grids click' -Action (New-ScheduledTaskAction -Execute $exe) `
    -Principal $principal -Settings $settings -Force | Out-Null
"Installed $exe and the task 'grid3-web-grids click' for $user."
