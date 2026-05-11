extends Node
## Autoload AI driver for remote TinyLlama control flow.
## Owns session state, request ordering, and virtual intent updates.

signal ai_session_state_changed(state: int)
signal ai_inference_started(request_id: int)
signal ai_inference_finished(action_token: String)

enum State {
  IDLE,
  ARMED,
  PLAYING,
  WAITING,
}

const CELL_SIZE: int = 24
const _TOKENS := preload("res://AI_int_lib/ai_action_tokens.gd")
const _WIRE := preload("res://AI_int_lib/perception_wire.gd")
const _SAMPLING := preload("res://AI_int_lib/perception_sampling.gd")

const _SYSTEM_PROMPT_PATH := "res://AI_int_lib/system_prompt.txt"
const _ARMED_HANDSHAKE_USER := "ARMED"
const _LauncherScript := preload("res://AI_int_lib/bundled_inference_launcher.gd")
const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")
## Max characters of model [code]content[/code] included in [method OLog.debug] lines (avoid huge perception blobs in logs).
const _TL_DEBUG_CONTENT_MAX_CHARS: int = 200

var _state: State = State.IDLE
var _main: Node = null
var _player: Area2D = null
var _inference_client: Dictionary = {}
var _system_prompt: String = ""

var _http_request: HTTPRequest
var _latest_snapshot: String = ""
var _has_snapshot: bool = false
var _physics_ticks: int = 0

var _request_id_counter: int = 0
var _latest_enqueued_request_id: int = -1
var _inflight_request_id: int = -1
var _next_inference_ms: int = 0
var _last_inference_url: String = ""

var _bundled_launcher: Node

## True while [method arm_ai_session] is in progress (awaiting bundled inference). Prevents overlapping arms.
var _arm_session_in_progress: bool = false

## Monotonic id for each [method arm_ai_session] entry; helps detect overlapping arms in NDJSON (debug).
static var _debug_arm_invoke_seq: int = 0


func _ready() -> void:
  _system_prompt = FileAccess.get_file_as_string(_SYSTEM_PROMPT_PATH).strip_edges()
  _http_request = HTTPRequest.new()
  add_child(_http_request)
  _http_request.request_completed.connect(_on_http_request_completed)
  _bundled_launcher = _LauncherScript.new()
  add_child(_bundled_launcher)
  _refresh_inference_client_config()
  set_physics_process(true)
  set_process(true)


## Registers scene references used for round lifecycle hooks and snapshot sampling.
## Params:
## - main_node: Main scene root node.
## Returns / side effects:
## - Stores references and emits current state to listeners.
## Usage:
## - Call once from Main._ready().
func attach_main(main_node: Node) -> void:
  _main = main_node
  _player = _main.get_node_or_null("Player") as Area2D
  emit_signal("ai_session_state_changed", int(_state))


## True when human Start input must be ignored by HUD/Main.
## Params:
## - none
## Returns:
## - true only while a round is already running ([enum State.PLAYING]); false in [enum State.ARMED] so the player can press Start to begin the AI round if the model did not emit [code]START[/code] alone.
func is_human_start_suppressed() -> bool:
  return _state == State.PLAYING


## Returns current AI session state enum encoded as int.
## Params:
## - none
## Returns:
## - One value from AiDriver.State.
## Usage:
## - HUD/Main use this for initial control sync.
func get_state() -> int:
  return int(_state)


## Pure helper for latest-enqueued request ordering checks.
## Params:
## - response_id: Request id attached to the completed response.
## - latest_enqueued_request_id: Most recent outbound request id.
## Returns:
## - true only when the response should be applied.
## Usage:
## - Used by runtime response handling and headless tests.
static func should_apply_response_id(response_id: int, latest_enqueued_request_id: int) -> bool:
  return response_id == latest_enqueued_request_id


