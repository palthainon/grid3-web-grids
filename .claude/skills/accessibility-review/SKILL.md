---
name: accessibility-review
description: Evaluate a Grid 3 grid set, and the website it drives, for switch, eye gaze and touch users who read and type. Runs tools/evaluate-gridset.ps1 on a built .gridset and tests/site-audit.js on the live site, then walks a cited checklist and writes a report with ranked improvements. Use when asked to review, audit or improve a grid set's design or accessibility, before publishing a new site grid, or when a user reports a grid is hard to use (stuck, slow to scan, hard to read, too bright).
---

# Accessibility review: grid sets and websites

The review has four parts: automatic grid checks, an automatic site audit, a checklist for a person, and a
report. Most grid design evidence comes from children or from adults without disabilities. So use the
numbers below as starting points, and test with the user (Light et al. 2019, see Sources).

## 1. Automatic grid checks

```powershell
pwsh -NoProfile -File tools\evaluate-gridset.ps1 -GridSet "grids\<Output>" -Out "$env:TEMP\eval.md"
```

- Add `-StepSeconds <s>` to show scan times. Take the value from the user's `UserSettings.xml`
  (`ForwardScanSpeed`). Keep the user's settings and times out of this public repo.
- Severity: **fix** blocks a user (stuck, unreadable). **improve** costs time or causes errors. **check**
  needs a person to look.
- What it checks, and why:

| Check | Rule | Source |
|---|---|---|
| contrast | Caption text at least 4.5:1 on its cell (transparent cells: on the grid background) | WCAG 2.2 1.4.3 |
| exit | Every grid has a way out, and the start grid can be reached again | COGA "Let users go back" |
| back-loop | A sub-grid must return with Jump.Back. Jump.To pushes onto Grid 3's history and Jump.Back pops it, so a Jump.To return makes the main grid's Back loop | Grid 3 `NavigationService` (read 2026-11-08) |
| scan | Group scanning for large grids, no group above 12 cells, a way out within 6 steps | Beukelman & Mirenda via switch scanning summary |
| auditory | Cells with no caption text need an `AudioDescription`. Scan groups have no spoken names | Grid 3 audio descriptions |
| position | A caption keeps one position on every grid (motor planning) | Thistle & Wilkinson 2018 (weak evidence) |
| dead-cell, blank-cell | No caption without a command. No command without a caption, image or description | |
| caption | Captions of 16 characters or fewer | |
| rest | A Rest cell on each grid (eye gaze, and a pause for any user) | Smartbox eye gaze settings |

The scan steps assume group scanning, then cell by cell in reading order. Grid 3's real order depends on
the user's access settings. Read them from the user's `UserSettings.xml` (`GroupScanningAccessMethod`).

## 2. Automatic site audit

Paste `tests/site-audit.js` into a signed-in Claude in Chrome tab with the JavaScript tool. It clicks
nothing and returns counts and test ids only, never page text. Read:

- `withoutName`: controls with no accessible name (WCAG 4.1.2). A page script cannot find these by label.
- `under24px`: controls smaller than 24 by 24 px (WCAG 2.5.8). A grid cell replaces most of these.
- `stableHooks`: the share of controls with `data-testid` or `aria-label`. Below about 50%, page scripts
  must use fragile selectors. Prefer role plus accessible name, then test ids (Playwright best practices).
- `liveRegions`: a chat needs `role="log"` so new messages can be found and read.
- `darkMode`: the site has dark rules. Use the site's own dark mode before you restyle it.

## 3. Checklist for a person

Mark each item seen, not seen, or untested. Ask the operator or the user for the items that need the device.

**Getting around**
- [ ] The user can leave every grid in two or three presses, and Back always goes to the grid they came from.
- [ ] Back is in the same cell on every grid. No cell that leaves the grid set (Grid explorer, another set)
      sits where Back sits on other grids.
- [ ] Navigation is shallow. Common tasks take one jump from Home.
- [ ] Every page or test grid set has an exit, including grids that only a tester sees.

