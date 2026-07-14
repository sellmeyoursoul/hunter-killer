extends Node3D
## M1 production 3D main: grasslands playfield, ENGINE duel harness, HUD overlay ([CONVERT_TO_3D.md §6 M1](../../Project_Docs/Completed_Features/CONVERT_TO_3D.md)).

const _Brand := preload("res://product_brand.gd")
const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _HerbScene := preload("res://creature/templates/creature_herbivore_kinematic_3d.tscn")
const _CarnScene := preload("res://creature/templates/creature_carnivore_kinematic_3d.tscn")
const _RabbitArchetype := preload("res://creature/species/rabbit_archetype.tres")
const _FoxArchetype := preload("res://creature/species/fox_archetype.tres")
const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")
const _GroundSampler := preload("res://environment/playfield_ground_sampler.gd")
const _Perimeter := preload("res://environment/playfield_perimeter_boulders.gd")
const _TopDownCamera := preload("res://environment/top_down_camera_control.gd")

const _GRASSLANDS_SCENE := "res://assets/locations/grasslands/h-k-grasslands.blend"
const _BOULDER_SCENE := "res://assets/environment/obstacle_boulder/h-k-boulder1.blend"
const _SOLID_SHRUB_3D := "res://assets/plants/solid_shrub/solid_shrub_3d.tscn"
const _OPEN_SHRUB_3D := "res://assets/plants/open_shrub/open_shrub_3d.tscn"

const _FALLBACK_PLAYFIELD_SIZE := Vector2(40.0, 40.0)
const _TOP_DOWN_MARGIN := 1.12
const _SHOULDER_BACK := 2.4
const _SHOULDER_SIDE := 0.65
const _SHOULDER_HEIGHT := 1.55
const _SHOULDER_LOOK_AHEAD := 3.0
const _SHOULDER_LOOK_HEIGHT := 1.1
const _CAMERA_PAN_SPEED := 24.0
const _CAMERA_ZOOM_STEP := 0.12
const _CAMERA_ZOOM_MIN := 0.35
const _CAMERA_ZOOM_MAX := 3.0

enum CameraMode { TOP_DOWN, OVER_SHOULDER }

@export var environment_grid: Resource = null

var score: int = 0
var _camera_mode: CameraMode = CameraMode.TOP_DOWN
var _camera_pan_offset := Vector2.ZERO
var _camera_zoom_scale := 1.0
var _round_ended: bool = false
var _motor_playfield_size: Vector2 = Vector2.ZERO
var _playfield_bounds: Dictionary = {}
var _herbivore_root: Node3D
var _carnivore_root: Node3D
var _herb_body: CharacterBody3D
var _carn_body: CharacterBody3D
var _solid_shrub_scene: PackedScene
var _open_shrub_scene: PackedScene
var _boulder_scene: PackedScene
var _playfield_root: Node3D
var _obstacles_root: Node3D
var _food_root: Node3D
var _using_fallback_floor: bool = false
var _ground_sampler: PlayfieldGroundSampler
var _nav_region: NavigationRegion3D


func _ready() -> void:
  OLog.info(
    "%s 3D is starting — %s, %s" % [_Brand.GAME_TITLE, _Brand.AUTHOR, _Brand.COMPANY],
    false,
    "Main3D",
  )
  $HUD.ai_player_game.connect(_on_hud_ai_player_game)
  $HUD.end_ai_game.connect(_on_hud_end_ai_game)
  set_process_unhandled_input(true)
  _build_playfield()
  _ensure_environment_grid()
  _apply_top_down_camera()
  call_deferred("_attach_ai_driver")


func get_motor_playfield_size() -> Vector2:
  if _motor_playfield_size.x > 0.0 and _motor_playfield_size.y > 0.0:
    return _motor_playfield_size
  return _FALLBACK_PLAYFIELD_SIZE


func get_motor_playfield_bounds_min() -> Vector2:
  if bool(_playfield_bounds.get("valid", false)):
    return _playfield_bounds.get("min", Vector2.ZERO)
  return Vector2.ZERO


func get_motor_playfield_bounds_max() -> Vector2:
  if bool(_playfield_bounds.get("valid", false)):
    return _playfield_bounds.get("max", _FALLBACK_PLAYFIELD_SIZE)
  return _FALLBACK_PLAYFIELD_SIZE


func get_environment_grid() -> Resource:
  return environment_grid


func get_herbivore_motor_body() -> Node:
  return _herb_body


func get_herbivore_creature_root() -> Node3D:
  return _herbivore_root


func get_carnivore_creature_root() -> Node3D:
  return _carnivore_root


## Baked ground-elevation grid for rim spawn placement and terrain-aware motor (null when invalid).
func get_ground_sampler() -> PlayfieldGroundSampler:
  return _ground_sampler


