# Grid 3 internals for grid building

What we have learned about Grid 3 by reading its files and stock grid sets, and observing it, on Windows PCs with Grid 3 3.0.93. Smartbox
does not document most of this, so treat it as observed behaviour of the installed version, not a contract.
Each fact says how it was found and whether it was seen working in Grid 3.

## Installing a grid set

- **Copying a `.gridset` into `Grid Sets` does not hold.** Grid 3's account sync put the old file back when
  it next started (seen 2026-11-05). Install through **Grid Explorer > Add grid sets > From file** (or the
  equivalent import) instead. The operator does this; after import Grid 3 re-saves the file, so its size and
  hash change slightly (46,079 bytes built, 46,228 installed).
- Windows opens `.gridset` with `"Grid 3.exe" "%1"` (file type `SensoryGridSet`), so
  `tools/import-gridset.ps1` starts Grid 3 with the file. On 2026-11-06 a running
  Grid 3 imported it with no prompt, opened it, and showed "Added Muse (3)". **Each such import adds a new
  copy** ("Muse (2)", "Muse (3)"). It does not replace. Delete old copies in Grid Explorer.
- "Grid Sets Installer" in the Start menu is Join-In's installer (`Join-In_Gridsets_Installer.exe`), not Grid 3's.

## Grid file format

