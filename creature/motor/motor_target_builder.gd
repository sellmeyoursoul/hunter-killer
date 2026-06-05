## Unified [code]SeekCandidate[][/code] + [code]ThreatSample[][/code] builder ([CREATURE_MOVEMENT_V2.md §A.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
extends Object

const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")
const _SeekCand := preload("res://creature/motor/seek_candidate.gd")
const _Threat := preload("res://creature/motor/threat_sample.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")


const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


static func _as_grid(v: Vector3) -> Vector2:
  return Vector2(v.x, v.z)


static func _read_dir_v3(v: Variant, fallback: Vector3 = Vector3(1.0, 0.0, 0.0)) -> Vector3:
  var d: Variant = Callable(_MotorPlane, &"read_dir").call(v, fallback)
  if typeof(d) == TYPE_VECTOR3:
    return d as Vector3
  if typeof(d) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(d as Vector2)
  return fallback


static func _spatial_motor_position(n: Node) -> Vector3:
  if n is Node:
    var p: Variant = _MotorPlane.body_motor_position(n)
    if typeof(p) == TYPE_VECTOR3:
      return p as Vector3
    if typeof(p) == TYPE_VECTOR2:
      return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


static func _spatial_motor_velocity(n: Node) -> Vector3:
  if _MotorPlane.is_motor_physics_body(n):
    var v: Variant = _MotorPlane.body_motor_velocity(n as Node)
    if typeof(v) == TYPE_VECTOR3:
      return v as Vector3
    if typeof(v) == TYPE_VECTOR2:
      return _MotorPlane.to_horizontal_vec3(v as Vector2)
  return Vector3.ZERO


static func feeding_mode_for_body(body: Node) -> int:
  if body != null and body.has_method(&"get_feeding_mode"):
    return int(body.call(&"get_feeding_mode"))
  if body != null and body.is_in_group(&"mobs") and not body.is_in_group(&"prey"):
    return _CreatureDefinition.FeedingMode.CARNIVORE
  return _CreatureDefinition.FeedingMode.HERBIVORE


static func food_intake_policy_for_body(body: Node) -> Resource:
  if body != null and body.has_method(&"get_food_intake_policy"):
    var pol: Variant = body.call(&"get_food_intake_policy")
    if pol is Resource:
      return pol as Resource
  return _DietRegistry.default_food_intake_policy(feeding_mode_for_body(body))


static func _policy_groups(policy: Resource, key: String) -> Array:
  if policy == null:
    return []
  var raw: Variant = policy.get(key)
  if typeof(raw) != TYPE_ARRAY:
    return []
  return raw as Array


static func _in_awareness_zone(
  creature_pos: Vector3,
  he_xy: Vector2,
  target_pos: Vector3,
  motor_p: Dictionary,
  facing: Vector3,
  use_prey_cone: bool,
) -> bool:
  var awareness_r := float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return false
  var cone_extra := float(motor_p.get("awareness_cone_extra", 0.0))
  if use_prey_cone:
    cone_extra = _predator_prey_cone_extra(motor_p)
  var half_deg := float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos := cos(deg_to_rad(half_deg))
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  var omni := false
  if use_prey_cone:
    omni = bool(motor_p.get("predator_prey_awareness_omni", false))
  elif bool(motor_p.get("herbivore_threat_awareness_omni", false)):
    omni = true
  var facing_v3 := _read_dir_v3(facing)
  var gd := _Motor.awareness_gate_distance(creature_pos, he_xy, target_pos)
  if omni:
    return gd <= awareness_r
  var eff := _Motor.effective_awareness_reach(
    creature_pos,
    target_pos,
    awareness_r,
    cone_extra,
    cone_cos,
    facing_v3,
    forward_cone_only,
  )
  return gd <= eff


static func _predator_prey_cone_extra(motor_p: Dictionary) -> float:
  var v := float(motor_p.get("predator_prey_awareness_cone_extra", 0.0))
  if v > 0.0:
    return v
  return float(motor_p.get("awareness_cone_extra", 0.0))


