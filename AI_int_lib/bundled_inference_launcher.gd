## Probes [code]INFERENCE_BASE_URL[/code] and optionally spawns a bundled OpenAI-compatible server next to the exported game.
## Params: parent [Node] must be in the scene tree (owns temporary [HTTPRequest] nodes).
extends Node

const _PROBE_POLL_SEC := 0.5
const _PROBE_HTTP_MIN_SEC := 15.0
## After `/health` returns 503 (“loading”), allow a longer probe window — load can stall HTTP replies past the normal probe budget.
const _PROBE_HTTP_AFTER_503_SEC := 90.0
const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")

## Absolute directory containing the player executable (exported) or dev fallback under the project.
static func get_bundle_root(inference_client: Dictionary) -> String:
  var o := str(inference_client.get("BUNDLE_ROOT_OVERRIDE", "")).strip_edges()
  if not o.is_empty():
    return o.replace("\\", "/").trim_suffix("/")
  if OS.has_feature("editor"):
    var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
    var dev_fallback := "%s/%s" % [project, _dev_inference_subdir()]
    if DirAccess.dir_exists_absolute(dev_fallback):
      return dev_fallback
  return OS.get_executable_path().get_base_dir().replace("\\", "/")


static func _dev_inference_subdir() -> String:
  match OS.get_name():
    "Windows":
      return "inference/windows"
    "macOS":
      return "inference/macos"
    _:
      return "inference/linux"


## True when config requests auto-start and the URL is loopback-only (do not spawn for remote APIs).
static func should_attempt_auto_start(inference_client: Dictionary, base_url: String) -> bool:
  if not _truthy(inference_client.get("INFERENCE_AUTO_START_ENABLED", false)):
    return false
  return _is_loopback_http_url(base_url)


static func _truthy(v: Variant) -> bool:
  if typeof(v) == TYPE_BOOL:
    return v
  var s := str(v).strip_edges().to_lower()
  return s == "1" or s == "true" or s == "yes"


static func _is_loopback_http_url(url: String) -> bool:
  var u := url.strip_edges().to_lower()
  return u.begins_with("http://127.0.0.1") or u.begins_with("http://localhost")


## Parses host port from [code]http://127.0.0.1:8080[/code] style URLs; defaults to 8080 if missing.
static func port_from_base_url(base_url: String) -> int:
  var u := base_url.strip_edges()
  var after_scheme := u
  if after_scheme.to_lower().begins_with("http://"):
    after_scheme = after_scheme.substr(7)
  elif after_scheme.to_lower().begins_with("https://"):
    after_scheme = after_scheme.substr(8)
  var colon := after_scheme.find(":")
  if colon < 0:
    return 8080
  var rest := after_scheme.substr(colon + 1)
  var slash := rest.find("/")
  var port_part := rest if slash < 0 else rest.substr(0, slash)
  if port_part.is_empty():
    return 8080
  var p := int(port_part)
  return p if p > 0 else 8080


