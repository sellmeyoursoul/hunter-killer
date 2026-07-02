extends RefCounted
class_name AwarenessZone
## Zone-of-awareness geometry — sphere ∪ forward cone + LoS ([CREATURE_MOVEMENT_V3.md §8.1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _LoS := preload("res://creature/motor/line_of_sight.gd")


## Horizontal gate distance from creature center to [param target_pos].
static func gate_dist(creature_pos: Vector3, target_pos: Vector3) -> float:
  var delta := Vector3(target_pos.x - creature_pos.x, 0.0, target_pos.z - creature_pos.z)
  return delta.length()


## Max awareness reach toward [param target_pos] along creature [param facing].
static func effective_reach_toward(
  creature_pos: Vector3,
  facing: Vector3,
  target_pos: Vector3,
  motor_v3: Dictionary,
  area_only: bool = false,
) -> float:
  var area_r := float(motor_v3.get("awareness_radius", 1500.0))
  if area_only:
    return area_r
  var cone_extra := float(motor_v3.get("awareness_cone_extra", 0.0))
  var half_angle := deg_to_rad(float(motor_v3.get("awareness_cone_half_angle_deg", 45.0)))
  var to_target := Vector3(target_pos.x - creature_pos.x, 0.0, target_pos.z - creature_pos.z)
  var dist := to_target.length()
  if dist < 1e-6:
    return area_r + cone_extra
  var dir := to_target / dist
  var face := _MotorPlane.read_dir(facing, _MotorPlane.HORIZONTAL_FORWARD)
  var angle := acos(clampf(face.dot(dir), -1.0, 1.0))
  var in_sphere := dist <= area_r
  var in_cone := angle <= half_angle and dist <= area_r + cone_extra
  if in_cone:
    return area_r + cone_extra
  if in_sphere:
    return area_r
  return 0.0


## True when [param target_pos] lies in the geometric zone (before LoS).
static func is_in_geometric_zone(
  creature_pos: Vector3,
  facing: Vector3,
  target_pos: Vector3,
  motor_v3: Dictionary,
  area_only: bool = false,
) -> bool:
  return effective_reach_toward(creature_pos, facing, target_pos, motor_v3, area_only) > 0.0


## LoS check using [code]creature_motor_v3.los_blocked_occlusion_fraction[/code] threshold.
static func line_of_sight_clear(
  space_state: PhysicsDirectSpaceState3D,
  creature_pos: Vector3,
  eye_height: float,
  target_pos: Vector3,
  motor_v3: Dictionary,
  exclude_rids: Array = [],
) -> Dictionary:
  if not bool(motor_v3.get("awareness_requires_los", true)):
    return {"line_of_sight_clear": true, "occluded": false, "occlusion_fraction": 0.0}
  if space_state == null:
    return {"line_of_sight_clear": true, "occluded": false, "occlusion_fraction": 0.0}
  var threshold := float(motor_v3.get("los_blocked_occlusion_fraction", 0.80))
  var eye := _LoS.eye_world_position(creature_pos, eye_height)
  var target := Vector3(target_pos.x, eye.y, target_pos.z)
  var frac := _LoS.occlusion_fraction(space_state, eye, target, exclude_rids)
  var blocked := frac > threshold
  return {
    "line_of_sight_clear": not blocked,
    "occluded": blocked,
    "occlusion_fraction": frac,
  }


## Geometric zone + optional LoS — returns [code]in_zone[/code] and LoS fields.
static func membership_with_los(
  space_state: PhysicsDirectSpaceState3D,
  creature_pos: Vector3,
  facing: Vector3,
  eye_height: float,
  target_pos: Vector3,
  motor_v3: Dictionary,
  area_only: bool = false,
  exclude_rids: Array = [],
) -> Dictionary:
  var in_geom := is_in_geometric_zone(creature_pos, facing, target_pos, motor_v3, area_only)
  if not in_geom:
    return {
      "in_zone": false,
      "in_awareness": false,
      "gate_dist": gate_dist(creature_pos, target_pos),
      "eff_reach": 0.0,
      "line_of_sight_clear": false,
      "occluded": true,
      "occlusion_fraction": 1.0,
    }
  var eff := effective_reach_toward(creature_pos, facing, target_pos, motor_v3, area_only)
  var los := line_of_sight_clear(
    space_state, creature_pos, eye_height, target_pos, motor_v3, exclude_rids,
  )
  var los_clear := bool(los.get("line_of_sight_clear", false))
  return {
    "in_zone": true,
    "in_awareness": los_clear,
    "gate_dist": gate_dist(creature_pos, target_pos),
    "eff_reach": eff,
    "line_of_sight_clear": los_clear,
    "occluded": bool(los.get("occluded", false)),
    "occlusion_fraction": float(los.get("occlusion_fraction", 0.0)),
  }
