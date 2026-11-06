// Shared new-item alert for site grid sets: a two-note chime and a small orange banner at the top.
// Grid 3 cannot show web notifications (no WebView2 permission handler, no push), so a site's page.js calls
// grid3Alert.watch() to alert while the site is open in Grid 3. Include it from site.psd1:
// Include = @('alert.js'). The builder puts it before page.js. Details: docs/templates.md (New-item alerts).
window.grid3Alert = window.grid3Alert || (() => {
  'use strict';
  function chime() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      [660, 880].forEach((freq, i) => {
        const osc = ctx.createOscillator(), gain = ctx.createGain(), t = ctx.currentTime + i * 0.18;
        osc.frequency.value = freq; osc.connect(gain); gain.connect(ctx.destination);
        gain.gain.setValueAtTime(0.0001, t); gain.gain.exponentialRampToValueAtTime(0.3, t + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.3); osc.start(t); osc.stop(t + 0.32);
      });
      setTimeout(() => ctx.close(), 1000);
    } catch (e) { /* no sound: the banner still shows */ }
  }

  function banner(text, ms = 8000) {
    if (!document.getElementById('grid3-banner-style')) {
      const s = document.createElement('style'); s.id = 'grid3-banner-style';
      s.textContent = '#grid3-banner{position:fixed;top:12px;left:50%;transform:translateX(-50%);z-index:2147483647;' +
        'background:#ff8c00;color:#000;font:600 18px sans-serif;padding:6px 16px;border-radius:16px}#grid3-banner[hidden]{display:none}';
      document.head.appendChild(s);
    }
    let b = document.getElementById('grid3-banner');
    if (!b) { b = document.createElement('div'); b.id = 'grid3-banner'; b.setAttribute('role', 'status'); document.body.appendChild(b); }
    b.textContent = text;
    b.hidden = false;
    clearTimeout(b.hideTimer);
    b.hideTimer = setTimeout(() => { b.hidden = true; }, ms);
  }

  // newest() returns the element that marks the newest incoming item (null if none yet, undefined to skip this
  // check). It alerts when a later element appears below the last one. A change of page (location.pathname)
  // or a re-render of the last element only resets the baseline, so older items loading above never alert.
  const watching = new Set();
  function watch({ newest, text = 'New message', every = 1500 }) {
    if (watching.has(text)) return;
    watching.add(text);
    const state = { primed: false, path: location.pathname, last: null };
    setInterval(() => {
      const now = newest();
      if (now === undefined) return;
      if (!state.primed || location.pathname !== state.path || (state.last && !state.last.isConnected)) {
        Object.assign(state, { primed: true, path: location.pathname, last: now });
        return;
      }
      if (now && now !== state.last && (!state.last || (state.last.compareDocumentPosition(now) & Node.DOCUMENT_POSITION_FOLLOWING))) {
        state.last = now;
        window.__grid3_alerts = (window.__grid3_alerts || 0) + 1;
        chime();
        banner(text);
      }
    }, every);
  }

  return { watch, chime, banner };
})();
