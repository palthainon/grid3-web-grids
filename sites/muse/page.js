// Muse page script for the messaging template. The builder puts it in every script commandid.
// A cell's WebBrowser.ExecuteJavaScript commandid "Muse/Home/Next_Message" runs GridCommands.Muse.Home.Next_Message().
// SpeakJavascriptFunction speaks the string a function returns. Labels read from the signed-in page 2026-11-05,
// and every function checked on the signed-in page in Chrome 2026-11-06 (docs/sites/muse.md).
(() => {
  'use strict';
  if (!/(^|\.)muse\.ai$/.test(location.hostname)) return;

  const visible = (el) => !!el && el.getClientRects().length > 0;
  const all = (sel, root = document) => [...root.querySelectorAll(sel)].filter(visible);
  const label = (el) => (el.getAttribute('aria-label') || el.textContent || '').trim();
  const clean = (text) => text.replace(/\s+/g, ' ').trim();
  const SELECTED = 'grid3-selected';

  // Each message has one Reply button. Its message is the highest ancestor that holds only that Reply button.
  function messages() {
    const log = document.querySelector('[role="log"][aria-label="Chat messages"]');
    if (!log) return [];
    return [...log.querySelectorAll('button[aria-label="Reply"]')].map((reply) => {
      let box = reply;
      while (box.parentElement && box.parentElement !== log && box.parentElement.querySelectorAll('button[aria-label="Reply"]').length === 1) box = box.parentElement;
      return box;
    });
  }

  function selectedIndex(list) {
    return list.findIndex((m) => m.classList.contains(SELECTED));
  }

  function select(list, index) {
    list.forEach((m) => m.classList.remove(SELECTED));
    const target = list[Math.max(0, Math.min(index, list.length - 1))];
    if (!target) return null;
    target.classList.add(SELECTED);
    target.scrollIntoView({ block: 'center' });
    return target;
  }

  function current() {
    const list = messages();
    const i = selectedIndex(list);
    return i >= 0 ? list[i] : select(list, list.length - 1);
  }

  // Prev and Next msg say who sent the message, when, and its first words. Muse draws no time on a message. It
  // puts a time marker ("8:42 AM", or "Nov 11, 7:41 PM" on older days) in the log before each group of messages,
  // and Muse's own replies have [data-hatch-assistant-message-body]. Read on the signed-in page 2026-11-12.
  const TIME_MARK = /^([A-Z][a-z]{2} \d{1,2}, )?\d{1,2}:\d{2} [AP]M$/;
  function sentAt(message) {
    const log = message.closest('[role="log"]');
    let row = message;
    while (row.parentElement && row.parentElement !== log) row = row.parentElement;
    for (let e = row.previousElementSibling; e; e = e.previousElementSibling) {
      const text = clean(e.innerText || '');
      if (TIME_MARK.test(text)) return text;
    }
    return '';
  }
  function preview(message) {
    if (!message) return 'No message';
    const sender = message.querySelector('[data-hatch-assistant-message-body]') ? 'Muse' : 'You';
    const words = clean(message.innerText || '').replace(/^(You|Muse):\s*/, '').split(' ');
    const start = words.slice(0, 12).join(' ') + (words.length > 12 ? ' ...' : '');
    return [sender, sentAt(message)].filter(Boolean).join(', ') + '. ' + start;
  }

  function messageBox() {
    return document.querySelector('textarea[aria-label="Message"]');
  }

  // Side chats live in a panel (docs/sites/muse.md). With Muse's "Keep chat panel visible" on, the panel is
  // docked and no Chats button exists. With it off, the Chats button toggles the panel, the rows appear a
  // moment after the click, and the open panel covers the messages. Prev and Next chat move an outline over
  // the rows. Select chat opens the outlined chat and closes the panel, so the messages can be used again.
  const chat = { index: -1, name: '' };
  const CHAT_MARK = 'grid3-chat';
  const trigger = () => all('[data-testid="hatch-chat-switcher-trigger"]')[0];
  // The rows, with the "New side chat" button (hatch-chat-compose) in its place before the side chats, so
  // Prev and Next chat can outline it and Select chat can press it.
  const chatRows = () => all('[data-testid="hatch-thread-row"], [data-testid="hatch-chat-compose"]');
  // A new side chat (/thread/new) has no Chats button, only "Back to main chat" (seen 2026-11-12).
  const backToMain = () => all('button[aria-label="Back to main chat"]')[0];
  // First line only: the WhatsApp row reads "WhatsApp" then "Channel conversation, view only".
  const rowName = (row) => clean((row.innerText || label(row)).split('\n')[0]);
  const later = (ms) => new Promise((done) => setTimeout(done, ms));
  async function waitFor(test, ms = 3000) {
    for (const end = Date.now() + ms; Date.now() < end; await later(50)) { const v = test(); if (v) return v; }
    return null;
  }

  // Opens the panel if needed. Returns the rows, or [] if they never appear.
  async function openChats() {
    if (chatRows().length) return chatRows();
    if (!trigger() && backToMain()) { backToMain().click(); await waitFor(() => trigger()); }
    if (!trigger()) return [];
    trigger().click();
    return (await waitFor(() => chatRows().length && chatRows())) || [];
  }

  // Closes the panel. A docked panel cannot close, so "Keep chat panel visible" is turned off first.
  async function closeChats() {
    if (!chatRows().length) return;
    if (!trigger()) {
      const options = document.querySelector('[data-testid="hatch-side-chats-options"]');
      if (!options) return;
      options.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
      options.click();
      const keep = await waitFor(() => all('[role="menuitemcheckbox"]').find((m) => /Keep chat panel visible/i.test(m.innerText)));
      if (!keep) return;
      if (keep.getAttribute('aria-checked') === 'true') keep.click();
      await waitFor(() => trigger());
    }
    if (chatRows().length && trigger()) trigger().click();
  }

  function markChat(rows, index) {
    rows.forEach((r) => r.classList.remove(CHAT_MARK));
    chat.index = (index + rows.length) % rows.length;
    const row = rows[chat.index];
    row.classList.add(CHAT_MARK);
    row.scrollIntoView({ block: 'nearest' });
    chat.name = rowName(row);
  }

  // Moves the outline. If the panel was closed, the first press opens it and outlines the current chat.
  function moveChat(step) {
    const rows = chatRows();
    if (rows.length) {
      const marked = rows.findIndex((r) => r.classList.contains(CHAT_MARK));
      const start = marked >= 0 ? marked : Math.max(0, rows.findIndex((r) => r.getAttribute('aria-current') === 'page'));
      markChat(rows, marked >= 0 ? start + step : start + (step > 0 ? 1 : -1));
      return;
    }
    chat.name = '';
    openChats().then((opened) => {
      if (opened.length) markChat(opened, Math.max(0, opened.findIndex((r) => r.getAttribute('aria-current') === 'page')));
    });
  }

  // Opens the outlined chat (or keeps the current one), closes the panel and returns the chat's name.
  function selectChat() {
    const rows = chatRows();
    const row = rows.find((r) => r.classList.contains(CHAT_MARK));
    if (!rows.length) return 'Chat list closed';
    rows.forEach((r) => r.classList.remove(CHAT_MARK));
    const name = row ? rowName(row) : chat.name;
    if (row && row.getAttribute('aria-current') !== 'page') row.click();
    messages().forEach((m) => m.classList.remove(SELECTED));
    setTimeout(() => closeChats(), 400);
    return name || 'Chat selected';
  }

  function toggleChats() {
    if (chatRows().length) closeChats(); else openChats();
  }

  // Muse's avatar panel: closes with its Close panel button, opens from the avatar.
  function togglePanel() {
    const close = all('[data-testid="hatch-status-panel-close"]')[0];
    if (close) close.click(); else all('[role="button"][aria-label="Muse"]')[0]?.click();
  }

  // Places: the pages on Muse's left rail, and Prev, Next, Read, Open and Close for the items on them.
  // Read from the signed-in page 2026-11-06 (docs/sites/muse.md). Never press Log out, a goal's Mark
  // checkbox, or anything that sends: items are only outlined until Open.
  const ITEM_MARK = 'grid3-item';
  const item = { name: '' };
  const firstLine = (el) => clean((el.innerText || label(el)).split('\n')[0]).slice(0, 200);
  const RAIL = {
    Chat: '[data-testid="hatch-nav-chat"]', Search: '[data-testid="hatch-nav-search"]',
    Feed: '[data-testid="hatch-nav-system-item-66656564"]', Ideas: '[data-testid="hatch-nav-system-item-6964656173"]',
    Goals: '[data-testid="hatch-nav-system-item-676f616c73"]', Library: '[data-testid="hatch-nav-system-item-6c696272617279"]',
  };
  // Every control Muse shows can be reached with Prev, Next and Open item (More Tools). The list is whatever is
  // on top: an open menu, the search results, the top dialog (Settings with every section's controls), the Muse
  // panel, the chat panel, a rail page's items, or on the chat page the selected message's controls and then the
  // page's own controls. Inventory read on the signed-in page 2026-11-12 (docs/sites/muse.md).
  // Never listed, so never pressed: choices that sign Philip out, wipe data, take payment or give Muse standing
  // permission. Approval cards are answered with the option cells, one time only. In Settings, no choice that
  // starts "Allow" either (a connector action set to Allow runs without asking).
  const BLOCKED = /^(log out|reset muse|reset approvals to defaults|reset to defaults|delete|remove|disconnect|add link by stripe|add shop pay|always allow|allow always|allow for |allow all )/i;
  const SETTINGS_BLOCKED = /^allow\b/i;
  const THREAD_ROW = '[data-testid="hatch-thread-row"]';
  const CONTROL = 'button, [role="button"], a[href], input[type="radio"], input[type="checkbox"], [role="switch"], [role="checkbox"], ' +
    '[role="radio"], [role="tab"], [role="menuitem"], [role="menuitemcheckbox"], [role="menuitemradio"], [role="option"], select';
  const isToggle = (el) => el.matches('input, [role="switch"], [role="checkbox"], [role="radio"], [role="menuitemcheckbox"], [role="menuitemradio"]');

  // A control's spoken name: its label, plus on or off for a switch or choice, or "selected" for a pressed button.
  function controlName(el) {
    let text = clean(el.getAttribute('aria-label') || '') || firstLine(el);
    if (el.matches('input') || !text) {
      const holder = el.labels?.[0] || el.closest('label') || el.parentElement;
      text = clean(el.getAttribute('aria-label') || '') || clean((holder?.innerText || '').split('\n').slice(0, 2).join('. '));
    }
    // A chat row's More thread actions (Pin, Rename, Archive) names its chat.
    const row = el.closest(THREAD_ROW);
    if (row && row !== el) text = `${text}, ${rowName(row)}`;
    const on = el.matches('input') ? el.checked : el.getAttribute('aria-checked');
    if (isToggle(el)) return `${text}, ${on === true || on === 'true' ? 'on' : 'off'}`;
    if (el.getAttribute('aria-pressed') === 'true' || el.getAttribute('aria-selected') === 'true') return `${text}, selected`;
    return text;
  }

  // The usable controls under root, without text boxes, blocked choices and Close buttons (More has a Close cell,
  // Home a Muse panel cell). A control inside another stays, such as a chat row's More thread actions, unless it
  // only repeats the outer control's name.
  function controls(root, test = visible) {
    const found = [...root.querySelectorAll(CONTROL)].filter((e) => test(e) && !BLOCKED.test(controlName(e)) && !/^close( panel)?$/i.test(controlName(e)));
    return found.filter((e) => !found.some((o) => o !== e && o.contains(e) && controlName(o) === controlName(e)));
  }

  const openMenu = () => all('[role="menu"]').pop();
  const settingsDialog = () => all('[role="dialog"]').find((d) => [...d.querySelectorAll('button')].some((b) => b.innerText.trim() === 'Log out'));
  const within = (box) => (el) => { const r = el.getBoundingClientRect(), b = box.getBoundingClientRect(); return visible(el) && r.right > b.left && r.left < b.right; };
  const musePanel = () => {
    let box = all('[data-testid="hatch-status-panel-close"]')[0];
    while (box && box.parentElement && !box.querySelector('button[aria-label="Activity"]')) box = box.parentElement;
    return box && box.querySelector('button[aria-label="Activity"]') ? box : null;
  };
  const chatPanel = () => chatRows().length ? document.querySelector('[data-testid="hatch-side-chats-panel-shell"], [data-testid="hatch-side-chats-panel-sliding-surface"]') : null;

  // The selected message (or the newest) and what Muse draws just after it, such as option buttons.
  function messageControls() {
    const list = messages();
    const i = selectedIndex(list) >= 0 ? selectedIndex(list) : list.length - 1;
    const log = document.querySelector('[role="log"][aria-label="Chat messages"]');
    if (!log || i < 0) return [];
    const mine = list[i], next = list[i + 1];
    return controls(log).filter((e) => mine.contains(e) || ((mine.compareDocumentPosition(e) & Node.DOCUMENT_POSITION_FOLLOWING)
      && (!next || (next.compareDocumentPosition(e) & Node.DOCUMENT_POSITION_PRECEDING))));
  }

  function items() {
    const menu = openMenu();
    if (menu) return controls(menu).filter((e) => !(settingsDialog() && SETTINGS_BLOCKED.test(controlName(e))));
    const results = all('[data-testid="command-palette-item"]');
    if (results.length) return results;
    const settings = settingsDialog();
    if (settings) return controls(settings).filter((e) => !SETTINGS_BLOCKED.test(controlName(e)));
    // Any other dialog, such as Goal details: its headings, paragraphs and list entries, and its controls.
    const dialog = all('[role="dialog"]').pop();
    if (dialog) {
      const ctl = controls(dialog);
      const blocks = all('h1, h2, h3, h4, p, li, [role="listitem"]', dialog).filter((e) => clean(e.innerText || '') && !ctl.some((c) => c.contains(e) || e.contains(c)));
      const outer = blocks.filter((e) => !blocks.some((o) => o !== e && o.contains(e)));
      return [...outer, ...ctl].sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1));
    }
    // The Muse panel's tabs sit side by side; only the shown tab is inside the panel.
    const panel = musePanel();
    if (panel) return controls(panel, within(panel));
    // A row's More thread actions button shows only on hover, but a click still opens its menu.
    const side = chatPanel();
    if (side) return controls(side, (e) => visible(e) || visible(e.closest(THREAD_ROW)));
    const path = location.pathname;
    if (path.startsWith('/feed')) return all('[data-testid="hatch-feed-unit"]');
    if (path.startsWith('/ideas')) return all('[role="listitem"]').map((li) => li.querySelector('button')).filter((b) => b && !b.closest('[role="log"]'));
    if (path.startsWith('/goals')) {
      return all('[role="checkbox"]').filter((c) => /^Mark /.test(label(c)))
        .map((c) => [...c.parentElement.parentElement.querySelectorAll('button')].find((b) => b !== c && !b.contains(c) && label(b) !== 'Goal options'))
        .filter(Boolean);
    }
    if (path.startsWith('/library')) return [...all('a[href^="/library"]'), ...all('[data-testid="hatch-library-card-motion"]')];
    // The chat page, a space or any other page: the message's controls, then the page's own controls. The rail
    // pages already have cells on More, so they are left out.
    const rail = Object.values(RAIL).join(', ');
    return [...messageControls(), ...controls(document.body).filter((e) => !e.closest('[role="log"]') && !e.matches(rail))];
  }

  // The whole item, line by line, without its button labels (a feed card: headline, time, summary).
  function readable(el) {
    const buttons = el.matches('button') ? [] : [...el.querySelectorAll('button')].map((b) => clean(b.innerText || ''));
    return (el.innerText || label(el)).split('\n').map(clean).filter((line) => line && !buttons.includes(line)).join('. ').slice(0, 1500);
  }
  const outlined = () => items().find((e) => e.classList.contains(ITEM_MARK));
  const itemName = (el) => (el.matches(CONTROL) ? controlName(el) : firstLine(el)) || 'No name';

  function clearItems() { document.querySelectorAll('.' + ITEM_MARK).forEach((e) => e.classList.remove(ITEM_MARK)); item.name = ''; }

  function moveItem(step) {
    const list = items();
    if (!list.length) { item.name = 'No items'; return; }
    const marked = list.findIndex((e) => e.classList.contains(ITEM_MARK));
    const next = marked < 0 ? (step > 0 ? 0 : list.length - 1) : (marked + step + list.length) % list.length;
    list.forEach((e) => e.classList.remove(ITEM_MARK));
    list[next].classList.add(ITEM_MARK);
    list[next].scrollIntoView({ block: 'center' });
    item.name = itemName(list[next]);
  }

  // Opens the outlined item. A feed card opens through its Discuss button, a Library card through its
  // unlabelled button (a click on the card itself does nothing).
  function openItem() {
    const el = items().find((e) => e.classList.contains(ITEM_MARK));
    if (!el) return 'Nothing outlined';
    const name = itemName(el);
    if (BLOCKED.test(name) || (settingsDialog() && SETTINGS_BLOCKED.test(name))) return 'Ask for help with that';
    const buttons = [...el.querySelectorAll('button')];
    const target = buttons.find((b) => b.innerText.trim() === 'Discuss')
      || (el.matches('[data-testid="hatch-library-card-motion"]') && buttons.find((b) => !b.getAttribute('aria-label'))) || el;
    clearItems();
    // Menu buttons (Settings, More options, More thread actions, Avatar options) open on pointerdown.
    if (target.matches('[aria-haspopup], [aria-expanded]')) target.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    target.click();
    return isToggle(target) ? controlName(target) : name;
  }

  const searchBox = () => all('[data-testid="command-palette-search-input"]')[0];
  const escape = (target) => target.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));

  // Closes the top dialog with its Close button (Settings, Goal details), or with Escape (search).
  function closeItem() {
    clearItems();
    const menu = openMenu();
    if (menu) { escape(menu); return; }
    if (searchBox()) { escape(searchBox()); return; }
    const dialog = all('[role="dialog"]').pop();
    const close = dialog && [...dialog.querySelectorAll('button')].find((b) => b.getAttribute('aria-label') === 'Close');
    if (close) { close.click(); return; }
    (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));
  }

  function goTo(place) {
    clearItems();
    document.querySelector(RAIL[place])?.click();
  }

  async function openSettings() {
    clearItems();
    const more = document.querySelector('[data-testid="hatch-dock-more"]');
    if (!more) return;
    more.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    more.click();
    (await waitFor(() => all('[role="menuitem"]').find((m) => /^Settings/.test(m.innerText.trim()))))?.click();
  }

  // Approvals (docs/sites/muse.md). Muse first shows a short card above the message box, "A task needs review"
  // with a Review button ([data-hatch-background-approval-surface], seen 2026-11-12). Review opens the full card.
  // Muse sets the full card's button labels per request, such as "Send", "Always allow for this recipient" and
  // "Don't send" (operator, 2026-11-12). Read options says the request and each button in order; Option 1 to 3
  // press button 1 to 3. A "More allow options" menu button counts as "More choices"; once it is open, its
  // entries take its place in the list.
  const CARD = '[data-testid="hatch-inline-approval-card"]';
  const SUMMARY = '[data-hatch-background-approval-surface]';
  const approvalCard = () => all(CARD).filter((c) => !c.matches(SUMMARY)).pop();
  // The short card can sit behind the message box, so it is found without the visible test.
  const approvalSummary = () => document.querySelector(CARD + SUMMARY);
  // Muse's avatar is labelled "Muse, needs approval" while a request waits that may not be on screen.
  const approvalWaiting = () => !!document.querySelector('[aria-label$=", needs approval"]');
  const textOf = (el) => clean(el.innerText || label(el));
  const NOT_A_CHOICE = /^(review|view and edit message|edit|view|show more|show less|copy)$/i;

  // Only real buttons count. The card's header holds a details toggle (a div with role button, "This task
  // comes from the side chat ... Hide details"), and the preview holds the email (seen 2026-11-12).
  function choices(card) {
    const skip = [...card.querySelectorAll('[data-testid="hatch-approval-request-preview"], [data-testid="approval-panel-header"]')];
    const list = [];
    for (const b of all('button', card)) {
      if (skip.some((s) => s.contains(b)) || !textOf(b) || NOT_A_CHOICE.test(textOf(b))) continue;
      if (label(b) === 'More allow options') {
        const menu = b.getAttribute('aria-expanded') === 'true' && openMenu();
        if (menu) list.push(...all('[role="menuitem"], [role="menuitemradio"]', menu).map((e) => ({ el: e, name: textOf(e) })));
        else list.push({ el: b, name: 'More choices', more: true });
        continue;
      }
      list.push({ el: b, name: textOf(b) });
    }
    return list;
  }

  // The request (an email's recipient, subject and text), without the card's button labels.
  function requestText(card) {
    const parts = [];
    const walk = document.createTreeWalker(card, NodeFilter.SHOW_TEXT);
    for (let n; (n = walk.nextNode());) if (!n.parentElement.closest('button, [role="button"]') && clean(n.textContent)) parts.push(clean(n.textContent));
    return parts.join(' ').slice(0, 1500) || 'No request text';
  }

  function openReview() {
    const review = approvalSummary()?.querySelector('button');
    if (!review) return false;
    review.click();
    return true;
  }

  function readApproval(card) {
    const words = requestText(card).split(' ');
    const request = words.slice(0, 30).join(' ').replace(/[.\s]+$/, '') + (words.length > 30 ? ' ...' : '.');
    const list = choices(card).map((c, i) => `${i + 1}, ${c.name}.`).join(' ');
    return `${card.getAttribute('aria-label') || 'Muse needs approval'}. ${request} ${list || 'No choices found. Ask for help.'}`;
  }

  function chooseApproval(card, n) {
    const choice = choices(card)[n - 1];
    if (!choice) return `No choice ${n}`;
    if (choice.more) { choice.el.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true })); choice.el.click(); return 'More choices. Press Read options.'; }
    choice.el.click();
    return choice.name;
  }

  // Options: clickable items in the newest Muse message (or just after it), other than the message toolbar.
  const TOOLBAR = new Set(['Reply', 'Copy response', 'React', 'More options']);
  function options() {
    const log = document.querySelector('[role="log"][aria-label="Chat messages"]');
    if (!log) return [];
    const found = all('button, a[href], [role="button"], [role="link"]', log)
      .filter((e) => !TOOLBAR.has(e.getAttribute('aria-label') || '') && clean(e.innerText || label(e)));
    const list = messages();
    for (const message of list.slice(-2).reverse()) {
      const mine = found.filter((e) => message.contains(e) || (message.compareDocumentPosition(e) & Node.DOCUMENT_POSITION_FOLLOWING));
      const outer = mine.filter((e) => !mine.some((o) => o !== e && o.contains(e)));
      if (outer.length) return outer;
    }
    return [];
  }
  function readOptions() {
    const card = approvalCard();
    if (card) return readApproval(card);
    if (openReview()) return 'A task needs review. Opening it. Press Read options again.';
    if (approvalWaiting() && !musePanel()) { togglePanel(); return 'Muse needs approval. The Muse panel is open. Press Read options again.'; }
    const list = options().map((o, i) => `${i + 1}, ${clean(o.innerText || label(o))}.`);
    return list.length ? list.join(' ') : 'No options';
  }

  function chooseOption(n) {
    const card = approvalCard();
    if (card) return chooseApproval(card, n);
    if (openReview()) return 'A task needs review. Opening it. Press Read options.';
    const option = options()[n - 1];
    if (!option) return `No option ${n}`;
    const text = clean(option.innerText || label(option));
    option.click();
    return text;
  }

  const COMMANDS = {
    'Home/Focus_Message_Input': () => { messageBox()?.focus(); },
    'Home/Previous_Message': () => { const list = messages(); const i = selectedIndex(list); select(list, i < 0 ? list.length - 1 : i - 1); },
    'Home/Next_Message': () => { const list = messages(); const i = selectedIndex(list); select(list, i < 0 ? list.length - 1 : i + 1); },
    'Home/Read_Selected_Message': () => clean(current()?.innerText || 'No message'),
    // Same text into the headphones (templates/headphone.js); the cell must run WebBrowser.NextElement after it.
    'Home/Read_Selected_Message_Headphones': () => grid3HeadphoneSay(clean(current()?.innerText || 'No message')),
    // Prev and Next msg run this after the move (headphones, then WebBrowser.NextElement, as Read in headphones).
    'Home/Preview_Selected_Message_Headphones': () => grid3HeadphoneSay(preview(current())),
    'Home/Center_Current_Message':() => { current()?.scrollIntoView({ block: 'center' }); },
    'Home/Jump_To_End_Of_Conversation': () => { const list = messages(); select(list, list.length - 1); },
    'Home/Reply_To_Message': () => { current()?.querySelector('button[aria-label="Reply"]')?.click(); },
    'Home/Previous_Chat': () => moveChat(-1),
    'Home/Next_Chat': () => moveChat(1),
    'Home/Read_Selected_Chat_Name': () => chat.name,
    'Chats/Toggle': () => { toggleChats(); },
    'Chats/Select': () => selectChat(),
    'Options/Read': () => readOptions(),
    // Home's Read options cell: the same text into the headphones (templates/headphone.js); the cell runs
    // WebBrowser.NextElement after it (operator, 2026-11-12).
    'Options/Read_Headphones': () => grid3HeadphoneSay(readOptions()),
    'Options/Option_1': () => chooseOption(1),
    'Options/Option_2': () => chooseOption(2),
    'Options/Option_3': () => chooseOption(3),
    'Panel/Toggle': () => { togglePanel(); },
    'Places/Chat': () => { goTo('Chat'); },
    'Places/Search': () => { goTo('Search'); },
    'Places/Feed': () => { goTo('Feed'); },
    'Places/Ideas': () => { goTo('Ideas'); },
    'Places/Goals': () => { goTo('Goals'); },
    'Places/Library': () => { goTo('Library'); },
    'Places/Settings': () => { openSettings(); },
    'Items/Previous': () => moveItem(-1),
    'Items/Next': () => moveItem(1),
    'Items/Read': () => item.name || 'Nothing outlined',
    'Items/Read_All': () => { const el = outlined(); return el ? readable(el) : 'Nothing outlined'; },
    'Items/Open': () => openItem(),
    'Items/Close': () => { closeItem(); },
    // Keyboard Back: an empty search box closes; a typed search stays open for Next item and Open item.
    'Search/Leave': () => { const box = searchBox(); if (box && !box.value.trim()) closeItem(); },
  };

  const root = (window.GridCommands = window.GridCommands || {});
  for (const [path, run] of Object.entries(COMMANDS)) {
    const parts = ['Muse', ...path.split('/')];
    let node = root;
    for (const part of parts.slice(0, -1)) node = node[part] = node[part] || {};
    node[parts[parts.length - 1]] = () => { try { return run(); } catch (e) { return 'Muse command failed'; } };
  }

  // New-message alert (templates/alert.js, included by site.psd1): a chime and a small banner when a new Muse
  // reply appears at the bottom of the open chat. Muse's replies have a React button; the user's own messages
  // start "You:" and have Copy response instead (read 2026-11-06).
  window.grid3Alert?.watch({
    text: 'New message from Muse',
    newest: () => {
      const log = document.querySelector('[role="log"][aria-label="Chat messages"]');
      if (!log) return undefined;
      const reacts = log.querySelectorAll('button[aria-label="React"]');
      return reacts[reacts.length - 1] || null;
    },
  });

  // Approval alert: the same chime and a banner when an approval card appears, also one waiting at page load.
  // Not grid3Alert.watch: that one ignores a new card after the last card is gone. One timer per page (page.js
  // runs again with every cell).
  if (window.grid3Alert && !window.__grid3ApprovalWatch) {
    let last = null;
    window.__grid3ApprovalWatch = setInterval(() => {
      const card = approvalCard() || approvalSummary() || document.querySelector('[aria-label$=", needs approval"]');
      if (card && card !== last) { window.__grid3_alerts = (window.__grid3_alerts || 0) + 1; window.grid3Alert.chime(); window.grid3Alert.banner('Muse needs your approval'); }
      last = card;
    }, 1500);
  }

  // "Get the Muse app" (the "Work with Muse anywhere" prompt) is hidden, so link scanning skips it.
  const css = `button[aria-label="Get the Muse app"]{display:none!important}
    .${SELECTED},.${CHAT_MARK},.${ITEM_MARK}{outline:6px solid #ff8c00!important;outline-offset:4px!important;border-radius:12px}`;
  const addStyle = () => { const s = document.createElement('style'); s.textContent = css; document.head.appendChild(s); };
  if (document.head) addStyle(); else document.addEventListener('DOMContentLoaded', addStyle);
})();