func new_game() -> void:
  _round_ended = false
  $ScoreTimer.stop()
  $StartTimer.stop()
  _clear_creatures()
  var ad := _ai_driver()
  if ad != null:
    ad.clear_creature_registry()
  _reset_food_plants()
  _spawn_duel_pair()
  if ad != null:
    ad.register_creature_root(_herbivore_root)
    ad.register_creature_root(_carnivore_root)
    if _herbivore_root.has_method(&"configure_motor_stack"):
      _herbivore_root.call("configure_motor_stack")
    if _carnivore_root.has_method(&"configure_motor_stack"):
      _carnivore_root.call("configure_motor_stack")
    ad.sync_duel_control_modes()
    ad.set_duel_round_active(true)
    ad.set_primary_creature(_herb_body)
    ad.notify_main_new_game()
  if _herb_body != null and _herb_body.has_signal(&"hit") and not _herb_body.hit.is_connected(_on_player_hit):
    _herb_body.hit.connect(_on_player_hit)
  $StartTimer.start()
  $HUD.reset_vitals_display()
  $HUD.update_score(score)
  $HUD.show_message("Get Ready")
  $Music.play()


func end_round(outcome_tag: String, winner: String) -> void:
  if _round_ended:
    return
  _round_ended = true
  _log_round_outcome(outcome_tag, winner)
  game_over()


func game_over() -> void:
  _round_ended = true
  $ScoreTimer.stop()
  $HUD.show_game_over()
  $Music.stop()
  $DeathSound.play()
  var ad := _ai_driver()
  if ad != null:
    ad.set_duel_round_active(false)
    ad.notify_main_game_over()


func _process(delta: float) -> void:
  if _camera_mode == CameraMode.TOP_DOWN:
    _update_top_down_camera_input(delta)
  match _camera_mode:
    CameraMode.TOP_DOWN:
      _apply_top_down_camera()
    CameraMode.OVER_SHOULDER:
      if _herb_body == null or not is_instance_valid(_herb_body) or _herb_body.visible == false:
        return
      _apply_over_shoulder_camera()


func _unhandled_input(event: InputEvent) -> void:
  if _camera_mode != CameraMode.TOP_DOWN:
    return
  if event is InputEventMouseButton:
    var mb := event as InputEventMouseButton
    if not mb.pressed:
      return
    if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
      _camera_zoom_scale = _TopDownCamera.apply_zoom_step(
        _camera_zoom_scale,
        true,
        _CAMERA_ZOOM_STEP,
        _CAMERA_ZOOM_MIN,
        _CAMERA_ZOOM_MAX,
      )
      get_viewport().set_input_as_handled()
    elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
      _camera_zoom_scale = _TopDownCamera.apply_zoom_step(
        _camera_zoom_scale,
        false,
        _CAMERA_ZOOM_STEP,
        _CAMERA_ZOOM_MIN,
        _CAMERA_ZOOM_MAX,
      )
      get_viewport().set_input_as_handled()


func _update_top_down_camera_input(delta: float) -> void:
  var strengths := _TopDownCamera.strengths_from_actions(
    Input.get_action_strength("camera_pan_right"),
    Input.get_action_strength("camera_pan_left"),
    Input.get_action_strength("camera_pan_back"),
    Input.get_action_strength("camera_pan_forward"),
  )
  _camera_pan_offset += _TopDownCamera.pan_offset_delta(strengths, delta, _CAMERA_PAN_SPEED)


func _reset_top_down_camera_control() -> void:
  _camera_pan_offset = Vector2.ZERO
  _camera_zoom_scale = 1.0


func _playfield_look_target() -> Vector3:
  var center: Vector3 = _playfield_bounds.get("center", Vector3.ZERO)
  var surface_y := float(
    _playfield_bounds.get("surface_y", _playfield_bounds.get("floor_y", 0.0)),
  )
  return Vector3(center.x, surface_y, center.z)


func _apply_top_down_camera() -> void:
  var cam := $CameraRig/Camera3D as Camera3D
  var ground_focus := _playfield_look_target()
  ground_focus += Vector3(_camera_pan_offset.x, 0.0, _camera_pan_offset.y)
  var sz: Vector2 = _playfield_bounds.get("size", _FALLBACK_PLAYFIELD_SIZE)
  var aspect := get_viewport().get_visible_rect().size.aspect()
  var v_fov_rad := deg_to_rad(cam.fov)
  var h_fov_rad := 2.0 * atan(tan(v_fov_rad * 0.5) * aspect)
  var half_w := sz.x * 0.5 * _TOP_DOWN_MARGIN
  var half_h := sz.y * 0.5 * _TOP_DOWN_MARGIN
  var height := maxf(
    maxf(half_w / tan(h_fov_rad * 0.5), half_h / tan(v_fov_rad * 0.5)),
    8.0,
  )
  height *= _TopDownCamera.clamped_zoom_scale(
    _camera_zoom_scale,
    _CAMERA_ZOOM_MIN,
    _CAMERA_ZOOM_MAX,
  )
  $CameraRig.global_transform = Transform3D.IDENTITY
  cam.transform = Transform3D.IDENTITY
  cam.global_position = ground_focus + Vector3(0.0, height, 0.0)
  cam.look_at(ground_focus, Vector3.FORWARD)


