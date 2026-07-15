---
name: generate-mydocs
description: Generates progressive learning documentation for a project in a mydocs-style directory, using source code as the primary source and existing project docs as reference. Use when the user wants to create beginner, advanced, and deep-dive study materials from a codebase.
---

<objective>
Many projects lack guided learning materials that progress from high-level concepts to implementation details. This skill reads a project's source code as the primary source, uses existing docs such as README and AGENTS.md as reference, and generates a complete <code>mydocs/</code> structure: a beginner series, an advanced series with user and developer paths, and deep-dive topics. The output is code-centric but organized by depth.
</objective>

<quick_start>
When the user wants to generate learning docs:

1. Default to the current working directory as the project root.
2. Load <code>workflows/plan.md</code> to discover the project and produce a learning-doc plan.
3. After the plan is approved, generate the <code>mydocs/</code> series in order: beginner → advanced → deep-dives.
</quick_start>

<intake>
<strong>Ask the user:</strong>

1. What is the project root directory? (default: current working directory)
2. What do you want to generate?
   - <strong>Full <code>mydocs/</code> set</strong> — plan + beginner + advanced + deep-dives
   - <strong>Plan only</strong> — discover the project and produce a plan first
   - <strong>Beginner series only</strong>
   - <strong>Advanced series only</strong>
   - <strong>One deep-dive topic</strong>
3. If generating a deep-dive: which topic, or should I suggest topics from the plan?

<strong>Wait for response before proceeding.</strong>
</intake>

<routing>
| Response | Workflow |
|----------|----------|
| "plan" / default | <code>workflows/plan.md</code> |
| "beginner" | <code>workflows/generate-beginner.md</code> |
| "advanced" | <code>workflows/generate-advanced.md</code> |
| "deep-dive" | <code>workflows/generate-deep-dive.md</code> |
| "full" | <code>workflows/plan.md</code>, then continue to beginner, advanced, and deep-dive in sequence |

After <code>plan.md</code> completes, if the user chose "full", continue with the other workflows in the order above.
</routing>

<reference_index>
<strong>Output structure:</strong> <code>references/doc-structure.md</code>
<strong>Writing style:</strong> <code>references/writing-style.md</code>
</reference_index>

<workflows_index>
| Workflow | Purpose |
|----------|---------|
| <code>plan.md</code> | Discover the project, read code and existing docs, produce a learning-doc plan. |
| <code>generate-beginner.md</code> | Generate the beginner series in <code>mydocs/beginner/</code>. |
| <code>generate-advanced.md</code> | Generate the advanced series in <code>mydocs/advanced/</code>. |
| <code>generate-deep-dive.md</code> | Generate one end-to-end deep-dive in <code>mydocs/deep-dives/</code>. |
</workflows_index>

<success_criteria>
This skill is working correctly when:

- A plan is produced and approved before generation starts for full or large tasks.
- Generated docs are organized by depth in <code>mydocs/beginner/</code>, <code>mydocs/advanced/</code>, and <code>mydocs/deep-dives/</code>.
- Each document is grounded in source code, with concrete file paths, functions, and snippets.
- Existing project docs are used as reference but not copied verbatim.
- The user reviews and approves the output before any existing files are overwritten.
</success_criteria>
