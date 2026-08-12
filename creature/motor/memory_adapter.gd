extends RefCounted
class_name MemoryAdapter
## V3 memory façade — planner consult + stack-owned writes ([CREATURE_MOVEMENT_V3.md §8.4 / §12.2 6d](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _GoalBelief := preload("res://creature/motor/goal_belief_memory.gd")
const _GoalSource := preload("res://creature/motor/goal_source_memory.gd")
const _KindProfile := preload("res://creature/motor/kind_profile_memory.gd")
const _DeadEnd := preload("res://creature/motor/dead_end_memory.gd")
const _LearnReg := preload("res://creature/memory/stimulus_learn_registry.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")

const FEASIBILITY_PRECISE := 0.75
const FEASIBILITY_COARSE := 0.45
const FEASIBILITY_LOCALE := 0.25
const FEASIBILITY_MEMORY_MOVING := 0.75

var _beliefs: Dictionary = {}
var _kind_profile: Dictionary = {}
var _threat_disposition_mod: float = 1.0
var _dead_end_marks: Array = []
const _ThreatDisposition := preload("res://creature/motor/threat_disposition.gd")
const _OccludedGhost := preload("res://creature/motor/occluded_in_zone_ghost.gd")
var _locale_store: RefCounted
var _pack_root: String = ""
var _traits: Dictionary = {}
var _modality_allowlist: Array = []
var _goal_catalog: Dictionary = {}
var _effective_goal_kinds: Array = []
var _food_intake_policy: Resource


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


## Wires diet policy used to filter remembered [code]find_food[/code] consult (§6.2 ingress).
func set_food_intake_policy(policy: Resource) -> void:
  _food_intake_policy = policy


## Clears instance beliefs, kind profile, dead-end marks, and locale rows.
func reset() -> void:
  _beliefs.clear()
  _kind_profile.clear()
  _threat_disposition_mod = _ThreatDisposition.DEFAULT_MOD
  _dead_end_marks.clear()
  if _locale_store != null and _locale_store.has_method(&"reset"):
    _locale_store.call(&"reset")


## Upserts [code]_goal_belief[/code] from live awareness food + threat samples (§8.4).
func sync_after_scan(food_split: Dictionary, threat_samples: Array, now_ms: int) -> void:
  _beliefs = _GoalBelief.sync_from_scene(_beliefs, food_split, now_ms)
  _beliefs = _GoalBelief.sync_from_threat_samples(_beliefs, threat_samples, now_ms)


## TTL, precise→coarse promotion, cap eviction, and dead-end mark maintenance (§8.3).
func maintain_beliefs(creature_pos: Vector3, now_ms: int, motor_v3: Dictionary) -> void:
  _beliefs = _GoalBelief.maintain(_beliefs, creature_pos, now_ms, motor_v3)
  _dead_end_marks = _DeadEnd.maintain(_dead_end_marks, now_ms, motor_v3)


