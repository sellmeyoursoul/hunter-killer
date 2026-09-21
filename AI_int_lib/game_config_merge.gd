## Static helpers to build a merged game config from defaults + [code]user://game_config.json[/code].
## Used by the **GameConfig** autoload and by [code]tests/run_all.gd[/code].
extends Object


## Default [code]logging_params[/code] when the file is missing or incomplete (matches OLog fallbacks).
static func default_logging_params() -> Dictionary:
  return {
    "LOG_LEVEL": "Error",
    "MAX_LINES_PER_PROCESS": 128,
    "MAX_QUEUE_ENTRIES": 1024,
  }


## Defaults for [code]perception[/code] (§4.2 snapshot stride vs inference period).
static func default_perception_params() -> Dictionary:
  return {
    "SNAPSHOT_PHYSICS_STRIDE": 1,
  }


## Defaults for [code]playfield_spawn[/code] (randomized interior boulder/food/duel-pair placement,
## [ENVIRONMENT_MODEL_PLAN.md §6.4](../Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)).
## [code]seed == 0[/code] draws a fresh OS-random seed each run. A non-empty [code]locked_layout_path[/code]
## bypasses randomization entirely and loads fractions verbatim from that JSON file — the "lock this
## layout until the bug is resolved" escape hatch.
## [code]creatures[/code] ([CM_V3_MULTI_MOBS.md](../Project_Docs/Draft_Features/CM_V3_MULTI_MOBS.md))
## is a flat list of [code]{archetype, count, player_controlled}[/code] entries — spawn is entirely
## species-agnostic (`main_3d.gd::_spawn_configured_creatures`); herbivore/carnivore is just each
## archetype's own [code]feeding_mode[/code] trait, never a spawn-time bucket. Default below
## reproduces the historical 1v1 rabbit-vs-fox duel; add more entries (any archetype, any count) for
## "2 foxes + 2 rabbits" or "a lion, a tiger, a bear" without touching spawn code.
static func default_playfield_spawn_params() -> Dictionary:
  return {
    "seed": 0,
    "locked_layout_path": "",
    "creatures": [
      {"archetype": "res://creature/species/rabbit_archetype.tres", "count": 1, "player_controlled": true},
      {"archetype": "res://creature/species/wolf_archetype.tres", "count": 1},
    ],
  }


const _PackRes := preload("res://pack_resource_resolver.gd")