## Ensures [code]GET base_url + probe_path[/code] succeeds, optionally spawning the bundled server first.
## Params:
## - inference_client: merged [code]GameConfig.get_inference_client()[/code] dict.
## Returns:
## - [code]true[/code] when the probe succeeds within [code]INFERENCE_START_TIMEOUT_MS[/code].
func ensure_inference_endpoint_ready(inference_client: Dictionary) -> bool:
  var base_url := str(inference_client.get("INFERENCE_BASE_URL", "")).strip_edges().rstrip("/")
  var probe_rel := str(inference_client.get("INFERENCE_PROBE_PATH", "/health")).strip_edges()
  if not probe_rel.begins_with("/"):
    probe_rel = "/%s" % probe_rel
  var probe_url := "%s%s" % [base_url, probe_rel]
  var timeout_ms := maxi(1000, int(inference_client.get("INFERENCE_START_TIMEOUT_MS", 60000)))
  var configured_http_sec := maxf(1.0, float(inference_client.get("HTTP_TIMEOUT_MS", 8000)) / 1000.0)
  var probe_http_sec := maxf(_PROBE_HTTP_MIN_SEC, configured_http_sec)

  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H1,H3,H4",
    "location": "bundled_inference_launcher.gd:ensure_entry",
    "message": "ensure_inference_endpoint_ready_start",
    "data": {
      "probe_url": probe_url,
      "timeout_ms": timeout_ms,
      "configured_http_sec": configured_http_sec,
      "probe_http_sec": probe_http_sec,
      "probe_http_min_sec": _PROBE_HTTP_MIN_SEC,
      "auto_start": should_attempt_auto_start(inference_client, base_url),
    },
  })
  #endregion

  var initial_pr := await _http_probe(probe_url, probe_http_sec)
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H1,H3",
    "location": "bundled_inference_launcher.gd:initial_probe",
    "message": "initial_http_probe",
    "data": {
      "probe_url": probe_url,
      "ok": initial_pr["ok"],
      "http_request_result": initial_pr["result"],
      "response_code": initial_pr["response_code"],
    },
  })
  #endregion
  if initial_pr["ok"]:
    return true

  if not should_attempt_auto_start(inference_client, base_url):
    var detail := ""
    if not _truthy(inference_client.get("INFERENCE_AUTO_START_ENABLED", false)):
      detail = (
        " INFERENCE_AUTO_START_ENABLED is false — start an OpenAI-compatible server at %s "
        + "or set INFERENCE_AUTO_START_ENABLED true with BUNDLED_SERVER_EXE and BUNDLED_MODEL_GGUF."
      ) % base_url
    elif not _is_loopback_http_url(base_url):
      detail = " Remote INFERENCE_BASE_URL — auto-start only runs for http://127.0.0.1 or http://localhost."
    OLog.error(
      "BundledInference: inference not reachable at %s.%s" % [probe_url, detail],
      true,
      "BundledInference"
    )
    return false

  var bundle_root := get_bundle_root(inference_client)
  var exe_rel := str(inference_client.get("BUNDLED_SERVER_EXE", "")).strip_edges()
  var model_rel := str(inference_client.get("BUNDLED_MODEL_GGUF", "")).strip_edges()
  if exe_rel.is_empty() or model_rel.is_empty():
    OLog.error(
      "BundledInference: set BUNDLED_SERVER_EXE and BUNDLED_MODEL_GGUF (relative to bundle root).",
      true,
      "BundledInference"
    )
    return false

  var exe_abs := "%s/%s" % [bundle_root, exe_rel.replace("\\", "/")]
  var model_abs := "%s/%s" % [bundle_root, model_rel.replace("\\", "/")]
  if not FileAccess.file_exists(exe_abs):
    OLog.error("BundledInference: server executable missing: %s" % exe_abs, true, "BundledInference")
    return false
  if not FileAccess.file_exists(model_abs):
    OLog.error("BundledInference: model file missing: %s" % model_abs, true, "BundledInference")
    return false

  var argv := PackedStringArray()
  argv.append("-m")
  argv.append(model_abs)
  _append_extra_server_args(argv, inference_client.get("BUNDLED_SERVER_ARGS", []))
  var port := port_from_base_url(base_url)
  argv.append("--host")
  argv.append("127.0.0.1")
  argv.append("--port")
  argv.append(str(port))

  var open_console := OS.has_feature("editor") and OS.get_name() == "Windows"

  OLog.info(
    "BundledInference: starting server (pid TBD) — %s" % exe_abs.get_file(),
    true,
    "BundledInference"
  )
  var pid := OS.create_process(exe_abs, argv, open_console)
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H2",
    "location": "bundled_inference_launcher.gd:create_process",
    "message": "after_create_process",
    "data": {
      "pid": pid,
      "exe_file": exe_abs.get_file(),
      "open_console_spawn": open_console,
      "argv_count": argv.size(),
    },
  })
  #endregion
  if pid <= 0:
    OLog.error("BundledInference: OS.create_process failed for %s" % exe_abs, true, "BundledInference")
    return false

  var deadline := Time.get_ticks_msec() + timeout_ms
  var post_spawn_polls := 0
  var extend_probe_after_loading := false
  ## True after any probe completes without HTTPRequest.TIMEOUT (e.g. TCP connects or explicit failure); avoids 15s caps while the server has not bound yet.
  var saw_non_timeout_response := false
  while Time.get_ticks_msec() < deadline:
    post_spawn_polls += 1
    var probe_seconds := probe_http_sec
    if not saw_non_timeout_response:
      probe_seconds = maxf(probe_http_sec, _PROBE_HTTP_AFTER_503_SEC)
    elif extend_probe_after_loading:
      probe_seconds = maxf(probe_http_sec, _PROBE_HTTP_AFTER_503_SEC)
    var poll_pr := await _http_probe(probe_url, probe_seconds)
    if poll_pr["result"] != HTTPRequest.RESULT_TIMEOUT:
      saw_non_timeout_response = true
    if (
      poll_pr["result"] == HTTPRequest.RESULT_SUCCESS
      and int(poll_pr["response_code"]) == 503
    ):
      extend_probe_after_loading = true
    #region agent log
    var _log_this_poll: bool = (
      post_spawn_polls <= 5
      or post_spawn_polls % 10 == 0
      or poll_pr["ok"]
    )
    if _log_this_poll:
      _AgentNdjson.write({
        "runId": "ai-arm",
        "hypothesisId": "H1,H3,H5",
        "location": "bundled_inference_launcher.gd:poll_probe",
        "message": "post_spawn_probe",
        "data": {
          "poll_index": post_spawn_polls,
          "ok": poll_pr["ok"],
          "http_request_result": poll_pr["result"],
          "response_code": poll_pr["response_code"],
          "probe_seconds": probe_seconds,
          "extend_after_503": extend_probe_after_loading,
          "saw_non_timeout_response": saw_non_timeout_response,
          "open_console_spawn": open_console,
          "process_running": OS.is_process_running(pid),
          "probe_url": probe_url,
          "ticks_left": deadline - Time.get_ticks_msec(),
        },
      })
    #endregion
    if poll_pr["ok"]:
      OLog.info("BundledInference: inference endpoint ready.", true, "BundledInference")
      return true
    # Spawned PID from OS.create_process can be a short-lived launcher when open_console=true; do not infer crash from PID there.
    if poll_pr["result"] != HTTPRequest.RESULT_SUCCESS:
      await get_tree().process_frame
      await get_tree().process_frame
      if not open_console and not OS.is_process_running(pid):
        #region agent log
        _AgentNdjson.write({
          "runId": "ai-arm",
          "hypothesisId": "H1,H6",
          "location": "bundled_inference_launcher.gd:child_exited",
          "message": "llama_server_process_not_running_after_failed_probe",
          "data": {
            "poll_index": post_spawn_polls,
            "last_http_result": poll_pr["result"],
            "last_response_code": poll_pr["response_code"],
            "pid": pid,
          },
        })
        #endregion
        OLog.error(
          (
            "BundledInference: llama-server exited before %s responded (poll %s, pid=%s, last_http_result=%s). "
            + "Run from editor to see stderr in the spawned console window, or verify model/DLL deps."
            % [probe_url, post_spawn_polls, pid, poll_pr["result"]]
          ),
          true,
          "BundledInference"
        )
        return false
    await get_tree().create_timer(_PROBE_POLL_SEC).timeout

  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H1,H3",
    "location": "bundled_inference_launcher.gd:probe_timeout",
    "message": "timeout_waiting_for_inference",
    "data": {
      "probe_url": probe_url,
      "polls_done": post_spawn_polls,
      "pid": pid,
      "open_console_spawn": open_console,
      "process_running_at_timeout": OS.is_process_running(pid),
    },
  })
  #endregion
  OLog.error(
    "BundledInference: timeout waiting for %s (started pid %s)." % [probe_url, pid],
    true,
    "BundledInference"
  )
  return false


