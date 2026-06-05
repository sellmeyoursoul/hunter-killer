extends Node3D
## M0 3D duel harness: ENGINE motor on kinematic templates via XZ adapter ([CONVERT_TO_3D.md §6 M0](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).
## Run from editor: [code]tests/scenes/duel_3d_m0.tscn[/code] — both creatures seek on the ground plane with no food/obstacles (parity tuning is M2).

const _HerbScene := preload("res://creature/templates/creature_herbivore_kinematic_3d.tscn")
const _CarnScene := preload("res://creature/templates/creature_carnivore_kinematic_3d.tscn")
const _RabbitArchetype := preload("res://creature/species/rabbit_archetype.tres")
const _FoxArchetype := preload("res://creature/species/fox_archetype.tres")
const _PlayerScr := preload("res://player.gd")

## Motor playfield size in world units (XZ ↔ motor plane per [MotorPlane](res://creature/motor/motor_plane.gd)).
const PLAYFIELD_SIZE := Vector2(40.0, 40.0)

var environment_grid: Resource = null
var _herbivore_root: Node3D
var _carnivore_root: Node3D
var _herb_body: CharacterBody3D
var _carn_body: CharacterBody3D


func _ready() -> void:
  _ensure_environment_grid()
  _attach_ai_driver()
  call_deferred("new_game")


func get_motor_playfield_size() -> Vector2:
  return PLAYFIELD_SIZE


func get_environment_grid() -> Resource:
  return environment_grid


func get_herbivore_motor_body() -> Node:
  return _herb_body


## Spawns herbivore + carnivore template bodies and starts an ENGINE duel round.
func new_game() -> void:
  _clear_creatures()
  var ad := _ai_driver()
  if ad != null:
    ad.clear_creature_registry()
  _spawn_duel_pair()
  if ad == null:
    return
  ad.register_creature(_herb_body)
  ad.register_creature(_carn_body)
  ad.sync_duel_control_modes()
  ad.set_duel_round_active(true)
  ad.set_primary_creature(_herb_body)
  ad.notify_main_new_game()


func _attach_ai_driver() -> void:
  var ad := _ai_driver()
  if ad == null or not ad.has_method(&"attach_main"):
    push_error("duel_3d_m0: AiDriver autoload missing — fix ai_driver.gd compile errors.")
    return
  ad.attach_main(self)


func _ai_driver() -> Node:
  return get_node_or_null("/root/AiDriver")


func _spawn_duel_pair() -> void:
  var hpos := _spawn_position("HerbivoreSpawn", Vector3(28.0, 0.6, 18.0))
  var cpos := _spawn_position("CarnivoreSpawn", Vector3(8.0, 0.7, 18.0))
  _herbivore_root = _HerbScene.instantiate() as Node3D
  _herbivore_root.set("definition", _RabbitArchetype)
  add_child(_herbivore_root)
  _herbivore_root.global_position = hpos
  _herb_body = _herbivore_root.get_node("Body") as CharacterBody3D
  _setup_motor_body(_herb_body, [&"prey", &"herbivores", &"creatures"])
  _carnivore_root = _CarnScene.instantiate() as Node3D
  _carnivore_root.set("definition", _FoxArchetype)
  add_child(_carnivore_root)
  _carnivore_root.global_position = cpos
  _carn_body = _carnivore_root.get_node("Body") as CharacterBody3D
  _setup_motor_body(_carn_body, [&"mobs", &"creatures"])


func _setup_motor_body(body: CharacterBody3D, groups: Array[StringName]) -> void:
  for g in groups:
    body.add_to_group(g)
  body.screen_size = PLAYFIELD_SIZE
  body.set_control_mode(_PlayerScr.engine_control_as_int())


func _spawn_position(marker_name: String, fallback: Vector3) -> Vector3:
  var m := get_node_or_null(marker_name)
  if m is Node3D:
    return (m as Node3D).global_position
  return fallback


func _clear_creatures() -> void:
  if _herbivore_root != null and is_instance_valid(_herbivore_root):
    _herbivore_root.queue_free()
  if _carnivore_root != null and is_instance_valid(_carnivore_root):
    _carnivore_root.queue_free()
  _herbivore_root = null
  _carnivore_root = null
  _herb_body = null
  _carn_body = null


func _ensure_environment_grid() -> void:
  if environment_grid != null:
    return
  var open := EnvironmentCellData.new()
  open.passible = true
  open.movement_impact = 0.0
  open.fit_size = -1.0
  var cell_world := 4.0
  var cw := maxi(1, ceili(PLAYFIELD_SIZE.x / cell_world))
  var ch := maxi(1, ceili(PLAYFIELD_SIZE.y / cell_world))
  environment_grid = EnvironmentGridBaked.new()
  var grid := environment_grid as EnvironmentGridBaked
  grid.cell_width = cw
  grid.cell_height = ch
  grid.cell_size_px = cell_world
  grid.origin_world = Vector2.ZERO
  grid.kind_presets = [open]
  var ids := PackedInt32Array()
  ids.resize(cw * ch)
  ids.fill(0)
  grid.cell_kind_ids = ids