## Species-agnostic motor spine ([CREATURE_MOVEMENT_V2.md §A.1](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
static func creature_motor_spine() -> Dictionary:
  return {
    "mode": "scripted",
    "lookahead_sec": 0.15,
    "weight_dist": 0.45,
    "weight_dist_sq": 55.0,
    "weight_closing": 1.05,
    "penalty_oob": 1e7,
    "distance_eps": 6.0,
    "creature_half_extent_x": 13.5,
    "creature_half_extent_y": 30.5,
    "scripted_intent_hold_physics_ticks": 8,
    "weight_interior": 0.65,
    "shuffle_tie_break": true,
    ## Uniform cost jitter per cardinal+idle in [member CardinalAvoidance.pick_best_move_intent]; pairs with instance-mixed tie shuffle seed.
    "motor_intent_cost_chaos": 3.05,
    "weight_edge": 0.48,
    "awareness_radius": 1500.0,
    "awareness_cone_extra": 3000.0,
    "awareness_cone_half_angle_deg": 45.0,
    "awareness_memory_ticks": 3,
    "awareness_memory_weight": 0.35,
    "awareness_memory_horizon_sec": 0.0,
    "weight_obstacle": 1.25,
    ## Off-path observed static AABB repulsion scale (full weight on step corridor / squeeze).
    "weight_obstacle_peripheral_mul": 0.2,
    ## Extra attenuation when obstacle is only in forward wedge beyond [code]awareness_radius[/code].
    "weight_obstacle_cone_edge_mul": 0.5,
    ## Prey ENGINE: strip merged shrub static AABBs this close to current [code]food_seek_targets[/code] so grazing can beat repulsion.
    "vegetation_blocking_forage_clearance": 92.0,
    ## Multiply base [code]weight_obstacle[/code] for carnivores (shrub footprints + pursuit balance).
    "weight_obstacle_predator_boost": 1.55,
    "interior_env_near_mob": 70.0,
    "weight_interior_env_solid": 8000.0,
    "weight_interior_env_slow": 4.0,
    "hunger_explore_interior_scale_min": 0.16,
    "hunger_explore_edge_scale_min": 0.16,
    "hunger_explore_hold_scale_min": 0.2,
    "hunger_explore_urgency_power": 1.25,
    ## Vitals / calories (CREATURE_MEMORY §3): baseline time drain matches [HUNGER_AND_EATING.md](../Project_Docs/Completed_Features/HUNGER_AND_EATING.md) §3; movement adds cost per world unit traveled this tick.
    "calorie_baseline_drain_per_sec": 1.0,
    "calorie_cost_per_unit_moved": 0.002,
    ## Predator meal gain on successful prey contact; clamped at [code]caloric_needs[/code] on the carnivore body.
    "predator_prey_meal_calories": 5,
    "weight_seek_ready_food": 16.0,
    ## Unified goal seek ([CREATURE_MOVEMENT_V2.md §A.2.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)); pack may override; falls back to [code]weight_seek_ready_food[/code] when absent.
    "weight_seek_goal": 16.0,
    "weight_seek_backtrack": 14.0,
    ## Remembered pinch approach: block 180° retry while other 8-way steps clear ([code]blocked_approach_memory.gd[/code]).
    "blocked_approach_memory_ticks": 45,
    "blocked_approach_backtrack_dot": 0.55,
    "weight_blocked_approach_backtrack": 48.0,
    "weight_blocked_approach_sector": 18.0,
    ## Forage pinch: physics ticks stalled (or zero-intent turn) before forced escape intent.
    "herbivore_pinch_escape_stuck_ticks": 1,
    "food_seek_imminent_mob_radius": 100.0,
    "jeopardy_forced_turn_ticks": 5,
    "weight_avoid_unready_food": 5.5,
    "food_avoid_unready_scale_when_ready_target": 0.35,
    "weight_explore_idle_penalty": 10.5,
    "weight_explore_turn_bias": 0.14,
    "explore_intent_hold_extra_ticks": 5,
    "explore_coverage_cell": 52.0,
    "explore_trail_max_cells": 96,
    "weight_explore_trail_repulsion": 2.35,
    ## Active seek + patrol stay-still: physics ticks per 8-way heading while sweeping awareness ([code]seek_stationary_look.gd[/code]).
    "seek_stationary_look_segment_physics_ticks": 9,
    ## Active seek heading change: physics ticks per intermediate heading on shortest arc turn ([code]seek_direction_turn.gd[/code]); [code]0[/code] reuses [code]seek_stationary_look_segment_physics_ticks[/code].
    "seek_direction_turn_segment_physics_ticks": 0,
    ## Active goal seek (food/prey): eight headings (N..NW) and wall-clock lock per pick ([code]seek_direction_commit.gd[/code]).
    "motor_seek_direction_lock_sec": 1.0,
    ## Carnivore pursuit: minimum seek weight toward visible prey ([code]food_seek_targets[/code]), independent of calorie ratio.
    "weight_seek_prey": 22.0,
    ## Consecutive physics ticks with nonzero intent but displacement below [code]motor_stuck_move_epsilon[/code] before escape shaping runs.
    "motor_stuck_escape_ticks": 8,
    "motor_stuck_move_epsilon": 1.25,
    ## Multiply [code]weight_seek_ready_food[/code] while stuck (breaks wall-slide deadlock toward prey).
    "motor_stuck_prey_pull_scale": 1.5,
    ## Boost expanding cardinal hint when stuck with no food/prey targets.
    "weight_stuck_escape_explore": 2.2,
    ## Softer expanding hint while prey is visible but movement has stalled ([code]motor_stuck_allow_expand_hint[/code]).
    "weight_stuck_escape_explore_when_chasing": 0.95,
    ## 3D terrain: uphill bonus when local depression exceeds [code]terrain_depression_threshold_m[/code].
    "terrain_elevation_motor_active": true,
    "weight_terrain_uphill": 4.0,
    "terrain_depression_threshold_m": 0.5,
    "terrain_stuck_min_uphill_m": 0.15,
    "terrain_drop_block_m": 0.35,
    "weight_terrain_drop": 40.0,
    "motor_stuck_turn_bias_scale": 0.25,
    "motor_stuck_idle_penalty_scale": 2.5,
    "motor_stuck_prey_expand_floor": 0.95,
    "motor_stuck_prey_idle_scale": 1.35,
    "motor_stuck_prey_turn_scale": 1.2,
    ## Unified ENGINE exploration: keep coverage terms while chasing ([code]exploration_blend_min_when_engaged[/code] at full pursuit urgency).
    "motor_exploration_always_enabled": true,
    "exploration_blend_min_when_engaged": 0.28,
    ## Inverse-distance pull toward prey samples ([code]pursuit_targets[/code]); complements [code]food_seek_targets[/code].
    "weight_pursuit_dist": 0.42,
    "weight_pursuit_closing": 0.95,
    "weight_pursuit_dist_sq": 38.0,
    ## Rival predator jeopardy ([code]mobs[/code] samples); scaled by [code]jeopardy_weight_rival_predator[/code].
    "jeopardy_forced_turn_ticks_predator": 5,
    "jeopardy_weight_rival_predator": 1.0,
    "intent_hold_ticks_predator": 6,
    ## Strategic solids: prey shields vs threat; predator pins prey toward nearby obstacle samples.
    "weight_obstacle_shield_prey": 28.0,
    "weight_obstacle_pin_predator": 22.0,
    ## Pinch detection / escape: full influence within this gate distance; linear falloff to zero at awareness max reach.
    "pinch_obstacle_full_weight_dist_m": 12.0,
    "pinch_obstacle_min_influence": 0.12,
    "predator_chase_edge_band": 110.0,
    "predator_chase_edge_weight_mul": 0.12,
    "predator_chase_pin_scale": 0.15,
    "predator_chase_closing_intent_dot": 0.35,
    "predator_obstructed_hunt_lock_ticks": 10,
    "predator_obstructed_max_toward_dot": 0.22,
    "predator_prey_visible_latch_ticks": 6,
    "predator_prey_engagement_latch_ticks": 36,
    "predator_engagement_latch_seek_scale": 0.72,
    "motor_seek_occlusion_penalty_weight": 12.0,
    "predator_edge_kill_close_mul": 1.35,
    "predator_edge_kill_close_pad": 12.0,
    "predator_stalemate_full_ticks": 6,
    "herbivore_flee_toward_threat_penalty": 8.0,
    "herbivore_flee_obstacle_shield_scale": 14.0,
    "herbivore_flee_shield_max_toward_dot": 0.15,
    "herbivore_flee_shield_min_away_dot": -0.05,
    "herbivore_flee_shield_require_chase_block": true,
    "herbivore_flee_corner_edge": 48.0,
    "herbivore_flee_corner_threat_move": 120.0,
    "motor_playfield_corner_band": 56.0,
    ## Preserve vs Find ([CREATURE_MOVEMENT_V2.md §A.3.1](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
    "preserve_bias_food_floor": 0.90,
    "seek_priority_food_ceiling": 0.80,
    "preserve_seek_blend_smoothness": 0.5,
    "starvation_override_food_ceiling": 0.10,
    ## Habitual locale / memory ([CREATURE_MEMORY.md §10](../Project_Docs/Draft_Features/CREATURE_MEMORY.md)) — wired in memory phase.
    "weight_believed_goal_pull": 6.4,
    "believed_goal_hotspot_near_radius": 250.0,
    "believed_goal_seek_escalate_radius": 1000.0,
    "believed_goal_escalate_seek_mul": 1.35,
    "believed_goal_escalate_preserve_blend": 0.55,
    "locale_prior_pull_w_norm": 3.0,
    "locale_prior_ewma_alpha": 0.15,
    "locale_prior_write_blend": 0.35,
    "locale_prior_max_buckets": 100,
    "locale_prior_idle_evict_base_sec": 10.0,
    "locale_prior_idle_evict_per_attempt_sec": 1.0,
    "salient_write_max_per_sec": 100.0,
    "escape_reversal_window_sec": 1.0,
    "tactic_squeeze_clearance": 28.0,
    "tactic_conspecific_aid_radius": 120.0,
    "replay_bell_k": 1.4,
    "replay_w_fit": 0.4,
    "replay_w_store": 0.6,
    "replay_n_sat": 10.0,
    "replay_n_min": 3.0,
    "urgency_boost_linear_slope": 25.0,
    "replay_urgency_slot_b_min": 90.0,
    "goal_memory_precise_radius": 1000.0,
    "goal_memory_moving_last_known_radius": 50.0,
    "goal_memory_mover_ttl_sec": 10.0,
    "goal_memory_ghost_horizon_sec": 0.4,
    "goal_memory_forget_radius": 2400.0,
    "goal_memory_ttl_sec": 45.0,
    "goal_memory_coarse_ttl_sec": 15.0,
    "goal_memory_max_entries": 25,
    "weight_seek_remembered_goal": 8.0,
    "weight_coarse_sector_goal_bias": 3.0,
  }


