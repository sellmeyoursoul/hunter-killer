extends Node
## Autoload singleton **OLog**: file logging with bounded queue, mutex, and logging settings from **GameConfig** (`user://game_config.json` merged with defaults).
## Design: `Project_Docs/Completed_Features/LOGGING_PLAN.md`.

#region Constants (match LOGGING_PLAN / instructions)
const MAX_LOG_LINE_CHARS := 2048
const LOG_STOP_BYTES := 1073741824 # ~1 GiB

const L_ERROR := 0
const L_INFO := 1
const L_DEBUG := 2

const CFG_ERROR := 0
const CFG_INFO := 1
const CFG_DEBUG := 2
#endregion

#region Config / runtime state
var _cfg_level: int = CFG_ERROR
var _max_lines_per_process: int = 128
var _max_queue_entries: int = 1024

var _enqueue_seq: int = 0
var _mutex: Mutex = Mutex.new()

## Queue of dictionaries: unix_time, level, source_tag, message, stack, seq
var _queue: Array = []

var _log_file: FileAccess
var _log_path: String = ""
var _bytes_written: int = 0
var _stopped_disk_full: bool = false

var _missing_config_notified: bool = false

var drops_info_total: int = 0
var drops_debug_total: int = 0
var drops_errors_total: int = 0
#endregion


func _ready() -> void:
  _load_config()
  _ensure_logs_dir()
  _log_path = _resolve_log_file_path()
  _open_log_file_append()
  set_process(true)


func _notification(what: int) -> void:
  if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
    _shutdown_drain()


func _process(_delta: float) -> void:
  _drain_batch()


#region Public API
## Logs an error-level line (always enqueued when disk policy allows). Optional mirror to editor Output when [param push_to_editor] is true.
func error(message: String, push_to_editor: bool = false, source_tag: String = "Main", with_stack: bool = false) -> void:
  var st := ""
  if with_stack:
    st = _capture_stack_text()
  _enqueue_filtered(L_ERROR, message, source_tag, st, push_to_editor)


## Logs info-level line when config allows Info or Debug.
func info(message: String, push_to_editor: bool = false, source_tag: String = "Main", with_stack: bool = false) -> void:
  if _cfg_level < CFG_INFO:
    return
  var st := ""
  if with_stack:
    st = _capture_stack_text()
  _enqueue_filtered(L_INFO, message, source_tag, st, push_to_editor)


## Logs debug-level line when config is Debug.
func debug(message: String, push_to_editor: bool = false, source_tag: String = "Main", with_stack: bool = false) -> void:
  if _cfg_level < CFG_DEBUG:
    return
  var st := ""
  if with_stack:
    st = _capture_stack_text()
  _enqueue_filtered(L_DEBUG, message, source_tag, st, push_to_editor)
#endregion


#region Config
## Loads merged [code]logging_params[/code] from the **GameConfig** autoload (never reads the JSON file directly).
func _load_config() -> void:
  var gc: Node = get_node_or_null("/root/GameConfig")
  if gc == null:
    _apply_default_config()
    _notify_missing_config("GameConfig autoload missing — check project.godot Autoload order")
    return
  var diag: String = gc.get_config_load_diagnostic()
  if diag != "":
    _notify_missing_config(diag)
  var lp: Variant = gc.get_logging_params()
  if typeof(lp) != TYPE_DICTIONARY:
    _apply_default_config()
    _notify_missing_config("GameConfig.get_logging_params() returned non-object")
    return
  _apply_logging_params(lp)


## Applies default logging behavior from LOGGING_PLAN §4.3 (Error-only, queue defaults).
func _apply_default_config() -> void:
  _cfg_level = CFG_ERROR
  _max_lines_per_process = 128
  _max_queue_entries = 1024


func _apply_logging_params(lp: Dictionary) -> void:
  var lvl_str: String = str(lp.get("LOG_LEVEL", "Error"))
  var parsed := _parse_log_level_string(lvl_str)
  if parsed < 0:
    _cfg_level = CFG_ERROR
    _notify_missing_config("Invalid LOG_LEVEL %s — using Error" % lvl_str)
  else:
    _cfg_level = parsed

  var mlp = lp.get("MAX_LINES_PER_PROCESS", 128)
  if typeof(mlp) in [TYPE_FLOAT, TYPE_INT] and int(mlp) > 0:
    _max_lines_per_process = int(mlp)
  else:
    _max_lines_per_process = 128

  var mqe = lp.get("MAX_QUEUE_ENTRIES", 1024)
  if typeof(mqe) in [TYPE_FLOAT, TYPE_INT] and int(mqe) > 0:
    _max_queue_entries = int(mqe)
  else:
    _max_queue_entries = 1024


func _parse_log_level_string(s: String) -> int:
  match s.strip_edges().to_lower():
    "error":
      return CFG_ERROR
    "info":
      return CFG_INFO
    "debug":
      return CFG_DEBUG
    _:
      return -1


func _notify_missing_config(reason: String) -> void:
  if _missing_config_notified:
    return
  _missing_config_notified = true
  push_error("OLog: %s — using Error-only logging and default queue sizes." % reason)
