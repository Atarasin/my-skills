---
name: design-sketch-review
description: >
  设计文档的"草图先行"评审闭环：接到设计需求时先不写正式文档，而是产出易于理解的
  交互式 HTML 评审草图（大白话、可视化）供用户评审；草图里的待定决策和待澄清问题做成
  页内可点选/填写的控件，用户确认后一键复制/下载结构化反馈文本发回；AI 按反馈就地迭代
  草图并记录每轮意见与修改痕迹；评审完全通过后，才基于最终草图输出完整、精确、面向
  执行 agent 的 markdown 设计文档。
  触发场景一（新设计）：用户带着需求来要设计/方案（"帮我设计…"、"出个方案"、"规划一下…"），
  必须先产 HTML 草图而不是先写 markdown。
  触发场景二（评审迭代）：用户提修改意见（"按这个意见改"、"这块不对重写"），或粘贴以
  "【评审反馈】"开头的页面导出文本时，必须按迭代协议就地修改草图并留痕。
  触发场景三（定稿）：用户明确表示评审通过（"可以了"、"定稿"、"输出正式文档"），基于最终
  草图生成完整 markdown 设计文档。
  也支持模式 B：把已有的复杂文档一次性转成可视化阅读版。
  Activate for: "visualize", "design review", "帮我设计", "出个方案", "评审",
  "按意见修改", "定稿", "输出正式文档", "可视化", "做个仪表板".
---

## 两种工作模式

| | 模式 A：设计评审闭环（主流程） | 模式 B：存量文档可视化 |
|---|---|---|
| 起点 | 用户提出新需求 | 用户拿来一份已有文档 |
| 事实源 | **HTML 草图**（定稿前没有 md） | 源 md 文档 |
| 终点 | 评审通过 → 输出正式 md 给执行 agent | 一次性 HTML 阅读版，不建档 |
| 迭代 | 就地改草图 + 留痕 | 若进入修改循环，按迭代协议执行（改 md 事实源 + 重渲染） |

判断规则：用户带着**需求**来 → 模式 A；带着**已有文档**来 → 模式 B。模式 A 是本 skill 的主流程，以下未特别说明的规则都针对模式 A。

---

## 模式 A 主流程：三阶段

### 阶段 1：产出 HTML 评审草图（铁律：评审通过前不写正式 md）

草图的定位是**给用户拍板用的**，不是给机器执行的。因此：

- **评审通过前，项目中不允许存在正式 md 设计文档**。用户提前索要 md 时，说明"现在还是草图阶段，评审通过后我会输出正式文档"。
- 内容用大白话写（优先级 A），侧重：这个设计要解决什么、怎么做、有哪些关键选择、风险在哪。
- **AI 自己拿不准的开放选择，不许擅自决定**——做成可交互"待定决策卡"（编号 D1~Dn，方案对比 + 默认建议），用户在页面上直接点选；需要用户补充的信息做成"澄清问题卡"（编号 Q1~Qn，页内填写）。页面底部固定"导出评审反馈"栏，用户选完填完后一键复制/下载结构化反馈文本发回对话——组件与导出脚本见 references/components.md"页内反馈与导出"。
- 未点选的决策项：导出文本中标注"未选择"，迭代时按卡上的默认建议落实并注明。
- 对话里直接提意见的途径永远保留，与页面导出等效；两个来源可以混用。
- Hero 区状态徽章：`评审中 · 第 N 轮`（amber 色）。
- 按迭代协议建档 history.json，`phase` 记 `"sketch"`，round 1 的 feedback 记 `"初始草图"`。

### 阶段 2：评审迭代

反馈来源二选一（都算一轮迭代）：用户粘贴以"【评审反馈】"开头的页面导出文本，或在对话里直接提意见。收到后执行迭代协议（六步，见下）——此时**修改对象就是 HTML 草图本身**，不存在 md 需要同步。被拍板的决策卡更新为"已定"静态卡（不再可交互、不再进入导出）。

### 阶段 3：定稿，输出正式 md

