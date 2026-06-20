extends Node
## Autoload AI driver — V3 Step 3 stub: session/LLM + goal-memory storage; zero ENGINE move intent until §12.2 rebuild.

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
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")
const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _GoalBeliefScr := preload("res://creature/motor/goal_belief_memory.gd")
const _GoalMem := preload("res://creature/motor/goal_source_memory.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _LauncherScript := preload("res://AI_int_lib/bundled_inference_launcher.gd")
const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")

const _SYSTEM_PROMPT_PATH := "res://AI_int_lib/system_prompt.txt"
const _ARMED_HANDSHAKE_USER := "ARMED"
const _COMPLETION_PROMPT_SEPARATOR := "\n\n---\n\n"
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

const _TL_DEBUG_CONTENT_MAX_CHARS: int = 200

const _SQRT2_INV: float = 0.7071067811865475
const _EIGHT_WAY_DIRS: Array[Vector3] = [
  Vector3(0.0, 0.0, -1.0),
  Vector3(_SQRT2_INV, 0.0, -_SQRT2_INV),
  Vector3(1.0, 0.0, 0.0),
  Vector3(_SQRT2_INV, 0.0, _SQRT2_INV),
  Vector3(0.0, 0.0, 1.0),
  Vector3(-_SQRT2_INV, 0.0, _SQRT2_INV),
  Vector3(-1.0, 0.0, 0.0),
  Vector3(-_SQRT2_INV, 0.0, -_SQRT2_INV),
]

#region agent log
const _DBG46_SESSION := "46c25f"
const _DBG46_REL := "res://debug-46c25f.log"


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
var _creature: Node = null
var _registered_creatures: Array = []
var _primary_creature: Node = null
var _duel_round_active: bool = false
var _duel_motor_round_salt: int = 0
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
var _noop_diag_last_ms: int = 0
var _last_request_used_completions: bool = false
var _last_prompt_tail: String = ""
var _last_user_head: String = ""
var _last_completion_grammar: String = ""

var _bundled_launcher: Node
var _warned_missing_creature_pack_by_id: Dictionary = {}

var _goal_belief_by_body: Dictionary = {}
var _goal_source_memory_by_body: Dictionary = {}
var _goal_memory_meta_by_body: Dictionary = {}

var _arm_session_in_progress: bool = false
var _cpu_player_round_active: bool = false

static var _debug_arm_invoke_seq: int = 0


static func gbnf_for_completion_state_enum(state_enum: int) -> String:
  match state_enum:
    1:
      return "root ::= \"START\"\n"
    2:
      return "root ::= \"UP\" | \"DOWN\" | \"LEFT\" | \"RIGHT\"\n"
    _:
      return ""


static func playing_control_mode_int_for_motor_mode_string(motor_mode: String) -> int:
  var norm := str(motor_mode).to_lower().strip_edges()
  return _ControlMode.ai_as_int() if norm == "llm" else _ControlMode.engine_as_int()


static func should_apply_response_id(response_id: int, latest_enqueued_request_id: int) -> bool:
  return response_id == latest_enqueued_request_id


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
        if typ == "text" or typ == "output_text" or typ == "input_text":
          out += str(d.get("text", ""))
        elif typ == "refusal":
          out += str(d.get("refusal", ""))
      elif typeof(item) == TYPE_STRING:
        out += str(item)
    return out
  return str(v)


static func extract_openai_completion_choice_text(resp: Dictionary) -> String:
  var choices: Variant = resp.get("choices", [])
  if typeof(choices) != TYPE_ARRAY or choices.is_empty():
    return ""
  var first: Variant = choices[0]
  if typeof(first) != TYPE_DICTIONARY:
    return ""
  return str((first as Dictionary).get("text", ""))


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


func attach_main(main_node: Node) -> void:
  _main = main_node
  _sync_creature_from_main()
  _goal_belief_reset_all()
  emit_signal("ai_session_state_changed", int(_state))


func _sync_creature_from_main() -> void:
  _creature = null
  if _main != null and _main.has_method(&"get_herbivore_motor_body"):
    _creature = _main.call(&"get_herbivore_motor_body") as Node


func clear_creature_registry() -> void:
  _registered_creatures.clear()
  _creature = null
  _primary_creature = null


func register_creature(node: Node) -> void:
  if node == null or not is_instance_valid(node):
    return
  if not _MotorPlane.is_motor_physics_body(node):
    return
  var pb := node as Node
  var id := pb.get_instance_id()
  for x in _registered_creatures:
    if x is Node and is_instance_valid(x) and (x as Node).get_instance_id() == id:
      return
  _registered_creatures.append(pb)


func set_primary_creature(node: Node) -> void:
  if node != null and _MotorPlane.is_motor_physics_body(node):
    _primary_creature = node as Node
    _creature = _primary_creature


func sync_duel_control_modes() -> void:
  var engine_int := _ControlMode.engine_as_int()
  for n in _registered_creatures:
    if not (n is Node) or not is_instance_valid(n):
      continue
    var nn := n as Node
    if nn.has_method(&"set_control_mode"):
      nn.call(&"set_control_mode", engine_int)
    _call_set_creature_move_intent(nn, Vector3.ZERO)


func set_duel_round_active(active: bool) -> void:
  _duel_round_active = active


func is_duel_round_active() -> bool:
  return _duel_round_active


func _scripted_motor_subjects() -> Array:
  if _registered_creatures.is_empty():
    var fb: Array = []
    if _creature != null:
      fb.append(_creature)
    return fb
  var out: Array = []
  for n in _registered_creatures:
    if _MotorPlane.is_motor_physics_body(n) and is_instance_valid(n):
      out.append(n as Node)
  return out


func _clear_registered_creature_move_intents() -> void:
  var seen: Dictionary = {}
  var stack: Array = _registered_creatures.duplicate()
  if _creature != null:
    stack.append(_creature)
  for n in stack:
    if not _MotorPlane.is_motor_physics_body(n) or not is_instance_valid(n):
      continue
    var pb := n as Node
    var id := pb.get_instance_id()
    if seen.has(id):
      continue
    seen[id] = true
    _call_set_creature_move_intent(pb, Vector3.ZERO)
    _clear_creature_wall_slide_away_hint(pb)


func is_human_start_suppressed() -> bool:
  return _state == State.ARMED or _state == State.PLAYING


func get_state() -> int:
  return int(_state)


func get_debug_motor_mobs_snapshot() -> Array:
  return []


func get_debug_carnivore_prey_snapshot(_predator: Node = null) -> Array:
  return []


func get_debug_motor_params_for_body(body: Node) -> Dictionary:
  if body == null:
    return {}
  return _creature_motor_params_for_body(body)


func get_armed_handshake_user() -> String:
  return _ARMED_HANDSHAKE_USER


func _call_set_creature_move_intent(body: Node, intent3: Vector3) -> void:
  if body == null or not body.has_method(&"set_creature_move_intent"):
    return
  body.call(&"set_creature_move_intent", intent3)


func _clear_creature_wall_slide_away_hint(body: Node) -> void:
  if body.has_method(&"clear_wall_slide_away_hint"):
    body.call(&"clear_wall_slide_away_hint")


func _clear_creature_wall_slide_toward_hint(body: Node) -> void:
  if body.has_method(&"clear_wall_slide_toward_hint"):
    body.call(&"clear_wall_slide_toward_hint")


func _live_creature_motor_params() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_creature_motor_params"):
    return g.call("get_creature_motor_params") as Dictionary
  return (_Merge.default_root()["creature_motor"] as Dictionary).duplicate(true)


func _viewport_playfield_size(preferred: Node) -> Vector2:
  if _main != null and _main.has_method(&"get_motor_playfield_size"):
    var mps: Variant = _main.call(&"get_motor_playfield_size")
    if typeof(mps) == TYPE_VECTOR2:
      var mv := mps as Vector2
      if mv.x > 0.0 and mv.y > 0.0:
        return mv
  if preferred is CanvasItem:
    var ci := preferred as CanvasItem
    if ci.is_inside_tree():
      return ci.get_viewport_rect().size
  if _main != null:
    var vp_main := _main.get_viewport()
    if vp_main != null:
      return vp_main.get_visible_rect().size
  var st := get_tree()
  if st != null:
    var vp_root := st.root.get_viewport()
    if vp_root != null:
      return vp_root.get_visible_rect().size
  var wh := DisplayServer.window_get_size()
  return Vector2(wh)


func _creature_motor_params_for_body(body: Node) -> Dictionary:
  var base := _live_creature_motor_params()
  if body == null:
    return base
  var motor_p := base
  var def_v: Variant = _MotorPlane.definition_for_body(body)
  if def_v != null and def_v is Resource:
    var def_res := def_v as Resource
    if def_res.get_script() == _CreatureDefinition:
      var pack_v: Variant = def_res.get("asset_pack_root")
      var pack_root := str(pack_v).strip_edges() if pack_v != null else ""
      if pack_root.is_empty():
        var bid := body.get_instance_id()
        if not _warned_missing_creature_pack_by_id.has(bid):
          _warned_missing_creature_pack_by_id[bid] = true
          _OLogSafe.error(
            "Creature motor: asset_pack_root empty on '%s' — pack overlay skipped."
            % str(body.name),
            false,
            "AiDriver",
          )
      else:
        var g := get_node_or_null("/root/GameConfig")
        if g != null and g.has_method("get_creature_motor_params_for_pack"):
          motor_p = g.call("get_creature_motor_params_for_pack", pack_root) as Dictionary
        else:
          motor_p = _Merge.merge_creature_motor_pack_overlay(base.duplicate(true), pack_root)
  var ss: Variant = body.get("screen_size")
  var playfield := ss as Vector2 if typeof(ss) == TYPE_VECTOR2 else Vector2.ZERO
  if playfield == Vector2.ZERO:
    playfield = _viewport_playfield_size(body)
  var dist_scale := _MotorPlane.motor_distance_scale_for_main(_main, playfield)
  return _MotorPlane.scale_motor_distance_params(motor_p, dist_scale)


func _live_perception_params() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_perception_params"):
    return g.call("get_perception_params") as Dictionary
  return _Merge.default_perception_params().duplicate(true)


func _live_inference_client() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_inference_client"):
    return g.call("get_inference_client") as Dictionary
  return (_Merge.default_root()["inference_client"] as Dictionary).duplicate(true)


func _goal_belief_reset_all() -> void:
  _goal_belief_by_body.clear()
  for store in _goal_source_memory_by_body.values():
    if store != null and store.has_method(&"reset"):
      store.call(&"reset")
  _goal_source_memory_by_body.clear()
  _goal_memory_meta_by_body.clear()


func _goal_belief_for_body(body_id: int) -> Dictionary:
  if not _goal_belief_by_body.has(body_id):
    _goal_belief_by_body[body_id] = {}
  return _goal_belief_by_body[body_id]


func _goal_memory_meta_for_body(body: Node) -> Dictionary:
  var bid := body.get_instance_id()
  if _goal_memory_meta_by_body.has(bid):
    return _goal_memory_meta_by_body[bid]
  var pack_root := ""
  var def_v: Variant = body.get("definition")
  if def_v is Resource and (def_v as Resource).get_script() == _CreatureDefinition:
    pack_root = str((def_v as Resource).get("asset_pack_root")).strip_edges()
  var traits := {
    "explorer_builder": 0.0,
    "change_stability": 0.0,
    "compassion_self_interest": 0.0,
    "community_individual": 0.0,
  }
  if def_v is Resource:
    traits["explorer_builder"] = float((def_v as Resource).get("explorer_builder"))
    traits["change_stability"] = float((def_v as Resource).get("change_stability"))
    traits["compassion_self_interest"] = float((def_v as Resource).get("compassion_self_interest"))
    traits["community_individual"] = float((def_v as Resource).get("community_individual"))
  var meta := {
    "pack_root": pack_root,
    "effective_goal_kinds": _GkReg.effective_goal_kinds_for_pack(pack_root),
    "goal_kind_catalog": _GkReg.goal_kind_catalog_for_pack(pack_root),
    "effective_modality_allowlist": _GoalMem.effective_modality_allowlist_for_pack(pack_root),
    "traits": traits,
  }
  _goal_memory_meta_by_body[bid] = meta
  if not _goal_source_memory_by_body.has(bid):
    _goal_source_memory_by_body[bid] = _GoalMem.new()
  return meta


func _goal_source_store_for_body(body: Node) -> _GoalMem:
  _goal_memory_meta_for_body(body)
  return _goal_source_memory_by_body[body.get_instance_id()] as _GoalMem


func _goal_belief_reset() -> void:
  _goal_belief_reset_all()


func _goal_belief_sync_from_scene(body_id: int, food_split: Dictionary) -> void:
  var beliefs := _goal_belief_for_body(body_id)
  _goal_belief_by_body[body_id] = _GoalBeliefScr.sync_from_scene(
    beliefs, food_split, Time.get_ticks_msec()
  )


func _goal_belief_maintain(creature_pos: Vector3, now_ms: int, motor_p: Dictionary, body_id: int) -> void:
  var beliefs := _goal_belief_for_body(body_id)
  _goal_belief_by_body[body_id] = _GoalBeliefScr.maintain(
    beliefs, creature_pos, now_ms, motor_p
  )


func notify_food_consumption_outcome(
  body: Node,
  food_anchor: Vector2,
  insufficient_yield: bool = false,
) -> void:
  if body == null or not is_instance_valid(body):
    return
  var motor_p := _creature_motor_params_for_body(body)
  var meta := _goal_memory_meta_for_body(body)
  var store := _goal_source_store_for_body(body)
  var env_grid: Variant = null
  if _main != null and _main.has_method("get_environment_grid"):
    env_grid = _main.call("get_environment_grid")
  var tier := _GoalMem.TIER_SUCCESS
  if insufficient_yield:
    tier = _GoalMem.TIER_PARTIAL
  store.try_salient_write(
    _GkReg.GK_FIND_FOOD,
    &"find_food",
    Vector3(food_anchor.x, 0.0, food_anchor.y),
    motor_p,
    env_grid,
    {},
    {"tier": tier, "insufficient_yield": insufficient_yield},
    meta["effective_goal_kinds"],
    meta["effective_modality_allowlist"],
    meta["traits"],
    meta["goal_kind_catalog"],
  )
  store.clear_salient_continuation()


func arm_ai_session() -> bool:
  if _arm_session_in_progress:
    return false
  _arm_session_in_progress = true
  _cpu_player_round_active = false
  _debug_arm_invoke_seq += 1
  var invoke_id := _debug_arm_invoke_seq
  _refresh_inference_client_config()
  var base_url := str(_inference_client.get("INFERENCE_BASE_URL", "")).strip_edges()
  var model_id := str(_inference_client.get("MODEL_ID", "")).strip_edges()
  if base_url.is_empty() or model_id.is_empty():
    _OLogSafe.error(
      "AiDriver: cannot arm — set inference_client.INFERENCE_BASE_URL and MODEL_ID.",
      true,
      "AiDriver",
    )
    _arm_session_in_progress = false
    return false
  var inf_ok: bool = await _bundled_launcher.ensure_inference_endpoint_ready(_inference_client)
  if not inf_ok:
    _arm_session_in_progress = false
    return false
  _set_state(State.ARMED)
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _ControlMode.engine_as_int())
  if _creature != null:
    _call_set_creature_move_intent(_creature, Vector3.ZERO)
  _goal_belief_reset_all()
  _has_snapshot = false
  _latest_snapshot = ""
  _next_inference_ms = Time.get_ticks_msec()
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H4",
    "location": "ai_driver.gd:arm_success",
    "message": "arm_ai_session_complete",
    "data": {"invoke_id": invoke_id, "emit_state_enum": get_state()},
  })
  _arm_session_in_progress = false
  return true


