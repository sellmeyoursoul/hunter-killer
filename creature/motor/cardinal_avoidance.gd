## Pure cardinal motor: score predicted positions and pick lowest-cost intent.
## Params passed via [param ctx] dictionary — see [Project_Docs/Completed_Features/MOB_AVOIDANCE_PLAN.md](../../Project_Docs/Completed_Features/MOB_AVOIDANCE_PLAN.md).
class_name CardinalAvoidance
extends Object

## Evaluation order for equal cost — first wins when [code]shuffle_tie_break[/code] is false.
static var _tie_order: Array[Vector2] = [
  Vector2(0.0, -1.0),
  Vector2(1.0, 0.0),
  Vector2(0.0, 1.0),
  Vector2(-1.0, 0.0),
  Vector2.ZERO,
]


## World-space distance from mob point to creature footprint ([param creature_center], [param creature_half]) used for awareness gating (matches clearance reference frame).
static func awareness_gate_distance(creature_center: Vector2, creature_half: Vector2, mob_pos: Vector2) -> float:
  var half := creature_half
  if half.x <= 0.0 or half.y <= 0.0:
    return creature_center.distance_to(mob_pos)
  var closest_c := closest_point_on_aabb(creature_center, half, mob_pos)
  return mob_pos.distance_to(closest_c)


## Effective reach: [param base_radius] plus [param cone_extra] when [param mob_pos] lies in forward sector about [param facing].
static func effective_awareness_reach(
  creature_center: Vector2,
  mob_pos: Vector2,
  base_radius: float,
  cone_extra: float,
  cone_cos_threshold: float,
  facing: Vector2,
) -> float:
  var reach := base_radius
  if cone_extra > 0.0 and cone_cos_threshold >= -1.0001:
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
    if u.dot(f) >= cone_cos_threshold:
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


## Picks unit intent in tie-order preference among cardinals + idle.
## Params:
## - ctx: Dictionary with keys per motor plan (`creature_position`, `bounds_max`, `mobs`, …). Optional: [code]shuffle_tie_break[/code], [code]tie_shuffle_seed[/code], [code]weight_interior[/code], [code]weight_dist_sq[/code], [code]weight_edge[/code], [code]deterministic_tie_order[/code].
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
  var eps: float = float(ctx.get("distance_eps", 12.0))
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
  var facing_raw: Variant = ctx.get("creature_facing", Vector2.RIGHT)
  var facing_v: Vector2 = Vector2.RIGHT
  if typeof(facing_raw) == TYPE_VECTOR2:
    facing_v = facing_raw as Vector2

  var order := evaluation_order_from_ctx(ctx)
  var best_d := Vector2.ZERO
  var best_cost := INF
  for d in order:
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
      w_obs
    )
    if cost < best_cost:
      best_cost = cost
      best_d = d
  return best_d


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
      )
      if gd > eff_r:
        continue
    total += _add_mob_cost_terms(
      predicted, half, mob_pos, mob_vel, w_dist, w_close, weight_dist_sq, eps, c_scale
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
  )
