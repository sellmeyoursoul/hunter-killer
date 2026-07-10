extends Node3D
class_name CreatureRoot3D
## 3D creature orchestrator: owns [member definition]; template scenes place [code]Body[/code] (kinematic or rigid) + [code]Vitals[/code].

const _DefScript := preload("res://creature/definition/creature_definition.gd")
const _CreatureMotorStack := preload("res://creature/motor/creature_motor_stack.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

var _motor_stack: RefCounted

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
  call_deferred("configure_motor_stack")


## Deferred after definition propagation — wires V3 motor stack to Body + Vitals.
func configure_motor_stack() -> void:
  if definition == null or definition.get_script() != _DefScript:
    return
  var body := get_motor_body()
  if body == null:
    return
  var vitals := get_node_or_null("Vitals")
  var pack_root := str(definition.get("asset_pack_root")).strip_edges()
  var motor_v3 := _merged_creature_motor_v3(pack_root)
  var main: Node = get_tree().current_scene if is_inside_tree() else null
  motor_v3 = _MotorPlane.scale_creature_motor_v3_for_playfield(motor_v3, body, main)
  if _motor_stack == null:
    _motor_stack = _CreatureMotorStack.new()
  var catalog := _GkReg.goal_kind_catalog_for_pack(pack_root)
  _motor_stack.configure(body, vitals, motor_v3, pack_root, catalog)
  if body.has_method(&"set_use_v3_action_calories"):
    body.call(&"set_use_v3_action_calories", true)
  if body.has_method(&"set_motor_stack_drives_physics"):
    body.call(&"set_motor_stack_drives_physics", true)


## Public motor tick entry for [code]AiDriver[/code] ([CREATURE_MOVEMENT_V3.md §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func motor_stack_tick(delta: float) -> ActionOutcome:
  if _motor_stack == null:
    return ActionOutcome.new()
  return _motor_stack.tick(delta) as ActionOutcome


## Stack-owned memory reset — called on duel/session teardown (6d.2 slice 0).
func reset_motor_memory() -> void:
  if _motor_stack != null and _motor_stack.has_method(&"reset_memory"):
    _motor_stack.call(&"reset_memory")


## EAT outcome locale write + kind EWMA — routes to this creature's stack adapter (§6.2).
func notify_food_consumption_outcome(
  food_anchor: Vector2,
  insufficient_yield: bool = false,
  stimulus_kind_id: StringName = &"",
  calories_gained: int = 0,
) -> void:
  if _motor_stack == null:
    return
  if _motor_stack.has_method(&"notify_food_consumption_outcome"):
    _motor_stack.call(
      &"notify_food_consumption_outcome",
      Vector3(food_anchor.x, 0.0, food_anchor.y),
      insufficient_yield,
      stimulus_kind_id,
      calories_gained,
    )


func get_motor_stack() -> RefCounted:
  return _motor_stack


func get_motor_body() -> CharacterBody3D:
  var body := get_node_or_null("Body")
  return body as CharacterBody3D if body is CharacterBody3D else null


func _merged_creature_motor_v3(pack_root: String) -> Dictionary:
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_v3_params_for_pack"):
    return gc.call(&"get_creature_motor_v3_params_for_pack", pack_root) as Dictionary
  var merge := preload("res://AI_int_lib/game_config_merge.gd")
  return merge.merge_creature_motor_v3_pack_overlay(
    merge.default_creature_motor_v3_params(),
    pack_root,
  )


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
  var body := mount as CharacterBody3D
  if body != null and body.has_method(&"apply_capsule_footprint_from_visual"):
    body.call(&"apply_capsule_footprint_from_visual", inst)


func _disable_collision_recursive(node: Node) -> void:
  if node is CollisionObject3D:
    var co := node as CollisionObject3D
    co.collision_layer = 0
    co.collision_mask = 0
  for ch in node.get_children():
    _disable_collision_recursive(ch)
