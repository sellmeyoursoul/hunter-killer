extends RefCounted
class_name LocomotionExecutor
## Stateless V3 locomotion executor — applies one [MotorAction] per physics tick ([CREATURE_MOVEMENT_V3.md §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

const _BLOCKED_DISPLACEMENT_FRAC := 0.15
## Min forward progress (world units) along intent before a move is considered to have advanced.
const _BLOCKED_PROGRESS_EPS := 0.001


## Applies [param action] to [param body] for one tick; debits calories on the body when supported.
static func apply_action(
  body: CharacterBody3D,
  action: Variant,
  delta: float,
  motor_v3: Dictionary,
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
      blocked = _displace_along_facing(body, 1.0, delta, pos_before)
    _MotorAction.Action.MOVE_BACKWARD:
      blocked = _displace_along_facing(body, -1.0, delta, pos_before)
    _MotorAction.Action.STAY, _MotorAction.Action.REST, _MotorAction.Action.EAT:
      pass
    _:
      act = _MotorAction.Action.STAY

  var disp := body.global_position - pos_before
  disp.y = 0.0

  if body.has_method(&"debit_action_calories"):
    body.call(&"debit_action_calories", cost)

  return _ActionOutcome.new(disp, blocked, cost, act)


static func _turn_increment_rad(motor_v3: Dictionary) -> float:
  return deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5)))


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
) -> bool:
  var facing: Vector3 = body.get("last_move_direction")
  if facing.length_squared() < 1e-12:
    facing = _MotorPlane.HORIZONTAL_RIGHT
  var intent := (facing * direction_sign).normalized()
  if body.has_method(&"apply_horizontal_move_intent"):
    body.call(&"apply_horizontal_move_intent", intent, delta)
  else:
    var spd := _expected_horizontal_speed(body)
    body.velocity = Vector3(intent.x * spd, body.velocity.y, intent.z * spd)
    body.move_and_slide()
  return _is_move_blocked(body, intent, pos_before)


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
