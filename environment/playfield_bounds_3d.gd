extends RefCounted
class_name PlayfieldBounds3D
## Computes motor-playfield XZ bounds from a 3D playfield root ([CONVERT_TO_3D.md §D10](../../Project_Docs/Completed_Features/CONVERT_TO_3D.md)).


const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _MeshWorldAabb3D := preload("res://environment/mesh_world_aabb_3d.gd")

const WORLD_STATIC_COLLISION_MASK := 1
const GROUND_RAY_HEIGHT := 256.0
const GROUND_RAY_DEPTH := 512.0


## Params:
## - root: Playfield subtree (grasslands import, floor colliders, etc.).
## Returns:
## - [code]valid[/code], motor-plane [code]min[/code]/[code]max[/code]/[code]size[/code], world [code]center[/code],
##   [code]floor_y[/code] (collision AABB min Y — raycast hint), [code]surface_y[/code] (collision AABB max Y).
static func xz_bounds_from_playfield_root(root: Node3D) -> Dictionary:
  if root == null:
    return _empty_bounds()
  var acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  _accumulate_collision_bounds(root, acc)
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  if mn.x >= mx.x or mn.z >= mx.z:
    acc = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
    _MeshWorldAabb3D.accumulate_mesh_bounds(root, acc)
    mn = acc[0]
    mx = acc[1]
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
    "surface_y": mx.y,
  }


static func _empty_bounds() -> Dictionary:
  return {
    "valid": false,
    "min": Vector2.ZERO,
    "max": Vector2.ZERO,
    "size": Vector2.ZERO,
    "center": Vector3.ZERO,
    "floor_y": 0.0,
    "surface_y": 0.0,
  }


## Walkable playfield extent from physics colliders only (visual meshes can pad the AABB).
static func _accumulate_collision_bounds(node: Node, acc: Array) -> void:
  if node is CollisionShape3D:
    _accumulate_collision_shape(node as CollisionShape3D, acc)
  for ch in node.get_children():
    _accumulate_collision_bounds(ch, acc)


## Fallback when a playfield import has meshes but no collision yet.
static func _accumulate_mesh_bounds(node: Node, acc: Array) -> void:
  _MeshWorldAabb3D.accumulate_mesh_bounds(node, acc)


## World-space AABB of all [MeshInstance3D] under [param root].
## Returns [code]valid[/code], [code]min[/code], [code]max[/code], [code]center[/code], [code]xz_radius[/code].
static func world_mesh_aabb(root: Node) -> Dictionary:
  return _MeshWorldAabb3D.world_mesh_aabb(root)


static func _accumulate_collision_shape(cs: CollisionShape3D, acc: Array) -> void:
  var sh: Shape3D = cs.shape
  if sh == null:
    return
  var xf: Transform3D = _MeshWorldAabb3D.node_global_transform(cs)
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
  var spawn_y := float(bounds.get("surface_y", bounds.get("floor_y", 0.0)))
  return Vector3(
    mn.x + frac.x * sz.x,
    spawn_y + body_lift,
    mn.y + frac.y * sz.y,
  )


## Motor-plane position for a world point (XZ only).
static func motor_position_from_world(world_pos: Vector3) -> Vector2:
  return _MotorPlane.from_vec3(world_pos)


## Distance from [param body] origin to capsule bottom (hemisphere included) for duel spawn grounding.
static func capsule_half_height_on_body(body: CharacterBody3D) -> float:
  var cs := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs != null and cs.shape is CapsuleShape3D:
    var cap := cs.shape as CapsuleShape3D
    return cap.height * 0.5 + cap.radius
  return 0.95


## Root global Y so the Body capsule bottom rests on [param surface_y].
static func root_global_y_for_surface(body: CharacterBody3D, surface_y: float) -> float:
  return surface_y - body.position.y + capsule_half_height_on_body(body)


## Raycasts on XZ for [code]world_static[/code] (layer 1) walkable surface.
## Params:
## - space: Active [PhysicsDirectSpaceState3D] (caller must be in tree).
## - xz: Horizontal sample point.
## - hint_y: Start near expected floor ([code]floor_y[/code] from bounds).
## Returns:
## - [code]hit[/code], [code]surface_y[/code] (hint when no hit).
static func raycast_ground_surface(
  space: PhysicsDirectSpaceState3D,
  xz: Vector2,
  hint_y: float,
  collision_mask: int = WORLD_STATIC_COLLISION_MASK,
  exclude_rids: Array = [],
) -> Dictionary:
  if space == null:
    return {"hit": false, "surface_y": hint_y}
  var x := xz.x
  var z := xz.y
  var down_from := Vector3(x, hint_y + GROUND_RAY_HEIGHT, z)
  var down_to := Vector3(x, hint_y - GROUND_RAY_DEPTH, z)
  var query := PhysicsRayQueryParameters3D.create(down_from, down_to)
  query.collision_mask = collision_mask
  query.hit_from_inside = true
  if not exclude_rids.is_empty():
    query.exclude = exclude_rids
  var hit: Dictionary = space.intersect_ray(query)
  if not hit.is_empty():
    return {"hit": true, "surface_y": float((hit.get("position", Vector3.ZERO) as Vector3).y)}
  var up_from := Vector3(x, hint_y - 10.0, z)
  var up_to := Vector3(x, hint_y + GROUND_RAY_HEIGHT, z)
  query = PhysicsRayQueryParameters3D.create(up_from, up_to)
  query.collision_mask = collision_mask
  if not exclude_rids.is_empty():
    query.exclude = exclude_rids
  hit = space.intersect_ray(query)
  if not hit.is_empty():
    return {"hit": true, "surface_y": float((hit.get("position", Vector3.ZERO) as Vector3).y)}
  return {"hit": false, "surface_y": hint_y}


