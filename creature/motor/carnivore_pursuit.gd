extends RefCounted
class_name CarnivorePursuit
## 8-way pursuit toward nearest prey position with playfield OOB penalty (same frame as [CardinalAvoidance]).

const _EightWay := preload("res://creature/motor/eight_way_directions.gd")


## Picks a unit direction toward the closest prey, or idle when none.
## Params:
## - ctx: [code]creature_position[/code], [code]bounds_min[/code], [code]bounds_max[/code], [code]creature_half_extents[/code], [code]prey_targets[/code] (Array of Vector2).
## Returns:
## - Normalized intent or [code]Vector2.ZERO[/code].
static func pick_pursuit_intent(ctx: Dictionary) -> Vector2:
  var prey: Array = ctx.get("prey_targets", []) as Array
  if prey.is_empty():
    return Vector2.ZERO
  var pos: Vector2 = ctx["creature_position"]
  var best: Vector2 = prey[0] as Vector2
  var best_d2 := pos.distance_squared_to(best)
  for i in range(1, prey.size()):
    var p: Vector2 = prey[i] as Vector2
    var d2 := pos.distance_squared_to(p)
    if d2 < best_d2:
      best_d2 = d2
      best = p
  var delta := best - pos
  if delta.length_squared() < 1.0:
    return Vector2.ZERO
  return _EightWay.best_aligned_to(delta)
