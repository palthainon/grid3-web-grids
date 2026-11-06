---
name: site-grid
description: Build, test and check a website grid set for a Grid 3 user (Muse, YouTube Test, or a new site) from Smartbox's WhatsApp or YouTube template. Use when changing sites/<site>/page.js or site.psd1, adding a site, fixing a cell that does nothing in Grid 3, or checking a site script against the live page.
---

# Site grid sets: build, test, check

Background: `docs/templates.md` (how the builder works), `docs/grid3-internals.md` (Grid 3 limits),
`docs/sites/<site>.md` (each site's page facts). Read the site file before you touch its `page.js`.

## Loop

1. Work in a worktree. Change `sites/<site>/page.js` or `site.psd1`.
2. If you change what the script expects from the page, change `tests/muse-chat-mock.html` (or the site's
   mock) to match the real page, and add a check to `tests/test-site-scripts.mjs`.
3. Build and check:
   ```powershell
   pwsh -NoProfile -File tools\build-site.ps1 -Site <site>
   pwsh -NoProfile -File tools\check-gridset.ps1 -GridSet "grids\<Output>"
   node tests\test-site-scripts.mjs        # once: cd tests; npm install
   ```
   The `built` section runs the built set's own commandids the way Grid 3 sends them. It is the closest
   test to Grid 3 that runs here.
4. Check on the live site (see below). Mock tests alone have missed real-page behaviour twice.
5. Update `docs/sites/<site>.md` with what you saw and the date. Update the ticket and write a retro.
6. Merge, then the operator imports `grids\<Output>` and presses the cells.

## Check on the live site

- Use a Claude in Chrome tab signed in to the site. Only the operator signs in. Paste `page.js` with the
  JavaScript tool, then call `GridCommands.<ScriptName>.<Section>.<Name>()` and read the results.
- Never call anything that sends for the user: option buttons, Send, Reply plus typing. Read and move only.
- Put the page back as the user had it (their chat, no outline).
- Keep page text out of the repo. Chats hold the user's private messages.

## Grid 3 traps

- Grid 3 never runs a grid set's `code.js`. The builder puts `page.js` in each script commandid instead.
- Agents cannot press Grid 3 cells (uiAccess blocks input) and must not restart Grid 3 (only a person can
  press Open on the Users screen). Hover outlines are not presses.
- `tools/import-gridset.ps1 -GridSet grids\<Output> -NoBuild` adds a new copy each time ("Muse (2)").
- Sites keep UI state between visits (Muse's "Keep chat panel visible"). Check both states of any such
  setting on the live page, and put it back as you found it.
- Keep a never-press list per site in `docs/sites/<site>.md` (Muse: Log out, goal Mark checkboxes, Send,
  options) and make the item finders skip those elements.
- Cells carry short calls; the page script loads from each grid's on-open loader and `localStorage`. Do
  not put page code in a cell's commandid.
- Put the most used cells in scan group 1 (`ScanBlocks`); a switch user scans group by group, then left to right.
- Alerts: websites cannot notify through Grid 3. Use `templates/alert.js` (`Include = @('alert.js')`) for alerts
  while the site is open; for alerts anywhere, the service must email or text the user (Grid 3 alerts for those).
- A cell's script function must answer at once. Grid 3 does not wait for promises, so Speak reads the return
  value before any async work finishes. Cache what Speak needs.