func begin_engine_player_round() -> bool:
  if _arm_session_in_progress:
    return false
  if _main == null:
    _OLogSafe.info(
      "AiDriver: cannot start CPU player — attach Main before pressing AI Player.",
      true,
      "AiDriver",
    )
    return false
  if _state == State.PLAYING or _state == State.ARMED:
    return false
  _arm_session_in_progress = true
  _cpu_player_round_active = true
  _set_state(State.ARMED)
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _ControlMode.engine_as_int())
  if _creature != null:
    _call_set_creature_move_intent(_creature, Vector3.ZERO)
  _goal_belief_reset_all()
  _has_snapshot = false
  _latest_snapshot = ""
  _next_inference_ms = Time.get_ticks_msec()
  _arm_session_in_progress = false
  return true


func cancel_armed_session() -> void:
  if _state != State.ARMED:
    return
  _cpu_player_round_active = false
  _http_request.cancel_request()
  _inflight_request_id = -1
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _ControlMode.human_as_int())
  if _creature != null:
    _call_set_creature_move_intent(_creature, Vector3.ZERO)
  _goal_belief_reset_all()
  _set_state(State.IDLE)


func _apply_human_control_on_registered_prey() -> void:
  var human_int := _ControlMode.human_as_int()
  for n in _registered_creatures:
    if not (n is Node) or not is_instance_valid(n):
      continue
    var nn := n as Node
    if nn.is_in_group(&"prey") and nn.has_method(&"set_control_mode"):
      nn.call("set_control_mode", human_int)


