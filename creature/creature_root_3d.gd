extends Node3D
class_name CreatureRoot3D
## 3D creature orchestrator: owns [member definition]; template scenes place [code]Body[/code] (kinematic or rigid) + [code]Vitals[/code].

const _DefScript := preload("res://creature/definition/creature_definition.gd")

const _SPECIES_MESH_FILE: Dictionary = {
  &"rabbit": "rabbit.blend",
  &"fox": "fox.blend",
}

@export var definition: Variant


func _ready() -> void:
  call_deferred("_propagate_definition_to_children")


## Deferred so child [code]_ready[/code] runs first; then we assign [member definition] on Body and Vitals.
func _propagate_definition_to_children() -> void:
  if definition == null or definition.get_script() != _DefScript:
    return
  var body := get_node_or_null("Body")
  if body != null:
    body.set("definition", definition)
  var vitals := get_node_or_null("Vitals")
  if vitals != null and vitals.has_method(&"apply_parent_definition"):
    vitals.call(&"apply_parent_definition", definition)
  _mount_visual_from_definition()


## Body child when present — visuals must follow [code]move_and_slide[/code] on [code]Body[/code], not the static root.
func _visual_parent() -> Node:
  return get_node_or_null("Body") if get_node_or_null("Body") != null else self


## Instantiates [member CreatureDefinition.variant_scene] or species [code].blend[/code] under [code]Visual[/code] (no collision).
func _mount_visual_from_definition() -> void:
  var mount := _visual_parent()
  if mount.get_node_or_null("Visual") != null:
    return
  var variant: Variant = definition.get("variant_scene")
  if variant is PackedScene:
    _attach_visual_scene(variant as PackedScene, mount)
    return
  var pack_root := str(definition.get("asset_pack_root")).strip_edges()
  var species: StringName = definition.get("species_id")
  var mesh_file: String = str(_SPECIES_MESH_FILE.get(species, ""))
  if mesh_file.is_empty() or pack_root.is_empty():
    return
  var path := "%s/%s" % [pack_root, mesh_file]
  if not ResourceLoader.exists(path):
    return
  var ps := load(path) as PackedScene
  if ps == null:
    return
  _attach_visual_scene(ps, mount)


func _attach_visual_scene(ps: PackedScene, mount: Node) -> void:
  var inst := ps.instantiate() as Node3D
  if inst == null:
    return
  inst.name = "Visual"
  _disable_collision_recursive(inst)
  mount.add_child(inst)


func _disable_collision_recursive(node: Node) -> void:
  if node is CollisionObject3D:
    var co := node as CollisionObject3D
    co.collision_layer = 0
    co.collision_mask = 0
  for ch in node.get_children():
    _disable_collision_recursive(ch)