## Aberrant wiring-detector profile — extreme ends of knobs ([CREATURE_MOVEMENT_V2.md §A.1](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
static func creature_motor_profile_dev() -> Dictionary:
  return {
    "weight_seek_ready_food": 0.0,
    "weight_seek_prey": 0.0,
    "weight_explore_turn_bias": 2.5,
    "weight_explore_idle_penalty": 0.5,
    "weight_explore_trail_repulsion": 0.15,
    "motor_intent_cost_chaos": 8.0,
    "scripted_intent_hold_physics_ticks": 1,
    "explore_intent_hold_extra_ticks": 0,
  }


## Ship / release stub — finalize before export ([CREATURE_MOVEMENT_V2.md §A.1](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
static func creature_motor_profile_ship() -> Dictionary:
  return {
    ## Phase 3 retune — spine-like seek for playtest/ship ([PHASE1_MOTOR_BASELINE.md](../Project_Docs/AI_Notes/PHASE1_MOTOR_BASELINE.md)).
    "weight_seek_ready_food": 16.0,
    "weight_seek_prey": 22.0,
    "weight_seek_backtrack": 14.0,
    ## Remembered pinch approach: block 180° retry while other 8-way steps clear ([code]blocked_approach_memory.gd[/code]).
    "blocked_approach_memory_ticks": 45,
    "blocked_approach_backtrack_dot": 0.55,
    "weight_blocked_approach_backtrack": 48.0,
    "weight_blocked_approach_sector": 18.0,
    ## Forage pinch: physics ticks stalled (or zero-intent turn) before forced escape intent.
    "herbivore_pinch_escape_stuck_ticks": 1,
    "motor_intent_cost_chaos": 0.0,
    "weight_explore_turn_bias": 0.14,
    "weight_explore_idle_penalty": 10.5,
    "weight_explore_trail_repulsion": 2.35,
    "weight_believed_goal_pull": 5.2,
    "locale_prior_pull_w_norm": 3.0,
    "locale_prior_write_blend": 0.32,
    "believed_goal_escalate_seek_mul": 1.4,
  }


## True when ship motor profile should merge (export tag or editor QA setting).
static func use_ship_motor_profile() -> bool:
  if OS.has_feature(&"creature_motor_ship"):
    return true
  if OS.has_feature("editor"):
    return bool(ProjectSettings.get_setting("hunter_killer_debug/use_ship_motor_profile", false))
  return false


## Merges spine + selected build profile ([code]creature_motor_ship[/code] export feature when set).
static func default_creature_motor_params() -> Dictionary:
  var spine := creature_motor_spine()
  var profile := (
    creature_motor_profile_ship()
    if use_ship_motor_profile()
    else creature_motor_profile_dev()
  )
  return _merge_dict_shallow(spine, profile)


## Test / harness helper — apply ship profile overlay on [param base].
static func apply_creature_motor_profile_ship(base: Dictionary) -> Dictionary:
  return _merge_dict_shallow(base, creature_motor_profile_ship())


## Test / harness helper — apply dev profile overlay on [param base].
static func apply_creature_motor_profile_dev(base: Dictionary) -> Dictionary:
  return _merge_dict_shallow(base, creature_motor_profile_dev())


## Per-spawn pack overlay: [param motor_p] ∪ [code]pack_resources.json[/code] [code]creature_motor[/code] ([CREATURE_MOVEMENT_V2.md §A.1](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
static func merge_creature_motor_pack_overlay(motor_p: Dictionary, pack_root: String) -> Dictionary:
  var root := str(pack_root).strip_edges()
  if root.is_empty():
    return motor_p.duplicate(true)
  var over := _PackRes.load_creature_motor_overlay(root)
  if over.is_empty():
    return motor_p.duplicate(true)
  return _merge_dict_shallow(motor_p, over)


