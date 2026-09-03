extends RefCounted
class_name AwarenessZoneScan
## Live food + threat scene scan for V3 planner ([CREATURE_MOVEMENT_V3.md §6.2 / §8.1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _AwarenessZone := preload("res://creature/motor/awareness_zone.gd")
const _ThreatSample := preload("res://creature/motor/threat_sample.gd")
const _NEUTRAL_KIND_YIELD := 0.5


## Scans the scene tree for live food and hostile threats visible to [param body].
## [param threat_los_cache] is the caller-owned per-creature awareness-hysteresis cache (see
## [method AwarenessZone.latch_awareness_verdict]) — pass the same [Dictionary] instance across
## ticks (e.g. planner [code]state["threat_los_hysteresis"][/code]) so threat in/out-of-awareness
## flips debounce across calls; omit (default empty, discarded) to scan without hysteresis.
static func scan_live(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  tree: SceneTree,
  area_only: bool = false,
  threat_los_cache: Dictionary = {},
) -> Dictionary:
  var out := {
    "food_split": {"ready": [], "unready": []},
    "threat_samples": [],
    "food_map_confidence": 0.0,
  }
  if body == null or tree == null:
    return out
  var creature_pos := body.global_position
  var facing: Vector3 = body.get("last_move_direction")
  var eye_h := _eye_height(body, motor_v3)
  var space := body.get_world_3d().direct_space_state if body.is_inside_tree() else null
  var subject_hostile := bool(body.get("is_hostile"))

  var policy: Resource = DietRegistry.food_intake_policy_for_body(body)
  _scan_food_plants(body, creature_pos, facing, eye_h, space, motor_v3, tree, area_only, policy, out)
  _scan_prey_food(body, creature_pos, facing, eye_h, space, motor_v3, tree, area_only, policy, out)
  _scan_hostile_threats(
    body, creature_pos, facing, eye_h, space, motor_v3, tree, area_only, subject_hostile, policy, out,
    threat_los_cache,
  )
  ## [code]food_map_confidence[/code] is owned by stack [code]inventory_ratio[/code] consult (§1) — not live-scan split.
  return out


static func _eye_height(body: CharacterBody3D, motor_v3: Dictionary) -> float:
  if motor_v3.has("los_eye_height"):
    return float(motor_v3.get("los_eye_height"))
  if body.has_method(&"get_los_eye_height"):
    return float(body.call(&"get_los_eye_height"))
  return 1.0


static func _scan_food_plants(
  _body: CharacterBody3D,
  creature_pos: Vector3,
  facing: Vector3,
  eye_h: float,
  space: PhysicsDirectSpaceState3D,
  motor_v3: Dictionary,
  tree: SceneTree,
  area_only: bool,
  policy: Resource,
  out: Dictionary,
) -> void:
  var ready: Array = out["food_split"]["ready"]
  var unready: Array = out["food_split"]["unready"]
  var plant_groups: Array = DietRegistry.policy_groups(policy, "plant_groups")
  if plant_groups.is_empty():
    return
  var seen: Dictionary = {}
  for group_name in plant_groups:
    var group := StringName(str(group_name))
    for node in tree.get_nodes_in_group(group):
      if not (node is Node3D):
        continue
      var plant := node as Node3D
      var pid := plant.get_instance_id()
      if seen.has(pid):
        continue
      seen[pid] = true
      var plant_pos := plant.global_position
      var mem := _AwarenessZone.membership_with_los(
        space, creature_pos, facing, eye_h, plant_pos, motor_v3, area_only,
      )
      if not bool(mem.get("in_awareness", false)):
        continue
      var kind_id := _stimulus_kind_for_plant(plant)
      if kind_id == &"":
        continue
      var consumable := true
      if plant.has_method(&"is_pickup_ready_for_motor"):
        consumable = bool(plant.call(&"is_pickup_ready_for_motor"))
      var entry := {
        "pos": plant_pos,
        "instance_id": plant.get_instance_id(),
        "stimulus_kind_id": kind_id,
        "consumable_now": consumable,
        "line_of_sight_clear": true,
        "occluded": false,
        "occlusion_fraction": float(mem.get("occlusion_fraction", 0.0)),
        "gate_dist": float(mem.get("gate_dist", 0.0)),
        "kind_yield": _NEUTRAL_KIND_YIELD,
        "source": &"live",
      }
      if consumable:
        ready.append(entry)
      else:
        unready.append(entry)
  out["food_split"]["ready"] = ready
  out["food_split"]["unready"] = unready


