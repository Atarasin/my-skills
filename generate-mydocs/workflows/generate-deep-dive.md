# Workflow: Generate a Deep-Dive Topic

<required_reading>
1. <code>references/doc-structure.md</code>
2. <code>references/writing-style.md</code>
</required_reading>

<process>
## Step 1: Select topic

Use the topic from the user or suggest topics from <code>mydocs/.learning-plan.md</code>. Confirm the choice before writing.

## Step 2: Trace through code

Read the relevant code at every applicable layer:

- UI layer (TUI / Web)
- Protocol / SDK
- Server
- Core engine
- Provider abstraction or external adapters

For each layer, identify:

- The key files and functions involved
- Input and output data shapes
- Where the data is transformed

## Step 3: Write the deep-dive

Generate <code>mydocs/deep-dives/topic-name.md</code> with:

- Title and scope
- End-to-end flow diagram
- Layer-by-layer explanation with code references
- Data shape examples at each layer
- A reproducible experiment or verification step
- Summary

## Step 4: Update deep-dive index

Update <code>mydocs/deep-dives/README.md</code> to list the new topic with a one-line description.

## Step 5: Review

Show the generated file and ask the user for feedback. Apply revisions if requested.
</process>

<success_criteria>
- The deep-dive file is generated with end-to-end flow.
- Each layer has concrete code references.
- A reproducible experiment or verification step is included.
- The deep-dive index is updated.
- The user has reviewed the output.
</success_criteria>
