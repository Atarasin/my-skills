# Workflow: Generate Beginner Series

<required_reading>
1. <code>references/doc-structure.md</code>
2. <code>references/writing-style.md</code>
</required_reading>

<process>
## Step 1: Read the plan

Load <code>mydocs/.learning-plan.md</code>. If it does not exist, fall back to a sensible default beginner outline based on the project structure.

## Step 2: Generate beginner README

Write <code>mydocs/beginner/README.md</code> with:

- Series goal and target audience
- Reading order
- Quick glossary of terms that will appear

## Step 3: Generate chapters

For each planned beginner chapter:

- Read the relevant high-level code and existing docs.
- Identify the central concept and a useful real-world analogy.
- Draw a Mermaid architecture or flow diagram if it helps.
- Write <code>mydocs/beginner/chapter-NN-title.md</code> with:
  - Title and overview
  - Central analogy
  - Key concepts in plain language
  - Minimal, high-level code references
  - "本章小结"

## Step 4: Generate or update top-level README

Write or update <code>mydocs/README.md</code> to introduce the three series and the suggested reading order.

## Step 5: Review

Show the generated file list and ask the user for feedback. Apply revisions if requested.
</process>

<success_criteria>
- <code>mydocs/beginner/README.md</code> exists with a reading order and glossary.
- All planned beginner chapters are generated.
- Each chapter has an analogy, summary, and minimal but accurate code references.
- The user has reviewed the output.
</success_criteria>
