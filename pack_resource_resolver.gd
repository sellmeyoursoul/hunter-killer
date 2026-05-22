## Resolves **`pack_resources.json` → `shared_resources`** entries for a domain pack, then falls back to **`assets/_shared/default/<kind>/`** when the tag is missing or the path does not load ([PackResourceResolver] implements **§2.1** of the archived asset plan).
## Params / returns:
## - **`pack_root`**: `res://` folder containing **`pack_resources.json`** (no trailing slash required).
## - **`tag`**: logical slot name inside **`shared_resources`**.
## - **`resolve_*` return**: `Dictionary` with **`path`** (`String`, always valid **`res://`**) and **`used_default`** (**`true`** when step 3 defaults won — treat as a bind failure for CI gameplay paths).
## Usage:
## [codeblock]
## var r: Dictionary = PackResourceResolver.resolve_texture_from_pack("res://assets/creatures/rabbit", "portrait")
## if r["used_default"]:
##     push_error("Missing rabbit portrait binding")
## var tex: Texture2D = load(r["path"]) as Texture2D
## [/codeblock]
extends RefCounted
class_name PackResourceResolver

const PATH_TEX_DEV := "res://assets/_shared/default/textures/missing_dev.png"
const PATH_TEX_RELEASE := "res://assets/_shared/default/textures/missing_release.png"
const PATH_AUDIO_DEV := "res://assets/_shared/default/audio/missing_dev.wav"
const PATH_AUDIO_RELEASE := "res://assets/_shared/default/audio/missing_release.wav"


## **`true`** when the loud dev defaults (**editor** or **debug** export) should apply instead of subtle release placeholders.
static func uses_editor_or_debug_profile() -> bool:
  return OS.has_feature("editor") or OS.is_debug_build()


## Canonical **`res://`** texture used when texture resolution falls through (**§2.1** profile split).
static func default_texture_res_path() -> String:
  return PATH_TEX_DEV if uses_editor_or_debug_profile() else PATH_TEX_RELEASE


## Canonical **`res://`** audio stream path used when audio resolution falls through.
static func default_audio_res_path() -> String:
  return PATH_AUDIO_DEV if uses_editor_or_debug_profile() else PATH_AUDIO_RELEASE


static func _normalized_pack_root(pack_root: String) -> String:
  var s := pack_root.strip_edges()
  while s.ends_with("/"):
    s = s.substr(0, s.length() - 1)
  return s


## Loads the full **`pack_resources.json`** root (empty **`Dictionary`** when missing or malformed).
static func load_pack_root(pack_root: String) -> Dictionary:
  var json_path := "%s/pack_resources.json" % _normalized_pack_root(pack_root)
  if not FileAccess.file_exists(json_path):
    return {}
  var txt := FileAccess.get_file_as_string(json_path)
  var parsed: Variant = JSON.parse_string(txt)
  if typeof(parsed) != TYPE_DICTIONARY:
    return {}
  return parsed


## **`creature_motor`** overlay from pack root ([CREATURE_MOVEMENT_V2.md §A.1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
static func load_creature_motor_overlay(pack_root: String) -> Dictionary:
  var root := load_pack_root(pack_root)
  var cm: Variant = root.get("creature_motor", {})
  if typeof(cm) != TYPE_DICTIONARY:
    return {}
  return cm


## Loads **`shared_resources`** only (empty **`Dictionary`** when **`pack_resources.json`** is absent or malformed).
static func load_shared_resources_map(pack_root: String) -> Dictionary:
  var json_path := "%s/pack_resources.json" % _normalized_pack_root(pack_root)
  if not FileAccess.file_exists(json_path):
    return {}
  var txt := FileAccess.get_file_as_string(json_path)
  var parsed: Variant = JSON.parse_string(txt)
  if typeof(parsed) != TYPE_DICTIONARY:
    return {}
  var root: Dictionary = parsed
  var sr: Variant = root.get("shared_resources", {})
  if typeof(sr) != TYPE_DICTIONARY:
    return {}
  return sr


static func _entry_res_path(entry: Variant) -> String:
  if typeof(entry) == TYPE_STRING:
    return str(entry).strip_edges()
  if typeof(entry) == TYPE_DICTIONARY:
    return str(entry.get("path", "")).strip_edges()
  return ""


static func _resource_path_exists(res_path: String) -> bool:
  if res_path.is_empty():
    return false
  return ResourceLoader.exists(res_path)


static func resolve_texture_from_pack(pack_root: String, tag: String) -> Dictionary:
  var shared := load_shared_resources_map(pack_root)
  var candidate := ""
  if shared.has(tag):
    candidate = _entry_res_path(shared[tag])
  if candidate != "" and _resource_path_exists(candidate):
    return {"path": candidate, "used_default": false}
  return {"path": default_texture_res_path(), "used_default": true}


static func resolve_audio_from_pack(pack_root: String, tag: String) -> Dictionary:
  var shared := load_shared_resources_map(pack_root)
  var candidate := ""
  if shared.has(tag):
    candidate = _entry_res_path(shared[tag])
  if candidate != "" and _resource_path_exists(candidate):
    return {"path": candidate, "used_default": false}
  return {"path": default_audio_res_path(), "used_default": true}
