extends RefCounted
## Preload namespace: [member Explore.pick_cardinal], [member Explore.locate]. Used by [code]AiDriver[/code] (carnivore + herbivore food search) and [code]CardinalAvoidance[/code] hints.
##
## Pattern: ordering N → NE → … → NW ([code]eight_way_directions.gd[/code]). Dwell **n** physics ticks per leg; after **eight** legs, **n ← 2n**.


const _EightWay := preload("res://creature/motor/eight_way_directions.gd")


class Explore:
  static func leg_count() -> int:
    return _EightWay.DIRECTIONS.size()


  ## Segment length for cycle [param cycle_index]: [code]base_ticks * 2^cycle_index[/code].
  static func segment_ticks_for_cycle(base_ticks: int, cycle_index: int) -> int:
    var b := maxi(1, base_ticks)
    return maxi(1, b << clampi(cycle_index, 0, 30))


  static func cycle_duration_ticks(base_ticks: int, cycle_index: int) -> int:
    return leg_count() * segment_ticks_for_cycle(base_ticks, cycle_index)


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


  static func pick_cardinal(base_ticks: int, effective_tick: int, phase_seed: int) -> Vector3:
    var loc: Dictionary = locate(base_ticks, effective_tick)
    var n_legs := leg_count()
    var ps := (phase_seed % n_legs + n_legs) % n_legs
    var slot := (int(loc["segment_index"]) + ps) % n_legs
    return _EightWay.DIRECTIONS[slot]
