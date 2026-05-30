## Trait → Tier-2 urgency channels ([CREATURE_GOAL_DRIVERS.md §3.3.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
## Phase-1 stub: trait deltas are zero; base urgency comes from dominant Tier-2 leaf.
extends Object

const _Tier2Dom := preload("res://creature/motor/tier2_dominance.gd")


class Tier2UrgencyChannels:
  var urgency_avoid_hostiles: float = 0.0
  var urgency_find_food: float = 0.0
  var urgency_find_mate: float = 0.0
  var urgency_preserve_calories: float = 0.0


static func channels_from_dict(d: Dictionary) -> Tier2UrgencyChannels:
  var c := Tier2UrgencyChannels.new()
  c.urgency_avoid_hostiles = float(d.get("urgency_avoid_hostiles", 0.0))
  c.urgency_find_food = float(d.get("urgency_find_food", 0.0))
  c.urgency_find_mate = float(d.get("urgency_find_mate", 0.0))
  c.urgency_preserve_calories = float(d.get("urgency_preserve_calories", 0.0))
  return c


static func channels_to_dict(c: Tier2UrgencyChannels) -> Dictionary:
  return {
    "urgency_avoid_hostiles": c.urgency_avoid_hostiles,
    "urgency_find_food": c.urgency_find_food,
    "urgency_find_mate": c.urgency_find_mate,
    "urgency_preserve_calories": c.urgency_preserve_calories,
  }


## Builds baseline urgency from the derived dominant Tier-2 leaf (phase-1: unit weight on active leaf).
static func base_urgency_channels_from_dominant(
  dominant_tier2_leaf: StringName, _motor_p: Dictionary = {}
) -> Tier2UrgencyChannels:
  var c := Tier2UrgencyChannels.new()
  if dominant_tier2_leaf == _Tier2Dom.LEAF_FIND_FOOD:
    c.urgency_find_food = 1.0
  elif dominant_tier2_leaf == _Tier2Dom.LEAF_AVOID_HOSTILES:
    c.urgency_avoid_hostiles = 1.0
  elif dominant_tier2_leaf == _Tier2Dom.LEAF_PRESERVE:
    c.urgency_preserve_calories = 1.0
  elif dominant_tier2_leaf == _Tier2Dom.LEAF_FIND_MATE:
    c.urgency_find_mate = 1.0
  else:
    c.urgency_preserve_calories = 1.0
  return c


## Phase-1 stub: returns [param base] unchanged.
static func apply_trait_urgency_channels(
  base: Tier2UrgencyChannels,
  _traits: Variant,
  _motor_p: Dictionary,
) -> Tier2UrgencyChannels:
  var out := Tier2UrgencyChannels.new()
  out.urgency_avoid_hostiles = base.urgency_avoid_hostiles
  out.urgency_find_food = base.urgency_find_food
  out.urgency_find_mate = base.urgency_find_mate
  out.urgency_preserve_calories = base.urgency_preserve_calories
  return out
