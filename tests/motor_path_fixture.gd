extends RefCounted
class_name MotorPathFixture
## Headless navmesh + floor fixture for V3 planner tests ([CREATURE_MOVEMENT_V3.md §3](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _FLOOR_SIZE := Vector2(40.0, 40.0)


## Open floor with baked navmesh — returns [code]{ root, map_rid, space_state, teardown }[/code].
static func build_open(parent: Node) -> Dictionary:
  return _build(parent, false)


## Floor plus center wall for backtrack / detour slices.
static func build_blocked(parent: Node) -> Dictionary:
  return _build(parent, true)


## P→R corridor pinch for carnivore live-prey pursuit detour smoke (C1).
static func build_pursuit_pinch(parent: Node) -> Dictionary:
  return _build(parent, false, true)


static func _build(parent: Node, with_wall: bool, pursuit_pinch: bool = false) -> Dictionary:
  var root := Node3D.new()
  root.name = "MotorPathFixture"
  parent.add_child(root)
  # Nav region is the geometry-source root: floor/wall live under it so the baker
  # (SOURCE_GEOMETRY_ROOT_NODE_CHILDREN) can find the static colliders.
  var nav_region := NavigationRegion3D.new()
  nav_region.name = "NavRegion"
  root.add_child(nav_region)
  var floor_body := StaticBody3D.new()
  floor_body.name = "Floor"
  floor_body.collision_layer = 1
  var floor_shape := BoxShape3D.new()
  floor_shape.size = Vector3(_FLOOR_SIZE.x, 0.2, _FLOOR_SIZE.y)
  var floor_col := CollisionShape3D.new()
  floor_col.shape = floor_shape
  floor_body.add_child(floor_col)
  floor_body.position = Vector3(_FLOOR_SIZE.x * 0.5, -0.1, _FLOOR_SIZE.y * 0.5)
  nav_region.add_child(floor_body)
  if with_wall:
    var wall := StaticBody3D.new()
    wall.name = "CenterWall"
    wall.collision_layer = 1
    var wall_shape := BoxShape3D.new()
    wall_shape.size = Vector3(0.4, 2.0, 8.0)
    var wall_col := CollisionShape3D.new()
    wall_col.shape = wall_shape
    wall.add_child(wall_col)
    wall.position = Vector3(_FLOOR_SIZE.x * 0.5, 1.0, _FLOOR_SIZE.y * 0.5)
    nav_region.add_child(wall)
  elif pursuit_pinch:
    var pinch := StaticBody3D.new()
    pinch.name = "PursuitPinchWall"
    pinch.collision_layer = 1
    var pinch_shape := BoxShape3D.new()
    pinch_shape.size = Vector3(0.4, 2.0, 6.0)
    var pinch_col := CollisionShape3D.new()
    pinch_col.shape = pinch_shape
    pinch.add_child(pinch_col)
    pinch.position = Vector3(_FLOOR_SIZE.x * 0.5, 1.0, _FLOOR_SIZE.y * 0.5)
    nav_region.add_child(pinch)
  var nm := NavigationMesh.new()
  nm.agent_radius = 0.25
  nm.agent_height = 2.0
  nm.cell_size = 0.25
  # Match the map's default cell height to avoid rasterization mismatch warnings/errors
  # that can suppress path results in headless mode.
  nm.cell_height = 0.25
  # The fixture floor/wall are StaticBody3D collision shapes (no MeshInstance3D), so the
  # baker must parse static colliders — the default parses only visual meshes and would
  # find no source geometry, yielding an empty navmesh.
  nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
  nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
  nm.geometry_collision_mask = 1
  nav_region.navigation_mesh = nm
  nav_region.bake_navigation_mesh()
  var map_rid := nav_region.get_navigation_map()
  # Ensure the map is active and its cell height matches the region so the server sync
  # commits a queryable navigation map in headless runs.
  NavigationServer3D.map_set_active(map_rid, true)
  NavigationServer3D.map_set_cell_height(map_rid, 0.25)
  var space := root.get_world_3d().direct_space_state if root.is_inside_tree() else null
  return {
    "root": root,
    "map_rid": map_rid,
    "space_state": space,
    "teardown": Callable(root, &"queue_free"),
  }


## Asserts nav path exists between two fixture points (call after [code]await process_frame[/code]).
static func assert_nav_path_ready(map_rid: RID, from: Vector3, to: Vector3) -> bool:
  if not map_rid.is_valid():
    return false
  var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, from, to, true)
  return path.size() >= 2