func _apply_over_shoulder_camera() -> void:
  var cam := $CameraRig/Camera3D as Camera3D
  var target := _herb_body.global_position
  var facing: Vector3 = _herb_body.last_move_direction
  if facing.length_squared() < 1e-8:
    facing = Vector3(0.0, 0.0, -1.0)
  else:
    facing = facing.normalized()
  var right := facing.cross(Vector3.UP)
  if right.length_squared() < 1e-8:
    right = Vector3(1.0, 0.0, 0.0)
  else:
    right = right.normalized()
  $CameraRig.global_transform = Transform3D.IDENTITY
  cam.transform = Transform3D.IDENTITY
  cam.global_position = (
    target
    - facing * _SHOULDER_BACK
    + right * _SHOULDER_SIDE
    + Vector3(0.0, _SHOULDER_HEIGHT, 0.0)
  )
  var look_target := target + Vector3(0.0, _SHOULDER_LOOK_HEIGHT, 0.0) + facing * _SHOULDER_LOOK_AHEAD
  cam.look_at(look_target, Vector3.UP)


func _build_playfield() -> void:
  _playfield_root = get_node_or_null("PlayfieldRoot") as Node3D
  if _playfield_root == null:
    _playfield_root = Node3D.new()
    _playfield_root.name = "PlayfieldRoot"
    add_child(_playfield_root)
  _clear_children(_playfield_root)
  _mount_grasslands_floor()
  _recompute_playfield_bounds()
  _obstacles_root = Node3D.new()
  _obstacles_root.name = "Obstacles3D"
  _playfield_root.add_child(_obstacles_root)
  _spawn_perimeter_boulders()
  _spawn_interior_boulders()
  _ensure_food_plants()
  call_deferred("_snap_playfield_props_to_ground")
  call_deferred("_bake_ground_sampler")
  call_deferred("_bake_playfield_navmesh")
  _log_playfield_diagnostics()


func get_navigation_map_rid() -> RID:
  if _nav_region != null and is_instance_valid(_nav_region):
    return _nav_region.get_navigation_map()
  return RID()


func _duel_max_capsule_radius() -> float:
  var r := 0.35
  if _RabbitArchetype != null:
    r = maxf(r, float(_RabbitArchetype.collision_capsule_radius))
  if _FoxArchetype != null:
    r = maxf(r, float(_FoxArchetype.collision_capsule_radius))
  return r


func _bake_playfield_navmesh() -> void:
  if _playfield_root == null:
    return
  if _nav_region != null and is_instance_valid(_nav_region):
    _nav_region.queue_free()
  _nav_region = NavigationRegion3D.new()
  _nav_region.name = "PlayfieldNavRegion"
  _playfield_root.add_child(_nav_region)
  var nm := NavigationMesh.new()
  nm.agent_radius = _duel_max_capsule_radius()
  nm.agent_height = 2.0
  nm.cell_size = 0.25
  nm.cell_height = 0.15
  _nav_region.navigation_mesh = nm
  _nav_region.bake_navigation_mesh()


func _mount_grasslands_floor() -> void:
  _using_fallback_floor = false
  if ResourceLoader.exists(_GRASSLANDS_SCENE):
    var grass := load(_GRASSLANDS_SCENE) as PackedScene
    if grass != null:
      var inst := grass.instantiate() as Node3D
      if inst != null:
        _playfield_root.add_child(inst)
        _Bounds3D.ensure_world_static_layers(inst)
        if _Bounds3D.count_static_bodies(inst) == 0:
          var baked: int = _Bounds3D.supplement_trimesh_collision_from_meshes(inst, _playfield_root)
          if baked > 0:
            OLog.info(
              "Main3D: grasslands had no StaticBody3D — baked %d trimesh collider(s) on layer 1"
              % baked,
              false,
              "Main3D",
            )
          else:
            push_warning(
              "Main3D: grasslands import has no collision meshes — using fallback floor",
            )
            inst.queue_free()
            _mount_fallback_floor()
            return
        return
  _mount_fallback_floor()


