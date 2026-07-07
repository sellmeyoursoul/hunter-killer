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
const _LocomotionExecutor := preload("res://creature/motor/locomotion_executor.gd")

## V2 reference: ~400 px/s at 60 Hz — [code]motor_stuck_move_epsilon[/code] 1.25 ≈ 18.75% of that per-tick budget.
const _LEGACY_REF_TICK_DISPLACEMENT := 400.0 / 60.0


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
    "boundary_scan_active": false,
    "boundary_scan_sign": 0,
    "boundary_scan_turns": 0,
    "boundary_scan_egress_ticks": 0,
    "precise_no_progress_ticks": 0,
    "precise_last_bearing_err_deg": INF,
    "precise_last_dist_sq": INF,
    "explore_no_progress_ticks": 0,
    "explore_last_facing_dot": -2.0,
    "playfield_clamp_latch_ticks": 0,
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
  if bool(state.get("boundary_scan_active", false)) and state.get("step_source") == &"explore":
    return _boundary_scan_action(body, motor_v3, state)
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8:
    return _MotorAction.STAY
  if goal_kind == _GkReg.GK_FIND_FOOD and _can_eat_now(body, step_goal, state, motor_v3):
    return _MotorAction.EAT
  if _at_arrival(body, step_goal, motor_v3):
    return _MotorAction.STAY
  return _locomote_toward_step_goal(body, motor_v3, state, ctx)


## True for step sources that hold a stable world objective (no per-tick LoS/nav/backtrack rewrite).
static func _is_latched_step_source(step_source: StringName) -> bool:
  return step_source == &"precise" or step_source == &"explore"


## Minimum per-tick displacement that counts as progress (scales with body speed × delta).
static func _latched_stuck_move_epsilon(
  motor_v3: Dictionary,
  body: CharacterBody3D,
  delta: float,
) -> float:
  var config := maxf(0.01, float(motor_v3.get("motor_stuck_move_epsilon", 1.25)))
  if body == null:
    return config
  var max_spd := _LocomotionExecutor._expected_horizontal_speed(body)
  var dt := maxf(delta, 1.0 / 120.0)
  var expected_per_tick := max_spd * dt
  var frac := config / _LEGACY_REF_TICK_DISPLACEMENT
  return maxf(0.01, expected_per_tick * frac)


static func _tick_had_meaningful_progress(
  body: CharacterBody3D,
  step_goal: Vector3,
  tick_disp: Vector3,
  act: int,
  _motor_v3: Dictionary,
  stuck_eps: float,
) -> bool:
  if act != _MotorAction.MOVE_FORWARD:
    return false
  if tick_disp.length_squared() < stuck_eps * stuck_eps:
    return false
  var creature_pos := body.global_position
  var to_goal := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
  if to_goal.length_squared() < 1e-8:
    return tick_disp.length_squared() >= stuck_eps * stuck_eps
  return tick_disp.dot(to_goal.normalized()) >= stuck_eps * 0.5


## Rotate explore bearing and clear latch after sustained stuck (interior / no progress).
static func _apply_explore_stuck_replan(state: Dictionary) -> void:
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-8:
    explore = _MotorPlane.HORIZONTAL_FORWARD
  state["explore_dir"] = explore.rotated(Vector3.UP, deg_to_rad(60.0)).normalized()
  state["explore_waypoint"] = Vector3.ZERO
  state["step_goal"] = Vector3.ZERO
  state["consecutive_blocked"] = 0
  _reset_explore_align_progress_state(state)


