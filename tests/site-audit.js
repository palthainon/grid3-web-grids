// Read-only accessibility audit of a website for grid-set work. Paste into a signed-in browser tab (DevTools
// console or Claude in Chrome's JavaScript tool) and read the returned object. It clicks nothing and returns
// counts and element test ids only, never page text, because pages hold the user's private data.
// Checks: accessible names (WCAG 4.1.2), target size (2.5.8, 24 px), stable hooks for page scripts
// (data-testid, aria-label, role), live regions for new messages, landmarks, lang, dark mode support.
(() => {
  const visible = (e) => { const r = e.getBoundingClientRect(); const s = getComputedStyle(e); return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none'; };
  const tag = (e) => e.tagName.toLowerCase() + (e.dataset.testid ? `[data-testid="${e.dataset.testid}"]` : e.getAttribute('role') ? `[role="${e.getAttribute('role')}"]` : '');
  const name = (e) => (e.getAttribute('aria-label') || (e.getAttribute('aria-labelledby') || '').split(/\s+/).map((id) => document.getElementById(id)?.textContent || '').join('') ||
    e.getAttribute('title') || e.getAttribute('alt') || e.textContent || e.value || e.placeholder || '').trim();
  const controls = [...document.querySelectorAll('button, a[href], input, select, textarea, [role="button"], [role="link"], [role="menuitem"], [role="tab"], [role="checkbox"], [role="switch"], [role="option"], [tabindex]:not([tabindex="-1"])')].filter(visible);
  const noName = controls.filter((e) => !name(e) && !(e.labels && e.labels.length));
  const small = controls.filter((e) => { const r = e.getBoundingClientRect(); return r.width < 24 || r.height < 24; });
  const hooked = controls.filter((e) => e.dataset.testid || e.getAttribute('aria-label'));
  let darkRules = 0;
  for (const sheet of document.styleSheets) { try { for (const r of sheet.cssRules) { if ((r.media && /prefers-color-scheme:\s*dark/.test(r.media.mediaText)) || /(^|[\s,])\.dark\b/.test(r.selectorText || '')) darkRules++; } } catch { /* cross-origin sheet */ } }
  const sample = (list) => [...new Set(list.map(tag))].slice(0, 10);
  return {
    url: location.origin + location.pathname,
    lang: document.documentElement.lang || null,
    controls: controls.length,
    withoutName: { count: noName.length, sample: sample(noName) },
    under24px: { count: small.length, sample: sample(small) },
    stableHooks: { percent: controls.length ? Math.round((100 * hooked.length) / controls.length) : 0, testids: document.querySelectorAll('[data-testid]').length },
    liveRegions: [...document.querySelectorAll('[aria-live], [role="log"], [role="status"], [role="alert"]')].filter(visible).map(tag).slice(0, 10),
    landmarks: ['main', 'nav', 'header', 'footer', 'aside', '[role="main"]', '[role="navigation"]', '[role="complementary"]'].filter((s) => document.querySelector(s)),
    headings: document.querySelectorAll('h1, h2, h3, [role="heading"]').length,
    imagesWithoutAlt: [...document.querySelectorAll('img')].filter((i) => visible(i) && !i.hasAttribute('alt')).length,
    darkMode: { rules: darkRules, active: document.documentElement.classList.contains('dark') || matchMedia('(prefers-color-scheme: dark)').matches },
    bodyColours: { text: getComputedStyle(document.body).color, background: getComputedStyle(document.body).backgroundColor },
  };
})();
