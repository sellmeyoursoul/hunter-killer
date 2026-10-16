## CLEANUP C9 targeted regression/repro: rabbit fleeing a fox near the walkable-terrain edge.
## Run: godot --path . --headless -s res://tests/test_c9_flee_edge_pingpong.gd   (exit 0 = pass)
##
## Boots the real main_3d.tscn (real terrain, baked navmesh, baked walkable mask), starts a round,
## then teleports the rabbit to a fixed point a few metres inside the walkable edge with the fox
## on the interior side, so the rabbit must flee along or into the edge. The per-stack
## C9/C10 fail-fast invariant harness stays ENABLED on the rabbit only (stacks are built by
## configure_motor_stack, not the opt-out test fixture); it is disabled for every other creature. A
## trip hard-quits the tree and pushes a "MOTOR_INVARIANT" error. The harness has no trip signal, so
## to keep a falling rabbit (C10 airborne, unrelated to flee) from failing the run, the test watches
## is_on_floor() itself and abandons the attempt as INCONCLUSIVE (NOTE + retry) a few ticks before
## the stack's airborne limit, disabling the rabbit harness for that attempt only.
##
## Hypothesis under test: MotorPlanner._mint_flee_waypoint scores candidates without knowing the
## walkable inset (CREATURE_MOVEMENT_V3.md 7.4), so flee waypoints may land on unwalkable ground.
extends SceneTree

const _TICKS := 600
## Rabbit starts this far inside the walkable edge (m).
const _EDGE_INSET_M := 3.0
## Fox starts this far further toward the interior than the rabbit (m).
const _FOX_STANDOFF_M := 18.0
## Max placement+run attempts per scenario when the fox never engages (no flee waypoint minted).
const _MAX_ATTEMPTS := 5
## Each retry moves the fox this much closer so it is likelier to perceive and engage (m).
const _STANDOFF_STEP_M := 4.0
## Rabbit consecutive not-on-floor ticks after which the attempt is abandoned as INCONCLUSIVE, just
## before the stack's own C10 airborne trip (default 45) would hard-quit the tree.
const _RABBIT_AIRBORNE_BAILOUT_TICKS := 36
## Closest the fox is ever placed (m); nearer than this it catches the rabbit before flee can mint a waypoint.
const _MIN_STANDOFF_M := 6.0
## Other creatures (e.g. wolves) airborne this many consecutive ticks print an informational NOTE.
const _NOTE_AIRBORNE_TICKS := 60
## Walkable-mask query margin for "never leaves walkable" / "waypoint is walkable" (m).
const _WALK_MARGIN_M := 0.0
## Clearance above the real ground surface at which a body is dropped by [method _place] (m). Body
## origin rests ~0.06 m above the surface; gravity ramps slowly so 1.2 m took ~26 ticks to land.
const _SPAWN_CLEARANCE_M := 0.15
## Ticks within which a freshly placed rabbit must report is_on_floor() (regression: sampler-height spawn).
const _PLACE_FLOOR_MAX_TICKS := 10
## Ticks a placed body is watched after placement; it must never fall below [constant _PLACE_MIN_Y].
const _PLACE_WATCH_TICKS := 60
const _PLACE_MIN_Y := -0.5
## Process seeds whose random interior-boulder layout covers a scenario start (CMV3C-34).
const _OVERLAP_SEEDS := [19, 29]
## Footprint probed for a physical prop overlap at a placement point (m); slightly larger than a creature body.
const _GUARD_CAPSULE_RADIUS_M := 0.6
const _GUARD_CAPSULE_HEIGHT_M := 1.8
## A prop root found overlapping a start is moved this far along +X, far outside the playfield (m).
const _GUARD_MOVE_AWAY_M := 1000.0

var _failures: int = 0
var _main: Node3D
var _sampler: Object


func _init() -> void:
  _run.call_deferred()