## Rim hug band: inward replan; interior: 60° stuck replan.
static func _apply_explore_stuck_or_rim_replan(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  if body != null and _is_near_playfield_boundary(body, motor_v3):
    _apply_explore_rim_escape_replan(state, body, motor_v3)
  else:
    _apply_explore_stuck_replan(state)
  state["blocked_objective_action"] = &"explore_replan"


## True when the creature has moved past [param latched] along latched [code]explore_dir[/code].
static func _passed_explore_waypoint(
  body: CharacterBody3D,
  latched: Vector3,
  state: Dictionary,
) -> bool:
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-12:
    return _facing_dot_to_target(body, latched) < 0.0
  explore = explore.normalized()
  var travel := body.global_position - latched
  travel.y = 0.0
  if travel.length_squared() < 1e-12:
    return true
  return travel.dot(explore) > 0.0


## Drop overshot explore latch; rim overshoot routes inward, interior rotates 60°.
static func _apply_explore_waypoint_passed(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  _apply_explore_stuck_or_rim_replan(state, body, motor_v3)


## Resets explore fields after §9 seek fallback so the next sync can mint a waypoint.
static func _seed_explore_after_seek(state: Dictionary, ctx: Dictionary) -> void:
  state["explore_dir"] = _initial_explore_dir(ctx)
  state["explore_waypoint"] = Vector3.ZERO
  state["step_goal"] = Vector3.ZERO
  state["step_instance_id"] = 0
  state["step_source"] = &"explore"
  state["consecutive_blocked"] = 0
  _reset_explore_align_progress_state(state)


static func _reset_explore_align_progress_state(state: Dictionary) -> void:
  state["explore_no_progress_ticks"] = 0
  state["explore_last_facing_dot"] = -2.0


static func _note_explore_align_progress(
  state: Dictionary,
  body: CharacterBody3D,
  step_goal: Vector3,
  explore_idle_stuck: bool,
) -> void:
  if step_goal.length_squared() < 1e-8:
    return
  var dot := _facing_dot_to_target(body, step_goal)
  var last_dot := float(state.get("explore_last_facing_dot", -2.0))
  if last_dot <= -1.5:
    state["explore_last_facing_dot"] = dot
    return
  if dot < 0.0:
    if explore_idle_stuck:
      state["explore_no_progress_ticks"] = int(state.get("explore_no_progress_ticks", 0)) + 1
  elif dot > last_dot + 0.01:
    state["explore_no_progress_ticks"] = 0
  elif explore_idle_stuck:
    state["explore_no_progress_ticks"] = int(state.get("explore_no_progress_ticks", 0)) + 1
  state["explore_last_facing_dot"] = dot


static func _playfield_hug_band(motor_v3: Dictionary) -> float:
  return maxf(4.0, float(motor_v3.get("playfield_hug_band", 14.0)))


static func _playfield_hug_info(body: CharacterBody3D, motor_v3: Dictionary) -> Dictionary:
  return _MotorPlane.playfield_boundary_hug(body, motor_v3, _playfield_hug_band(motor_v3))


static func _is_near_playfield_boundary(body: CharacterBody3D, motor_v3: Dictionary) -> bool:
  return bool(_playfield_hug_info(body, motor_v3).get("near", false))


## Footprint within fixed world margin of playfield edge (clamp ground truth; not scaled hug band).
static func _is_at_playfield_rim(body: CharacterBody3D, motor_v3: Dictionary) -> bool:
  var rim_margin := maxf(0.5, float(motor_v3.get("playfield_rim_margin", 2.0)))
  return bool(_MotorPlane.playfield_boundary_hug(body, motor_v3, rim_margin).get("near", false))


## True when post-scan egress may end after a forward step (creature left the tight rim band).
static func _rim_egress_move_cleared(body: CharacterBody3D, motor_v3: Dictionary) -> bool:
  return not _is_at_playfield_rim(body, motor_v3)


static func _playfield_clamp_latch_ttl(motor_v3: Dictionary) -> int:
  var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
  return min_ticks + _boundary_scan_turn_budget(motor_v3)


static func _should_explore_boundary_scan(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  boundary_clamped: bool,
) -> bool:
  if boundary_clamped:
    return true
  if int(state.get("playfield_clamp_latch_ticks", 0)) > 0:
    return true
  if _is_at_playfield_rim(body, motor_v3):
    return true
  return _is_near_playfield_boundary(body, motor_v3)


static func _boundary_scan_turn_budget(motor_v3: Dictionary) -> int:
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  if turn_deg <= 0.0:
    return 16
  return maxi(1, int(ceil(360.0 / turn_deg)))


## Horizontal bearing toward playfield interior after rim boundary scan (inbound normal, not rim tangent).
## True when a latched explore bearing at the rim is tangent/outward vs playfield inbound.
static func _explore_latch_needs_rim_realign(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
) -> bool:
  if body == null or not _is_near_playfield_boundary(body, motor_v3):
    return false
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-12:
    return true
  var inward := _rim_escape_explore_dir(body, motor_v3)
  if inward.length_squared() < 1e-12:
    return false
  return explore.normalized().dot(inward.normalized()) < _move_alignment_min_dot(motor_v3)


static func _rim_escape_explore_dir(body: CharacterBody3D, motor_v3: Dictionary) -> Vector3:
  var hug := _playfield_hug_info(body, motor_v3)
  var inbound: Vector3 = hug.get("inbound_normal", Vector3.ZERO)
  if inbound.length_squared() > 1e-12:
    return inbound.normalized()
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO)
  if facing.length_squared() > 1e-12:
    return facing.normalized()
  return _MotorPlane.HORIZONTAL_FORWARD


## Clear explore latch and pick an interior bearing after rim clamp (avoids scan ↔ tangent loop).
static func _apply_explore_rim_escape_replan(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
  state["explore_waypoint"] = Vector3.ZERO
  state["step_goal"] = Vector3.ZERO
  state["consecutive_blocked"] = 0
  state["playfield_clamp_latch_ticks"] = 0
  state["boundary_scan_egress_ticks"] = 0
  _reset_explore_align_progress_state(state)


static func _pick_boundary_scan_sign(body: CharacterBody3D, hug: Dictionary, motor_v3: Dictionary) -> int:
  var inbound: Vector3 = hug.get("inbound_normal", Vector3.ZERO)
  if inbound.length_squared() < 1e-12:
    return 1
  var tangent_ccw := inbound.cross(Vector3.UP).normalized()
  var tangent_cw := -tangent_ccw
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), tangent_ccw)
  if facing.length_squared() < 1e-12:
    return 1
  facing = facing.normalized()
  var prefer := tangent_ccw if facing.dot(tangent_ccw) >= facing.dot(tangent_cw) else tangent_cw
  var turn_rad := deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5)))
  var left_after := facing.rotated(Vector3.UP, turn_rad).dot(prefer)
  var right_after := facing.rotated(Vector3.UP, -turn_rad).dot(prefer)
  return 1 if left_after >= right_after else -1


