# Guide for AI agents

You are helping someone build or fix a Grid 3 grid set for a website. Grid 3 is how many people with
disabilities communicate, so be careful and test before you hand anything over.

## Read first

1. [docs/grid3-internals.md](docs/grid3-internals.md): what Grid 3 can and cannot do, with exact command IDs.
2. [docs/templates.md](docs/templates.md): how `tools/build-site.ps1` builds a site from a stock set.
3. [.claude/skills/site-grid/SKILL.md](.claude/skills/site-grid/SKILL.md): the build, test and live-check loop.
   [.claude/skills/grid3-press/SKILL.md](.claude/skills/grid3-press/SKILL.md): press Grid 3 cells yourself on a test machine.
   `tools/evaluate-gridset.ps1` and `tests/site-audit.js`: evaluate a grid set and its site for access and readability.
4. `docs/sites/<site>.md` for the site you are changing.

## Workflow

- `main` is the published branch: what users download and what goes on their devices. It takes changes only
  by pull request from `dev`. Branch protection blocks direct pushes to `main`; that the PR comes from `dev`
  is our rule.
- `dev` is where work starts. Make a feature branch from `dev` (in a git worktree under `.claude/worktrees/`),
  open a PR into `dev`, and squash-merge it when the build, `check-gridset.ps1` and the tests pass.
- To publish: open a PR from `dev` to `main` that says what changed for users and what was checked in Grid 3.
  Squash-merge it. Then merge `main` back into `dev` and push `dev`
  (`git checkout dev; git pull; git merge origin/main; git push`), so the next publish PR shows only new work.
  Then users pull `main` and reimport the `.gridset`.
- Rebuild `grids/*.gridset` in the same PR as any change to `sites/`, `templates/` or `tools/build-site.ps1`.
- Track each work stream in `tickets/` (one file per stream). Tickets here are public: no personal details.

## Rules

- Never change the user's startup grid set (often Fast Talker) except through Grid 3's Edit mode, by a person.
- Never copy files into Grid 3's `Grid Sets` folder. Import through Grid Explorer.
- Never send messages, buy, or connect accounts for the user. Check page scripts read-only. Never press Send,
  option buttons, Log out, or anything that changes the account.
- Never enter passwords. A person signs in.
- Keep private page text (chats, names, goals) out of the repo, the tests and the mock pages.
- Record what you saw, with the date. Mark anything untested as untested.

## Grid 3 traps that cost us hours

- Grid 3 3.0.93 never runs a grid set's `Settings0/WebBrowser/code.js`. Load the page script from a grid's
  on-open commands and keep it in localStorage. The builder does this.
- The stock Start cell jumps before it navigates. Wait for the site to load (`CommandExecution.Wait`) before
  the script loads, or a fresh install does nothing.
- Computer use cannot press Grid 3 cells: Grid 3 has `uiAccess`, so Windows blocks the input. Hover outlines
  are not presses. On a test machine, use the `grid3-press` skill: a person installs `tools/grid3-click.ps1`
  once as administrator, then an agent presses cells itself. Test page scripts on the live site in a
  signed-in browser tab.
- When a cell does nothing, read Grid 3's log first:
  `C:\Users\Public\Documents\Sensory Software\Diagnostic Logs\Grid 3.log`.
- A program that a Run cell starts must live where Grid 3 can see it: `%ProgramData%` (`%ALLUSERSAPPDATA%`).
  From the Claude desktop app, writes to `%APPDATA%` go to a private copy, and Grid 3 cannot find the file.
- Grid 3's device volume cells (`ComputerControl.DeviceVolume`) change only the Windows default playback device.
  For a named device, use `tools/device-volume.cs` (Headphone Test > Volume).
- Websites cannot raise notifications in Grid 3. Use `templates/alert.js` while the site is open.
- Sites keep UI state between visits (Muse's "Keep chat panel visible"). Model each state in the mock page.
