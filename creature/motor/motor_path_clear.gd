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
