---
id: 2026-11-06-public-grids
title: Public web grid sets for Grid 3 (Muse first) and the template for more sites
status: active
opened: 2026-11-06
closed:
---

## Tracker

```yaml
next: {n: 1, do: "Ask Smartbox support about sharing sets derived from their stock sets (questions in docs/online-grids.md)", owner: maintainer}
work:
  - {n: 1, name: smartbox-permission, state: open, owner: maintainer,
     note: "Built grid sets redistribute stock WhatsApp and YouTube material; NOTICE offers removal. Ask Smartbox before wider sharing or Online Grids"}
  - {n: 2, name: online-grids, state: open, owner: maintainer, needs: [1],
     note: "Publish Muse to Smartbox's Online Grids from Grid Explorer (docs/online-grids.md). Agents never publish"}
  - {n: 3, name: email-alerts, state: open, owner: maintainer,
     note: "Alerts outside a site: have the service email or text the user, which Grid 3 alerts for natively. Untested"}
  - {n: 4, name: more-sites, state: open, owner: maintainer,
     note: "Add sites with the messaging or media template (docs/templates.md)"}
  - {n: 6, name: email-keyboard-check, state: done, date: 2026-11-06, owner: maintainer,
     note: "The email-style keyboard is in use in Grid 3 on the user's device and works for them"}
  - {n: 5, name: library-documents, state: open, owner: maintainer,
     note: "Muse Library documents opened in a viewer that stayed on a spinner in Chrome; reading them is untested"}
  - {n: 7, name: headphone-reading, state: open, owner: maintainer,
     note: "Read long text in the audio feedback voice (headphones) so the room does not hear it. templates/headphone.js passes tests/test-headphone.mjs. Import grids/Headphone Test.gridset and press cells 1-4 to hear which device each uses. Then use it for Muse Read msg"}
```

## Status

- 2026-11-08 (later): Added the accessibility-review skill (`tools/evaluate-gridset.ps1`, `tests/site-audit.js`,
  a cited checklist). Muse evaluation: `docs/evaluations/2026-11-08-muse.md`, seven ranked improvements, none
  made yet (PR 21, on dev).

- 2026-11-08: A switch user could not leave the Muse keyboard. Jump.To pushes onto Grid 3's history and
  Jump.Back pops it, so the Tools and Punctuation grids' Jump.To back to the keyboard made its Back loop. The
  builder's Imports now take `Return` (PRs 16 and 17, on main). Not yet checked in Grid 3.

- 2026-11-06 (later, 3): A web page can speak through Grid 3's audio feedback voice (docs/grid3-internals.md,
  "Speaking to the headphones"). Built `grids/Headphone Test.gridset` to hear it on a device. Not yet heard in Grid 3.

- 2026-11-06 (later, 2): The email-style keyboard is in use in Grid 3 on the user's device, and the user is happy with it.

- 2026-11-06 (later): The Muse keyboard now follows the user's email keyboard: imported from Smartbox's stock
  Email set (new builder key `Imports`), plus Fix and fast typing on space as on the user's copy, letters in
  scan group 2. Untested in Grid 3: Fix, Del word and the Tools commands typing into a web page.

- 2026-11-06: Repo published from a private working repo with fresh history. Muse grid set tested in Grid 3
  by its user (messages, chats, options, rail pages, feed reading, search, alert). Branches: `dev` for work,
  `main` by PR only.
