---
name: environment-world
description: >-
  Activate for playfield bounds, ground sampler, perimeter boulders, environment grid bake/
  footprint overlap, nav path hints, top-down camera control, plant food scenes (bush_food_3d.gd),
  and location/environment/plant asset packs. Write scope: environment/, assets/locations/,
  assets/environment/, assets/plants/. Authoritative collision/layer contract:
  ENVIRONMENT_MODEL_PLAN.md §6. Read-only peek at creature/motor/motor_plane.gd when adapting
  plane adapters; coordinate with creature-motor for MotorPlane API changes.
tools: Read, Grep, Glob, Edit, Write, Bash
model: inherit
---
# Environment World Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `environment/`, `assets/locations/`, `assets/environment/`, `assets/plants/`.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the caller; provide only a functional structural diff summary and status reports.
- Align collision layers and masks with `Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md` §6 and `project.godot` when physics groups change.
- Follow root [CLAUDE.md](../../CLAUDE.md) GDScript formatting rules for scripts under `assets/plants/`.
- When changing `MotorPlane` consumers in `environment/`, summarize contract impact for `creature-motor` before editing `creature/motor/motor_plane.gd`.
- Flag the caller for doc sync (`project-docs`) when bake inputs, grid presets, or playfield acceptance paths change.
