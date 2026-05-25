## Pure cardinal motor: score predicted positions and pick lowest-cost intent.
## Params passed via [param ctx] dictionary — see [Project_Docs/Completed_Features/MOB_AVOIDANCE_PLAN.md](../../Project_Docs/Completed_Features/MOB_AVOIDANCE_PLAN.md).
## Interior grid costs ([EnvironmentGridBaked]) are optional and gated by [code]ctx.interior_env_motor_active[/code] (OBJECT §8.2 — ENGINE-only nudges).
class_name CardinalAvoidance
extends Object

const _ObsStrat := preload("res://creature/motor/motor_obstacle_strategy.gd")
const _GoalMem := preload("res://creature/motor/goal_source_memory.gd")

## Evaluation order for equal cost — first wins when [code]shuffle_tie_break[/code] is false.
static var _tie_order: Array[Vector2] = [
  Vector2(0.0, -1.0),
  Vector2(1.0, 0.0),
  Vector2(0.0, 1.0),
  Vector2(-1.0, 0.0),
  Vector2.ZERO,
]


## Lookahead distance for cardinal static probes (patrol block test, stuck escape, tie-break filter).
static func motor_cardinal_probe_step(he_xy: Vector2) -> float:
  return maxf(maxf(he_xy.x, he_xy.y) * 2.8, 40.0)


## Nearest surface separation between footprint at [param creature_pos] and static AABB obstacles.
static func footprint_static_clearance(creature_pos: Vector2, he_xy: Vector2, static_obs: Array) -> float:
  var best_clear := INF
  for ob in static_obs:
    if typeof(ob) != TYPE_DICTIONARY:
      continue
    var op: Vector2 = ob.get("position", Vector2.ZERO)
    var ohe_raw: Variant = ob.get("half_extents", Vector2.ZERO)
    var ohe := Vector2.ZERO
    if typeof(ohe_raw) == TYPE_VECTOR2:
      ohe = ohe_raw as Vector2
    var sep := INF
    if ohe.x > 0.0 and ohe.y > 0.0:
      var sep_closest_c := closest_point_on_aabb(creature_pos, he_xy, op)
      var sep_closest_o := closest_point_on_aabb(op, ohe, creature_pos)
      sep = sep_closest_c.distance_to(sep_closest_o)
    else:
      sep = creature_pos.distance_to(op) - maxf(he_xy.x, he_xy.y)
    best_clear = minf(best_clear, sep)
  return best_clear


## True when a unit cardinal step would leave the footprint pinched against static geometry.
static func cardinal_step_blocked(
  creature_pos: Vector2,
  he_xy: Vector2,
  direction: Vector2,
  static_obs: Array,
  min_clearance_px: float,
) -> bool:
  if direction.length_squared() < 1e-12 or static_obs.is_empty() or min_clearance_px <= 0.0:
    return false
  var step := motor_cardinal_probe_step(he_xy)
  var probe_pos := creature_pos + direction.normalized() * step
  return footprint_static_clearance(probe_pos, he_xy, static_obs) < min_clearance_px


## First direction in [param order] that also appears in [param tied_dirs] (deterministic plateau tie-break).
static func first_tied_dir_in_eval_order(tied_dirs: Array, order: Array) -> Vector2:
  for d in order:
    if typeof(d) != TYPE_VECTOR2 or (d as Vector2).length_squared() < 1e-14:
      continue
    for td in tied_dirs:
      if typeof(td) == TYPE_VECTOR2 and (td as Vector2).is_equal_approx(d as Vector2):
        return d as Vector2
  if not tied_dirs.is_empty() and typeof(tied_dirs[0]) == TYPE_VECTOR2:
    return tied_dirs[0] as Vector2
  return Vector2.ZERO


## World-space distance from mob point to creature footprint ([param creature_center], [param creature_half]) used for awareness gating (matches clearance reference frame).
static func awareness_gate_distance(creature_center: Vector2, creature_half: Vector2, mob_pos: Vector2) -> float:
  var half := creature_half
  if half.x <= 0.0 or half.y <= 0.0:
    return creature_center.distance_to(mob_pos)
  var closest_c := closest_point_on_aabb(creature_center, half, mob_pos)
  return mob_pos.distance_to(closest_c)


## Effective reach: [param base_radius] plus [param cone_extra] when [param mob_pos] lies in forward sector about [param facing].
## Default ([param forward_cone_only] false): omnidirectional disk at [param base_radius]; forward sector extends to [param base_radius] + [param cone_extra].
## Legacy ([param forward_cone_only] true): targets outside the forward cone have zero reach (no rear disk).
static func effective_awareness_reach(
  creature_center: Vector2,
  mob_pos: Vector2,
  base_radius: float,
  cone_extra: float,
  cone_cos_threshold: float,
  facing: Vector2,
  forward_cone_only: bool = false,
) -> float:
  var delta := mob_pos - creature_center
  var dist := delta.length()
  var u := Vector2.RIGHT
  if dist > 1e-4:
    u = delta / dist
  var f := facing
  if f.length() < 1e-4:
    f = Vector2.RIGHT
  else:
    f = f.normalized()
  var in_forward_cone := true
  if cone_cos_threshold >= -1.0001:
    in_forward_cone = u.dot(f) >= cone_cos_threshold
  if forward_cone_only:
    if not in_forward_cone:
      return 0.0
    return base_radius + cone_extra
  var reach := base_radius
  if cone_extra > 0.0 and in_forward_cone:
    reach = base_radius + cone_extra
  return reach


