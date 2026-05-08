## Helpers for §4.2: world sampling point and **axis-aligned** half-extents from [code]CollisionObject2D[/code] hitboxes.
## Used so grid cells, overlap encoding, and [code]_EXT[/code] lines match physics (Capsule/rect shapes, rotation).

extends Object


## Computes the **world-space axis-aligned bounding box** of a shape’s local [param rect] after [param shape_global_xf].
## Params: [param rect] from [code]Shape2D.get_rect()[/code]; [param shape_global_xf] is [code]CollisionShape2D.global_transform[/code].
## Returns: AABB covering the four corners of [param rect] transformed by [param shape_global_xf].
static func world_aabb_from_shape_rect(rect: Rect2, shape_global_xf: Transform2D) -> Rect2:
  var corners: Array[Vector2] = [
    rect.position,
    Vector2(rect.position.x + rect.size.x, rect.position.y),
    Vector2(rect.position.x, rect.position.y + rect.size.y),
    rect.position + rect.size,
  ]
  var w0: Vector2 = shape_global_xf * corners[0]
  var mn: Vector2 = w0
  var mx: Vector2 = w0
  for i in range(1, corners.size()):
    var w: Vector2 = shape_global_xf * corners[i]
    mn.x = minf(mn.x, w.x)
    mn.y = minf(mn.y, w.y)
    mx.x = maxf(mx.x, w.x)
    mx.y = maxf(mx.y, w.y)
  return Rect2(mn, mx - mn)


## Unions [param a] and [param b] into the smallest [code]Rect2[/code] containing both (both must have positive size when used after first merge).
static func merge_aabbs(a: Rect2, b: Rect2) -> Rect2:
  var end_a: Vector2 = a.position + a.size
  var end_b: Vector2 = b.position + b.size
  var tl: Vector2 = Vector2(minf(a.position.x, b.position.x), minf(a.position.y, b.position.y))
  var br: Vector2 = Vector2(maxf(end_a.x, end_b.x), maxf(end_a.y, end_b.y))
  return Rect2(tl, br - tl)


## Sampling point and half-extents for a physics body using enabled [code]CollisionShape2D[/code] children.
## Params: [param body] — [code]Area2D[/code], [code]RigidBody2D[/code], etc.
## Returns: [code]Dictionary[/code] with [code]point: Vector2[/code] (world center of union AABB) and [code]half_extents: Vector3[/code] ([code]hx, hy, 0[/code]).
## If no usable shape exists, returns [code]body.global_position[/code] and [code]Vector3.ZERO[/code] half-extents (caller may [code]push_error[/code] in debug).
static func sampling_from_collision_object(body: CollisionObject2D) -> Dictionary:
  var merged: Rect2
  var has_rect: bool = false
  for child in body.get_children():
    if not (child is CollisionShape2D):
      continue
    var cs: CollisionShape2D = child
    if cs.disabled or cs.shape == null:
      continue
    var local_rect: Rect2 = cs.shape.get_rect()
    var world_aabb: Rect2 = world_aabb_from_shape_rect(local_rect, cs.global_transform)
    if not has_rect:
      merged = world_aabb
      has_rect = true
    else:
      merged = merge_aabbs(merged, world_aabb)
  if has_rect:
    var c: Vector2 = merged.get_center()
    var h: Vector2 = merged.size * 0.5
    return {"point": c, "half_extents": Vector3(h.x, h.y, 0.0)}
  return {"point": body.global_position, "half_extents": Vector3.ZERO}
