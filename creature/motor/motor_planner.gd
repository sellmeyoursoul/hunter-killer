extends RefCounted
class_name MotorPlanner
## V3 live-tier planner — turn/move toward step objectives ([CREATURE_MOVEMENT_V3.md §3 / §12.2 6c](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _AwarenessScan := preload("res://creature/motor/awareness_zone_scan.gd")
const _PathClear := preload("res://creature/motor/motor_path_clear.gd")
const _BlockedApproach := preload("res://creature/motor/blocked_approach_memory.gd")
const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")


## Fresh planner runtime state owned by [code]CreatureMotorStack[/code].
static func new_state() -> Dictionary:
  return {
    "goal_kind": &"",
    "step_goal": Vector3.ZERO,
    "step_instance_id": 0,
    "step_source": &"live",
    "blocked_approach": {},
    "consecutive_blocked": 0,
    "explore_dir": Vector3.ZERO,
    "last_outcome_blocked": false,
  }


## Picks one locomotion [MotorAction] for this physics tick.
static func select_action(ctx: Dictionary, state: Dictionary) -> int:
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  if body == null:
    return _MotorAction.STAY
  if bool(ctx.get("flight_fast_path_active", false)):
    return _select_flight_action(ctx, state)
  var incumbent: Dictionary = ctx.get("incumbent", {})
  if incumbent.is_empty():
    return _MotorAction.STAY
  var goal_kind: StringName = incumbent.get("goal_kind", &"")
  if goal_kind.is_empty():
    return _MotorAction.STAY
  _sync_step_objective(ctx, state, goal_kind)
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8:
    return _MotorAction.STAY
  if goal_kind == _GkReg.GK_FIND_FOOD and _can_eat_now(body, step_goal, state, motor_v3):
    return _MotorAction.EAT
  return _turn_or_move_toward(body, step_goal, motor_v3, state, ctx)


## Updates [param state] after [param outcome] is applied.
static func note_outcome(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
) -> void:
  var blocked := outcome != null and outcome.blocked
  state["last_outcome_blocked"] = blocked
  if blocked:
    state["consecutive_blocked"] = int(state.get("consecutive_blocked", 0)) + 1
    var approach := _BlockedApproach.infer_approach_dir(
      body.global_position,
      body.global_position,
      _MotorPlane.body_motor_velocity(body),
      [],
      _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO),
    )
    var ttl := int(motor_v3.get("blocked_approach_memory_ticks", 45))
    _BlockedApproach.record(state["blocked_approach"], approach, physics_tick, ttl)
  else:
    state["consecutive_blocked"] = 0


static func _sync_step_objective(ctx: Dictionary, state: Dictionary, goal_kind: StringName) -> void:
  if state.get("goal_kind", &"") != goal_kind:
    state["goal_kind"] = goal_kind
    state["step_goal"] = Vector3.ZERO
    state["step_instance_id"] = 0
    state["explore_dir"] = Vector3.ZERO
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  var scan: Dictionary = ctx.get("scan", {})
  var map_rid: RID = ctx.get("map_rid", RID())
  var creature_pos := body.global_position
  var agent_r := _agent_radius(body)

  match goal_kind:
    _GkReg.GK_FIND_FOOD:
      var food := _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), creature_pos)
      if not food.is_empty():
        var ultimate: Vector3 = food.get("pos", Vector3.ZERO)
        state["step_goal"] = _PathClear.resolve_step_objective(map_rid, creature_pos, ultimate, agent_r)
        state["step_instance_id"] = int(food.get("instance_id", 0))
        state["step_source"] = &"live"
        return
      if _sync_food_memory_objective(ctx, state, creature_pos, motor_v3, map_rid, agent_r):
        return
      state["step_goal"] = _explore_step_goal(creature_pos, state, motor_v3)
      state["step_instance_id"] = 0
      state["step_source"] = &"explore"
    _GkReg.GK_AVOID_HOSTILES:
      state["step_goal"] = _flee_objective(ctx, creature_pos, motor_v3)
      state["step_instance_id"] = 0
      state["step_source"] = &"live"
    _:
      state["step_goal"] = _explore_step_goal(creature_pos, state, motor_v3)
      state["step_instance_id"] = 0
      state["step_source"] = &"explore"


