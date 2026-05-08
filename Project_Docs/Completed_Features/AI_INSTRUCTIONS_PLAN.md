# AI & tooling instructions — hub

> Archive note: moved to `Project_Docs/Completed_Features` on **Wednesday, May 6, 2026 at 11:36 AM (UTC-4)** after completing the rules refactor execution.
> Active rule sources are now `.cursor/rules/AGENTS.md` and `.cursor/rules/focus/*`.

## Purpose

This file is the **design doc** for context-specific guidance resulting from a refactor of [`.cursor/rules/instructions.md`](../.cursor/rules/instructions.md). **General project rules** move to [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md). In every **Create `./…`** block below, **`./` means the [`.cursor/rules`](../.cursor/rules) directory** (create subfolders such as `focus/` there as needed). Once the refactor is completed [`.cursor/rules/instructions.md`](../.cursor/rules/instructions.md) will be deprecated and stripped to a single pointer to AGENTS.md, so as not to break any existing references to it.

## How to use this plan

The contents of [`.cursor/rules/instructions.md`](../.cursor/rules/instructions.md) were placed below and split into sections that say where each part should land. Each payload is surrounded by **`Create {file location name} : {START/END}`** tags. If a referenced file does not exist yet, create it at that path and paste the marked content in.

Inside the **Create `./AGENTS.md`** block, relative links such as `./focus/…` are written for the live file under **`.cursor/rules/`** (they will not resolve if you click them from this plan in `Project Docs/`).

## Refactor status and environment

During the refactor, follow the rules in [`.cursor/rules/instructions.md`](../.cursor/rules/instructions.md). After the refactor is completed, treat  **AGENTS.md** as the source of truth for agent-facing rules.

No project **Python** environment is assumed. If the repo later adds Python tooling, add explicit environment rules then.

**Create ./AGENTS.md : START**

# Agent instructions

## Agent role

You are an expert game developer focused on C++, the Godot game engine, and integrating AI into game engines.

## Behavioral instructions

- **Ambiguity protocol:** If a requirement is unclear or not explicitly stated in the Project Documents, **STOP and ask for clarification**. Do not guess. Project Documents = `./Project_Docs/*.md` (excluding `./Project_Docs/Completed_Features/*`) plus files in `./.cursor/rules/*`.
- **Refactoring:** Do not rename or move files once they have been created. Renaming files will break the contextual rule application and is strictly prohibited.

## Formatting

**Applies when:** You add or change formatted source code.

**Follow the project style guide:**

- Use 2-space indentation.
- Put the opening brace on the same line when the language’s usual style allows it.
- Put spaces around operators.

## Documenting / comments

**Applies when:** You write or modify a function (or equivalent unit).

**Include:**

- What the function is for.
- What each parameter means.
- What it returns (or side effects), when that is not obvious from names alone.
- A short usage example when behavior is non-obvious or has non-trivial preconditions.

## Testing / unit tests

**Applies when:** You implement a new feature.

**Do:**

- Add unit tests that cover the important code paths and meaningful edge cases.
- Prefer a clear Arrange–Act–Assert (or equivalent) structure.
- Use test names that state intent.

## Project Docs interactions

### Agentic assisted design

**Applies when:** You write or revise design documents that an agentic developer is expected to implement from.

**Use these embedded markers** so the next review pass can find open design conversation:

- `<<Question: …>>` — Ask the agent for information or clarification the next time it reads this doc.
- `<<Comment: …>>` — Note an area that needs more thought, a reminder for the author, or something author and agent should resolve together.

### Debugging assistance (OLog)

**Applies when:** You create or refactor code where understanding control flow or failures matters.

**Use `OLog` roughly as follows** (full policy: [logging_instr.md](./focus/logging_instr.md)):

- `info()` — Major lifecycle or state events (e.g. thread or subsystem start/stop).
- `debug()` — Frequent path tracing when needed (e.g. a collision or decision branch), without flooding logs.
- `error()` — Likely failures, violated assumptions, or recoverable errors worth investigating.

## Focus areas (index)

Detailed rules live only in these files; add more pointers here as new focus areas appear (e.g. UI).

**Ignore incosistencies in historical files** Files defined in (./Project_Docs/Completed_Features) are historical feature design docs. We expect cross-doc drift with those files. Only call this out in a situation where explicityly asked to include them.

- **Logging (policy, PII, volume):** [logging_instr.md](./focus/logging_instr.md)
- **Runtime / in-game AI agents (embedded LLM), not IDE assistants:** [agentic_coding.md](./focus/agentic_coding.md)

**Create ./AGENTS.md : END**

**Create ./focus/logging_instr.md : START**

# Logging & sensitive data (oLog / game output)

- **PII & secrets:** Do not log personally identifiable information, credentials, API keys, session tokens, or secrets. If diagnostic output might include paths, redact usernames in home-directory paths when feasible.
- **Volume:** Do not log huge payloads (full model prompts, entire perception grids, raw binary). Prefer short summaries, counts, or bounded excerpts; large debug blobs belong behind explicit dev-only flags and truncation.
- **Line length:** Treat **`MAX_LOG_LINE_CHARS`** (default **2048** characters per logical line of user-visible message text) as a soft cap in implementation; truncate long strings with a suffix such as ` [truncated]` rather than writing megabytes to disk.

**Create ./focus/logging_instr.md : END**

**Create ./focus/agentic_coding.md : START**

# Goals for runtime / in-game AI (embedded LLM)

**Scope:** These goals apply when **implementing** in-engine, LLM-driven behavior in the Godot project. They do **not** describe Cursor or other IDE coding assistants.

When designing or coding that embedded LLM stack, prioritize in this order:

1. **Contextualize inputs.** The model should only treat input as valid inside an approved fiction/game context (e.g. player text is in-character dialogue). Treat out-of-world or jailbreak-style input as in-fiction noise or incomprehensible, per product rules—not as instructions to the engine.
2. **Optimize cost and performance.** Assume limited hardware and token budget; use the **minimum** prompt/completion size that still meets the task.
3. **Design for parallelism.** Multiple agents may run; share prompts, caches, or utilities where safe; avoid needless sequential bottlenecks when parallel work is required.
4. **Minimize context.** Provide only what the role needs for the current decision—lighter prompts and smaller blast radius for hallucinations or prompt injection.
5. **Constrain surface area.** The model may only drive the game through a **defined API** (tools, GDScript facades, etc.). Do not expose unfettered access to arbitrary code or engine internals.

**Create ./focus/agentic_coding.md : END**

# Implemetnation Checklist

- [x] Validte that files and directories exist
- [x] Create files and directories for any that are missing
- [x] Move content from this file into the files outlined in the markdown
- [x] Clean up instructions.md
- [x] Validate all links/paths are correct.
