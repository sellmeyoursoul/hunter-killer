extends RefCounted
## Appends one JSON line to Cursor debug NDJSON (`res://debug-e87b37.log`). Also mirrors to `user://` when project write fails or always for redundancy. No secrets.


const SESSION_ID := "e87b37"
const _REL_PATH := "res://debug-e87b37.log"
const _USER_MIRROR := "user://debug-e87b37.log"


static func write(entry: Dictionary) -> void:
  var payload := entry.duplicate(true)
  payload["sessionId"] = SESSION_ID
  if not payload.has("timestamp"):
    payload["timestamp"] = int(Time.get_unix_time_from_system() * 1000.0)
  var line := JSON.stringify(payload)
  var project_abs := ProjectSettings.globalize_path(_REL_PATH).replace("\\", "/")
  var ok_project := _append_line_ndjson(project_abs, line)
  var user_abs := ProjectSettings.globalize_path(_USER_MIRROR).replace("\\", "/")
  var ok_user := _append_line_ndjson(user_abs, line)
  if not ok_project and not ok_user:
    push_error(
      "AgentNdjsonSink: cannot write NDJSON (project=%s user=%s)" % [project_abs, user_abs]
    )


## Params:
## - abs_path: Absolute filesystem path (forward slashes ok).
## - line: One NDJSON line (no newline inside).
## Returns:
## - true when the line was appended.
static func _append_line_ndjson(abs_path: String, line: String) -> bool:
  var f: FileAccess = null
  if FileAccess.file_exists(abs_path):
    f = FileAccess.open(abs_path, FileAccess.READ_WRITE)
    if f != null:
      f.seek_end()
  else:
    f = FileAccess.open(abs_path, FileAccess.WRITE)
  if f == null:
    push_warning("AgentNdjsonSink: open failed err=%s path=%s" % [FileAccess.get_open_error(), abs_path])
    return false
  f.store_line(line)
  f.close()
  return true
