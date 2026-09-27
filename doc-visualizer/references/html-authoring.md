# HTML 编写：技术栈、配色、组件、骨架

## 技术栈（写作期按 CDN 写）

```html
<!-- 写作期：CDN 形态，随手加 utility 类即可，浏览器直接刷新预览 -->
<script src="https://cdn.tailwindcss.com"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js"></script>
```

- ⚠️ **最后一步再决定是否内联**（见 `build-and-verify.md`），写作阶段不要纠结。
- ⚠️ **明暗主题**：跟随当前 IDE/终端主题，**不要凭习惯写死深色 Hero**。浅色主题下所有面板、卡片、图表区都必须浅底深字，深色大色块（如 `bg-slate-900` 顶栏）对比过强；深色主题下反之。浅色主题的默认写法 = `bg-white border-b border-slate-200` 的 header + 页面顶部一条细渐变条。
- ⚠️ **mermaid 只在确实需要时引入**，且必须锁定精确版本（如 `@10.9.8`），不要用 `@10`。**更推荐手写 SVG**（见 `svg-authoring.md`），可一次性绕开 `mermaid-pitfalls.md` 记录的全部坑。

## 颜色语义系统

| 用途 | Tailwind 类 |
|---|---|
| 红线 / 阻断 / 禁止 | `border-red-500 bg-red-50 text-red-800` |
| 警告 / 待处理 | `border-amber-500 bg-amber-50 text-amber-800` |
| 通过 / 已确认 | `border-emerald-500 bg-emerald-50 text-emerald-800` |
| 架构 / 数据 | `border-blue-500 bg-blue-50 text-blue-800` |
| 策略 / 决策 | `border-purple-500 bg-purple-50 text-purple-800` |
| 里程碑主色 | 深色主题 `bg-slate-800 text-white`／浅色主题 `bg-slate-100 text-slate-800 border border-slate-200` |

> ⚠️ **判断"好/坏"的配色按语义走，不要套股市红绿**：本技能产出的多是分析/判决类内容，
> `emerald` = 通过/正向、`red` = 失败/负向，与 A 股"红涨绿跌"习惯相反。若文档本身是行情/收益解读，
> 才按用户所在市场的习惯（A 股：涨红跌绿）着色，且**同一份文件里不要混用两套**。

## 核心组件模式

### 可展开卡片：优先用原生 `<details>`

★ 默认选择：零 JS 风险、零插件依赖、键盘可达，且验证脚本直接 `el.open = true` 即可（不存在"点了又收起"的脚本坑）。

```html
<details class="bg-white rounded-xl border border-slate-200 p-4 shadow-sm">
  <summary class="text-sm font-semibold text-slate-800">
    <span class="chev">&#9656;</span> 机制拆解：钱是怎么亏掉的
  </summary>
  <p class="text-sm text-slate-600 mt-2">展开后的大白话解释</p>
</details>
```

需要 `.chev` 旋转变换与隐藏默认三角的 CSS（见下方骨架）。**只在需要"展开状态参与其它计算"时才改用 Alpine 方案**：

```html
<div x-data="{open:false}" class="border rounded-xl overflow-hidden">
  <button @click="open=!open"
    class="w-full flex items-center gap-3 p-4 bg-slate-800 text-white hover:bg-slate-700">
    <span class="font-mono bg-white/20 px-2 py-0.5 rounded text-sm">M1</span>
    <span class="font-semibold">统一 ETL</span>
    <span class="ml-auto text-xs opacity-70">5 切片 · 22 任务</span>
    <svg class="w-4 h-4 transition-transform" :class="open&&'rotate-180'"
      fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
    </svg>
  </button>
  <div x-show="open" x-collapse class="p-4 space-y-2 bg-slate-50">
    <!-- 切片列表 -->
  </div>
</div>
```

> 注：`x-collapse` 需要 Alpine.js Collapse 插件。不可用时改用 `x-show="open"` + `class="transition-all"`。

