extends RefCounted
class_name LocomotionExecutor
## Stateless V3 locomotion executor — applies one [MotorAction] per physics tick ([CREATURE_MOVEMENT_V3.md §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

const _BLOCKED_DISPLACEMENT_FRAC := 0.15
## Min forward progress (world units) along intent before a move is considered to have advanced.
const _BLOCKED_PROGRESS_EPS := 0.001
## Speed fraction retained at the goal itself (arrival damping — CLEANUP R1). Kept comfortably
## above [code]motor_stuck_move_epsilon[/code]'s implied per-tick fraction (~0.19 at defaults,
## [code]motor_planner.gd[/code] `_latched_stuck_move_epsilon`) so a damped final approach still
## registers as progress for `precise`/`locale` no-progress tracking — retune both together if
## either default changes.
const _ARRIVAL_DAMPING_MIN_SPEED_FRAC := 0.35


## Applies [param action] to [param body] for one tick; debits calories on the body when supported.
## [param dist_to_goal], when set, tapers a [code]MOVE_FORWARD[/code]'s speed as the body nears
## the goal (arrival damping, CLEANUP R1) instead of moving at full speed and clamping position
## after the fact (CLEANUP C1/C2's prior fix — removed: it fought `motor_planner.gd`'s
## fixed-objective overshoot remint by preventing "passed the goal" from ever being observed).
## Goal-agnostic — applies to any [code]MOVE_FORWARD[/code] with a known distance regardless of
## which goal kind produced it, not just EAT. Optional so 4-arg call sites (tests / body shim)
## and [code]MOVE_BACKWARD[/code] (no meaningful goal to damp toward) stay at full speed.
## [param move_turn_target], when set, blends a bounded turn toward it into this tick's
## [code]MOVE_FORWARD[/code] (tank/car-style — CLEANUP R1 mitigation #2) instead of moving along a
## frozen heading. Pairs with [code]motor_planner.gd[/code]'s widened `move_blend_max_error_deg`
## gate, which now allows `MOVE_FORWARD` before facing is fully aligned.
static func apply_action(
  body: CharacterBody3D,
  action: Variant,
  delta: float,
  motor_v3: Dictionary,
  dist_to_goal: Variant = null,
  move_turn_target: Variant = null,
) -> ActionOutcome:
  var act := _MotorAction.normalize(action)
  var cost := _MotorAction.calorie_cost_for(act, delta, motor_v3)
  var pos_before := body.global_position
  var blocked := false

  match act:
    _MotorAction.Action.TURN_LEFT:
      _rotate_facing(body, motor_v3, 1.0)
    _MotorAction.Action.TURN_RIGHT:
      _rotate_facing(body, motor_v3, -1.0)
    _MotorAction.Action.MOVE_FORWARD:
      var align_frac := _blend_turn_toward(body, motor_v3, delta, move_turn_target)
      blocked = _displace_along_facing(body, 1.0, delta, pos_before, dist_to_goal, motor_v3, align_frac)
    _MotorAction.Action.MOVE_BACKWARD:
      blocked = _displace_along_facing(body, -1.0, delta, pos_before, null, motor_v3)
    _MotorAction.Action.STAY, _MotorAction.Action.REST, _MotorAction.Action.EAT:
      pass
    _:
      act = _MotorAction.Action.STAY

  var disp := body.global_position - pos_before
  disp.y = 0.0

  if body.has_method(&"debit_action_calories"):
    body.call(&"debit_action_calories", cost)

  return _ActionOutcome.new(disp, blocked, cost, act)


## Speed fraction to apply this tick: [code]1.0[/code] when [param dist_to_goal] is unset (null)
## or at/beyond [code]approach_arrival_damping_radius[/code], tapering linearly down to
## [const _ARRIVAL_DAMPING_MIN_SPEED_FRAC] as the body closes on the goal.
static func _arrival_damping_frac(dist_to_goal: Variant, motor_v3: Dictionary) -> float:
  var vt := typeof(dist_to_goal)
  if vt != TYPE_FLOAT and vt != TYPE_INT:
    return 1.0
  var dist := float(dist_to_goal)
  if dist < 0.0:
    return 1.0
  var radius := maxf(0.01, float(motor_v3.get("approach_arrival_damping_radius", 2.5)))
  if dist >= radius:
    return 1.0
  return lerpf(_ARRIVAL_DAMPING_MIN_SPEED_FRAC, 1.0, dist / radius)


static func _turn_increment_rad(motor_v3: Dictionary) -> float:
  return deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5)))


## Max angular rate (rad/sec) for the continuous blended turn+move law (§1 R1 —
## CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §1), distinct from [method _turn_increment_rad]'s fixed
## per-tick step, which stays reserved for pure-orientation actions ([code]TURN_LEFT[/code]/
## [code]TURN_RIGHT[/code] — boundary scan, EAT-orbit) that this law doesn't touch.
static func _move_turn_rate_rad(motor_v3: Dictionary) -> float:
  return deg_to_rad(float(motor_v3.get("move_turn_rate_deg_per_sec", 1350.0)))


