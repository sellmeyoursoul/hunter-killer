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
const _RISK := preload("res://AI_int_lib/perception_risk_hints.gd")
const _SAMPLING := preload("res://AI_int_lib/perception_sampling.gd")
const _MOTOR := preload("res://creature/motor/cardinal_avoidance.gd")
const _PlayerScr := preload("res://player.gd")
const _IntentHoldScr := preload("res://creature/motor/scripted_intent_hold.gd")
const _JeopardyTurnScr := preload("res://creature/motor/jeopardy_forced_turn.gd")
const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")
const _Merge := preload("res://AI_int_lib/game_config_merge.gd")

const _SYSTEM_PROMPT_PATH := "res://AI_int_lib/system_prompt.txt"
const _ARMED_HANDSHAKE_USER := "ARMED"
## Separates system rules from handshake / observation in one [code]/v1/completions[/code] prompt (no chat roles).
const _COMPLETION_PROMPT_SEPARATOR := "\n\n---\n\n"
## Appended after the user blob so the last tokens prime a single-token reply (completions continue from context end).
const _COMPLETION_OUTPUT_TRAILER_ARMED := (
  "\n\n=== YOUR_TURN ===\n"
  + "The line above is the handshake payload only.\n"
  + "Reply with exactly one token: START in ALL CAPS. No other characters or words.\n"
)
const _COMPLETION_OUTPUT_TRAILER_PLAYING := (
  "\n\n=== YOUR_TURN ===\n"
  + "The block above is the observation snapshot for this tick.\n"
  + "Read PLAIN_HINT and RISK_HINTS before interpreting the ASCII grid.\n"
  + "Reply with exactly one movement token: UP, DOWN, LEFT, or RIGHT in ALL CAPS. No other characters or words.\n"
)


## GBNF passed to llama.cpp [code]/v1/completions[/code] as [code]grammar[/code] so tiny models cannot drift into newlines or prompt echo.
## Params:
## - state_enum: [enum State] encoded as int ([code]1[/code] ARMED, [code]2[/code] PLAYING).
## Returns:
## - Grammar string, or empty when grammar does not apply.
static func gbnf_for_completion_state_enum(state_enum: int) -> String:
  match state_enum:
    1:
      return "root ::= \"START\"\n"
    2:
      return "root ::= \"UP\" | \"DOWN\" | \"LEFT\" | \"RIGHT\"\n"
    _:
      return ""


## Maps merged [code]creature_motor.mode[/code] to [code]player.gd[/code] control int when **ARMED → PLAYING** ([method notify_main_new_game]); unknown modes map to ENGINE (same rule as [code]_creature_motor_mode[/code]).
## Params:
## - motor_mode: Raw [code]mode[/code] string from merged config (case-insensitive).
## Returns:
## - [code]ai_control_as_int()[/code] for [code]llm[/code], else [code]engine_control_as_int()[/code] on the preloaded player script.
static func playing_control_mode_int_for_motor_mode_string(motor_mode: String) -> int:
  var norm := str(motor_mode).to_lower().strip_edges()
  return _PlayerScr.ai_control_as_int() if norm == "llm" else _PlayerScr.engine_control_as_int()


const _LauncherScript := preload("res://AI_int_lib/bundled_inference_launcher.gd")
const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")
## Max characters of model [code]content[/code] included in [method OLog.debug] lines (avoid huge perception blobs in logs).
const _TL_DEBUG_CONTENT_MAX_CHARS: int = 200

#region agent log
const _DBG46_SESSION := "46c25f"
const _DBG46_REL := "res://debug-46c25f.log"


