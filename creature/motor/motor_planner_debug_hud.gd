extends Control
## On-screen V3 motor planner debug for duel smoke — action, incumbent, step source, scan counts.
## Enable via Project Settings [code]hunter_killer_debug/draw_motor_planner_hud[/code], or press **F10** in debug builds.

const _PLAYING_STATE: int = 2

@export var poll_frames: int = 3

var _dev_toggle: bool = false
var _poll: int = 0


func _ready() -> void:
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  set_process(true)
  set_process_unhandled_input(true)
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
  $HerbivoreLabel.text = _format_creature_line(herb_root, "Herb")
  $CarnivoreLabel.text = _format_creature_line(carn_root, "Carn")


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


func _format_creature_line(creature_root: Node, fallback_name: String) -> String:
  if creature_root == null:
    return "%s motor\n(no creature)" % fallback_name
  var title := _creature_display_name(creature_root, fallback_name)
  var stack_v: Variant = creature_root.call(&"get_motor_stack")
  if stack_v == null or not (stack_v as Object).has_method(&"get_debug_snapshot"):
    return "%s motor\n(stack pending)" % title
  var snap: Dictionary = stack_v.call(&"get_debug_snapshot") as Dictionary
  return _format_snapshot(title, snap)


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


static func _format_snapshot(title: String, snap: Dictionary) -> String:
  var cal_pct := int(round(float(snap.get("calorie_ratio", 0.0)) * 100.0))
  var tgt: Vector2 = snap.get("step_goal_xz", Vector2.ZERO)
  var inc_goal := str(snap.get("incumbent_goal", ""))
  if bool(snap.get("incumbent_empty", true)):
    inc_goal = "(none)"
  var blk_act := str(snap.get("blocked_objective_action", ""))
  if blk_act.is_empty():
    blk_act = "-"
  var commit := int(snap.get("turn_commit_sign", 0))
  var commit_label := "0"
  if commit > 0:
    commit_label = "L"
  elif commit < 0:
    commit_label = "R"
  return (
    "%s motor\n"
    + "act=%s blk=%s cal=%d%%\n"
    + "inc=%s w=%.3f\n"
    + "src=%s gk=%s tgt=(%.1f,%.1f) id=%d\n"
    + "cmt=%s err=%.1f dot=%.3f\n"
    + "blk_act=%s cblk=%d tick=%d/%d ff=%d food=%d thr=%d"
  ) % [
    title,
    str(snap.get("action", "?")),
    "1" if bool(snap.get("blocked", false)) else "0",
    cal_pct,
    inc_goal,
    float(snap.get("incumbent_weight", 0.0)),
    str(snap.get("step_source", "")),
    str(snap.get("goal_kind", "")),
    tgt.x,
    tgt.y,
    int(snap.get("step_instance_id", 0)),
    commit_label,
    float(snap.get("bearing_error_deg", 0.0)),
    float(snap.get("facing_dot_tgt", 0.0)),
    blk_act,
    int(snap.get("consecutive_blocked", 0)),
    int(snap.get("physics_tick", 0)),
    int(snap.get("consideration_interval", 0)),
    1 if bool(snap.get("flight_fast_path", false)) else 0,
    int(snap.get("ready_food", 0)),
    int(snap.get("threat_count", 0)),
  ]
