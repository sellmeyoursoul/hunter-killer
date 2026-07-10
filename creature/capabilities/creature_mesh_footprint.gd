extends RefCounted
class_name CreatureMeshFootprint
## Capsule footprint derived from a creature [code]Visual[/code] mesh AABB in body-local space.


const _MeshWorldAabb3D := preload("res://environment/mesh_world_aabb_3d.gd")


## Body-local mesh AABB for [param visual_root] relative to [param body].
static func mesh_aabb_in_body_local(body: Node3D, visual_root: Node) -> Dictionary:
  var inactive := {
    "valid": false,
    "min": Vector3.ZERO,
    "max": Vector3.ZERO,
    "center": Vector3.ZERO,
    "radius": 0.0,
    "height": 0.0,
  }
  if body == null or visual_root == null:
    return inactive
  var world: Dictionary = _MeshWorldAabb3D.world_mesh_aabb(visual_root)
  if not bool(world.get("valid", false)):
    return inactive
  var wmn: Vector3 = world.get("min", Vector3.ZERO)
  var wmx: Vector3 = world.get("max", Vector3.ZERO)
  var body_inv := body.global_transform.affine_inverse()
  var corners: Array[Vector3] = [
    Vector3(wmn.x, wmn.y, wmn.z),
    Vector3(wmx.x, wmn.y, wmn.z),
    Vector3(wmx.x, wmn.y, wmx.z),
    Vector3(wmn.x, wmn.y, wmx.z),
    Vector3(wmn.x, wmx.y, wmn.z),
    Vector3(wmx.x, wmx.y, wmn.z),
    Vector3(wmx.x, wmx.y, wmx.z),
    Vector3(wmn.x, wmx.y, wmx.z),
  ]
  var acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  for corner in corners:
    var local: Vector3 = body_inv * corner
    var acc_mn: Vector3 = acc[0]
    var acc_mx: Vector3 = acc[1]
    acc_mn.x = minf(acc_mn.x, local.x)
    acc_mn.y = minf(acc_mn.y, local.y)
    acc_mn.z = minf(acc_mn.z, local.z)
    acc_mx.x = maxf(acc_mx.x, local.x)
    acc_mx.y = maxf(acc_mx.y, local.y)
    acc_mx.z = maxf(acc_mx.z, local.z)
    acc[0] = acc_mn
    acc[1] = acc_mx
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  if mn.x >= mx.x or mn.z >= mx.z:
    return inactive
  var sx := mx.x - mn.x
  var sy := mx.y - mn.y
  var sz := mx.z - mn.z
  var radius := maxf(sx, sz) * 0.5
  var height := sy - 2.0 * radius
  if height < 0.2:
    height = maxf(0.2, sy * 0.55)
  height = maxf(2.0 * radius + 0.05, height)
  return {
    "valid": true,
    "min": mn,
    "max": mx,
    "center": (mn + mx) * 0.5,
    "radius": radius,
    "height": height,
  }
