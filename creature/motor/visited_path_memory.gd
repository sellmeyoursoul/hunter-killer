extends RefCounted
class_name VisitedPathMemory
## Spatial visitation history per creature — a physically-walked-through wedge should read as
## "explored" for [code]explore_w_unexp[/code] even when it holds zero known food beliefs, which
## is exactly the case the belief-density-only coverage in `MemoryAdapter.explore_bearing_coverage`
## couldn't distinguish from genuinely unvisited ground (live finding 2026-09-04: a fox bounced
## east-west into the same two walls because "checked, confirmed empty" and "never been near"
## scored identically as maximally unexplored). Mirrors `DeadEndMemory`'s
## stateless-static-helper-over-a-plain-Array shape — `MemoryAdapter` owns the array.

## TTL + cap eviction on [param marks].
static func maintain(marks: Array, now_ms: int, motor_v3: Dictionary) -> Array:
  var ttl_ms := int(float(motor_v3.get("visited_path_memory_ttl_sec", 90.0)) * 1000.0)
  var max_entries := maxi(1, int(motor_v3.get("visited_path_memory_max_entries", 64)))
  var kept: Array = []
  for row_v in marks:
    if typeof(row_v) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = row_v
    if now_ms - int(row.get("recorded_ms", 0)) <= ttl_ms:
      kept.append(row)
  kept.sort_custom(func(a, b): return int(a["recorded_ms"]) < int(b["recorded_ms"]))
  while kept.size() > max_entries:
    kept.pop_front()
  return kept


## Appends one sample, but only if far enough from the most recently recorded one — otherwise
## standing still (e.g. REST, EAT) or walking slowly would flood the history with near-duplicate
## points and starve out the cap (`visited_path_memory_max_entries`) with redundant coverage of the
## same small patch instead of a spread of the ground actually covered.
static func record_sample(
  marks: Array,
  world_pos: Vector3,
  now_ms: int,
  motor_v3: Dictionary,
) -> Array:
  var min_spacing := float(motor_v3.get("visited_path_memory_min_spacing", 40.0))
  if not marks.is_empty():
    var last: Dictionary = marks[marks.size() - 1]
    var last_pos: Vector3 = _read_pos(last.get("world_pos", Vector3.ZERO))
    if world_pos.distance_to(last_pos) < min_spacing:
      return marks
  marks.append({"world_pos": world_pos, "recorded_ms": now_ms})
  return marks


static func _read_pos(v: Variant) -> Vector3:
  if typeof(v) == TYPE_VECTOR3:
    return v
  return Vector3.ZERO