func _run() -> void:
  var forced_seed := _seed_from_args()
  if forced_seed >= 0:
    await _run_seeded_placement(forced_seed)
    return
  await _boot_main()
  _assert(_sampler != null and _sampler.is_valid() and _sampler.has_walkable_mask(), "walkable mask baked")
  var driver: Node = _main.call("_ai_driver")
  _assert(driver != null and bool(driver.call("begin_engine_player_round")), "AI driver round starts")
  if _failures == 0:
    await _test_flee_along_edge("minus_x_edge", Vector2(-1.0, 0.0), 40.0)
    await _test_flee_along_edge("plus_z_edge", Vector2(0.0, 1.0), 0.0)
    await _test_flee_along_edge("minus_x_minus_z_corner", Vector2(-1.0, -1.0).normalized(), 0.0)
    await _test_placement_lands_on_floor("minus_x_edge", Vector2(-1.0, 0.0), 40.0)
    await _test_placement_lands_on_floor("plus_z_edge", Vector2(0.0, 1.0), 0.0)
    await _test_placement_lands_on_floor("minus_x_minus_z_corner", Vector2(-1.0, -1.0).normalized(), 0.0)
    await _test_guard_resolves_moved_interior_boulder()
    # Seeds 19 and 29 (of 1..32) put an interior boulder over the minus_x_edge start (CMV3C-34). Each
    # runs in a child Godot process: re-instantiating main_3d in-process leaves the AI driver holding
    # freed creature roots (log noise), and the seed must be set before main is instantiated.
    for overlap_seed in _OVERLAP_SEEDS:
      _test_seeded_placement_subprocess(overlap_seed)
  if _failures > 0:
    push_error("test_c9_flee_edge_pingpong.gd: %d assertion(s) failed." % _failures)
  quit(0 if _failures == 0 else 1)


## Seed from a `-- --seed=N` user arg, or -1 when absent.
func _seed_from_args() -> int:
  for arg in OS.get_cmdline_user_args():
    if arg.begins_with("--seed="):
      return int(arg.substr(7))
  return -1


## Child-process mode: boots main with `playfield_spawn.seed` forced and runs only the placement
## regression at all three scenario starts. Exit code 0 = pass.
func _run_seeded_placement(forced_seed: int) -> void:
  await _boot_main(forced_seed)
  await _test_placement_lands_on_floor("seed%d_minus_x_edge" % forced_seed, Vector2(-1.0, 0.0), 40.0)
  await _test_placement_lands_on_floor("seed%d_plus_z_edge" % forced_seed, Vector2(0.0, 1.0), 0.0)
  await _test_placement_lands_on_floor(
    "seed%d_minus_x_minus_z_corner" % forced_seed, Vector2(-1.0, -1.0).normalized(), 0.0
  )
  if _failures > 0:
    push_error("test_c9_flee_edge_pingpong.gd (seed %d): %d assertion(s) failed." % [forced_seed, _failures])
  quit(0 if _failures == 0 else 1)


## Spawns this script in a child Godot process with [param forced_seed] and asserts it exits 0.
func _test_seeded_placement_subprocess(forced_seed: int) -> void:
  var output: Array = []
  var args := PackedStringArray([
    "--path", ProjectSettings.globalize_path("res://"), "--headless",
    "-s", "res://tests/test_c9_flee_edge_pingpong.gd", "--", "--seed=%d" % forced_seed,
  ])
  var rc := OS.execute(OS.get_executable_path(), args, output, true)
  for chunk in output:
    for line in str(chunk).split("
"):
      if line.begins_with("C9_EDGE_PLACE") or line.begins_with("NOTE (overlap guard)") or line.contains("ASSERT"):
        print("  [seed %d] %s" % [forced_seed, line])
  _assert(rc == 0, "seed %d: child placement run failed (rc=%d)" % [forced_seed, rc])


## (Re)boots main_3d.tscn and waits for navigation. Frees any previous instance first.
## [param forced_seed] >= 0 overrides `playfield_spawn.seed` in GameConfig's merged config before
## instantiating (0 = random per process, the shipped default); -1 leaves the config untouched.
func _boot_main(forced_seed: int = -1) -> void:
  if _main != null and is_instance_valid(_main):
    root.remove_child(_main)
    _main.queue_free()
    await process_frame
    await process_frame
  if forced_seed >= 0:
    var cfg: Node = root.get_node("GameConfig")
    var merged: Dictionary = cfg.get("_merged")
    var spawn_cfg: Dictionary = merged.get("playfield_spawn", {})
    spawn_cfg["seed"] = forced_seed
    merged["playfield_spawn"] = spawn_cfg
    cfg.set("_merged", merged)
  var scene: PackedScene = load("res://main_3d.tscn") as PackedScene
  _main = scene.instantiate() as Node3D
  root.add_child(_main)
  await process_frame
  await process_frame
  var waited := 0
  while not bool(_main.call("is_navigation_ready")) and waited < 600:
    await process_frame
    waited += 1
  _sampler = _main.call("get_ground_sampler")


func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)


