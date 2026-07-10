extends RefCounted
class_name StaticObstacleCollision
## Mesh-aligned collision for static props (shrubs, mesh-only boulder imports).
## Policy: mesh-only imports bake at spawn via [method PlayfieldBounds3D.ensure_obstacle_physics];
## authored [StaticBody3D] shells (food shrubs) bake convex hulls from visuals in [code]_ready[/code].


const _MeshWorldAabb3D := preload("res://environment/mesh_world_aabb_3d.gd")


## World-space AABB of all [MeshInstance3D] under [param root].
## Returns [code]valid[/code], [code]min[/code], [code]max[/code], [code]center[/code], [code]xz_radius[/code].
static func world_mesh_aabb(root: Node) -> Dictionary:
  return _MeshWorldAabb3D.world_mesh_aabb(root)


## Replaces [CollisionShape3D] children on [param blocker] with convex hulls from [param visual_root].
## Returns the number of convex shapes added (0 when no mesh).
static func sync_convex_blocker_from_visual(blocker: StaticBody3D, visual_root: Node3D) -> int:
  if blocker == null or visual_root == null:
    return 0
  _clear_collision_shapes(blocker)
  var acc: Array = [0]
  var blocker_inv := blocker.global_transform.affine_inverse()
  _add_convex_shapes_recursive(visual_root, blocker, blocker_inv, acc)
  return int(acc[0])


## Sizes [param area]'s first [CollisionShape3D] sphere to the visual mesh footprint (+ [param padding]).
static func fit_pickup_sphere_from_visual(
  area: Area3D,
  visual_root: Node3D,
  padding: float = 0.15,
) -> bool:
  if area == null or visual_root == null:
    return false
  var aabb := world_mesh_aabb(visual_root)
  if not bool(aabb.get("valid", false)):
    return false
  var radius := float(aabb.get("xz_radius", 0.0)) + maxf(0.0, padding)
  if radius <= 0.0:
    return false
  var cs := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs == null:
    cs = CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    area.add_child(cs)
  var sphere := cs.shape as SphereShape3D
  if sphere == null:
    sphere = SphereShape3D.new()
    cs.shape = sphere
  sphere.radius = radius
  return true


static func _clear_collision_shapes(body: StaticBody3D) -> void:
  var to_remove: Array[Node] = []
  for child in body.get_children():
    if child is CollisionShape3D:
      to_remove.append(child)
  for node in to_remove:
    node.free()


static func _add_convex_shapes_recursive(
  node: Node,
  blocker: StaticBody3D,
  blocker_inv: Transform3D,
  acc: Array,
) -> void:
  if node is MeshInstance3D:
    var mi := node as MeshInstance3D
    var mesh: Mesh = mi.mesh
    if mesh != null:
      var convex: Shape3D = mesh.create_convex_shape()
      if convex != null:
        var cs := CollisionShape3D.new()
        cs.shape = convex
        cs.transform = blocker_inv * mi.global_transform
        blocker.add_child(cs)
        acc[0] = int(acc[0]) + 1
  for child in node.get_children():
    _add_convex_shapes_recursive(child, blocker, blocker_inv, acc)