static func _scan_prey_food(
  body: CharacterBody3D,
  creature_pos: Vector3,
  facing: Vector3,
  eye_h: float,
  space: PhysicsDirectSpaceState3D,
  motor_v3: Dictionary,
  tree: SceneTree,
  area_only: bool,
  policy: Resource,
  out: Dictionary,
) -> void:
  var prey_groups: Array = DietRegistry.policy_groups(policy, "prey_groups")
  if prey_groups.is_empty():
    return
  var ready: Array = out["food_split"]["ready"]
  var seen: Dictionary = {}
  for group_name in prey_groups:
    var group := StringName(str(group_name))
    for node in tree.get_nodes_in_group(group):
      if node == body or not (node is Node3D):
        continue
      var prey := node as Node3D
      var pid := prey.get_instance_id()
      if seen.has(pid):
        continue
      seen[pid] = true
      var prey_pos := prey.global_position
      var mem := _AwarenessZone.membership_with_los(
        space, creature_pos, facing, eye_h, prey_pos, motor_v3, area_only,
      )
      if not bool(mem.get("in_awareness", false)):
        continue
      var vel := Vector3.ZERO
      if prey is CharacterBody3D:
        vel = _MotorPlane.body_motor_velocity(prey as CharacterBody3D)
      var kind_id := &""
      if prey is CharacterBody3D:
        kind_id = _stimulus_kind_for_creature(prey as CharacterBody3D)
      ready.append({
        "pos": prey_pos,
        "instance_id": pid,
        "stimulus_kind_id": kind_id,
        "consumable_now": true,
        "line_of_sight_clear": true,
        "occluded": false,
        "occlusion_fraction": float(mem.get("occlusion_fraction", 0.0)),
        "gate_dist": float(mem.get("gate_dist", 0.0)),
        "kind_yield": _NEUTRAL_KIND_YIELD,
        "source": &"live",
        "is_moving": true,
        "velocity": vel,
      })
  out["food_split"]["ready"] = ready


static func _stimulus_kind_for_plant(plant: Node) -> StringName:
  var kind_v: Variant = plant.get("stimulus_kind_id")
  if typeof(kind_v) == TYPE_STRING_NAME and not StringName(kind_v).is_empty():
    return kind_v as StringName
  if typeof(kind_v) == TYPE_STRING and not str(kind_v).strip_edges().is_empty():
    return StringName(str(kind_v).strip_edges())
  return &""


static func _stimulus_kind_for_creature(body: CharacterBody3D) -> StringName:
  var def_v: Variant = body.get("definition")
  if def_v is Resource:
    var species_v: Variant = (def_v as Resource).get("species_id")
    if typeof(species_v) == TYPE_STRING_NAME and not StringName(species_v).is_empty():
      return species_v as StringName
    if typeof(species_v) == TYPE_STRING and not str(species_v).strip_edges().is_empty():
      return StringName(str(species_v).strip_edges())
  return &""


