extends RefCounted
class_name MotorPathClear
## Clear-path tests for V3 movement weighing ([CREATURE_MOVEMENT_V3.md §3](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _AwarenessZone := preload("res://creature/motor/awareness_zone.gd")
const _NavHint := preload("res://environment/nav_path_hint.gd")


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


## True when nothing on [param collision_mask] intercepts the straight segment [param from]→
## [param to] — gates contact actions (EAT, future combat) so a target separated by a solid the
## acting body can't physically pass (e.g. a species-only `MobBlocker`) can't be interacted with
## just because it's within straight-line range. Pass the *acting* body's own `collision_mask` so
## the check matches whatever layers actually stop that body's movement — a herbivore and a
## carnivore standing at the same spot can get different answers for the same solid.
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
  return space_state.intersect_ray(query).is_empty()


## Resolves step objective — navmesh first waypoint when path exists, else direct objective.
static func resolve_step_objective(
  map_rid: RID,
  creature_pos: Vector3,
  ultimate: Vector3,
  agent_radius: float,
) -> Vector3:
  if map_rid.is_valid():
    var wp := _NavHint.first_waypoint_world(map_rid, creature_pos, ultimate, agent_radius)
    if wp.length_squared() > 1e-8 and creature_pos.distance_squared_to(wp) > 4.0:
      return wp
  return ultimate
