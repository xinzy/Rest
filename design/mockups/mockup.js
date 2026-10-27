// 歇会儿 · UI 原型脚本：把 HTML 里的占位元素渲染成 SVG，并处理画廊缩放和截图模式。
// ?only=<画框 id> 进入截图模式：只保留该画框，并放在页面左上角。
// 出现问题时在页面顶部显示红色横幅；capture.sh 会检查横幅，有问题就不截图。

function showProblem(msg) {
  let banner = document.querySelector('.err-banner');
  if (!banner) {
    banner = document.createElement('div');
    banner.className = 'err-banner';
    document.body.prepend(banner);
  }
  const line = document.createElement('div');
  line.className = 'err-line';
  line.textContent = msg;
  banner.append(line);
}

window.addEventListener('error', (e) => showProblem(`原型脚本出错：${e.message}`));

(() => {
  'use strict';

  // 24×24 线性图标，描边 1.8，圆角端点
  const ICONS = {
    drop: '<path d="M12 2.8C9.7 5.6 5.6 10.6 5.6 14.4a6.4 6.4 0 0 0 12.8 0C18.4 10.6 14.3 5.6 12 2.8Z" fill="currentColor" stroke="none"/>',
    eye: '<path d="M2.2 12S5.8 5.5 12 5.5 21.8 12 21.8 12 18.2 18.5 12 18.5 2.2 12 2.2 12Z"/><circle cx="12" cy="12" r="3"/>',
    walk: '<circle cx="13.6" cy="4.3" r="2" fill="currentColor" stroke="none"/><path d="M8.3 11.6 10.7 8.8 12.8 7.9 14.8 10.6 17.2 11.4M12.8 7.9 11.3 13.6M11.3 13.6 9.4 17.2 7.4 20.8M11.3 13.6 13.9 16.5 14.7 21"/>',
    gear: '<circle cx="12" cy="12" r="8.6" stroke-width="2.8" stroke-linecap="butt" stroke-dasharray="3.1 3.654"/><circle cx="12" cy="12" r="6.6"/><circle cx="12" cy="12" r="2.6"/>',
    coffee: '<path d="M4.5 9h11v4.6a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5V9Z"/><path d="M15.5 10.6h1.2a2.6 2.6 0 0 1 0 5.2h-1.5M8 3.6v2.2M11.5 3.6v2.2M3.5 21h13"/>',
    'chev-down': '<path d="M6 9.5 12 15.5 18 9.5"/>',
    'chev-left': '<path d="M14.5 6 8.5 12 14.5 18"/>',
    'chev-right': '<path d="M9.5 6 15.5 12 9.5 18"/>',
    trash: '<path d="M4.5 6.5h15M9.5 6.5V4.8c0-.4.4-.8.8-.8h3.4c.4 0 .8.4.8.8v1.7M6.5 6.5l.9 12.6a1.6 1.6 0 0 0 1.6 1.4h6a1.6 1.6 0 0 0 1.6-1.4l.9-12.6M10 10.5V17M14 10.5V17"/>',
    check: '<path d="M5 12.5 9.5 17 19 7.5"/>',
    mic: '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>',
    moon: '<path d="M20.5 13.8A8.6 8.6 0 1 1 10.2 3.5a6.8 6.8 0 0 0 10.3 10.3Z"/>',
    wifi: '<path d="M2.8 9.2a13.5 13.5 0 0 1 18.4 0M5.9 12.6a9 9 0 0 1 12.2 0M9 16a4.4 4.4 0 0 1 6 0"/><circle cx="12" cy="19.2" r="1.4" fill="currentColor" stroke="none"/>',
    battery: '<rect x="2" y="7.5" width="18" height="9" rx="2.6"/><rect x="3.9" y="9.4" width="11" height="5.2" rx="1.2" fill="currentColor" stroke="none"/><path d="M22.2 10.6v2.8"/>',
    cc: '<rect x="3" y="4.5" width="18" height="6.5" rx="3.25"/><circle cx="7.6" cy="7.75" r="1.6" fill="currentColor" stroke="none"/><rect x="3" y="13" width="18" height="6.5" rx="3.25"/><circle cx="16.4" cy="16.25" r="1.6" fill="currentColor" stroke="none"/>',
    search: '<circle cx="10.5" cy="10.5" r="6.3"/><path d="M15.3 15.3 20.5 20.5"/>',
    chart: '<path d="M4 20.5h16"/><path d="M7.5 16.5v-5M12 16.5V6M16.5 16.5V9.5" stroke-width="2.4"/>',
    power: '<path d="M12 3v8.5M7.2 5.7a8 8 0 1 0 9.6 0"/>',
    pause: '<path d="M9 6v12M15 6v12" stroke-width="2.6"/>',
    play: '<path d="M8 5.2v13.6a.6.6 0 0 0 .9.5l10.6-6.8a.6.6 0 0 0 0-1L8.9 4.7a.6.6 0 0 0-.9.5Z" fill="currentColor" stroke="none"/>',
    undo: '<path d="M9 14.5 4.5 10 9 5.5"/><path d="M4.5 10h10a5 5 0 0 1 0 10H11"/>',
    folder: '<path d="M3.5 7.5a2 2 0 0 1 2-2h4l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2Z"/>',
    doc: '<path d="M6.5 3.5h7l4 4v12a1 1 0 0 1-1 1h-10a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1Z"/><path d="M13.5 3.5v4h4"/>',
    alert: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.4v.1" stroke-width="2.2"/>',
  };

  const STEPPER = '<svg viewBox="0 0 15 22" aria-hidden="true"><path d="M4.5 9 7.5 6 10.5 9M4.5 13l3 3 3-3" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  function need(el, key) {
    const v = el.dataset[key];
    if (v === undefined || v === '') throw new Error(`${el.className} 缺少 data-${key}`);
    return v;
  }

  function num(el, key) {
    const v = Number(need(el, key));
    if (!Number.isFinite(v)) throw new Error(`${el.className} 的 data-${key} 不是数字`);
    return v;
  }

  function icon(name) {
    const body = ICONS[name];
    if (!body) throw new Error(`未知图标：${name}`);
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
  }

  // 菜单栏图标：18×18 模板图，r = 7；进度弧从 12 点方向顺时针，表示剩余时间
  function mbIcon(state, f) {
    const C = 2 * Math.PI * 7;
    const ring = (w) => `<circle cx="9" cy="9" r="7" fill="none" stroke="currentColor" stroke-width="${w}"/>`;
    let body;
    switch (state) {
      case 'working':
        body = `<g opacity=".28">${ring(2)}</g>`;
        if (f > 0) {
          body += `<circle cx="9" cy="9" r="7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-dasharray="${(f * C).toFixed(2)} ${C.toFixed(2)}" transform="rotate(-90 9 9)"/>`;
        }
        break;
      case 'warning':
        body = ring(1.5) + '<circle cx="9" cy="9" r="2.6" fill="currentColor"/>';
        break;
      case 'break':
        body = '<circle cx="9" cy="9" r="7.75" fill="currentColor"/>';
        break;
      case 'paused':
        body = ring(1.5) + '<rect x="6.4" y="6" width="1.7" height="6" rx=".6" fill="currentColor"/><rect x="9.9" y="6" width="1.7" height="6" rx=".6" fill="currentColor"/>';
        break;
      case 'idle':
        body = `<g opacity=".35">${ring(2)}</g>`;
        break;
      default:
        throw new Error(`未知菜单栏图标状态：${state}`);
    }
    return `<svg viewBox="0 0 18 18" aria-hidden="true">${body}</svg>`;
  }

  // 进度环；颜色写在 style 里，这样才能使用 var()
  function ringSVG(size, stroke, f, color, track) {
    const r = (size - stroke) / 2;
    const c = 2 * Math.PI * r;
    const mid = size / 2;
    const arc = f > 0
      ? `<circle cx="${mid}" cy="${mid}" r="${r}" fill="none" style="stroke:${color}" stroke-width="${stroke}" stroke-linecap="round" stroke-dasharray="${(f * c).toFixed(2)} ${c.toFixed(2)}" transform="rotate(-90 ${mid} ${mid})"/>`
      : '';
    return `<svg viewBox="0 0 ${size} ${size}" aria-hidden="true"><circle cx="${mid}" cy="${mid}" r="${r}" fill="none" style="stroke:${track}" stroke-width="${stroke}"/>${arc}</svg>`;
  }

  function renderMenubar(el) {
    const d = el.dataset;
    const menus = need(el, 'menus').split(' ');
    const pressed = 'pressed' in d ? ' pressed' : '';
    el.innerHTML = `
      <div class="mb-left"><span class="apple">\uF8FF</span><b>${need(el, 'app')}</b>${menus.map((m) => `<span>${m}</span>`).join('')}</div>
      <div class="mb-right">
        <span class="mb-item${pressed}"><span class="mb" data-state="${need(el, 'state')}" data-f="${d.f ?? 1}"></span></span>
        <span class="mb-item"><span class="ic" data-ic="wifi"></span></span>
        <span class="mb-item"><span class="ic" data-ic="battery"></span></span>
        <span class="mb-item"><span class="ic" data-ic="search"></span></span>
        <span class="mb-item"><span class="ic" data-ic="cc"></span></span>
        <span class="mb-item clock">${need(el, 'time')}</span>
      </div>`;
  }

  // ---------- 报表图表（示例数据：2026-10-21 周三 至 10-27 周二） ----------

  const DAYS = [['周三', '10/21'], ['周四', '10/22'], ['周五', '10/23'], ['周六', '10/24'], ['周日', '10/25'], ['周一', '10/26'], ['今天', '10/27']];
  const WATER = [6, 8, 9, 5, 8, 4, 3];
  const WATER_GOAL = 8;
  const BREAKS = [[12, 2], [14, 1], [11, 3], [0, 0], [0, 0], [13, 1], [2, 0]]; // [完成, 跳过]

  function topRounded(x, y, w, h, r) {
    if (h <= 0) return '';
    const rr = Math.min(r, w / 2, h);
    return `M${x},${y + h}V${y + rr}Q${x},${y} ${x + rr},${y}H${x + w - rr}Q${x + w},${y} ${x + w},${y + rr}V${y + h}Z`;
  }

  function chartFrame(W, H, ymax, ticks) {
    const L = 30, R = 6, T = 20, B = 40;
    const pw = W - L - R, ph = H - T - B;
    const y = (v) => T + ph - (v / ymax) * ph;
    const slot = pw / DAYS.length;
    const cx = (i) => L + slot * (i + 0.5);
    let grid = '';
    for (const t of ticks) {
      grid += `<line x1="${L}" x2="${W - R}" y1="${y(t)}" y2="${y(t)}" style="stroke:var(--sep)"/>`;
      grid += `<text x="${L - 8}" y="${y(t) + 4}" text-anchor="end">${t}</text>`;
    }
    let xlabels = '';
    DAYS.forEach(([wd, date], i) => {
      const today = i === DAYS.length - 1;
      xlabels += `<text x="${cx(i)}" y="${H - B + 18}" text-anchor="middle"${today ? ' class="cur"' : ''}>${wd}</text>`;
      xlabels += `<text x="${cx(i)}" y="${H - B + 32}" text-anchor="middle" class="xs">${date}</text>`;
    });
    return { L, R, T, B, ph, y, slot, cx, grid, xlabels, bw: Math.min(40, slot * 0.42) };
  }

  function chartWater(W, H) {
    const g = chartFrame(W, H, 10, [0, 2, 4, 6, 8, 10]);
    const today = DAYS.length - 1;
    let s = `<rect x="${g.cx(today) - g.slot * 0.4}" y="${g.T - 14}" width="${g.slot * 0.8}" height="${H - g.T + 10}" rx="8" style="fill:var(--fill)"/>`;
    s += g.grid;
    WATER.forEach((v, i) => {
      const top = g.y(v);
      const met = v >= WATER_GOAL;
      s += `<path d="${topRounded(g.cx(i) - g.bw / 2, top, g.bw, g.y(0) - top, 5)}" style="fill:var(--water)" opacity="${met ? 1 : 0.42}"/>`;
      s += `<text x="${g.cx(i)}" y="${top - 6}" text-anchor="middle" class="val">${v}</text>`;
    });
    const gy = g.y(WATER_GOAL);
    s += `<line x1="${g.L}" x2="${W - g.R}" y1="${gy}" y2="${gy}" style="stroke:var(--water-ink)" stroke-width="1.5" stroke-dasharray="5 4"/>`;
    s += `<text x="${W - g.R}" y="${gy - 6}" text-anchor="end" class="goal">目标 ${WATER_GOAL} 杯</text>`;
    return s + g.xlabels;
  }

  function chartBreaks(W, H) {
    const g = chartFrame(W, H, 20, [0, 5, 10, 15, 20]);
    let s = g.grid;
    BREAKS.forEach(([done, skipped], i) => {
      const x = g.cx(i) - g.bw / 2;
      const yDone = g.y(done);
      const yTop = g.y(done + skipped);
      if (skipped > 0) {
        s += `<rect x="${x}" y="${yDone}" width="${g.bw}" height="${g.y(0) - yDone}" style="fill:var(--green)"/>`;
        s += `<path d="${topRounded(x, yTop, g.bw, yDone - yTop, 5)}" style="fill:var(--orange)"/>`;
      } else {
        s += `<path d="${topRounded(x, yDone, g.bw, g.y(0) - yDone, 5)}" style="fill:var(--green)"/>`;
      }
      if (done + skipped > 0) s += `<text x="${g.cx(i)}" y="${yTop - 6}" text-anchor="middle" class="val">${done + skipped}</text>`;
    });
    return s + g.xlabels;
  }

  const CHARTS = { water: chartWater, breaks: chartBreaks };

  function renderChart(el) {
    const kind = need(el, 'chart');
    const draw = CHARTS[kind];
    if (!draw) throw new Error(`未知图表：${kind}`);
    const W = num(el, 'w');
    const H = num(el, 'h');
    el.innerHTML = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" aria-hidden="true">${draw(W, H)}</svg>`;
  }

  // 面板水平居中到同一画框中被按下的菜单栏图标下方（不超出画框）
  function anchorUnderStatusItem(el) {
    const frame = el.closest('.frame');
    const item = frame.querySelector('.mb-item.pressed');
    if (!item) throw new Error('.anchor 所在画框没有按下的菜单栏图标');
    const fr = frame.getBoundingClientRect();
    const ir = item.getBoundingClientRect();
    const w = el.offsetWidth;
    const center = ir.left - fr.left + ir.width / 2;
    el.style.left = `${Math.round(Math.max(8, Math.min(fr.width - w - 8, center - w / 2)))}px`;
  }

  // 内容超出画框、或窗口里的内容被裁掉时报告问题。
  // 遮罩背景（.ov-scene）故意溢出；带 data-clip 的窗口故意裁掉内容（如编辑器）。
  function checkFit(s) {
    const frame = s.querySelector('.frame');
    const fr = frame.getBoundingClientRect();
    let right = 0;
    let bottom = 0;
    for (const el of frame.querySelectorAll('*')) {
      if (el.closest('.ov-scene') || el.parentElement.closest('[data-clip]')) continue;
      const r = el.getBoundingClientRect();
      if (!r.width && !r.height) continue;
      right = Math.max(right, r.right - fr.left);
      bottom = Math.max(bottom, r.bottom - fr.top);
    }
    if (right > fr.width + 0.5 || bottom > fr.height + 0.5) {
      showProblem(`${s.id}：内容超出画框，内容范围 ${Math.ceil(right)}×${Math.ceil(bottom)}，画框 ${fr.width}×${fr.height}`);
    }
    for (const win of frame.querySelectorAll('.win:not([data-clip])')) {
      const cut = win.scrollHeight - win.clientHeight;
      if (cut > 1) showProblem(`${s.id}：窗口内容被裁掉 ${cut}px`);
    }
  }

  // ---------- 入口 ----------

  const only = new URLSearchParams(location.search).get('only');
  if (only) {
    const target = document.getElementById(only);
    if (!target || !target.matches('section.shot')) throw new Error(`没有这个画框：${only}`);
    document.documentElement.classList.add('capture');
    document.querySelector('.gallery-head')?.remove();
    document.querySelectorAll('section.shot').forEach((s) => s !== target && s.remove());
  }

  for (const s of document.querySelectorAll('section.shot')) {
    const frame = s.querySelector('.frame');
    if (!frame) throw new Error(`${s.id} 缺少 .frame`);
    frame.style.width = `${num(s, 'w')}px`;
    frame.style.height = `${num(s, 'h')}px`;
  }

  document.querySelectorAll('.menubar[data-app]').forEach(renderMenubar);
  document.querySelectorAll('.ic[data-ic]').forEach((el) => { el.innerHTML = icon(el.dataset.ic); });
  document.querySelectorAll('.mb[data-state]').forEach((el) => { el.innerHTML = mbIcon(el.dataset.state, Number(el.dataset.f ?? 1)); });
  document.querySelectorAll('.stepper').forEach((el) => { el.innerHTML = STEPPER; });
  document.querySelectorAll('.ring[data-size]').forEach((el) => {
    const size = num(el, 'size');
    el.style.width = el.style.height = `${size}px`;
    el.insertAdjacentHTML('afterbegin', ringSVG(size, num(el, 'stroke'), num(el, 'f'), need(el, 'color'), need(el, 'track')));
  });
  document.querySelectorAll('.chart[data-chart]').forEach(renderChart);
  document.querySelectorAll('.anchor').forEach(anchorUnderStatusItem);
  document.querySelectorAll('section.shot').forEach(checkFit);

  if (!only) {
    const fit = () => {
      for (const s of document.querySelectorAll('section.shot')) {
        s.querySelector('.frame-wrap').style.zoom = String(Math.min(1, s.clientWidth / Number(s.dataset.w)));
      }
    };
    fit();
    window.addEventListener('resize', fit);
  }

  document.documentElement.dataset.ready = '1';
})();