A `.gridset` is a zip: `FileMap.xml`, `Settings0/settings.xml` (description, `StartGrid`, `Thumbnail`),
`Settings0/Styles/styles.xml`, and `Grids/<name>/grid.xml` plus media named after the cell (`2-1.png` for
column 2, row 1; the cell's `<Image>` holds just `.png`). `FileMap.xml` lists each grid's extra files.

- Cells omit `X`, `Y`, `ColumnSpan` and `RowSpan` when they are 0 or 1.
- A grid can have grid-level `<Commands>` straight after `RowDefinitions`; they run when the grid opens
  (seen working: Muse - Start loads Muse without pressing Start).
- Grid-level `WebBrowserLinksSource=JavaScriptQuery` and `WebBrowserLinksJavaScriptQuery=<commandid>` set
  what the Links grid lists. Only Smartbox commandids are known to work.
- Commands run in order, and `CommandExecution.Wait` (`waittime`, `cancellable`) pauses between them.

`tools/check-gridset.ps1` checks a built set for cells outside the grid, overlapping cells, jumps to
missing grids and missing FileMap files, and can list a grid's cells and commands.

## Commands and their parameters

Read from `SensorySoftware.Grids.Storage.dll` by reflection (method below), so the keys are exact.

| Command ID | Parameters (default) | Notes |
|---|---|---|
| `WebBrowser.NavigateUrl` | `url` | |
| `WebBrowser.ScrollDown` / `ScrollUp` / `ScrollLeft` / `ScrollRight` | `size` (Medium; Small, Large) | **Did nothing on muse.ai** (seen 2026-11-05). Probably scrolls the document, and Muse scrolls an inner box |
| `WebBrowser.NextElement` / `PreviousElement` / `ActivateElement` | none | Grid's own link cursor |
| `WebBrowser.SpatialNavigateUp` / `Down` / `Left` / `Right` | none | |
| `WebBrowser.NextHeading` / `PreviousHeading`, `ReadingMode` | `indicatorenabled`, `action` | Reading mode shows main text only; it does not speak |
| `WebBrowser.ExecuteJavaScript` | `commandid` only | Runs `"GridCommands." + commandid + "()"` in the page as a script. The commandid can carry the script itself (below) |
| `WebBrowser.SpeakJavascriptFunction` | `commandid` only | Same call; speaks the string the function returns (WhatsApp's Read msg) |
| `ComputerControl.Keyboard` | `keystring`, such as `{ENTER}`, `{ESC}`, `{LEFTCONTROL}a{DELETE}` | Goes to whatever has focus. `{ESC}` did not close Muse's avatar panel |
| `ComputerControl.MoveMouseTo` | `x` (10), `y` (10) | Screen position. Grid 3 is system-DPI-aware, so physical pixels (1920x1080 here). Untested on the device |
| `ComputerControl.MoveMouseBy` | `x`, `y` | |
| `ComputerControl.MouseClick` | `button` (Left; Right) | Clicks where the pointer is |
| `ComputerControl.MouseWheelDown` / `Up` | `indicatorenabled`, `commandtype` (SingleClick; RepeatedClicks, Continuous), `repeatcount`, `repeatgap`, `holdduration` | Scrolls whatever is under the pointer |
| `Speech.SpeakNow` | `text`, `useauditoryvoice` (False), `wait` | Speaks fixed text. `useauditoryvoice` 1 uses the audio feedback voice ("Use audio feedback voice" in the editor) |
| `Speech.ReadCell` | `useauditoryvoice` (False), `wait` | Speaks the pressed cell's own caption |
| `Speech.SpeakClipboard` | none | Speaks the clipboard with the speaking voice. It has no audio feedback option |
| `Email.Speak`, `Sms.Speak` | none | Speak the open message. The code passes `usePrivateVoice` false, so always the speaking voice |
| `Speech.Stop` | none | |
| `Jump.To` | `grid` | Within the grid set. Pushes the grid onto the history stack (`NavigationService.JumpToGrid`) |
| `Jump.Back` | none | Pops the history stack (`NavigationService.JumpBack`). If a sub-grid returns to its main grid with `Jump.To`, the main grid's Jump.Back returns to the sub-grid, and the user loops between them. Return from a sub-grid with `Jump.Back` |
| `Settings.ChangeGridSet` | `gridsetname` | Opens another grid set at its start grid, for example from a startup set such as Fast Talker to Muse. It takes no grid name. `Jump.Back` does not cross grid sets (`NavigationService.JumpBack` checks the set name, read 2026-11-08), so a Back from another set can only open the startup set at its start |
| `Settings.GridExplorer`, `Settings.RestAll` | | |

Full lists, with every command's keys and defaults: load the DLL in PowerShell 7 from Grid 3's program folder,
resolve its other DLLs from the same folder (`AppDomain.AssemblyResolve`), and for every type named
`*CommandDefinition` print `Instance.ID` and each `Instance.ParameterDefinitions` item's `Key` and `DefaultValue`.

### Speaking to the headphones (Grid 3 3.0.104, read 2026-11-06)

Grid 3 has two voices: the speaking voice (Settings > Speech, the main speaker) and the audio feedback voice
(the "private voice", often headphones). `ISpeechService.Speak` takes `usePrivateVoice`. Read from the IL:

- Only `Speech.SpeakNow` and `Speech.ReadCell` let a cell choose the audio feedback voice. Both speak fixed text
  (the parameter, or the cell's caption). Email, SMS, clipboard and `SpeakJavascriptFunction` use the speaking voice.
- **A web page can reach the audio feedback voice.** When `WebBrowser.NextElement`, `PreviousElement` or a
  spatial move changes Grid 3's web hotspot cursor (`MoveElementAsync`), Grid 3 speaks
  `element._grid_getHotSpotAuditoryFeedbackText()` with `usePrivateVoice` true, if the user setting
  `WebBrowserSettings.SpeakLinks` is on (default on).
- A click on the page also moves the cursor (Grid 3's injected script sends `onDomClick`, and the cursor goes to
  the first hotspot in the clicked element's chunk), but **without speech**. Seen 2026-11-06 in Grid 3 3.0.104:
  a click alone was silent.
- `templates/headphone.js` uses both: `grid3HeadphoneSay(text)` adds two 2-pixel buttons in their own
  `data-grid-chunk` box and clicks the first. The cell then waits 1 s and runs `WebBrowser.NextElement`, which
  lands on the second button, whose `_grid_getHotSpotAuditoryFeedbackText` returns the text. New buttons each time,
  because Grid 3 speaks only when the hotspot changes.
- Tested by `node tests	est-headphone.mjs` with Grid 3's own page script, loaded from the local install.
  `grids/Headphone Test.gridset` is the check on a device: each cell says which device it should play on.
  Seen 2026-11-06 on a test machine (3.0.104): `SpeakNow` with and without the audio feedback voice played on the
  right devices. The two-button route is not yet heard. Grid 3 3.0.93 may differ.

### Page scripts in commandids (Grid 3 3.0.93, read 2026-11-06)

Seen 2026-11-06: in the first build of `Muse.gridset`, jump cells (Type, Reply)
worked, and every script cell (Next msg, Read msg, Next chat) did nothing. The reason, read from the IL:

- `Settings0/WebBrowser/webbrowserextensions.xml` can name a code file: `<Code>.js</Code>` means
  `Settings0/WebBrowser/code.js`. Stock sets ship this file with no code.
- `WebBrowserContainer`'s constructor calls `RecreateBrowser` first and reads `code.js` after it.
  `WebView2Wrapper`'s constructor copies the script list at once (`ToArray`), so `code.js` is not in it.
  Only `RecreateBrowser` from the private-browsing setter would pick it up later. **So Grid 3 never runs
  `code.js`.** The builder still ships it, in case a later Grid 3 fixes the order.
- `ExecuteJavaScript` and `SpeakJavascriptFunction` send
  `"GridCommands." + id.Replace(" ", "_").Replace("-", "_").Replace('/', '.') + "()"`
  (`AccessibleAppsCommandConversionHelper.ConvertGridCommandToExecutableScript`) unchanged to
  `CoreWebView2.ExecuteScriptAsync`. Speak speaks the script's result.
- So `tools/build-site.ps1` (since 2026-11-06, evening) does what WhatsApp does: each cell's commandid is a
  short call (about 215 characters), and the page script lives in one place per grid:
  - **Loader:** one `ExecuteJavaScript` in each grid's on-open `<Commands>`. It runs page.js (percent-encoded,
    because a commandid can hold no space, hyphen or slash) once per page and version, and saves it in the
    site's `localStorage` (`grid3_Muse`).
  - **Cell call:** `_;function<TAB>GridCommands(){};window.__grid3_Muse||((0,eval)(localStorage.grid3_Muse||''),...);GridCommands.Muse.Home.Next_Message`.
    If the page was reloaded since the loader ran, it reloads page.js from `localStorage`, then calls the
    function. The hoisted function declaration makes `GridCommands._` safe on a fresh page.
  - Before that change every cell carried all of page.js (about 7 KB). That worked in Grid 3 (seen
    2026-11-06), but made each cell a huge string.
  - **Seen on a second machine 2026-11-06: no script cell worked** with that build, while the operator's
    machine (which had run an earlier build) was fine. Cause: the stock Start cell runs `Jump.To` Home *before*
    `WebBrowser.NavigateUrl`, so Home's loader ran on a blank page, and a fresh profile had nothing saved in
    `localStorage`. Fix: the Start cell (and AutoStart) now ends with `CommandExecution.Wait` (`waittime`
    `00:00:06.0000000`, `cancellable` 1, the format Smartbox's Audible and Facebook sets use) and the loader.
    Site key `StartWait` sets the seconds. Changing grid (More, then Back) also reruns a loader.
- Smartbox's encrypted per-app scripts in `%APPDATA%\Smartbox\Grid 3\AccessibleApps` load only on their
  own sites, so nothing else defines `GridCommands` on muse.ai.

Tested by `node tests\test-site-scripts.mjs built`: the built set's commandids, sent the way Grid 3 sends
them (CDP `Runtime.evaluate`), with no page script injected. **Not yet seen in Grid 3.** Pointer cells
(below) are the fallback.

### Notifications (read 2026-11-06)

- **Websites cannot notify through Grid 3.** Grid 3's browser is WebView2. A site's notification request goes to
  the host app, and Grid 3 has no handler for it, so it is never shown or granted. One user's profile listed
  web.whatsapp.com as blocked. WebView2 has no web push either, so nothing arrives while the page is closed.
- **Grid 3's native alerts come from services it owns:** `EmailConnectorService` (`OnNewMessage`, `Notify`,
  `SetUserNotification`) for the email account set up in Grid 3, and `GridPhoneSmsSyncService`
  (`OnMessageNotification`, `Notify`) for texts through Grid Phone. There is a "Play a notification sound"
  setting. These run in the background whatever grid set is open. Other notification code is for Z-Wave
  devices and Smartbox cloud sync. A grid set has no command or API to raise one of these alerts.
- So: for alerts while a site's grid set is open, use `templates/alert.js` (docs/templates.md). For alerts
  anywhere, have the service send the user an email or a text (Muse can email; it already sends reminders to
  Main chat and WhatsApp). Untested: whether a Muse email reaches Grid 3's alert.

### Switch scanning order (read 2026-11-06)

- The user this was built for uses group scanning with `CellScanningOrder` `SimpleScan` (`UserSettings.xml`). Groups are the
  cells' `ScanBlock` attribute (no attribute = group 1), scanned in number order. Inside a group, SimpleScan
  goes cell by cell in reading order: top row first, left to right. Read from the files; the order was
  confirmed by the operator only as "top down, left to right" in question.
- Each grid has `ScanBlockAudioDescriptions` with entries 1 to 8 and no text. Untested: whether text there
  is spoken as the group's name.
- `tools/build-site.ps1` sets groups from a site's `ScanBlocks` table.

## Stock grid sets as models

The stock sets in `Locale\en-US\gridsets` are the best reference for commands in use. WhatsApp's layout:

- **Home:** Type = focus message input (script) + Jump to keyboard. Read msg = `SpeakJavascriptFunction`.
- **Keyboard:** Send = `{ENTER}` + show chat list (script) + Jump to Home.

`tools/build-site.ps1` builds
whole sets from the stock WhatsApp and YouTube sets instead; see [templates.md](templates.md).

## Working with Grid 3 as an AI agent

### What an agent can and cannot do with Grid 3 (2026-11-06)

- **Computer use cannot press Grid 3 cells.** `Grid 3.exe` has `uiAccess="true"` in its manifest. Windows
  blocks input from normal programs into it: clicks, keys and UI Automation all failed. Grid 3 still draws
  its hover outline under the pointer, which looks like a press but is not. Screenshots work.
- So an agent cannot open a user on Grid 3's Users screen. Do not restart Grid 3: it stops there until a
  person presses Open.
- `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS` set in the launching shell did not reach Grid 3's browser. Windows
  starts uiAccess programs through a service, which uses the saved user environment.
- Grid 3 3.0.93 has a hidden `BrowserDevTools` setting (`appSettings` in its `.config` file, read from
  `WebView2Wrapper.AreDevToolsEnabled`). Untested: it needs a file change under Program Files and a restart.
- What works: test page scripts on the live site in a signed-in Claude in Chrome tab, then let a person press
  the cells in Grid 3. Site facts and the check steps are in `docs/sites/<site>.md`.
- Each Grid 3 user has its own browser profile (`%APPDATA%\Smartbox\Grid 3\WebView2Cache\<user>`). A site
  signed in under one user is not signed in under another.
