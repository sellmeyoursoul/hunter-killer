## Picks sliding direction along a 2D wall so the deviation from incoming motion is minimized (prefer larger dot with [param incoming_unit] among ±wall tangent).
extends RefCounted

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


## Incoming should be normalized; normal from [method PhysicsDirectSpaceState2D.intersect_ray] (typically points from surface outward toward ray origin — tangents lie in the perpendicular span).
func pick_tangent_closer(incoming_unit: Vector2, wall_normal_unit: Vector2) -> Vector2:
  var n := wall_normal_unit
  if n.length_squared() < 1e-10:
    return incoming_unit.normalized()
  n = n.normalized()
  var inc := incoming_unit.normalized()

  ## Unit tangent and its opposite; whichever aligns more with [param inc] is the smallest heading change from [param inc] among sideways options.
  var t := Vector2(-n.y, n.x).normalized()
  var d_pos := inc.dot(t)
  var d_neg := inc.dot(-t)
  if d_pos > d_neg + 1e-5:
    return t
  if d_neg > d_pos + 1e-5:
    return -t
  ## Perpendicular incoming (dot ~0): stable tie-breaking via 2D "cross" z sign.
  var cross_z := inc.x * t.y - inc.y * t.x
  if cross_z >= 0.0:
    return t
  return -t


## Picks the wall tangent that best continues egress away from [param away_unit] (flee / jeopardy).
## Params:
## - incoming_unit: Normalized motor intent before the ray hit (used only when [param away_unit] is zero).
## - wall_normal_unit: Outward wall normal from [method PhysicsDirectSpaceState2D.intersect_ray].
## - away_unit: Preferred escape bearing (typically prey position minus threat); need not be tangent to the wall.
## Returns:
## - Unit slide heading along the wall that maximizes separation from the threat, not minimal turn from [param incoming_unit].
func pick_tangent_away_from(
  incoming_unit: Vector2, wall_normal_unit: Vector2, away_unit: Vector2
) -> Vector2:
  if away_unit.length_squared() < 1e-12:
    return pick_tangent_closer(incoming_unit, wall_normal_unit)
  var n := wall_normal_unit
  if n.length_squared() < 1e-10:
    return incoming_unit.normalized()
  n = n.normalized()
  var away := away_unit.normalized()
  var t := Vector2(-n.y, n.x).normalized()
  var best := t
  var best_score := -INF
  for c: Vector2 in [t, -t]:
    var score: float = c.dot(away) - maxf(0.0, c.dot(-away)) * 2.0
    if score > best_score:
      best_score = score
      best = c
  return best


## Picks the wall tangent that best continues closing on [param toward_unit] (predator flank around cover).
func pick_tangent_toward(
  incoming_unit: Vector2, wall_normal_unit: Vector2, toward_unit: Vector2
) -> Vector2:
  if toward_unit.length_squared() < 1e-12:
    return pick_tangent_closer(incoming_unit, wall_normal_unit)
  var n := wall_normal_unit
  if n.length_squared() < 1e-10:
    return incoming_unit.normalized()
  n = n.normalized()
  var toward := toward_unit.normalized()
  var t := Vector2(-n.y, n.x).normalized()
  var best := t
  var best_score := -INF
  for c: Vector2 in [t, -t]:
    var score: float = c.dot(toward) - maxf(0.0, c.dot(-toward)) * 2.0
    if score > best_score:
      best_score = score
      best = c
  return best


## Vector3/XZ variant of [method pick_tangent_closer].
func pick_tangent_closer_v3(incoming_unit: Vector3, wall_normal_unit: Vector3) -> Vector3:
  var inc2 := Vector2(incoming_unit.x, incoming_unit.z)
  var n2 := Vector2(wall_normal_unit.x, wall_normal_unit.z)
  return _MotorPlane.to_horizontal_vec3(pick_tangent_closer(inc2, n2))


## Vector3/XZ variant of [method pick_tangent_away_from].
func pick_tangent_away_from_v3(
  incoming_unit: Vector3, wall_normal_unit: Vector3, away_unit: Vector3
) -> Vector3:
  var inc2 := Vector2(incoming_unit.x, incoming_unit.z)
  var n2 := Vector2(wall_normal_unit.x, wall_normal_unit.z)
  var away2 := Vector2(away_unit.x, away_unit.z)
  return _MotorPlane.to_horizontal_vec3(pick_tangent_away_from(inc2, n2, away2))


## Vector3/XZ variant of [method pick_tangent_toward].
func pick_tangent_toward_v3(
  incoming_unit: Vector3, wall_normal_unit: Vector3, toward_unit: Vector3
) -> Vector3:
  var inc2 := Vector2(incoming_unit.x, incoming_unit.z)
  var n2 := Vector2(wall_normal_unit.x, wall_normal_unit.z)
  var toward2 := Vector2(toward_unit.x, toward_unit.z)
  return _MotorPlane.to_horizontal_vec3(pick_tangent_toward(inc2, n2, toward2))