func _begin_playing_for_creature_goals_duel() -> void:
  var rng := RandomNumberGenerator.new()
  rng.randomize()
  _duel_motor_round_salt = rng.randi()
  _set_state(State.PLAYING)
  _randomize_duel_spawn_facing()
  if _cpu_player_round_active:
    if _creature != null and _creature.has_method("set_control_mode"):
      _creature.call(
        "set_control_mode",
        playing_control_mode_int_for_motor_mode_string(_creature_motor_mode())
      )
  else:
    _apply_human_control_on_registered_prey()


func _randomize_duel_spawn_facing() -> void:
  for n in _registered_creatures:
    if not _MotorPlane.is_motor_physics_body(n) or not is_instance_valid(n):
      continue
    var body := n as Node
    var slot := (body.get_instance_id() ^ _duel_motor_round_salt) & 7
    var facing: Vector3 = _EIGHT_WAY_DIRS[slot]
    if body.has_method(&"apply_duel_spawn_facing"):
      body.call(&"apply_duel_spawn_facing", facing)
    else:
      body.set("last_move_direction", facing)


func notify_main_new_game() -> void:
  _sync_creature_from_main()
  _has_snapshot = false
  _latest_snapshot = ""
  _physics_ticks = 0
  _next_inference_ms = Time.get_ticks_msec()
  _goal_belief_reset_all()
  match _state:
    State.ARMED:
      _begin_playing_for_creature_goals_duel()
    State.WAITING:
      _cpu_player_round_active = false
      if is_duel_round_active():
        _begin_playing_for_creature_goals_duel()
      else:
        _set_state(State.IDLE)
        if _creature != null and _creature.has_method("set_control_mode"):
          _creature.call("set_control_mode", _ControlMode.human_as_int())
    _:
      if is_duel_round_active():
        _begin_playing_for_creature_goals_duel()
      else:
        _cpu_player_round_active = false
        if _creature != null and _creature.has_method("set_control_mode"):
          _creature.call("set_control_mode", _ControlMode.human_as_int())