static func _pick_shorter_arc_turn_sign(
  body: CharacterBody3D,
  reference_dir: Vector3,
  motor_v3: Dictionary,
) -> int:
  ## Pick turn direction that improves dot toward [param reference_dir] after one turn step.
  var ref := reference_dir
  if ref.length_squared() < 1e-12:
    return 1
  ref = ref.normalized()
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), ref)
  if facing.length_squared() < 1e-12:
    return 1
  facing = facing.normalized()
  var turn_rad := deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5)))
  var left_after := facing.rotated(Vector3.UP, turn_rad).dot(ref)
  var right_after := facing.rotated(Vector3.UP, -turn_rad).dot(ref)
  return _resolve_turn_sign_tie(left_after, right_after, motor_v3)


## §7.3.0 align turn pick toward world [param target] (fewest-turn + chaos at ±180°).
static func _pick_align_turn_sign(
  body: CharacterBody3D,
  target: Vector3,
  motor_v3: Dictionary,
) -> int:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-12:
    return 1
  return _pick_shorter_arc_turn_sign(body, to_target, motor_v3)


static func _resolve_turn_sign_tie(left_after: float, right_after: float, motor_v3: Dictionary) -> int:
  const tie_eps := 1e-5
  if left_after > right_after + tie_eps:
    return 1
  if right_after > left_after + tie_eps:
    return -1
  var chaos := clampf(float(motor_v3.get("goal_consideration_chaos", 0.15)), 0.0, 1.0)
  if chaos > 0.0 and randf() < chaos:
    return 1 if randf() < 0.5 else -1
  return 1


