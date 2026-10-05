extends RefCounted
class_name MotorPlane
## Motor-plane helpers: horizontal **Vector3** (Y=0) with **Vector2** XZ shims ([CONVERT_TO_3D.md §3.2](../../Project_Docs/Completed_Features/CONVERT_TO_3D.md)).


const _DefScript := preload("res://creature/definition/creature_definition.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")
const _FallPhysics := preload("res://creature/motor/fall_physics.gd")

## Reference playfield long-edge (world units) used to scale motor distance params on smaller 3D mains.
const REFERENCE_MOTOR_PLAYFIELD_EDGE := 1890.0

## Idle intent on the horizontal motor plane.
const HORIZONTAL_ZERO := Vector3.ZERO
## World +X (motor "right" / east).
const HORIZONTAL_RIGHT := Vector3(1.0, 0.0, 0.0)
## Single source of truth (B22/B23) for the game's model-forward axis: world +Z. Default facing,
## fallback directions and the Visual yaw formula all derive from this one constant.
const MODEL_FORWARD := Vector3(0.0, 0.0, 1.0)


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


## Y rotation (radians, Godot convention: +Y counter-clockwise from above) that rotates
## [constant MODEL_FORWARD] onto horizontal [param dir]; wrapped to (-PI, PI].
## Invariant: yaw_from_horizontal_dir(MODEL_FORWARD) == 0 and
## Basis(Vector3.UP, yaw) * MODEL_FORWARD ~= dir.
static func yaw_from_horizontal_dir(dir: Variant, default: Vector3 = MODEL_FORWARD) -> float:
  var d := read_dir(dir, default)
  return wrapf(atan2(d.x, d.z) - atan2(MODEL_FORWARD.x, MODEL_FORWARD.z), -PI, PI)


## Facing invariant (CREATURE_BODY_DIMENSIONS §4.5, B5): a body with [code]body_width <= body_length[/code]
## only travels along +/- facing (never strafes). Pure check, no scene access.
## [param displacement] applied horizontal displacement or velocity (Y ignored); [param facing]
## horizontal facing direction (Y ignored, need not be normalized); [param body_width] /
## [param body_length] live body extents; [param tolerance_rad] max angle between the displacement
## and the facing axis (either sign). Returns true when the invariant holds: the body is exempt
## (width > length), the displacement is ~zero (below 1e-6 m), or the displacement is within
## [param tolerance_rad] of +/- facing. A zero-length facing with non-zero displacement fails.
## Example: [code]MotorPlane.facing_invariant_holds(Vector3(0, 0, 2), Vector3(0, 0, 1), 1.5, 6.0)[/code]
## is true; the same displacement with facing (1, 0, 0) is false.
static func facing_invariant_holds(
  displacement: Vector3,
  facing: Vector3,
  body_width: float,
  body_length: float,
  tolerance_rad: float = 0.0175,
) -> bool:
  if body_width > body_length:
    return true
  var d := Vector3(displacement.x, 0.0, displacement.z)
  if d.length_squared() < 1e-12:
    return true
  var f := Vector3(facing.x, 0.0, facing.z)
  if f.length_squared() < 1e-12:
    return false
  var cos_abs := absf(d.normalized().dot(f.normalized()))
  return cos_abs >= cos(tolerance_rad) - 1e-6


## Horizontal velocity from motor-plane variant ([code]Vector2[/code] or [code]Vector3[/code]).
static func read_velocity(v: Variant) -> Vector3:
  return read_pos(v)


## [EnvironmentGridBaked] world sample uses [code]Vector2(x, z)[/code].
static func to_grid_world(v: Vector3) -> Vector2:
  return Vector2(v.x, v.z)


## Distance between [param a] and [param b] on the horizontal motor plane (XZ only; Y ignored).
## Use this whenever a body's position is compared to a navmesh/path point or any other
## ground-level objective. A body's `global_position` is its capsule centre, which sits about half
## the capsule height above the ground: roughly 1.9 m for the rabbit and 7.7 m for the wolf. That
## is more than `arrival_tolerance` (5 m), so a 3D distance from a wolf to a hop directly under it
## never counts as arrived (the wolf silent-stall root cause, 2026-09-25).
## Example: `MotorPlane.horizontal_distance(body.global_position, nav_hop) <= arrival_tol`.
static func horizontal_distance(a: Vector3, b: Vector3) -> float:
  return Vector2(b.x - a.x, b.z - a.z).length()


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


