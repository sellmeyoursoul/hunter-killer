## Static helpers to build a merged game config from defaults + [code]user://game_config.json[/code].
## Used by the **GameConfig** autoload and by [code]tests/run_all.gd[/code].
extends Object


## Default [code]logging_params[/code] when the file is missing or incomplete (matches OLog fallbacks).
static func default_logging_params() -> Dictionary:
  return {
    "LOG_LEVEL": "Error",
    "MAX_LINES_PER_PROCESS": 128,
    "MAX_QUEUE_ENTRIES": 1024,
  }


## Defaults for [code]perception[/code] (§4.2 snapshot stride vs inference period).
static func default_perception_params() -> Dictionary:
  return {
    "SNAPSHOT_PHYSICS_STRIDE": 1,
  }


## Defaults for [code]inference_client[/code]; empty [code]INFERENCE_BASE_URL[/code] means AI cannot arm until set.
static func default_inference_client() -> Dictionary:
  return {
    "INFERENCE_BASE_URL": "",
    "COMPLETIONS_PATH": "/v1/completions",
    "CHAT_COMPLETIONS_PATH": "/v1/chat/completions",
    "MODEL_ID": "",
    "API_KEY": "",
    "HTTP_TIMEOUT_MS": 8000,
    "INFERENCE_PERIOD_MS": 250,
    "MAX_OUTPUT_TOKENS": 48,
    "LLAMA_COMPLETION_GRAMMAR_ENABLED": true,
    "TEMPERATURE": 0.0,
    "INFERENCE_AUTO_START_ENABLED": false,
    "BUNDLE_ROOT_OVERRIDE": "",
    "BUNDLED_SERVER_EXE": "",
    "BUNDLED_MODEL_GGUF": "",
    "BUNDLED_SERVER_ARGS": ["--no-mmap", "-ngl", "0"],
    "INFERENCE_PROBE_PATH": "/health",
    "INFERENCE_START_TIMEOUT_MS": 300000,
    "BUNDLED_SERVER_ATTACH_CONSOLE": true,
  }


## Full default root object (before reading the file).
static func default_root() -> Dictionary:
  return {
    "logging_params": default_logging_params(),
    "inference_client": default_inference_client(),
    "perception": default_perception_params(),
  }


## Shallow-merges [param over] into a duplicate of [param base] (both dictionary-valued sections).
static func _merge_dict_shallow(base: Dictionary, over: Variant) -> Dictionary:
  var out := base.duplicate(true)
  if typeof(over) != TYPE_DICTIONARY:
    return out
  var d: Dictionary = over
  for k in d:
    out[k] = d[k]
  return out


## Merges a parsed file root [param file_root] over [param defaults_root] for known top-level keys.
static func merge_root(defaults_root: Dictionary, file_root: Dictionary) -> Dictionary:
  var r := defaults_root.duplicate(true)
  if file_root.has("logging_params"):
    r["logging_params"] = _merge_dict_shallow(r["logging_params"], file_root["logging_params"])
  if file_root.has("inference_client"):
    r["inference_client"] = _merge_dict_shallow(r["inference_client"], file_root["inference_client"])
  if file_root.has("perception"):
    r["perception"] = _merge_dict_shallow(r["perception"], file_root["perception"])
  return r


## Loads [code]user://game_config.json[/code] merged over [code]res://game_config.json[/code] (repo template) over hardcoded defaults.
## Use this for runtime so a missing user file still picks up dev inference defaults from the repo template.
## Params:
## - user_path: Optional override (mainly for tests).
## Returns:
## - [code]{ "merged": Dictionary, "diagnostic": String }[/code]; [param diagnostic] empty when user file loaded OK.
static func load_merged_config(user_path: String = "user://game_config.json") -> Dictionary:
  const repo_template := "res://game_config.json"
  var merged: Dictionary = default_root()
  if FileAccess.file_exists(repo_template):
    var rtxt := FileAccess.get_file_as_string(repo_template)
    var rjson := JSON.new()
    if rjson.parse(rtxt) == OK and typeof(rjson.data) == TYPE_DICTIONARY:
      merged = merge_root(merged, rjson.data)
  if not FileAccess.file_exists(user_path):
    return {
      "merged": merged,
      "diagnostic": "%s is missing — merged [code]res://game_config.json[/code] template when present." % user_path,
    }
  var utxt := FileAccess.get_file_as_string(user_path)
  var ujson := JSON.new()
  var err := ujson.parse(utxt)
  if err != OK:
    return {
      "merged": merged,
      "diagnostic": "%s JSON parse error (code %s) — kept merged defaults + repo template." % [user_path, err],
    }
  if typeof(ujson.data) != TYPE_DICTIONARY:
    return {
      "merged": merged,
      "diagnostic": "%s root must be a JSON object — kept merged defaults + repo template." % user_path,
    }
  merged = merge_root(merged, ujson.data)
  return {"merged": merged, "diagnostic": ""}


## Loads JSON from [param path], merges into defaults, returns [code]{ "merged": Dictionary, "diagnostic": String }[/code].
## [param diagnostic] is empty on full success; otherwise a single human-readable reason (file missing, parse error, wrong root type).
static func load_merge_from_path(path: String) -> Dictionary:
  var base := default_root()
  if not FileAccess.file_exists(path):
    return {
      "merged": base,
      "diagnostic": "%s is missing — using defaults." % path,
    }
  var txt := FileAccess.get_file_as_string(path)
  var json := JSON.new()
  var err := json.parse(txt)
  if err != OK:
    return {
      "merged": base,
      "diagnostic": "%s JSON parse error (code %s) — using defaults." % [path, err],
    }
  var root = json.data
  if typeof(root) != TYPE_DICTIONARY:
    return {
      "merged": base,
      "diagnostic": "%s root must be a JSON object — using defaults." % path,
    }
  var merged: Dictionary = merge_root(base, root)
  return {
    "merged": merged,
    "diagnostic": "",
  }
