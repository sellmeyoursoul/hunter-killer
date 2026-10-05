extends RefCounted
class_name MotorPathClear
## Clear-path tests for V3 movement weighing ([CREATURE_MOVEMENT_V3.md §3](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _AwarenessZone := preload("res://creature/motor/awareness_zone.gd")
const _GhostObstacleQuery := preload("res://creature/motor/ghost_obstacle_query.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _NavRouter := preload("res://creature/motor/nav_router.gd")

## Minimum horizontal (XZ) distance, in metres, from the creature to a navmesh path point before
## [method resolve_step_objective] will steer at it. This is the same 2 m as the old 3D
## `distance_squared_to > 4.0` gate, but measured on the ground plane.
const MIN_HOP_DISTANCE := 2.0
## How far above / below a body's position [method nav_query_origin] searches for the navmesh
## surface under it. Above: the navmesh can sit slightly above a short body's origin. Below: must
## exceed any creature's origin height above the surface plus terrain slop (authored-dimension bodies
## have their origin at the feet, so this is generous; legacy bodies sit at the capsule centre).
const NAV_QUERY_ABOVE := _NavRouter.NAV_QUERY_ABOVE
const NAV_QUERY_BELOW := _NavRouter.NAV_QUERY_BELOW


## Navmesh point to use as the *start* of a path query for a body at [param creature_pos]; thin static
## wrapper over [method NavRouter.query_origin]. [param nav] is a [NavRouter] or (legacy / fixture seam) a
## raw map RID, which is wrapped. See the router for the tall-capsule rationale (2026-09-25).
## Example: `MotorPathClear.nav_query_origin(nav, body_pos)`.
static func nav_query_origin(nav: Variant, creature_pos: Vector3) -> Vector3:
  return _NavRouter.coerce(nav).query_origin(null, creature_pos)


## True when LoS to [param objective] passes the V3 occlusion threshold.
static func has_clear_los(
  space_state: PhysicsDirectSpaceState3D,
  creature_pos: Vector3,
  eye_height: float,
  objective: Vector3,
  motor_v3: Dictionary,
) -> bool:
  var los := _AwarenessZone.line_of_sight_clear(
    space_state, creature_pos, eye_height, objective, motor_v3,
  )
  return bool(los.get("line_of_sight_clear", false))


## True when nothing on [param collision_mask] — real *or* the movement-inert ghost/query-only
## layer ([GhostObstacleQuery]) — intercepts the straight segment [param from]→[param to] — gates
## contact actions (EAT, future combat) so a target separated by a solid the acting body can't
## physically pass (e.g. a species-only `MobBlocker` refuge wall) can't be interacted with just
## because it's within straight-line range. Pass the *acting* body's own `collision_mask` so the
## real-layer half of the check matches whatever layers actually stop that body's movement — a
## herbivore and a carnivore standing at the same spot can get different answers for the same
## solid. PHYSICS_SQUEEZE.md §3 decision 25/28 (2026-09-18): object-scale obstacles like
## `open_shrub_3d`'s `MobBlocker` were migrated onto the ghost layer (decision 16/25) so they're
## deliberately excluded from every body's real `collision_mask` — this check's original
## real-mask-only raycast went stale the moment that migration landed, since it could no longer see
## the very obstacles it exists to catch (live repro: a wolf standing outside a shrub refuge ring
## reached "through" the wall and ate the sheltered rabbit). Checking the ghost layer too restores
## the original guarantee without re-adding real collision response to query-only obstacles.
static func has_clear_contact_path(
  space_state: PhysicsDirectSpaceState3D,
  from: Vector3,
  to: Vector3,
  collision_mask: int,
  exclude_rids: Array = [],
) -> bool:
  if space_state == null:
    return true
  if from.distance_squared_to(to) < 1e-6:
    return true
  var query := PhysicsRayQueryParameters3D.create(from, to)
  query.collision_mask = collision_mask
  for rid in exclude_rids:
    if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
      query.exclude.append(rid as RID)
  if not space_state.intersect_ray(query).is_empty():
    return false
  var ghost_query := PhysicsRayQueryParameters3D.create(from, to)
  ghost_query.collision_mask = _GhostObstacleQuery.GHOST_LAYER_MASK
  for rid in exclude_rids:
    if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
      ghost_query.exclude.append(rid as RID)
  return space_state.intersect_ray(ghost_query).is_empty()


## Resolves the step objective: the first navmesh path point more than [const MIN_HOP_DISTANCE]
## away from [param creature_pos] on the XZ plane. Falls back to [param ultimate] when there's no
## map, no path, the target itself is within that distance, or every path point is within it.
## [param nav] is a [NavRouter] (or a raw map RID, wrapped). [param agent_radius] is unused (kept for call-site stability).
##
## Hop distance is measured horizontally, not in 3D (2026-09-25 wolf silent-stall fix):
## [param creature_pos] is the body's capsule centre, but path points are on the ground. The
## wolf's centre is ~7.7 m up, so a 3D `> 2 m` gate always passed, even for a hop 0.1 m
## (horizontally) under the wolf. On sloped terrain, `map_get_path` snaps an elevated start
## slightly uphill, and the funnel then emits a corner next to the wolf's own XZ position.
## `path[1]` therefore kept landing under the wolf, and it spun on MOVE_FORWARD with zero forward
## speed. Scanning the whole path, instead of only `path[1]` then `ultimate`, also avoids cutting
## straight through a corner just because the first bend was close. The query also starts from
## [method nav_query_origin] (the surface under the body), not the elevated centre.
static func resolve_step_objective(
  nav: Variant,
  creature_pos: Vector3,
  ultimate: Vector3,
  _agent_radius: float,
) -> Vector3:
  var router := _NavRouter.coerce(nav)
  if not router.has_map():
    return ultimate
  if _MotorPlane.horizontal_distance(creature_pos, ultimate) <= MIN_HOP_DISTANCE:
    return ultimate
  var path: PackedVector3Array = router.path(null, creature_pos, ultimate)["points"]
  if path.size() < 2:
    return ultimate
  for i in range(1, path.size()):
    var wp: Vector3 = path[i]
    if _MotorPlane.horizontal_distance(creature_pos, wp) > MIN_HOP_DISTANCE:
      return wp
  return ultimate
