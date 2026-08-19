# 核心组件模式与页面骨架

生成 HTML 前必读。所有组件基于 Tailwind CDN + Alpine.js；颜色语义遵循 SKILL.md 的颜色语义系统。

## 目录

- 里程碑可展开卡片
- 红线警告卡
- 假设状态卡
- 架构层叠图
- Mermaid 依赖图（源文本写法）
- 雷区折叠列表
- 标签页导航
- 页面整体 HTML 骨架（含迭代历史面板插槽）
- 模式 A 专用：Hero 状态徽章、页内反馈与导出（可点选决策卡 / 可填写澄清卡 / 导出栏）

## 里程碑可展开卡片

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
> 注：`x-collapse` 需要 Alpine.js Collapse 插件。若不可用，改用 `x-show="open"` 加 `class="transition-all"`。

## 红线警告卡

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

## 假设状态卡

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

## 架构层叠图

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

## Mermaid 依赖图（源文本写法）

这是图的**源文本**；最终 HTML 里推荐预渲染成静态 SVG 内嵌（见 mermaid.md），不要保留 `<pre class="mermaid">`。

```html
<div class="overflow-x-auto">
<pre class="mermaid">
graph LR
  M0[M0 前置实验\nP0+P1] --> M2
  M1[M1 统一ETL] --> M2[M2 观测层]
  M2 --> M3[M3 策略链路]
  M3 --> M4[M4 审计仓管]
  M5[M5 二期\n独立预注册]
  style M0 fill:#fef3c7
  style M5 fill:#f3f4f6,stroke-dasharray:5
</pre>
</div>
```

## 雷区折叠列表

```html
<div x-data="{open:false}">
  <button @click="open=!open"
    class="flex items-center gap-2 text-amber-800 font-semibold hover:text-amber-600">
    <span>⚠️ R1 — OPTIONAL 门禁嵌在 leverage.enabled 下</span>
    <span x-text="open?'▲':'▼'" class="text-xs"></span>
  </button>
  <div x-show="open" class="mt-2 text-sm text-gray-700 pl-6 border-l-2 border-amber-300">
    <p><strong>位置：</strong> builder.py:198-207</p>
    <p><strong>规避：</strong> concept 必须独立 config.concept.enabled 条件块</p>
  </div>
</div>
```

## 标签页导航

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

## 页面整体 HTML 骨架（含迭代历史面板插槽）

> 推荐：图用**预渲染静态 SVG**（见 mermaid.md），骨架里没有任何 mermaid 运行时引用。
> 若坚持运行时 mermaid：加回锁版本的 CDN `<script>` + `mermaid.initialize({startOnLoad:false,...})`，并在 `<main>` 上加懒渲染逻辑（见 mermaid.md 坑 3）。

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><!-- 文档标题 --></title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js"></script>
  <style>
    [x-cloak]{display:none!important}
    .tab-content{display:none}
    /* 静态 SVG 图：横向可滚动、等比缩放 */
    .mmd-svg{overflow-x:auto}
    .mmd-svg svg{max-width:100%;height:auto}
  </style>
