extends RefCounted
class_name MotorGoalHub
## V3 goal hub — eligibility, scoring, winner selection ([CREATURE_MOVEMENT_V3.md §1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")

const GOAL_FIND_FOOD := _GkReg.GK_FIND_FOOD
const GOAL_AVOID_HOSTILES := _GkReg.GK_AVOID_HOSTILES
const GOAL_SHELTER := _GkReg.GK_SHELTER
const GOAL_REST := &"rest"

const _REST_CALORIE_FLOOR := 0.95
const _NEUTRAL_KIND_THREAT := 0.5


## Builds eligible hub rows per §1 matrix; Mate omitted until §6.5.
static func build_eligible_goals(ctx: Dictionary) -> Array[Dictionary]:
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  var cr := clampf(float(ctx.get("calorie_ratio", 1.0)), 0.0, 1.0)
  var starvation_ceil := float(motor_v3.get("starvation_override_food_ceiling", 0.10))
  var seek_ceil := float(motor_v3.get("seek_priority_food_ceiling", 0.80))
  var threat_samples: Array = _threat_samples(ctx)
  var flight_fast_path := bool(ctx.get("flight_fast_path_active", false))
  var out: Array[Dictionary] = []

  if flight_fast_path:
    return out

  if cr < starvation_ceil:
    out.append(_goal_row(GOAL_FIND_FOOD, motor_v3))
    return out

  out.append(_goal_row(GOAL_FIND_FOOD, motor_v3))
  if not threat_samples.is_empty():
    out.append(_goal_row(GOAL_AVOID_HOSTILES, motor_v3))
  if cr >= seek_ceil:
    out.append(_goal_row(GOAL_SHELTER, motor_v3))
  if cr >= _REST_CALORIE_FLOOR and bool(ctx.get("safety_met", false)):
    out.append(_goal_row(GOAL_REST, motor_v3))
  return out


## Scores eligible rows: [code]weight = effective_base × urgency × (feasibility_floor + feasibility) × trait_goal_mul[/code].
static func score_goals(eligible: Array, ctx: Dictionary) -> Array:
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  var cr := clampf(float(ctx.get("calorie_ratio", 1.0)), 0.0, 1.0)
  var threat_samples: Array = _threat_samples(ctx)
  var scored: Array = []
  for row_v in eligible:
    if typeof(row_v) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = (row_v as Dictionary).duplicate(true)
    var goal_kind: StringName = row.get("goal_kind", &"")
    var effective_base := _effective_base(goal_kind, motor_v3, ctx)
    var urgency := _urgency_for_goal(goal_kind, cr, threat_samples, motor_v3)
    var floor_key := _feasibility_floor_key(goal_kind)
    var feasibility_floor := float(motor_v3.get(floor_key, 0.05))
    var feasibility := float(row.get("feasibility", 0.0))
    var trait_goal_mul := 1.0
    row["weight"] = (
      effective_base
      * urgency
      * (feasibility_floor + feasibility)
      * trait_goal_mul
    )
    row["urgency"] = urgency
    row["effective_base"] = effective_base
    scored.append(row)
  return scored


## Eat urgency — preserve band smoothstep ([CREATURE_MOVEMENT_V3.md §1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
static func urgency_eat(calorie_ratio: float, motor_v3: Dictionary) -> float:
  var cr := clampf(calorie_ratio, 0.0, 1.0)
  var starvation_ceil := float(motor_v3.get("starvation_override_food_ceiling", 0.10))
  var seek_ceil := float(motor_v3.get("seek_priority_food_ceiling", 0.80))
  var preserve_floor := float(motor_v3.get("preserve_bias_food_floor", 0.90))
  var smoothness := clampf(float(motor_v3.get("preserve_seek_blend_smoothness", 0.5)), 0.001, 1.0)
  if cr < starvation_ceil or cr < seek_ceil:
    return 1.0
  if cr >= preserve_floor:
    return 0.0
  var band := maxf(1e-6, preserve_floor - seek_ceil)
  var t := clampf((preserve_floor - cr) / band, 0.0, 1.0)
  if smoothness >= 0.999:
    return t
  return smoothstep(0.0, 1.0, pow(t, 1.0 / smoothness))


