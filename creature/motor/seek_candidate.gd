## Unified seek ingress records ([CREATURE_MOVEMENT_V2.md §A.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
class_name SeekCandidate
extends Object

const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

const SOURCE_LIVE_READY := &"live_ready"
const SOURCE_LIVE_UNREADY := &"live_unready"
const SOURCE_MEMORY_PRECISE := &"memory_precise"
const SOURCE_MEMORY_MOVING := &"memory_moving"
const SOURCE_LIVE_PREY := &"live_prey"


## Returns a seek-candidate dictionary for motor ingress / filtering.
static func make(
  pos: Vector3,
  goal_kind: StringName,
  consumable_now: bool = true,
  is_moving: bool = false,
  instance_id: int = 0,
  source: StringName = &"",
  line_of_sight_clear: bool = true,
  occluded: bool = false,
  occlusion_fraction: float = 0.0,
) -> Dictionary:
  return {
    "pos": pos,
    "goal_kind": goal_kind,
    "consumable_now": consumable_now,
    "is_moving": is_moving,
    "instance_id": instance_id,
    "source": source,
    "line_of_sight_clear": line_of_sight_clear,
    "occluded": occluded,
    "occlusion_fraction": occlusion_fraction,
  }


static func _pos_from_entry(e: Variant) -> Variant:
  if typeof(e) == TYPE_VECTOR3:
    return e
  if typeof(e) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(e as Vector2)
  if typeof(e) == TYPE_DICTIONARY:
    return _MotorPlane.read_pos((e as Dictionary).get("pos", null))
  return null


## Build candidates from awareness food split ([code]ready[/code] / [code]unready[/code] entries).
static func build_from_food_split(food_split: Dictionary) -> Array:
  var out: Array = []
  for e in food_split.get("ready", []) as Array:
    var p: Variant = _pos_from_entry(e)
    if p == null:
      continue
    if typeof(e) == TYPE_DICTIONARY:
      var d: Dictionary = e as Dictionary
      out.append(
        make(
          p as Vector3,
          _GkReg.GK_FIND_FOOD,
          true,
          false,
          int(d.get("instance_id", 0)),
          SOURCE_LIVE_READY,
          bool(d.get("line_of_sight_clear", true)),
          bool(d.get("occluded", false)),
          float(d.get("occlusion_fraction", 0.0)),
        )
      )
    else:
      out.append(make(p as Vector3, _GkReg.GK_FIND_FOOD, true, false, 0, SOURCE_LIVE_READY))
  for e in food_split.get("unready", []) as Array:
    var p2: Variant = _pos_from_entry(e)
    if p2 == null:
      continue
    if typeof(e) == TYPE_DICTIONARY:
      var d2: Dictionary = e as Dictionary
      out.append(
        make(
          p2 as Vector3,
          _GkReg.GK_FIND_FOOD,
          false,
          false,
          int(d2.get("instance_id", 0)),
          SOURCE_LIVE_UNREADY,
          bool(d2.get("line_of_sight_clear", true)),
          bool(d2.get("occluded", false)),
          float(d2.get("occlusion_fraction", 0.0)),
        )
      )
    else:
      out.append(make(p2 as Vector3, _GkReg.GK_FIND_FOOD, false, false, 0, SOURCE_LIVE_UNREADY))
  return out


## Build candidates from legacy motor ingress lists (compat / tests).
static func build_from_motor_ingress(
  food_ready: Array,
  food_unready: Array,
  prey_positions: Array,
) -> Array:
  var split := {"ready": food_ready, "unready": food_unready}
  var out: Array = build_from_food_split(split)
  for pq in prey_positions:
    var pp := _MotorPlane.read_pos(pq)
    if pp == Vector3.ZERO and typeof(pq) != TYPE_VECTOR3 and typeof(pq) != TYPE_VECTOR2:
      continue
    out.append(
      make(pp, _GkReg.GK_FIND_FOOD, true, true, 0, SOURCE_LIVE_PREY)
    )
  return out


## World positions for candidates matching [param goal_kind] with [param consumable_only].
static func positions_matching(
  candidates: Array,
  goal_kind: StringName,
  consumable_only: bool = true,
) -> Array:
  var out: Array = []
  for c in candidates:
    if typeof(c) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = c as Dictionary
    if row.get("goal_kind", &"") != goal_kind:
      continue
    if consumable_only and not bool(row.get("consumable_now", true)):
      continue
    var p: Variant = row.get("pos", null)
    if typeof(p) == TYPE_VECTOR3:
      out.append(p as Vector3)
  return out


## Nearest consumable [code]find_food[/code] position (for locale-prior anchor).
static func nearest_find_food_anchor(candidates: Array, creature_pos: Vector3) -> Vector3:
  var best := Vector3.ZERO
  var best_d := INF
  for c in candidates:
    if typeof(c) != TYPE_DICTIONARY:
      continue
    var row: Dictionary = c as Dictionary
    if row.get("goal_kind", &"") != _GkReg.GK_FIND_FOOD:
      continue
    if not bool(row.get("consumable_now", true)):
      continue
    var p: Variant = row.get("pos", null)
    if typeof(p) != TYPE_VECTOR3:
      continue
    var pt := p as Vector3
    var d := creature_pos.distance_to(pt)
    if d < best_d:
      best_d = d
      best = pt
  return best