## Appends one NDJSON line for debug session 46c25f (no API keys, no full blobs).
static func _dbg46_emit(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
  var payload := {
    "sessionId": _DBG46_SESSION,
    "runId": run_id,
    "hypothesisId": hypothesis_id,
    "location": location,
    "message": message,
    "data": data,
    "timestamp": int(Time.get_unix_time_from_system() * 1000.0),
  }
  var line := JSON.stringify(payload)
  var abs_path := ProjectSettings.globalize_path(_DBG46_REL).replace("\\", "/")
  var f: FileAccess = null
  if FileAccess.file_exists(abs_path):
    f = FileAccess.open(abs_path, FileAccess.READ_WRITE)
    if f != null:
      f.seek_end()
  else:
    f = FileAccess.open(abs_path, FileAccess.WRITE)
  if f == null:
    return
  f.store_line(line)
  f.close()
#endregion

var _state: State = State.IDLE
var _main: Node = null
var _creature: CharacterBody2D = null
var _inference_client: Dictionary = {}
var _system_prompt: String = ""

var _http_request: HTTPRequest
var _latest_snapshot: String = ""
var _has_snapshot: bool = false
var _physics_ticks: int = 0

## Last mob samples passed to the cardinal motor ([method _build_motor_context]); duplicated for the awareness debug overlay.
var _debug_last_motor_mobs: Array = []

var _request_id_counter: int = 0
var _latest_enqueued_request_id: int = -1
var _inflight_request_id: int = -1
var _next_inference_ms: int = 0
var _last_inference_url: String = ""

## Throttles editor-facing [code]noop[/code] diagnostics so tiny models at high cadence do not flood Output.
var _noop_diag_last_ms: int = 0

## Last completions request shape for Cursor NDJSON debug (session 46c25f).
var _last_request_used_completions: bool = false
var _last_prompt_tail: String = ""
var _last_user_head: String = ""
var _last_completion_grammar: String = ""

var _bundled_launcher: Node

## Persisted challenger streak state for scripted motor oscillation damping (keys `challenger`, `frames`; see scripted_intent_hold.gd).
var _scripted_intent_hold_state: Dictionary = {}
var _jeopardy_forced_turn_state: Dictionary = {}

## Ring buffer of mob snapshots for motor memory: each entry maps [code]RigidBody2D.get_instance_id()[/code] to [code]{ "position", "velocity" }[/code].
var _mob_hist: Array = []

## Instance ids of mobs that have been inside effective awareness at least once this round; gates extrapolated [code]gated[/code] samples and [code]ghost[/code] entries to observed mobs only.
var _mob_ids_ever_observed: Dictionary = {}

## True while [method arm_ai_session] is in progress (awaiting bundled inference) or a synchronous CPU arm is finishing.
var _arm_session_in_progress: bool = false

## When true from [method begin_engine_player_round], [method _creature_motor_mode] behaves as scripted (local motor only) until round end.
var _cpu_player_round_active: bool = false

## Coarse grid cell centers visited this round (coverage memory); last append is current cell (stripped before motor).
var _explore_trail_centers: Array = []
var _explore_trail_last_cell: Vector2i = Vector2i(2147483647, 2147483647)

## Monotonic id for each [method arm_ai_session] entry; helps detect overlapping arms in NDJSON (debug).
static var _debug_arm_invoke_seq: int = 0


## Returns merged [code]creature_motor[/code] from autoload [code]GameConfig[/code], or merge defaults when absent (headless tool loads).
func _live_creature_motor_params() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_creature_motor_params"):
    return g.call("get_creature_motor_params") as Dictionary
  return (_Merge.default_root()["creature_motor"] as Dictionary).duplicate(true)


## Returns merged [code]perception[/code] dict (same fallback pattern as [_live_creature_motor_params]).
func _live_perception_params() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_perception_params"):
    return g.call("get_perception_params") as Dictionary
  return _Merge.default_perception_params().duplicate(true)


## Returns merged [code]inference_client[/code] dict (same fallback pattern as [_live_creature_motor_params]).
func _live_inference_client() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_inference_client"):
    return g.call("get_inference_client") as Dictionary
  return (_Merge.default_root()["inference_client"] as Dictionary).duplicate(true)


## Clears ENGINE coverage trail (new round, attach, or session end).
func _explore_trail_reset() -> void:
  _explore_trail_centers.clear()
  _explore_trail_last_cell = Vector2i(2147483647, 2147483647)


## Records a trail sample when [param world] enters a new coarse grid cell ([code]explore_coverage_cell_px[/code] from [param motor_p]).
## Params:
## - world: Player world position.
## - motor_p: Merged [code]creature_motor[/code].
## Returns:
## - none
func _explore_trail_record(world: Vector2, motor_p: Dictionary) -> void:
  var cell_px := maxf(16.0, float(motor_p.get("explore_coverage_cell_px", 52.0)))
  var ix := int(floorf(world.x / cell_px))
  var iy := int(floorf(world.y / cell_px))
  var c := Vector2i(ix, iy)
  if c == _explore_trail_last_cell:
    return
  _explore_trail_last_cell = c
  var center := Vector2((float(ix) + 0.5) * cell_px, (float(iy) + 0.5) * cell_px)
  _explore_trail_centers.append(center)
  var cap := maxi(8, int(motor_p.get("explore_trail_max_cells", 96)))
  while _explore_trail_centers.size() > cap:
    _explore_trail_centers.pop_front()


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
  _creature = _main.get_node_or_null("Player") as CharacterBody2D
  Callable(_IntentHoldScr, &"reset_state").call(_scripted_intent_hold_state)
  Callable(_JeopardyTurnScr, &"reset_state").call(_jeopardy_forced_turn_state)
  _mob_hist.clear()
  _mob_ids_ever_observed.clear()
  _explore_trail_reset()
  emit_signal("ai_session_state_changed", int(_state))


## True when human Start input must be ignored by HUD/Main.
## Params:
## - none
## Returns:
## - true while [enum State.ARMED] (round begins after **AI Player** without a separate Start) or [enum State.PLAYING].
func is_human_start_suppressed() -> bool:
  return _state == State.ARMED or _state == State.PLAYING


## Returns current AI session state enum encoded as int.
## Params:
## - none
## Returns:
## - One value from AiDriver.State.
## Usage:
## - HUD/Main use this for initial control sync.
func get_state() -> int:
  return int(_state)


## Debug-only copy of [member _debug_last_motor_mobs] (deep duplicate safe for overlay readers).
## Params:
## - none
## Returns:
## - Array of mob dicts with [code]position[/code], [code]velocity[/code], [code]cost_scale[/code], optional [code]_motor_debug_source[/code] ([code]live[/code] | [code]gated[/code] | [code]ghost[/code]).
func get_debug_motor_mobs_snapshot() -> Array:
  return _debug_last_motor_mobs.duplicate(true)


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


## Flattens OpenAI-style [code]message.content[/code] (string, array of typed blocks, or null) to plain text.
## Params:
## - v: Raw JSON value from [code]choices[0].message.content[/code].
## Returns:
## - Concatenated assistant-visible text; empty string when absent.
static func coerce_openai_message_content_value(v: Variant) -> String:
  if v == null:
    return ""
  var t := typeof(v)
  if t == TYPE_STRING:
    return str(v)
  if t == TYPE_ARRAY:
    var out := ""
    for item in v as Array:
      if typeof(item) == TYPE_DICTIONARY:
        var d: Dictionary = item
        var typ := str(d.get("type", "text"))
        # llama.cpp OAI paths may emit output_text / input_text blocks, not only "text".
        if typ == "text" or typ == "output_text" or typ == "input_text":
          out += str(d.get("text", ""))
        elif typ == "refusal":
          out += str(d.get("refusal", ""))
      elif typeof(item) == TYPE_STRING:
        out += str(item)
    return out
  return str(v)


## Extracts generated text from an OpenAI-compatible [code]/v1/completions[/code] JSON object.
## Params:
## - resp: Parsed top-level response object.
## Returns:
## - [code]choices[0].text[/code] when present.
static func extract_openai_completion_choice_text(resp: Dictionary) -> String:
  var choices: Variant = resp.get("choices", [])
  if typeof(choices) != TYPE_ARRAY or choices.is_empty():
    return ""
  var first: Variant = choices[0]
  if typeof(first) != TYPE_DICTIONARY:
    return ""
  return str((first as Dictionary).get("text", ""))


## Extracts assistant text from an OpenAI-compatible [code]/v1/chat/completions[/code] JSON object.
## Params:
## - resp: Parsed top-level response object.
## Returns:
## - Non-empty string when [code]choices[0].message.content[/code] (or legacy [code]choices[0].text[/code]) carries text.
static func extract_openai_chat_choice_text(resp: Dictionary) -> String:
  var choices: Variant = resp.get("choices", [])
  if typeof(choices) != TYPE_ARRAY or choices.is_empty():
    return ""
  var first: Variant = choices[0]
  if typeof(first) != TYPE_DICTIONARY:
    return ""
  var choice: Dictionary = first
  var message: Variant = choice.get("message", {})
  if typeof(message) == TYPE_DICTIONARY:
    var msg: Dictionary = message
    var c := coerce_openai_message_content_value(msg.get("content", ""))
    if not c.strip_edges().is_empty():
      return c
  return str(choice.get("text", ""))


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
  _cpu_player_round_active = false
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
    _OLogSafe.error(
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
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _PlayerScr.engine_control_as_int())
  if _creature != null and _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  Callable(_IntentHoldScr, &"reset_state").call(_scripted_intent_hold_state)
  Callable(_JeopardyTurnScr, &"reset_state").call(_jeopardy_forced_turn_state)
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


## Arms a CPU round: scripted motor + [member Player.ControlMode.ENGINE]; no inference or HTTP handshake.
## Params:
## - none
## Returns:
## - False when overlapping arm, already ARMED or PLAYING, or [member Main]/Player not ready.
## Usage:
## - Main HUD "AI Player" when local engine control replaces remote LLM.
func begin_engine_player_round() -> bool:
  if _arm_session_in_progress:
    return false
  if _main == null or _creature == null:
    _OLogSafe.info(
      "AiDriver: cannot start CPU player — attach Main before pressing AI Player.",
      true,
      "AiDriver",
    )
    return false
  if _state == State.PLAYING or _state == State.ARMED:
    return false
  _arm_session_in_progress = true
  _debug_arm_invoke_seq += 1
  var invoke_id := _debug_arm_invoke_seq
  _cpu_player_round_active = true
  _set_state(State.ARMED)
  if _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _PlayerScr.engine_control_as_int())
  if _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  Callable(_IntentHoldScr, &"reset_state").call(_scripted_intent_hold_state)
  Callable(_JeopardyTurnScr, &"reset_state").call(_jeopardy_forced_turn_state)
  _has_snapshot = false
  _latest_snapshot = ""
  _next_inference_ms = Time.get_ticks_msec()
  #region agent log
  _AgentNdjson.write({
    "runId": "cpu-arm",
    "hypothesisId": "HUD",
    "location": "ai_driver.gd:begin_engine_player_round_done",
    "message": "begin_engine_player_round_complete",
    "data": {"invoke_id": invoke_id},
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
  _cpu_player_round_active = false
  _http_request.cancel_request()
  _inflight_request_id = -1
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _PlayerScr.human_control_as_int())
  if _creature != null and _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  Callable(_IntentHoldScr, &"reset_state").call(_scripted_intent_hold_state)
  Callable(_JeopardyTurnScr, &"reset_state").call(_jeopardy_forced_turn_state)
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
  _mob_hist.clear()
  _mob_ids_ever_observed.clear()
  _explore_trail_reset()
  match _state:
    State.ARMED:
      _set_state(State.PLAYING)
      if _creature != null and _creature.has_method("set_control_mode"):
        _creature.call(
          "set_control_mode",
          playing_control_mode_int_for_motor_mode_string(_creature_motor_mode())
        )
    State.WAITING:
      _cpu_player_round_active = false
      _set_state(State.IDLE)
      if _creature != null and _creature.has_method("set_control_mode"):
        _creature.call("set_control_mode", _PlayerScr.human_control_as_int())
    _:
      _cpu_player_round_active = false
      if _creature != null and _creature.has_method("set_control_mode"):
        _creature.call("set_control_mode", _PlayerScr.human_control_as_int())


## Notifies the driver that Main.game_over() completed.
## Params:
## - none
## Returns / side effects:
## - Transitions to WAITING and clears movement intent/inference cadence.
## Usage:
## - Call from Main.game_over().
func notify_main_game_over() -> void:
  _cpu_player_round_active = false
  if _creature != null and _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  _set_state(State.WAITING)
  _next_inference_ms = 0
  _has_snapshot = false
  _latest_snapshot = ""
  _mob_hist.clear()
  _mob_ids_ever_observed.clear()
  _explore_trail_reset()


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
  if _state == State.PLAYING and _creature_motor_mode() == "scripted":
    return
  if _inflight_request_id != -1:
    return
  var now_ms := Time.get_ticks_msec()
  if now_ms < _next_inference_ms:
    return
  _enqueue_inference_request()


## Returns effective motor lane for [method _physics_process] / inference gating:
## **`scripted`** while [member _cpu_player_round_active]; else **`llm`** or **`scripted`** from merged [code]creature_motor.mode[/code].
## Params:
## - none
## Returns:
## - **`scripted`** or **`llm`** (defaults to scripted when absent / unknown mode string).
func _creature_motor_mode() -> String:
  if _cpu_player_round_active:
    return "scripted"
  var cm := _live_creature_motor_params()
  var m := str(cm.get("mode", "scripted")).to_lower().strip_edges()
  if m == "llm":
    return "llm"
  return "scripted"


## Parses [code]creature_motor[/code] boolean that defaults to [code]true[/code] when the key is absent (JSON may use bool or string).
## Params:
## - motor_p: Merged motor section.
## - key: Field name (e.g. [code]shuffle_tie_break[/code]).
## Returns:
## - [code]false[/code] only when the value is explicitly falsey ([code]false[/code], [code]"false"[/code], [code]0[/code], etc.).
func _motor_bool_default_true(motor_p: Dictionary, key: String) -> bool:
  if not motor_p.has(key):
    return true
  var v: Variant = motor_p[key]
  if typeof(v) == TYPE_BOOL:
    return bool(v)
  var s := str(v).to_lower().strip_edges()
  return s not in ["0", "false", "no", "off", ""]


## Distance from mob to creature footprint for awareness gating; mirrors [method CardinalAvoidance.awareness_gate_distance] using [member _MOTOR] for AABB math.
func _awareness_gate_distance_for_driver(
  creature_center: Vector2, creature_half: Vector2, mob_pos: Vector2
) -> float:
  var half := creature_half
  if half.x <= 0.0 or half.y <= 0.0:
    return creature_center.distance_to(mob_pos)
  var closest_c := _MOTOR.closest_point_on_aabb(creature_center, half, mob_pos)
  return mob_pos.distance_to(closest_c)


## Effective reach with forward cone; mirrors [method CardinalAvoidance.effective_awareness_reach].
func _effective_awareness_reach_for_driver(
  creature_center: Vector2,
  mob_pos: Vector2,
  base_radius: float,
  cone_extra: float,
  cone_cos_threshold: float,
  facing: Vector2,
) -> float:
  var reach := base_radius
  if cone_extra > 0.0 and cone_cos_threshold >= -1.0001:
    var delta := mob_pos - creature_center
    var dist := delta.length()
    var u := Vector2.RIGHT
    if dist > 1e-4:
      u = delta / dist
    var f := facing
    if f.length() < 1e-4:
      f = Vector2.RIGHT
    else:
      f = f.normalized()
    if u.dot(f) >= cone_cos_threshold:
      reach = base_radius + cone_extra
  return reach


## Appends a mob field snapshot for memory ghosts ([member _mob_hist]). Drops oldest entries past [code]awareness_memory_ticks[/code].
func _record_mob_history_if_playing() -> void:
  if _main == null:
    return
  var motor_p_hist := _live_creature_motor_params()
  var max_t := int(motor_p_hist.get("awareness_memory_ticks", 3))
  if max_t <= 0:
    _mob_hist.clear()
    _mob_ids_ever_observed.clear()
    return
  var snap: Dictionary = {}
  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var rb := n as RigidBody2D
      snap[rb.get_instance_id()] = {
        "position": rb.global_position,
        "velocity": rb.linear_velocity,
      }
  _mob_hist.append(snap)
  while _mob_hist.size() > max_t:
    _mob_hist.pop_front()


## Collects static obstacles (group [code]obstacles[/code]) as AABBs for the motor ([code]position[/code] + [code]half_extents[/code]).
func _static_obstacles_for_motor() -> Array:
  var out: Array = []
  if _main == null:
    return out
  for n in _main.get_tree().get_nodes_in_group("obstacles"):
    if not n is StaticBody2D:
      continue
    var sb := n as StaticBody2D
    for ch in sb.get_children():
      if ch is CollisionShape2D:
        var cs := ch as CollisionShape2D
        if cs.shape is RectangleShape2D:
          var r := cs.shape as RectangleShape2D
          var he := r.size * 0.5
          out.append({"position": cs.global_position, "half_extents": he})
  return out


## Builds [param mobs] array for [code]CardinalAvoidance[/code]: live entries, unreachable live with memory scale (only if that mob was previously inside effective awareness this round), despawned ghosts (same observed rule).
## Params:
## - motor_p: Merged [code]creature_motor[/code].
## - creature_pos: Creature center (world).
## - he_xy: Footprint half-extents for gating.
## Returns:
## - Array of [code]{ "position", "velocity", "cost_scale", "_motor_debug_source?" }[/code] dicts. [code]_motor_debug_source[/code] is overlay-only; motor ignores it.
func _motor_mobs_array(motor_p: Dictionary, creature_pos: Vector2, he_xy: Vector2) -> Array:
  var out: Array = []
  if _main == null:
    return out
  var awareness_r: float = float(motor_p.get("awareness_radius", 0.0))
  var cone_extra: float = float(motor_p.get("awareness_cone_extra", 0.0))
  var half_deg: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos: float = cos(deg_to_rad(half_deg))
  var facing_v := Vector2.RIGHT
  if _creature != null:
    var fd: Variant = _creature.get("last_move_direction")
    if typeof(fd) == TYPE_VECTOR2:
      var fv := fd as Vector2
      if fv.length() > 1e-4:
        facing_v = fv.normalized()

  var mem_ticks := maxi(0, int(motor_p.get("awareness_memory_ticks", 3)))
  var mem_w: float = float(motor_p.get("awareness_memory_weight", 0.35))
  var horizon: float = float(motor_p.get("awareness_memory_horizon_sec", 0.0))
  if horizon <= 0.0 and mem_ticks > 0:
    horizon = float(mem_ticks) / maxf(1.0, float(Engine.physics_ticks_per_second))

  var live_ids: Dictionary = {}

  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var rb := n as RigidBody2D
      var id := rb.get_instance_id()
      live_ids[id] = true
      var p := rb.global_position
      var v := rb.linear_velocity
      var gated := false
      if awareness_r > 0.0:
        var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, p)
        var eff := _effective_awareness_reach_for_driver(
          creature_pos, p, awareness_r, cone_extra, cone_cos, facing_v
        )
        gated = gd > eff
      if not gated:
        _mob_ids_ever_observed[id] = true
      if gated:
        if mem_ticks > 0 and mem_w > 0.0 and _mob_ids_ever_observed.has(id):
          var pred := p + v * horizon
          out.append({
            "position": pred,
            "velocity": v,
            "cost_scale": mem_w,
            "_motor_debug_source": "gated",
          })
      else:
        out.append({
          "position": p,
          "velocity": v,
          "cost_scale": 1.0,
          "_motor_debug_source": "live",
        })

  if mem_ticks > 0 and mem_w > 0.0 and _mob_hist.size() > 0:
    var ghost_added: Dictionary = {}
    var i := _mob_hist.size() - 1
    while i >= 0:
      var snap: Dictionary = _mob_hist[i]
      for id in snap:
        if live_ids.has(id):
          continue
        if ghost_added.has(id):
          continue
        if not _mob_ids_ever_observed.has(id):
          continue
        var e: Dictionary = snap[id]
        var gp: Vector2 = e.get("position", Vector2.ZERO)
        var gv: Vector2 = e.get("velocity", Vector2.ZERO)
        var pred := gp + gv * horizon
        if awareness_r > 0.0:
          var gd2 := _awareness_gate_distance_for_driver(creature_pos, he_xy, pred)
          var eff2 := _effective_awareness_reach_for_driver(
            creature_pos, pred, awareness_r, cone_extra, cone_cos, facing_v
          )
          if gd2 > eff2:
            continue
        out.append({
          "position": pred,
          "velocity": gv,
          "cost_scale": mem_w,
          "_motor_debug_source": "ghost",
        })
        ghost_added[id] = true
      i -= 1

  return out