## Places [param creature_root] so [param body] capsule bottom sits on raycast ground at [param xz].
## Returns true when a static surface was hit.
static func snap_creature_root_to_ground(
  creature_root: Node3D,
  body: CharacterBody3D,
  xz: Vector2,
  hint_y: float,
  space: PhysicsDirectSpaceState3D,
) -> bool:
  var ground: Dictionary = raycast_ground_surface(space, xz, hint_y)
  var surface_y := float(ground.get("surface_y", hint_y))
  var root_y := root_global_y_for_surface(body, surface_y)
  creature_root.global_position = Vector3(xz.x, root_y, xz.y)
  return bool(ground.get("hit", false))


## Runs zero-intent [method CharacterBody3D.move_and_slide] steps so [method CharacterBody3D.is_on_floor] stabilizes after snap.
## Params:
## - body: Duel creature [code]Body[/code] already in the scene tree.
## - steps: Physics iterations (default 12).
## - step_sec: Fixed timestep per iteration (default 1/60 s).
static func settle_character_body_on_floor(
  body: CharacterBody3D,
  steps: int = 12,
  step_sec: float = 1.0 / 60.0,
) -> void:
  if body == null:
    return
  var grav := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
  if not body.is_on_floor():
    body.velocity = Vector3(0.0, -2.0, 0.0)
    body.move_and_slide()
  body.velocity = Vector3.ZERO
  for _i in steps:
    if body.is_on_floor():
      body.velocity.y = 0.0
    else:
      body.velocity.y -= grav * step_sec
    body.move_and_slide()


## Re-snaps duel spawn root to ground and settles until [method CharacterBody3D.is_on_floor] or nudge budget exhausted.
## Params:
## - creature_root: Creature root [code]Node3D[/code] parent of [param body].
## - body: Duel [code]Body[/code] already in the scene tree.
## - space: Active [PhysicsDirectSpaceState3D].
## - hint_y: Floor hint from playfield bounds.
## Returns:
## - True when [param body] reports on-floor after settlement.
static func settle_creature_spawn_on_floor(
  creature_root: Node3D,
  body: CharacterBody3D,
  space: PhysicsDirectSpaceState3D,
  hint_y: float,
  settle_steps: int = 12,
) -> bool:
  if creature_root == null or body == null:
    return false
  settle_character_body_on_floor(body, settle_steps)
  if body.is_on_floor():
    return true
  for _nudge in 8:
    var xz := Vector2(creature_root.global_position.x, creature_root.global_position.z)
    var ground: Dictionary = raycast_ground_surface(space, xz, hint_y)
    if bool(ground.get("hit", false)):
      creature_root.global_position.y = root_global_y_for_surface(
        body, float(ground.get("surface_y", hint_y))
      )
    else:
      creature_root.global_position.y -= 0.12
    settle_character_body_on_floor(body, 4)
    if body.is_on_floor():
      return true
  return body.is_on_floor()


## Lowest mesh point in [param prop_root] local space (for grounding imported props).
static func mesh_local_bottom_y(prop_root: Node3D) -> float:
  var acc: Array = [INF]
  _accum_mesh_bottom_in_root_space(prop_root, prop_root, acc)
  var min_y: float = acc[0]
  return 0.0 if min_y == INF else min_y


static func _accum_mesh_bottom_in_root_space(prop_root: Node3D, node: Node, acc: Array) -> void:
  if node is MeshInstance3D:
    var mi := node as MeshInstance3D
    var mesh: Mesh = mi.mesh
    if mesh != null:
      var local_aabb := mesh.get_aabb()
      var root_inv := prop_root.global_transform.affine_inverse()
      for c in _MeshWorldAabb3D.box_corners_local(local_aabb.size):
        var mesh_point: Vector3 = local_aabb.position + c
        var in_root: Vector3 = root_inv * (mi.global_transform * mesh_point)
        acc[0] = minf(float(acc[0]), in_root.y)
  for ch in node.get_children():
    _accum_mesh_bottom_in_root_space(prop_root, ch, acc)


