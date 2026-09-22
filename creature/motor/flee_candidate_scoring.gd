extends RefCounted
class_name FleeCandidateScoring
## Shared flee-candidate scoring math — PHYSICS_SQUEEZE.md decision 20 (§9 slice 9). Pure functions;
## `MotorPlanner._mint_flee_waypoint` owns candidate generation and feeds these.
##
## One "race margin" scores every candidate the same way (open bearings and shelter/choke beliefs
## alike): how much farther the threat is from the candidate point than the fleeing creature is,
## as a scale-free ratio. Explicitly equal-speed, pure-distance (decision 20's
## deliberately deferred refinement — no speed/cornering yet). Multiple threats aggregate by the
## *worst* (most dangerous) margin, not a sum or average: being caught by any one pursuer is the
## failure condition.

## Horizontal (XZ) threat positions for every `in_awareness` sample. Samples carry either
## `world_pos_3d` or the legacy 2D `world_pos`.
static func threat_positions(samples: Array, creature_pos: Vector3) -> Array:
  var out: Array = []
  for s_v in samples:
    if typeof(s_v) != TYPE_DICTIONARY:
      continue
    var s: Dictionary = s_v
    if not bool(s.get("in_awareness", false)):
      continue
    if s.has("world_pos_3d"):
      out.append(s["world_pos_3d"])
    else:
      var wp: Vector2 = s.get("world_pos", Vector2.ZERO)
      out.append(Vector3(wp.x, creature_pos.y, wp.y))
  return out


## Threat's body radius, or 0.0 when unknown. A sample's own `capsule_radius` wins (test hook, and
## the seam where slice 10's held/noised estimate — decisions 8d/18 — will plug in); otherwise the
## live body behind `instance_id` is read directly. Ground truth for now: no composure noise or
## hysteresis yet.
static func threat_capsule_radius(sample: Dictionary) -> float:
  if sample.has("capsule_radius"):
    return maxf(0.0, float(sample["capsule_radius"]))
  var iid := int(sample.get("instance_id", 0))
  if iid == 0:
    return 0.0
  var node := instance_from_id(iid)
  if node != null and node.has_method(&"get_collision_capsule_radius"):
    return maxf(0.0, float(node.call(&"get_collision_capsule_radius")))
  return 0.0


## Threat's body height, or 0.0 when unknown — same source precedence as `threat_capsule_radius`
## (test hook via `capsule_height`, else the live body behind `instance_id`). Used alongside the
## radius wherever a threat's capsule needs to be shape-cast (decision 23, §9 slice 10).
static func threat_capsule_height(sample: Dictionary) -> float:
  if sample.has("capsule_height"):
    return maxf(0.0, float(sample["capsule_height"]))
  var iid := int(sample.get("instance_id", 0))
  if iid == 0:
    return 0.0
  var node := instance_from_id(iid)
  if node != null and node.has_method(&"get_collision_capsule_height"):
    return maxf(0.0, float(node.call(&"get_collision_capsule_height")))
  return 0.0


static func _flat_dist(a: Vector3, b: Vector3) -> float:
  return Vector2(a.x - b.x, a.z - b.z).length()


## Worst-case race margin at [param point]: `min over threats of (d_threat − d_self) /
## (d_threat + d_self)`, where each d is the straight-line distance to [param point]. A scale-free
## ratio in [-1, 1] — +1 = the creature is essentially already there, 0 = dead heat, -1 = the threat
## is already there — so a shelter 10 units away reads the same in a tiny test arena and a huge real
## one (normalizing by the flee distance instead made every nearby candidate's margin ≈ 0). Positive
## = creature gets there first. Returns 0.0 (a neutral toss-up) with no threats.
static func race_margin(creature_pos: Vector3, point: Vector3, threat_pts: Array) -> float:
  if threat_pts.is_empty():
    return 0.0
  var d_self := _flat_dist(creature_pos, point)
  var worst := INF
  for t_v in threat_pts:
    var d_t := _flat_dist(t_v as Vector3, point)
    var denom := d_t + d_self
    var m := 0.0 if denom < 1e-6 else (d_t - d_self) / denom
    worst = minf(worst, m)
  return worst


## Bonus/penalty as a fraction of flee distance, monotone in [param margin]: clearly favorable →
## large bonus, a toss-up → near zero, losing → zero, clearly losing → negative (discourages
## committing to a path that's already lost). Linear between `-cap` and `+cap` at `gain` slope;
## exact shape is tuning, not decided (decision 20).
static func race_term(margin: float, motor_v3: Dictionary) -> float:
  var cap := maxf(1e-6, float(motor_v3.get("flee_race_margin_cap", 0.5)))
  var gain := float(motor_v3.get("flee_race_margin_gain", 0.6))
  return clampf(margin, -cap, cap) * gain


## 0..1 gate on a belief's own bonus by how the race is going: full when clearly winning, half at a
## toss-up (attempting one isn't punished), zero when clearly losing. Bonus, not override.
static func belief_race_factor(margin: float, motor_v3: Dictionary) -> float:
  var cap := maxf(1e-6, float(motor_v3.get("flee_race_margin_cap", 0.5)))
  return clampf(0.5 + margin / (2.0 * cap), 0.0, 1.0)


## Whether a stored choke point is worth fleeing to: the creature fits
## (`opening_width >= own_diameter`) and every considered threat is *known* not to
## (`opening_width < threat_diameter`). A threat of unknown size disqualifies it — no protective
## claim without a size to compare. A gap both fit through is just open ground, already covered by
## the open bearings.
static func choke_useful(opening_width: float, own_diameter: float, threat_diameters: Array) -> bool:
  if threat_diameters.is_empty() or opening_width < own_diameter:
    return false
  for d_v in threat_diameters:
    var d := float(d_v)
    if d <= 0.0 or opening_width >= d:
      return false
  return true


## Final candidate score in distance units: measured reach plus `flee_dist ×` (race term + the
## belief's own bonus gated by the race). Open bearings pass `belief_bonus_frac = 0`.
static func effective(
  reach: float,
  flee_dist: float,
  margin: float,
  belief_bonus_frac: float,
  motor_v3: Dictionary,
) -> float:
  var bonus := belief_bonus_frac * belief_race_factor(margin, motor_v3) if belief_bonus_frac > 0.0 else 0.0
  return reach + flee_dist * (race_term(margin, motor_v3) + bonus)
