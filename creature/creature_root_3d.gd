extends Node3D
class_name CreatureRoot3D
## 3D creature orchestrator: owns [member definition]; template scenes place [code]Body[/code] (kinematic or rigid) + [code]Vitals[/code].

const _DefScript := preload("res://creature/definition/creature_definition.gd")

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
