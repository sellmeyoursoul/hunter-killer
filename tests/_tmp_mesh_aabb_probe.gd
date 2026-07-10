extends SceneTree

const _StaticObs := preload("res://environment/static_obstacle_collision.gd")
const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")


func _init() -> void:
  var holder := Node3D.new()
  get_root().add_child(holder)
  _probe_blend(holder, "fox", "res://assets/creatures/fox/fox.blend")
  _probe_blend(holder, "rabbit", "res://assets/creatures/rabbit/rabbit.blend")
  _probe_scene(holder, "solid_shrub", "res://assets/plants/solid_shrub/solid_shrub_3d.tscn")
  _probe_scene(holder, "open_shrub", "res://assets/plants/open_shrub/open_shrub_3d.tscn")
  quit(0)


func _probe_blend(parent: Node3D, label: String, path: String) -> void:
  var ps: PackedScene = load(path) as PackedScene
  if ps == null:
    print("%s FAILED load" % label)
    return
  var scene_root := ps.instantiate() as Node3D
  parent.add_child(scene_root)
  var aabb := _StaticObs.world_mesh_aabb(scene_root)
  print("%s aabb=%s" % [label, str(aabb)])


func _probe_scene(parent: Node3D, label: String, path: String) -> void:
  var ps: PackedScene = load(path) as PackedScene
  if ps == null:
    print("%s FAILED load" % label)
    return
  var scene_root := ps.instantiate() as Node3D
  parent.add_child(scene_root)
  if scene_root.has_method(&"_ready"):
    scene_root.call("_ready")
  var visual := scene_root.get_node_or_null("Visual/ReadyVisual") as Node3D
  if visual == null:
    visual = scene_root.get_node_or_null("Visual") as Node3D
  var aabb := _StaticObs.world_mesh_aabb(visual)
  var blocker := scene_root.get_node_or_null("StaticBody3D") as StaticBody3D
  if blocker == null:
    blocker = scene_root.get_node_or_null("MobBlocker") as StaticBody3D
  var shapes := 0
  if blocker != null:
    for ch in blocker.get_children():
      if ch is CollisionShape3D:
        shapes += 1
  print("%s visual_aabb=%s blocker_shapes=%d" % [label, str(aabb), shapes])
