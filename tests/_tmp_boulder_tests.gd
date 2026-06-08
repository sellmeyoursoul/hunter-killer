extends SceneTree

const _PlayfieldBounds3D := preload("res://environment/playfield_bounds_3d.gd")
const _PerimeterBoulders := preload("res://environment/playfield_perimeter_boulders.gd")

var _failures := 0


func _init() -> void:
  _test_boulder_obstacle_collision_bake()
  _test_perimeter_boulder_density()
  quit(0 if _failures == 0 else 1)


func _assert(cond: bool, msg: String) -> void:
  if cond:
    print("OK: %s" % msg)
    return
  _failures += 1
  push_error("FAIL: %s" % msg)


func _test_boulder_obstacle_collision_bake() -> void:
  var boulder: PackedScene = load(
    "res://assets/environment/obstacle_boulder/h-k-boulder1.blend",
  ) as PackedScene
  _assert(boulder != null, "boulder scene loads")
  var rock := boulder.instantiate() as Node3D
  var scene_root := Node3D.new()
  scene_root.add_child(rock)
  _assert(_PlayfieldBounds3D.count_static_bodies(rock) == 0, "no physics before bake")
  var colliders := _PlayfieldBounds3D.ensure_obstacle_physics(rock)
  _assert(colliders >= 1, "bakes trimesh collision")
  var sb := rock.get_node_or_null("AutoCollision_Cube") as StaticBody3D
  _assert(sb != null and sb.is_in_group(&"obstacles"), "collider in obstacles group")


func _test_perimeter_boulder_density() -> void:
  var boulder: PackedScene = load(
    "res://assets/environment/obstacle_boulder/h-k-boulder1.blend",
  ) as PackedScene
  var bounds: Dictionary = {
    "valid": true,
    "min": Vector2(0.0, 0.0),
    "max": Vector2(40.0, 30.0),
    "surface_y": 0.0,
    "floor_y": 0.0,
  }
  var tight_parent := Node3D.new()
  var loose_parent := Node3D.new()
  var scene_root := Node3D.new()
  scene_root.add_child(tight_parent)
  scene_root.add_child(loose_parent)
  _PerimeterBoulders.place_along_perimeter(
    tight_parent, bounds, boulder, _PerimeterBoulders.DEFAULT_SPACING, _PerimeterBoulders.DEFAULT_INSET
  )
  _PerimeterBoulders.place_along_perimeter(loose_parent, bounds, boulder, 4.0, 0.8)
  print("tight=%d loose=%d" % [tight_parent.get_child_count(), loose_parent.get_child_count()])
  _assert(
    tight_parent.get_child_count() > loose_parent.get_child_count() * 2,
    "tight spacing denser than 4m",
  )
