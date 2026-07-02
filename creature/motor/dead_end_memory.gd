extends RefCounted
class_name DeadEndMemory
## Geographic cul-de-sac marks per creature ([CREATURE_MEMORY.md §5.6](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


## TTL + cap eviction on [param marks].
static func maintain(marks: Array, now_ms: int, motor_v3: Dictionary) -> Array:
  var ttl_ms := int(float(motor_v3.get("dead_end_memory_ttl_sec", 15.0)) * 1000.0)
  var max_entries := maxi(1, int(motor_v3.get("dead_end_memory_max_entries", 12)))
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


## Appends one dead-end mark row.
static func record_mark(
  marks: Array,
  world_pos: Vector3,
  approach_heading: Vector3,
  goal_kind: StringName,
  instance_id: int,
  now_ms: int,
) -> Array:
  var heading := approach_heading
  heading.y = 0.0
  if heading.length_squared() < 1e-8:
    return marks
  marks.append({
    "world_pos": world_pos,
    "approach_heading": heading.normalized(),
    "goal_kind": goal_kind,
    "instance_id": instance_id,
    "recorded_ms": now_ms,
  })
  return marks


## True when waypoint [param waypoint] should be filtered for [param goal_kind].
static func is_waypoint_blocked(
  marks: Array,
  creature_pos: Vector3,
  waypoint: Vector3,
  goal_kind: StringName,
  motor_v3: Dictionary,
) -> bool:
  var match_r := float(motor_v3.get("dead_end_match_radius", 52.0))
  var heading_dot := float(motor_v3.get("dead_end_heading_dot", 0.55))
  var to_wp := waypoint - creature_pos
  to_wp.y = 0.0
  if to_wp.length_squared() < 1e-8:
    return false
  var approach := to_wp.normalized()
  for row_v in marks:
    if typeof(row_v) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = row_v
    if row.get("goal_kind", &"") != goal_kind:
      continue
    var mark_pos: Vector3 = _read_pos(row.get("world_pos", Vector3.ZERO))
    if mark_pos.distance_to(waypoint) > match_r:
      continue
    var mark_heading: Vector3 = _read_dir(row.get("approach_heading", Vector3.ZERO))
    if mark_heading.length_squared() < 1e-8:
      continue
    if approach.dot(mark_heading.normalized()) >= heading_dot:
      return true
  return false


## Removes marks near [param world_pos] after successful traverse.
static func clear_near_success(marks: Array, world_pos: Vector3, motor_v3: Dictionary) -> Array:
  var match_r := float(motor_v3.get("dead_end_match_radius", 52.0))
  var kept: Array = []
  for row_v in marks:
    if typeof(row_v) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = row_v
    var mark_pos: Vector3 = _read_pos(row.get("world_pos", Vector3.ZERO))
    if mark_pos.distance_to(world_pos) > match_r:
      kept.append(row)
  return kept


static func _read_pos(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


static func _read_dir(v: Variant) -> Vector3:
  var d: Variant = Callable(_MotorPlane, &"read_dir").call(v, Vector3.ZERO)
  if typeof(d) == TYPE_VECTOR3:
    return d as Vector3
  return Vector3.ZERO
