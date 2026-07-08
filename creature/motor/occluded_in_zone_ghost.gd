extends RefCounted
class_name OccludedInZoneGhost
## Read-time occluded-in-zone ghost projection ([CREATURE_MOVEMENT_V3.md §8.1 / §8.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _AwarenessZone := preload("res://creature/motor/awareness_zone.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _GoalBelief := preload("res://creature/motor/goal_belief_memory.gd")

const SOURCE_GHOST := &"ghost"


## True when sample counts as nearby threat for Safety / Flight / REST interrupt (§8.4).
static func danger_filter(sample: Dictionary) -> bool:
  if sample.is_empty():
    return false
  if sample.get("source", &"") == SOURCE_GHOST:
    return sample.get("goal_kind", &"") == _GkReg.GK_AVOID_HOSTILES
  return bool(sample.get("hostile", true)) and bool(sample.get("in_awareness", false))


## Projects occluded-in-zone ghost samples from [param beliefs] not deduped by [param live_instance_ids].
static func project_ghosts(
  zone_ctx: Dictionary,
  beliefs: Dictionary,
  live_instance_ids: Dictionary,
) -> Array:
  var out: Array = []
  if beliefs.is_empty():
    return out
  var creature_pos: Vector3 = zone_ctx.get("creature_pos", Vector3.ZERO)
  var facing: Vector3 = zone_ctx.get("facing", Vector3.FORWARD)
  var eye_h := float(zone_ctx.get("eye_height", 1.0))
  var motor_v3: Dictionary = zone_ctx.get("motor_v3", {})
  var area_only := bool(zone_ctx.get("area_only", false))
  var space: PhysicsDirectSpaceState3D = zone_ctx.get("space_state")
  var area_r := float(motor_v3.get("awareness_radius", 1500.0))
  var cone_extra := float(motor_v3.get("awareness_cone_extra", 0.0))
  var max_reach := area_r + cone_extra
  var horizon := float(motor_v3.get("goal_memory_ghost_horizon_sec", 0.4))

  for iid_v in beliefs.keys():
    var iid := int(iid_v)
    if iid == 0 or live_instance_ids.has(iid):
      continue
    var row: Dictionary = beliefs[iid]
    if not _row_eligible_for_projection(row):
      continue
    var last_pos := _read_pos(row.get("last_world_pos", Vector3.ZERO))
    if last_pos.length_squared() < 1e-8:
      continue
    if not _AwarenessZone.is_in_geometric_zone(
      creature_pos, facing, last_pos, motor_v3, area_only,
    ):
      continue
    var los := _AwarenessZone.line_of_sight_clear(
      space, creature_pos, eye_h, last_pos, motor_v3,
    )
    if bool(los.get("line_of_sight_clear", false)):
      continue
    var believed_pos := last_pos
    if bool(row.get("is_moving", false)):
      var vel := _read_vel(row.get("last_velocity", Vector3.ZERO))
      if vel.length_squared() > 1e-8:
        believed_pos = last_pos + vel * horizon
      if _AwarenessZone.gate_dist(creature_pos, believed_pos) > max_reach:
        continue
    var mem := _AwarenessZone.membership_with_los(
      space, creature_pos, facing, eye_h, last_pos, motor_v3, area_only,
    )
    var ghost := {
      "world_pos": _MotorPlane.from_vec3(last_pos),
      "world_pos_3d": last_pos,
      "gate_dist": float(mem.get("gate_dist", _AwarenessZone.gate_dist(creature_pos, last_pos))),
      "eff_reach": float(mem.get("eff_reach", 0.0)),
      "in_awareness": true,
      "hostile": true,
      "acute": true,
      "source": SOURCE_GHOST,
      "line_of_sight_clear": false,
      "occluded": true,
      "occlusion_fraction": float(los.get("occlusion_fraction", 1.0)),
      "instance_id": iid,
      "goal_kind": row.get("goal_kind", &""),
      "stimulus_kind_id": row.get("stimulus_kind_id", &""),
      "velocity": _MotorPlane.from_vec3(_read_vel(row.get("last_velocity", Vector3.ZERO))),
      "ghost_strength": float(row.get("ghost_strength", 1.0)),
    }
    out.append(ghost)
  return out


static func _row_eligible_for_projection(row: Dictionary) -> bool:
  var goal_kind: StringName = row.get("goal_kind", &"")
  if goal_kind == _GkReg.GK_AVOID_HOSTILES:
    return true
  if goal_kind == _GkReg.GK_FIND_FOOD:
    return row.get("tier", &"") == _GoalBelief.TIER_PRECISE
  if goal_kind == _GkReg.GK_SHELTER:
    return true
  return false


static func _read_pos(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


static func _read_vel(v: Variant) -> Vector3:
  var vel: Variant = Callable(_MotorPlane, &"read_velocity").call(v)
  if typeof(vel) == TYPE_VECTOR3:
    return vel as Vector3
  if typeof(vel) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(vel as Vector2)
  return Vector3.ZERO
