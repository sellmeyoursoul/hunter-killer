extends Node3D
## Runtime debug draw for scripted motor awareness on **3D** duel bodies (base radius, forward cone).
## Under herbivore Body: gated live + ghost mob samples ([method AiDriver.get_debug_motor_mobs_snapshot]).
## Under carnivore Body: prey positions inside carnivore reach ([method AiDriver.get_debug_carnivore_prey_snapshot]).
## Enable via Project Settings [code]hunter_killer_debug/draw_awareness[/code], or press **F9** in debug builds.
## Geometry uses scaled [code]creature_motor_v3[/code] — same as [code]CreatureMotorStack[/code] live scan.

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _PLAYING_STATE: int = 2

var _dev_toggle: bool = false
var _mesh_inst: MeshInstance3D
var _marker_root: Node3D


func _ready() -> void:
  _mesh_inst = MeshInstance3D.new()
  _mesh_inst.name = "AwarenessMesh"
  add_child(_mesh_inst)
  _marker_root = Node3D.new()
  _marker_root.name = "MobMarkers"
  add_child(_marker_root)
  set_process(true)
  set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  if event is InputEventKey and event.pressed and not event.echo:
    var ek := event as InputEventKey
    if ek.keycode == KEY_F9:
      _dev_toggle = not _dev_toggle
      _rebuild_draw()


func _process(_delta: float) -> void:
  if _overlay_enabled():
    _rebuild_draw()
  elif _mesh_inst.mesh != null:
    _mesh_inst.mesh = null
    _clear_markers()


func _overlay_enabled() -> bool:
  var via_settings := bool(
    ProjectSettings.get_setting("hunter_killer_debug/draw_awareness", false)
  )
  return via_settings or (OS.is_debug_build() and _dev_toggle)


func _awareness_debug_allowed(ad: Node) -> bool:
  if ad == null:
    return false
  if ad.get_state() == _PLAYING_STATE:
    return true
  if ad.has_method(&"is_duel_round_active") and bool(ad.call(&"is_duel_round_active")):
    return true
  return false


func _motor_params_for_parent(ad: Node, par: Node) -> Dictionary:
  if par != null and ad != null and ad.has_method(&"get_debug_motor_v3_params_for_body"):
    var pack_motor: Variant = ad.call("get_debug_motor_v3_params_for_body", par)
    if typeof(pack_motor) == TYPE_DICTIONARY:
      return pack_motor as Dictionary
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_v3_params"):
    var global_v3: Variant = gc.call("get_creature_motor_v3_params")
    if typeof(global_v3) == TYPE_DICTIONARY and par != null:
      var main: Node = get_tree().current_scene if is_inside_tree() else null
      var playfield := _playfield_size_for_overlay(par, main)
      var dist_scale := _MotorPlane.motor_distance_scale_for_main(main, playfield)
      return _MotorPlane.scale_motor_distance_params(global_v3 as Dictionary, dist_scale)
  return {}


## Playfield bounds for overlay fallback when [code]AiDriver[/code] debug params are unavailable.
func _playfield_size_for_overlay(body: Node, main: Node) -> Vector2:
  var ss: Variant = body.get("screen_size")
  if typeof(ss) == TYPE_VECTOR2:
    var pf := ss as Vector2
    if pf.x > 0.0 and pf.y > 0.0:
      return pf
  if main != null and main.has_method(&"get_motor_playfield_size"):
    var mps: Variant = main.call(&"get_motor_playfield_size")
    if typeof(mps) == TYPE_VECTOR2:
      var mv := mps as Vector2
      if mv.x > 0.0 and mv.y > 0.0:
        return mv
  return Vector2.ZERO


## Builds a flat sector mesh on the XZ plane at local [param lift].
func _append_sector_tris(
  st: SurfaceTool,
  radius: float,
  ang0: float,
  ang1: float,
  lift: float,
  segments: int,
) -> void:
  if radius <= 0.0:
    return
  var center := Vector3(0.0, lift, 0.0)
  st.set_color(Color(1.0, 1.0, 1.0, 1.0))
  for i in range(segments):
    var t0 := float(i) / float(segments)
    var t1 := float(i + 1) / float(segments)
    var a0 := lerpf(ang0, ang1, t0)
    var a1 := lerpf(ang0, ang1, t1)
    var p0 := center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
    var p1 := center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
    st.set_normal(Vector3.UP)
    st.add_vertex(center)
    st.add_vertex(p0)
    st.add_vertex(p1)


