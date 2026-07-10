extends RefCounted
class_name MotorPlannerExploreLog
## Fixed-width motor tick lines for F10 HUD + rolling smoke log ([code]user://logs/motor_explore_tick.log[/code]).

const _LOG_REL_PATH := "logs/motor_explore_tick.log"
const _MAX_LINES := 800
const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")

static var _lines: PackedStringArray = PackedStringArray()
static var _session_open: bool = false


static func _log_header() -> String:
  return "# motor tick log — fixed-width columns (rolling last %d lines, all step sources)" % _MAX_LINES


## Clears the rolling buffer and truncates the tick log (call on motor stack configure / duel reset).
static func reset_session() -> void:
  _lines = PackedStringArray()
  _session_open = false
  if not _logging_enabled():
    return
  _ensure_logs_dir()
  _flush_log_file()
  _session_open = true


static func _ensure_logs_dir() -> void:
  var dir := DirAccess.open("user://")
  if dir != null:
    dir.make_dir_recursive("logs")


static func _flush_log_file() -> void:
  var f := FileAccess.open("user://%s" % _LOG_REL_PATH, FileAccess.WRITE)
  if f == null:
    return
  f.store_line(_log_header())
  for line in _lines:
    f.store_line(line)
  f.close()


static func _append_line_to_log_file(line: String) -> void:
  var f := FileAccess.open("user://%s" % _LOG_REL_PATH, FileAccess.READ_WRITE)
  if f == null:
    return
  f.seek_end()
  f.store_line(line)
  f.close()


## True when [code]hunter_killer_debug/motor_explore_tick_log[/code] is set (debug builds only).
static func _logging_enabled() -> bool:
  if not OS.is_debug_build():
    return false
  return bool(ProjectSettings.get_setting("hunter_killer_debug/motor_explore_tick_log", false))


## Clip or pad [param text] to [param width] characters (monospace HUD / log alignment).
static func _fw(text: String, width: int) -> String:
  var s := text.strip_edges()
  if s.length() > width:
    return s.substr(0, width)
  return s.rpad(width, " ")


## Boundary-scan turn label from [code]boundary_scan_sign[/code] ([code]sL[/code]/[code]sR[/code]).
static func scan_label_from_snap(snap: Dictionary) -> String:
  if not bool(snap.get("boundary_scan_active", false)):
    return ""
  var scan_sign := int(snap.get("boundary_scan_sign", 0))
  if scan_sign > 0:
    return "sL"
  if scan_sign < 0:
    return "sR"
  return "s0"


## One fixed-width explore tick line (HUD row + log file).
static func format_explore_tick_line(snap: Dictionary, creature_label: String = "") -> String:
  var tgt: Vector2 = snap.get("step_goal_xz", Vector2.ZERO)
  var blk_act := str(snap.get("blocked_objective_action", ""))
  if blk_act.is_empty():
    blk_act = "-"
  var inc_goal := str(snap.get("incumbent_goal", ""))
  if bool(snap.get("incumbent_empty", true)):
    inc_goal = "(none)"
  var scan_lbl := scan_label_from_snap(snap)
  var prefix := ""
  if not creature_label.is_empty():
    prefix = "%s " % _fw(creature_label, 8)
  return (
    prefix
    + "t=%04d act=%s blk=%s cal=%3d%% "
    + "inc=%s w=%6.3f src=%s gk=%s "
    + "tgt=(%8.1f,%8.1f) id=%5d "
    + "err=%+7.1f dot=%7.3f enp=%d "
    + "scan=%s blk_act=%s cblk=%3d ff=%d food=%d thr=%d"
  ) % [
    int(snap.get("physics_tick", 0)),
    _fw(str(snap.get("action", "?")), 6),
    "1" if bool(snap.get("blocked", false)) else "0",
    int(round(float(snap.get("calorie_ratio", 0.0)) * 100.0)),
    _fw(inc_goal, 10),
    float(snap.get("incumbent_weight", 0.0)),
    _fw(str(snap.get("step_source", "")), 7),
    _fw(str(snap.get("goal_kind", "")), 10),
    tgt.x,
    tgt.y,
    int(snap.get("step_instance_id", 0)),
    float(snap.get("bearing_error_deg", 0.0)),
    float(snap.get("facing_dot_tgt", 0.0)),
    int(snap.get("explore_no_progress_ticks", 0)),
    _fw(scan_lbl, 2),
    _fw(blk_act, 16),
    int(snap.get("consecutive_blocked", 0)),
    1 if bool(snap.get("flight_fast_path", false)) else 0,
    int(snap.get("ready_food", 0)),
    int(snap.get("threat_count", 0)),
  ]