## In-awareness [code]food_plants[/code] split by each node's [code]is_pickup_ready_for_motor[/code] (same cone/radius as mob motor gating).
## When [code]awareness_radius <= 0[/code], returns empty lists (no omniscient food seek/avoid); unlike live mob cost, food targets require explicit sensory range.
## Params:
## - motor_p: Merged [code]creature_motor[/code].
## - creature_pos: Creature center (world).
## - he_xy: Footprint half-extents for gating.
## - facing_v: Forward axis for cone reach.
## Returns:
## - Dict with [code]ready[/code] / [code]unready[/code] arrays of [code]Vector2[/code] bush roots.
func _motor_food_plants_in_awareness_by_readiness(
  motor_p: Dictionary, creature_pos: Vector2, he_xy: Vector2, facing_v: Vector2
) -> Dictionary:
  var ready_positions: Array = []
  var unready_positions: Array = []
  if _main == null:
    return {"ready": ready_positions, "unready": unready_positions}
  var awareness_r: float = float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return {"ready": ready_positions, "unready": unready_positions}
  var cone_extra: float = float(motor_p.get("awareness_cone_extra", 0.0))
  var half_deg: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos: float = cos(deg_to_rad(half_deg))
  for n in _main.get_tree().get_nodes_in_group(&"food_plants"):
    if not n.has_method(&"is_pickup_ready_for_motor"):
      continue
    var fp: Vector2 = n.global_position
    var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, fp)
    var eff := _effective_awareness_reach_for_driver(
      creature_pos, fp, awareness_r, cone_extra, cone_cos, facing_v
    )
    if gd > eff:
      continue
    var ready_v: Variant = n.call(&"is_pickup_ready_for_motor")
    if typeof(ready_v) == TYPE_BOOL and bool(ready_v):
      ready_positions.append(fp)
    else:
      unready_positions.append(fp)
  return {"ready": ready_positions, "unready": unready_positions}


