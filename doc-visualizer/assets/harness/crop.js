/**
 * 2× 定向裁剪：把某个标签页里的第 N 个目标元素单独截出来目检。
 *
 * 用法：
 *   NODE_PATH="<托管 node workspace>/node_modules" \
 *   node crop.js <file.html> <outDir> <tab> [selector] [index]
 *
 *   selector 默认 'section'（页面卡片的常见容器）；'.svg-wrap' 取全部 SVG；
 *   index 省略时截该选择器下所有可见目标，给数字则只截第 N 个（从 0 起）。
 *
 * 为什么必须做：越界/重叠断言只查坐标冲突，查不出「文字在窄列里被挤断行」
 * 「卡片网格里长副标题撑破卡片」这类排版问题，而它们在 1200px 整页缩略图上完全看不出来。
 */
const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');

const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FILE = process.argv[2];
const OUT = process.argv[3] || 'shots';
const TAB = process.argv[4] || 'overview';
const SEL = process.argv[5] || 'section';
const IDX = process.argv[6] !== undefined ? Number(process.argv[6]) : -1;

if (!FILE) { console.error('用法: node crop.js <file.html> <outDir> <tab> [selector] [index]'); process.exit(2); }

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--force-device-scale-factor=2'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 1200, deviceScaleFactor: 2 });
  await page.goto('file:///' + path.resolve(FILE).replace(/\\/g, '/'), { waitUntil: 'networkidle0' });
  await new Promise((r) => setTimeout(r, 500));

  const ok = await page.evaluate((t) => {
    const btn = [...document.querySelectorAll('main > div button')]
      .find((b) => b.getAttribute('@click') === `tab='${t}'`);
    if (!btn) return false;
    btn.click();
    return true;
  }, TAB);
  if (!ok) { console.error('未找到标签:', TAB); await browser.close(); process.exit(1); }
  await new Promise((r) => setTimeout(r, 400));

  // ⚠️ 必须按可见性过滤：隐藏标签里的元素尺寸退化，直接截会抛
  //    "Node is either not visible or not an HTMLElement"
  const n = await page.evaluate((sel) =>
    [...document.querySelectorAll(sel)].filter((d) => d.getBoundingClientRect().width > 0).length
  , SEL);
  console.log('可见目标数:', n, '| selector:', SEL, '| tab:', TAB);
  if (!n) { await browser.close(); process.exit(1); }

  const list = IDX >= 0 ? [IDX] : [...Array(n).keys()];
  for (const i of list) {
    const h = await page.evaluateHandle((sel, idx) =>
      [...document.querySelectorAll(sel)].filter((d) => d.getBoundingClientRect().width > 0)[idx]
    , SEL, i);
    const el = h.asElement();
    if (!el) continue;
    const name = `crop_${TAB}_${SEL.replace(/[^a-zA-Z0-9]/g, '')}_${i + 1}.png`;
    await el.screenshot({ path: path.join(OUT, name) });
    console.log('shot', name);
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
