## Physics-ray line of sight on the 3D playfield (M4 — CONVERT_TO_3D §5.1).
class_name LineOfSight3D
extends RefCounted

const OCCLUSION_BLOCKED_FRACTION := 0.6
const WORLD_STATIC_MASK := 1
const SEGMENT_SAMPLES := 10
const DEFAULT_EYE_HEIGHT_RATIO := 0.9


## World Y for ray origin from body feet [param creature_pos] and [param eye_height].
static func eye_world_position(creature_pos: Vector3, eye_height: float) -> Vector3:
  return Vector3(creature_pos.x, creature_pos.y + eye_height, creature_pos.z)


## Fraction of path segments blocked by [code]world_static[/code] occluders (**0..1**).
static func occlusion_fraction(
  space_state: PhysicsDirectSpaceState3D,
  from: Vector3,
  to: Vector3,
  exclude_rids: Array = [],
) -> float:
  if space_state == null:
    return 0.0
  var total := from.distance_to(to)
  if total < 0.05:
    return 0.0
  var blocked := 0
  for i in range(SEGMENT_SAMPLES):
    var t0 := float(i) / float(SEGMENT_SAMPLES)
    var t1 := float(i + 1) / float(SEGMENT_SAMPLES)
    var a := from.lerp(to, t0)
    var b := from.lerp(to, t1)
    var query := PhysicsRayQueryParameters3D.create(a, b)
    query.collision_mask = WORLD_STATIC_MASK
    query.hit_from_inside = true
    for rid in exclude_rids:
      if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
        query.exclude.append(rid as RID)
    var hit: Dictionary = space_state.intersect_ray(query)
    if not hit.is_empty():
      blocked += 1
  return float(blocked) / float(SEGMENT_SAMPLES)


## True when [param occlusion_fraction] exceeds the M4 blocked threshold (>60%).
static func is_occluded(occlusion_fraction_value: float) -> bool:
  return occlusion_fraction_value > OCCLUSION_BLOCKED_FRACTION


## Combined LoS check from creature eye to target centroid.
static func line_of_sight_clear(
  space_state: PhysicsDirectSpaceState3D,
  creature_pos: Vector3,
  eye_height: float,
  target_pos: Vector3,
  exclude_rids: Array = [],
) -> Dictionary:
  var eye := eye_world_position(creature_pos, eye_height)
  var target := Vector3(target_pos.x, eye.y, target_pos.z)
  var frac := occlusion_fraction(space_state, eye, target, exclude_rids)
  return {
    "line_of_sight_clear": not is_occluded(frac),
    "occluded": is_occluded(frac),
    "occlusion_fraction": frac,
  }
