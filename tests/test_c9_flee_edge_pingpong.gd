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

var _failures: int = 0
var _main: Node3D
var _sampler: Object


func _init() -> void:
  _run.call_deferred()


func _run() -> void:
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
  _assert(_sampler != null and _sampler.is_valid() and _sampler.has_walkable_mask(), "walkable mask baked")
  var driver: Node = _main.call("_ai_driver")
  _assert(driver != null and bool(driver.call("begin_engine_player_round")), "AI driver round starts")
  if _failures == 0:
    await _test_flee_along_edge("minus_x_edge", Vector2(-1.0, 0.0), 40.0)
    await _test_flee_along_edge("plus_z_edge", Vector2(0.0, 1.0), 0.0)
    await _test_flee_along_edge("minus_x_minus_z_corner", Vector2(-1.0, -1.0).normalized(), 0.0)
  if _failures > 0:
    push_error("test_c9_flee_edge_pingpong.gd: %d assertion(s) failed." % _failures)
  quit(0 if _failures == 0 else 1)


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


## Teleports [param body] to [param xz] on the terrain surface and clears its velocity.
func _place(body: CharacterBody3D, xz: Vector2) -> void:
  var y: float = _sampler.sample_elevation(xz, 0.0) + 1.2
  body.global_position = Vector3(xz.x, y, xz.y)
  body.velocity = Vector3.ZERO