## §7.3.2 explore seek + §1 inventory ship defaults ([CREATURE_MOVEMENT_V3.md §7.3.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
static func default_creature_motor_v3_explore_inventory_params() -> Dictionary:
  return {
    "explore_bearing_count": 8,
    "explore_empty_map_unexplored_baseline": 0.5,
    ## Open space (explore_w_open) outweighs spawn-heading inertia by default — a genuinely clear
    ## bearing should win over "close to how I'm already facing" unless unexplored/forward factors
    ## tip the balance among comparably-open options (CLEANUP C8 rebalance, 2026-08-07).
    "explore_w_spawn": 0.20,
    "explore_w_open": 0.45,
    "explore_w_unexp": 0.25,
    "explore_w_forward": 0.10,
    "explore_w_live_near": 0.50,
    ## Live finding 2026-09-04: belief/live-near coverage alone can't tell "walked through here,
    ## confirmed empty" from "never been near" — both read as zero coverage, so a picked-clean
    ## direction kept re-winning explore_w_unexp's pull as if it were still unexplored (root cause
    ## of a fox bouncing east-west between two walls). `explore_w_visited_wedge` is the capped
    ## per-wedge contribution (via `maxf`, not summed) from `VisitedPathMemory`'s spatial
    ## visitation history once a wedge has been physically walked through recently — same
    ## magnitude class as a coarse belief (0.5) so it competes but doesn't drown out real food
    ## density elsewhere.
    "explore_w_visited_wedge": 0.6,
    "visited_path_memory_ttl_sec": 90.0,
    "visited_path_memory_max_entries": 64,
    "visited_path_memory_min_spacing": 40.0,
    ## Wedges within this many neighbors of a blocked bearing get a discounted open_term (fading
    ## linearly to no discount at the edge) instead of scoring identically to a fully-clear wedge
    ## on the far side of the ring — gives explore_w_open real graduation to act on.
    "explore_open_safety_margin_wedges": 3,
    "goal_inventory_min_find_food": 3,
    "goal_inventory_min_find_mate": 1,
    "goal_sated_patrol_urgency": 0.15,
    "goal_mapping_urgency": 0.35,
    "goal_consideration_chaos": 0.15,
    "goal_memory_mover_ttl_sec": 10.0,
    "predator_prey_engagement_latch_base_ticks": 40,
    "predator_prey_engagement_latch_scale_min": 0.5,
    "predator_prey_engagement_latch_scale_max": 1.5,
    "predator_prey_engagement_latch_ticks_min": 8,
    "predator_prey_engagement_latch_ticks_max": 120,
    "flee_waypoint_latch_ticks": 16,
    ## Multi-threat flee bearing blending ([CM_V3_MULTI_MOBS.md]
    ## (../Project_Docs/Draft_Features/CM_V3_MULTI_MOBS.md) step 4) — `_flee_objective` sums every
    ## in-awareness threat's away-unit-vector weighted by `1 / max(gate_dist, flee_threat_weight_min_dist)`
    ## rather than fleeing the nearest threat alone. With exactly one threat this reduces to the
    ## historical nearest-only bearing exactly (a single normalized vector's weight cancels out).
    ## Floor keeps a point-blank threat's weight finite instead of blowing up toward infinity.
    "flee_threat_weight_min_dist": 1.0,
    ## Lerp factor pulling each remint's raw blended bearing toward the previous remint's chosen
    ## bearing (`flee_blend_dir_prev`) — only applied when 2+ threats contributed (never with a
    ## single threat, so 1v1 flee stays bit-identical to pre-blending behavior). 0 = no smoothing
    ## (full oscillation risk restored); 1 = bearing never updates. Targets the C9-class resonance
    ## risk of two similar-weight threats on opposite/adjacent sides flipping the seed bearing
    ## between remints — tune against live multi-predator testing, not assumed correct at 0.35.
    "flee_bearing_smoothing": 0.35,
    "pursuit_detour_latch_ticks": 32,
    ## Two-boulder-pinch fix (2026-09-16, `motor_planner.gd::_derive_find_food_step_objective`):
    ## consecutive consideration ticks a live food target may sit outside the awareness/LOS cone
    ## before the pursuit gives up on it and falls back to generic explore. Bridges a momentary
    ## facing-cone dropout during a blocked approach without masking a real loss (eaten/despawned).
    "live_food_awareness_grace_ticks": 2,
    ## Max escalation tries (`LatchHold.escalate`, [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §4]
    ## (../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md)) before
    ## `_remint_alternate_pursuit_detour` gives up and clears the latch — the only safety valve
    ## against retrying forever on a visible-but-physically-unreachable live pursuit target.
    ## Promoted from a hardcoded `> 2` literal so a future consumer of the shared latch can pick
    ## its own cap without touching `motor_planner.gd`.
    "pursuit_detour_max_escalations": 2,
    ## CLEANUP C9 give-up escalation (2026-08-07): once even the best of `_mint_flee_waypoint`'s
    ## 6 geometry-scored candidate bearings reaches less than this fraction of the requested flee
    ## distance, the creature is treated as genuinely cornered (not just locally obstructed).
    "flee_give_up_reach_frac": 0.35,
    ## Full-circle candidate count used only once `flee_give_up_reach_frac` triggers — finer than
    ## the normal 6-bearing sweep, and (unlike that sweep) ignores recent-backtrack history
    ## entirely: a cornered animal takes whatever real opening exists, threat-bearing and prior
    ## missteps be damned.
    "flee_give_up_scan_directions": 16,
    ## Latch duration while give-up-escalated, vs. the normal `flee_waypoint_latch_ticks` — a
    ## cornered animal re-assesses far more often than one calmly fleeing, because the situation
    ## (and the predator's position) changes fast at this range.
    "flee_give_up_latch_ticks": 5,
    ## RANDOMTESTS RT4 Slice 2 (2026-08-26): fractional-reach bonus applied to a flee candidate
    ## bearing that points at a confirmed shelter belief, scaled down linearly to 0 as the shelter's
    ## distance approaches `goal_memory_forget_radius_shelter` — a shelter right next to the creature
    ## gets close to the full bonus, one near the forget-radius edge gets almost none. Lets "known
    ## safe and reachable" narrowly beat "merely open ground" without overriding the give-up
    ## escalation's own boxed-in handling.
    "flee_shelter_bias_bonus": 0.15,
    ## Flee-candidate scoring, decision 20 (FleeCandidateScoring): every candidate (open bearings and
    ## shelter/choke beliefs) gets `race_term = clamp(margin, +-cap) * gain` (fraction of flee distance;
    ## margin is the scale-free ratio (d_threat - d_self) / (d_threat + d_self), so cap 0.5 = threat 3x farther);
    ## a belief's own bonus (`flee_shelter_bias_bonus` / `flee_choke_bias_bonus`, x tier weight x
    ## proximity) is additionally gated 0..1 by the race. Beliefs within `flee_belief_radius_factor` x
    ## the flee distance enter the pool, nearest `flee_belief_max_candidates` only. Untuned.
    "flee_race_margin_cap": 0.5,
    "flee_race_margin_gain": 0.6,
    "flee_choke_bias_bonus": 0.15,
    "flee_belief_radius_factor": 1.0,
    "flee_belief_max_candidates": 4,
  }


