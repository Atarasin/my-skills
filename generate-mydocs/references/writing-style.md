<overview>
Style and quality rules for generated learning documents.
</overview>

<language>
Write the document body in Chinese. Keep code identifiers, file paths, function names, and technical terms in English. On first use of a technical term, add a brief Chinese explanation in parentheses.
</language>

<structure_rules>
- Start each chapter with a one-paragraph overview.
- Use a central analogy for beginner chapters; use precise technical descriptions for advanced chapters.
- Include at least one Mermaid diagram per chapter when it clarifies architecture, state, or flow.
- End every chapter with a "本章小结" section.
- Add "上一章 / 下一章" links in advanced and deep-dive chapters.
</structure_rules>

<code_rules>
- Ground every claim in source code. Include concrete file paths and function/class names.
- Keep code snippets short and focused; prefer pointing to the file over pasting large blocks.
- For deep-dives, show data-shape examples at each layer.
</code_rules>

<source_rules>
- Use existing project docs (README, AGENTS.md, existing mydocs/) only as reference.
- Do not copy existing docs verbatim.
- Derive explanations from reading the actual source code.
</source_rules>

<safety_rules>
- Before overwriting an existing file, show a diff preview and ask for explicit approval.
- Never delete user-written content without confirmation.
</safety_rules>