## Builds evaluation order: fixed [member _tie_order] or **shuffled cardinals** + idle last ([param tie_shuffle_seed] mixes ties without new RNG state each call).
## Params:
## - ctx: Motor context; reads [code]shuffle_tie_break[/code] (default [code]true[/code]), [code]deterministic_tie_order[/code] (force [member _tie_order]), [code]tie_shuffle_seed[/code], [code]creature_position[/code].
## Returns:
## - Array of unit directions ending with [code]Vector2.ZERO[/code].
static func evaluation_order_from_ctx(ctx: Dictionary) -> Array[Vector2]:
  if bool(ctx.get("deterministic_tie_order", false)) or not bool(ctx.get("shuffle_tie_break", true)):
    return _tie_order.duplicate()
  var pos: Vector2 = ctx["creature_position"]
  var rng_seed := int(ctx.get("tie_shuffle_seed", 0))
  rng_seed = rng_seed ^ 0x9e3779b9 ^ int(pos.x * 73856093.0) ^ int(pos.y * 19349663.0)
  if rng_seed == 0:
    rng_seed = 1
  var rng := RandomNumberGenerator.new()
  rng.seed = rng_seed
  var dirs: Array[Vector2] = [
    Vector2(0.0, -1.0),
    Vector2(1.0, 0.0),
    Vector2(0.0, 1.0),
    Vector2(-1.0, 0.0),
  ]
  var i := 3
  while i > 0:
    var j := rng.randi_range(0, i)
    var tmp: Vector2 = dirs[i]
    dirs[i] = dirs[j]
    dirs[j] = tmp
    i -= 1
  dirs.append(Vector2.ZERO)
  return dirs


## Shortest squared distance from [param creature_center] (optionally AABB [param half]) to any mob point in [param mobs].
static func nearest_mob_dist_sq(creature_center: Vector2, half: Vector2, mobs: Array) -> float:
  var best := INF
  for item in mobs:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var mob_pos: Vector2 = item.get("position", Vector2.ZERO)
    var d: float
    if half.x <= 0.0 or half.y <= 0.0:
      d = creature_center.distance_squared_to(mob_pos)
    else:
      var closest := closest_point_on_aabb(creature_center, half, mob_pos)
      d = closest.distance_squared_to(mob_pos)
    if d < best:
      best = d
  return best


## Minimum world distance from creature footprint ([param center], [param half]) to any point in [param points] ([code]Vector2[/code] or dict with [code]position[/code]).
static func minimum_footprint_point_clearance(center: Vector2, half: Vector2, points: Array) -> float:
  var best := INF
  for item in points:
    var pt: Vector2 = Vector2.ZERO
    if typeof(item) == TYPE_VECTOR2:
      pt = item as Vector2
    elif typeof(item) == TYPE_DICTIONARY:
      pt = (item as Dictionary).get("position", Vector2.ZERO)
    else:
      continue
    var d: float
    if half.x <= 0.0 or half.y <= 0.0:
      d = center.distance_to(pt)
    else:
      var closest := closest_point_on_aabb(center, half, pt)
      d = closest.distance_to(pt)
    if d < best:
      best = d
  return best


## Linear pull toward nearest [param food_targets] world point; disabled when any imminent mob is within [param imminent_mob_radius] of [param predicted] footprint. Use [method effective_food_seek_weight] to disable the whole tick from the creature's current footprint.
## **Goal-target memory (planned):** [param food_targets] should include only **precise-tier** remembered positions (within [code]goal_memory_precise_radius_px[/code] stationary envelope **or** the moving last-known disk per CREATURE_MEMORY). Coarse 8-way memories (N, NE, …) are egocentric and change as the creature moves — implement as a separate weak cardinal bias or perception field ([code]weight_coarse_sector_goal_bias[/code]), not as fake [code]Vector2[/code] targets here.
## Params:
## - predicted: Candidate creature center after lookahead.
## - half: Footprint half-extents ([code]Vector2.ZERO[/code] uses center-point distance).
## - food_targets: [code]Array[/code] of [code]Vector2[/code] world positions (ready bushes in awareness + precise-tier memory).
## - weight: Scales summed distance cost; [code]0[/code] disables.
## - imminent_mob_points: Mob centers for survival gating (typically all live mobs).
## - imminent_mob_radius: If [code]> 0[/code] and clearance to any point falls below this, returns [code]0[/code].
## Returns:
## - Nonnegative cost (higher when farther from nearest food); [code]0[/code] when disabled or gated.
static func food_seek_cost_at_prediction(
  predicted: Vector2,
  half: Vector2,
  food_targets: Array,
  weight: float,
  imminent_mob_points: Array,
  imminent_mob_radius: float,
) -> float:
  if weight <= 0.0 or food_targets.is_empty():
    return 0.0
  if imminent_mob_radius > 0.0 and imminent_mob_points.size() > 0:
    if minimum_footprint_point_clearance(predicted, half, imminent_mob_points) < imminent_mob_radius:
      return 0.0
  var best_d := INF
  for t in food_targets:
    if typeof(t) != TYPE_VECTOR2:
      continue
    var pt := t as Vector2
    var d: float
    if half.x <= 0.0 or half.y <= 0.0:
      d = predicted.distance_to(pt)
    else:
      var c := closest_point_on_aabb(predicted, half, pt)
      d = c.distance_to(pt)
    if d < best_d:
      best_d = d
  if not is_finite(best_d):
    return 0.0
  return weight * best_d