## RIDs of every [CollisionObject3D] under [param root] (for ground-ray exclude lists).
static func collect_collision_object_rids(root: Node) -> Array:
  var rids: Array = []
  _collect_collision_object_rids_recursive(root, rids)
  return rids


static func _collect_collision_object_rids_recursive(node: Node, rids: Array) -> void:
  if node is CollisionObject3D:
    rids.append((node as CollisionObject3D).get_rid())
  for ch in node.get_children():
    _collect_collision_object_rids_recursive(ch, rids)


## Places [param prop_root] so mesh bottom rests on raycast ground at [param xz].
## Skips [param exclude_rids] plus any colliders on [param prop_root] so baked prop meshes do not block the ray.
## Returns true when a static surface was hit.
static func snap_prop_root_to_ground(
  prop_root: Node3D,
  xz: Vector2,
  hint_y: float,
  space: PhysicsDirectSpaceState3D,
  exclude_rids: Array = [],
) -> bool:
  var skip: Array = exclude_rids.duplicate()
  for rid in collect_collision_object_rids(prop_root):
    if not skip.has(rid):
      skip.append(rid)
  var ground: Dictionary = raycast_ground_surface(space, xz, hint_y, WORLD_STATIC_COLLISION_MASK, skip)
  var surface_y := float(ground.get("surface_y", hint_y))
  var bottom_y := mesh_local_bottom_y(prop_root)
  prop_root.global_position = Vector3(xz.x, surface_y - bottom_y, xz.y)
  return bool(ground.get("hit", false))


## True when [param world_xz] lies inside motor bounds (XZ only).
static func xz_inside_bounds(bounds: Dictionary, world_xz: Vector2) -> bool:
  if not bool(bounds.get("valid", false)):
    return false
  var mn: Vector2 = bounds.get("min", Vector2.ZERO)
  var mx: Vector2 = bounds.get("max", Vector2.ZERO)
  return world_xz.x >= mn.x and world_xz.x <= mx.x and world_xz.y >= mn.y and world_xz.y <= mx.y


## Counts [StaticBody3D] nodes under [param node].
static func count_static_bodies(node: Node) -> int:
  var n := 0
  if node is StaticBody3D:
    n += 1
  for ch in node.get_children():
    n += count_static_bodies(ch)
  return n


## Forces [code]world_static[/code] layer/mask on playfield [StaticBody3D] colliders.
static func ensure_world_static_layers(node: Node) -> void:
  if node is StaticBody3D:
    var sb := node as StaticBody3D
    sb.collision_layer = WORLD_STATIC_COLLISION_MASK
    sb.collision_mask = WORLD_STATIC_COLLISION_MASK
    return
  for ch in node.get_children():
    ensure_world_static_layers(ch)


## Bakes trimesh colliders for mesh-only obstacle imports and tags bodies for motor + physics.
## Policy: skips baking when any [StaticBody3D] already exists (authored shells bake in scene code).
## Mesh-only imports (e.g. boulders) must ship without [StaticBody3D] so spawn-time trimesh bake runs.
## See [StaticObstacleCollision] and [ENVIRONMENT_MODEL_PLAN.md §6.3](../../Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md).
## Returns the number of [StaticBody3D] colliders now under [param root] (existing or newly added).
static func ensure_obstacle_physics(root: Node3D) -> int:
  if root == null:
    return 0
  var existing := count_static_bodies(root)
  if existing == 0:
    supplement_trimesh_collision_from_meshes(root, root)
  ensure_world_static_layers(root)
  _tag_obstacle_static_bodies(root)
  return count_static_bodies(root)


static func _tag_obstacle_static_bodies(node: Node) -> void:
  if node is StaticBody3D:
    node.add_to_group(&"obstacles")
    return
  for ch in node.get_children():
    _tag_obstacle_static_bodies(ch)


## When a mesh import has no physics bodies, bake trimesh [StaticBody3D] colliders (layer 1).
## Returns the number of colliders added.
static func supplement_trimesh_collision_from_meshes(scene_root: Node, collision_parent: Node3D) -> int:
  var acc: Array = [0]
  _supplement_trimesh_recursive(scene_root, collision_parent, acc)
  return int(acc[0])


static func _supplement_trimesh_recursive(node: Node, collision_parent: Node3D, acc: Array) -> void:
  if node is MeshInstance3D:
    var mi := node as MeshInstance3D
    var mesh: Mesh = mi.mesh
    if mesh != null:
      var sb := StaticBody3D.new()
      sb.name = "AutoCollision_%s" % mi.name
      var cs := CollisionShape3D.new()
      cs.shape = mesh.create_trimesh_shape()
      sb.add_child(cs)
      collision_parent.add_child(sb)
      sb.global_transform = mi.global_transform
      sb.collision_layer = WORLD_STATIC_COLLISION_MASK
      sb.collision_mask = WORLD_STATIC_COLLISION_MASK
      acc[0] = int(acc[0]) + 1
  for ch in node.get_children():
    _supplement_trimesh_recursive(ch, collision_parent, acc)
