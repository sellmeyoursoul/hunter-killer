## Picks sliding direction along a 2D wall so the deviation from incoming motion is minimized (prefer larger dot with [param incoming_unit] among ±wall tangent).
extends RefCounted


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
