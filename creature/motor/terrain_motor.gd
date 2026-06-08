extends Object
class_name TerrainMotor
## Terrain elevation cost and physics probes for 3D cardinal motor on sculpted ground.


const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")


## Negative cost (bonus) for uphill cardinal probes when the creature sits in a depression.
## Params:
## - current_y / probe_y: Ground elevation (m) at creature and probe XZ.
## - depression_score: [PlayfieldGroundSampler.local_depression_score] at creature XZ.
## - motor_p: [code]creature_motor[/code] dict with terrain keys.
## Returns:
## - Additive cost delta (negative rewards uphill steps in valleys).
static func elevation_cost_delta(
  current_y: float,
  probe_y: float,
  depression_score: float,
  motor_p: Dictionary,
) -> float:
  if not bool(motor_p.get("terrain_elevation_motor_active", true)):
    return 0.0
  var thresh := float(motor_p.get("terrain_depression_threshold_m", 0.5))
  if depression_score < thresh:
    return 0.0
  var gain := probe_y - current_y
  if gain <= 0.0:
    return 0.0
  var weight := float(motor_p.get("weight_terrain_uphill", 4.0))
  return -gain * weight


## Score bonus for stuck / escape cardinal selection (higher = better uphill exit).
static func elevation_escape_score(
  current_y: float,
  probe_y: float,
  depression_score: float,
  motor_p: Dictionary,
) -> float:
  if depression_score < float(motor_p.get("terrain_depression_threshold_m", 0.5)):
    return 0.0
  var gain := probe_y - current_y
  var min_gain := float(motor_p.get("terrain_stuck_min_uphill_m", 0.15))
  if gain < min_gain:
    return gain * 0.5
  return gain * float(motor_p.get("weight_terrain_uphill", 4.0))


## True when a horizontal ray from [param body] hits [code]world_static[/code] before [param step] distance.
## Params:
## - space: Active physics space.
## - body: Creature [CharacterBody3D] (excluded from ray).
## - origin: Body world position.
## - dir: Unit horizontal intent.
## - step: Probe distance (motor cardinal step).
## - collision_mask: Layer mask (default world_static).
static func cardinal_blocked_by_terrain(
  space: PhysicsDirectSpaceState3D,
  body: CharacterBody3D,
  origin: Vector3,
  dir: Vector3,
  step: float,
  collision_mask: int = _Bounds3D.WORLD_STATIC_COLLISION_MASK,
) -> bool:
  if space == null or body == null or dir.length_squared() < 1e-12 or step <= 0.0:
    return false
  var inc := Vector3(dir.x, 0.0, dir.z).normalized()
  var ray_origin := origin + Vector3(0.0, 0.2, 0.0)
  var target := ray_origin + inc * step
  var query := PhysicsRayQueryParameters3D.create(ray_origin, target)
  query.collision_mask = collision_mask
  query.exclude = [body.get_rid()]
  var hit: Dictionary = space.intersect_ray(query)
  if hit.is_empty():
    return false
  var hit_pos: Vector3 = hit.get("position", target) as Vector3
  return ray_origin.distance_to(hit_pos) < step * 0.88
