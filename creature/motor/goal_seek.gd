## Dominant Tier-2 → [code]goal_seek_targets[/code] / [code]weight_seek_goal[/code] ([CREATURE_MOVEMENT_V2.md §A.2.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
extends Object

const _Tier2 := preload("res://creature/motor/tier2_dominance.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _SeekCand := preload("res://creature/motor/seek_candidate.gd")


## Filters ingress candidates and picks seek weight for cardinal linear pull.
## Params:
## - dom_leaf: [method tier2_dominance.derive_dominant_tier2_leaf] wire id.
## - candidates: [method seek_candidate.build_from_motor_ingress] array.
## - w_seek_food: Scaled [code]weight_seek_ready_food[/code] (plants + remembered ready).
## - w_seek_prey: Scaled [code]weight_seek_prey[/code] (carnivore live prey).
## Returns:
## - [code]goal_seek_targets[/code] ([code]Vector3[][/code]), [code]weight_seek_goal[/code], [code]seek_candidates[/code] (filtered).
static func resolve_for_dominant_leaf(
  dom_leaf: StringName,
  candidates: Array,
  w_seek_food: float,
  w_seek_prey: float,
) -> Dictionary:
  var positions: Array = []
  var weight := 0.0
  var filtered: Array = []
  if dom_leaf == _Tier2.LEAF_FIND_FOOD:
    var prey_positions := _SeekCand.positions_matching(
      candidates, _GkReg.GK_FIND_FOOD, true
    )
    var has_prey := false
    for c in candidates:
      if typeof(c) != TYPE_DICTIONARY:
        continue
      if (c as Dictionary).get("source", &"") == _SeekCand.SOURCE_LIVE_PREY:
        has_prey = true
        break
    if has_prey and w_seek_prey > 0.0:
      positions = prey_positions
      weight = w_seek_prey
      for c in candidates:
        if typeof(c) != TYPE_DICTIONARY:
          continue
        var row: Dictionary = c as Dictionary
        if row.get("source", &"") == _SeekCand.SOURCE_LIVE_PREY:
          filtered.append(row)
    elif w_seek_food > 0.0:
      for c in candidates:
        if typeof(c) != TYPE_DICTIONARY:
          continue
        var row2: Dictionary = c as Dictionary
        if row2.get("source", &"") == _SeekCand.SOURCE_LIVE_PREY:
          continue
        if (
          row2.get("goal_kind", &"") == _GkReg.GK_FIND_FOOD
          and bool(row2.get("consumable_now", true))
        ):
          var p: Variant = row2.get("pos", null)
          if typeof(p) == TYPE_VECTOR3:
            positions.append(p as Vector3)
          filtered.append(row2)
      weight = w_seek_food
  return {
    "goal_seek_targets": positions,
    "weight_seek_goal": weight,
    "seek_candidates": filtered,
  }


## Reads [code]weight_seek_goal[/code] from motor params with fallback to [code]weight_seek_ready_food[/code].
static func base_weight_seek_goal(motor_p: Dictionary) -> float:
  if motor_p.has("weight_seek_goal"):
    return float(motor_p.get("weight_seek_goal", 0.0))
  return float(motor_p.get("weight_seek_ready_food", 0.0))