触发：用户明确表示通过（"可以了"、"定稿"、"输出正式文档"等）。

1. **检查遗留决策**：草图里仍有"等你拍板"状态的决策卡时，按卡上的默认建议落实，并在 md 决策记录中注明"按默认建议"；不允许带着未定决策定稿。
2. **生成正式 md**（面向执行 agent，规范见下文"正式 md 写作规范"），输出到项目 `docs/` 目录（无则项目根），文件名 `<日期>_<主题>.md`，用户指定路径时从其指定。
3. **一致性自检**：逐项核对草图中的每张决策卡、每条红线、每个里程碑在 md 里都有对应落实，发现遗漏立即修正 md。
4. **收尾**：history.json 的 `phase` 改为 `"finalized"`、`final_doc` 记 md 路径；追加一轮定稿记录（feedback 记 `"评审通过，定稿"`，status 记 `"已定稿"`）；md 快照存 `rounds/final-rNN.md`；重新生成主 HTML，Hero 徽章改为 emerald 色 `已定稿 · 正式文档见 <md 文件名>`。

**定稿后再有修改意见**：回到阶段 2（phase 重新置 `"sketch"`，轮次继续累加），再次通过后重新全量生成 md 替换旧版——不允许绕过草图直接改 md。

### 正式 md 写作规范（面向执行 agent）

与草图相反：md 写给机器和执行者看，**精确、完整、结构化，不追求通俗易懂**，保留全部技术术语。模板：

```markdown
# <标题>
> 版本：v<定稿次数> | 日期：<YYYY-MM-DD> | 状态：已定稿 | 评审轮次：N 轮
> 人读版（评审草图）：.doc-visualizer-output/<文件名>.html

## 1. 目标与范围
## 2. 总体设计 / 架构
## 3. 详细设计
   （按模块展开：接口定义、数据结构、配置项、算法口径写全，不给执行者留猜测空间）
## 4. 任务分解
   （执行 agent 可直接领取的粒度，标注依赖关系）
## 5. 约束与红线
## 6. 验收标准
   （每条是可判定的条件，避免"运行正常"这种模糊表述）
## 7. 已确认的决策记录
   （D1~Dn：选择 + 理由 + 评审轮次；"按默认建议"的要注明）
## 8. 风险与开放问题
```

---

## ⭐ 最高优先级 A：用普通话写 HTML，不要抄术语

**适用于一切 HTML 产物（草图、阅读版），不适用于正式 md**（md 给执行 agent 看，要精确不要通俗）。

HTML 是写给"聪明但不了解这个项目的人"看的。**每一条内容都要问自己**：*"这样写，对方读完能明白这在说什么吗？"* 不能就改写。不要因为"忠于原文/忠于思路"而保留读者看不懂的内容。

**三种处理方式**（按优先级）：

1. **直接替换**：能用大白话说清楚的，直接改写
   > ❌ `vol正向预测收益、守卫/择时/regime降仓/vol-targeting四者同因失败`
   > ✅ `过去试过四种减少亏损的方法：自动止损、择时操作、仓位控制、波动率调仓——测试下来全部在同一个地方失败：市场最低迷时把股票卖掉了`

2. **注释保留**：术语不可避免时，括号内补一句大白话
   > ✅ `数据管道（ETL）搭好后，顺手验证这个猜想`

3. **术语悬浮提示**：必须保留的专业词汇用 tooltip 包裹
   ```html
   <span class="tooltip-term" title="从多个原始 CSV 文件读取、清洗、统一格式后写入 parquet">ETL</span>
   ```
   ```css
   .tooltip-term{border-bottom:1px dashed #94a3b8;cursor:help;color:#475569}
   ```

### 常见行话翻译参考

