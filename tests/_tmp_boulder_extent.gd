extends SceneTree

const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")


func _init() -> void:
  var scene_root := Node3D.new()
  var boulder: PackedScene = load(
    "res://assets/environment/obstacle_boulder/h-k-boulder1.blend",
  ) as PackedScene
  if boulder == null:
    push_error("boulder scene failed to load")
    quit(1)
    return
  var rock := boulder.instantiate() as Node3D
  scene_root.add_child(rock)
  _dump_tree(rock, 0)
  var col_acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  var mesh_acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  _Bounds3D._accumulate_collision_bounds(rock, col_acc)
  _Bounds3D._accumulate_mesh_bounds(rock, mesh_acc)
  _print_acc("collision", col_acc)
  _print_acc("mesh", mesh_acc)
  quit(0)


func _print_acc(label: String, acc: Array) -> void:
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  print(
    "%s mn=%.3f,%.3f,%.3f mx=%.3f,%.3f,%.3f xz_diameter=%.3f,%.3f"
    % [label, mn.x, mn.y, mn.z, mx.x, mx.y, mx.z, mx.x - mn.x, mx.z - mn.z]
  )


func _dump_tree(node: Node, depth: int) -> void:
  var indent := "  ".repeat(depth)
  var extra := ""
  if node is CollisionShape3D:
    var cs := node as CollisionShape3D
    var sh: Shape3D = cs.shape
    if sh is BoxShape3D:
      extra = " BoxShape3D size=%s" % str((sh as BoxShape3D).size)
    elif sh is ConvexPolygonShape3D:
      extra = " ConvexPolygonShape3D"
    elif sh is ConcavePolygonShape3D:
      extra = " ConcavePolygonShape3D"
    elif sh != null:
      extra = " shape=%s" % sh.get_class()
  elif node is MeshInstance3D:
    var mi := node as MeshInstance3D
    if mi.mesh != null:
      extra = " aabb=%s" % str(mi.mesh.get_aabb())
  print("%s%s %s%s" % [indent, node.get_class(), node.name, extra])
  for ch in node.get_children():
    _dump_tree(ch, depth + 1)
