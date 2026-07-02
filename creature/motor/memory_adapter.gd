extends RefCounted
class_name MemoryAdapter
## V3 memory façade — planner consult + stack-owned writes ([CREATURE_MOVEMENT_V3.md §8.4 / §12.2 6d](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _GoalBelief := preload("res://creature/motor/goal_belief_memory.gd")
const _GoalSource := preload("res://creature/motor/goal_source_memory.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

const FEASIBILITY_PRECISE := 0.75
const FEASIBILITY_COARSE := 0.45
const FEASIBILITY_LOCALE := 0.25

var _beliefs: Dictionary = {}
var _locale_store: RefCounted
var _pack_root: String = ""
var _traits: Dictionary = {}
var _modality_allowlist: Array = []
var _goal_catalog: Dictionary = {}
var _effective_goal_kinds: Array = []


func _init() -> void:
  _locale_store = _GoalSource.new()


## Wires pack traits and modality allowlist used by consult + salient writes.
func configure(pack_root: String, traits: Dictionary) -> void:
  _pack_root = str(pack_root).strip_edges()
  _traits = traits.duplicate(true) if typeof(traits) == TYPE_DICTIONARY else {}
  _modality_allowlist = _GoalSource.effective_modality_allowlist_for_pack(_pack_root)
  _effective_goal_kinds = _GkReg.effective_goal_kinds_for_pack(_pack_root)


## Sets the goal-kind catalog consulted during salient locale writes.
func set_goal_catalog(goal_catalog: Dictionary) -> void:
  _goal_catalog = goal_catalog.duplicate(true) if typeof(goal_catalog) == TYPE_DICTIONARY else {}


## Clears instance beliefs and locale rows — duel/session reset (6d.2 slice 0).
func reset() -> void:
  _beliefs.clear()
  if _locale_store != null and _locale_store.has_method(&"reset"):
    _locale_store.call(&"reset")


## Upserts [code]_goal_belief[/code] from live awareness food + threat samples (§8.4).
func sync_after_scan(food_split: Dictionary, threat_samples: Array, now_ms: int) -> void:
  _beliefs = _GoalBelief.sync_from_scene(_beliefs, food_split, now_ms)
  _beliefs = _GoalBelief.sync_from_threat_samples(_beliefs, threat_samples, now_ms)


## TTL, precise→coarse promotion, and cap eviction on stack-owned beliefs (§8.3).
func maintain_beliefs(creature_pos: Vector3, now_ms: int, motor_v3: Dictionary) -> void:
  _beliefs = _GoalBelief.maintain(_beliefs, creature_pos, now_ms, motor_v3)


## Records find_food locale prior after EAT outcome — stack store only (§6.2, §8.4).
func notify_food_consumption_outcome(
  food_anchor: Vector3,
  insufficient_yield: bool,
  motor_v3: Dictionary,
  env_grid: Variant = null,
) -> void:
  if _locale_store == null:
    return
  var tier := _GoalSource.TIER_SUCCESS
  if insufficient_yield:
    tier = _GoalSource.TIER_PARTIAL
  _locale_store.try_salient_write(
    _GkReg.GK_FIND_FOOD,
    &"find_food",
    food_anchor,
    motor_v3,
    env_grid,
    {},
    {"tier": tier, "insufficient_yield": insufficient_yield},
    _effective_goal_kinds,
    _modality_allowlist,
    _traits,
    _goal_catalog,
  )
  _locale_store.clear_salient_continuation()


## Returns the internal locale-prior store (salient writes land in 6d.2).
func get_locale_store() -> RefCounted:
  return _locale_store


## Returns a shallow copy of instance belief rows keyed by [code]instance_id[/code].
func get_beliefs() -> Dictionary:
  return _beliefs.duplicate(true)


## Replaces instance beliefs — test harness only for 6d.1 read slices.
func set_beliefs_for_test(beliefs: Dictionary) -> void:
  _beliefs = beliefs.duplicate(true) if typeof(beliefs) == TYPE_DICTIONARY else {}


## Seeds one precise [code]find_food[/code] belief row for headless fixtures.
func seed_precise_food_belief(
  instance_id: int,
  world_pos: Vector3,
  now_ms: int,
  consumable: bool = true,
) -> void:
  _beliefs[instance_id] = {
    "instance_id": instance_id,
    "goal_kind": _GkReg.GK_FIND_FOOD,
    "tier": _GoalBelief.TIER_PRECISE,
    "last_world_pos": world_pos,
    "last_observed_ms": now_ms,
    "coarse_entered_ms": 0,
    "consumable_now": consumable,
    "is_moving": false,
    "last_velocity": Vector3.ZERO,
  }


## Seeds one coarse [code]find_food[/code] belief row for headless fixtures.
func seed_coarse_food_belief(instance_id: int, world_pos: Vector3, now_ms: int) -> void:
  _beliefs[instance_id] = {
    "instance_id": instance_id,
    "goal_kind": _GkReg.GK_FIND_FOOD,
    "tier": _GoalBelief.TIER_COARSE,
    "last_world_pos": world_pos,
    "last_observed_ms": now_ms,
    "coarse_entered_ms": now_ms,
    "consumable_now": true,
    "is_moving": false,
    "last_velocity": Vector3.ZERO,
  }


## Best [code]find_food[/code] feasibility from memory tiers when no live ready food (§1).
func best_find_food_feasibility(
  creature_pos: Vector3,
  motor_v3: Dictionary,
  food_split: Dictionary,
  now_ms: int,
  env_grid: Variant = null,
  motor_ctx: Dictionary = {},
) -> float:
  var ready: Array = food_split.get("ready", [])
  if not ready.is_empty():
    return 1.0
  if consult_precise_food(creature_pos, motor_v3, food_split, now_ms).get("active", false):
    return FEASIBILITY_PRECISE
  if consult_coarse_bearing(creature_pos, motor_v3, food_split, 0, now_ms).get("active", false):
    return FEASIBILITY_COARSE
  if consult_locale_seek(creature_pos, motor_v3, env_grid, motor_ctx).get("active", false):
    return FEASIBILITY_LOCALE
  return 0.0


## §8.2 precise GPS seek — nearest remembered consumable bush outside live awareness.
func consult_precise_food(
  creature_pos: Vector3,
  motor_v3: Dictionary,
  food_split: Dictionary,
  now_ms: int,
) -> Dictionary:
  var inactive := {
    "active": false,
    "pos": Vector3.ZERO,
    "instance_id": 0,
    "source": &"precise",
  }
  var live_ids := _GoalBelief.live_food_instance_ids(food_split)
  var precise_r := float(motor_v3.get("goal_memory_precise_radius", 1000.0))
  var forget_r := float(motor_v3.get("goal_memory_forget_radius", 2400.0))
  var global_ttl_ms := int(float(motor_v3.get("goal_memory_ttl_sec", 45.0)) * 1000.0)
  var best_iid := 0
  var best_pos := Vector3.ZERO
  var best_d_sq := INF
  for iid in _beliefs.keys():
    if live_ids.has(iid):
      continue
    var row: Dictionary = _beliefs[iid]
    if row.get("goal_kind", &"") != _GkReg.GK_FIND_FOOD:
      continue
    if row.get("tier", &"") != _GoalBelief.TIER_PRECISE:
      continue
    if not bool(row.get("consumable_now", true)):
      continue
    if bool(row.get("is_moving", false)):
      continue
    var last_pos: Vector3 = _read_pos(row.get("last_world_pos", Vector3.ZERO))
    var dist := creature_pos.distance_to(last_pos)
    if dist > precise_r or dist > forget_r:
      continue
    var age_ms := now_ms - int(row.get("last_observed_ms", 0))
    if age_ms > global_ttl_ms:
      continue
    var d_sq := creature_pos.distance_squared_to(last_pos)
    if d_sq < best_d_sq:
      best_d_sq = d_sq
      best_iid = int(iid)
      best_pos = last_pos
  if best_iid == 0:
    return inactive
  return {
    "active": true,
    "pos": best_pos,
    "instance_id": best_iid,
    "source": &"precise",
  }


## §8.3 coarse path-in-direction — bearing only, not GPS to [code]last_world_pos[/code].
func consult_coarse_bearing(
  creature_pos: Vector3,
  motor_v3: Dictionary,
  food_split: Dictionary,
  incumbent_instance_id: int,
  now_ms: int,
) -> Dictionary:
  var inactive := {
    "active": false,
    "bearing": Vector3.ZERO,
    "instance_id": 0,
    "source": &"coarse",
  }
  var live_ids := _GoalBelief.live_food_instance_ids(food_split)
  var forget_r := float(motor_v3.get("goal_memory_forget_radius", 2400.0))
  var coarse_ttl_ms := int(float(motor_v3.get("goal_memory_coarse_ttl_sec", 15.0)) * 1000.0)
  var global_ttl_ms := int(float(motor_v3.get("goal_memory_ttl_sec", 45.0)) * 1000.0)
  var candidates: Array = []
  for iid in _beliefs.keys():
    if live_ids.has(iid):
      continue
    var row: Dictionary = _beliefs[iid]
    if row.get("goal_kind", &"") != _GkReg.GK_FIND_FOOD:
      continue
    if row.get("tier", &"") != _GoalBelief.TIER_COARSE:
      continue
    if bool(row.get("is_moving", false)):
      continue
    var last_pos: Vector3 = _read_pos(row.get("last_world_pos", Vector3.ZERO))
    if creature_pos.distance_to(last_pos) > forget_r:
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    var age_ms := now_ms - last_obs
    if age_ms > global_ttl_ms:
      continue
    var coarse_entered := int(row.get("coarse_entered_ms", last_obs))
    if now_ms - coarse_entered > coarse_ttl_ms:
      continue
    var delta := last_pos - creature_pos
    delta.y = 0.0
    if delta.length_squared() < 1e-8:
      continue
    candidates.append({
      "instance_id": int(iid),
      "bearing": delta.normalized(),
      "last_observed_ms": last_obs,
      "incumbent_match": int(iid) == incumbent_instance_id,
    })
  if candidates.is_empty():
    return inactive
  candidates.sort_custom(func(a, b):
    if bool(a["incumbent_match"]) != bool(b["incumbent_match"]):
      return bool(a["incumbent_match"])
    return int(a["last_observed_ms"]) > int(b["last_observed_ms"])
  )
  var pick: Dictionary = candidates[0]
  return {
    "active": true,
    "bearing": pick["bearing"],
    "instance_id": int(pick["instance_id"]),
    "source": &"coarse",
  }


## Locale prior / [code]replay_rank_score[/code] hotspot consult for seek cycle (§3, §9).
func consult_locale_seek(
  creature_pos: Vector3,
  motor_v3: Dictionary,
  env_grid: Variant = null,
  motor_ctx: Dictionary = {},
) -> Dictionary:
  var inactive := {
    "active": false,
    "anchor": Vector3.ZERO,
    "replay_rank_score": 0.0,
    "source": &"locale",
  }
  if _locale_store == null:
    return inactive
  var ctx := motor_ctx.duplicate(true) if typeof(motor_ctx) == TYPE_DICTIONARY else {}
  if not ctx.has("effective_modality_allowlist"):
    ctx["effective_modality_allowlist"] = _modality_allowlist
  var bias := _GoalSource.project_believed_goal_bias(
    creature_pos,
    _GkReg.GK_FIND_FOOD,
    motor_v3,
    _locale_store,
    Vector3.ZERO,
    env_grid,
    ctx,
    [],
    _traits,
  )
  var centroid: Vector3 = bias.get("hotspot_centroid", Vector3.ZERO)
  var pull_mag := float(bias.get("pull_mag", 0.0))
  if centroid.length_squared() < 1e-8 and pull_mag <= 1e-4:
    var nearest := _nearest_find_food_prior_anchor(creature_pos, motor_v3)
    if nearest == Vector3.ZERO:
      return inactive
    centroid = nearest
  var best_rank := _best_locale_replay_rank(creature_pos, motor_v3, ctx)
  if centroid.length_squared() < 1e-8 and best_rank <= 1e-8:
    return inactive
  return {
    "active": true,
    "anchor": centroid,
    "replay_rank_score": best_rank,
    "source": &"locale",
  }


static func _read_pos(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


func _best_locale_replay_rank(
  creature_pos: Vector3,
  motor_v3: Dictionary,
  motor_ctx: Dictionary,
) -> float:
  var hotspot_r := float(motor_v3.get("believed_goal_hotspot_near_radius", 250.0))
  var best := 0.0
  for key in _locale_store._rows.keys():
    var row: Dictionary = _locale_store._rows[key]
    if row.get("goal_kind") != _GkReg.GK_FIND_FOOD:
      continue
    var rank: float = _locale_store._replay_rank_score(
      row, motor_v3, motor_ctx, creature_pos, _traits, hotspot_r
    )
    best = maxf(best, rank)
  return best


func _nearest_find_food_prior_anchor(creature_pos: Vector3, motor_v3: Dictionary) -> Vector3:
  var coverage_cell := _GoalSource.coverage_cell_from_motor(motor_v3)
  var escalate_r := float(motor_v3.get("believed_goal_seek_escalate_radius", 1000.0))
  var best := Vector3.ZERO
  var best_d := INF
  for key in _locale_store._rows.keys():
    var row: Dictionary = _locale_store._rows[key]
    if row.get("goal_kind") != _GkReg.GK_FIND_FOOD:
      continue
    var cx := int(row.get("cell_x", 0))
    var cy := int(row.get("cell_y", 0))
    var center := _MotorPlane.to_horizontal_vec3(
      Vector2((float(cx) + 0.5) * coverage_cell, (float(cy) + 0.5) * coverage_cell)
    )
    var d := creature_pos.distance_to(center)
    if d > escalate_r:
      continue
    if d < best_d:
      best_d = d
      best = center
  return best


## Seeds a locale-prior grid row for headless consult fixtures (6d.1).
func seed_locale_prior_for_test(
  cell_x: int,
  cell_y: int,
  stored_strength: float = 1.0,
) -> void:
  var key := _GoalSource._row_key(_GkReg.GK_FIND_FOOD, 99001, &"open_forage")
  _locale_store._rows[key] = {
    "goal_kind": _GkReg.GK_FIND_FOOD,
    "context_hash": 99001,
    "modality_tag": &"open_forage",
    "pole_facet_tag": &"explorer",
    "cell_x": cell_x,
    "cell_y": cell_y,
    "attempt_count": 8,
    "success_count": 6,
    "success_delta": 0.2,
    "stored_strength": stored_strength,
    "last_used_time": Time.get_ticks_msec() / 1000.0,
  }