## V3 motor defaults ([CREATURE_MOVEMENT_V3.md §7.5 / §12.2 6a](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
static func default_creature_motor_v3_params() -> Dictionary:
  var core := {
    ## Sign-pick probe angle only (2026-09-15) — `_pick_boundary_scan_sign`/`_pick_shorter_arc_turn_sign`
    ## simulate one small step each way to decide left-vs-right; decoupled from actual turn
    ## execution, which reads `move_turn_rate_deg_per_sec` instead. Not a per-tick applied step.
    "turn_increment_deg": 22.5,
    ## Explicit facing-alignment tolerance for path-clearance/LoS gating (2026-09-15) —
    ## `_is_facing_aligned_with_tolerance`/`_move_alignment_min_dot`. Previously derived from
    ## `turn_increment_deg`; split out because that key no longer represents an applied turn step.
    "move_alignment_tolerance_deg": 22.5,
    ## §1 R1 continuous controller (CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §1) — max angular rate for
    ## the executor's blended turn+move law. Since the 2026-09-15 dexterity turn-rate unification
    ## (§9), also the rate boundary-scan/EAT-orbit's pure-orientation turning uses (`_rotate_facing`)
    ## — one rate, one source, no more separate fixed per-tick step for those. This flat value is
    ## the pre-dexterity default / fallback for a body with no `CreatureDefinition`
    ## (`creature_motor_stack.gd::_refresh_move_turn_rate` leaves it untouched in that case) —
    ## creature bodies get a per-dexterity value instead, see the three pegs below. Default derived
    ## to match the old fixed-step's worst-case per-tick cap at 60Hz (22.5 / (1/60) = 1350), so the
    ## continuous law's max turn speed wasn't a step change from the pre-R1 default when it shipped.
    "move_turn_rate_deg_per_sec": 1350.0,
    ## Dexterity-pegged turn-rate curve (2026-09-15, CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9) —
    ## `StatMath.peg_curve(stat_dexterity, ...)` via `creature_motor_stack.gd::_refresh_move_turn_rate`.
    ## Stat 25 preserved at exactly the historical flat default above (already live-tested through
    ## every C9/C1-C5 acceptance leg) rather than pushed faster; 1 and 10 derived from `StatMath`'s
    ## own point-pool table ratios (`T[10]/T[1]`≈3.7645, `T[25]/T[10]`≈1.95198) so the shape matches
    ## every other stat curve in the project.
    "move_turn_rate_deg_per_sec_at_stat_1": 183.7,
    "move_turn_rate_deg_per_sec_at_stat_10": 691.6,
    "move_turn_rate_deg_per_sec_at_stat_25": 1350.0,
    "calorie_baseline_drain_per_sec": 1.0,
    "move_calorie_per_sec": 1.0,
    "rest_baseline_multiplier": 0.5,
    "preserve_bias_food_floor": 0.90,
    "seek_priority_food_ceiling": 0.80,
    "preserve_seek_blend_smoothness": 0.5,
    "starvation_override_food_ceiling": 0.10,
    "awareness_radius": 1500.0,
    "awareness_cone_extra": 400.0,
    "awareness_cone_half_angle_deg": 45.0,
    "awareness_requires_los": true,
    "los_blocked_occlusion_fraction": 0.80,
    ## Silhouette radius (world meters) used to fan shadow-test rays across a LoS target instead
    ## of just its center point — pack-overridable per species for better/worse peripheral vision.
    "los_target_radius": 0.5,
    ## Consecutive same-direction raw LoS verdicts required before `_run_path_clearance_los_nav`
    ## flips its latched clear/blocked state (thrash-guard for tight obstacle pockets).
    "los_hysteresis_ticks": 3,
    ## Consecutive same-direction raw awareness verdicts required before a scanned threat's
    ## in/out-of-awareness state flips (per-target latch in `AwarenessZone.latch_awareness_verdict`,
    ## CLEANUP C11 flip-flop fix — separate tunable from `los_hysteresis_ticks` since threat
    ## awareness and path-clearance LoS have no evidence they need the same debounce timing).
    "threat_awareness_hysteresis_ticks": 3,
    ## EAT contact range in world meters to ultimate (not nav [code]step_goal[/code]).
    "eat_action_max_distance": 5.0,
    ## Full front arc for EAT facing (half-angle = arc/2; default 90° → ±45°).
    "eat_facing_arc_deg": 90.0,
    ## Facing revolutions in eat range without EAT before one rearward break tick.
    "eat_orbit_break_revolutions": 3,
    "arrival_tolerance": 5.0,
    "blocked_approach_memory_ticks": 45,
    "blocked_approach_backtrack_dot": 0.55,
    "goal_replan_base_ticks": 8,
    "flight_acute_panic_radius": 220.0,
    "goal_base_find_food": 1.0,
    "goal_base_avoid_hostiles": 1.0,
    "goal_base_rest": 0.85,
    "goal_base_shelter": 0.5,
    "goal_base_find_mate": 0.0,
    "goal_feasibility_floor_find_food": 0.05,
    "goal_feasibility_floor_avoid_hostiles": 0.05,
    "goal_feasibility_floor_rest": 0.05,
    "goal_feasibility_floor_shelter": 0.05,
    "goal_feasibility_floor_find_mate": 0.05,
    "flight_urgency_far_floor": 0.5,
    "flight_urgency_dist_floor": 1.0,
    "goal_memory_ttl_sec": 45.0,
    "goal_memory_coarse_ttl_sec": 15.0,
    "goal_memory_precise_radius": 1000.0,
    "goal_memory_forget_radius": 2400.0,
    "goal_memory_max_entries": 25,
    ## GK_SHELTER candidate detection (CREATURE_MOVEMENT_V3.md §6.4) — ring-probe nomination +
    ## STAY-evaluate confirm, plus shelter-specific belief-memory retention (confirmed shelters
    ## must outlive food's short TTL/precise-radius since Flight needs them around later).
    "shelter_probe_lookahead_dist": 3.0,
    "shelter_enclosure_probe_radius": 2.5,
    ## PHYSICS_SQUEEZE.md §3 decision 29 (2026-09-20): was 8 (`plant_mob_block`'s old real physics
    ## layer) — stale since decision 25 migrated `open_shrub_3d`'s `MobBlocker` onto the
    ## movement-inert ghost/query-only layer (`GhostObstacleQuery.GHOST_LAYER_MASK`). Nothing in the
    ## project has been on layer 8 since; a shrub-only shelter candidate silently read as 0%
    ## enclosed regardless of how many shrubs actually surrounded it.
    "shelter_enclosure_blocker_mask": 16,
    "shelter_enclosure_detect_threshold": 0.5,
    "shelter_enclosure_confirm_threshold": 0.65,
    "shelter_eval_confirm_cycles": 5,
    "shelter_eval_max_cycles": 15,
    "shelter_probe_retry_cooldown_cycles": 2,
    ## Graded shelter-belief confidence (2026-09-11 design review) — GoalBeliefMemory.shelter_tier_weight.
    ## observed: a passive/opportunistic glance cleared the enclosure threshold, no confirm cycle.
    ## confirmed: the deliberate multi-cycle STAY-evaluate passed. battle_tested: the creature was
    ## actually at/near this confirmed shelter when a real threat's danger window cleared — known
    ## safety, not just a good guess. Feeds `consult_shelter_beliefs`' preference among confirmed
    ## shelters, the weighted `shelter_map_confidence` sum, and (via that sum) how far below
    ## `seek_priority_food_ceiling` a creature can still get pulled into a GOAL_SHELTER STAY-evaluate.
    "shelter_confidence_observed": 0.3,
    "shelter_confidence_confirmed": 0.6,
    "shelter_confidence_battle_tested": 1.0,
    ## Concealment-rest (2026-09-12 design review; curve migrated 2026-09-15) — `Action.WAIT`
    ## while occupying a shelter spot. `StatMath.peg_curve(stat_composure, ...)` pegged at stat
    ## 1/10/25 gives the full-pool multiplier directly; `curr_point_comp/max_point_comp` lerps from
    ## `_at_stat_1` (no discount, like STAY, pool fully spent) toward that pegged value as the pool
    ## refills — see `creature_motor_stack.gd::_refresh_wait_calorie_multiplier`. Stat-1/10/25
    ## values preserve what the retired single-anchor `saturating` curve produced at those same
    ## three stats, so this migration is not a live-behavior change, only a shape/mechanism one.
    "wait_calorie_multiplier_at_stat_1": 0.9353,
    "wait_calorie_multiplier_at_stat_10": 0.625,
    "wait_calorie_multiplier_at_stat_25": 0.5156,
    ## Prey-race giveaway (2026-09-12; curve migrated 2026-09-15) — a predator chasing a
    ## live-visible, non-closing moving prey (open terrain, no blocking obstacle to trip the
    ## existing §9 passibility-fail giveup) gives up after `prey_race_giveup_ticks`, itself scaled
    ## by observation the same way WAIT's calorie discount is scaled by composure via
    ## `StatMath.peg_curve` — low observation (stat 1, slow to realize) down to high observation
    ## (stat 25, realizes fast). Give-up reuses the existing passibility-fail exclusion machinery
    ## rather than a new one — see `motor_planner.gd::_arm_prey_engagement_from_live_food`.
    "prey_race_giveup_ticks_at_stat_1": 80.94,
    "prey_race_giveup_ticks_at_stat_10": 37.5,
    "prey_race_giveup_ticks_at_stat_25": 22.19,
    "prey_race_not_closing_epsilon": 0.05,
    "prey_race_exclusion_cooldown_ticks": 60,
    ## Ticks a live food that lost the live-vs-locale calorie handoff stays excluded from every food
    ## consult (see `motor_planner.gd::_hold_live_food_lost_to_locale`) — long enough to walk to the
    ## locale target instead of turning back to the remembered copy of the food it just rejected.
    "live_locale_handoff_exclusion_ticks": 240,
    ## Hub incumbent hysteresis — the incumbent goal's weight is scaled by (1 + this) at each
    ## consideration (`MotorGoalHub.apply_incumbent_bonus`), so a challenger must clearly beat it.
    ## 0.4 keeps a sated find_food from being pulled off by a far, non-closing threat's low avoid
    ## weight, while a genuinely nearer threat (higher urgency) still takes over. Untuned.
    "goal_incumbent_switch_margin": 0.4,
    "goal_inventory_min_shelter": 1.0,
    "goal_shelter_explore_floor": 0.25,
    "goal_memory_ttl_sec_shelter": 300.0,
    "goal_memory_precise_radius_shelter": 2400.0,
    "goal_memory_forget_radius_shelter": 2400.0,
    ## GK_CHOKE_POINT belief (PHYSICS_SQUEEZE.md decision 19/§9 slice 8). Tier weights mirror the
    ## shelter_confidence_* trio but only two tiers exist (a gap's width is a physical fact, so
    ## there's no battle-tested). The `_choke_point` decay overrides apply to *confirmed* rows only
    ## (a measured width is durable); `observed` rows use the generic goal_memory_* decay.
    "choke_confidence_observed": 0.3,
    "choke_confidence_confirmed": 0.7,
    ## Choke-point *producer* (ChokePointProbe/ChokePointTracker, wired in CreatureMotorStack): a gap
    ## is "bounded on both sides within `choke_detect_width_factor` x the creature's own diameter".
    ## Sampled every `choke_probe_interval_ticks`; a stretch ends after `choke_exit_samples` clear
    ## samples and counts as passed if the exit is >= `choke_pass_min_travel_factor` x diameter from
    ## the entry. Remote `observed` looks are `choke_observe_lookahead_factor` x radius ahead, noised
    ## by observation stat. Rows within `choke_merge_radius_factor` x diameter merge; at most
    ## `choke_max_rows` rows so sightings can't crowd out food memory. All untuned.
    "choke_detect_width_factor": 4.0,
    "choke_probe_interval_ticks": 3,
    "choke_exit_samples": 3,
    "choke_pass_min_travel_factor": 1.0,
    "choke_observe_lookahead_factor": 6.0,
    "choke_merge_radius_factor": 1.0,
    "choke_merge_radius": 3.0,
    "choke_max_rows": 8,
    "choke_observe_noise_frac_v1": 0.4,
    "choke_observe_noise_frac_v10": 0.15,
    "choke_observe_noise_frac_v25": 0.03,
    "goal_memory_ttl_sec_choke_point": 300.0,
    "goal_memory_precise_radius_choke_point": 2400.0,
    "goal_memory_forget_radius_choke_point": 2400.0,
    "dead_end_memory_ttl_sec": 15.0,
    "dead_end_memory_max_entries": 12,
    "dead_end_match_radius": 52.0,
    "dead_end_heading_dot": 0.55,
    "dead_end_record_min_blocked_ticks": 3,
    ## Ticks a locale food anchor stays skipped after an empty arrival (no consumable found) before
    ## it can be re-picked — prevents immediately re-targeting a point the creature is already
    ## standing on, which produces degenerate bearing math and an in-place turn-storm
    ## (CLEANUP C2 duel-manual finding, 2026-07-17). Bumped 90 -> 300 (CLEANUP C15, 2026-08-11):
    ## 90 ticks (1.5s) was far shorter than the ~500-700 tick eat/wander/return cycle observed
    ## live, so the same empty anchor was always off cooldown again well before the creature came
    ## back around to reconsult locale memory — see `notify_locale_food_arrival_empty` in
    ## memory_adapter.gd for the companion fix (repeated empty arrivals now also erode that cell's
    ## stored_strength, so it loses out over time even once back off cooldown).
    "locale_revisit_cooldown_ticks": 300,
    ## Bounded nearby-search after an empty locale arrival (2026-09-13 stuck-rabbit fix): duration
    ## (physics ticks) and radius (world meters) of the look-around before the anchor's locale
    ## belief is hard-invalidated (`GoalSourceMemoryStore.invalidate_locale_belief_near`) and the
    ## creature falls back to ordinary `explore`. See `_maybe_search_arrival_remint` /
    ## `_mint_locale_search_waypoint` in motor_planner.gd.
    "locale_search_ticks": 240,
    "locale_search_radius": 12.0,
    "approach_overshoot_guard_move_steps": 2,
    ## Arrival damping radius (world meters) — MOVE_FORWARD speed tapers from full to
    ## _ARRIVAL_DAMPING_MIN_SPEED_FRAC as `dist_to_goal` closes inside this band. Independent of
    ## `eat_action_max_distance` / `arrival_tolerance` (goal-agnostic, not EAT-specific; CLEANUP R1).
    "approach_arrival_damping_radius": 2.5,
    ## Widened MOVE_FORWARD heading gate (CLEANUP R1 mitigation #2 — blend turn+move in one tick).
    ## MOVE_FORWARD is legal whenever heading error is within this arc (vs. the tight
    ## `turn_increment_deg` cone); the executor blends a bounded turn toward `step_goal` into the
    ## same tick's move instead of requiring full alignment first. 60° keeps guaranteed forward
    ## progress at the edge (cos 60° = 0.5) and stays clear of `eat_facing_arc_deg`'s 90°-off
    ## `_test_motor_align_cone_contract` fixture. Not derived from duel evidence — a starting point.
    "move_blend_max_error_deg": 60.0,
    ## Legacy ratio vs V2 ~400 u/s @ 60 Hz; planner scales per tick as [code]max_speed × delta × (epsilon / 6.67)[/code].
    "motor_stuck_move_epsilon": 1.25,
    ## PHYSICS_SQUEEZE.md §3 decision 30 (2026-09-21): C10 airborne-invariant threshold
    ## (`creature_motor_stack.gd`'s `_trip_invariant` "stuck-under-geometry" check). This flat
    ## default is what a fixture/test with no real baked playfield keeps — `MotorPlane.
    ## scale_creature_motor_v3_for_playfield` overwrites it per-creature at spawn with
    ## `ticks_to_fall(playfield's real worst-case elevation drop) + motor_invariant_airborne_buffer_ticks`
    ## whenever a real `PlayfieldGroundSampler` is available, so a genuine multi-meter terrain fall
    ## isn't misread as a stuck-under-geometry bug on a tall playfield, while a flat/small one keeps
    ## this tight default.
    "motor_invariant_max_airborne_ticks": 45,
    ## Buffer added on top of the computed worst-case fall duration above — deliberately reusing the
    ## *original* flat threshold's value as "how much slower than the theoretical minimum a real,
    ## non-bugged fall is allowed to be" rather than inventing a new number.
    "motor_invariant_airborne_buffer_ticks": 45,
    ## Playfield edge hug band for explore boundary scan ([code]PlayfieldClamp[/code] margins).
    "playfield_hug_band": 14.0,
    ## Unscaled world margin for rim detection when scaled [code]playfield_hug_band[/code] is too tight.
    "playfield_rim_margin": 2.0,
    "passibility_fail_switch_threshold": 2,
    "safety_time": 5,
    "goal_memory_ghost_horizon_sec": 0.4,
    "flight_disposition_mod_min": 0.4,
    "flight_disposition_mod_max": 1.2,
    "flight_disposition_benign_delta": -0.05,
    "flight_disposition_evade_delta": 0.08,
    "kind_profile_neutral_prior": 0.5,
    "kind_profile_ewma_alpha": 0.15,
    "kind_nutrition_yield_reference_calories": 5.0,
    ## Live-vs-locale food handoff starvation safety margin ([CM stuck-rabbit fix, 2026-09-16] —
    ## `motor_planner.gd::_live_vs_locale_handoff_prefers_live`), as a fraction of `caloric_needs`.
    ## A live target whose round trip (there, eat, back) would leave projected calories at or below
    ## this buffer — while the locale alternative's one-way trip would not — loses to locale, even
    ## though the live target isn't an outright net loss on its own. Not exactly 0: travel cost here
    ## is a straight-line/constant-speed estimate (no turning overhead), so a thin margin protects
    ## against that estimation error actually starving the creature.
    "food_handoff_starvation_margin_frac": 0.125,
    "food_handoff_starvation_margin_scale_min": 0.5,
    "food_handoff_starvation_margin_scale_max": 1.5,
    "food_yield_estimate_noise_frac_v1": 0.4,
    "food_yield_estimate_noise_frac_v10": 0.15,
    "food_yield_estimate_noise_frac_v25": 0.03,
    "locale_prior_ewma_alpha": 0.15,
    "unknown_kind_multiplier": 1.0,
    "believed_goal_hotspot_near_radius": 250.0,
    "believed_goal_seek_escalate_radius": 1000.0,
  }
  return _merge_dict_shallow(core, default_creature_motor_v3_explore_inventory_params())


