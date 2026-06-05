## Builds static obstacle AABBs (repulsion channel) and outline sample points (strategic shield/pin channel).
## Rock field uses group [code]obstacles[/code]; **shrub footprints** ([code]food_plants[/code] subtree [StaticBody2D]) merge in separately so predators avoid bushes without putting shrubs on the global obstacle group ([code]bush_food.gd[/code] grazing vs repulsion tuning in [method AiDriver._filter_obstacle_geom_for_foraging_prey]).
## 3D bodies project collision onto the motor XZ plane ([CONVERT_TO_3D.md §3.5](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).
extends Object
class_name MotorObstacleGeometry


static func _as_grid(v: Vector3) -> Vector2:
  return Vector2(v.x, v.z)


static func _read_pos_v3(v: Variant) -> Vector3:
  var p: Variant = Callable(MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


## Transforms all corners of [param local_rect] into world space via [param xf].
static func _rect_corners_world(xf: Transform2D, local_rect: Rect2) -> PackedVector2Array:
  var mn := local_rect.position
  var mx := local_rect.position + local_rect.size
  var out := PackedVector2Array()
  out.append(xf * Vector2(mn.x, mn.y))
  out.append(xf * Vector2(mx.x, mn.y))
  out.append(xf * Vector2(mx.x, mx.y))
  out.append(xf * Vector2(mn.x, mx.y))
  return out


## Axis-aligned half extents and center enclosing [param corners] (nonempty).
static func _aabb_from_corners(corners: PackedVector2Array) -> Dictionary:
  var mn := corners[0]
  var mx := corners[0]
  for i in range(1, corners.size()):
    var q := corners[i]
    mn.x = minf(mn.x, q.x)
    mn.y = minf(mn.y, q.y)
    mx.x = maxf(mx.x, q.x)
    mx.y = maxf(mx.y, q.y)
  var center := (mn + mx) * 0.5
  var half := (mx - mn) * 0.5
  return {
    "position": MotorPlane.to_horizontal_vec3(center),
    "half_extents": half,
  }


static func _aabb_from_corners_3d(corners: PackedVector3Array) -> Dictionary:
  var as_2d := PackedVector2Array()
  for i in range(corners.size()):
    as_2d.append(_as_grid(corners[i]))
  return _aabb_from_corners(as_2d)


## Extra capsule rim samples beyond [method CapsuleShape2D.get_rect] corners for flank scoring.
static func _capsule_rim_world(cs: CollisionShape2D, cap: CapsuleShape2D) -> PackedVector2Array:
  var xf := cs.global_transform
  var out := PackedVector2Array()
  var rr := cap.get_rect()
  var corners := _rect_corners_world(xf, rr)
  out.append_array(corners)
  var seg_top := xf * Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y)
  var seg_bot := xf * Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y + rr.size.y)
  var r := maxf(cap.radius, 1.0)
  for k in range(8):
    var ang := PI * float(k) / 4.0
    var off := xf.basis_xform(Vector2(cos(ang), sin(ang)) * r * 0.65)
    out.append(seg_top + off)
    out.append(seg_bot + off)
  return out


## Appends geometry from one collision shape ([param cs]) into [param out_aabbs] / [param sample_points].
static func _append_collision_shape_geom(
  cs: CollisionShape2D, out_aabbs: Array, sample_points: PackedVector3Array
) -> void:
  var sh: Shape2D = cs.shape
  if sh == null:
    return
  if sh is RectangleShape2D:
    var rect_sh := sh as RectangleShape2D
    var corners := _rect_corners_world(cs.global_transform, rect_sh.get_rect())
    if corners.size() >= 4:
      out_aabbs.append(_aabb_from_corners(corners))
      for i in range(corners.size()):
        sample_points.append(MotorPlane.to_horizontal_vec3(corners[i]))
  elif sh is CircleShape2D:
    var circ := sh as CircleShape2D
    var xf_circ := cs.global_transform
    var rad := maxf(circ.radius, 1.0)
    var rim_circ := PackedVector2Array()
    for k in range(16):
      var ang := TAU * float(k) / 16.0
      rim_circ.append(xf_circ * (Vector2(cos(ang), sin(ang)) * rad))
    if rim_circ.size() >= 8:
      out_aabbs.append(_aabb_from_corners(rim_circ))
      for i in range(rim_circ.size()):
        sample_points.append(MotorPlane.to_horizontal_vec3(rim_circ[i]))
  elif sh is CapsuleShape2D:
    var cap := sh as CapsuleShape2D
    var rim := _capsule_rim_world(cs, cap)
    if rim.size() >= 4:
      out_aabbs.append(_aabb_from_corners(rim))
      for i in range(rim.size()):
        sample_points.append(MotorPlane.to_horizontal_vec3(rim[i]))
  elif sh is ConvexPolygonShape2D:
    var poly := sh as ConvexPolygonShape2D
    var xf := cs.global_transform
    var gcorners := PackedVector2Array()
    for pv in poly.points:
      gcorners.append(xf * pv)
    if gcorners.size() >= 3:
      out_aabbs.append(_aabb_from_corners(gcorners))
      for i in range(gcorners.size()):
        sample_points.append(MotorPlane.to_horizontal_vec3(gcorners[i]))


