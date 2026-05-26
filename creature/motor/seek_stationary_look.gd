## Rotates creature facing through cardinals while no-goal patrol lock holds [code]Vector2.ZERO[/code].
## Used during active seek search so awareness cone sweeps without translation.
extends Object

const _ExploreScr := preload("res://creature/motor/expanding_cardinal_explore.gd")

## Picks a unit eight-way look direction for [param hold_elapsed_ticks] within a repeating 8-segment cycle.
## Params:
## - segment_ticks: Physics ticks to dwell on each heading (clamped to at least 1).
## - hold_elapsed_ticks: Ticks since this stationary hold began (nonnegative).
## - phase_seed: Per-body salt so creatures do not sync sweep phases.
## Returns:
## - One normalized seek heading (N, NE, E, …).
static func pick_facing(segment_ticks: int, hold_elapsed_ticks: int, phase_seed: int) -> Vector2:
  return _ExploreScr.Explore.pick_seek_direction(
    segment_ticks, maxi(0, hold_elapsed_ticks), phase_seed
  )
