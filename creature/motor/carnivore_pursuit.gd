extends RefCounted
class_name CarnivorePursuit
## 8-way pursuit toward nearest prey position with playfield OOB penalty (same frame as [CardinalAvoidance]).

const _EightWay := preload("res://creature/motor/eight_way_directions.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


static func _read_pos_v3(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


## Picks a unit direction toward the closest prey, or idle when none.
## Params:
## - ctx: [code]creature_position[/code], [code]bounds_min[/code], [code]bounds_max[/code], [code]creature_half_extents[/code], [code]prey_targets[/code] (Array of Vector3/Vector2).
## Returns:
## - Normalized intent or [code]Vector3.ZERO[/code].
static func pick_pursuit_intent(ctx: Dictionary) -> Vector3:
  var prey: Array = ctx.get("prey_targets", []) as Array
  if prey.is_empty():
    return Vector3.ZERO
  var pos: Vector3 = _read_pos_v3(ctx.get("creature_position", Vector3.ZERO))
  var best: Vector3 = _read_pos_v3(prey[0])
  var best_d2 := pos.distance_squared_to(best)
  for i in range(1, prey.size()):
    var p: Vector3 = _read_pos_v3(prey[i])
    var d2 := pos.distance_squared_to(p)
    if d2 < best_d2:
      best_d2 = d2
      best = p
  var delta := best - pos
  if delta.length_squared() < 1.0:
    return Vector3.ZERO
  return _EightWay.best_aligned_to(delta)