## Accumulates collision shapes attached to one [StaticBody2D].
static func append_static_body_shapes(
  sb: StaticBody2D, out_aabbs: Array, sample_points: PackedVector3Array
) -> void:
  for child in sb.get_children():
    if child is CollisionShape2D:
      _append_collision_shape_geom(child as CollisionShape2D, out_aabbs, sample_points)


## Accumulates [CollisionShape3D] children on a [StaticBody3D], projected to motor XZ.
static func append_static_body_shapes_3d(
  sb: StaticBody3D, out_aabbs: Array, sample_points: PackedVector3Array
) -> void:
  for child in sb.get_children():
    if child is CollisionShape3D:
      _append_collision_shape_geom_3d(child as CollisionShape3D, out_aabbs, sample_points)


## Appends one 3D collision shape projected onto the motor plane.
static func _append_collision_shape_geom_3d(
  cs: CollisionShape3D, out_aabbs: Array, sample_points: PackedVector3Array
) -> void:
  var sh: Shape3D = cs.shape
  if sh == null:
    return
  var xf := cs.global_transform
  var corners := PackedVector3Array()
  if sh is BoxShape3D:
    corners = _box_corners_motor_plane(xf, (sh as BoxShape3D).size)
  elif sh is SphereShape3D:
    corners = _sphere_rim_motor_plane(xf, (sh as SphereShape3D).radius)
  elif sh is CapsuleShape3D:
    var cap := sh as CapsuleShape3D
    corners = _capsule_rim_motor_plane(xf, cap.radius, cap.height)
  elif sh is CylinderShape3D:
    var cyl := sh as CylinderShape3D
    corners = _cylinder_rim_motor_plane(xf, cyl.radius, cyl.height)
  if corners.size() >= 3:
    out_aabbs.append(_aabb_from_corners_3d(corners))
    for i in range(corners.size()):
      sample_points.append(corners[i])


static func _box_corners_motor_plane(xf: Transform3D, size: Vector3) -> PackedVector3Array:
  var half := size * 0.5
  var out := PackedVector3Array()
  for lx in [-half.x, half.x]:
    for lz in [-half.z, half.z]:
      var wp := xf * Vector3(lx, 0.0, lz)
      out.append(Vector3(wp.x, 0.0, wp.z))
  return out


static func _sphere_rim_motor_plane(xf: Transform3D, radius: float) -> PackedVector3Array:
  var r := maxf(radius, 0.01)
  var out := PackedVector3Array()
  for k in range(16):
    var ang := TAU * float(k) / 16.0
    var local := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
    var wp := xf * local
    out.append(Vector3(wp.x, 0.0, wp.z))
  return out


static func _capsule_rim_motor_plane(xf: Transform3D, radius: float, height: float) -> PackedVector3Array:
  var r := maxf(radius, 0.01)
  var half_h := maxf(height * 0.5, 0.0)
  var out := PackedVector3Array()
  for ly in [-half_h, half_h]:
    for k in range(8):
      var ang := TAU * float(k) / 8.0
      var local := Vector3(cos(ang) * r, ly, sin(ang) * r)
      var wp := xf * local
      out.append(Vector3(wp.x, 0.0, wp.z))
  return out


static func _cylinder_rim_motor_plane(xf: Transform3D, radius: float, height: float) -> PackedVector3Array:
  return _capsule_rim_motor_plane(xf, radius, height)


## Nodes in group [code]obstacles[/code] ([StaticBody2D] / [StaticBody3D] roots).
static func collect_obstacle_group_statics(main: Node) -> Dictionary:
  var aabbs: Array = []
  var sample_points := PackedVector3Array()
  if main == null:
    return {"aabbs": aabbs, "sample_points": sample_points}
  for n in main.get_tree().get_nodes_in_group(&"obstacles"):
    if n is StaticBody2D:
      append_static_body_shapes(n as StaticBody2D, aabbs, sample_points)
    elif n is StaticBody3D:
      append_static_body_shapes_3d(n as StaticBody3D, aabbs, sample_points)
  return {"aabbs": aabbs, "sample_points": sample_points}


