// YouTube test site for the media template: proves the template and this script against a public site.
// Smartbox ships its own YouTube set; this one exists to test the media template.
// A cell's commandid "YouTubeTest/Home/Right" runs GridCommands.YouTubeTest.Home.Right(). Selectors read from
// youtube.com on 2026-11-05 (signed out). To adapt to another video site, change SITE only.
(() => {
  'use strict';
  const SITE = {
    name: 'YouTubeTest',
    host: /(^|\.)youtube\.com$/,
    tiles: 'ytd-rich-item-renderer, ytd-video-renderer, ytd-compact-video-renderer, yt-lockup-view-model',
    title: 'a#video-title, a#video-title-link, a.yt-lockup-metadata-view-model__title, h3 a',
    search: 'input[name="search_query"]',
    skipAds: '.ytp-skip-ad-button, .ytp-ad-skip-button-modern, .ytp-ad-skip-button',
    autoplayOn: '.ytp-autonav-toggle-button[aria-checked="true"]',
  };
  if (!SITE.host.test(location.hostname)) return;

  const SELECTED = 'grid3-selected';
  const visible = (el) => !!el && el.getClientRects().length > 0;
  const tiles = () => [...document.querySelectorAll(SITE.tiles)].filter(visible);
  const titleOf = (tile) => tile?.querySelector(SITE.title);

  function selectedIndex(list) { return list.findIndex((t) => t.classList.contains(SELECTED)); }

  function select(list, index) {
    list.forEach((t) => t.classList.remove(SELECTED));
    const tile = list[Math.max(0, Math.min(index, list.length - 1))];
    if (!tile) return null;
    tile.classList.add(SELECTED);
    tile.scrollIntoView({ block: 'center' });
    return tile;
  }

  function step(delta) {
    const list = tiles();
    const i = selectedIndex(list);
    select(list, i < 0 ? 0 : i + delta);
  }

  // Up and Down go to the nearest tile in the row above or below; in a one-column list that is the next tile.
  function vertical(direction) {
    const list = tiles();
    const i = selectedIndex(list);
    if (i < 0) return select(list, 0);
    const from = list[i].getBoundingClientRect();
    let best = -1;
    let bestScore = Infinity;
    list.forEach((tile, j) => {
      const r = tile.getBoundingClientRect();
      const dy = direction > 0 ? r.top - from.bottom + 1 : from.top - r.bottom + 1;
      if (j === i || dy < 0) return;
      const score = dy * 4 + Math.abs(r.left - from.left);
      if (score < bestScore) { bestScore = score; best = j; }
    });
    if (best >= 0) select(list, best);
  }

  function current() {
    const list = tiles();
    const i = selectedIndex(list);
    return i >= 0 ? list[i] : select(list, 0);
  }

  const video = () => document.querySelector('video');

  const COMMANDS = {
    'Home/Right': () => step(1),
    'Home/Left': () => step(-1),
    'Home/Down': () => vertical(1),
    'Home/Up': () => vertical(-1),
    'Home/Setup': () => { select(tiles(), 0); },
    'Search/Down': () => step(1),
    'Search/Up': () => step(-1),
    'Search/PageSetUp': () => { select(tiles(), 0); },
    'Generic/PageSetUp': () => {},
    'Generic/JumptoTop': () => { window.scrollTo(0, 0); select(tiles(), 0); },
    'Generic/Read': () => (titleOf(current())?.getAttribute('title') || titleOf(current())?.textContent || 'No video').trim(),
    'Generic/Select': () => { titleOf(current())?.click(); },
    'Generic/Search': () => { const box = document.querySelector(SITE.search); box?.focus(); box?.select(); },
    'Player/PlayPause': () => { const v = video(); if (v) { if (v.paused) v.play(); else v.pause(); } },
    'Player/DisableAutoplay': () => { document.querySelector(SITE.autoplayOn)?.click(); },
    'Player/CloseAdsBanners': () => { document.querySelectorAll(SITE.skipAds).forEach((b) => b.click()); },
    'Player/Back': () => { video()?.pause(); },
  };

  const root = (window.GridCommands = window.GridCommands || {});
  for (const [path, run] of Object.entries(COMMANDS)) {
    const parts = [SITE.name, ...path.split('/')];
    let node = root;
    for (const part of parts.slice(0, -1)) node = node[part] = node[part] || {};
    node[parts[parts.length - 1]] = () => { try { return run(); } catch (e) { return 'Command failed'; } };
  }

  const css = `.${SELECTED}{outline:6px solid #ff8c00!important;outline-offset:2px!important;border-radius:12px}`;
  const addStyle = () => { const s = document.createElement('style'); s.textContent = css; document.head.appendChild(s); };
  if (document.head) addStyle(); else document.addEventListener('DOMContentLoaded', addStyle);
})();
