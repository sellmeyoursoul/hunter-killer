## Instance goal-target beliefs — [CREATURE_MEMORY.md §5.5](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md).
extends Object

const TIER_PRECISE := &"PRECISE"
const TIER_COARSE := &"COARSE"

const _SectorScr := preload("res://creature/motor/believed_goal_sector.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _SeekCand := preload("res://creature/motor/seek_candidate.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


static func _read_pos_v3(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


static func _read_vel_v3(v: Variant) -> Vector3:
  var vel: Variant = Callable(_MotorPlane, &"read_velocity").call(v)
  if typeof(vel) == TYPE_VECTOR3:
    return vel as Vector3
  if typeof(vel) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(vel as Vector2)
  return Vector3.ZERO


## Extract world positions from awareness entries ([code]Vector3[/code] or [code]{pos, instance_id}[/code]).
static func food_positions_from_entries(entries: Array) -> Array:
  var out: Array = []
  for e in entries:
    if typeof(e) == TYPE_VECTOR3:
      out.append(e)
    elif typeof(e) == TYPE_DICTIONARY:
      var p: Variant = (e as Dictionary).get("pos", null)
      if typeof(p) == TYPE_VECTOR3:
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


## Union of live target ids from food split, prey entries, and threat samples.
static func live_target_instance_ids(
  food_split: Dictionary,
  prey_entries: Array,
  threat_samples: Array,
) -> Dictionary:
  var seen := live_food_instance_ids(food_split)
  for e in prey_entries:
    if typeof(e) != TYPE_DICTIONARY:
      continue
    var iid: int = int((e as Dictionary).get("instance_id", 0))
    if iid != 0:
      seen[iid] = true
  for s in threat_samples:
    if typeof(s) != TYPE_DICTIONARY:
      continue
    var iid2: int = int((s as Dictionary).get("instance_id", 0))
    if iid2 != 0:
      seen[iid2] = true
  return seen


static func _moving_ttl_ms(motor_p: Dictionary) -> int:
  var sec := float(
    motor_p.get(
      "goal_memory_mover_ttl_sec",
      motor_p.get("predator_prey_memory_sec", motor_p.get("goal_memory_ttl_sec", 45.0)),
    )
  )
  return int(sec * 1000.0)


static func _memory_strength(age_ms: int, ttl_ms: int) -> float:
  return clampf(1.0 - float(age_ms) / float(maxi(1, ttl_ms)), 0.4, 1.0)


static func _upsert_row(
  beliefs: Dictionary,
  instance_id: int,
  goal_kind: StringName,
  pos: Vector3,
  now_ms: int,
  is_moving: bool,
  velocity: Vector3 = Vector3.ZERO,
  consumable_now: bool = true,
) -> void:
  if instance_id == 0:
    return
  var row: Dictionary = beliefs.get(instance_id, {}) as Dictionary
  if row.is_empty():
    row = {
      "instance_id": instance_id,
      "goal_kind": goal_kind,
      "tier": TIER_PRECISE,
      "last_world_pos": pos,
      "last_observed_ms": now_ms,
      "coarse_entered_ms": 0,
      "consumable_now": consumable_now,
      "merge_use_count": 0,
      "last_merged_ms": 0,
      "is_moving": is_moving,
      "last_velocity": velocity,
    }
  else:
    row["goal_kind"] = goal_kind
    row["tier"] = TIER_PRECISE
    row["last_world_pos"] = pos
    row["last_observed_ms"] = now_ms
    row["coarse_entered_ms"] = 0
    row["consumable_now"] = consumable_now
    row["is_moving"] = is_moving
    row["last_velocity"] = velocity
  beliefs[instance_id] = row


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
      var pos: Vector3 = _read_pos_v3(ent.get("pos", Vector3.ZERO))
      _upsert_row(beliefs, iid, _GkReg.GK_FIND_FOOD, pos, now_ms, false, Vector3.ZERO, consumable)
      if ent.has("anticipated_calories"):
        beliefs[iid]["anticipated_calories"] = float(ent["anticipated_calories"])
  return beliefs


## Upsert moving prey entries ([code]{instance_id, pos, velocity}[/code]).
static func sync_from_prey_entries(
  beliefs: Dictionary,
  prey_entries: Array,
  now_ms: int,
) -> Dictionary:
  for e in prey_entries:
    if typeof(e) != TYPE_DICTIONARY:
      continue
    var ent: Dictionary = e as Dictionary
    var iid: int = int(ent.get("instance_id", 0))
    if iid == 0:
      continue
    var pos: Vector3 = _read_pos_v3(ent.get("pos", Vector3.ZERO))
    var vel: Vector3 = _read_vel_v3(ent.get("velocity", Vector3.ZERO))
    _upsert_row(beliefs, iid, _GkReg.GK_FIND_FOOD, pos, now_ms, true, vel, true)
  return beliefs


## Upsert moving hostile threats ([code]ThreatSample[/code] shape).
static func sync_from_threat_samples(
  beliefs: Dictionary,
  threat_samples: Array,
  now_ms: int,
) -> Dictionary:
  for s in threat_samples:
    if typeof(s) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = s as Dictionary
    if not bool(row.get("in_awareness", false)):
      continue
    var iid: int = int(row.get("instance_id", 0))
    if iid == 0:
      continue
    var pos: Vector3 = _read_pos_v3(row.get("world_pos", Vector3.ZERO))
    var vel: Vector3 = _read_vel_v3(row.get("velocity", Vector3.ZERO))
    _upsert_row(beliefs, iid, _GkReg.GK_AVOID_HOSTILES, pos, now_ms, true, vel, false)
  return beliefs


## Best precise moving belief for [param goal_kind] (nearest, in envelope, not live).
static func sample_best_moving(
  beliefs: Dictionary,
  creature_pos: Vector3,
  motor_p: Dictionary,
  goal_kind: StringName,
  live_ids: Dictionary,
  now_ms: int,
) -> Dictionary:
  var inactive := {
    "active": false,
    "position": Vector3.ZERO,
    "velocity": Vector3.ZERO,
    "strength": 0.0,
    "instance_id": 0,
  }
  var ttl_ms := _moving_ttl_ms(motor_p)
  var forget_r := float(motor_p.get("goal_memory_forget_radius", 2400.0))
  var precise_r := float(motor_p.get("goal_memory_precise_radius", 1000.0))
  var best_iid := 0
  var best_pos := Vector3.ZERO
  var best_vel := Vector3.ZERO
  var best_strength := 0.0
  var best_d_sq := INF
  for iid in beliefs.keys():
    if live_ids.has(iid):
      continue
    var row: Dictionary = beliefs[iid]
    if row.get("goal_kind", &"") != goal_kind:
      continue
    if not bool(row.get("is_moving", false)):
      continue
    if row.get("tier", TIER_COARSE) != TIER_PRECISE:
      continue
    var last_pos: Vector3 = _read_pos_v3(row.get("last_world_pos", Vector3.ZERO))
    if creature_pos.distance_to(last_pos) > precise_r:
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    var age_ms := now_ms - last_obs
    if age_ms > ttl_ms:
      continue
    if creature_pos.distance_to(last_pos) > forget_r:
      continue
    var d_sq := creature_pos.distance_squared_to(last_pos)
    if d_sq < best_d_sq:
      best_d_sq = d_sq
      best_iid = int(iid)
      best_pos = last_pos
      best_vel = _read_vel_v3(row.get("last_velocity", Vector3.ZERO))
      best_strength = _memory_strength(age_ms, ttl_ms)
  if best_iid == 0:
    return inactive
  return {
    "active": true,
    "position": best_pos,
    "velocity": best_vel,
    "strength": best_strength,
    "instance_id": best_iid,
  }


## True when a precise remembered [code]avoid_hostiles[/code] mover is still in envelope.
static func has_remembered_avoid_threat(
  beliefs: Dictionary,
  creature_pos: Vector3,
  motor_p: Dictionary,
  live_ids: Dictionary,
  now_ms: int,
) -> bool:
  var sample := sample_best_moving(
    beliefs, creature_pos, motor_p, _GkReg.GK_AVOID_HOSTILES, live_ids, now_ms
  )
  return bool(sample.get("active", false))


## Inject remembered prey chase into live lists (centroid + ghost velocity + light intercept).
static func inject_moving_memory_chase(
  sample: Dictionary,
  prey_pts_live: Array,
  pursuit_targets: Array,
  motor_p: Dictionary,
) -> void:
  if not bool(sample.get("active", false)):
    return
  var mp: Vector3 = _read_pos_v3(sample.get("position", Vector3.ZERO))
  if mp == Vector3.ZERO:
    return
  prey_pts_live.clear()
  prey_pts_live.append(mp)
  var mem_vel: Vector3 = _read_vel_v3(sample.get("velocity", Vector3.ZERO))
  var mem_scale := clampf(float(sample.get("strength", 1.0)), 0.4, 1.0)
  pursuit_targets.clear()
  pursuit_targets.append({
    "position": mp,
    "velocity": mem_vel,
    "cost_scale": mem_scale,
  })
  if mem_vel.length_squared() > 1e-8:
    var horizon := float(motor_p.get("goal_memory_ghost_horizon_sec", 0.4))
    var intercept := mp + mem_vel * horizon
    pursuit_targets.append({
      "position": intercept,
      "velocity": mem_vel,
      "cost_scale": mem_scale * 0.85,
    })


## TTL / precise→coarse / LRU maintenance.
static func maintain(
  beliefs: Dictionary,
  creature_pos: Vector3,
  now_ms: int,
  motor_p: Dictionary,
) -> Dictionary:
  var precise_r := float(motor_p.get("goal_memory_precise_radius", 1000.0))
  var forget_r := float(motor_p.get("goal_memory_forget_radius", 2400.0))
  var coarse_ttl_ms := int(float(motor_p.get("goal_memory_coarse_ttl_sec", 15.0)) * 1000.0)
  var global_ttl_ms := int(float(motor_p.get("goal_memory_ttl_sec", 45.0)) * 1000.0)
  var mover_ttl_ms := _moving_ttl_ms(motor_p)
  var max_entries := maxi(1, int(motor_p.get("goal_memory_max_entries", 25)))
  var to_erase: Array = []
  for iid in beliefs.keys():
    var row: Dictionary = beliefs[iid]
    var last_pos: Vector3 = _read_pos_v3(row.get("last_world_pos", Vector3.ZERO))
    var dist := creature_pos.distance_to(last_pos)
    if dist > forget_r:
      to_erase.append(iid)
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    var ttl_ms := mover_ttl_ms if bool(row.get("is_moving", false)) else global_ttl_ms
    if now_ms - last_obs > ttl_ms:
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


static func _append_pursuit_ghost(
  pursuit_targets: Array,
  pos: Vector3,
  vel: Vector3,
  cost_scale: float,
  motor_p: Dictionary,
) -> void:
  pursuit_targets.append({"position": pos, "velocity": vel, "cost_scale": cost_scale})
  if vel.length_squared() > 1e-8:
    var horizon := float(motor_p.get("goal_memory_ghost_horizon_sec", 0.4))
    var intercept := pos + vel * horizon
    pursuit_targets.append({
      "position": intercept,
      "velocity": vel,
      "cost_scale": cost_scale * 0.85,
    })


## Merge precise beliefs into motor lists; accumulate coarse sector weights (normalized max=1).
static func merge_into_motor_context(
  beliefs: Dictionary,
  ctx: Dictionary,
  creature_pos: Vector3,
  motor_p: Dictionary,
  live_ids: Dictionary,
  now_ms: int,
  allow_moving_prey_memory: bool = true,
) -> Dictionary:
  var w_remember := float(motor_p.get("weight_seek_remembered_goal", 8.0))
  var w_coarse := float(motor_p.get("weight_coarse_sector_goal_bias", 3.0))
  var precise_r := float(motor_p.get("goal_memory_precise_radius", 1000.0))
  var max_merge := 25
  var merged_n := 0
  var sector_acc: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  var ttl_ms := _moving_ttl_ms(motor_p)
  if w_remember > 0.0:
    var food_targets: Array = ctx.get("food_seek_targets", []) as Array
    var unready_targets: Array = ctx.get("unready_food_avoid_targets", []) as Array
    var seek_candidates: Array = ctx.get("seek_candidates", []) as Array
    for iid in beliefs.keys():
      if live_ids.has(iid):
        continue
      if merged_n >= max_merge:
        break
      var row: Dictionary = beliefs[iid]
      if row.get("tier", TIER_COARSE) != TIER_PRECISE:
        continue
      var last_pos: Vector3 = _read_pos_v3(row.get("last_world_pos", Vector3.ZERO))
      if creature_pos.distance_to(last_pos) > precise_r:
        continue
      var gk: StringName = row.get("goal_kind", &"")
      var is_moving: bool = bool(row.get("is_moving", false))
      if is_moving and gk == _GkReg.GK_FIND_FOOD:
        if not allow_moving_prey_memory:
          continue
        var age_ms := now_ms - int(row.get("last_observed_ms", 0))
        if age_ms > ttl_ms:
          continue
        var _vel: Vector3 = _read_vel_v3(row.get("last_velocity", Vector3.ZERO))
        var strength := _memory_strength(age_ms, ttl_ms)
        seek_candidates.append(
          Callable(_SeekCand, &"make").call(
            last_pos,
            _GkReg.GK_FIND_FOOD,
            true,
            true,
            int(iid),
            _SeekCand.SOURCE_MEMORY_MOVING,
          )
        )
        row["ghost_strength"] = strength
      elif not is_moving and gk == _GkReg.GK_FIND_FOOD:
        var consumable: bool = bool(row.get("consumable_now", true))
        if consumable:
          food_targets.append(last_pos)
        else:
          unready_targets.append(last_pos)
        seek_candidates.append(
          Callable(_SeekCand, &"make").call(
            last_pos,
            _GkReg.GK_FIND_FOOD,
            consumable,
            false,
            int(iid),
            _SeekCand.SOURCE_MEMORY_PRECISE,
          )
        )
      row["merge_use_count"] = int(row.get("merge_use_count", 0)) + 1
      row["last_merged_ms"] = now_ms
      beliefs[iid] = row
      merged_n += 1
    ctx["food_seek_targets"] = food_targets
    ctx["unready_food_avoid_targets"] = unready_targets
    ctx["seek_candidates"] = seek_candidates
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
      var last_c: Vector3 = _read_pos_v3(row_c.get("last_world_pos", Vector3.ZERO))
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
