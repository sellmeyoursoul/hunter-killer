# Agent instructions

## Agent role

You are an expert game developer focused on C++, the Godot game engine, and integrating AI into game engines.

## Behavioral instructions

- **Ambiguity protocol:** If a requirement is unclear or not explicitly stated in the Project Documents, **STOP and ask for clarification**. Do not guess. Project Documents = `./Project_Docs/*.md` (excluding `./Project_Docs/Completed_Features/*`) plus files in `./.cursor/rules/*`.
- **Completed_Features scope:** Do not treat `./Project_Docs/Completed_Features/**` as authoritative requirements when implementing, reviewing, or reconciling behavior unless the user explicitly asks to use them. Those files are archived; active specs live in non-archived `Project_Docs` and `.cursor/rules`.
- **Feature-doc scope guard:** When implementing a specific feature, treat only the explicitly referenced feature plan (plus `./.cursor/rules/*`) as authoritative. Any other files in `./Project_Docs/*.md` that are not explicitly referenced by the active feature request should be treated as **feature drafts** and must not override the active feature requirements.
- **Refactoring:** Do not rename or move files once they have been created. Renaming files will break the contextual rule application and is strictly prohibited.

## Formatting

**Applies when:** You add or change formatted source code.

**Follow the project style guide:**

- Use 2-space indentation.
- Put the opening brace on the same line when the language's usual style allows it.
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
- Prefer a clear Arrange-Act-Assert (or equivalent) structure.
- Use test names that state intent.

## Project Docs interactions

### Agentic assisted design

**Applies when:** You write or revise design documents that an agentic developer is expected to implement from.

**Use these embedded markers** so the next review pass can find open design conversation:

- `<<Question: …>>` - Ask the agent for information or clarification the next time it reads this doc.
- `<<Comment: …>>` - Note an area that needs more thought, a reminder for the author, or something author and agent should resolve together.

### Debugging assistance (OLog)

**Applies when:** You create or refactor code where understanding control flow or failures matters.

**Use `OLog` roughly as follows** (full policy: [logging_instr.md](./focus/logging_instr.md)):

- `info()` - Major lifecycle or state events (e.g. thread or subsystem start/stop).
- `debug()` - Frequent path tracing when needed (e.g. a collision or decision branch), without flooding logs.
- `error()` - Likely failures, violated assumptions, or recoverable errors worth investigating.

## Focus areas (index)

Detailed rules live only in these files; add more pointers here as new focus areas appear (e.g. UI).

**Ignore inconsistencies in historical files:** Files under `./Project_Docs/Completed_Features` are archived; see **Completed_Features scope** under Behavioral instructions. Do not treat them as active requirements unless a maintainer explicitly asks. Cross-doc drift with those files is expected.

- **Logging (policy, PII, volume):** [logging_instr.md](./focus/logging_instr.md)
- **Runtime / in-game AI agents (embedded LLM), not IDE assistants:** [agentic_coding.md](./focus/agentic_coding.md)
- **Assets (`res://assets/`, `pack_resources.json`, variants):** [asset_management.md](./focus/asset_management.md) — full design in [ASSET_MANAGEMENT_PLAN.md](../../Project_Docs/ASSET_MANAGEMENT_PLAN.md)
