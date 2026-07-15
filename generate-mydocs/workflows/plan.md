# Workflow: Plan Learning Docs

<required_reading>
1. <code>references/doc-structure.md</code>
</required_reading>

<process>
## Step 1: Discover project structure

Read the following from the project root:

- <code>README.md</code>
- <code>AGENTS.md</code> (if exists)
- <code>package.json</code>, <code>pnpm-workspace.yaml</code>, or equivalent workspace config
- Top-level directory listing

Identify:

- Apps, packages, and key modules
- Entry points (CLI, server, library exports)
- Build, test, and run commands
- Existing <code>mydocs/</code> structure (if any)

## Step 2: Read existing docs

If <code>mydocs/</code> already exists, read its <code>README.md</code> and any series READMEs to understand what is already covered. Note gaps and outdated content.

## Step 3: Identify code entry points

For each major component, locate the key source files. Examples of what to capture:

- Agent / core logic → relevant <code>src/</code> directories
- Server → server bootstrap and route handlers
- CLI / TUI → terminal interface code
- Protocol / SDK → shared types and client code
- Provider abstraction → LLM adapter layer

## Step 4: Produce a plan

Generate a plan file at <code>mydocs/.learning-plan.md</code>. The plan includes:

- Proposed beginner chapter titles and what each covers
- Proposed advanced chapter titles, split into user path and developer path
- Proposed deep-dive topics
- Key code entry points for each item

If the user chose "plan only", stop here and present the plan.

## Step 5: Get approval

Show the plan to the user. Ask for approval or revisions. Once approved, route to the next workflow based on the user's original request.
</process>

<success_criteria>
- Project structure and key modules are understood.
- Existing docs are reviewed and gaps are noted.
- A written plan exists at <code>mydocs/.learning-plan.md</code>.
- The user has approved the plan before generation continues.
</success_criteria>
