## Instance goal-target beliefs (stationary food) — [CREATURE_MEMORY.md §5.5](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md).
extends Object

const TIER_PRECISE := &"PRECISE"
const TIER_COARSE := &"COARSE"

const _SectorScr := preload("res://creature/motor/believed_goal_sector.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")


## Extract world positions from awareness entries ([code]Vector2[/code] or [code]{pos, instance_id}[/code]).
static func food_positions_from_entries(entries: Array) -> Array:
  var out: Array = []
  for e in entries:
    if typeof(e) == TYPE_VECTOR2:
      out.append(e)
    elif typeof(e) == TYPE_DICTIONARY:
      var p: Variant = (e as Dictionary).get("pos", null)
      if typeof(p) == TYPE_VECTOR2:
        out.append(p)
  return out


## Live instance ids from awareness [code]ready[/code] / [code]unready[/code] lists.
static func live_food_instance_ids(food_split: Dictionary) -> Dictionary:
  var seen: Dictionary = {}
  for key in ["ready", "unready"]:
    for e in food_split.get(key, []) as Array:
      if typeof(e) != TYPE_DICTIONARY:
        continue
      var iid: Variant = (e as Dictionary).get("instance_id", null)
      if typeof(iid) == TYPE_INT:
        seen[iid] = true
  return seen


## Upsert beliefs for bushes seen this tick; returns updated belief table.
static func sync_from_scene(
  beliefs: Dictionary,
  food_split: Dictionary,
  now_ms: int,
) -> Dictionary:
  for key in ["ready", "unready"]:
    var consumable: bool = key == "ready"
    for e in food_split.get(key, []) as Array:
      if typeof(e) != TYPE_DICTIONARY:
        continue
      var ent: Dictionary = e as Dictionary
      var iid: int = int(ent.get("instance_id", 0))
      if iid == 0:
        continue
      var pos: Vector2 = ent.get("pos", Vector2.ZERO)
      var row: Dictionary = beliefs.get(iid, {}) as Dictionary
      if row.is_empty():
        row = {
          "instance_id": iid,
          "goal_kind": _GkReg.GK_FIND_FOOD,
          "tier": TIER_PRECISE,
          "last_world_pos": pos,
          "last_observed_ms": now_ms,
          "coarse_entered_ms": 0,
          "consumable_now": consumable,
          "merge_use_count": 0,
          "last_merged_ms": 0,
        }
      else:
        row["tier"] = TIER_PRECISE
        row["last_world_pos"] = pos
        row["last_observed_ms"] = now_ms
        row["consumable_now"] = consumable
        row["coarse_entered_ms"] = 0
      beliefs[iid] = row
  return beliefs


## TTL / precise→coarse / LRU maintenance.
static func maintain(
  beliefs: Dictionary,
  creature_pos: Vector2,
  now_ms: int,
  motor_p: Dictionary,
) -> Dictionary:
  var precise_r := float(motor_p.get("goal_memory_precise_radius_px", 1000.0))
  var forget_r := float(motor_p.get("goal_memory_forget_radius_px", 2400.0))
  var coarse_ttl_ms := int(float(motor_p.get("goal_memory_coarse_ttl_sec", 15.0)) * 1000.0)
  var global_ttl_ms := int(float(motor_p.get("goal_memory_ttl_sec", 45.0)) * 1000.0)
  var max_entries := maxi(1, int(motor_p.get("goal_memory_max_entries", 25)))
  var to_erase: Array = []
  for iid in beliefs.keys():
    var row: Dictionary = beliefs[iid]
    var last_pos: Vector2 = row.get("last_world_pos", Vector2.ZERO)
    var dist := creature_pos.distance_to(last_pos)
    if dist > forget_r:
      to_erase.append(iid)
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    if now_ms - last_obs > global_ttl_ms:
      to_erase.append(iid)
      continue
    var tier: StringName = row.get("tier", TIER_PRECISE)
    if tier == TIER_PRECISE and dist > precise_r:
      row["tier"] = TIER_COARSE
      row["coarse_entered_ms"] = now_ms
      beliefs[iid] = row
      tier = TIER_COARSE
    if tier == TIER_COARSE:
      var coarse_entered := int(row.get("coarse_entered_ms", now_ms))
      if now_ms - coarse_entered > coarse_ttl_ms:
        to_erase.append(iid)
  for iid in to_erase:
    beliefs.erase(iid)
  while beliefs.size() > max_entries:
    var worst_iid: Variant = null
    var worst_use := 2147483647
    var worst_merge := 2147483647
    for iid2 in beliefs.keys():
      var row2: Dictionary = beliefs[iid2]
      var mu := int(row2.get("merge_use_count", 0))
      var lm := int(row2.get("last_merged_ms", 0))
      if mu < worst_use or (mu == worst_use and lm < worst_merge):
        worst_use = mu
        worst_merge = lm
        worst_iid = iid2
    if worst_iid == null:
      break
    beliefs.erase(worst_iid)
  return beliefs


