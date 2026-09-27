# 内联构建与渲染验证

## 交付形态怎么选

| 形态 | 特征 | 何时用 |
|---|---|---|
| **离线自包含（推荐）** | Tailwind CSS 与 Alpine.js **编译/内联进单个文件**，零外部请求，断网可开 | 产物要归档、要发给别人、可能被别的编辑器/预览工具打开、内网环境 |
| CDN 形态 | 三个 `<script src="https://…">`，文件小、写作体验最好 | 只是自己在本机快速预览，且确定有网 |

> **判断依据**：打开目标项目的 `.doc-visualizer-output/` 看一眼既有产物——如果是内联的（`grep cdn` 无结果、文件通常 100KB+），**跟随既有约定做内联**；如果是空的或都走 CDN，用 CDN 即可。
> 实务上最优解是**写作按 CDN 写、交付前一步内联**，同一份源两种用途。

两种形态的共同点：无需服务器、浏览器直接打开；支持点击展开/标签切换/悬停提示；中文字符正确渲染（UTF-8）。

---

## 一、离线自包含单文件构建

### ① 本地编译 Tailwind（不要用 Play CDN 的运行时生成）

Play CDN 需要网络、且首屏会闪一下无样式；既有产物是**编译后内联**的。

**零安装优先**：本机托管 node 环境里通常已带 `tailwindcss` 与 `alpinejs`，直接调用：

```bash
NODE_MODULES=<托管 node workspace>/node_modules   # 例：~/.workbuddy/binaries/node/workspace/node_modules
ls "$NODE_MODULES/tailwindcss/lib/cli.js" "$NODE_MODULES/alpinejs/dist/cdn.min.js"
```

没有就装进**临时目录**（不要装进项目，别污染 `node_modules`）：

```bash
mkdir -p /tmp/viz && cd /tmp/viz && npm install tailwindcss@3.4.17 alpinejs@3.14.1
```

> ⚠️ **版本对齐**：`tailwindcss@3.4.17` + `alpinejs@3.14.1` 是既有产物在用的版本。换版本会改变 utility 输出与 Alpine 行为，与同目录其它产物不一致。
> ⚠️ **Tailwind 3.x 与 4.x 的 CLI 用法完全不同**，本文命令只适用 3.x。

**编译**（`tailwind.config.js` 与 `input.css` 直接用 `assets/harness/` 里那两个）：

```bash
SRC_HTML=$PWD/tmp/viz1/src.html \
node "$NODE_MODULES/tailwindcss/lib/cli.js" \
    -c tmp/viz1/tailwind.config.js -i tmp/viz1/input.css -o tmp/viz1/out.css --minify
```

- 自带的 `tailwind.config.js` 从环境变量 **`SRC_HTML`** 读源文件路径，必须传**绝对路径**（相对路径会按 cwd 解析，路径含中文/空格也原样传即可）。
- `input.css` 就三行：`@tailwind base; @tailwind components; @tailwind utilities;`

### ② 源文件留占位注释（正文与构建分离）

```html
<style>
/*__TAILWIND_CSS__*/
</style>
...
<script>
/*__ALPINE_JS__*/
</script>
```

好处：`src.html` 保持可预览，改文案不用重跑编译逻辑。

### ③ 构建脚本替换 + 断言（务必带断言）

```python
html = src.replace("/*__TAILWIND_CSS__*/", css).replace("/*__ALPINE_JS__*/", alpine)
assert "/*__TAILWIND_CSS__*/" not in html and "/*__ALPINE_JS__*/" not in html
for needle in ("cdn.tailwindcss.com", "cdn.jsdelivr.net", "mermaid"):
    assert needle not in html, f"运行时依赖残留: {needle}"   # 内联成功的唯一硬证据
```

> 内联前先确认两件事：`out.css` 不含 `</style>`、`alpine.min.js` 不含 `</script>`（否则会提前闭合标签，页面直接崩）。实测 tailwindcss 3.4.17 输出与 alpinejs 3.14.1 的 `cdn.min.js` 都不含这两个序列，可安全内联。

> **顺带检查产物**：内联后文件通常 100~150KB（Alpine 约 44KB、编译后 CSS 约 16KB，其余是正文与 SVG）。**20KB 左右 = 内联没生效**；**190KB+ 也属正常**（正文长、SVG 张数多）。判据是「有没有 CDN 残留」，不是绝对字节数。

### ④ 落地目录：直接复制本技能自带的 harness

本技能在 `assets/harness/` 下带了**已验证过的通用脚本**，不要每版重新写：

| 文件 | 作用 |
|---|---|
| `build.py` | 内联 CSS/JS + 五道断言（截断自查、占位符、闭合标签、CDN 残留、产物大小） |
| `verify.js` | 全套渲染断言 + 逐标签截图；**标签清单从 HTML 自动发现**，无需手写 TABS |
| `crop.js` | 按 `选择器 + 索引` 2× 定向裁剪，用于目检 |
| `input.css` | 三行 `@tailwind` 指令 |
| `tailwind.config.js` | 从环境变量 `SRC_HTML` 读源文件**绝对路径** |