## Horizontal footprint half-extents on the motor plane for [param body]'s upright
## [CollisionShape3D] capsule child: [code]Vector2(x = world-X half-extent, y = world-Z
## half-extent)[/code]. Consumed by [PlayfieldClamp] (clamp, edge margins, boundary hug).
##
## An upright [CapsuleShape3D]'s horizontal cross-section is a circle of [member
## CapsuleShape3D.radius], so both axes are [code]radius[/code]. (Before 2026-09-25 the Z axis was
## [code]radius + height / 2[/code] — a leftover from the 2D port, where a [CapsuleShape2D]'s
## height ran along screen Y, which became world Z on the motor plane. It made the playfield clamp
## hold creatures ~[code]height / 2[/code] farther from the north/south edges than from east/west —
## 7.67 u extra for the wolf. No caller needs a vertical extent from this function.)
## [param motor_p]'s [code]creature_half_extent_x[/code] / [code]creature_half_extent_y[/code] are
## the fallback when [param body] is null or has no capsule child.
## Example: wolf capsule r 7.03, h 15.33 → [code]Vector2(7.03, 7.03)[/code].
static func footprint_half_extents(body: Node, motor_p: Dictionary) -> Vector2:
  var he_xy := Vector2(
    maxf(0.0, float(motor_p.get("creature_half_extent_x", 13.5))),
    maxf(0.0, float(motor_p.get("creature_half_extent_y", 30.5))),
  )
  if body == null:
    return he_xy
  var cs3 := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs3 != null and cs3.shape is CapsuleShape3D:
    var r := maxf(0.0, (cs3.shape as CapsuleShape3D).radius)
    return Vector2(r, r)
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
  # Inward per edge on motor plane (Vector2.x → world X, Vector2.y → world Z).
  # Godot Vector2.DOWN = (0, +1) = +Z; Vector2.UP = (0, −1) = −Z.
  const EDGE_INBOUND_2D: Array[Vector2] = [
    Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
  ]
  var inbound2 := Vector2.ZERO
  var tightest := min_m
  const EDGE_TIE_EPS := 0.01
  var margin_vals: Array[float] = [margins.x, margins.y, margins.z, margins.w]
  for i in margin_vals.size():
    if margin_vals[i] <= tightest + EDGE_TIE_EPS:
      inbound2 += EDGE_INBOUND_2D[i]
  if inbound2.length_squared() < 1e-12:
    return inactive
  inbound2 = inbound2.normalized()
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
  var scaled := scale_motor_distance_params(motor_v3, scale)
  return _apply_terrain_scaled_invariant_airborne_ticks(scaled, body, main)


## PHYSICS_SQUEEZE.md §3 decision 30 (2026-09-21): the C10 airborne-invariant threshold
## (`motor_invariant_max_airborne_ticks`) was a flat constant (45) sized for near-miss recoveries,
## not for a genuine multi-meter fall — a wolf that legitimately walks off a real terrain cliff can
## take far longer than that to reach the bottom, tripping the invariant as if it were a
## stuck-under-geometry bug. Per-playfield at spawn time (this baked ground sampler already exists
## for spawn placement — [PlayfieldGroundSampler]) rather than a single project-wide constant, so a
## different playfield's terrain automatically gets a correctly-sized threshold with no manual
## re-tuning. Only raises the threshold above the config default, never below it — a playfield with
## no baked sampler (most tests, fixtures without a real [code]Main3D[/code]) or with no elevation
## range at all keeps the default, unchanged behavior.
static func _apply_terrain_scaled_invariant_airborne_ticks(
  motor_v3: Dictionary, body: Node, main: Node,
) -> Dictionary:
  if main == null or not main.has_method(&"get_ground_sampler"):
    return motor_v3
  var sampler: Variant = main.call(&"get_ground_sampler")
  if sampler == null or not (sampler as Object).has_method(&"is_valid") or not sampler.is_valid():
    return motor_v3
  var max_drop := float(sampler.max_elevation_range())
  if max_drop <= 0.0:
    return motor_v3
  var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
  var grav_mul := 1.0
  if body != null and body.has_method(&"get_gravity_multiplier"):
    grav_mul = maxf(0.01, float(body.call(&"get_gravity_multiplier")))
  var fall_ticks := _FallPhysics.ticks_to_fall(max_drop, gravity * grav_mul, Engine.get_physics_ticks_per_second())
  var buffer_ticks := int(motor_v3.get("motor_invariant_airborne_buffer_ticks", 45))
  var default_ticks := int(motor_v3.get("motor_invariant_max_airborne_ticks", 45))
  motor_v3["motor_invariant_max_airborne_ticks"] = maxi(default_ticks, fall_ticks + buffer_ticks)
  return motor_v3


## Motor distance keys that are tuned as fixed world-meter contracts (action ranges, arrival
## gates) rather than perception/exploration distances — these must NOT scale with playfield
## size, or they shrink below what's survivable against live, evasive targets on small
## playfields. [code]eat_action_max_distance[/code] is the fixed 5m EAT capture range (bug:
## previously scaled down to ~0.5m on small duel arenas, making prey capture nearly impossible);
## [code]arrival_tolerance[/code] is the shared arrival-gate fallback for the same range family.
const _UNSCALED_MOTOR_DISTANCE_KEYS := [
  "eat_action_max_distance",
  "arrival_tolerance",
]


## True when [param key] is a motor distance tuned for playfield scale ([method scale_motor_distance_params]).
static func _is_distance_motor_param_key(key: Variant) -> bool:
  var s := str(key)
  if s in _UNSCALED_MOTOR_DISTANCE_KEYS:
    return false
  if s in [
    "awareness_radius",
    "awareness_cone_extra",
    "explore_coverage_cell",
    "interior_env_near_mob",
    "calorie_cost_per_unit_moved",
    "motor_stuck_move_epsilon",
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
