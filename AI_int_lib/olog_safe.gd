## Compile-safe forwarding to autoload [code]OLog[/code] via [code]/root/OLog[/code] on the scene tree.
## Use from scripts that may be parsed before autoload globals resolve (e.g. [code]godot --headless -s[/code] test entry).
extends Object


static func _node() -> Node:
  var ml := Engine.get_main_loop()
  if ml is SceneTree:
    return (ml as SceneTree).root.get_node_or_null("/root/OLog")
  return null


static func error(msg: String, console: bool, tag: String) -> void:
  var L := _node()
  if L != null and L.has_method("error"):
    L.call("error", msg, console, tag)


static func info(msg: String, console: bool, tag: String) -> void:
  var L := _node()
  if L != null and L.has_method("info"):
    L.call("info", msg, console, tag)


static func debug(msg: String, console: bool, tag: String) -> void:
  var L := _node()
  if L != null and L.has_method("debug"):
    L.call("debug", msg, console, tag)
