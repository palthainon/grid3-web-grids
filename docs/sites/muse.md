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
| New side chat | `button[data-testid="hatch-chat-compose"]` (`aria-label="New side chat"`), after the channel rows and before the side chats | Not a `hatch-thread-row`. A click opens `/thread/new`, closes the panel and focuses the message box. Nothing is made until a message is sent. That page has **no Chats button**, only `button[aria-label="Back to main chat"]`. Seen 2026-11-12, Chrome |
| Approval card | `[data-testid="hatch-inline-approval-card"]`, `role="group"`, `aria-label` such as "Muse needs approval" | Muse asks before some actions, such as sending an email. Chat stays paused until it is answered. Allow: the primary button (`data-hatch-approval-primary-action="true"`) plus a `More allow options` button whose menu holds `[role="menuitem"]` items. Deny: plain buttons ("Deny", "Deny for this task"). Labels come from Muse: "Allow", "Allow once", "Always allow", "Allow for this task", "Allow for this space", "Allow all ... actions". With several approvals the primary button is "Allow always" and "Allow once" is in the menu. Read from Muse's page code 2026-11-12 (no card was waiting, so not seen drawn) |
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
| Settings | `button[data-testid="hatch-dock-more"]` menu > "Settings Ctrl+," | the section buttons, then every control in the open section (see below) | shows the section, or presses the control | see the block list below |

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

Dark mode (2026-11-08): Muse has Light, Dark and System buttons in Settings > General > Appearance > Mode
(`aria-label` Light, Dark, System). System follows `prefers-color-scheme`, and Muse puts the `dark` class on
`<html>` (page background `#181819`). Seen in Chrome 2026-11-08. The grid set's cells use a dark `Theme` to
match. Grid 3's browser on a light Windows theme shows Muse light until a person picks Dark.

Keyboard (2026-11-06): follows the user's email keyboard. It is imported from Smartbox's stock Email set
(`Email message`, `Email message tools`, `Email message punctuation`), with Muse's browser in place of the email
editor, plus Fix (AI spelling correction) at column 7, row 2 and fast typing on the space bar, as on the user's
copy. Scan groups: the letters are one group, scanned key by key, as on the user's email keyboard. Row groups
were tried on 2026-11-08 and reverted at the operator's request. Punctuation keeps one group per key row. Send presses Enter; Back closes an empty search and returns. Clear selects all
and deletes. Tools: Select all, Copy, Paste, Left, Right, Previous and Next word, Start and End of text.
Dropped from the old WhatsApp keyboard: Quick msg and Emojis (Emojis is still on Home). Untested in a web page:
Fix, Del word and the Tools commands (Grid 3 `Action.*` text commands; Del letter already worked).

Switch scan groups on Home (2026-11-06): group 1 messages (Read in headphones, Prev msg, Reply, Next msg, Read options,
Type, Read msg, Option 1, Option 2, Option 3), group 2 the chat column, group 3 Back (opens Fast Talker), Rest and More. More Tools (2026-11-08): group 1 column 0 (Back at
0,0, then the item controls), group 2 the rail pages, group 3 the tools (Grid explorer at 9,5).
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
- `Muse/Home/Read_Selected_Message_Headphones` gives the same text to `templates/headphone.js`, so Grid 3 reads it with
  the audio feedback voice (headphones). Its cell must run `CommandExecution.Wait` (1 s) and `WebBrowser.NextElement`
  after it. In the mock, the hidden click kept the selection and both panels. Home's "Read in headphones" cell (8,0, before Read msg at 9,3)
  carries it. It replaced Emojis, which moved to More Tools in place of Zoom out (2026-11-06). Not tried on muse.ai.
- Read options said "1, Add both. 2, Add only the weekly schedule. 3, Leave the folder as it is."
- Next chat opened the panel, picked the next chat, closed the panel, and Read chat named it. Prev chat went
  back. The page was left on Main chat.
- Not pressed: Option 1, 2 and 3, Send. Each sends a message for the user, which agents must not do.
- Known gap: after a page load the first Next or Prev chat press says nothing, because the chat names are
  unknown until the panel has opened once. Later presses name the chat at once.

## Approvals and New side chat (2026-11-12)

- Superseded 2026-11-12 (later): the "Allow once only" rule. A real email request showed a short card first:
  `[data-testid="hatch-inline-approval-card"][data-hatch-background-approval-surface]`, text "A task needs
  review", one Review button. It sat above the message box. Review opens the full card. The old Grid 3 copy
  missed the card, so Option 1 pressed an email link and Option 2 a message option.
- Now: Read options or an Option cell presses Review first. Then Read options says the request (first 30 words)
  and each button of the full card in order. Option 1 to 3 press button 1 to 3. The operator listed the buttons
  for an email as "Send", "Always allow for this recipient" and "Don't send", and wants Philip to hear and pick
  each one. A "More allow options" menu button counts as "More choices". Once open, its entries take its place.
- Checked: the short card and its Review button found on the signed-in page in Chrome. The permission prompt
  blocked an agent press of Review, so the full card's layout is from the operator's report and the mock.
