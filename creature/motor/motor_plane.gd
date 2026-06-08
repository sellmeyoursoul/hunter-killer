extends RefCounted
class_name MotorPlane
## Motor-plane helpers: horizontal **Vector3** (Y=0) with **Vector2** XZ shims ([CONVERT_TO_3D.md §3.2](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).


const _DefScript := preload("res://creature/definition/creature_definition.gd")

## Legacy 2D duel playfield width ([code]project.godot[/code] viewport) used to scale [code]*_px[/code] motor distances on 3D mains.
const REFERENCE_MOTOR_PLAYFIELD_PX := 1890.0

## Idle intent on the horizontal motor plane.
const HORIZONTAL_ZERO := Vector3.ZERO
## World +X (motor "right" / east).
const HORIZONTAL_RIGHT := Vector3(1.0, 0.0, 0.0)
## World −Z (motor "forward" / north in 3D playfields).
const HORIZONTAL_FORWARD := Vector3(0.0, 0.0, -1.0)


## True when [param node] is a 3D physics body the ENGINE motor can drive.
static func is_motor_physics_body(node: Variant) -> bool:
  return node is PhysicsBody3D


## Projects world position onto the horizontal motor plane (XZ).
static func from_vec3(v: Vector3) -> Vector2:
  return Vector2(v.x, v.z)


## Alias for [method from_vec3] to match motor caller naming.
static func to_vec2(v: Vector3) -> Vector2:
  return from_vec3(v)


## Promotes motor-plane direction to ground-plane intent (**Y = 0**).
static func to_horizontal_vec3(v: Vector2) -> Vector3:
  return Vector3(v.x, 0.0, v.y)


## Accepts [code]Vector3[/code] or legacy [code]Vector2[/code] motor-plane position.
static func read_pos(v: Variant) -> Vector3:
  if typeof(v) == TYPE_VECTOR3:
    return v as Vector3
  if typeof(v) == TYPE_VECTOR2:
    return to_horizontal_vec3(v as Vector2)
  return Vector3.ZERO


## Normalized horizontal direction; [param default] when input is zero-length.
static func read_dir(v: Variant, default: Vector3 = HORIZONTAL_RIGHT) -> Vector3:
  var p := read_pos(v)
  if p.length_squared() < 1e-12:
    return default.normalized() if default.length_squared() > 1e-12 else Vector3.ZERO
  return Vector3(p.x, 0.0, p.z).normalized()


## Horizontal velocity from motor-plane variant ([code]Vector2[/code] or [code]Vector3[/code]).
static func read_velocity(v: Variant) -> Vector3:
  return read_pos(v)


## [EnvironmentGridBaked] world sample uses [code]Vector2(x, z)[/code].
static func to_grid_world(v: Vector3) -> Vector2:
  return Vector2(v.x, v.z)


## Motor-plane position for a duel [Node3D] physics child.
static func body_motor_position(body: Node) -> Vector3:
  if body is Node3D:
    var n3 := body as Node3D
    var p := n3.global_position if n3.is_inside_tree() else n3.position
    return Vector3(p.x, 0.0, p.z)
  return Vector3.ZERO


## Horizontal velocity on the motor plane (3D XZ components).
static func body_motor_velocity(body: Node) -> Vector3:
  if body is CharacterBody3D:
    var v := (body as CharacterBody3D).velocity
    return Vector3(v.x, 0.0, v.z)
  if body is RigidBody3D:
    var lv := (body as RigidBody3D).linear_velocity
    return Vector3(lv.x, 0.0, lv.z)
  return Vector3.ZERO


## Capsule footprint half-extents on the motor plane ([CollisionShape3D] capsule child).
static func footprint_half_extents(body: Node, motor_p: Dictionary) -> Vector2:
  var he_xy := Vector2(
    maxf(0.0, float(motor_p.get("creature_half_extent_x", 13.5))),
    maxf(0.0, float(motor_p.get("creature_half_extent_y", 30.5))),
  )
  if body == null:
    return he_xy
  var cs3 := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs3 != null and cs3.shape is CapsuleShape3D:
    var cap3 := cs3.shape as CapsuleShape3D
    return Vector2(
      maxf(0.0, cap3.radius),
      maxf(0.0, cap3.radius + cap3.height * 0.5),
    )
  return he_xy


## Multiplier for legacy pixel-tuned motor distances when [param main] reports world-meter playfield bounds ([CONVERT_TO_3D.md §4 D7](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).
static func motor_distance_scale_for_main(main: Node, playfield_size: Vector2) -> float:
  if main == null or not main.has_method(&"get_motor_playfield_size"):
    return 1.0
  if playfield_size.x <= 0.0 or playfield_size.y <= 0.0:
    return 1.0
  var long_edge := maxf(playfield_size.x, playfield_size.y)
  if long_edge >= REFERENCE_MOTOR_PLAYFIELD_PX * 0.25:
    return 1.0
  return minf(playfield_size.x, playfield_size.y) / REFERENCE_MOTOR_PLAYFIELD_PX


## Scales distance-like [code]creature_motor[/code] keys ([code]*_px[/code], awareness radii) for 3D world units.
static func scale_motor_distance_params(motor_p: Dictionary, scale: float) -> Dictionary:
  if is_equal_approx(scale, 1.0):
    return motor_p
  var out := motor_p.duplicate(true)
  for key in [&"awareness_radius", &"awareness_cone_extra"]:
    if out.has(key):
      out[key] = float(out[key]) * scale
  for key in out.keys():
    if str(key).ends_with("_px"):
      out[key] = float(out[key]) * scale
  return out


## [CreatureDefinition] on the body or its [code]CreatureRoot3D[/code] parent.
static func definition_for_body(body: Node) -> Variant:
  if body == null:
    return null
  var def_v: Variant = body.get("definition")
  if def_v is Resource and def_v.get_script() == _DefScript:
    return def_v
  var parent := body.get_parent()
  if parent != null:
    def_v = parent.get("definition")
    if def_v is Resource and def_v.get_script() == _DefScript:
      return def_v
  return null
