## Rotates creature facing through cardinals while no-goal patrol lock holds [code]Vector2.ZERO[/code].
## Used during active seek search so awareness cone sweeps without translation.
extends Object

const _ExploreScr := preload("res://creature/motor/expanding_cardinal_explore.gd")

const CARDINALS: Array[Vector2] = [
  Vector2.RIGHT,
  Vector2.DOWN,
  Vector2.LEFT,
  Vector2.UP,
]


## Picks a unit cardinal look direction for [param hold_elapsed_ticks] within a repeating 4-segment cycle.
## Params:
## - segment_ticks: Physics ticks to dwell on each cardinal (clamped to at least 1).
## - hold_elapsed_ticks: Ticks since this stationary hold began (nonnegative).
## - phase_seed: Per-body salt so creatures do not sync sweep phases.
## Returns:
## - One of [member CARDINALS].
static func pick_facing(segment_ticks: int, hold_elapsed_ticks: int, phase_seed: int) -> Vector2:
  var seg := maxi(1, segment_ticks)
  var loc: Dictionary = _ExploreScr.Explore.locate(seg, maxi(0, hold_elapsed_ticks))
  var ps := (phase_seed % 4 + 4) % 4
  var slot := (int(loc["segment_index"]) + ps) % 4
  return CARDINALS[slot]
