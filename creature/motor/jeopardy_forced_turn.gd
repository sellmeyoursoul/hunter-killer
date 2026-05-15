## Tracks straight-line closure on a forward-cone mob and overrides with a scored cardinal turn when jeopardy persists.
extends Object

const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")

const _CARDINALS: Array[Vector2] = [
  Vector2(0.0, -1.0),
  Vector2(1.0, 0.0),
  Vector2(0.0, 1.0),
  Vector2(-1.0, 0.0),
]

const _INTENT_EPS_SQ := 25e-8
const _COST_TIE_EPS := 1e-4


static func reset_state(io_state: Dictionary) -> void:
  io_state.clear()


static func _intent_match(a: Vector2, b: Vector2) -> bool:
  return (a - b).length_squared() <= _INTENT_EPS_SQ


## Closest mob in the forward cone within [param imminent_radius_px] (footprint clearance).
static func primary_threat_in_forward_cone(
  creature_center: Vector2,
  half: Vector2,
  facing: Vector2,
  mobs: Array,
  imminent_radius_px: float,
  cone_cos_threshold: float,
) -> Dictionary:
  var out := {"found": false, "clearance": INF, "mob_pos": Vector2.ZERO}
  if imminent_radius_px <= 0.0 or mobs.is_empty():
    return out
  var f := facing
  if f.length_squared() < 1e-8:
    f = Vector2.RIGHT
  else:
    f = f.normalized()
  var best_clear := INF
  var best_pos := Vector2.ZERO
  for item in mobs:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var mob_pos: Vector2 = item.get("position", Vector2.ZERO)
    var clearance := _Motor.awareness_gate_distance(creature_center, half, mob_pos)
    if clearance >= imminent_radius_px:
      continue
    var delta := mob_pos - creature_center
    var dist := delta.length()
    if dist > 1e-4:
      var u := delta / dist
      if u.dot(f) < cone_cos_threshold:
        continue
    if clearance < best_clear:
      best_clear = clearance
      best_pos = mob_pos
  if best_clear < INF:
    out["found"] = true
    out["clearance"] = best_clear
    out["mob_pos"] = best_pos
  return out


## Updates jeopardy streak state; returns whether a forced turn should fire this tick.
## Params:
## - io_state: Driver-owned dict ([code]last_incumbent[/code], [code]last_clearance[/code], [code]jeopardy_streak[/code]).
## - tick: [code]incumbent[/code], [code]creature_position[/code], [code]creature_half_extents[/code], [code]creature_facing[/code], [code]mobs[/code], [code]imminent_radius_px[/code], [code]cone_cos_threshold[/code], [code]required_ticks[/code].
static func evaluate_jeopardy_tick(tick: Dictionary, io_state: Dictionary) -> Dictionary:
  var result := {"should_force": false, "threat_mob_pos": Vector2.ZERO}
  var incumbent: Vector2 = tick.get("incumbent", Vector2.ZERO)
  var pos: Vector2 = tick["creature_position"]
  var half: Vector2 = tick.get("creature_half_extents", Vector2.ZERO)
  var facing: Vector2 = tick.get("creature_facing", Vector2.RIGHT)
  var mobs: Array = tick.get("mobs", []) as Array
  var imminent_r: float = float(tick.get("imminent_radius_px", 0.0))
  var cone_cos: float = float(tick.get("cone_cos_threshold", -2.0))
  var required := maxi(1, int(tick.get("required_ticks", 5)))

  var threat := primary_threat_in_forward_cone(pos, half, facing, mobs, imminent_r, cone_cos)
  if not bool(threat.get("found", false)):
    io_state.clear()
    return result

  if incumbent.length_squared() <= _INTENT_EPS_SQ:
    io_state.clear()
    return result

  var clearance: float = float(threat["clearance"])
  if not io_state.has("last_clearance"):
    io_state["last_incumbent"] = incumbent
    io_state["last_clearance"] = clearance
    io_state["jeopardy_streak"] = 0
    return result

  var last_inc: Variant = io_state.get("last_incumbent", null)
  var straight := typeof(last_inc) == TYPE_VECTOR2 and _intent_match(incumbent, last_inc as Vector2)
  var last_clear: float = float(io_state["last_clearance"])
  var closing := straight and clearance < last_clear - 0.05

  io_state["last_incumbent"] = incumbent
  io_state["last_clearance"] = clearance

  if not straight:
    io_state["jeopardy_streak"] = 0
    return result

  if closing:
    io_state["jeopardy_streak"] = int(io_state.get("jeopardy_streak", 0)) + 1
  else:
    io_state["jeopardy_streak"] = 0

  if int(io_state.get("jeopardy_streak", 0)) >= required:
    result["should_force"] = true
    result["threat_mob_pos"] = threat["mob_pos"] as Vector2
    io_state["jeopardy_streak"] = 0
    io_state.erase("last_incumbent")
    io_state.erase("last_clearance")
  return result


