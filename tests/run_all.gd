## Headless test entry: [code]godot --path . --headless -s res://tests/run_all.gd[/code]
extends SceneTree

const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _Tokens := preload("res://AI_int_lib/ai_action_tokens.gd")
const _Wire := preload("res://AI_int_lib/perception_wire.gd")
const _Sampling := preload("res://AI_int_lib/perception_sampling.gd")
const _Risk := preload("res://AI_int_lib/perception_risk_hints.gd")
const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")
const IntentHoldScr := preload("res://creature/motor/scripted_intent_hold.gd")
const _Driver := preload("res://AI_int_lib/ai_driver.gd")
const _PlayerScr := preload("res://player.gd")
const _Bundle := preload("res://AI_int_lib/bundled_inference_launcher.gd")
const _EnvCell := preload("res://environment/environment_cell_data.gd")
const _EnvGrid := preload("res://environment/environment_grid_baked.gd")
const _EnvBake := preload("res://environment/environment_grid_bake.gd")

var _failures: int = 0


func _init() -> void:
  _run_all()
  quit(0 if _failures == 0 else 1)


func _run_all() -> void:
  _test_merge_defaults_and_override()
  _test_load_merged_config_repo_fallback()
  _test_hunter_killer_debug_project_settings()
  _test_tokens()
  _test_perception_snippet()
  _test_perception_sampling()
  _test_perception_risk_hints()
  _test_cardinal_avoidance()
  _test_scripted_intent_hold()
  _test_mob_avoidance_acceptance()
  _test_ai_driver_helpers()
  _test_bundled_inference_helpers()
  _test_environment_baked_grid()
  if _failures > 0:
    push_error("tests/run_all.gd: %d assertion(s) failed." % _failures)


func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)


func _test_merge_defaults_and_override() -> void:
  var base := _Merge.default_root()
  var file_root := {
    "logging_params": {"LOG_LEVEL": "Debug"},
    "inference_client": {"INFERENCE_BASE_URL": "http://x"},
    "perception": {"SNAPSHOT_PHYSICS_STRIDE": 3},
    "creature_motor": {"mode": "llm"},
  }
  var merged: Dictionary = _Merge.merge_root(base, file_root)
  _assert(merged["logging_params"]["LOG_LEVEL"] == "Debug", "merge logging_params.LOG_LEVEL")
  _assert(merged["logging_params"]["MAX_LINES_PER_PROCESS"] == 128, "merge logging_params keeps default key")
  _assert(merged["inference_client"]["INFERENCE_BASE_URL"] == "http://x", "merge inference_client url")
  _assert(merged["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 3, "merge perception stride")
  _assert(str(merged["creature_motor"].get("mode", "")) == "llm", "merge creature_motor.mode override")
  _assert(
    is_equal_approx(float(merged["creature_motor"].get("weight_interior", 0.0)), 0.65),
    "merge creature_motor keeps default weight_interior when not overridden",
  )
  _assert(
    is_equal_approx(float(merged["creature_motor"].get("weight_dist_sq", 0.0)), 55.0),
    "merge creature_motor keeps default weight_dist_sq when not overridden",
  )
  _assert(
    is_equal_approx(float(merged["creature_motor"].get("weight_edge", 0.0)), 0.48),
    "merge creature_motor keeps default weight_edge when not overridden",
  )
  _assert(
    float(merged["creature_motor"].get("lookahead_sec", 0.0)) > 0.0,
    "merge creature_motor keeps default lookahead when not overridden"
  )
  var res: Dictionary = _Merge.load_merge_from_path("user://__does_not_exist_for_test__.json")
  _assert(str(res.get("diagnostic", "")) != "", "missing file should set diagnostic")
  var m2: Dictionary = res["merged"]
  _assert(m2["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 1, "missing file perception default")
  _assert(str(base["creature_motor"].get("mode", "")) == "scripted", "default creature_motor.mode scripted")
  _assert(int(base["creature_motor"].get("scripted_intent_hold_physics_ticks", -1)) == 5, "default scripted intent hold")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_interior", 0.0)), 0.65), "default weight_interior")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_dist", 0.0)), 0.45), "default weight_dist")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_closing", 0.0)), 1.05), "default weight_closing")
  _assert(is_equal_approx(float(base["creature_motor"].get("distance_eps", 0.0)), 12.0), "default distance_eps")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_dist_sq", 0.0)), 55.0), "default weight_dist_sq")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_edge", 0.0)), 0.48), "default weight_edge")
  _assert(bool(base["creature_motor"].get("shuffle_tie_break", false)), "default shuffle_tie_break")
  _assert(is_equal_approx(float(base["creature_motor"].get("awareness_radius", 0.0)), 1500.0), "default awareness_radius")
  _assert(is_equal_approx(float(base["creature_motor"].get("awareness_cone_extra", 0.0)), 3000.0), "default awareness_cone_extra")
  _assert(int(base["creature_motor"].get("awareness_memory_ticks", -1)) == 3, "default awareness_memory_ticks")
  _assert(is_equal_approx(float(base["creature_motor"].get("awareness_memory_weight", 0.0)), 0.35), "default awareness_memory_weight")