- A new approval card plays the chime and shows "Muse needs your approval".
- Prev and Next chat outline "New side chat" in its place among the rows. Select chat opens it, and Type then
  writes in it. In the new chat, Chats presses "Back to main chat" and then opens the panel.
- Checked: New side chat, Select chat and Chats on the signed-in page in Chrome 2026-11-12. The approval cells
  passed against the mock only. They are untested on a real approval card, and untested in Grid 3.

## Read options in the headphones (2026-11-12)

Home's Read options cell runs `Muse/Options/Read_Headphones`, a 1 s wait and `WebBrowser.NextElement`, the same
route as Read in headphones (operator asked for it). The text is the same as `Options/Read`: the message options, or
an approval request and its buttons. Option 1 to 3 still say their result aloud. Not yet heard in Grid 3.

## Prev and Next msg preview (2026-11-12)

Muse draws no time on a message. It puts a time marker in the log before each group of messages: "8:42 AM" for
today, "Nov 11, 7:41 PM" for older days (a `div` holding one `span`). Muse's replies have
`[data-hatch-assistant-message-body]`; the user's messages do not. Read on the signed-in page in Chrome.

After the move, Prev msg and Next msg run `Muse/Home/Preview_Selected_Message_Headphones`, then a 1 s wait and
`WebBrowser.NextElement`, the same route as Read in headphones. Philip hears the sender, the time of the
message's group, and the first 12 words: "Muse, 8:42 AM. Good morning, Philip. ...". The time is the marker
before the message, so a message later in a group says the group's time. Checked on the real page in Chrome
(the text only). Not yet heard in Grid 3.

## Every control, and how the grid reaches it (2026-11-12)

Inventory read on the signed-in page in Chrome 2026-11-12. More's Prev, Next, Read and Open item walk whatever
is on top, in this order. Close shuts a menu (Escape) or the top dialog.

| On top | Items | Seen on the real page |
|---|---|---|
| A menu | its entries | Settings menu (Keyboard shortcuts, Download apps, Report an issue, Settings), message More options (Copy, Share), thread actions (Pin, Rename, Archive), Side chat options (Show archived chats), Avatar options, a permission's Ask or Deny |
| Search | the results | |
| Settings | the 10 sections, then every control in the open section, sub-pages included ("Go back" first) | General: Meta Account, Language, Light, Dark, System, 9 colours. Connectors: Available, Connected, each connector, See all. Permissions: the 4 Ask choices ("Ask for some actions. Before actions that may share your information ..., on"), Connectors, Websites, Spaces, Scheduled tasks, Direct network protocols. Gmail's actions ("Send emails, Ask"). Wallet, Secure store, Messaging channels, Devices, Data controls, Help and support, Legal info |
| Another dialog | its headings, paragraphs, list entries and controls, in page order | Goal details |
| Muse panel | its tabs and the shown tab's entries | Activity (scheduled tasks and the activity list), Approvals (approvals history), Identity (Edit, SOUL, MEMORY) |
| Chat panel | Side chat options, the rows, each row's More thread actions, Channels, Side chats, New side chat | |
| Feed, Ideas, Goals, Library | the page's items, as before | |
| The chat page or a space | the selected message's controls (its options, links, React, Reply, Copy response, More options), then the page's controls | Muse Dashboard, Create a space, Settings, Chats, Attach file, Muse |

Spoken names: a choice says "on" or "off", a pressed button says "selected", a row's More thread actions names
its chat. Text boxes are left out: Type and Search reach the message box and the search box.

Never listed and never pressed: Log out, Reset Muse, Reset approvals to defaults, Reset to defaults, Delete,
Remove, Disconnect, Add Link by Stripe, Add Shop Pay, Always allow, Allow always, Allow for ..., Allow all .... In
Settings, also any choice that starts "Allow", so Philip cannot give a connector action standing permission.
Gmail's "Send emails" offers only Ask and Deny (seen 2026-11-12). Close buttons are left out: More has Close,
Home has Muse panel.

A row's More thread actions shows only on hover. A script click opens its menu anyway (seen 2026-11-12). The Muse
panel's tabs sit side by side, so only controls inside the panel's box count. While Muse's avatar reads "Muse,
needs approval" and no card is on screen, Read options opens the Muse panel.

Untested: Rename (it needs typing into a text box the grid does not focus), pressing Settings controls on the
real page (only opening was tried), Open item on Attach file and Create a space. Not yet seen in Grid 3.

## How to check page.js against the real page

1. Use a Claude in Chrome tab signed in to Muse. The operator signs in; agents never enter credentials.
   The built-in browser pane and the `MuseAccessEdge` profile were not signed in on 2026-11-06.
2. Paste `sites/muse/page.js` into the tab with the extension's JavaScript tool, then call
   `GridCommands.Muse.<Section>.<Name>()` and read the results.
3. Read-only: never call Option, Reply plus Send, or anything that types into the message box and sends.
4. Put the user back where they were: their chat, no outline left (`.grid3-selected`).