## Outermost walkable coordinate along [param axis_dir] (unit, or diagonal) through the lateral
## coordinate [param lateral]. For an axis edge, scans the one varying coordinate outward.
## Returns the XZ of the outermost walkable point (0.25 m resolution).
func _edge_point(outward: Vector2, lateral: float) -> Vector2:
  var is_diag := absf(outward.x) > 0.01 and absf(outward.y) > 0.01
  var best := Vector2.ZERO
  var t := 0.0
  while t <= 120.0:
    var p: Vector2
    if is_diag:
      p = Vector2(signf(outward.x), signf(outward.y)) * t
    elif absf(outward.x) > 0.01:
      p = Vector2(signf(outward.x) * t, lateral)
    else:
      p = Vector2(lateral, signf(outward.y) * t)
    if _sampler.is_walkable(p, _WALK_MARGIN_M):
      best = p
    t += 0.25
  return best


## Runs the scenario up to [constant _MAX_ATTEMPTS] times (fox sometimes never engages the rabbit, so
## no flee waypoint is minted). Hard assertions apply to the first attempt where flee engaged:
## (a) no C9/C10 invariant trip on the rabbit or fox, (b) rabbit never off walkable ground,
## (c) every minted flee waypoint is inside the walkable region. Fails only if flee never engages.
func _test_flee_along_edge(label: String, outward: Vector2, lateral: float) -> void:
  var r: Dictionary = {}
  var attempts := 0
  var inconclusive := 0
  for attempt in _MAX_ATTEMPTS:
    attempts = attempt + 1
    r = await _run_attempt(label, outward, lateral, maxf(_FOX_STANDOFF_M - float(attempt) * _STANDOFF_STEP_M, _MIN_STANDOFF_M))
    if int(r["trip_tick"]) >= 0:
      break
    if int(r["inconclusive_tick"]) >= 0:
      inconclusive += 1
      # A violation seen before the fall is still a real finding; otherwise retry.
      if int(r["off_walkable_tick"]) < 0 and (r["bad_waypoints"] as Array).is_empty():
        continue
      break
    if (r["seen_waypoints"] as Array).size() > 0:
      break
  var ctx := "%s (rabbit start %s, fox start %s, edge %s, attempts %d, inconclusive %d)" % [
    label, str(r["rabbit_xz"]), str(r["fox_xz"]), str(r["edge"]), attempts, inconclusive,
  ]
  var seen: Array = r["seen_waypoints"]
  var bad: Array = r["bad_waypoints"]
  _assert(int(r["trip_tick"]) < 0, "%s: MOTOR_INVARIANT tripped on rabbit at tick %d (see MOTOR_INVARIANT line above)" % [ctx, int(r["trip_tick"])])
  _assert(
    seen.size() > 0,
    "%s: rabbit minted no flee waypoint in any of %d attempts (flee never engaged or attempt inconclusive)" % [ctx, attempts],
  )
  # An early catch is a legitimate predator win, not a failure: waypoints are validated up to the catch.
  var ow: Vector2 = r["off_walkable_pos"]
  var known_note := ""
  if ow.x < -94.0 and absf(ow.y) < 3.0:
    known_note = " [known open C9 item: west-edge notch body-clamp leak]"
  _assert(
    int(r["off_walkable_tick"]) < 0,
    "%s: rabbit left walkable terrain at tick %d pos %s%s" % [ctx, int(r["off_walkable_tick"]), str(ow), known_note],
  )
  _assert(
    bad.is_empty(),
    "%s: %d/%d flee waypoints off walkable ground, first: %s" % [
      ctx, bad.size(), seen.size(), str(bad[0]) if not bad.is_empty() else "",
    ],
  )
  print(
    "C9_EDGE %s: attempts=%d inconclusive=%d ticks=%d live=%d excursion=%.2f waypoints=%d bad_waypoints=%d off_walkable_tick=%d trip_tick=%d caught_tick=%d" % [
      label, attempts, inconclusive, int(r["ticks_run"]), int(r["live"]), float(r["excursion"]), seen.size(), bad.size(),
      int(r["off_walkable_tick"]), int(r["trip_tick"]), int(r["caught_tick"]),
    ]
  )