## Per-spawn pack overlay: [param motor_v3] ∪ [code]pack_resources.json[/code] [code]creature_motor_v3[/code] (one-shot legacy copy when absent).
static func merge_creature_motor_v3_pack_overlay(motor_v3: Dictionary, pack_root: String) -> Dictionary:
  var root := str(pack_root).strip_edges()
  if root.is_empty():
    return motor_v3.duplicate(true)
  var over := _PackRes.merge_creature_motor_v3_pack_overlay(root)
  if over.is_empty():
    return motor_v3.duplicate(true)
  return _merge_dict_shallow(motor_v3, over)


## Defaults for [code]inference_client[/code]; empty [code]INFERENCE_BASE_URL[/code] means AI cannot arm until set.
static func default_inference_client() -> Dictionary:
  return {
    "INFERENCE_BASE_URL": "",
    "COMPLETIONS_PATH": "/v1/completions",
    "CHAT_COMPLETIONS_PATH": "/v1/chat/completions",
    "MODEL_ID": "",
    "API_KEY": "",
    "HTTP_TIMEOUT_MS": 8000,
    "INFERENCE_PERIOD_MS": 250,
    "MAX_OUTPUT_TOKENS": 48,
    "LLAMA_COMPLETION_GRAMMAR_ENABLED": true,
    "TEMPERATURE": 0.0,
    "INFERENCE_AUTO_START_ENABLED": false,
    "BUNDLE_ROOT_OVERRIDE": "",
    "BUNDLED_SERVER_EXE": "",
    "BUNDLED_MODEL_GGUF": "",
    "BUNDLED_SERVER_ARGS": ["--no-mmap", "-ngl", "0"],
    "INFERENCE_PROBE_PATH": "/health",
    "INFERENCE_START_TIMEOUT_MS": 300000,
    "BUNDLED_SERVER_ATTACH_CONSOLE": true,
  }


