extends RefCounted
class_name KindProfileMemory
## Per-creature stimulus-kind facet beliefs — EWMA storage ([CREATURE_MEMORY.md §5.7](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).

const _LearnReg := preload("res://creature/memory/stimulus_learn_registry.gd")


## Returns facet [param value] for [param stimulus_kind_id], or [param neutral_prior] when unseen.
static func facet_value(
  profile: Dictionary,
  facet_key: StringName,
  stimulus_kind_id: StringName,
  neutral_prior: float,
) -> float:
  if stimulus_kind_id == &"":
    return neutral_prior
  var kind_row: Variant = profile.get(stimulus_kind_id, {})
  if typeof(kind_row) != TYPE_DICTIONARY:
    return neutral_prior
  var facet: Variant = (kind_row as Dictionary).get(facet_key, {})
  if typeof(facet) != TYPE_DICTIONARY:
    return neutral_prior
  return float((facet as Dictionary).get("value", neutral_prior))


## EWMA update for one learn-topic observation on [param profile].
static func record_observation(
  profile: Dictionary,
  topic_id: StringName,
  stimulus_kind_id: StringName,
  value: float,
  now_ms: int,
  motor_v3: Dictionary,
) -> Dictionary:
  if stimulus_kind_id == &"":
    return profile
  var facet_key := _LearnReg.facet_for_topic(topic_id)
  if facet_key == &"":
    return profile
  var alpha := float(motor_v3.get("kind_profile_ewma_alpha", motor_v3.get("locale_prior_ewma_alpha", 0.15)))
  alpha = clampf(alpha, 0.01, 1.0)
  var clamped := clampf(value, 0.0, 1.0)
  var kind_row: Dictionary = profile.get(stimulus_kind_id, {}) as Dictionary
  if kind_row.is_empty():
    kind_row = {}
  var facet: Dictionary = kind_row.get(facet_key, {}) as Dictionary
  if facet.is_empty():
    facet = {"value": clamped, "sample_count": 0, "last_updated_ms": now_ms}
  var prev := float(facet.get("value", clamped))
  facet["value"] = lerpf(prev, clamped, alpha)
  facet["sample_count"] = int(facet.get("sample_count", 0)) + 1
  facet["last_updated_ms"] = now_ms
  kind_row[facet_key] = facet
  profile[stimulus_kind_id] = kind_row
  return profile


## Maps EAT [param calories_gained] to a 0…1 [code]nutrition_yield[/code] observation (§5.7).
## Uses per-bite reference calories — not creature caloric_needs — so a full bush bite scores high.
static func nutrition_yield_observation(
  calories_gained: int,
  insufficient_yield: bool,
  motor_v3: Dictionary,
) -> float:
  var ref := maxf(1.0, float(motor_v3.get("kind_nutrition_yield_reference_calories", 5.0)))
  var bite := clampf(float(calories_gained) / ref, 0.0, 1.0)
  if insufficient_yield:
    return clampf(bite * 0.5, 0.0, 0.5)
  return bite


## Shallow copy of the profile table.
static func duplicate_profile(profile: Dictionary) -> Dictionary:
  return profile.duplicate(true)
