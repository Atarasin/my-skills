<overview>
Defines the three depth levels and what each generated series should contain.
</overview>

<series name="beginner">
<goal>Build intuition without requiring deep code literacy.</goal>
<content>
- What the project is and what problems it solves
- High-level architecture with diagrams
- End-to-end flow for a typical use case
- Core concepts and their relationships
- Permission, extension, and runtime basics at a conceptual level
</content>
<code_level>Minimal. Mention top-level directories and a few key file names only when they help orientation.</code_level>
<output_files>
- <code>mydocs/README.md</code> — overview of all three series
- <code>mydocs/beginner/README.md</code> — series guide, reading order, glossary
- <code>mydocs/beginner/chapter-NN-title.md</code> — one chapter per concept
</output_files>
</series>

<series name="advanced">
<goal>Explain internal mechanisms using concrete source code.</goal>
<content>
- Turn lifecycle and event loops
- Context management and compaction
- Tool system descriptions and invocation
- Permission policy chain
- Plan mode and goal system
- Background tasks and cron
- Subagents and swarm
- Skills, plugins, and MCP
- Records, replay, and telemetry
- Server, SDK, and protocol
- Debugging and testing
- Contributing guidelines
</content>
<code_level>Concrete. Include file paths, function/class names, state machines, and event flows.</code_level>
<output_files>
- <code>mydocs/advanced/README.md</code> — series guide with user path and developer path
- <code>mydocs/advanced/chapter-NN-title.md</code> — one chapter per mechanism
</output_files>
</series>

<series name="deep-dives">
<goal>Trace one specific mechanism from user interface to provider API.</goal>
<content>
- Complete end-to-end flow diagram
- Key source files and functions at each layer
- Data shape at each transformation point
- A reproducible experiment or verification step
</content>
<code_level>Layer-by-layer code references from UI/Web down to the provider abstraction.</code_level>
<output_files>
- <code>mydocs/deep-dives/README.md</code> — topic index
- <code>mydocs/deep-dives/topic-name.md</code> — one document per mechanism
</output_files>
</series>