func _test_load_merged_config_repo_fallback() -> void:
  var res: Dictionary = _Merge.load_merged_config("user://__does_not_exist_merged_test__.json")
  var merged: Dictionary = res["merged"]
  var ic: Dictionary = merged["inference_client"]
  _assert(str(ic.get("INFERENCE_BASE_URL", "")).begins_with("http"), "merged config pulls inference URL from repo template")


func _test_hunter_killer_debug_project_settings() -> void:
  _assert(
    ProjectSettings.has_setting("hunter_killer_debug/draw_awareness"),
    "project defines hunter_killer_debug/draw_awareness",
  )
  _assert(
    ProjectSettings.get_setting("hunter_killer_debug/draw_awareness") == false,
    "draw_awareness defaults to off",
  )


func _test_tokens() -> void:
  _assert(_Tokens.normalize_completion_token("  left\nnoise") == "LEFT", "token first line")
  _assert(_Tokens.normalize_completion_token("START") == "START", "START")
  _assert(_Tokens.normalize_completion_token("I'll go UP now") == "UP", "prose contains UP word")
  _assert(_Tokens.normalize_completion_token("<|im_end|> LEFT") == "LEFT", "strip span then direction")
  _assert(_Tokens.normalize_completion_token("xyzzy") == "noop", "unknown → noop")
  _assert(_Tokens.normalize_completion_token("") == "noop", "empty → noop")
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("Okay.\nSTART") == "START",
    "handshake finds START on a later line"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("Sure, START") == "START",
    "handshake word START in prose"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("RESTART") == "noop",
    "RESTART does not match START word"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("START <|im_end|>") == "START",
    "strip trailing chat marker after START"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("<|im_end|>") == "noop",
    "chat markers alone → noop"
  )


func _test_perception_snippet() -> void:
  var h := _Wire.format_header_line(1000, 3, 10, 8, 24)
  _assert(h == "1000 3 10 8 24", "header line")
  var v := _Wire.format_entity_velocity_line("PLAYER", 2, 4, Vector3(10, -20, 0))
  _assert(v.begins_with("PLAYER 2 4 "), "player vel line prefix")
  var e := _Wire.format_entity_extents_line("PLAYER_EXT", Vector3(12, 8, 0))
  _assert(e.begins_with("PLAYER_EXT "), "extents line")
  # Callable: static method exists on script; analyzer sometimes misses it on preload() type (see ai_driver.gd).
  var ph := Callable(_Wire, &"format_plain_hint_line").call(1, "interior", "moving") as String
  _assert(ph.begins_with("PLAIN_HINT ") and ph.contains("Mob list index 1"), "plain hint tagging closer")
  var ph_corner := Callable(_Wire, &"format_plain_hint_line").call(-1, "corner", "stopped") as String
  _assert(ph_corner.contains("CORNER"), "corner stopped posture echoed")