func _mount_fallback_floor() -> void:
  _using_fallback_floor = true
  var floor_body := StaticBody3D.new()
  floor_body.name = "FallbackFloor"
  var box := BoxShape3D.new()
  box.size = Vector3(_FALLBACK_PLAYFIELD_SIZE.x, 0.2, _FALLBACK_PLAYFIELD_SIZE.y)
  var col := CollisionShape3D.new()
  col.shape = box
  floor_body.add_child(col)
  floor_body.position = Vector3(
    _FALLBACK_PLAYFIELD_SIZE.x * 0.5,
    -0.1,
    _FALLBACK_PLAYFIELD_SIZE.y * 0.5,
  )
  floor_body.collision_layer = 1
  floor_body.collision_mask = 1
  var mesh_inst := MeshInstance3D.new()
  mesh_inst.name = "FallbackFloorMesh"
  var plane := BoxMesh.new()
  plane.size = Vector3(_FALLBACK_PLAYFIELD_SIZE.x, 0.05, _FALLBACK_PLAYFIELD_SIZE.y)
  mesh_inst.mesh = plane
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.32, 0.52, 0.28)
  mesh_inst.material_override = mat
  mesh_inst.position = floor_body.position + Vector3(0.0, 0.1, 0.0)
  _playfield_root.add_child(mesh_inst)
  _playfield_root.add_child(floor_body)


func _recompute_playfield_bounds() -> void:
  _playfield_bounds = _Bounds3D.xz_bounds_from_playfield_root(_playfield_root)
  if bool(_playfield_bounds.get("valid", false)):
    _motor_playfield_size = _playfield_bounds.get("size", _FALLBACK_PLAYFIELD_SIZE)
  else:
    _motor_playfield_size = _FALLBACK_PLAYFIELD_SIZE
    _playfield_bounds = {
      "valid": true,
      "min": Vector2.ZERO,
      "max": _FALLBACK_PLAYFIELD_SIZE,
      "size": _FALLBACK_PLAYFIELD_SIZE,
      "center": Vector3(
        _FALLBACK_PLAYFIELD_SIZE.x * 0.5,
        0.0,
        _FALLBACK_PLAYFIELD_SIZE.y * 0.5,
      ),
      "floor_y": 0.0,
      "surface_y": 0.0,
    }
  _ground_sampler = null


func _ensure_ground_sampler_ready() -> void:
  if _ground_sampler != null and _ground_sampler.is_valid():
    return
  if not bool(_playfield_bounds.get("valid", false)):
    return
  var world_3d := get_world_3d()
  if world_3d == null:
    return
  _ground_sampler = _GroundSampler.bake_from_playfield(
    _playfield_bounds, world_3d.direct_space_state
  )


func _bake_ground_sampler() -> void:
  await get_tree().physics_frame
  if not bool(_playfield_bounds.get("valid", false)):
    _ground_sampler = null
    return
  var world_3d := get_world_3d()
  if world_3d == null:
    _ground_sampler = null
    return
  var space := world_3d.direct_space_state
  _ground_sampler = _GroundSampler.bake_from_playfield(_playfield_bounds, space)
  if _ground_sampler != null and _ground_sampler.is_valid():
    var center_xz: Vector2 = (
      _playfield_bounds.get("min", Vector2.ZERO)
      + _playfield_bounds.get("size", Vector2.ZERO) * 0.5
    )
    var center_elev: float = _ground_sampler.sample_elevation(center_xz)
    var fracs: Array = _ground_sampler.pick_duel_spawn_fractions()
    OLog.info(
      "Main3D: ground sampler baked — center_y=%.2f spawn_fracs=(%.2f,%.2f) (%.2f,%.2f)"
      % [
        center_elev,
        (fracs[0] as Vector2).x,
        (fracs[0] as Vector2).y,
        (fracs[1] as Vector2).x,
        (fracs[1] as Vector2).y,
      ],
      false,
      "Main3D",
    )


func _spawn_perimeter_boulders() -> void:
  if _boulder_scene == null:
    _boulder_scene = load(_BOULDER_SCENE) as PackedScene
  if _boulder_scene == null:
    return
  _Perimeter.place_along_perimeter(_obstacles_root, _playfield_bounds, _boulder_scene)


func _spawn_interior_boulders() -> void:
  if _boulder_scene == null:
    _boulder_scene = load(_BOULDER_SCENE) as PackedScene
  if _boulder_scene == null:
    return
  # Pass 5 / C1 interior obstacles — denser field for chase detour smoke.
  var fracs: Array[Vector2] = [
    Vector2(0.12, 0.18),
    Vector2(0.28, 0.72),
    Vector2(0.52, 0.22),
    Vector2(0.74, 0.58),
    Vector2(0.42, 0.48),
    Vector2(0.86, 0.34),
    Vector2(0.18, 0.42),
    Vector2(0.24, 0.46),
    Vector2(0.48, 0.66),
    Vector2(0.54, 0.70),
    Vector2(0.72, 0.28),
    Vector2(0.78, 0.32),
    Vector2(0.20, 0.26),
    Vector2(0.26, 0.20),
    Vector2(0.66, 0.76),
    Vector2(0.72, 0.80),
    Vector2(0.38, 0.34),
    Vector2(0.58, 0.44),
  ]
  for frac in fracs:
    var pos := _Bounds3D.world_position_from_fraction(_playfield_bounds, frac, 0.0)
    var rock := _boulder_scene.instantiate() as Node3D
    if rock == null:
      continue
    _obstacles_root.add_child(rock)
    rock.global_position = pos
    rock.add_to_group(&"obstacles")
    PlayfieldBounds3D.ensure_obstacle_physics(rock)


