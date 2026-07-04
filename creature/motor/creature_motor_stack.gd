extends RefCounted
class_name CreatureMotorStack
## Per-creature V3 motor runtime — hub + cadence + planner + execution ([CREATURE_MOVEMENT_V3.md §1 / §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")
const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _LocomotionExecutor := preload("res://creature/motor/locomotion_executor.gd")
const _MotorGoalHub := preload("res://creature/motor/motor_goal_hub.gd")
const _MotorCadence := preload("res://creature/motor/motor_consideration_cadence.gd")
const _MotorPlanner := preload("res://creature/motor/motor_planner.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _AwarenessScan := preload("res://creature/motor/awareness_zone_scan.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _MemoryAdapter := preload("res://creature/motor/memory_adapter.gd")


var _body: CharacterBody3D
var _vitals: Node
var _motor_v3: Dictionary = {}
var _pack_root: String = ""
var _goal_catalog: Dictionary = {}

var _physics_tick_count: int = 0
var _consideration_interval: int = 8
var _active_goals: Array = []
var _incumbent: Dictionary = {}
var _flight_fast_path_active: bool = false
var _safety_met: bool = false
var _threat_samples: Array = []
var _food_split: Dictionary = {"ready": [], "unready": []}
var _food_map_confidence: float = 0.0
var _stat_observation: int = 10
var _planner_state: Dictionary = {}
var _threat_samples_test_override: bool = false
var _scan_test_override: Dictionary = {}
var _use_scan_test_override: bool = false
var _env_grid_test_override: Variant = null
var _use_env_grid_test_override: bool = false
var _memory_adapter: _MemoryAdapter
var _last_outcome: _ActionOutcome


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
  _active_goals = []
  _incumbent = {}
  _flight_fast_path_active = false
  _planner_state = _MotorPlanner.new_state()
  _threat_samples_test_override = false
  _use_scan_test_override = false
  _scan_test_override = {}
  if _memory_adapter == null:
    _memory_adapter = _MemoryAdapter.new()
  _memory_adapter.configure(_pack_root, _traits_from_body())
  _memory_adapter.set_goal_catalog(_goal_catalog)


## One physics tick: awareness scan, consideration cadence, planner action, execution.
func tick(delta: float) -> _ActionOutcome:
  _physics_tick_count += 1
  _run_live_scan()
  _maintain_memory_beliefs()
  var ctx := _build_context()
  _update_flight_fast_path_stub(ctx)
  ctx["flight_fast_path_active"] = _flight_fast_path_active

  if _should_run_consideration():
    _run_consideration(ctx)

  var planner_ctx := _build_planner_context(ctx, delta)
  var pos_before_tick := _body.global_position
  var action := _MotorPlanner.select_action(planner_ctx, _planner_state)
  var outcome: _ActionOutcome = _LocomotionExecutor.apply_action(_body, action, delta, _motor_v3)
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
  )
  _last_outcome = outcome
  if int(outcome.action) == _MotorAction.EAT:
    _try_complete_eat()
  if outcome != null and not outcome.blocked and int(outcome.action) == _MotorAction.MOVE_FORWARD:
    if _memory_adapter != null:
      _memory_adapter.clear_dead_end_near(_body.global_position, _motor_v3)
  elif run_blocked_resolution:
    var blocked_ctx := _build_planner_context(ctx, delta)
    _MotorPlanner.apply_blocked_objective_resolution(
      blocked_ctx, _planner_state, _body, _motor_v3
    )
  _apply_gravity_if_stationary(action, delta)
  return outcome


func get_physics_tick_count() -> int:
  return _physics_tick_count


func get_consideration_interval() -> int:
  return _consideration_interval


func get_active_goals() -> Array:
  return _active_goals.duplicate(true)


func get_incumbent() -> Dictionary:
  return _incumbent.duplicate(true)


