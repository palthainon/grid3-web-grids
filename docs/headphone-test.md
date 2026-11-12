# Headphone Test grid set

`grids/Headphone Test.gridset`, built by `tools/build-headphone-test.ps1`. It checks which device each Grid 3
speak route plays on, and holds cells to copy into a user's own grid sets in Edit mode. Positions are
column,row from 0.

## Pages

| Page | Size | What it holds |
|---|---|---|
| Home | 5x3 | 0,0 1 Headphones and 1,0 2 Speaker (SpeakNow with and without the audio feedback voice). 2,0 Web test. 3,0 Exit (Grid Explorer). 4,0 Volume cells. 0,1 to 2,1 sign-in pages (Gmail, Outlook, Google Messages; a person signs in). 3,1 Cells to copy. 0,2 Stop speaking. 1,2 Device test. 2,2 Email test. 3,2 Text message test |
| Cells to copy | 4x3 | 0,0 and 1,0 Grid 3 "Change audio device" cells (they fill in Grid 3's device order). 0,2 Speaker check. 2,2 Back. 3,2 Exit |
| Volume | 4x3 | 0,0 Speaker louder. 1,0 Speaker quieter. 0,1 Headphones louder. 1,1 Headphones quieter. 2,0 Speaker check. 2,1 Headphones check. 3,1 Log volume status. 2,2 Back. 3,2 Exit |
| Devices | 6x3 | Four device cells that also speak a test sentence. 0,2 audio feedback test |
| Email, Texts | 7x4 | Grid 3's email or SMS list, with device cells that switch and then read (`Email.Speak`, `Sms.Speak`) |
| Web | 6x4 | example.com with `templates/headphone.js` reads |

## Volume cells and device-volume.exe

Grid 3's own device volume cells (`ComputerControl.DeviceVolume`) change only the Windows default playback device.
The Volume page's cells run `%ALLUSERSAPPDATA%\grid3-web-grids\device-volume.exe` (that is `C:\ProgramData`):

- `device-volume.exe "<part of the device name>" +10` or `-10`: one named device, 10 points a press. A step up
  also unmutes. `mute` toggles mute.
- `device-volume.exe status`: logs each device's volume and mute, which one is the Windows default, and each app
  on each device with its app volume.
- Every run adds lines to `C:\ProgramData\grid3-web-grids\device-volume.log`. "no device matches" means the name
  in the cell does not fit a device on this computer.

Install or update it on each computer with `pwsh -NoProfile -File tools\install-device-volume.ps1`. It builds
`tools/device-volume.cs` with the C# compiler in Windows (no download) and prints a status.

The device names come from build parameters: `-SpeakerName` (default `USB AUDIO CODEC`) and `-HeadphoneName`
(default `AB13X`). The match ignores case and repeated spaces. Rebuild with the names from a status run when a
computer's devices differ.

## Tested

- 2026-11-12, test machine, Grid 3 3.0.104: Log volume status and Speaker louder pressed with `grid3-click`.
  Grid 3 started the exe both times (Grid 3.log), and the exe logged. The defaults name devices that machine does
  not have, so no volume changed in Grid 3. The exe changed volume when run outside Grid 3.
- Device and headphone results are in the private ticket for the user's device.
