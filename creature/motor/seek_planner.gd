## POST_LOS seek-cycle planner (Phase 4.5a) — step goal when direct path to ultimate goal is blocked.
## Design: [POST_LOS_MOVEMENT.md](../../Project_Docs/Draft_Features/POST_LOS_MOVEMENT.md)
class_name SeekPlanner
extends RefCounted

const _Los := preload("res://creature/motor/line_of_sight.gd")
const _NavHint := preload("res://environment/nav_path_hint.gd")

const STEP_MODE_DIRECT := &"direct"
const STEP_MODE_NAVMESH := &"navmesh"
const STEP_MODE_NONE := &"none"


## Physics ticks between goal-table / path replans from Observation (higher stat => smaller n).
static func observation_replan_interval_ticks(
  observation_stat: float,
  motor_p: Dictionary,
) -> int:
  var base_n := maxi(1, int(motor_p.get("post_los_replan_base_ticks", 8)))
  var stat_clamped := clampf(observation_stat, 0.0, 100.0)
  var scale := lerpf(2.0, 0.5, stat_clamped / 100.0)
  return maxi(1, int(round(float(base_n) * scale)))


## True when LoS from creature eye to goal is not blocked (>60% occluded threshold).
static func direct_path_clear(
  creature_pos: Vector3,
  goal_pos: Vector3,
  los_ctx: Dictionary,
) -> bool:
  if goal_pos == Vector3.ZERO:
    return true
  if not bool(los_ctx.get("enabled", false)):
    return true
  var space_v: Variant = los_ctx.get("space_state", null)
  if space_v == null:
    return true
  var space := space_v as PhysicsDirectSpaceState3D
  if space == null:
    return true
  var eye_h := float(los_ctx.get("eye_height", 0.9))
  var exclude: Array = los_ctx.get("exclude_rids", []) as Array
  var result: Dictionary = _Los.line_of_sight_clear(
    space,
    creature_pos,
    eye_h,
    goal_pos,
    exclude,
  )
  return bool(result.get("line_of_sight_clear", true))


## Resolves step goal for cardinal motor: direct ultimate, first nav waypoint, or unchanged fallback.
static func resolve_step_goal(
  creature_pos: Vector3,
  ultimate_goal: Vector3,
  los_ctx: Dictionary,
  nav_map_rid: RID,
  agent_radius: float,
  planner_enabled: bool,
) -> Dictionary:
  var out := {
    "ultimate_goal": ultimate_goal,
    "step_goal": ultimate_goal,
    "step_mode": STEP_MODE_DIRECT,
    "path_valid": true,
  }
  if not planner_enabled or ultimate_goal == Vector3.ZERO:
    return out
  if direct_path_clear(creature_pos, ultimate_goal, los_ctx):
    return out
  out["path_valid"] = false
  if not nav_map_rid.is_valid():
    out["step_mode"] = STEP_MODE_NONE
    return out
  var wp := _NavHint.first_waypoint_world(
    nav_map_rid,
    creature_pos,
    ultimate_goal,
    agent_radius,
  )
  if wp == Vector3.ZERO:
    out["step_mode"] = STEP_MODE_NONE
    return out
  out["step_goal"] = wp
  out["step_mode"] = STEP_MODE_NAVMESH
  out["path_valid"] = true
  return out
