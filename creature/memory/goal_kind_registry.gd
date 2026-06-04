## Core [code]GoalKind[/code] registry + pack merge ([CREATURE_GOAL_DRIVERS.md §4.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
class_name GoalKindRegistry
extends Object

const GK_FIND_FOOD := &"find_food"
const GK_AVOID_HOSTILES := &"avoid_hostiles"
const GK_SHELTER := &"shelter"
const GK_FIND_MATE := &"find_mate"

const PARENT_FIND_FOOD := &"find_food"
const PARENT_AVOID_HOSTILES := &"avoid_hostiles"
const PARENT_FIND_MATE := &"find_mate"
const PARENT_PRESERVE := &"preserve_calories"

const _PackRes := preload("res://pack_resource_resolver.gd")

const _VALID_PARENT_TIER2: Array[StringName] = [
  PARENT_FIND_FOOD,
  PARENT_AVOID_HOSTILES,
  PARENT_FIND_MATE,
  PARENT_PRESERVE,
]


static func core_goal_kinds() -> Array:
  return [GK_FIND_FOOD, GK_AVOID_HOSTILES, GK_SHELTER, GK_FIND_MATE]


static func _core_catalog_entries() -> Dictionary:
  return {
    GK_FIND_FOOD: {
      "parent_tier2": PARENT_FIND_FOOD,
      "salient_writes": true,
      "context_overlay": &"grid_cell",
    },
    GK_AVOID_HOSTILES: {
      "parent_tier2": PARENT_AVOID_HOSTILES,
      "salient_writes": true,
      "context_overlay": &"grid_cell",
    },
    GK_SHELTER: {
      "parent_tier2": PARENT_AVOID_HOSTILES,
      "salient_writes": false,
      "context_overlay": &"squeeze_fingerprint",
    },
    GK_FIND_MATE: {
      "parent_tier2": PARENT_FIND_MATE,
      "salient_writes": false,
      "context_overlay": &"",
    },
  }


static func _parent_tier2_valid(sn: StringName) -> bool:
  return sn in _VALID_PARENT_TIER2


## Per-[code]GoalKind[/code] metadata: [code]parent_tier2[/code], [code]salient_writes[/code], [code]context_overlay[/code].
static func goal_kind_catalog_for_pack(pack_root: String) -> Dictionary:
  var catalog: Dictionary = _core_catalog_entries().duplicate(true)
  var seen: Dictionary = {}
  for g in core_goal_kinds():
    seen[g] = true
  var root := _PackRes.load_pack_root(pack_root)
  var gk: Variant = root.get("goal_kinds", {})
  if typeof(gk) != TYPE_DICTIONARY:
    return catalog
  var extras: Variant = (gk as Dictionary).get("extra_goal_kinds", [])
  if typeof(extras) != TYPE_ARRAY:
    return catalog
  for entry in extras as Array:
    if typeof(entry) != TYPE_DICTIONARY:
      continue
    var d: Dictionary = entry as Dictionary
    var id_sn := StringName(str(d.get("id", "")).strip_edges())
    if id_sn == &"" or seen.has(id_sn):
      continue
    for core in core_goal_kinds():
      if id_sn == core:
        push_error("goal_kind_registry: pack extra collides with core id %s" % str(id_sn))
        continue
    var parent := StringName(str(d.get("parent_tier2", "")).strip_edges())
    if not _parent_tier2_valid(parent):
      push_error(
        "goal_kind_registry: skip extra %s — invalid parent_tier2 %s"
        % [str(id_sn), str(parent)]
      )
      continue
    seen[id_sn] = true
    var salient := true
    if d.has("salient_writes"):
      salient = bool(d.get("salient_writes", true))
    var overlay := StringName(str(d.get("context_overlay", "")).strip_edges())
    catalog[id_sn] = {
      "parent_tier2": parent,
      "salient_writes": salient,
      "context_overlay": overlay,
    }
  return catalog


## Merges pack [code]goal_kinds.extra_goal_kinds[][/code] into core ids.
static func effective_goal_kinds_for_pack(pack_root: String) -> Array:
  var out: Array = []
  var catalog := goal_kind_catalog_for_pack(pack_root)
  for g in core_goal_kinds():
    if catalog.has(g):
      out.append(g)
  var extras_sorted: Array = []
  for k in catalog.keys():
    var sn := k as StringName
    if sn in core_goal_kinds():
      continue
    extras_sorted.append(sn)
  extras_sorted.sort()
  for e in extras_sorted:
    out.append(e)
  return out


static func validate_goal_kind(goal_kind: StringName, effective_goal_kinds: Array) -> bool:
  if goal_kind == &"":
    return false
  for g in effective_goal_kinds:
    if g == goal_kind:
      return true
  return false


static func parent_tier2_for_goal_kind(goal_kind: StringName, catalog: Dictionary) -> StringName:
  if typeof(catalog) != TYPE_DICTIONARY or not catalog.has(goal_kind):
    return &""
  return catalog[goal_kind].get("parent_tier2", &"") as StringName


static func salient_writes_enabled(goal_kind: StringName, catalog: Dictionary) -> bool:
  if typeof(catalog) != TYPE_DICTIONARY or not catalog.has(goal_kind):
    return false
  return bool(catalog[goal_kind].get("salient_writes", true))


## Dominant Tier-2 leaf wire id → default salient [code]GoalKind[/code] at outcome.
static func tier2_to_default_goal_kind(dominant_tier2: StringName) -> StringName:
  match dominant_tier2:
    PARENT_FIND_FOOD:
      return GK_FIND_FOOD
    PARENT_AVOID_HOSTILES:
      return GK_AVOID_HOSTILES
    PARENT_FIND_MATE:
      return GK_FIND_MATE
    _:
      return &""


## Routes dominant Tier-2 + optional outcome hint to wire [code]GoalKind[/code] ([CREATURE_GOAL_DRIVERS.md §4.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
## Phase-1: [code]avoid_hostiles[/code] only for Avoid outcomes — [code]shelter[/code] deferred.
static func resolve_goal_kind_at_outcome(
  dominant_tier2: StringName,
  outcome_ctx: Dictionary = {},
  catalog: Dictionary = {},
) -> StringName:
  var hint: StringName = outcome_ctx.get("goal_kind_hint", &"") as StringName
  if hint != &"" and typeof(catalog) == TYPE_DICTIONARY and catalog.has(hint):
    var entry: Dictionary = catalog[hint] as Dictionary
    if entry.get("parent_tier2", &"") == dominant_tier2 and bool(entry.get("salient_writes", true)):
      return hint
  if bool(outcome_ctx.get("use_shelter", false)):
    return tier2_to_default_goal_kind(dominant_tier2)
  return tier2_to_default_goal_kind(dominant_tier2)
