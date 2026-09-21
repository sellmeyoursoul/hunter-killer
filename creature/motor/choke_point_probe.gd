extends RefCounted
class_name ChokePointProbe
## Producer-side geometry for choke-point beliefs (PHYSICS_SQUEEZE.md decision 19, §9 slice 8's
## producer follow-up). Measures the lateral opening at a point by casting a ray to each side of a
## heading against terrain + the ghost object layer, and turns a noisy remote reading into an
## `observed` estimate. Pure functions — [ChokePointTracker] owns the stateful "did the creature
## actually pass through" logic, and `CreatureMotorStack` wires both into `MemoryAdapter`.

const _GhostObstacleQuery := preload("res://creature/motor/ghost_obstacle_query.gd")
const _StatMath := preload("res://creature/stat_math.gd")

## Terrain (layer 1) + ghost object layer — everything a body's width can be squeezed between.
const BLOCKER_MASK := 1 | _GhostObstacleQuery.GHOST_LAYER_MASK


## Lateral opening at [param at] perpendicular to [param heading]. `bounded` is true only when
## *both* sides hit something within [param max_half] — one open side means it's not a gap, just a
## wall (or open ground). `width` = left + right clearance from the centerline (both clamped to
## [param max_half] when unbounded, so `width` is then only meaningful as "at least this wide").
static func measure_width(
  space_state: PhysicsDirectSpaceState3D,
  at: Vector3,
  heading: Vector3,
  max_half: float,
  exclude_rids: Array = [],
  mask: int = BLOCKER_MASK,
) -> Dictionary:
  var out := {"left": max_half, "right": max_half, "width": max_half * 2.0, "bounded": false}
  if space_state == null or max_half <= 0.0:
    return out
  var flat := Vector3(heading.x, 0.0, heading.z)
  if flat.length_squared() < 1e-8:
    return out
  var lateral := flat.normalized().cross(Vector3.UP).normalized()
  var left := _side_clearance(space_state, at, lateral, max_half, exclude_rids, mask)
  var right := _side_clearance(space_state, at, -lateral, max_half, exclude_rids, mask)
  out["left"] = left
  out["right"] = right
  out["width"] = left + right
  out["bounded"] = left < max_half and right < max_half
  return out


static func _side_clearance(
  space_state: PhysicsDirectSpaceState3D,
  at: Vector3,
  dir: Vector3,
  max_half: float,
  exclude_rids: Array,
  mask: int,
) -> float:
  var query := PhysicsRayQueryParameters3D.create(at, at + dir * max_half, mask)
  for rid in exclude_rids:
    if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
      query.exclude.append(rid as RID)
  var hit := space_state.intersect_ray(query)
  if hit.is_empty():
    return max_half
  return at.distance_to(hit.position as Vector3)


## `stat_observation`-scaled noise fraction for a remote width estimate — same three-peg shape as
## the food-yield estimate noise (`MotorPlanner._food_yield_estimate_noise_frac`), separate keys.
static func observe_noise_frac(stat_observation: int, motor_v3: Dictionary) -> float:
  var v1 := float(motor_v3.get("choke_observe_noise_frac_v1", 0.4))
  var v10 := float(motor_v3.get("choke_observe_noise_frac_v10", 0.15))
  var v25 := float(motor_v3.get("choke_observe_noise_frac_v25", 0.03))
  return maxf(0.0, _StatMath.peg_curve(stat_observation, v1, v10, v25))


## Remote sighting: measures the opening [param lookahead] ahead of [param pos] along
## [param heading] and degrades it by observation noise. Returns `{}` when there is no bounded gap
## there, otherwise `{mouth, est_width, weight}` — [param weight] (0..1) shrinks with noise and
## with how far away the look was, so a distant guess never outranks a close one (decision 19).
## [param max_look] is the farthest a look is ever taken; [param lookahead] is this one.
static func observe_ahead(
  space_state: PhysicsDirectSpaceState3D,
  pos: Vector3,
  heading: Vector3,
  lookahead: float,
  max_look: float,
  max_half: float,
  stat_observation: int,
  motor_v3: Dictionary,
  exclude_rids: Array = [],
) -> Dictionary:
  var flat := Vector3(heading.x, 0.0, heading.z)
  if flat.length_squared() < 1e-8 or lookahead <= 0.0:
    return {}
  var mouth := pos + flat.normalized() * lookahead
  var m := measure_width(space_state, mouth, heading, max_half, exclude_rids)
  if not bool(m.get("bounded", false)):
    return {}
  var frac := observe_noise_frac(stat_observation, motor_v3)
  var width := float(m["width"])
  if frac > 0.0:
    width *= 1.0 + randf_range(-frac, frac)
  var dist_ratio := clampf(lookahead / maxf(max_look, 1e-6), 0.0, 1.0)
  var weight := clampf((1.0 - frac) * lerpf(1.0, 0.5, dist_ratio), 0.0, 1.0)
  return {"mouth": mouth, "est_width": maxf(width, 0.0), "weight": weight}
