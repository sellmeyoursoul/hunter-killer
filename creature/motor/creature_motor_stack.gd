extends RefCounted
class_name CreatureMotorStack
## Per-creature V3 motor runtime — hub + cadence + planner + execution ([CREATURE_MOVEMENT_V3.md §1 / §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")
const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _MotorGoalHub := preload("res://creature/motor/motor_goal_hub.gd")
const _MotorCadence := preload("res://creature/motor/motor_consideration_cadence.gd")
const _MotorPlanner := preload("res://creature/motor/motor_planner.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _AwarenessScan := preload("res://creature/motor/awareness_zone_scan.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _MemoryAdapter := preload("res://creature/motor/memory_adapter.gd")
const _ExploreLog := preload("res://creature/motor/motor_planner_explore_log.gd")
const _ReplayCapture := preload("res://creature/motor/motor_planner_replay_capture.gd")
const _ThreatDisposition := preload("res://creature/motor/threat_disposition.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")


var _body: CharacterBody3D
var _vitals: Node
var _motor_v3: Dictionary = {}
var _pack_root: String = ""
var _goal_catalog: Dictionary = {}

var _physics_tick_count: int = 0
var _consideration_interval: int = 8
var _ticks_since_consideration: int = 0
var _active_goals: Array = []
var _incumbent: Dictionary = {}
var _flight_fast_path_active: bool = false
var _safety_met: bool = false
var _threat_samples: Array = []
var _live_threat_samples: Array = []
var _food_split: Dictionary = {"ready": [], "unready": []}
var _food_map_confidence: float = 0.0
var _stat_observation: int = 10
var _planner_state: Dictionary = {}
var _threat_samples_test_override: bool = false
var _safety_cycles: int = 0
var _flight_fast_path_latched: bool = false
var _scan_test_override: Dictionary = {}
var _use_scan_test_override: bool = false
var _env_grid_test_override: Variant = null
var _use_env_grid_test_override: bool = false
var _memory_adapter: _MemoryAdapter
var _last_outcome: _ActionOutcome
var _benign_episode_pending: bool = false
var _was_flight_fast_path: bool = false

## TEMP-DEBUG (CLEANUP C9/C10 fail-fast harness): live invariant checks at the end of every
## [method tick] — flags known bug signatures (stuck-under-geometry, flee-waypoint loop, silent
## stall) the instant they happen instead of reconstructing them from logs afterward. No-op cost
## when disabled; flip to false once C9/C10 are closed out.
const _DEBUG_ASSERT_MOTOR_INVARIANTS := true
const _INVARIANT_POS_HISTORY_LEN := 30
const _INVARIANT_FLEE_WP_HISTORY_LEN := 20
const _INVARIANT_STALL_MIN_DISP := 0.02
const _INVARIANT_SETTLE_TICKS := 45
const _INVARIANT_MAX_AIRBORNE_TICKS := 45
var _invariant_pos_history: Array = []
var _invariant_flee_wp_history: Array = []
var _invariant_last_flee_wp: Vector3 = Vector3.ZERO
var _invariant_airborne_ticks: int = 0
var _invariant_tripped: bool = false


## Wires body, vitals, merged [code]creature_motor_v3[/code], and goal catalog at spawn.
func configure(
  body: CharacterBody3D,
  vitals: Node,
  motor_v3: Dictionary,
  pack_root: String,
  goal_catalog: Dictionary,
) -> void:
  _body = body
  _vitals = vitals
  _motor_v3 = motor_v3.duplicate(true)
  if body != null:
    _motor_v3["caloric_needs_hint"] = maxf(1.0, float(body.get("caloric_needs")))
  _pack_root = str(pack_root).strip_edges()
  _goal_catalog = goal_catalog.duplicate(true) if typeof(goal_catalog) == TYPE_DICTIONARY else {}
  _stat_observation = _resolve_stat_observation()
  _consideration_interval = _MotorCadence.observation_replan_interval_ticks(
    _stat_observation,
    _motor_v3,
  )
  _physics_tick_count = 0
  _ticks_since_consideration = _consideration_interval
  _active_goals = []
  _incumbent = {}
  _flight_fast_path_active = false
  _flight_fast_path_latched = false
  _safety_cycles = 0
  _safety_met = false
  _benign_episode_pending = false
  _was_flight_fast_path = false
  _planner_state = _MotorPlanner.new_state()
  _threat_samples_test_override = false
  _use_scan_test_override = false
  _scan_test_override = {}
  if _memory_adapter == null:
    _memory_adapter = _MemoryAdapter.new()
  _memory_adapter.configure(_pack_root, _traits_from_body())
  _memory_adapter.set_goal_catalog(_goal_catalog)
  if _body != null and _body.has_method(&"get_food_intake_policy"):
    _memory_adapter.set_food_intake_policy(_body.call(&"get_food_intake_policy"))
  _ExploreLog.reset_session()
  _ReplayCapture.reset_session_for(_creature_log_label())


## One physics tick: awareness scan, consideration cadence, planner action, execution.
func tick(delta: float) -> _ActionOutcome:
  _physics_tick_count += 1
  _run_live_scan()
  _maintain_memory_beliefs()
  var area_only := _rest_area_only_perception()
  _refresh_danger_samples(area_only)
  var ctx := _build_context()

  var ran_consideration := false
  if _should_run_consideration():
    _update_safety_on_consideration()
    ran_consideration = true

  _update_flight_fast_path(ctx)
  ctx["flight_fast_path_active"] = _flight_fast_path_active
  var flight_just_entered := _flight_fast_path_active and not _was_flight_fast_path
  var flight_just_exited := not _flight_fast_path_active and _was_flight_fast_path
  ctx["flight_just_entered"] = flight_just_entered
  if flight_just_exited:
    (_MotorPlanner as GDScript).call("clear_flee_waypoint_latch", _planner_state)
  _update_threat_disposition(ctx)
  ctx["threat_disposition_mod"] = _threat_disposition_mod()
  ctx["safety_met"] = _safety_met

  if ran_consideration:
    _run_consideration(ctx)

  var planner_ctx := _build_planner_context(ctx, delta)
  planner_ctx["refresh_step_objective"] = ran_consideration
  planner_ctx["run_path_clearance"] = ran_consideration

  var pos_before_tick := _body.global_position
  var action := _MotorPlanner.select_action(planner_ctx, _planner_state)
  var dist_to_goal_for_move: Variant = null
  var move_turn_target: Variant = null
  if int(_MotorAction.normalize(action)) == _MotorAction.MOVE_FORWARD:
    # Arrival damping only applies to fixed/latched objectives (locale/precise/memory_moving) —
    # `live` pursuit's step_goal is the prey's own position, re-targeted every tick, so its
    # distance shrinks exactly as the fox closes in; damping it there throttles the predator
    # right when closing the last few meters matters most, while the fleeing prey's own step_goal
    # (a distant flee waypoint) never enters damping range — an asymmetric speed penalty that let
    # a matched-speed prey out-run a nominally faster predator (CLEANUP R1, duel 2026-07-15).
    # Mirrors the same `live`-exclusion already applied to the overshoot remint
    # (`_is_fixed_objective_overshoot_source` in motor_planner.gd) and for the same reason.
    if _planner_state.get("step_source", &"live") != &"live":
      var candidate := float(_planner_state.get("dist_to_goal", -1.0))
      if candidate >= 0.0:
        dist_to_goal_for_move = candidate
    # Turn+move blend (CLEANUP R1 mitigation #2) applies to every step source, `live` included —
    # unlike arrival damping, blending a bounded heading correction into the move is exactly what
    # keeps a continuously-retargeting live pursuit from committing to a stale heading and
    # overshooting through the target (the duel bug this mitigation targets).
    var step_goal: Vector3 = _planner_state.get("step_goal", Vector3.ZERO)
    if step_goal.length_squared() > 1e-8:
      move_turn_target = step_goal
  var outcome: _ActionOutcome = LocomotionExecutor.apply_action(
    _body, action, delta, _motor_v3, dist_to_goal_for_move, move_turn_target
  )
  var boundary_clamped := _clamp_playfield_if_needed()
  var run_blocked_resolution: bool = (
    _MotorPlanner as GDScript
  ).call(
    "note_tick_completion",
    _planner_state,
    _body,
    outcome,
    _motor_v3,
    _physics_tick_count,
    pos_before_tick,
    boundary_clamped,
    delta,
    planner_ctx,
  )
  _last_outcome = outcome
  if outcome != null and int(outcome.action) == _MotorAction.MOVE_FORWARD and outcome.blocked:
    var blocked_path_ctx := _build_planner_context(ctx, delta)
    (_MotorPlanner as GDScript).call(
      "apply_immediate_blocked_path_reevaluation",
      blocked_path_ctx,
      _planner_state,
      _body,
      _motor_v3,
    )
  if int(outcome.action) == _MotorAction.EAT:
    _try_complete_eat()
  if outcome != null and not outcome.blocked and int(outcome.action) == _MotorAction.MOVE_FORWARD:
    if _memory_adapter != null:
      _memory_adapter.clear_dead_end_near(_body.global_position, _motor_v3)
  elif run_blocked_resolution:
    var blocked_ctx := _build_planner_context(ctx, delta)
    if not (_MotorPlanner as GDScript).call(
      "should_suppress_live_pursuit_blocked_resolution",
      blocked_ctx,
      _planner_state,
    ):
      _MotorPlanner.apply_blocked_objective_resolution(
        blocked_ctx, _planner_state, _body, _motor_v3
      )
  if _objective_completed_this_tick(action):
    _run_consideration(ctx)
  _advance_consideration_timer()
  _apply_gravity_if_stationary(action, delta)
  _maybe_log_motor_tick()
  if _DEBUG_ASSERT_MOTOR_INVARIANTS:
    _assert_motor_invariants(action, outcome)
  return outcome


## TEMP-DEBUG (CLEANUP C9/C10): fail-fast the instant a known bug signature reproduces, with the
## exact tick's state dumped to stderr — see [const _DEBUG_ASSERT_MOTOR_INVARIANTS].
func _assert_motor_invariants(action: int, outcome: _ActionOutcome) -> void:
  if _invariant_tripped or _body == null or not is_instance_valid(_body):
    return
  var pos := _body.global_position
  var label := _creature_log_label()

  if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)):
    _trip_invariant(label, "NaN/Inf position", {"pos": pos, "tick": _physics_tick_count})
    return

  if _physics_tick_count <= _INVARIANT_SETTLE_TICKS:
    return

  if _body.is_on_floor():
    _invariant_airborne_ticks = 0
  else:
    _invariant_airborne_ticks += 1
    if _invariant_airborne_ticks > _INVARIANT_MAX_AIRBORNE_TICKS:
      _trip_invariant(
        label,
        "airborne/off-floor for %d+ ticks (stuck-under-geometry, C10)" % _INVARIANT_MAX_AIRBORNE_TICKS,
        {"pos": pos, "airborne_ticks": _invariant_airborne_ticks, "tick": _physics_tick_count},
      )
      return

  var flee_wp: Vector3 = _planner_state.get("flee_waypoint", Vector3.ZERO)
  if flee_wp == Vector3.ZERO:
    # Flight episode ended — history from a prior episode shouldn't indict a new one that
    # happens to mint near the same spot (e.g. a recurring corner) on its very first remint.
    _invariant_flee_wp_history.clear()
    _invariant_last_flee_wp = Vector3.ZERO
  elif flee_wp.distance_to(_invariant_last_flee_wp) >= 0.05:
    # Only a genuine remint (the waypoint just changed) counts as a history event — while a
    # waypoint is latched it's expected to read back identical tick after tick, so comparing
    # every tick's value (rather than only value-change events) against history flagged normal
    # latch persistence as a false "repeat."
    for prior in _invariant_flee_wp_history:
      if (prior as Vector3).distance_to(flee_wp) < 0.05:
        _trip_invariant(
          label,
          "flee_waypoint remint repeated a recent remint (boundary ping-pong, C9)",
          {"flee_waypoint": flee_wp, "tick": _physics_tick_count},
        )
        return
    _invariant_flee_wp_history.append(flee_wp)
    if _invariant_flee_wp_history.size() > _INVARIANT_FLEE_WP_HISTORY_LEN:
      _invariant_flee_wp_history.pop_front()
    _invariant_last_flee_wp = flee_wp

  if int(_MotorAction.normalize(action)) == _MotorAction.MOVE_FORWARD and not outcome.blocked:
    _invariant_pos_history.append(pos)
    if _invariant_pos_history.size() > _INVARIANT_POS_HISTORY_LEN:
      _invariant_pos_history.pop_front()
    if _invariant_pos_history.size() == _INVARIANT_POS_HISTORY_LEN:
      var oldest: Vector3 = _invariant_pos_history[0]
      if oldest.distance_to(pos) < _INVARIANT_STALL_MIN_DISP:
        _trip_invariant(
          label,
          "unblocked MOVE_FORWARD made no progress over %d ticks (silent stall)"
          % _INVARIANT_POS_HISTORY_LEN,
          {"pos": pos, "oldest_pos": oldest, "tick": _physics_tick_count},
        )
        return
  else:
    _invariant_pos_history.clear()


