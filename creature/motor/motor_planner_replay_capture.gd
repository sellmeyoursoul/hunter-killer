extends RefCounted
class_name MotorPlannerReplayCapture
## Opt-in per-tick JSONL capture of planner inputs (creature position/facing/calories + live
## scan) for headless replay regression fixtures
## ([CREATURE_MOVEMENT_V3_CLEANUP.md](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md)
## replay harness plan). Off by default — enable via
## [code]hunter_killer_debug/motor_replay_capture[/code] (debug builds only). Unlike
## [MotorPlannerExploreLog] (one shared HUD/log file, all creatures interleaved), capture writes
## one rolling file **per creature label** so a duel session's predator and prey traces can be
## replayed independently without interleave-parsing.

const _LOG_DIR_REL := "logs/motor_replay_capture"
const _MAX_LINES_PER_CREATURE := 2000

static var _lines_by_creature: Dictionary = {}  # String -> PackedStringArray
static var _session_open_by_creature: Dictionary = {}  # String -> bool


static func _capture_enabled() -> bool:
  if not OS.is_debug_build():
    return false
  return bool(ProjectSettings.get_setting("hunter_killer_debug/motor_replay_capture", false))


## Filesystem-safe stem for a creature label (species id / display name / node name).
static func _safe_file_stem(creature_label: String) -> String:
  var lowered := creature_label.strip_edges().to_lower()
  var out := ""
  for c in lowered:
    if c == " " or c == "/" or c == "\\" or c == ":":
      out += "_"
    else:
      out += c
  if out.is_empty():
    return "creature"
  return out


static func _rel_path_for(creature_label: String) -> String:
  return "%s/%s.jsonl" % [_LOG_DIR_REL, _safe_file_stem(creature_label)]


static func _ensure_dir() -> void:
  var dir := DirAccess.open("user://")
  if dir != null:
    dir.make_dir_recursive(_LOG_DIR_REL)


## Clears the rolling buffer and truncates the capture file for one creature — call from
## [code]CreatureMotorStack.configure()[/code]. Scoped per creature label (not global like
## [method MotorPlannerExploreLog.reset_session]) so one creature (re)configuring mid-session
## does not wipe another creature's in-progress capture.
static func reset_session_for(creature_label: String) -> void:
  _lines_by_creature[creature_label] = PackedStringArray()
  _session_open_by_creature[creature_label] = false
  if not _capture_enabled():
    return
  _ensure_dir()
  _flush_file(creature_label)
  _session_open_by_creature[creature_label] = true


static func _flush_file(creature_label: String) -> void:
  var f := FileAccess.open("user://%s" % _rel_path_for(creature_label), FileAccess.WRITE)
  if f == null:
    return
  var lines: PackedStringArray = _lines_by_creature.get(creature_label, PackedStringArray())
  for line in lines:
    f.store_line(line)
  f.close()


static func _append_line_to_file(creature_label: String, line: String) -> void:
  var path := "user://%s" % _rel_path_for(creature_label)
  var f: FileAccess = null
  if FileAccess.file_exists(path):
    f = FileAccess.open(path, FileAccess.READ_WRITE)
    if f != null:
      f.seek_end()
  else:
    f = FileAccess.open(path, FileAccess.WRITE)
  if f == null:
    return
  f.store_line(line)
  f.close()


## Recursively converts Vector2/Vector3/StringName (not JSON-native) to plain arrays/strings so
## [method JSON.stringify] can round-trip the live-scan payload. Dictionary keys are stringified
## ([StringName] keys are not valid JSON object keys).
static func _sanitize(value: Variant) -> Variant:
  match typeof(value):
    TYPE_VECTOR3:
      var v3: Vector3 = value
      return [v3.x, v3.y, v3.z]
    TYPE_VECTOR2:
      var v2: Vector2 = value
      return [v2.x, v2.y]
    TYPE_STRING_NAME:
      return str(value)
    TYPE_DICTIONARY:
      var out_dict := {}
      for key in (value as Dictionary).keys():
        out_dict[str(key)] = _sanitize((value as Dictionary)[key])
      return out_dict
    TYPE_ARRAY:
      var out_arr := []
      for item in (value as Array):
        out_arr.append(_sanitize(item))
      return out_arr
    _:
      return value


## Appends one replay-capture record when capture is enabled for [param creature_label]. No-op
## (cheap) when the debug flag is off — safe to call unconditionally every tick.
## [param record] may carry raw engine types (Vector3 / StringName) — sanitized here before
## [method JSON.stringify].
static func maybe_capture_tick(creature_label: String, record: Dictionary) -> void:
  if not _capture_enabled():
    return
  if not _session_open_by_creature.get(creature_label, false):
    reset_session_for(creature_label)
  var line := JSON.stringify(_sanitize(record))
  if not _lines_by_creature.has(creature_label):
    _lines_by_creature[creature_label] = PackedStringArray()
  var lines: PackedStringArray = _lines_by_creature[creature_label]
  lines.append(line)
  var rolled := false
  while lines.size() > _MAX_LINES_PER_CREATURE:
    lines.remove_at(0)
    rolled = true
  _lines_by_creature[creature_label] = lines
  if rolled:
    _flush_file(creature_label)
  else:
    _append_line_to_file(creature_label, line)
