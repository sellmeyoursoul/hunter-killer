extends RefCounted
class_name PlayfieldBounds3D
## Computes motor-playfield XZ bounds from a 3D playfield root ([CONVERT_TO_3D.md §D10](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).


const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


## Params:
## - root: Playfield subtree (grasslands import, floor colliders, etc.).
## Returns:
## - [code]valid[/code], motor-plane [code]min[/code]/[code]max[/code]/[code]size[/code], world [code]center[/code], [code]floor_y[/code].
static func xz_bounds_from_playfield_root(root: Node3D) -> Dictionary:
  if root == null:
    return _empty_bounds()
  var acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  _accumulate_node_bounds(root, acc)
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  if mn.x >= mx.x or mn.z >= mx.z:
    return _empty_bounds()
  var min2 := Vector2(mn.x, mn.z)
  var max2 := Vector2(mx.x, mx.z)
  var center := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
  return {
    "valid": true,
    "min": min2,
    "max": max2,
    "size": max2 - min2,
    "center": center,
    "floor_y": mn.y,
  }


static func _empty_bounds() -> Dictionary:
  return {
    "valid": false,
    "min": Vector2.ZERO,
    "max": Vector2.ZERO,
    "size": Vector2.ZERO,
    "center": Vector3.ZERO,
    "floor_y": 0.0,
  }


static func _accumulate_node_bounds(node: Node, acc: Array) -> void:
  if node is CollisionShape3D:
    _accumulate_collision_shape(node as CollisionShape3D, acc)
  elif node is MeshInstance3D:
    _accumulate_mesh_instance(node as MeshInstance3D, acc)
  for ch in node.get_children():
    _accumulate_node_bounds(ch, acc)


static func _accumulate_collision_shape(cs: CollisionShape3D, acc: Array) -> void:
  var sh: Shape3D = cs.shape
  if sh == null:
    return
  var xf: Transform3D = cs.global_transform
  if sh is BoxShape3D:
    _accumulate_box(xf, (sh as BoxShape3D).size, acc)
  elif sh is SphereShape3D:
    _accumulate_sphere(xf, (sh as SphereShape3D).radius, acc)
  elif sh is CapsuleShape3D:
    var cap := sh as CapsuleShape3D
    _accumulate_capsule(xf, cap.radius, cap.height, acc)
  elif sh is CylinderShape3D:
    var cyl := sh as CylinderShape3D
    _accumulate_cylinder(xf, cyl.radius, cyl.height, acc)


static func _accumulate_mesh_instance(mi: MeshInstance3D, acc: Array) -> void:
  var mesh: Mesh = mi.mesh
  if mesh == null:
    return
  var local_aabb := mesh.get_aabb()
  var corners := _box_corners_local(local_aabb.size)
  var origin := local_aabb.position
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  for c in corners:
    var w: Vector3 = mi.global_transform * (origin + c)
    mn.x = minf(mn.x, w.x)
    mn.y = minf(mn.y, w.y)
    mn.z = minf(mn.z, w.z)
    mx.x = maxf(mx.x, w.x)
    mx.y = maxf(mx.y, w.y)
    mx.z = maxf(mx.z, w.z)
  acc[0] = mn
  acc[1] = mx


static func _box_corners_local(size: Vector3) -> Array:
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


static func _accumulate_box(xf: Transform3D, size: Vector3, acc: Array) -> void:
  var half := size * 0.5
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  for lx in [-half.x, half.x]:
    for ly in [-half.y, half.y]:
      for lz in [-half.z, half.z]:
        var w: Vector3 = xf * Vector3(lx, ly, lz)
        mn.x = minf(mn.x, w.x)
        mn.y = minf(mn.y, w.y)
        mn.z = minf(mn.z, w.z)
        mx.x = maxf(mx.x, w.x)
        mx.y = maxf(mx.y, w.y)
        mx.z = maxf(mx.z, w.z)
  acc[0] = mn
  acc[1] = mx


static func _accumulate_sphere(xf: Transform3D, radius: float, acc: Array) -> void:
  var r := maxf(radius, 0.01)
  var c := xf.origin
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  mn.x = minf(mn.x, c.x - r)
  mn.y = minf(mn.y, c.y - r)
  mn.z = minf(mn.z, c.z - r)
  mx.x = maxf(mx.x, c.x + r)
  mx.y = maxf(mx.y, c.y + r)
  mx.z = maxf(mx.z, c.z + r)
  acc[0] = mn
  acc[1] = mx


static func _accumulate_capsule(xf: Transform3D, radius: float, height: float, acc: Array) -> void:
  var r := maxf(radius, 0.01)
  var half_h := maxf(height * 0.5, 0.0)
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  for ly in [-half_h, half_h]:
    for lx in [-r, r]:
      for lz in [-r, r]:
        var w: Vector3 = xf * Vector3(lx, ly, lz)
        mn.x = minf(mn.x, w.x)
        mn.y = minf(mn.y, w.y)
        mn.z = minf(mn.z, w.z)
        mx.x = maxf(mx.x, w.x)
        mx.y = maxf(mx.y, w.y)
        mx.z = maxf(mx.z, w.z)
  acc[0] = mn
  acc[1] = mx


static func _accumulate_cylinder(xf: Transform3D, radius: float, height: float, acc: Array) -> void:
  _accumulate_capsule(xf, radius, height, acc)


## Maps a normalized playfield fraction ([code]0..1[/code] on XZ) to a grounded world position.
static func world_position_from_fraction(bounds: Dictionary, frac: Vector2, body_lift: float) -> Vector3:
  if not bool(bounds.get("valid", false)):
    return Vector3(frac.x, body_lift, frac.y)
  var mn: Vector2 = bounds.get("min", Vector2.ZERO)
  var sz: Vector2 = bounds.get("size", Vector2.ZERO)
  var floor_y := float(bounds.get("floor_y", 0.0))
  return Vector3(
    mn.x + frac.x * sz.x,
    floor_y + body_lift,
    mn.y + frac.y * sz.y,
  )


## Motor-plane position for a world point (XZ only).
static func motor_position_from_world(world_pos: Vector3) -> Vector2:
  return _MotorPlane.from_vec3(world_pos)