## Records find_food locale prior + kind EWMA after EAT outcome (§6.2, §8.4).
func notify_food_consumption_outcome(
  food_anchor: Vector3,
  insufficient_yield: bool,
  motor_v3: Dictionary,
  env_grid: Variant = null,
  stimulus_kind_id: StringName = &"",
  calories_gained: int = 0,
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
  if stimulus_kind_id != &"" and calories_gained > 0:
    var normalized := _KindProfile.nutrition_yield_observation(
      calories_gained, insufficient_yield, motor_v3
    )
    record_observation(
      _LearnReg.TOPIC_NUTRITION_YIELD,
      stimulus_kind_id,
      normalized,
      motor_v3,
    )


## Records a `find_food` FAILURE at [param anchor] (CLEANUP C15): a locale-memory anchor was
## reached and had no consumable food after all — the mirror-image write to
## [method notify_food_consumption_outcome]'s SUCCESS/PARTIAL, so a cell that keeps producing
## empty arrivals erodes its own `stored_strength` over repeated visits (same `try_salient_write`
## learning path, same row key — attempts accumulate from both outcomes) instead of relying solely
## on the short-lived per-visit `locale_revisit_cooldown_ticks` timer to avoid it.
func notify_locale_food_arrival_empty(
  anchor: Vector3,
  motor_v3: Dictionary,
  env_grid: Variant = null,
) -> void:
  if _locale_store == null:
    return
  _locale_store.try_salient_write(
    _GkReg.GK_FIND_FOOD,
    &"find_food",
    anchor,
    motor_v3,
    env_grid,
    {},
    {"tier": _GoalSource.TIER_FAILURE},
    _effective_goal_kinds,
    _modality_allowlist,
    _traits,
    _goal_catalog,
  )
  _locale_store.clear_salient_continuation()


## Returns the internal locale-prior store (salient writes land in 6d.2).
func get_locale_store() -> RefCounted:
  return _locale_store


## Live + occluded-in-zone threat ghosts passing [code]danger_filter[/code] (§8.4).
func consult_danger_samples(zone_ctx: Dictionary, live_threat_samples: Array) -> Array:
  var live_ids: Dictionary = {}
  var out: Array = []
  for sample_v in live_threat_samples:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v as Dictionary
    var iid := int(sample.get("instance_id", 0))
    if iid != 0:
      live_ids[iid] = true
    if _OccludedGhost.danger_filter(sample):
      out.append(sample.duplicate(true))
  for ghost_v in _OccludedGhost.project_ghosts(zone_ctx, _beliefs, live_ids):
    if typeof(ghost_v) != TYPE_DICTIONARY:
      continue
    var ghost: Dictionary = ghost_v as Dictionary
    if _OccludedGhost.danger_filter(ghost):
      out.append(ghost)
  var now_ms := int(zone_ctx.get("now_ms", 0))
  for vghost_v in _OccludedGhost.project_facing_lost_threat_ghosts(zone_ctx, _beliefs, live_ids, now_ms):
    if typeof(vghost_v) != TYPE_DICTIONARY:
      continue
    var vghost: Dictionary = vghost_v as Dictionary
    if _OccludedGhost.danger_filter(vghost):
      out.append(vghost)
  return out


## Returns a shallow copy of instance belief rows keyed by [code]instance_id[/code].
func get_beliefs() -> Dictionary:
  return _beliefs.duplicate(true)


func get_kind_profile() -> Dictionary:
  return _KindProfile.duplicate_profile(_kind_profile)


## Per-creature Flight skittishness scalar (§1 — not locale memory).
func get_threat_disposition_mod() -> float:
  return _threat_disposition_mod


## Applies benign and/or evade nudges from disposition episode logic (§1).
func apply_disposition_deltas(benign_delta: float, evade_delta: float, motor_v3: Dictionary) -> void:
  var total := benign_delta + evade_delta
  if absf(total) < 1e-8:
    return
  _threat_disposition_mod = _ThreatDisposition.nudge(_threat_disposition_mod, total, motor_v3)


## Test harness — seed disposition without simulating episodes.
func set_threat_disposition_mod_for_test(value: float, motor_v3: Dictionary) -> void:
  _threat_disposition_mod = _ThreatDisposition.clamp_mod(value, motor_v3)


func get_dead_end_marks() -> Array:
  return _dead_end_marks.duplicate(true)


## EWMA kind-profile update per learn-topic registry (§5.7).
func record_observation(
  topic_id: StringName,
  stimulus_kind_id: StringName,
  value: float,
  motor_v3: Dictionary,
) -> void:
  _kind_profile = _KindProfile.record_observation(
    _kind_profile,
    topic_id,
    stimulus_kind_id,
    value,
    Time.get_ticks_msec(),
    motor_v3,
  )


## Returns one kind facet value; neutral prior when unseen (§6.2).
func consult_kind_facet(facet_key: StringName, stimulus_kind_id: StringName, motor_v3: Dictionary) -> float:
  var neutral := float(motor_v3.get("kind_profile_neutral_prior", 0.5))
  return _KindProfile.facet_value(_kind_profile, facet_key, stimulus_kind_id, neutral)


## Records geographic cul-de-sac mark after blocked approach (§3 **B**).
func record_dead_end_mark(
  world_pos: Vector3,
  approach_heading: Vector3,
  goal_kind: StringName,
  instance_id: int,
  now_ms: int,
) -> void:
  _dead_end_marks = _DeadEnd.record_mark(
    _dead_end_marks, world_pos, approach_heading, goal_kind, instance_id, now_ms
  )


## True when [param waypoint] matches a remembered dead-end for [param goal_kind].
func is_waypoint_dead_end(
  creature_pos: Vector3,
  waypoint: Vector3,
  goal_kind: StringName,
  motor_v3: Dictionary,
) -> bool:
  return _DeadEnd.is_waypoint_blocked(
    _dead_end_marks, creature_pos, waypoint, goal_kind, motor_v3
  )


## Clears dead-end marks after successful traverse near [param world_pos].
func clear_dead_end_near(world_pos: Vector3, motor_v3: Dictionary) -> void:
  _dead_end_marks = _DeadEnd.clear_near_success(_dead_end_marks, world_pos, motor_v3)


## Increments passibility_fail_count on incumbent instance belief (§3 **C**).
func increment_passibility_fail(instance_id: int, now_ms: int) -> void:
  _beliefs = _GoalBelief.increment_passibility_fail(_beliefs, instance_id, now_ms)


## Injects [code]kind_yield[/code] on live food entries from kind profile consult.
func enrich_food_split_with_kind_yield(food_split: Dictionary, motor_v3: Dictionary) -> Dictionary:
  var out := food_split.duplicate(true)
  for key in ["ready", "unready"]:
    var enriched: Array = []
    for entry_v in out.get(key, []) as Array:
      if typeof(entry_v) != TYPE_DICTIONARY:
        continue
      var entry: Dictionary = (entry_v as Dictionary).duplicate(true)
      var kind_id: StringName = entry.get("stimulus_kind_id", &"")
      entry["kind_yield"] = consult_kind_facet(_LearnReg.FACET_NUTRITION_YIELD, kind_id, motor_v3)
      enriched.append(entry)
    out[key] = enriched
  return out


## Replaces instance beliefs — test harness only for 6d.1 read slices.
func set_beliefs_for_test(beliefs: Dictionary) -> void:
  _beliefs = beliefs.duplicate(true) if typeof(beliefs) == TYPE_DICTIONARY else {}


## Seeds one precise [code]avoid_hostiles[/code] belief row for ghost fixtures (6d.3).
func seed_threat_belief_for_test(
  instance_id: int,
  world_pos: Vector3,
  now_ms: int,
  stimulus_kind_id: StringName = &"wolf",
  velocity: Vector3 = Vector3.ZERO,
) -> void:
  _beliefs[instance_id] = {
    "instance_id": instance_id,
    "goal_kind": _GkReg.GK_AVOID_HOSTILES,
    "tier": _GoalBelief.TIER_PRECISE,
    "last_world_pos": world_pos,
    "last_observed_ms": now_ms,
    "coarse_entered_ms": 0,
    "consumable_now": false,
    "is_moving": velocity.length_squared() > 1e-8,
    "last_velocity": velocity,
    "passibility_fail_count": 0,
    "last_passibility_fail_ms": 0,
    "stimulus_kind_id": stimulus_kind_id,
  }


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
    "passibility_fail_count": 0,
    "last_passibility_fail_ms": 0,
  }


