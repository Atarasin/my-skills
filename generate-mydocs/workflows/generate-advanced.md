# Workflow: Generate Advanced Series

<required_reading>
1. <code>references/doc-structure.md</code>
2. <code>references/writing-style.md</code>
</required_reading>

<process>
## Step 1: Read the plan

Load <code>mydocs/.learning-plan.md</code>.

## Step 2: Generate advanced README

Write <code>mydocs/advanced/README.md</code> with:

- Series goal and prerequisites
- User path chapters
- Developer / contributor path chapters
- Advanced glossary

## Step 3: Generate chapters

For each planned advanced chapter:

- Read the relevant source code deeply.
- Identify the mechanism, state machine, event flow, and data transformations.
- Draw Mermaid diagrams for state machines, sequence flows, or architecture.
- Write <code>mydocs/advanced/chapter-NN-title.md</code> with:
  - Title and overview
  - Technical explanation
  - Concrete source-code entry points (file paths and functions)
  - "本章小结"
  - "上一章 / 下一章" links

## Step 4: Review

Show the generated file list and ask the user for feedback. Apply revisions if requested.
</process>

<success_criteria>
- <code>mydocs/advanced/README.md</code> exists with user and developer paths.
- All planned advanced chapters are generated.
- Each chapter has source-code file/function references and diagrams.
- The user has reviewed the output.
</success_criteria>
