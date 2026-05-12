extends Node2D
## Runtime debug draw for scripted motor awareness (base radius, forward cone extra band, gated live + ghost mob samples).
## Enable via Project Settings [code]hunter_killer_debug/draw_awareness[/code], or press **F9** in debug builds ([code]OS.is_debug_build()[/code]).

const _PLAYING_STATE: int = 2  # Matches [enum AiDriver.State.PLAYING] on the autoload script.

var _dev_toggle: bool = false


func _ready() -> void:
  z_index = 50
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


func _draw() -> void:
  if not _overlay_enabled():
    return
  var ad := get_node_or_null("/root/AiDriver")
  if ad == null or ad.get_state() != _PLAYING_STATE:
    return
  var motor: Dictionary = GameConfig.get_creature_motor_params()
  var r0 := float(motor.get("awareness_radius", 0.0))
  if r0 <= 0.0:
    return
  var extra := float(motor.get("awareness_cone_extra", 0.0))
  var half_deg := float(motor.get("awareness_cone_half_angle_deg", 45.0))
  var facing := Vector2.RIGHT
  var par := get_parent()
  if par != null:
    var fd: Variant = par.get("last_move_direction")
    if typeof(fd) == TYPE_VECTOR2:
      var fv := fd as Vector2
      if fv.length() > 1e-4:
        facing = fv.normalized()

  var base_col := Color(0.25, 0.82, 1.0, 0.38)
  draw_arc(Vector2.ZERO, r0, 0.0, TAU, 72, base_col, 2.0, true)

  if extra > 0.0:
    var hf := deg_to_rad(half_deg)
    var ang := facing.angle()
    var a0 := ang - hf
    var a1 := ang + hf
    var rim := Color(0.25, 1.0, 0.62, 0.52)
    draw_arc(Vector2.ZERO, r0 + extra, a0, a1, 36, rim, 2.0, true)
    draw_line(
      Vector2.from_angle(a0) * r0,
      Vector2.from_angle(a0) * (r0 + extra),
      Color(rim.r, rim.g, rim.b, 0.42),
      2.0,
    )
    draw_line(
      Vector2.from_angle(a1) * r0,
      Vector2.from_angle(a1) * (r0 + extra),
      Color(rim.r, rim.g, rim.b, 0.42),
      2.0,
    )

  for item in ad.get_debug_motor_mobs_snapshot():
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var d: Dictionary = item
    var src: String = str(d.get("_motor_debug_source", ""))
    if src != "gated" and src != "ghost":
      continue
    var wp: Variant = d.get("position", null)
    if typeof(wp) != TYPE_VECTOR2:
      continue
    var world_p := wp as Vector2
    var lp := to_local(world_p)
    var col := Color(1.0, 0.52, 0.08, 0.92) if src == "gated" else Color(0.88, 0.22, 1.0, 0.92)
    draw_circle(lp, 7.0, col)
