/* Islet — website. A small re-creation of the island, running in the browser. */
(() => {
  'use strict';
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const pad = (n) => String(n).padStart(2, '0');
  const fmt = (s) => { s = Math.max(0, Math.round(s)); return `${Math.floor(s / 60)}:${pad(s % 60)}`; };
  const clock = (d = new Date()) => d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const dateStr = (d = new Date()) => d.toLocaleDateString([], { weekday: 'long', day: 'numeric', month: 'long' });

  // ---------------------------------------------------------------- toast
  const toastEl = $('#toast');
  let toastT;
  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add('on');
    clearTimeout(toastT);
    toastT = setTimeout(() => toastEl.classList.remove('on'), 2400);
  }

  // ---------------------------------------------------------------- icons
  const sv = (d, fill) => `<svg class="ic${fill ? ' fill' : ''}" viewBox="0 0 24 24" aria-hidden="true">${d}</svg>`;
  const I = {
    play: sv('<path d="M7.5 4.8v14.4c0 .8.9 1.3 1.6.8l11-7.2a1 1 0 0 0 0-1.6l-11-7.2c-.7-.5-1.6 0-1.6.8Z"/>', 1),
    pause: sv('<rect x="5.5" y="4.5" width="4.6" height="15" rx="1.4"/><rect x="13.9" y="4.5" width="4.6" height="15" rx="1.4"/>', 1),
    next: sv('<path d="M3.5 6.2v11.6c0 .7.8 1.2 1.4.7l7.4-5.8a1 1 0 0 0 0-1.4L4.9 5.5c-.6-.5-1.4 0-1.4.7ZM12 6.2v11.6c0 .7.8 1.2 1.4.7l7.4-5.8a1 1 0 0 0 0-1.4l-7.4-5.8c-.6-.5-1.4 0-1.4.7Z"/>', 1),
    prev: sv('<path d="M20.5 6.2v11.6c0 .7-.8 1.2-1.4.7l-7.4-5.8a1 1 0 0 1 0-1.4l7.4-5.8c.6-.5 1.4 0 1.4.7ZM12 6.2v11.6c0 .7-.8 1.2-1.4.7l-7.4-5.8a1 1 0 0 1 0-1.4l7.4-5.8c.6-.5 1.4 0 1.4.7Z"/>', 1),
    msg: sv('<path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v7a2.5 2.5 0 0 1-2.5 2.5H10l-4.5 4v-4A2.5 2.5 0 0 1 4 13.5Z"/>'),
    lock: sv('<rect x="4" y="10" width="16" height="10" rx="2.5"/><path d="M8 10V7.5a4 4 0 0 1 8 0V10"/>'),
    bolt: sv('<path d="M13 2.5 4.5 13.5h6.5L10 21.5l8.5-11H12Z"/>', 1),
    timer: sv('<circle cx="12" cy="13.5" r="7"/><path d="M12 10v3.5l2.5 1.5M10 3h4"/>'),
    leaf: sv('<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14Zm0 0 7-7"/>'),
    shot: sv('<path d="M4 8V5.5A1.5 1.5 0 0 1 5.5 4H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5V8M20 16v2.5a1.5 1.5 0 0 1-1.5 1.5H16M8 20H5.5A1.5 1.5 0 0 1 4 18.5V16"/><circle cx="12" cy="12" r="3"/>'),
    down: sv('<path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19.5h14"/>'),
    mic: sv('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>'),
    micOff: sv('<path d="M15 9.5V6a3 3 0 0 0-5.6-1.5M9 9v2a3 3 0 0 0 4.6 2.5M5.5 11a6.5 6.5 0 0 0 10.6 5M18.5 11a6.4 6.4 0 0 1-.6 2.7M12 17.5V21M4 4l16 16"/>'),
    vol: sv('<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4Z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>'),
    mute: sv('<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4Z"/><path d="m16 9.5 5 5m0-5-5 5"/>'),
    copy: sv('<rect x="8" y="8" width="12" height="12" rx="2.5"/><path d="M16 8V6.5A2.5 2.5 0 0 0 13.5 4h-7A2.5 2.5 0 0 0 4 6.5v7A2.5 2.5 0 0 0 6.5 16H8"/>'),
    check: sv('<path d="m5 12.5 4.5 4.5L19 7.5"/>'),
    folder: sv('<path d="M3.5 7.5A2.5 2.5 0 0 1 6 5h3.5l2 2.2H18a2.5 2.5 0 0 1 2.5 2.5v7.8A2.5 2.5 0 0 1 18 20H6a2.5 2.5 0 0 1-2.5-2.5Z"/>'),
    pen: sv('<path d="M14.5 5.5 18.5 9.5M4 20l1-4.5L15.5 5a2 2 0 0 1 2.8 0l.7.7a2 2 0 0 1 0 2.8L8.5 19Z"/>'),
    search: sv('<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4 4"/>'),
    spark: sv('<path d="M12 3.5 13.8 9a2 2 0 0 0 1.2 1.2l5.5 1.8-5.5 1.8a2 2 0 0 0-1.2 1.2L12 20.5 10.2 15A2 2 0 0 0 9 13.8L3.5 12 9 10.2A2 2 0 0 0 10.2 9Z"/>'),
    head: sv('<path d="M4 15v-2a8 8 0 0 1 16 0v2"/><rect x="3.5" y="14" width="4.5" height="6.5" rx="1.8"/><rect x="16" y="14" width="4.5" height="6.5" rx="1.8"/>'),
    batt: sv('<rect x="2.5" y="7.5" width="17" height="9" rx="2.5"/><rect x="4.5" y="9.5" width="10" height="5" rx="1" fill="currentColor" stroke="none"/><path d="M21.5 10.5v3"/>'),
    wifi: sv('<path d="M2.5 9a14 14 0 0 1 19 0M5.8 12.5a9 9 0 0 1 12.4 0M9.2 16a4 4 0 0 1 5.6 0"/><circle cx="12" cy="19" r=".8" fill="currentColor"/>'),
    signal: sv('<path d="M5 18v-2M9.5 18v-5M14 18v-8M18.5 18V6"/>'),
  };

  // ---------------------------------------------------------------- spring
  class Spring {
    constructor(v, k = 320, z = 0.74) { this.v = v; this.t = v; this.vel = 0; this.k = k; this.z = z; }
    to(t) { this.t = t; }
    snap(v) { this.v = this.t = v; this.vel = 0; }
    step(dt) {
      const d = 2 * this.z * Math.sqrt(this.k), n = Math.max(1, Math.ceil(dt * 240)), h = dt / n;
      for (let i = 0; i < n; i++) { const a = -this.k * (this.v - this.t) - d * this.vel; this.vel += a * h; this.v += this.vel * h; }
      if (Math.abs(this.v - this.t) < 0.05 && Math.abs(this.vel) < 0.05) { this.v = this.t; this.vel = 0; return false; }
      return true;
    }
  }

  // ---------------------------------------------------------------- devices
  const WALL = {
    mac: 'radial-gradient(60% 80% at 15% 20%, #3b5bdb 0%, transparent 60%), radial-gradient(55% 70% at 85% 30%, #c2255c 0%, transparent 60%), radial-gradient(70% 70% at 60% 100%, #0b7285 0%, transparent 65%), linear-gradient(160deg, #141a35, #0a0b14)',
    win: 'radial-gradient(70% 90% at 70% 10%, #4263eb 0%, transparent 60%), radial-gradient(60% 80% at 10% 90%, #12b886 0%, transparent 60%), radial-gradient(50% 60% at 95% 85%, #7048e8 0%, transparent 60%), linear-gradient(180deg, #0e1530, #090b12)',
    android: 'radial-gradient(90% 50% at 20% 15%, #f76707 0%, transparent 60%), radial-gradient(90% 60% at 90% 45%, #d6336c 0%, transparent 62%), radial-gradient(100% 60% at 30% 95%, #5f3dc4 0%, transparent 65%), linear-gradient(180deg, #1a1023, #0b0910)',
  };
  const APPS = [
    ['Files', 'linear-gradient(135deg,#ffd54f,#f0a500)'], ['Browser', 'linear-gradient(135deg,#2dd4bf,#0a84ff)'],
    ['Music', 'linear-gradient(135deg,#ff7a90,#ff375f)'], ['Chat', 'linear-gradient(135deg,#3ee07a,#12a150)'],
    ['Mail', 'linear-gradient(135deg,#6cb8ff,#1c6ef2)'], ['Settings', 'linear-gradient(135deg,#a1a1aa,#52525b)'],
    ['Photos', 'linear-gradient(135deg,#fbbf24,#ec4899)'], ['Notes', 'linear-gradient(135deg,#fde68a,#f59e0b)'],
  ];
  const dockIcons = (n) => APPS.slice(0, n).map((a) => `<i style="--g:${a[1]}"></i>`).join('');

  const DEVICES = {
    mac: {
      W: 1060, H: 651,
      html: () => `<div class="mac"><div class="mac-lid"><div class="screen"><div class="wall" style="background:${WALL.mac}"></div>
        <div class="menubar"><div class="l"><b>Finder</b><span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span></div>
        <div class="r">${I.batt}${I.wifi}${I.search}<span data-clock-long></span></div></div>
        <div class="mac-dock">${dockIcons(8)}</div><div class="flash"></div></div></div><div class="mac-base"></div></div>`,
      geo: { top: 0, ears: true, nw: 184, nh: 32, reserve: 32, gap: 184, card: 450, xm: 490, ln: 580, cr: 12, er: 28 },
    },
    win: {
      W: 980, H: 646,
      html: () => `<div class="win"><div class="win-mon"><div class="screen"><div class="wall" style="background:${WALL.win}"></div>
        <div class="win-window"></div>
        <div class="task">${dockIcons(6)}<span class="clock"><span data-clock></span><br><span data-date-short></span></span></div><div class="flash"></div></div></div>
        <div class="win-neck"></div><div class="win-foot"></div></div>`,
      geo: { top: 10, ears: false, nw: 0, nh: 36, reserve: 0, gap: 0, card: 450, xm: 490, ln: 560, cr: 18, er: 32 },
    },
    android: {
      W: 412, H: 854,
      html: () => `<div class="android"><div class="phone"><div class="screen"><div class="wall" style="background:${WALL.android}"></div>
        <div class="status"><span data-clock></span><span class="r">${I.signal}${I.wifi}${I.batt}</span></div>
        <div class="ph-clock" data-clock-big></div><div class="ph-date" data-date></div>
        <div class="ph-apps">${dockIcons(8)}</div><div class="cam"></div><div class="flash"></div></div></div></div>`,
      geo: { top: 9, ears: false, nw: 112, nh: 36, reserve: 36, gap: 112, card: 368, xm: 368, ln: 368, cr: 18, er: 32 },
    },
  };

  const TRACKS = [
    { t: 'Midnight Drive', a: 'The Night Owls', art: 'linear-gradient(135deg,#ff5e7e,#6a3de8)', c: '#ff6f91', c2: '#8b5cf6', dur: 214 },
    { t: 'Golden Hour', a: 'Sunset Avenue', art: 'linear-gradient(135deg,#ffb347,#ff5f6d)', c: '#ffa25f', c2: '#ff5f6d', dur: 187 },
    { t: 'Ocean Eyes', a: 'Blue Static', art: 'linear-gradient(135deg,#43e3c4,#2b6dff)', c: '#4fd1ff', c2: '#2b6dff', dur: 241 },
  ];

  // accent + glow per moment
  const LOOK = {
    idle: { a: '#8ab4ff', a2: '#7a5cff', glow: 0 },
    peek: { a: '#8ab4ff', a2: '#7a5cff', glow: 0 },
    welcome: { a: '#3df5c8', a2: '#7a5cff', glow: 1, g: ['#3df5c8', '#7a5cff', '#ff5cc8'] },
    message: { a: '#34c759', a2: '#0a84ff', glow: .9, g: ['#34c759', '#7ce8a0', '#0fa968'] },
    otp: { a: '#34c759', a2: '#3df5c8', glow: .9, g: ['#34c759', '#3df5c8', '#0fa968'] },
    charging: { a: '#34c759', a2: '#a3e635', glow: 1, g: ['#34c759', '#a3e635', '#22c55e'] },
    timer: { a: '#ff9f0a', a2: '#ff5f6d', glow: .55, g: ['#ff9f0a', '#ffd166', '#ff6b35'] },
    xtimer: { a: '#ff9f0a', a2: '#ff5f6d', glow: .55, g: ['#ff9f0a', '#ffd166', '#ff6b35'] },
    focus: { a: '#34c759', a2: '#3df5c8', glow: .5, g: ['#34c759', '#3df5c8', '#86efac'] },
    shot: { a: '#a78bfa', a2: '#22d3ee', glow: .85, g: ['#a78bfa', '#22d3ee', '#f472b6'] },
    download: { a: '#0a84ff', a2: '#22d3ee', glow: .45, g: ['#0a84ff', '#22d3ee', '#6366f1'] },
    done: { a: '#0a84ff', a2: '#22d3ee', glow: .85, g: ['#0a84ff', '#22d3ee', '#6366f1'] },
    call: { a: '#34c759', a2: '#0a84ff', glow: .45, g: ['#34c759', '#7ce8a0', '#0fa968'] },
    xcall: { a: '#34c759', a2: '#0a84ff', glow: .45, g: ['#34c759', '#7ce8a0', '#0fa968'] },
    volume: { a: '#c7d2fe', a2: '#8ab4ff', glow: 0 },
    launcher: { a: '#8ab4ff', a2: '#7a5cff', glow: .3, g: ['#8ab4ff', '#7a5cff', '#3df5c8'] },
  };

  // ---------------------------------------------------------------- the simulator
  class Sim {
    constructor(host, opts = {}) {
      this.host = host;
      this.device = opts.device || 'mac';
      this.interactive = opts.interactive !== false;
      this.onLook = opts.onLook || (() => {});
      this.state = 'idle';
      this.prev = 'idle';
      this.d = { track: 0, playing: true, pos: 83, pct: 82, timer: 300, timerTotal: 300, timerPaused: false,
                 focus: 1500, focusTotal: 1500, call: 0, micMuted: false, dl: 0, vol: 62, copied: false };
      this.sw = new Spring(100); this.sh = new Spring(30); this.sr = new Spring(10);
      this.raf = 0; this.last = 0;
      this.build();
      setInterval(() => this.tick(), 1000);
    }

    get geo() { return DEVICES[this.device].geo; }

    build() {
      const dv = DEVICES[this.device];
      this.host.dataset.device = this.device;
      this.host.innerHTML = dv.html();
      this.screen = $('.screen', this.host);
      this.flashEl = $('.flash', this.host);
      this.glow = document.createElement('div');
      this.glow.className = 'isl-glow';
      this.wrap = document.createElement('div');
      this.wrap.className = 'isl-wrap' + (dv.geo.ears ? ' ears' : '');
      this.wrap.setAttribute('role', 'button');
      this.wrap.setAttribute('aria-label', 'The island. Tap to open.');
      this.wrap.tabIndex = this.interactive ? 0 : -1;
      this.isl = document.createElement('div');
      this.isl.className = 'isl';
      this.wrap.appendChild(this.isl);
      this.screen.appendChild(this.glow);
      this.screen.appendChild(this.wrap);
      this.wrap.style.top = this.glow.style.top = dv.geo.top + 'px';
      this.cEl = null;
      this.key = '';
      this.paintClock();
      if (this.interactive) this.bind();
      const L = this.layout(this.state);
      this.sw.snap(L.w); this.sh.snap(L.h); this.sr.snap(L.r);
      this.apply();
      this.render(true);
    }

    setDevice(dev) {
      if (dev === this.device) return;
      this.device = dev;
      this.host.classList.add('swap');
      setTimeout(() => {
        this.build();
        this.host.classList.remove('swap');
        fitAll();
      }, reduce ? 0 : 260);
    }

    bind() {
      this.wrap.addEventListener('click', (e) => {
        const b = e.target.closest('[data-a]');
        markUser();
        if (b) { e.stopPropagation(); this.action(b.dataset.a, b, e); return; }
        this.tapBody();
      });
      this.wrap.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); markUser(); this.tapBody(); } });
      this.wrap.addEventListener('mouseenter', () => { if (this.state === 'idle') this.go('peek'); });
      this.wrap.addEventListener('mouseleave', () => { if (this.state === 'peek') this.go('idle'); });
      this.wrap.addEventListener('wheel', (e) => {
        if (['launcher', 'xmusic'].includes(this.state)) return;
        e.preventDefault();
        markUser();
        this.d.vol = Math.max(0, Math.min(100, this.d.vol + (e.deltaY < 0 ? 4 : -4)));
        if (this.state !== 'volume') { this.volBack = this.state === 'peek' ? 'idle' : this.state; this.go('volume'); }
        else { const b = $('.vbar b', this.wrap); if (b) b.style.setProperty('--v', this.d.vol); const n = $('[data-live="vol"]', this.wrap); if (n) n.textContent = this.d.vol; }
        clearTimeout(this.volT);
        this.volT = setTimeout(() => { if (this.state === 'volume') this.go(this.volBack || 'idle'); }, 1500);
      }, { passive: false });
      this.screen.addEventListener('click', (e) => {
        if (this.wrap.contains(e.target)) return;
        if (['launcher', 'xmusic', 'xtimer', 'xcall'].includes(this.state)) { markUser(); this.collapse(); }
      });
    }

    // ---- geometry for each moment
    layout(s) {
      const g = this.geo, wing = { music: 66, call: 78, focus: 92, timer: 76, download: 98, charging: 96, volume: 104, peek: 96 }[s] || 0;
      const compact = (w) => ({ w: g.ears || this.device === 'android' ? g.nw + 2 * w : Math.max(300, 160 + 2 * w), h: g.nh, r: g.cr });
      const card = (h, w = g.card) => ({ w, h: g.reserve + h + (g.reserve ? 0 : 6), r: g.er });
      switch (s) {
        case 'idle': return { w: g.ears ? g.nw : this.device === 'win' ? 196 : g.nw, h: g.nh, r: g.ears ? 10 : g.cr };
        case 'peek': return this.device === 'win' ? { w: 290, h: g.nh, r: g.cr } : compact(wing);
        case 'music': case 'call': case 'focus': case 'timer': case 'download': case 'charging': case 'volume': return compact(wing);
        case 'welcome': return card(66);
        case 'message': return card(72);
        case 'otp': return card(72);
        case 'shot': return card(108);
        case 'done': return card(70);
        case 'xmusic': return card(176, g.xm);
        case 'xtimer': return card(128);
        case 'xcall': return card(108);
        case 'launcher': return card(this.device === 'android' ? 352 : 300, g.ln);
        default: return { w: g.nw || 190, h: g.nh, r: g.cr };
      }
    }

    // ---- content for each moment
    html(s) {
      const g = this.geo, d = this.d, tr = TRACKS[d.track];
      const gap = g.gap;
      const row = (l, r, m = '') => `<div class="c-row" style="--gap:${gap}px">${'<div class="l">' + l + '</div>'}<div class="m">${gap ? '' : m}</div><div class="r">${r}</div></div>`;
      const below = (inner) => `<div style="height:${g.reserve}px"></div>${inner}`;
      switch (s) {
        case 'idle':
          return this.device === 'win' ? row('', '', `<span data-clock></span>`) : '';
        case 'peek':
          return row(`<span style="font-weight:600;font-size:13px" data-clock></span>`,
                     `<span style="color:#6ee38c;font-size:12.5px">${d.pct}%</span><span style="color:#6ee38c">${I.batt}</span>`,
                     `<span style="color:rgba(255,255,255,.55);font-size:12px" data-date-short></span>`);
        case 'music':
          return row(`<span class="art" style="--art:${tr.art}"></span>`,
                     `<span class="bars${d.playing ? '' : ' paused'}" style="--c:${tr.c}"><i></i><i></i><i></i><i></i></span>`,
                     `<span>${tr.t}</span>`);
        case 'timer':
          return row(`<span style="color:var(--orange)">${I.timer}</span>`,
                     `<span style="color:#ffc062" data-live="timer">${fmt(d.timer)}</span><span class="ring" style="--c:var(--orange);--p:${100 - d.timer / d.timerTotal * 100}" data-live-p="timer"></span>`,
                     `<span style="color:rgba(255,255,255,.7)">Timer</span>`);
        case 'focus':
          return row(`<span style="color:var(--green)">${I.leaf}</span><span style="font-size:12.5px;color:rgba(255,255,255,.75)">Focus</span>`,
                     `<span style="color:#6ee38c" data-live="focus">${fmt(d.focus)}</span>`, '');
        case 'charging':
          return row(`<span style="color:var(--green)">${I.bolt}</span><span style="font-size:12.5px;color:rgba(255,255,255,.8);font-weight:500">Charging</span>`,
                     `<span style="color:#6ee38c" data-live="pct">${d.pct}%</span>`, '');
        case 'call':
          return row(`<span style="color:${d.micMuted ? 'var(--red)' : 'var(--green)'}">${d.micMuted ? I.micOff : I.mic}</span>`,
                     `<span style="color:#6ee38c" data-live="call">${fmt(d.call)}</span>`, `<span style="color:rgba(255,255,255,.7)">On a call</span>`);
        case 'download':
          return row(`<span style="color:var(--blue)">${I.down}</span>`,
                     `<span style="font-size:12px;color:rgba(255,255,255,.6)" data-live="dlmb">${(d.dl / 100 * 1.4).toFixed(1)} MB</span><span class="ring" style="--c:var(--blue);--p:${d.dl}" data-live-p="dl"></span>`,
                     `<span>Islet.zip</span>`);
        case 'volume':
          return row(`<span>${d.vol ? I.vol : I.mute}</span>`,
                     `<span class="vbar" style="--v:${d.vol}"><b></b></span><span style="font-size:12px;width:22px;text-align:right" data-live="vol">${d.vol}</span>`, '');
        case 'welcome':
          return below(`<div class="cardx"><span class="ico" style="background:rgba(61,245,200,.16);color:#3df5c8">${I.spark}</span>
            <div class="tx"><div class="ti">Hi, I'm Islet</div><div class="bo">Tap me, scroll on me, or try a moment below.</div></div></div>`);
        case 'message':
          return below(`<div class="cardx"><span class="ico" style="background:linear-gradient(135deg,#3ee07a,#12a150)">${I.msg}</span>
            <div class="tx"><div class="meta">Messages · now</div><div class="ti">Priya</div><div class="bo">Still on for dinner at 8? I booked the table 🍽️</div></div></div>`);
        case 'otp':
          return below(`<div class="cardx" style="align-items:center"><span class="ico" style="background:rgba(52,199,89,.18);color:#6ee38c">${I.lock}</span>
            <div class="tx"><div class="meta">Your Bank · now</div><div class="ti">482913 is your code</div><div class="bo">Valid for 10 minutes.</div></div>
            <button class="pill g otp" data-a="copy">${d.copied ? I.check + 'Copied' : I.copy + '482 913'}</button></div>`);
        case 'shot':
          return below(`<div class="cardx"><span class="shot-th" style="--th:${WALL[this.device]}" draggable="true" title="Drag me"></span>
            <div class="tx"><div class="ti">Screenshot</div><div class="meta">Islet stepped out of the shot</div>
            <div class="row-btns"><button class="pill" data-a="t:Copied to clipboard">${I.copy}Copy</button><button class="pill" data-a="t:Opening Markup…">${I.pen}Markup</button><button class="pill" data-a="t:Showing in folder">${I.folder}Show</button></div></div></div>`);
        case 'done':
          return below(`<div class="cardx" style="align-items:center"><span class="ico" style="background:rgba(10,132,255,.2);color:#8ec5ff">${I.down}</span>
            <div class="tx"><div class="meta">Downloaded · 1.4 MB</div><div class="ti">Islet.zip</div></div>
            <button class="pill b" data-a="t:Opening Islet.zip…">Open</button><button class="pill" data-a="t:Showing in folder" style="width:31px;padding:0">${I.folder}</button></div>`);
        case 'xmusic':
          return below(`<div class="xm" style="--c:${tr.c}"><div class="xm-top"><span class="xm-art" style="--art:${tr.art}"></span>
            <div style="flex:1;min-width:0"><div class="ti">${tr.t}</div><div class="ar">${tr.a}</div><span class="dev">${I.head}Headphones</span></div>
            <span class="bars${d.playing ? '' : ' paused'}" style="--c:${tr.c};height:22px"><i></i><i></i><i></i><i></i></span></div>
            <div class="prog"><span data-live="pos">${fmt(d.pos)}</span><span class="track" data-a="seek"><b style="--p:${d.pos / tr.dur * 100}" data-live-p="pos"></b></span><span data-live="rem">-${fmt(tr.dur - d.pos)}</span></div>
            <div class="ctrls"><button data-a="prev" aria-label="Previous">${I.prev}</button><button class="big" data-a="play" aria-label="Play or pause">${d.playing ? I.pause : I.play}</button><button data-a="next" aria-label="Next">${I.next}</button></div></div>`);
        case 'xtimer': {
          const focus = this.prev === 'focus';
          const left = focus ? d.focus : d.timer, total = focus ? d.focusTotal : d.timerTotal;
          return below(`<div class="xt" style="--c:${focus ? 'var(--green)' : 'var(--orange)'}"><div><div class="lbl">${focus ? 'Focus · round 1' : 'Timer · ' + Math.round(total / 60) + ' min'}${d.timerPaused && !focus ? ' · paused' : ''}</div>
            <div class="big" data-live="${focus ? 'focus' : 'timer'}">${fmt(left)}</div></div><span class="ringbig" style="--p:${100 - left / total * 100}" data-live-p="${focus ? 'focus' : 'timer'}"></span></div>
            <div class="xt-btns"><button class="pill" data-a="tpause">${d.timerPaused ? I.play + 'Resume' : I.pause + 'Pause'}</button>
            <button class="pill" data-a="tadd">+1 min</button><button class="pill r" data-a="tstop">Stop</button></div>`);
        }
        case 'xcall':
          return below(`<div class="cardx" style="align-items:center"><span class="ico" style="border-radius:50%;background:${d.micMuted ? 'rgba(255,69,58,.2);color:#ff8a80' : 'rgba(52,199,89,.2);color:#6ee38c'}">${d.micMuted ? I.micOff : I.mic}</span>
            <div class="tx"><div class="ti">${d.micMuted ? 'Microphone muted' : 'On a call'}</div><div class="meta">Camera and microphone in use</div></div>
            <span style="font-weight:600;color:#6ee38c;font-variant-numeric:tabular-nums" data-live="call">${fmt(d.call)}</span></div>
            <div class="xt-btns"><button class="pill ${d.micMuted ? 'g' : ''}" data-a="mute">${d.micMuted ? I.mic + 'Unmute' : I.micOff + 'Mute mic'}</button><button class="pill" data-a="collapse">Hide</button></div>`);
        case 'launcher': {
          const n = this.device === 'android' ? 8 : 6;
          const apps = APPS.slice(0, n).map((a) => `<span data-a="t:Opening ${a[0]}…"><i style="--g:${a[1]}"></i>${a[0]}</span>`).join('');
          const tile = (ic, col, t, sub, act) => `<button data-a="${act}"><span class="dot" style="background:${col}33;color:${col}">${ic}</span><span>${t}<small>${sub}</small></span></button>`;
          return below(`<div class="ln"><div class="ln-top"><div><div class="ln-time" data-clock></div><div class="ln-date" data-date></div></div>
            <span style="display:flex;align-items:center;gap:5px;font-size:12px;color:#6ee38c">${d.pct}% ${I.batt}</span></div>
            <div class="ln-search">${I.search}<span class="caret"></span>Search apps · type 10m for a timer</div>
            <div class="ln-apps">${apps}</div>
            <div class="ln-tiles">${tile(I.leaf, '#34c759', 'Focus', '25 min', 'go:focus')}${tile(I.timer, '#ff9f0a', 'Timer', '5 min', 'go:timer')}${tile(I.timer, '#ff9f0a', 'Timer', '15 min', 'go:timer15')}${tile(I.shot, '#a78bfa', 'Snip', 'screen', 'go:shot')}</div></div>`);
        }
      }
      return '';
    }

    // ---- transitions
    go(s, opts = {}) {
      if (s === 'xtimer' || s === 'xcall' || s === 'xmusic') this.prev = this.state === 'peek' ? 'idle' : this.state;
      if (s === 'timer' && opts.minutes) { this.d.timer = this.d.timerTotal = opts.minutes * 60; this.d.timerPaused = false; }
      if (s === 'download' && this.state !== 'download') { this.d.dl = 0; this.runDownload(); }
      if (s === 'call' && !['call', 'xcall'].includes(this.state)) this.d.call = 0;
      if (s === 'otp') this.d.copied = false;
      this.state = s;
      const L = this.layout(s);
      this.sw.to(L.w); this.sh.to(L.h); this.sr.to(L.r);
      const look = LOOK[s] || LOOK.idle;
      this.glow.style.setProperty('--g1', (look.g || [])[0] || look.a);
      this.glow.style.setProperty('--g2', (look.g || [])[1] || look.a2);
      this.glow.style.setProperty('--g3', (look.g || [])[2] || look.a);
      let a = look.a, a2 = look.a2;
      if (s === 'music' || s === 'xmusic') { a = TRACKS[this.d.track].c; a2 = TRACKS[this.d.track].c2; this.glow.style.setProperty('--g1', a); this.glow.style.setProperty('--g2', a2); this.glow.style.setProperty('--g3', a); }
      this.glow.style.opacity = (s === 'music' || s === 'xmusic') ? (this.d.playing ? .75 : 0) : look.glow;
      this.onLook(a, a2, s);
      this.render();
      this.kick();
    }

    collapse() {
      const back = { xmusic: 'music', xtimer: this.prev === 'focus' ? 'focus' : 'timer', xcall: 'call' }[this.state];
      this.go(back || 'idle');
    }

    tapBody() {
      switch (this.state) {
        case 'idle': case 'peek': this.go('launcher'); break;
        case 'music': this.go('xmusic'); break;
        case 'timer': case 'focus': this.go('xtimer'); break;
        case 'call': this.go('xcall'); break;
        case 'launcher': case 'xmusic': case 'xtimer': case 'xcall': this.collapse(); break;
        case 'message': toast('Opening Messages…'); this.go('idle'); break;
        case 'welcome': this.go('launcher'); break;
        case 'charging': case 'volume': this.go('idle'); break;
        case 'done': toast('Opening Islet.zip…'); this.go('idle'); break;
        default: break;
      }
    }

    action(a, el, ev) {
      const d = this.d;
      if (a.startsWith('t:')) { toast(a.slice(2)); if (this.state === 'launcher' || this.state === 'shot' || this.state === 'done') setTimeout(() => this.go('idle'), 350); return; }
      if (a.startsWith('go:')) {
        const s = a.slice(3);
        if (s === 'timer15') this.go('timer', { minutes: 15 });
        else if (s === 'timer') this.go('timer', { minutes: 5 });
        else if (s === 'shot') this.screenshot();
        else this.go(s);
        return;
      }
      switch (a) {
        case 'copy':
          d.copied = true;
          if (navigator.clipboard) navigator.clipboard.writeText('482913').catch(() => {});
          toast('Copied 482913. Try pasting it.');
          this.render(true);
          setTimeout(() => { if (this.state === 'otp') this.go('idle'); }, 1400);
          break;
        case 'play': d.playing = !d.playing; this.go(this.state); break;
        case 'next': case 'prev':
          d.track = (d.track + (a === 'next' ? 1 : TRACKS.length - 1)) % TRACKS.length; d.pos = 0; d.playing = true;
          this.go(this.state);
          break;
        case 'seek': {
          const r = el.getBoundingClientRect();
          const tr = TRACKS[d.track];
          d.pos = Math.round(Math.max(0, Math.min(1, ((ev ? ev.clientX : r.left) - r.left) / r.width)) * tr.dur);
          this.updateLive();
          break;
        }
        case 'tpause': d.timerPaused = !d.timerPaused; this.render(true); break;
        case 'tadd': d.timer += 60; d.timerTotal += 60; this.render(true); break;
        case 'tstop': d.timer = 0; this.go('idle'); break;
        case 'mute': d.micMuted = !d.micMuted; this.render(true); break;
        case 'collapse': this.collapse(); break;
      }
    }

    screenshot() {
      // the island steps out of the shot, the screen flashes, then the screenshot card drops in
      this.wrap.style.transition = 'opacity .12s, transform .25s';
      this.wrap.style.opacity = '0';
      this.glow.style.opacity = '0';
      setTimeout(() => { this.flashEl.classList.remove('go'); void this.flashEl.offsetWidth; this.flashEl.classList.add('go'); }, 160);
      setTimeout(() => { this.wrap.style.opacity = '1'; this.go('shot'); }, 700);
    }

    runDownload() {
      clearInterval(this.dlT);
      this.dlT = setInterval(() => {
        if (this.state !== 'download') { clearInterval(this.dlT); return; }
        this.d.dl = Math.min(100, this.d.dl + 4 + Math.random() * 5);
        this.updateLive();
        if (this.d.dl >= 100) { clearInterval(this.dlT); setTimeout(() => this.go('done'), 250); }
      }, 110);
    }

    // ---- per-second life
    tick() {
      const d = this.d;
      if (d.playing) { d.pos++; if (d.pos >= TRACKS[d.track].dur) { d.pos = 0; d.track = (d.track + 1) % TRACKS.length; if (this.state === 'music' || this.state === 'xmusic') this.render(true); } }
      if (!d.timerPaused && d.timer > 0) d.timer--;
      if (d.focus > 0) d.focus--;
      d.call++;
      if (this.state === 'charging' && d.pct < 100 && Math.random() < .35) d.pct++;
      this.paintClock();
      this.updateLive();
    }

    updateLive() {
      const d = this.d, tr = TRACKS[d.track];
      const set = (k, v) => $$(`[data-live="${k}"]`, this.wrap).forEach((n) => (n.textContent = v));
      const setp = (k, v) => $$(`[data-live-p="${k}"]`, this.wrap).forEach((n) => n.style.setProperty('--p', v));
      set('timer', fmt(d.timer)); setp('timer', 100 - d.timer / d.timerTotal * 100);
      set('focus', fmt(d.focus)); setp('focus', 100 - d.focus / d.focusTotal * 100);
      set('pct', d.pct + '%'); set('call', fmt(d.call)); set('vol', d.vol);
      set('pos', fmt(d.pos)); set('rem', '-' + fmt(tr.dur - d.pos)); setp('pos', d.pos / tr.dur * 100);
      setp('dl', d.dl); set('dlmb', (d.dl / 100 * 1.4).toFixed(1) + ' MB');
    }

    paintClock() {
      const now = new Date();
      $$('[data-clock]', this.host).forEach((n) => (n.textContent = clock(now)));
      $$('[data-clock-big]', this.host).forEach((n) => (n.textContent = clock(now).replace(/\s?[AP]M/i, '')));
      $$('[data-date]', this.host).forEach((n) => (n.textContent = dateStr(now)));
      $$('[data-date-short]', this.host).forEach((n) => (n.textContent = now.toLocaleDateString([], { weekday: 'short', day: 'numeric', month: 'short' })));
      $$('[data-clock-long]', this.host).forEach((n) => (n.textContent = now.toLocaleDateString([], { weekday: 'short', day: 'numeric', month: 'short' }) + '  ' + clock(now)));
    }

    render(sameKey) {
      const key = this.state + ':' + this.device;
      const L = this.layout(this.state);
      const html = this.html(this.state);
      if (sameKey && this.cEl) {
        this.cEl.innerHTML = html;
        this.cEl.style.width = L.w + 'px'; this.cEl.style.height = L.h + 'px';
        this.paintClock();
        return;
      }
      if (key === this.key && this.cEl) { this.cEl.innerHTML = html; this.paintClock(); return; }
      this.key = key;
      const old = this.cEl;
      if (old) { old.classList.remove('in'); old.classList.add('out'); setTimeout(() => old.remove(), 170); }
      const c = document.createElement('div');
      c.className = 'isl-c in';
      c.style.width = L.w + 'px';
      c.style.height = L.h + 'px';
      c.innerHTML = html;
      this.isl.appendChild(c);
      this.cEl = c;
      this.paintClock();
    }

    // ---- motion
    kick() {
      if (reduce) { this.sw.snap(this.sw.t); this.sh.snap(this.sh.t); this.sr.snap(this.sr.t); this.apply(); return; }
      if (this.raf) return;
      this.last = performance.now();
      const loop = (t) => {
        const dt = Math.min(0.05, (t - this.last) / 1000);
        this.last = t;
        const m = this.sw.step(dt) | this.sh.step(dt) | this.sr.step(dt);
        this.apply();
        this.raf = m ? requestAnimationFrame(loop) : 0;
      };
      this.raf = requestAnimationFrame(loop);
    }

    apply() {
      const w = Math.max(10, this.sw.v), h = Math.max(4, this.sh.v), r = Math.max(0, Math.min(this.sr.v, h / 2, w / 2));
      const ears = this.geo.ears;
      this.wrap.style.width = w + 'px';
      this.wrap.style.height = h + 'px';
      this.isl.style.borderRadius = ears ? `0 0 ${r}px ${r}px` : r + 'px';
      this.glow.style.width = w + 'px';
      this.glow.style.height = h + 'px';
      this.glow.style.borderRadius = this.isl.style.borderRadius;
    }
  }

  // ---------------------------------------------------------------- page accent
  const root = document.documentElement;
  function setAccent(a, a2) { root.style.setProperty('--accent', a); root.style.setProperty('--accent2', a2); }

  // ---------------------------------------------------------------- scaling devices to fit
  const fits = [];
  function fitAll() {
    fits.forEach(({ fit, sim, max }) => {
      const dv = DEVICES[sim.device];
      const cw = fit.clientWidth;
      const s = Math.min(max, cw / dv.W);
      sim.host.style.setProperty('--s', s);
      fit.style.height = dv.H * s + 'px';
    });
  }
  addEventListener('resize', fitAll);

  // ---------------------------------------------------------------- hero simulator + autoplay
  const narrow = matchMedia('(max-width: 700px)').matches;
  const os = detectOS();
  const startDevice = narrow || os === 'android' || os === 'ios' ? 'android' : os === 'win' ? 'win' : 'mac';
  const hero = new Sim($('#heroDevice'), { device: startDevice, onLook: (a, a2) => { if (heroVisible) setAccent(a, a2); updateRemote(); } });
  fits.push({ fit: $('#heroFit'), sim: hero, max: 1 });

  const SEQ = [['welcome', 3.4], ['idle', 1], ['message', 3.6], ['idle', .8], ['music', 2.6], ['xmusic', 3.8], ['music', 1.4], ['idle', .9],
               ['charging', 3.4], ['otp', 3.8], ['idle', .8], ['timer', 2.8], ['download', 4.4], ['shot', 4], ['call', 2.8], ['idle', 1.6]];
  let seqI = 0, seqT = 0, userAt = -1e9, heroVisible = true;
  function markUser() { userAt = performance.now(); }
  function autoplay() {
    clearTimeout(seqT);
    const idle = performance.now() - userAt > 14000;
    if (heroVisible && idle && !reduce && document.visibilityState === 'visible') {
      const [s, dur] = SEQ[seqI % SEQ.length];
      seqI++;
      if (s === 'shot') hero.screenshot();
      else if (s === 'timer') hero.go('timer', { minutes: 5 });
      else if (hero.state !== s) hero.go(s);
      seqT = setTimeout(autoplay, dur * 1000 + (s === 'shot' ? 700 : 0));
    } else {
      seqT = setTimeout(autoplay, 1200);
    }
  }
  setTimeout(autoplay, reduce ? 0 : 1300);

  // device tabs
  const seg = $('.seg'), segPill = $('.seg-pill');
  function placeSeg() {
    const b = $('button[aria-selected="true"]', seg);
    segPill.style.width = b.offsetWidth + 'px';
    segPill.style.transform = `translateX(${b.offsetLeft - 4}px)`;
  }
  $$('button', seg).forEach((b) => {
    b.setAttribute('aria-selected', String(b.dataset.device === startDevice));
    b.addEventListener('click', () => {
      markUser();
      $$('button', seg).forEach((x) => x.setAttribute('aria-selected', String(x === b)));
      placeSeg();
      hero.setDevice(b.dataset.device);
    });
  });
  document.fonts && document.fonts.ready.then(placeSeg);
  placeSeg();

  // remote
  const remote = $('#remote');
  function updateRemote() {
    const map = { xmusic: 'music', xtimer: 'timer', xcall: 'call', done: 'download', focus: 'timer' };
    const cur = map[hero.state] || hero.state;
    $$('button', remote).forEach((b) => b.classList.toggle('on', b.dataset.scene === cur));
  }
  $$('button', remote).forEach((b) => b.addEventListener('click', () => {
    markUser();
    const s = b.dataset.scene;
    if (s === 'shot') hero.screenshot();
    else if (s === 'timer') hero.go('timer', { minutes: 5 });
    else if (s === 'volume') { hero.volBack = 'idle'; hero.go('volume'); clearTimeout(hero.volT); hero.volT = setTimeout(() => hero.state === 'volume' && hero.go('idle'), 2200); }
    else hero.go(s);
  }));

  // ---------------------------------------------------------------- a day: scroll story
  const day = new Sim($('#dayDevice'), { device: narrow ? 'android' : 'mac', interactive: false, onLook: (a, a2) => { if (!heroVisible) setAccent(a, a2); } });
  fits.push({ fit: $('#dayFit'), sim: day, max: narrow ? .62 : .7 });
  const dayClock = $('#dayClock');
  const steps = $$('.step');
  const stepObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      steps.forEach((s) => s.classList.toggle('on', s === e.target));
      const sc = e.target.dataset.scene;
      dayClock.textContent = e.target.dataset.time;
      if (sc === 'shot') day.screenshot();
      else day.go(sc, sc === 'timer' ? { minutes: 5 } : {});
    });
  }, { rootMargin: '-45% 0px -45% 0px' });
  steps.forEach((s) => stepObs.observe(s));

  // hero visibility decides who paints the page light
  new IntersectionObserver(([e]) => {
    heroVisible = e.isIntersecting;
    const s = heroVisible ? hero : day;
    const look = LOOK[s.state] || LOOK.idle;
    if (s.state === 'music' || s.state === 'xmusic') setAccent(TRACKS[s.d.track].c, TRACKS[s.d.track].c2);
    else setAccent(look.a, look.a2);
  }, { threshold: 0.15 }).observe($('#heroFit'));

  fitAll();
  requestAnimationFrame(fitAll);

  // ---------------------------------------------------------------- nav: shows where you are
  const navLive = $('#navLiveText');
  const names = { simulator: 'Simulator', day: 'A day with Islet', features: 'Features', download: 'Download', faq: 'Questions' };
  const navObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      navLive.textContent = names[e.target.id] || 'Islet';
      $$('.nav-links a').forEach((a) => a.classList.toggle('on', a.getAttribute('href') === '#' + e.target.id));
    });
  }, { rootMargin: '-40% 0px -55% 0px' });
  ['simulator', 'day', 'features', 'download', 'faq'].forEach((id) => navObs.observe(document.getElementById(id)));

  // the nav slides away while you scroll down (so it never covers the island) and returns when you scroll up
  const navEl = $('#nav');
  let lastY = scrollY;
  addEventListener('scroll', () => {
    const y = scrollY;
    if (y > 160 && y > lastY + 4) navEl.classList.add('away');
    else if (y < lastY - 4 || y < 160) navEl.classList.remove('away');
    lastY = y;
  }, { passive: true });
  navEl.addEventListener('focusin', () => navEl.classList.remove('away'));

  // ---------------------------------------------------------------- downloads
  function detectOS() {
    const ua = navigator.userAgent || '';
    const plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
    if (/android/i.test(ua)) return 'android';
    if (/iphone|ipad|ipod/i.test(ua)) return 'ios';
    if (/mac/i.test(plat) || /mac os x/i.test(ua)) return navigator.maxTouchPoints > 1 ? 'ios' : 'mac';
    if (/win/i.test(plat) || /windows/i.test(ua)) return 'win';
    return null;
  }
  const FILES = { mac: ['/downloads/Islet-Mac.zip', 'Mac'], win: ['/downloads/Islet-Windows.exe', 'Windows'], android: ['/downloads/Islet-Android.apk', 'Android'] };
  const heroBtn = $('#heroDownload'), heroLabel = $('#heroDownloadLabel');
  if (FILES[os]) {
    heroLabel.textContent = 'Download for ' + FILES[os][1];
    heroBtn.href = FILES[os][0];
    heroBtn.setAttribute('download', '');
    heroBtn.addEventListener('click', () => {
      toast(`Downloading Islet for ${FILES[os][1]}. First-open steps are below.`);
      setTimeout(() => $('#download').scrollIntoView({ behavior: reduce ? 'auto' : 'smooth' }), 700);
    });
    const card = $(`.dl[data-os="${os}"]`);
    if (card) {
      card.classList.add('mine');
      const grid = card.parentElement;
      if (matchMedia('(max-width: 1020px)').matches) grid.prepend(card);
    }
  } else if (os === 'ios') {
    $('.hero-note').textContent = 'On iPhone? It already has an island. Get Islet for your Mac, PC or Android.';
  }
  $$('.dl-btn').forEach((b) => b.addEventListener('click', () => {
    const name = FILES[b.dataset.file][1];
    toast(`Downloading Islet for ${name}…`);
  }));
  $$('.sum').forEach((b) => {
    const h = b.dataset.sum;
    b.textContent = `SHA-256 ${h.slice(0, 10)}…${h.slice(-8)} · copy`;
    b.addEventListener('click', () => {
      if (navigator.clipboard) navigator.clipboard.writeText(h).then(() => toast('Checksum copied'), () => toast(h));
      else toast(h);
    });
  });
})();