## Returns [param weight] or [code]0[/code] when any imminent mob is within [param imminent_mob_radius] of the creature's **current** footprint (survival over foraging for the whole tick).
static func effective_food_seek_weight(
  weight: float,
  creature_center: Vector2,
  half: Vector2,
  imminent_mob_points: Array,
  imminent_mob_radius: float,
) -> float:
  if weight <= 0.0 or imminent_mob_radius <= 0.0 or imminent_mob_points.is_empty():
    return weight
  if minimum_footprint_point_clearance(creature_center, half, imminent_mob_points) < imminent_mob_radius:
    return 0.0
  return weight


## Inverse-distance repulsion for depleted / locked bushes still in motor awareness so the agent does not hug an inedible solid.
## Params:
## - predicted: Candidate creature center after lookahead.
## - half: Footprint half-extents ([code]Vector2.ZERO[/code] uses center-point distance).
## - unready_targets: [code]Vector2[/code] world positions (not pickup-ready this tick).
## - weight: Scales [code]sum(1 / max(eps, dist))[/code]; [code]0[/code] disables.
## - eps: Distance floor (typically shared with mob [code]distance_eps[/code]).
## Returns:
## - Nonnegative cost; rises when [param predicted] moves closer to any unready bush.
static func unready_food_avoid_cost_at_prediction(
  predicted: Vector2,
  half: Vector2,
  unready_targets: Array,
  weight: float,
  eps: float,
) -> float:
  if weight <= 0.0 or unready_targets.is_empty():
    return 0.0
  var total := 0.0
  for t in unready_targets:
    if typeof(t) != TYPE_VECTOR2:
      continue
    var pt := t as Vector2
    var d: float
    if half.x <= 0.0 or half.y <= 0.0:
      d = predicted.distance_to(pt)
    else:
      var c := closest_point_on_aabb(predicted, half, pt)
      d = c.distance_to(pt)
    total += weight / maxf(eps, d)
  return total


## Inverse-distance repulsion for coarse cells already visited this round (ENGINE coverage); discourages retreading when no higher-priority objective applies.
## Params:
## - predicted: Candidate creature center after lookahead.
## - half: Footprint half-extents ([code]Vector2.ZERO[/code] uses center-point distance).
## - trail_centers: Prior cell centers (caller should omit the active cell).
## - weight: Scales [code]sum(1 / max(eps, dist))[/code]; [code]0[/code] disables.
## - eps: Distance floor.
## Returns:
## - Nonnegative cost; rises when [param predicted] approaches previously visited cells.
static func exploration_trail_repulsion_cost(
  predicted: Vector2,
  half: Vector2,
  trail_centers: Array,
  weight: float,
  eps: float,
) -> float:
  if weight <= 0.0 or trail_centers.is_empty():
    return 0.0
  var total := 0.0
  for t in trail_centers:
    if typeof(t) != TYPE_VECTOR2:
      continue
    var pt := t as Vector2
    var d: float
    if half.x <= 0.0 or half.y <= 0.0:
      d = predicted.distance_to(pt)
    else:
      var c := closest_point_on_aabb(predicted, half, pt)
      d = c.distance_to(pt)
    total += weight / maxf(eps, d)
  return total


## Extra cost from baked environment at [param predicted] center (OBJECT §3.5 / §3.6, §8.2.2).
## Params:
## - [param mob_threat_high]: Reserved for §8.2.1 unknown explore/avoid vs mob threat; v1 uses grid solid/slow only.
static func interior_env_cost_at(
  predicted: Vector2,
  environment_grid: Variant,
  creature_size: float,
  _mob_threat_high: bool,
  p: Dictionary,
) -> float:
  if not bool(p.get("active", false)):
    return 0.0
  if creature_size <= 0.0:
    return 0.0
  if environment_grid == null or not (environment_grid is EnvironmentGridBaked):
    return 0.0
  var grid := environment_grid as EnvironmentGridBaked
  if not grid.is_valid_shape():
    return 0.0
  var cell_r := grid.sample_cell_data_at_world(predicted)
  if cell_r == null:
    return 0.0
  if not (cell_r is EnvironmentCellData):
    return 0.0
  var env := cell_r as EnvironmentCellData
  var w_solid: float = float(p.get("weight_solid", 8000.0))
  var w_slow: float = float(p.get("weight_slow", 4.0))
  if not env.can_enter(creature_size):
    return w_solid
  var mult := env.movement_speed_multiplier(creature_size)
  if mult < 0.999:
    return w_slow * (1.0 - mult)
  return 0.0