| 术语 | 大白话 |
|---|---|
| ETL / parquet | 数据处理管道 / 列式存储文件 |
| regime | 市场状态（牛市/熊市/震荡等） |
| vol / volatility | 价格波动幅度 |
| lag=N 交易日 | 数据延迟 N 个交易日才能用 |
| fingerprint / 指纹 | 文件哈希校验值 |
| sentinel / 哨兵 | 自动检测异常的守卫程序 |
| 前视 / look-ahead | 回测时不小心用到了未来的数据（作弊） |
| 幸存者偏差 | 已退市的失败股票不在数据里，结论过于乐观 |
| prereg | 预注册（先写下判断标准，再看数据） |

### 两层内容模式

每张卡片/条目用"摘要 + 可选技术详情"两层结构——草图阶段尤其重要：用户看摘要拍板，技术细节留到定稿的 md 里写全：

```html
<div class="border rounded-xl p-4">
  <p class="font-semibold">一句话说清楚这是什么</p>
  <p class="text-sm text-gray-600 mt-1">用普通话解释为什么重要、会发生什么</p>
  <details class="mt-3">
    <summary class="text-xs text-gray-400 cursor-pointer hover:text-gray-600">原始技术细节 ▾</summary>
    <p class="text-xs text-gray-500 mt-1"><!-- 技术说明 --></p>
  </details>
</div>
```

---

## ⭐ 最高优先级 B：迭代协议——修改与重渲染原子同步，意见全程留痕

**铁律：任何一轮修改，必须在同一轮里完成"改事实源 → 重新生成 HTML → 更新 history.json"。** 事实源的认定：

- 模式 A 草图阶段：事实源 = HTML 草图本身（此时没有 md）
- 模式 A 定稿后的再迭代：仍先改草图，重新定稿时再全量重生成 md
- 模式 B 进入修改循环：事实源 = 源 md 文档

### 迭代流程（六步，缺一不可）

1. **记意见**：反馈**原文**追加进 history.json 的 `rounds`（不改写、不概括），`status` 先记 `"处理中"`。原文可以是用户粘贴的"【评审反馈】"导出文本，也可以是对话原话。
2. **改事实源**：按意见修改草图（或模式 B 的 md）。
3. **回填记录**：`changes`（大白话修改摘要）、`affected_sections`（页面板块名）、`status` 回填完整。
4. **重新生成主 HTML**：完整走可视化流程，注入最新历史面板；本轮涉及的板块加"本轮更新"角标。
5. **存档**：新主 HTML 复制为 `rounds/round-NN.html` 并修正副本内链接；有 md 时同步快照（草图阶段无 md 则跳过 md 快照）。
6. **汇报**：打开主 HTML，告知当前轮次、回应了哪条意见、改动了哪些板块。

### 产出物结构

```
.doc-visualizer-output/
├── 2026-08-19_概念数据接入.html      ← 永远是最新版，浏览器直接打开
└── 2026-08-19_概念数据接入/          ← 同名存档目录（不带 .html 后缀）
    ├── history.json                  ← 迭代记录（唯一数据源）
    └── rounds/
        ├── round-01.html             ← 第 1 轮完成时的完整 HTML 副本
        ├── round-02.html
        ├── final-r04.md              ← 定稿时的正式 md 快照（模式 A 定稿轮才有）
        └── round-01.md               ← 源文档快照（仅模式 B / 定稿后再迭代时有）
```

### history.json 规范

```json
{
  "doc": "概念数据接入方案",
  "mode": "A",
  "phase": "sketch",
  "final_doc": null,
  "rounds": [
    {
      "round": 1,
      "date": "2026-08-19 15:02",
      "feedback": "初始草图",
      "changes": "首次产出评审草图：整体分四个里程碑，留了 2 个待定决策（D1 存储选型、D2 依赖图方案）",
      "affected_sections": ["全部"],
      "status": "已采纳"
    },
    {
      "round": 2,
      "date": "2026-08-19 16:40",
      "feedback": "里程碑拆分太粗，M2 和 M3 的依赖关系没讲清楚；D2 选方案 B",
      "changes": "把 M2 拆成 M2a 和 M2b；概览页补了依赖关系图；D2 按你的选择定为方案 B，决策卡已标记",
      "affected_sections": ["路线图", "概览", "待定决策"],
      "status": "已采纳"
    }
  ]
}
```

