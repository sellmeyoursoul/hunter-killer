# Motor play baseline (Phase 1 → Phase 3)

**Last updated:** 2026-06-12  
**Regression anchor:** `godot --path . --headless -s res://tests/run_all.gd` (Godot 4.6.2 steam tools).

**Duel species packs:** Herbivore **rabbit** → `res://assets/creatures/rabbit/pack_resources.json` ([`rabbit_archetype.tres`](../../creature/species/rabbit_archetype.tres) on Player). Carnivore **fox** → `res://assets/creatures/fox/pack_resources.json` ([`fox_archetype.tres`](../../creature/species/fox_archetype.tres) on Mob). Editor default stays **dev** profile; pack overlays restore seek/prey and zero chaos for playtest (`resolver_smoke` remains headless-only).

**Round end:** Duels end on **starvation** or **predation** only — no wall-clock round timer ([`main.gd`](../../main.gd)).

## Phase 3 duel gates (tier 1 — before Phase 4)

Authoritative spec: [CREATURE_MOVEMENT_V2.md §Phase 3 — exit tiers and gates](../Draft_Features/CREATURE_MOVEMENT_V2.md).

| Gate | Pass |
|------|------|
| **Advance** | ≥1 `predation_carn_win` (fox) **and** ≥1 `starvation_carn_herb_win` (rabbit) on `main_3d` with 2× playtest boost |
| **Ship viability** | ≥1 win (either species) with `hunter_killer_debug/use_ship_motor_profile = true` |
| **Dev negative** | Default dev profile: no sustained seek / obvious aberrant loop; `_test_creature_motor_v2_profiles` green |

Log rows in [CREATURE_GOALS_PLAYTEST_LOG.md](../Completed_Features/CREATURE_GOALS_PLAYTEST_LOG.md). Re-run all three gates after **major** motor merge / profile / duel-pack changes.

## How to run QA profile (editor)

| Method | When to use |
|--------|-------------|
| **Project Settings → `hunter_killer_debug/use_ship_motor_profile`** = `true` | Editor playtest with **ship** motor (normal seek, no dev chaos). Restart scene after toggling. |
| **Export feature `creature_motor_ship`** | Release / ship builds (same as ship profile merge). |
| **Default (setting off)** | `creature_motor_profile_dev` — wiring/regression only (`weight_seek_ready_food = 0`, high chaos). |

## Profile summary

| Profile | `weight_seek_ready_food` | `motor_intent_cost_chaos` | Purpose |
|---------|--------------------------|---------------------------|---------|
| **dev** (default editor) | 0 | 8 | Aberrant wiring detector |
| **ship** | 16 | 0 | Phase 3 playtest / release tuning |

## Scenario matrix

| Scenario | Setup | Pass criteria (ship profile) |
|----------|--------|------------------------------|
| **1. Herbivore forage** | Rabbit pack on Player, calories &lt; ~80% need, ready bushes in cone | Moves toward ready food (including diagonals); avoids depleted bushes when mixed; seek weakens in preserve band (~90%+ calories). With **no plant in cone**, expanding **8-way** hint (`herbivore_expanding_explore_mul` × pack hint) sweeps off walls; stuck escape uses `weight_stuck_escape_explore` (not predator prey-floor keys). |
| **2. Mob pursuit** | Duel carnivore (fox pack on Mob), prey not yet in awareness | **No-goal guided patrol lock:** expanding **8-way** hint (`expanding_cardinal_explore` + `predator_patrol_explore_mul`) held for one segment; trail repulsion active; random lock remains for herbivore. Chase when prey enters awareness. Memory expand only after first live sight. |
| **2b. Run variance** | Replay duel; fox patrol before contact | Patrol legs follow expand sweep (segment-aligned lock); phase_seed still varies spawn offset. Chase leg stays directed once prey in cone. |
| **3. Jeopardy flee** | Fox enters rabbit **awareness cone** (not omni); panic flee only inside `herbivore_flee_panic_radius_px` footprint distance | No flee while fox is off-cone/behind; alert band keeps partial forage seek. |
| **4. Hunt corner escape** | Fox chasing prey, pinned on shrub AABB | After one tick with intent but no displacement, hunt forces clearance **8-way** step or rotating explore heading (`predator_hunt_stuck_rotate_ticks`). |
| **5. Predator NE-corner patrol** | Fox no-goal patrol hugging NE playfield rim (~100 m mains) | **`motor_corner_hugging`** arms latched interior escape (`_predator_latched_corner_escape_intent`); patrol expand hint prefers interior diagonal over perpetual rim slide; pacing-trap break uses corner egress at wall-only corners. Watch OLog **`corner_esc`**. |

## Automated verification (headless)

| Check | Test / code |
|-------|-------------|
| Dev profile aberrant | `_test_creature_motor_v2_profiles` |
| Ship profile seek restored | same |
| Locale prior write + pull | `_test_goal_source_memory` |
| Escalate seek multiplier | `_test_locale_prior_escalate_seek` |
| AH-7 reversal suppress | `_test_escape_reversal_suppression` (no SceneTree `add_child`) |
| Coarse belief TTL | `_test_goal_belief_coarse_ttl` |
| Predator chase without explore | `_test_predator_chase_motor_ctx` |
| No-goal patrol lock | `_test_no_goal_patrol_lock` |
| No-goal guided patrol (fox) | `_test_no_goal_patrol_lock_guided`, `_test_predator_patrol_expanding_coverage` |
| Predator south-wall pinch escape | `_test_predator_south_wall_boulder_pinch_escape`, `_test_predator_pacing_trap_break` |
| Predator NE-corner interior escape | `_test_predator_northeast_corner_interior_escape` |
| 3D playfield-scaled cardinal probes | `_test_motor_cardinal_probe_scaled_for_small_playfield` |
| Expand hint cardinal | `_test_expanding_cardinal_explore` (UP vs idle) |

## After memory (Phase 2 + Phase 3 retune)

**Code enabled:** `LocalePriorMap`, `_goal_belief`, eat/jeopardy salient writes, `replay_weight`, escalate band (`believed_goal_seek_escalate_radius_px`).

| Scenario | Expected delta vs spine-only |
|----------|------------------------------|
| **Herbivore forage** | After eating, weak pull toward remembered patch cells within 250 px hotspot; `replay_weight` may boost seek when consult hash matches; remembered bushes outside awareness merge only inside `goal_memory_precise_radius_px` (no coarse GPS Vector2). |
| **Mob pursuit** | Unchanged predator path (memory phase-1 herbivore-focused). |
| **Jeopardy flee** | Jeopardy clear may write `avoid_hostiles` locale row; AH-7 suppresses write if starvation reversal re-enters threat within 1 s. |

**Phase 3 tuning applied (ship profile):** `weight_believed_goal_pull` **5.2** (spine 6.4), `locale_prior_write_blend` **0.32**, `believed_goal_escalate_seek_mul` **1.4**. Revisit after live playtest.

## Maintainer notes

- Record clip paths or short prose under each scenario when validating in-editor.
- If motor regresses vs table above, adjust `creature_motor_profile_ship` and spine `locale_prior_*` / `weight_believed_goal_pull` — not dev profile.
