extends RefCounted
class_name ThreatDisposition
## Per-creature Flight skittishness — read/write + episode nudges ([CREATURE_MOVEMENT_V3.md §1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const DEFAULT_MOD := 1.0


## Clamps [param value] to [code]flight_disposition_mod_min[/code]…[code]max[/code] in [param motor_v3].
static func clamp_mod(value: float, motor_v3: Dictionary) -> float:
  var lo := float(motor_v3.get("flight_disposition_mod_min", 0.4))
  var hi := float(motor_v3.get("flight_disposition_mod_max", 1.2))
  return clampf(value, lo, hi)


## Applies signed [param delta] to [param current_mod] with clamping.
static func nudge(current_mod: float, delta: float, motor_v3: Dictionary) -> float:
  return clamp_mod(current_mod + delta, motor_v3)


## True when any in-zone threat sample has sub-acute [code]urgency_dist < 1[/code] (§1 benign exposure).
static func has_subacute_threat(threat_samples: Array, motor_v3: Dictionary) -> bool:
  for sample_v in threat_samples:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    if not bool(sample.get("hostile", true)):
      continue
    var urgency_dist := _urgency_dist_for_sample(sample, motor_v3)
    if urgency_dist < 1.0 - 1e-4:
      return true
  return false


## True when any in-zone hostile threat sample is present.
static func has_in_zone_threat(threat_samples: Array) -> bool:
  for sample_v in threat_samples:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if bool(sample.get("in_awareness", false)) and bool(sample.get("hostile", true)):
      return true
  return false


## Episode tick — returns benign/evade deltas to apply (0 when no nudge).
static func episode_deltas(
  threat_samples: Array,
  flight_fast_path_active: bool,
  was_flight_fast_path: bool,
  benign_episode_pending: bool,
  motor_v3: Dictionary,
) -> Dictionary:
  var benign_delta := 0.0
  var evade_delta := 0.0
  var next_pending := benign_episode_pending

  if flight_fast_path_active:
    next_pending = false
    if not was_flight_fast_path:
      evade_delta = float(motor_v3.get("flight_disposition_evade_delta", 0.08))
  elif was_flight_fast_path and not has_in_zone_threat(threat_samples):
    evade_delta = float(motor_v3.get("flight_disposition_evade_delta", 0.08))
  elif has_subacute_threat(threat_samples, motor_v3):
    next_pending = true
  elif benign_episode_pending and not has_in_zone_threat(threat_samples):
    benign_delta = float(motor_v3.get("flight_disposition_benign_delta", -0.05))
    next_pending = false

  return {
    "benign_delta": benign_delta,
    "evade_delta": evade_delta,
    "benign_episode_pending": next_pending,
  }


## Distance-only Flight urgency for one threat sample (§1 geometry curve).
static func _urgency_dist_for_sample(sample: Dictionary, motor_v3: Dictionary) -> float:
  var gate_dist := float(sample.get("gate_dist", INF))
  var eff_reach := _effective_awareness_reach(sample, motor_v3)
  var area_radius := float(motor_v3.get("awareness_radius", eff_reach))
  var dist_floor := float(motor_v3.get("flight_urgency_dist_floor", 1.0))
  var far_floor := float(motor_v3.get("flight_urgency_far_floor", 0.5))
  var denom := maxf(dist_floor, eff_reach - area_radius)
  var t := clampf((eff_reach - gate_dist) / denom, 0.0, 1.0)
  return lerpf(far_floor, 1.0, t)


static func _effective_awareness_reach(sample: Dictionary, motor_v3: Dictionary) -> float:
  var sample_reach: Variant = sample.get("eff_reach", null)
  if sample_reach != null:
    return maxf(0.0, float(sample_reach))
  return float(motor_v3.get("awareness_radius", 1500.0))
