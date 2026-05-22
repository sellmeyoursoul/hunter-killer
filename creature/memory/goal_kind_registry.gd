## Core [code]GoalKind[/code] registry + pack merge ([CREATURE_GOAL_DRIVERS.md §4.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
extends Object

const GK_FIND_FOOD := &"find_food"
const GK_AVOID_HOSTILES := &"avoid_hostiles"
const GK_SHELTER := &"shelter"
const GK_FIND_MATE := &"find_mate"

const _PackRes := preload("res://pack_resource_resolver.gd")


static func core_goal_kinds() -> Array:
  return [GK_FIND_FOOD, GK_AVOID_HOSTILES, GK_SHELTER, GK_FIND_MATE]


## Merges pack [code]goal_kinds.extra_goal_kinds[][/code] into core ids.
static func effective_goal_kinds_for_pack(pack_root: String) -> Array:
  var out: Array = []
  var seen: Dictionary = {}
  for g in core_goal_kinds():
    var sn := StringName(g)
    if not seen.has(sn):
      seen[sn] = true
      out.append(sn)
  var root := _PackRes.load_pack_root(pack_root)
  var gk: Variant = root.get("goal_kinds", {})
  if typeof(gk) != TYPE_DICTIONARY:
    return out
  var extras: Variant = (gk as Dictionary).get("extra_goal_kinds", [])
  if typeof(extras) != TYPE_ARRAY:
    return out
  for entry in extras as Array:
    if typeof(entry) != TYPE_DICTIONARY:
      continue
    var id_raw: Variant = (entry as Dictionary).get("id", "")
    var id_sn := StringName(str(id_raw).strip_edges())
    if id_sn == &"" or seen.has(id_sn):
      continue
    for core in core_goal_kinds():
      if id_sn == core:
        push_error("goal_kind_registry: pack extra collides with core id %s" % str(id_sn))
        continue
    seen[id_sn] = true
    out.append(id_sn)
  return out


static func validate_goal_kind(goal_kind: StringName, effective_goal_kinds: Array) -> bool:
  if goal_kind == &"":
    return false
  for g in effective_goal_kinds:
    if g == goal_kind:
      return true
  return false


## Dominant Tier-2 leaf wire id → default salient [code]GoalKind[/code] at outcome.
static func tier2_to_default_goal_kind(dominant_tier2: StringName) -> StringName:
  match dominant_tier2:
    &"find_food":
      return GK_FIND_FOOD
    &"avoid_hostiles":
      return GK_AVOID_HOSTILES
    &"find_mate":
      return GK_FIND_MATE
    _:
      return &""
