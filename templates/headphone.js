// grid3HeadphoneSay(text): with a WebBrowser.NextElement command after it in the same cell, Grid 3 speaks the
// text with the audio feedback voice (the headphones). Grid 3 3.0.104 code, read 2026-11-06 (docs/grid3-internals.md):
// - A click on the page moves Grid 3's hotspot cursor without speech. NextElement moves it and speaks the new
//   hotspot's _grid_getHotSpotAuditoryFeedbackText() with that voice, if "Speak links" is on (the default).
// - So this adds two 2-pixel buttons in their own chunk and clicks the first. NextElement then lands on the second,
//   which returns the text. New buttons each time, because Grid 3 speaks only when the hotspot changes.
// Trap: the page sees the click too. A site that closes menus on any click will close them.
window.grid3HeadphoneSay = function (text) {
  var old = document.getElementById('grid3-headphone');
  if (old) old.remove();
  var box = document.createElement('div');
  box.id = 'grid3-headphone';
  box.setAttribute('data-grid-chunk', 'true');
  box.style.cssText = 'position:fixed;left:0;bottom:0;width:4px;height:2px;overflow:hidden;opacity:0.01;z-index:2147483647';
  var start = document.createElement('button');
  var speak = document.createElement('button');
  start.textContent = speak.textContent = '.';
  start._grid_getHotSpotAuditoryFeedbackText = function () { return ''; };
  speak._grid_getHotSpotAuditoryFeedbackText = function () { return String(text); };
  box.appendChild(start);
  box.appendChild(speak);
  document.body.appendChild(box);
  start.click();
  return '';
};
