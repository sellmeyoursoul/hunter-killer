extends Node3D
## Debug scene: shows rabbit, fox and wolf mounted exactly as the game mounts them, each heading
## world -Z (the game's current forward), so a human can confirm which way each model's nose points.
## Run: open res://tools/facing_check_3d.tscn and press F6 ("Run Current Scene").
## Mount path reused: archetype body_scene -> CreatureRoot3D deferred _mount_visual_from_definition
## (species mesh file / wolf 3x wrapper / capsule fit) -> CreatureKinematicBody3D._sync_visual_facing
## (yaw_from_horizontal_dir(last_move_direction) + template visual_yaw_offset_rad).
## No archetype .tres exists for the fox, so it is a duplicate of the wolf archetype with fox
## species_id / pack root (carnivore template, same as the game would use).
## Camera keys: 1 = front 3/4 view, 2 = side view (from -X), 3 = top-down, 4/5/6 = rabbit/fox/wolf close-up.
## Run with F6 (Run Current Scene); F5 runs the project's main scene instead.

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _HEADING := Vector3(0.0, 0.0, -1.0)
const _CONE_HALF_ANGLE := deg_to_rad(40.0)

var _entries: Array[Dictionary] = []
var _camera: Camera3D
var _report: Label


## Builds ground, axes, camera, HUD and spawns the three creatures.
func _ready() -> void:
  _build_environment()
  _build_ground()
  _build_axes()
  _build_hud()
  var rabbit := load("res://creature/species/rabbit_archetype.tres") as CreatureDefinition
  var wolf := load("res://creature/species/wolf_archetype.tres") as CreatureDefinition
  var fox: CreatureDefinition = wolf.duplicate() as CreatureDefinition
  fox.species_id = &"fox"
  fox.display_name = "Fox"
  fox.asset_pack_root = "res://assets/creatures/fox"
  fox.creature_size = 3.0
  _spawn(rabbit, Vector3(-45.0, 0.0, 0.0))
  _spawn(fox, Vector3(0.0, 0.0, 0.0))
  _spawn(wolf, Vector3(55.0, 0.0, 0.0))
  _set_camera_view(1)
  ## Mount is deferred inside CreatureRoot3D; wait, then face and annotate.
  await get_tree().process_frame
  await get_tree().process_frame
  await get_tree().process_frame
  _finalize_creatures()


## Camera presets: 1 front 3/4, 2 side, 3 top-down.
func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed and not event.echo:
    match (event as InputEventKey).keycode:
      KEY_1:
        _set_camera_view(1)
      KEY_2:
        _set_camera_view(2)
      KEY_3:
        _set_camera_view(3)
      KEY_4:
        _set_camera_view(4)
      KEY_5:
        _set_camera_view(5)
      KEY_6:
        _set_camera_view(6)


## Instantiates the definition's body_scene exactly like main_3d does and records it.
## [param def] creature definition; [param pos] world position of the CreatureRoot3D.
func _spawn(def: CreatureDefinition, pos: Vector3) -> void:
  var root := def.body_scene.instantiate() as Node3D
  root.set("definition", def)
  add_child(root)
  root.global_position = pos
  _entries.append({"root": root, "def": def})


## After the deferred mount: freezes physics, applies the body's own facing path, adds annotations.
func _finalize_creatures() -> void:
  var lines: Array[String] = []
  for e in _entries:
    var root: Node3D = e["root"]
    var def: CreatureDefinition = e["def"]
    var body := root.get_node("Body") as CharacterBody3D
    body.visible = true  # Body is hidden until a duel round starts; show it here.
    body.set_physics_process(false)
    body.set_process(false)
    body.velocity = Vector3.ZERO
    body.set("last_move_direction", _HEADING)
    body.call("_sync_visual_facing")
    var visual := body.get_node_or_null("Visual") as Node3D
    var expect_yaw := _MotorPlane.yaw_from_horizontal_dir(_HEADING) + float(body.get("visual_yaw_offset_rad"))
    var yaw_txt := "NO VISUAL"
    if visual != null:
      yaw_txt = "visual.rotation.y=%.4f (expected %.4f)" % [visual.rotation.y, expect_yaw]
    var radius := 2.0
    var col := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if col != null and col.shape is CapsuleShape3D:
      radius = (col.shape as CapsuleShape3D).radius * body.scale.x
    var sp := str(def.species_id)
    _annotate(body.global_position, radius, sp)
    lines.append("%s: %s, body scale %.2f, capsule r %.2f" % [sp, yaw_txt, body.scale.x, radius])
    print("FacingCheck ", lines[lines.size() - 1])
  _report.text = "\n".join(lines)


