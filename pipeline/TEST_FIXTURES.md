# Test fixture cheat-sheet (hunter-killer acceptance tests)

For phase P when writing `tests/pipeline/test_tNNN.gd`. Copy the helpers below instead of reading `tests/run_all.gd` (9,000+ lines; reading it for fixtures cost one T-002 P session about 161k tokens). Taken from `tests/pipeline/test_t002.gd` and `test_task_t001.gd`, which passed. If you need a helper that is not here, grep `tests/run_all.gd` for `^func _<name>`, read only that function, then add it to this file.

## Script skeleton (Godot 4.7, 2-space indent, no tabs)
```gdscript
## T-NNN acceptance. Run: godot --path . --headless -s res://tests/pipeline/test_tNNN.gd   (exit 0 = pass)
## "PRE:" assertions use only code that exists at the base commit (they prove the geometry is what the test claims).
extends SceneTree

var _failures: int = 0


func _init() -> void:
  _run.call_deferred()


func _run() -> void:
  await _test_something()
  if _failures > 0:
    push_error("test_tNNN.gd: %d assertion(s) failed." % _failures)
  quit(0 if _failures == 0 else 1)


func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)
```
`verify` shows the worker the printed `ERROR: ASSERT: ...` lines, so write assertion messages that say what is wrong and include the value (`"... (dot %.3f)" % x`). Use `root.add_child(main)` for a scene root, `await physics_frame` before any physics query, and `main.queue_free()` at the end of each test.

## Pitfalls that already cost tokens
- **Re-read body dimensions after the first physics frame.** A spawned rabbit's capsule radius is 0.6 right after `add_child` and is re-fit from the mesh (about 1.7355) by the next physics frame (`apply_capsule_footprint_from_visual`). Spawn, `await physics_frame`, and only then read `get_collision_capsule_radius()` or build geometry sized from it. A PRE assertion that uses the stale value passes and misleads (this broke T-002's first test).
- **Obstacles the planner sees live on the ghost layer** (`GhostObstacleQuery.GHOST_LAYER_MASK`, mask 0 on the obstacle). Real terrain is layer 1. A body on the wrong layer is invisible to the route scan and the shelter probe.
- **Calling a private static planner function from a test:** `(_MotorPlanner as GDScript).call("_mint_flee_waypoint", ctx, _MotorPlanner.new_state(), body, motor_v3)`. The existing tests call them this way rather than directly.
- **Check that a new function exists before calling it**, so the test fails with a message and not a script error: `_has_static(script, &"name")` below.
- **Choices among several items need a discriminating case.** If the code picks the largest/smallest/first of many, add a fixture with two items (for example two threats of different radii) where the choices disagree, and assert the intended one.
- **Running a tool script from a test** (when the feature is a CLI tool): `OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--headless", "-s", TOOL, "--", "key=value"], out, true)`, then parse `out` with `RegEx`. See `tests/pipeline/test_task_t001.gd`.
- The full suite takes about 9 s and one acceptance script a few seconds. Do not loop hundreds of frames.

## Helpers (copy what you need; add the preloads at the top of the script)
```gdscript
const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _Ghost := preload("res://creature/motor/ghost_obstacle_query.gd")
const _MotorPlanner := preload("res://creature/motor/motor_planner.gd")
const _MemoryAdapter := preload("res://creature/motor/memory_adapter.gd")
const _ThreatSampleScr := preload("res://creature/motor/threat_sample.gd")
const _RabbitArchetypeRes := preload("res://creature/species/rabbit_archetype.tres")
const _Herbivore3DScenePath := "res://creature/templates/creature_herbivore_kinematic_3d.tscn"


func _has_static(script: GDScript, fn: StringName) -> bool:
  for m in script.get_script_method_list():
    if StringName(m["name"]) == fn:
      return true
  return false


func _motor_v3_params() -> Dictionary:
  var p := _Merge.default_creature_motor_v3_params()
  p["awareness_radius"] = 500.0
  p["awareness_cone_extra"] = 200.0
  p["awareness_cone_half_angle_deg"] = 80.0
  p["awareness_requires_los"] = false
  return p


func _ghost_body(main: Node3D, shape: Shape3D, pos: Vector3) -> StaticBody3D:
  var body := StaticBody3D.new()
  var col := CollisionShape3D.new()
  col.shape = shape
  body.add_child(col)
  body.collision_layer = _Ghost.GHOST_LAYER_MASK
  body.collision_mask = 0
  main.add_child(body)
  body.global_position = pos
  return body


func _box(size: Vector3) -> BoxShape3D:
  var b := BoxShape3D.new()
  b.size = size
  return b


## Spawn, then `await physics_frame` BEFORE reading its radius or height (see pitfalls).
func _spawn_rabbit(main: Node3D, pos: Vector3) -> CharacterBody3D:
  var scene: PackedScene = load(_Herbivore3DScenePath) as PackedScene
  var creature_root := scene.instantiate() as Node3D
  creature_root.set("definition", _RabbitArchetypeRes)
  main.add_child(creature_root)
  var body := creature_root.get_node("Body") as CharacterBody3D
  for g in [&"player", &"prey", &"herbivores", &"creatures"]:
    body.add_to_group(g)
  body.global_position = pos
  return body


## radius < 0 leaves the size unknown (no "capsule_radius" key).
func _threat_at(pos: Vector3, radius: float = -1.0) -> Dictionary:
  var threat := _ThreatSampleScr.make(Vector2(pos.x, pos.z), absf(pos.x) + absf(pos.z), true)
  threat["world_pos_3d"] = pos
  threat["in_awareness"] = true
  if radius >= 0.0:
    threat["capsule_radius"] = radius
  return threat


func _planner_ctx(body: CharacterBody3D, main: Node3D, threat: Dictionary, adapter: RefCounted) -> Dictionary:
  return {
    "body": body,
    "motor_v3": _motor_v3_params(),
    "incumbent": {},
    "threat_samples": [threat],
    "scan": {"food_split": {"ready": [], "unready": []}, "threat_samples": [threat]},
    "flight_fast_path_active": true,
    "flight_just_entered": true,
    "space_state": main.get_world_3d().direct_space_state,
    "eye_height": 1.0,
    "map_rid": RID(),
    "physics_tick": 1,
    "memory_adapter": adapter,
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": null,
  }


## Unit direction (XZ) from the body to the minted flee waypoint.
func _mint_flee_dir(body: CharacterBody3D, ctx: Dictionary, motor_v3: Dictionary) -> Vector3:
  var wp: Vector3 = (_MotorPlanner as GDScript).call(
    "_mint_flee_waypoint", ctx, _MotorPlanner.new_state(), body, motor_v3
  )
  var d := Vector3(wp.x - body.global_position.x, 0.0, wp.z - body.global_position.z)
  return d.normalized()
```
Beliefs: `var adapter := _MemoryAdapter.new()`; shelter and choke belief rows are read through the adapter (`consult_shelter_belief_candidates`, `consult_choke_point_beliefs`, `get_beliefs()`); grep `memory_adapter.gd` for the write call you need.
Route scan: `RoutePlausibilityScan.scan_path(space, PackedVector3Array([a, b]), radius, height)` returns a dictionary with `blocked`.

## Extending this file
After each task, add the helper or pitfall that cost the most tokens to rediscover. Keep it under about 400 lines.