func is_flight_fast_path_active() -> bool:
  return _flight_fast_path_active


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
  var bearing := {"bearing_error_deg": 0.0, "facing_dot_tgt": 0.0}
  if _body != null and step_goal.length_squared() > 1e-8:
    var creature_pos := _body.global_position
    var to_target := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
    var facing := _MotorPlane.read_dir(_body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
    var to_n := to_target.normalized()
    var cross := facing.x * to_n.z - facing.z * to_n.x
    var dot := clampf(facing.dot(to_n), -1.0, 1.0)
    bearing["bearing_error_deg"] = rad_to_deg(atan2(cross, dot))
    bearing["facing_dot_tgt"] = facing.dot(to_n)
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
    "turn_commit_sign": int(ps.get("turn_commit_sign", 0)),
    "boundary_scan_active": bool(ps.get("boundary_scan_active", false)),
    "bearing_error_deg": float(bearing.get("bearing_error_deg", 0.0)),
    "facing_dot_tgt": float(bearing.get("facing_dot_tgt", 0.0)),
    "physics_tick": _physics_tick_count,
    "consideration_interval": _consideration_interval,
    "flight_fast_path": _flight_fast_path_active,
    "ready_food": ready.size(),
    "threat_count": _threat_samples.size(),
    "incumbent_empty": _incumbent.is_empty(),
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
  _threat_samples = samples.duplicate(true)
  _threat_samples_test_override = true


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
  if not _threat_samples_test_override:
    _threat_samples = scan.get("threat_samples", []).duplicate(true)


func _apply_scan_dict(scan: Dictionary) -> void:
  var split: Variant = scan.get("food_split", {})
  if typeof(split) == TYPE_DICTIONARY:
    _food_split = (split as Dictionary).duplicate(true)
  if _memory_adapter != null:
    _food_split = _memory_adapter.enrich_food_split_with_kind_yield(_food_split, _motor_v3)
  if scan.has("food_map_confidence"):
    _food_map_confidence = float(scan.get("food_map_confidence", _food_map_confidence))
  if scan.has("threat_samples") and not _threat_samples_test_override:
    _threat_samples = scan.get("threat_samples", []).duplicate(true)
  if _memory_adapter != null:
    _memory_adapter.sync_after_scan(_food_split, _threat_samples, Time.get_ticks_msec())


func _maintain_memory_beliefs() -> void:
  if _memory_adapter == null or _body == null:
    return
  _memory_adapter.maintain_beliefs(_body.global_position, Time.get_ticks_msec(), _motor_v3)


func _rest_area_only_perception() -> bool:
  return false


func _build_context() -> Dictionary:
  return {
    "body": _body,
    "motor_v3": _motor_v3,
    "calorie_ratio": _calorie_ratio(),
    "threat_samples": _threat_samples,
    "flight_fast_path_active": _flight_fast_path_active,
    "safety_met": _safety_met,
    "food_map_confidence": _food_map_confidence,
    "pack_root": _pack_root,
    "goal_catalog": _goal_catalog,
    "food_split": _food_split,
    "memory_adapter": _memory_adapter,
    "environment_grid": _resolve_environment_grid(),
  }


func _build_planner_context(hub_ctx: Dictionary, _delta: float) -> Dictionary:
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
  }


func _resolve_main() -> Node:
  if _body == null or not _body.is_inside_tree():
    return null
  var tree := _body.get_tree()
  if tree == null:
    return null
  var root_node := tree.current_scene
  if root_node != null and root_node.has_method(&"get_navigation_map_rid"):
    return root_node
  return tree.root.get_child(0) if tree.root.get_child_count() > 0 else null


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


func _update_flight_fast_path_stub(ctx: Dictionary) -> void:
  var panic_r := float(_motor_v3.get("flight_acute_panic_radius", 220.0))
  _flight_fast_path_active = false
  for sample_v in ctx.get("threat_samples", []):
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    if float(sample.get("gate_dist", INF)) <= panic_r:
      _flight_fast_path_active = true
      return


func _should_run_consideration() -> bool:
  if _physics_tick_count == 1:
    return true
  return _physics_tick_count % _consideration_interval == 0


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
    return
  var weight_eps := 1e-4
  if float(winner.get("weight", 0.0)) <= weight_eps:
    _incumbent = {}
    return
  if _incumbent.get("goal_kind", &"") != winner.get("goal_kind", &""):
    _planner_state = _MotorPlanner.new_state()
  _incumbent = winner


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
  var plant := instance_from_id(instance_id)
  if plant == null:
    return
  if plant.has_method(&"try_grant_engine_creature"):
    plant.call(&"try_grant_engine_creature", _body)


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