</head>
<body class="bg-gray-50 text-gray-900 min-h-screen">

  <!-- 顶部 Hero -->
  <header class="bg-gradient-to-r from-slate-900 to-slate-700 text-white px-6 py-8">
    <div class="max-w-5xl mx-auto">
      <p class="text-slate-400 text-sm mb-1"><!-- 日期 --></p>
      <h1 class="text-2xl font-bold mb-2"><!-- 标题 --></h1>
      <p class="text-slate-300 max-w-2xl"><!-- 一句话摘要 --></p>
      <!-- 关键统计数字徽章 -->
      <div class="flex flex-wrap gap-2 mt-4">
        <span class="bg-white/10 rounded-full px-3 py-1 text-sm">5 条里程碑</span>
        <span class="bg-red-500/30 rounded-full px-3 py-1 text-sm">5 条红线</span>
        <span class="bg-amber-500/30 rounded-full px-3 py-1 text-sm">7 个假设</span>
        <!-- 状态徽章：评审中(amber) / 已定稿(emerald)，见"模式 A 专用组件"；模式 B 写"阅读版"即可 -->
        <span class="bg-amber-500/30 rounded-full px-3 py-1 text-sm">评审中 · 第 2 轮 · 2 个决策待定</span>
      </div>
    </div>
  </header>

  <!-- 主内容 -->
  <main class="max-w-5xl mx-auto px-4 py-8" x-data="{tab:'overview'}">
    <!-- 标签导航："迭代记录"永远固定在最后一项 -->
    <div class="flex gap-1 border-b mb-6 overflow-x-auto">
      <button @click="tab='overview'"
        :class="tab==='overview'?'border-b-2 border-blue-600 text-blue-600':'text-gray-600'"
        class="px-4 py-2 text-sm font-medium whitespace-nowrap">概览</button>
      <!-- 其余内容标签...（本轮有改动的标签按钮带"RN 更新"角标，见 SKILL.md） -->
      <button @click="tab='history'"
        :class="tab==='history'?'border-b-2 border-blue-600 text-blue-600':'text-gray-600'"
        class="px-4 py-2 text-sm font-medium whitespace-nowrap">迭代记录</button>
    </div>

    <!-- 内容标签：图直接放静态 SVG -->
    <div x-show="tab==='overview'" x-cloak>
      <div class="overflow-x-auto bg-white border border-gray-200 rounded-xl p-4">
        <div class="mmd-svg"><!-- 此处为预渲染好的 <svg>...</svg> --></div>
      </div>
    </div>
    <!-- 其余标签内容... -->

    <!-- 迭代历史面板：结构见 SKILL.md"迭代历史面板"一节，数据生成时写死 -->
    <div x-show="tab==='history'" x-cloak class="space-y-4">
      <!-- 按 round 倒序的轮次卡片 -->
    </div>
  </main>

  <!-- 模式 A 且评审中：此处必须插入导出栏 + 兜底弹窗 + 导出脚本（见"页内反馈与导出"）；已定稿则不放 -->
</body>
</html>
```


## 模式 A 专用组件

### Hero 状态徽章

替换骨架 Hero 里的迭代信息徽章，二选一：

```html
<!-- 评审中（amber）：N 为当前轮次，n 为待定决策数量，无待定决策时省略后半句 -->
<span class="bg-amber-500/30 rounded-full px-3 py-1 text-sm">评审中 · 第 2 轮 · 2 个决策待定</span>

<!-- 已定稿（emerald） -->
<span class="bg-emerald-500/30 rounded-full px-3 py-1 text-sm">已定稿 · 正式文档：2026-08-19_概念数据接入.md</span>
```

### 页内反馈与导出（草图阶段的核心交互）

目标：用户在页面上直接点选方案、填写回答，确认后一键导出结构化反馈文本发给 AI，省去"逐条打字描述"的来回。

三类元素：**待定决策卡（D 编号，点选）**、**澄清问题卡（Q 编号，填写）**、**底部导出栏**。统一用 `data-fb` 编号挂载，导出脚本直接读 DOM（不依赖 Alpine 状态，最不容易出错）。

#### 待定决策卡（可点选）

```html
<div class="border-2 border-dashed border-amber-400 bg-amber-50 rounded-xl p-4"
     data-fb="D2" data-title="依赖图怎么渲染">
  <div class="flex items-center gap-2 flex-wrap">
    <span class="font-mono bg-amber-200 text-amber-900 px-2 py-0.5 rounded text-sm font-bold">D2</span>
    <span class="font-semibold text-amber-900">依赖图怎么渲染：静态图片还是运行时动态生成？</span>
    <span class="fb-badge text-xs px-2 py-1 rounded-full font-medium ml-auto bg-amber-100 text-amber-800">等你拍板</span>
  </div>
  <div class="mt-3 grid sm:grid-cols-2 gap-3">
    <button type="button" onclick="fbPick(this)" data-opt="方案A"
      class="fb-opt text-left bg-white rounded-lg p-3 border border-gray-200 hover:border-amber-400 transition">
      <p class="font-medium text-sm">方案 A：生成时把图转成静态 SVG 嵌进页面</p>
      <p class="text-xs text-gray-600 mt-1">优点：任何环境都能打开、永不出错；缺点：图内容变了要重新生成</p>
    </button>
    <button type="button" onclick="fbPick(this)" data-opt="方案B"
      class="fb-opt text-left bg-white rounded-lg p-3 border border-gray-200 hover:border-amber-400 transition">
      <p class="font-medium text-sm">方案 B：页面加载时用 mermaid 库现场画图</p>
      <p class="text-xs text-gray-600 mt-1">优点：源文本留在页面里好维护；缺点：被其他工具打开时可能报错</p>
    </button>
  </div>
  <input class="fb-note mt-2 w-full text-sm rounded-lg border border-amber-200 bg-white px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-amber-300"
    placeholder="备注（可选）">
  <p class="mt-2 text-xs text-amber-700">默认建议：方案 A（更稳）。不选则按默认建议落实。</p>