func _ensure_world_static_collision(root: Node) -> void:
  _Bounds3D.ensure_world_static_layers(root)


func _snap_playfield_props_to_ground() -> void:
  await get_tree().physics_frame
  var hint_y := float(_playfield_bounds.get("floor_y", 0.0))
  var space := get_world_3d().direct_space_state if get_world_3d() != null else null
  if space == null:
    return
  for prop_root in [_obstacles_root, _food_root]:
    if prop_root == null or not is_instance_valid(prop_root):
      continue
    var sibling_exclude := _prop_collision_rids_under(prop_root)
    for ch in prop_root.get_children():
      if ch is Node3D:
        var prop := ch as Node3D
        var xz := Vector2(prop.global_position.x, prop.global_position.z)
        var skip := sibling_exclude.duplicate()
        for rid in _prop_collision_rids_under(prop):
          if not skip.has(rid):
            skip.append(rid)
        var ground := _raycast_prop_ground_surface(space, xz, hint_y, skip)
        if not bool(ground.get("hit", false)):
          OLog.info(
            "Main3D: no ground hit for prop %s at (%.1f, %.1f) — left at Y estimate"
            % [prop.name, xz.x, xz.y],
            true,
            "Main3D",
          )
          continue
        var surface_y := float(ground.get("surface_y", hint_y))
        var bottom_y := _prop_mesh_local_bottom_y(prop)
        prop.global_position = Vector3(xz.x, surface_y - bottom_y, xz.y)


func _prop_collision_rids_under(root: Node) -> Array:
  var rids: Array = []
  _prop_collision_rids_under_recursive(root, rids)
  return rids


func _prop_collision_rids_under_recursive(node: Node, rids: Array) -> void:
  if node is CollisionObject3D:
    rids.append((node as CollisionObject3D).get_rid())
  for ch in node.get_children():
    _prop_collision_rids_under_recursive(ch, rids)


func _raycast_prop_ground_surface(
  space: PhysicsDirectSpaceState3D,
  xz: Vector2,
  hint_y: float,
  exclude_rids: Array,
) -> Dictionary:
  if space == null:
    return {"hit": false, "surface_y": hint_y}
  var mask := _Bounds3D.WORLD_STATIC_COLLISION_MASK
  var x := xz.x
  var z := xz.y
  var down_from := Vector3(x, hint_y + _Bounds3D.GROUND_RAY_HEIGHT, z)
  var down_to := Vector3(x, hint_y - _Bounds3D.GROUND_RAY_DEPTH, z)
  var query := PhysicsRayQueryParameters3D.create(down_from, down_to)
  query.collision_mask = mask
  query.hit_from_inside = true
  if not exclude_rids.is_empty():
    query.exclude = exclude_rids
  var hit: Dictionary = space.intersect_ray(query)
  if not hit.is_empty():
    return {"hit": true, "surface_y": float((hit.get("position", Vector3.ZERO) as Vector3).y)}
  var up_from := Vector3(x, hint_y - 10.0, z)
  var up_to := Vector3(x, hint_y + _Bounds3D.GROUND_RAY_HEIGHT, z)
  query = PhysicsRayQueryParameters3D.create(up_from, up_to)
  query.collision_mask = mask
  if not exclude_rids.is_empty():
    query.exclude = exclude_rids
  hit = space.intersect_ray(query)
  if not hit.is_empty():
    return {"hit": true, "surface_y": float((hit.get("position", Vector3.ZERO) as Vector3).y)}
  return {"hit": false, "surface_y": hint_y}


func _prop_mesh_local_bottom_y(prop_root: Node3D) -> float:
  var acc: Array = [INF]
  _accum_prop_mesh_bottom_in_root_space(prop_root, prop_root, acc)
  var min_y: float = acc[0]
  return 0.0 if min_y == INF else min_y


func _accum_prop_mesh_bottom_in_root_space(prop_root: Node3D, node: Node, acc: Array) -> void:
  if node is MeshInstance3D:
    var mi := node as MeshInstance3D
    var mesh: Mesh = mi.mesh
    if mesh != null:
      var local_aabb := mesh.get_aabb()
      var root_inv := prop_root.global_transform.affine_inverse()
      var size := local_aabb.size
      for ox in [0.0, size.x]:
        for oy in [0.0, size.y]:
          for oz in [0.0, size.z]:
            var mesh_point: Vector3 = local_aabb.position + Vector3(ox, oy, oz)
            var in_root: Vector3 = root_inv * (mi.global_transform * mesh_point)
            acc[0] = minf(float(acc[0]), in_root.y)
  for ch in node.get_children():
    _accum_prop_mesh_bottom_in_root_space(prop_root, ch, acc)


