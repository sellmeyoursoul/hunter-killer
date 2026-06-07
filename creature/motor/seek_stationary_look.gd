## Rotates creature facing through 8-way directions while no-goal patrol lock holds [code]Vector3.ZERO[/code].
## Used during active seek search so awareness cone sweeps without translation.
extends Object

const DIRECTION_COUNT: int = 8


## Picks a unit look direction for [param hold_elapsed_ticks] within a repeating 8-segment cycle (N→NE→…→NW).
## Params:
## - segment_ticks: Physics ticks to dwell on each direction (clamped to at least 1).
## - hold_elapsed_ticks: Ticks since this stationary hold began (nonnegative).
## - phase_seed: Per-body salt so creatures do not sync sweep phases.
## Returns:
## - One of [member EightWayDirections.DIRECTIONS] (sector order −Z = N).
static func pick_facing(segment_ticks: int, hold_elapsed_ticks: int, phase_seed: int) -> Vector3:
  var seg := maxi(1, segment_ticks)
  var elapsed := maxi(0, hold_elapsed_ticks)
  var cycle_len := DIRECTION_COUNT * seg
  var rem := elapsed % cycle_len if cycle_len > 0 else 0
  var seg_ix := int(floor(float(rem) / float(seg)))
  var ps := (phase_seed % DIRECTION_COUNT + DIRECTION_COUNT) % DIRECTION_COUNT
  var slot := (seg_ix + ps) % DIRECTION_COUNT
  return EightWayDirections.DIRECTIONS[slot]