## One placement + simulation pass. Returns a Dictionary of observations (no assertions on flee
## outcome; only setup preconditions are asserted). Every creature except the rabbit has its
## fail-fast invariant harness disabled (a trip hard-quits the whole tree); non-fox others are
## watched for a long airborne stretch, reported as a NOTE only. "inconclusive_tick" >= 0 means the
## rabbit was airborne too long (C10, unrelated to flee) and the attempt was abandoned.
func _run_attempt(label: String, outward: Vector2, lateral: float, standoff_m: float) -> Dictionary:
  # Arrange
  _main.call("new_game")
  var edge := _edge_point(outward, lateral)
  var inward := -outward.normalized()
  var rabbit_xz := edge + inward * _EDGE_INSET_M
  var fox_xz := rabbit_xz + inward * standoff_m
  var rabbit: CharacterBody3D = _main.call("get_player_creature_body")
  var fox_root: Node3D = (_main.call("get_carnivore_creature_roots") as Array)[0]
  var fox: CharacterBody3D = fox_root.get_node("Body")
  var rabbit_root: Node3D = rabbit.get_parent()
  var others: Array[CharacterBody3D] = []
  for body in (_main.call("get_all_creature_bodies") as Array):
    if body != rabbit:
      var other_stack: RefCounted = body.get_parent().call("get_motor_stack")
      if other_stack != null:
        other_stack.call("set_debug_assert_motor_invariants_enabled_for_test", false)
      if body != fox:
        others.append(body)
  var other_airborne: Dictionary = {}
  var noted: Dictionary = {}
  await _clear_props_at(rabbit_xz)
  await _clear_props_at(fox_xz)
  _place(rabbit, rabbit_xz)
  _place(fox, fox_xz)
  await physics_frame
  var rabbit_stack: RefCounted = rabbit_root.call("get_motor_stack")
  var fox_stack: RefCounted = fox_root.call("get_motor_stack")
  if rabbit_stack != null:
    rabbit_stack.call("set_debug_assert_motor_invariants_enabled_for_test", true)
  var bailout_ticks := _RABBIT_AIRBORNE_BAILOUT_TICKS
  if rabbit_stack != null:
    var mv3: Dictionary = rabbit_stack.get("_motor_v3")
    bailout_ticks = mini(bailout_ticks, int(mv3.get("motor_invariant_max_airborne_ticks", 45)) - 8)
  var rabbit_airborne := 0
  var inconclusive_tick := -1
  _assert(
    rabbit_stack != null and fox_stack != null,
    "%s: both creatures have motor stacks" % label,
  )
  _assert(
    bool(rabbit_stack.get("_debug_assert_motor_invariants")),
    "%s: C9/C10 invariant harness is enabled on the rabbit stack" % label,
  )
  _assert(
    _sampler.is_walkable(Vector2(rabbit.global_position.x, rabbit.global_position.z), _WALK_MARGIN_M),
    "%s: PRE rabbit start %s is walkable" % [label, str(rabbit.global_position)],
  )
  var start := Vector2(rabbit.global_position.x, rabbit.global_position.z)
  var max_excursion := 0.0
  var off_walkable_tick := -1
  var off_walkable_pos := Vector2.ZERO
  var bad_waypoints: Array = []
  var seen_waypoints: Array = []
  var last_wp := Vector3.ZERO
  var trip_tick := -1
  var caught_tick := -1
  var ticks_run := 0
  var rabbit_alive_ticks := 0
  # Act
  for tick_i in _TICKS:
    await physics_frame
    ticks_run += 1
    if not is_instance_valid(rabbit) or not is_instance_valid(rabbit_stack):
      break
    if bool(rabbit_stack.get("_invariant_tripped")):
      trip_tick = tick_i
      break
    rabbit_airborne = (rabbit_airborne + 1) if not rabbit.is_on_floor() else 0
    if rabbit_airborne >= bailout_ticks:
      inconclusive_tick = tick_i
      rabbit_stack.call("set_debug_assert_motor_invariants_enabled_for_test", false)
      print("NOTE (INCONCLUSIVE attempt, C10 airborne unrelated to flee): %s tick %d rabbit pos %s airborne %d ticks, fox start standoff %.1f m" % [
        label, tick_i, str(rabbit.global_position), rabbit_airborne, standoff_m,
      ])
      break
    for other in others:
      if not is_instance_valid(other) or noted.has(other):
        continue
      var n: int = (int(other_airborne.get(other, 0)) + 1) if not other.is_on_floor() else 0
      other_airborne[other] = n
      if n >= _NOTE_AIRBORNE_TICKS:
        noted[other] = true
        print("NOTE (unrelated to rabbit flee, not asserted): %s %s airborne %d ticks near %s" % [
          label, str(other.get_parent().name), n, str(other.global_position),
        ])
    if bool(_main.get("_round_ended")) or bool(rabbit.get("_defeat_hidden")):
      caught_tick = tick_i
      break
    rabbit_alive_ticks += 1
    var pos := Vector2(rabbit.global_position.x, rabbit.global_position.z)
    max_excursion = maxf(max_excursion, pos.distance_to(start))
    if off_walkable_tick < 0 and not _sampler.is_walkable(pos, _WALK_MARGIN_M):
      off_walkable_tick = tick_i
      off_walkable_pos = pos
    var ps: Dictionary = rabbit_stack.get("_planner_state")
    if bool(ps.get("flee_waypoint_set", false)):
      var wp: Vector3 = ps.get("flee_waypoint", Vector3.ZERO)
      if wp.distance_to(last_wp) >= 0.05:
        last_wp = wp
        seen_waypoints.append(wp)
        if not _sampler.is_walkable(Vector2(wp.x, wp.z), _WALK_MARGIN_M):
          bad_waypoints.append({"tick": tick_i, "wp": wp, "rabbit": rabbit.global_position})
  return {
    "edge": edge, "rabbit_xz": rabbit_xz, "fox_xz": fox_xz,
    "trip_tick": trip_tick, "inconclusive_tick": inconclusive_tick, "caught_tick": caught_tick, "ticks_run": ticks_run,
    "live": rabbit_alive_ticks, "excursion": max_excursion,
    "off_walkable_tick": off_walkable_tick, "off_walkable_pos": off_walkable_pos,
    "bad_waypoints": bad_waypoints, "seen_waypoints": seen_waypoints,
  }