func _append_arc_line(
  st: SurfaceTool,
  radius: float,
  ang0: float,
  ang1: float,
  lift: float,
  segments: int,
) -> void:
  if radius <= 0.0:
    return
  for i in range(segments):
    var t0 := float(i) / float(segments)
    var t1 := float(i + 1) / float(segments)
    var a0 := lerpf(ang0, ang1, t0)
    var a1 := lerpf(ang0, ang1, t1)
    var p0 := Vector3(cos(a0) * radius, lift, sin(a0) * radius)
    var p1 := Vector3(cos(a1) * radius, lift, sin(a1) * radius)
    st.set_normal(Vector3.UP)
    st.add_vertex(p0)
    st.add_vertex(p1)


func _clear_markers() -> void:
  for ch in _marker_root.get_children():
    ch.queue_free()


func _add_world_marker(world_p: Vector3, col: Color, radius: float = 0.18) -> void:
  var mi := MeshInstance3D.new()
  var sph := SphereMesh.new()
  sph.radius = radius
  sph.height = radius * 2.0
  mi.mesh = sph
  var mat := StandardMaterial3D.new()
  mat.albedo_color = col
  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  mi.material_override = mat
  mi.position = to_local(world_p)
  _marker_root.add_child(mi)


func _rebuild_draw() -> void:
  if not _overlay_enabled():
    return
  var ad := get_node_or_null("/root/AiDriver")
  if not _awareness_debug_allowed(ad):
    _mesh_inst.mesh = null
    _clear_markers()
    return
  var par := get_parent()
  var motor: Dictionary = _motor_params_for_parent(ad, par)
  var r0 := float(motor.get("awareness_radius", 0.0))
  if r0 <= 0.0:
    _mesh_inst.mesh = null
    _clear_markers()
    return
  var extra := float(motor.get("awareness_cone_extra", 0.0))
  var half_deg := float(motor.get("awareness_cone_half_angle_deg", 45.0))
  var forward_cone_only := bool(motor.get("awareness_forward_cone_only", false))
  var facing := _MotorPlane.HORIZONTAL_RIGHT
  if par != null:
    var fd: Variant = par.get("last_move_direction")
    facing = _MotorPlane.read_dir(fd, _MotorPlane.HORIZONTAL_RIGHT)
  var hf := deg_to_rad(half_deg)
  var ang := Vector2(facing.x, facing.z).angle()
  var a0 := ang - hf
  var a1 := ang + hf
  var reach := r0 + maxf(0.0, extra)
  const LIFT := 0.06
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  if forward_cone_only:
    _append_sector_tris(st, reach, a0, a1, LIFT, 36)
  else:
    _append_sector_tris(st, r0, 0.0, TAU, LIFT, 72)
    if extra > 0.0:
      _append_sector_tris(st, reach, a0, a1, LIFT + 0.01, 24)
  var mesh := st.commit()
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.25, 0.82, 1.0, 0.14)
  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  _mesh_inst.material_override = mat
  _mesh_inst.mesh = mesh
  _clear_markers()
  var carn_overlay := par != null and par.is_in_group(&"mobs")
  if carn_overlay:
    for wp in ad.get_debug_carnivore_prey_snapshot(par):
      var world_p := _MotorPlane.read_pos(wp)
      if world_p == Vector3.ZERO:
        continue
      _add_world_marker(world_p, Color(0.35, 1.0, 0.45, 0.92))
    return
  for item in ad.get_debug_motor_mobs_snapshot():
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var d: Dictionary = item
    var src: String = str(d.get("_motor_debug_source", ""))
    if src != "gated" and src != "ghost":
      continue
    var wp2: Variant = d.get("position", null)
    var world_p2 := _MotorPlane.read_pos(wp2)
    if world_p2 == Vector3.ZERO:
      continue
    var col := Color(1.0, 0.52, 0.08, 0.92) if src == "gated" else Color(0.88, 0.22, 1.0, 0.92)
    _add_world_marker(world_p2, col)
