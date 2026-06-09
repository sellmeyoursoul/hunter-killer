## Locale prior store + habitual bias façade ([CREATURE_MEMORY.md §14](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).
extends RefCounted
class_name GoalSourceMemoryStore

const _SectorScr := preload("res://creature/motor/believed_goal_sector.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _EnvGrid := preload("res://environment/environment_grid_baked.gd")
const _PackRes := preload("res://pack_resource_resolver.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

const TIER_SUCCESS := &"SUCCESS"
const TIER_PARTIAL := &"PARTIAL_SUCCESS"
const TIER_FAILURE := &"FAILURE"
const TIER_NEUTRAL := &"NEUTRAL"
const TIER_NEAR_DEATH := &"NEAR_DEATH"

const _CORE_MODALITIES: Array[StringName] = [
  &"lasting_local_change",
  &"squeeze_commit",
  &"return_home",
  &"hide_stealth",
  &"flee_retreat",
  &"open_forage",
  &"fight",
]

const _CORE_POLES: Array[StringName] = [
  &"explorer",
  &"builder",
  &"change",
  &"stability",
  &"compassion",
  &"self_interest",
  &"community",
  &"individual",
]

const _POLE_AXIS: Dictionary = {
  &"explorer": &"explorer_builder",
  &"builder": &"explorer_builder",
  &"change": &"change_stability",
  &"stability": &"change_stability",
  &"compassion": &"compassion_self_interest",
  &"self_interest": &"compassion_self_interest",
  &"community": &"community_individual",
  &"individual": &"community_individual",
}

const _POLE_SIGN: Dictionary = {
  &"explorer": -1,
  &"builder": 1,
  &"change": -1,
  &"stability": 1,
  &"compassion": -1,
  &"self_interest": 1,
  &"community": -1,
  &"individual": 1,
}

const _POLE_AXIS_ORDER: Array[StringName] = [
  &"explorer_builder",
  &"change_stability",
  &"compassion_self_interest",
  &"community_individual",
]

const _RANK_WEIGHTS: Array[float] = [1.0, 0.2, 0.2]

var _rows: Dictionary = {}
var _writes_this_sec: int = 0
var _write_sec_bucket: int = -1
var _last_salient_tier2: StringName = &""
var _last_salient_goal_kind: StringName = &""


static func _read_pos_v3(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


static func effective_modality_allowlist_for_pack(pack_root: String) -> Array:
  var out: Array = []
  var seen: Dictionary = {}
  for m in _CORE_MODALITIES:
    if not seen.has(m):
      seen[m] = true
      out.append(m)
  var root := _PackRes.load_pack_root(pack_root)
  var st: Variant = root.get("strategy_class_tags", {})
  if typeof(st) != TYPE_DICTIONARY:
    return out
  var extras: Variant = (st as Dictionary).get("extra_modalities", [])
  if typeof(extras) != TYPE_ARRAY:
    return out
  for raw in extras as Array:
    var sn := StringName(str(raw).strip_edges())
    if sn == &"" or seen.has(sn):
      continue
    seen[sn] = true
    out.append(sn)
  return out


static func coverage_cell_from_motor(motor_p: Dictionary) -> float:
  return maxf(16.0, float(motor_p.get("explore_coverage_cell", 52.0)))


static func grid_indices_for_anchor(anchor: Vector3, motor_p: Dictionary) -> Vector2i:
  var anchor_2d := Vector2(anchor.x, anchor.z)
  var coverage_cell := coverage_cell_from_motor(motor_p)
  return Vector2i(
    int(floorf(anchor_2d.x / coverage_cell)),
    int(floorf(anchor_2d.y / coverage_cell)),
  )


## Returns [code]false[/code] when [param env_grid] is missing/invalid or anchor cell is OOB ([CREATURE_MEMORY.md §2.1.1](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).
static func anchor_cell_in_bounds(anchor: Vector3, motor_p: Dictionary, env_grid: Variant) -> bool:
  if env_grid == null or not (env_grid is _EnvGrid):
    return false
  var grid := env_grid as EnvironmentGridBaked
  if not grid.is_valid_shape():
    return false
  var coverage_cell := coverage_cell_from_motor(motor_p)
  var rel := Vector2(anchor.x, anchor.z)
  var cx := int(floorf(rel.x / coverage_cell))
  var cy := int(floorf(rel.y / coverage_cell))
  return cx >= 0 and cy >= 0 and cx < grid.cell_width and cy < grid.cell_height


static func context_hash_for_find_food(
  goal_kind: StringName, anchor: Vector3, motor_p: Dictionary, env_grid: Variant
) -> int:
  if not anchor_cell_in_bounds(anchor, motor_p, env_grid):
    return -1
  var idx := grid_indices_for_anchor(anchor, motor_p)
  var payload: Array = [str(goal_kind), idx.x, idx.y]
  return hash(payload)


static func context_hash_for_avoid_hostiles(
  goal_kind: StringName, anchor: Vector3, motor_p: Dictionary, env_grid: Variant
) -> int:
  return context_hash_for_find_food(goal_kind, anchor, motor_p, env_grid)


static func context_hash_for_goal_kind(
  goal_kind: StringName,
  anchor: Vector3,
  motor_p: Dictionary,
  env_grid: Variant,
) -> int:
  if goal_kind == _GkReg.GK_FIND_FOOD:
    return context_hash_for_find_food(goal_kind, anchor, motor_p, env_grid)
  if goal_kind == _GkReg.GK_AVOID_HOSTILES:
    return context_hash_for_avoid_hostiles(goal_kind, anchor, motor_p, env_grid)
  return -1


static func nearest_eligible_food_anchor(targets: Array, creature_pos: Vector3) -> Vector3:
  var best := Vector3.ZERO
  var best_d := INF
  for t in targets:
    var pt := Vector3.ZERO
    if typeof(t) == TYPE_VECTOR3:
      pt = t as Vector3
    elif typeof(t) == TYPE_DICTIONARY:
      var dv: Variant = (t as Dictionary).get("pos", null)
      if typeof(dv) == TYPE_VECTOR3:
        pt = dv as Vector3
      else:
        continue
    else:
      continue
    var d := creature_pos.distance_to(pt)
    if d < best_d:
      best_d = d
      best = pt
  if best_d >= INF:
    return Vector3.ZERO
  return best


static func validate_episode_tags(
  pole_tags: Array,
  modality_tags: Array,
  effective_modality_allowlist: Array,
  emitter_knows_modality: bool,
) -> Dictionary:
  var poles_out: Array = []
  var pole_seen_axis: Dictionary = {}
  for raw in pole_tags:
    var p := StringName(str(raw).strip_edges())
    if p == &"":
      continue
    if p not in _CORE_POLES:
      return {"ok": false, "poles": [], "modalities": []}
    var axis: StringName = _POLE_AXIS.get(p, &"")
    var strength := 1.0
    if pole_seen_axis.has(axis):
      if strength <= float(pole_seen_axis[axis]):
        continue
    pole_seen_axis[axis] = strength
    poles_out.append(p)
  var mod_out: Array = []
  for raw in modality_tags:
    var m := StringName(str(raw).strip_edges())
    if m == &"":
      continue
    var allowed := false
    for a in effective_modality_allowlist:
      if a == m:
        allowed = true
        break
    if not allowed:
      push_error("goal_source_memory: stripped unknown modality %s" % str(m))
      continue
    mod_out.append(m)
  if emitter_knows_modality and mod_out.is_empty():
    return {"ok": false, "poles": [], "modalities": []}
  return {"ok": true, "poles": poles_out, "modalities": mod_out}


static func build_modality_tags_from_motor_ctx(motor_ctx: Dictionary, goal_kind: StringName) -> Array:
  var active: Array = []
  if bool(motor_ctx.get("tactic_in_squeeze", false)):
    active.append(&"squeeze_commit")
  if bool(motor_ctx.get("tactic_jeopardy_egress", false)):
    active.append(&"flee_retreat")
  if bool(motor_ctx.get("tactic_hide_viable", false)):
    active.append(&"hide_stealth")
  if bool(motor_ctx.get("tactic_return_home_payoff", false)):
    active.append(&"return_home")
  if bool(motor_ctx.get("tactic_lasting_local_change", false)):
    active.append(&"lasting_local_change")
  if bool(motor_ctx.get("tactic_fight_active", false)):
    active.append(&"fight")
  if not active.is_empty():
    return active
  if goal_kind == _GkReg.GK_FIND_FOOD:
    return [&"open_forage"]
  if goal_kind == _GkReg.GK_AVOID_HOSTILES:
    return [&"flee_retreat"]
  return []


static func infer_pole_for_modality(modality: StringName, motor_ctx: Dictionary) -> StringName:
  match modality:
    &"lasting_local_change":
      return &"builder"
    &"return_home":
      return &"stability"
    &"squeeze_commit":
      if int(motor_ctx.get("conspecific_aid_count", 0)) >= 1:
        return &"community"
      return &"individual"
    &"flee_retreat":
      return &"individual"
    &"hide_stealth":
      if bool(motor_ctx.get("hide_hold_still", false)):
        return &"stability"
      return &"change"
    &"fight":
      return &"self_interest"
    &"open_forage":
      return &"explorer"
    _:
      return &"explorer"


static func rank_modality_tags(
  modality_tags: Array, motor_ctx: Dictionary, rows: Dictionary, goal_kind: StringName, ctx_hash: int
) -> Array:
  var scored: Array = []
  for tag in modality_tags:
    var sn := StringName(tag)
    var fit := current_fit_for_modality(sn, motor_ctx, Vector3.ZERO, 0.0)
    var store_key := _row_key(goal_kind, ctx_hash, sn)
    var stored := 0.0
    if rows.has(store_key):
      stored = float((rows[store_key] as Dictionary).get("stored_strength", 0.0))
    var strength := fit * stored
    scored.append({"tag": sn, "strength": strength, "fit": fit})
  scored.sort_custom(func(a, b): return float(a["strength"]) > float(b["strength"]))
  var out: Array = []
  for i in mini(3, scored.size()):
    out.append(scored[i]["tag"])
  return out


static func raw_axis_for_pole(traits: Dictionary, pole_tag: StringName) -> float:
  if pole_tag == &"" or pole_tag not in _POLE_AXIS:
    return 0.0
  var axis: StringName = _POLE_AXIS[pole_tag]
  var pole_sign_val := float(_POLE_SIGN.get(pole_tag, 0))
  var scalar := float(traits.get(axis, 0.0))
  return (scalar / 100.0) * pole_sign_val


## Signed Slot A raw (−100…+100) for one pole facet ([CREATURE_GOAL_DRIVERS.md §5.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
static func slot_a_raw_for_pole(traits: Dictionary, pole_tag: StringName) -> float:
  var raw := raw_axis_for_pole(traits, pole_tag)
  var unsigned := clampf(abs(raw) * 100.0, 0.0, 100.0)
  if unsigned < 1e-8:
    return 0.0
  return signf(raw) * unsigned


## Top-3 pole blend across episode pole tags (write-time / tests).
static func pole_blend_from_tags(traits: Dictionary, pole_tags: Array) -> float:
  var scored: Array = []
  var best_per_axis: Dictionary = {}
  for raw in pole_tags:
    var p := StringName(str(raw).strip_edges())
    if p == &"" or p not in _POLE_AXIS:
      continue
    var axis: StringName = _POLE_AXIS[p]
    var strength := absf(raw_axis_for_pole(traits, p))
    if best_per_axis.has(axis) and strength <= float(best_per_axis[axis]["strength"]):
      continue
    best_per_axis[axis] = {"tag": p, "strength": strength}
  for axis in _POLE_AXIS_ORDER:
    if not best_per_axis.has(axis):
      continue
    scored.append(best_per_axis[axis])
  scored.sort_custom(func(a, b): return float(a["strength"]) > float(b["strength"]))
  var blend := 0.0
  for i in mini(3, scored.size()):
    var tag: StringName = scored[i]["tag"]
    blend += _RANK_WEIGHTS[i] * raw_axis_for_pole(traits, tag)
  return blend


static func bell_cap(slot_b_base: float, motor_p: Dictionary) -> float:
  var k := float(motor_p.get("replay_bell_k", 1.4))
  var b_norm := clampf(slot_b_base / 100.0, 0.0, 1.0)
  return (1.0 - exp(-k * b_norm)) * 75.0


static func urgency_boost(
  external_urgency: float, slot_b_base: float, motor_p: Dictionary
) -> float:
  var min_b := float(motor_p.get("replay_urgency_slot_b_min", 90.0))
  if slot_b_base < min_b:
    return 0.0
  var slope := float(motor_p.get("urgency_boost_linear_slope", 25.0))
  return slope * clampf(external_urgency, 0.0, 1.0)


static func cap_final(
  slot_b_base: float, external_urgency: float, motor_p: Dictionary
) -> float:
  return minf(
    100.0,
    bell_cap(slot_b_base, motor_p) + urgency_boost(external_urgency, slot_b_base, motor_p),
  )


static func effective_slot_a(
  slot_a_raw: float, slot_b_base: float, external_urgency: float, motor_p: Dictionary
) -> float:
  if absf(slot_a_raw) < 1e-8:
    return 0.0
  var cap_f := cap_final(slot_b_base, external_urgency, motor_p)
  return signf(slot_a_raw) * minf(absf(slot_a_raw), cap_f)


static func _jeopardy_subscore(motor_ctx: Dictionary, motor_p: Dictionary) -> float:
  if bool(motor_ctx.get("tactic_jeopardy_egress", false)):
    return 1.0
  if bool(motor_ctx.get("herbivore_flee_active", false)):
    return 1.0
  var imminent: Array = motor_ctx.get("imminent_mob_points", []) as Array
  if imminent.is_empty():
    return 0.0
  var pos_v: Variant = motor_ctx.get("creature_position", null)
  if typeof(pos_v) != TYPE_VECTOR3:
    return 1.0
  var pos := pos_v as Vector3
  var r := float(motor_p.get("food_seek_imminent_mob_radius", 100.0))
  for mp in imminent:
    var threat_p := _read_pos_v3(mp)
    if threat_p != Vector3.ZERO and pos.distance_to(threat_p) <= r:
      return 1.0
  return 0.0


static func _hunger_subscore(motor_ctx: Dictionary, motor_p: Dictionary) -> float:
  var cr := float(motor_ctx.get("calorie_ratio", 1.0))
  var ceil_seek := float(motor_p.get("seek_priority_food_ceiling", 0.80))
  if cr >= ceil_seek:
    return 0.0
  if ceil_seek <= 1e-6:
    return 1.0
  return clampf((ceil_seek - cr) / ceil_seek, 0.0, 1.0)


## Bitmask contributors → [code]max[/code] aggregate ([CREATURE_GOAL_DRIVERS.md §5.1.3](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
static func compute_external_urgency(motor_ctx: Dictionary, motor_p: Dictionary) -> float:
  return clampf(
    maxf(_jeopardy_subscore(motor_ctx, motor_p), _hunger_subscore(motor_ctx, motor_p)),
    0.0,
    1.0,
  )


static func current_fit_for_modality(
  modality: StringName, motor_ctx: Dictionary, creature_pos: Vector3, hotspot_r: float
) -> float:
  match modality:
    &"squeeze_commit":
      return 1.0 if bool(motor_ctx.get("tactic_in_squeeze", false)) else 0.0
    &"flee_retreat":
      return 1.0 if bool(motor_ctx.get("tactic_jeopardy_egress", false)) else 0.0
    &"hide_stealth":
      return 1.0 if bool(motor_ctx.get("tactic_hide_viable", false)) else 0.0
    &"lasting_local_change":
      return 1.0 if bool(motor_ctx.get("tactic_lasting_local_change", false)) else 0.0
    &"return_home":
      var hc: Variant = motor_ctx.get("nearest_hotspot_centroid", Vector3.ZERO)
      if typeof(hc) != TYPE_VECTOR3 or hotspot_r <= 1e-4:
        return 0.0
      var dist := creature_pos.distance_to(hc as Vector3)
      return clampf(1.0 - dist / hotspot_r, 0.0, 1.0)
    &"fight":
      return 0.0
    &"open_forage":
      return 0.0
    _:
      return 0.0


static func _row_key(goal_kind: StringName, context_hash: int, modality_tag: StringName) -> String:
  return "%s:%d:%s" % [str(goal_kind), context_hash, str(modality_tag)]


static func _reward_scalar_for_tier(tier: StringName) -> float:
  match tier:
    TIER_SUCCESS, TIER_PARTIAL:
      return 1.0
    TIER_FAILURE, TIER_NEAR_DEATH:
      return -1.0
    _:
      return 0.0


func _rate_limit_ok(motor_p: Dictionary) -> bool:
  var now_sec := int(Time.get_ticks_msec() / 1000.0)
  if now_sec != _write_sec_bucket:
    _write_sec_bucket = now_sec
    _writes_this_sec = 0
  var cap := int(motor_p.get("salient_write_max_per_sec", 100))
  if _writes_this_sec >= cap:
    return false
  _writes_this_sec += 1
  return true


func _same_goal_continuation_blocks(dominant_tier2: StringName, goal_kind: StringName) -> bool:
  if _last_salient_tier2 == &"":
    return false
  return _last_salient_tier2 == dominant_tier2 and _last_salient_goal_kind == goal_kind


func try_salient_write(
  goal_kind: StringName,
  dominant_tier2: StringName,
  anchor: Vector3,
  motor_p: Dictionary,
  env_grid: Variant,
  motor_ctx: Dictionary,
  outcome: Dictionary,
  effective_goal_kinds: Array,
  effective_modality_allowlist: Array,
  _traits: Dictionary = {},
  goal_kind_catalog: Dictionary = {},
) -> bool:
  if not _rate_limit_ok(motor_p):
    return false
  if not _GkReg.validate_goal_kind(goal_kind, effective_goal_kinds):
    push_error("goal_source_memory: reject write — unknown GoalKind %s" % str(goal_kind))
    return false
  if (
    typeof(goal_kind_catalog) == TYPE_DICTIONARY
    and not goal_kind_catalog.is_empty()
    and not _GkReg.salient_writes_enabled(goal_kind, goal_kind_catalog)
  ):
    return false
  var tier: StringName = outcome.get("tier", TIER_NEUTRAL)
  if tier == TIER_NEUTRAL:
    return false
  if _GkReg.tier2_to_default_goal_kind(dominant_tier2) == &"":
    return false
  if _same_goal_continuation_blocks(dominant_tier2, goal_kind):
    return false
  var ctx_hash := context_hash_for_goal_kind(goal_kind, anchor, motor_p, env_grid)
  if ctx_hash < 0:
    return false
  var emitter_knows := bool(motor_ctx.get("tactic_classifier_active", false))
  var mod_tags: Array = build_modality_tags_from_motor_ctx(motor_ctx, goal_kind)
  var pole_tags: Array = []
  if typeof(outcome.get("pole_facet_tags", [])) == TYPE_ARRAY:
    pole_tags = (outcome.get("pole_facet_tags", []) as Array).duplicate()
  var validated := validate_episode_tags(
    pole_tags, mod_tags, effective_modality_allowlist, emitter_knows
  )
  if not bool(validated.get("ok", false)):
    return false
  mod_tags = validated.get("modalities", []) as Array
  pole_tags = validated.get("poles", []) as Array
  var ranked := rank_modality_tags(mod_tags, motor_ctx, _rows, goal_kind, ctx_hash)
  if ranked.is_empty():
    for i in mini(3, mod_tags.size()):
      ranked.append(mod_tags[i])
  if ranked.is_empty():
    return false
  var cell := grid_indices_for_anchor(anchor, motor_p)
  var reward := _reward_scalar_for_tier(tier)
  var now := Time.get_ticks_msec() / 1000.0
  var ewma_a := float(motor_p.get("locale_prior_ewma_alpha", 0.15))
  var write_blend := float(motor_p.get("locale_prior_write_blend", 0.35))
  var pole_rank1 := &"explorer"
  if not pole_tags.is_empty():
    pole_rank1 = pole_tags[0]
  else:
    pole_rank1 = infer_pole_for_modality(ranked[0], motor_ctx)
  for ri in ranked.size():
    var modality: StringName = ranked[ri]
    if ri == 0 and pole_tags.is_empty():
      pole_rank1 = infer_pole_for_modality(modality, motor_ctx)
    var key := _row_key(goal_kind, ctx_hash, modality)
    var row: Dictionary = _rows.get(key, {}) as Dictionary
    if row.is_empty():
      row = {
        "goal_kind": goal_kind,
        "context_hash": ctx_hash,
        "modality_tag": modality,
        "pole_facet_tag": pole_rank1,
        "cell_x": cell.x,
        "cell_y": cell.y,
        "attempt_count": 0,
        "success_count": 0,
        "success_delta": 0.0,
        "stored_strength": 0.0,
        "last_used_time": now,
      }
    row["attempt_count"] = int(row.get("attempt_count", 0)) + 1
    if reward > 0.0:
      row["success_count"] = int(row.get("success_count", 0)) + 1
    row["success_delta"] = lerpf(
      float(row.get("success_delta", 0.0)), reward, ewma_a
    )
    var sr := float(row["success_count"]) / maxf(1.0, float(row["attempt_count"]))
    row["stored_strength"] = lerpf(float(row.get("stored_strength", 0.0)), sr, write_blend)
    row["last_used_time"] = now
    row["pole_facet_tag"] = pole_rank1
    row["cell_x"] = cell.x
    row["cell_y"] = cell.y
    _rows[key] = row
  _last_salient_tier2 = dominant_tier2
  _last_salient_goal_kind = goal_kind
  _evict_if_needed(motor_p, now)
  return true


func clear_salient_continuation() -> void:
  _last_salient_tier2 = &""
  _last_salient_goal_kind = &""


func reset() -> void:
  _rows.clear()
  _writes_this_sec = 0
  _write_sec_bucket = -1
  clear_salient_continuation()


func _evict_if_needed(motor_p: Dictionary, now: float) -> void:
  var max_buckets := int(motor_p.get("locale_prior_max_buckets", 100))
  var base_idle := float(motor_p.get("locale_prior_idle_evict_base_sec", 10.0))
  var per_attempt := float(motor_p.get("locale_prior_idle_evict_per_attempt_sec", 1.0))
  var keys := _rows.keys()
  for key in keys:
    var row: Dictionary = _rows[key]
    var attempts := int(row.get("attempt_count", 0))
    var idle_limit := base_idle + float(maxi(0, attempts - 1)) * per_attempt
    if now - float(row.get("last_used_time", now)) > idle_limit:
      _rows.erase(key)
  while _rows.size() > max_buckets:
    var worst_key := ""
    var worst_score := -INF
    for key in _rows.keys():
      var row: Dictionary = _rows[key]
      var idle_age := now - float(row.get("last_used_time", now))
      var attempts2 := maxi(1, int(row.get("attempt_count", 1)))
      var score := idle_age / float(attempts2)
      if score > worst_score:
        worst_score = score
        worst_key = key
    if worst_key == "":
      break
    _rows.erase(worst_key)


func decay_tick(motor_p: Dictionary) -> void:
  var ewma_a := float(motor_p.get("locale_prior_ewma_alpha", 0.15))
  for key in _rows.keys():
    var row: Dictionary = _rows[key]
    row["success_delta"] = lerpf(float(row.get("success_delta", 0.0)), 0.0, ewma_a)
    row["stored_strength"] = lerpf(float(row.get("stored_strength", 0.0)), 0.0, ewma_a * 0.25)
    _rows[key] = row


func consult_replay_weight(
  goal_kind: StringName,
  consult_hash: int,
  motor_p: Dictionary,
  motor_ctx: Dictionary,
  creature_pos: Vector3,
  traits: Dictionary,
) -> float:
  if consult_hash < 0:
    return 1.0
  var best_strength := 0.0
  var best_bundle: Dictionary = {}
  var hotspot_r := float(motor_p.get("believed_goal_hotspot_near_radius", 250.0))
  for key in _rows.keys():
    var row: Dictionary = _rows[key]
    if row.get("goal_kind") != goal_kind:
      continue
    if int(row.get("context_hash", -1)) != consult_hash:
      continue
    var mod: StringName = row.get("modality_tag", &"")
    if not _modality_allowed(mod, motor_ctx):
      continue
    row["last_used_time"] = Time.get_ticks_msec() / 1000.0
    _rows[key] = row
    var stored := float(row.get("stored_strength", 0.0))
    var bundle := _replay_rank_bundle(row, motor_p, motor_ctx, creature_pos, traits, hotspot_r)
    var rank := float(bundle.get("replay_rank_score", 0.0))
    if rank > float(best_bundle.get("replay_rank_score", -1.0)) or (
      is_equal_approx(rank, float(best_bundle.get("replay_rank_score", -1.0)))
      and stored > best_strength
    ):
      best_bundle = bundle
      best_strength = stored
  if best_strength <= 1e-8 and float(best_bundle.get("replay_rank_score", 0.0)) <= 1e-8:
    return 1.0
  var slot_b := float(best_bundle.get("slot_b_base", 0.0))
  var confidence := float(best_bundle.get("confidence", 1.0))
  var pole: StringName = best_bundle.get("pole_facet_tag", &"explorer") as StringName
  var slot_a_raw := slot_a_raw_for_pole(traits, pole)
  var ext := compute_external_urgency(motor_ctx, motor_p)
  var effective_a := effective_slot_a(slot_a_raw, slot_b, ext, motor_p)
  var replay_delta := effective_a * (slot_b / 100.0) * confidence
  return best_strength * (1.0 + replay_delta / 100.0)


func _modality_allowed(mod: StringName, motor_ctx: Dictionary) -> bool:
  if mod == &"":
    return false
  var allow: Variant = motor_ctx.get("effective_modality_allowlist", null)
  if typeof(allow) != TYPE_ARRAY:
    return true
  for a in allow as Array:
    if a == mod:
      return true
  return false


func _replay_rank_bundle(
  row: Dictionary,
  motor_p: Dictionary,
  motor_ctx: Dictionary,
  creature_pos: Vector3,
  traits: Dictionary,
  hotspot_r: float,
) -> Dictionary:
  var modality: StringName = row.get("modality_tag", &"open_forage")
  var fit := current_fit_for_modality(modality, motor_ctx, creature_pos, hotspot_r)
  var stored := float(row.get("stored_strength", 0.0))
  var fit_blend := fit * stored
  var k := float(motor_p.get("replay_bell_k", 1.4))
  var w_fit := float(motor_p.get("replay_w_fit", 0.4))
  var w_store := float(motor_p.get("replay_w_store", 0.6))
  var x_blend := w_fit * fit_blend + w_store * stored
  var slot_b := (1.0 - exp(-k * x_blend)) * 100.0
  var attempts := int(row.get("attempt_count", 0))
  var successes := int(row.get("success_count", 0))
  var n_sat := float(motor_p.get("replay_n_sat", 10.0))
  var n_min := float(motor_p.get("replay_n_min", 3.0))
  var evidence := 1.0 - exp(-float(attempts) / maxf(1.0, n_sat))
  var success_rate := float(successes) / maxf(1.0, float(attempts))
  var thin_cap := minf(1.0, float(attempts) / maxf(1.0, n_min))
  var delta := float(row.get("success_delta", 0.0))
  var delta_factor := clampf(1.0 + 0.1 * signf(delta), 0.85, 1.15)
  var confidence := clampf(evidence * (0.5 + 0.5 * success_rate) * thin_cap * delta_factor, 0.0, 1.0)
  var change_stability := float(traits.get("change_stability", 0.0))
  var t := (change_stability + 100.0) / 200.0
  var mixed_penalty := 4.0 * success_rate * (1.0 - success_rate)
  var failures := attempts - successes
  var streak_bonus := (1.0 - evidence) if failures == 0 and attempts > 0 else 0.0
  var novelty_score := (1.0 - evidence) * (1.0 - mixed_penalty) + streak_bonus
  var proven_score := evidence * (0.5 + 0.5 * success_rate)
  var trait_rank_bias := lerpf(novelty_score, proven_score, t)
  var pole: StringName = row.get("pole_facet_tag", &"explorer")
  return {
    "slot_b_base": slot_b,
    "confidence": confidence,
    "replay_rank_score": slot_b * confidence * trait_rank_bias,
    "pole_facet_tag": pole,
  }


func _replay_rank_score(
  row: Dictionary,
  motor_p: Dictionary,
  motor_ctx: Dictionary,
  creature_pos: Vector3,
  traits: Dictionary,
  hotspot_r: float,
) -> float:
  return float(
    _replay_rank_bundle(row, motor_p, motor_ctx, creature_pos, traits, hotspot_r).get(
      "replay_rank_score", 0.0
    )
  )


static func project_believed_goal_bias(
  creature_pos: Vector3,
  dominant_goal_kind: StringName,
  motor_p: Dictionary,
  store: GoalSourceMemoryStore = null,
  food_anchor: Vector3 = Vector3.ZERO,
  env_grid: Variant = null,
  motor_ctx: Dictionary = {},
  coarse_sector_weights: Array = [],
  traits: Dictionary = {},
) -> Dictionary:
  var sector_out: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  for i in mini(8, coarse_sector_weights.size()):
    sector_out[i] = float(coarse_sector_weights[i])
  var pull_dir := Vector3.ZERO
  var pull_mag := 0.0
  if store == null or dominant_goal_kind != _GkReg.GK_FIND_FOOD:
    return {"pull_dir": pull_dir, "pull_mag": pull_mag, "sector_weights": sector_out}
  var hotspot_r := float(motor_p.get("believed_goal_hotspot_near_radius", 250.0))
  var w_norm := float(motor_p.get("locale_prior_pull_w_norm", 3.0))
  var coverage_cell := coverage_cell_from_motor(motor_p)
  var candidates: Array = []
  for key in store._rows.keys():
    var row: Dictionary = store._rows[key]
    if row.get("goal_kind") != _GkReg.GK_FIND_FOOD:
      continue
    var cx := int(row.get("cell_x", 0))
    var cy := int(row.get("cell_y", 0))
    var center_2d := Vector2((float(cx) + 0.5) * coverage_cell, (float(cy) + 0.5) * coverage_cell)
    var center := _MotorPlane.to_horizontal_vec3(center_2d)
    var dist := creature_pos.distance_to(center)
    if dist > hotspot_r:
      continue
    var rank := store._replay_rank_score(row, motor_p, motor_ctx, creature_pos, traits, hotspot_r)
    row["last_used_time"] = Time.get_ticks_msec() / 1000.0
    store._rows[key] = row
    candidates.append({"center": center, "rank": rank, "stored": float(row.get("stored_strength", 0.0))})
  candidates.sort_custom(func(a, b):
    if not is_equal_approx(float(a["rank"]), float(b["rank"])):
      return float(a["rank"]) > float(b["rank"])
    return float(a["stored"]) > float(b["stored"])
  )
  var top: Array = []
  for i in mini(3, candidates.size()):
    top.append(candidates[i])
  var sum_w := 0.0
  var centroid := Vector3.ZERO
  for item in top:
    var w := float(item["rank"])
    sum_w += w
    centroid += (item["center"] as Vector3) * w
  if sum_w > 1e-8:
    centroid /= sum_w
    var delta := centroid - creature_pos
    if delta.length_squared() > 1e-12:
      pull_dir = delta.normalized()
    pull_mag = clampf(sum_w / maxf(w_norm, 1e-6), 0.0, 1.0)
  var consult_hash := -1
  if food_anchor != Vector3.ZERO:
    consult_hash = context_hash_for_find_food(
      _GkReg.GK_FIND_FOOD, food_anchor, motor_p, env_grid
    )
  var replay_w := 1.0
  if store != null and consult_hash >= 0:
    replay_w = store.consult_replay_weight(
      _GkReg.GK_FIND_FOOD, consult_hash, motor_p, motor_ctx, creature_pos, traits
    )
  return {
    "pull_dir": pull_dir,
    "pull_mag": pull_mag,
    "sector_weights": sector_out,
    "replay_weight": replay_w,
    "consult_context_hash": consult_hash,
    "hotspot_centroid": centroid,
    "nearest_prior_dist": _nearest_find_food_prior_dist(store, creature_pos, motor_p),
  }


## Distance to nearest [code]find_food[/code] locale row center, or [code]INF[/code] if none.
static func _nearest_find_food_prior_dist(
  store: GoalSourceMemoryStore, creature_pos: Vector3, motor_p: Dictionary
) -> float:
  if store == null:
    return INF
  var coverage_cell := coverage_cell_from_motor(motor_p)
  var best := INF
  for key in store._rows.keys():
    var row: Dictionary = store._rows[key]
    if row.get("goal_kind") != _GkReg.GK_FIND_FOOD:
      continue
    var cx := int(row.get("cell_x", 0))
    var cy := int(row.get("cell_y", 0))
    var center := _MotorPlane.to_horizontal_vec3(
      Vector2((float(cx) + 0.5) * coverage_cell, (float(cy) + 0.5) * coverage_cell)
    )
    best = minf(best, creature_pos.distance_to(center))
  return best


## [CREATURE_MOVEMENT_V2 §A.3.1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md): boost seek when priors exist in escalate band but not hotspot.
static func escalate_seek_multiplier(
  store: GoalSourceMemoryStore,
  creature_pos: Vector3,
  motor_p: Dictionary,
  dominant_tier2: StringName,
  pull_mag: float,
) -> float:
  if store == null or dominant_tier2 != _GkReg.GK_FIND_FOOD:
    return 1.0
  if pull_mag > 1e-4:
    return 1.0
  var hotspot_r := float(motor_p.get("believed_goal_hotspot_near_radius", 250.0))
  var escalate_r := float(motor_p.get("believed_goal_seek_escalate_radius", 1000.0))
  var nearest := _nearest_find_food_prior_dist(store, creature_pos, motor_p)
  if nearest > hotspot_r and nearest <= escalate_r:
    return float(motor_p.get("believed_goal_escalate_seek_mul", 1.35))
  return 1.0


## Threat-response consult ([CREATURE_MEMORY.md §14.3](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)): rank [code]avoid_hostiles[/code] rows only — no flee cardinal term.
func consult_threat_response(
  creature_pos: Vector3,
  motor_p: Dictionary,
  motor_ctx: Dictionary,
  traits: Dictionary,
) -> Dictionary:
  var best_mod := &""
  var best_rank := 0.0
  var hotspot_r := float(motor_p.get("believed_goal_hotspot_near_radius", 250.0))
  var ctx_hash := context_hash_for_avoid_hostiles(
    _GkReg.GK_AVOID_HOSTILES, creature_pos, motor_p, motor_ctx.get("environment_grid", null)
  )
  for key in _rows.keys():
    var row: Dictionary = _rows[key]
    if row.get("goal_kind") != _GkReg.GK_AVOID_HOSTILES:
      continue
    var mod: StringName = row.get("modality_tag", &"")
    if mod == &"":
      continue
    row["last_used_time"] = Time.get_ticks_msec() / 1000.0
    _rows[key] = row
    var rank := _replay_rank_score(row, motor_p, motor_ctx, creature_pos, traits, hotspot_r)
    if rank > best_rank:
      best_rank = rank
      best_mod = mod
  return {
    "preferred_modality": best_mod,
    "replay_rank_score": best_rank,
    "consult_context_hash": ctx_hash,
  }


static func align_step_with_sector(d: Vector3, sector_s: int) -> float:
  return _SectorScr.align_step_with_sector(d, sector_s)