func _ensure_food_plants() -> void:
  if _food_root != null and is_instance_valid(_food_root):
    return
  if _solid_shrub_scene == null:
    _solid_shrub_scene = load(_SOLID_SHRUB_3D) as PackedScene
  if _open_shrub_scene == null:
    _open_shrub_scene = load(_OPEN_SHRUB_3D) as PackedScene
  _food_root = Node3D.new()
  _food_root.name = "FoodPlants"
  add_child(_food_root)
  var solid_fracs: Array[Vector2] = [
    Vector2(0.328, 0.495),
    Vector2(0.677, 0.171),
    Vector2(0.370, 0.743),
  ]
  var open_fracs: Array[Vector2] = [
    Vector2(0.238, 0.648),
    Vector2(0.661, 0.810),
  ]
  for frac in solid_fracs:
    if _solid_shrub_scene == null:
      break
    var s: Node3D = _solid_shrub_scene.instantiate() as Node3D
    if not _validate_food_plant_kind_id(s):
      s.queue_free()
      continue
    _food_root.add_child(s)
    s.global_position = _Bounds3D.world_position_from_fraction(_playfield_bounds, frac, 0.0)
  for frac in open_fracs:
    if _open_shrub_scene == null:
      break
    var o: Node3D = _open_shrub_scene.instantiate() as Node3D
    if not _validate_food_plant_kind_id(o):
      o.queue_free()
      continue
    _food_root.add_child(o)
    o.global_position = _Bounds3D.world_position_from_fraction(_playfield_bounds, frac, 0.0)


func _validate_food_plant_kind_id(plant: Node) -> bool:
  var kind_v: Variant = plant.get("stimulus_kind_id")
  var kind_id := &""
  if typeof(kind_v) == TYPE_STRING_NAME:
    kind_id = kind_v as StringName
  elif typeof(kind_v) == TYPE_STRING and not str(kind_v).strip_edges().is_empty():
    kind_id = StringName(str(kind_v).strip_edges())
  if kind_id == &"":
    OLog.error("Food plant spawn blocked — missing stimulus_kind_id on %s" % plant.name, false, "Main3D")
    return false
  return true


func _reset_food_plants() -> void:
  if _food_root == null:
    return
  for c in _food_root.get_children():
    if c.has_method(&"reset_session"):
      c.call(&"reset_session")


func _spawn_duel_pair() -> void:
  _ensure_ground_sampler_ready()
  var herb_frac := Vector2(0.50, 0.50)
  var carn_frac := Vector2(0.18, 0.50)
  if _ground_sampler != null and _ground_sampler.is_valid():
    var spawn_fracs: Array = _ground_sampler.pick_duel_spawn_fractions()
    if spawn_fracs.size() >= 2:
      herb_frac = spawn_fracs[0] as Vector2
      carn_frac = spawn_fracs[1] as Vector2
  var hpos := _spawn_position("HerbivoreSpawn", herb_frac)
  var cpos := _spawn_position("CarnivoreSpawn", carn_frac)
  var hint_y := float(_playfield_bounds.get("floor_y", 0.0))
  if _ground_sampler != null and _ground_sampler.is_valid():
    OLog.info(
      "Main3D duel spawn: herb_frac=(%.2f,%.2f) carn_frac=(%.2f,%.2f) herb_elev=%.2f carn_elev=%.2f"
      % [
        herb_frac.x,
        herb_frac.y,
        carn_frac.x,
        carn_frac.y,
        _ground_sampler.sample_elevation(Vector2(hpos.x, hpos.z), hint_y),
        _ground_sampler.sample_elevation(Vector2(cpos.x, cpos.z), hint_y),
      ],
      false,
      "Main3D",
    )
  _herbivore_root = _HerbScene.instantiate() as Node3D
  _herbivore_root.set("definition", _RabbitArchetype)
  add_child(_herbivore_root)
  _herb_body = _herbivore_root.get_node("Body") as CharacterBody3D
  _setup_motor_body(_herb_body, [&"player", &"prey", &"herbivores", &"creatures"])
  _snap_creature_to_ground(_herbivore_root, _herb_body, hpos, "herbivore")
  _carnivore_root = _CarnScene.instantiate() as Node3D
  _carnivore_root.set("definition", _FoxArchetype)
  add_child(_carnivore_root)
  _carn_body = _carnivore_root.get_node("Body") as CharacterBody3D
  _setup_motor_body(_carn_body, [&"mobs", &"creatures"])
  _snap_creature_to_ground(_carnivore_root, _carn_body, cpos, "carnivore")
  if _herb_body.has_method(&"start_duel_spawn"):
    _herb_body.call(&"start_duel_spawn")
  if _carn_body.has_method(&"start_duel_spawn"):
    _carn_body.call(&"start_duel_spawn")
  call_deferred("_settle_spawned_creature_bodies")


