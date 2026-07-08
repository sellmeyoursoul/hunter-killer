extends RefCounted
class_name MotorExploreSeek
## Unified explore bearing pick + waypoint mint ([CREATURE_MOVEMENT_V3.md §7.3.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _MotorPlanner := preload("res://creature/motor/motor_planner.gd")
const _AwarenessZone := preload("res://creature/motor/awareness_zone.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")

const _FORWARD_SWATCH_HALF_ANGLE_DEG := 45.0


## Mints [code]explore_dir[/code], [code]explore_waypoint[/code], [code]step_source = explore[/code]; returns [code]step_goal[/code].
static func mint_explore_step(
  goal_kind: StringName,
  creature_pos: Vector3,
  state: Dictionary,
  motor_v3: Dictionary,
  ctx: Dictionary,
) -> Vector3:
  state["step_source"] = &"explore"
  var reach := float(motor_v3.get("awareness_radius", 1500.0)) * 0.5
  var arrival_tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  var latched: Vector3 = state.get("explore_waypoint", Vector3.ZERO)
  var body: CharacterBody3D = ctx.get("body")
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)

  if latched.length_squared() > 1e-8:
    if creature_pos.distance_to(latched) <= arrival_tol:
      state["explore_waypoint"] = Vector3.ZERO
      latched = Vector3.ZERO
    elif body != null and _planner_call("_passed_explore_waypoint", [body, latched, state]):
      _planner_call("_apply_explore_waypoint_passed", [state, body, motor_v3])
      latched = Vector3.ZERO
    elif body != null and _planner_call("_explore_latch_needs_rim_realign", [body, motor_v3, state]):
      _planner_call("_apply_explore_rim_escape_replan", [state, body, motor_v3])
      latched = Vector3.ZERO
    else:
      var adapter_hold: RefCounted = ctx.get("memory_adapter")
      if adapter_hold != null and adapter_hold.has_method(&"is_waypoint_dead_end"):
        if adapter_hold.is_waypoint_dead_end(creature_pos, latched, goal_kind, motor_v3):
          _remint_explore_dir(goal_kind, creature_pos, state, motor_v3, ctx, body)
          latched = Vector3.ZERO
      if latched.length_squared() > 1e-8:
        state["step_goal"] = latched
        return latched

  if explore.length_squared() < 1e-8:
    explore = _pick_explore_dir(goal_kind, creature_pos, _spawn_facing(ctx), motor_v3, ctx)
    state["explore_dir"] = explore

  explore = (state["explore_dir"] as Vector3).normalized()
  if body != null and _planner_call("_is_near_playfield_boundary", [body, motor_v3]):
    var inward: Vector3 = _planner_call("_rim_escape_explore_dir", [body, motor_v3])
    if inward.length_squared() > 1e-12:
      explore = inward.normalized()
      state["explore_dir"] = explore

  var waypoint := creature_pos + explore * reach
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter != null and adapter.has_method(&"is_waypoint_dead_end"):
    if adapter.is_waypoint_dead_end(creature_pos, waypoint, goal_kind, motor_v3):
      _remint_explore_dir(goal_kind, creature_pos, state, motor_v3, ctx, body)
      explore = (state["explore_dir"] as Vector3).normalized()
      waypoint = creature_pos + explore * reach
  state["explore_waypoint"] = waypoint
  state["step_goal"] = waypoint
  return waypoint


## Scored bearing rays — remint only ([CREATURE_MOVEMENT_V3.md §7.3.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
static func _pick_explore_dir(
  goal_kind: StringName,
  creature_pos: Vector3,
  spawn_facing: Vector3,
  motor_v3: Dictionary,
  ctx: Dictionary,
) -> Vector3:
  var bearing_count := maxi(1, int(motor_v3.get("explore_bearing_count", 8)))
  var w_spawn := float(motor_v3.get("explore_w_spawn", 0.35))
  var w_open := float(motor_v3.get("explore_w_open", 0.30))
  var w_unexp := float(motor_v3.get("explore_w_unexp", 0.25))
  var w_forward := float(motor_v3.get("explore_w_forward", 0.10))
  var chaos := clampf(float(motor_v3.get("goal_consideration_chaos", 0.15)), 0.0, 1.0)
  var baseline := float(motor_v3.get("explore_empty_map_unexplored_baseline", 0.5))
  var spawn_u := spawn_facing
  if spawn_u.length_squared() < 1e-12:
    spawn_u = _MotorPlane.HORIZONTAL_FORWARD
  else:
    spawn_u = spawn_u.normalized()

  var coverage := _coverage_for_goal(goal_kind, creature_pos, motor_v3, ctx, bearing_count)
  var max_cov := 0.0
  for i in coverage.size():
    max_cov = maxf(max_cov, coverage[i])
  var empty_map := max_cov < 1e-8

  var forward_swatch := _forward_unexplored_swatch_values(
    coverage, bearing_count, spawn_u, empty_map, baseline, max_cov
  )

  var best_dir := spawn_u
  var best_score := -INF
  for i in bearing_count:
    var dir := _wedge_center_dir(i, bearing_count)
    var spawn_term := dir.dot(spawn_u)
    var open_term := _nav_clearance(creature_pos, dir, motor_v3, ctx)
    var unexp := _unexplored_for_wedge(i, coverage, empty_map, baseline, max_cov)
    var forward_term := forward_swatch[i] if i < forward_swatch.size() else 0.0
    var score := (
      w_spawn * spawn_term
      + w_open * open_term
      + w_unexp * unexp
      + w_forward * forward_term
    )
    if chaos > 0.0:
      score += randf_range(-chaos, chaos)
    if score > best_score:
      best_score = score
      best_dir = dir
  if best_dir.length_squared() < 1e-12:
    return _MotorPlane.HORIZONTAL_FORWARD
  return best_dir.normalized()