## Live mob centers for food-seek survival gating (ungated; all [code]mobs[/code] group [code]RigidBody2D[/code]).
## Params:
## - none
## Returns:
## - Array of [code]Vector2[/code].
func _motor_imminent_mob_positions() -> Array:
  var out: Array = []
  if _main == null:
    return out
  for n in _main.get_tree().get_nodes_in_group(&"mobs"):
    if n is RigidBody2D:
      out.append((n as RigidBody2D).global_position)
  return out


## Derives multipliers so low hunger relaxes center/edge posture costs and shortens scripted intent hold (more map coverage).
## Params:
## - motor_p: Merged [code]creature_motor[/code]; optional [code]hunger_explore_*[/code] keys tune low-calorie exploration (see [code]game_config_merge.default_creature_motor_params[/code]).
## Returns:
## - Dict with [code]interior_mul[/code], [code]edge_mul[/code], [code]hold_mul[/code] in [code](0, 1][/code]; all [code]1.0[/code] when calories full or creature lacks hunger fields.
func _hunger_exploration_modifiers(motor_p: Dictionary) -> Dictionary:
  var calorie_ratio := 1.0
  if _creature != null:
    var c0: Variant = _creature.get("current_calories")
    var n0: Variant = _creature.get("caloric_needs")
    if (typeof(c0) == TYPE_FLOAT or typeof(c0) == TYPE_INT) and (typeof(n0) == TYPE_FLOAT or typeof(n0) == TYPE_INT):
      calorie_ratio = clampf(float(c0) / maxf(1.0, float(n0)), 0.0, 1.0)
  var urgency := 1.0 - calorie_ratio
  var power := float(motor_p.get("hunger_explore_urgency_power", 1.25))
  urgency = clampf(pow(urgency, power), 0.0, 1.0)
  var min_i := float(motor_p.get("hunger_explore_interior_scale_min", 0.16))
  var min_e := float(motor_p.get("hunger_explore_edge_scale_min", 0.16))
  var min_h := float(motor_p.get("hunger_explore_hold_scale_min", 0.2))
  return {
    "interior_mul": lerpf(1.0, min_i, urgency),
    "edge_mul": lerpf(1.0, min_e, urgency),
    "hold_mul": lerpf(1.0, min_h, urgency),
  }


