## Headless test entry: [code]godot --path . --headless -s res://tests/run_all.gd[/code]
extends SceneTree

const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _Tokens := preload("res://AI_int_lib/ai_action_tokens.gd")
const _Wire := preload("res://AI_int_lib/perception_wire.gd")
const _Sampling := preload("res://AI_int_lib/perception_sampling.gd")
const _Driver := preload("res://AI_int_lib/ai_driver.gd")
const _Bundle := preload("res://AI_int_lib/bundled_inference_launcher.gd")

var _failures: int = 0


func _init() -> void:
  _run_all()
  quit(0 if _failures == 0 else 1)


func _run_all() -> void:
  _test_merge_defaults_and_override()
  _test_load_merged_config_repo_fallback()
  _test_tokens()
  _test_perception_snippet()
  _test_perception_sampling()
  _test_ai_driver_helpers()
  _test_bundled_inference_helpers()
  if _failures > 0:
    push_error("tests/run_all.gd: %d assertion(s) failed." % _failures)


func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)


func _test_merge_defaults_and_override() -> void:
  var base := _Merge.default_root()
  var file_root := {
    "logging_params": {"LOG_LEVEL": "Debug"},
    "inference_client": {"INFERENCE_BASE_URL": "http://x"},
    "perception": {"SNAPSHOT_PHYSICS_STRIDE": 3},
  }
  var merged: Dictionary = _Merge.merge_root(base, file_root)
  _assert(merged["logging_params"]["LOG_LEVEL"] == "Debug", "merge logging_params.LOG_LEVEL")
  _assert(merged["logging_params"]["MAX_LINES_PER_PROCESS"] == 128, "merge logging_params keeps default key")
  _assert(merged["inference_client"]["INFERENCE_BASE_URL"] == "http://x", "merge inference_client url")
  _assert(merged["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 3, "merge perception stride")
  var res: Dictionary = _Merge.load_merge_from_path("user://__does_not_exist_for_test__.json")
  _assert(str(res.get("diagnostic", "")) != "", "missing file should set diagnostic")
  var m2: Dictionary = res["merged"]
  _assert(m2["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 1, "missing file perception default")


func _test_load_merged_config_repo_fallback() -> void:
  var res: Dictionary = _Merge.load_merged_config("user://__does_not_exist_merged_test__.json")
  var merged: Dictionary = res["merged"]
  var ic: Dictionary = merged["inference_client"]
  _assert(str(ic.get("INFERENCE_BASE_URL", "")).begins_with("http"), "merged config pulls inference URL from repo template")


func _test_tokens() -> void:
  _assert(_Tokens.normalize_completion_token("  left\nnoise") == "LEFT", "token first line")
  _assert(_Tokens.normalize_completion_token("START") == "START", "START")
  _assert(_Tokens.normalize_completion_token("I'll go UP now") == "UP", "prose contains UP word")
  _assert(_Tokens.normalize_completion_token("<|im_end|> LEFT") == "LEFT", "strip span then direction")
  _assert(_Tokens.normalize_completion_token("xyzzy") == "noop", "unknown → noop")
  _assert(_Tokens.normalize_completion_token("") == "noop", "empty → noop")
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("Okay.\nSTART") == "START",
    "handshake finds START on a later line"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("Sure, START") == "START",
    "handshake word START in prose"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("RESTART") == "noop",
    "RESTART does not match START word"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("START <|im_end|>") == "START",
    "strip trailing chat marker after START"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("<|im_end|>") == "noop",
    "chat markers alone → noop"
  )


func _test_perception_snippet() -> void:
  var h := _Wire.format_header_line(1000, 3, 10, 8, 24)
  _assert(h == "1000 3 10 8 24", "header line")
  var v := _Wire.format_entity_velocity_line("PLAYER", 2, 4, Vector3(10, -20, 0))
  _assert(v.begins_with("PLAYER 2 4 "), "player vel line prefix")
  var e := _Wire.format_entity_extents_line("PLAYER_EXT", Vector3(12, 8, 0))
  _assert(e.begins_with("PLAYER_EXT "), "extents line")


func _test_perception_sampling() -> void:
  var ident := Transform2D.IDENTITY
  var r := Rect2(-10, -20, 30, 40)
  var a := _Sampling.world_aabb_from_shape_rect(r, ident)
  _assert(a.get_center().is_equal_approx(Vector2(5, 0)), "aabb center ident xf")
  _assert(a.size.is_equal_approx(Vector2(30, 40)), "aabb size ident xf")
  var shifted := Transform2D.IDENTITY.translated(Vector2(100, 200))
  var b := _Sampling.world_aabb_from_shape_rect(Rect2(-5, -5, 10, 10), shifted)
  _assert(b.get_center().is_equal_approx(Vector2(100, 200)), "aabb translated unit rect")
  var st_root := get_root()
  var body := Area2D.new()
  var cs := CollisionShape2D.new()
  var cap := CapsuleShape2D.new()
  cap.radius = 10.0
  cap.height = 30.0
  cs.shape = cap
  body.add_child(cs)
  st_root.add_child(body)
  body.global_position = Vector2(200, 300)
  var s: Dictionary = _Sampling.sampling_from_collision_object(body)
  st_root.remove_child(body)
  body.queue_free()
  var p: Vector2 = s.get("point", Vector2.ZERO)
  var he: Vector3 = s.get("half_extents", Vector3.ZERO)
  _assert(p.is_equal_approx(Vector2(200, 300)), "capsule sampling center")
  _assert(he.x > 5.0 and he.y > 15.0, "capsule half-extents plausible")


func _test_ai_driver_helpers() -> void:
  _assert(_Driver.should_apply_response_id(7, 7), "latest-enqueued response applies")
  _assert(not _Driver.should_apply_response_id(6, 7), "older response is stale")
  var d := _Driver.new()
  _assert(d.get_armed_handshake_user() == "ARMED", "armed handshake literal")
  _assert(_Driver.http_request_result_label(HTTPRequest.RESULT_CANT_CONNECT) == "CANT_CONNECT", "HTTP label")
  _assert(
    _Driver.extract_openai_chat_choice_text({
      "choices": [{"message": {"content": [{"type": "text", "text": "LEFT"}]}}],
    })
    == "LEFT",
    "OpenAI array-shaped message.content",
  )
  _assert(
    _Driver.extract_openai_chat_choice_text({"choices": [{"message": {"content": "RIGHT"}, "text": ""}]})
    == "RIGHT",
    "string message.content",
  )
  _assert(
    _Driver.extract_openai_chat_choice_text({"choices": [{"text": "legacy DOWN"}]}) == "legacy DOWN",
    "legacy choices[0].text fallback",
  )
  _assert(
    _Driver.extract_openai_chat_choice_text({
      "choices": [{"message": {"content": [{"type": "output_text", "text": "UP"}]}}],
    })
    == "UP",
    "OpenAI output_text content block (llama-server)",
  )
  _assert(
    _Driver.extract_openai_completion_choice_text({"choices": [{"text": "LEFT"}]}) == "LEFT",
    "OpenAI /v1/completions choices[0].text",
  )
  _assert(
    _Driver.extract_openai_completion_choice_text({"choices": [{}]}) == "",
    "empty completion text",
  )
  _assert(_Driver.gbnf_for_completion_state_enum(1).contains("START"), "gbnf ARMED")
  _assert(_Driver.gbnf_for_completion_state_enum(2).contains("RIGHT"), "gbnf PLAYING")
  _assert(_Driver.gbnf_for_completion_state_enum(0).is_empty(), "gbnf IDLE empty")


func _test_bundled_inference_helpers() -> void:
  var ic_off := {"INFERENCE_AUTO_START_ENABLED": false}
  _assert(not _Bundle.should_attempt_auto_start(ic_off, "http://127.0.0.1:8080"), "auto-start off")
  var ic_on := {"INFERENCE_AUTO_START_ENABLED": true}
  _assert(_Bundle.should_attempt_auto_start(ic_on, "http://127.0.0.1:8080"), "loopback + auto")
  _assert(not _Bundle.should_attempt_auto_start(ic_on, "https://api.example.com"), "remote URL no spawn")
  _assert(_Bundle.port_from_base_url("http://127.0.0.1:9090/") == 9090, "port parse")
  _assert(_Bundle.port_from_base_url("http://127.0.0.1") == 8080, "default port when omitted")
