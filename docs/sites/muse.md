# Muse (muse.ai) page facts

What `sites/muse/page.js` relies on. Seen on the signed-in page on 2026-11-06 in the operator's Chrome
(Claude in Chrome tab, 1685 px wide), unless a line says otherwise. Update this file whenever Muse changes.

## Page

| Thing | How to find it | Notes |
|---|---|---|
| Message box | `textarea[aria-label="Message"]` | No Send button while it is empty (seen 2026-11-05) |
| Message list | `[role="log"][aria-label="Chat messages"]` | Scrolls inside a parent element, so Grid 3's `WebBrowser.ScrollDown` does nothing |
| One message | the highest ancestor of a `button[aria-label="Reply"]` that holds only that Reply button | 7 found on the main chat. Each also has `Copy response`, `React`, `More options` |
| Options in a message | plain `button` elements inside the newest message, text such as "Add both" | Muse also writes them in the text ("Option A ...") |
| "Keep chat panel visible" | menu item `[role="menuitemcheckbox"]` in the menu of `[data-testid="hatch-side-chats-options"]` (open it with pointerdown then click) | On: the chat panel is docked open and **no Chats button exists**, so nothing else closes it. It was on in the operator's Chrome on 2026-11-06 |
| Chats button | `[data-testid="hatch-chat-switcher-trigger"]`, text "Chats Open chat and side chats" | Only while "Keep chat panel visible" is off. A click toggles the chat panel |
| Chat panel | `[data-testid="hatch-side-chats-panel-sliding-surface"]` > `nav[aria-label="Side chats"]` | The rows exist only while it is open. With the setting off, the open panel lays a cover over the messages, so clicks and scrolls do not reach them |
| Rail Chat icon | `a[data-testid="hatch-nav-chat"]` (`aria-expanded`) | A script click did not close the docked panel |
| Chat rows | `[data-testid="hatch-thread-row"]`, `role="button"` | 9 rows: Main chat, WhatsApp, then side chats. The current row has `aria-current="page"` |
| Chat row name | first line of the row's text | The WhatsApp row reads "WhatsApp" then "Channel conversation, view only" |
| Avatar panel | open: `[role="button"][aria-label="Muse"]`, close: `[data-testid="hatch-status-panel-close"]` (`aria-label="Close panel"`) | |
| "Work with Muse anywhere" | `button[aria-label="Get the Muse app"]` | page.js hides it |

## Left rail pages (read 2026-11-06, Chrome)

| Page | Rail item | Items page.js moves over | Open does | Never press |
|---|---|---|---|---|
| Chat | `a[data-testid="hatch-nav-chat"]` | (chat cells on Home) | | |
| Search | `button[data-testid="hatch-nav-search"]` | `[data-testid="command-palette-item"]` in the `hatch-quick-search-frame` dialog | opens the chat or page | |
| Feed (`/feed`) | `[data-testid="hatch-nav-system-item-66656564"]` | `[data-testid="hatch-feed-unit"]` cards (23) | presses the card's Discuss button (untested: may start a chat about it) | the card's link leaves Muse |
| Ideas (`/ideas`) | `...-6964656173` | first button in each `[role="listitem"]` (24) | presses the idea (untested: may send it to Muse) | |
| Goals (`/goals`) | `...-676f616c73` | the title button in each row with a `role="checkbox"` "Mark ..." (11) | opens the goal (untested) | the Mark checkbox |
| Library (`/library/...`) | `...-6c696272617279` | the section links (`a[href^="/library"]`: Spaces, Documents, Images, Videos, Podcasts, System files) then `[data-testid="hatch-library-card-motion"]` cards | follows the link or card | |
| Settings | `button[data-testid="hatch-dock-more"]` menu > "Settings Ctrl+," | section buttons in the dialog before "Log out" (General ... Legal info) | shows the section | Log out, Wallet changes |

Reading and sub-pages (checked in Chrome 2026-11-06, later):
- Feed: 24 cards, each headline, time, summary and Discuss. Prev and Next item say the headline. Read item says
  headline, time and the full summary, without button labels. No more cards loaded after a full lap.
