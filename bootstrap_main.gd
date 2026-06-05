extends Node
## Routes to [code]main_3d.tscn[/code] or legacy [code]main.tscn[/code] per [code]Use-2d[/code] ([CONVERT_TO_3D.md §D2](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).

const _MAIN_3D := "res://main_3d.tscn"
const _MAIN_2D := "res://main.tscn"


func _ready() -> void:
  var use_2d := false
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"use_2d"):
    use_2d = gc.call(&"use_2d")
  var path := _MAIN_2D if use_2d else _MAIN_3D
  if not ResourceLoader.exists(path):
    push_error("bootstrap_main: missing scene %s" % path)
    get_tree().quit(1)
    return
  get_tree().call_deferred("change_scene_to_file", path)
