# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hunter-Killer is a 3D game built in **Godot 4.6 (GDScript)** featuring a predator/prey duel (fox vs. rabbit) in a grasslands arena. The primary technical innovation is a **dual motor system**: creatures can be driven by a scripted 9-way cardinal avoidance engine (ENGINE mode) or by a TinyLlama LLM over an OpenAI-compatible HTTP API (AI mode). The player controls the herbivore.

## Running & Testing

**Open project in Godot editor:**
```
godot --path .
```

**Run all headless tests:**
```
godot --path . --headless -s res://tests/run_all.gd
```

**Run focused motor/motivation tests only:**
```
godot --path . --headless -s res://tests/run_motor_motivation_only.gd
```

There is no separate build step — open the project in Godot 4.6 and press F5 (or use Project → Export for a standalone build). Jolt Physics and D3D12 are required.

## Configuration

Behavior is controlled by a three-layer config merge (`AI_int_lib/game_config_merge.gd`):

1. Hardcoded defaults in `game_config_merge.gd`
2. `res://game_config.json` (project-level overrides, committed)
3. `user://game_config.json` (per-machine overrides, not committed)

The `GameConfig` autoload exposes `get_logging_params()`, `get_inference_client()`, `get_perception_params()`, and `get_creature_motor_params()`. Key config key: `creature_motor.mode` — set to `"scripted"` (ENGINE) or `"llm"` (AI).

## Architecture

### Entry Point
`main_3d.gd` loads the grasslands scene, spawns a herbivore + carnivore creature pair, attaches AI drivers, manages the HUD/camera, and handles round lifecycle.

### AI Driver (`AI_int_lib/ai_driver.gd`)
The central orchestrator. States: IDLE → ARMED → PLAYING → WAITING. Each physics tick it either:
- **(ENGINE mode):** Calls `CardinalAvoidance.pick_best_move_intent()` and pushes the resulting `Vector3` intent directly to the creature.
- **(LLM mode):** Builds a `perception_wire.gd` snapshot blob, POSTs to the inference server, and on response maps tokens (`START/UP/DOWN/LEFT/RIGHT`) back to creature intent.

This file is large (~375 KB). The motor logic is controller-agnostic — the same `CreatureKinematicBody3D` receives intents from either path.

### Motor System (`creature/motor/`)
- **`cardinal_avoidance.gd`** — Core scoring engine. Scores 9 candidate directions (8-way + idle), picks minimum cost. Weights come from `game_config.json`.
- **`motor_target_builder.gd`** — Ingests goals and threats to feed the scorer.
- **`motor_plane.gd`** — Adapts 2D XZ motor logic to 3D world space (Y is up; movement is XZ-planar).
- **`jeopardy_forced_turn.gd`** — Overrides motor output on imminent collision threat.
- **`terrain_motor.gd`** — Elevation-aware movement hints from baked ground sampler.
- **`seek_planner.gd`** — Multi-stage goal-seeking pipeline (candidates → commitment → turning → stationary look).

### Creature System (`creature/`)
- **`definition/creature_definition.gd`** — Species data Resource (vitals, perception scales, traits, diet mode). Instances: `species/rabbit_archetype.tres`, `species/fox_archetype.tres`.
- **`capabilities/creature_kinematic_body_3d.gd`** — Physics integration (`CharacterBody3D`). Translates `Vector3` move intent to `move_and_slide()` + visual facing sync.
- **`capabilities/creature_vitals_component.gd`** — Calorie burn, starvation, predation clamping per tick.
- **`capabilities/creature_control_mode.gd`** — Enum: `HUMAN / ENGINE / AI`.

### Environment (`environment/`)
- **`playfield_bounds_3d.gd`** — Rectangular arena with collision walls. Physics layer 1.
- **`playfield_ground_sampler.gd`** — Bakes an elevation grid at startup; queried by `terrain_motor.gd`.
- Physics layers: 1 = static, 2 = player/prey, 4 = carnivores, 8 = plant mob blockers.

### Logging
`oLog_lib/olog.gd` — Autoload. Configurable log level, line caps, queue limits via `logging_params` config section.

## Documentation Tiers

Project docs live in `Project_Docs/` and follow a strict hierarchy — **always consult the highest applicable tier**:

| Tier | Path | Status |
|------|------|--------|
| III (Definitive) | `Project_Docs/Definitive_Features/` | Current contracts — authoritative |
| II (Draft) | `Project_Docs/Draft_Features/` | Active design — may supersede Tier III |
| A (Completed) | `Project_Docs/Completed_Features/` | Shipped snapshots — drift expected |

Key Tier III docs: `CREATURE_3D_ARCHITECTURE.md`, `CREATURE_MOVEMENT.md`, `CREATURE_TRAIT_USAGE.md`.
Key Tier II docs: `CREATURE_MOVEMENT_V2.md` (V3 motor refactor in progress), `CREATURE_GOAL_DRIVERS.md`, `CREATURE_MEMORY.md`.

When a Tier II draft conflicts with a Tier III definitive, the draft takes precedence for in-flight work; flag the conflict rather than silently picking one.

## GDScript Conventions

- Use tabs for indentation (enforced by `.editorconfig`).
- Motor and vitals logic must be pure (no side effects on `Node` state) to remain unit-testable headlessly.
- All hardcoded tuning constants belong in `game_config.json`, not in source files.
- `ai_driver.gd` is intentionally monolithic — resist splitting unless the V3 refactor spec (`CREATURE_MOVEMENT_V3`) calls for it.

# Project Instructions
Please adhere to the coding standards and guidelines outlined in the `.cursor/rules/` directory.