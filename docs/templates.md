# Site grid sets from Smartbox templates

`tools/build-site.ps1` builds a grid set for a website from one of Smartbox's own stock grid sets, so a
new site gets the same layout, cells, keyboards and styles that Smartbox ships. Built 2026-11-05. The
builds and the page scripts are tested by script. **Grid 3 has not yet run a built set.**

## Templates

| Template | Stock source (on this machine) | For | Example site |
|---|---|---|---|
| `templates/messaging.psd1` | `Accessible Apps\WhatsApp.gridset` v1.103 | Chat and messaging sites | `sites/muse` |
| `templates/media.psd1` | `Accessible Apps\YouTube.gridset` v3.98 | Video and content sites | `sites/youtube-test` |

Each template names its stock file, the stock grid and commandid prefixes, the Start grid, the logo cell,
and its contract: the stock commandids a site's page script can answer.

## How a build works

1. Copy the stock set. Rename its grids (`WhatsApp - Home` becomes `Muse - Home`) and give each a new GridGuid.
2. Rewrite every command. A stock commandid (`WhatsApp/Home/Next_Message`) becomes the site's
   (`Muse/Home/Next_Message`). Stock URLs become the site's URL. Jumps follow the renamed grids.
3. Remove each cell that needs a commandid the site's `page.js` does not answer. A commandid in the site's
   `Ignore` list is removed on its own, and the rest of that cell stays (for WhatsApp's housekeeping calls).
4. Remove the cells in the site's `Blank` list, then add or replace the site's own `Cells`.
5. Drop every grid that no cell can reach from the Start grid.
6. Put the site's logo on the Start grid and as the thumbnail. Drop WhatsApp's background art and
   Smartbox's documentation and versioning ids.
7. Apply the site's `Edits` (change a stock cell, keep its look) and `ScanBlocks` (switch scan groups).
8. Give each script cell a short call, like WhatsApp's buttons: `Muse/Home/Next_Message` calls
   `GridCommands.Muse.Home.Next_Message()`. Grid 3 3.0.93 never runs a grid set's `code.js`, so each grid with
   script cells gets one loader in its on-open commands that runs `page.js` and keeps it in the site's
   `localStorage`; a call reloads it from there after a page reload. `SpeakJavascriptFunction` speaks what
   the function returns. `code.js` is still shipped. Details:
   [grid3-internals.md](grid3-internals.md#page-scripts-in-commandids-grid-3-3093-read-2026-11-06).

The build prints the cells it removed, so the gaps against the stock set are visible.

## New-item alerts

Grid 3 cannot show a website's own notifications (see
[grid3-internals.md](grid3-internals.md#notifications-read-2026-11-06)). For alerts while a site is open, use
the shared piece `templates/alert.js`:

1. In `site.psd1`, add `Include = @('alert.js')`. The builder puts it before `page.js`; the tests load it too.
2. In `page.js`, call `window.grid3Alert?.watch({ text: 'New message from <Site>', newest: () => ... })`.
   `newest` returns the element that marks the newest incoming item (null if none, undefined to skip a check).
   Pick a marker only incoming items have: Muse's replies have a React button, the user's own messages do not.
3. It plays a two-note chime and shows a small orange banner for 8 s when a later marker appears below the
   last one. Older items loading above, a re-render, or a change of page reset the baseline without alerting.
4. Add a test that adds an incoming item and an outgoing one to the mock, as `tests/test-site-scripts.mjs`
   does for Muse.

Seen working in Grid 3 for Muse on 2026-11-06 ("a nice little orange banner at the top and a pleasant
sound"). It only runs while the site's grid set is open. For alerts anywhere in Grid 3, send
the message to the user's email or as a text: Grid 3 alerts for those natively.

## Adding a site

1. Make `sites/<name>/` with `site.psd1`, `page.js` and a 512x512 `logo.png`. Copy the nearest example.
2. In `page.js`, set the hostname check and register functions in a `COMMANDS` table, one per line
   (`'Home/Next_Message': () => ...`). The builder reads the keys from those lines. Every key must be in the
   template's contract or in the site's `Extra` list.
3. Find the site's elements by stable labels: `aria-label`, `role`, `data-testid`. Do not use generated
   class names. Read them from the live page (signed in if needed) and record the date in a comment.
4. Build: `pwsh -NoProfile -File tools\build-site.ps1 -Site <name>`, then check:
   `pwsh -NoProfile -File tools\check-gridset.ps1 -GridSet "grids\<Output>"`.
5. Add the site to `tests/test-site-scripts.mjs` and run it (`cd tests; npm install` once).
6. Check every function on the live site in a signed-in Claude in Chrome tab, and record the page facts in
   `docs/sites/<name>.md` (skill `site-grid`).
7. Put the most used cells in scan group 1 with `ScanBlocks`, so a switch user reaches them first.

`site.psd1` keys: `Name` (grid name prefix), `Template`, `Include` (shared pieces from `templates/`, such as
`alert.js`), `ScriptName` (commandid and `GridCommands` prefix),
`Url`, `Output`, `Logo`, `ThumbnailBackground`, `AutoStart` (run the Start cell's commands when the set
opens), `StartWait` (seconds to wait after opening the site before the loader runs), `Description`, `Ignore`, `Extra`, `Blank` (`'<grid> X,Y'`), `Edits` (change a stock cell and keep its look: `Grid`, `X`, `Y`, and any of `Commands`
to replace its commands, `Prepend`, `Append`, `JumpBack` to turn its Jump.To into Jump.Back, `Span = @(cols, rows)`),
`Imports` (grids from another stock set: `Source`, `Grids` map from source grid to short name, `Send` and `Back`
grid lists, `Return` (the main grid: sub-grid jumps to it become Jump.Back), `DropCommands` patterns; the
replaced grid's workspace cell is kept), `Cells` (each with `Grid`, `X`, `Y`,
`Caption`, `Image`, `Style`, `Commands`).

## The two example sites

- **Muse** (`grids/Muse.gridset`): 10 grids. Home keeps Read msg, Prev and Next msg, Prev and Next chat
  (Muse's side chats), Reply, Type, Emojis and More. It adds Select chat, Chats (opens or closes the chat
  panel) and Muse panel (opens or closes Muse's avatar panel), Read options, and Option 1, 2 and 3 (press
  the clickable items in Muse's newest message and say what was pressed). Prev and Next chat move an outline
  over the chats; Select chat opens the outlined chat and closes the panel, so the messages work again.
  More Tools (More on Home) holds Muse's rail pages (Search, Feed, Ideas, Goals, Library, Settings, Chat)
  and Prev item, Next item, Read item, Open item and Close for the items on the open page. Prev and Next
  item say an item's first line; Read item says all of it. A dialog opened from a search result (such as
  Goal details) becomes the list of items until Close.
  Page facts and the real-page check: [sites/muse.md](sites/muse.md). Removed: Search, Forward, Send GIF, Send photo or video, View media, and the delete, group,
  theme and log-out cells. Messages are found by their Reply buttons, chats by `hatch-thread-row`.
- **YouTube Test** (`grids/YouTube Test.gridset`): 10 grids, only the Trending cells removed. It exists to
  test the media template on a public site. Smartbox ships its own YouTube set.

## Tested so far

- `node tests\test-site-scripts.mjs`: 40/40 on 2026-11-06 (narrow chat list and options added). The live
  YouTube autoplay check fails about 1 run in 3: YouTube sometimes ignores the toggle click. Earlier,
  31/31 earlier that day, including 9 checks that run the built
  `Muse.gridset` commandids the way Grid 3 sends them. 22/22 on 2026-11-05. Muse against `tests/muse-chat-mock.html` (Muse's real
  labels, simplified layout). YouTube Test against live youtube.com, signed out: it moved between results, read
  titles, opened a video, toggled play and turned autoplay off.
- Both built sets pass `check-gridset.ps1` with no problems.
- Seen in Grid 3 2026-11-06 (first build): jump cells worked, script cells did nothing, because Grid 3 never
  runs `code.js`. The rebuild with the script in each commandid is not yet seen in Grid 3.