static func _scan_hostile_threats(
  body: CharacterBody3D,
  creature_pos: Vector3,
  facing: Vector3,
  eye_h: float,
  space: PhysicsDirectSpaceState3D,
  motor_v3: Dictionary,
  tree: SceneTree,
  area_only: bool,
  subject_hostile: bool,
  policy: Resource,
  out: Dictionary,
  threat_los_cache: Dictionary,
) -> void:
  var samples: Array = []
  var groups: Array[StringName] = [&"mobs", &"creatures"]
  var seen: Dictionary = {}
  var hysteresis_ticks := int(motor_v3.get("threat_awareness_hysteresis_ticks", 3))
  for group_name in groups:
    for node in tree.get_nodes_in_group(group_name):
      if node == body or not (node is CharacterBody3D):
        continue
      var other := node as CharacterBody3D
      var oid := other.get_instance_id()
      if seen.has(oid):
        continue
      seen[oid] = true
      if not _is_threat_to_subject(other, subject_hostile, body, policy):
        continue
      var other_pos := other.global_position
      var mem := _AwarenessZone.membership_with_los(
        space, creature_pos, facing, eye_h, other_pos, motor_v3, area_only,
      )
      var raw_aware := bool(mem.get("in_awareness", false))
      var aware := _AwarenessZone.latch_awareness_verdict(
        threat_los_cache, oid, raw_aware, hysteresis_ticks,
      )
      if not aware:
        continue
      var wp := _MotorPlane.from_vec3(other_pos)
      samples.append(
        _ThreatSample.make(
          wp,
          float(mem.get("gate_dist", INF)),
          true,
          _MotorPlane.from_vec3(_MotorPlane.body_motor_velocity(other)),
          oid,
          true,
          true,
          _ThreatSample.SOURCE_LIVE_MOB,
          true,
          false,
          float(mem.get("occlusion_fraction", 0.0)),
          _stimulus_kind_for_creature(other),
        )
      )
      var last := samples[samples.size() - 1] as Dictionary
      last["eff_reach"] = float(mem.get("eff_reach", 0.0))
      last["world_pos_3d"] = other_pos
  out["threat_samples"] = samples
  ## Drop hysteresis-cache entries for ids not seen this scan (despawned/left-group nodes) so the
  ## cache doesn't grow unbounded over a session — `seen` covers every candidate node examined this
  ## tick, not just confirmed threats, so a node that's still present but no longer a threat keeps
  ## its (inert, unconsulted) entry rather than being pruned and re-latched from a cold start.
  for cached_id in threat_los_cache.keys():
    if not seen.has(cached_id):
      threat_los_cache.erase(cached_id)


static func _is_threat_to_subject(
  other: CharacterBody3D,
  subject_hostile: bool,
  _subject: CharacterBody3D,
  policy: Resource,
) -> bool:
  if policy != null and DietRegistry.node_is_valid_food_for_policy(other, policy):
    return false
  if subject_hostile:
    return other.is_in_group(&"prey")
  return bool(other.get("is_hostile")) or other.is_in_group(&"mobs")


static func _food_map_confidence_from_split(food_split: Dictionary) -> float:
  var ready: Array = food_split.get("ready", [])
  if not ready.is_empty():
    return 1.0
  var unready: Array = food_split.get("unready", [])
  if not unready.is_empty():
    return 0.35
  return 0.0


## Ranks ready live food by kind yield (desc), then distance; breaks ties with instance id.
static func best_ready_food_target(
  food_split: Dictionary,
  creature_pos: Vector3,
  excluded_instance_ids: Dictionary = {},
) -> Dictionary:
  var ready: Array = food_split.get("ready", [])
  if ready.is_empty():
    return {}
  var best: Dictionary = {}
  var best_yield := -INF
  var best_dist := INF
  for entry_v in ready:
    if typeof(entry_v) != TYPE_DICTIONARY:
      continue
    var entry: Dictionary = entry_v
    if excluded_instance_ids.has(int(entry.get("instance_id", 0))):
      continue
    var pos: Vector3 = entry.get("pos", Vector3.ZERO)
    var d := creature_pos.distance_to(pos)
    var yield_v := float(entry.get("kind_yield", _NEUTRAL_KIND_YIELD))
    if yield_v > best_yield + 1e-6 or (is_equal_approx(yield_v, best_yield) and d < best_dist):
      best_yield = yield_v
      best_dist = d
      best = entry
  return best.duplicate(true)
