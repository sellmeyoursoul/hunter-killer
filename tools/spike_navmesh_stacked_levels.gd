extends SceneTree
## Q13 spike (NAVIGATION_PASSABILITY_PLAN.md): which navmesh level does NavigationServer3D pick when a
## query touches stacked levels? Read-only against the engine; no production code is touched.
## Run: godot --path . --headless -s res://tools/spike_navmesh_stacked_levels.gd
##
## Fixture: ground top at y = 0 (40 x 40 m) and a deck top at y = DECK_Y over x 10..30, z 10..30
## (overlaps the ground in XZ). Two layouts are measured:
##   "two_regions" - one NavigationRegion3D per level (each baked on its own), same map.
##   "one_region"  - a single region baked from both colliders (Recast multi-level spans).
## Each layout is queried without and with a NavigationLink3D joining the levels.

const DECK_Y := 4.0
const GROUND_TOP := 0.0
const PROBE_XZ := Vector2(20.0, 20.0)  # under the deck centre: both levels exist in this column
const OUTSIDE_XZ := Vector2(5.0, 20.0)  # ground only (outside the deck footprint)
const LINK_LOW := Vector3(8.0, 0.0, 20.0)
const LINK_HIGH := Vector3(11.0, DECK_Y, 20.0)


func _initialize() -> void:
  _run()


func _run() -> void:
  await process_frame
  await physics_frame
  for layout in ["two_regions", "one_region"]:
    for with_link in [false, true]:
      await _measure(layout, with_link)
  quit(0)


## Builds the fixture for [param layout], waits for the map sync, prints all measurements, frees it.
func _measure(layout: String, with_link: bool) -> void:
  print("")
  print("=== layout=%s link=%s ===" % [layout, with_link])
  var root := Node3D.new()
  get_root().add_child(root)
  var regions: Array[NavigationRegion3D] = []
  if layout == "two_regions":
    regions.append(_make_region(root, [_box(Vector3(20, -0.1, 20), Vector3(40, 0.2, 40))]))
    regions.append(_make_region(root, [_box(Vector3(20, DECK_Y - 0.1, 20), Vector3(20, 0.2, 20))]))
  else:
    regions.append(
      _make_region(
        root,
        [
          _box(Vector3(20, -0.1, 20), Vector3(40, 0.2, 40)),
          _box(Vector3(20, DECK_Y - 0.1, 20), Vector3(20, 0.2, 20)),
        ],
      ),
    )
  if with_link:
    var link := NavigationLink3D.new()
    link.bidirectional = true
    link.start_position = LINK_LOW
    link.end_position = LINK_HIGH
    root.add_child(link)
  var map := get_root().get_world_3d().navigation_map
  for r in regions:
    print("region polys=%d" % r.navigation_mesh.get_polygon_count())
    NavigationServer3D.region_set_navigation_mesh(r.get_rid(), r.navigation_mesh)
  var ready := false
  for i in 60:
    await physics_frame
    if NavigationServer3D.map_get_closest_point(map, Vector3(OUTSIDE_XZ.x, 0.0, OUTSIDE_XZ.y)) != Vector3.ZERO:
      ready = true
      break
  print("map ready=%s" % ready)
  for i in 5:
    await physics_frame

  print("-- map_get_closest_point at column under deck (x=%.0f z=%.0f) --" % [PROBE_XZ.x, PROBE_XZ.y])
  for y in [-50.0, -1.0, 0.0, 0.5, 1.0, 2.0, 2.01, 2.5, 3.0, 3.9, 4.0, 4.5, 6.0, 10.0, 60.0]:
    var q := Vector3(PROBE_XZ.x, y, PROBE_XZ.y)
    _print_point("closest_point", q, NavigationServer3D.map_get_closest_point(map, q))

  print("-- map_get_closest_point_to_segment (query_origin style, +1 / -60) --")
  for y in [0.0, 2.0, 3.0, 4.0, 4.5, 10.0]:
    var from := Vector3(PROBE_XZ.x, y + 1.0, PROBE_XZ.y)
    var to := Vector3(PROBE_XZ.x, y - 60.0, PROBE_XZ.y)
    var hit := NavigationServer3D.map_get_closest_point_to_segment(map, from, to, false)
    _print_point("segment body_y=%.2f" % y, from, hit)

  print("-- map_get_closest_point_owner (region identity) --")
  for y in [0.0, 2.0, 4.0, 10.0]:
    var q := Vector3(PROBE_XZ.x, y, PROBE_XZ.y)
    var owner_rid := NavigationServer3D.map_get_closest_point_owner(map, q)
    var idx := -1
    for i in regions.size():
      if regions[i].get_rid() == owner_rid:
        idx = i
    print("owner query_y=%.2f -> region_index=%d" % [y, idx])

  print("-- determinism (same query x20) --")
  var q0 := Vector3(PROBE_XZ.x, 2.0, PROBE_XZ.y)
  var distinct := {}
  for i in 20:
    distinct[str(NavigationServer3D.map_get_closest_point(map, q0))] = true
  print("distinct results for y=2.0: %d %s" % [distinct.size(), str(distinct.keys())])

  print("-- map_get_closest_point outside deck footprint (x=%.0f) --" % OUTSIDE_XZ.x)
  for y in [0.0, 2.0, 4.0, 10.0]:
    var q := Vector3(OUTSIDE_XZ.x, y, OUTSIDE_XZ.y)
    _print_point("closest_point", q, NavigationServer3D.map_get_closest_point(map, q))

  print("-- map_get_path (optimize=true) --")
  var low_a := Vector3(5, 0, 20)
  var low_under := Vector3(20, 0, 20)
  var high_a := Vector3(20, DECK_Y, 20)
  _print_path(map, "low(5,0,20)->high(20,4,20)", low_a, high_a)
  _print_path(map, "high(20,4,20)->low(5,0,20)", high_a, low_a)
  _print_path(map, "low(5,0,20)->under-deck low(20,0,20)", low_a, low_under)
  _print_path(map, "high(20,4,20)->under-deck low(20,0,20)", high_a, low_under)
  # Endpoint snapping with off-mesh query heights (no level given by the caller).
  _print_path(map, "low(5,0,20)->motor-plane(20,0,20) [y=0 on deck column]", low_a, Vector3(20, 0, 20))
  _print_path(map, "low(5,0,20)->mid-air(20,2,20)", low_a, Vector3(20, 2, 20))
  _print_path(map, "low(5,0,20)->above(20,10,20)", low_a, Vector3(20, 10, 20))
  _print_path(map, "mid-air(20,2,20)->low(5,0,20)", Vector3(20, 2, 20), low_a)
  _print_path(map, "above(20,10,20)->low(5,0,20)", Vector3(20, 10, 20), low_a)

  root.queue_free()
  for i in 3:
    await physics_frame