### 红线警告卡

```html
<div class="border-l-4 border-red-500 bg-red-50 rounded-r-lg p-4">
  <div class="flex items-start gap-3">
    <span class="text-red-500 text-xl mt-0.5">🚫</span>
    <div>
      <p class="font-semibold text-red-800">红线 1：不产生降仓规则</p>
      <p class="mt-1 text-sm text-red-700">vol 正向预测收益，守卫/择时/regime 降仓四者同因失败已定论。</p>
    </div>
  </div>
</div>
```

### 假设状态卡

```html
<div class="border rounded-xl p-4 hover:shadow-md transition-shadow">
  <div class="flex items-center justify-between mb-2">
    <span class="font-mono font-bold text-lg">H1</span>
    <span class="text-xs px-2 py-1 rounded-full bg-amber-100 text-amber-800 font-medium">待验证</span>
  </div>
  <p class="font-medium text-sm mb-1">镜重圆回撤归因</p>
  <p class="text-xs text-gray-600">事件前窗暴露分位中位数 ≥P80 且 KS p&lt;0.05 → 成立</p>
  <div class="mt-2 pt-2 border-t text-xs text-gray-500">预期结论：M3 实跑后判决</div>
</div>
```

### 架构层叠图（纯 CSS，无需 SVG）

```html
<div class="space-y-1 max-w-lg">
  <div class="bg-purple-100 border-2 border-purple-300 rounded-lg p-3 text-center font-medium">
    策略链路层 · concept_exposure / env_report / 审计钩子
  </div>
  <div class="bg-blue-100 border-2 border-blue-300 rounded-lg p-3 text-center font-medium mx-4">
    观测层 · builder concept 阶段 / reporter / webui
  </div>
  <div class="bg-green-100 border-2 border-green-300 rounded-lg p-3 text-center font-medium mx-8">
    指标层 · market panel / stock heat_rank_pct / lifecycle
  </div>
  <div class="bg-gray-100 border-2 border-gray-300 rounded-lg p-3 text-center font-medium mx-12">
    数据层 · concept_etl / parquet / 三哨兵 / 指纹缓存
  </div>
  <div class="text-center text-xs text-gray-400 mt-1">↑ 每层只读下一层，禁止反向依赖</div>
</div>
```

### 标签页导航

```html
<div x-data="{tab:'overview'}">
  <!-- 标签按钮 -->
  <div class="flex gap-1 border-b mb-6 overflow-x-auto">
    <button @click="tab='overview'"
      :class="tab==='overview'?'border-b-2 border-blue-600 text-blue-600':'text-gray-600'"
      class="px-4 py-2 text-sm font-medium whitespace-nowrap">概览</button>
    <!-- 其余标签... -->
  </div>
  <!-- 各标签内容 -->
  <div x-show="tab==='overview'">...</div>
</div>
```

> ⚠️ `x-data` 必须放在**所有 `x-show` 面板的公共父容器**上，放在子元素上会导致切换全部失效。

## 完整 HTML 骨架

