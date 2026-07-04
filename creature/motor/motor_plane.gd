extends RefCounted
class_name MotorPlane
## Motor-plane helpers: horizontal **Vector3** (Y=0) with **Vector2** XZ shims ([CONVERT_TO_3D.md §3.2](../../Project_Docs/Completed_Features/CONVERT_TO_3D.md)).


const _DefScript := preload("res://creature/definition/creature_definition.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")

## Reference playfield long-edge (world units) used to scale motor distance params on smaller 3D mains.
const REFERENCE_MOTOR_PLAYFIELD_EDGE := 1890.0

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


## Y rotation (radians) so a mesh whose default forward is −Z aligns with horizontal [param dir].
static func yaw_from_horizontal_dir(dir: Variant, default: Vector3 = HORIZONTAL_FORWARD) -> float:
  var d := read_dir(dir, default)
  return atan2(d.x, -d.z)


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


## Playfield edge hug data for explore boundary scan ([code]PlayfieldClamp[/code] margins).
## Returns [code]near[/code], horizontal [code]inbound_normal[/code] (toward interior), [code]min_margin[/code].
static func playfield_boundary_hug(body: Node, motor_p: Dictionary, hug_band: float) -> Dictionary:
  var inactive := {"near": false, "inbound_normal": Vector3.ZERO, "min_margin": INF}
  if body == null:
    return inactive
  var bounds: Dictionary = {}
  if body.has_method(&"_playfield_bounds_for_clamp"):
    bounds = body.call(&"_playfield_bounds_for_clamp")
  else:
    var bounds_max_v: Variant = body.get("playfield_bounds_max")
    var bounds_min_v: Variant = body.get("playfield_bounds_min")
    var ss: Variant = body.get("screen_size")
    var max_v := bounds_max_v as Vector2 if typeof(bounds_max_v) == TYPE_VECTOR2 else Vector2.ZERO
    if max_v == Vector2.ZERO and typeof(ss) == TYPE_VECTOR2:
      max_v = ss as Vector2
    bounds = {
      "min": bounds_min_v as Vector2 if typeof(bounds_min_v) == TYPE_VECTOR2 else Vector2.ZERO,
      "max": max_v,
    }
  var bmax: Vector2 = bounds.get("max", Vector2.ZERO)
  if bmax.x <= 0.0 or bmax.y <= 0.0:
    return inactive
  var bmin: Vector2 = bounds.get("min", Vector2.ZERO)
  var he := footprint_half_extents(body, motor_p)
  var pos2 := from_vec3(body.global_position if body is Node3D else Vector3.ZERO)
  var min_m := _PlayfieldClamp.min_edge_margin(pos2, he, bmax, bmin)
  if min_m > hug_band:
    return inactive
  var margins := _PlayfieldClamp.edge_margins(pos2, he, bmax, bmin)
  var inbound2 := Vector2.ZERO
  var tightest := min_m
  if margins.x <= tightest + 0.01:
    inbound2 = Vector2.RIGHT
  elif margins.y <= tightest + 0.01:
    inbound2 = Vector2.LEFT
  elif margins.z <= tightest + 0.01:
    inbound2 = Vector2.DOWN
  elif margins.w <= tightest + 0.01:
    inbound2 = Vector2.UP
  if inbound2.length_squared() < 1e-12:
    return inactive
  return {
    "near": true,
    "inbound_normal": Vector3(inbound2.x, 0.0, inbound2.y).normalized(),
    "min_margin": min_m,
  }


## Multiplier for reference-playfield-tuned motor distances from [param playfield_size] world bounds ([CONVERT_TO_3D.md §4 D7](../../Project_Docs/Completed_Features/CONVERT_TO_3D.md)).
static func motor_distance_scale_for_playfield(playfield_size: Vector2) -> float:
  if playfield_size.x <= 0.0 or playfield_size.y <= 0.0:
    return 1.0
  var long_edge := maxf(playfield_size.x, playfield_size.y)
  if long_edge >= REFERENCE_MOTOR_PLAYFIELD_EDGE * 0.25:
    return 1.0
  return minf(playfield_size.x, playfield_size.y) / REFERENCE_MOTOR_PLAYFIELD_EDGE