static func _begin_boundary_scan(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  var hug := _playfield_hug_info(body, motor_v3)
  var scan_sign := int(state.get("boundary_scan_sign", 0))
  if scan_sign == 0:
    scan_sign = _pick_boundary_scan_sign(body, hug, motor_v3)
  state["boundary_scan_active"] = true
  state["boundary_scan_sign"] = scan_sign
  state["boundary_scan_turns"] = 0
  state["consecutive_blocked"] = 0
  state["playfield_clamp_latch_ticks"] = 0
  state["blocked_objective_action"] = &"boundary_scan"


## Ticks after [method _end_boundary_scan] during which inward-align turns don't re-arm the scan.
## Sized to a full turn (align to inward waypoint) plus a short forward-egress margin.
static func _boundary_scan_egress_budget(motor_v3: Dictionary) -> int:
  return _boundary_scan_turn_budget(motor_v3) + int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))


static func _end_boundary_scan(
  state: Dictionary,
  body: CharacterBody3D,
  action: StringName,
  motor_v3: Dictionary,
) -> void:
  state["boundary_scan_active"] = false
  state["boundary_scan_turns"] = 0
  state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
  state["explore_waypoint"] = Vector3.ZERO
  state["step_goal"] = Vector3.ZERO
  state["consecutive_blocked"] = 0
  state["playfield_clamp_latch_ticks"] = 0
  state["blocked_objective_action"] = action
  if action == &"boundary_scan_done":
    state["boundary_scan_egress_ticks"] = _boundary_scan_egress_budget(motor_v3)
  _reset_explore_align_progress_state(state)


static func _boundary_scan_action(body: CharacterBody3D, motor_v3: Dictionary, state: Dictionary) -> int:
  var scan_sign := int(state.get("boundary_scan_sign", 0))
  if scan_sign == 0:
    scan_sign = _pick_boundary_scan_sign(body, _playfield_hug_info(body, motor_v3), motor_v3)
    state["boundary_scan_sign"] = scan_sign
  return _MotorAction.TURN_LEFT if scan_sign > 0 else _MotorAction.TURN_RIGHT


static func _reset_precise_progress_state(state: Dictionary) -> void:
  state["precise_no_progress_ticks"] = 0
  state["precise_last_bearing_err_deg"] = INF
  state["precise_last_dist_sq"] = INF


static func _note_precise_position_progress(
  state: Dictionary,
  body: CharacterBody3D,
  stuck_eps: float,
) -> void:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8:
    return
  var err_deg := absf(_signed_bearing_error_deg(body, step_goal))
  var dist_sq := body.global_position.distance_squared_to(step_goal)
  var last_err := float(state.get("precise_last_bearing_err_deg", INF))
  var last_dist := float(state.get("precise_last_dist_sq", INF))
  if is_inf(last_err) or is_inf(last_dist):
    state["precise_last_bearing_err_deg"] = err_deg
    state["precise_last_dist_sq"] = dist_sq
    return
  var improve_thresh := stuck_eps * stuck_eps
  var bearing_improved := err_deg + 0.25 < last_err
  var dist_improved := dist_sq + improve_thresh < last_dist
  if bearing_improved or dist_improved:
    state["precise_no_progress_ticks"] = 0
  else:
    state["precise_no_progress_ticks"] = int(state.get("precise_no_progress_ticks", 0)) + 1
  state["precise_last_bearing_err_deg"] = err_deg
  state["precise_last_dist_sq"] = dist_sq


