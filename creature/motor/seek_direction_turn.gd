## Shortest-arc 8-way facing turn when an active seek heading changes.
## Dwells on each intermediate heading so awareness can spot off-path goal targets.
extends Object

const _EightWay := preload("res://creature/motor/eight_way_directions.gd")
const _BelievedSector := preload("res://creature/motor/believed_goal_sector.gd")

const DIRECTION_COUNT: int = 8


## Sector index 0..7 for unit [param dir] (+Y = N).
static func sector_index(dir: Vector2) -> int:
  return _BelievedSector.sector_index_for_step(dir)


## Unit direction for sector [param ix] (wrapped mod 8).
static func direction_at_index(ix: int) -> Vector2:
  var n := (ix % DIRECTION_COUNT + DIRECTION_COUNT) % DIRECTION_COUNT
  return _EightWay.DIRECTIONS[n]


## Count of 45° steps along the shortest arc from [param from_dir] to [param to_dir]; 0 when same sector.
static func turn_steps_between(from_dir: Vector2, to_dir: Vector2) -> int:
  if from_dir.length_squared() < 1e-12 or to_dir.length_squared() < 1e-12:
    return 0
  var from_ix := sector_index(from_dir)
  var to_ix := sector_index(to_dir)
  if from_ix == to_ix:
    return 0
  var cw := (to_ix - from_ix + DIRECTION_COUNT) % DIRECTION_COUNT
  var ccw := (from_ix - to_ix + DIRECTION_COUNT) % DIRECTION_COUNT
  return mini(cw, ccw)


## +1 = clockwise, -1 = counter-clockwise along the shortest arc.
static func shortest_turn_sign(from_ix: int, to_ix: int) -> int:
  var cw := (to_ix - from_ix + DIRECTION_COUNT) % DIRECTION_COUNT
  var ccw := (from_ix - to_ix + DIRECTION_COUNT) % DIRECTION_COUNT
  if cw < ccw:
    return 1
  if ccw < cw:
    return -1
  return 1


## Facing after [param step_ix] steps (0-based) from [param from_ix] toward [param to_ix].
static func facing_at_turn_step(from_ix: int, to_ix: int, step_ix: int) -> Vector2:
  var arc_sign := shortest_turn_sign(from_ix, to_ix)
  var ix: int
  if arc_sign > 0:
    ix = (from_ix + step_ix + 1) % DIRECTION_COUNT
  else:
    ix = (from_ix - step_ix - 1 + DIRECTION_COUNT * 8) % DIRECTION_COUNT
  return direction_at_index(ix)


## Picks dwell facing while turning from [param from_dir] to [param to_dir].
## Params:
## - segment_ticks: Physics ticks per intermediate heading (clamped to at least 1).
## - elapsed_ticks: Ticks since this turn began (nonnegative).
## Returns:
## - [code]{ "facing": Vector2, "complete": bool, "steps_total": int }[/code]
static func pick_turn_facing(
  from_dir: Vector2,
  to_dir: Vector2,
  segment_ticks: int,
  elapsed_ticks: int,
) -> Dictionary:
  var steps := turn_steps_between(from_dir, to_dir)
  if steps <= 0:
    var end_f := to_dir.normalized() if to_dir.length_squared() > 1e-12 else from_dir.normalized()
    return {"facing": end_f, "complete": true, "steps_total": 0}
  var seg := maxi(1, segment_ticks)
  var elapsed := maxi(0, elapsed_ticks)
  var total_ticks := steps * seg
  var from_ix := sector_index(from_dir)
  var to_ix := sector_index(to_dir)
  if elapsed >= total_ticks:
    return {"facing": direction_at_index(to_ix), "complete": true, "steps_total": steps}
  var step_ix := int(floor(float(elapsed) / float(seg)))
  return {
    "facing": facing_at_turn_step(from_ix, to_ix, step_ix),
    "complete": false,
    "steps_total": steps,
  }
