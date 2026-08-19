# my-skills

个人 Skill 集合，用于在 Kimi Code 中通过 `SKILL.md` 扩展可复用的工作流。

## 当前 Skill

| Skill | 路径 | 用途 |
|-------|------|------|
| `audit-design-implementation` | [`audit-design-implementation/SKILL.md`](audit-design-implementation/SKILL.md) | 基于设计文档审计项目实现，记录不符合项并应用修复，最多进行三轮独立的审计-修复循环（逐轮裁决 clean / modified / modified (cosmetic-only) / blocked，收敛即停），最终生成审计报告。 |
| `codex-plan-review` | [`codex-plan-review/SKILL.md`](codex-plan-review/SKILL.md) | 起草多步实施方案/研究方案/设计文档时，调用外部 codex 做对抗式评审（不同模型、不认识对话、只读核实），逐条修订方案，最多 3 轮。 |
| `design-sketch-review` | [`design-sketch-review/SKILL.md`](design-sketch-review/SKILL.md) | 设计文档"草图先行"评审闭环：先产出交互式 HTML 评审草图（大白话、可视化）供用户点选确认，按反馈就地迭代留痕，评审通过后输出正式 markdown 设计文档，并由 md 同源生成定稿版 HTML（此后 md 为唯一事实源）。 |
| `doc-visualizer` | [`doc-visualizer/SKILL.md`](doc-visualizer/SKILL.md) | 将复杂的技术方案、架构文档、研究提案、多章节规范转换为自包含的交互式 HTML 仪表板（无需服务器、浏览器直接打开），大幅提升阅读与理解效率。 |
| `execute-plan` | [`execute-plan/SKILL.md`](execute-plan/SKILL.md) | 按层次化执行计划驱动开发：解析 milestone / slice / task 结构，在独立 worktree 中实现并验证每个 milestone，通过后再合并回主分支。 |
| `fupeng-perspective` | [`fupeng-perspective/SKILL.md`](fupeng-perspective/SKILL.md) | 以经济学家付鹏（付鹏说 / 金融炼药师）的思维框架与表达方式分析宏观、资产价格与商业问题：基于 156 个公开来源提炼的 6 个心智模型、9 条决策启发式与完整表达 DNA，作为思维顾问给出交易员视角的分析。 |
| `generate-mydocs` | [`generate-mydocs/SKILL.md`](generate-mydocs/SKILL.md) | 以源码为主要素材、以现有文档为参考，为项目生成渐进式学习文档（beginner / advanced / deep-dives）。 |
| `review-design-proposal` | [`review-design-proposal/SKILL.md`](review-design-proposal/SKILL.md) | 从需求覆盖、架构可行性、风险与失败模式、一致性与可执行性等视角评审设计方案，并直接修订设计文档。 |

## 使用方式

在 Kimi Code 中，系统会自动发现项目内的 `SKILL.md` 文件。需要对应能力时，直接描述需求即可，例如：

- “根据 `docs/design.md` 审计当前项目实现是否一致，并修复发现的问题。”
- “按 `docs/execution-plan.md` 把 M1 做完，完成后先停。”
- “把 `docs/design.md` 可视化成一个交互式 HTML 仪表板，方便快速看懂。”
- “为这个项目生成一套 mydocs 学习文档。”
- “帮我评审 `docs/design-proposal.md`，看看这个方案有没有问题。”
- “帮我设计一个 xxx 方案，先出个评审草图给我看看。”
- “把这个实施计划交给 codex 做一轮对抗式评审再动手。”
- “用付鹏的视角分析一下当前的宏观环境。”
