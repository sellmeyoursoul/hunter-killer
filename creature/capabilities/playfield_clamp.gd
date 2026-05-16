extends RefCounted
class_name PlayfieldClamp
## Clamps a world position inside the visible playfield AABB (edges act as walls).


## Params:
## - world_pos: Position to clamp.
## - half_extents: Footprint half-size (x = horizontal radius, y = vertical half-height).
## - screen_size: Playfield size in pixels (typically viewport visible rect).
## Returns:
## - Clamped position inside [half_extents, screen_size - half_extents] on each axis.
static func clamp_position(world_pos: Vector2, half_extents: Vector2, screen_size: Vector2) -> Vector2:
  var h := half_extents
  if h.x <= 0.0:
    h.x = 1.0
  if h.y <= 0.0:
    h.y = 1.0
  return world_pos.clamp(Vector2(h.x, h.y), screen_size - h)