static func _sync_food_memory_objective(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> bool:
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return false
  var scan: Dictionary = ctx.get("scan", {})
  var food_split: Dictionary = scan.get("food_split", {})
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  var env_grid: Variant = ctx.get("environment_grid", null)
  var motor_ctx: Dictionary = {}
  var precise: Dictionary = adapter.consult_precise_food(creature_pos, motor_v3, food_split, now_ms)
  if bool(precise.get("active", false)):
    state["step_goal"] = precise.get("pos", Vector3.ZERO)
    state["step_instance_id"] = int(precise.get("instance_id", 0))
    state["step_source"] = &"precise"
    return true
  var incumbent_iid := int(state.get("step_instance_id", 0))
  var coarse: Dictionary = adapter.consult_coarse_bearing(
    creature_pos, motor_v3, food_split, incumbent_iid, now_ms
  )
  if bool(coarse.get("active", false)):
    var reach := float(motor_v3.get("awareness_radius", 150.0)) * 0.5
    var bearing: Vector3 = coarse.get("bearing", Vector3.ZERO)
    state["step_goal"] = creature_pos + bearing.normalized() * reach
    state["step_instance_id"] = int(coarse.get("instance_id", 0))
    state["step_source"] = &"coarse"
    return true
  var locale: Dictionary = adapter.consult_locale_seek(creature_pos, motor_v3, env_grid, motor_ctx)
  if bool(locale.get("active", false)):
    var anchor: Vector3 = locale.get("anchor", Vector3.ZERO)
    state["step_goal"] = _PathClear.resolve_step_objective(map_rid, creature_pos, anchor, agent_r)
    state["step_instance_id"] = 0
    state["step_source"] = &"locale"
    return true
  return false


static func _select_flight_action(ctx: Dictionary, state: Dictionary) -> int:
  state["goal_kind"] = _GkReg.GK_AVOID_HOSTILES
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  state["step_goal"] = _flee_objective(ctx, body.global_position, motor_v3)
  state["step_source"] = &"live"
  if state["step_goal"].length_squared() < 1e-8:
    return _MotorAction.STAY
  return _turn_or_move_toward(body, state["step_goal"], motor_v3, state, ctx)


static func _flee_objective(ctx: Dictionary, creature_pos: Vector3, motor_v3: Dictionary) -> Vector3:
  var threats: Array = ctx.get("threat_samples", [])
  if threats.is_empty():
    return Vector3.ZERO
  var nearest: Dictionary = {}
  var nearest_d := INF
  for sample_v in threats:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    var d := float(sample.get("gate_dist", INF))
    if d < nearest_d:
      nearest_d = d
      nearest = sample
  if nearest.is_empty():
    return Vector3.ZERO
  var threat_pos := Vector3.ZERO
  if nearest.has("world_pos_3d"):
    threat_pos = nearest["world_pos_3d"]
  else:
    var wp: Vector2 = nearest.get("world_pos", Vector2.ZERO)
    threat_pos = Vector3(wp.x, creature_pos.y, wp.y)
  var away := creature_pos - threat_pos
  away.y = 0.0
  if away.length_squared() < 1e-8:
    away = _MotorPlane.HORIZONTAL_FORWARD
  var flee_dist := float(motor_v3.get("awareness_radius", 150.0)) * 0.5
  return creature_pos + away.normalized() * flee_dist


static func _explore_step_goal(creature_pos: Vector3, state: Dictionary, motor_v3: Dictionary) -> Vector3:
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-8:
    explore = _MotorPlane.HORIZONTAL_FORWARD.rotated(Vector3.UP, randf_range(-PI, PI))
    state["explore_dir"] = explore.normalized()
  var reach := float(motor_v3.get("awareness_radius", 150.0)) * 0.5
  return creature_pos + (state["explore_dir"] as Vector3).normalized() * reach


static func _can_eat_now(
  body: CharacterBody3D,
  step_goal: Vector3,
  state: Dictionary,
  motor_v3: Dictionary,
) -> bool:
  var max_dist := float(motor_v3.get("eat_action_max_distance", 5.0))
  var dist := body.global_position.distance_to(step_goal)
  if dist > max_dist:
    return false
  if not _is_facing_aligned(body, step_goal, motor_v3):
    return false
  return int(state.get("step_instance_id", 0)) != 0


static func _turn_or_move_toward(
  body: CharacterBody3D,
  step_goal: Vector3,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> int:
  var creature_pos := body.global_position
  var to_goal := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
  if to_goal.length_squared() < 1e-8:
    return _MotorAction.STAY
  var move_dir := to_goal.normalized()
  var blocked_dir := _BlockedApproach.active_dir(
    state.get("blocked_approach", {}),
    int(ctx.get("physics_tick", 0)),
  )
  var backtrack_dot := float(motor_v3.get("blocked_approach_backtrack_dot", 0.55))
  if (
    blocked_dir.length_squared() > 1e-12
    and _BlockedApproach.is_backtrack_step(move_dir, blocked_dir, backtrack_dot)
  ):
    move_dir = move_dir.rotated(Vector3.UP, deg_to_rad(60.0))
    state["step_goal"] = creature_pos + move_dir * to_goal.length()
  if not _is_facing_aligned(body, state["step_goal"], motor_v3):
    return _pick_turn_action(body, state["step_goal"], motor_v3)
  var step_source: StringName = state.get("step_source", &"live")
  if step_source != &"precise":
    var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
    var eye_h := float(ctx.get("eye_height", 1.0))
    if not _PathClear.has_clear_los(space, creature_pos, eye_h, state["step_goal"], motor_v3):
      var map_rid: RID = ctx.get("map_rid", RID())
      var agent_r := _agent_radius(body)
      state["step_goal"] = _PathClear.resolve_step_objective(
        map_rid, creature_pos, state["step_goal"], agent_r,
      )
      if not _is_facing_aligned(body, state["step_goal"], motor_v3):
        return _pick_turn_action(body, state["step_goal"], motor_v3)
  return _MotorAction.MOVE_FORWARD


static func _is_facing_aligned(body: CharacterBody3D, target: Vector3, motor_v3: Dictionary) -> bool:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return true
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  var min_dot := cos(deg_to_rad(turn_deg * 0.5))
  return facing.dot(to_target.normalized()) >= min_dot


static func _pick_turn_action(body: CharacterBody3D, target: Vector3, _motor_v3: Dictionary) -> int:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z).normalized()
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var cross := facing.x * to_target.z - facing.z * to_target.x
  if cross >= 0.0:
    return _MotorAction.TURN_LEFT
  return _MotorAction.TURN_RIGHT


static func _agent_radius(body: CharacterBody3D) -> float:
  if body.has_method(&"get_collision_capsule_radius"):
    return maxf(0.1, float(body.call(&"get_collision_capsule_radius")))
  return 0.35