## Full default root object (before reading the file).
static func default_root() -> Dictionary:
  return {
    "logging_params": default_logging_params(),
    "inference_client": default_inference_client(),
    "perception": default_perception_params(),
    "creature_motor": default_creature_motor_params(),
    "creature_motor_v3": default_creature_motor_v3_params(),
    "playfield_spawn": default_playfield_spawn_params(),
  }


## Shallow-merges [param over] into a duplicate of [param base] (both dictionary-valued sections).
static func _merge_dict_shallow(base: Dictionary, over: Variant) -> Dictionary:
  var out := base.duplicate(true)
  if typeof(over) != TYPE_DICTIONARY:
    return out
  var d: Dictionary = over
  for k in d:
    out[k] = d[k]
  return out


## Merges a parsed file root [param file_root] over [param defaults_root] for known top-level keys.
static func merge_root(defaults_root: Dictionary, file_root: Dictionary) -> Dictionary:
  var r := defaults_root.duplicate(true)
  if file_root.has("logging_params"):
    r["logging_params"] = _merge_dict_shallow(r["logging_params"], file_root["logging_params"])
  if file_root.has("inference_client"):
    r["inference_client"] = _merge_dict_shallow(r["inference_client"], file_root["inference_client"])
  if file_root.has("perception"):
    r["perception"] = _merge_dict_shallow(r["perception"], file_root["perception"])
  if file_root.has("creature_motor"):
    r["creature_motor"] = _merge_dict_shallow(r["creature_motor"], file_root["creature_motor"])
  if file_root.has("creature_motor_v3"):
    r["creature_motor_v3"] = _merge_dict_shallow(r["creature_motor_v3"], file_root["creature_motor_v3"])
  if file_root.has("playfield_spawn"):
    r["playfield_spawn"] = _merge_dict_shallow(r["playfield_spawn"], file_root["playfield_spawn"])
  return r