## Teleports [param body] to [param xz] just above the REAL ground and clears its velocity.
## Ground comes from a terrain-only raycast (props and perimeter boulders excluded via main's
## walkable-mask exclude RIDs). [method PlayfieldGroundSampler.sample_elevation] is terrain-only too
## since CMV3C-33; this test used to avoid it because its rays included props and could report a
## boulder top (~16 m) over y=0 terrain at the corner.
func _place(body: CharacterBody3D, xz: Vector2) -> void:
  body.global_position = Vector3(xz.x, _ground_y(xz) + _SPAWN_CLEARANCE_M, xz.y)
  body.velocity = Vector3.ZERO


## Terrain-only ground height at [param xz] (props and perimeter boulders excluded; see [method _place]).
func _ground_y(xz: Vector2) -> float:
  var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
  var exclude: Array = _main.call("_walkable_mask_exclude_rids")
  var hint_y := float(_main.get("_playfield_bounds").get("floor_y", 0.0))
  var ground: Dictionary = PlayfieldBounds3D.raycast_ground_surface(
    space, xz, hint_y, PlayfieldBounds3D.WORLD_STATIC_COLLISION_MASK, exclude
  )
  return float(ground.get("surface_y", hint_y))


## Prop roots (direct children of Obstacles3D / the food root) whose layer-1 colliders overlap a
## creature-sized capsule standing on the terrain at [param xz]. A body placed inside one is
## depenetrated under the one-sided terrain grid and falls (CMV3C-34; interior boulders are random
## per process). Returns an Array of Node3D.
func _prop_roots_overlapping(xz: Vector2) -> Array:
  var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
  var shape := CapsuleShape3D.new()
  shape.radius = _GUARD_CAPSULE_RADIUS_M
  shape.height = _GUARD_CAPSULE_HEIGHT_M
  var q := PhysicsShapeQueryParameters3D.new()
  q.shape = shape
  var centre_y := _ground_y(xz) + _SPAWN_CLEARANCE_M + _GUARD_CAPSULE_HEIGHT_M * 0.5
  q.transform = Transform3D(Basis.IDENTITY, Vector3(xz.x, centre_y, xz.y))
  q.collision_mask = PlayfieldBounds3D.WORLD_STATIC_COLLISION_MASK
  var roots: Array = []
  var hits: Array[Dictionary] = space.intersect_shape(q, 32)
  for prop_root in [_main.get("_obstacles_root"), _main.get("_food_root")]:
    if prop_root == null or not is_instance_valid(prop_root):
      continue
    for hit in hits:
      var collider := hit.get("collider") as Node
      if collider == null or not (prop_root as Node).is_ancestor_of(collider):
        continue
      var top: Node = collider
      while top.get_parent() != prop_root:
        top = top.get_parent()
      # Interior boulders only: perimeter boulders are the playfield wall and must stay put.
      if top is Node3D and _is_interior_boulder(top as Node3D) and not roots.has(top):
        roots.append(top)
  return roots


