## Short-lived memory of the heading used to enter a pinch so motor can avoid 180° backtrack ([CREATURE_MEMORY.md §2](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md) trail + locale sector).
extends Object
class_name BlockedApproachMemory

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


## Unit step direction [param d] → sector index 0..7 (N, NE, E, SE, S, SW, W, NW; **−Z = N**).
static func sector_index_for_step(d: Vector3) -> int:
  if d.length_squared() < 1e-8:
    return 0
  var u := d.normalized()
  var angle := atan2(u.x, -u.z)
  if angle < 0.0:
    angle += TAU
  return int(floor((angle + PI / 8.0) / (PI / 4.0))) % 8


## Phase-1 align: **1.0** if [param d] falls in [param sector_s]'s 45° arc, else **0.0**.
static func align_step_with_sector(d: Vector3, sector_s: int) -> float:
  if sector_s < 0 or sector_s > 7:
    return 0.0
  return 1.0 if sector_index_for_step(d) == sector_s else 0.0


## True when [param step_dir] continues along [param approach_dir] (re-entering the blocked corridor).
static func is_backtrack_step(step_dir: Vector3, approach_dir: Vector3, min_dot: float) -> bool:
  if step_dir.length_squared() < 1e-12 or approach_dir.length_squared() < 1e-12:
    return false
  return step_dir.normalized().dot(approach_dir.normalized()) >= min_dot


## Infers the heading the creature used to reach its current cell (trail > displacement > last move > intent).
static func infer_approach_dir(
  creature_pos: Vector3,
  last_stuck_sample_pos: Vector3,
  last_move: Vector3,
  trail_centers: Array,
  incumbent_intent: Vector3,
) -> Vector3:
  if creature_pos.distance_squared_to(last_stuck_sample_pos) > 0.25:
    return (creature_pos - last_stuck_sample_pos).normalized()
  if last_move.length_squared() > 1e-12:
    return last_move.normalized()
  if not trail_centers.is_empty():
    var anchor: Variant = trail_centers[trail_centers.size() - 1]
    if typeof(anchor) == TYPE_VECTOR3:
      var delta := creature_pos - (anchor as Vector3)
      if delta.length_squared() > 64.0:
        return delta.normalized()
  if incumbent_intent.length_squared() > 1e-12:
    return incumbent_intent.normalized()
  return Vector3.ZERO


## Records [param approach_dir] until [param physics_tick] reaches [code]until_tick[/code].
static func record(io_state: Dictionary, approach_dir: Vector3, physics_tick: int, ttl_ticks: int) -> void:
  if approach_dir.length_squared() < 1e-12:
    return
  var u := approach_dir.normalized()
  io_state["dir"] = u
  io_state["sector"] = sector_index_for_step(u)
  io_state["until_tick"] = physics_tick + maxi(1, ttl_ticks)


## Active unit approach direction, or zero when expired / unset.
static func active_dir(io_state: Dictionary, physics_tick: int) -> Vector3:
  if io_state.is_empty():
    return Vector3.ZERO
  if physics_tick >= int(io_state.get("until_tick", 0)):
    return Vector3.ZERO
  var d: Variant = io_state.get("dir", null)
  if typeof(d) == TYPE_VECTOR3 and (d as Vector3).length_squared() > 1e-12:
    return d as Vector3
  return Vector3.ZERO


## Sector index 0..7 for the recorded approach, or -1 when inactive.
static func active_sector(io_state: Dictionary, physics_tick: int) -> int:
  if active_dir(io_state, physics_tick).length_squared() < 1e-12:
    return -1
  return int(io_state.get("sector", -1))
