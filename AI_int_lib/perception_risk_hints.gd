## Pure kinematic hints so the LLM ranks threats - vector closing (option B).
## Uses world positions and velocities; no scene tree.
class_name PerceptionRiskHints
extends Object

## Treat mobs slower than this (world px/s) as not closing for threat dot math.
static var mob_speed_eps: float = 15.0
## Radial inward speed (toward playable creature axis, px/s) must exceed this to count as closing.
static var closing_radial_eps: float = 10.0
## Creature speed magnitude below → `stopped` hint band (world px/s).
static var creature_stopped_eps: float = 1.0

## Computes playable creature grid patch and stationary vs motion band labels.
## Params:
## - pr, pc: creature cell row/col (aligned with occupancy grid indexing).
## - rows, cols: grid dimensions used for boundary tests.
## - creature_vel: current creature velocity vector (world space).
## Returns:
## - Dictionary `{ "patch": "corner"|"wall"|"interior", "band": "moving"|"stopped" }`.
static func classify_creature_patch_and_band(pr: int, pc: int, rows: int, cols: int, creature_vel: Vector2) -> Dictionary:
  var on_top := pr <= 0
  var on_bot := pr >= rows - 1
  var on_left := pc <= 0
  var on_right := pc >= cols - 1
  var on_wall := on_top or on_bot or on_left or on_right
  var patch: String
  if on_wall:
    patch = (
      "corner"
      if (on_top or on_bot) and (on_left or on_right)
      else "wall")
  else:
    patch = "interior"
  var band := "stopped" if creature_vel.length_squared() <= creature_stopped_eps * creature_stopped_eps else "moving"
  return {"patch": patch, "band": band}


## Returns closing metrics between one mob sample and the creature sampling point.
## Params:
## - mob_point / mob_vel: mob world center and velocity.
## - creature_point: creature world sampling point (stationary for this derivation).
## Returns:
## - `closing`: true when inward radial closing speed rises above thresholds.
## - `t_approx_sec`: INF when not closing else dist / inward_radial_speed.
static func mob_closing_metrics(mob_point: Vector2, mob_vel: Vector2, creature_point: Vector2) -> Dictionary:
  var toward := creature_point - mob_point
  var dist_sq := toward.length_squared()
  var speed := mob_vel.length()
  var inf_sec := INF
  const tiny := 1e-4

  var inward_radial := 0.0

  if dist_sq <= tiny:
    inward_radial = 0.0
    return {"closing": true, "t_approx_sec": 0.0, "inward_radial_px_s": inward_radial}

  if speed < mob_speed_eps:
    return {"closing": false, "t_approx_sec": inf_sec, "inward_radial_px_s": 0.0}

  inward_radial = mob_vel.dot(toward.normalized())

  var closing := inward_radial > closing_radial_eps

  if not closing:
    return {"closing": false, "t_approx_sec": inf_sec, "inward_radial_px_s": inward_radial}

  var t_approx := toward.length() / maxf(inward_radial, closing_radial_eps)
  return {"closing": true, "t_approx_sec": t_approx, "inward_radial_px_s": inward_radial}


## Picks nearest-list salient mob for option B among **closing** movers.
## Mob order is authoritative (nearest Euclidean first — same ordering as emitted MOB lines).
## Tie-break keeps the earliest list index (nearest among equal t_approx_sec).
## Params:
## - mob_entries: dictionaries with `"point"` (Vector2), `"velocity"` (Vector2), keyed in sort order (nearest first).
## - creature_point: creature sampling center.
## Returns:
## - Dictionary `{ "idx_1": int (-1 none), "t_approx_sec": float }`.
static func pick_priority_closing_mob(mob_entries: Array, creature_point: Vector2) -> Dictionary:
  var best_idx_1 := -1
  var best_t := INF
  var idx := 0
  while idx < mob_entries.size():
    var e: Variant = mob_entries[idx]
    if e is Dictionary:
      var mob_point: Vector2 = e.get("point", Vector2.ZERO)
      var mob_vel: Vector2 = e.get("velocity", Vector2.ZERO)
      var metrics: Dictionary = mob_closing_metrics(mob_point, mob_vel, creature_point)
      if bool(metrics["closing"]) and float(metrics["t_approx_sec"]) < best_t:
        best_t = float(metrics["t_approx_sec"])
        best_idx_1 = idx + 1
    idx += 1
  if best_idx_1 < 0:
    return {"idx_1": -1, "t_approx_sec": INF}
  return {"idx_1": best_idx_1, "t_approx_sec": best_t}
