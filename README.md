# my-skills

个人 Skill 集合，用于在 Kimi Code 中通过 `SKILL.md` 扩展可复用的工作流。

## 当前 Skill

| Skill | 路径 | 用途 |
|-------|------|------|
| `audit-design-implementation` | [`audit-design-implementation/SKILL.md`](audit-design-implementation/SKILL.md) | 基于设计文档审计项目实现，记录不符合项并应用修复，最多进行三轮独立的审计-修复循环，最终生成审计报告。 |
| `execute-plan` | [`execute-plan/SKILL.md`](execute-plan/SKILL.md) | 按层次化执行计划驱动开发：解析 milestone / slice / task 结构，在独立 worktree 中实现并验证每个 milestone，通过后再合并回主分支。 |
| `generate-mydocs` | [`generate-mydocs/SKILL.md`](generate-mydocs/SKILL.md) | 以源码为主要素材、以现有文档为参考，为项目生成渐进式学习文档（beginner / advanced / deep-dives）。 |
| `review-design-proposal` | [`review-design-proposal/SKILL.md`](review-design-proposal/SKILL.md) | 从需求覆盖、架构可行性、风险与失败模式、一致性与可执行性等视角评审设计方案，并直接修订设计文档。 |

## 使用方式

在 Kimi Code 中，系统会自动发现项目内的 `SKILL.md` 文件。需要对应能力时，直接描述需求即可，例如：

- “根据 `docs/design.md` 审计当前项目实现是否一致，并修复发现的问题。”
- “按 `docs/execution-plan.md` 把 M1 做完，完成后先停。”
- “为这个项目生成一套 mydocs 学习文档。”
- “帮我评审 `docs/design-proposal.md`，看看这个方案有没有问题。”
