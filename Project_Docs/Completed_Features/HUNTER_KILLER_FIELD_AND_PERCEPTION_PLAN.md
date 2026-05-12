# Hunter-Killer field, perception, and obstacles (archived)

**Status:** Completed (2026-05-12). Archived under `Project_Docs/Completed_Features/`. Delivered behavior lives in the repo (`AiDriver`, `CardinalAvoidance`, `player.gd`, `creature/awareness_debug_overlay.gd`, `main.tscn`, `obstacle_field.tscn`, `game_config_merge.gd`, `project.godot`) and headless tests in `tests/run_all.gd`. For new Hunter-Killer design work, use active (non-archived) documents in `Project_Docs/`.

This document recorded the **Hunter-Killer** fork goals: enlarged playfield (`art/Creep_field.png`), scripted motor **awareness radius**, **forward cone**, **mob memory ghosts**, and **static obstacles** for the avoidance motor.

**Historical references (same folder):** [MOB_AVOIDANCE_PLAN.md](MOB_AVOIDANCE_PLAN.md) (older motor phase), [FORK_HUNTER_KILLER.md](FORK_HUNTER_KILLER.md) (fork workflow for humans).

**Baseline motor scoring:** Hunter-Killer does **not** redefine the core cost sum (inverse clearance, closing, OOB, interior/edge, footprint keys). Keep the existing **`creature_motor`** keys and `ctx` fields already wired in the repo (**`weight_dist`**, **`weight_dist_sq`**, **`weight_closing`**, **`weight_interior`**, **`weight_edge`**, **`penalty_oob`**, **`distance_eps`**, **`lookahead_sec`**, **`scripted_intent_hold_physics_ticks`**, **`creature_half_extent_*`** / capsule override, **`shuffle_tie_break`**, **`mode`**, etc.). This file added field/scene layout and the perception keys in the tables below.

## Playfield and scene

| Item | Detail |
|------|--------|
| Viewport | `project.godot` `[display]` matches **Creep_field.png** pixel size (**1890×1050**). |
| Background | `main.tscn` `TextureRect` uses `res://art/Creep_field.png`, full-rect placement. |
| Mob spawn path | `Path2D` curve is a rectangle inset **12 px** from the border (same role as the old inset margin). |
| Start | `StartPosition` near center of field. |
| Solids | Instanced `res://obstacle_field.tscn` under Main — `StaticBody2D` nodes in group `obstacles` with `RectangleShape2D` approximations; tune positions/sizes in the editor to match the art. |

**Obstacle shapes (this phase):** `_static_obstacles_for_motor` only considers **direct child** nodes of each `StaticBody2D` in group `obstacles` that are `CollisionShape2D` with shape `RectangleShape2D`. Collision shapes nested under an intermediate node, or non-rectangle shapes, are **not** collected unless the pipeline is extended later.

**Note:** Player remains `Area2D`; obstacle avoidance in the first milestone is **motor-only** (no physics blocking). Add collision layers / `CharacterBody2D` later if the creature must not overlap rocks.

## `creature_motor` configuration keys

| Key | Type | Meaning |
|-----|------|---------|
| `awareness_radius` | float | When **> 0**, base max distance (px) from creature **center** to mob **center** (or mob→footprint closest point when half-extents positive) for the distance gate; mobs farther than **effective reach** (see cone below) are not direct “live” samples unless memory rules add them. When **≤ 0**, there is **no finite distance cap** for that gate: this does **not** mean “no awareness”—it means every mob the driver passes to the motor is treated as within range for distance purposes (still subject to motor list construction and memory rules). |
| `awareness_cone_extra` | float | Extra reach (px) added along **forward sector** (see half-angle). If **≤ 0**, the forward sector does **not** extend reach beyond `awareness_radius` (half-angle alone has no distance effect). |
| `awareness_cone_half_angle_deg` | float | Half-angle of forward cone in degrees; total cone width is `2 ×` this value. Values **> 90°** are allowed (wide peripheral or “wrap” vision); **180° and above** can make the forward sector cover the full circle for reach purposes (fantastical omnidirectional awareness). |
| `awareness_memory_ticks` | int | Ring buffer depth of recent mob snapshots. **`0` = no object permanence:** nothing outside current effective awareness is carried via the memory channel (no ghosts; gated live extrapolation is not emitted). |
| `awareness_memory_weight` | float | `cost_scale` for ghost predictions and for **gated** live mobs (out of effective reach but extrapolated). **`0`** means those samples are not weighted into the cost for **this phase** (same practical outcome as omitting them; a future phase may distinguish “buffer on, weight `0`” from “no buffer”). |
| `awareness_memory_horizon_sec` | float | Extrapolation horizon `pos + vel * horizon` for ghosts (and gated live extrapolation); `0` uses `memory_ticks / physics_ticks_per_second`. **This phase** uses this single-step extrapolation only; richer memory models are out of scope until specified. |
| `weight_obstacle` | float | Scales inverse-distance repulsion from `static_obstacles` (same clearance math as mobs, no closing term). |

