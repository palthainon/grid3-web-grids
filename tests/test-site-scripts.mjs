// Tests each site's page.js the way Grid 3 runs it: injected before the page loads (as
// AddScriptToExecuteOnDocumentCreated does), then called as GridCommands.<commandid with / as .>().
// Muse runs against tests\muse-chat-mock.html served as muse.ai. YouTube Test runs against live youtube.com.
// Setup once: cd tests; npm install. Run: node tests\test-site-scripts.mjs [muse|youtube]
import { chromium } from 'playwright-core';
import { readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const sites = resolve(here, '..', 'sites');
const only = process.argv[2];
// A site's script as the builder joins it: the templates its site.psd1 lists under Include, then page.js.
const siteScript = (site) => {
  const config = readFileSync(join(sites, site, 'site.psd1'), 'utf8');
  const include = [...(config.match(/Include\s*=\s*@\(([^)]*)\)/)?.[1] ?? '').matchAll(/'([^']+)'/g)].map((m) => m[1]);
  return [...include.map((f) => readFileSync(resolve(here, '..', 'templates', f), 'utf8')), readFileSync(join(sites, site, 'page.js'), 'utf8')].join('\n');
};
const results = [];
const check = (name, ok, detail = '') => { results.push(ok); console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` (${detail})` : ''}`); };

// Grid 3's conversion (AccessibleAppsCommandConversionHelper): spaces and hyphens to _, / to ., then ().
const grid3 = (page, commandid) => page.evaluate(`GridCommands.${commandid.replace(/ /g, '_').replace(/-/g, '_').replace(/\//g, '.')}()`);

// The built set's own commandids, run as Grid 3 runs them: CoreWebView2.ExecuteScriptAsync (CDP Runtime.evaluate)
// of the converted string, with no page script injected (Grid 3 3.0.93 never loads code.js).
function builtCommandIds(gridset) {
  const dir = mkdtempSync(join(tmpdir(), 'gridset-'));
  try {
    execFileSync(join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe'), ['-xf', resolve(here, '..', 'grids', gridset), '-C', dir]);
    const ids = {};
    for (const grid of readdirSync(join(dir, 'Grids'))) {
      const xml = readFileSync(join(dir, 'Grids', grid, 'grid.xml'), 'utf8');
      for (const m of xml.matchAll(/<Parameter Key="commandid">([^<]+)<\/Parameter>/g)) {
        const id = m[1].replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&gt;/g, '>').replace(/&lt;/g, '<').replace(/&amp;/g, '&');
        ids[id.slice(id.lastIndexOf(';') + 1).split('.').slice(2).join('/')] = id;
      }
    }
    return ids;
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
const runBuilt = async (page, id) => {
  const cdp = await page.context().newCDPSession(page);
  const script = `GridCommands.${id.replace(/ /g, '_').replace(/-/g, '_').replace(/\//g, '.')}()`;
  const r = await cdp.send('Runtime.evaluate', { expression: script, returnByValue: true });
  await cdp.detach();
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
  return r.result.value;
};

const browser = await chromium.launch({ channel: 'msedge', headless: true });
try {
  if (!only || only === 'muse') {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await context.addInitScript(siteScript('muse'));
    await context.route('https://muse.ai/**', (r) => r.fulfill({ contentType: 'text/html', body: readFileSync(join(here, 'muse-chat-mock.html'), 'utf8') }));
    const page = await context.newPage();
    await page.goto('https://muse.ai/');
    console.log('-- Muse (mock page)');
    check('GridCommands.Muse registered', await page.evaluate(() => typeof GridCommands?.Muse?.Home?.Next_Message === 'function'));
    check('Get the Muse app hidden', !(await page.locator('#getApp').isVisible()));
    check('Read_Selected_Message reads the newest message first', (await grid3(page, 'Muse/Home/Read_Selected_Message')).startsWith('Muse: answer 12'));
    await grid3(page, 'Muse/Home/Previous_Message');
    check('Previous_Message moves up one', (await grid3(page, 'Muse/Home/Read_Selected_Message')) === 'You: question 11');
    await grid3(page, 'Muse/Home/Next_Message');
    const heard = () => page.evaluate(() => { const b = document.querySelectorAll('#grid3-headphone button'); return b.length ? b[b.length - 1]._grid_getHotSpotAuditoryFeedbackText() : ''; });
    await grid3(page, 'Muse/Home/Previous_Message');
    await grid3(page, 'Muse/Home/Preview_Selected_Message_Headphones');
    check('Prev msg preview says sender, time and the start', (await heard()) === 'You, 8:11 AM. question 11', await heard());
    for (let i = 0; i < 10; i++) await grid3(page, 'Muse/Home/Previous_Message');
    await grid3(page, 'Muse/Home/Preview_Selected_Message_Headphones');
    check('Prev msg preview uses an older day marker', (await heard()) === 'You, Nov 11, 7:41 PM. question 1', await heard());
    await grid3(page, 'Muse/Home/Jump_To_End_Of_Conversation');
    await grid3(page, 'Muse/Home/Preview_Selected_Message_Headphones');
    check('Next msg preview of a Muse reply', (await heard()).startsWith('Muse, 8:11 AM. answer 12'), await heard());
    check('Next_Message moves down one', (await grid3(page, 'Muse/Home/Read_Selected_Message')).startsWith('Muse: answer 12'));
    check('selected message is outlined', await page.evaluate(() => document.querySelectorAll('.grid3-selected').length === 1));
    await grid3(page, 'Muse/Home/Previous_Message');
    await grid3(page, 'Muse/Home/Reply_To_Message');
    check('Reply_To_Message presses that message\'s Reply', JSON.stringify(await page.evaluate(() => window.replied)) === '[11]');
    await grid3(page, 'Muse/Home/Jump_To_End_Of_Conversation');
    check('Jump_To_End selects the newest message', (await grid3(page, 'Muse/Home/Read_Selected_Message')).startsWith('Muse: answer 12'));
    await grid3(page, 'Muse/Home/Focus_Message_Input');
    check('Focus_Message_Input focuses the Message box', await page.evaluate(() => document.activeElement?.id === 'box'));
    // Docked panel ("Keep chat panel visible" on): Prev and Next chat only move the outline.
    const rowCount = () => page.evaluate(() => [...document.querySelectorAll('[data-testid="hatch-thread-row"]')].filter((e) => e.getClientRects().length).length);
    const marked = () => page.evaluate(() => [...document.querySelectorAll('.grid3-chat')].map((e) => e.firstChild.textContent));
    await grid3(page, 'Muse/Home/Next_Chat');
    check('Next_Chat outlines the chat after the current one', JSON.stringify(await marked()) === '["Weekly briefing"]' && (await grid3(page, 'Muse/Home/Read_Selected_Chat_Name')) === 'Weekly briefing');
    await grid3(page, 'Muse/Home/Next_Chat');
    check('Read chat names the outlined chat (first line only)', (await grid3(page, 'Muse/Home/Read_Selected_Chat_Name')) === 'Sports roundup');
    await grid3(page, 'Muse/Home/Previous_Chat');
    check('Previous_Chat moves the outline back and opens nothing', JSON.stringify(await marked()) === '["Weekly briefing"]' && JSON.stringify(await page.evaluate(() => window.opened)) === '[]');
    check('Chats/Select opens the outlined chat and says it', (await grid3(page, 'Muse/Chats/Select')) === 'Weekly briefing' && JSON.stringify(await page.evaluate(() => window.opened)) === '["Weekly briefing"]');
    await page.waitForTimeout(1500);
    check('Chats/Select closes a docked panel (turns Keep chat panel visible off)', (await rowCount()) === 0 && await page.locator('#trigger').isVisible() && await page.locator('#cover').count() === 0);
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(600);
    check('Chats/Toggle opens the panel', (await rowCount()) === 3);
    const panelItems = [];
    for (let i = 0; i < 4; i++) { await grid3(page, 'Muse/Items/Next'); panelItems.push(await grid3(page, 'Muse/Items/Read')); }
    check('chat panel: items are its controls, with the hidden More thread actions', JSON.stringify(panelItems) === JSON.stringify(['Side chat options', 'Main chat', 'More thread actions, Main chat', 'Weekly briefing']), JSON.stringify(panelItems));
    await grid3(page, 'Muse/Items/Previous');
    await grid3(page, 'Muse/Items/Open');
    check('chat panel: Open item presses the hidden More thread actions', JSON.stringify(await page.evaluate(() => window.threadActions)) === '["Main chat"]');
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(300);
    check('Chats/Toggle closes it again', (await rowCount()) === 0);
    // New side chat: Prev and Next chat reach the "New side chat" button; Select chat presses it. In the new
    // chat there is no Chats button, so Chats goes back to Main chat first and then opens the panel.
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(600);
    await grid3(page, 'Muse/Home/Previous_Chat');
    await grid3(page, 'Muse/Home/Previous_Chat');
    check('Previous_Chat past Main chat wraps to New side chat', (await grid3(page, 'Muse/Home/Read_Selected_Chat_Name')) === 'New side chat');
    check('Chats/Select presses New side chat and says it', (await grid3(page, 'Muse/Chats/Select')) === 'New side chat' && (await page.evaluate(() => window.opened.at(-1))) === 'New side chat');
    await page.waitForTimeout(600);
    check('the new side chat has no Chats button', !(await page.locator('#trigger').isVisible()) && await page.locator('#backMain').isVisible());
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(800);
    check('Chats/Toggle in a new side chat goes back to Main chat and opens the panel', (await rowCount()) === 3 && await page.locator('[data-testid="hatch-thread-row"][aria-current="page"]').textContent() === 'Main chat');
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(300);
    check('Options/Read lists the newest message options', (await grid3(page, 'Muse/Options/Read')) === '1, Tell me more. 2, Give me a summary. 3, Start over.');
    check('Option_2 presses the second option and says it', (await grid3(page, 'Muse/Options/Option_2')) === 'Give me a summary' && JSON.stringify(await page.evaluate(() => window.chosen)) === '["Give me a summary"]');
    // Approvals: while a card waits, the option cells answer it. Only a one-time allow is ever pressed.
    const decisions = () => page.evaluate(() => window.decisions.splice(0));
    await page.evaluate(() => window.addApproval({ primary: 'Always allow', more: ['Allow for this task', 'Allow once'], deny: ['Deny', 'Deny for this task'] }));
    check('Options/Read with an approval says the request and the choices', (await grid3(page, 'Muse/Options/Read')) === 'Muse needs approval. 1, Allow once. 2, Deny. 3, Read the request.');
    const request = await grid3(page, 'Muse/Options/Option_3');
    check('Option_3 reads the request without button labels', request === 'Send email to Pat. Subject: Lunch. See you at noon.', request);
    check('Option_1 skips Always allow and picks Allow once from the menu', (await grid3(page, 'Muse/Options/Option_1')) === 'Allow once' && await page.waitForTimeout(600).then(decisions) .then((d) => JSON.stringify(d) === '["Allow once"]'));
    await page.evaluate(() => window.addApproval({ primary: 'Allow', more: ['Always allow'] }));
    check('Option_1 presses a plain Allow button', (await grid3(page, 'Muse/Options/Option_1')) === 'Allowed once' && JSON.stringify(await decisions()) === '["Allow"]');
    await page.evaluate(() => window.addApproval({ primary: 'Always allow', more: ['Allow for this task'] }));
    await grid3(page, 'Muse/Options/Option_1');
    await page.waitForTimeout(3500);
    check('Option_1 presses nothing when Muse offers no one-time allow', JSON.stringify(await decisions()) === '[]' && (await page.locator('#grid3-banner').textContent()) === 'No allow once choice. Ask for help.');
    check('Option_2 presses Deny', (await grid3(page, 'Muse/Options/Option_2')) === 'Denied' && JSON.stringify(await decisions()) === '["Deny"]');
    await page.evaluate(() => window.addApproval({ primary: 'Allow' }));
    await page.waitForTimeout(2000);
    check('a new approval card chimes and shows the banner', (await page.locator('#grid3-banner').textContent()) === 'Muse needs your approval');
    await grid3(page, 'Muse/Options/Option_2');
    await decisions();
    check('with no approval, the options are the message options again', (await grid3(page, 'Muse/Options/Read')).startsWith('1, Tell me more.'));
    await grid3(page, 'Muse/Panel/Toggle');
    check('Panel/Toggle opens the avatar panel', await page.locator('#panel').count() === 1);
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(400); // the unpinned panel draws its rows 200 ms after the click
    const rowsBefore = await rowCount();
    const before = await grid3(page, 'Muse/Home/Read_Selected_Message');
    await grid3(page, 'Muse/Home/Read_Selected_Message_Headphones');
    check('Read in headphones gives the selected message to two new hotspot buttons',
      await page.evaluate(() => { const b = document.querySelectorAll('#grid3-headphone button'); return b.length === 2 && b[1]._grid_getHotSpotAuditoryFeedbackText(); }) === before, before);
    const after = { selection: (await grid3(page, 'Muse/Home/Read_Selected_Message')) === before, avatarPanel: await page.locator('#panel').count(), chatRows: await rowCount() };
    check('Read in headphones keeps the selection, the avatar panel and the chat panel open',
      rowsBefore === 3 && after.selection && after.avatarPanel === 1 && after.chatRows === 3, JSON.stringify({ rowsBefore, ...after }));
    await grid3(page, 'Muse/Chats/Toggle');
    await grid3(page, 'Muse/Panel/Toggle');
    check('Panel/Toggle closes it', await page.locator('#panel').count() === 0);
    await context.close();
  }

  if (!only || only === 'built') {
    const ids = builtCommandIds('Muse.gridset');
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await context.route('https://muse.ai/**', (r) => r.fulfill({ contentType: 'text/html', body: readFileSync(join(here, 'muse-chat-mock.html'), 'utf8') }));
    const page = await context.newPage();
    await page.goto('https://muse.ai/');
    console.log('-- Muse.gridset commandids (mock page, no page script injected)');
    check('built set carries every Muse command', ['Home/Read_Selected_Message', 'Home/Previous_Message', 'Home/Next_Message', 'Home/Next_Chat', 'Home/Focus_Message_Input', 'Chats/Select', 'Chats/Toggle', 'Panel/Toggle'].every((k) => ids[k]), Object.keys(ids).join(', '));
    check('commandids hold no space, hyphen or slash', Object.values(ids).every((id) => !/[ \-\/]/.test(id)));
    check('GridCommands absent before the first press', await page.evaluate(() => typeof window.GridCommands === 'undefined'));
    check('cell commandids are short calls; one loader per grid holds the script', Object.entries(ids).every(([k, id]) => k === 'Load' || id.length < 300) && ids['Load']?.length > 3000, `longest call ${Math.max(...Object.entries(ids).filter(([k]) => k !== 'Load').map(([, id]) => id.length))} chars`);
    await runBuilt(page, ids['Load']);
    await runBuilt(page, ids['Load']);
    check('Read msg speaks the newest message', (await runBuilt(page, ids['Home/Read_Selected_Message'])).startsWith('Muse: answer 12'));
    await runBuilt(page, ids['Home/Previous_Message']);
    await runBuilt(page, ids['Home/Previous_Message']);
    check('Prev msg twice keeps its place between presses', (await runBuilt(page, ids['Home/Read_Selected_Message'])) === 'Muse: answer 10');
    check('page script ran once (one style tag)', await page.evaluate(() => [...document.querySelectorAll('style')].filter((s) => s.textContent.includes('grid3-selected')).length === 1));
    // New-message alert: a chime and a small banner for a new Muse reply only.
    const alerts = () => page.evaluate(() => window.__grid3_alerts || 0);
    await page.waitForTimeout(1800);
    check('alert: no alert for the messages already there', (await alerts()) === 0);
    await page.evaluate(() => window.addMessage('You: are you there?'));
    await page.waitForTimeout(1800);
    check('alert: The user’s own message does not alert', (await alerts()) === 0);
    await page.evaluate(() => window.addMessage('Muse: yes, here.'));
    await page.waitForTimeout(1800);
    check('alert: a new Muse reply chimes and shows the banner', (await alerts()) === 1 && await page.locator('#grid3-banner').isVisible() && (await page.locator('#grid3-banner').textContent()) === 'New message from Muse');
    await page.waitForTimeout(1800);
    check('alert: one reply alerts once', (await alerts()) === 1);
    await runBuilt(page, ids['Home/Focus_Message_Input']);
    check('Type focuses the Message box', await page.evaluate(() => document.activeElement?.id === 'box'));
    // "Keep chat panel visible" off: the panel opens behind the Chats button, late, and covers the messages.
    await page.goto('https://muse.ai/?unpinned');
    await runBuilt(page, ids['Load']);
    const rows = () => page.evaluate(() => [...document.querySelectorAll('[data-testid="hatch-thread-row"]')].filter((e) => e.getClientRects().length).length);
    await runBuilt(page, ids['Home/Next_Chat']);
    const first = await runBuilt(page, ids['Home/Read_Selected_Chat_Name']);
    await page.waitForTimeout(800);
    check('unpinned: first Next chat opens the panel and outlines the current chat', (await rows()) === 3 && (await runBuilt(page, ids['Home/Read_Selected_Chat_Name'])) === 'Main chat', `first Read chat said "${first}"`);
    await runBuilt(page, ids['Home/Next_Chat']);
    check('unpinned: Next chat names the next chat at once', (await runBuilt(page, ids['Home/Read_Selected_Chat_Name'])) === 'Weekly briefing');
    check('unpinned: Select chat says it', (await runBuilt(page, ids['Chats/Select'])) === 'Weekly briefing');
    await page.waitForTimeout(1000);
    check('unpinned: Select chat opens it, closes the panel and uncovers the messages', JSON.stringify(await page.evaluate(() => window.opened)) === '["Weekly briefing"]' && (await rows()) === 0 && await page.locator('#cover').count() === 0);
    await runBuilt(page, ids['Chats/Toggle']);
    await page.waitForTimeout(600);
    const openRows = await rows();
    await runBuilt(page, ids['Chats/Toggle']);
    await page.waitForTimeout(300);
    check('unpinned: Chats opens and closes the panel', openRows === 3 && (await rows()) === 0);
    check('Option 1 presses the first option', (await runBuilt(page, ids['Options/Option_1'])) === 'Tell me more');
    // Rail pages and their items (More Tools grid).
    const clicked = () => page.evaluate(() => window.clicked);
    const step = async (id) => { await runBuilt(page, ids[id]); return runBuilt(page, ids['Items/Read']); };
    await runBuilt(page, ids['Places/Feed']);
    check('Feed: Next item reads the first card, again the second', (await step('Items/Next')) === 'Team news' && (await step('Items/Next')) === 'Box office figures');
    check('Feed: Read item says the whole card without its buttons', (await runBuilt(page, ids['Items/Read_All'])) === 'Box office figures. 3m ago. Summary of Box office figures.');
    check('Feed: Open item presses the card\'s Discuss button', (await runBuilt(page, ids['Items/Open'])) === 'Box office figures' && JSON.stringify(await clicked()) === '["Discuss"]');
    await runBuilt(page, ids['Places/Ideas']);
    check('Ideas: Prev item from nothing outlines the last idea', (await step('Items/Previous')) === 'I can plan your evening');
    await runBuilt(page, ids['Places/Goals']);
    check('Goals: items are goal titles, never the Mark checkbox', (await step('Items/Next')) === 'Weekly check-in' && (await step('Items/Next')) === 'Feature tour' && (await step('Items/Next')) === 'Weekly check-in');
    await runBuilt(page, ids['Items/Open']);
    check('Goals: Open item opens Goal details, and its blocks become the items', (await step('Items/Next')) === 'Goal details' && (await step('Items/Next')) === 'Weekly check-in' && (await step('Items/Next')) === 'The user said yes to Weekly check-in.');
    await step('Items/Next'); await step('Items/Next'); await step('Items/Next');
    check('Goals: Read item says a whole activity entry', (await runBuilt(page, ids['Items/Read_All'])) === 'Reminder set. Reminder set for Saturday.');
    await runBuilt(page, ids['Items/Close']);
    check('Goals: Close shuts Goal details', await page.locator('[role="dialog"]').count() === 0);
    await runBuilt(page, ids['Places/Library']);
    check('Library: items are the section links then the cards', (await step('Items/Next')) === 'Spaces' && (await step('Items/Next')) === 'Documents' && (await step('Items/Next')) === 'Card one');
    const before = (await clicked()).length;
    await runBuilt(page, ids['Items/Open']);
    check('Library: Open item presses the card unlabelled button', JSON.stringify((await clicked()).slice(before)) === '[""]');
    await runBuilt(page, ids['Places/Search']);
    check('Search: opens the dialog with the box focused', await page.evaluate(() => document.activeElement?.dataset.testid === 'command-palette-search-input'));
    check('Search: items are the results', (await step('Items/Next')) === 'Main chat' && (await step('Items/Next')) === 'WhatsApp');
    await page.fill('[data-testid="command-palette-search-input"]', 'Team');
    await runBuilt(page, ids['Search/Leave']);
    check('Search: keyboard Back keeps a typed search open', await page.locator('[data-testid="hatch-quick-search-frame"]').count() === 1);
    await runBuilt(page, ids['Items/Close']);
    check('Search: Close shuts the dialog', await page.locator('[data-testid="hatch-quick-search-frame"]').count() === 0);
    await runBuilt(page, ids['Places/Search']);
    await page.fill('[data-testid="command-palette-search-input"]', '');
    await runBuilt(page, ids['Search/Leave']);
    check('Search: keyboard Back closes an empty search', await page.locator('[data-testid="hatch-quick-search-frame"]').count() === 0);
    await runBuilt(page, ids['Places/Settings']);
    await page.waitForTimeout(400);
    const walk = async (n) => { const said = []; for (let i = 0; i < n; i++) said.push(await step('Items/Next')); return said; };
    const settingsSaid = await walk(7);
    check('Settings: items are the sections and every control in the section, never Log out, Reset Muse or Close',
      JSON.stringify(settingsSaid) === JSON.stringify(['General', 'Connectors', 'Light', 'Dark, selected', 'Always ask, on', 'Ask for some actions, off', 'General']), JSON.stringify(settingsSaid));
    await walk(5);
    check('Settings: Open item on a choice turns it on and says so', (await runBuilt(page, ids['Items/Open'])) === 'Ask for some actions, on');
    await runBuilt(page, ids['Items/Close']);
    check('Settings: Close shuts the dialog', await page.locator('[role="dialog"]').count() === 0 && !(await clicked()).includes('Log out'));
    await runBuilt(page, ids['Places/Chat']);
    check('Chat: back to the chat', await page.evaluate(() => location.pathname === '/' && !document.querySelector('main').hidden));
    // Chat page: the newest message's controls (options, Reply, React), then the page's own controls.
    const chatSaid = await walk(6);
    check('Chat: items are the message controls, then the page controls', JSON.stringify(chatSaid) === JSON.stringify(['Tell me more', 'Give me a summary', 'Start over', 'Reply', 'React', 'Settings']), JSON.stringify(chatSaid));
    await runBuilt(page, ids['Items/Open']);
    await page.waitForTimeout(300);
    check('Chat: Open item on the Settings menu button opens the menu, and its entries become the items', (await step('Items/Next')) === 'Keyboard shortcuts');
    await runBuilt(page, ids['Items/Close']);
    check('Chat: Close shuts the menu', await page.locator('[role="menu"]').count() === 0);
    await runBuilt(page, ids['Panel/Toggle']);
    const panelSaid = await walk(3);
    check('Muse panel: items are its tabs and entries, not Close panel', JSON.stringify(panelSaid) === JSON.stringify(['Activity, selected', 'Approvals', 'Send this email in Gmail']), JSON.stringify(panelSaid));
    await runBuilt(page, ids['Panel/Toggle']);
    await page.reload();
    check('after a page load, a cell loads the script from localStorage without the loader', (await runBuilt(page, ids['Home/Read_Selected_Message'])).startsWith('Muse: answer 12'));
    await page.reload();
    await runBuilt(page, ids['Load']);
    check('Read msg works again after a page load', (await runBuilt(page, ids['Home/Read_Selected_Message'])).startsWith('Muse: answer 12'));
    await context.close();
  }

  if (!only || only === 'youtube') {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await context.addInitScript(siteScript('youtube-test'));
    const page = await context.newPage();
    console.log('-- YouTube Test (live youtube.com, signed out)');
    await page.goto('https://www.youtube.com/results?search_query=nature+documentary', { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('ytd-video-renderer a#video-title', { timeout: 20000 });
    check('GridCommands.YouTubeTest registered', await page.evaluate(() => typeof GridCommands?.YouTubeTest?.Home?.Right === 'function'));
    await grid3(page, 'YouTubeTest/Search/PageSetUp');
    const first = await grid3(page, 'YouTubeTest/Generic/Read');
    check('PageSetUp selects the first result and Read speaks its title', first.length > 3, first.slice(0, 60));
    await grid3(page, 'YouTubeTest/Search/Down');
    const second = await grid3(page, 'YouTubeTest/Generic/Read');
    check('Search/Down moves to the next result', second !== first, second.slice(0, 60));
    await grid3(page, 'YouTubeTest/Search/Up');
    check('Search/Up moves back', (await grid3(page, 'YouTubeTest/Generic/Read')) === first);
    await grid3(page, 'YouTubeTest/Generic/Search');
    check('Generic/Search focuses the search box', await page.evaluate(() => document.activeElement?.name === 'search_query'));
    await grid3(page, 'YouTubeTest/Generic/Select');
    await page.waitForURL(/\/watch\?/, { timeout: 20000 });
    check('Generic/Select opens the video', page.url().includes('/watch?'), page.url().slice(0, 60));
    await page.waitForSelector('video', { timeout: 20000 });
    await page.waitForTimeout(3000);
    await grid3(page, 'YouTubeTest/Player/CloseAdsBanners');
    const before = await page.evaluate(() => document.querySelector('video').paused);
    await grid3(page, 'YouTubeTest/Player/PlayPause');
    await page.waitForTimeout(1500);
    const after = await page.evaluate(() => document.querySelector('video').paused);
    check('Player/PlayPause toggles the video', before !== after, `paused ${before} -> ${after}`);
    const autoplayBefore = await page.evaluate(() => document.querySelector('.ytp-autonav-toggle-button')?.getAttribute('aria-checked'));
    await grid3(page, 'YouTubeTest/Player/DisableAutoplay');
    // Live YouTube redraws the toggle late; wait up to 3 s (failed 1 in 2 runs at a fixed 800 ms on 2026-11-06).
    await page.waitForFunction(() => document.querySelector('.ytp-autonav-toggle-button')?.getAttribute('aria-checked') !== 'true', null, { timeout: 3000 }).catch(() => {});
    const autoplayAfter = await page.evaluate(() => document.querySelector('.ytp-autonav-toggle-button')?.getAttribute('aria-checked'));
    check('Player/DisableAutoplay turns autoplay off', autoplayAfter !== 'true', `${autoplayBefore} -> ${autoplayAfter}`);
    await context.close();
  }
} finally {
  await browser.close();
}
const failed = results.filter((ok) => !ok).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
