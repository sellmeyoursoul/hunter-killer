extends RefCounted
class_name ChokePointTracker
## Turns a stream of per-sample width readings ([ChokePointProbe.measure_width]) into a *confirmed*
## choke point: the creature was bounded on both sides through a stretch, then left it having
## actually travelled through (not just poked in and backed out). One tracker per creature, fed at
## the stack's probe cadence. PHYSICS_SQUEEZE.md decision 19 — `confirmed` stores the real measured
## opening (the narrowest reading of the stretch), independent of the passer's own size.

const _Probe := preload("res://creature/motor/choke_point_probe.gd")

var _in_gap: bool = false
var _entry_pos: Vector3 = Vector3.ZERO
var _min_width: float = INF
var _min_pos: Vector3 = Vector3.ZERO
var _clear_samples: int = 0


func reset() -> void:
  _in_gap = false
  _entry_pos = Vector3.ZERO
  _min_width = INF
  _min_pos = Vector3.ZERO
  _clear_samples = 0


## Feeds one sample. Returns `{}` normally, or `{mouth, width}` on the sample that closes out a
## stretch the creature passed through. [param exit_samples] consecutive unbounded samples end a
## stretch (hysteresis against a single ray missing); [param min_travel] is how far the exit must be
## from the entry for it to count as a pass rather than a poke-and-retreat.
func update(
  space_state: PhysicsDirectSpaceState3D,
  pos: Vector3,
  heading: Vector3,
  max_half: float,
  min_travel: float,
  exit_samples: int,
  exclude_rids: Array = [],
) -> Dictionary:
  var m := _Probe.measure_width(space_state, pos, heading, max_half, exclude_rids)
  if bool(m.get("bounded", false)):
    _clear_samples = 0
    var w := float(m["width"])
    if not _in_gap:
      _in_gap = true
      _entry_pos = pos
      _min_width = w
      _min_pos = pos
    elif w < _min_width:
      _min_width = w
      _min_pos = pos
    return {}
  if not _in_gap:
    return {}
  _clear_samples += 1
  if _clear_samples < maxi(1, exit_samples):
    return {}
  var passed := _entry_pos.distance_to(pos) >= min_travel
  var result := {}
  if passed:
    result = {"mouth": _min_pos, "width": _min_width}
  reset()
  return result
