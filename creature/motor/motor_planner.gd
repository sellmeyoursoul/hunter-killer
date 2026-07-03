extends RefCounted
class_name MotorPlanner
## V3 live-tier planner — turn/move toward step objectives ([CREATURE_MOVEMENT_V3.md §3 / §12.2 6c](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _AwarenessScan := preload("res://creature/motor/awareness_zone_scan.gd")
const _PathClear := preload("res://creature/motor/motor_path_clear.gd")
const _BlockedApproach := preload("res://creature/motor/blocked_approach_memory.gd")
const _BlockedObjective := preload("res://creature/motor/blocked_objective_resolver.gd")
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
    "explore_waypoint": Vector3.ZERO,
    "last_outcome_blocked": false,
    "step_stimulus_kind_id": &"",
    "blocked_objective_action": &"",
    "turn_commit_sign": 0,
    "turn_commit_bearing_deg": null,
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
  if _at_arrival(body, step_goal, motor_v3):
    return _MotorAction.STAY
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
    var pos_after := body.global_position
    var disp := outcome.displacement if outcome != null else Vector3.ZERO
    disp.y = 0.0
    var pos_before := pos_after - disp
    var approach := _BlockedApproach.infer_approach_dir(
      pos_after,
      pos_before,
      _MotorPlane.body_motor_velocity(body),
      [],
      _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO),
    )
    var ttl := int(motor_v3.get("blocked_approach_memory_ticks", 45))
    _BlockedApproach.record(state["blocked_approach"], approach, physics_tick, ttl)
    if state.get("step_source", &"") == &"explore":
      state["explore_waypoint"] = Vector3.ZERO
  else:
    state["consecutive_blocked"] = 0


static func _sync_step_objective(ctx: Dictionary, state: Dictionary, goal_kind: StringName) -> void:
  if state.get("goal_kind", &"") != goal_kind:
    state["goal_kind"] = goal_kind
    state["step_goal"] = Vector3.ZERO
    state["step_instance_id"] = 0
    state["explore_dir"] = Vector3.ZERO
    state["explore_waypoint"] = Vector3.ZERO
    state["turn_commit_sign"] = 0
    state["turn_commit_bearing_deg"] = null
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
        state["step_stimulus_kind_id"] = food.get("stimulus_kind_id", &"")
        state["step_source"] = &"live"
        return
      if _sync_food_memory_objective(ctx, state, creature_pos, motor_v3, map_rid, agent_r):
        return
      state["step_goal"] = _explore_step_goal(creature_pos, state, motor_v3, ctx)
      state["step_instance_id"] = 0
      state["step_source"] = &"explore"
    _GkReg.GK_AVOID_HOSTILES:
      state["step_goal"] = _flee_objective(ctx, creature_pos, motor_v3)
      state["step_instance_id"] = 0
      state["step_source"] = &"live"
    _:
      state["step_goal"] = _explore_step_goal(creature_pos, state, motor_v3, ctx)
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
    state["step_stimulus_kind_id"] = precise.get("stimulus_kind_id", &"")
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


static func _explore_step_goal(creature_pos: Vector3, state: Dictionary, motor_v3: Dictionary, ctx: Dictionary) -> Vector3:
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-8:
    explore = _initial_explore_dir(ctx)
    state["explore_dir"] = explore.normalized()
  var reach := float(motor_v3.get("awareness_radius", 150.0)) * 0.5
  var arrival_tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  var latched: Vector3 = state.get("explore_waypoint", Vector3.ZERO)
  if latched.length_squared() > 1e-8:
    if creature_pos.distance_to(latched) <= arrival_tol:
      state["explore_waypoint"] = Vector3.ZERO
      latched = Vector3.ZERO
    else:
      var adapter_hold: RefCounted = ctx.get("memory_adapter")
      if adapter_hold != null and adapter_hold.has_method(&"is_waypoint_dead_end"):
        if adapter_hold.is_waypoint_dead_end(creature_pos, latched, _GkReg.GK_FIND_FOOD, motor_v3):
          explore = explore.rotated(Vector3.UP, deg_to_rad(60.0))
          state["explore_dir"] = explore.normalized()
          state["explore_waypoint"] = Vector3.ZERO
          latched = Vector3.ZERO
      if latched.length_squared() > 1e-8:
        return latched
  var waypoint := creature_pos + (state["explore_dir"] as Vector3).normalized() * reach
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter != null and adapter.has_method(&"is_waypoint_dead_end"):
    if adapter.is_waypoint_dead_end(creature_pos, waypoint, _GkReg.GK_FIND_FOOD, motor_v3):
      explore = explore.rotated(Vector3.UP, deg_to_rad(60.0))
      state["explore_dir"] = explore.normalized()
      waypoint = creature_pos + state["explore_dir"] * reach
  state["explore_waypoint"] = waypoint
  return waypoint