## Builds the dictionary consumed by [code]cardinal_avoidance.pick_best_move_intent[/code].
## Half-extents: JSON [code]creature_half_extent_*[/code] are clamped with [code]maxf(0, …)[/code]; capsule-derived values use the same clamp. Use **positive** JSON values for real footprint scoring ([code]Vector2.ZERO[/code] in context falls back to center-point motor math).
## Params:
## - motor_p: Merged [code]creature_motor[/code] params from [code]GameConfig[/code].
## - hunger_explore: Output of [method _hunger_exploration_modifiers] (optional; empty uses no scaling).
## Returns:
## - Context dict with creature position (playable entity body), bounds, mob samples, and tunables.
func _build_motor_context(motor_p: Dictionary, hunger_explore: Dictionary = {}) -> Dictionary:
  var pos := _creature.global_position
  var spd := 400.0
  var spv: Variant = _creature.get("speed")
  if typeof(spv) == TYPE_FLOAT or typeof(spv) == TYPE_INT:
    spd = float(spv)
  var ss := _creature.get("screen_size") as Vector2
  if ss == Vector2.ZERO:
    ss = _creature.get_viewport_rect().size
  var he_xy := Vector2(
    maxf(0.0, float(motor_p.get("creature_half_extent_x", 13.5))),
    maxf(0.0, float(motor_p.get("creature_half_extent_y", 30.5))),
  )
  if _creature != null:
    var cs := _creature.get_node_or_null("CollisionShape2D") as CollisionShape2D
    if cs != null and cs.shape is CapsuleShape2D:
      var cap := cs.shape as CapsuleShape2D
      he_xy = Vector2(
        maxf(0.0, cap.radius),
        maxf(0.0, cap.radius + cap.height * 0.5),
      )
  var half_deg: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var facing_display := Vector2.RIGHT
  var fd0: Variant = _creature.get("last_move_direction")
  if typeof(fd0) == TYPE_VECTOR2:
    var fv0 := fd0 as Vector2
    if fv0.length() > 1e-4:
      facing_display = fv0.normalized()
  var mobs_arr: Array = _motor_mobs_array(motor_p, pos, he_xy)
  _debug_last_motor_mobs = mobs_arr.duplicate(true)

  var csz := 0.0
  if _creature != null:
    var szv: Variant = _creature.get("creature_size")
    if typeof(szv) == TYPE_FLOAT or typeof(szv) == TYPE_INT:
      csz = float(szv)
  var interior_active := false
  if _creature != null:
    interior_active = int(_creature.get("control_mode")) == _PlayerScr.engine_control_as_int()
  var env_grid: Variant = null
  if _main != null and _main.has_method("get_environment_grid"):
    env_grid = _main.call("get_environment_grid")

  var food_split: Dictionary = _motor_food_plants_in_awareness_by_readiness(
    motor_p, pos, he_xy, facing_display
  )
  var food_targets: Array = food_split["ready"]
  var unready_food_targets: Array = food_split["unready"]
  var w_seek_base := float(motor_p.get("weight_seek_ready_food", 16.0))
  var w_avoid_unready_base := float(motor_p.get("weight_avoid_unready_food", 5.5))
  var imminent_r_cfg := float(motor_p.get("food_seek_imminent_mob_radius_px", 100.0))
  var cr := 1.0
  if _creature != null:
    var ccal: Variant = _creature.get("current_calories")
    var cneed: Variant = _creature.get("caloric_needs")
    if (typeof(ccal) == TYPE_FLOAT or typeof(ccal) == TYPE_INT) and (
      typeof(cneed) == TYPE_FLOAT or typeof(cneed) == TYPE_INT
    ):
      cr = clampf(float(ccal) / maxf(1.0, float(cneed)), 0.0, 1.0)
  var w_seek := 0.0
  if not food_targets.is_empty() and w_seek_base > 0.0 and cr < 0.998:
    var urg := clampf(1.0 - cr, 0.0, 1.0)
    w_seek = w_seek_base * lerpf(0.28, 1.0, pow(urg, 0.85))
  var w_avoid_unready := 0.0
  if not unready_food_targets.is_empty() and w_avoid_unready_base > 0.0 and cr < 0.998:
    var urg2 := clampf(1.0 - cr, 0.0, 1.0)
    w_avoid_unready = w_avoid_unready_base * lerpf(0.22, 1.0, pow(urg2, 0.85))
    if not food_targets.is_empty():
      w_avoid_unready *= float(motor_p.get("food_avoid_unready_scale_when_ready_target", 0.35))
  var w_idle_exp_base := float(motor_p.get("weight_explore_idle_penalty", 10.5))
  var w_turn_exp_base := float(motor_p.get("weight_explore_turn_bias", 0.14))
  var w_idle_exp := 0.0
  var w_turn_exp := 0.0
  var w_trail_rep := 0.0
  var trail_for_motor: Array = []
  if food_targets.is_empty():
    var urg3 := clampf(1.0 - cr, 0.0, 1.0)
    var urg_curve3 := lerpf(0.18, 1.0, pow(urg3, 0.9))
    if w_idle_exp_base > 0.0:
      w_idle_exp = w_idle_exp_base * urg_curve3
    if w_turn_exp_base > 0.0:
      w_turn_exp = w_turn_exp_base * urg_curve3
    var w_trail_base := float(motor_p.get("weight_explore_trail_repulsion", 2.35))
    if w_trail_base > 0.0:
      w_trail_rep = w_trail_base * urg_curve3
    trail_for_motor = _explore_trail_centers.duplicate()
    if trail_for_motor.size() > 1:
      trail_for_motor.pop_back()
  var imminent_pts: Array = []
  var imminent_r_applied := 0.0
  if imminent_r_cfg > 0.0 and (w_seek > 0.0 or not food_targets.is_empty()):
    imminent_pts = _motor_imminent_mob_positions()
    imminent_r_applied = imminent_r_cfg
    if w_seek > 0.0 and not imminent_pts.is_empty():
      var clear_now := float(
        Callable(_MOTOR, &"minimum_footprint_point_clearance").call(pos, he_xy, imminent_pts)
      )
      if clear_now < imminent_r_cfg:
        w_seek = 0.0

  return {
    "creature_position": pos,
    "creature_speed": spd,
    "lookahead_sec": float(motor_p.get("lookahead_sec", 0.15)),
    "bounds_min": Vector2.ZERO,
    "bounds_max": ss,
    "mobs": mobs_arr,
    "weight_dist": float(motor_p.get("weight_dist", 0.45)),
    "weight_dist_sq": float(motor_p.get("weight_dist_sq", 55.0)),
    "weight_closing": float(motor_p.get("weight_closing", 1.05)),
    "penalty_oob": float(motor_p.get("penalty_oob", 1e7)),
    "distance_eps": float(motor_p.get("distance_eps", 6.0)),
    "creature_half_extents": he_xy,
    "weight_interior": float(motor_p.get("weight_interior", 0.65)) * float(hunger_explore.get("interior_mul", 1.0)),
    "weight_edge": float(motor_p.get("weight_edge", 0.48)) * float(hunger_explore.get("edge_mul", 1.0)),
    "shuffle_tie_break": _motor_bool_default_true(motor_p, "shuffle_tie_break"),
    "tie_shuffle_seed": _physics_ticks,
    "awareness_radius": float(motor_p.get("awareness_radius", 0.0)),
    "awareness_cone_extra": float(motor_p.get("awareness_cone_extra", 0.0)),
    "awareness_cone_cos_threshold": cos(deg_to_rad(half_deg)),
    "creature_facing": facing_display,
    "static_obstacles": _static_obstacles_for_motor(),
    "weight_obstacle": float(motor_p.get("weight_obstacle", 0.0)),
    "creature_size": csz,
    "environment_grid": env_grid,
    "interior_env_motor_active": interior_active,
    "interior_env_near_mob_px": float(motor_p.get("interior_env_near_mob_px", 70.0)),
    "weight_interior_env_solid": float(motor_p.get("weight_interior_env_solid", 8000.0)),
    "weight_interior_env_slow": float(motor_p.get("weight_interior_env_slow", 4.0)),
    "food_seek_targets": food_targets,
    "weight_seek_ready_food": w_seek,
    "imminent_mob_points": imminent_pts,
    "food_seek_imminent_mob_radius_px": imminent_r_applied,
    "unready_food_avoid_targets": unready_food_targets,
    "weight_avoid_unready_food": w_avoid_unready,
    "weight_explore_idle_penalty": w_idle_exp,
    "weight_explore_turn_bias": w_turn_exp,
    "explore_trail_centers": trail_for_motor,
    "weight_explore_trail_repulsion": w_trail_rep,
  }


