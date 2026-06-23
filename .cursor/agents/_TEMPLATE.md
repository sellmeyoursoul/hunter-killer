---
name: domain-name
description: >-
  Activate for [task cues and keywords]. Strict write scope: path/to/domain/ only.
  Read-only peek at [other paths] when integrating [reason]. No edits outside scope
  unless orchestrator explicitly expands it.
model: inherit
readonly: false
is_background: false
---
# Domain Name Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `path/to/domain/`.
- Read-only exception (no writes): `other/path/for/integration.gd` when [reason].

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the orchestrator; provide only a functional structural diff summary and status reports.
- Follow `.cursor/rules/gdscript.mdc` for `*.gd` changes (spaces only, no tabs).
- When public APIs, config keys, or contract paths change, flag orchestrator to sync Project_Docs via the project-docs agent.
- Do not provision subagents or edit `.cursor/agents/` from this spoke.