## Maps [constant HTTPRequest.RESULT_*] to a short label for logs.
static func http_request_result_label(result: int) -> String:
  match result:
    HTTPRequest.RESULT_SUCCESS:
      return "SUCCESS"
    HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
      return "CHUNKED_BODY_SIZE_MISMATCH"
    HTTPRequest.RESULT_CANT_CONNECT:
      return "CANT_CONNECT"
    HTTPRequest.RESULT_CANT_RESOLVE:
      return "CANT_RESOLVE"
    HTTPRequest.RESULT_CONNECTION_ERROR:
      return "CONNECTION_ERROR"
    HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
      return "TLS_HANDSHAKE_ERROR"
    HTTPRequest.RESULT_NO_RESPONSE:
      return "NO_RESPONSE"
    HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
      return "BODY_SIZE_LIMIT_EXCEEDED"
    HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
      return "BODY_DECOMPRESS_FAILED"
    HTTPRequest.RESULT_REQUEST_FAILED:
      return "REQUEST_FAILED"
    HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
      return "DOWNLOAD_FILE_CANT_OPEN"
    HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
      return "DOWNLOAD_FILE_WRITE_ERROR"
    HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
      return "REDIRECT_LIMIT_REACHED"
    HTTPRequest.RESULT_TIMEOUT:
      return "TIMEOUT"
    _:
      return "UNKNOWN_%s" % result


## Returns the exact ARMED handshake payload string.
## Params:
## - none
## Returns:
## - Literal ARMED user-message text.
## Usage:
## - Headless tests verify this does not drift.
func get_armed_handshake_user() -> String:
  return _ARMED_HANDSHAKE_USER


## Arms an AI session if inference config is valid.
## Params:
## - none
## Returns / side effects:
## - Returns false when required config is missing or the inference endpoint cannot be reached; true when state becomes ARMED.
## Usage:
## - Call when HUD "AI Player" is pressed (await from an async caller — this function uses [code]await[/code] internally).
func arm_ai_session() -> bool:
  if _arm_session_in_progress:
    #region agent log
    _AgentNdjson.write({
      "runId": "ai-arm",
      "hypothesisId": "H4",
      "location": "ai_driver.gd:arm_rejected_reentrant",
      "message": "arm_ai_session_skipped_already_in_progress",
      "data": {},
    })
    #endregion
    return false
  _arm_session_in_progress = true
  _debug_arm_invoke_seq += 1
  var invoke_id := _debug_arm_invoke_seq
  _refresh_inference_client_config()
  var base_url := str(_inference_client.get("INFERENCE_BASE_URL", "")).strip_edges()
  var model_id := str(_inference_client.get("MODEL_ID", "")).strip_edges()
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H4",
    "location": "ai_driver.gd:arm_enter",
    "message": "arm_ai_session_entry",
    "data": {
      "invoke_id": invoke_id,
      "base_url_nonempty": not base_url.is_empty(),
      "model_id_nonempty": not model_id.is_empty(),
    },
  })
  #endregion
  if base_url.is_empty() or model_id.is_empty():
    OLog.error(
      "AiDriver: cannot arm — set inference_client.INFERENCE_BASE_URL and MODEL_ID "
      + "(user://game_config.json overrides res://game_config.json template).",
      true,
      "AiDriver"
    )
    _arm_session_in_progress = false
    return false
  var inf_ok: bool = await _bundled_launcher.ensure_inference_endpoint_ready(_inference_client)
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H1,H3,H4",
    "location": "ai_driver.gd:after_ensure",
    "message": "ensure_inference_endpoint_ready_returned",
    "data": {"invoke_id": invoke_id, "ok": inf_ok},
  })
  #endregion
  if not inf_ok:
    #region agent log
    _AgentNdjson.write({
      "runId": "ai-arm",
      "hypothesisId": "H1,H3,H5",
      "location": "ai_driver.gd:arm_failed_inference",
      "message": "arm_ai_session_inference_not_ready",
      "data": {"invoke_id": invoke_id},
    })
    #endregion
    _arm_session_in_progress = false
    return false
  _set_state(State.ARMED)
  if _player != null and _player.has_method("set_control_mode"):
    _player.call("set_control_mode", 1) # Player.ControlMode.AI
  if _player != null and _player.has_method("set_ai_move_dir"):
    _player.call("set_ai_move_dir", Vector2.ZERO)
  _has_snapshot = false
  _latest_snapshot = ""
  _next_inference_ms = Time.get_ticks_msec()
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H4",
    "location": "ai_driver.gd:arm_success",
    "message": "arm_ai_session_complete",
    "data": {"invoke_id": invoke_id, "emit_state_enum": get_state()},
  })
  #endregion
  _arm_session_in_progress = false
  return true


