# Builds tools\device-volume.cs into %APPDATA%\grid3-web-grids\device-volume.exe with the C# compiler that
# ships with Windows (.NET Framework 4). The Volume cells in Headphone Test run that path. No download.
# It writes device-volume.log next to the exe. Run it again after a pull that changes device-volume.cs.
# Usage: pwsh -File tools\install-device-volume.ps1   (then: device-volume.exe x list, to log the device names)
$ErrorActionPreference = 'Stop'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "No C# compiler at $csc" }
$dir = New-Item -ItemType Directory -Force (Join-Path $env:APPDATA 'grid3-web-grids')
$exe = Join-Path $dir 'device-volume.exe'
& $csc /nologo /target:winexe /optimize "/out:$exe" (Join-Path $PSScriptRoot 'device-volume.cs')
if ($LASTEXITCODE) { throw "csc failed ($LASTEXITCODE)" }
& $exe x list | Out-Null
Get-Content (Join-Path $dir 'device-volume.log') -Tail 1
