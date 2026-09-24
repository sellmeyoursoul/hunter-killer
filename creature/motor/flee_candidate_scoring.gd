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
##
## A separation term (decision 44 follow-up A, 2026-09-24) sits beside the race margin: the race
## margin is distance-free (a near endpoint the threat is slightly farther from scores well even if
## it brings the creature closer to the threat than it stands now), so every candidate also scores
## how much farther from its nearest threat it ends up — see [method separation_gain].

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


## Distance from [param point] to the *nearest* threat in [param threat_pts] (horizontal), or INF
## with no threats. Nearest (min), not an average — decision 20's worst-case rule: the closest
## pursuer is the one that catches you.
static func min_threat_dist(point: Vector3, threat_pts: Array) -> float:
  var best := INF
  for t_v in threat_pts:
    best = minf(best, _flat_dist(t_v as Vector3, point))
  return best


## Separation gained at [param endpoint] relative to standing at [param creature_pos] (decision 44
## follow-up A, 2026-09-24): `(min_threat_dist(endpoint) − min_threat_dist(creature_pos)) / norm_dist`,
## clamped to [-1, 1]. Positive = the endpoint leaves the creature farther from its nearest threat
## than it is now; negative = it ends *closer* (walking toward the pursuer). [param norm_dist] is the
## flee distance for open/incumbent/locale candidates, and the candidate's own probed distance for
## shelter/choke beliefs (the same "equivalent full flee distance" rescale their reach gets). Returns
## 0.0 with no threats or a degenerate [param norm_dist].
## Example: creature 60u from the threat, endpoint 48u from it, norm 150 -> (48 − 60) / 150 = −0.08.
static func separation_gain(creature_pos: Vector3, endpoint: Vector3, threat_pts: Array, norm_dist: float) -> float:
  if threat_pts.is_empty() or norm_dist <= 1e-6:
    return 0.0
  var gained := min_threat_dist(endpoint, threat_pts) - min_threat_dist(creature_pos, threat_pts)
  return clampf(gained / norm_dist, -1.0, 1.0)


## Shelter exception to the separation term: true when the creature believes it wins the race to
## the shelter endpoint (worst-case race margin strictly > 0, i.e. `belief_race_factor` above its
## 0.5 toss-up value). Such a shelter is scored as a full escape (separation credited as 1.0 — the
## value a straight-away open bearing earns) instead of by the distance it leaves to the threat:
## once inside a refuge the creature reaches first, remaining distance to the pursuer is not what
## keeps it safe. Merely zeroing the term would still leave every won shelter `gain × flee_dist`
## behind straight-away open ground. Choke points do NOT get this exception.
static func shelter_race_won(margin: float) -> bool:
  return margin > 0.0


## Final candidate score in distance units: measured reach plus `flee_dist ×` (race term + the
## belief's own bonus gated by the race + `flee_separation_gain × separation`). Open bearings pass
## `belief_bonus_frac = 0`. [param separation] comes from [method separation_gain] (or 1.0 for a
## shelter the creature wins the race to, [method shelter_race_won]); default 0.0 keeps the
## pre-separation score for callers that don't supply it.
static func effective(
  reach: float,
  flee_dist: float,
  margin: float,
  belief_bonus_frac: float,
  motor_v3: Dictionary,
  separation: float = 0.0,
) -> float:
  var bonus := belief_bonus_frac * belief_race_factor(margin, motor_v3) if belief_bonus_frac > 0.0 else 0.0
  var sep_term := float(motor_v3.get("flee_separation_gain", 0.25)) * separation
  return reach + flee_dist * (race_term(margin, motor_v3) + bonus + sep_term)
