extends CharacterBody3D
## Kinematic 3D creature: **horizontal move intent** uses **X and Z only**; Y is ignored for steering.
## **Gravity and jump** are owned here so [code]AiDriver[/code] can stay thin (2D-style direction promoted to XZ).

const _LocoProfile := preload("res://creature/definition/locomotion_profile.gd")
const _DefScript := preload("res://creature/definition/creature_definition.gd")

@export var definition: Variant


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


func _resolve_locomotion() -> Variant:
  var def: Variant = _resolve_definition()
  if def != null:
    var lp: Variant = def.get("locomotion_profile")
    if lp != null:
      return lp
  return _LocoProfile.new()


## Params:
## - intent: movement direction; **Y component is ignored** (flattened to XZ).
## - delta: physics step seconds.
## Usage: motor passes compass intent; this node normalizes horizontal plane and integrates [method move_and_slide].
func apply_horizontal_move_intent(intent: Vector3, delta: float) -> void:
  var loco: Variant = _resolve_locomotion()
  var max_spd := float(loco.get("max_speed"))
  var accel := float(loco.get("acceleration"))
  var fric := float(loco.get("friction"))
  var grav_mul := float(loco.get("gravity_multiplier"))
  var h := Vector3(intent.x, 0.0, intent.z)
  if h.length_squared() > 1.0 + 1e-6:
    h = h.normalized()
  var target := h * max_spd
  velocity.x = move_toward(velocity.x, target.x, accel * delta)
  velocity.z = move_toward(velocity.z, target.z, accel * delta)
  if h.length_squared() < 1e-8:
    velocity.x = move_toward(velocity.x, 0.0, fric * delta)
    velocity.z = move_toward(velocity.z, 0.0, fric * delta)
  if not is_on_floor():
    var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
    velocity.y -= g * grav_mul * delta
  move_and_slide()


## Applies upward velocity when on floor and profile requests jump.
func apply_jump_if_floor() -> void:
  var loco: Variant = _resolve_locomotion()
  var jv := float(loco.get("jump_velocity"))
  if is_on_floor():
    velocity.y = jv
