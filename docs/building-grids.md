# Building and installing grid sets

Two ways: Grid 3's Edit mode, or a build script in `tools/` that writes a `.gridset` to import. Change the
user's own grid sets (their startup set, such as Fast Talker) only in Edit mode, and only when they or their
carer asks. See [grid3-internals.md](grid3-internals.md) for the file format and commands, and
[templates.md](templates.md) for site grid sets.

## By script

1. Change `sites/<site>/page.js` or `site.psd1` (see [templates.md](templates.md)).
2. Build: `pwsh -NoProfile -File toolsuild-site.ps1 -Site muse`. It reads Smartbox's stock grid set from
   the local Grid 3 install, so it runs on a Windows PC with Grid 3.
3. Check: `pwsh -NoProfile -File tools\check-gridset.ps1 -GridSet grids\Muse.gridset`, or
   `& tools\check-gridset.ps1 -Show 'Muse - Home'` to list a grid's cells.
4. Test: `cd tests; npm install` once, then `node tests	est-site-scripts.mjs`.
5. Import: Grid Explorer > Add grid sets > From file, or
   `pwsh -NoProfile -File tools\import-gridset.ps1 -GridSet grids\Muse.gridset -NoBuild`, which opens the file
   with Grid 3 the way a double-click does. Each import adds a new copy ("Muse (2)"), so delete old copies.
   Never copy files into `Grid Sets`: Grid 3's sync undoes it.
6. Test with the user's own access method (switch scanning, not only touch).

## Adding a tile to the user's main grid set

Change the startup grid set only in Grid 3's Edit mode, never by replacing the file. AI agents cannot do this:
Grid 3 blocks their clicks (uiAccess), so a person does it. Back up first (Grid 3's user backup).

Example: Fast Talker's `Social media menu` grid is 10x6 with 2x2 tiles (Facebook, Twitter, WhatsApp,
Instagram, YouTube, Spotify), with an empty 2x2 block at column 8, row 1, right of WhatsApp. WhatsApp's tile
jumps to a grid inside Fast Talker; Muse is its own grid set, so its tile changes grid set.

1. Make sure only one grid set is named exactly `Muse` in Grid Explorer.
2. Open the menu grid. Menu > **Edit grid**.
3. Select an empty cell and make it 2x2 like the other tiles.
4. Add the command for changing grid set (`Settings.ChangeGridSet`) and pick **Muse**.
5. Caption `Muse`. Picture: `sites\muse\logo.png`. Style as the other tiles.
6. Save, leave Edit mode, press the tile, and check it opens Muse.

Muse's Home has a cell (top left) that changes back to the startup grid set. It is set to `Fast Talker` in
`sites/muse/site.psd1`; change `gridsetname` to the user's startup set and rebuild.

## Edit mode basics

From the Smartbox Hub (2022-2024 articles); labels on this device may differ slightly.

- **New grid set:** Menu (three lines, top left) > **Grid Explorer** > **Add grid sets** > **Blank grid set**.
- **New grid:** open the set, Menu > **Edit grid** > blue **Grid Set** tab > **New grid**. It includes a Jump back cell.
- **New cell:** in Edit mode select an empty cell > **Create cell**.
- **Jump cell:** Create cell > **Jumps** > **Jump to** > pick a grid. **Follow Jump** tests it in Edit mode.
- **Manage grids** (Grid Set tab): Jump to, Copy, Rename, Set as home, Delete, Add from another grid set.
- **Styles:** Style tab > **New Style**. Changing a style updates every cell that uses it.

### File types

| File | What it is |
|---|---|
| `.gridset` | A complete grid set, portable to other Grid 3 or Grid for iPad devices |
| `.gridsetx` | A licence-protected grid set that only opens on a licensed device |
| `.grid3user` | A user backup with grid sets, settings and saved user data |

Grid 3 warns when a grid set goes over 50 MB.

## Smartbox documentation

- [Getting started with Grid 3](https://hub.thinksmartbox.com/topic/how-to-use-grid-3/)
- [Edit mode articles](https://hub.thinksmartbox.com/topic/edit-mode-grid-3/)
- [Add and manage grids](https://hub.thinksmartbox.com/knowledgebase/how-do-i-add-and-manage-grids-in-grid-3/)
- [Add a grid set](https://hub.thinksmartbox.com/knowledgebase/how-do-you-add-a-grid-set-in-grid-3/)
- [Make a jump cell](https://hub.thinksmartbox.com/knowledgebase/how-do-i-make-a-cell-that-jumps-to-another-grid-in-grid-3/)
- [Styles](https://hub.thinksmartbox.com/knowledgebase/using-styles-to-change-cell-appearance-and-speed-up-editing-in-grid-3/)
- [Grid Explorer](https://hub.thinksmartbox.com/knowledgebase/grid-explorer-in-grid-3/)
- [Command library](https://hub.thinksmartbox.com/knowledgebase/grid-command-library/)
- [Web browser commands](https://hub.thinksmartbox.com/knowledgebase/grid-command-library-web-browser/)
- [Accessible apps not working](https://hub.thinksmartbox.com/knowledgebase/a-feature-of-a-grid-accessible-app-is-not-working-what-can-i-do/)