## Picks unit intent in tie-order preference among cardinals + idle.
## Params:
## - ctx: Dictionary with keys per motor plan (`creature_position`, `bounds_max`, `mobs`, …). Optional: [code]shuffle_tie_break[/code], [code]tie_shuffle_seed[/code], [code]weight_interior[/code], [code]weight_dist_sq[/code], [code]weight_edge[/code], [code]deterministic_tie_order[/code], [code]motor_intent_cost_chaos[/code] (uniform jitter ± this amount per candidate cost; breaks symmetric plateaus; 0 disables), [code]motor_chaos_seed[/code] ([code]tie_shuffle_seed[/code] XOR body id typical), [code]weight_explore_idle_penalty[/code], [code]weight_explore_turn_bias[/code] (no ready-food targets and no high mob threat: penalize idle; [code]weight_explore_turn_bias[/code] lowers cost only for the cardinal matching [code]creature_facing[/code] / last move, not the reverse), [code]explore_trail_centers[/code] + [code]weight_explore_trail_repulsion[/code] (retread penalty), [code]expanding_explore_hint[/code] + [code]weight_expanding_explore_hint[/code] (no ready-food: bias toward expanding cardinal sweep — see [code]expanding_cardinal_explore.gd[/code] [code]Explore[/code]).
## Returns:
## - Normalized cardinal `Vector2` or `Vector2.ZERO`.
## Usage:
## - `CardinalAvoidance.pick_best_move_intent({ "creature_position": p, "bounds_max": sz, "mobs": [...] })`
static func pick_best_move_intent(ctx: Dictionary) -> Vector2:
  var creature_pos: Vector2 = ctx["creature_position"]
  var speed: float = float(ctx.get("creature_speed", 400.0))
  var lookahead: float = float(ctx.get("lookahead_sec", 0.15))
  var bounds_min: Vector2 = ctx.get("bounds_min", Vector2.ZERO)
  var bounds_max: Vector2 = ctx["bounds_max"]
  var mobs: Array = ctx.get("mobs", [])
  var w_dist: float = float(ctx.get("weight_dist", 0.45))
  var w_dist_sq: float = float(ctx.get("weight_dist_sq", 0.0))
  var w_close: float = float(ctx.get("weight_closing", 1.05))
  var penalty_oob: float = float(ctx.get("penalty_oob", 1e7))
  var eps: float = float(ctx.get("distance_eps", 6.0))
  var w_interior: float = float(ctx.get("weight_interior", 0.0))
  var w_edge: float = float(ctx.get("weight_edge", 0.0))
  var w_obs: float = float(ctx.get("weight_obstacle", 0.0))
  var static_obs: Array = ctx.get("static_obstacles", []) as Array
  var half_ext_raw: Variant = ctx.get("creature_half_extents", Vector2.ZERO)
  var footprint_half: Vector2 = (
    Vector2.ZERO
    if typeof(half_ext_raw) != TYPE_VECTOR2
    else half_ext_raw as Vector2
  )
  var awareness_r: float = float(ctx.get("awareness_radius", 0.0))
  var cone_extra: float = float(ctx.get("awareness_cone_extra", 0.0))
  var cone_cos: float = float(ctx.get("awareness_cone_cos_threshold", -2.0))
  var forward_cone_only := bool(ctx.get("awareness_forward_cone_only", false))
  var facing_raw: Variant = ctx.get("creature_facing", Vector2.RIGHT)
  var facing_v: Vector2 = Vector2.RIGHT
  if typeof(facing_raw) == TYPE_VECTOR2:
    facing_v = facing_raw as Vector2

  var sz_env: float = float(ctx.get("creature_size", 0.0))
  var near_thr: float = float(ctx.get("interior_env_near_mob_px", 70.0))
  var d_sq := nearest_mob_dist_sq(creature_pos, footprint_half, mobs)
  var mob_threat_high := near_thr > 0.0 and d_sq < near_thr * near_thr
  var interior_p := {
    "active": bool(ctx.get("interior_env_motor_active", false)),
    "weight_solid": float(ctx.get("weight_interior_env_solid", 8000.0)),
    "weight_slow": float(ctx.get("weight_interior_env_slow", 4.0)),
  }
  var env_grid: Variant = ctx.get("environment_grid", null)
  var food_targets: Array = ctx.get("food_seek_targets", []) as Array
  var prey_seek_targets: Array = ctx.get("prey_seek_targets", []) as Array
  var w_seek_food_raw: float = float(ctx.get("weight_seek_ready_food", 0.0))
  var w_seek_prey_raw: float = float(ctx.get("weight_seek_prey", 0.0))
  var imminent_pts: Array = ctx.get("imminent_mob_points", []) as Array
  var imminent_r: float = float(ctx.get("food_seek_imminent_mob_radius_px", 0.0))
  var unready_food: Array = ctx.get("unready_food_avoid_targets", []) as Array
  var w_avoid_unready: float = float(ctx.get("weight_avoid_unready_food", 0.0))
  var w_idle_explore: float = float(ctx.get("weight_explore_idle_penalty", 0.0))
  var w_turn_explore: float = float(ctx.get("weight_explore_turn_bias", 0.0))
  var trail_centers: Array = ctx.get("explore_trail_centers", []) as Array
  var w_trail_rep: float = float(ctx.get("weight_explore_trail_repulsion", 0.0))
  var w_expand_hint: float = float(ctx.get("weight_expanding_explore_hint", 0.0))
  var expand_hint_raw: Variant = ctx.get("expanding_explore_hint", Vector2.ZERO)
  var explore_mult: float = float(ctx.get("exploration_blend_multiplier", 1.0))
  var allow_explore := explore_mult > 1e-6 and not mob_threat_high
  var w_seek_food := effective_food_seek_weight(
    w_seek_food_raw, creature_pos, footprint_half, imminent_pts, imminent_r
  )
  var pursuit_targets: Array = ctx.get("pursuit_targets", []) as Array
  var w_p_dist: float = float(ctx.get("weight_pursuit_dist", 0.0))
  var w_p_close: float = float(ctx.get("weight_pursuit_closing", 0.0))
  var w_p_sq: float = float(ctx.get("weight_pursuit_dist_sq", 0.0))
  var strat_pts_raw: Variant = ctx.get("aware_obstacle_samples", PackedVector2Array())
  var strat_pts := PackedVector2Array()
  if strat_pts_raw is PackedVector2Array:
    strat_pts = strat_pts_raw as PackedVector2Array
  elif typeof(strat_pts_raw) == TYPE_ARRAY:
    for x in strat_pts_raw as Array:
      if typeof(x) == TYPE_VECTOR2:
        strat_pts.append(x as Vector2)
  var strat_threat: Vector2 = ctx.get("strategic_threat_pos", Vector2.ZERO)
  var strat_prey_pin: Vector2 = ctx.get("strategic_prey_pin_pos", Vector2.ZERO)
  var w_shield: float = float(ctx.get("weight_obstacle_shield_prey", 0.0))
  var w_pin: float = float(ctx.get("weight_obstacle_pin_predator", 0.0))

  var chaos_amp := float(ctx.get("motor_intent_cost_chaos", 0.0))
  var chaos_seed_base := int(ctx.get("motor_chaos_seed", 0))
  if chaos_seed_base == 0:
    chaos_seed_base = int(hash(creature_pos))
  var pick_tick := int(ctx.get("motor_pick_tick", 0))

  var goal_in_sight := (
    not food_targets.is_empty()
    or not prey_seek_targets.is_empty()
    or not pursuit_targets.is_empty()
  )
  var has_active_goal := bool(ctx.get("motor_has_active_goal", goal_in_sight))
  var tie_eps := float(ctx.get("motor_tie_cost_epsilon", 0.45))
  var plateau_random := bool(ctx.get("motor_no_goal_plateau_random", true))
  var block_min_clr := float(ctx.get("motor_cardinal_block_min_clearance_px", 4.0))
  var filter_blocked_cardinals := bool(ctx.get("motor_filter_blocked_cardinals", false))
  filter_blocked_cardinals = (
    filter_blocked_cardinals or (not has_active_goal)
  ) and block_min_clr > 0.0 and not static_obs.is_empty()

  var order := evaluation_order_from_ctx(ctx)
  var best_d := Vector2.ZERO
  var best_cost := INF
  var scored: Array = []
  for d in order:
    if (
      filter_blocked_cardinals
      and d.length_squared() > 1e-14
      and cardinal_step_blocked(creature_pos, footprint_half, d, static_obs, block_min_clr)
    ):
      continue
    var step := d * speed * lookahead
    var predicted := creature_pos + step
    var cost := cost_at_prediction(
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
      w_seek_food,
      imminent_pts,
      imminent_r,
      unready_food,
      w_avoid_unready,
      pursuit_targets,
      w_p_dist,
      w_p_close,
      w_p_sq,
      strat_pts,
      strat_threat,
      strat_prey_pin,
      w_shield,
      w_pin,
      prey_seek_targets,
      w_seek_prey_raw,
      forward_cone_only,
    )
    if w_idle_explore > 0.0 and allow_explore:
      if d.length_squared() < 1e-14:
        cost += w_idle_explore
    if w_turn_explore > 0.0 and allow_explore and d.length_squared() > 1e-14:
      var lm := facing_v
      if lm.length_squared() > 1e-12:
        var u := lm.normalized()
        cost -= w_turn_explore * maxf(0.0, d.dot(u))
    var expand_gate_stuck := bool(ctx.get("motor_stuck_allow_expand_hint", false))
    var expand_allow := allow_explore or expand_gate_stuck
    if w_expand_hint > 0.0 and expand_allow and d.length_squared() > 1e-14:
      if typeof(expand_hint_raw) == TYPE_VECTOR2:
        var zh := expand_hint_raw as Vector2
        if zh.length_squared() > 1e-12:
          if (not mob_threat_high) or expand_gate_stuck:
            var uh := zh.normalized()
            cost -= w_expand_hint * maxf(0.0, d.dot(uh))
    if w_trail_rep > 0.0 and allow_explore:
      cost += exploration_trail_repulsion_cost(
        predicted, footprint_half, trail_centers, w_trail_rep, eps
      )
    cost += believed_goal_step_cost(d, ctx)
    if chaos_amp > 1e-10 and d.length_squared() > 1e-14:
      var dir_rng := RandomNumberGenerator.new()
      var dir_seed := chaos_seed_base
      dir_seed ^= int(d.x * 92837111) ^ int(d.y * 689287499) ^ pick_tick
      dir_rng.seed = maxi(1, absi(dir_seed))
      cost += dir_rng.randf_range(-chaos_amp, chaos_amp)
    scored.append({"dir": d, "cost": cost})
    if cost < best_cost:
      best_cost = cost
      best_d = d
  if plateau_random and not goal_in_sight:
    var tied_dirs: Array[Vector2] = []
    for item in scored:
      if typeof(item) != TYPE_DICTIONARY:
        continue
      var c_cost := float((item as Dictionary).get("cost", INF))
      if c_cost > best_cost + tie_eps:
        continue
      var c_dir: Variant = (item as Dictionary).get("dir", Vector2.ZERO)
      if typeof(c_dir) != TYPE_VECTOR2:
        continue
      var dir_v := c_dir as Vector2
      if dir_v.length_squared() < 1e-14:
        continue
      if filter_blocked_cardinals and cardinal_step_blocked(
        creature_pos, footprint_half, dir_v, static_obs, block_min_clr
      ):
        continue
      tied_dirs.append(dir_v)
    if tied_dirs.size() > 1:
      return first_tied_dir_in_eval_order(tied_dirs, order)
    if tied_dirs.size() == 1:
      return tied_dirs[0]
  return best_d


