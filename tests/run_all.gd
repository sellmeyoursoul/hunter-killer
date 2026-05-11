## Headless test entry: [code]godot --path . --headless -s res://tests/run_all.gd[/code]
extends SceneTree

const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _Tokens := preload("res://AI_int_lib/ai_action_tokens.gd")
const _Wire := preload("res://AI_int_lib/perception_wire.gd")
const _Sampling := preload("res://AI_int_lib/perception_sampling.gd")
const _Risk := preload("res://AI_int_lib/perception_risk_hints.gd")
const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")
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
  _test_perception_risk_hints()
  _test_cardinal_avoidance()
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
    "creature_motor": {"mode": "llm"},
  }
  var merged: Dictionary = _Merge.merge_root(base, file_root)
  _assert(merged["logging_params"]["LOG_LEVEL"] == "Debug", "merge logging_params.LOG_LEVEL")
  _assert(merged["logging_params"]["MAX_LINES_PER_PROCESS"] == 128, "merge logging_params keeps default key")
  _assert(merged["inference_client"]["INFERENCE_BASE_URL"] == "http://x", "merge inference_client url")
  _assert(merged["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 3, "merge perception stride")
  _assert(str(merged["creature_motor"].get("mode", "")) == "llm", "merge creature_motor.mode override")
  _assert(
    float(merged["creature_motor"].get("lookahead_sec", 0.0)) > 0.0,
    "merge creature_motor keeps default lookahead when not overridden"
  )
  var res: Dictionary = _Merge.load_merge_from_path("user://__does_not_exist_for_test__.json")
  _assert(str(res.get("diagnostic", "")) != "", "missing file should set diagnostic")
  var m2: Dictionary = res["merged"]
  _assert(m2["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 1, "missing file perception default")
  _assert(str(base["creature_motor"].get("mode", "")) == "scripted", "default creature_motor.mode scripted")


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
  # Callable: static method exists on script; analyzer sometimes misses it on preload() type (see ai_driver.gd).
  var ph := Callable(_Wire, &"format_plain_hint_line").call(1, "interior", "moving") as String
  _assert(ph.begins_with("PLAIN_HINT ") and ph.contains("Mob list index 1"), "plain hint tagging closer")
  var ph_corner := Callable(_Wire, &"format_plain_hint_line").call(-1, "corner", "stopped") as String
  _assert(ph_corner.contains("CORNER"), "corner stopped posture echoed")


func _test_cardinal_avoidance() -> void:
  var base_ctx := {
    "creature_position": Vector2(100.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
  }
  var idle := _Motor.pick_best_move_intent(base_ctx)
  _assert(idle.is_equal_approx(Vector2(0.0, -1.0)), "no mobs tie picks UP first")

  var flee := base_ctx.duplicate(true)
  flee["creature_position"] = Vector2(100.0, 0.0)
  flee["mobs"] = [{"position": Vector2(200.0, 0.0), "velocity": Vector2(-150.0, 0.0)}]
  var leftish := _Motor.pick_best_move_intent(flee)
  _assert(leftish.is_equal_approx(Vector2(-1.0, 0.0)), "mob east favors moving west")

  var oob_pen := _Motor.cost_at_prediction(
    Vector2(-10.0, 200.0),
    [],
    Vector2.ZERO,
    Vector2(480.0, 720.0),
    1.0,
    0.5,
    1e7,
    8.0
  )
  _assert(oob_pen >= 1e6, "OOB prediction gets huge cost")

  var corner := base_ctx.duplicate(true)
  corner["creature_position"] = Vector2(2.0, 360.0)
  corner["mobs"] = []
  var away_from_oob := _Motor.pick_best_move_intent(corner)
  _assert(not away_from_oob.is_equal_approx(Vector2(-1.0, 0.0)), "near left wall avoids stepping OOB")


func _test_perception_risk_hints() -> void:
  var p0 := Vector2.ZERO

  var head_on := _Risk.mob_closing_metrics(Vector2(220.0, 0.0), Vector2(-180.0, 0.0), p0)
  _assert(bool(head_on["closing"]), "straight-on mob radially closes on creature")

  var tangent := _Risk.mob_closing_metrics(Vector2(150.0, 0.0), Vector2(0.0, 200.0), p0)
  _assert(not bool(tangent["closing"]), "perpendicular mover is not radially closing")

  var still := _Risk.mob_closing_metrics(Vector2(80.0, 0.0), Vector2.ZERO, p0)
  _assert(not bool(still["closing"]), "stationary mob skips closing heuristic")

  var corner_sb := Callable(_Risk, &"classify_creature_patch_and_band").call(0, 0, 12, 10, Vector2.ZERO) as Dictionary
  _assert(str(corner_sb.get("patch", "")) == "corner", "corner cell label")
  _assert(str(corner_sb.get("band", "")) == "stopped", "zero velocity reads stopped")

  var wall_lab := Callable(_Risk, &"classify_creature_patch_and_band").call(0, 5, 12, 10, Vector2.ZERO) as Dictionary
  _assert(str(wall_lab.get("patch", "")) == "wall", "top-edge non-corner is wall")

  var interior_mv := Callable(_Risk, &"classify_creature_patch_and_band").call(4, 4, 12, 10, Vector2(50.0, 0.0)) as Dictionary
  _assert(str(interior_mv.get("patch", "")) == "interior", "interior cell")
  _assert(str(interior_mv.get("band", "")) == "moving", "nonzero speed reads moving")

  var prio_mobs_nearest_first: Array = [
    {"point": Vector2(40.0, 0.0), "velocity": Vector2(-200.0, 0.0)},
    {"point": Vector2(80.0, 0.0), "velocity": Vector2(-150.0, 0.0)},
  ]
  var pr: Dictionary = _Risk.pick_priority_closing_mob(prio_mobs_nearest_first, p0)
  _assert(int(pr["idx_1"]) == 1, "nearest fastest closer wins when time-to-close shortest")

  var rh := _Wire.format_risk_hints_line(-1, INF, "interior", "moving")
  _assert(
    rh.begins_with("RISK_HINTS ") and rh.contains("CLOSEST_CLOSING_I=-1") and rh.contains("CREATURE_PATCH"),
    "risk hint formatter no closer"
  )


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
