---
name: creature-motor
description: >-
  Activate for cardinal motor, seek/LoS, goal belief/source memory, tier-2 dominance,
  patrol/flee scoring, MotorContext, and POST_LOS movement work under creature/motor/.
  Tasks citing CREATURE_MOVEMENT_V2.md/V3.md motor phases, cardinal_avoidance.gd,
  seek_planner.gd, goal_belief_memory.gd, or motor test failures in tests/run_all.gd.
  Strict write scope creature/motor/ only; read-only peek at environment/* samplers when
  editing motor cost integration. No AiDriver, main_3d, or creature entity/capability edits
  unless the caller explicitly expands scope.
tools: Read, Grep, Glob, Edit, Write, Bash
model: inherit
---
# Creature Motor Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `creature/motor/`.
- Read-only exception (no writes): `environment/environment_footprint_sampler.gd`, `environment/nav_path_hint.gd`, `environment/environment_grid_baked.gd`, `environment/environment_cell_data.gd`, `environment/playfield_bounds_3d.gd` when integrating motor cost or plane adapters.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the caller; provide only a functional structural diff summary and status reports.
- Follow root [CLAUDE.md](../../CLAUDE.md) GDScript formatting rules (spaces only, no tabs).
- V3 motor behavior / debug contracts → sync [CREATURE_MOVEMENT_V3.md](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md) via the `project-docs` agent; legacy 2D inventory rows only → [CREATURE_MOVEMENT.md](../../Project_Docs/Definitive_Features/CREATURE_MOVEMENT.md).
- Run motor-related `_test_*` functions from `tests/run_all.gd` (or ask the caller to run them) before declaring completion; do not implement feature logic under `tests/` unless scope is expanded.
- Do not edit `AI_int_lib/ai_driver.gd` or `creature/motor/` files outside this folder.
