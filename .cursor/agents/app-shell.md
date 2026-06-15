---
name: app-shell
description: >-
  Activate for duel round lifecycle in main_3d, HUD vitals/buttons, GameConfig autoload facade,
  game_config.json, OLog autoload, pack_resource_resolver, product_brand, project.godot
  (main scene, autoload order, input, debug), and legacy art/ audio referenced by main scene.
  Write scope: main_3d.gd, main_3d.tscn, hud.gd, hud.tscn, game_config.gd, game_config.json,
  oLog_lib/, pack_resource_resolver.gd, product_brand.gd, project.godot, art/. Integration
  owner—delegate motor, AI orchestration, and entity logic to domain agents rather than inlining.
model: inherit
readonly: false
is_background: false
---
# App Shell Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `main_3d.gd`, `main_3d.tscn`, `hud.gd`, `hud.tscn`, `game_config.gd`, `game_config.json`, `oLog_lib/`, `pack_resource_resolver.gd`, `product_brand.gd`, `project.godot`, `art/`.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the orchestrator; provide only a functional structural diff summary and status reports.
- Preserve autoload order in `project.godot`: GameConfig → OLog → AiDriver.
- Keep `game_config.gd` as facade; merge logic stays in `AI_int_lib/game_config_merge.gd` (ai-runtime agent).
- Wire integration only in main/hud; do not duplicate motor scoring or perception assembly—call AiDriver and creature APIs.
- Follow `.cursor/rules/logging.mdc` when changing OLog config consumption paths.
- Flag orchestrator for doc sync when autoload paths, main scene, or resolver tag contracts change.