## Aborts an armed handshake without calling [method Main.new_game]; restores human control and IDLE UI.
## Params:
## - none
## Returns / side effects:
## - No-op unless current state is [enum State.ARMED].
## Usage:
## - HUD "Cancel" during setup, or automatic cleanup after a failed handshake HTTP response.
func cancel_armed_session() -> void:
  if _state != State.ARMED:
    return
  _http_request.cancel_request()
  _inflight_request_id = -1
  if _player != null and _player.has_method("set_control_mode"):
    _player.call("set_control_mode", 0)
  if _player != null and _player.has_method("set_ai_move_dir"):
    _player.call("set_ai_move_dir", Vector2.ZERO)
  _set_state(State.IDLE)


## Notifies the driver that Main.new_game() completed.
## Params:
## - none
## Returns / side effects:
## - Updates state and resets round-scoped transient fields.
## Usage:
## - Call at the end of Main.new_game().
func notify_main_new_game() -> void:
  _has_snapshot = false
  _latest_snapshot = ""
  _physics_ticks = 0
  _next_inference_ms = Time.get_ticks_msec()
  match _state:
    State.ARMED:
      _set_state(State.PLAYING)
      if _player != null and _player.has_method("set_control_mode"):
        _player.call("set_control_mode", 1)
    State.WAITING:
      _set_state(State.IDLE)
      if _player != null and _player.has_method("set_control_mode"):
        _player.call("set_control_mode", 0)
    _:
      if _player != null and _player.has_method("set_control_mode"):
        _player.call("set_control_mode", 0)


## Notifies the driver that Main.game_over() completed.
## Params:
## - none
## Returns / side effects:
## - Transitions to WAITING and clears movement intent/inference cadence.
## Usage:
## - Call from Main.game_over().
func notify_main_game_over() -> void:
  if _player != null and _player.has_method("set_ai_move_dir"):
    _player.call("set_ai_move_dir", Vector2.ZERO)
  _set_state(State.WAITING)
  _next_inference_ms = 0
  _has_snapshot = false
  _latest_snapshot = ""


func _exit_tree() -> void:
  _request_id_counter = 0
  _latest_enqueued_request_id = -1
  _inflight_request_id = -1
  _has_snapshot = false
  _latest_snapshot = ""
  if _http_request != null:
    _http_request.cancel_request()


func _process(_delta: float) -> void:
  if _state != State.ARMED and _state != State.PLAYING:
    return
  if _inflight_request_id != -1:
    return
  var now_ms := Time.get_ticks_msec()
  if now_ms < _next_inference_ms:
    return
  _enqueue_inference_request()


func _physics_process(_delta: float) -> void:
  if _state != State.PLAYING or _main == null or _player == null:
    return
  _physics_ticks += 1
  var p: Dictionary = GameConfig.get_perception_params()
  var stride := maxi(1, int(p.get("SNAPSHOT_PHYSICS_STRIDE", 1)))
  if _physics_ticks % stride != 0:
    return
  _latest_snapshot = _build_snapshot_blob()
  _has_snapshot = not _latest_snapshot.is_empty()


func _refresh_inference_client_config() -> void:
  _inference_client = GameConfig.get_inference_client()


func _set_state(next_state: State) -> void:
  if _state == next_state:
    return
  _state = next_state
  emit_signal("ai_session_state_changed", int(_state))


