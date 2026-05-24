extends Node2D
## Runtime debug draw for scripted motor awareness (base radius, forward cone extra band).
## Under Player: gated live + ghost mob samples ([method AiDriver.get_debug_motor_mobs_snapshot]). Under Mob: prey positions inside carnivore reach ([method AiDriver.get_debug_carnivore_prey_snapshot]).
## Enable via Project Settings [code]hunter_killer_debug/draw_awareness[/code], or press **F9** in debug builds ([code]OS.is_debug_build()[/code]).

const _PLAYING_STATE: int = 2  # Matches [enum AiDriver.State.PLAYING] on the autoload script.

var _dev_toggle: bool = false


func _ready() -> void:
  z_index = 50
  visible = true
  set_process(true)
  set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  if event is InputEventKey and event.pressed and not event.echo:
    var ek := event as InputEventKey
    if ek.keycode == KEY_F9:
      _dev_toggle = not _dev_toggle
      queue_redraw()


func _process(_delta: float) -> void:
  if _overlay_enabled():
    queue_redraw()


## Params:
## - none
## Returns:
## - [code]true[/code] when project setting forces overlay on, or debug build + F9 toggle.
func _overlay_enabled() -> bool:
  var via_settings := bool(
    ProjectSettings.get_setting("hunter_killer_debug/draw_awareness", false)
  )
  return via_settings or (OS.is_debug_build() and _dev_toggle)


## Params:
## - ad: AiDriver autoload node (may be null).
## Returns:
## - [code]true[/code] during LLM [enum AiDriver.State.PLAYING] or active scripted duel ([method AiDriver.is_duel_round_active]).
func _awareness_debug_allowed(ad: Node) -> bool:
  if ad == null:
    return false
  if ad.get_state() == _PLAYING_STATE:
    return true
  if ad.has_method(&"is_duel_round_active") and bool(ad.call(&"is_duel_round_active")):
    return true
  return false


## Resolves merged motor params for the parent creature (pack overlay when available).
func _motor_params_for_parent(ad: Node, par: Node) -> Dictionary:
  if par is PhysicsBody2D and ad != null and ad.has_method(&"get_debug_motor_params_for_body"):
    var pack_motor: Variant = ad.call("get_debug_motor_params_for_body", par)
    if typeof(pack_motor) == TYPE_DICTIONARY:
      return pack_motor as Dictionary
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    var global_motor: Variant = gc.call("get_creature_motor_params")
    if typeof(global_motor) == TYPE_DICTIONARY:
      return global_motor as Dictionary
  return {}


## Filled sector from [param center] between [param ang0] and [param ang1] out to [param radius].
func _filled_sector(center: Vector2, radius: float, ang0: float, ang1: float, col: Color, segments: int = 32) -> void:
  if radius <= 0.0:
    return
  var pts := PackedVector2Array()
  pts.append(center)
  for i in range(segments + 1):
    var t := float(i) / float(segments)
    var ang := lerpf(ang0, ang1, t)
    pts.append(center + Vector2.from_angle(ang) * radius)
  if pts.size() >= 3:
    draw_colored_polygon(pts, col)


func _draw() -> void:
  if not _overlay_enabled():
    return
  var ad := get_node_or_null("/root/AiDriver")
  if not _awareness_debug_allowed(ad):
    return
  var par := get_parent()
  var motor: Dictionary = _motor_params_for_parent(ad, par)
  var r0 := float(motor.get("awareness_radius", 0.0))
  if r0 <= 0.0:
    return
  var extra := float(motor.get("awareness_cone_extra", 0.0))
  var half_deg := float(motor.get("awareness_cone_half_angle_deg", 45.0))
  var forward_cone_only := bool(motor.get("awareness_forward_cone_only", false))
  var facing := Vector2.RIGHT
  if par != null:
    var fd: Variant = par.get("last_move_direction")
    if typeof(fd) == TYPE_VECTOR2:
      var fv := fd as Vector2
      if fv.length() > 1e-4:
        facing = fv.normalized()

  var hf := deg_to_rad(half_deg)
  var ang := facing.angle()
  var a0 := ang - hf
  var a1 := ang + hf
  var reach := r0 + maxf(0.0, extra)

  if forward_cone_only:
    _filled_sector(Vector2.ZERO, reach, a0, a1, Color(0.25, 0.82, 1.0, 0.16), 36)
    draw_arc(Vector2.ZERO, reach, a0, a1, 36, Color(0.25, 1.0, 0.62, 0.72), 4.0, true)
    draw_line(Vector2.ZERO, Vector2.from_angle(a0) * reach, Color(0.25, 1.0, 0.62, 0.55), 3.0)
    draw_line(Vector2.ZERO, Vector2.from_angle(a1) * reach, Color(0.25, 1.0, 0.62, 0.55), 3.0)
  else:
    draw_circle(Vector2.ZERO, r0, Color(0.25, 0.82, 1.0, 0.12))
    draw_arc(Vector2.ZERO, r0, 0.0, TAU, 72, Color(0.25, 0.82, 1.0, 0.55), 4.0, true)
    if extra > 0.0:
      _filled_sector(Vector2.ZERO, reach, a0, a1, Color(0.25, 1.0, 0.62, 0.14), 24)
      draw_arc(Vector2.ZERO, reach, a0, a1, 36, Color(0.25, 1.0, 0.62, 0.72), 4.0, true)
      draw_line(
        Vector2.from_angle(a0) * r0,
        Vector2.from_angle(a0) * reach,
        Color(0.25, 1.0, 0.62, 0.55),
        3.0,
      )
      draw_line(
        Vector2.from_angle(a1) * r0,
        Vector2.from_angle(a1) * reach,
        Color(0.25, 1.0, 0.62, 0.55),
        3.0,
      )

  var carn_overlay := par != null and par.is_in_group(&"mobs")
  if carn_overlay:
    for wp in ad.get_debug_carnivore_prey_snapshot(par as PhysicsBody2D):
      if typeof(wp) != TYPE_VECTOR2:
        continue
      var world_p := wp as Vector2
      draw_circle(to_local(world_p), 9.0, Color(0.35, 1.0, 0.45, 0.92))
    return

  for item in ad.get_debug_motor_mobs_snapshot():
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var d: Dictionary = item
    var src: String = str(d.get("_motor_debug_source", ""))
    if src != "gated" and src != "ghost":
      continue
    var wp2: Variant = d.get("position", null)
    if typeof(wp2) != TYPE_VECTOR2:
      continue
    var world_p2 := wp2 as Vector2
    var lp := to_local(world_p2)
    var col := Color(1.0, 0.52, 0.08, 0.92) if src == "gated" else Color(0.88, 0.22, 1.0, 0.92)
    draw_circle(lp, 9.0, col)