static func _note_boundary_scan_progress(
  state: Dictionary,
  body: CharacterBody3D,
  act: int,
  motor_v3: Dictionary,
  stuck_this_tick: bool,
) -> void:
  if not bool(state.get("boundary_scan_active", false)):
    return
  if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
    state["boundary_scan_turns"] = int(state.get("boundary_scan_turns", 0)) + 1
  var budget := _boundary_scan_turn_budget(motor_v3)
  if int(state.get("boundary_scan_turns", 0)) >= budget:
    _end_boundary_scan(state, body, &"boundary_scan_done", motor_v3)
  elif act == _MotorAction.MOVE_FORWARD and not stuck_this_tick:
    _end_boundary_scan(state, body, &"boundary_scan_done", motor_v3)


static func _record_blocked_approach(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
) -> void:
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


## Updates [param state] after locomotion + playfield clamp for this tick.
## Returns true when blocked objective resolution should run (precise / live latched paths).
static func note_outcome(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
  pos_before_tick: Vector3 = Vector3.ZERO,
  boundary_clamped: bool = false,
  delta: float = 1.0 / 60.0,
) -> bool:
  var act: int = _MotorAction.STAY
  if outcome != null:
    act = _MotorAction.normalize(outcome.action)
  var step_source: StringName = state.get("step_source", &"live")
  var is_latched := _is_latched_step_source(step_source)
  var executor_blocked: bool = outcome != null and outcome.blocked
  var pos_after := body.global_position
  var tick_disp := Vector3(
    pos_after.x - pos_before_tick.x, 0.0, pos_after.z - pos_before_tick.z
  )
  var stuck_eps := _latched_stuck_move_epsilon(motor_v3, body, delta)
  var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
  var no_progress := tick_disp.length_squared() < stuck_eps * stuck_eps
  var boundary_stuck := boundary_clamped and act == _MotorAction.MOVE_FORWARD
  var move_stuck: bool = executor_blocked or boundary_stuck
  var scan_active := bool(state.get("boundary_scan_active", false))
  var explore_idle_stuck := (
    step_source == &"explore"
    and is_latched
    and no_progress
    and not scan_active
  )
  var stuck_this_tick: bool = move_stuck or explore_idle_stuck

  state["last_outcome_blocked"] = stuck_this_tick
  if outcome != null and stuck_this_tick:
    outcome.blocked = true

  if step_source == &"precise" and is_latched:
    _note_precise_position_progress(state, body, stuck_eps)

  if step_source == &"explore" and is_latched:
    var align_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    _note_explore_align_progress(state, body, align_goal, explore_idle_stuck)
    if move_stuck:
      state["explore_no_progress_ticks"] = maxi(
        int(state.get("explore_no_progress_ticks", 0)),
        min_ticks,
      )

  if step_source == &"explore":
    if boundary_clamped:
      state["playfield_clamp_latch_ticks"] = _playfield_clamp_latch_ttl(motor_v3)
    elif int(state.get("playfield_clamp_latch_ticks", 0)) > 0:
      state["playfield_clamp_latch_ticks"] = int(state["playfield_clamp_latch_ticks"]) - 1

  # Post-scan inward-egress grace: run down while turning inward; clear on a real forward step
  # off the tight rim band (not a tangent slide still at the wall) or on rim clamp / scan re-entry.
  if step_source == &"explore" and int(state.get("boundary_scan_egress_ticks", 0)) > 0:
    var egress_move_ok := (
      act == _MotorAction.MOVE_FORWARD
      and not move_stuck
      and not no_progress
      and _rim_egress_move_cleared(body, motor_v3)
    )
    var egress_align_turn := (
      act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT
    )
    var egress_rim_move_hold := (
      act == _MotorAction.MOVE_FORWARD
      and body != null
      and _is_at_playfield_rim(body, motor_v3)
      and not egress_move_ok
    )
    if egress_move_ok or boundary_stuck or scan_active:
      state["boundary_scan_egress_ticks"] = 0
    elif not egress_align_turn and not egress_rim_move_hold:
      state["boundary_scan_egress_ticks"] = int(state["boundary_scan_egress_ticks"]) - 1

  if stuck_this_tick:
    state["consecutive_blocked"] = int(state.get("consecutive_blocked", 0)) + 1
    if move_stuck:
      _record_blocked_approach(state, body, outcome, motor_v3, physics_tick)
      if step_source == &"explore":
        state["explore_waypoint"] = Vector3.ZERO
  elif is_latched:
    var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    if _tick_had_meaningful_progress(body, step_goal, tick_disp, act, motor_v3, stuck_eps):
      state["consecutive_blocked"] = 0
      if step_source == &"precise":
        _reset_precise_progress_state(state)
      elif step_source == &"explore" and not boundary_clamped:
        state["playfield_clamp_latch_ticks"] = 0
        _reset_explore_align_progress_state(state)
  else:
    state["consecutive_blocked"] = 0

  _note_boundary_scan_progress(state, body, act, motor_v3, stuck_this_tick)

  if step_source == &"precise" and int(state.get("precise_no_progress_ticks", 0)) >= min_ticks:
    state["last_outcome_blocked"] = true
    if outcome != null:
      outcome.blocked = true
    state["consecutive_blocked"] = maxi(int(state.get("consecutive_blocked", 0)), min_ticks)
    return true

  if int(state.get("consecutive_blocked", 0)) < min_ticks:
    return false

  if step_source == &"explore":
    # During post-scan inward egress, turning toward the inward waypoint must not re-arm the
    # scan (that was the Fox turn-only scan-loop bug). Only a fresh rim clamp escapes here.
    var in_egress := int(state.get("boundary_scan_egress_ticks", 0)) > 0
    if _should_explore_boundary_scan(body, motor_v3, state, boundary_clamped):
      if not bool(state.get("boundary_scan_active", false)):
        var post_scan_clamp: bool = (
          state.get("blocked_objective_action") == &"boundary_scan_done"
          and boundary_clamped
          and not executor_blocked
        )
        if post_scan_clamp:
          _apply_explore_rim_escape_replan(state, body, motor_v3)
          state["blocked_objective_action"] = &"explore_replan"
        elif not in_egress:
          _begin_boundary_scan(state, body, motor_v3)
    elif not in_egress and int(state.get("explore_no_progress_ticks", 0)) >= min_ticks:
      _apply_explore_stuck_or_rim_replan(state, body, motor_v3)
    return false

  return true


