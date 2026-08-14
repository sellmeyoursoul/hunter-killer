## Instance goal-target beliefs — [CREATURE_MEMORY.md §5.5](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md).
extends Object

const TIER_PRECISE := &"PRECISE"
const TIER_COARSE := &"COARSE"

const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


## Unit step direction [param d] → sector index 0..7 (N, NE, E, SE, S, SW, W, NW; **−Z = N**).
static func sector_index_for_step(d: Vector3) -> int:
  if d.length_squared() < 1e-8:
    return 0
  var u := d.normalized()
  var angle := atan2(u.x, -u.z)
  if angle < 0.0:
    angle += TAU
  return int(floor((angle + PI / 8.0) / (PI / 4.0))) % 8


## Phase-1 align: **1.0** if [param d] falls in [param sector_s]'s 45° arc, else **0.0**.
static func align_step_with_sector(d: Vector3, sector_s: int) -> float:
  if sector_s < 0 or sector_s > 7:
    return 0.0
  return 1.0 if sector_index_for_step(d) == sector_s else 0.0


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


## Live seek positions only; skips occluded-in-zone plants kept for goal-belief sync.
static func food_positions_from_live_entries(entries: Array) -> Array:
  var out: Array = []
  for e in entries:
    if typeof(e) == TYPE_DICTIONARY:
      var ent: Dictionary = e as Dictionary
      if bool(ent.get("occluded", false)):
        continue
      var p: Variant = ent.get("pos", null)
      if typeof(p) == TYPE_VECTOR3:
        out.append(p)
    elif typeof(e) == TYPE_VECTOR3:
      out.append(e)
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
      "is_moving": is_moving,
      "last_velocity": velocity,
      "passibility_fail_count": 0,
      "last_passibility_fail_ms": 0,
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
    row["passibility_fail_count"] = 0
    row["last_passibility_fail_ms"] = 0
  beliefs[instance_id] = row


## Increments passibility failure count on one belief row (§3 **C**).
static func increment_passibility_fail(
  beliefs: Dictionary,
  instance_id: int,
  now_ms: int,
) -> Dictionary:
  if instance_id == 0 or not beliefs.has(instance_id):
    return beliefs
  var row: Dictionary = beliefs[instance_id]
  row["passibility_fail_count"] = int(row.get("passibility_fail_count", 0)) + 1
  row["last_passibility_fail_ms"] = now_ms
  beliefs[instance_id] = row
  return beliefs


## Upsert one GK_SHELTER STAY-evaluate outcome (§6.4). Dedicated constructor rather than
## `_upsert_row` — the generic one unconditionally resets tier/fail-counters on every call, which
## would wipe a prior confirm/fail verdict on the next re-observation; shelter's confirm/fail
## semantics must survive re-observation instead. `shelter_fail_count` resets to 0 on confirm,
## increments on each consecutive failed evaluation.
static func upsert_shelter_row(
  beliefs: Dictionary,
  instance_id: int,
  anchor: Vector3,
  now_ms: int,
  fit_confirmed: bool,
  enclosure_fraction: float,
) -> void:
  if instance_id == 0:
    return
  var prior: Dictionary = beliefs.get(instance_id, {}) as Dictionary
  var fail_count := 0 if fit_confirmed else int(prior.get("shelter_fail_count", 0)) + 1
  beliefs[instance_id] = {
    "instance_id": instance_id,
    "goal_kind": _GkReg.GK_SHELTER,
    "tier": TIER_PRECISE,
    "last_world_pos": anchor,
    "last_observed_ms": now_ms,
    "coarse_entered_ms": 0,
    "consumable_now": true,
    "is_moving": false,
    "last_velocity": Vector3.ZERO,
    "passibility_fail_count": int(prior.get("passibility_fail_count", 0)),
    "last_passibility_fail_ms": int(prior.get("last_passibility_fail_ms", 0)),
    "fit_confirmed": fit_confirmed,
    "enclosure_fraction": enclosure_fraction,
    "shelter_fail_count": fail_count,
    "shelter_last_eval_ms": now_ms,
  }


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
      var is_moving := bool(ent.get("is_moving", false))
      var vel: Vector3 = _read_vel_v3(ent.get("velocity", Vector3.ZERO))
      _upsert_row(beliefs, iid, _GkReg.GK_FIND_FOOD, pos, now_ms, is_moving, vel, consumable)
      if ent.has("stimulus_kind_id"):
        beliefs[iid]["stimulus_kind_id"] = ent.get("stimulus_kind_id", &"")
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
    if row.has("stimulus_kind_id"):
      beliefs[iid]["stimulus_kind_id"] = row.get("stimulus_kind_id", &"")
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


## Light intercept objective for latch-gated moving prey consult (§12.2 D5).
static func moving_seek_objective_pos(row: Dictionary, motor_p: Dictionary) -> Vector3:
  var last_pos: Vector3 = _read_pos_v3(row.get("last_world_pos", Vector3.ZERO))
  var vel: Vector3 = _read_vel_v3(row.get("last_velocity", Vector3.ZERO))
  if vel.length_squared() < 1e-8:
    return last_pos
  var horizon := float(motor_p.get("goal_memory_ghost_horizon_sec", 0.4))
  return last_pos + vel * horizon


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
  ## Confirmed shelters must outlive food's short TTL/precise-radius — Flight (Slice 2) needs them
  ## around later, not just while freshly observed. Shelter-specific keys fall back to the generic
  ## ones when unset.
  var shelter_precise_r := float(motor_p.get("goal_memory_precise_radius_shelter", precise_r))
  var shelter_forget_r := float(motor_p.get("goal_memory_forget_radius_shelter", forget_r))
  var shelter_ttl_ms := int(float(motor_p.get("goal_memory_ttl_sec_shelter", motor_p.get("goal_memory_ttl_sec", 45.0))) * 1000.0)
  var to_erase: Array = []
  for iid in beliefs.keys():
    var row: Dictionary = beliefs[iid]
    var is_shelter: bool = row.get("goal_kind", &"") == _GkReg.GK_SHELTER
    var last_pos: Vector3 = _read_pos_v3(row.get("last_world_pos", Vector3.ZERO))
    var dist := creature_pos.distance_to(last_pos)
    if dist > (shelter_forget_r if is_shelter else forget_r):
      to_erase.append(iid)
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    var ttl_ms := shelter_ttl_ms if is_shelter else (mover_ttl_ms if bool(row.get("is_moving", false)) else global_ttl_ms)
    if now_ms - last_obs > ttl_ms:
      to_erase.append(iid)
      continue
    var tier: StringName = row.get("tier", TIER_PRECISE)
    if tier == TIER_PRECISE and dist > (shelter_precise_r if is_shelter else precise_r):
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
    var worst_observed := 2147483647
    for iid2 in beliefs.keys():
      var row2: Dictionary = beliefs[iid2]
      ## Confirmed shelter beliefs are hard-won (a multi-cycle STAY-evaluate) and rarely refresh
      ## `last_observed_ms` post-confirmation, unlike food beliefs refreshed every live scan — that
      ## would make a confirmed shelter the de facto first LRU-eviction candidate. Exempt (still
      ## subject to TTL/forget-radius eviction above).
      if row2.get("goal_kind", &"") == _GkReg.GK_SHELTER and bool(row2.get("fit_confirmed", false)):
        continue
      var observed := int(row2.get("last_observed_ms", 0))
      var iid_int := int(iid2)
      if observed < worst_observed:
        worst_observed = observed
        worst_iid = iid2
      elif observed == worst_observed and (worst_iid == null or iid_int < int(worst_iid)):
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