func _test_cardinal_avoidance() -> void:
  var base_ctx := {
    "creature_position": Vector2(100.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.0,
  }
  var idle := _Motor.pick_best_move_intent(base_ctx)
  _assert(idle.is_equal_approx(Vector2(0.0, -1.0)), "no mobs tie picks UP first")

  var flee := base_ctx.duplicate(true)
  flee["creature_position"] = Vector2(100.0, 0.0)
  flee["mobs"] = [{"position": Vector2(200.0, 0.0), "velocity": Vector2(-150.0, 0.0)}]
  var leftish := _Motor.pick_best_move_intent(flee)
  _assert(leftish.is_equal_approx(Vector2(-1.0, 0.0)), "mob east favors moving west")

  var oob_pen := _Motor.cost_at_prediction(
    Vector2(-10.0, 200.0),
    [],
    Vector2.ZERO,
    Vector2(480.0, 720.0),
    1.0,
    0.5,
    1e7,
    8.0,
    Vector2.ZERO
  )
  _assert(oob_pen >= 1e6, "OOB prediction gets huge cost")

  var q := _Motor.closest_point_on_aabb(Vector2(100.0, 100.0), Vector2(10.0, 10.0), Vector2(200.0, 100.0))
  _assert(q.is_equal_approx(Vector2(110.0, 100.0)), "nearest AABB point clamps to east face")

  var c_point := _Motor.cost_at_prediction(
    Vector2(100.0, 100.0),
    [{"position": Vector2(100.0, 130.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(480.0, 720.0),
    1.0,
    0.5,
    1e7,
    8.0,
    Vector2.ZERO
  )
  var c_foot := _Motor.cost_at_prediction(
    Vector2(100.0, 100.0),
    [{"position": Vector2(100.0, 130.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(480.0, 720.0),
    1.0,
    0.5,
    1e7,
    8.0,
    Vector2(20.0, 20.0)
  )
  _assert(c_foot > c_point, "nonzero footprint clears mob at center more aggressively than point model")

  var threat := base_ctx.duplicate(true)
  threat["creature_position"] = Vector2(200.0, 200.0)
  threat["mobs"] = [{"position": Vector2(200.0, 200.0), "velocity": Vector2.ZERO}]
  var c_idle := _Motor.cost_at_prediction(
    Vector2(200.0, 200.0),
    threat["mobs"],
    Vector2.ZERO,
    Vector2(480.0, 720.0),
    1.0,
    0.5,
    1e7,
    8.0,
    Vector2(20.0, 20.0)
  )
  var c_step := _Motor.cost_at_prediction(
    Vector2(200.0, 200.0) + Vector2(0.0, -1.0) * 400.0 * 0.15,
    threat["mobs"],
    Vector2.ZERO,
    Vector2(480.0, 720.0),
    1.0,
    0.5,
    1e7,
    8.0,
    Vector2(20.0, 20.0)
  )
  _assert(c_step < c_idle, "mob overlap favors moving off center vs standing still (affirmative dodge cost)")

  var pair := [
    {"position": Vector2(170.0, 200.0), "velocity": Vector2.ZERO},
    {"position": Vector2(230.0, 200.0), "velocity": Vector2.ZERO},
  ]
  var mid := Vector2(200.0, 200.0)
  var c_pair_lin := _Motor.cost_at_prediction(
    mid, pair, Vector2.ZERO, Vector2(480.0, 720.0), 0.45, 1.05, 1e7, 12.0, Vector2.ZERO, 0.0, 0.0
  )
  var c_pair_sq := _Motor.cost_at_prediction(
    mid, pair, Vector2.ZERO, Vector2(480.0, 720.0), 0.45, 1.05, 1e7, 12.0, Vector2.ZERO, 0.0, 55.0
  )
  _assert(c_pair_sq > c_pair_lin + 0.05, "weight_dist_sq adds crowding penalty between two mobs")

  var corner := base_ctx.duplicate(true)
  corner["creature_position"] = Vector2(2.0, 360.0)
  corner["mobs"] = []
  var away_from_oob := _Motor.pick_best_move_intent(corner)
  _assert(not away_from_oob.is_equal_approx(Vector2(-1.0, 0.0)), "near left wall avoids stepping OOB")

  # Callable: static exists on script; analyzer sometimes misses it on preload() type (see _test_perception_snippet).
  var o_det: Array = Callable(_Motor, &"evaluation_order_from_ctx").call(
    {"creature_position": Vector2.ONE, "deterministic_tie_order": true, "shuffle_tie_break": true}
  ) as Array
  _assert((o_det[0] as Vector2).is_equal_approx(Vector2(0.0, -1.0)), "deterministic tie order starts UP")
  var o_a: Array = Callable(_Motor, &"evaluation_order_from_ctx").call(
    {"creature_position": Vector2(3.0, 4.0), "tie_shuffle_seed": 7, "shuffle_tie_break": true}
  ) as Array
  var o_b: Array = Callable(_Motor, &"evaluation_order_from_ctx").call(
    {"creature_position": Vector2(3.0, 4.0), "tie_shuffle_seed": 999, "shuffle_tie_break": true}
  ) as Array
  _assert((o_a[4] as Vector2).is_equal_approx(Vector2.ZERO) and (o_b[4] as Vector2).is_equal_approx(Vector2.ZERO), "ZERO always last in shuffled order")
  var perm_diff := false
  for i in range(4):
    if not (o_a[i] as Vector2).is_equal_approx(o_b[i] as Vector2):
      perm_diff = true
  _assert(perm_diff, "different tie_shuffle_seed permutes cardinals")

  var left_open := {
    "creature_position": Vector2(20.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 3.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.0,
  }
  var inward := _Motor.pick_best_move_intent(left_open)
  _assert(inward.is_equal_approx(Vector2.RIGHT), "interior posture pulls toward playfield center from left edge")

  var wall_hug := {
    "creature_position": Vector2(24.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 12.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 2.6,
  }
  var off_edge := _Motor.pick_best_move_intent(wall_hug)
  _assert(off_edge.is_equal_approx(Vector2.RIGHT), "edge clearance pulls away from boundary without interior term")

  ## Awareness gating: mobs beyond radius contribute no incremental mob cost.
  var ctr := Vector2(400.0, 400.0)
  var pred := Vector2(400.0, 400.0)
  var c_no_mob: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.5,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    500.0,
    0.0,
    -2.0,
    Vector2.RIGHT,
    [],
    0.0,
  )
  var c_far_mob: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(400.0, 400.0 + 4000.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.5,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    500.0,
    0.0,
    -2.0,
    Vector2.RIGHT,
    [],
    0.0,
  )
  _assert(is_equal_approx(c_no_mob, c_far_mob), "mob outside awareness radius adds no cost")

  ## Sector cone: forward mob inside extended reach counts; aft mob beyond base only does not.
  var cos45 := cos(deg_to_rad(45.0))
  var c_behind: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(-200.0, 400.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    100.0,
    500.0,
    cos45,
    Vector2(1.0, 0.0),
    [],
    0.0,
  )
  var c_ahead: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(1000.0, 400.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    100.0,
    500.0,
    cos45,
    Vector2(1.0, 0.0),
    [],
    0.0,
  )
  _assert(c_behind < c_ahead - 0.01, "cone lets forward mob contribute more than aft mob at same distance class")

  ## awareness_radius <= 0: no finite distance gate (HK perception plan).
  var c_far_open: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(400.0, 400.0 + 4000.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    0.0,
    0.0,
    cos45,
    Vector2(1.0, 0.0),
    [],
    0.0,
  )
  _assert(c_far_open > c_no_mob + 0.001, "nonpositive awareness_radius still applies mob repulsion from far mobs")
  var c_far_neg: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(400.0, 400.0 + 4000.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    -10.0,
    500.0,
    cos45,
    Vector2(1.0, 0.0),
    [],
    0.0,
  )
  _assert(c_far_neg > c_no_mob + 0.001, "negative awareness_radius skips distance gate like zero")

  ## awareness_cone_extra <= 0: forward sector does not extend reach beyond base radius.
  var c_cone_off: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(520.0, 400.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    100.0,
    0.0,
    cos45,
    Vector2(1.0, 0.0),
    [],
    0.0,
  )
  var c_cone_on: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [{"position": Vector2(520.0, 400.0), "velocity": Vector2.ZERO}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    ctr,
    100.0,
    400.0,
    cos45,
    Vector2(1.0, 0.0),
    [],
    0.0,
  )
  _assert(is_equal_approx(c_cone_off, c_no_mob), "zero cone_extra drops forward mob beyond base radius")
  _assert(c_cone_on > c_no_mob + 0.001, "positive cone_extra pulls forward mob into reach")

  ## Half-angle 180°: forward sector covers full circle; behind mob still gets base+extra reach.
  var cos180 := cos(deg_to_rad(180.0))
  var r_behind := Callable(_Motor, &"effective_awareness_reach").call(
    ctr, Vector2(-200.0, 400.0), 100.0, 500.0, cos180, Vector2(1.0, 0.0)
  ) as float
  var r_narrow := Callable(_Motor, &"effective_awareness_reach").call(
    ctr, Vector2(-200.0, 400.0), 100.0, 500.0, cos45, Vector2(1.0, 0.0)
  ) as float
  _assert(is_equal_approx(r_behind, 600.0), "180° half-angle extends cone extra behind creature")
  _assert(is_equal_approx(r_narrow, 100.0), "45° half-angle does not extend extra behind creature")

  ## Per-entry cost_scale scales mob contribution.
  var c_full := _Motor.cost_at_prediction(
    pred,
    [{"position": Vector2(400.0, 460.0), "velocity": Vector2.ZERO, "cost_scale": 1.0}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
  )
  var c_half := _Motor.cost_at_prediction(
    pred,
    [{"position": Vector2(400.0, 460.0), "velocity": Vector2.ZERO, "cost_scale": 0.5}],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
  )
  _assert(is_equal_approx(c_full, c_half * 2.0), "cost_scale halves mob cost contribution")

  ## Static obstacles add repulsion via weight_obstacle.
  var obs := [{"position": Vector2(400.0, 500.0), "half_extents": Vector2(40.0, 40.0)}]
  var c_plain := _Motor.cost_at_prediction(
    pred, [], Vector2.ZERO, Vector2(2000.0, 2000.0), 1.0, 0.0, 1e7, 12.0, Vector2.ZERO
  )
  var c_block: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,
    [],
    Vector2.ZERO,
    Vector2(2000.0, 2000.0),
    1.0,
    0.0,
    1e7,
    12.0,
    Vector2.ZERO,
    0.0,
    0.0,
    0.0,
    Vector2.ZERO,
    0.0,
    0.0,
    -2.0,
    Vector2.RIGHT,
    obs,
    2.5,
  )
  _assert(c_block > c_plain + 0.001, "obstacle adds inverse-distance cost near prediction")


func _test_environment_baked_grid() -> void:
  var open := _EnvCell.new()
  open.passible = true
  open.movement_impact = 0.0
  open.fit_size = -1.0
  _assert(open.can_enter(99.0), "open passible all sizes")
  _assert(is_equal_approx(open.movement_speed_multiplier(99.0), 1.0), "open no movement impact")

  var mud := _EnvCell.new()
  mud.passible = true
  mud.movement_impact = 0.3
  mud.fit_size = -1.0
  _assert(is_equal_approx(mud.movement_speed_multiplier(1.0), 0.7), "mud slows everyone when no shrub fit_size")

  var shrub := _EnvCell.new()
  shrub.passible = true
  shrub.movement_impact = 0.4
  shrub.fit_size = 2.0
  _assert(is_equal_approx(shrub.movement_speed_multiplier(1.0), 1.0), "shrub exempt when size strictly below fit_size")
  _assert(is_equal_approx(shrub.movement_speed_multiplier(2.0), 0.6), "shrub applies at size == fit_size (strict < exemption)")

  var wall := _EnvCell.new()
  wall.passible = false
  wall.fit_size = 0.0
  _assert(not wall.can_enter(0.1), "squeeze wall blocks everyone when fit_size <= 0")

  var gap := _EnvCell.new()
  gap.passible = false
  gap.fit_size = 3.0
  gap.movement_impact = 0.2
  _assert(gap.can_enter(3.0), "squeeze inclusive creature_size <= fit_size")
  _assert(not gap.can_enter(3.01), "squeeze rejects creature_size > fit_size")
  _assert(is_equal_approx(gap.movement_speed_multiplier(2.0), 0.8), "squeeze interior applies impact to all legal sizes")

  var presets: Array = []
  var k0 := _EnvCell.new()
  k0.passible = true
  var k1 := _EnvCell.new()
  k1.passible = false
  k1.fit_size = 1.0
  presets.append(k0)
  presets.append(k1)
  var img := Image.create(4, 2, false, Image.FORMAT_RGBA8)
  img.fill(Color.WHITE)
  for x in range(2, 4):
    img.set_pixel(x, 0, Color.BLACK)
    img.set_pixel(x, 1, Color.BLACK)
  var cmap := {Color.WHITE: 0, Color.BLACK: 1}
  var baked = _EnvBake.bake_from_image(img, 2, Vector2.ZERO, 32.0, cmap, presets, 0)
  _assert(baked != null, "bake_from_image returns grid")
  _assert(baked.cell_width == 2 and baked.cell_height == 1, "bake cell dims from 4x2 image with pixels_per_cell 2")
  _assert(baked.get_kind_id_at(0, 0) == 0 and baked.get_kind_id_at(1, 0) == 1, "bake maps top-left pixel per cell")
  _assert(baked.is_valid_shape(), "baked buffer matches dimensions")
  var wc: Vector2i = baked.world_to_cell(Vector2(33.0, 10.0))
  _assert(wc == Vector2i(1, 0), "world_to_cell uses floor division by cell_size_px")
  var d1 = baked.sample_cell_data_at_world(Vector2(50.0, 0.0))
  _assert(d1 != null and d1.get("passible") == false, "sample_cell_data_at_world returns squeeze preset")


func _test_mob_avoidance_acceptance() -> void:
  for a in ["move_up", "move_down", "move_left", "move_right"]:
    _assert(InputMap.has_action(a), "InputMap defines %s for HUMAN movement" % a)
  var repo := _Merge.load_merged_config("user://__mob_avoid_accept_repo__.json")
  var cm: Dictionary = repo["merged"]["creature_motor"]
  _assert(str(cm.get("mode", "")).to_lower() == "scripted", "repo game_config creature_motor.mode scripted")
  _assert(
    _Driver.playing_control_mode_int_for_motor_mode_string("llm") == _PlayerScr.ai_control_as_int(),
    "PLAYING branch: llm motor → AI control int",
  )
  _assert(
    _Driver.playing_control_mode_int_for_motor_mode_string("LLM") == _PlayerScr.ai_control_as_int(),
    "motor mode comparison is case-insensitive",
  )
  _assert(
    _Driver.playing_control_mode_int_for_motor_mode_string("scripted") == _PlayerScr.engine_control_as_int(),
    "PLAYING branch: scripted motor → ENGINE control int",
  )
  _assert(
    _Driver.playing_control_mode_int_for_motor_mode_string("unknown_mode") == _PlayerScr.engine_control_as_int(),
    "unknown motor mode maps to ENGINE (safe scripted motor)",
  )


func _test_scripted_intent_hold() -> void:
  var fh := Callable(IntentHoldScr, &"filtered_intent")
  var st: Dictionary = {}
  var incumbent := Vector2(0.0, 1.0)
  var challenger := Vector2(0.0, -1.0)
  for _i in range(4):
    _assert(
      (fh.call(challenger, incumbent, 5, st) as Vector2).is_equal_approx(incumbent),
      "intent hold ignores single-tick challenger"
    )
  var switched: Vector2 = fh.call(challenger, incumbent, 5, st) as Vector2
  _assert(switched.is_equal_approx(challenger), "intent hold adopts after streak")

  Callable(IntentHoldScr, &"reset_state").call(st)
  var right := Vector2(1.0, 0.0)
  _assert((fh.call(right, incumbent, 5, st) as Vector2).is_equal_approx(incumbent), "new challenger resets streak frame 1")
  var left := Vector2(-1.0, 0.0)
  _assert((fh.call(left, incumbent, 5, st) as Vector2).is_equal_approx(incumbent), "challenger swap restarts accumulation")

  Callable(IntentHoldScr, &"reset_state").call(st)
  var cold: Vector2 = fh.call(right, Vector2.ZERO, 3, st) as Vector2
  _assert(cold.is_equal_approx(right), "idle incumbent skips hold")


func _test_perception_risk_hints() -> void:
  var p0 := Vector2.ZERO

  var head_on := _Risk.mob_closing_metrics(Vector2(220.0, 0.0), Vector2(-180.0, 0.0), p0)
  _assert(bool(head_on["closing"]), "straight-on mob radially closes on creature")

  var tangent := _Risk.mob_closing_metrics(Vector2(150.0, 0.0), Vector2(0.0, 200.0), p0)
  _assert(not bool(tangent["closing"]), "perpendicular mover is not radially closing")

  var still := _Risk.mob_closing_metrics(Vector2(80.0, 0.0), Vector2.ZERO, p0)
  _assert(not bool(still["closing"]), "stationary mob skips closing heuristic")

  var corner_sb := Callable(_Risk, &"classify_creature_patch_and_band").call(0, 0, 12, 10, Vector2.ZERO) as Dictionary
  _assert(str(corner_sb.get("patch", "")) == "corner", "corner cell label")
  _assert(str(corner_sb.get("band", "")) == "stopped", "zero velocity reads stopped")

  var wall_lab := Callable(_Risk, &"classify_creature_patch_and_band").call(0, 5, 12, 10, Vector2.ZERO) as Dictionary
  _assert(str(wall_lab.get("patch", "")) == "wall", "top-edge non-corner is wall")

  var interior_mv := Callable(_Risk, &"classify_creature_patch_and_band").call(4, 4, 12, 10, Vector2(50.0, 0.0)) as Dictionary
  _assert(str(interior_mv.get("patch", "")) == "interior", "interior cell")
  _assert(str(interior_mv.get("band", "")) == "moving", "nonzero speed reads moving")

  var prio_mobs_nearest_first: Array = [
    {"point": Vector2(40.0, 0.0), "velocity": Vector2(-200.0, 0.0)},
    {"point": Vector2(80.0, 0.0), "velocity": Vector2(-150.0, 0.0)},
  ]
  var pr: Dictionary = _Risk.pick_priority_closing_mob(prio_mobs_nearest_first, p0)
  _assert(int(pr["idx_1"]) == 1, "nearest fastest closer wins when time-to-close shortest")

  var rh := _Wire.format_risk_hints_line(-1, INF, "interior", "moving")
  _assert(
    rh.begins_with("RISK_HINTS ") and rh.contains("CLOSEST_CLOSING_I=-1") and rh.contains("CREATURE_PATCH"),
    "risk hint formatter no closer"
  )


func _test_perception_sampling() -> void:
  var ident := Transform2D.IDENTITY
  var r := Rect2(-10, -20, 30, 40)
  var a := _Sampling.world_aabb_from_shape_rect(r, ident)
  _assert(a.get_center().is_equal_approx(Vector2(5, 0)), "aabb center ident xf")
  _assert(a.size.is_equal_approx(Vector2(30, 40)), "aabb size ident xf")
  var shifted := Transform2D.IDENTITY.translated(Vector2(100, 200))
  var b := _Sampling.world_aabb_from_shape_rect(Rect2(-5, -5, 10, 10), shifted)
  _assert(b.get_center().is_equal_approx(Vector2(100, 200)), "aabb translated unit rect")
  var st_root := get_root()
  var body := Area2D.new()
  var cs := CollisionShape2D.new()
  var cap := CapsuleShape2D.new()
  cap.radius = 10.0
  cap.height = 30.0
  cs.shape = cap
  body.add_child(cs)
  st_root.add_child(body)
  body.global_position = Vector2(200, 300)
  var s: Dictionary = _Sampling.sampling_from_collision_object(body)
  st_root.remove_child(body)
  body.queue_free()
  var p: Vector2 = s.get("point", Vector2.ZERO)
  var he: Vector3 = s.get("half_extents", Vector3.ZERO)
  _assert(p.is_equal_approx(Vector2(200, 300)), "capsule sampling center")
  _assert(he.x > 5.0 and he.y > 15.0, "capsule half-extents plausible")


func _test_ai_driver_helpers() -> void:
  _assert(_Driver.should_apply_response_id(7, 7), "latest-enqueued response applies")
  _assert(not _Driver.should_apply_response_id(6, 7), "older response is stale")
  var d := _Driver.new()
  _assert(d.get_armed_handshake_user() == "ARMED", "armed handshake literal")
  _assert(_Driver.http_request_result_label(HTTPRequest.RESULT_CANT_CONNECT) == "CANT_CONNECT", "HTTP label")
  _assert(
    _Driver.extract_openai_chat_choice_text({
      "choices": [{"message": {"content": [{"type": "text", "text": "LEFT"}]}}],
    })
    == "LEFT",
    "OpenAI array-shaped message.content",
  )
  _assert(
    _Driver.extract_openai_chat_choice_text({"choices": [{"message": {"content": "RIGHT"}, "text": ""}]})
    == "RIGHT",
    "string message.content",
  )
  _assert(
    _Driver.extract_openai_chat_choice_text({"choices": [{"text": "legacy DOWN"}]}) == "legacy DOWN",
    "legacy choices[0].text fallback",
  )
  _assert(
    _Driver.extract_openai_chat_choice_text({
      "choices": [{"message": {"content": [{"type": "output_text", "text": "UP"}]}}],
    })
    == "UP",
    "OpenAI output_text content block (llama-server)",
  )
  _assert(
    _Driver.extract_openai_completion_choice_text({"choices": [{"text": "LEFT"}]}) == "LEFT",
    "OpenAI /v1/completions choices[0].text",
  )
  _assert(
    _Driver.extract_openai_completion_choice_text({"choices": [{}]}) == "",
    "empty completion text",
  )
  _assert(_Driver.gbnf_for_completion_state_enum(1).contains("START"), "gbnf ARMED")
  _assert(_Driver.gbnf_for_completion_state_enum(2).contains("RIGHT"), "gbnf PLAYING")
  _assert(_Driver.gbnf_for_completion_state_enum(0).is_empty(), "gbnf IDLE empty")


func _test_bundled_inference_helpers() -> void:
  var ic_off := {"INFERENCE_AUTO_START_ENABLED": false}
  _assert(not _Bundle.should_attempt_auto_start(ic_off, "http://127.0.0.1:8080"), "auto-start off")
  var ic_on := {"INFERENCE_AUTO_START_ENABLED": true}
  _assert(_Bundle.should_attempt_auto_start(ic_on, "http://127.0.0.1:8080"), "loopback + auto")
  _assert(not _Bundle.should_attempt_auto_start(ic_on, "https://api.example.com"), "remote URL no spawn")
  _assert(_Bundle.port_from_base_url("http://127.0.0.1:9090/") == 9090, "port parse")
  _assert(_Bundle.port_from_base_url("http://127.0.0.1") == 8080, "default port when omitted")