## Additive habitual-goal costs per cardinal step ([CREATURE_MEMORY.md §14.1](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).
static func believed_goal_step_cost(d: Vector2, ctx: Dictionary) -> float:
  var bias_v: Variant = ctx.get("believed_goal_source_bias", {})
  if typeof(bias_v) != TYPE_DICTIONARY:
    return 0.0
  var bias: Dictionary = bias_v
  var pull_dir: Vector2 = bias.get("pull_dir", Vector2.ZERO)
  var pull_mag := clampf(float(bias.get("pull_mag", 0.0)), 0.0, 1.0)
  var w_pull := float(ctx.get("weight_believed_goal_pull", 0.0))
  var cost := 0.0
  if pull_mag > 1e-8 and w_pull > 1e-8 and d.length_squared() > 1e-12:
    var u_pull := pull_dir.normalized() if pull_dir.length_squared() > 1e-12 else Vector2.ZERO
    cost += -d.normalized().dot(u_pull) * w_pull * pull_mag
  var sector_raw: Variant = bias.get("sector_weights", [])
  if typeof(sector_raw) != TYPE_ARRAY:
    return cost
  var w_sector := float(ctx.get("weight_coarse_sector_goal_bias", 0.0))
  if w_sector <= 1e-8 or d.length_squared() < 1e-12:
    return cost
  var sectors: Array = sector_raw
  for s in range(mini(sectors.size(), 8)):
    var sw := float(sectors[s])
    if sw <= 1e-8:
      continue
    cost += (
      -sw
      * _GoalMem.align_step_with_sector(d, s)
      * w_sector
    )
  return cost