func _enqueue_inference_request() -> void:
  _refresh_inference_client_config()
  var user_content := _ARMED_HANDSHAKE_USER if _state == State.ARMED else ""
  if _state == State.PLAYING:
    if not _has_snapshot:
      _next_inference_ms = Time.get_ticks_msec() + int(_inference_client.get("INFERENCE_PERIOD_MS", 250))
      return
    user_content = _latest_snapshot
  var rid := _request_id_counter
  _request_id_counter += 1
  _latest_enqueued_request_id = rid
  var base_url := str(_inference_client.get("INFERENCE_BASE_URL", "")).rstrip("/")
  var path := str(_inference_client.get("CHAT_COMPLETIONS_PATH", "/v1/chat/completions"))
  var url := "%s%s" % [base_url, path]
  _last_inference_url = url
  var req := {
    "model": str(_inference_client.get("MODEL_ID", "")),
    "messages": [
      {"role": "system", "content": _system_prompt},
      {"role": "user", "content": user_content},
    ],
    "max_tokens": int(_inference_client.get("MAX_OUTPUT_TOKENS", 8)),
    "temperature": float(_inference_client.get("TEMPERATURE", 0.0)),
    "stream": false,
  }
  var headers := ["Content-Type: application/json"]
  var api_key := str(_inference_client.get("API_KEY", "")).strip_edges()
  if not api_key.is_empty():
    headers.append("Authorization: Bearer %s" % api_key)
  var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(req))
  if err != OK:
    _inflight_request_id = -1
    _next_inference_ms = Time.get_ticks_msec() + int(_inference_client.get("INFERENCE_PERIOD_MS", 250))
    return
  _inflight_request_id = rid
  _next_inference_ms = Time.get_ticks_msec() + int(_inference_client.get("INFERENCE_PERIOD_MS", 250))
  emit_signal("ai_inference_started", rid)


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  var rid := _inflight_request_id
  _inflight_request_id = -1
  if not should_apply_response_id(rid, _latest_enqueued_request_id):
    return
  if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
    _fail_inference_response(
      "inference HTTP failed (%s, http=%s) url=%s"
      % [http_request_result_label(result), response_code, _last_inference_url]
    )
    return
  var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
  if typeof(parsed) != TYPE_DICTIONARY:
    _fail_inference_response("inference response JSON was not an object")
    return
  var content := _extract_message_content(parsed)
  var token: String = (
    _TOKENS.normalize_completion_token_armed_handshake(content)
    if _state == State.ARMED
    else _TOKENS.normalize_completion_token(content)
  )
  var excerpt := content.strip_edges().replace("\n", " ").replace("\r", " ")
  if excerpt.length() > _TL_DEBUG_CONTENT_MAX_CHARS:
    excerpt = excerpt.substr(0, _TL_DEBUG_CONTENT_MAX_CHARS) + " [truncated]"
  OLog.debug("TL completion raw=\"%s\" → token=%s" % [excerpt, token], true, "AiDriver")
  _apply_action_token(token)
  emit_signal("ai_inference_finished", token)


func _fail_inference_response(reason: String) -> void:
  emit_signal("ai_inference_finished", "noop")
  if _state != State.ARMED:
    return
  OLog.error("AiDriver: %s — cancel AI setup." % reason, true, "AiDriver")
  cancel_armed_session()


func _extract_message_content(resp: Dictionary) -> String:
  var choices: Variant = resp.get("choices", [])
  if typeof(choices) != TYPE_ARRAY or choices.is_empty():
    return ""
  var first: Variant = choices[0]
  if typeof(first) != TYPE_DICTIONARY:
    return ""
  var message: Variant = first.get("message", {})
  if typeof(message) != TYPE_DICTIONARY:
    return ""
  return str(message.get("content", ""))


func _apply_action_token(token: String) -> void:
  if token == "START":
    if _state == State.ARMED and _main != null and _main.has_method("new_game"):
      _main.call_deferred("new_game")
    return
  if _player == null or not _player.has_method("set_ai_move_dir"):
    return
  var dir := Vector2.ZERO
  match token:
    "UP":
      dir = Vector2(0, -1)
    "DOWN":
      dir = Vector2(0, 1)
    "LEFT":
      dir = Vector2(-1, 0)
    "RIGHT":
      dir = Vector2(1, 0)
    _:
      return
  _player.call("set_ai_move_dir", dir)


