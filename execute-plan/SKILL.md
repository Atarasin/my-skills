---
name: execute-plan
description: |
  按层次化执行计划（milestone → slice → task）驱动开发的工作流：解析执行计划文档，
  为每个 milestone 创建独立 git worktree，按 slice 依赖顺序实现任务，用独立评审
  subagent 对照设计方案验证，验证通过才合并主分支并清理 worktree，不通过则修复重验。
  支持"完成一个 milestone 即停"或"按依赖顺序做完全部"两种模式。
  当用户提到执行计划、按计划开发、开发/实现/继续某个 milestone 或 slice、
  "execute the plan"、"implement M1"，或给出一个含 milestone/slice/task
  （或 phase/阶段/increment 等同义分层）结构的计划文档并要求开始开发时，
  务必使用本 skill——即使用户没有明说"执行计划"，只要出现"按 XX 文档把
  M0 做完"这类意图就应触发。不适用的情形：撰写/评审/修改计划文档本身、
  解释计划内容、与计划无关的单步 git/worktree 操作或普通 bug 修复。
---

# 执行计划驱动开发

按 milestone → slice → task 的层次结构完成执行计划的开发。核心纪律只有一条：**每个 milestone 在隔离的 worktree 中开发，通过独立验证后才允许进入主分支。**
这样主分支永远处于可发布状态，失败的 milestone 可以整体丢弃而不污染历史。

## 计划文档格式约定

- `## M<n>：<标题>`：milestone。正文声明依赖（如"依赖：M1 全部"）与目标。
- `### M<n>.S<m> <标题>`：slice。正文首行声明依赖（如"依赖：S1、M0.S2"或"无"）。
- `- [ ] T<k> …`：task 复选框，`[x]` 表示已完成。
- slice 末尾的"验收"task 是该 slice 的完成定义（DoD）；milestone 末尾可能有"里程碑门禁"小节。
- 计划中的章节引用（如 §3.2、§4.4）指向同目录设计方案文档的对应章节。实现前必须读原章节——计划里的一句话只是索引，约束细节全在设计方案里，跳过它是返工的最大来源。

遇到偏离此格式的计划文档时不要放弃：按"里程碑/阶段 → 可独立验证的增量 → 单 PR 工作单元"的语义对应解析，解析结果先向用户复述确认再动工。

## Phase 0：定位与解析

1. 确定执行计划文件：优先用用户给出的路径；否则 Glob 搜索 `**/*execution-plan*` / `**/*执行计划*`；多个候选或找不到时问用户。
2. 通读执行计划及其 README/设计方案文档地图，建立：
   - milestone 列表、完成状态（全部 task 为 `[x]` 视为已完成）、依赖与硬顺序；
   - milestone 内 slice 依赖图（未声明依赖的 slice 可并行，默认仍按文档顺序串行实现——并行只在用户明确要求时启用，因为并行 slice 间的隐式冲突
     比串行的时间成本更贵）；
   - 每个 slice 的 task 与验收 task；
   - 验证所需的测试矩阵/门禁文档（如 05-testing-gates.md 一类）。
3. 确认仓库状态：当前在主分支（或与用户确认目标合并分支）、工作区干净。不干净时停下来问用户，不要自行 stash 或丢弃——那些改动可能是用户正在进行的工作。

## Phase 1：选择范围与模式

若用户在调用时未说明，用 AskUserQuestion 一次问清：

1. **起始 milestone**：默认取依赖已满足、未完成的编号最小者。用户指定的milestone 若有未完成的前置依赖，指出缺口并让用户确认是否仍继续。
2. **执行模式**：`single`（完成一个 milestone 后停止汇报）或 `all`（按依赖顺序连续完成剩余全部）。

## Phase 2：单个 milestone 的开发循环

1. **建 worktree**：`EnterWorktree(name: "<里程碑编号小写>")`（如 `m1`）。环境没有 EnterWorktree 工具时用 git 原语等价实现：
   `git worktree add .claude/worktrees/<name> -b <name>`，之后所有开发命令在该 worktree 目录下执行。记录 worktree 路径与分支名，Phase 4 合并与清理要用。
2. **建任务清单**：用 TaskCreate 按 slice → task 建任务，用 addBlockedBy
   编码 slice 间依赖，让进度对用户可见。
3. **按 slice 开发**，依赖拓扑序逐个进行：
   - 动工前读设计方案中该 slice 引用的全部章节；
   - 逐个 task 实现，遵循仓库既有代码风格与 CLAUDE.md 约定；
   - 验收 task：按其引用的测试矩阵行补齐并运行测试，全部通过才算 slice 完成；
   - 每完成一个 slice 提交一次 commit（格式 `M<n>.S<m>: <slice 标题>`），并把计划文档中对应 task 勾为 `[x]`（计划在仓库内则随代码一起提交）。按 slice 提交而不是按 task 或整个 milestone，是为了让验证失败时能定位到出问题的增量。
4. slice 全部完成后进入 Phase 3。

## Phase 3：milestone 验证

验证是独立步骤，不能用"开发时测试都过了"代替——开发者视角天然带确认偏差：

1. Spawn 一个独立验证 subagent（Agent 工具），只给它设计方案、执行计划和本 milestone 的 diff（不给开发过程上下文），让它以评审视角逐条核对计划条目与设计约束（特别是 §x.x 细节和里程碑门禁项），输出"符合 / 不符合 + 理由"清单。
2. 运行完整测试：本 milestone 新增测试 + 仓库既有测试套件 + 门禁文档中属于本 milestone 的检查项。
3. **通过** → Phase 4。**不通过** → 修复后回到本 Phase 从头重新验证（包括重新 spawn 评审 subagent——部分重验会漏掉修复引入的新问题）。连续 3 轮失败时停下，向用户汇报剩余问题与已尝试的修复，等待指示。

## Phase 4：合并与清理

1. 确认 worktree 内改动已全部 commit，然后 `ExitWorktree(action: "keep")`回到主工作区。
2. 主分支若有新提交：先在 milestone 分支上合并/rebase 主分支，解决冲突并重跑测试，再合并——保证合并进主分支的状态就是验证过的状态。
3. **记录完成状态**：验证通过后、合并前，把计划文档中该 milestone 的"里程碑门禁"复选框勾为 `[x]`，并确认该 milestone 下所有 slice/task 的复选框都已勾上（漏勾的补上），随 milestone 分支一起 commit。计划文档是项目完成状态的单一记录源——门禁复选框只能在验证真正通过后勾选，它是"这个 milestone 验证过了"的凭证，不是开发完成的标记。
4. `git merge --no-ff <milestone 分支> -m "merge M<n>: <标题>"`。用 `--no-ff` 保留 milestone 边界，便于整体回滚。
5. 用 `git log` 确认改动已进主分支后，`git worktree remove <路径>`、`git branch -d <分支>`（`-d` 而非 `-D`：未合并的分支删不掉正是安全网）。
6. 向用户汇报：完成的 slice/task、验证结论、合并 commit。

## Phase 5：模式分支

- `single`：汇报后结束，提示下一个可开始的 milestone。
- `all`：回到 Phase 2 处理下一个依赖已满足的 milestone，直到计划完成或某个 milestone 验证卡住（3 轮失败）。

## 约束

- 不改计划的范围与内容（勾 `[x]` 除外）：发现计划有问题（依赖矛盾、与设计冲突）时停下向用户说明——计划是用户评审过的契约，不是草稿。
- 验证未通过绝不合并；不用跳过测试、放宽断言或删除失败用例的方式"通过"。
- 全程不 push 远端，除非用户明确要求。