## Closest point on axis-aligned `[center ± half]` to [param world_point] ([param half] nonnegative per axis).
static func closest_point_on_aabb(center: Vector2, half: Vector2, world_point: Vector2) -> Vector2:
  return Vector2(
    clampf(world_point.x, center.x - half.x, center.x + half.x),
    clampf(world_point.y, center.y - half.y, center.y + half.y)
  )


static func _footprint_outside_bounds(center: Vector2, half: Vector2, bounds_min: Vector2, bounds_max: Vector2) -> bool:
  return (
    center.x - half.x < bounds_min.x
    or center.x + half.x > bounds_max.x
    or center.y - half.y < bounds_min.y
    or center.y + half.y > bounds_max.y
  )


## Posture term: penalize predicted center distance from playfield center (normalized by half diagonal). [code]weight[/code] 0 disables.
static func _interior_posture_cost(
  predicted: Vector2, bounds_min: Vector2, bounds_max: Vector2, weight: float, eps: float
) -> float:
  if weight <= 0.0:
    return 0.0
  var c := (bounds_min + bounds_max) * 0.5
  var d := predicted.distance_to(c)
  var scale := 0.5 * bounds_min.distance_to(bounds_max)
  return weight * (d / maxf(eps, scale))


## Penalize closeness to playfield AABB edges (inverse clearance of footprint to bounds). Stronger than center-only posture along mid-walls; [code]weight[/code] 0 disables.
## Params:
## - predicted: Candidate creature center after lookahead.
## - half: Footprint half-extents ([code]Vector2.ZERO[/code] = point at [param predicted]).
## - bounds_min / bounds_max: In-bounds playfield rectangle (same frame as predicted).
## - weight: Scales [code]1 / max(eps, margin_px)[/code] where [code]margin_px[/code] is clearance from footprint to nearest edge.
## - eps: Floor for division (matches mob distance floor for stable tuning).
## Returns:
## - Nonnegative cost contribution.
static func _edge_clearance_cost(
  predicted: Vector2,
  half: Vector2,
  bounds_min: Vector2,
  bounds_max: Vector2,
  weight: float,
  eps: float
) -> float:
  if weight <= 0.0:
    return 0.0
  var margin: float
  if half == Vector2.ZERO:
    var mx := minf(predicted.x - bounds_min.x, bounds_max.x - predicted.x)
    var my := minf(predicted.y - bounds_min.y, bounds_max.y - predicted.y)
    margin = minf(mx, my)
  else:
    var left := predicted.x - half.x - bounds_min.x
    var right := bounds_max.x - (predicted.x + half.x)
    var top := predicted.y - half.y - bounds_min.y
    var bottom := bounds_max.y - (predicted.y + half.y)
    margin = minf(minf(left, right), minf(top, bottom))
  return weight / maxf(eps, margin)


static func _add_mob_cost_terms(
  predicted: Vector2,
  half: Vector2,
  mob_pos: Vector2,
  mob_vel: Vector2,
  w_dist: float,
  w_close: float,
  w_dist_sq: float,
  eps: float,
  scale: float,
) -> float:
  if scale <= 0.0:
    return 0.0
  var closest: Vector2
  var dist: float
  if half == Vector2.ZERO:
    closest = predicted
    dist = predicted.distance_to(mob_pos)
  else:
    closest = closest_point_on_aabb(predicted, half, mob_pos)
    var delta_f := closest - mob_pos
    dist = delta_f.length()
  var inv := 1.0 / maxf(eps, dist)
  var add := 0.0
  add += scale * w_dist * inv
  if w_dist_sq > 0.0:
    add += scale * w_dist_sq * inv * inv
  if dist > 1e-4:
    var toward_creature := closest - mob_pos
    var u := toward_creature / dist
    var closing := mob_vel.dot(u)
    if closing > 0.0:
      add += scale * w_close * closing * inv
  return add


