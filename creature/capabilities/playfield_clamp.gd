extends RefCounted
class_name PlayfieldClamp
## Clamps a world position inside the visible playfield AABB (edges act as walls).


## Params:
## - world_pos: Position to clamp.
## - half_extents: Footprint half-size (x = horizontal radius, y = vertical half-height).
## - bounds_max: Playfield max corner (2D viewport size, or 3D world [code]max[/code] on XZ).
## - bounds_min: Playfield min corner (usually [code]Vector2.ZERO[/code] in 2D; world offset in 3D).
## Returns:
## - Clamped position inside the playfield AABB inset by [param half_extents].
static func clamp_position(
  world_pos: Vector2,
  half_extents: Vector2,
  bounds_max: Vector2,
  bounds_min: Vector2 = Vector2.ZERO,
) -> Vector2:
  var h := half_extents
  if h.x <= 0.0:
    h.x = 1.0
  if h.y <= 0.0:
    h.y = 1.0
  return world_pos.clamp(bounds_min + h, bounds_max - h)


## Footprint clearance to each playfield edge: x=left, y=right, z=top, w=bottom.
static func edge_margins(
  world_pos: Vector2,
  half_extents: Vector2,
  bounds_max: Vector2,
  bounds_min: Vector2 = Vector2.ZERO,
) -> Vector4:
  var h := half_extents
  if h.x <= 0.0:
    h.x = 1.0
  if h.y <= 0.0:
    h.y = 1.0
  var left := world_pos.x - h.x - bounds_min.x
  var right := bounds_max.x - (world_pos.x + h.x)
  var top := world_pos.y - h.y - bounds_min.y
  var bottom := bounds_max.y - (world_pos.y + h.y)
  return Vector4(left, right, top, bottom)


## Minimum footprint clearance to any playfield edge.
static func min_edge_margin(
  world_pos: Vector2,
  half_extents: Vector2,
  bounds_max: Vector2,
  bounds_min: Vector2 = Vector2.ZERO,
) -> float:
  var m := edge_margins(world_pos, half_extents, bounds_max, bounds_min)
  return minf(minf(m.x, m.y), minf(m.z, m.w))


## Inward-facing unit normal for the playfield edge the heading closes on (or [code]Vector2.ZERO[/code]).
static func inbound_normal_if_closing(
  heading_unit: Vector2,
  world_pos: Vector2,
  half_extents: Vector2,
  bounds_max: Vector2,
  step_length: float,
  min_clearance_px: float = 4.0,
  bounds_min: Vector2 = Vector2.ZERO,
) -> Vector2:
  if heading_unit.length_squared() < 1e-12 or step_length <= 0.0:
    return Vector2.ZERO
  var h := half_extents
  if h.x <= 0.0:
    h.x = 1.0
  if h.y <= 0.0:
    h.y = 1.0
  var u := heading_unit.normalized()
  var m := edge_margins(world_pos, h, bounds_max, bounds_min)
  var predicted := world_pos + u * step_length
  var left_pred := predicted.x - h.x - bounds_min.x
  var right_pred := bounds_max.x - (predicted.x + h.x)
  var top_pred := predicted.y - h.y - bounds_min.y
  var bot_pred := bounds_max.y - (predicted.y + h.y)
  const AXIS_EPS := 0.12
  const CLOSURE_EPS := 0.25
  var best_n := Vector2.ZERO
  var worst_closure := 0.0
  if u.x < -AXIS_EPS and left_pred < min_clearance_px and left_pred < m.x - CLOSURE_EPS:
    var closure := m.x - left_pred
    if closure > worst_closure:
      worst_closure = closure
      best_n = Vector2.RIGHT
  if u.x > AXIS_EPS and right_pred < min_clearance_px and right_pred < m.y - CLOSURE_EPS:
    var closure := m.y - right_pred
    if closure > worst_closure:
      worst_closure = closure
      best_n = Vector2.LEFT
  if u.y < -AXIS_EPS and top_pred < min_clearance_px and top_pred < m.z - CLOSURE_EPS:
    var closure := m.z - top_pred
    if closure > worst_closure:
      worst_closure = closure
      best_n = Vector2.DOWN
  if u.y > AXIS_EPS and bot_pred < min_clearance_px and bot_pred < m.w - CLOSURE_EPS:
    var closure := m.w - bot_pred
    if closure > worst_closure:
      worst_closure = closure
      best_n = Vector2.UP
  return best_n


## Inward normal when already hugging an edge and [param heading_unit] still drives into it.
static func inbound_normal_if_hugging(
  heading_unit: Vector2,
  world_pos: Vector2,
  half_extents: Vector2,
  bounds_max: Vector2,
  hug_band_px: float,
  bounds_min: Vector2 = Vector2.ZERO,
) -> Vector2:
  if heading_unit.length_squared() < 1e-12 or hug_band_px <= 0.0:
    return Vector2.ZERO
  var u := heading_unit.normalized()
  var m := edge_margins(world_pos, half_extents, bounds_max, bounds_min)
  const AXIS_EPS := 0.12
  var best_n := Vector2.ZERO
  var tightest := INF
  if m.x < hug_band_px and u.x < -AXIS_EPS and m.x < tightest:
    tightest = m.x
    best_n = Vector2.RIGHT
  if m.y < hug_band_px and u.x > AXIS_EPS and m.y < tightest:
    tightest = m.y
    best_n = Vector2.LEFT
  if m.z < hug_band_px and u.y < -AXIS_EPS and m.z < tightest:
    tightest = m.z
    best_n = Vector2.DOWN
  if m.w < hug_band_px and u.y > AXIS_EPS and m.w < tightest:
    tightest = m.w
    best_n = Vector2.UP
  return best_n


## Redirects [param heading_unit] to slide along a playfield edge (soft bounds), mirroring rock wall-slide.
## Params:
## - slide_pick: [code]WallSlidePick[/code] (or compatible [code]pick_tangent_closer[/code] / [code]pick_tangent_away_from[/code]).
## - away_hint: Optional escape bearing (flee / wedge egress); uses tangent-away when set.
static func slide_heading_along_edge(
  heading_unit: Vector2,
  world_pos: Vector2,
  half_extents: Vector2,
  bounds_max: Vector2,
  lookahead_px: float,
  slide_pick: RefCounted,
  away_hint: Vector2 = Vector2.ZERO,
  bounds_min: Vector2 = Vector2.ZERO,
  min_clearance_px: float = 4.0,
) -> Vector2:
  if heading_unit.length_squared() < 1e-12 or slide_pick == null:
    return heading_unit
  var inc := heading_unit.normalized()
  var step := maxf(lookahead_px, 8.0)
  var n := inbound_normal_if_closing(
    inc, world_pos, half_extents, bounds_max, step, min_clearance_px, bounds_min
  )
  if n.length_squared() < 1e-12:
    var hug_band := maxf(min_clearance_px * 2.0, 14.0)
    n = inbound_normal_if_hugging(inc, world_pos, half_extents, bounds_max, hug_band, bounds_min)
  if n.length_squared() < 1e-12:
    return inc
  if away_hint.length_squared() > 1e-12 and slide_pick.has_method(&"pick_tangent_away_from"):
    return slide_pick.call(&"pick_tangent_away_from", inc, n, away_hint)
  if slide_pick.has_method(&"pick_tangent_closer"):
    return slide_pick.call(&"pick_tangent_closer", inc, n)
  return inc
