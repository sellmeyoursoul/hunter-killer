extends RigidBody3D
## Rigid 3D carnivore **stub**: stores horizontal intent each tick; applies central force in XZ in [method _physics_process].
## Same **intent API** as [code]CreatureKinematicBody3D.apply_horizontal_move_intent[/code] for a future motor bridge.

const _DefScript := preload("res://creature/definition/creature_definition.gd")

@export var definition: Variant
## Scales central force; tune per mass in scene.
@export var move_force_scale: float = 120.0

var _horizontal_intent: Vector3 = Vector3.ZERO

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
  _apply_intent_force()


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
