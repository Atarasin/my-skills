/**
 * Render-verify a doc-visualizer dashboard in a real browser.
 *
 * 用法：
 *   NODE_PATH="<托管 node workspace>/node_modules" node verify.js <file.html> [shotsDir]
 *
 * 断言：
 *   - 控制台 0 error/warning、0 pageerror
 *   - Alpine 已启动（x-cloak 全部移除、默认标签恰好 1 个面板可见）
 *   - 每个标签都能切到正确面板
 *   - 每张可见 SVG：无元素越出 viewBox、无 text 互相重叠、无 NaN transform、按自然尺寸渲染
 *   - 表格单元格无纵向裁切、页面无横向溢出
 *
 * 标签清单从 HTML 里自动发现（@click="tab='xxx'"），不需要手写 TABS。
 */
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FILE = process.argv[2];
const SHOTS = process.argv[3] || 'shots';
if (!FILE) { console.error('用法: node verify.js <file.html> [shotsDir]'); process.exit(2); }

// SVG 容器类名：本项目统一用 .svg-wrap（历史产物也有用 .mmd-svg 的）
const SVG_WRAP = process.env.SVG_WRAP || '.svg-wrap';

const errors = [];

(async () => {
  fs.mkdirSync(SHOTS, { recursive: true });

  // 从 HTML 里发现标签清单（顺序即文档顺序）
  const raw = fs.readFileSync(FILE, 'utf8');
  const TABS = [...raw.matchAll(/@click="tab='([^']+)'"/g)].map((m) => m[1])
    .filter((v, i, a) => a.indexOf(v) === i);
  if (!TABS.length) { console.error('FATAL: 未在 HTML 中找到 @click="tab=\'...\'" 标签按钮'); process.exit(2); }
  console.log('TABS', JSON.stringify(TABS));

  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--allow-file-access-from-files', '--force-device-scale-factor=1'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 1000 });

  page.on('console', (m) => {
    if (m.type() === 'error' || m.type() === 'warning') errors.push(`[console.${m.type()}] ${m.text()}`);
  });
  page.on('pageerror', (e) => errors.push(`[pageerror] ${e.message}`));

  await page.goto('file:///' + path.resolve(FILE).replace(/\\/g, '/'), { waitUntil: 'networkidle0', timeout: 60000 });
  await new Promise((r) => setTimeout(r, 700));

  // ① Alpine 是否真的启动（挂了会"静默全黑"）
  const boot = await page.evaluate(() => ({
    alpine: typeof window.Alpine !== 'undefined',
    cloakLeft: document.querySelectorAll('[x-cloak]').length,
    visiblePanels: [...document.querySelectorAll('main > div[x-show]')]
      .filter((d) => d.getBoundingClientRect().height > 0).length,
    tabButtons: document.querySelectorAll('main > div button').length,
  }));
  console.log('BOOT', JSON.stringify(boot));
  if (!boot.alpine) errors.push('Alpine 未加载');
  if (boot.cloakLeft !== 0) errors.push(`${boot.cloakLeft} 个 x-cloak 未被移除`);
  if (boot.visiblePanels !== 1) errors.push(`期望恰好 1 个可见面板，实为 ${boot.visiblePanels}`);
  if (boot.tabButtons !== TABS.length) errors.push(`期望 ${TABS.length} 个标签按钮，实为 ${boot.tabButtons}`);

  // ② 逐标签切换 + 截图 + SVG 审计
  for (const tab of TABS) {
    const clicked = await page.evaluate((t, sel) => {
      const btns = [...document.querySelectorAll('main > div button')];
      const btn = btns.find((b) => b.getAttribute('@click') === `tab='${t}'`);
      if (!btn) return false;
      btn.click();
      return true;
    }, tab, SVG_WRAP);
    if (!clicked) { errors.push(`未找到标签按钮: ${tab}`); continue; }
    await new Promise((r) => setTimeout(r, 350));

    const state = await page.evaluate((sel) => {
      const panels = [...document.querySelectorAll('main > div[x-show]')];
      const visible = panels.filter((d) => d.getBoundingClientRect().height > 0);

      // ⚠️ 只审计可见面板里的 SVG：隐藏标签的 SVG 尺寸为 0、getBBox() 退化，会放过真实越界
      const audits = [...document.querySelectorAll(sel + ' svg')]
        .filter((svg) => svg.getBoundingClientRect().width > 0)
        .map((svg) => {
          const [, , vw, vh] = svg.getAttribute('viewBox').split(/\s+/).map(Number);
          const bad = [];
          let nan = 0;

          // ⑦ NaN transform（收紧写法：图注里的 "NaN" 字面量不应触发）
          if (/translate\(undefined|translate\(NaN|,\s*NaN\)/.test(svg.innerHTML)) nan = 1;

          // ③ 越界（含 polyline）
          for (const el of svg.querySelectorAll('rect,text,line,polygon,circle,path,polyline')) {
            let b;
            try { b = el.getBBox(); } catch (e) { continue; }
            if (!isFinite(b.x) || !isFinite(b.y) || !isFinite(b.width)) { nan++; continue; }
            const slack = el.tagName === 'text' ? 1.5 : 0.5;  // text 量的是墨迹外框
            if (b.x < -slack || b.y < -slack ||
                b.x + b.width > vw + slack || b.y + b.height > vh + slack) {
              bad.push(`${el.tagName}[${(el.textContent || '').slice(0, 22)}]` +
                `@${b.x.toFixed(0)},${b.y.toFixed(0)} ${b.width.toFixed(0)}x${b.height.toFixed(0)}`);
            }
          }

          // ③b 文本互相重叠（越界断言抓不到，阈值 25%）
          const texts = [...svg.querySelectorAll('text')].map((el) => {
            const r = el.getBBox();
            return { r, lbl: (el.textContent || '').slice(0, 18) };
          }).filter((t) => isFinite(t.r.width) && t.r.width > 0 && isFinite(t.r.height) && t.r.height > 0);
          for (let i = 0; i < texts.length; i++) {
            for (let j = i + 1; j < texts.length; j++) {
              const a = texts[i].r, b = texts[j].r;
              const ox = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
              const oy = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
              if (ox <= 0 || oy <= 0) continue;
              const ratio = (ox * oy) / Math.min(a.width * a.height, b.width * b.height);
              if (ratio > 0.25) {
                bad.push(`TEXT-OVERLAP "${texts[i].lbl}" x "${texts[j].lbl}" (${Math.round(ratio * 100)}%)`);
              }
            }
          }

          return {
            w: vw, h: vh,
            renderedW: Math.round(svg.getBoundingClientRect().width),
            out: bad, nan,
          };
        });

      // 表格单元格纵向裁切
      const clipped = [...document.querySelectorAll('td, th')].filter(
        (c) => c.scrollHeight > c.clientHeight + 1 && c.clientHeight > 0
      ).length;
      return { visibleCount: visible.length, svgCount: audits.length, audits, clipped };
    }, SVG_WRAP);

    if (state.visibleCount !== 1) errors.push(`标签 ${tab}: ${state.visibleCount} 个可见面板`);
    for (const a of state.audits) {
      if (a.out.length) errors.push(`标签 ${tab}: ${a.out.length} 处 SVG 问题 (viewBox ${a.w}x${a.h}) -> ${a.out.slice(0, 5).join(' | ')}`);
      if (a.nan) errors.push(`标签 ${tab}: SVG 内 ${a.nan} 处 NaN/undefined transform`);
      // ④ 未被缩放（自然尺寸）
      if (a.renderedW !== a.w) errors.push(`标签 ${tab}: SVG 渲染宽 ${a.renderedW}px 但 viewBox 宽 ${a.w}（被缩放）`);
    }
    if (state.clipped) errors.push(`标签 ${tab}: ${state.clipped} 个表格单元格纵向裁切`);

    await page.screenshot({ path: path.join(SHOTS, `${tab}.png`), fullPage: true });
    console.log(`TAB ${tab.padEnd(14)} visible=${state.visibleCount} svgs=${state.svgCount} ` +
      `w=${state.audits.map((a) => a.renderedW).join(',')} clipped=${state.clipped}`);
  }

  // ⑤ 页面不得横向溢出
  const overflow = await page.evaluate(() => ({
    scrollW: document.documentElement.scrollWidth,
    clientW: document.documentElement.clientWidth,
  }));
  console.log('OVERFLOW', JSON.stringify(overflow));
  if (overflow.scrollW > overflow.clientW + 2) {
    errors.push(`页面横向溢出: ${overflow.scrollW} > ${overflow.clientW}`);
  }

  await browser.close();

  console.log('\n===== ERRORS (' + errors.length + ') =====');
  errors.forEach((e) => console.log(' - ' + e));
  process.exit(errors.length ? 1 : 0);
})().catch((e) => { console.error('FATAL', e); process.exit(2); });
