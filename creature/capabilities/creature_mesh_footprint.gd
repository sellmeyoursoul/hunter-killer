extends RefCounted
class_name CreatureMeshFootprint
## Measuring-only helper (CREATURE_BODY_DIMENSIONS.md B24): rest-pose mesh AABB, size and pivot of a
## creature [code]Visual[/code] in body-local space. It never decides collision size.


const _MeshWorldAabb3D := preload("res://environment/mesh_world_aabb_3d.gd")


## Body-local mesh AABB for [param visual_root] relative to [param body].
## Returns [code]{valid, min, max, center, size, pivot_offset}[/code]: [code]size[/code] is
## [code]Vector3(width X, height Y, length Z)[/code]; [code]pivot_offset[/code] is the AABB bottom-centre
## (centre X, min Y, centre Z) relative to the body origin (zero when the B10 pivot is met).
## Measure before any facing yaw is applied to the Visual.
static func mesh_aabb_in_body_local(body: Node3D, visual_root: Node) -> Dictionary:
  var inactive := {
    "valid": false,
    "min": Vector3.ZERO,
    "max": Vector3.ZERO,
    "center": Vector3.ZERO,
    "size": Vector3.ZERO,
    "pivot_offset": Vector3.ZERO,
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
  var ctr := (mn + mx) * 0.5
  return {
    "valid": true,
    "min": mn,
    "max": mx,
    "center": ctr,
    "size": mx - mn,
    "pivot_offset": Vector3(ctr.x, mn.y, ctr.z),
  }