func _physics_process(_delta: float) -> void:
  if _state != State.PLAYING or _main == null or _creature == null:
    return
  _physics_ticks += 1
  var p: Dictionary = _live_perception_params()
  var stride := maxi(1, int(p.get("SNAPSHOT_PHYSICS_STRIDE", 1)))
  if _physics_ticks % stride == 0:
    _latest_snapshot = _build_snapshot_blob()
    _has_snapshot = not _latest_snapshot.is_empty()

  if _creature_motor_mode() == "scripted" and int(_creature.get("control_mode")) == _PlayerScr.engine_control_as_int():
    var motor_p := _live_creature_motor_params()
    _explore_trail_record(_creature.global_position, motor_p)
    var h_ex := _hunger_exploration_modifiers(motor_p)
    var ctx := _build_motor_context(motor_p, h_ex)
    var incumbent_v: Variant = _creature.get("creature_move_intent")
    var incumbent: Vector2 = incumbent_v if typeof(incumbent_v) == TYPE_VECTOR2 else Vector2.ZERO
    var raw_intent: Vector2 = _MOTOR.pick_best_move_intent(ctx)
    var jeopardy_forced := false
    var jeopardy_ticks := maxi(0, int(motor_p.get("jeopardy_forced_turn_ticks", 5)))
    if jeopardy_ticks > 0:
      var half_deg_j: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
      var jeopardy_eval: Dictionary = Callable(_JeopardyTurnScr, &"evaluate_jeopardy_tick").call(
        {
          "incumbent": incumbent,
          "creature_position": ctx["creature_position"],
          "creature_half_extents": ctx.get("creature_half_extents", Vector2.ZERO),
          "creature_facing": ctx.get("creature_facing", Vector2.RIGHT),
          "mobs": ctx.get("mobs", []),
          "imminent_radius_px": float(motor_p.get("food_seek_imminent_mob_radius_px", 100.0)),
          "cone_cos_threshold": cos(deg_to_rad(half_deg_j)),
          "required_ticks": jeopardy_ticks,
        },
        _jeopardy_forced_turn_state,
      )
      if bool(jeopardy_eval.get("should_force", false)):
        raw_intent = Callable(_JeopardyTurnScr, &"pick_forced_turn").call(
          ctx,
          incumbent,
          jeopardy_eval["threat_mob_pos"],
        ) as Vector2
        jeopardy_forced = true
        Callable(_IntentHoldScr, &"reset_state").call(_scripted_intent_hold_state)
    var hold_base := float(maxi(1, int(motor_p.get("scripted_intent_hold_physics_ticks", 8))))
    var food_seek_list: Array = ctx.get("food_seek_targets", []) as Array
    var extra_hold := 0.0
    if food_seek_list.is_empty():
      extra_hold = float(maxi(0, int(motor_p.get("explore_intent_hold_extra_ticks", 5))))
    var hold_ticks := maxi(
      1,
      int(round((hold_base + extra_hold) * float(h_ex.get("hold_mul", 1.0))))
    )
    var intent: Vector2 = raw_intent
    if not jeopardy_forced:
      intent = Callable(_IntentHoldScr, &"filtered_intent").call(
        raw_intent, incumbent, hold_ticks, _scripted_intent_hold_state
      ) as Vector2
    if _creature.has_method("set_creature_move_intent"):
      _creature.call("set_creature_move_intent", intent)

  _record_mob_history_if_playing()