## Live [code]food_plants[/code] split by readiness ([CREATURE_MOVEMENT_V2.md §E.1](CREATURE_MOVEMENT_V2.md)).
static func scan_food_plants_in_awareness(
  tree: SceneTree,
  policy: Resource,
  motor_p: Dictionary,
  creature_pos: Vector3,
  he_xy: Vector2,
  facing: Vector3,
) -> Dictionary:
  var ready_positions: Array = []
  var unready_positions: Array = []
  if tree == null:
    return {"ready": ready_positions, "unready": unready_positions}
  var plant_groups := _policy_groups(policy, "plant_groups")
  if plant_groups.is_empty():
    return {"ready": ready_positions, "unready": unready_positions}
  for group_name in plant_groups:
    var g := StringName(str(group_name))
    for n in tree.get_nodes_in_group(g):
      if not n.has_method(&"is_pickup_ready_for_motor"):
        continue
      var fp: Vector3 = _spatial_motor_position(n)
      if not _in_awareness_zone(creature_pos, he_xy, fp, motor_p, facing, false):
        continue
      var ready_v: Variant = n.call(&"is_pickup_ready_for_motor")
      var entry := {"pos": fp, "instance_id": n.get_instance_id()}
      var cal_v: Variant = n.get("current_calories")
      if typeof(cal_v) == TYPE_FLOAT or typeof(cal_v) == TYPE_INT:
        entry["anticipated_calories"] = float(cal_v)
      if typeof(ready_v) == TYPE_BOOL and bool(ready_v):
        ready_positions.append(entry)
      else:
        unready_positions.append(entry)
  return {"ready": ready_positions, "unready": unready_positions}


## Prey entries under awareness ([code]{instance_id, pos, velocity}[/code]).
static func collect_prey_entries(
  tree: SceneTree,
  body: Node,
  policy: Resource,
  motor_p: Dictionary,
  creature_pos: Vector3,
  he_xy: Vector2,
  facing: Vector3,
) -> Array:
  var out: Array = []
  if tree == null or body == null:
    return out
  var prey_groups := _policy_groups(policy, "prey_groups")
  if prey_groups.is_empty():
    return out
  var seen: Dictionary = {}
  for group_name in prey_groups:
    var g := StringName(str(group_name))
    for n in tree.get_nodes_in_group(g):
      if not (n is Node2D or n is Node3D):
        continue
      if (n as Node) == body:
        continue
      var nid := n.get_instance_id()
      if seen.has(nid):
        continue
      seen[nid] = true
      var prey_pos := _spatial_motor_position(n)
      if not _in_awareness_zone(creature_pos, he_xy, prey_pos, motor_p, facing, true):
        continue
      var vel := _spatial_motor_velocity(n)
      out.append({"instance_id": nid, "pos": prey_pos, "velocity": vel})
  return out


## Prey [code]Vector3[/code] positions under awareness (policy [code]prey_groups[/code]).
static func collect_prey_positions(
  tree: SceneTree,
  body: Node,
  policy: Resource,
  motor_p: Dictionary,
  creature_pos: Vector3,
  he_xy: Vector2,
  facing: Vector3,
) -> Array:
  var out: Array = []
  for e in collect_prey_entries(tree, body, policy, motor_p, creature_pos, he_xy, facing):
    if typeof(e) != TYPE_DICTIONARY:
      continue
    var p: Variant = (e as Dictionary).get("pos", null)
    if typeof(p) == TYPE_VECTOR3:
      out.append(p as Vector3)
  return out


## Pursuit dicts for carnivore/omnivore hunt ([code]position[/code], [code]velocity[/code], [code]cost_scale[/code]).
static func collect_pursuit_targets(
  tree: SceneTree,
  body: Node,
  policy: Resource,
  motor_p: Dictionary,
  creature_pos: Vector3,
  he_xy: Vector2,
  facing: Vector3,
) -> Array:
  var arr: Array = []
  if tree == null or body == null:
    return arr
  var prey_groups := _policy_groups(policy, "prey_groups")
  if prey_groups.is_empty():
    return arr
  var seen: Dictionary = {}
  for group_name in prey_groups:
    var g := StringName(str(group_name))
    for n in tree.get_nodes_in_group(g):
      if not (n is Node2D or n is Node3D):
        continue
      if (n as Node) == body:
        continue
      var nid := n.get_instance_id()
      if seen.has(nid):
        continue
      seen[nid] = true
      var prey_pos := _spatial_motor_position(n)
      if not _in_awareness_zone(creature_pos, he_xy, prey_pos, motor_p, facing, true):
        continue
      var vel := _spatial_motor_velocity(n)
      arr.append({"position": prey_pos, "velocity": vel, "cost_scale": 1.0})
  return arr