func notify_main_game_over() -> void:
  _cpu_player_round_active = false
  _clear_registered_creature_move_intents()
  _duel_motor_round_salt = 0
  _set_state(State.WAITING)
  _next_inference_ms = 0
  _has_snapshot = false
  _latest_snapshot = ""
  _goal_belief_reset_all()


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


func _creature_motor_mode() -> String:
  if _cpu_player_round_active or is_duel_round_active():
    return "scripted"
  var cm := _live_creature_motor_params()
  var m := str(cm.get("mode", "scripted")).to_lower().strip_edges()
  if m == "llm":
    return "llm"
  return "scripted"


func _physics_process(_delta: float) -> void:
  if _state != State.PLAYING or _main == null:
    return
  var subjects := _scripted_motor_subjects()
  if subjects.is_empty():
    return
  var focal := _primary_creature if _primary_creature != null else _creature
  if focal == null:
    focal = subjects[0] as Node

  _physics_ticks += 1
  var p: Dictionary = _live_perception_params()
  var stride := maxi(1, int(p.get("SNAPSHOT_PHYSICS_STRIDE", 1)))
  if _physics_ticks % stride == 0:
    _latest_snapshot = _build_snapshot_blob(focal)
    _has_snapshot = not _latest_snapshot.is_empty()

  if _creature_motor_mode() != "scripted":
    return
  for subj in subjects:
    if not is_instance_valid(subj):
      continue
    var is_pred_subj: bool = subj.is_in_group(&"mobs") and not subj.is_in_group(&"prey")
    if not is_pred_subj and int(subj.get("control_mode")) != _ControlMode.engine_as_int():
      continue
    _call_set_creature_move_intent(subj, Vector3.ZERO)


func _refresh_inference_client_config() -> void:
  _inference_client = _live_inference_client()


func _set_state(next_state: State) -> void:
  if _state == next_state:
    return
  if _state == State.PLAYING and next_state != State.PLAYING:
    _goal_belief_reset_all()
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
    _last_completion_grammar = ""
    if bool(_inference_client.get("LLAMA_COMPLETION_GRAMMAR_ENABLED", true)):
      _last_completion_grammar = gbnf_for_completion_state_enum(int(_state))
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
  var content := _extract_message_content(parsed)
  var token: String = (
    _TOKENS.normalize_completion_token_armed_handshake(content)
    if _state == State.ARMED
    else _TOKENS.normalize_completion_token(content)
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
  var intent_body := _primary_creature if _primary_creature != null else _creature
  if intent_body == null or not intent_body.has_method(&"set_creature_move_intent"):
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
  _call_set_creature_move_intent(intent_body, Vector3(dir.x, 0.0, dir.y))


func _build_snapshot_blob(_snapshot_creature: Node = null) -> String:
  return ""