## Alias for [method note_outcome] with explicit tick-boundary arguments.
static func note_tick_completion(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
  pos_before_tick: Vector3,
  boundary_clamped: bool,
  delta: float = 1.0 / 60.0,
) -> bool:
  return note_outcome(
    state, body, outcome, motor_v3, physics_tick, pos_before_tick, boundary_clamped, delta
  )


static func _sync_step_objective(ctx: Dictionary, state: Dictionary, goal_kind: StringName) -> void:
  if state.get("goal_kind", &"") != goal_kind:
    state["goal_kind"] = goal_kind
    state["step_goal"] = Vector3.ZERO
    state["step_instance_id"] = 0
    state["explore_dir"] = Vector3.ZERO
    state["explore_waypoint"] = Vector3.ZERO
    state["boundary_scan_active"] = false
    state["boundary_scan_sign"] = 0
    state["boundary_scan_turns"] = 0
    state["boundary_scan_egress_ticks"] = 0
    state["playfield_clamp_latch_ticks"] = 0
    _reset_precise_progress_state(state)
    _reset_explore_align_progress_state(state)
  var refresh_targets := bool(ctx.get("refresh_step_objective", false))
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  var has_step_goal := step_goal.length_squared() > 1e-8
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  var scan: Dictionary = ctx.get("scan", {})
  var map_rid: RID = ctx.get("map_rid", RID())
  var creature_pos := body.global_position
  var agent_r := _agent_radius(body)

  match goal_kind:
    _GkReg.GK_FIND_FOOD:
      if refresh_targets or not has_step_goal:
        _derive_find_food_step_objective(
          ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
        )
      elif state.get("step_source", &"") == &"explore":
        _maintain_explore_latch(ctx, state, motor_v3)
    _GkReg.GK_AVOID_HOSTILES:
      if refresh_targets or not has_step_goal:
        state["step_goal"] = _flee_objective(ctx, creature_pos, motor_v3)
        state["step_instance_id"] = 0
        state["step_source"] = &"live"
    _:
      if refresh_targets or not has_step_goal:
        state["step_goal"] = _explore_step_goal(creature_pos, state, motor_v3, ctx)
        state["step_instance_id"] = 0
        state["step_source"] = &"explore"


