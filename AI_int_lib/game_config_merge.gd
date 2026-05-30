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
    ## Prey ENGINE: strip merged shrub static AABBs this close to current [code]food_seek_targets[/code] so grazing can beat repulsion.
    "vegetation_blocking_forage_clearance_px": 92.0,
    ## Multiply base [code]weight_obstacle[/code] for carnivores (shrub footprints + pursuit balance).
    "weight_obstacle_predator_boost": 1.55,
    "interior_env_near_mob_px": 70.0,
    "weight_interior_env_solid": 8000.0,
    "weight_interior_env_slow": 4.0,
    "hunger_explore_interior_scale_min": 0.16,
    "hunger_explore_edge_scale_min": 0.16,
    "hunger_explore_hold_scale_min": 0.2,
    "hunger_explore_urgency_power": 1.25,
    ## Vitals / calories (CREATURE_MEMORY §3): baseline time drain matches [HUNGER_AND_EATING.md](../Project_Docs/Completed_Features/HUNGER_AND_EATING.md) §3; movement adds cost per pixel traveled this tick.
    "calorie_baseline_drain_per_sec": 1.0,
    "calorie_cost_per_px_moved": 0.002,
    ## Predator (mob) gain on successful prey contact; clamped at that mob's [code]caloric_needs[/code] in [code]mob.gd[/code].
    "predator_prey_meal_calories": 5,
    "weight_seek_ready_food": 16.0,
    "weight_seek_backtrack": 14.0,
    "food_seek_imminent_mob_radius_px": 100.0,
    "jeopardy_forced_turn_ticks": 5,
    "weight_avoid_unready_food": 5.5,
    "food_avoid_unready_scale_when_ready_target": 0.35,
    "weight_explore_idle_penalty": 10.5,
    "weight_explore_turn_bias": 0.14,
    "explore_intent_hold_extra_ticks": 5,
    "explore_coverage_cell_px": 52.0,
    "explore_trail_max_cells": 96,
    "weight_explore_trail_repulsion": 2.35,
    ## Expanding 8-way explore ([code]expanding_cardinal_explore.gd[/code] → [code]Explore[/code]): initial dwell **n** per heading; doubles each full 8-leg cycle.
    "expanding_explore_base_physics_ticks": 36,
    ## Active seek + patrol stay-still: physics ticks per 8-way heading while sweeping awareness ([code]seek_stationary_look.gd[/code]).
    "seek_stationary_look_segment_physics_ticks": 9,
    ## Herbivore ENGINE: cost bias toward expanding sweep when no ready-food in motor context ([code]CardinalAvoidance[/code]).
    "weight_expanding_explore_hint": 0.12,
    ## Active food/prey seek: eight headings (N..NW) and wall-clock lock per pick ([code]seek_direction_commit.gd[/code]).
    "motor_seek_direction_lock_sec": 1.0,
    ## Carnivore pursuit: minimum seek weight toward visible prey ([code]food_seek_targets[/code]), independent of calorie ratio.
    "weight_seek_prey": 22.0,
    ## Consecutive physics ticks with nonzero intent but displacement below [code]motor_stuck_move_epsilon_px[/code] before escape shaping runs.
    "motor_stuck_escape_ticks": 8,
    "motor_stuck_move_epsilon_px": 1.25,
    ## Multiply [code]weight_seek_ready_food[/code] while stuck (breaks wall-slide deadlock toward prey).
    "motor_stuck_prey_pull_scale": 1.5,
    ## Boost expanding cardinal hint when stuck with no food/prey targets.
    "weight_stuck_escape_explore": 2.2,
    ## Softer expanding hint while prey is visible but movement has stalled ([code]motor_stuck_allow_expand_hint[/code]).
    "weight_stuck_escape_explore_when_chasing": 0.95,
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
    "predator_chase_edge_band_px": 110.0,
    "predator_chase_edge_weight_mul": 0.12,
    "predator_chase_pin_scale": 0.15,
    "predator_chase_closing_intent_dot": 0.35,
    "predator_obstructed_hunt_lock_ticks": 10,
    "predator_obstructed_max_toward_dot": 0.22,
    "predator_edge_kill_close_mul": 1.35,
    "predator_edge_kill_close_pad_px": 12.0,
    "predator_stalemate_full_ticks": 6,
    "herbivore_flee_toward_threat_penalty": 8.0,
    "herbivore_flee_obstacle_shield_scale": 14.0,
    "herbivore_flee_shield_max_toward_dot": 0.15,
    "herbivore_flee_shield_min_away_dot": -0.05,
    "herbivore_flee_shield_require_chase_block": true,
    "herbivore_flee_corner_edge_px": 48.0,
    "herbivore_flee_corner_threat_move_px": 120.0,
    "motor_playfield_corner_band_px": 56.0,
    ## Legacy alias — prefer [code]expanding_explore_base_physics_ticks[/code].
    "carnivore_explore_rotate_physics_ticks": 36,
    ## Preserve vs Find ([CREATURE_MOVEMENT_V2.md §A.3.1](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
    "preserve_bias_food_floor": 0.90,
    "seek_priority_food_ceiling": 0.80,
    "preserve_seek_blend_smoothness": 0.5,
    "starvation_override_food_ceiling": 0.10,
    ## Habitual locale / memory ([CREATURE_MEMORY.md §10](../Project_Docs/Draft_Features/CREATURE_MEMORY.md)) — wired in memory phase.
    "weight_believed_goal_pull": 6.4,
    "believed_goal_hotspot_near_radius_px": 250.0,
    "believed_goal_seek_escalate_radius_px": 1000.0,
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
    "tactic_squeeze_clearance_px": 28.0,
    "tactic_conspecific_aid_radius_px": 120.0,
    "replay_bell_k": 1.4,
    "replay_w_fit": 0.4,
    "replay_w_store": 0.6,
    "replay_n_sat": 10.0,
    "replay_n_min": 3.0,
    "goal_memory_precise_radius_px": 1000.0,
    "goal_memory_moving_last_known_radius_px": 50.0,
    "goal_memory_forget_radius_px": 2400.0,
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
    "weight_expanding_explore_hint": 3.0,
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