## Horizontal facing at first explore pick — duel spawn facing, not random (§3 explore latch).
static func _initial_explore_dir(ctx: Dictionary) -> Vector3:
  var body: CharacterBody3D = ctx.get("body")
  if body != null:
    var facing := _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO)
    if facing.length_squared() > 1e-12:
      return facing.normalized()
  return _MotorPlane.HORIZONTAL_FORWARD


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
  if not _is_facing_aligned_for_eat(body, step_goal, motor_v3):
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
  var step_source: StringName = state.get("step_source", &"live")
  # Fixed GPS / latched explore: no backtrack detour rewrite (§7.3 / §8.2).
  if not _is_latched_step_source(step_source):
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
  if not _is_facing_aligned_for_move(body, state["step_goal"], motor_v3):
    return _pick_turn_action(body, state["step_goal"], motor_v3, state)
  if not _is_latched_step_source(step_source):
    var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
    var eye_h := float(ctx.get("eye_height", 1.0))
    if not _PathClear.has_clear_los(space, creature_pos, eye_h, state["step_goal"], motor_v3):
      var map_rid: RID = ctx.get("map_rid", RID())
      var agent_r := _agent_radius(body)
      state["step_goal"] = _PathClear.resolve_step_objective(
        map_rid, creature_pos, state["step_goal"], agent_r,
      )
      if not _is_facing_aligned_for_move(body, state["step_goal"], motor_v3):
        return _pick_turn_action(body, state["step_goal"], motor_v3, state)
  state["turn_commit_sign"] = 0
  state["turn_commit_bearing_deg"] = null
  return _MotorAction.MOVE_FORWARD


static func _is_facing_aligned_with_tolerance(
  body: CharacterBody3D,
  target: Vector3,
  motor_v3: Dictionary,
  tolerance_multiplier: float,
) -> bool:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return true
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  var min_dot := cos(deg_to_rad(turn_deg * tolerance_multiplier))
  return facing.dot(to_target.normalized()) >= min_dot


static func _is_facing_aligned_for_eat(body: CharacterBody3D, target: Vector3, motor_v3: Dictionary) -> bool:
  return _is_facing_aligned_with_tolerance(body, target, motor_v3, 0.5)


static func _is_facing_aligned_for_move(body: CharacterBody3D, target: Vector3, motor_v3: Dictionary) -> bool:
  # One full turn increment: a single atomic turn can overshoot the half-increment EAT cone.
  return _is_facing_aligned_with_tolerance(body, target, motor_v3, 1.0)


static func _facing_dot_to_target(body: CharacterBody3D, target: Vector3) -> float:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return 1.0
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  return clampf(facing.dot(to_target.normalized()), -1.0, 1.0)


static func _move_alignment_min_dot(motor_v3: Dictionary) -> float:
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  return cos(deg_to_rad(turn_deg))


static func _signed_bearing_error_deg(body: CharacterBody3D, target: Vector3) -> float:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return 0.0
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var to_n := to_target.normalized()
  var cross := facing.x * to_n.z - facing.z * to_n.x
  var dot := clampf(facing.dot(to_n), -1.0, 1.0)
  return rad_to_deg(atan2(cross, dot))


static func _flat_bearing_deg(from_pos: Vector3, to_pos: Vector3) -> float:
  var d := Vector3(to_pos.x - from_pos.x, 0.0, to_pos.z - from_pos.z)
  if d.length_squared() < 1e-8:
    return 0.0
  return rad_to_deg(atan2(d.x, d.z))