static func _derive_find_food_step_objective(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  scan: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> void:
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


## Overshoot / rim / dead-end maintenance on a held explore latch (runs between consideration ticks).
static func _maintain_explore_latch(
  ctx: Dictionary,
  state: Dictionary,
  motor_v3: Dictionary,
) -> void:
  var body: CharacterBody3D = ctx.get("body")
  if body == null:
    return
  var creature_pos := body.global_position
  var latched: Vector3 = state.get("explore_waypoint", Vector3.ZERO)
  if latched.length_squared() < 1e-8:
    return
  var arrival_tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  if creature_pos.distance_to(latched) <= arrival_tol:
    state["explore_waypoint"] = Vector3.ZERO
    state["step_goal"] = Vector3.ZERO
    return
  if _passed_explore_waypoint(body, latched, state):
    _apply_explore_waypoint_passed(state, body, motor_v3)
    return
  if _explore_latch_needs_rim_realign(body, motor_v3, state):
    _apply_explore_rim_escape_replan(state, body, motor_v3)
    return
  var adapter_hold: RefCounted = ctx.get("memory_adapter")
  if adapter_hold != null and adapter_hold.has_method(&"is_waypoint_dead_end"):
    if adapter_hold.is_waypoint_dead_end(creature_pos, latched, _GkReg.GK_FIND_FOOD, motor_v3):
      if _is_near_playfield_boundary(body, motor_v3):
        state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
      else:
        var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
        if explore.length_squared() < 1e-8:
          explore = _MotorPlane.HORIZONTAL_FORWARD
        state["explore_dir"] = explore.rotated(Vector3.UP, deg_to_rad(60.0)).normalized()
      state["explore_waypoint"] = Vector3.ZERO
      state["step_goal"] = Vector3.ZERO
      return
  state["step_goal"] = latched


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
    var new_iid := int(precise.get("instance_id", 0))
    if int(state.get("step_instance_id", 0)) != new_iid:
      _reset_precise_progress_state(state)
    state["step_goal"] = precise.get("pos", Vector3.ZERO)
    state["step_instance_id"] = new_iid
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
  return _locomote_toward_step_goal(body, motor_v3, state, ctx)


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
  var body: CharacterBody3D = ctx.get("body")
  if latched.length_squared() > 1e-8:
    if creature_pos.distance_to(latched) <= arrival_tol:
      state["explore_waypoint"] = Vector3.ZERO
      latched = Vector3.ZERO
    elif body != null and _passed_explore_waypoint(body, latched, state):
      _apply_explore_waypoint_passed(state, body, motor_v3)
      latched = Vector3.ZERO
    elif body != null and _explore_latch_needs_rim_realign(body, motor_v3, state):
      _apply_explore_rim_escape_replan(state, body, motor_v3)
      latched = Vector3.ZERO
    else:
      var adapter_hold: RefCounted = ctx.get("memory_adapter")
      if adapter_hold != null and adapter_hold.has_method(&"is_waypoint_dead_end"):
        if adapter_hold.is_waypoint_dead_end(creature_pos, latched, _GkReg.GK_FIND_FOOD, motor_v3):
          if body != null and _is_near_playfield_boundary(body, motor_v3):
            state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
          else:
            explore = explore.rotated(Vector3.UP, deg_to_rad(60.0))
            state["explore_dir"] = explore.normalized()
          state["explore_waypoint"] = Vector3.ZERO
          latched = Vector3.ZERO
      if latched.length_squared() > 1e-8:
        return latched
  explore = (state["explore_dir"] as Vector3).normalized()
  if body != null and _is_near_playfield_boundary(body, motor_v3):
    var inward := _rim_escape_explore_dir(body, motor_v3)
    if inward.length_squared() > 1e-12:
      explore = inward.normalized()
      state["explore_dir"] = explore
  var waypoint := creature_pos + explore * reach
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter != null and adapter.has_method(&"is_waypoint_dead_end"):
    if adapter.is_waypoint_dead_end(creature_pos, waypoint, _GkReg.GK_FIND_FOOD, motor_v3):
      if body != null and _is_near_playfield_boundary(body, motor_v3):
        explore = _rim_escape_explore_dir(body, motor_v3).normalized()
        state["explore_dir"] = explore
      else:
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


static func _locomote_toward_step_goal(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> int:
  resolve_path_to_step_goal(body, motor_v3, state, ctx)
  return align_and_move(body, motor_v3, state)


## §3.1 path clearance — LoS + nav substep when [code]run_path_clearance[/code] is set (§6e.2 cadence).
static func resolve_path_to_step_goal(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> void:
  if not bool(ctx.get("run_path_clearance", false)):
    return
  _run_path_clearance_los_nav(body, motor_v3, state, ctx)


## §3.2 immediate blocked-MOVE recheck — backtrack detour + clearance (not on consideration cadence).
static func apply_immediate_blocked_path_reevaluation(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8:
    return
  var creature_pos := body.global_position
  var to_goal := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
  if to_goal.length_squared() < 1e-8:
    return
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
  _run_path_clearance_los_nav(body, motor_v3, state, ctx)


static func _run_path_clearance_los_nav(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> void:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8:
    return
  if not _is_facing_aligned_for_move(body, step_goal, motor_v3):
    return
  var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
  var eye_h := float(ctx.get("eye_height", 1.0))
  var creature_pos := body.global_position
  if not _PathClear.has_clear_los(space, creature_pos, eye_h, step_goal, motor_v3):
    var map_rid: RID = ctx.get("map_rid", RID())
    var agent_r := _agent_radius(body)
    state["step_goal"] = _PathClear.resolve_step_objective(
      map_rid, creature_pos, step_goal, agent_r,
    )


## True when the tick's action completed a step objective (EAT or arrival STAY).
static func completed_step_objective(
  body: CharacterBody3D,
  state: Dictionary,
  motor_v3: Dictionary,
  action: int,
) -> bool:
  if action == _MotorAction.EAT:
    return true
  if action == _MotorAction.STAY:
    var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    if step_goal.length_squared() > 1e-8 and _at_arrival(body, step_goal, motor_v3):
      return true
  return false


## §7.3.0 facing-relative one-action pick toward current [code]step_goal[/code].
static func align_and_move(body: CharacterBody3D, motor_v3: Dictionary, state: Dictionary) -> int:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if step_goal.length_squared() < 1e-8:
    return _MotorAction.STAY
  if _is_facing_aligned_for_move(body, step_goal, motor_v3):
    return _MotorAction.MOVE_FORWARD
  var turn_sign := _pick_align_turn_sign(body, step_goal, motor_v3)
  return _MotorAction.TURN_LEFT if turn_sign > 0 else _MotorAction.TURN_RIGHT


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
      _seed_explore_after_seek(state, ctx)
    _:
      pass