## Loads [code]user://game_config.json[/code] merged over [code]res://game_config.json[/code] (repo template) over hardcoded defaults.
## Use this for runtime so a missing user file still picks up dev inference defaults from the repo template.
## Params:
## - user_path: Optional override (mainly for tests).
## Returns:
## - [code]{ "merged": Dictionary, "diagnostic": String }[/code]; [param diagnostic] empty when user file loaded OK.
static func load_merged_config(user_path: String = "user://game_config.json") -> Dictionary:
  const repo_template := "res://game_config.json"
  var merged: Dictionary = default_root()
  if FileAccess.file_exists(repo_template):
    var rtxt := FileAccess.get_file_as_string(repo_template)
    var rjson := JSON.new()
    if rjson.parse(rtxt) == OK and typeof(rjson.data) == TYPE_DICTIONARY:
      merged = merge_root(merged, rjson.data)
  if not FileAccess.file_exists(user_path):
    ## First run (or user data cleared): repo template + defaults are still valid; do not surface as OLog error.
    return {
      "merged": merged,
      "diagnostic": "",
    }
  var utxt := FileAccess.get_file_as_string(user_path)
  var ujson := JSON.new()
  var err := ujson.parse(utxt)
  if err != OK:
    return {
      "merged": merged,
      "diagnostic": "%s JSON parse error (code %s) — kept merged defaults + repo template." % [user_path, err],
    }
  if typeof(ujson.data) != TYPE_DICTIONARY:
    return {
      "merged": merged,
      "diagnostic": "%s root must be a JSON object — kept merged defaults + repo template." % user_path,
    }
  merged = merge_root(merged, ujson.data)
  return {"merged": merged, "diagnostic": ""}


## Loads JSON from [param path], merges into defaults, returns [code]{ "merged": Dictionary, "diagnostic": String }[/code].
## [param diagnostic] is empty on full success; otherwise a single human-readable reason (file missing, parse error, wrong root type).
static func load_merge_from_path(path: String) -> Dictionary:
  var base := default_root()
  if not FileAccess.file_exists(path):
    return {
      "merged": base,
      "diagnostic": "%s is missing — using defaults." % path,
    }
  var txt := FileAccess.get_file_as_string(path)
  var json := JSON.new()
  var err := json.parse(txt)
  if err != OK:
    return {
      "merged": base,
      "diagnostic": "%s JSON parse error (code %s) — using defaults." % [path, err],
    }
  var root = json.data
  if typeof(root) != TYPE_DICTIONARY:
    return {
      "merged": base,
      "diagnostic": "%s root must be a JSON object — using defaults." % path,
    }
  var merged: Dictionary = merge_root(base, root)
  return {
    "merged": merged,
    "diagnostic": "",
  }