static func _append_extra_server_args(argv: PackedStringArray, raw: Variant) -> void:
  if typeof(raw) == TYPE_ARRAY:
    for x in raw:
      var s := str(x).strip_edges()
      if not s.is_empty():
        argv.append(s)
    return
  var as_text := str(raw).strip_edges()
  if as_text.is_empty():
    return
  var j := JSON.new()
  if j.parse(as_text) == OK and typeof(j.data) == TYPE_ARRAY:
    for x in j.data:
      var s2 := str(x).strip_edges()
      if not s2.is_empty():
        argv.append(s2)


## Performs GET [param url]; returns TCP/HTTP-layer outcome for readiness probes ([code]/health[/code], [code]/v1/models[/code], etc.).
## Params:
## - url: Fully qualified HTTP GET target.
## - timeout_sec: Socket/body deadline for HTTPRequest (seconds).
## Returns:
## Dictionary: [code]result[/code] ([constant HTTPRequest.RESULT_SUCCESS] when transport OK), HTTP [code]response_code[/code], [code]ok[/code] when response is usable 2xx (503 “loading model” => [code]false[/code]).
func _http_probe(url: String, timeout_sec: float) -> Dictionary:
  var http := HTTPRequest.new()
  add_child(http)
  http.timeout = timeout_sec
  var err := http.request(url, [], HTTPClient.METHOD_GET)
  if err != OK:
    http.queue_free()
    return {"ok": false, "result": HTTPRequest.RESULT_REQUEST_FAILED, "response_code": -1}
  var state := {
    "done": false,
    "ok": false,
    "result": HTTPRequest.RESULT_NO_RESPONSE,
    "response_code": -1,
  }
  http.request_completed.connect(
    func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
      state["result"] = result
      state["response_code"] = response_code
      state["ok"] = (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
      state["done"] = true
      http.queue_free()
  )
  while not state["done"]:
    await get_tree().process_frame
  return {
    "ok": state["ok"],
    "result": state["result"],
    "response_code": state["response_code"],
  }