每做一版就在项目 `tmp/` 下开一个新目录（`tmp/viz<N>/`，N 递增），把这 5 个文件连同 `src.html`、`p1/p2/p3.html` 分段源一起放进去：

```bash
HARNESS=<本技能目录>/assets/harness
cp "$HARNESS"/{build.py,verify.js,crop.js,input.css,tailwind.config.js} tmp/viz1/
```

完整流程：

```bash
NODE_MODULES=<托管 node workspace>/node_modules
SRC_HTML=$PWD/tmp/viz1/src.html node "$NODE_MODULES/tailwindcss/lib/cli.js" \
    -c tmp/viz1/tailwind.config.js -i tmp/viz1/input.css -o tmp/viz1/out.css --minify
python tmp/viz1/build.py tmp/viz1/src.html tmp/viz1/out.css .doc-visualizer-output/<name>.html
NODE_PATH="$NODE_MODULES" node tmp/viz1/verify.js .doc-visualizer-output/<name>.html tmp/viz1/shots
NODE_PATH="$NODE_MODULES" node tmp/viz1/crop.js  .doc-visualizer-output/<name>.html tmp/viz1/crops overview .svg-wrap
```

好处：**改一处坐标只需重跑 `build.py` + `verify.js`**，源与产物、断言与目检四件事各自独立。**不要 `npm install` 到项目里** —— 从托管 node 环境调用（见①）。非默认 Chrome 路径用 `CHROME_PATH` 环境变量覆盖；换了 SVG 容器类名用 `SVG_WRAP` 覆盖。

### ★ 长页面必须分段写

单次写入约 **25k token 就会被截断**（表现为文件尾部凭空缺一段、HTML 不闭合，且工具仍报成功）。超过 6 个标签或含 6 张以上 SVG 的页面，拆成 `p1.html`/`p2.html`/`p3.html` 分段写，再 `cat p1.html p2.html p3.html > src.html` 拼接。

- 拆分点选在**标签容器边界**最安全（每个 `p<i>.html` 内部自闭合）；
- `<style>/*__TAILWIND_CSS__*/</style>` 留在 `p1`，`/*__ALPINE_JS__*/` 留在最后一段；
- 拼完不要手工核对 —— 直接交给 `build.py`（它会拒绝不以 `</html>` 结尾的源），再跑 `verify.js`（它会核对标签数）。

---

## 二、渲染验证（写入后必做）

**目检不算验证。**缩略整页截图看不出 2px 裁切，干净环境里的截图也看不出宿主页 CSS 污染。用脚本 + 真实浏览器断言。

puppeteer-core + 本机 Chrome（`C:/Program Files/Google/Chrome/Application/chrome.exe`；Linux/macOS 换成对应路径，或按 `mermaid-pitfalls.md` 坑 4 下载 chrome-for-testing）。

### ① Alpine 是否真的启动

只看控制台干净不够——Alpine 挂了所有面板都是隐藏的，页面会"静默全黑"。这条能抓住。

```js
const boot = {
  alpine: typeof window.Alpine !== 'undefined',
  cloakLeft: document.querySelectorAll('[x-cloak]').length,      // 应为 0
  visiblePanels: [...document.querySelectorAll('main > div[x-show]')]
    .filter(d => d.getBoundingClientRect().height > 0).length,   // 应为 1
};
```

### ② 逐标签切换 + 断言"恰好 1 个面板可见"

```js
// ⚠️ 用 @click 属性值精确定位按钮，不要按下标取（会随标签顺序变化而错位）
[...document.querySelectorAll('main > div button')]
  .find(b => b.getAttribute('@click') === `tab='${t}'`).click();
```

### ③ SVG 越界断言（抓得到肉眼看不见的裁切）

```js
// ⚠️ 只查"可见面板里"的 svg —— 隐藏标签的 svg getBoundingClientRect() 为 0、
//    getBBox() 退化，会把真实越界全部放过（这个坑实际漏检过一整轮）
const svgs = [...document.querySelectorAll('.svg-wrap svg')]
  .filter(s => s.getBoundingClientRect().width > 0);
for (const svg of svgs) {
  const [, , vw, vh] = svg.getAttribute('viewBox').split(/\s+/).map(Number);
  // ⚠️ polyline 也要放进选择器，否则折线溢出查不出来
  for (const el of svg.querySelectorAll('rect,text,line,polygon,circle,path,polyline')) {
    const b = el.getBBox();
    const slack = el.tagName === 'text' ? 1.5 : 0.5;   // text 量的是墨迹外框，留点余量
    if (b.x < -slack || b.y < -slack || b.x + b.width > vw + slack || b.y + b.height > vh + slack)
      console.log('OUT', el.tagName, b.x, b.y, b.width, b.height);
  }
}
```

> `getBBox()` 对路径/直线量的是几何外框；对 `text` 量的是**实际墨迹外框**（含字形上下伸部），所以 text 的 slack 给大一点。断言只报不抛，靠"输出为空"判定通过。
>
> ⚠️ **③ 只覆盖"超出画布"，覆盖不了"文字压文字"** —— 见下面 ③b，两者必须都跑。

