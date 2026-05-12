# Hunter-Killer field, perception, and obstacles (active)

This document tracks the **Hunter-Killer** fork goals: enlarged playfield (`art/Creep_field.png`), scripted motor **awareness radius**, **forward cone**, **mob memory ghosts**, and **static obstacles** for the avoidance motor.

**Baseline motor contract (delivered earlier):** [Completed_Features/MOB_AVOIDANCE_PLAN.md](Completed_Features/MOB_AVOIDANCE_PLAN.md).

**Fork workflow (GitHub + local clone):** [FORK_HUNTER_KILLER.md](FORK_HUNTER_KILLER.md).

## Playfield and scene

| Item | Detail |
|------|--------|
| Viewport | `project.godot` `[display]` matches **Creep_field.png** pixel size (**1890×1050**). |
| Background | `main.tscn` `TextureRect` uses `res://art/Creep_field.png`, full-rect placement. |
| Mob spawn path | `Path2D` curve is a rectangle inset **12 px** from the border (same role as the old inset margin). |
| Start | `StartPosition` near center of field. |
| Solids | Instanced `res://obstacle_field.tscn` under Main — `StaticBody2D` nodes in group `obstacles` with `RectangleShape2D` approximations; tune positions/sizes in the editor to match the art. |

**Note:** Player remains `Area2D`; obstacle avoidance in the first milestone is **motor-only** (no physics blocking). Add collision layers / `CharacterBody2D` later if the creature must not overlap rocks.

## `creature_motor` configuration keys

| Key | Type | Meaning |
|-----|------|---------|
| `awareness_radius` | float | Base max distance (px) from creature **center** to mob **center** (or mob→footprint closest point when half-extents positive) for which inverse-distance / closing terms apply. Mobs farther away are skipped unless cone extends reach. |
| `awareness_cone_extra` | float | Extra reach (px) added along **forward sector** (see half-angle). |
| `awareness_cone_half_angle_deg` | float | Half-angle of forward cone in degrees; total cone width is `2 ×` this value. |
| `awareness_memory_ticks` | int | Ring buffer depth of recent mob snapshots (`0` disables memory). |
| `awareness_memory_weight` | float | `cost_scale` for ghost predictions and for **gated** live mobs (out of reach but extrapolated). |
| `awareness_memory_horizon_sec` | float | Extrapolation horizon `pos + vel * horizon` for ghosts; `0` uses `memory_ticks / physics_ticks_per_second`. |
| `weight_obstacle` | float | Scales inverse-distance repulsion from `static_obstacles` (same clearance math as mobs, no closing term). |

Defaults live in `AI_int_lib/game_config_merge.gd`; repo overrides in `game_config.json`.

## Runtime wiring

- **`player.gd`:** `last_move_direction` updates when `current_velocity.length() > 1.0`; idle keeps last facing.
- **`AiDriver`:** `_motor_mobs_array` builds live + memory entries; `_mob_hist` ring buffer updated each physics tick while **PLAYING**; `_static_obstacles_for_motor` scans group `obstacles` for `StaticBody2D` + `RectangleShape2D` children.
- **`CardinalAvoidance`:** `cost_at_prediction` applies awareness gating from **current** creature center, optional cone reach, per-mob `cost_scale`, and obstacle list.

## Headless tests

```text
godot --path . --headless -s res://tests/run_all.gd
```

`tests/run_all.gd` covers: radius gating (no cost from far mob), cone (forward vs aft), `cost_scale` halving, obstacle repulsion.

## Interactive / manual checklist

1. Arm AI session, scripted motor: confirm creature does not **constantly hug walls** when mobs are clearly outside awareness (tune `awareness_radius` / `weight_edge` / `weight_interior` as needed).
2. Move in a line: verify stronger reaction to threats **ahead** vs **behind** at similar map distance (cone + extra reach).
3. Let a mob leave the radius: behavior should still reflect **recent** motion (memory ghosts); reduce `awareness_memory_weight` if oscillation appears.
4. Navigate between rock rectangles: motor should steer around; adjust `obstacle_field.tscn` or `weight_obstacle` if clipping is too soft or too harsh.
