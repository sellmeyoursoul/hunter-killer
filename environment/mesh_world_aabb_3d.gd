extends RefCounted
class_name MeshWorldAabb3D
## World-space mesh AABB walks for props, creatures, and playfield fallbacks.


## World-space AABB of all [MeshInstance3D] under [param root].
## Returns [code]valid[/code], [code]min[/code], [code]max[/code], [code]center[/code], [code]xz_radius[/code].
static func world_mesh_aabb(root: Node) -> Dictionary:
  var inactive := {
    "valid": false,
    "min": Vector3.ZERO,
    "max": Vector3.ZERO,
    "center": Vector3.ZERO,
    "xz_radius": 0.0,
  }
  if root == null:
    return inactive
  var acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  accumulate_mesh_bounds(root, acc)
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  if mn.x >= mx.x or mn.z >= mx.z:
    return inactive
  var center := (mn + mx) * 0.5
  var half_x := (mx.x - mn.x) * 0.5
  var half_z := (mx.z - mn.z) * 0.5
  return {
    "valid": true,
    "min": mn,
    "max": mx,
    "center": center,
    "xz_radius": maxf(half_x, half_z),
  }


## Expands [param acc] [code][min, max][/code] with every [MeshInstance3D] under [param node].
static func accumulate_mesh_bounds(node: Node, acc: Array) -> void:
  if node is MeshInstance3D:
    _accumulate_mesh_instance(node as MeshInstance3D, acc)
  for ch in node.get_children():
    accumulate_mesh_bounds(ch, acc)


static func _accumulate_mesh_instance(mi: MeshInstance3D, acc: Array) -> void:
  var mesh: Mesh = mi.mesh
  if mesh == null:
    return
  var local_aabb := mesh.get_aabb()
  var corners := box_corners_local(local_aabb.size)
  var origin := local_aabb.position
  var mi_xf := node_global_transform(mi)
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  for c in corners:
    var w: Vector3 = mi_xf * (origin + c)
    mn.x = minf(mn.x, w.x)
    mn.y = minf(mn.y, w.y)
    mn.z = minf(mn.z, w.z)
    mx.x = maxf(mx.x, w.x)
    mx.y = maxf(mx.y, w.y)
    mx.z = maxf(mx.z, w.z)
  acc[0] = mn
  acc[1] = mx


static func box_corners_local(size: Vector3) -> Array:
  return [
    Vector3.ZERO,
    Vector3(size.x, 0.0, 0.0),
    Vector3(size.x, 0.0, size.z),
    Vector3(0.0, 0.0, size.z),
    Vector3(0.0, size.y, 0.0),
    Vector3(size.x, size.y, 0.0),
    Vector3(size.x, size.y, size.z),
    Vector3(0.0, size.y, size.z),
  ]


## Global transform for bounds walks — uses scene graph when not yet in-tree (headless fixtures).
static func node_global_transform(node: Node3D) -> Transform3D:
  if node.is_inside_tree():
    return node.global_transform
  var chain: Array[Node3D] = []
  var cur: Node = node
  while cur is Node3D:
    chain.append(cur as Node3D)
    cur = cur.get_parent()
  chain.reverse()
  var xf := Transform3D.IDENTITY
  for n in chain:
    xf = xf * n.transform
  return xf