## Merge precise beliefs into motor lists; accumulate coarse sector weights (normalized max=1).
static func merge_into_motor_context(
  beliefs: Dictionary,
  ctx: Dictionary,
  creature_pos: Vector2,
  motor_p: Dictionary,
  live_ids: Dictionary,
  now_ms: int,
) -> Dictionary:
  var w_remember := float(motor_p.get("weight_seek_remembered_goal", 8.0))
  var w_coarse := float(motor_p.get("weight_coarse_sector_goal_bias", 3.0))
  var precise_r := float(motor_p.get("goal_memory_precise_radius_px", 1000.0))
  var max_merge := 25
  var merged_n := 0
  var sector_acc: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  if w_remember > 0.0:
    var food_targets: Array = ctx.get("food_seek_targets", []) as Array
    var unready_targets: Array = ctx.get("unready_food_avoid_targets", []) as Array
    for iid in beliefs.keys():
      if live_ids.has(iid):
        continue
      if merged_n >= max_merge:
        break
      var row: Dictionary = beliefs[iid]
      if row.get("tier", TIER_COARSE) != TIER_PRECISE:
        continue
      var last_pos: Vector2 = row.get("last_world_pos", Vector2.ZERO)
      if creature_pos.distance_to(last_pos) > precise_r:
        continue
      var consumable: bool = bool(row.get("consumable_now", true))
      if consumable:
        food_targets.append(last_pos)
      else:
        unready_targets.append(last_pos)
      row["merge_use_count"] = int(row.get("merge_use_count", 0)) + 1
      row["last_merged_ms"] = now_ms
      beliefs[iid] = row
      merged_n += 1
    ctx["food_seek_targets"] = food_targets
    ctx["unready_food_avoid_targets"] = unready_targets
    if merged_n > 0:
      var w_live := float(ctx.get("weight_seek_ready_food", 0.0))
      if w_live > 0.0:
        ctx["weight_seek_ready_food"] = w_live + w_remember * 0.5
      else:
        ctx["weight_seek_ready_food"] = w_remember * 0.5
  if w_coarse > 0.0:
    for iid in beliefs.keys():
      if live_ids.has(iid):
        continue
      var row_c: Dictionary = beliefs[iid]
      if row_c.get("tier", TIER_PRECISE) != TIER_COARSE:
        continue
      var last_c: Vector2 = row_c.get("last_world_pos", Vector2.ZERO)
      var delta := last_c - creature_pos
      if delta.length_squared() < 1e-8:
        continue
      var s := _SectorScr.sector_index_for_step(delta)
      sector_acc[s] = float(sector_acc[s]) + 1.0
      row_c["merge_use_count"] = int(row_c.get("merge_use_count", 0)) + 1
      row_c["last_merged_ms"] = now_ms
      beliefs[iid] = row_c
    var peak := 0.0
    for w in sector_acc:
      peak = maxf(peak, float(w))
    if peak > 1e-8:
      for i in 8:
        sector_acc[i] = float(sector_acc[i]) / peak
  var bias: Dictionary = ctx.get("believed_goal_source_bias", {}) as Dictionary
  if typeof(bias) != TYPE_DICTIONARY:
    bias = {}
  bias["sector_weights"] = sector_acc
  ctx["believed_goal_source_bias"] = bias
  return ctx