#endregion


#region Enqueue / eviction
## Enqueues after level gating (caller already filtered for info/debug). Errors always pass.
func _enqueue_filtered(level: int, message: String, source_tag: String, stack: String, push_editor: bool) -> void:
  var msg := _truncate_line(message.replace("\n", " ").replace("\r", " "))
  var tag := _truncate_line(source_tag)
  var unix_time: float = Time.get_unix_time_from_system()

  if push_editor == true:
    call_deferred("_mirror_to_editor_impl", level, msg)

  _mutex.lock()
  while _queue.size() >= _max_queue_entries:
    _evict_one_unlocked()
  var rec := {
    "unix_time": unix_time,
    "level": level,
    "source_tag": tag,
    "message": msg,
    "stack": stack,
    "seq": _enqueue_seq,
  }
  _enqueue_seq += 1
  _queue.append(rec)
  _mutex.unlock()


## Removes one entry using INFO → DEBUG → ERROR tiering and newest-within-tier (seq).
func _evict_one_unlocked() -> void:
  if _queue.is_empty():
    return
  var victim_idx := -1
  var victim_seq := -1
  # Pass 1: INFO
  for i in range(_queue.size()):
    var e: Dictionary = _queue[i]
    if int(e.get("level", L_ERROR)) == L_INFO:
      var s := int(e.get("seq", 0))
      if s > victim_seq:
        victim_seq = s
        victim_idx = i
  if victim_idx >= 0:
    _bump_drop_counter(int(_queue[victim_idx].get("level", L_ERROR)))
    _queue.remove_at(victim_idx)
    return
  victim_seq = -1
  victim_idx = -1
  # Pass 2: DEBUG
  for i in range(_queue.size()):
    var e2: Dictionary = _queue[i]
    if int(e2.get("level", L_ERROR)) == L_DEBUG:
      var s2 := int(e2.get("seq", 0))
      if s2 > victim_seq:
        victim_seq = s2
        victim_idx = i
  if victim_idx >= 0:
    _bump_drop_counter(int(_queue[victim_idx].get("level", L_ERROR)))
    _queue.remove_at(victim_idx)
    return
  victim_seq = -1
  victim_idx = -1
  # Pass 3: ERROR (last resort)
  for i in range(_queue.size()):
    var e3: Dictionary = _queue[i]
    if int(e3.get("level", L_ERROR)) == L_ERROR:
      var s3 := int(e3.get("seq", 0))
      if s3 > victim_seq:
        victim_seq = s3
        victim_idx = i
  if victim_idx >= 0:
    drops_errors_total += 1
    _queue.remove_at(victim_idx)


func _bump_drop_counter(level: int) -> void:
  match level:
    L_INFO:
      drops_info_total += 1
    L_DEBUG:
      drops_debug_total += 1
    L_ERROR:
      drops_errors_total += 1
#endregion


#region Drain / file I/O
## Writes up to [member _max_lines_per_process] records; formats UTC lines on drain.
func _drain_batch() -> void:
  if _stopped_disk_full or _log_file == null:
    return
  _mutex.lock()
  var batch: Array = []
  var n: int = min(_max_lines_per_process, _queue.size())
  for _i in n:
    if _queue.is_empty():
      break
    batch.append(_queue.pop_front())
  _mutex.unlock()
  for rec in batch:
    _write_record(rec)


func _shutdown_drain() -> void:
  set_process(false)
  _mutex.lock()
  var rest: Array = _queue.duplicate()
  _queue.clear()
  _mutex.unlock()
  for rec in rest:
    _write_record(rec)
  if _log_file:
    _log_file.flush()
    _log_file.close()
    _log_file = null


func _write_record(rec: Dictionary) -> void:
  if _stopped_disk_full or _log_file == null:
    return
  if _bytes_written >= LOG_STOP_BYTES:
    _stopped_disk_full = true
    push_error("OLog: log file reached size limit; logging stopped.")
    return
  var unix_time: float = float(rec.get("unix_time", 0.0))
  var level := int(rec.get("level", L_ERROR))
  var source_tag: String = str(rec.get("source_tag", "Main"))
  var message: String = str(rec.get("message", ""))
  var stack: String = str(rec.get("stack", ""))
  var line := _format_primary_line(unix_time, level, source_tag, message)
  _log_file.store_string(line + "\n")
  _bytes_written += line.length() + 1
  _log_file.flush()
  if not stack.is_empty():
    for stack_line in stack.split("\n"):
      var sl := stack_line.strip_edges()
      if sl.is_empty():
        continue
      var cont := _format_primary_line(unix_time, level, source_tag, sl)
      _log_file.store_string(cont + "\n")
      _bytes_written += cont.length() + 1
      _log_file.flush()


func _ensure_logs_dir() -> void:
  var mk_err := DirAccess.make_dir_recursive_absolute("user://logs")
  if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
    push_warning("OLog: user://logs mkdir failed: %s" % mk_err)
  var d := DirAccess.open("user://")
  if d == null:
    push_warning("OLog: DirAccess.open user:// failed")
    return
  if not d.dir_exists("logs"):
    var err := d.make_dir_recursive("logs")
    if err != OK:
      push_warning("OLog: user://logs mkdir failed: %s" % err)


