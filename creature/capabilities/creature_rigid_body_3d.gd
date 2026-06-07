extends RigidBody3D
## Rigid 3D carnivore **stub**: stores horizontal intent each tick; applies central force in XZ in [method _physics_process].
## Same **intent API** as [code]CreatureKinematicBody3D.apply_horizontal_move_intent[/code] for a future motor bridge.

const _DefScript := preload("res://creature/definition/creature_definition.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")

@export var definition: Variant
## Scales central force; tune per mass in scene.
@export var move_force_scale: float = 120.0

var creature_move_intent: Vector3 = Vector3.ZERO
var last_move_direction: Vector3 = MotorPlane.HORIZONTAL_RIGHT
var control_mode: int = 0
var screen_size: Vector2 = Vector2.ZERO

var _horizontal_intent: Vector3 = Vector3.ZERO


func _ready() -> void:
  control_mode = _ControlMode.engine_as_int()


func set_control_mode(mode: int) -> void:
  control_mode = mode


## AiDriver motor contract: [code]Vector3(x, 0, z)[/code] or legacy [code]Vector2(x, z)[/code].
func set_creature_move_intent(dir: Variant) -> void:
  var h := _MotorPlane.read_dir(dir, MotorPlane.HORIZONTAL_ZERO)
  creature_move_intent = h if h.length_squared() > 1e-12 else Vector3.ZERO
  set_horizontal_move_intent_for_tick(creature_move_intent)


func apply_duel_spawn_facing(facing: Variant) -> void:
  var h := _MotorPlane.read_dir(facing, MotorPlane.HORIZONTAL_ZERO)
  if h.length_squared() > 1e-12:
    last_move_direction = h

func _resolve_definition() -> Variant:
  var local_def: Variant = get("definition")
  if local_def != null and local_def.get_script() == _DefScript:
    return local_def
  var p := get_parent()
  if p:
    var pd: Variant = p.get("definition")
    if pd != null and pd.get_script() == _DefScript:
      return pd
  return null


## Replaces horizontal intent for the upcoming physics frame; **Y ignored**.
func set_horizontal_move_intent_for_tick(intent: Vector3) -> void:
  _horizontal_intent = Vector3(intent.x, 0.0, intent.z)


## Same signature as kinematic [method apply_horizontal_move_intent] so callers can branch on body type via [method Object.has_method].
func apply_horizontal_move_intent(intent: Vector3, _delta: float) -> void:
  set_horizontal_move_intent_for_tick(intent)


func _physics_process(_delta: float) -> void:
  if control_mode != _ControlMode.engine_as_int():
    return
  _apply_intent_force()
  var lv := linear_velocity
  var hvel := Vector3(lv.x, 0.0, lv.z)
  if hvel.length_squared() > 1e-8:
    last_move_direction = hvel.normalized()


func _apply_intent_force() -> void:
  var h := _horizontal_intent
  if h.length_squared() < 1e-8:
    return
  var def: Variant = _resolve_definition()
  var spd_scale := 1.0
  if def != null:
    var lp: Variant = def.get("locomotion_profile")
    if lp != null:
      spd_scale = float(lp.get("max_speed")) / 5.0
  apply_central_force(h.normalized() * move_force_scale * spd_scale)
