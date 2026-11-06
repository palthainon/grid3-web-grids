// Tests templates/headphone.js the way Grid 3 would use it, without Grid 3 running.
// Loads Grid 3's own page script from the local install (it is not ours, so it is not in the repo), runs the
// built Headphone Test cells as Grid 3 runs commandids, then replays what Grid 3 does with the onDomClick message
// (WebBrowserContainer.OnDomClick, read 2026-11-06): find the chunk, its first hotspot, and the hotspot's text.
// Run: node tests\test-headphone.mjs   (needs Grid 3 installed and pwsh tools\build-headphone-test.ps1 first)
import { chromium } from 'playwright-core';
import { readFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const dll = 'C:\\Program Files (x86)\\Smartbox\\Grid 3\\SensorySoftware.Grids.Grid3.dll';
if (!existsSync(dll)) { console.log('SKIP: Grid 3 is not installed here'); process.exit(0); }
// Grid 3 embeds its page script as UTF-8 text blocks in the DLL.
const grid3Script = (readFileSync(dll).toString('utf8').match(/[\t\n\r\x20-\x7e\u00a0-\uffff]{2000,}/g) ?? [])
  .filter((b) => b.includes('_grid_') && b.includes('function')).map((b) => b.replace(/^\uFEFF/, ''));

const dir = mkdtempSync(join(tmpdir(), 'gridset-'));
execFileSync(join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe'), ['-xf', resolve(here, '..', 'grids', 'Headphone Test.gridset'), '-C', dir]);
const web = readFileSync(join(dir, 'Grids', 'Headphone Test - Web', 'grid.xml'), 'utf8');
rmSync(dir, { recursive: true, force: true });
const commandId = (caption) => {
  const cell = web.split('<Cell ').find((c) => c.includes(`<Caption>${caption}</Caption>`));
  return cell.match(/<Parameter Key="commandid">([^<]*)</)[1].replace(/&apos;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
};
const grid3 = (page, id) => page.evaluate(`GridCommands.${id.replace(/ /g, '_').replace(/-/g, '_').replace(/\//g, '.')}()`);

const results = [];
const check = (name, ok, detail = '') => { results.push(ok); console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` (${detail})` : ''}`); };

const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage();
await page.addInitScript(() => {
  window.__messages = [];
  window.chrome = window.chrome || {};
  window.chrome.webview = { postMessage: (m) => window.__messages.push(m) };
});
for (const script of grid3Script) await page.addInitScript(script);
// Served as example.com, the page the test set opens. Init scripts run on navigation, not on setContent.
await page.route('https://example.com/**', (route) => route.fulfill({ contentType: 'text/html',
  body: '<html><body><h1>Example</h1><p>Some page text <a href="#">a link</a>.</p></body></html>' }));
await page.goto('https://example.com/');

// What Grid 3 does after onDomClick, then what it speaks with usePrivateVoice = true.
const spoken = () => page.evaluate(() => {
  const click = window.__messages.filter((m) => m.name === 'onDomClick').pop();
  if (!click) return { error: 'no onDomClick message' };
  const id = JSON.parse(click.data).elementID;
  const chunk = document._grid_getElementById(id)._grid_getOrCreateContainingChunk();
  const hotSpot = document._grid_getElementById(chunk)._grid_getFirstHotSpot();
  return { id, text: document._grid_getElementById(hotSpot)._grid_getHotSpotAuditoryFeedbackText() };
});

check('Grid 3 page script loaded', await page.evaluate(() => typeof HTMLElement.prototype._grid_getHotSpotAuditoryFeedbackText === 'function'),
  `${grid3Script.length} blocks`);
await grid3(page, commandId('3 Web headphones'));
const first = await spoken();
check('cell 3 sends a click and its hotspot text is the test sentence', /^Test three\./.test(first.text ?? ''), first.text ?? first.error);
await grid3(page, commandId('3 Web headphones'));
const second = await spoken();
check('pressed again, the hotspot is a new element (so Grid 3 speaks again)', second.id && second.id !== first.id, `${first.id} then ${second.id}`);
check('one test button on the page', await page.evaluate(() => document.querySelectorAll('#grid3-headphone').length === 1));
const four = await grid3(page, commandId('4 Web speaker'));
check('cell 4 returns its sentence for SpeakJavascriptFunction', /^Test four\./.test(four ?? ''), four);

await browser.close();
const passed = results.filter(Boolean).length;
console.log(`\n${passed}/${results.length} passed`);
process.exit(passed === results.length ? 0 : 1);