func _build_snapshot_blob() -> String:
  if _main == null or _player == null:
    return ""
  var viewport_size := (_player.get("screen_size") as Vector2)
  if viewport_size == Vector2.ZERO:
    viewport_size = _player.get_viewport_rect().size
  var cols := int(ceil(viewport_size.x / float(CELL_SIZE)))
  var rows := int(ceil(viewport_size.y / float(CELL_SIZE)))
  if cols <= 0 or rows <= 0:
    return ""

  var grid: Array = []
  for _r in rows:
    var row := PackedInt32Array()
    row.resize(cols)
    grid.append(row)

  var player_sample := _SAMPLING.sampling_from_collision_object(_player)
  var player_point: Vector2 = player_sample.get("point", _player.global_position)
  var player_ext: Vector3 = player_sample.get("half_extents", Vector3.ZERO)
  var player_cell := _world_to_cell(player_point, cols, rows)

  var mobs: Array[Dictionary] = []
  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var mob := n as RigidBody2D
      var mob_sample := _SAMPLING.sampling_from_collision_object(mob)
      var mob_point: Vector2 = mob_sample.get("point", mob.global_position)
      mobs.append({
        "node": mob,
        "sample": mob_sample,
        "dist": mob_point.distance_to(player_point),
        "id": mob.get_instance_id(),
      })
  mobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
    var da: float = a["dist"]
    var db: float = b["dist"]
    if is_equal_approx(da, db):
      return int(a["id"]) < int(b["id"])
    return da < db
  )

  for info in mobs:
    var mob_point: Vector2 = info["sample"].get("point", Vector2.ZERO)
    var mob_cell := _world_to_cell(mob_point, cols, rows)
    var cur := int(grid[mob_cell.x][mob_cell.y])
    if mob_cell == player_cell:
      grid[mob_cell.x][mob_cell.y] = 3
    elif cur == 0:
      grid[mob_cell.x][mob_cell.y] = 2

  var pcur := int(grid[player_cell.x][player_cell.y])
  grid[player_cell.x][player_cell.y] = 3 if pcur == 2 else 1

  var lines: PackedStringArray = []
  lines.append(_WIRE.format_header_line(Time.get_ticks_msec(), int(_main.get("score")), cols, rows, CELL_SIZE))
  for r in rows:
    var s := ""
    var row_arr: PackedInt32Array = grid[r]
    for c in cols:
      s += str(row_arr[c])
    lines.append(s)
  var player_vel := Vector3.ZERO
  if _player.has_method("get"):
    player_vel = Vector3((_player.get("current_velocity") as Vector2).x, (_player.get("current_velocity") as Vector2).y, 0.0)
  lines.append(_WIRE.format_entity_velocity_line("PLAYER", player_cell.x, player_cell.y, player_vel))
  lines.append(_WIRE.format_entity_extents_line("PLAYER_EXT", player_ext))

  for info in mobs:
    var mob: RigidBody2D = info["node"]
    var mob_sample: Dictionary = info["sample"]
    var mob_point: Vector2 = mob_sample.get("point", mob.global_position)
    var mob_cell := _world_to_cell(mob_point, cols, rows)
    var mob_vel := Vector3(mob.linear_velocity.x, mob.linear_velocity.y, 0.0)
    var mob_ext: Vector3 = mob_sample.get("half_extents", Vector3.ZERO)
    lines.append(_WIRE.format_entity_velocity_line("MOB", mob_cell.x, mob_cell.y, mob_vel))
    lines.append(_WIRE.format_entity_extents_line("MOB_EXT", mob_ext))

  return "\n".join(lines)


func _world_to_cell(world_pos: Vector2, cols: int, rows: int) -> Vector2i:
  var c := clampi(int(floor(world_pos.x / float(CELL_SIZE))), 0, cols - 1)
  var r := clampi(int(floor(world_pos.y / float(CELL_SIZE))), 0, rows - 1)
  return Vector2i(r, c)