## Accumulates inverse-clearance, closing-speed, and optional interior posture costs for one predicted pose.
## Params:
## - predicted: Candidate creature **center** after `lookahead`.
## - creature_half_extents: Axis-aligned half-size in world space; [code]Vector2.ZERO[/code] uses center-point geometry (legacy/tests).
## - mobs: Array of dicts with `position` and `velocity` (world); optional [code]cost_scale[/code].
## - awareness_radius: If `<= 0`, no distance gating (legacy). Else skip mobs farther than effective cone reach from [param creature_center_aware].
## - awareness_cone_cos_threshold: If `< -1`, cone extra disabled; else forward sector uses [method effective_awareness_reach].
## - static_obstacles: Array of dicts with `position` (center) and `half_extents` (half size of AABB); zero velocity repulsion via [param weight_obstacle].
## - food_targets: Optional [code]Vector2[/code] world positions of pickup-ready food (ENGINE hunger); [param weight_seek_ready_food] scales linear distance cost.
## - imminent_mob_points: Mob centers for disabling food pull when a mob is too close to [param predicted] (survival over foraging).
## - imminent_mob_radius: Clearance threshold in px; [code]0[/code] disables gating.
## - unready_food_targets: Optional [code]Vector2[/code] world positions of bushes in awareness that are **not** pickup-ready; [param weight_avoid_unready_food] adds inverse-distance cost so the agent leaves depleted shrubs.
## - weight_avoid_unready_food: Scales [code]sum(1 / max(eps, dist))[/code] per unready bush; [code]0[/code] disables.
## Returns:
## - Scalar cost (higher = worse).
static func cost_at_prediction(
  predicted: Vector2,
  mobs: Array,
  bounds_min: Vector2,
  bounds_max: Vector2,
  w_dist: float,
  w_close: float,
  penalty_oob: float,
  eps: float,
  creature_half_extents: Vector2 = Vector2.ZERO,
  weight_interior: float = 0.0,
  weight_dist_sq: float = 0.0,
  weight_edge: float = 0.0,
  creature_center_aware: Vector2 = Vector2.ZERO,
  awareness_radius: float = 0.0,
  awareness_cone_extra: float = 0.0,
  awareness_cone_cos_threshold: float = -2.0,
  creature_facing: Vector2 = Vector2.RIGHT,
  static_obstacles: Array = [],
  weight_obstacle: float = 0.0,
  mob_threat_high: bool = false,
  environment_grid: Variant = null,
  interior_creature_size: float = 0.0,
  interior_env_params: Dictionary = {},
  food_targets: Array = [],
  weight_seek_ready_food: float = 0.0,
  imminent_mob_points: Array = [],
  imminent_mob_radius: float = 0.0,
  unready_food_targets: Array = [],
  weight_avoid_unready_food: float = 0.0,
  pursuit_targets: Array = [],
  weight_pursuit_dist: float = 0.0,
  weight_pursuit_closing: float = 0.0,
  weight_pursuit_dist_sq: float = 0.0,
  aware_obstacle_samples: PackedVector2Array = PackedVector2Array(),
  strategic_threat_pos: Vector2 = Vector2.ZERO,
  strategic_prey_pin_pos: Vector2 = Vector2.ZERO,
  weight_obstacle_shield_prey: float = 0.0,
  weight_obstacle_pin_predator: float = 0.0,
  prey_seek_targets: Array = [],
  weight_seek_prey: float = 0.0,
  awareness_forward_cone_only: bool = false,
) -> float:
  var half := creature_half_extents
  if half.x <= 0.0 or half.y <= 0.0:
    half = Vector2.ZERO

  if half == Vector2.ZERO:
    if (
      predicted.x < bounds_min.x
      or predicted.x > bounds_max.x
      or predicted.y < bounds_min.y
      or predicted.y > bounds_max.y
    ):
      return penalty_oob
  elif _footprint_outside_bounds(predicted, half, bounds_min, bounds_max):
    return penalty_oob

  var total := 0.0
  var gate_half := half
  for item in mobs:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var mob_pos: Vector2 = item.get("position", Vector2.ZERO)
    var mob_vel: Vector2 = item.get("velocity", Vector2.ZERO)
    var c_scale: float = float(item.get("cost_scale", 1.0))
    if awareness_radius > 0.0:
      var gd := awareness_gate_distance(creature_center_aware, gate_half, mob_pos)
      var eff_r := effective_awareness_reach(
        creature_center_aware,
        mob_pos,
        awareness_radius,
        awareness_cone_extra,
        awareness_cone_cos_threshold,
        creature_facing,
        awareness_forward_cone_only,
      )
      if gd > eff_r:
        continue
    total += _add_mob_cost_terms(
      predicted, half, mob_pos, mob_vel, w_dist, w_close, weight_dist_sq, eps, c_scale
    )

  for item in pursuit_targets:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var ppos: Vector2 = item.get("position", Vector2.ZERO)
    var pvel: Vector2 = item.get("velocity", Vector2.ZERO)
    var p_scale: float = float(item.get("cost_scale", 1.0))
    if awareness_radius > 0.0:
      var gd2 := awareness_gate_distance(creature_center_aware, gate_half, ppos)
      var eff_p := effective_awareness_reach(
        creature_center_aware,
        ppos,
        awareness_radius,
        awareness_cone_extra,
        awareness_cone_cos_threshold,
        creature_facing,
        awareness_forward_cone_only,
      )
      if gd2 > eff_p:
        continue
    total -= _add_mob_cost_terms(
      predicted,
      half,
      ppos,
      pvel,
      weight_pursuit_dist,
      weight_pursuit_closing,
      weight_pursuit_dist_sq,
      eps,
      p_scale,
    )

  if weight_obstacle > 0.0:
    for ob in static_obstacles:
      if typeof(ob) != TYPE_DICTIONARY:
        continue
      var op: Vector2 = ob.get("position", Vector2.ZERO)
      var ohe_raw: Variant = ob.get("half_extents", Vector2.ZERO)
      var ohe := Vector2.ZERO
      if typeof(ohe_raw) == TYPE_VECTOR2:
        ohe = ohe_raw as Vector2
      if ohe.x <= 0.0 or ohe.y <= 0.0:
        continue
      total += _add_mob_cost_terms(
        predicted, half, op, Vector2.ZERO, w_dist, w_close, weight_dist_sq, eps, weight_obstacle
      )

  total += _interior_posture_cost(predicted, bounds_min, bounds_max, weight_interior, eps)
  total += _edge_clearance_cost(predicted, half, bounds_min, bounds_max, weight_edge, eps)
  total += interior_env_cost_at(
    predicted,
    environment_grid,
    interior_creature_size,
    mob_threat_high,
    interior_env_params,
  )
  total += food_seek_cost_at_prediction(
    predicted,
    half,
    food_targets,
    weight_seek_ready_food,
    imminent_mob_points,
    imminent_mob_radius,
  )
  if weight_seek_prey > 0.0 and not prey_seek_targets.is_empty():
    total += food_seek_cost_at_prediction(
      predicted,
      half,
      prey_seek_targets,
      weight_seek_prey,
      imminent_mob_points,
      imminent_mob_radius,
    )
  total += unready_food_avoid_cost_at_prediction(
    predicted, half, unready_food_targets, weight_avoid_unready_food, eps
  )
  total += _ObsStrat.strategic_obstacle_cost(
    predicted,
    strategic_threat_pos,
    strategic_prey_pin_pos,
    aware_obstacle_samples,
    weight_obstacle_shield_prey,
    weight_obstacle_pin_predator,
    eps,
  )
  return total