规则：
- `feedback` 永远记用户原话；页面导出的反馈文本（以"【评审反馈】"开头、逐行列出 Dn 选择/Qn 回答/其他意见）原样整段记录，保留多行；模式 A 首轮记 `"初始草图"`；定稿轮记 `"评审通过，定稿"`
- `phase`：`"sketch"`（评审中）或 `"finalized"`（已定稿）；`final_doc` 为正式 md 路径或 `null`
- `changes` 用大白话；**不做逐字 diff**——用户关心的是"这轮回应了什么意见、动了哪些板块"
- `affected_sections` 用 HTML 页面板块/标签名，不用 md 标题或行号；全量改动写 `["全部"]`
- `status` 四选一：`已采纳` / `部分采纳` / `未采纳` / `已定稿`（仅定稿轮）；未采纳或部分采纳必须在 `changes` 里写明原因
- `date` 格式 `YYYY-MM-DD HH:MM`

### 存档与链接规则

- 主 HTML 里"查看此轮版本"链接：`href="<存档目录名>/rounds/round-0K.html"`
- `rounds/` 里的副本深两层，复制后立即修正副本内历史链接：
  ```bash
  sed -i 's|href="<存档目录名>/rounds/|href="./|g' rounds/round-NN.html
  ```
  无 sed 时用 python 等价替换。

### 旧版产物兼容

遇到无存档目录的旧 HTML：首次进入迭代时补建存档目录与 history.json（round 1 记 `"初始版本（历史补建）"`），旧 HTML 原样存为 `rounds/round-01.html`，从 round 2 起按正常流程走。

---

## 第一步：结构分析

读取需求/文档后，识别以下结构元素并记录数量与内容：

| 元素类型 | 识别特征 | → 可视化形式 |
|---|---|---|
| 里程碑/阶段 | M0~Mn、Phase N、阶段 | 带可展开任务的路线图卡片 |
| 嵌套任务树 | Mx-Sy-Tz、子任务列表 | 可折叠树（三级） |
| 硬性约束/红线 | 红线、禁止、MUST NOT、冻结条款 | 红色警告卡 + 图标 |
| 假设/实验 | H1~Hn、待验证假设 | 状态徽章卡片 |
| 架构分层 | 四层、Layer、数据层/指标层/… | 层叠堆栈图 |
| 依赖关系 | blocks/blockedBy、前置条件 | Mermaid 流程图 |
| 数据事实表 | markdown 表格、事实摘要 | 可排序交互表 |
| 实现陷阱 | 雷区、Rn、注意点 | 折叠警告列表 |
| 关键决策 | 冻结口径、已确认设计 | 决策卡片网格 |
| **待定决策（模式 A 草图）** | AI 拿不准、需用户拍板的开放选择 | 待定决策卡 D1~Dn |

提取元数据：标题、一句话摘要、日期、核心数字（几个里程碑、几条红线、几个待定决策…）。

---

## 第二步：页面结构设计

按内容决定标签数量，没有对应内容的标签不生成：

1. **概览 (Overview)**：标题卡、关键统计数字、架构层叠图、依赖关系图
2. **路线图 (Roadmap)**：M0→Mn 可展开卡片 → 切片 → 任务
3. **待定决策 (Decisions)**：D1~Dn 决策卡（模式 A 草图阶段必有，除非确实零开放选择；定稿后保留为"已确认的决策"展示）
4. **约束与决策 (Rules)**：红线警告卡（全部展示，不折叠）、冻结决策列表
5. **假设追踪 (Hypotheses)**：Hn 卡片网格
6. **实现指南 (Guide)**：雷区列表、关键锚点表
7. **数据事实 (Data)**：数据表格、画像数字
8. **迭代记录 (History)**：**永远生成，固定在标签导航最后一项**——按轮次倒序的卡片时间线

---

## 第三步：生成 HTML

### 技术栈（全 CDN，零安装）

