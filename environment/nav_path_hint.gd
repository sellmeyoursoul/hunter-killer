## NavigationServer3D path hint for cardinal motor (M4 — optional detour bias).
class_name NavPathHint
extends RefCounted

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


## Unit direction on XZ toward the next nav waypoint, or [code]Vector3.ZERO[/code] if unavailable.
static func unit_direction_to_next_waypoint(
  map_rid: RID,
  from_world: Vector3,
  to_world: Vector3,
  _agent_radius: float,
) -> Vector3:
  if not map_rid.is_valid():
    return Vector3.ZERO
  var from_2d := Vector2(from_world.x, from_world.z)
  var to_2d := Vector2(to_world.x, to_world.z)
  if from_2d.distance_squared_to(to_2d) < 4.0:
    return Vector3.ZERO
  var path: PackedVector3Array = NavigationServer3D.map_get_path(
    map_rid,
    from_world,
    to_world,
    true,
  )
  if path.size() < 2:
    return Vector3.ZERO
  var next := path[1]
  var delta := Vector3(next.x - from_world.x, 0.0, next.z - from_world.z)
  if delta.length_squared() < 1e-8:
    return Vector3.ZERO
  return delta.normalized()


## First nav waypoint after [param from_world] on a path to [param to_world], or [code]Vector3.ZERO[/code].
static func first_waypoint_world(
  map_rid: RID,
  from_world: Vector3,
  to_world: Vector3,
  _agent_radius: float,
) -> Vector3:
  if not map_rid.is_valid():
    return Vector3.ZERO
  var from_2d := Vector2(from_world.x, from_world.z)
  var to_2d := Vector2(to_world.x, to_world.z)
  if from_2d.distance_squared_to(to_2d) < 4.0:
    return Vector3.ZERO
  var path: PackedVector3Array = NavigationServer3D.map_get_path(
    map_rid,
    from_world,
    to_world,
    true,
  )
  if path.size() < 2:
    return Vector3.ZERO
  return path[1]
