/* ==========================================================================
   Hikaru — springboard prototipi (ES5, iOS 6 Safari uyumlu)
   iOS 6'da let/const/arrow/template-literal/Promise YOK. Bu yuzden saf ES5.
   ========================================================================== */
(function () {
  'use strict';

  /* ---------------------------------------------------------------- veri */  /* img: prototype/icons/<ad>.png  (cihazdaki dark ikon setinden) */
  var APPS = [
    { name: 'Telefon',     img: 'MobilePhone' },
    { name: 'Mesajlar',    img: 'MobileSMS' },
    { name: 'Safari',      img: 'MobileSafari' },
    { name: 'Kamera',      img: 'Camera' },
    { name: 'Fotograflar', img: 'MobileSlideShow' },
    { name: 'Muzik',       img: 'Music' },
    { name: 'Mail',        img: 'MobileMail' },
    { name: 'Ayarlar',     img: 'Preferences' },
    { name: 'Hava',        img: 'Weather' },
    { name: 'Takvim',      special: 'calendar' },
    { name: 'Saat',        special: 'clock' },
    { name: 'Haritalar',   img: 'Maps' },
    { name: 'Notlar',      img: 'MobileNotes' },
    { name: 'Hesap',       img: 'Calculator' },
    { name: 'App Store',   img: 'AppStore' },
    { name: 'Hatirlatici', img: 'Reminders' },
    { name: 'Borsa',       img: 'Stocks' },
    { name: 'Videolar',    img: 'Videos' },
    { name: 'Pusula',      img: 'Compass' },
    { name: 'Cydia',       g: 'g-orange', letter: 'C' },

    { name: 'iFile',       g: 'g-blue',   letter: 'F' },
    { name: 'Sesli Not',   g: 'g-red',    letter: 'S' },
    { name: 'Oyun Merkezi',g: 'g-teal',   letter: 'O' },
    { name: 'Kisiler',     g: 'g-gray',   letter: 'K', dark: true },
    { name: 'AppDrop',     g: 'g-purple', letter: 'A' },
    { name: 'Veteris',     g: 'g-indigo', letter: 'V' },
    { name: 'Hoshino',     g: 'g-dark',   letter: 'H' },
    { name: 'Safari+',     g: 'g-cyan',   letter: 'S' }
  ];
  var DOCK = ['Telefon', 'Safari', 'Mesajlar', 'Muzik'];
  var PER_PAGE = 20;

  var SVGNS = 'http://www.w3.org/2000/svg';
  var XLINK = 'http://www.w3.org/1999/xlink';

  /* ------------------------------------------------------------- yardimci */
  function el(tag, cls) {
    var n = document.createElement(tag);
    if (cls) { n.className = cls; }
    return n;
  }

  function svgUse(id) {
    var s = document.createElementNS(SVGNS, 'svg');
    s.setAttribute('viewBox', '0 0 24 24');
    var u = document.createElementNS(SVGNS, 'use');
    u.setAttribute('xlink:href', '#' + id);
    u.setAttributeNS(XLINK, 'href', '#' + id);
    s.appendChild(u);
    return s;
  }

  function pad2(n) { return n < 10 ? '0' + n : '' + n; }

  function byName(name) {
    for (var i = 0; i < APPS.length; i++) {
      if (APPS[i].name === name) { return APPS[i]; }
    }
    return null;
  }

  /* ---------------------------------------------------------- ikon uretimi */
  function buildIcon(app) {
    var cls = 'icon';
    if (app.g) { cls += ' ' + app.g; }
    if (app.img) { cls += ' has-img'; }
    if (app.dark) { cls += ' dark'; }
    if (app.filled) { cls += ' filled'; }
    var ic = el('div', cls);

    if (app.special === 'calendar') {
      var face = el('div', 'cal-face');
      var days = ['PAZ', 'PZT', 'SAL', 'CAR', 'PER', 'CUM', 'CMT'];
      var now = new Date();
      var d1 = el('div', 'cal-day'); d1.innerHTML = days[now.getDay()];
      var d2 = el('div', 'cal-num'); d2.innerHTML = now.getDate();
      face.appendChild(d1); face.appendChild(d2);
      ic.appendChild(face);
      return ic;
    }

    if (app.special === 'clock') {
      var cf = el('div', 'clock-face');
      var h = el('div', 'hand h-hour');
      var m = el('div', 'hand h-min');
      cf.appendChild(h); cf.appendChild(m); cf.appendChild(el('div', 'pin'));
      ic.appendChild(cf);
      setClockHands(ic, new Date());
      return ic;
    }

    if (app.special === 'weather') {
      ic.appendChild(el('div', 'wx-sun'));
      ic.appendChild(el('div', 'wx-cloud'));
      return ic;
    }

    if (app.img) {
      var img = document.createElement('img');
      img.className = 'ic-img';
      img.src = 'icons/' + app.img + '.png';
      img.alt = app.name;
      ic.appendChild(img);
      return ic;
    }

    if (app.letter) {
      var lt = el('span', 'ic-letter');
      lt.innerHTML = app.letter;
      ic.appendChild(lt);
      return ic;
    }

    if (app.ico) { ic.appendChild(svgUse(app.ico)); }
    return ic;
  }

  function setClockHands(root, now) {
    var h = root.querySelector('.h-hour');
    var m = root.querySelector('.h-min');
    if (!h || !m) { return; }
    var min = now.getMinutes();
    var hour = (now.getHours() % 12) + min / 60;
    h.style.webkitTransform = 'rotate(' + (hour * 30) + 'deg)';
    h.style.transform = 'rotate(' + (hour * 30) + 'deg)';
    m.style.webkitTransform = 'rotate(' + (min * 6) + 'deg)';
    m.style.transform = 'rotate(' + (min * 6) + 'deg)';
  }

  /* -------------------------------------------------------------- dokunma */
  function bindTap(node, fn) {
    var handled = false;
    node.addEventListener('touchstart', function () { handled = false; }, false);
    node.addEventListener('touchend', function (e) {
      handled = true;
      e.preventDefault();
      fn(e, node);
      setTimeout(function () { handled = false; }, 400);
    }, false);
    node.addEventListener('click', function (e) {
      if (handled) { return; }
      fn(e, node);
    }, false);
  }

  function xy(e) {
    if (e.touches && e.touches.length) { return { x: e.touches[0].clientX, y: e.touches[0].clientY }; }
    if (e.changedTouches && e.changedTouches.length) { return { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }; }
    return { x: e.clientX, y: e.clientY };
  }

  /* ------------------------------------------------------------ ana ekran */
  var pageEls = [document.getElementById('page1'), document.getElementById('page2')];
  var track = document.getElementById('track');
  var currentPage = 0;

  function setPage(i) {
    if (i < 0) { i = 0; }
    if (i > pageEls.length - 1) { i = pageEls.length - 1; }
    currentPage = i;
    var t = 'translateX(' + (-50 * i) + '%)';
    track.style.webkitTransform = t;
    track.style.transform = t;
  }

  function makeTile(app, withLabel) {
    var tile = el('div', 'tile');
    tile.setAttribute('data-app', app.name);
    tile.appendChild(buildIcon(app));
    if (withLabel) {
      var lb = el('span', 'label');
      lb.innerHTML = app.name;
      tile.appendChild(lb);
    }
    bindTap(tile, function () { openApp(app.name); });
    return tile;
  }

  function renderHome() {
    var i;
    for (i = 0; i < APPS.length; i++) {
      var target = pageEls[Math.floor(i / PER_PAGE)];
      if (!target) { continue; }
      target.appendChild(makeTile(APPS[i], true));
    }
    var dock = document.getElementById('dock');
    for (i = 0; i < DOCK.length; i++) {
      var app = byName(DOCK[i]);
      if (app) { dock.appendChild(makeTile(app, false)); }
    }
  }

  /* ---------------------------------------------------------- uygulama ac */
  var appOverlay = document.getElementById('appOverlay');
  var sheetTitle = document.getElementById('sheetTitle');
  var sheetBody = document.getElementById('sheetBody');

  function openApp(name) {
    sheetTitle.innerHTML = name;
    sheetBody.innerHTML =
      '<p style="margin:0 0 8px 0">Bu bir arayuz prototipi. Simdilik sadece kabugu goruyorsun.</p>' +
      '<p style="margin:0">Gercek cihazda bu kutu, uygulamayi <code>SBSLaunchApplicationWithIdentifier</code> ' +
      '(veya AppLaunch) ile acacak. Batarya icin uygulama arka planda tutulmaz.</p>';
    appOverlay.className = 'overlay app-overlay show';
  }

  bindTap(appOverlay, function (e, node) {
    if (e.target === node || e.target.className === 'app-sheet') {
      node.className = 'overlay app-overlay';
    }
  });

  /* --------------------------------------------------------------- arama */
  var searchOverlay = document.getElementById('searchOverlay');
  var searchInput = document.getElementById('searchInput');
  var results = document.getElementById('results');

  function renderResults(q) {
    results.innerHTML = '';
    var ql = (q || '').toLowerCase();
    var shown = 0;
    for (var i = 0; i < APPS.length && shown < 8; i++) {
      if (ql && APPS[i].name.toLowerCase().indexOf(ql) === -1) { continue; }
      var row = el('div', 'result-row');
      var dot = el('span', 'dot ' + APPS[i].g);
      row.appendChild(dot);
      row.appendChild(document.createTextNode(APPS[i].name));
      (function (name) {
        bindTap(row, function () {
          searchOverlay.className = 'overlay search-overlay';
          openApp(name);
        });
      }(APPS[i].name));
      results.appendChild(row);
      shown++;
    }
  }

  function openSearch() {
    searchOverlay.className = 'overlay search-overlay show';
    renderResults('');
    setTimeout(function () { try { searchInput.focus(); } catch (err) {} }, 120);
  }

  bindTap(document.getElementById('searchpill'), openSearch);
  bindTap(document.getElementById('searchCancel'), function () {
    searchOverlay.className = 'overlay search-overlay';
  });
  searchInput.onkeyup = function () { renderResults(searchInput.value); };

  /* ------------------------------------------------------ kontrol merkezi */
  var ccOverlay = document.getElementById('ccOverlay');

  function openCC() {
    ccOverlay.className = 'overlay cc-overlay show';
  }
  function closeCC() {
    ccOverlay.className = 'overlay cc-overlay';
  }

  bindTap(ccOverlay, function (e, node) {
    if (e.target === node) { closeCC(); }
  });

  var toggles = ccOverlay.getElementsByTagName('button');
  for (var ti = 0; ti < toggles.length; ti++) {
    (function (btn) {
      bindTap(btn, function () {
        if (btn.className.indexOf('cc-mini') > -1) { return; }
        btn.className = btn.className.indexOf('on') > -1
          ? btn.className.replace(' on', '')
          : btn.className + ' on';
      });
    }(toggles[ti]));
  }

  /* ------------------------------------------------------- kaydirma/lar */
  var startX = 0, startY = 0, tracking = false, stageTop = 0;

  function begin(e) {
    var p = xy(e);
    startX = p.x; startY = p.y; tracking = true;
    var rect = document.getElementById('stage').getBoundingClientRect();
    stageTop = rect ? rect.top : 0;
  }

  function end(e) {
    if (!tracking) { return; }
    tracking = false;
    var p = xy(e);
    var dx = p.x - startX;
    var dy = p.y - startY;

    /* ust kenardan asagi cekme -> kontrol merkezi */
    if ((startY - stageTop) < 26 && dy > 34 && Math.abs(dy) > Math.abs(dx)) {
      openCC();
      return;
    }
    /* yatay kaydirma -> sayfa degistir */
    if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) {
      setPage(currentPage + (dx < 0 ? 1 : -1));
    }
  }

  var pagesEl = document.getElementById('pages');
  var events = ('ontouchstart' in window)
    ? { start: 'touchstart', end: 'touchend' }
    : { start: 'mousedown', end: 'mouseup' };

  pagesEl.addEventListener(events.start, begin, false);
  document.addEventListener(events.end, end, false);

  /* ---------------------------------------------------------------- saat */
  function tick() {
    var now = new Date();
    document.getElementById('sb-clock').innerHTML = now.getHours() + ':' + pad2(now.getMinutes());
    var clocks = document.querySelectorAll('.clock-face');
    for (var i = 0; i < clocks.length; i++) {
      setClockHands(clocks[i].parentNode, now);
    }
  }

  /* ------------------------------------------------------------------ bas */
  renderHome();
  tick();
  setInterval(tick, 20000);

  /* masaustu onizleme kolayligi: C tusu kontrol merkezi, S tusu arama */
  document.addEventListener('keydown', function (e) {
    var k = e.keyCode;
    if (k === 67) { openCC(); }
    if (k === 83) { openSearch(); }
    if (k === 27) { closeCC(); searchOverlay.className = 'overlay search-overlay'; appOverlay.className = 'overlay app-overlay'; }
  }, false);
}());
