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
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const narrow = matchMedia('(max-width: 640px)').matches;

  // ---------------------------------------------------------------- toast
  const toastEl = $('#toast');
  let toastT;
  function toast(msg) {
    toastEl.textContent = msg;
    toastEl.classList.add('on');
    clearTimeout(toastT);
    toastT = setTimeout(() => toastEl.classList.remove('on'), 2600);
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
  // device glyphs for buttons and cards (generic shapes, no brand marks)
  const OSI = {
    mac: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4.5" y="5" width="15" height="10.5" rx="1.8"/><path d="M2.5 18.5h19"/></svg>',
    win: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="2"/><path d="M12 16v3.5M8 19.5h8"/></svg>',
    android: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="6.8" y="2.5" width="10.4" height="19" rx="2.6"/><path d="M11 5.4h2"/></svg>',
    any: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19.5h14"/></svg>',
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

  // ---------------------------------------------------------------- wallpaper: blue silk (original artwork)
  let wallN = 0;
  function silk() {
    const u = 'w' + (++wallN);
    return `<svg viewBox="0 0 1600 1000" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs>
      <linearGradient id="b${u}" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#0a2797"/><stop offset=".5" stop-color="#1a50ea"/><stop offset="1" stop-color="#5a90ff"/></linearGradient>
      <radialGradient id="g${u}" cx=".8" cy=".08" r=".6"><stop offset="0" stop-color="#d4e4ff" stop-opacity=".95"/><stop offset="1" stop-color="#d4e4ff" stop-opacity="0"/></radialGradient>
      <linearGradient id="r1${u}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#a9c8ff"/><stop offset=".4" stop-color="#3471ff"/><stop offset="1" stop-color="#0b2ea6"/></linearGradient>
      <linearGradient id="r2${u}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#eef4ff"/><stop offset=".3" stop-color="#7aa7ff"/><stop offset="1" stop-color="#1745d4"/></linearGradient>
      <linearGradient id="r3${u}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7ea9ff"/><stop offset="1" stop-color="#0c2c9f"/></linearGradient>
      <linearGradient id="r4${u}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c4d9ff" stop-opacity=".9"/><stop offset="1" stop-color="#2a63f5" stop-opacity=".2"/></linearGradient>
      <filter id="s${u}" x="-5%" y="-20%" width="110%" height="140%"><feGaussianBlur stdDeviation="5"/></filter>
      <filter id="d${u}" x="-5%" y="-20%" width="110%" height="140%"><feGaussianBlur stdDeviation="22"/></filter>
    </defs>
    <rect width="1600" height="1000" fill="url(#b${u})"/>
    <rect width="1600" height="1000" fill="url(#g${u})"/>
    <path d="M-60 520C260 330 600 620 940 450S1480 170 1700 250L1700 330C1460 260 1150 520 930 560S300 450-60 650Z" fill="url(#r4${u})" opacity=".55"/>
    <path d="M-60 650C300 430 640 770 990 570S1510 300 1700 380L1700 540C1480 470 1160 720 970 740S300 620-60 830Z" fill="url(#r3${u})"/>
    <path d="M-60 690C320 470 660 820 1020 600S1520 340 1700 410" fill="none" stroke="#000a40" stroke-width="40" opacity=".18" filter="url(#d${u})"/>
    <path d="M-60 770C340 570 700 910 1060 700S1520 480 1700 550L1700 720C1500 650 1200 880 1020 900S360 780-60 980Z" fill="url(#r1${u})"/>
    <path d="M-60 900C380 720 760 1030 1120 850S1540 650 1700 710L1700 1060-60 1060Z" fill="url(#r2${u})"/>
    <path d="M-60 770C340 570 700 910 1060 700S1520 480 1700 550" fill="none" stroke="#eaf2ff" stroke-width="3" opacity=".75" filter="url(#s${u})"/>
    <path d="M-60 900C380 720 760 1030 1120 850S1540 650 1700 710" fill="none" stroke="#fff" stroke-width="2.5" opacity=".7" filter="url(#s${u})"/>
    <path d="M-60 650C300 430 640 770 990 570S1510 300 1700 380" fill="none" stroke="#d6e5ff" stroke-width="2" opacity=".55" filter="url(#s${u})"/>
    </svg>`;
  }
  const THUMB = 'linear-gradient(165deg,#b9d1ff 0%,#4a82ff 38%,#1747db 70%,#0a2797 100%)';

  const APPS = [
    ['Files', 'linear-gradient(135deg,#ffd54f,#f0a500)'], ['Browser', 'linear-gradient(135deg,#2dd4bf,#0a84ff)'],
    ['Music', 'linear-gradient(135deg,#ff7a90,#ff375f)'], ['Chat', 'linear-gradient(135deg,#3ee07a,#12a150)'],
    ['Mail', 'linear-gradient(135deg,#6cb8ff,#1c6ef2)'], ['Settings', 'linear-gradient(135deg,#a1a1aa,#52525b)'],
    ['Photos', 'linear-gradient(135deg,#fbbf24,#ec4899)'], ['Notes', 'linear-gradient(135deg,#fde68a,#f59e0b)'],
  ];
  const dockIcons = (n) => APPS.slice(0, n).map((a) => `<i style="--g:${a[1]}"></i>`).join('');
  const EDGES = '<i class="edge l"></i><i class="edge r"></i><i class="edge t"></i>';

  const DEVICES = {
    mac: {
      W: 1060, H: 651,
      html: () => `<div class="mac"><div class="mac-lid">${EDGES}<div class="screen"><div class="wall">${silk()}</div>
        <div class="menubar"><div class="l"><b>Finder</b><span>File</span><span>Edit</span><span>View</span><span>Go</span><span>Window</span></div>
        <div class="r">${I.batt}${I.wifi}${I.search}<span data-clock-long></span></div></div>
        <div class="mac-dock">${dockIcons(8)}</div><div class="flash"></div></div></div><div class="mac-base"></div></div>`,
      geo: { top: 0, ears: true, nw: 184, nh: 32, reserve: 32, gap: 184, card: 450, xm: 490, ln: 580, cr: 12, er: 28 },
    },
    win: {
      W: 980, H: 656,
      html: () => `<div class="win"><div class="win-mon">${EDGES}<i class="edge b"></i><div class="win-bezel"><div class="screen"><div class="wall">${silk()}</div>
        <div class="task"><span class="start">${I.spark}</span>${dockIcons(5)}<span class="clock"><span data-clock></span><br><span data-date-short></span></span></div><div class="flash"></div></div></div></div>
        <div class="win-neck"></div><div class="win-foot"></div></div>`,
      geo: { top: 10, ears: false, nw: 0, nh: 36, reserve: 0, gap: 0, card: 450, xm: 490, ln: 560, cr: 18, er: 32 },
    },
    android: {
      W: 412, H: 854,
      html: () => `<div class="android"><div class="phone">${EDGES}<div class="screen"><div class="wall">${silk()}</div>
        <div class="status"><span data-clock></span><span class="r">${I.signal}${I.wifi}${I.batt}</span></div>
        <div class="ph-clock" data-clock-big></div><div class="ph-date" data-date></div>
        <div class="ph-apps">${dockIcons(8)}</div><div class="cam"></div><div class="flash"></div></div></div></div>`,
      geo: { top: 9, ears: false, nw: 112, nh: 36, reserve: 36, gap: 112, card: 368, xm: 368, ln: 368, cr: 18, er: 32 },
    },
  };

  const TRACKS = [
    { t: 'Lunar Drift', a: 'Blue Static', art: 'linear-gradient(135deg,#7fb2ff,#1f5eff 55%,#0a2797)', c: '#6aa0ff', c2: '#2b6dff', dur: 214 },
    { t: 'Golden Hour', a: 'Sunset Avenue', art: 'linear-gradient(135deg,#ffb347,#ff5f6d)', c: '#ffa25f', c2: '#ff5f6d', dur: 187 },
    { t: 'Ocean Eyes', a: 'The Night Owls', art: 'linear-gradient(135deg,#43e3c4,#2b6dff)', c: '#4fd1ff', c2: '#2b6dff', dur: 241 },
  ];

  // glow colours per moment
  const LOOK = {
    welcome: ['#3df5c8', '#7a5cff', '#ff5cc8', .9], message: ['#34c759', '#7ce8a0', '#0fa968', .85], otp: ['#34c759', '#3df5c8', '#0fa968', .85],
    charging: ['#34c759', '#a3e635', '#22c55e', 1], timer: ['#ff9f0a', '#ffd166', '#ff6b35', .5], xtimer: ['#ff9f0a', '#ffd166', '#ff6b35', .5],
    focus: ['#34c759', '#3df5c8', '#86efac', .5], shot: ['#a78bfa', '#22d3ee', '#f472b6', .8], download: ['#0a84ff', '#22d3ee', '#6366f1', .45],
    done: ['#0a84ff', '#22d3ee', '#6366f1', .8], call: ['#34c759', '#7ce8a0', '#0fa968', .45], xcall: ['#34c759', '#7ce8a0', '#0fa968', .45],
    launcher: ['#8ab4ff', '#7a5cff', '#3df5c8', .35],
  };

  // ---------------------------------------------------------------- the simulator
  class Sim {
    constructor(host, opts = {}) {
      this.host = host;
      this.device = opts.device || 'mac';
      this.interactive = opts.interactive !== false;
      this.onUser = opts.onUser || (() => {});
      this.onState = opts.onState || (() => {});
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
        this.go(this.state);
        this.host.classList.remove('swap');
        fitAll();
      }, reduce ? 0 : 260);
    }

    bind() {
      this.wrap.addEventListener('click', (e) => {
        const b = e.target.closest('[data-a]');
        this.onUser();
        if (b) { e.stopPropagation(); this.action(b.dataset.a, b, e); return; }
        this.tapBody();
      });
      this.wrap.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); this.onUser(); this.tapBody(); } });
      this.wrap.addEventListener('mouseenter', () => { if (this.state === 'idle') this.go('peek'); });
      this.wrap.addEventListener('mouseleave', () => { if (this.state === 'peek') this.go('idle'); });
      this.wrap.addEventListener('wheel', (e) => {
        if (['launcher', 'xmusic'].includes(this.state)) return;
        e.preventDefault();
        this.onUser();
        this.d.vol = clamp(this.d.vol + (e.deltaY < 0 ? 4 : -4), 0, 100);
        if (this.state !== 'volume') { this.volBack = this.state === 'peek' ? 'idle' : this.state; this.go('volume'); }
        else { const b = $('.vbar', this.wrap); if (b) b.style.setProperty('--v', this.d.vol); const n = $('[data-live="vol"]', this.wrap); if (n) n.textContent = this.d.vol; }
        clearTimeout(this.volT);
        this.volT = setTimeout(() => { if (this.state === 'volume') this.go(this.volBack || 'idle'); }, 1500);
      }, { passive: false });
      this.screen.addEventListener('click', (e) => {
        if (this.wrap.contains(e.target)) return;
        if (['launcher', 'xmusic', 'xtimer', 'xcall'].includes(this.state)) { this.onUser(); this.collapse(); }
      });
    }

    layout(s) {
      const g = this.geo, wing = { music: 66, call: 78, focus: 92, timer: 76, download: 98, charging: 96, volume: 104, peek: 96 }[s] || 0;
      const compact = (w) => ({ w: g.ears || this.device === 'android' ? g.nw + 2 * w : Math.max(300, 160 + 2 * w), h: g.nh, r: g.cr });
      const card = (h, w = g.card) => ({ w, h: g.reserve + h + (g.reserve ? 0 : 6), r: g.er });
      switch (s) {
        case 'idle': return { w: g.ears ? g.nw : this.device === 'win' ? 196 : g.nw, h: g.nh, r: g.ears ? 10 : g.cr };
        case 'peek': return this.device === 'win' ? { w: 290, h: g.nh, r: g.cr } : compact(wing);
        case 'music': case 'call': case 'focus': case 'timer': case 'download': case 'charging': case 'volume': return compact(wing);
        case 'welcome': return card(this.device === 'android' ? 66 : 70);
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

    html(s) {
      const g = this.geo, d = this.d, tr = TRACKS[d.track];
      const gap = g.gap;
      const row = (l, r, m = '') => `<div class="c-row${gap ? '' : ' flat'}" style="--gap:${gap}px"><div class="l">${l}</div><div class="m">${gap ? '' : m}</div><div class="r">${r}</div></div>`;
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
          return row(`<span style="color:var(--iblue)">${I.down}</span>`,
                     `<span style="font-size:12px;color:rgba(255,255,255,.6)" data-live="dlmb">${(d.dl / 100 * 1.4).toFixed(1)} MB</span><span class="ring" style="--c:var(--iblue);--p:${d.dl}" data-live-p="dl"></span>`,
                     `<span>Islet.zip</span>`);
        case 'volume':
          return row(`<span>${d.vol ? I.vol : I.mute}</span>`,
                     `<span class="vbar" style="--v:${d.vol}"><b></b></span><span style="font-size:12px;width:22px;text-align:right" data-live="vol">${d.vol}</span>`, '');
        case 'welcome':
          return below(`<div class="cardx"><span class="ico" style="background:rgba(61,245,200,.16);color:#3df5c8">${I.spark}</span>
            <div class="tx"><div class="ti">Hi, I'm Islet</div><div class="bo">${this.device === 'android' ? 'Tap me to open the launcher.' : 'Tap me to open the launcher. Scroll on me for volume.'}</div></div></div>`);
        case 'message':
          return below(`<div class="cardx"><span class="ico" style="background:linear-gradient(135deg,#3ee07a,#12a150)">${I.msg}</span>
            <div class="tx"><div class="meta">Messages · now</div><div class="ti">Priya</div><div class="bo">Still on for dinner at 8? I booked the table 🍽️</div></div></div>`);
        case 'otp':
          return below(`<div class="cardx" style="align-items:center"><span class="ico" style="background:rgba(52,199,89,.18);color:#6ee38c">${I.lock}</span>
            <div class="tx"><div class="meta">Your Bank · now</div><div class="ti">482913 is your code</div><div class="bo">Valid for 10 minutes.</div></div>
            <button class="pill g otp" data-a="copy">${d.copied ? I.check + 'Copied' : I.copy + '482 913'}</button></div>`);
        case 'shot':
          return below(`<div class="cardx"><span class="shot-th" style="--th:${THUMB}" draggable="true" title="Drag me"></span>
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

    go(s, opts = {}) {
      if (s === 'xtimer' || s === 'xcall' || s === 'xmusic') this.prev = this.state === 'peek' ? 'idle' : this.state;
      if (s === 'timer' && opts.minutes) { this.d.timer = this.d.timerTotal = opts.minutes * 60; this.d.timerPaused = false; }
      if (s === 'focus' && opts.fresh) this.d.focus = this.d.focusTotal;
      if (s === 'download' && this.state !== 'download') { this.d.dl = 0; this.runDownload(); }
      if (s === 'call' && !['call', 'xcall'].includes(this.state)) this.d.call = 0;
      if (s === 'otp') this.d.copied = false;
      this.state = s;
      const L = this.layout(s);
      this.sw.to(L.w); this.sh.to(L.h); this.sr.to(L.r);
      let look = LOOK[s];
      if (s === 'music' || s === 'xmusic') { const t = TRACKS[this.d.track]; look = [t.c, t.c2, t.c, this.d.playing ? .7 : 0]; }
      if (look) {
        this.glow.style.setProperty('--g1', look[0]); this.glow.style.setProperty('--g2', look[1]); this.glow.style.setProperty('--g3', look[2]);
        this.glow.style.opacity = look[3];
      } else this.glow.style.opacity = 0;
      this.onState(s);
      this.render();
      this.kick();
    }

    collapse() {
      const back = { xmusic: 'music', xtimer: this.prev === 'focus' ? 'focus' : 'timer', xcall: 'call' }[this.state];
      this.go(back || 'idle');
    }

    tapBody() {
      switch (this.state) {
        case 'idle': case 'peek': case 'welcome': this.go('launcher'); break;
        case 'music': this.go('xmusic'); break;
        case 'timer': case 'focus': this.go('xtimer'); break;
        case 'call': this.go('xcall'); break;
        case 'launcher': case 'xmusic': case 'xtimer': case 'xcall': this.collapse(); break;
        case 'message': toast('Opening Messages…'); this.go('idle'); break;
        case 'charging': case 'volume': this.go('idle'); break;
        case 'done': toast('Opening Islet.zip…'); this.go('idle'); break;
        default: break;
      }
    }

    action(a, el, ev) {
      const d = this.d;
      if (a.startsWith('t:')) { toast(a.slice(2)); if (['launcher', 'shot', 'done'].includes(this.state)) setTimeout(() => this.go('idle'), 350); return; }
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
          d.pos = Math.round(clamp(((ev ? ev.clientX : r.left) - r.left) / r.width, 0, 1) * TRACKS[d.track].dur);
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
      this.wrap.style.transition = 'opacity .12s';
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

  // ---------------------------------------------------------------- fit devices to their column
  const fits = [];
  function fitAll() {
    fits.forEach(({ fit, sim, max }) => {
      const dv = DEVICES[sim.device];
      const s = Math.min(typeof max === 'function' ? max(sim.device) : max, fit.clientWidth / dv.W);
      sim.host.style.setProperty('--s', s);
      fit.style.height = dv.H * s + 'px';
    });
  }
  addEventListener('resize', fitAll);

  // ---------------------------------------------------------------- platform
  function detectOS() {
    const ua = navigator.userAgent || '';
    const plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
    if (/android/i.test(ua)) return 'android';
    if (/iphone|ipad|ipod/i.test(ua)) return 'ios';
    if (/mac/i.test(plat) || /mac os x/i.test(ua)) return navigator.maxTouchPoints > 1 ? 'ios' : 'mac';
    if (/win/i.test(plat) || /windows/i.test(ua)) return 'win';
    return null;
  }
  const os = detectOS();
  const isMac = os === 'mac' || os === 'ios';
  const FILES = {
    mac: { href: '/downloads/Islet-Mac.zip', name: 'Mac', meta: 'v1.0 · macOS 14 or later · Free' },
    win: { href: '/downloads/Islet-Windows.exe', name: 'Windows', meta: 'v1.0 · Windows x64 · Free' },
    android: { href: '/downloads/Islet-Android.apk', name: 'Android', meta: 'v1.6 · Android 8.0 or later · Free' },
  };
  $$('[data-os-icon]').forEach((n) => { n.innerHTML = OSI[n.dataset.osIcon || os] || OSI.any; });

  // ---------------------------------------------------------------- HERO: a big tilted device, straightening as you scroll
  const heroDev = narrow || os === 'android' || os === 'ios' ? 'android' : os === 'mac' ? 'mac' : 'win';
  let heroUserAt = -1e9;
  const hero = new Sim($('#heroDevice'), { device: heroDev, onUser: () => { heroUserAt = performance.now(); } });
  fits.push({ fit: $('#heroFit'), sim: hero, max: (d) => (d === 'android' ? (narrow ? .78 : .9) : 1.08) });

  const HSEQ = [['welcome', 3.4], ['idle', .9], ['music', 2.4], ['xmusic', 3.8], ['music', 1.3], ['message', 3.6], ['idle', .8],
                ['charging', 3.2], ['otp', 3.6], ['idle', .8], ['timer', 2.8], ['download', 4.2], ['idle', 1.4]];
  let hI = 0, heroVisible = true;
  (function heroAuto() {
    const idle = performance.now() - heroUserAt > 12000;
    if (heroVisible && idle && !reduce && document.visibilityState === 'visible') {
      const [s, dur] = HSEQ[hI++ % HSEQ.length];
      if (s === 'timer') hero.go('timer', { minutes: 5 }); else if (hero.state !== s) hero.go(s);
      setTimeout(heroAuto, dur * 1000);
    } else setTimeout(heroAuto, 1200);
  })();
  new IntersectionObserver(([e]) => { heroVisible = e.isIntersecting; }, { threshold: .1 }).observe($('#heroFit'));

  const heroTilt = $('#heroTilt');
  const RY = heroDev === 'android' ? 18 : 26, RX = heroDev === 'android' ? 6 : 5;
  let mx = 0, my = 0, cmx = 0, cmy = 0, tiltRaf = 0;
  function tiltFrame() {
    tiltRaf = 0;
    cmx += (mx - cmx) * .08; cmy += (my - cmy) * .08;
    const p = reduce ? .4 : clamp(scrollY / (innerHeight * .55), 0, 1);
    const e = 1 - Math.pow(1 - p, 2);
    const ry = RY * (1 - e) + cmx * 3, rx = RX * (1 - e) - cmy * 2;
    heroTilt.style.transform = `rotateX(${rx.toFixed(2)}deg) rotateY(${ry.toFixed(2)}deg) translateZ(0)`;
    if (Math.abs(mx - cmx) > .002 || Math.abs(my - cmy) > .002) tiltRaf = requestAnimationFrame(tiltFrame);
  }
  const queueTilt = () => { if (!tiltRaf) tiltRaf = requestAnimationFrame(tiltFrame); };
  addEventListener('scroll', queueTilt, { passive: true });
  if (!reduce && matchMedia('(hover: hover)').matches) {
    addEventListener('pointermove', (e) => { mx = e.clientX / innerWidth * 2 - 1; my = e.clientY / innerHeight * 2 - 1; queueTilt(); }, { passive: true });
  }
  tiltFrame();

  // ---------------------------------------------------------------- MODES: tabs drive the island
  const modesDev = narrow || os === 'android' || os === 'ios' ? 'android' : os === 'mac' ? 'mac' : 'win';
  let modesUserAt = -1e9;
  const modes = new Sim($('#modesDevice'), { device: modesDev, onUser: () => { modesUserAt = performance.now(); stopTab(); } });
  fits.push({ fit: $('#modesFit'), sim: modes, max: (d) => (d === 'android' ? (narrow ? .7 : .62) : .7) });

  const TABS = {
    music: [['music', 1.5], ['xmusic', 4.3]],
    focus: [['focus', 1.6], ['xtimer', 4.2]],
    alerts: [['message', 4.6], ['idle', .8]],
    codes: [['otp', 5.4]],
    charging: [['charging', 5.2]],
    shot: [['shot', 5.4]],
  };
  const ORDER = Object.keys(TABS);
  const tabBtns = $$('#tabs button');
  let tabTimers = [], curTab = null, modesVisible = false, nextAuto = 0;
  function stopTab() {
    tabTimers.forEach(clearTimeout); tabTimers = [];
    tabBtns.forEach((b) => { const p = $('.tprog', b); p.style.transition = 'none'; p.style.setProperty('--tp', 0); });
  }
  function playTab(name, auto) {
    stopTab();
    curTab = name;
    tabBtns.forEach((b) => b.setAttribute('aria-selected', String(b.dataset.tab === name)));
    const steps = TABS[name];
    const total = steps.reduce((a, s) => a + s[1], 0);
    let t = 0;
    steps.forEach(([s, dur]) => {
      const at = t;
      tabTimers.push(setTimeout(() => {
        if (s === 'shot') modes.screenshot();
        else if (s === 'focus') modes.go('focus', { fresh: true });
        else modes.go(s);
      }, at * 1000));
      t += dur;
    });
    const bar = $('.tprog', tabBtns.find((b) => b.dataset.tab === name));
    if (auto && !reduce) {
      requestAnimationFrame(() => { bar.style.transition = `--tp ${total}s linear`; bar.style.setProperty('--tp', 1); });
      tabTimers.push(setTimeout(() => { if (modesVisible) playTab(ORDER[(ORDER.indexOf(name) + 1) % ORDER.length], true); else nextAuto = 1; }, total * 1000));
    }
  }
  tabBtns.forEach((b) => b.addEventListener('click', () => {
    modesUserAt = performance.now();
    playTab(b.dataset.tab, false);
    // resume the tour a little later
    tabTimers.push(setTimeout(() => { if (performance.now() - modesUserAt >= 13900 && modesVisible) playTab(ORDER[(ORDER.indexOf(b.dataset.tab) + 1) % ORDER.length], true); }, 14000));
  }));
  // start the tour when the section shows up; resume after a pause in interaction
  new IntersectionObserver(([e]) => {
    modesVisible = e.isIntersecting;
    if (modesVisible && (!curTab || nextAuto) && performance.now() - modesUserAt > 14000) { nextAuto = 0; playTab(curTab ? ORDER[(ORDER.indexOf(curTab) + 1) % ORDER.length] : 'music', true); }
  }, { threshold: .35 }).observe($('#modesFit'));
  setInterval(() => {
    if (modesVisible && !tabTimers.length && performance.now() - modesUserAt > 14000) playTab(curTab ? ORDER[(ORDER.indexOf(curTab) + 1) % ORDER.length] : 'music', true);
  }, 2000);

  // device switch
  const seg = $('#seg'), segPill = $('.seg-pill', seg);
  function placeSeg() {
    const b = $('button[aria-selected="true"]', seg);
    if (!b) return;
    segPill.style.width = b.offsetWidth + 'px';
    segPill.style.transform = `translateX(${b.offsetLeft - 4}px)`;
  }
  $$('button', seg).forEach((b) => {
    b.setAttribute('aria-selected', String(b.dataset.device === modesDev));
    b.addEventListener('click', () => {
      $$('button', seg).forEach((x) => x.setAttribute('aria-selected', String(x === b)));
      placeSeg();
      modes.setDevice(b.dataset.device);
    });
  });
  if (document.fonts) document.fonts.ready.then(() => { placeSeg(); fitAll(); });
  placeSeg();

  // gentle 3D settle as the device arrives
  const modesTilt = $('#modesTilt'), modesStage = $('.modes-stage');
  function modesFrame() {
    const r = modesStage.getBoundingClientRect();
    const q = reduce ? 1 : clamp((innerHeight - r.top) / (innerHeight * .75), 0, 1);
    const e = 1 - Math.pow(1 - q, 3);
    modesTilt.style.transform = `rotateX(${(18 * (1 - e)).toFixed(2)}deg) translateY(${(40 * (1 - e)).toFixed(1)}px)`;
  }
  addEventListener('scroll', () => requestAnimationFrame(modesFrame), { passive: true });
  modesFrame();

  fitAll();
  requestAnimationFrame(fitAll);

  // ---------------------------------------------------------------- SHORTCUT: keys press, launcher types
  const keyEls = { ctrl: $('.key[data-k="ctrl"]'), alt: $('.key[data-k="alt"]'), space: $('.key[data-k="space"]') };
  if (isMac) {
    keyEls.ctrl.style.display = 'none';
    $('b', keyEls.alt).textContent = '⌥ Option';
    keyEls.alt.classList.add('wide');
    $('#scTitle').textContent = 'Two keys. One shortcut.';
    $('#scHint').innerHTML = 'Try it here: press <kbd>⌥ Option</kbd> <kbd>Space</kbd>';
  }
  if (!matchMedia('(hover: hover)').matches) $('#scHint').style.display = 'none';
  const typedEl = $('#typed'), enterIc = $('#enterIc'), resultEl = $('#scResult'), scTime = $('#scTime'), field = $('.field');
  const comboKeys = isMac ? ['alt', 'space'] : ['ctrl', 'alt', 'space'];
  let scToken = 0, scVisible = false, scLoopT = 0, countT = 0;
  function press(k, on) { keyEls[k].classList.toggle('down', on); }
  async function scRun(fromUser) {
    const tok = ++scToken;
    clearTimeout(scLoopT); clearInterval(countT);
    const alive = () => tok === scToken;
    typedEl.textContent = ''; resultEl.classList.remove('on'); enterIc.classList.remove('hit');
    if (!fromUser) {
      for (const k of comboKeys) { press(k, true); await sleep(170); if (!alive()) return; }
      await sleep(420); if (!alive()) return;
      comboKeys.forEach((k) => press(k, false));
    }
    field.classList.add('focus');
    await sleep(380); if (!alive()) return;
    for (const ch of '10m') { typedEl.textContent += ch; await sleep(170); if (!alive()) return; }
    await sleep(320); if (!alive()) return;
    enterIc.classList.add('hit');
    await sleep(220); if (!alive()) return;
    enterIc.classList.remove('hit');
    resultEl.classList.add('on');
    let left = 600; scTime.textContent = fmt(left);
    countT = setInterval(() => { left--; scTime.textContent = fmt(left); }, 1000);
    await sleep(3800); if (!alive()) return;
    clearInterval(countT);
    field.classList.remove('focus'); resultEl.classList.remove('on'); typedEl.textContent = '';
    if (scVisible && !reduce) scLoopT = setTimeout(() => scRun(false), 1400);
  }
  new IntersectionObserver(([e]) => {
    const was = scVisible;
    scVisible = e.isIntersecting;
    if (scVisible && !was) scRun(false);
  }, { threshold: .4 }).observe($('#keys'));

  // the real keys work too
  const held = new Set();
  const keyName = (e) => (e.code === 'Space' ? 'space' : e.key === 'Control' ? 'ctrl' : e.key === 'Alt' ? 'alt' : null);
  addEventListener('keydown', (e) => {
    const k = keyName(e);
    if (k && keyEls[k] && keyEls[k].style.display !== 'none') { held.add(k); press(k, true); }
    const combo = isMac ? e.altKey && e.code === 'Space' : e.ctrlKey && e.altKey && e.code === 'Space';
    if (combo) {
      e.preventDefault();
      if (scVisible) { scRun(true); toast("That's the one. In Islet it opens the launcher."); }
      else { modes.go('launcher'); toast('Launcher opened on the simulator.'); }
    }
  });
  addEventListener('keyup', (e) => { const k = keyName(e); if (k) { held.delete(k); press(k, false); } });
  addEventListener('blur', () => { held.clear(); Object.keys(keyEls).forEach((k) => press(k, false)); });

  // ---------------------------------------------------------------- reveal on scroll
  const rvObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); rvObs.unobserve(e.target); } });
  }, { rootMargin: '0px 0px -8% 0px' });
  $$('.rv').forEach((el) => {
    const sibs = [...el.parentElement.children].filter((c) => c.classList.contains('rv'));
    el.style.setProperty('--rd', Math.min(5, sibs.indexOf(el)) * 70 + 'ms');
    rvObs.observe(el);
  });

  // ---------------------------------------------------------------- nav
  const navEl = $('#nav');
  const onScrollNav = () => navEl.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScrollNav, { passive: true });
  onScrollNav();
  const navMap = { overview: 'overview', modes: 'modes', shortcut: 'shortcut', download: 'download', faq: 'download' };
  const secObs = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      const id = navMap[e.target.id];
      $$('.links a').forEach((a) => a.classList.toggle('on', a.getAttribute('href') === '#' + id));
    });
  }, { rootMargin: '-45% 0px -50% 0px' });
  Object.keys(navMap).forEach((id) => { const el = document.getElementById(id); if (el) secObs.observe(el); });

  // ---------------------------------------------------------------- downloads
  const heroBtn = $('#heroDownload'), ctaBtn = $('#ctaDownload');
  if (FILES[os]) {
    const f = FILES[os];
    $('#heroLabel').textContent = 'Download for ' + f.name;
    $('#ctaLabel').textContent = 'Download for ' + f.name;
    $('#heroMeta').textContent = f.meta;
    $('#ctaMeta').textContent = f.meta.replace(' · Free', '');
    [heroBtn, ctaBtn].forEach((b) => {
      b.href = f.href; b.setAttribute('download', '');
      b.addEventListener('click', () => {
        toast(`Downloading Islet for ${f.name}. Setup steps are in Download.`);
        setTimeout(() => $('#download').scrollIntoView({ behavior: reduce ? 'auto' : 'smooth' }), 800);
      });
    });
    const card = $(`.dl[data-os="${os}"]`);
    card.classList.add('mine');
    if (matchMedia('(max-width: 1020px)').matches) card.parentElement.prepend(card);
  } else if (os === 'ios') {
    $('#heroMeta').textContent = 'On iPhone? It already has an island. Get Islet for your Mac, PC or Android.';
  }
  $('#seeAction').addEventListener('click', () => { modesUserAt = -1e9; });
  $$('.dl-btn').forEach((b) => b.addEventListener('click', () => toast(`Downloading Islet for ${FILES[b.dataset.file].name}…`)));
  $$('.sum').forEach((b) => {
    const h = b.dataset.sum;
    b.textContent = `SHA-256 ${h.slice(0, 10)}…${h.slice(-8)} · copy`;
    b.addEventListener('click', () => {
      if (navigator.clipboard) navigator.clipboard.writeText(h).then(() => toast('Checksum copied'), () => toast(h));
      else toast(h);
    });
  });
})();
