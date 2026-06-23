---
name: creature-entity
description: >-
  Activate for CreatureDefinition, LocomotionProfile, FoodIntakePolicy, vitals/predation/
  perception capabilities, kinematic body, diet registry, species .tres archetypes, 3D
  template scenes, GoalKindRegistry, CreatureRoot3D, and awareness debug overlay. Write
  scope: creature/definition/, creature/capabilities/, creature/species/, creature/templates/,
  creature/memory/, creature/creature_root_3d.gd, creature/awareness_debug_overlay_3d.gd.
  Not creature/motor/ (use creature-motor). Authoritative docs: CREATURE_3D_ARCHITECTURE.md,
  CREATURE_ATTRIBUTES_USAGE.md, CREATURE_TRAIT_USAGE.md.
model: inherit
readonly: false
is_background: false
---
# Creature Entity Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `creature/definition/`, `creature/capabilities/`, `creature/species/`, `creature/templates/`, `creature/memory/`, `creature/creature_root_3d.gd`, `creature/awareness_debug_overlay_3d.gd`.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the orchestrator; provide only a functional structural diff summary and status reports.
- Follow `.cursor/rules/gdscript.mdc` and align with `Project_Docs/Definitive_Features/CREATURE_3D_ARCHITECTURE.md` for scene graph and intent API contracts.
- Keep pure math in capability helper scripts; keep runtime state on Node-attached components per definitive architecture tables.
- Delegate movement/seek/LoS logic changes to creature-motor; do not edit `creature/motor/` from this agent.
- Flag orchestrator for doc sync when public definition fields, template paths, or trait/stat usage maps change.