func _setup_motor_body(body: CharacterBody3D, groups: Array[StringName]) -> void:
  for g in groups:
    body.add_to_group(g)
  body.screen_size = get_motor_playfield_size()
  body.playfield_bounds_min = get_motor_playfield_bounds_min()
  body.playfield_bounds_max = get_motor_playfield_bounds_max()
  body.set_control_mode(_ControlMode.engine_as_int())


func _spawn_position(marker_name: String, fallback_frac: Vector2) -> Vector3:
  var m := get_node_or_null(marker_name)
  if m is Node3D and (m as Node3D).position.length_squared() > 1e-6:
    return (m as Node3D).global_position
  return _Bounds3D.world_position_from_fraction(_playfield_bounds, fallback_frac, 0.0)


func _snap_creature_to_ground(
  creature_root: Node3D,
  body: CharacterBody3D,
  xz_pos: Vector3,
  role: String,
) -> void:
  var hint_y := float(_playfield_bounds.get("floor_y", 0.0))
  var xz := Vector2(xz_pos.x, xz_pos.z)
  var space := get_world_3d().direct_space_state if get_world_3d() != null else null
  var ground_hit: bool = _Bounds3D.snap_creature_root_to_ground(creature_root, body, xz, hint_y, space)
  if not ground_hit:
    creature_root.global_position = Vector3(
      xz.x,
      _Bounds3D.root_global_y_for_surface(body, hint_y),
      xz.y,
    )
    OLog.info(
      "Main3D: no ground raycast hit for %s at (%.1f, %.1f) — using floor_y fallback"
      % [role, xz.x, xz.y],
      true,
      "Main3D",
    )
  if space != null and creature_root is Node3D:
    PlayfieldBounds3D.settle_creature_spawn_on_floor(creature_root, body, space, hint_y)
  else:
    _Bounds3D.settle_character_body_on_floor(body)


func _settle_spawned_creature_bodies() -> void:
  await get_tree().physics_frame
  var hint_y := float(_playfield_bounds.get("floor_y", 0.0))
  var space := get_world_3d().direct_space_state if get_world_3d() != null else null
  for body in [_herb_body, _carn_body]:
    if body == null or not is_instance_valid(body):
      continue
    var creature_root: Node = body.get_parent()
    if space != null and creature_root is Node3D:
      PlayfieldBounds3D.settle_creature_spawn_on_floor(creature_root as Node3D, body, space, hint_y)
    else:
      _Bounds3D.settle_character_body_on_floor(body)
  await get_tree().physics_frame
  if space != null:
    for body in [_herb_body, _carn_body]:
      if body == null or not is_instance_valid(body):
        continue
      if body.is_on_floor():
        continue
      var creature_root_retry: Node = body.get_parent()
      if creature_root_retry is Node3D:
        PlayfieldBounds3D.settle_creature_spawn_on_floor(creature_root_retry as Node3D, body, space, hint_y)
  call_deferred("_log_spawn_floor_contact")


func _log_playfield_diagnostics() -> void:
  var floor_kind := "fallback" if _using_fallback_floor else "grasslands"
  var child_count := _playfield_root.get_child_count() if _playfield_root != null else 0
  var mn: Vector2 = _playfield_bounds.get("min", Vector2.ZERO)
  var mx: Vector2 = _playfield_bounds.get("max", Vector2.ZERO)
  var sz: Vector2 = _playfield_bounds.get("size", Vector2.ZERO)
  var center: Vector3 = _playfield_bounds.get("center", Vector3.ZERO)
  var floor_y := float(_playfield_bounds.get("floor_y", 0.0))
  OLog.info(
    "Main3D playfield: floor=%s children=%d valid=%s size=(%.1f, %.1f) min=(%.1f, %.1f) max=(%.1f, %.1f) center=(%.1f, %.1f, %.1f) floor_y=%.2f"
    % [
      floor_kind,
      child_count,
      str(_playfield_bounds.get("valid", false)),
      sz.x,
      sz.y,
      mn.x,
      mn.y,
      mx.x,
      mx.y,
      center.x,
      center.y,
      center.z,
      floor_y,
    ],
    false,
    "Main3D",
  )


