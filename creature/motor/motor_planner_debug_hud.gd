extends Control
## On-screen V3 motor planner debug for duel smoke — one label per active creature (any species,
## any count — [CM_V3_MULTI_MOBS.md](../../Project_Docs/Draft_Features/CM_V3_MULTI_MOBS.md)), each
## colored ([CreatureDebugColor]) to match that creature's F9 awareness-zone overlay so it's fast to
## line a creature up with its output with more than one on screen.
## Enable via Project Settings [code]hunter_killer_debug/draw_motor_planner_hud[/code], or press **F10** in debug builds.
## Deliberately minimal on screen — title (species + creature id) plus [code]src[/code]/[code]gk[/code]
## only. The full field set (target, bearing, blocked-state, food/threat counts, hunt engagement,
## etc.) is still computed every tick by [method _ExploreLog.format_explore_tick_hud] / written to
## [code]user://logs/motor_explore_tick.log[/code] when [code]motor_explore_tick_log[/code] is set —
## that function has the full key list and formatting; add a field back into [method _format_creature_line]
## the same way if troubleshooting needs more than src/gk.
## Frozen, not cleared, on round end: [method _refresh_labels] only overwrites a label when it finds
## live creature+stack data, so the last tick before creatures were freed stays on screen to read.

const _DebugColor := preload("res://creature/creature_debug_color.gd")

@export var poll_frames: int = 4

var _dev_toggle: bool = false
var _poll: int = 0
var _labels: Array[Label] = []
var _label_font: Font


func _ready() -> void:
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  set_process(true)
  set_process_unhandled_input(true)
  var font := SystemFont.new()
  font.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "monospace"])
  _label_font = font
  _sync_visibility()


func _unhandled_input(event: InputEvent) -> void:
  if not OS.is_debug_build():
    return
  if event is InputEventKey and event.pressed and not event.echo:
    var ek := event as InputEventKey
    if ek.keycode == KEY_F10:
      _dev_toggle = not _dev_toggle
      _sync_visibility()


func _process(_delta: float) -> void:
  if not _panel_enabled():
    if visible:
      visible = false
    return
  if not visible:
    visible = true
  _poll += 1
  if _poll < poll_frames:
    return
  _poll = 0
  _refresh_labels()


## Gated only on the debug toggle/setting, not on "is a round active" — a round ending must not
## make the panel (or its last readings) disappear; see [method _refresh_labels].
func _panel_enabled() -> bool:
  var via_settings := bool(
    ProjectSettings.get_setting("hunter_killer_debug/draw_motor_planner_hud", false)
  )
  return via_settings or (OS.is_debug_build() and _dev_toggle)


func _sync_visibility() -> void:
  visible = _panel_enabled()


func _creature_roots() -> Array:
  var scene := get_tree().current_scene
  if scene == null or not scene.has_method(&"get_all_creature_roots"):
    return []
  var roots: Variant = scene.call(&"get_all_creature_roots")
  return roots as Array if typeof(roots) == TYPE_ARRAY else []


func _refresh_labels() -> void:
  var roots := _creature_roots()
  _ensure_label_pool(maxi(1, roots.size()))
  if roots.is_empty():
    return
  for i in range(roots.size()):
    var root: Node = roots[i]
    if root == null or not is_instance_valid(root):
      continue
    var line := _format_creature_line(root)
    if line.is_empty():
      continue
    _labels[i].text = line
    _labels[i].add_theme_color_override("font_color", _color_for_root(root))


func _ensure_label_pool(count: int) -> void:
  var container := $CreatureLabels
  while _labels.size() < count:
    var lbl := Label.new()
    lbl.add_theme_font_override("font", _label_font)
    lbl.add_theme_font_size_override("font_size", 14)
    lbl.custom_minimum_size = Vector2(220, 0)
    container.add_child(lbl)
    _labels.append(lbl)
  while _labels.size() > count:
    var extra: Label = _labels.pop_back()
    extra.queue_free()


func _color_for_root(creature_root: Node) -> Color:
  return _DebugColor.color_for_instance_id(_instance_id_for_root(creature_root))


func _instance_id_for_root(creature_root: Node) -> int:
  var body := creature_root.get_node_or_null("Body")
  if body == null:
    return 0
  return int(body.get("creature_instance_id"))


func _format_creature_line(creature_root: Node) -> String:
  if not creature_root.has_method(&"get_motor_stack"):
    return ""
  var stack_v: Variant = creature_root.call(&"get_motor_stack")
  if stack_v == null or not (stack_v as Object).has_method(&"get_debug_snapshot"):
    return ""
  var snap: Dictionary = stack_v.call(&"get_debug_snapshot") as Dictionary
  var title := "%s #%d" % [
    _creature_display_name(creature_root, "Creature"),
    _instance_id_for_root(creature_root),
  ]
  return "%s\nsrc=%s gk=%s" % [title, str(snap.get("step_source", "")), str(snap.get("goal_kind", ""))]


func _creature_display_name(creature_root: Node, fallback: String) -> String:
  var def_v: Variant = creature_root.get("definition")
  if def_v is Resource:
    var display := str((def_v as Resource).get("display_name")).strip_edges()
    if not display.is_empty():
      return display
    var species := str((def_v as Resource).get("species_id")).strip_edges()
    if not species.is_empty():
      return species
  if not creature_root.name.is_empty():
    return str(creature_root.name)
  return fallback