## Rotates [member CharacterBody3D.last_move_direction] toward [param target] at up to
## [method _move_turn_rate_rad] (CLEANUP R1 mitigation #2 — blend turn+move in one tick; §1
## continuous controller — proportional rate instead of a fixed per-tick step). No-op when
## [param target] is unset (plain move, e.g. non-goal-directed callers) or the body is already on
## top of it (direction undefined at zero distance) — both return [code]1.0[/code] so callers that
## don't pass a target keep moving at full speed, unaffected by heading alignment. Signed angle
## derived the same way as `motor_planner.gd`'s `_pick_align_turn_sign`/bearing-error math, but
## solved for the exact rotation [method Vector3.rotated] needs rather than just a left/right pick,
## so the turn is clamped to whatever fraction of this tick's rate cap closes the remaining error.
## Returns the post-turn heading-alignment fraction ([code]max(0, cos(heading_error))[/code]) for
## the caller to scale forward speed by — floors at zero rather than going negative, so a target
## behind the creature yields zero forward speed (turn-in-place), never backward creep (§1's
## explicit forward/backward-must-not-be-interchangeable constraint).
static func _blend_turn_toward(
  body: CharacterBody3D, motor_v3: Dictionary, delta: float, target: Variant
) -> float:
  if typeof(target) != TYPE_VECTOR3:
    return 1.0
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return 1.0
  var facing: Vector3 = body.get("last_move_direction")
  if facing.length_squared() < 1e-12:
    facing = _MotorPlane.HORIZONTAL_RIGHT
  var to_n := to_target.normalized()
  var cross := facing.x * to_n.z - facing.z * to_n.x
  var dot := clampf(facing.dot(to_n), -1.0, 1.0)
  var max_turn := _move_turn_rate_rad(motor_v3) * maxf(0.0, delta)
  var turn := clampf(atan2(-cross, dot), -max_turn, max_turn)
  var new_facing := facing
  if absf(turn) >= 1e-6:
    new_facing = facing.rotated(Vector3.UP, turn).normalized()
    body.set("last_move_direction", new_facing)
    if body.has_method(&"_sync_visual_facing"):
      body.call(&"_sync_visual_facing")
  return maxf(0.0, new_facing.dot(to_n))


static func _rotate_facing(body: CharacterBody3D, motor_v3: Dictionary, direction_sign: float) -> void:
  var facing: Vector3 = body.get("last_move_direction")
  if facing.length_squared() < 1e-12:
    facing = _MotorPlane.HORIZONTAL_RIGHT
  var angle := _turn_increment_rad(motor_v3) * direction_sign
  facing = facing.rotated(Vector3.UP, angle).normalized()
  body.set("last_move_direction", facing)
  _clear_horizontal_velocity(body)
  if body.has_method(&"_sync_visual_facing"):
    body.call(&"_sync_visual_facing")


## Stops stale horizontal velocity from fighting turn-facing on the next body physics step.
static func _clear_horizontal_velocity(body: CharacterBody3D) -> void:
  body.velocity = Vector3(0.0, body.velocity.y, 0.0)


static func _displace_along_facing(
  body: CharacterBody3D,
  direction_sign: float,
  delta: float,
  pos_before: Vector3,
  dist_to_goal: Variant = null,
  motor_v3: Dictionary = {},
  align_frac: float = 1.0,
) -> bool:
  var facing: Vector3 = body.get("last_move_direction")
  if facing.length_squared() < 1e-12:
    facing = _MotorPlane.HORIZONTAL_RIGHT
  var dir := (facing * direction_sign).normalized()
  var damp_frac := _arrival_damping_frac(dist_to_goal, motor_v3) * align_frac
  # Sub-unit magnitude reads as partial thrust to `apply_horizontal_move_intent` (only normalizes
  # when length exceeds 1) — reuses that existing seam instead of adding a speed-scale parameter.
  var intent := dir * damp_frac
  if body.has_method(&"apply_horizontal_move_intent"):
    body.call(&"apply_horizontal_move_intent", intent, delta)
  else:
    var spd := _expected_horizontal_speed(body) * damp_frac
    body.velocity = Vector3(dir.x * spd, body.velocity.y, dir.z * spd)
    body.move_and_slide()
  # Blocked-detection uses the unit direction, not the damped intent — a slow-but-real approach
  # near the goal must not register as blocked just because commanded speed is intentionally low.
  return _is_move_blocked(body, dir, pos_before)


static func _expected_horizontal_speed(body: CharacterBody3D) -> float:
  if body.has_method(&"_resolve_locomotion"):
    var loco: Variant = body.call(&"_resolve_locomotion")
    if loco != null:
      return maxf(0.0, float(loco.get("max_speed")))
  return maxf(0.0, float(body.get("speed")))


## Blocked when the body hits a wall opposing [param intent_dir] and made negligible progress along it.
## Collision-driven so open-floor moves (no wall contact) are never flagged blocked, independent of physics delta.
static func _is_move_blocked(body: CharacterBody3D, intent_dir: Vector3, pos_before: Vector3) -> bool:
  var moved := body.global_position - pos_before
  moved.y = 0.0
  var progress := moved.dot(intent_dir)
  if progress > _BLOCKED_PROGRESS_EPS:
    return false
  if not body.is_on_wall():
    return false
  var normal := body.get_wall_normal()
  if normal.length_squared() < 1e-8:
    return true
  var flat_normal := Vector3(normal.x, 0.0, normal.z)
  if flat_normal.length_squared() < 1e-8:
    return false
  return flat_normal.normalized().dot(intent_dir) < -_BLOCKED_DISPLACEMENT_FRAC