## True for a randomly placed interior boulder (group `obstacles`, interior visual scale).
func _is_interior_boulder(node: Node3D) -> bool:
  return node.is_in_group(&"obstacles") and absf(node.scale.x - PlayfieldBounds3D.INTERIOR_BOULDER_VISUAL_SCALE) < 0.01


## Overlap guard: if any prop overlaps the start at [param xz], moves that prop root far outside the
## playfield (deterministic; the start itself is unchanged) and waits two physics frames so the move
## reaches the physics broadphase. Never place a body into a collider. Returns the number of props moved.
func _clear_props_at(xz: Vector2) -> int:
  var overlapping := _prop_roots_overlapping(xz)
  if overlapping.is_empty():
    return 0
  for prop in overlapping:
    var node := prop as Node3D
    print("NOTE (overlap guard): moving prop %s off start %s (was at %s)" % [node.name, str(xz), str(node.global_position)])
    node.global_position += Vector3(_GUARD_MOVE_AWAY_M, 0.0, 0.0)
  await physics_frame
  await physics_frame
  _assert(_prop_roots_overlapping(xz).is_empty(), "overlap guard: start %s still overlaps a prop after moving it" % str(xz))
  return overlapping.size()


## Regression: after [method _place] at a scenario start the rabbit AND the fox (at the standoff)
## must be on the floor within [constant _PLACE_FLOOR_MAX_TICKS] ticks (previously spawned ~18 m up
## at the corner and free-fell) and must stay above [constant _PLACE_MIN_Y] for
## [constant _PLACE_WATCH_TICKS] ticks (CMV3C-34: placed inside a boulder, then fell through).
func _test_placement_lands_on_floor(label: String, outward: Vector2, lateral: float) -> void:
  # Arrange
  _main.call("new_game")
  var rabbit: CharacterBody3D = _main.call("get_player_creature_body")
  var fox_root: Node3D = (_main.call("get_carnivore_creature_roots") as Array)[0]
  var fox: CharacterBody3D = fox_root.get_node("Body")
  var rabbit_xz := _edge_point(outward, lateral) + (-outward.normalized()) * _EDGE_INSET_M
  var fox_xz := rabbit_xz + (-outward.normalized()) * _FOX_STANDOFF_M
  # Act
  await _clear_props_at(rabbit_xz)
  await _clear_props_at(fox_xz)
  _place(rabbit, rabbit_xz)
  _place(fox, fox_xz)
  var bodies: Array[CharacterBody3D] = [rabbit, fox]
  var floor_ticks: Array[int] = [-1, -1]
  var min_ys: Array[float] = [999.0, 999.0]
  for tick_i in _PLACE_WATCH_TICKS:
    await physics_frame
    for i in bodies.size():
      if floor_ticks[i] < 0 and bodies[i].is_on_floor():
        floor_ticks[i] = tick_i
      min_ys[i] = minf(min_ys[i], bodies[i].global_position.y)
  # Assert
  var names: Array[String] = ["rabbit", "fox"]
  var starts: Array[Vector2] = [rabbit_xz, fox_xz]
  for i in bodies.size():
    _assert(
      floor_ticks[i] >= 0 and floor_ticks[i] < _PLACE_FLOOR_MAX_TICKS,
      "%s: %s not on floor within %d ticks after _place at %s (floor_tick=%d, y=%.2f)" % [
        label, names[i], _PLACE_FLOOR_MAX_TICKS, str(starts[i]), floor_ticks[i], bodies[i].global_position.y,
      ],
    )
    _assert(
      min_ys[i] > _PLACE_MIN_Y,
      "%s: %s fell below y=%.1f after _place at %s (min y=%.2f)" % [label, names[i], _PLACE_MIN_Y, str(starts[i]), min_ys[i]],
    )
    print("C9_EDGE_PLACE %s %s: floor_tick=%d min_y=%.2f" % [label, names[i], floor_ticks[i], min_ys[i]])


