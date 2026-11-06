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
    await grid3(page, 'Muse/Chats/Toggle');
    await page.waitForTimeout(300);
    check('Chats/Toggle closes it again', (await rowCount()) === 0);
    check('Options/Read lists the newest message options', (await grid3(page, 'Muse/Options/Read')) === '1, Tell me more. 2, Give me a summary. 3, Start over.');
    check('Option_2 presses the second option and says it', (await grid3(page, 'Muse/Options/Option_2')) === 'Give me a summary' && JSON.stringify(await page.evaluate(() => window.chosen)) === '["Give me a summary"]');
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
    check('Settings: items are the sections, never Log out', (await step('Items/Next')) === 'General' && (await step('Items/Next')) === 'Connectors' && (await step('Items/Next')) === 'General');
    await runBuilt(page, ids['Items/Close']);
    check('Settings: Close shuts the dialog', await page.locator('[role="dialog"]').count() === 0 && !(await clicked()).includes('Log out'));
    await runBuilt(page, ids['Places/Chat']);
    check('Chat: back to the chat', await page.evaluate(() => location.pathname === '/' && !document.querySelector('main').hidden));
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
