# grid3-web-grids

Build accessible [Smartbox Grid 3](https://thinksmartbox.com/grid-3/) grid sets for websites, so someone who
uses Grid 3 with a switch, eye gaze or touch can use a site through big cells instead of a mouse.

The first site is **Muse** (muse.ai, Meta's personal AI agent): read and reply to messages, move between
chats, press the options Muse offers, browse its Feed, Ideas, Goals, Library, Search and Settings, and hear a
chime when Muse replies. It was built for, and tested by, a Grid 3 user on a Grid Pad.

## How it works

- Each site starts from one of Smartbox's own stock grid sets (WhatsApp for chat sites, YouTube for media
  sites), so it keeps Smartbox's layout, keyboards and styles. `tools/build-site.ps1` copies the stock set
  from your Grid 3 install, renames it, and rewires its cells to the new site.
- A small page script (`sites/<site>/page.js`) answers each cell, the way Smartbox's WhatsApp set calls its
  own functions: a cell runs `GridCommands.Muse.Home.Next_Message()` in Grid 3's built-in browser.
- Grid 3 3.0.93 never loads a grid set's own browser script, so the builder loads the page script when each
  grid opens and keeps it in the site's local storage. Details: [docs/grid3-internals.md](docs/grid3-internals.md).

## Use it

- **Ready-made:** import `grids/Muse.gridset` in Grid 3: Grid Explorer > Add grid sets > From file. Sign in
  to muse.ai inside Grid 3's browser. See [docs/sites/muse.md](docs/sites/muse.md) for the cells.
- **Build it yourself** (Windows, Grid 3 installed, PowerShell 7, Node.js for the tests):

  ```powershell
  pwsh -NoProfile -File tools\build-site.ps1 -Site muse
  pwsh -NoProfile -File tools\check-gridset.ps1 -GridSet grids\Muse.gridset
  cd tests; npm install; cd ..
  node tests\test-site-scripts.mjs
  ```

- **Add a site:** [docs/templates.md](docs/templates.md). AI agents: start with [AGENTS.md](AGENTS.md).
- **Contribute:** branch from `dev` and open a pull request into `dev`. `main` is the published branch and
  only takes pull requests from `dev`. Details in [AGENTS.md](AGENTS.md#workflow).

## Docs

| File | What it covers |
|---|---|
| [docs/templates.md](docs/templates.md) | Templates, the builder, site config keys, new-item alerts, adding a site |
| [docs/grid3-internals.md](docs/grid3-internals.md) | What Grid 3 grid sets can do: file format, commands, page scripts, scanning, notifications |
| [docs/building-grids.md](docs/building-grids.md) | Build, check, import, Edit mode, adding a tile to a main grid set |
| [docs/sites/muse.md](docs/sites/muse.md) | Muse page facts the script relies on, and how to re-check them |
| [docs/online-grids.md](docs/online-grids.md) | Publishing to Smartbox's Online Grids library |

## Licence and trademarks

Our code and docs are MIT licensed ([LICENSE](LICENSE)). The built `.gridset` files contain material from
Smartbox's stock grid sets and are not covered by that licence; see [NOTICE](NOTICE). Grid 3 is a product of
Smartbox Assistive Technology. Muse is a product of Meta. This project is not affiliated with either.
