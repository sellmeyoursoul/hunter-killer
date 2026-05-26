extends RefCounted
## Preload namespace: [member Explore.pick_seek_direction], [member Explore.pick_cardinal], [member Explore.locate]. Used by [code]AiDriver[/code] (carnivore + herbivore food search) and [code]CardinalAvoidance[/code] hints.
##
## Pattern: ordering RIGHT → DOWN → LEFT → UP (cardinal) or N → NE → … → NW (eight-way). Dwell **n** physics ticks per leg; after a full cycle, **n ← 2n**.

const _MotorOctScr := preload("res://creature/motor/motor_oct_directions.gd")


class Explore:
  const CARDINALS: Array[Vector2] = [
    Vector2.RIGHT,
    Vector2.DOWN,
    Vector2.LEFT,
    Vector2.UP,
  ]


  ## Segment length for cycle [param cycle_index]: [code]base_ticks * 2^cycle_index[/code].
  static func segment_ticks_for_cycle(base_ticks: int, cycle_index: int) -> int:
    var b := maxi(1, base_ticks)
    return maxi(1, b << clampi(cycle_index, 0, 30))


  static func cycle_duration_ticks(base_ticks: int, cycle_index: int) -> int:
    return 4 * segment_ticks_for_cycle(base_ticks, cycle_index)


  ## Maps monotonic time to cycle index, segment index, and segment tick budget.
  static func locate(base_ticks: int, effective_tick: int) -> Dictionary:
    var rem := maxi(0, effective_tick)
    var cycle_index := 0
    for _guard in range(4096):
      var dur := cycle_duration_ticks(base_ticks, cycle_index)
      if rem < dur:
        var seg := segment_ticks_for_cycle(base_ticks, cycle_index)
        var seg_ix := int(floor(float(rem) / float(seg)))
        return {"cycle_index": cycle_index, "segment_index": seg_ix, "segment_ticks": seg}
      rem -= dur
      cycle_index += 1
    return {"cycle_index": 0, "segment_index": 0, "segment_ticks": maxi(1, base_ticks)}


  static func pick_cardinal(base_ticks: int, effective_tick: int, phase_seed: int) -> Vector2:
    var loc: Dictionary = locate(base_ticks, effective_tick)
    var ps := (phase_seed % 4 + 4) % 4
    var slot := (int(loc["segment_index"]) + ps) % 4
    return CARDINALS[slot]


  static func cycle_duration_ticks_seek(base_ticks: int, cycle_index: int) -> int:
    return 8 * segment_ticks_for_cycle(base_ticks, cycle_index)


  static func locate_seek(base_ticks: int, effective_tick: int) -> Dictionary:
    var rem := maxi(0, effective_tick)
    var cycle_index := 0
    for _guard in range(4096):
      var dur := cycle_duration_ticks_seek(base_ticks, cycle_index)
      if rem < dur:
        var seg := segment_ticks_for_cycle(base_ticks, cycle_index)
        var seg_ix := int(floor(float(rem) / float(seg)))
        return {"cycle_index": cycle_index, "segment_index": seg_ix, "segment_ticks": seg}
      rem -= dur
      cycle_index += 1
    return {"cycle_index": 0, "segment_index": 0, "segment_ticks": maxi(1, base_ticks)}


  ## Eight-way patrol / explore sweep (N, NE, E, SE, S, SW, W, NW).
  static func pick_seek_direction(base_ticks: int, effective_tick: int, phase_seed: int) -> Vector2:
    var loc: Dictionary = locate_seek(base_ticks, effective_tick)
    var ps := (phase_seed % 8 + 8) % 8
    var slot := (int(loc["segment_index"]) + ps) % 8
    return _MotorOctScr.SEEK_DIRECTIONS[slot]
