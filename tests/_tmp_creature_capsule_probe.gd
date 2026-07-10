extends SceneTree

const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")


func _init() -> void:
  _probe_creature(
    "fox",
    "res://creature/templates/creature_carnivore_kinematic_3d.tscn",
    "res://creature/species/fox_archetype.tres",
  )
  _probe_creature(
    "rabbit",
    "res://creature/templates/creature_herbivore_kinematic_3d.tscn",
    "res://creature/species/rabbit_archetype.tres",
  )
  quit(0)


func _probe_creature(label: String, scene_path: String, def_path: String) -> void:
  var ps: PackedScene = load(scene_path) as PackedScene
  var def: Resource = load(def_path) as Resource
  if ps == null or def == null:
    print("%s load fail" % label)
    return
  var creature_root := ps.instantiate() as Node3D
  get_root().add_child(creature_root)
  creature_root.set("definition", def)
  if creature_root.has_method(&"_propagate_definition_to_children"):
    creature_root.call("_propagate_definition_to_children")
  var body := creature_root.get_node_or_null("Body") as Node3D
  var visual := body.get_node_or_null("Visual") if body != null else null
  if visual == null:
    print("%s no visual" % label)
    return
  var acc: Array = [Vector3(INF, INF, INF), Vector3(-INF, -INF, -INF)]
  _Bounds3D._accumulate_mesh_bounds(visual, acc)
  var mn: Vector3 = acc[0]
  var mx: Vector3 = acc[1]
  var sx := mx.x - mn.x
  var sy := mx.y - mn.y
  var sz := mx.z - mn.z
  var radius := maxf(sx, sz) * 0.5
  var height := maxf(0.05, sy - 2.0 * radius)
  var cs := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
  var cap_r := -1.0
  var cap_h := -1.0
  if cs != null and cs.shape is CapsuleShape3D:
    var cap := cs.shape as CapsuleShape3D
    cap_r = cap.radius
    cap_h = cap.height
  print(
    "%s mesh sx=%.3f sy=%.3f sz=%.3f fit_r=%.3f fit_h=%.3f cap_r=%.3f cap_h=%.3f body_scale=%s"
    % [label, sx, sy, sz, radius, height, cap_r, cap_h, str(body.scale)]
  )