## Static blocking collision under each [code]food_plants[/code] shrub (solid + open blocker).
static func collect_plant_blocker_statics(main: Node) -> Dictionary:
  var aabbs: Array = []
  var sample_points := PackedVector3Array()
  if main == null:
    return {"aabbs": aabbs, "sample_points": sample_points}
  for bush in main.get_tree().get_nodes_in_group(&"food_plants"):
    for ch in bush.get_children():
      if ch is StaticBody2D:
        append_static_body_shapes(ch as StaticBody2D, aabbs, sample_points)
      elif ch is StaticBody3D:
        append_static_body_shapes_3d(ch as StaticBody3D, aabbs, sample_points)
  return {"aabbs": aabbs, "sample_points": sample_points}


static func merge_geometry_packs(a: Dictionary, b: Dictionary) -> Dictionary:
  var aabbs_out: Array = (a["aabbs"] as Array).duplicate(true)
  aabbs_out.append_array(b.get("aabbs", []) as Array)
  var sp_a: PackedVector3Array = (
    a.get("sample_points", PackedVector3Array()) as PackedVector3Array
  )
  var merged := sp_a.duplicate()
  var sp_b: PackedVector3Array = (
    b.get("sample_points", PackedVector3Array()) as PackedVector3Array
  )
  for i in range(sp_b.size()):
    merged.append(sp_b[i])
  return {"aabbs": aabbs_out, "sample_points": merged}


## Rocks + shrub footprints for motor repulsion/strategic cues.
static func collect_from_scene_tree(main: Node) -> Dictionary:
  var rocks := collect_obstacle_group_statics(main)
  var plants := collect_plant_blocker_statics(main)
  return merge_geometry_packs(rocks, plants)


## Drops obstacle samples farther than [param radius_px] from [param creature_center] ([code]<= 0[/code] keeps all).
static func filter_samples_by_radius(
  creature_center: Vector3, radius_px: float, samples: PackedVector3Array
) -> PackedVector3Array:
  if radius_px <= 0.0:
    return samples
  var r2 := radius_px * radius_px
  var out := PackedVector3Array()
  for i in range(samples.size()):
    var p := samples[i]
    if creature_center.distance_squared_to(p) <= r2:
      out.append(p)
  return out


## True when segment [param a]→[param b] crosses [param rect] (endpoints inside count as hit).
static func _segment_intersects_rect(a: Vector3, b: Vector3, rect: Rect2) -> bool:
  var a2 := _as_grid(a)
  var b2 := _as_grid(b)
  if rect.has_point(a2) or rect.has_point(b2):
    return true
  var mn := rect.position
  var mx := rect.position + rect.size
  var corners := [
    Vector2(mn.x, mn.y),
    Vector2(mx.x, mn.y),
    Vector2(mx.x, mx.y),
    Vector2(mn.x, mx.y),
  ]
  for i in range(corners.size()):
    var c0: Vector2 = corners[i]
    var c1: Vector2 = corners[(i + 1) % corners.size()]
    if Geometry2D.segment_intersects_segment(a2, b2, c0, c1) != null:
      return true
  return false


## True when the hunter→prey segment intersects a static AABB (bush / rock on the chase line).
## Params:
## - hunter_pos / prey_pos: Footprint centers in world space.
## - hunter_he / prey_he: Capsule half-extents used to pad obstacle rects.
## - static_obs: Motor AABB dicts with [code]position[/code] and [code]half_extents[/code].
## - min_clearance_px: Extra padding beyond footprint halves.
static func chase_segment_blocked_by_aabbs(
  hunter_pos: Vector3,
  hunter_he: Vector2,
  prey_pos: Vector3,
  prey_he: Vector2,
  static_obs: Array,
  min_clearance_px: float,
) -> bool:
  if prey_pos == Vector3.ZERO or static_obs.is_empty() or min_clearance_px <= 0.0:
    return false
  if hunter_pos.distance_squared_to(prey_pos) < 64.0:
    return false
  var pad := maxf(
    min_clearance_px,
    maxf(maxf(hunter_he.x, hunter_he.y), maxf(prey_he.x, prey_he.y)) * 0.35,
  )
  for ob in static_obs:
    if typeof(ob) != TYPE_DICTIONARY:
      continue
    var op: Vector3 = _read_pos_v3(ob.get("position", Vector3.ZERO))
    var ohe_raw: Variant = ob.get("half_extents", Vector2.ZERO)
    var ohe := Vector2.ZERO
    if typeof(ohe_raw) == TYPE_VECTOR2:
      ohe = ohe_raw as Vector2
    if ohe.x <= 0.0 or ohe.y <= 0.0:
      continue
    var inflated := ohe + Vector2(pad, pad)
    var op2 := _as_grid(op)
    var rect := Rect2(op2 - inflated, inflated * 2.0)
    if _segment_intersects_rect(hunter_pos, prey_pos, rect):
      return true
  return false