func _refresh_inference_client_config() -> void:
  _inference_client = _live_inference_client()


func _set_state(next_state: State) -> void:
  if _state == next_state:
    return
  if _state == State.PLAYING and next_state != State.PLAYING:
    Callable(_IntentHoldScr, &"reset_state").call(_scripted_intent_hold_state)
    Callable(_JeopardyTurnScr, &"reset_state").call(_jeopardy_forced_turn_state)
    _explore_trail_reset()
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
  var completions_path := str(_inference_client.get("COMPLETIONS_PATH", "/v1/completions")).strip_edges()
  var url: String
  var req: Dictionary
  if not completions_path.is_empty():
    url = "%s%s" % [base_url, completions_path]
    var trailer := ""
    match _state:
      State.ARMED:
        trailer = _COMPLETION_OUTPUT_TRAILER_ARMED
      State.PLAYING:
        trailer = _COMPLETION_OUTPUT_TRAILER_PLAYING
      _:
        trailer = ""
    var prompt := _system_prompt + _COMPLETION_PROMPT_SEPARATOR + user_content + trailer
    _last_request_used_completions = true
    _last_prompt_tail = prompt.substr(maxi(0, prompt.length() - 220), 220)
    _last_user_head = (
      user_content.get_slice("\n", 0).strip_edges().substr(0, 120)
      if not user_content.is_empty()
      else ""
    )
    #region agent log
    _last_completion_grammar = ""
    if bool(_inference_client.get("LLAMA_COMPLETION_GRAMMAR_ENABLED", true)):
      _last_completion_grammar = gbnf_for_completion_state_enum(int(_state))
    _dbg46_emit(
      "ai-inf",
      "H-A",
      "ai_driver.gd:_enqueue_inference_request",
      "enqueue_completions",
      {
        "state_enum": int(_state),
        "url_tail": url.substr(maxi(0, url.length() - 96), 96),
        "prompt_chars": prompt.length(),
        "trailer_chars": trailer.length(),
        "grammar_chars": _last_completion_grammar.length(),
        "prompt_tail": _last_prompt_tail,
        "user_head": _last_user_head,
      },
    )
    #endregion
    req = {
      "model": str(_inference_client.get("MODEL_ID", "")),
      "prompt": prompt,
      "max_tokens": int(_inference_client.get("MAX_OUTPUT_TOKENS", 48)),
      "temperature": float(_inference_client.get("TEMPERATURE", 0.0)),
      "stream": false,
      "echo": false,
    }
    if not _last_completion_grammar.is_empty():
      req["grammar"] = _last_completion_grammar
  else:
    var chat_path := str(_inference_client.get("CHAT_COMPLETIONS_PATH", "/v1/chat/completions")).strip_edges()
    if chat_path.is_empty():
      chat_path = "/v1/chat/completions"
    url = "%s%s" % [base_url, chat_path]
    _last_request_used_completions = false
    _last_prompt_tail = ""
    _last_user_head = (
      user_content.get_slice("\n", 0).strip_edges().substr(0, 120)
      if not user_content.is_empty()
      else ""
    )
    #region agent log
    _dbg46_emit(
      "ai-inf",
      "H-A",
      "ai_driver.gd:_enqueue_inference_request",
      "enqueue_chat",
      {"state_enum": int(_state), "url_tail": url.substr(maxi(0, url.length() - 96), 96), "user_head": _last_user_head},
    )
    #endregion
    req = {
      "model": str(_inference_client.get("MODEL_ID", "")),
      "messages": [
        {"role": "system", "content": _system_prompt},
        {"role": "user", "content": user_content},
      ],
      "max_tokens": int(_inference_client.get("MAX_OUTPUT_TOKENS", 48)),
      "temperature": float(_inference_client.get("TEMPERATURE", 0.0)),
      "stream": false,
    }
  _last_inference_url = url
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
  var choice0_keys: Array = []
  var ch: Variant = (parsed as Dictionary).get("choices", [])
  if typeof(ch) == TYPE_ARRAY and not (ch as Array).is_empty():
    var z: Variant = (ch as Array)[0]
    if typeof(z) == TYPE_DICTIONARY:
      for k in (z as Dictionary).keys():
        choice0_keys.append(str(k))
  var cmpl_raw := extract_openai_completion_choice_text(parsed)
  var content := _extract_message_content(parsed)
  var token: String = (
    _TOKENS.normalize_completion_token_armed_handshake(content)
    if _state == State.ARMED
    else _TOKENS.normalize_completion_token(content)
  )
  var excerpt := content.strip_edges().replace("\n", " ").replace("\r", " ")
  var content_empty := content.strip_edges().is_empty()
  if excerpt.length() > _TL_DEBUG_CONTENT_MAX_CHARS:
    excerpt = excerpt.substr(0, _TL_DEBUG_CONTENT_MAX_CHARS) + " [truncated]"
  _OLogSafe.debug("TL completion raw=\"%s\" → token=%s" % [excerpt, token], true, "AiDriver")
  #region agent log
  _dbg46_emit(
    "ai-inf",
    "H-B",
    "ai_driver.gd:_on_http_request_completed",
    "completion_parsed",
    {
      "state_enum": int(_state),
      "used_completions": _last_request_used_completions,
      "prompt_tail": _last_prompt_tail,
      "user_head": _last_user_head,
      "choice0_keys": choice0_keys,
      "cmpl_len": cmpl_raw.length(),
      "cmpl_head": cmpl_raw.substr(0, mini(80, cmpl_raw.length())).replace("\n", "\\n"),
      "cmpl_nonempty_stripped": not cmpl_raw.strip_edges().is_empty(),
      "grammar_sent_chars": _last_completion_grammar.length(),
      "content_head": content.substr(0, mini(100, content.length())).replace("\n", "\\n"),
      "token": token,
    },
  )
  #endregion
  if token == "noop" and (_state == State.ARMED or _state == State.PLAYING):
    var now_ms := Time.get_ticks_msec()
    if now_ms - _noop_diag_last_ms >= 2000:
      _noop_diag_last_ms = now_ms
      _OLogSafe.info(
        (
          "AiDriver: TL noop (state_enum=%d, content_empty=%s). raw_excerpt=\"%s\". "
          + "If content_empty: raise inference_client.MAX_OUTPUT_TOKENS or fix server JSON. "
          + "Else: model/template issue; see OLog debug for each completion."
        )
        % [int(_state), content_empty, excerpt],
        true,
        "AiDriver"
      )
  _apply_action_token(token)
  emit_signal("ai_inference_finished", token)


