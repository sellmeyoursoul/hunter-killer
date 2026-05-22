## Trait → Tier-2 urgency channels ([CREATURE_GOAL_DRIVERS.md §3.3.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)). Phase-1 stub: zero deltas.
extends Object


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