## Multi-line explore snapshot for on-screen HUD (log file keeps [method format_explore_tick_line]).
static func format_explore_tick_hud(snap: Dictionary, creature_label: String = "") -> String:
  var tgt: Vector2 = snap.get("step_goal_xz", Vector2.ZERO)
  var blk_act := str(snap.get("blocked_objective_action", ""))
  if blk_act.is_empty():
    blk_act = "-"
  var inc_goal := str(snap.get("incumbent_goal", ""))
  if bool(snap.get("incumbent_empty", true)):
    inc_goal = "(none)"
  var scan_lbl := scan_label_from_snap(snap)
  var tag := ""
  if not creature_label.is_empty():
    tag = _fw(creature_label, 8) + " "
  var hunt_suffix := _hunt_debug_suffix(snap)
  return (
    tag
    + "t=%04d act=%s blk=%s cal=%3d%% inc=%s w=%6.3f\n"
    + "src=%s gk=%s\n"
    + "tgt=(%8.1f,%8.1f) id=%5d\n"
    + "err=%+7.1f dot=%7.3f enp=%d scan=%s\n"
    + "blk_act=%s cblk=%3d ff=%d food=%d thr=%d"
    + hunt_suffix
  ) % [
    int(snap.get("physics_tick", 0)),
    _fw(str(snap.get("action", "?")), 6),
    "1" if bool(snap.get("blocked", false)) else "0",
    int(round(float(snap.get("calorie_ratio", 0.0)) * 100.0)),
    _fw(inc_goal, 10),
    float(snap.get("incumbent_weight", 0.0)),
    _fw(str(snap.get("step_source", "")), 7),
    _fw(str(snap.get("goal_kind", "")), 10),
    tgt.x,
    tgt.y,
    int(snap.get("step_instance_id", 0)),
    float(snap.get("bearing_error_deg", 0.0)),
    float(snap.get("facing_dot_tgt", 0.0)),
    int(snap.get("explore_no_progress_ticks", 0)),
    _fw(scan_lbl, 2),
    _fw(blk_act, 16),
    int(snap.get("consecutive_blocked", 0)),
    1 if bool(snap.get("flight_fast_path", false)) else 0,
    int(snap.get("ready_food", 0)),
    int(snap.get("threat_count", 0)),
  ]


static func _hunt_debug_suffix(snap: Dictionary) -> String:
  if not bool(snap.get("is_carnivore", false)):
    return ""
  var goal_kind := str(snap.get("goal_kind", ""))
  var eng_rem := int(snap.get("prey_engagement_ticks_remaining", 0))
  if goal_kind != "find_food" and eng_rem <= 0:
    return ""
  var inv_mode := int(snap.get("food_inventory_step_mode", -1))
  var inv_lbl := "?"
  match inv_mode:
    0:
      inv_lbl = "hun"
    1:
      inv_lbl = "stk"
    2:
      inv_lbl = "und"
  var eng_id := int(snap.get("prey_engagement_instance_id", 0))
  var eng_total := int(snap.get("prey_engagement_latch_total", 0))
  return "\neng_id=%d eng=%d/%d inv=%s" % [eng_id, eng_rem, eng_total, inv_lbl]


## Append one motor tick line when logging is enabled (all [code]step_source[/code] values; rolling [code]_MAX_LINES[/code] buffer).
static func maybe_log_tick(creature_label: String, snap: Dictionary) -> void:
  if not _logging_enabled():
    return
  if not _session_open:
    reset_session()
  var line := format_explore_tick_line(snap, creature_label)
  _lines.append(line)
  var rolled := false
  while _lines.size() > _MAX_LINES:
    _lines.remove_at(0)
    rolled = true
  if rolled:
    _flush_log_file()
  else:
    _append_line_to_log_file(line)
  _OLogSafe.debug(line, false, "MotorExplore")
