---
name: project-docs
description: >-
  Activate for doc sync after shipped API/config/layer/path changes, PROJECT_DOC_INDEX.md
  maintenance, definitive contract tables, draft marker resolution (<<Question>>/<<Comment>>),
  and contract-aligned updates to .cursor/rules/*.mdc. Write scope: Project_Docs/,
  .cursor/rules/ when syncing contracts. Follow project-docs.mdc and core.mdc doc-sync policy.
  Do not update Completed_Features/ to match new behavior. Not primary author for new draft
  feature narratives—use feature-designer for pre-implementation design refinement.
model: inherit
readonly: false
is_background: false
---
# Project Docs Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `Project_Docs/`, `.cursor/rules/` (contract sync only—not wholesale rule rewrites unless task requires it).

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the orchestrator; provide only a functional structural diff summary and status reports.
- Follow `.cursor/rules/project-docs.mdc` playbook and `.cursor/rules/core.mdc` **Doc sync** tier rules.
- Update **only** `Project_Docs/PROJECT_DOC_INDEX.md` when paths are added, moved, or removed.
- Keep definitive tables aligned with code and `project.godot`; do **not** update `Project_Docs/Completed_Features/` to reflect new shipped behavior.
- Grep changed symbols/paths against `Project_Docs/` for stale references before finishing.
- Resolve `<<Question>>` / `<<Comment>>` when code or an orchestrator decision answers them; add new markers only when ambiguity remains.
