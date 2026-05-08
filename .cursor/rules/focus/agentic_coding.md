# Goals for runtime / in-game AI (embedded LLM)

**Scope:** These goals apply when **implementing** in-engine, LLM-driven behavior in the Godot project. They do **not** describe Cursor or other IDE coding assistants.

When designing or coding that embedded LLM stack, prioritize in this order:

1. **Contextualize inputs.** The model should only treat input as valid inside an approved fiction/game context (e.g. player text is in-character dialogue). Treat out-of-world or jailbreak-style input as in-fiction noise or incomprehensible, per product rules—not as instructions to the engine.
2. **Optimize cost and performance.** Assume limited hardware and token budget; use the **minimum** prompt/completion size that still meets the task.
3. **Design for parallelism.** Multiple agents may run; share prompts, caches, or utilities where safe; avoid needless sequential bottlenecks when parallel work is required.
4. **Minimize context.** Provide only what the role needs for the current decision—lighter prompts and smaller blast radius for hallucinations or prompt injection.
5. **Constrain surface area.** The model may only drive the game through a **defined API** (tools, GDScript facades, etc.). Do not expose unfettered access to arbitrary code or engine internals.
