(function () {
  // Ensure viewport meta tag exists for correct mobile scaling
  if (!document.querySelector('meta[name="viewport"]')) {
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1.0';
    document.head.appendChild(meta);
  }

  // love.js sets canvas dimensions via JS inline styles after page load.
  // CSS !important alone loses that race, so we force-apply via setProperty
  // every 100 ms for the first 3 seconds, then on every resize.
  function scaleCanvas() {
    var c = document.getElementById('canvas');
    if (!c) return;
    var vw = window.innerWidth;
    var vh = Math.round(vw * 720 / 1280);
    c.style.setProperty('width',  vw + 'px', 'important');
    c.style.setProperty('height', vh + 'px', 'important');
  }
  scaleCanvas();
  window.addEventListener('resize', scaleCanvas);
  var _poll = setInterval(scaleCanvas, 100);
  setTimeout(function () { clearInterval(_poll); }, 3000);

  var style = document.createElement('style');
  style.textContent = [
    'html, body {',
    '  margin: 0;',
    '  padding: 0;',
    '  background: #000;',
    '  overflow-x: hidden;',
    '}',
    '#game-controls {',
    '  display: flex;',
    '  flex-direction: row;',
    '  justify-content: space-between;',
    '  padding: 12px;',
    '  background: rgba(0,0,0,0.7);',
    '  width: 100%;',
    '  margin: 0;',
    '  box-sizing: border-box;',
    '}',
    // Left cluster: 3 cols × 2 rows — Q/W/E top, A/S/D bottom
    '#game-controls .cluster-left {',
    '  display: grid;',
    '  grid-template-columns: repeat(3, 60px);',
    '  grid-template-rows: repeat(2, 60px);',
    '  gap: 6px;',
    '}',
    // Right cluster: 2 cols × 4 rows
    '#game-controls .cluster-right {',
    '  display: grid;',
    '  grid-template-columns: repeat(2, 60px);',
    '  grid-template-rows: repeat(4, 60px);',
    '  gap: 6px;',
    '}',
    '#game-controls button {',
    '  min-width: 60px;',
    '  min-height: 60px;',
    '  background: rgba(255,255,255,0.15);',
    '  color: white;',
    '  border: 1px solid rgba(255,255,255,0.3);',
    '  border-radius: 8px;',
    '  font-size: 18px;',
    '  cursor: pointer;',
    '  user-select: none;',
    '  -webkit-user-select: none;',
    '  touch-action: none;',
    '}',
    '#game-controls button:active {',
    '  background: rgba(255,255,255,0.35);',
    '}',
    // Left cluster positions
    '#game-controls .btn-q  { grid-column: 1; grid-row: 1; }',
    '#game-controls .btn-w  { grid-column: 2; grid-row: 1; }',
    '#game-controls .btn-e  { grid-column: 3; grid-row: 1; }',
    '#game-controls .btn-a  { grid-column: 1; grid-row: 2; }',
    '#game-controls .btn-s  { grid-column: 2; grid-row: 2; }',
    '#game-controls .btn-d  { grid-column: 3; grid-row: 2; }',
    // Right cluster positions (col 1 / col 2, rows 1–4)
    '#game-controls .btn-up    { grid-column: 1; grid-row: 1; }',
    '#game-controls .btn-f     { grid-column: 2; grid-row: 1; }',
    '#game-controls .btn-down  { grid-column: 1; grid-row: 2; }',
    '#game-controls .btn-g     { grid-column: 2; grid-row: 2; }',
    '#game-controls .btn-l     { grid-column: 1; grid-row: 3; }',
    '#game-controls .btn-m     { grid-column: 2; grid-row: 3; }',
    '#game-controls .btn-enter { grid-column: 1; grid-row: 4; }',
    '#game-controls .btn-esc   { grid-column: 2; grid-row: 4; }'
  ].join('\n');
  document.head.appendChild(style);

  // love.js's WASM SDL layer reads e.keyCode (a legacy numeric code) to
  // determine which key was pressed. Synthetic events default to keyCode=0
  // which SDL maps to nothing, so all button presses are silently ignored.
  var KEY_CODES = {
    'q': 81, 'w': 87, 'e': 69,
    'a': 65, 's': 83, 'd': 68,
    'ArrowUp': 38, 'f': 70,
    'ArrowDown': 40, 'g': 71,
    'l': 76, 'm': 77,
    'Enter': 13, 'Escape': 27
  };

  document.addEventListener('DOMContentLoaded', function () {
    var canvas = document.getElementById('canvas');

    function fireKey(type, key, code) {
      if (!canvas) { canvas = document.getElementById('canvas'); }
      if (!canvas) { return; }
      var kc = KEY_CODES[key] || 0;
      canvas.dispatchEvent(new KeyboardEvent(type, {
        key: key, code: code,
        keyCode: kc, which: kc, charCode: kc,
        bubbles: true, cancelable: true
      }));
    }

    function attachButton(btn, key, code) {
      btn.addEventListener('mousedown', function () { fireKey('keydown', key, code); });
      btn.addEventListener('mouseup',   function () { fireKey('keyup',   key, code); });
      btn.addEventListener('mouseleave',function () { fireKey('keyup',   key, code); });
      btn.addEventListener('touchstart', function (e) {
        e.preventDefault(); fireKey('keydown', key, code);
      }, { passive: false });
      btn.addEventListener('touchend', function (e) {
        e.preventDefault(); fireKey('keyup', key, code);
      }, { passive: false });
      btn.addEventListener('touchcancel', function (e) {
        e.preventDefault(); fireKey('keyup', key, code);
      }, { passive: false });
    }

    function makeBtn(cls, label, key, code) {
      var b = document.createElement('button');
      b.className = cls;
      b.textContent = label;
      attachButton(b, key, code);
      return b;
    }

    var controls = document.createElement('div');
    controls.id = 'game-controls';

    // Left cluster: Q/W/E (inventory prev, forward, inventory next)
    //               A/S/D (turn left, back, turn right)
    var left = document.createElement('div');
    left.className = 'cluster-left';
    left.appendChild(makeBtn('btn-q', 'Q', 'q', 'KeyQ'));
    left.appendChild(makeBtn('btn-w', 'W', 'w', 'KeyW'));
    left.appendChild(makeBtn('btn-e', 'E', 'e', 'KeyE'));
    left.appendChild(makeBtn('btn-a', 'A', 'a', 'KeyA'));
    left.appendChild(makeBtn('btn-s', 'S', 's', 'KeyS'));
    left.appendChild(makeBtn('btn-d', 'D', 'd', 'KeyD'));

    // Right cluster: ↑/F  (budget up / use item)
    //                ↓/G  (budget down / grab)
    //                L/M  (loadout / map)
    //                ↵/Esc (confirm+advance / settings)
    var right = document.createElement('div');
    right.className = 'cluster-right';
    right.appendChild(makeBtn('btn-up',    '↑',   'ArrowUp',   'ArrowUp'));
    right.appendChild(makeBtn('btn-f',     'F',   'f',         'KeyF'));
    right.appendChild(makeBtn('btn-down',  '↓',   'ArrowDown', 'ArrowDown'));
    right.appendChild(makeBtn('btn-g',     'G',   'g',         'KeyG'));
    right.appendChild(makeBtn('btn-l',     'L',   'l',         'KeyL'));
    right.appendChild(makeBtn('btn-m',     'M',   'm',         'KeyM'));
    right.appendChild(makeBtn('btn-enter', '↵',   'Enter',     'Enter'));
    right.appendChild(makeBtn('btn-esc',   'Esc', 'Escape',    'Escape'));

    controls.appendChild(left);
    controls.appendChild(right);
    document.body.appendChild(controls);
  });
}());
