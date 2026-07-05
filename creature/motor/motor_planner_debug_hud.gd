extends Control
## On-screen V3 motor planner debug for duel smoke — action, incumbent, step source, scan counts.
## Enable via Project Settings [code]hunter_killer_debug/draw_motor_planner_hud[/code], or press **F10** in debug builds.
## Explore ticks also append to [code]user://logs/motor_explore_tick.log[/code] when [code]motor_explore_tick_log[/code] is set.

const _PLAYING_STATE: int = 2
const _ExploreLog := preload("res://creature/motor/motor_planner_explore_log.gd")

@export var poll_frames: int = 4

var _dev_toggle: bool = false
var _poll: int = 0


func _ready() -> void:
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  set_process(true)
  set_process_unhandled_input(true)
  _apply_monospace_labels()
  _sync_visibility()


func _apply_monospace_labels() -> void:
  var font := SystemFont.new()
  font.font_names = PackedStringArray(["Consolas", "Courier New", "DejaVu Sans Mono", "monospace"])
  for node_name in ["HerbivoreLabel", "CarnivoreLabel"]:
    var lbl := get_node_or_null(node_name) as Label
    if lbl != null:
      lbl.add_theme_font_override("font", font)
      lbl.add_theme_font_size_override("font_size", 13)


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


func _panel_enabled() -> bool:
  if not _motor_debug_allowed():
    return false
  var via_settings := bool(
    ProjectSettings.get_setting("hunter_killer_debug/draw_motor_planner_hud", false)
  )
  return via_settings or (OS.is_debug_build() and _dev_toggle)


func _motor_debug_allowed(ad: Node = null) -> bool:
  if ad == null:
    ad = get_node_or_null("/root/AiDriver")
  if ad == null:
    return false
  if ad.get_state() == _PLAYING_STATE:
    return true
  if ad.has_method(&"is_duel_round_active") and bool(ad.call(&"is_duel_round_active")):
    return true
  return false


func _sync_visibility() -> void:
  visible = _panel_enabled()


func _refresh_labels() -> void:
  var herb_root := _resolve_creature_root(&"herbivore")
  var carn_root := _resolve_creature_root(&"carnivore")
  $HerbivoreLabel.text = _format_creature_line("Herbivore", "Herb", herb_root)
  $CarnivoreLabel.text = _format_creature_line("Fox", "Fox", carn_root)


func _resolve_creature_root(role: StringName) -> Node:
  var scene := get_tree().current_scene
  if scene == null:
    return null
  if role == &"herbivore" and scene.has_method(&"get_herbivore_creature_root"):
    return scene.call(&"get_herbivore_creature_root") as Node
  if role == &"carnivore" and scene.has_method(&"get_carnivore_creature_root"):
    return scene.call(&"get_carnivore_creature_root") as Node
  var body: Node = null
  if role == &"herbivore" and scene.has_method(&"get_herbivore_motor_body"):
    body = scene.call(&"get_herbivore_motor_body") as Node
  if role == &"carnivore":
    var mobs := get_tree().get_nodes_in_group(&"mobs")
    if mobs.size() >= 1:
      body = mobs[0]
  if body == null:
    return null
  var parent := body.get_parent()
  if parent != null and parent.has_method(&"get_motor_stack"):
    return parent
  return null


func _format_creature_line(fallback_name: String, short_tag: String, creature_root: Node) -> String:
  if creature_root == null:
    return "%s motor\n(no creature)" % fallback_name
  var title := _creature_display_name(creature_root, fallback_name)
  var stack_v: Variant = creature_root.call(&"get_motor_stack")
  if stack_v == null or not (stack_v as Object).has_method(&"get_debug_snapshot"):
    return "%s motor\n(stack pending)" % title
  var snap: Dictionary = stack_v.call(&"get_debug_snapshot") as Dictionary
  return _format_snapshot(title, short_tag, snap)


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


static func _format_snapshot(title: String, short_tag: String, snap: Dictionary) -> String:
  var header := _ExploreLog._fw(title, 12) + " motor"
  var explore_block: String = _ExploreLog.format_explore_tick_hud(snap, short_tag)
  var tick_iv := int(snap.get("consideration_interval", 0))
  return header + "\n" + explore_block + "\niv=%d" % tick_iv
