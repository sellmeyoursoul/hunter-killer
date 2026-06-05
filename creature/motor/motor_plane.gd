extends RefCounted
class_name MotorPlane
## Motor-plane helpers: **Vector2(x, y)** maps to world **XZ** via [method to_horizontal_vec3] ([CONVERT_TO_3D.md §3.2](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).


const _DefScript := preload("res://creature/definition/creature_definition.gd")


## True when [param node] is a 2D or 3D physics body the ENGINE motor can drive.
static func is_motor_physics_body(node: Variant) -> bool:
  return node is PhysicsBody2D or node is PhysicsBody3D


## Projects world position onto the horizontal motor plane (2D: XY; 3D: XZ).
static func from_vec3(v: Vector3) -> Vector2:
  return Vector2(v.x, v.z)


## Promotes motor-plane direction to ground-plane intent (**Y = 0**).
static func to_horizontal_vec3(v: Vector2) -> Vector3:
  return Vector3(v.x, 0.0, v.y)


## Motor-plane position for a duel body ([Node2D] or [Node3D] physics child).
static func body_motor_position(body: Node) -> Vector2:
  if body is Node2D:
    return (body as Node2D).global_position
  if body is Node3D:
    return from_vec3((body as Node3D).global_position)
  return Vector2.ZERO


## Horizontal velocity on the motor plane (2D velocity or 3D XZ components).
static func body_motor_velocity(body: Node) -> Vector2:
  if body is CharacterBody2D:
    return (body as CharacterBody2D).velocity
  if body is RigidBody2D:
    return (body as RigidBody2D).linear_velocity
  if body is CharacterBody3D:
    var v := (body as CharacterBody3D).velocity
    return Vector2(v.x, v.z)
  if body is RigidBody3D:
    var lv := (body as RigidBody3D).linear_velocity
    return Vector2(lv.x, lv.z)
  return Vector2.ZERO


## Capsule footprint half-extents on the motor plane (2D capsule or 3D capsule child).
static func footprint_half_extents(body: Node, motor_p: Dictionary) -> Vector2:
  var he_xy := Vector2(
    maxf(0.0, float(motor_p.get("creature_half_extent_x", 13.5))),
    maxf(0.0, float(motor_p.get("creature_half_extent_y", 30.5))),
  )
  if body == null:
    return he_xy
  var cs2 := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs2 != null and cs2.shape is CapsuleShape2D:
    var cap := cs2.shape as CapsuleShape2D
    return Vector2(
      maxf(0.0, cap.radius),
      maxf(0.0, cap.radius + cap.height * 0.5),
    )
  var cs3 := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs3 != null and cs3.shape is CapsuleShape3D:
    var cap3 := cs3.shape as CapsuleShape3D
    return Vector2(
      maxf(0.0, cap3.radius),
      maxf(0.0, cap3.radius + cap3.height * 0.5),
    )
  return he_xy


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
