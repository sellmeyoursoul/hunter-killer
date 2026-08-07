## Physics-ray line of sight on the 3D playfield (M4 — CONVERT_TO_3D §5.1).
class_name LineOfSight3D
extends RefCounted

const OCCLUSION_BLOCKED_FRACTION := 0.6
const WORLD_STATIC_MASK := 1
## Ring samples fanned around the target's silhouette, plus the center — 1 + this many total.
const SHADOW_RING_SAMPLES := 8
const DEFAULT_EYE_HEIGHT_RATIO := 0.9
## Fallback target silhouette radius when the caller doesn't supply one.
const DEFAULT_TARGET_RADIUS := 0.5


## World Y for ray origin from body feet [param creature_pos] and [param eye_height].
static func eye_world_position(creature_pos: Vector3, eye_height: float) -> Vector3:
  return Vector3(creature_pos.x, creature_pos.y + eye_height, creature_pos.z)


## Fraction of a fan of rays across [param to]'s silhouette (radius [param target_radius])
## blocked by [code]world_static[/code] occluders, cast from [param from] (**0..1**). This is a
## shadow-coverage test — an occluder anywhere between [param from] and the target casts a
## "shadow" that either does or doesn't cover a given silhouette sample point — not a test of how
## much of the [param from]→[param to] path's *length* passes through solid geometry. (CLEANUP
## C8 fix, 2026-08-07: the prior implementation chopped the path into 10 fixed-length buckets and
## voted per bucket, so a normally-sized wall sitting near [param from] but far from [param to]
## could only ever fill one bucket — capping occlusion at ~10% and never crossing a realistic
## blocked threshold no matter how solid the wall was.)
static func occlusion_fraction(
  space_state: PhysicsDirectSpaceState3D,
  from: Vector3,
  to: Vector3,
  exclude_rids: Array = [],
  target_radius: float = DEFAULT_TARGET_RADIUS,
) -> float:
  if space_state == null:
    return 0.0
  var dir := to - from
  var dist := dir.length()
  if dist < 0.05:
    return 0.0
  dir /= dist
  var perp_a := dir.cross(Vector3.UP)
  if perp_a.length_squared() < 1e-8:
    perp_a = dir.cross(Vector3.RIGHT)
  perp_a = perp_a.normalized()
  var perp_b := dir.cross(perp_a).normalized()
  var samples: Array[Vector3] = [to]
  for i in range(SHADOW_RING_SAMPLES):
    var ang := TAU * float(i) / float(SHADOW_RING_SAMPLES)
    samples.append(to + (perp_a * cos(ang) + perp_b * sin(ang)) * target_radius)
  var blocked := 0
  for sample in samples:
    var query := PhysicsRayQueryParameters3D.create(from, sample)
    query.collision_mask = WORLD_STATIC_MASK
    query.hit_from_inside = true
    for rid in exclude_rids:
      if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
        query.exclude.append(rid as RID)
    var hit: Dictionary = space_state.intersect_ray(query)
    if not hit.is_empty():
      blocked += 1
  return float(blocked) / float(samples.size())


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
  target_radius: float = DEFAULT_TARGET_RADIUS,
) -> Dictionary:
  var eye := eye_world_position(creature_pos, eye_height)
  var target := Vector3(target_pos.x, eye.y, target_pos.z)
  var frac := occlusion_fraction(space_state, eye, target, exclude_rids, target_radius)
  return {
    "line_of_sight_clear": not is_occluded(frac),
    "occluded": is_occluded(frac),
    "occlusion_fraction": frac,
  }