### ③b 文本互相重叠断言

越界断言完全抓不到文字叠字（实测漏检过两版）。

```js
// ⚠️ 写在上面同一个 for (const svg of svgs) 循环体内（复用同一份"仅可见面板"过滤），
//    不要另起一个 getBBox 遍历 —— 隐藏标签会退化、结果不可信。
// 做法：同一 SVG 内所有 text 两两求交，交集面积 > 较小框的 25% 即报。
// 阈值 25% 是实测调出来的：再低会误报成组柱状图的相邻数值标签，再高会放过"半遮半掩"。
const texts = [...svg.querySelectorAll('text')].map(el => {
  const r = el.getBBox();
  return { r, lbl: (el.textContent || '').slice(0, 18) };
}).filter(t => isFinite(t.r.width) && t.r.width > 0 && isFinite(t.r.height) && t.r.height > 0);
for (let i = 0; i < texts.length; i++) {
  for (let j = i + 1; j < texts.length; j++) {
    const a = texts[i].r, b = texts[j].r;
    const ox = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
    const oy = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
    if (ox <= 0 || oy <= 0) continue;
    const ratio = (ox * oy) / Math.min(a.width * a.height, b.width * b.height);
    if (ratio > 0.25) console.log('TEXT-OVERLAP', ratio.toFixed(2), texts[i].lbl, 'x', texts[j].lbl);
  }
}
```

> ⚠️ 旋转的 `text` 在重叠检测里用的**同样是旋转前的框**，所以纵轴标题除了被越界断言误报，还可能与本不相干的左侧刻度标签产生**假交叠**。正解见 `svg-authoring.md` 第 5 条——**把标题缩到 ≤4 字**、并与刻度标签留 ≥16px 间距，而不是在断言里给某类元素开口子。
>
> 💡 想少踩这两类问题，最省事的写法是：**每个 `<text>` 只承担一件事、单行、短**。长句拆成多行 `<text>`，宽度先估算再落坐标。

### ④ 未被缩放的断言（SVG 按自然尺寸渲染）

给 1px 容差（subpixel 布局）：

```js
Math.abs(svg.getBoundingClientRect().width - Number(svg.getAttribute('width'))) <= 1
```

### ⑤ 页面不得横向溢出

移动端/窄屏友好的底线：

```js
document.documentElement.scrollWidth <= document.documentElement.clientWidth + 2
```

### ⑥ 控制台 0 错误

监听 console 的 `error`/`warning` 与 `pageerror` 事件（含 NaN 刷屏）。

### ⑦ NaN 检查（mermaid 图专用）

```js
// ⚠️ 写紧一点：只需匹配真实的 transform 异常。
//    宽写法 /translate\(undefined|NaN/ 会被图注里的 "NaN" 字面量（如引述术语「NaN 保持」）误报。
/translate\(undefined|translate\(NaN|,\s*NaN\)/.test(svg.innerHTML)
```

### 两个脚本坑（都实际踩过）

- **`page.$('.svg-wrap svg')` 取的是文档序第一个**。切到非首个标签后该元素 `display:none`，`ElementHandle.screenshot()` 直接抛 `Node is either not visible or not an HTMLElement`。正解：用 `page.evaluateHandle()` 选 `getBoundingClientRect().width > 0` 的那个，再 `.asElement()`。
- **所有审计必须限定在可见面板内**（见 ③ 的注释）。

### 收尾

- 展开折叠卡片用 `Alpine.$data(card).open = true`（幂等），**不要循环 `button.click()`** —— 验证脚本每个标签页点一遍展开按钮，会把前一个标签页已展开的卡片再点回收起，轮到目标标签页时恰好全是收起状态，截图误判"展开失败"。
  > 若卡片用的是原生 `<details>`（**推荐，零 JS 风险**），直接设 `el.open = true` 即可，不存在这个问题。
- **按自然分辨率 2× 裁剪放大目检**：断言与裁剪是**互补而非冗余**的关系——断言查的是坐标层面的冲突，**查不出**「文字在窄列里被挤断行」「卡片网格里长副标题撑破卡片」这类排版问题。因此裁剪脚本要**支持按选择器 + 索引取第 N 个目标**（如 `crop.js <html> <out> <tab> <selector> <index>`），并且**至少覆盖两类区域**：
  1. 每张 SVG（看文字是否完整、有无假交叠）；
  2. **窄列区域**——4 列读数卡网格、多列表格、以及任何「数字 + 单位 + 副标题」挤在一起的小卡片。这类问题在 1200px 整页缩略图上完全看不出来。
  > 定位口径参考：`.svg-wrap` 取全部 SVG；`section` 取标签页内的卡片（按索引取需要的那张）。
  > ⚠️ 切到非首个标签后再裁剪时，必须用 `getBoundingClientRect().width > 0` 过滤可见目标，否则会截到隐藏标签里尺寸退化的元素。
- 每轮改完**重跑全套**（改一处坐标可能让别处越界，编译产物也要重建）。