static func _remint_explore_dir(
  goal_kind: StringName,
  creature_pos: Vector3,
  state: Dictionary,
  motor_v3: Dictionary,
  ctx: Dictionary,
  body: CharacterBody3D,
) -> void:
  if body != null and _planner_call("_is_near_playfield_boundary", [body, motor_v3]):
    state["explore_dir"] = _planner_call("_rim_escape_explore_dir", [body, motor_v3])
  else:
    state["explore_dir"] = _pick_explore_dir(
      goal_kind, creature_pos, _spawn_facing(ctx), motor_v3, ctx
    )
  state["explore_waypoint"] = Vector3.ZERO


static func _spawn_facing(ctx: Dictionary) -> Vector3:
  var body: CharacterBody3D = ctx.get("body")
  if body != null:
    var facing := _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO)
    if facing.length_squared() > 1e-12:
      return facing.normalized()
  return _MotorPlane.HORIZONTAL_FORWARD


static func _coverage_for_goal(
  goal_kind: StringName,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  ctx: Dictionary,
  bearing_count: int,
) -> PackedFloat32Array:
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null or not adapter.has_method(&"explore_bearing_coverage"):
    var empty := PackedFloat32Array()
    empty.resize(bearing_count)
    return empty
  var scan: Dictionary = ctx.get("scan", {})
  if typeof(scan) != TYPE_DICTIONARY:
    scan = {}
  var food_split: Dictionary = scan.get("food_split", ctx.get("food_split", {}))
  var threat_samples: Array = scan.get("threat_samples", ctx.get("threat_samples", []))
  var zone_ctx: Dictionary = ctx.get("zone_ctx", {})
  if zone_ctx.is_empty():
    zone_ctx = _build_zone_ctx(ctx)
  return adapter.explore_bearing_coverage(
    goal_kind,
    creature_pos,
    motor_v3,
    food_split,
    int(ctx.get("now_ms", Time.get_ticks_msec())),
    zone_ctx,
    threat_samples,
  )


static func _build_zone_ctx(ctx: Dictionary) -> Dictionary:
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  var creature_pos := body.global_position if body != null else Vector3.ZERO
  var facing: Vector3 = _spawn_facing(ctx)
  var eye_h := float(ctx.get("eye_height", 1.0))
  var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
  if body != null and body.is_inside_tree() and space == null:
    space = body.get_world_3d().direct_space_state
    if body.has_method(&"get_los_eye_height"):
      eye_h = float(body.call(&"get_los_eye_height"))
  return {
    "creature_pos": creature_pos,
    "facing": facing,
    "eye_height": eye_h,
    "space_state": space,
    "motor_v3": motor_v3,
    "area_only": false,
  }


static func _wedge_center_dir(wedge_index: int, wedge_count: int) -> Vector3:
  var angle := TAU * (float(wedge_index) + 0.5) / float(wedge_count)
  return Vector3(sin(angle), 0.0, -cos(angle))


static func _nav_clearance(
  creature_pos: Vector3,
  dir: Vector3,
  motor_v3: Dictionary,
  ctx: Dictionary,
) -> float:
  if dir.length_squared() < 1e-12:
    return 0.0
  var probe_dist := float(motor_v3.get("awareness_radius", 1500.0)) * 0.5
  var target := creature_pos + dir.normalized() * probe_dist
  var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
  var eye_h := float(ctx.get("eye_height", 1.0))
  if space == null:
    return 1.0
  var los := _AwarenessZone.line_of_sight_clear(
    space, creature_pos, eye_h, target, motor_v3,
  )
  if bool(los.get("line_of_sight_clear", false)):
    return 1.0
  var frac := float(los.get("occlusion_fraction", 1.0))
  return clampf(1.0 - frac, 0.0, 1.0)


static func _unexplored_for_wedge(
  wedge_index: int,
  coverage: PackedFloat32Array,
  empty_map: bool,
  baseline: float,
  max_cov: float,
) -> float:
  if wedge_index < 0 or wedge_index >= coverage.size():
    return baseline if empty_map else 0.0
  if empty_map:
    return baseline
  if max_cov < 1e-8:
    return baseline
  return clampf(1.0 - coverage[wedge_index] / max_cov, 0.0, 1.0)


static func _forward_unexplored_swatch_values(
  coverage: PackedFloat32Array,
  bearing_count: int,
  spawn_u: Vector3,
  empty_map: bool,
  baseline: float,
  max_cov: float,
) -> PackedFloat32Array:
  var out := PackedFloat32Array()
  out.resize(bearing_count)
  var cos_half := cos(deg_to_rad(_FORWARD_SWATCH_HALF_ANGLE_DEG))
  var swatch_sum := 0.0
  var swatch_n := 0
  for i in bearing_count:
    var wedge_dir := _wedge_center_dir(i, bearing_count)
    if wedge_dir.dot(spawn_u) >= cos_half:
      swatch_sum += _unexplored_for_wedge(i, coverage, empty_map, baseline, max_cov)
      swatch_n += 1
  var swatch_avg := swatch_sum / float(maxi(1, swatch_n))
  for i in bearing_count:
    var dir := _wedge_center_dir(i, bearing_count)
    out[i] = swatch_avg if dir.dot(spawn_u) >= cos_half else 0.0
  return out


static func _planner_call(method: StringName, args: Array) -> Variant:
  return Callable(_MotorPlanner, method).callv(args)