## Seeds one moving [code]find_food[/code] prey belief for headless fixtures (§12.2 post-6d-explore-prey).
func seed_moving_prey_belief(
  instance_id: int,
  world_pos: Vector3,
  velocity: Vector3,
  now_ms: int,
  stimulus_kind_id: StringName = &"rabbit",
) -> void:
  _beliefs[instance_id] = {
    "instance_id": instance_id,
    "goal_kind": _GkReg.GK_FIND_FOOD,
    "tier": _GoalBelief.TIER_PRECISE,
    "last_world_pos": world_pos,
    "last_observed_ms": now_ms,
    "coarse_entered_ms": 0,
    "consumable_now": true,
    "is_moving": true,
    "last_velocity": velocity,
    "passibility_fail_count": 0,
    "last_passibility_fail_ms": 0,
    "stimulus_kind_id": stimulus_kind_id,
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
    "passibility_fail_count": 0,
    "last_passibility_fail_ms": 0,
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
    if not _belief_instance_passes_diet(int(iid)):
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
    "stimulus_kind_id": _beliefs.get(best_iid, {}).get("stimulus_kind_id", &""),
    "source": &"precise",
  }


## Latch-gated moving prey dropout bridge — [CREATURE_MOVEMENT_V3.md §12.2 D4/D8/D9](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md).
func consult_moving_prey_food(
  engagement_instance_id: int,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  food_split: Dictionary,
  now_ms: int,
  consult_ctx: Dictionary = {},
) -> Dictionary:
  var inactive := {
    "active": false,
    "pos": Vector3.ZERO,
    "instance_id": 0,
    "stimulus_kind_id": &"",
    "source": &"memory_moving",
  }
  if engagement_instance_id == 0:
    return inactive
  if bool(consult_ctx.get("flight_fast_path_active", false)):
    return inactive
  var panic_r := float(motor_v3.get("flight_acute_panic_radius", 220.0))
  for sample_v in consult_ctx.get("threat_samples", []):
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", true)):
      continue
    if float(sample.get("gate_dist", INF)) <= panic_r:
      return inactive
  var live_ids := _GoalBelief.live_food_instance_ids(food_split)
  if live_ids.has(engagement_instance_id):
    return inactive
  if not _beliefs.has(engagement_instance_id):
    return inactive
  var row: Dictionary = _beliefs[engagement_instance_id]
  if row.get("goal_kind", &"") != _GkReg.GK_FIND_FOOD:
    return inactive
  if not bool(row.get("is_moving", false)):
    return inactive
  if not _belief_instance_passes_diet(engagement_instance_id):
    return inactive
  var forget_r := float(motor_v3.get("goal_memory_forget_radius", 2400.0))
  var last_pos: Vector3 = _read_pos(row.get("last_world_pos", Vector3.ZERO))
  if creature_pos.distance_to(last_pos) > forget_r:
    return inactive
  var mover_ttl_ms := int(float(motor_v3.get("goal_memory_mover_ttl_sec", 10.0)) * 1000.0)
  var age_ms := now_ms - int(row.get("last_observed_ms", 0))
  if age_ms > mover_ttl_ms:
    return inactive
  var objective := _GoalBelief.moving_seek_objective_pos(row, motor_v3)
  return {
    "active": true,
    "pos": objective,
    "instance_id": engagement_instance_id,
    "stimulus_kind_id": row.get("stimulus_kind_id", &""),
    "source": &"memory_moving",
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
    if not _belief_instance_passes_diet(int(iid)):
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


## Fractional known-objective count for [param goal_kind] (§1 inventory table).
func count_known_objectives(
  goal_kind: StringName,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  food_split: Dictionary = {},
  now_ms: int = 0,
  _zone_ctx: Dictionary = {},
  live_threat_samples: Array = [],
) -> float:
  if now_ms <= 0:
    now_ms = Time.get_ticks_msec()
  var live_ids := _live_instance_ids_for_goal(goal_kind, food_split, live_threat_samples)
  var total := _count_live_known_objectives(goal_kind, food_split, live_threat_samples)
  total += _count_belief_known_objectives(goal_kind, creature_pos, motor_v3, now_ms, live_ids)
  total += _count_locale_known_objectives(goal_kind, creature_pos, motor_v3)
  return total


## Per-wedge memory coverage for explore bearing pick (§7.3.2).
func explore_bearing_coverage(
  goal_kind: StringName,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  food_split: Dictionary = {},
  now_ms: int = 0,
  zone_ctx: Dictionary = {},
  live_threat_samples: Array = [],
) -> PackedFloat32Array:
  if now_ms <= 0:
    now_ms = Time.get_ticks_msec()
  var wedge_count := maxi(1, int(motor_v3.get("explore_bearing_count", 8)))
  var coverage := PackedFloat32Array()
  coverage.resize(wedge_count)
  for i in wedge_count:
    coverage[i] = 0.0
  _accumulate_belief_bearing_coverage(
    coverage, goal_kind, creature_pos, motor_v3, now_ms, wedge_count
  )
  var near_r := float(motor_v3.get("awareness_radius", 1500.0)) * 0.5
  var live_near_w := float(motor_v3.get("explore_w_live_near", 0.5))
  _accumulate_live_near_bearing_coverage(
    coverage,
    goal_kind,
    creature_pos,
    near_r,
    live_near_w,
    wedge_count,
    food_split,
    zone_ctx,
    live_threat_samples,
  )
  return coverage


func _live_instance_ids_for_goal(
  goal_kind: StringName,
  food_split: Dictionary,
  live_threat_samples: Array,
) -> Dictionary:
  if goal_kind == _GkReg.GK_FIND_FOOD:
    return _GoalBelief.live_food_instance_ids(food_split)
  if goal_kind != _GkReg.GK_AVOID_HOSTILES:
    return {}
  var seen: Dictionary = {}
  for sample_v in live_threat_samples:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v as Dictionary
    if not bool(sample.get("in_awareness", false)):
      continue
    var iid := int(sample.get("instance_id", 0))
    if iid != 0:
      seen[iid] = true
  return seen


func _count_live_known_objectives(
  goal_kind: StringName,
  food_split: Dictionary,
  live_threat_samples: Array,
) -> float:
  if goal_kind == _GkReg.GK_FIND_FOOD:
    var count := 0.0
    for key in ["ready", "unready"]:
      for entry_v in food_split.get(key, []) as Array:
        if typeof(entry_v) != TYPE_DICTIONARY:
          continue
        var entry: Dictionary = entry_v as Dictionary
        var iid := int(entry.get("instance_id", 0))
        if not _belief_instance_passes_diet(iid):
          continue
        count += 1.0
    return count
  if goal_kind == _GkReg.GK_AVOID_HOSTILES:
    var seen: Dictionary = {}
    var count := 0.0
    for sample_v in live_threat_samples:
      if typeof(sample_v) != TYPE_DICTIONARY:
        continue
      var sample: Dictionary = sample_v as Dictionary
      if not bool(sample.get("in_awareness", false)):
        continue
      var iid := int(sample.get("instance_id", 0))
      if iid != 0 and seen.has(iid):
        continue
      if iid != 0:
        seen[iid] = true
      count += 1.0
    return count
  return 0.0


func _count_belief_known_objectives(
  goal_kind: StringName,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  now_ms: int,
  live_ids: Dictionary,
) -> float:
  var forget_r := float(motor_v3.get("goal_memory_forget_radius", 2400.0))
  var coarse_ttl_ms := int(float(motor_v3.get("goal_memory_coarse_ttl_sec", 15.0)) * 1000.0)
  var global_ttl_ms := int(float(motor_v3.get("goal_memory_ttl_sec", 45.0)) * 1000.0)
  var total := 0.0
  for iid_v in _beliefs.keys():
    var iid := int(iid_v)
    if live_ids.has(iid):
      continue
    var row: Dictionary = _beliefs[iid]
    if row.get("goal_kind", &"") != goal_kind:
      continue
    if goal_kind == _GkReg.GK_FIND_FOOD and not _belief_instance_passes_diet(iid):
      continue
    var last_pos: Vector3 = _read_pos(row.get("last_world_pos", Vector3.ZERO))
    if creature_pos.distance_to(last_pos) > forget_r:
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    var age_ms := now_ms - last_obs
    if age_ms > global_ttl_ms:
      continue
    var tier: StringName = row.get("tier", &"")
    if tier == _GoalBelief.TIER_PRECISE:
      total += 1.0
    elif tier == _GoalBelief.TIER_COARSE:
      if bool(row.get("is_moving", false)):
        continue
      var coarse_entered := int(row.get("coarse_entered_ms", last_obs))
      if now_ms - coarse_entered > coarse_ttl_ms:
        continue
      total += 0.5
  return total


func _count_locale_known_objectives(
  goal_kind: StringName,
  creature_pos: Vector3,
  motor_v3: Dictionary,
) -> float:
  if _locale_store == null:
    return 0.0
  var coverage_cell := _GoalSource.coverage_cell_from_motor(motor_v3)
  var escalate_r := float(motor_v3.get("believed_goal_seek_escalate_radius", 1000.0))
  var total := 0.0
  for key in _locale_store._rows.keys():
    var row: Dictionary = _locale_store._rows[key]
    if row.get("goal_kind") != goal_kind:
      continue
    var cx := int(row.get("cell_x", 0))
    var cy := int(row.get("cell_y", 0))
    var center := _MotorPlane.to_horizontal_vec3(
      Vector2((float(cx) + 0.5) * coverage_cell, (float(cy) + 0.5) * coverage_cell)
    )
    if creature_pos.distance_to(center) > escalate_r:
      continue
    total += 0.25
  return total


func _accumulate_belief_bearing_coverage(
  coverage: PackedFloat32Array,
  goal_kind: StringName,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  now_ms: int,
  wedge_count: int,
) -> void:
  var forget_r := float(motor_v3.get("goal_memory_forget_radius", 2400.0))
  var coarse_ttl_ms := int(float(motor_v3.get("goal_memory_coarse_ttl_sec", 15.0)) * 1000.0)
  var global_ttl_ms := int(float(motor_v3.get("goal_memory_ttl_sec", 45.0)) * 1000.0)
  for iid_v in _beliefs.keys():
    var iid := int(iid_v)
    var row: Dictionary = _beliefs[iid]
    if row.get("goal_kind", &"") != goal_kind:
      continue
    if goal_kind == _GkReg.GK_FIND_FOOD and not _belief_instance_passes_diet(iid):
      continue
    var last_pos: Vector3 = _read_pos(row.get("last_world_pos", Vector3.ZERO))
    var dist := creature_pos.distance_to(last_pos)
    if dist > forget_r:
      continue
    var last_obs := int(row.get("last_observed_ms", 0))
    if now_ms - last_obs > global_ttl_ms:
      continue
    var tier: StringName = row.get("tier", &"")
    var tier_w := 0.0
    if tier == _GoalBelief.TIER_PRECISE:
      tier_w = 1.0
    elif tier == _GoalBelief.TIER_COARSE:
      var coarse_entered := int(row.get("coarse_entered_ms", last_obs))
      if now_ms - coarse_entered > coarse_ttl_ms:
        continue
      tier_w = 0.5
    else:
      continue
    var band_w := _coverage_band_weight(dist, motor_v3)
    var wedge := _bearing_wedge_index(creature_pos, last_pos, wedge_count)
    coverage[wedge] += tier_w * band_w


func _accumulate_live_near_bearing_coverage(
  coverage: PackedFloat32Array,
  goal_kind: StringName,
  creature_pos: Vector3,
  near_r: float,
  live_near_w: float,
  wedge_count: int,
  food_split: Dictionary,
  zone_ctx: Dictionary,
  live_threat_samples: Array,
) -> void:
  if goal_kind == _GkReg.GK_FIND_FOOD:
    for key in ["ready", "unready"]:
      for entry_v in food_split.get(key, []) as Array:
        if typeof(entry_v) != TYPE_DICTIONARY:
          continue
        var entry: Dictionary = entry_v as Dictionary
        var iid := int(entry.get("instance_id", 0))
        if not _belief_instance_passes_diet(iid):
          continue
        var pos := _sample_world_pos(entry)
        if creature_pos.distance_to(pos) > near_r:
          continue
        var wedge := _bearing_wedge_index(creature_pos, pos, wedge_count)
        coverage[wedge] += live_near_w
    return
  if goal_kind == _GkReg.GK_AVOID_HOSTILES:
    var seen: Dictionary = {}
    for sample_v in live_threat_samples:
      if typeof(sample_v) != TYPE_DICTIONARY:
        continue
      var sample: Dictionary = sample_v as Dictionary
      if not bool(sample.get("in_awareness", false)):
        continue
      var iid := int(sample.get("instance_id", 0))
      if iid != 0 and seen.has(iid):
        continue
      if iid != 0:
        seen[iid] = true
      var pos := _sample_world_pos(sample)
      if creature_pos.distance_to(pos) > near_r:
        continue
      var wedge := _bearing_wedge_index(creature_pos, pos, wedge_count)
      coverage[wedge] += live_near_w
    return
  if goal_kind == _GkReg.GK_SHELTER:
    var live_ids: Dictionary = {}
    for ghost_v in _OccludedGhost.project_ghosts(zone_ctx, _beliefs, live_ids):
      if typeof(ghost_v) != TYPE_DICTIONARY:
        continue
      var ghost: Dictionary = ghost_v as Dictionary
      if ghost.get("goal_kind", &"") != _GkReg.GK_SHELTER:
        continue
      var pos := _sample_world_pos(ghost)
      if creature_pos.distance_to(pos) > near_r:
        continue
      var wedge := _bearing_wedge_index(creature_pos, pos, wedge_count)
      coverage[wedge] += live_near_w


func _coverage_band_weight(dist: float, motor_v3: Dictionary) -> float:
  var hotspot_r := float(motor_v3.get("believed_goal_hotspot_near_radius", 250.0))
  var escalate_r := float(motor_v3.get("believed_goal_seek_escalate_radius", 1000.0))
  if dist <= hotspot_r:
    return 1.0
  if dist <= escalate_r:
    return 0.5
  return 0.2


func _bearing_wedge_index(creature_pos: Vector3, target_pos: Vector3, wedge_count: int) -> int:
  var delta := target_pos - creature_pos
  delta.y = 0.0
  if delta.length_squared() < 1e-8:
    return 0
  var angle := atan2(delta.x, -delta.z)
  if angle < 0.0:
    angle += TAU
  return int(floor(angle / TAU * float(wedge_count))) % wedge_count


func _sample_world_pos(sample: Dictionary) -> Vector3:
  if sample.has("world_pos_3d"):
    return _read_pos(sample.get("world_pos_3d"))
  if sample.has("pos"):
    return _read_pos(sample.get("pos"))
  if sample.has("world_pos"):
    return _read_pos(sample.get("world_pos"))
  return Vector3.ZERO


func _belief_instance_passes_diet(instance_id: int) -> bool:
  if _food_intake_policy == null or instance_id == 0:
    return true
  if not is_instance_id_valid(instance_id):
    # Remembered beliefs can outlive (or, in tests, never correspond to) a live scene Node —
    # e.g. C4 (CREATURE_MOVEMENT_V3_CLEANUP.md): a stale/synthetic instance_id previously hit
    # instance_from_id() directly and both spammed an engine-level ObjectDB error and silently
    # failed the diet check. No live node to check against — do not gate on diet here.
    return true
  var node := instance_from_id(instance_id)
  return _DietRegistry.node_is_valid_food_for_policy(node, _food_intake_policy)