</div>
```

#### 澄清问题卡（可填写）

```html
<div class="border-2 border-dashed border-blue-400 bg-blue-50 rounded-xl p-4"
     data-fb="Q1" data-title="数据更新频率">
  <div class="flex items-center gap-2 flex-wrap">
    <span class="font-mono bg-blue-200 text-blue-900 px-2 py-0.5 rounded text-sm font-bold">Q1</span>
    <span class="font-semibold text-blue-900">需要你补充：底层数据多久更新一次？</span>
  </div>
  <textarea class="fb-answer mt-2 w-full text-sm rounded-lg border border-blue-200 bg-white px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-300"
    rows="2" placeholder="直接填写，例如：每天凌晨批量更新"></textarea>
</div>
```

#### 已定决策卡（静态，不进入导出）

用户拍板后的迭代里，把对应卡换成这个静态版本（**去掉 `data-fb`**，不可再点选）：

```html
<div class="border-2 border-emerald-400 bg-emerald-50 rounded-xl p-4">
  <div class="flex items-center gap-2 flex-wrap">
    <span class="font-mono bg-emerald-200 text-emerald-900 px-2 py-0.5 rounded text-sm font-bold">D2</span>
    <span class="font-semibold text-emerald-900">依赖图怎么渲染：静态图片还是运行时动态生成？</span>
    <span class="text-xs px-2 py-1 rounded-full bg-emerald-100 text-emerald-800 font-medium ml-auto">已定：方案 A · 第 2 轮</span>
  </div>
  <p class="mt-2 text-sm text-emerald-800">按评审意见定为方案 A。落选方案 B 的原因：被外部工具打开时可能报错。</p>
</div>
```

#### "待定决策"标签页底部：其他意见输入框

```html
<textarea id="fbExtra" rows="3" placeholder="其他意见（可选）：整体性的想法直接写在这里，导出时会一并带上"
  class="w-full text-sm rounded-xl border border-gray-300 bg-white px-4 py-3 focus:outline-none focus:ring-2 focus:ring-slate-300"></textarea>
```

#### 导出栏 + 兜底弹窗 + 导出脚本（评审中的页面必须完整包含）

```html
<!-- 悬浮导出栏（fixed，右下角） -->
<div class="fixed bottom-4 right-4 z-50 flex items-center gap-2 bg-slate-800 text-white rounded-full shadow-xl px-4 py-2 text-sm">
  <span id="fbCount" class="text-xs text-slate-300"></span>
  <button onclick="exportFeedback('copy')" class="bg-emerald-500 hover:bg-emerald-400 rounded-full px-3 py-1 font-medium">复制评审反馈</button>
  <button onclick="exportFeedback('download')" class="bg-white/10 hover:bg-white/20 rounded-full px-3 py-1">下载 .md</button>
</div>