## Hostile mob threats for **Avoid hostiles** (herbivore / omnivore posture).
static func collect_hostile_threat_samples(
  tree: SceneTree,
  body: Node,
  motor_p: Dictionary,
  creature_pos: Vector3,
  he_xy: Vector2,
  facing: Vector3,
) -> Array:
  var out: Array = []
  if tree == null or body == null:
    return out
  var awareness_r := float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return out
  for n in tree.get_nodes_in_group(&"mobs"):
    if not _MotorPlane.is_motor_physics_body(n):
      continue
    var rb := n as Node
    if rb == body:
      continue
    var mp := _spatial_motor_position(rb)
    if not _in_awareness_zone(creature_pos, he_xy, mp, motor_p, facing, false):
      continue
    var gd := _Motor.awareness_gate_distance(creature_pos, he_xy, mp)
    var vel := _spatial_motor_velocity(rb)
    out.append(
      Callable(_Threat, &"make").call(
        mp, gd, true, vel, rb.get_instance_id(), true, true, _Threat.SOURCE_LIVE_MOB
      )
    )
  return out


static func nearest_hostile_threat_sample(threat_samples: Array) -> Dictionary:
  var best: Dictionary = _Threat.inactive()
  var best_dist := INF
  for s in threat_samples:
    if typeof(s) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = s as Dictionary
    if not bool(row.get("in_awareness", false)):
      continue
    var d := float(row.get("gate_dist", INF))
    if d < best_dist:
      best_dist = d
      best = row
  return best


## Single builder entry — [code]feeding_mode[/code] + [FoodIntakePolicy] drive membership.
static func build_motor_target_lists(
  tree: SceneTree,
  body: Node,
  motor_p: Dictionary,
  creature_pos: Vector3,
  he_xy: Vector2,
  facing: Vector3,
) -> Dictionary:
  var policy := food_intake_policy_for_body(body)
  var feeding_mode := feeding_mode_for_body(body)
  var plant_groups := _policy_groups(policy, "plant_groups")
  var prey_groups := _policy_groups(policy, "prey_groups")
  var supports_plant_belief := not plant_groups.is_empty()
  var supports_prey_hunt := not prey_groups.is_empty()
  var food_split := scan_food_plants_in_awareness(
    tree, policy, motor_p, creature_pos, he_xy, facing
  )
  var prey_entries: Array = []
  var prey_positions: Array = []
  var pursuit_targets: Array = []
  if supports_prey_hunt:
    prey_entries = collect_prey_entries(
      tree, body, policy, motor_p, creature_pos, he_xy, facing
    )
    prey_positions = collect_prey_positions(
      tree, body, policy, motor_p, creature_pos, he_xy, facing
    )
    pursuit_targets = collect_pursuit_targets(
      tree, body, policy, motor_p, creature_pos, he_xy, facing
    )
  var threat_samples: Array = collect_hostile_threat_samples(
    tree, body, motor_p, creature_pos, he_xy, facing
  )
  var seek_candidates: Array = _SeekCand.build_from_food_split(food_split)
  for e in prey_entries:
    if typeof(e) != TYPE_DICTIONARY:
      continue
    var ent: Dictionary = e as Dictionary
    var pp: Variant = ent.get("pos", null)
    if typeof(pp) != TYPE_VECTOR3:
      continue
    seek_candidates.append(
      Callable(_SeekCand, &"make").call(
        pp as Vector3,
        _GkReg.GK_FIND_FOOD,
        true,
        true,
        int(ent.get("instance_id", 0)),
        _SeekCand.SOURCE_LIVE_PREY,
      )
    )
  var primary_threat := nearest_hostile_threat_sample(threat_samples)
  return {
    "feeding_mode": feeding_mode,
    "food_intake_policy": policy,
    "food_split": food_split,
    "seek_candidates": seek_candidates,
    "threat_samples": threat_samples,
    "primary_hostile_threat": _Threat.to_legacy_herbivore_dict(primary_threat),
    "prey_entries": prey_entries,
    "prey_positions": prey_positions,
    "pursuit_targets": pursuit_targets,
    "supports_plant_belief": supports_plant_belief,
    "supports_prey_hunt": supports_prey_hunt,
  }