func _fail_inference_response(reason: String) -> void:
  emit_signal("ai_inference_finished", "noop")
  if _state != State.ARMED:
    return
  _OLogSafe.error("AiDriver: %s — cancel AI setup." % reason, true, "AiDriver")
  cancel_armed_session()


func _extract_message_content(resp: Dictionary) -> String:
  var from_cmpl := extract_openai_completion_choice_text(resp)
  if not from_cmpl.strip_edges().is_empty():
    return from_cmpl
  return extract_openai_chat_choice_text(resp)


func _apply_action_token(token: String) -> void:
  if token == "START":
    if _state == State.ARMED and _main != null and _main.has_method("new_game"):
      _main.call_deferred("new_game")
    return
  if _creature == null or not _creature.has_method("set_creature_move_intent"):
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
  _creature.call("set_creature_move_intent", dir)


func _build_snapshot_blob() -> String:
  if _main == null or _creature == null:
    return ""
  var viewport_size := (_creature.get("screen_size") as Vector2)
  if viewport_size == Vector2.ZERO:
    viewport_size = _creature.get_viewport_rect().size
  var cols := int(ceil(viewport_size.x / float(CELL_SIZE)))
  var rows := int(ceil(viewport_size.y / float(CELL_SIZE)))
  if cols <= 0 or rows <= 0:
    return ""

  var grid: Array = []
  for _r in rows:
    var row := PackedInt32Array()
    row.resize(cols)
    grid.append(row)

  var creature_sample := _SAMPLING.sampling_from_collision_object(_creature)
  var creature_point: Vector2 = creature_sample.get("point", _creature.global_position)
  var creature_ext: Vector3 = creature_sample.get("half_extents", Vector3.ZERO)
  var creature_cell := _world_to_cell(creature_point, cols, rows)

  var mobs: Array[Dictionary] = []
  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var mob := n as RigidBody2D
      var mob_sample := _SAMPLING.sampling_from_collision_object(mob)
      var mob_point: Vector2 = mob_sample.get("point", mob.global_position)
      mobs.append({
        "node": mob,
        "sample": mob_sample,
        "dist": mob_point.distance_to(creature_point),
        "id": mob.get_instance_id(),
      })
  mobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
    var da: float = a["dist"]
    var db: float = b["dist"]
    if is_equal_approx(da, db):
      return int(a["id"]) < int(b["id"])
    return da < db
  )

  var mob_hint_entries: Array = []
  for info in mobs:
    var mob_rb: RigidBody2D = info["node"]
    var hint_point: Vector2 = info["sample"].get("point", mob_rb.global_position)
    mob_hint_entries.append({"point": hint_point, "velocity": mob_rb.linear_velocity})

  var creature_vel2 := Vector2.ZERO
  if _creature.has_method("get"):
    creature_vel2 = _creature.get("current_velocity") as Vector2

  var patch_band: Dictionary = (
    Callable(_RISK, &"classify_creature_patch_and_band").call(
      creature_cell.x,
      creature_cell.y,
      rows,
      cols,
      creature_vel2
    )
    as Dictionary
  )
  var prio: Dictionary = Callable(_RISK, &"pick_priority_closing_mob").call(mob_hint_entries, creature_point) as Dictionary

  for info in mobs:
    var mob_point: Vector2 = info["sample"].get("point", Vector2.ZERO)
    var mob_cell := _world_to_cell(mob_point, cols, rows)
    var cur := int(grid[mob_cell.x][mob_cell.y])
    if mob_cell == creature_cell:
      grid[mob_cell.x][mob_cell.y] = 3
    elif cur == 0:
      grid[mob_cell.x][mob_cell.y] = 2

  var pcur := int(grid[creature_cell.x][creature_cell.y])
  grid[creature_cell.x][creature_cell.y] = 3 if pcur == 2 else 1

  var lines: PackedStringArray = []
  lines.append(_WIRE.format_header_line(Time.get_ticks_msec(), int(_main.get("score")), cols, rows, CELL_SIZE))
  lines.append(
    (
      Callable(_WIRE, &"format_risk_hints_line").call(
        int(prio["idx_1"]),
        float(prio["t_approx_sec"]),
        str(patch_band["patch"]),
        str(patch_band["band"])
      )
      as String
    )
  )
  lines.append(
    (
      Callable(_WIRE, &"format_plain_hint_line").call(int(prio["idx_1"]), str(patch_band["patch"]), str(patch_band["band"]))
      as String
    )
  )
  for r in rows:
    var s := ""
    var row_arr: PackedInt32Array = grid[r]
    for c in cols:
      s += str(row_arr[c])
    lines.append(s)
  var creature_vel := Vector3(creature_vel2.x, creature_vel2.y, 0.0)
  lines.append(_WIRE.format_entity_velocity_line("PLAYER", creature_cell.x, creature_cell.y, creature_vel))
  lines.append(_WIRE.format_entity_extents_line("PLAYER_EXT", creature_ext))

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