<!-- file:// 下剪贴板可能失败：兜底弹窗手动复制 -->
<div id="fbModal" class="hidden fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
  <div class="bg-white rounded-xl p-4 w-full max-w-lg">
    <p class="text-sm font-medium mb-2">自动复制失败，请手动全选复制：</p>
    <textarea id="fbText" class="w-full h-48 text-xs border rounded-lg p-2" readonly></textarea>
    <button onclick="document.getElementById('fbModal').classList.add('hidden')" class="mt-2 text-sm text-blue-600">关闭</button>
  </div>
</div>

<script>
// 生成时写死：当前文档名与轮次
const FB_DOC = '概念数据接入方案';
const FB_ROUND = 2;

function fbPick(btn){
  const card = btn.closest('[data-fb]');
  card.querySelectorAll('.fb-opt').forEach(b=>{
    b.classList.remove('fb-selected','border-emerald-500','ring-2','ring-emerald-200');
    b.classList.add('border-gray-200');
  });
  btn.classList.add('fb-selected','border-emerald-500','ring-2','ring-emerald-200');
  btn.classList.remove('border-gray-200');
  const badge = card.querySelector('.fb-badge');
  if(badge){
    badge.textContent = '已选：' + btn.dataset.opt;
    badge.className = 'fb-badge text-xs px-2 py-1 rounded-full font-medium ml-auto bg-emerald-100 text-emerald-800';
  }
  fbRefresh();
}
function fbRefresh(){
  const cards = document.querySelectorAll('[data-fb]');
  let done = 0;
  cards.forEach(c=>{
    const picked = !!c.querySelector('.fb-selected');
    const filled = ((c.querySelector('.fb-answer')||{}).value||'').trim().length > 0;
    if(picked || filled) done++;
  });
  document.getElementById('fbCount').textContent = '已处理 ' + done + '/' + cards.length;
}
function buildFeedback(){
  const L = ['【评审反馈】《' + FB_DOC + '》第 ' + FB_ROUND + ' 轮'];
  document.querySelectorAll('[data-fb]').forEach(c=>{
    const id = c.dataset.fb, title = c.dataset.title || '';
    const sel = c.querySelector('.fb-selected');
    const note = ((c.querySelector('.fb-note')||{}).value||'').trim();
    const ans = ((c.querySelector('.fb-answer')||{}).value||'').trim();
    if(c.querySelector('.fb-opt')){
      L.push(id + ' ' + title + '：' + (sel ? '选「' + sel.dataset.opt + '」' : '未选择（按默认建议）') + (note ? '（备注：' + note + '）' : ''));
    }else{
      L.push(id + ' ' + title + '：' + (ans || '（未填写）'));
    }
  });
  const extra = (document.getElementById('fbExtra')||{value:''}).value.trim();
  if(extra) L.push('其他意见：' + extra);
  return L.join('\n');
}
async function exportFeedback(mode){
  const text = buildFeedback();
  if(mode === 'download'){
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([text], {type:'text/markdown'}));
    a.download = '评审反馈_第' + FB_ROUND + '轮.md';
    a.click();
    return;
  }
  try{
    await navigator.clipboard.writeText(text);
    alert('已复制，粘贴回对话发给我即可');
  }catch(e){
    document.getElementById('fbText').value = text;
    document.getElementById('fbModal').classList.remove('hidden');
  }
}
document.addEventListener('input', fbRefresh);
fbRefresh();
</script>
```

规则：
- D 编号（决策）与 Q 编号（澄清）各自全程连续、不复用；每张待定卡必须有唯一 `data-fb`
- 决策卡选项用 `<button>`，点选走 `fbPick(this)`；澄清卡回答框用 `.fb-answer`；决策卡备注用 `.fb-note`
- `FB_DOC` / `FB_ROUND` 每次重新生成时更新为当前文档与轮次；`rounds/` 里的历史副本保留其生成时的值，不回改
- 已定稿的页面：移除导出栏、兜底弹窗与全部交互控件，决策卡全部是"已定"静态版
- 导出文本以 `【评审反馈】` 开头——AI 收到以此开头的消息时必须走迭代协议