```html
<script src="https://cdn.tailwindcss.com"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js"></script>
```

> ⚠️ Mermaid 有四个真实踩过的渲染大坑，**图放在标签页/折叠容器里时直接用"预渲染静态 SVG"方案一次根治**。完整排查与根治流程见 [references/mermaid.md](references/mermaid.md)，生成任何含 Mermaid 图的页面前必读。

### 颜色语义系统

| 用途 | Tailwind 类 |
|---|---|
| 红线 / 阻断 / 禁止 | `border-red-500 bg-red-50 text-red-800` |
| 警告 / 待处理 / 评审中 | `border-amber-500 bg-amber-50 text-amber-800` |
| 通过 / 已确认 / 已定稿 | `border-emerald-500 bg-emerald-50 text-emerald-800` |
| 架构 / 数据 | `border-blue-500 bg-blue-50 text-blue-800` |
| 策略 / 决策 | `border-purple-500 bg-purple-50 text-purple-800` |
| 里程碑主色 | `bg-slate-800 text-white` |
| 评审意见引用块 | `border-slate-300 bg-slate-50 text-slate-700` |

### 核心组件模式

里程碑卡片、红线卡、假设卡、架构层叠图、雷区列表、标签页导航、**待定决策卡**、Hero 状态徽章，以及页面整体骨架，全部见 [references/components.md](references/components.md)（含可直接套用的完整代码）。生成页面前必读。

### 迭代历史面板（每次生成必须注入）

面板数据生成时从 history.json 读入并**写死成静态 HTML**（不运行时加载，file:// 下 fetch 会失败）。每轮一张卡，**按 round 倒序**：

```html
<div x-show="tab==='history'" x-cloak class="space-y-4">
  <div class="bg-white border border-gray-200 rounded-xl p-5">
    <div class="flex items-center gap-3 flex-wrap">
      <span class="font-mono bg-slate-800 text-white px-2 py-0.5 rounded text-sm">R2</span>
      <span class="text-xs text-gray-400">2026-08-19 16:40</span>
      <span class="text-xs px-2 py-1 rounded-full bg-emerald-100 text-emerald-800 font-medium">已采纳</span>
      <span class="ml-auto flex gap-1 flex-wrap">
        <span class="text-xs bg-blue-50 text-blue-700 rounded-full px-2 py-0.5">路线图</span>
      </span>
    </div>
    <blockquote class="mt-3 border-l-4 border-slate-300 bg-slate-50 rounded-r-lg px-4 py-2 text-sm text-slate-700">
      <span class="text-xs text-slate-400 block mb-1">评审意见（原文）</span>
      里程碑拆分太粗，M2 和 M3 的依赖关系没讲清楚；D2 选方案 B
    </blockquote>
    <p class="mt-3 text-sm text-gray-700"><span class="font-medium">本轮修改：</span>把 M2 拆成 M2a 和 M2b……</p>
    <a href="2026-08-19_概念数据接入/rounds/round-02.html"
      class="mt-2 inline-block text-xs text-blue-600 hover:underline">查看此轮版本 →</a>
  </div>
</div>
```

样式规则：
- status 徽章：`已采纳` emerald / `部分采纳` amber / `未采纳` red / `已定稿` emerald 加深
- 首轮（初始草图）不显示意见引用块；定稿轮的卡片顶部加一行 `🎉 本轮定稿，正式文档：<md 文件名>`
- 轮次卡数 = history.json 条数 = `rounds/*.html` 数，三者必须一致

### 本轮更新角标

按 history.json **最后一轮**的 `affected_sections`，在对应标签按钮文字后加：

```html
<span class="ml-1 text-xs px-1.5 py-0.5 rounded bg-emerald-500 text-white align-middle">R2 更新</span>
```

`["全部"]` 时角标加在 Hero 标题旁。历史副本保留其生成时的角标，不回改。

---

## 第四步：输出文件

1. **写入路径**：当前项目文件夹下的 `.doc-visualizer-output/`：
   ```bash
   mkdir -p .doc-visualizer-output/<日期>_<主题>/rounds
   ```