> 推荐组合：**图用手写 SVG**（或 mermaid 预渲染的静态 SVG）+ **Alpine 只管标签切换** + **可展开卡片用原生 `<details>`**。
> 交付前按 `build-and-verify.md` 把两个占位注释替换掉。

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><!-- 文档标题 --></title>
  <!-- 写作期用 CDN；交付前把整个 <style>/*__TAILWIND_CSS__*/</style> 与 <script>/*__ALPINE_JS__*/</script> 内联 -->
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js"></script>
  <style>
    /*__TAILWIND_CSS__*/
  </style>
  <style>
    [x-cloak]{display:none!important}
    /* 手写 SVG / 静态 SVG：自然尺寸 + 卡片内横向滚动（不整图压小）*/
    .svg-wrap{overflow-x:auto}
    .svg-wrap svg{max-width:none;height:auto}
    /* 原生 details 折叠卡：去掉默认三角，用自绘箭头 */
    details>summary{list-style:none;cursor:pointer}
    details>summary::-webkit-details-marker{display:none}
    .chev{display:inline-block;transition:transform .15s ease-out}
    details[open]>summary .chev{transform:rotate(90deg)}
    .fade-in{animation:fade .22s ease-out}
    @keyframes fade{from{opacity:0;transform:translateY(3px)}to{opacity:1;transform:none}}
    .mono{font-family:ui-monospace,Consolas,'Courier New',monospace}
    .tnum{font-variant-numeric:tabular-nums}
    /* 术语悬浮提示（见 rewriting.md）。.tt 是简写，二者用其一即可 */
    .tt,.tooltip-term{border-bottom:1px dashed #94a3b8;cursor:help;color:#475569}
  </style>
</head>
<body class="bg-slate-100 text-slate-900 min-h-screen">

  <!-- 顶部细渐变条：浅色主题下代替深色 Hero 的视觉锚点 -->
  <div class="h-1 bg-gradient-to-r from-violet-500 via-blue-500 to-emerald-500"></div>

  <!-- 顶部 Hero（浅色主题写法：浅底深字）-->
  <header class="bg-white border-b border-slate-200 px-5 py-8">
    <div class="max-w-5xl mx-auto">
      <p class="text-slate-500 text-xs mb-2"><!-- 日期 · 文档性质 --></p>
      <h1 class="text-2xl md:text-3xl font-bold text-slate-900 mb-3 leading-snug"><!-- 标题 --></h1>
      <p class="text-slate-600 max-w-3xl leading-relaxed text-sm md:text-base"><!-- 一句话摘要 --></p>
      <!-- 关键统计数字徽章 -->
      <div class="flex flex-wrap gap-2 mt-5 text-xs md:text-sm">
        <span class="bg-slate-100 text-slate-700 rounded-full px-3 py-1 border border-slate-200">5 条里程碑</span>
        <span class="bg-red-50 text-red-700 rounded-full px-3 py-1 border border-red-200">5 条红线</span>
        <span class="bg-amber-50 text-amber-700 rounded-full px-3 py-1 border border-amber-200">7 个假设</span>
      </div>
    </div>
  </header>

  <!-- 主内容：x-data 必须在所有 x-show 面板的公共父容器上 -->
  <main class="max-w-5xl mx-auto px-4 py-7" x-data="{tab:'overview'}">
    <!-- 标签导航 -->
    <div class="flex gap-1 border-b border-slate-300 mb-6 overflow-x-auto pb-px">
      <button @click="tab='overview'"
        :class="tab==='overview'?'border-b-2 border-blue-600 text-blue-700 bg-white/60':'text-slate-500 hover:text-slate-800'"
        class="px-4 py-2.5 text-sm font-medium whitespace-nowrap rounded-t-lg transition-colors">概览</button>
      <!-- 其余标签... -->
    </div>

    <!-- 标签内容：每个面板都要 x-show + x-cloak -->
    <div x-show="tab==='overview'" x-cloak class="fade-in space-y-6">
      <section class="bg-white rounded-xl border border-slate-200 p-4 shadow-sm">
        <div class="svg-wrap">
          <!-- 手写（或预渲染好的）<svg width="980" height="170" viewBox="0 0 980 170" ...>...</svg> -->
        </div>
      </section>

      <!-- 可展开卡片：原生 details，零 JS 风险 -->
      <details class="bg-white rounded-xl border border-slate-200 p-4 shadow-sm">
        <summary class="text-sm font-semibold text-slate-800">
          <span class="chev">&#9656;</span> 机制拆解：钱是怎么亏掉的
        </summary>
        <p class="text-sm text-slate-600 mt-2"><!-- 展开后的大白话解释 --></p>
      </details>
    </div>
  </main>

  <script>
    /*__ALPINE_JS__*/
  </script>
</body>
</html>
```
