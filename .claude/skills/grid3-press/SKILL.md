---
name: grid3-press
description: Press Grid 3 cells yourself on a test machine and read what happened, with tools/grid3-click.ps1, screenshots and Grid 3's own log. Use when you need to check a built grid set in Grid 3 (a cell runs a program, a page opens, a jump works), when a cell "does nothing", or before telling a person a grid set works. Not for the user's own device.
---

# Press Grid 3 cells and read the result

Grid 3 has `uiAccess`, so Windows drops clicks, keys and UI Automation from normal programs. Computer use
clicks, `SendInput` and UI Automation all failed (2026-11-12). `tools/grid3-click.ps1` presses through a
scheduled task that runs `grid3-click.exe` elevated. Background: `docs/grid3-internals.md`, "Working with Grid 3
as an AI agent".

## One-time setup (a person, as administrator)

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools\install-grid3-click.ps1
```

- Run it from a checkout of `main` (a detached worktree is fine). Run it again after any change to
  `tools/grid3-click.cs`. So test every accept and refuse path unelevated first: compile the exe to a scratch
  folder with the same `csc` line and run it. Unelevated, it logs "clicked" but Grid 3 ignores the click.
- Never install it on the end user's own device. It lets any program of that Windows user press Grid 3 cells.
- Check it: `Get-ScheduledTask 'grid3-web-grids click'` and `%ProgramFiles%\grid3-web-grids\grid3-click.exe`.

## Loop

1. Look first. Ask for screen access to Grid 3 if the project's rules say so, then take a computer use screenshot
   (`scale` 0.5 is enough). `(Get-Process 'Grid 3').MainWindowTitle` gives `Grid 3 - <set> - <set> - <grid>`
   without a screenshot.
2. Convert the cell centre to physical pixels: screenshot frame x times (screen width / frame width). Example:
   frame 1456 wide, screen 1920 wide, so multiply by 1.3187. Get screen sizes with
   `[System.Windows.Forms.Screen]::AllScreens`.
3. Press: `pwsh -NoProfile -File tools\grid3-click.ps1 -X <x> -Y <y>`. It prints one log line:
   `clicked Grid 3 at x,y (sent 2 of 2)`, or `refused: x,y is over '<process>'`.
4. Wait 2 to 3 s, then check: a new screenshot, the window title, the program's own log, and Grid 3's log:
   `C:\Users\Public\Documents\Sensory Software\Diagnostic Logs\Grid 3.log`. For a Run cell, Grid 3 logs
   `Launching <path> <args>`, then `started` or `Error launching ... cannot find the file`.

## Traps

- Send the click alone. A screenshot in the same message runs at the same time and can make the exe refuse.
- While computer use runs, the Claude desktop app shrinks to a topmost panel on the right of the primary display.
  The exe refuses cells under it (correctly: the click would land on Claude). Move the panel to another monitor
  with `SetWindowPos` on the Claude window whose extended style is `0x280108`. The full-screen click-through
  overlay (`WS_EX_TRANSPARENT`) is harmless: the exe looks through it.
- An elevated window with focus (an admin PowerShell) blocks cursor moves from normal programs. The exe moves the
  pointer itself, so this no longer matters for presses.
- The exe refuses points over Grid 3's web browser (`msedgewebview2`), so it cannot press a page's buttons
  (such as Send). Test page scripts on the live site instead (`site-grid` skill).
- Grid 3's own toolbar works: Menu at the top left, then Grid Explorer, reaches any grid set without the set's
  own cells.
- The Claude desktop app is a packaged app. Files it writes to `%APPDATA%` go to a private copy that Grid 3
  cannot see. Install anything Grid 3 must run under `%ProgramData%` (Grid 3's `%ALLUSERSAPPDATA%`).
- Never press anything that sends, buys or changes an account for the user. Navigation and test-set cells only.
- Record what you saw (log lines, titles) in the ticket, with the date.
