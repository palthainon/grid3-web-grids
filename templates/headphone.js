// grid3HeadphoneSay(text): Grid 3 speaks the text with the audio feedback voice (the headphones).
// Grid 3 speaks a web hotspot with that voice when its hotspot cursor moves, and a click on the page moves
// the cursor. So this clicks a new 2-pixel button, in its own chunk, that returns the text. Grid 3 3.0.104 code,
// read 2026-11-06 (docs/grid3-internals.md). Needs Grid 3's "Speak links" setting (on by default).
// Trap: the page sees the click too. A site that closes menus on any click will close them.
window.grid3HeadphoneSay = function (text) {
  var old = document.getElementById('grid3-headphone');
  if (old) old.remove();
  var box = document.createElement('div');
  box.id = 'grid3-headphone';
  box.setAttribute('data-grid-chunk', 'true');
  box.style.cssText = 'position:fixed;left:0;bottom:0;width:2px;height:2px;overflow:hidden;opacity:0.01;z-index:2147483647';
  var button = document.createElement('button');
  button.textContent = '.';
  button._grid_getHotSpotAuditoryFeedbackText = function () { return String(text); };
  box.appendChild(button);
  document.body.appendChild(box);
  button.click();
  return '';
};
