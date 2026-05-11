## Pure cardinal motor: score predicted positions and pick lowest-cost intent.
## Params passed via [param ctx] dictionary — see [Project_Docs/MOB_AVOIDANCE_PLAN.md](../../Project_Docs/MOB_AVOIDANCE_PLAN.md).
class_name CardinalAvoidance
extends Object

## Evaluation order for equal cost — first wins (deterministic).
static var _tie_order: Array[Vector2] = [
  Vector2(0.0, -1.0),
  Vector2(1.0, 0.0),
  Vector2(0.0, 1.0),
  Vector2(-1.0, 0.0),
  Vector2.ZERO,
]


## Picks unit intent in tie-order preference among cardinals + idle.
## Params:
## - ctx: Dictionary with keys per MOB_AVOIDANCE_PLAN (`creature_position`, `bounds_max`, `mobs`, …).
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
  var w_dist: float = float(ctx.get("weight_dist", 1.0))
  var w_close: float = float(ctx.get("weight_closing", 0.5))
  var penalty_oob: float = float(ctx.get("penalty_oob", 1e7))
  var eps: float = float(ctx.get("distance_eps", 8.0))

  var best_d := Vector2.ZERO
  var best_cost := INF
  for d in _tie_order:
    var step := d * speed * lookahead
    var predicted := creature_pos + step
    var cost := cost_at_prediction(
      predicted, mobs, bounds_min, bounds_max, w_dist, w_close, penalty_oob, eps
    )
    if cost < best_cost:
      best_cost = cost
      best_d = d
  return best_d


## Accumulates inverse-distance and closing-speed costs for one predicted point.
## Params:
## - predicted: Candidate creature center after `lookahead`.
## - mobs: Array of dicts with `position` and `velocity` (world).
## - bounds_min/max: Axis-aligned clamp rectangle for OOB test.
## - w_dist / w_close / penalty_oob / eps: Tunables from ctx.
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
  eps: float
) -> float:
  if (
    predicted.x < bounds_min.x
    or predicted.x > bounds_max.x
    or predicted.y < bounds_min.y
    or predicted.y > bounds_max.y
  ):
    return penalty_oob

  var total := 0.0
  for item in mobs:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var mob_pos: Vector2 = item.get("position", Vector2.ZERO)
    var mob_vel: Vector2 = item.get("velocity", Vector2.ZERO)
    var delta := predicted - mob_pos
    var dist := delta.length()
    var inv := 1.0 / maxf(eps, dist)
    total += w_dist * inv
    if dist > 1e-4:
      var u := delta / dist
      var closing := mob_vel.dot(u)
      if closing > 0.0:
        total += w_close * closing * inv
  return total
