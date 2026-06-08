extends RefCounted
class_name PlayfieldPerimeterBoulders
## Places perimeter [code]h-k-boulder1[/code] rocks along the playfield XZ AABB ([CONVERT_TO_3D.md §3.5](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).

## [code]h-k-boulder1[/code] mesh spans ~2.1 m on XZ; fox capsule diameter is 0.8 m.
## Spacing below rock diameter overlaps colliders so creatures cannot slip between rocks.
const DEFAULT_SPACING := 1.4
const DEFAULT_INSET := 0.5


## Params:
## - parent: Receives spawned boulder roots.
## - bounds: Dictionary from [method PlayfieldBounds3D.xz_bounds_from_playfield_root].
## - boulder_scene: Imported boulder [PackedScene].
## - spacing: Distance between rock centers along each edge.
## - inset: Pull rocks inward from the AABB edge so colliders overlap the rim.
static func place_along_perimeter(
  parent: Node3D,
  bounds: Dictionary,
  boulder_scene: PackedScene,
  spacing: float = DEFAULT_SPACING,
  inset: float = DEFAULT_INSET,
) -> void:
  if parent == null or boulder_scene == null or not bool(bounds.get("valid", false)):
    return
  var mn: Vector2 = bounds.get("min", Vector2.ZERO)
  var mx: Vector2 = bounds.get("max", Vector2.ZERO)
  var floor_y := float(bounds.get("floor_y", 0.0))
  var step := maxf(spacing, 1.0)
  var inset_v := maxf(inset, 0.0)
  _spawn_edge(parent, boulder_scene, mn.x + inset_v, mx.x - inset_v, mn.y + inset_v, floor_y, step, true)
  _spawn_edge(parent, boulder_scene, mn.x + inset_v, mx.x - inset_v, mx.y - inset_v, floor_y, step, true)
  _spawn_edge(parent, boulder_scene, mn.x + inset_v, mn.x + inset_v, mn.y + inset_v, mx.y - inset_v, step, false)
  _spawn_edge(parent, boulder_scene, mx.x - inset_v, mx.x - inset_v, mn.y + inset_v, mx.y - inset_v, step, false)


static func _spawn_edge(
  parent: Node3D,
  scene: PackedScene,
  x0: float,
  x1: float,
  fixed_axis: float,
  floor_y: float,
  step: float,
  vary_x: bool,
) -> void:
  if vary_x:
    var x := x0
    while x <= x1 + 0.001:
      _spawn_one(parent, scene, Vector3(x, floor_y, fixed_axis))
      x += step
  else:
    var z := x0
    while z <= x1 + 0.001:
      _spawn_one(parent, scene, Vector3(fixed_axis, floor_y, z))
      z += step


static func _spawn_one(parent: Node3D, scene: PackedScene, pos: Vector3) -> void:
  var rock := scene.instantiate() as Node3D
  if rock == null:
    return
  parent.add_child(rock)
  rock.global_position = pos
  rock.add_to_group(&"obstacles")
  PlayfieldBounds3D.ensure_obstacle_physics(rock)