2. **文件名**：主 HTML 为 `<日期>_<主题简称>.html`；存档目录同名（去 `.html`）。正式 md 输出到项目 `docs/`（无则项目根），文件名 `<日期>_<主题>.md`。
3. **打开文件**（WSL/Linux 优先 xdg-open，失败提示路径）：
   ```bash
   xdg-open .doc-visualizer-output/xxx.html 2>/dev/null || \
   explorer.exe "$(wslpath -w "$(pwd)/.doc-visualizer-output/xxx.html")" 2>/dev/null || \
   echo "请在浏览器中打开: $(pwd)/.doc-visualizer-output/xxx.html"
   ```
4. 告知用户：主 HTML 绝对路径、当前轮次与阶段（评审中/已定稿）、本轮改动板块、待定决策数量（若有）。

---

## 生成质量检查清单

**渲染基础**
- [ ] `charset="UTF-8"` 在 `<head>` 首行；CDN script 正确，Alpine.js 有 `defer`
- [ ] `x-data` 在需要状态的父容器上；`x-show` 与 `tab==='xxx'` 精确匹配
- [ ] 文本节点中 `<` `>` `&` 已转义；移动端友好；中文无截断

**Mermaid**（含图时逐条过 [references/mermaid.md](references/mermaid.md)）

**迭代留痕（每次生成必查）**
- [ ] history.json 存在，条数 = 面板卡片数 = `rounds/` 下 HTML 数
- [ ] 本轮 `feedback` 是用户原文（首轮/定稿轮除外），无 `"处理中"` 残留
- [ ] `changes` 是大白话；`affected_sections` 用页面板块名；角标只出现在对应板块
- [ ] 主 HTML 历史链接前缀 `<存档目录名>/rounds/`，刚存入的副本内已改为 `./`

**模式 A 专属**
- [ ] 评审通过前，项目中**不存在**正式 md 设计文档
- [ ] 草图里所有 AI 拿不准的开放选择都已做成待定决策卡（D 编号连续），所有需用户补充的信息都有澄清问题卡（Q 编号连续）
- [ ] 页内反馈机制完整：每个待定项有唯一 `data-fb`（决策卡可点选、澄清卡可填写），底部有导出栏与兜底弹窗，导出脚本中 `FB_DOC`/`FB_ROUND` 已写死为当前文档与轮次
- [ ] 已定决策为静态卡（无 `data-fb`、不可再点选）；已定稿的页面整体移除导出栏与交互控件
- [ ] 定稿时：无遗留"等你拍板"决策（未拍板的按默认建议落实并注明）；md 通过一致性自检（每张决策卡/红线/里程碑都有落实）；history.json 的 `phase`/`final_doc` 已更新；md 快照已存入 rounds/

**渲染验证（写入后必做）**：真实浏览器逐标签点击验证，控制台 0 错误——脚本见 [references/mermaid.md](references/mermaid.md) 末尾；迭代场景下必须点开"迭代记录"确认面板正常。

---

## 典型调用示例

**模式 A：新设计（草图先行）**
- `帮我设计一个概念数据接入方案`（→ 阶段 1：直接产 HTML 草图，不写 md；待定项做成页内可点选/填写的卡）
- 用户在页面上选好 D1/D2、填完 Q1，点"复制评审反馈"，粘贴回来：`【评审反馈】《概念数据接入方案》第 1 轮\nD1 ……：选「方案B」\n……`（→ 阶段 2：按迭代协议处理）
- `里程碑拆分太粗，D2 我选方案 B`（→ 阶段 2：对话提意见同样走迭代协议）
- `可以了，输出正式文档吧`（→ 阶段 3：定稿，生成 md 给执行 agent）
- `前几轮都改了什么？`（→ 打开"迭代记录"标签页，或读 history.json 摘要回答）

**模式 B：存量文档**
- `把 docs/xxx.md 做成交互式可视化，帮我看懂它`
- `make an interactive dashboard for this architecture doc`
