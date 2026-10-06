extends Node
## Autoload **GameConfig**: loads and merges [code]user://game_config.json[/code] before **OLog** initializes.
## Provides merged [code]logging_params[/code], [code]perception[/code], [code]creature_motor[/code], [code]creature_motor_v3[/code], and [code]playfield_spawn[/code] with safe defaults.

const CONFIG_PATH := "user://game_config.json"
const _Merge := preload("res://AI_int_lib/game_config_merge.gd")

var _merged: Dictionary = {}
var _diagnostic: String = ""


func _ready() -> void:
  _reload_from_disk()


## Reloads config from disk (e.g. after the user fixes JSON). Called once at startup by default.
func _reload_from_disk() -> void:
  var result: Dictionary = _Merge.load_merged_config(CONFIG_PATH)
  _merged = result["merged"]
  _diagnostic = str(result.get("diagnostic", ""))
  _apply_dev_logging_override()


## Dev runs (editor binary, incl. headless smokes via [code]--path[/code]): the repo [code]res://game_config.json[/code]
## [code]logging_params[/code] wins over a stale [code]user://game_config.json[/code] copy, so editing the repo file
## (e.g. [code]LOG_LEVEL[/code] = Debug) takes effect. Exported builds keep user:// precedence.
## Root cause it fixes: a user:// copy with [code]"LOG_LEVEL": "Info"[/code] silently shadowed the repo's Debug.
func _apply_dev_logging_override() -> void:
  if not OS.has_feature("editor"):
    return
  const repo_template := "res://game_config.json"
  if not FileAccess.file_exists(repo_template):
    return
  var rjson := JSON.new()
  if rjson.parse(FileAccess.get_file_as_string(repo_template)) != OK:
    return
  if typeof(rjson.data) != TYPE_DICTIONARY:
    return
  var repo_lp: Variant = (rjson.data as Dictionary).get("logging_params", null)
  if typeof(repo_lp) != TYPE_DICTIONARY:
    return
  var lp: Dictionary = _merged.get("logging_params", {}).duplicate(true)
  for k in (repo_lp as Dictionary):
    lp[k] = repo_lp[k]
  _merged["logging_params"] = lp


## Non-empty when [code]user://game_config.json[/code] failed to load (parse error, wrong root type). A missing user file is normal on first run: [code]load_merged_config[/code] still merges [code]res://game_config.json[/code] plus defaults and leaves this diagnostic empty.
func get_config_load_diagnostic() -> String:
  return _diagnostic


## Merged [code]logging_params[/code]; always a dictionary suitable for [code]OLog[/code].
func get_logging_params() -> Dictionary:
  var lp: Variant = _merged.get("logging_params", {})
  if typeof(lp) != TYPE_DICTIONARY:
    return _Merge.default_logging_params()
  return lp.duplicate(true)


## Merged [code]perception[/code] (e.g. [code]SNAPSHOT_PHYSICS_STRIDE[/code]).
func get_perception_params() -> Dictionary:
  var p: Variant = _merged.get("perception", {})
  if typeof(p) != TYPE_DICTIONARY:
    return _Merge.default_perception_params()
  return p.duplicate(true)


## Merged [code]creature_motor[/code] ([code]mode[/code]: [code]scripted[/code] or [code]llm[/code], plus avoidance tunables).
func get_creature_motor_params() -> Dictionary:
  var cm: Variant = _merged.get("creature_motor", {})
  if typeof(cm) != TYPE_DICTIONARY:
    return _Merge.default_creature_motor_params()
  return cm.duplicate(true)


## Merged [code]creature_motor_v3[/code] (V3 locomotion / hub / planner keys only).
func get_creature_motor_v3_params() -> Dictionary:
  var cm: Variant = _merged.get("creature_motor_v3", {})
  if typeof(cm) != TYPE_DICTIONARY:
    return _Merge.default_creature_motor_v3_params()
  return cm.duplicate(true)


## Body-dimensions width clearance margin ([code]creature_motor_v3.width_margin[/code], default 0.10).
## Returns the default if missing/non-numeric; clamped to >= 0.
func get_width_margin() -> float:
  return _get_v3_nonneg_float("width_margin", 0.10)


## Body-dimensions reach margin fraction ([code]creature_motor_v3.reach_margin_fraction[/code], default 0.25).
## Returns the default if missing/non-numeric; clamped to >= 0.
func get_reach_margin_fraction() -> float:
  return _get_v3_nonneg_float("reach_margin_fraction", 0.25)


## Reads a numeric [code]creature_motor_v3[/code] key; falls back to [param fallback] when missing,
## non-numeric, or NaN/inf; result clamped to >= 0.
func _get_v3_nonneg_float(key: String, fallback: float) -> float:
  var v: Variant = get_creature_motor_v3_params().get(key, fallback)
  if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
    return fallback
  var f := float(v)
  if is_nan(f) or is_inf(f):
    return fallback
  return maxf(f, 0.0)


## Merged [code]playfield_spawn[/code] ([code]seed[/code], [code]locked_layout_path[/code]).
func get_playfield_spawn_params() -> Dictionary:
  var ps: Variant = _merged.get("playfield_spawn", {})
  if typeof(ps) != TYPE_DICTIONARY:
    return _Merge.default_playfield_spawn_params()
  return ps.duplicate(true)


## Spine + profile + optional pack [code]creature_motor[/code] overlay for one creature instance.
func get_creature_motor_params_for_pack(pack_root: String) -> Dictionary:
  var base := get_creature_motor_params()
  return _Merge.merge_creature_motor_pack_overlay(base, pack_root)


## Defaults + optional pack [code]creature_motor_v3[/code] overlay for one creature instance.
func get_creature_motor_v3_params_for_pack(pack_root: String) -> Dictionary:
  var base := get_creature_motor_v3_params()
  return _Merge.merge_creature_motor_v3_pack_overlay(base, pack_root)


## Full merged root (advanced callers / tests).
func get_merged_root() -> Dictionary:
  return _merged.duplicate(true)