**Mob inclusion (normative):** The creature must **not** incur mob repulsion terms for mobs it is **unaware** of under the rules above—**except** when a **ghost** entry is included because prior snapshots in `_mob_hist` still support extrapolation under the memory keys. Live mobs beyond effective reach are only represented when memory adds gated or ghost samples.

**Cone geometry (normative, matches `CardinalAvoidance.effective_awareness_reach`):** Let **`u`** be the unit vector from **creature center → mob (or ghost) position**, and **`f`** the creature **facing** (`last_move_direction`, or `Vector2.RIGHT` if degenerate). Let **`θ`** be this half-angle in radians. The mob lies in the forward sector when **`u·f ≥ cos(θ)`**. **Effective reach** is **`awareness_radius + awareness_cone_extra`** in that sector and **`awareness_radius`** elsewhere (a step in direction space, not a smooth blend). The runtime passes **`cos(θ)`** as `awareness_cone_cos_threshold` in the motor `ctx`; authors tune **`awareness_cone_half_angle_deg`** only.

Defaults live in `AI_int_lib/game_config_merge.gd`; repo overrides in `game_config.json`.

**LLM snapshot scope:** `_build_snapshot_blob()` in `AiDriver` builds the **text blob for HTTP inference** when the session is in **PLAYING** LLM mode. It is **not** consumed by the **ENGINE** / scripted cardinal motor path. Motor awareness for scripting is entirely `_motor_mobs_array` → `ctx`; snapshot contents are out of scope for this perception spec unless LLM perception is explicitly redesigned.

## Debug overlay (viewport)

Like the editor’s **Debug → Visible Collision Shapes** view, but **runtime** and specific to perception (optional):

| Mechanism | Behavior |
|-----------|----------|
| Project Settings | `hunter_killer_debug/draw_awareness` (**bool**, default off) — when **true**, draws awareness overlay whenever a round is running. |
| Dev toggle | In **`OS.is_debug_build()`** builds only, **F9** toggles the overlay on/off for the current process (ORed with the project setting so designers can force it on via settings). |

Implementation: `Player/AwarenessDebugOverlay` (`creature/awareness_debug_overlay.gd`) — base **radius** circle, **forward cone** boundary for the extra reach band, and markers for **gated live** vs **memory ghost** mob samples (last snapshot from `AiDriver`).

## Runtime wiring

- **`player.gd`:** `last_move_direction` updates when `current_velocity.length() > 1.0`; idle keeps last facing.
- **`AwarenessDebugOverlay`:** child of Player; draws awareness disk, forward cone extra band, and **gated** / **ghost** markers when `hunter_killer_debug/draw_awareness` is on or **F9** was pressed in a debug build.
- **`AiDriver`:** `_motor_mobs_array` builds live + memory entries; `_mob_hist` ring buffer updated each physics tick while **PLAYING**; `_static_obstacles_for_motor` scans group `obstacles` (see **Obstacle shapes** under Playfield for which collision nodes qualify).
- **`CardinalAvoidance`:** `cost_at_prediction` applies awareness gating from **current** creature center, optional cone reach, per-mob `cost_scale`, and obstacle list.

**Physics tick ordering (implementation note):** On each **PLAYING** tick, scripted motor intent is resolved **before** `_record_mob_history_if_playing()` appends the new ring-buffer snapshot. If diagnosing “memory vs motor” timing, expect the newest `_mob_hist` entry to reflect the state **after** that tick’s motor decision, not before it.

## Headless tests

```text
godot --path . --headless -s res://tests/run_all.gd
```

`tests/run_all.gd` covers: positive-radius gating (far mob adds no cost), nonpositive `awareness_radius` (no finite distance cap), cone forward vs aft, `awareness_cone_extra` zero vs positive, `effective_awareness_reach` at 180° vs narrow half-angle, `cost_scale` halving, obstacle repulsion.

## Interactive / manual checklist

1. Arm AI session, scripted motor: confirm creature does not **constantly hug walls** when mobs are clearly outside awareness (tune `awareness_radius` / `weight_edge` / `weight_interior` as needed).
2. Move in a line: verify stronger reaction to threats **ahead** vs **behind** at similar map distance (cone + extra reach).
3. Let a mob leave the radius: behavior should still reflect **recent** motion (memory ghosts); reduce `awareness_memory_weight` if oscillation appears.
4. Navigate between rock rectangles: motor should steer around; adjust `obstacle_field.tscn` or `weight_obstacle` if clipping is too soft or too harsh.