func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
  var body := StaticBody3D.new()
  body.collision_layer = 1
  var shape := BoxShape3D.new()
  shape.size = size
  var col := CollisionShape3D.new()
  col.shape = shape
  body.add_child(col)
  body.position = pos
  return body


## Region whose children are [param bodies]; baked synchronously (as tests/motor_path_fixture.gd does).
func _make_region(parent: Node, bodies: Array) -> NavigationRegion3D:
  var region := NavigationRegion3D.new()
  parent.add_child(region)
  for b in bodies:
    region.add_child(b)
  var nm := NavigationMesh.new()
  nm.agent_radius = 0.25
  nm.agent_height = 2.0
  nm.cell_size = 0.25
  nm.cell_height = 0.25
  nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
  nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
  nm.geometry_collision_mask = 1
  region.navigation_mesh = nm
  region.bake_navigation_mesh(false)
  return region


func _level_of(p: Vector3) -> String:
  if p == Vector3.ZERO:
    return "EMPTY/ZERO"
  return "UPPER" if p.y > DECK_Y * 0.5 else "LOWER"


func _print_point(label: String, q: Vector3, hit: Vector3) -> void:
  print("%s query=%s -> %s level=%s" % [label, str(q), str(hit), _level_of(hit)])


func _print_path(map: RID, label: String, from: Vector3, to: Vector3) -> void:
  var path := NavigationServer3D.map_get_path(map, from, to, true)
  if path.is_empty():
    print("path %s: EMPTY" % label)
    return
  var ys := PackedStringArray()
  var length := 0.0
  for i in path.size():
    ys.append("%s/%s" % [str(snappedf(path[i].y, 0.01)), _level_of(path[i]).left(1)])
    if i > 0:
      length += path[i - 1].distance_to(path[i])
  print(
    "path %s: n=%d len=%.2f start=%s end=%s ys=%s"
    % [label, path.size(), length, str(path[0]), str(path[path.size() - 1]), ", ".join(ys)],
  )