func _trip_invariant(label: String, reason: String, data: Dictionary) -> void:
  _invariant_tripped = true
  push_error("MOTOR_INVARIANT [%s] %s | %s" % [label, reason, JSON.stringify(data)])
  if _body != null and _body.is_inside_tree():
    _body.get_tree().quit(1)


func _maybe_log_motor_tick() -> void:
  var snap := get_debug_snapshot()
  var label := _creature_log_label()
  _ExploreLog.maybe_log_tick(label, snap)
  _ReplayCapture.maybe_capture_tick(label, _replay_capture_record())


## Raw planner-input snapshot for [MotorPlannerReplayCapture] — the external stimulus
## (position/facing/calories + live scan) that drove this tick's [method _MotorPlanner.select_action]
## call, as opposed to [method get_debug_snapshot]'s derived planner-output state.
func _replay_capture_record() -> Dictionary:
  var pos := Vector3.ZERO
  var facing := Vector3.ZERO
  if _body != null:
    pos = _body.global_position
    facing = _MotorPlane.read_dir(_body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var action_label := "?"
  if _last_outcome != null:
    action_label = _motor_action_debug_label(int(_last_outcome.action))
  return {
    "tick": _physics_tick_count,
    "pos": pos,
    "facing": facing,
    "calorie_ratio": _calorie_ratio(),
    "goal_kind": str(_incumbent.get("goal_kind", "")),
    "step_source": str(_planner_state.get("step_source", "")),
    "action": action_label,
    "food_split": _food_split,
    "threat_samples": _threat_samples,
    "food_map_confidence": _food_map_confidence,
  }


## Per-instance label, e.g. `rabbit#116937200019` — the numeric suffix is `creature_instance_id`
## (`Node.get_instance_id()`, stable for the instance's lifetime), so logs stay unambiguous once
## more than one creature of the same species is alive at once (CLEANUP C2 live-repro finding).
func _creature_log_label() -> String:
  if _body == null:
    return "creature"
  var iid := int(_body.get("creature_instance_id")) if _body.get("creature_instance_id") != null else 0
  var suffix := ("#%d" % iid) if iid != 0 else ""
  var def_v: Variant = _body.get("definition")
  if def_v is Resource:
    var species := str((def_v as Resource).get("species_id")).strip_edges()
    if not species.is_empty():
      return species + suffix
    var display := str((def_v as Resource).get("display_name")).strip_edges()
    if not display.is_empty():
      return display + suffix
  if not _body.name.is_empty():
    return str(_body.name) + suffix
  return "creature" + suffix


func get_physics_tick_count() -> int:
  return _physics_tick_count


func get_consideration_interval() -> int:
  return _consideration_interval


func get_ticks_since_consideration() -> int:
  return _ticks_since_consideration


func get_active_goals() -> Array:
  return _active_goals.duplicate(true)


func get_incumbent() -> Dictionary:
  return _incumbent.duplicate(true)


## Known-food inventory scalar driving hub shelter gate and Eat urgency (§1).
func get_food_map_confidence() -> float:
  return _food_map_confidence


func is_flight_fast_path_active() -> bool:
  return _flight_fast_path_active


func is_safety_met() -> bool:
  return _safety_met


func get_food_split() -> Dictionary:
  return _food_split.duplicate(true)


func get_planner_step_goal() -> Vector3:
  return _planner_state.get("step_goal", Vector3.ZERO)


func get_planner_step_source() -> StringName:
  return _planner_state.get("step_source", &"")


func get_planner_blocked_objective_action() -> StringName:
  return _planner_state.get("blocked_objective_action", &"")


## Read-only motor planner snapshot for duel debug HUD ([code]motor_planner_debug_hud.gd[/code]).
func get_debug_snapshot() -> Dictionary:
  var ps := _planner_state.duplicate(true)
  var step_goal: Vector3 = ps.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8 and str(ps.get("step_source", "")) == "explore":
    var latched_wp: Vector3 = ps.get("explore_waypoint", Vector3.ZERO)
    if latched_wp.length_squared() > 1e-8:
      step_goal = latched_wp
  var ready: Array = _food_split.get("ready", [])
  var action_label := "?"
  var blocked := false
  if _last_outcome != null:
    action_label = _motor_action_debug_label(int(_last_outcome.action))
    blocked = _last_outcome.blocked
  var bearing := {"bearing_error_deg": 0.0, "facing_dot_tgt": 0.0, "dist_to_goal": 0.0}
  if _body != null and step_goal.length_squared() > 1e-8:
    var creature_pos := _body.global_position
    var to_target := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
    var facing := _MotorPlane.read_dir(_body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
    var to_n := to_target.normalized()
    var cross := facing.x * to_n.z - facing.z * to_n.x
    var dot := clampf(facing.dot(to_n), -1.0, 1.0)
    bearing["bearing_error_deg"] = rad_to_deg(atan2(cross, dot))
    bearing["facing_dot_tgt"] = facing.dot(to_n)
    # Recomputed fresh here (not read from planner state's dist_to_goal) so it reflects this
    # exact tick's body position even on ticks that never reach align_and_move (EAT, orbit,
    # STAY-at-arrival) — CLEANUP R1 debugging follow-up (2026-07-15 duel review).
    bearing["dist_to_goal"] = to_target.length()
  return {
    "action": action_label,
    "blocked": blocked,
    "calorie_ratio": _calorie_ratio(),
    "incumbent_goal": str(_incumbent.get("goal_kind", "")),
    "incumbent_weight": float(_incumbent.get("weight", 0.0)),
    "goal_kind": str(ps.get("goal_kind", "")),
    "step_source": str(ps.get("step_source", "")),
    "step_goal_xz": Vector2(step_goal.x, step_goal.z),
    "step_instance_id": int(ps.get("step_instance_id", 0)),
    "stimulus_kind_id": str(ps.get("step_stimulus_kind_id", "")),
    "blocked_objective_action": str(ps.get("blocked_objective_action", "")),
    "consecutive_blocked": int(ps.get("consecutive_blocked", 0)),
    "explore_no_progress_ticks": int(ps.get("explore_no_progress_ticks", 0)),
    "boundary_scan_active": bool(ps.get("boundary_scan_active", false)),
    "boundary_scan_sign": int(ps.get("boundary_scan_sign", 0)),
    "bearing_error_deg": float(bearing.get("bearing_error_deg", 0.0)),
    "facing_dot_tgt": float(bearing.get("facing_dot_tgt", 0.0)),
    "dist_to_goal": float(bearing.get("dist_to_goal", 0.0)),
    "physics_tick": _physics_tick_count,
    "consideration_interval": _consideration_interval,
    "ticks_since_consideration": _ticks_since_consideration,
    "flight_fast_path": _flight_fast_path_active,
    "ready_food": ready.size(),
    "threat_count": _threat_samples.size(),
    "incumbent_empty": _incumbent.is_empty(),
    "food_map_confidence": _food_map_confidence,
    "inventory_ratio": _food_map_confidence,
    "effective_urgency_find_food": _MotorGoalHub.effective_urgency_find_food(
      _calorie_ratio(),
      _food_map_confidence,
      _motor_v3,
    ),
    "prey_engagement_instance_id": int(ps.get("prey_engagement_instance_id", 0)),
    "prey_engagement_ticks_remaining": int(ps.get("prey_engagement_ticks_remaining", 0)),
    "prey_engagement_latch_total": int(ps.get("prey_engagement_latch_total", 0)),
    "pursuit_detour_ticks_remaining": int(ps.get("pursuit_detour_ticks_remaining", 0)),
    "food_inventory_step_mode": int(ps.get("food_inventory_step_mode", -1)),
    "is_carnivore": _is_carnivore_body(),
  }


## Short debug label for a [MotorAction] id ([code]-1[/code] → [code]"?"[/code]).
func _motor_action_debug_label(act: int) -> String:
  match act:
    _MotorAction.TURN_LEFT:
      return "TURN_L"
    _MotorAction.TURN_RIGHT:
      return "TURN_R"
    _MotorAction.MOVE_FORWARD:
      return "MOVE_F"
    _MotorAction.MOVE_BACKWARD:
      return "MOVE_B"
    _MotorAction.STAY:
      return "STAY"
    _MotorAction.REST:
      return "REST"
    _MotorAction.EAT:
      return "EAT"
    _:
      return "?"


func get_memory_adapter() -> _MemoryAdapter:
  return _memory_adapter


## Clears stack-owned beliefs and locale priors — session / duel reset (6d.2 slice 0).
func reset_memory() -> void:
  if _memory_adapter != null:
    _memory_adapter.reset()


## Records find_food locale prior + kind EWMA after EAT — routes to this stack's adapter (§6.2).
func notify_food_consumption_outcome(
  food_anchor: Vector3,
  insufficient_yield: bool = false,
  stimulus_kind_id: StringName = &"",
  calories_gained: int = 0,
) -> void:
  if _memory_adapter == null:
    return
  _memory_adapter.notify_food_consumption_outcome(
    food_anchor,
    insufficient_yield,
    _motor_v3,
    _resolve_environment_grid(),
    stimulus_kind_id,
    calories_gained,
  )


## Test harness: inject environment grid for salient-write fixtures.
func set_environment_grid_for_test(grid: Variant) -> void:
  _env_grid_test_override = grid
  _use_env_grid_test_override = true


## Test harness: seed precise find_food belief on the stack's memory adapter.
func seed_precise_food_belief_for_test(instance_id: int, world_pos: Vector3, now_ms: int) -> void:
  _memory_adapter.seed_precise_food_belief(instance_id, world_pos, now_ms)


## Test harness: seed coarse find_food belief on the stack's memory adapter.
func seed_coarse_food_belief_for_test(instance_id: int, world_pos: Vector3, now_ms: int) -> void:
  _memory_adapter.seed_coarse_food_belief(instance_id, world_pos, now_ms)


## Test harness: seed locale prior on the stack's memory adapter.
func seed_locale_prior_for_test(cell_x: int, cell_z: int, weight: float) -> void:
  _memory_adapter.seed_locale_prior_for_test(cell_x, cell_z, weight)


## Test / harness injection for threat geometry (6b).
func set_threat_samples_for_test(samples: Array) -> void:
  _live_threat_samples = samples.duplicate(true)
  _threat_samples = _live_threat_samples.duplicate(true)
  _threat_samples_test_override = true


func seed_threat_belief_for_test(
  instance_id: int,
  world_pos: Vector3,
  now_ms: int,
  stimulus_kind_id: StringName = &"wolf",
) -> void:
  if _memory_adapter != null:
    _memory_adapter.seed_threat_belief_for_test(instance_id, world_pos, now_ms, stimulus_kind_id)


func set_safety_met_for_test(met: bool) -> void:
  _safety_met = met


func set_food_map_confidence_for_test(confidence: float) -> void:
  _food_map_confidence = clampf(confidence, 0.0, 1.0)


## Injects a canned live scan result for headless planner tests.
func set_live_scan_for_test(scan: Dictionary) -> void:
  _scan_test_override = scan.duplicate(true)
  _use_scan_test_override = true


func _run_live_scan() -> void:
  if _use_scan_test_override:
    _apply_scan_dict(_scan_test_override)
    return
  if _body == null or not _body.is_inside_tree():
    return
  var tree := _body.get_tree()
  if tree == null:
    return
  var area_only := _rest_area_only_perception()
  var scan := _AwarenessScan.scan_live(_body, _motor_v3, tree, area_only)
  _apply_scan_dict(scan)


func _apply_scan_dict(scan: Dictionary) -> void:
  var split: Variant = scan.get("food_split", {})
  if typeof(split) == TYPE_DICTIONARY:
    _food_split = (split as Dictionary).duplicate(true)
  if _memory_adapter != null:
    _food_split = _memory_adapter.enrich_food_split_with_kind_yield(_food_split, _motor_v3)
  if not _threat_samples_test_override:
    _live_threat_samples = scan.get("threat_samples", []).duplicate(true)
  if _memory_adapter != null:
    _memory_adapter.sync_after_scan(_food_split, _live_threat_samples, Time.get_ticks_msec())
  _refresh_food_inventory()


func _refresh_food_inventory() -> void:
  if _memory_adapter == null or _body == null:
    _food_map_confidence = 0.0
    return
  var now_ms := Time.get_ticks_msec()
  var known := _memory_adapter.count_known_objectives(
    _GkReg.GK_FIND_FOOD,
    _body.global_position,
    _motor_v3,
    _food_split,
    now_ms,
    _build_zone_ctx(false),
    _live_threat_samples,
  )
  _food_map_confidence = _MotorGoalHub.inventory_ratio_for_goal(
    _GkReg.GK_FIND_FOOD,
    known,
    _motor_v3,
  )


func _refresh_danger_samples(area_only: bool) -> void:
  if _memory_adapter == null or _body == null:
    _threat_samples = _live_threat_samples.duplicate(true)
    return
  var zone_ctx := _build_zone_ctx(area_only)
  _threat_samples = _memory_adapter.consult_danger_samples(zone_ctx, _live_threat_samples)


func _build_zone_ctx(area_only: bool) -> Dictionary:
  var creature_pos := _body.global_position if _body != null else Vector3.ZERO
  var facing: Vector3 = _body.get("last_move_direction") if _body != null else Vector3.FORWARD
  var eye_h := 1.0
  var space: PhysicsDirectSpaceState3D = null
  if _body != null and _body.is_inside_tree():
    space = _body.get_world_3d().direct_space_state
    if _body.has_method(&"get_los_eye_height"):
      eye_h = float(_body.call(&"get_los_eye_height"))
  return {
    "creature_pos": creature_pos,
    "facing": facing,
    "eye_height": eye_h,
    "space_state": space,
    "motor_v3": _motor_v3,
    "area_only": area_only,
  }


func _maintain_memory_beliefs() -> void:
  if _memory_adapter == null or _body == null:
    return
  _memory_adapter.maintain_beliefs(_body.global_position, Time.get_ticks_msec(), _motor_v3)


func _rest_area_only_perception() -> bool:
  if _incumbent.get("goal_kind", &"") == _MotorGoalHub.GOAL_REST:
    return true
  if _last_outcome != null and int(_last_outcome.action) == _MotorAction.REST:
    return true
  return false


func _update_safety_on_consideration() -> void:
  var required := maxi(1, int(_motor_v3.get("safety_time", 5)))
  if _threat_samples.is_empty():
    _safety_cycles += 1
  else:
    _safety_cycles = 0
  _safety_met = _safety_cycles >= required


func _build_context() -> Dictionary:
  return {
    "body": _body,
    "motor_v3": _motor_v3,
    "calorie_ratio": _calorie_ratio(),
    "threat_samples": _threat_samples,
    "flight_fast_path_active": _flight_fast_path_active,
    "safety_met": _safety_met,
    "food_map_confidence": _food_map_confidence,
    "inventory_ratio": _food_map_confidence,
    "pack_root": _pack_root,
    "goal_catalog": _goal_catalog,
    "food_split": _food_split,
    "memory_adapter": _memory_adapter,
    "environment_grid": _resolve_environment_grid(),
    "threat_disposition_mod": _threat_disposition_mod(),
  }


func _build_planner_context(hub_ctx: Dictionary, delta: float) -> Dictionary:
  var map_rid := RID()
  var main := _resolve_main()
  if main != null and main.has_method(&"get_navigation_map_rid"):
    map_rid = main.call(&"get_navigation_map_rid") as RID
  var space: PhysicsDirectSpaceState3D = null
  var eye_h := 1.0
  if _body != null and _body.is_inside_tree():
    space = _body.get_world_3d().direct_space_state
    if _body.has_method(&"get_los_eye_height"):
      eye_h = float(_body.call(&"get_los_eye_height"))
  return {
    "body": _body,
    "motor_v3": _motor_v3,
    "incumbent": _incumbent,
    "flight_fast_path_active": hub_ctx.get("flight_fast_path_active", false),
    "flight_just_entered": bool(hub_ctx.get("flight_just_entered", false)),
    "threat_samples": _threat_samples,
    "scan": {
      "food_split": _food_split,
      "threat_samples": _threat_samples,
      "food_map_confidence": _food_map_confidence,
    },
    "map_rid": map_rid,
    "space_state": space,
    "eye_height": eye_h,
    "physics_tick": _physics_tick_count,
    "memory_adapter": _memory_adapter,
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": _resolve_environment_grid(),
    "traits": _traits_from_body(),
    "calorie_ratio": _calorie_ratio(),
    "delta": delta,
  }


func _resolve_main() -> Node:
  if _body != null and _body.is_inside_tree():
    var walk: Node = _body
    while walk != null:
      if walk.has_method(&"get_navigation_map_rid"):
        return walk
      walk = walk.get_parent()
    var tree := _body.get_tree()
    if tree == null:
      return null
    var root_node := tree.current_scene
    if root_node != null and root_node.has_method(&"get_navigation_map_rid"):
      return root_node
    return tree.root.get_child(0) if tree.root.get_child_count() > 0 else null
  return null


func _calorie_ratio() -> float:
  if _body == null:
    return 1.0
  var cap := maxf(1.0, float(_body.get("caloric_needs")))
  var current := float(_body.get("current_calories"))
  if _vitals != null:
    var vc: Variant = _vitals.get("current_calories")
    if typeof(vc) == TYPE_FLOAT or typeof(vc) == TYPE_INT:
      current = float(vc)
  return clampf(current / cap, 0.0, 1.0)


func _resolve_stat_observation() -> int:
  if _body == null:
    return 10
  var def_v: Variant = _body.get("definition")
  if def_v is Resource:
    var stat_v: Variant = (def_v as Resource).get("stat_observation")
    if typeof(stat_v) == TYPE_INT or typeof(stat_v) == TYPE_FLOAT:
      return maxi(10, int(stat_v))
  return 10


func _update_flight_fast_path(ctx: Dictionary) -> void:
  var panic_r := float(_motor_v3.get("flight_acute_panic_radius", 220.0))
  var acute := false
  for sample_v in ctx.get("threat_samples", []):
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    if float(sample.get("gate_dist", INF)) <= panic_r:
      acute = true
      break
  if acute:
    _flight_fast_path_latched = true
  if _flight_fast_path_latched:
    _flight_fast_path_active = not _safety_met
    if not _flight_fast_path_active:
      _flight_fast_path_latched = false
  else:
    _flight_fast_path_active = acute


func _threat_disposition_mod() -> float:
  if _memory_adapter == null:
    return _ThreatDisposition.DEFAULT_MOD
  return _memory_adapter.get_threat_disposition_mod()


func _update_threat_disposition(ctx: Dictionary) -> void:
  if _memory_adapter == null:
    _was_flight_fast_path = _flight_fast_path_active
    return
  var deltas := _ThreatDisposition.episode_deltas(
    ctx.get("threat_samples", []),
    _flight_fast_path_active,
    _was_flight_fast_path,
    _benign_episode_pending,
    _motor_v3,
  )
  _memory_adapter.apply_disposition_deltas(
    float(deltas.get("benign_delta", 0.0)),
    float(deltas.get("evade_delta", 0.0)),
    _motor_v3,
  )
  _benign_episode_pending = bool(deltas.get("benign_episode_pending", false))
  _was_flight_fast_path = _flight_fast_path_active


func _should_run_consideration() -> bool:
  return _ticks_since_consideration >= _consideration_interval


func _restart_consideration_timer() -> void:
  _ticks_since_consideration = 0


func _advance_consideration_timer() -> void:
  _ticks_since_consideration += 1


func _objective_completed_this_tick(action: int) -> bool:
  if _incumbent.is_empty() or _body == null:
    return false
  return (_MotorPlanner as GDScript).call(
    "completed_step_objective",
    _body,
    _planner_state,
    _motor_v3,
    action,
  )


func _run_consideration(ctx: Dictionary) -> void:
  ctx["now_ms"] = Time.get_ticks_msec()
  var eligible := _MotorGoalHub.build_eligible_goals(ctx)
  var enriched: Array = []
  for row_v in eligible:
    if typeof(row_v) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = (row_v as Dictionary).duplicate(true)
    row["feasibility"] = _feasibility_for_goal(row, ctx)
    enriched.append(row)
  var scored := _MotorGoalHub.score_goals(enriched, ctx)
  _active_goals = scored
  var winner := _MotorGoalHub.pick_winner(scored, _motor_v3)
  if winner.is_empty():
    _incumbent = {}
    _restart_consideration_timer()
    return
  var weight_eps := 1e-4
  if float(winner.get("weight", 0.0)) <= weight_eps:
    _incumbent = {}
    _restart_consideration_timer()
    return
  if _incumbent.get("goal_kind", &"") != winner.get("goal_kind", &""):
    _planner_state = _MotorPlanner.new_state()
  _incumbent = winner
  _restart_consideration_timer()


static func _feasibility_for_goal(row: Dictionary, ctx: Dictionary) -> float:
  var goal_kind: StringName = row.get("goal_kind", &"")
  var food_split: Dictionary = ctx.get("food_split", {})
  match goal_kind:
    _GkReg.GK_FIND_FOOD:
      var adapter: RefCounted = ctx.get("memory_adapter")
      if adapter != null:
        return adapter.best_find_food_feasibility(
          _creature_pos_from_ctx(ctx),
          ctx.get("motor_v3", {}),
          food_split,
          int(ctx.get("now_ms", Time.get_ticks_msec())),
          ctx.get("environment_grid", null),
          {},
        )
      var ready: Array = food_split.get("ready", [])
      return 1.0 if not ready.is_empty() else 0.0
    _GkReg.GK_AVOID_HOSTILES:
      var threats: Array = ctx.get("threat_samples", [])
      return 1.0 if not threats.is_empty() else 0.0
    _GkReg.GK_SHELTER:
      return 0.0
    _MotorGoalHub.GOAL_REST:
      return 1.0 if bool(ctx.get("safety_met", false)) else 0.0
    _:
      return 0.0


func _try_complete_eat() -> void:
  if _body == null:
    return
  var instance_id := int(_planner_state.get("step_instance_id", 0))
  if instance_id == 0:
    return
  var target := instance_from_id(instance_id)
  if target == null:
    return
  if target is CharacterBody3D and target != _body:
    if target.has_method(&"try_grant_as_prey_to"):
      var anchor: Vector3 = (target as CharacterBody3D).global_position
      var stimulus: StringName = _planner_state.get("step_stimulus_kind_id", &"")
      var meal := _resolve_predator_prey_meal_calories()
      if bool(target.call(&"try_grant_as_prey_to", _body)):
        notify_food_consumption_outcome(anchor, false, stimulus, meal)
        _clear_prey_engagement_planner_state()
      return
  if target.has_method(&"try_grant_engine_creature"):
    target.call(&"try_grant_engine_creature", _body)


func _clear_prey_engagement_planner_state() -> void:
  _planner_state["prey_engagement_instance_id"] = 0
  _planner_state["prey_engagement_ticks_remaining"] = 0
  _planner_state["prey_engagement_latch_total"] = 0


func _resolve_predator_prey_meal_calories() -> int:
  var meal := 5
  var gc := Engine.get_main_loop()
  if gc != null and gc.has_method(&"get_root"):
    var game_config := (gc as SceneTree).root.get_node_or_null("GameConfig")
    if game_config != null and game_config.has_method(&"get_creature_motor_params"):
      meal = int(game_config.call(&"get_creature_motor_params").get("predator_prey_meal_calories", meal))
  return meal


func _is_carnivore_body() -> bool:
  if _body == null:
    return false
  if _body.has_method(&"get_feeding_mode"):
    return int(_body.call(&"get_feeding_mode")) == _CreatureDefinition.FeedingMode.CARNIVORE
  return bool(_body.get("is_hostile"))


func _apply_gravity_if_stationary(action: int, delta: float) -> void:
  if _body == null:
    return
  match action:
    _MotorAction.STAY, _MotorAction.TURN_LEFT, _MotorAction.TURN_RIGHT, _MotorAction.REST, _MotorAction.EAT:
      if _body.has_method(&"apply_horizontal_move_intent"):
        _body.call(&"apply_horizontal_move_intent", Vector3.ZERO, delta)


func _clamp_playfield_if_needed() -> bool:
  if _body == null:
    return false
  var mode := int(_body.get("control_mode"))
  if mode != _ControlMode.engine_as_int() and mode != _ControlMode.ai_as_int():
    return false
  if _body.has_method(&"clamp_playfield_position"):
    return bool(_body.call(&"clamp_playfield_position"))
  return false


func _traits_from_body() -> Dictionary:
  var traits := {
    "explorer_builder": 0.0,
    "change_stability": 0.0,
    "compassion_self_interest": 0.0,
    "community_individual": 0.0,
  }
  if _body == null:
    return traits
  var def_v: Variant = _body.get("definition")
  if def_v is Resource:
    traits["explorer_builder"] = float((def_v as Resource).get("explorer_builder"))
    traits["change_stability"] = float((def_v as Resource).get("change_stability"))
    traits["compassion_self_interest"] = float((def_v as Resource).get("compassion_self_interest"))
    traits["community_individual"] = float((def_v as Resource).get("community_individual"))
  return traits


static func _creature_pos_from_ctx(ctx: Dictionary) -> Vector3:
  var body: CharacterBody3D = ctx.get("body")
  if body != null:
    return body.global_position
  return Vector3.ZERO


func _resolve_environment_grid() -> Variant:
  if _use_env_grid_test_override:
    return _env_grid_test_override
  var main := _resolve_main()
  if main != null and main.has_method(&"get_environment_grid"):
    return main.call(&"get_environment_grid")
  return null