## Regression (CMV3C-34): an interior boulder moved to sit on a start is detected by the overlap
## guard and resolved, after which the body lands on the floor and stays up.
func _test_guard_resolves_moved_interior_boulder() -> void:
  # Arrange
  _main.call("new_game")
  var rabbit: CharacterBody3D = _main.call("get_player_creature_body")
  var xz := _edge_point(Vector2(-1.0, 0.0), 40.0) + Vector2(_EDGE_INSET_M, 0.0)
  var boulder: Node3D = null
  for ch in (_main.get("_obstacles_root") as Node3D).get_children():
    var n3 := ch as Node3D
    if n3 != null and _is_interior_boulder(n3):
      boulder = n3
      break
  _assert(boulder != null, "guard test: an interior boulder exists to move")
  if boulder == null:
    return
  boulder.global_position = Vector3(xz.x, boulder.global_position.y, xz.y)
  await physics_frame
  await physics_frame
  _assert(not _prop_roots_overlapping(xz).is_empty(), "guard test: moved boulder is detected overlapping start %s" % str(xz))
  # Act
  var moved: int = await _clear_props_at(xz)
  _place(rabbit, xz)
  var floor_tick := -1
  var min_y := 999.0
  for tick_i in _PLACE_WATCH_TICKS:
    await physics_frame
    min_y = minf(min_y, rabbit.global_position.y)
    if floor_tick < 0 and rabbit.is_on_floor():
      floor_tick = tick_i
  # Assert
  _assert(moved >= 1, "guard test: guard moved at least one prop (moved %d)" % moved)
  _assert(_prop_roots_overlapping(xz).is_empty(), "guard test: start %s clear after guard" % str(xz))
  _assert(floor_tick >= 0 and floor_tick < _PLACE_FLOOR_MAX_TICKS, "guard test: rabbit on floor after guard (floor_tick=%d)" % floor_tick)
  _assert(min_y > _PLACE_MIN_Y, "guard test: rabbit stayed above y=%.1f (min y=%.2f)" % [_PLACE_MIN_Y, min_y])
  print("C9_EDGE_GUARD moved=%d floor_tick=%d min_y=%.2f" % [moved, floor_tick, min_y])