static func _angle_delta_deg(a: float, b: float) -> float:
  return fmod(a - b + 540.0, 360.0) - 180.0


static func _pick_turn_action(
  body: CharacterBody3D,
  target: Vector3,
  motor_v3: Dictionary,
  state: Dictionary,
) -> int:
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  var creature_pos := body.global_position
  var bearing_deg := _flat_bearing_deg(creature_pos, target)
  var step_source: StringName = state.get("step_source", &"live")
  var stored_bearing: Variant = state.get("turn_commit_bearing_deg", null)
  # Flight/flee retargets each tick; latched precise/explore keep commit until MOVE cone (§7.3).
  if (
    stored_bearing != null
    and not _is_latched_step_source(step_source)
    and absf(_angle_delta_deg(bearing_deg, stored_bearing)) > turn_deg
  ):
    state["turn_commit_sign"] = 0
  var move_min_dot := _move_alignment_min_dot(motor_v3)
  var facing_dot := _facing_dot_to_target(body, target)
  var commit := int(state.get("turn_commit_sign", 0))
  if commit != 0:
    # Hold committed turn until MOVE alignment — ignore atan2 sign flips near ±180°.
    if facing_dot >= move_min_dot:
      state["turn_commit_sign"] = 0
      state["turn_commit_bearing_deg"] = null
      return _MotorAction.MOVE_FORWARD
    return _MotorAction.TURN_LEFT if commit > 0 else _MotorAction.TURN_RIGHT
  var error_deg := _signed_bearing_error_deg(body, target)
  var new_commit := 1 if error_deg >= 0.0 else -1
  state["turn_commit_sign"] = new_commit
  state["turn_commit_bearing_deg"] = bearing_deg
  return _MotorAction.TURN_LEFT if new_commit > 0 else _MotorAction.TURN_RIGHT


## True for step sources that hold a stable world objective (no per-tick LoS/nav/backtrack rewrite).
static func _is_latched_step_source(step_source: StringName) -> bool:
  return step_source == &"precise" or step_source == &"explore"


static func _agent_radius(body: CharacterBody3D) -> float:
  if body.has_method(&"get_collision_capsule_radius"):
    return maxf(0.1, float(body.call(&"get_collision_capsule_radius")))
  return 0.35


static func _at_arrival(body: CharacterBody3D, step_goal: Vector3, motor_v3: Dictionary) -> bool:
  var tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  return body.global_position.distance_to(step_goal) <= tol


## Applies §9 persist/switch/seek after blocked locomotion; mutates [param state] step fields.
static func apply_blocked_objective_resolution(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
  if int(state.get("consecutive_blocked", 0)) < min_ticks:
    return
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return
  var iid := int(state.get("step_instance_id", 0))
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  if iid != 0 and adapter.has_method(&"increment_passibility_fail"):
    adapter.increment_passibility_fail(iid, now_ms)
  var approach := _BlockedApproach.active_dir(
    state.get("blocked_approach", {}),
    int(ctx.get("physics_tick", 0)),
  )
  if approach.length_squared() > 1e-8 and adapter.has_method(&"record_dead_end_mark"):
    adapter.record_dead_end_mark(
      body.global_position,
      approach,
      state.get("goal_kind", _GkReg.GK_FIND_FOOD),
      iid,
      now_ms,
    )
  var blocked_ctx := ctx.duplicate(true)
  blocked_ctx["creature_pos"] = body.global_position
  var resolution := _BlockedObjective.resolve(
    blocked_ctx,
    iid,
    state.get("step_stimulus_kind_id", &""),
    motor_v3,
  )
  state["blocked_objective_action"] = resolution.get("action", &"persist")
  match resolution.get("action", &"persist"):
    _BlockedObjective.ACTION_SWITCH:
      state["explore_dir"] = Vector3.ZERO
      state["explore_waypoint"] = Vector3.ZERO
      state["step_goal"] = Vector3.ZERO
    _BlockedObjective.ACTION_SEEK:
      state["explore_dir"] = Vector3.ZERO
      state["explore_waypoint"] = Vector3.ZERO
      state["step_goal"] = Vector3.ZERO
      state["step_instance_id"] = 0
      state["step_source"] = &"explore"
    _:
      pass