## Builds `user://logs/<slug>.log` from [code]application/config/name[/code].
func _resolve_log_file_path() -> String:
  var pname: String = str(ProjectSettings.get_setting("application/config/name", "game"))
  var slug := _slugify_project_name(pname)
  return "user://logs/%s.log" % slug


func _slugify_project_name(s: String) -> String:
  var out := ""
  for i in range(s.length()):
    var c: String = s.substr(i, 1)
    if _char_is_ascii_alnum(c):
      out += c.to_lower()
    else:
      out += "_"
  while out.find("__") >= 0:
    out = out.replace("__", "_")
  out = out.strip_edges()
  while out.begins_with("_"):
    out = out.substr(1)
  while out.ends_with("_"):
    out = out.substr(0, out.length() - 1)
  return out if not out.is_empty() else "game"


## Returns true if [param c] is a single ASCII letter or digit (slug safe segment).
func _char_is_ascii_alnum(c: String) -> bool:
  if c.length() != 1:
    return false
  var u: int = c.unicode_at(0)
  return (u >= 48 and u <= 57) or (u >= 65 and u <= 90) or (u >= 97 and u <= 122)


func _open_log_file_append() -> void:
  var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_log_path) else FileAccess.WRITE_READ
  _log_file = FileAccess.open(_log_path, mode)
  if _log_file == null:
    push_error("OLog: cannot open log file at %s" % _log_path)
    return
  _log_file.seek_end()
  _bytes_written = int(_log_file.get_length())
#endregion


#region Formatting
## Whole-second UNIX timestamp for [method Time.get_datetime_dict_from_unix_time] (expects int, not float).
@warning_ignore("narrowing_conversion")
func _unix_seconds_floor(unix_time: float) -> int:
  return int(floor(unix_time))


## Primary line: `[timestamp] | LEVEL | source_tag | message` with UTC from unix_time.
func _format_primary_line(unix_time: float, level: int, source_tag: String, message: String) -> String:
  # Godot returns UTC components for get_datetime_dict_from_unix_time (single-arg API).
  var dt: Dictionary = Time.get_datetime_dict_from_unix_time(_unix_seconds_floor(unix_time)) as Dictionary
  var frac: float = absf(fmod(unix_time, 1.0))
  var ms_val: int = _fraction_to_ms_four_digits(frac)
  var dd := "%02d" % _dict_int(dt, "day", 1)
  var mm := "%02d" % _dict_int(dt, "month", 1)
  var yyyy := "%04d" % _dict_int(dt, "year", 1970)
  var hh := "%02d" % _dict_int(dt, "hour", 0)
  var mi := "%02d" % _dict_int(dt, "minute", 0)
  var ss := "%02d" % _dict_int(dt, "second", 0)
  var ms4 := "%04d" % ms_val
  var lvl_name := _level_to_label(level)
  var ts := "%s-%s-%s %s:%s:%s:%s UTC" % [dd, mm, yyyy, hh, mi, ss, ms4]
  return "[%s] | %s | %s | %s" % [ts, lvl_name, source_tag, message]


## Maps fractional seconds to a 0–9999 millisecond field for the log timestamp.
@warning_ignore("narrowing_conversion")
func _fraction_to_ms_four_digits(frac: float) -> int:
  return int(round(frac * 1000.0)) % 10000


## Coerces a datetime field from [Time] dictionaries to int without narrowing warnings.
@warning_ignore("narrowing_conversion")
func _dict_int(d: Dictionary, key: StringName, fallback: int) -> int:
  var v: Variant = d.get(key, fallback)
  if typeof(v) == TYPE_FLOAT:
    return int(round(v))
  return int(v)


func _level_to_label(level: int) -> String:
  match level:
    L_ERROR:
      return "ERROR"
    L_INFO:
      return "INFO"
    L_DEBUG:
      return "DEBUG"
    _:
      return "?"


func _truncate_line(s: String) -> String:
  if s.length() <= MAX_LOG_LINE_CHARS:
    return s
  return s.substr(0, MAX_LOG_LINE_CHARS) + " [truncated]"
#endregion


#region Editor mirror + stack
## Deferred so mirrors run on main thread after worker calls.
func _mirror_to_editor_impl(level: int, message: String) -> void:
  match level:
    L_ERROR:
      push_error(message)
    L_INFO:
      push_warning(message)
    L_DEBUG:
      print(message)


## Captures a multi-line stack string (one frame per line) for optional logging.
func _capture_stack_text() -> String:
  var frames: Array = get_stack()
  var lines: PackedStringArray = PackedStringArray()
  # Skip frames inside OLog (adjust count if refactors change depth).
  var skip := 2
  for i in range(skip, frames.size()):
    var f: Dictionary = frames[i]
    var fn: String = str(f.get("function", "?"))
    var src: String = str(f.get("source", "?"))
    var ln: int = int(f.get("line", 0))
    lines.append("  %s — %s:%d" % [fn, src.get_file(), ln])
  return "\n".join(lines)
#endregion