## Adds wedge, arrow and label for one creature. [param center] body world centre,
## [param radius] scaled capsule radius used to size the annotations.
func _annotate(center: Vector3, radius: float, species: String) -> void:
  var length := maxf(12.0, radius * 4.0)
  var origin := Vector3(center.x, 0.15, center.z)
  _add_wedge(origin, length, Color(1.0, 0.8, 0.1, 0.30))
  _add_arrow(origin + Vector3(0, 0.3, 0), _HEADING, length * 1.1, Color(1.0, 0.1, 0.1), maxf(0.35, radius * 0.12))
  var label := Label3D.new()
  label.text = "%s\ngame forward = -Z" % species.capitalize()
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.no_depth_test = true
  label.pixel_size = 0.04
  label.font_size = 48
  label.outline_size = 16
  label.position = Vector3(center.x, radius * 3.0 + 6.0, center.z)
  add_child(label)


## Flat translucent sector on XZ centred on the heading (same triangle fan as the awareness overlay).
func _add_wedge(origin: Vector3, reach: float, color: Color) -> void:
  var centre_angle := atan2(_HEADING.z, _HEADING.x)
  var a0 := centre_angle - _CONE_HALF_ANGLE
  var a1 := centre_angle + _CONE_HALF_ANGLE
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var segments := 36
  for i in range(segments):
    var aa := lerpf(a0, a1, float(i) / segments)
    var ab := lerpf(a0, a1, float(i + 1) / segments)
    st.set_normal(Vector3.UP)
    st.add_vertex(Vector3.ZERO)
    st.add_vertex(Vector3(cos(aa) * reach, 0.0, sin(aa) * reach))
    st.add_vertex(Vector3(cos(ab) * reach, 0.0, sin(ab) * reach))
  var mi := MeshInstance3D.new()
  mi.mesh = st.commit()
  mi.material_override = _unshaded(color)
  mi.position = origin
  add_child(mi)


## Arrow (cylinder shaft + cone head) from [param from] along unit [param dir].
func _add_arrow(from: Vector3, dir: Vector3, length: float, color: Color, thickness: float) -> Node3D:
  var arrow := Node3D.new()
  arrow.position = from
  arrow.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
  var head_len := length * 0.2
  var shaft := MeshInstance3D.new()
  var cyl := CylinderMesh.new()
  cyl.top_radius = thickness
  cyl.bottom_radius = thickness
  cyl.height = length - head_len
  shaft.mesh = cyl
  shaft.position = Vector3(0.0, cyl.height * 0.5, 0.0)
  shaft.material_override = _unshaded(color)
  arrow.add_child(shaft)
  var head := MeshInstance3D.new()
  var cone := CylinderMesh.new()
  cone.top_radius = 0.0
  cone.bottom_radius = thickness * 2.5
  cone.height = head_len
  head.mesh = cone
  head.position = Vector3(0.0, length - head_len * 0.5, 0.0)
  head.material_override = _unshaded(color)
  arrow.add_child(head)
  add_child(arrow)
  return arrow


## Unshaded material helper (alpha enabled when color.a < 1).
func _unshaded(color: Color) -> StandardMaterial3D:
  var m := StandardMaterial3D.new()
  m.albedo_color = color
  m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  m.cull_mode = BaseMaterial3D.CULL_DISABLED
  if color.a < 1.0:
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  return m