**Switch scanning**
- [ ] The most used cells are in the first scan group, top left (Tufts Interactive Communicator, Nomon).
- [ ] Large grids are split into groups (rows, or blocks of related cells). A long single group wastes time.
- [ ] The scan highlight is clearly visible on every cell colour, at least 3:1 against the cell (WCAG 1.4.11).
- [ ] With auditory scanning, every cell and group says something useful. A private cue voice in
      headphones is best (ACE Centre).
- [ ] The user's settings skip empty cells, limit scan loops, and filter repeat presses (Smartbox).

**Eye gaze and touch**
- [ ] Each grid has a Rest cell. Targets are large and well spaced. Dwell time is set with the user.

**Reading**
- [ ] Text contrast at least 4.5:1. Borders and states at least 3:1.
- [ ] The screen is comfortable: offer a dark theme that matches the site's dark mode (expert opinion, no
      study found).
- [ ] Short captions in the user's words. Text-first labels suit literate adults.
- [ ] The keyboard matches the keyboard the user already knows (QWERTY for literate adults, Petroi 2014,
      small study).
- [ ] Colour coding, if any, follows one scheme everywhere.

**The website**
- [ ] Controls the grid needs have stable hooks (`data-testid`, `aria-label`, role).
- [ ] Nothing the grid needs moves or times out unexpectedly (COGA).
- [ ] The page keeps state between visits (pinned panels, themes). Test both states.
- [ ] Keep a never-press list (Send, Log out, purchases, account changes) in `docs/sites/<site>.md`.

**Function**
- [ ] Each script cell answers at once. Grid 3 does not wait for promises.
- [ ] The grid set works on a fresh install (no saved script yet, a slow first page load).
- [ ] Alerts: websites cannot notify through Grid 3. `templates/alert.js` covers the time the site is open.

## 4. Report

Write `docs/evaluations/<YYYY-MM-DD>-<site>.md`:

1. What was evaluated: the build (commit), the date, and how (tool runs, live page, device).
2. The tool output: findings by severity, and the scan table.
3. Ranked improvements. For each one: the finding, the change, the gain for the user, the risk, and whether
   it needs the user to try it first. Put changes to a layout the user already knows last, and test them
   with the user.
4. What was not tested.

Keep the user's name, settings, messages and screenshots out of the public report. Put user-specific
findings in the private repo's ticket.

## Lessons from Muse (2026-11)

- A Back loop trapped a switch user in the keyboard. An imported sub-grid returned with Jump.To. The
  `back-loop` check finds it.
- Most used first: the user scans messages more than chats, so messages are group 1 on Home.
- Scan order must match the visual order. Options 1, 2, 3 scanned as 1, 3, 2 until the layout was fixed.
- One toggle cell beats an Open and Close pair. A select step (outline, then Select) works for lists.
- Leaving the keyboard should undo what opening it did (an empty search box closes on Back).
- The user wanted the keyboard they already use (their email keyboard). Familiar beats new.
- A bright screen tired the user. The dark theme gave every caption at least 5.4:1 contrast.
- Web notifications cannot reach Grid 3. A chime and banner in the page work while the site is open.

## Sources

- WCAG 2.2: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html,
  https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html,
  https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- W3C COGA, Making Content Usable: https://www.w3.org/TR/coga-usable/
- ARIA log role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- Stable selectors: https://playwright.dev/docs/best-practices
- Smartbox switch scanning: https://hub.thinksmartbox.com/knowledgebase/using-switch-scanning-with-grid-3/
- Smartbox eye gaze settings: https://hub.thinksmartbox.com/knowledgebase/eye-gaze-settings-in-grid-3/
- Light et al. 2019, AAC display design, state of the science: https://pmc.ncbi.nlm.nih.gov/articles/PMC6436972
- Light & McNaughton 2014, communicative competence: https://informahealthcare.com/doi/full/10.3109/07434618.2014.885080
- Thistle & Wilkinson 2018, consistent location: https://pubs.asha.org/doi/10.1044/2018_AJSLP-17-0129
- Switch access scanning summary: https://en.wikipedia.org/wiki/Switch_access_scanning
- Scan order and spelling grids (Nomon): https://arxiv.org/pdf/2204.01619
- Auditory scanning with a cue voice (ACE Centre): https://docs.acecentre.org.uk/products/echo/auditory-scanning
- Eye gaze dwell and target size (non-AAC users): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7880147/
