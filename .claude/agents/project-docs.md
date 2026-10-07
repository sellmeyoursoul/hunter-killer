---
name: project-docs
description: >-
  Activate for doc sync after shipped API/config/layer/path changes, PROJECT_DOC_INDEX.md
  maintenance, definitive contract tables, draft marker resolution (<<Question>>/<<Comment>>),
  and contract-aligned updates to CLAUDE.md files. Write scope:
  Project_Docs/ and the CLAUDE.md files (root and nested). Follow
  Project_Docs/CLAUDE.md and root CLAUDE.md doc-sync policy. Do not update Completed_Features/
  to match new behavior. Not primary author for new draft feature narratives — use
  feature-designer for pre-implementation design refinement.
tools: Read, Grep, Glob, Edit, Write
model: inherit
---
# Project Docs Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `Project_Docs/`, nested `CLAUDE.md` files (`CLAUDE.md`, `Project_Docs/CLAUDE.md`, `assets/CLAUDE.md`, `AI_int_lib/CLAUDE.md`, `oLog_lib/CLAUDE.md`) (contract sync only — not wholesale rule rewrites unless task requires it).

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the caller; provide only a functional structural diff summary and status reports.
- Follow [Project_Docs/CLAUDE.md](../../Project_Docs/CLAUDE.md) playbook and root [CLAUDE.md](../../CLAUDE.md) **Doc sync** tier rules.
- Update **only** `Project_Docs/PROJECT_DOC_INDEX.md` when paths are added, moved, or removed.
- Keep definitive tables aligned with code and `project.godot`; do **not** update `Project_Docs/Completed_Features/` to reflect new shipped behavior.
- When a contract is stated in more than one `CLAUDE.md` file (e.g. OLog hygiene appears in both `oLog_lib/CLAUDE.md` and `AI_int_lib/CLAUDE.md`), update every copy in the same change — they must not drift from each other.
- Grep changed symbols/paths against `Project_Docs/` for stale references before finishing.
- Resolve `<<Question>>` / `<<Comment>>` when code or a caller decision answers them; add new markers only when ambiguity remains.
