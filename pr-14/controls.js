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
    '#game-controls .cluster-left {',
    '  display: grid;',
    '  grid-template-columns: repeat(3, 60px);',
    '  grid-template-rows: repeat(2, 60px);',
    '  gap: 6px;',
    '}',
    '#game-controls .cluster-right {',
    '  display: grid;',
    '  grid-template-columns: repeat(2, 60px);',
    '  grid-template-rows: repeat(2, 60px);',
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
    '#game-controls .btn-w {',
    '  grid-column: 2;',
    '  grid-row: 1;',
    '}',
    '#game-controls .btn-a {',
    '  grid-column: 1;',
    '  grid-row: 2;',
    '}',
    '#game-controls .btn-s {',
    '  grid-column: 2;',
    '  grid-row: 2;',
    '}',
    '#game-controls .btn-d {',
    '  grid-column: 3;',
    '  grid-row: 2;',
    '}',
    '#game-controls .btn-f {',
    '  grid-column: 1;',
    '  grid-row: 1;',
    '}',
    '#game-controls .btn-g {',
    '  grid-column: 2;',
    '  grid-row: 1;',
    '}',
    '#game-controls .btn-esc {',
    '  grid-column: 1 / span 2;',
    '  grid-row: 2;',
    '}'
  ].join('\n');
  document.head.appendChild(style);

  // love.js's WASM SDL layer reads e.keyCode (a legacy numeric code) to
  // determine which key was pressed. Synthetic events default to keyCode=0
  // which SDL maps to nothing, so all button presses are silently ignored.
  var KEY_CODES = {
    'w': 87, 'a': 65, 's': 83, 'd': 68,
    'f': 70, 'g': 71, 'Escape': 27
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
      btn.addEventListener('mousedown', function () {
        fireKey('keydown', key, code);
      });
      btn.addEventListener('mouseup', function () {
        fireKey('keyup', key, code);
      });
      btn.addEventListener('mouseleave', function () {
        fireKey('keyup', key, code);
      });
      btn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        fireKey('keydown', key, code);
      }, { passive: false });
      btn.addEventListener('touchend', function (e) {
        e.preventDefault();
        fireKey('keyup', key, code);
      }, { passive: false });
      btn.addEventListener('touchcancel', function (e) {
        e.preventDefault();
        fireKey('keyup', key, code);
      }, { passive: false });
    }

    var controls = document.createElement('div');
    controls.id = 'game-controls';

    // Left cluster: WASD movement
    var leftCluster = document.createElement('div');
    leftCluster.className = 'cluster-left';

    var btnW = document.createElement('button');
    btnW.className = 'btn-w';
    btnW.textContent = 'W';
    attachButton(btnW, 'w', 'KeyW');

    var btnA = document.createElement('button');
    btnA.className = 'btn-a';
    btnA.textContent = 'A';
    attachButton(btnA, 'a', 'KeyA');

    var btnS = document.createElement('button');
    btnS.className = 'btn-s';
    btnS.textContent = 'S';
    attachButton(btnS, 's', 'KeyS');

    var btnD = document.createElement('button');
    btnD.className = 'btn-d';
    btnD.textContent = 'D';
    attachButton(btnD, 'd', 'KeyD');

    leftCluster.appendChild(btnW);
    leftCluster.appendChild(btnA);
    leftCluster.appendChild(btnS);
    leftCluster.appendChild(btnD);

    // Right cluster: action buttons
    var rightCluster = document.createElement('div');
    rightCluster.className = 'cluster-right';

    var btnF = document.createElement('button');
    btnF.className = 'btn-f';
    btnF.textContent = 'F';
    attachButton(btnF, 'f', 'KeyF');

    var btnG = document.createElement('button');
    btnG.className = 'btn-g';
    btnG.textContent = 'G';
    attachButton(btnG, 'g', 'KeyG');

    var btnEsc = document.createElement('button');
    btnEsc.className = 'btn-esc';
    btnEsc.textContent = 'Esc';
    attachButton(btnEsc, 'Escape', 'Escape');

    rightCluster.appendChild(btnF);
    rightCluster.appendChild(btnG);
    rightCluster.appendChild(btnEsc);

    controls.appendChild(leftCluster);
    controls.appendChild(rightCluster);
    document.body.appendChild(controls);
  });
}());