## World axes: -Z (blue) and +X (green), drawn left of the creatures.
func _build_axes() -> void:
  var o := Vector3(-80.0, 0.3, 25.0)
  _add_arrow(o, Vector3(0, 0, -1), 30.0, Color(0.2, 0.4, 1.0), 0.5)
  _add_arrow(o, Vector3(1, 0, 0), 30.0, Color(0.2, 1.0, 0.3), 0.5)
  _add_axis_label("-Z (game forward)", o + Vector3(0, 2, -34))
  _add_axis_label("+X", o + Vector3(34, 2, 0))


## Billboard text at [param pos].
func _add_axis_label(text: String, pos: Vector3) -> void:
  var l := Label3D.new()
  l.text = text
  l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  l.no_depth_test = true
  l.pixel_size = 0.04
  l.font_size = 40
  l.outline_size = 12
  l.position = pos
  add_child(l)


## Large flat ground plane at y = 0.
func _build_ground() -> void:
  var mi := MeshInstance3D.new()
  var pm := PlaneMesh.new()
  pm.size = Vector2(260.0, 160.0)
  mi.mesh = pm
  var m := StandardMaterial3D.new()
  m.albedo_color = Color(0.35, 0.45, 0.32)
  mi.material_override = m
  add_child(mi)


## Light, sky colour and camera.
func _build_environment() -> void:
  var sun := DirectionalLight3D.new()
  sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
  add_child(sun)
  var env := Environment.new()
  env.background_mode = Environment.BG_COLOR
  env.background_color = Color(0.55, 0.7, 0.9)
  env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  env.ambient_light_color = Color(0.7, 0.7, 0.7)
  var we := WorldEnvironment.new()
  we.environment = env
  add_child(we)
  _camera = Camera3D.new()
  _camera.far = 1000.0
  add_child(_camera)
  _camera.current = true


## On-screen hint and per-species report labels.
func _build_hud() -> void:
  var layer := CanvasLayer.new()
  add_child(layer)
  var hint := Label.new()
  hint.text = "Does each nose point along its arrow? Report per species: correct / backwards / sideways (left or right).\nCamera: 1 front 3/4, 2 side, 3 top-down, 4 rabbit close-up, 5 fox close-up, 6 wolf close-up"
  hint.position = Vector2(12, 8)
  hint.add_theme_font_size_override("font_size", 20)
  hint.add_theme_color_override("font_outline_color", Color.BLACK)
  hint.add_theme_constant_override("outline_size", 6)
  layer.add_child(hint)
  _report = Label.new()
  _report.position = Vector2(12, 70)
  _report.add_theme_font_size_override("font_size", 14)
  _report.add_theme_color_override("font_outline_color", Color.BLACK)
  _report.add_theme_constant_override("outline_size", 4)
  layer.add_child(_report)


## Positions the camera for preset [param which] (1 front 3/4, 2 side, 3 top-down, 4/5/6 close-up of
## rabbit / fox / wolf from the front-left, so the nose and the -Z arrow are both visible).
func _set_camera_view(which: int) -> void:
  var target := Vector3(5.0, 0.0, -5.0)
  var pos := Vector3(5.0, 40.0, -70.0)
  match which:
    2:
      pos = Vector3(-120.0, 45.0, -5.0)
    3:
      pos = Vector3(5.0, 150.0, -4.9)
    4, 5, 6:
      var center := Vector3(-45.0, 1.0, 0.0)
      var dist := 9.0
      if which == 5:
        center = Vector3(0.0, 1.0, 0.0)
        dist = 12.0
      elif which == 6:
        center = Vector3(55.0, 3.0, 0.0)
        dist = 28.0
      target = center
      pos = center + Vector3(-0.6, 0.55, -1.0).normalized() * dist
  _camera.global_position = pos
  _camera.look_at(target, Vector3.UP)
