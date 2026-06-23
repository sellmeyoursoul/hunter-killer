---
name: assets-pack
description: >-
  Activate for pack_resources.json schema, shared_resources tags, creature blend/texture
  imports, _shared/default fallbacks, per-pack creature_motor overlays, and missing-dev/
  missing-release placeholders. Write scope: assets/creatures/, assets/_shared/. Follow
  assets.mdc. Pipeline intent reference only: Completed_Features/ASSET_MANAGEMENT_PLAN.md.
  Read-only peek at pack manifests under assets/plants/ when cross-pack tags align; resolver
  code changes belong to app-shell (pack_resource_resolver.gd).
model: inherit
readonly: false
is_background: false
---
# Assets Pack Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `assets/creatures/`, `assets/_shared/`.
- Read-only exception (no writes): `assets/plants/*/pack_resources.json` and other domain manifests when verifying tag consistency.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the orchestrator; provide only a functional structural diff summary and status reports.
- Follow `.cursor/rules/assets.mdc` for domain layout, `_shared/default/` usage, and pack_resources.json schema.
- Do not reference `res://assets/_shared/` directly from gameplay code—logical tags resolve via `pack_resource_resolver.gd` (app-shell).
- When adding `creature_motor` overlay keys, flag orchestrator to verify merge behavior in `AI_int_lib/game_config_merge.gd` and headless tests.
- Keep new authored content under `assets/` domain folders; do not add gameplay scripts here unless they are pack-private helpers cited in assets.mdc.