- A search result can open a dialog over its page: a goal reminder opened Goal details
  (`/goals/goal_...`). While any dialog other than search or Settings is open, the items are its headings,
  paragraphs and list entries: Goal details, the goal name, its description, Activity, the day, and each
  activity entry. Close used the dialog's Close button.
- A Library card opens through its unlabelled button (a click on the card does nothing). The document opened
  in `hatch-file-editor-dialog` but stayed on a loading spinner for over 10 seconds, with only its file name
  as an item. Escape closed it. Reading Library documents is untested.

The rail item test ids end in the hex of the page name (`66656564` is "feed"). The Settings dialog closes with
its `aria-label="Close"` button; the search dialog closes with Escape. Seen working 2026-11-06 in Chrome:
moving and reading on every page, opening a Library link, a search result and a Settings section, and Close.

Search box: an empty search closes with one Escape on the box (the animation takes over a second). The
keyboard's Back runs `Search/Leave`, which closes an empty search, then Jump.Back returns to More. A typed
search stays open for Next item and Open item. Seen in Chrome 2026-11-06.

Switch scan groups on Home (2026-11-06): group 1 messages (Read msg, Prev msg, Reply, Next msg, Read options,
Type, Emojis, Option 1, Option 2, Option 3), group 2 the chat column, group 3 Fast Talker, Rest and More.
The user mostly stays in Main chat, so messages come first.

New-message alert (2026-11-06): web notifications cannot reach Grid 3 (no WebView2 permission handler in
Grid 3, no push in WebView2). Instead page.js uses `templates/alert.js` and checks the open chat every 1.5 s. When a new Muse reply appears
at the bottom (Muse's replies have a `React` button; the user's own start "You:" and have `Copy response`), it
plays a two-note chime and shows a small orange "New message from Muse" banner for 8 s. Older messages loading
above, or a change of chat, do not alert. Only while the Muse grid set is open. Seen and heard in Grid 3 on
2026-11-06. For alerts outside Muse, Muse would have to email or text the user (Grid 3 alerts
for those natively; untested).

Security policy: muse.ai sends a strict `Content-Security-Policy`. `connect-src` blocks requests to this
machine, so a page script cannot send data out. `eval` inside Grid 3's injected script still works (tested
with the real header on the mock page, 2026-11-06). `X-Frame-Options: SAMEORIGIN` blocks wrapper pages.

## Behaviour of page.js on the real page (2026-11-06, Chrome)

Second check, later that day, after the operator's Grid 3 test (chat panel stuck open, messages not usable):
- Prev and Next chat move an orange outline over the rows and open nothing. Read chat names the outlined row.
- Select chat opened the outlined chat, turned "Keep chat panel visible" off, and closed the panel. The
  messages were uncovered and Prev msg worked.
- Chats opened and closed the panel. With the panel closed, the first Next chat opens it and outlines the
  current chat; that press says nothing.
- Muse panel closed and reopened the avatar panel.
- Afterwards I put back "Keep chat panel visible", Main chat and the open avatar panel.

First check:

- Read msg reads the newest message. Prev msg moves up one and outlines it.
- Read options said "1, Add both. 2, Add only the weekly schedule. 3, Leave the folder as it is."
- Next chat opened the panel, picked the next chat, closed the panel, and Read chat named it. Prev chat went
  back. The page was left on Main chat.
- Not pressed: Option 1, 2 and 3, Send. Each sends a message for the user, which agents must not do.
- Known gap: after a page load the first Next or Prev chat press says nothing, because the chat names are
  unknown until the panel has opened once. Later presses name the chat at once.

## How to check page.js against the real page

1. Use a Claude in Chrome tab signed in to Muse. The operator signs in; agents never enter credentials.
   The built-in browser pane and the `MuseAccessEdge` profile were not signed in on 2026-11-06.
2. Paste `sites/muse/page.js` into the tab with the extension's JavaScript tool, then call
   `GridCommands.Muse.<Section>.<Name>()` and read the results.
3. Read-only: never call Option, Reply plus Send, or anything that types into the message box and sends.
4. Put the user back where they were: their chat, no outline left (`.grid3-selected`).
