## Derived dominant Tier-2 leaf per tick ([CREATURE_MOVEMENT_V2.md §A.2.3](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
extends Object

const LEAF_FIND_FOOD := &"find_food"
const LEAF_AVOID_HOSTILES := &"avoid_hostiles"
const LEAF_PRESERVE := &"preserve_calories"
const LEAF_FIND_MATE := &"find_mate"


## Returns wire id for the dominant Tier-2 leaf this tick.
static func derive_dominant_tier2_leaf(
  calorie_ratio: float,
  acute_threat: bool,
  find_mate_urgency: float = 0.0,
  motor_p: Dictionary = {},
) -> StringName:
  var cr := clampf(calorie_ratio, 0.0, 1.0)
  var starvation_ceil := float(motor_p.get("starvation_override_food_ceiling", 0.10))
  var seek_ceil := float(motor_p.get("seek_priority_food_ceiling", 0.80))
  var preserve_floor := float(motor_p.get("preserve_bias_food_floor", 0.90))
  if cr < starvation_ceil:
    return LEAF_FIND_FOOD
  if acute_threat:
    return LEAF_AVOID_HOSTILES
  if cr < seek_ceil:
    return LEAF_FIND_FOOD
  if cr >= preserve_floor:
    return LEAF_PRESERVE
  if find_mate_urgency > 1e-6:
    return LEAF_FIND_MATE
  return LEAF_PRESERVE


## Multiplier for food-seek / explore weights in the Preserve-Find mid band (CREATURE_MOVEMENT_V2.md A.3.1).
## Returns 1.0 when hungry (calorie_ratio below seek_priority_food_ceiling) or under starvation override; 0.0 at preserve floor+.
static func preserve_find_food_seek_scale(calorie_ratio: float, motor_p: Dictionary) -> float:
  var cr := clampf(calorie_ratio, 0.0, 1.0)
  var starvation_ceil := float(motor_p.get("starvation_override_food_ceiling", 0.10))
  if cr < starvation_ceil:
    return 1.0
  var seek_ceil := float(motor_p.get("seek_priority_food_ceiling", 0.80))
  var preserve_floor := float(motor_p.get("preserve_bias_food_floor", 0.90))
  if cr < seek_ceil:
    return 1.0
  if cr >= preserve_floor:
    return 0.0
  var span := maxf(1e-6, preserve_floor - seek_ceil)
  var t := clampf((cr - seek_ceil) / span, 0.0, 1.0)
  var sharp := clampf(float(motor_p.get("preserve_seek_blend_smoothness", 0.5)), 0.05, 1.0)
  var blend := pow(t, 1.0 / sharp)
  return 1.0 - blend