## Flight urgency geometry — max over in-zone threat samples ([CREATURE_MOVEMENT_V3.md §1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
static func urgency_flight(threat_samples: Array, motor_v3: Dictionary) -> float:
  var best := 0.0
  for sample_v in threat_samples:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    if not bool(sample.get("hostile", true)):
      continue
    var gate_dist := float(sample.get("gate_dist", INF))
    var eff_reach := _effective_awareness_reach(sample, motor_v3)
    var area_radius := float(motor_v3.get("awareness_radius", eff_reach))
    var dist_floor := float(motor_v3.get("flight_urgency_dist_floor", 1.0))
    var far_floor := float(motor_v3.get("flight_urgency_far_floor", 0.5))
    var denom := maxf(dist_floor, eff_reach - area_radius)
    var t := clampf((eff_reach - gate_dist) / denom, 0.0, 1.0)
    var urgency_dist := lerpf(far_floor, 1.0, t)
    var kind_threat := _NEUTRAL_KIND_THREAT
    var threat_disposition_mod := 1.0
    var relative_threat_mod := 1.0
    var sample_urgency := clampf(
      urgency_dist * kind_threat * threat_disposition_mod * relative_threat_mod,
      0.0,
      1.0,
    )
    best = maxf(best, sample_urgency)
  return best


## Winner = max [code]weight[/code]; [code]goal_consideration_chaos[/code] breaks near-ties.
static func pick_winner(scored: Array, motor_v3: Dictionary) -> Dictionary:
  if scored.is_empty():
    return {}
  var chaos := clampf(float(motor_v3.get("goal_consideration_chaos", 0.15)), 0.0, 1.0)
  var best_idx := 0
  var best_weight := -INF
  for i in scored.size():
    var row: Dictionary = scored[i]
    var w := float(row.get("weight", 0.0))
    if w > best_weight:
      best_weight = w
      best_idx = i
  if chaos > 0.0 and scored.size() > 1:
    var tied: Array[int] = [best_idx]
    for i in scored.size():
      if i == best_idx:
        continue
      var w := float((scored[i] as Dictionary).get("weight", 0.0))
      var eps := chaos * maxf(abs(best_weight), 1e-6)
      if abs(w - best_weight) <= eps:
        tied.append(i)
    if tied.size() > 1:
      best_idx = tied[randi() % tied.size()]
  return (scored[best_idx] as Dictionary).duplicate(true)


static func _goal_row(goal_kind: StringName, motor_v3: Dictionary) -> Dictionary:
  return {
    "goal_kind": goal_kind,
    "feasibility": 0.0,
    "step_chain": [],
    "step_index": 0,
    "source": &"stub",
    "weight": 0.0,
  }


static func _threat_samples(ctx: Dictionary) -> Array:
  var samples: Variant = ctx.get("threat_samples", [])
  return samples if typeof(samples) == TYPE_ARRAY else []


static func _effective_base(goal_kind: StringName, motor_v3: Dictionary, ctx: Dictionary) -> float:
  match goal_kind:
    GOAL_FIND_FOOD:
      return float(motor_v3.get("goal_base_find_food", 1.0))
    GOAL_AVOID_HOSTILES:
      return float(motor_v3.get("goal_base_avoid_hostiles", 1.0))
    GOAL_SHELTER:
      var base := float(motor_v3.get("goal_base_shelter", 0.5))
      var confidence := float(ctx.get("food_map_confidence", motor_v3.get("food_map_confidence", 0.0)))
      return base * clampf(confidence, 0.0, 1.0)
    GOAL_REST:
      return float(motor_v3.get("goal_base_rest", 0.85))
    _:
      return 0.0


static func _feasibility_floor_key(goal_kind: StringName) -> String:
  match goal_kind:
    GOAL_FIND_FOOD:
      return "goal_feasibility_floor_find_food"
    GOAL_AVOID_HOSTILES:
      return "goal_feasibility_floor_avoid_hostiles"
    GOAL_SHELTER:
      return "goal_feasibility_floor_shelter"
    GOAL_REST:
      return "goal_feasibility_floor_rest"
    _:
      return "goal_feasibility_floor_find_food"


static func _urgency_for_goal(
  goal_kind: StringName,
  calorie_ratio: float,
  threat_samples: Array,
  motor_v3: Dictionary,
) -> float:
  match goal_kind:
    GOAL_FIND_FOOD:
      return urgency_eat(calorie_ratio, motor_v3)
    GOAL_AVOID_HOSTILES:
      return urgency_flight(threat_samples, motor_v3)
    GOAL_SHELTER:
      return 1.0
    GOAL_REST:
      return 1.0
    _:
      return 0.0


static func _effective_awareness_reach(_sample: Dictionary, motor_v3: Dictionary) -> float:
  var sample_reach: Variant = _sample.get("eff_reach", null)
  if sample_reach != null:
    return maxf(0.0, float(sample_reach))
  return float(motor_v3.get("awareness_radius", 1500.0))