## Multiplier using [param playfield_size] when set, else [param main] [code]get_motor_playfield_size()[/code].
static func motor_distance_scale_for_main(main: Node, playfield_size: Vector2) -> float:
  var pf := playfield_size
  if pf == Vector2.ZERO and main != null and main.has_method(&"get_motor_playfield_size"):
    var mps: Variant = main.call(&"get_motor_playfield_size")
    if typeof(mps) == TYPE_VECTOR2:
      pf = mps as Vector2
  return motor_distance_scale_for_playfield(pf)


## Scales distance-like [code]creature_motor[/code] keys for 3D world units ([CONVERT_TO_3D.md §4 D7](../../Project_Docs/Completed_Features/CONVERT_TO_3D.md)).
static func scale_motor_distance_params(motor_p: Dictionary, scale: float) -> Dictionary:
  var out := motor_p.duplicate(true)
  if not is_equal_approx(scale, 1.0):
    for key in out.keys():
      if _is_distance_motor_param_key(key):
        out[key] = float(out[key]) * scale
  _inject_cardinal_probe_mins(out, scale)
  return out


## Playfield size from duel body [code]screen_size[/code] or [param main] [code]get_motor_playfield_size()[/code].
static func playfield_size_for_body(body: Node, main: Node = null) -> Vector2:
  if body != null:
    var ss: Variant = body.get("screen_size")
    if typeof(ss) == TYPE_VECTOR2:
      var pf := ss as Vector2
      if pf.x > 0.0 and pf.y > 0.0:
        return pf
  if main == null and body != null and body.is_inside_tree():
    main = body.get_tree().current_scene
  if main != null and main.has_method(&"get_motor_playfield_size"):
    var mps: Variant = main.call(&"get_motor_playfield_size")
    if typeof(mps) == TYPE_VECTOR2:
      var mv := mps as Vector2
      if mv.x > 0.0 and mv.y > 0.0:
        return mv
  return Vector2.ZERO


## Scales [code]creature_motor_v3[/code] distance keys to match playfield world units (overlay + V3 stack).
static func scale_creature_motor_v3_for_playfield(motor_v3: Dictionary, body: Node, main: Node = null) -> Dictionary:
  if motor_v3.is_empty():
    return motor_v3
  if main == null and body != null and body.is_inside_tree():
    main = body.get_tree().current_scene
  var playfield := playfield_size_for_body(body, main)
  var scale := motor_distance_scale_for_main(main, playfield)
  return scale_motor_distance_params(motor_v3, scale)


## Playfield-scaled cardinal lookahead floors ([code]cardinal_avoidance.gd[/code] stuck / edge escape).
static func _inject_cardinal_probe_mins(motor_p: Dictionary, scale: float) -> void:
  if not motor_p.has("motor_cardinal_probe_min"):
    motor_p["motor_cardinal_probe_min"] = 40.0 * scale
  if not motor_p.has("motor_cardinal_near_probe_min"):
    motor_p["motor_cardinal_near_probe_min"] = 10.0 * scale


## True when [param key] is a motor distance tuned for playfield scale ([method scale_motor_distance_params]).
static func _is_distance_motor_param_key(key: Variant) -> bool:
  var s := str(key)
  if s in [
    "awareness_radius",
    "awareness_cone_extra",
    "explore_coverage_cell",
    "interior_env_near_mob",
    "calorie_cost_per_unit_moved",
    "motor_stuck_move_epsilon",
    "eat_action_max_distance",
    "arrival_tolerance",
  ]:
    return true
  for suffix in [
    "_radius",
    "_clearance",
    "_band",
    "_probe",
    "_epsilon",
    "_pad",
    "_move",
    "_edge",
    "_lookahead",
  ]:
    if s.ends_with(suffix):
      return true
  return false


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