func _log_spawn_floor_contact() -> void:
  await get_tree().physics_frame
  for body in [_herb_body, _carn_body]:
    if body == null or not is_instance_valid(body):
      continue
    var on_floor: bool = body.is_on_floor()
    var pos: Vector3 = body.global_position
    OLog.info(
      "Main3D spawn: %s pos=(%.2f, %.2f, %.2f) is_on_floor=%s"
      % [body.name, pos.x, pos.y, pos.z, str(on_floor)],
      true,
      "Main3D",
    )
    if not on_floor:
      push_warning(
        "Main3D: %s not on floor after spawn — check playfield collision layer 1 (world_static)"
        % body.name
      )


func _clear_creatures() -> void:
  if _herbivore_root != null and is_instance_valid(_herbivore_root):
    _herbivore_root.queue_free()
  if _carnivore_root != null and is_instance_valid(_carnivore_root):
    _carnivore_root.queue_free()
  _herbivore_root = null
  _carnivore_root = null
  _herb_body = null
  _carn_body = null


func _clear_children(node: Node) -> void:
  for ch in node.get_children():
    ch.queue_free()


func _attach_ai_driver() -> void:
  var ad := _ai_driver()
  if ad == null or not ad.has_method(&"attach_main"):
    push_error("Main3D: AiDriver autoload missing — fix ai_driver.gd compile errors.")
    return
  ad.attach_main(self)
  ad.ai_session_state_changed.connect(_on_ai_session_state_changed)
  $HUD.set_ai_session_state(ad.get_state())


func _ai_driver() -> Node:
  return get_node_or_null("/root/AiDriver")


func _ensure_environment_grid() -> void:
  if environment_grid != null and environment_grid is EnvironmentGridBaked:
    var g := environment_grid as EnvironmentGridBaked
    if g.is_valid_shape():
      return
  environment_grid = _create_default_open_grid()


func _create_default_open_grid() -> Resource:
  var sz := get_motor_playfield_size()
  var cell_world := 4.0
  var cw := maxi(1, ceili(sz.x / cell_world))
  var ch := maxi(1, ceili(sz.y / cell_world))
  var open := EnvironmentCellData.new()
  open.passible = true
  open.movement_impact = 0.0
  open.fit_size = -1.0
  var grid := EnvironmentGridBaked.new()
  grid.cell_width = cw
  grid.cell_height = ch
  grid.cell_size = cell_world
  grid.origin_world = Vector2.ZERO
  grid.kind_presets = [open]
  var ids := PackedInt32Array()
  ids.resize(cw * ch)
  ids.fill(0)
  grid.cell_kind_ids = ids
  return grid


func _log_round_outcome(outcome_tag: String, winner: String) -> void:
  var herb_cal := -1
  var carn_cal := -1
  if _herb_body != null and is_instance_valid(_herb_body):
    herb_cal = int(round(float(_herb_body.current_calories)))
  if _carn_body != null and is_instance_valid(_carn_body):
    carn_cal = int(round(float(_carn_body.current_calories)))
  OLog.info(
    "CREATURE_GOALS round: winner=%s cause=%s herb_cal=%d carn_cal=%d"
    % [winner, outcome_tag, herb_cal, carn_cal],
    false,
    "Main3D",
  )


func _on_score_timer_timeout() -> void:
  score += 1
  $HUD.update_score(score)


func _on_start_timer_timeout() -> void:
  $ScoreTimer.start()


func _on_player_hit() -> void:
  var prey_cal := 0
  if _herb_body != null:
    prey_cal = int(round(float(_herb_body.current_calories)))
  $HUD.set_carnivore_score_display(prey_cal)
  var tag := "predation_carn_win"
  if _herb_body != null and _herb_body.has_method(&"was_defeated_by_starvation"):
    if _herb_body.call(&"was_defeated_by_starvation"):
      tag = "starvation_herb"
  end_round(tag, "carnivore")


func _on_hud_start_game() -> void:
  _reset_top_down_camera_control()
  _camera_mode = CameraMode.OVER_SHOULDER
  new_game()
  if _herb_body != null and _herb_body.has_method(&"set_control_mode"):
    _herb_body.set_control_mode(_ControlMode.human_as_int())


func _on_hud_ai_player_game() -> void:
  $HUD/AIPlayerButton.disabled = true
  $HUD.show_message("Starting CPU player…")
  var ad := _ai_driver()
  var ok: bool = ad.begin_engine_player_round() if ad != null else false
  $HUD/AIPlayerButton.disabled = false
  $HUD.dismiss_message()
  if not ok:
    $HUD.show_message("Could not start CPU player. See logs.")
    $HUD.set_ai_session_state(0)
    return
  _reset_top_down_camera_control()
  _camera_mode = CameraMode.TOP_DOWN
  new_game()


func _on_hud_end_ai_game() -> void:
  var ad := _ai_driver()
  if ad != null and ad.get_state() == 1:
    ad.cancel_armed_session()
    return
  end_round("end_ai", "none")


func _on_ai_session_state_changed(state: int) -> void:
  $HUD.set_ai_session_state(state)
