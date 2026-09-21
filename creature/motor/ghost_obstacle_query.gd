extends RefCounted
class_name GhostObstacleQuery
## Live per-instance fit query against the movement-inert "ghost" object-scale passability layer
## ([PHYSICS_SQUEEZE.md](../../Project_Docs/Draft_Features/PHYSICS_SQUEEZE.md) decision 16).
## Query-only: this layer is deliberately excluded from every creature's real `collision_mask`
## (`move_and_slide` never resolves against it), so the only way anything is ever "blocked" by an
## object on this layer is a caller explicitly running a query like the ones here and acting on
## the result — real physics collision response never happens on its own.

## Physics layer bit for object-scale query-only obstacles (`3d_physics/layer_16` in
## project.godot, `obstacle_query_ghost`). Real geometry-derived colliders live here (reusing
## `StaticObstacleCollision`'s existing mesh-to-convex-hull bake — decision 16/17), sized exactly
## like their visual footprint, never added to any creature's real movement mask.
const GHOST_LAYER_MASK := 16


## True when a capsule of [param radius]/[param height] centered at [param at] overlaps anything
## on the ghost layer — i.e. a body this size does not fit there. Point-in-place check (not a
## motion sweep) — correct for a per-tick pre-move gate, where the tested point is this tick's
## proposed destination and per-tick displacement is small relative to obstacle scale.
static func capsule_overlaps_ghost_layer(
  space_state: PhysicsDirectSpaceState3D,
  at: Vector3,
  radius: float,
  height: float,
  exclude_rids: Array = [],
) -> bool:
  if space_state == null or radius <= 0.0:
    return false
  var shape := CapsuleShape3D.new()
  shape.radius = radius
  shape.height = maxf(height, radius * 2.0)
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = shape
  query.collision_mask = GHOST_LAYER_MASK
  query.transform = Transform3D(Basis(), at)
  for rid in exclude_rids:
    if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
      query.exclude.append(rid as RID)
  return not space_state.intersect_shape(query, 1).is_empty()


## Fraction (0..1) of the straight motion [param from] → [param to] a capsule of [param radius]/
## [param height] can travel before first overlapping the ghost layer — a real sweep
## (`PhysicsDirectSpaceState3D.cast_motion`), not a discretized point-sample walk. `1.0` means the
## whole segment is clear; `0.0` means the capsule is blocked (or already overlapping something)
## right at [param from]. Used by [RoutePlausibilityScan] to walk a multi-segment navmesh path and
## find the first point along it a given creature's own capsule can't actually clear.
static func sweep_capsule_along_segment(
  space_state: PhysicsDirectSpaceState3D,
  from: Vector3,
  to: Vector3,
  radius: float,
  height: float,
  exclude_rids: Array = [],
  mask: int = GHOST_LAYER_MASK,
) -> float:
  if space_state == null or radius <= 0.0:
    return 1.0
  var motion := to - from
  if motion.length_squared() < 1e-10:
    return 1.0
  var shape := CapsuleShape3D.new()
  shape.radius = radius
  shape.height = maxf(height, radius * 2.0)
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = shape
  query.collision_mask = mask
  query.transform = Transform3D(Basis(), from)
  query.motion = motion
  for rid in exclude_rids:
    if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
      query.exclude.append(rid as RID)
  var result := space_state.cast_motion(query)
  if result.size() < 1:
    return 1.0
  return clampf(float(result[0]), 0.0, 1.0)


## §8e escape hatch (PHYSICS_SQUEEZE.md decision "8e resolved," 2026-09-18): a purely query-enforced
## layer has no engine-style depenetration — if a body ever ends up overlapping a ghost-layer shape
## (spawn placement, a neighboring object's collision re-syncing under it after a state change, a
## size change mid-transit), [method capsule_overlaps_ghost_layer] alone can trap it forever, since
## almost every nearby destination still reads as "overlapping" once you're already inside. This is
## true when [param body_pos] already overlaps the ghost layer and moving to [param next_pos] does
## not get closer to *any* of the specific shapes currently overlapped there — "getting out" is
## never blocked by the same check that prevents "getting further in." Only engages when an overlap
## already exists at [param body_pos]; a body that isn't currently stuck gets no special treatment.
##
## Uses each overlapped collider's own world position as a coarse clearance proxy rather than a
## real penetration-depth solve — good enough for the roughly-centered convex obstacles this layer
## holds today (a single shrub/boulder's own `StaticBody3D` origin), and decision 8e explicitly
## left the exact clearance comparison as an implementation-time detail, not a design blocker.
static func escaping_overlap(
  space_state: PhysicsDirectSpaceState3D,
  body_pos: Vector3,
  next_pos: Vector3,
  radius: float,
  height: float,
  exclude_rids: Array = [],
) -> bool:
  if space_state == null or radius <= 0.0:
    return false
  var overlaps := _overlapping_shapes(space_state, body_pos, radius, height, exclude_rids)
  if overlaps.is_empty():
    return false
  for hit_v in overlaps:
    var hit: Dictionary = hit_v
    var collider: Object = hit.get("collider")
    var center := body_pos
    if collider is Node3D:
      center = (collider as Node3D).global_position
    var cur_dist := body_pos.distance_to(center)
    var next_dist := next_pos.distance_to(center)
    if next_dist < cur_dist - 0.001:
      return false
  return true


static func _overlapping_shapes(
  space_state: PhysicsDirectSpaceState3D,
  at: Vector3,
  radius: float,
  height: float,
  exclude_rids: Array,
) -> Array:
  var shape := CapsuleShape3D.new()
  shape.radius = radius
  shape.height = maxf(height, radius * 2.0)
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = shape
  query.collision_mask = GHOST_LAYER_MASK
  query.transform = Transform3D(Basis(), at)
  for rid in exclude_rids:
    if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
      query.exclude.append(rid as RID)
  return space_state.intersect_shape(query, 8)