## Alias for [method cost_at_prediction] with all optional fields explicit — easier for headless tests than long positional argument lists.
static func cost_at_prediction_aware(
  predicted: Vector2,
  mobs: Array,
  bounds_min: Vector2,
  bounds_max: Vector2,
  w_dist: float,
  w_close: float,
  penalty_oob: float,
  eps: float,
  creature_half_extents: Vector2,
  weight_interior: float,
  weight_dist_sq: float,
  weight_edge: float,
  creature_center_aware: Vector2,
  awareness_radius: float,
  awareness_cone_extra: float,
  awareness_cone_cos_threshold: float,
  creature_facing: Vector2,
  static_obstacles: Array = [],
  weight_obstacle: float = 0.0,
  mob_threat_high: bool = false,
  environment_grid: Variant = null,
  interior_creature_size: float = 0.0,
  interior_env_params: Dictionary = {},
  food_targets: Array = [],
  weight_seek_ready_food: float = 0.0,
  imminent_mob_points: Array = [],
  imminent_mob_radius: float = 0.0,
  unready_food_targets: Array = [],
  weight_avoid_unready_food: float = 0.0,
  pursuit_targets: Array = [],
  weight_pursuit_dist: float = 0.0,
  weight_pursuit_closing: float = 0.0,
  weight_pursuit_dist_sq: float = 0.0,
  aware_obstacle_samples: PackedVector2Array = PackedVector2Array(),
  strategic_threat_pos: Vector2 = Vector2.ZERO,
  strategic_prey_pin_pos: Vector2 = Vector2.ZERO,
  weight_obstacle_shield_prey: float = 0.0,
  weight_obstacle_pin_predator: float = 0.0,
  prey_seek_targets: Array = [],
  weight_seek_prey: float = 0.0,
  awareness_forward_cone_only: bool = false,
) -> float:
  return cost_at_prediction(
    predicted,
    mobs,
    bounds_min,
    bounds_max,
    w_dist,
    w_close,
    penalty_oob,
    eps,
    creature_half_extents,
    weight_interior,
    weight_dist_sq,
    weight_edge,
    creature_center_aware,
    awareness_radius,
    awareness_cone_extra,
    awareness_cone_cos_threshold,
    creature_facing,
    static_obstacles,
    weight_obstacle,
    mob_threat_high,
    environment_grid,
    interior_creature_size,
    interior_env_params,
    food_targets,
    weight_seek_ready_food,
    imminent_mob_points,
    imminent_mob_radius,
    unready_food_targets,
    weight_avoid_unready_food,
    pursuit_targets,
    weight_pursuit_dist,
    weight_pursuit_closing,
    weight_pursuit_dist_sq,
    aware_obstacle_samples,
    strategic_threat_pos,
    strategic_prey_pin_pos,
    weight_obstacle_shield_prey,
    weight_obstacle_pin_predator,
    prey_seek_targets,
    weight_seek_prey,
    awareness_forward_cone_only,
  )