## Picks a cardinal turn (never [param straight_incumbent] or idle) using motor costs, then widest angle vs [param threat_mob_pos].
static func pick_forced_turn(ctx: Dictionary, straight_incumbent: Vector2, threat_mob_pos: Vector2) -> Vector2:
  var straight := straight_incumbent
  if straight.length_squared() > _INTENT_EPS_SQ:
    straight = straight.normalized()
  else:
    straight = Vector2.RIGHT

  var creature_pos: Vector2 = ctx["creature_position"]
  var speed: float = float(ctx.get("creature_speed", 400.0))
  var lookahead: float = float(ctx.get("lookahead_sec", 0.15))
  var bounds_min: Vector2 = ctx.get("bounds_min", Vector2.ZERO)
  var bounds_max: Vector2 = ctx["bounds_max"]
  var mobs: Array = ctx.get("mobs", []) as Array
  var w_dist: float = float(ctx.get("weight_dist", 0.45))
  var w_dist_sq: float = float(ctx.get("weight_dist_sq", 0.0))
  var w_close: float = float(ctx.get("weight_closing", 1.05))
  var penalty_oob: float = float(ctx.get("penalty_oob", 1e7))
  var eps: float = float(ctx.get("distance_eps", 6.0))
  var footprint_half: Vector2 = ctx.get("creature_half_extents", Vector2.ZERO)
  var w_interior: float = float(ctx.get("weight_interior", 0.0))
  var w_edge: float = float(ctx.get("weight_edge", 0.0))
  var w_obs: float = float(ctx.get("weight_obstacle", 0.0))
  var static_obs: Array = ctx.get("static_obstacles", []) as Array
  var awareness_r: float = float(ctx.get("awareness_radius", 0.0))
  var cone_extra: float = float(ctx.get("awareness_cone_extra", 0.0))
  var cone_cos: float = float(ctx.get("awareness_cone_cos_threshold", -2.0))
  var facing_v: Vector2 = ctx.get("creature_facing", Vector2.RIGHT)
  var sz_env: float = float(ctx.get("creature_size", 0.0))
  var near_thr: float = float(ctx.get("interior_env_near_mob_px", 70.0))
  var d_sq := _Motor.nearest_mob_dist_sq(creature_pos, footprint_half, mobs)
  var mob_threat_high := near_thr > 0.0 and d_sq < near_thr * near_thr
  var interior_p := {
    "active": bool(ctx.get("interior_env_motor_active", false)),
    "weight_solid": float(ctx.get("weight_interior_env_solid", 8000.0)),
    "weight_slow": float(ctx.get("weight_interior_env_slow", 4.0)),
  }
  var env_grid: Variant = ctx.get("environment_grid", null)
  var food_targets: Array = ctx.get("food_seek_targets", []) as Array
  var w_seek_raw: float = float(ctx.get("weight_seek_ready_food", 0.0))
  var imminent_pts: Array = ctx.get("imminent_mob_points", []) as Array
  var imminent_r: float = float(ctx.get("food_seek_imminent_mob_radius_px", 0.0))
  var w_seek := _Motor.effective_food_seek_weight(
    w_seek_raw, creature_pos, footprint_half, imminent_pts, imminent_r
  )
  var unready_food: Array = ctx.get("unready_food_avoid_targets", []) as Array
  var w_avoid_unready: float = float(ctx.get("weight_avoid_unready_food", 0.0))

  var candidates: Array[Vector2] = []
  for d in _CARDINALS:
    if _intent_match(d, straight):
      continue
    candidates.append(d)

  if candidates.is_empty():
    return Vector2(-straight.y, straight.x)

  var best_cost := INF
  var scored: Array = []
  for d in candidates:
    var predicted := creature_pos + d * speed * lookahead
    var cost := _Motor.cost_at_prediction(
      predicted,
      mobs,
      bounds_min,
      bounds_max,
      w_dist,
      w_close,
      penalty_oob,
      eps,
      footprint_half,
      w_interior,
      w_dist_sq,
      w_edge,
      creature_pos,
      awareness_r,
      cone_extra,
      cone_cos,
      facing_v,
      static_obs,
      w_obs,
      mob_threat_high,
      env_grid,
      sz_env,
      interior_p,
      food_targets,
      w_seek,
      imminent_pts,
      imminent_r,
      unready_food,
      w_avoid_unready,
    )
    scored.append({"dir": d, "cost": cost})
    if cost < best_cost:
      best_cost = cost

  var ties: Array[Vector2] = []
  for entry in scored:
    var e: Dictionary = entry
    if float(e["cost"]) <= best_cost + _COST_TIE_EPS:
      ties.append(e["dir"] as Vector2)

  if ties.size() == 1:
    return ties[0]

  var to_mob := threat_mob_pos - creature_pos
  if to_mob.length_squared() < 1e-8:
    return ties[0]

  var u := to_mob.normalized()
  var best_sep := -1.0
  var best_d := ties[0]
  for d in ties:
    var sep := absf(d.x * u.y - d.y * u.x)
    if sep > best_sep + 1e-8:
      best_sep = sep
      best_d = d
    elif absf(sep - best_sep) <= 1e-8 and d.x < best_d.x:
      best_d = d
  return best_d
