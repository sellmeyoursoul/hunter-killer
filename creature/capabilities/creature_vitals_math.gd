extends RefCounted
class_name CreatureVitalsMath
## Pure calorie math shared by 2D/3D creatures — **single definition** of burn formula.
## Params:
## - baseline_per_sec, cost_per_unit_moved: merged global defaults (e.g. from [code]GameConfig[/code]).
## - distance_moved: path length this tick in **the same units** as [param cost_per_unit_moved] (px in 2D POC, world units in 3D when tuned).
## - delta: integration step seconds.
## - baseline_mul, movement_mul: [member CreatureDefinition.calorie_baseline_drain_multiplier] and movement multiplier.

static func burn_amount(
  baseline_per_sec: float,
  cost_per_unit_moved: float,
  distance_moved: float,
  delta: float,
  baseline_mul: float = 1.0,
  movement_mul: float = 1.0,
) -> float:
  return baseline_per_sec * baseline_mul * delta + cost_per_unit_moved * movement_mul * distance_moved


static func add_food_clamped(current: float, grant: int, cap: int) -> float:
  return minf(float(cap), current + float(maxi(0, grant)))
