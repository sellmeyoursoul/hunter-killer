extends RefCounted
class_name MotorPlanner
## V3 live-tier planner — turn/move toward step objectives ([CREATURE_MOVEMENT_V3.md §3 / §12.2 6c](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _LearnReg := preload("res://creature/memory/stimulus_learn_registry.gd")
const _AwarenessScan := preload("res://creature/motor/awareness_zone_scan.gd")
const _PathClear := preload("res://creature/motor/motor_path_clear.gd")
const _BlockedApproach := preload("res://creature/motor/blocked_approach_memory.gd")
const _BlockedObjective := preload("res://creature/motor/blocked_objective_resolver.gd")
const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")
const _LocomotionExecutor := preload("res://creature/motor/locomotion_executor.gd")
const _ExploreSeek := preload("res://creature/motor/motor_explore_seek.gd")
const _MotorGoalHub := preload("res://creature/motor/motor_goal_hub.gd")
const _ShelterProbe := preload("res://creature/motor/shelter_enclosure_probe.gd")
const _GoalSource := preload("res://creature/motor/goal_source_memory.gd")
const _LatchHold := preload("res://creature/motor/latch_hold.gd")

const _FOOD_INV_HUNGRY := 0
const _FOOD_INV_STOCKED := 1
const _FOOD_INV_UNDERSTOCKED := 2

## V2 reference: ~400 px/s at 60 Hz — [code]motor_stuck_move_epsilon[/code] 1.25 ≈ 18.75% of that per-tick budget.
const _LEGACY_REF_TICK_DISPLACEMENT := 400.0 / 60.0


## Fresh planner runtime state owned by [code]CreatureMotorStack[/code].
static func new_state() -> Dictionary:
  return {
    "goal_kind": &"",
    "step_goal": Vector3.ZERO,
    ## Sole source of truth for whether `step_goal` holds a real target — `Vector3.ZERO` is also a
    ## legitimate world position (playfield centered near origin), so the vector's magnitude can't
    ## be used to tell "unset" from "target is near the origin" (CLEANUP C9 sentinel-collision bug,
    ## design review §5).
    "step_goal_set": false,
    "step_instance_id": 0,
    "step_source": &"live",
    "blocked_approach": {},
    "consecutive_blocked": 0,
    "explore_dir": Vector3.ZERO,
    "explore_waypoint": Vector3.ZERO,
    ## See `step_goal_set` — same sentinel-collision hazard for a minted explore waypoint.
    "explore_waypoint_set": false,
    "last_outcome_blocked": false,
    "step_stimulus_kind_id": &"",
    "blocked_objective_action": &"",
    "boundary_scan_active": false,
    "boundary_scan_sign": 0,
    "boundary_scan_turns": 0,
    "boundary_scan_egress_ticks": 0,
    "precise_no_progress_ticks": 0,
    "precise_last_bearing_err_deg": INF,
    "precise_last_dist_sq": INF,
    "locale_no_progress_ticks": 0,
    "locale_last_bearing_err_deg": INF,
    "locale_last_dist_sq": INF,
    ## Anchor cleared by `_maybe_locale_arrival_bind_or_clear` (arrived, no consumable) plus a
    ## countdown so the very next re-derivation doesn't immediately re-pick the same empty spot —
    ## re-approaching a point the creature is already standing on makes bearing math degenerate
    ## and produces an in-place turn-storm (CLEANUP C2 duel-manual finding, 2026-07-17).
    "locale_arrival_clear_anchor": Vector3.ZERO,
    ## See `step_goal_set` — same sentinel-collision hazard for the cleared-anchor bookkeeping.
    "locale_arrival_clear_anchor_set": false,
    "locale_arrival_clear_cooldown_ticks": 0,
    "explore_no_progress_ticks": 0,
    "explore_last_facing_dot": -2.0,
    ## Prior tick's MOVE_FORWARD displacement magnitude for the still-ramping check in
    ## `note_outcome` (§ explore-idle-stuck cold-start fix): -1.0 = no baseline yet this commit.
    "explore_last_move_disp_len": -1.0,
    "playfield_clamp_latch_ticks": 0,
    "food_inventory_step_mode": -1,
    "prey_engagement_instance_id": 0,
    "prey_engagement_ticks_remaining": 0,
    "prey_engagement_latch_total": 0,
    "flee_waypoint": Vector3.ZERO,
    ## See `step_goal_set` — this is the field whose sentinel collision caused C9's 7th-fix bug.
    "flee_waypoint_set": false,
    "flee_waypoint_ticks_remaining": 0,
    "flee_backtrack_streak": 0,
    "flee_recent_dirs": [],
    "pursuit_detour_waypoint": Vector3.ZERO,
    ## See `step_goal_set` — same sentinel-collision hazard for the pursuit-detour latch.
    "pursuit_detour_waypoint_set": false,
    "pursuit_detour_ticks_remaining": 0,
    "pursuit_detour_alt_flip": false,
    "pursuit_detour_escalation_tier": 0,
    "step_ultimate_pos": Vector3.ZERO,
    ## See `step_goal_set` — same sentinel-collision hazard for the "ultimate" (pre-step-clamp) target.
    "step_ultimate_pos_set": false,
    "force_align_turn_before_move": false,
    ## Accumulated turn degrees while in eat range without EAT (C3 orbit break).
    "eat_orbit_turn_deg_accumulated": 0.0,
    ## Horizontal distance to `step_goal` as of the last `align_and_move` tick; -1.0 = not yet
    ## computed this session. Planner-owned so future range-gated goals (e.g. ranged combat) can
    ## consult it without recomputing (CLEANUP R1).
    "dist_to_goal": -1.0,
    ## Latched LoS-blocked verdict for `_run_path_clearance_los_nav` hysteresis (§3.2 thrash fix):
    ## a flip clear->blocked or blocked->clear only takes effect after `los_hysteresis_ticks`
    ## consecutive same-direction raw verdicts, so a single grazing ray at a tight obstacle pocket
    ## can't alternate the step goal every tick.
    "los_blocked_latched": false,
    "los_verdict_streak": 0,
    ## Per-target awareness-hysteresis cache for the live threat scan (design review §7,
    ## CLEANUP C11) — `{instance_id: {"latched": bool, "streak": int}}`, owned and pruned by
    ## `AwarenessZoneScan._scan_hostile_threats` via `AwarenessZone.latch_awareness_verdict`.
    ## Generalizes `los_blocked_latched`'s single-target pattern above to a multi-target scan.
    "threat_los_hysteresis": {},
    ## GK_SHELTER candidate-nomination / STAY-evaluate bookkeeping (CREATURE_MOVEMENT_V3.md §6.4).
    "shelter_candidate_anchor": Vector3.ZERO,
    ## See `step_goal_set` — same sentinel-collision hazard for the shelter candidate anchor.
    "shelter_candidate_anchor_set": false,
    "shelter_candidate_instance_id": 0,
    "shelter_eval_active": false,
    "shelter_eval_cycles": 0,
    "shelter_eval_total_ticks": 0,
    "shelter_eval_result": &"",
    "shelter_eval_last_fraction": 0.0,
    "shelter_probe_cooldown_cycles": 0,
  }


## Picks one locomotion [MotorAction] for this physics tick.
static func select_action(ctx: Dictionary, state: Dictionary) -> int:
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  if body == null:
    return _MotorAction.STAY
  if bool(ctx.get("flight_fast_path_active", false)):
    return _select_flight_action(ctx, state)
  var incumbent: Dictionary = ctx.get("incumbent", {})
  if incumbent.is_empty():
    return _MotorAction.STAY
  var goal_kind: StringName = incumbent.get("goal_kind", &"")
  if goal_kind.is_empty():
    return _MotorAction.STAY
  if goal_kind == _GkReg.GK_FIND_FOOD:
    _tick_prey_engagement_latch(ctx, state)
  _sync_step_objective(ctx, state, goal_kind)
  if bool(state.get("boundary_scan_active", false)) and state.get("step_source") == &"explore":
    return _boundary_scan_action(body, motor_v3, state)
  var delta := float(ctx.get("delta", 1.0 / 60.0))
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return _MotorAction.STAY
  if goal_kind == _GkReg.GK_FIND_FOOD:
    if _can_eat_now(body, step_goal, state, motor_v3, delta, ctx):
      state["eat_orbit_turn_deg_accumulated"] = 0.0
      return _MotorAction.EAT
    var orbit_act := _select_eat_orbit_or_align(body, step_goal, state, motor_v3, delta)
    if orbit_act >= 0:
      return orbit_act
  # CLEANUP (2026-08-26): `GOAL_REST` previously fell through to the generic `_at_arrival` ->
  # `STAY` branch below like every other non-find_food goal — `MotorAction.REST` existed (enum,
  # action-name string, `rest_baseline_multiplier` calorie handling, `_rest_area_only_perception`'s
  # own `_last_outcome.action == REST` check) but `select_action` never actually returned it, so a
  # winning REST cycle was indistinguishable from ordinary idling both to the player and to that
  # perception gate. `_sync_shelter_or_rest_objective` now holds the creature's own position as the
  # step goal, so this is `true` the same tick REST is reached.
  if goal_kind == _MotorGoalHub.GOAL_REST and _at_arrival(body, step_goal, motor_v3):
    return _MotorAction.REST
  ## Bound food instance: do not STAY at arrival_tolerance before EAT step-range is reached.
  if _at_arrival(body, step_goal, motor_v3):
    if goal_kind != _GkReg.GK_FIND_FOOD or int(state.get("step_instance_id", 0)) == 0:
      return _MotorAction.STAY
  return _locomote_toward_step_goal(body, motor_v3, state, ctx)


## True for step sources that hold a stable world objective (no per-tick LoS/nav/backtrack rewrite).
static func _is_latched_step_source(step_source: StringName) -> bool:
  return (
    step_source == &"precise"
    or step_source == &"explore"
    or step_source == &"memory_moving"
  )


## Minimum per-tick displacement that counts as progress (scales with body speed × delta).
static func _latched_stuck_move_epsilon(
  motor_v3: Dictionary,
  body: CharacterBody3D,
  delta: float,
) -> float:
  var config := maxf(0.01, float(motor_v3.get("motor_stuck_move_epsilon", 1.25)))
  if body == null:
    return config
  var max_spd := _LocomotionExecutor._expected_horizontal_speed(body)
  var dt := maxf(delta, 1.0 / 120.0)
  var expected_per_tick := max_spd * dt
  var frac := config / _LEGACY_REF_TICK_DISPLACEMENT
  return maxf(0.01, expected_per_tick * frac)


static func _tick_had_meaningful_progress(
  body: CharacterBody3D,
  step_goal: Vector3,
  tick_disp: Vector3,
  act: int,
  _motor_v3: Dictionary,
  stuck_eps: float,
) -> bool:
  if act != _MotorAction.MOVE_FORWARD:
    return false
  if tick_disp.length_squared() < stuck_eps * stuck_eps:
    return false
  var creature_pos := body.global_position
  var to_goal := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
  if to_goal.length_squared() < 1e-8:
    return tick_disp.length_squared() >= stuck_eps * stuck_eps
  return tick_disp.dot(to_goal.normalized()) >= stuck_eps * 0.5


## Rotate explore bearing and clear latch after sustained stuck (interior / no progress).
static func _apply_explore_stuck_replan(state: Dictionary) -> void:
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-8:
    explore = _MotorPlane.HORIZONTAL_FORWARD
  state["explore_dir"] = explore.rotated(Vector3.UP, deg_to_rad(60.0)).normalized()
  state["explore_waypoint"] = Vector3.ZERO
  state["explore_waypoint_set"] = false
  state["step_goal"] = Vector3.ZERO
  state["step_goal_set"] = false
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  _reset_explore_align_progress_state(state)


## Rim hug band: inward replan; interior: 60° stuck replan.
static func _apply_explore_stuck_or_rim_replan(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  if body != null and _is_near_playfield_boundary(body, motor_v3):
    _apply_explore_rim_escape_replan(state, body, motor_v3)
  else:
    _apply_explore_stuck_replan(state)
  state["blocked_objective_action"] = &"explore_replan"


## True when the creature has moved past [param latched] along latched [code]explore_dir[/code].
static func _passed_explore_waypoint(
  body: CharacterBody3D,
  latched: Vector3,
  state: Dictionary,
) -> bool:
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-12:
    return _facing_dot_to_target(body, latched) < 0.0
  explore = explore.normalized()
  var travel := body.global_position - latched
  travel.y = 0.0
  if travel.length_squared() < 1e-12:
    return true
  return travel.dot(explore) > 0.0


## Expected horizontal displacement for one [code]MOVE_FORWARD[/code] tick at cruise speed.
static func _expected_forward_step_world(body: CharacterBody3D, delta: float) -> float:
  var max_spd := _LocomotionExecutor._expected_horizontal_speed(body)
  return maxf(0.01, max_spd * maxf(delta, 1.0 / 120.0))


static func _is_fixed_objective_overshoot_source(step_source: StringName) -> bool:
  # `live` deferred — moving prey retargets every tick; overshoot remint causes pursuit flutter.
  return (
    step_source == &"locale"
    or step_source == &"precise"
    or step_source == &"memory_moving"
  )


## Same [code]step_source[/code] + instance refresh (e.g. per-tick live prey pos) — not a discrete jump.
static func _is_continuous_objective_retarget(
  state: Dictionary,
  step_source: StringName,
  instance_id: int,
) -> bool:
  if instance_id == 0:
    return false
  return (
    state.get("step_source", &"") == step_source
    and int(state.get("step_instance_id", 0)) == instance_id
  )


## True when [param pos_after] lies past [param goal] along [param approach_dir] (horizontal).
static func _passed_goal_along_approach(
  pos_after: Vector3,
  goal: Vector3,
  approach_dir: Vector3,
) -> bool:
  if approach_dir.length_squared() < 1e-12:
    return false
  var travel := pos_after - goal
  travel.y = 0.0
  if travel.length_squared() < 1e-12:
    return true
  return travel.dot(approach_dir.normalized()) > 0.0


static func _maybe_flag_material_step_goal_change(
  state: Dictionary,
  body: CharacterBody3D,
  old_goal: Vector3,
  new_goal: Vector3,
  motor_v3: Dictionary,
  delta: float,
) -> void:
  if old_goal.length_squared() < 1e-8 or new_goal.length_squared() < 1e-8:
    return
  var stuck_eps := _latched_stuck_move_epsilon(motor_v3, body, delta)
  var flat_old := Vector3(old_goal.x, 0.0, old_goal.z)
  var flat_new := Vector3(new_goal.x, 0.0, new_goal.z)
  if flat_old.distance_to(flat_new) > stuck_eps:
    state["force_align_turn_before_move"] = true


static func _assign_resolved_step_goal(
  state: Dictionary,
  body: CharacterBody3D,
  ultimate: Vector3,
  resolved_goal: Vector3,
  motor_v3: Dictionary,
  delta: float,
  flag_material_change: bool = true,
) -> void:
  var old_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if flag_material_change:
    _maybe_flag_material_step_goal_change(state, body, old_goal, resolved_goal, motor_v3, delta)
  state["step_goal"] = resolved_goal
  state["step_goal_set"] = true
  if ultimate.length_squared() > 1e-8:
    state["step_ultimate_pos"] = ultimate
    state["step_ultimate_pos_set"] = true


## Post-[code]MOVE_F[/code] overshoot recovery for fixed objectives (post-6d-approach-geometry Layer 1).
## Remint + turn-first only; retains [code]locale_no_progress_ticks[/code] /
## [code]precise_no_progress_ticks[/code] so Layer 2 can still escalate §9 (CLEANUP 2026-07-14).
static func _maybe_apply_fixed_objective_overshoot(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
  pos_before_tick: Vector3,
  delta: float,
) -> void:
  var step_source: StringName = state.get("step_source", &"live")
  if not _is_fixed_objective_overshoot_source(step_source):
    return
  var ultimate: Vector3 = state.get("step_ultimate_pos", Vector3.ZERO)
  var ultimate_valid := bool(state.get("step_ultimate_pos_set", false))
  if not ultimate_valid:
    ultimate = state.get("step_goal", Vector3.ZERO)
    ultimate_valid = bool(state.get("step_goal_set", false))
  if not ultimate_valid:
    return
  var arrival_tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  if body.global_position.distance_to(ultimate) <= arrival_tol:
    return
  var close_steps := int(motor_v3.get("approach_overshoot_guard_move_steps", 2))
  var close_band := close_steps * _expected_forward_step_world(body, delta)
  if body.global_position.distance_to(ultimate) >= close_band:
    return
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return
  var pos_after := body.global_position
  var to_goal_before := Vector3(
    step_goal.x - pos_before_tick.x, 0.0, step_goal.z - pos_before_tick.z
  )
  if to_goal_before.length_squared() < 1e-12:
    return
  var approach_dir := to_goal_before.normalized()
  var dist_before := pos_before_tick.distance_to(step_goal)
  var dist_after := pos_after.distance_to(step_goal)
  var passed := _passed_goal_along_approach(pos_after, step_goal, approach_dir)
  var rear_confirm := dist_after > dist_before and _facing_dot_to_target(body, step_goal) < 0.0
  if not passed and not rear_confirm:
    return
  var map_rid: RID = ctx.get("map_rid", RID())
  var agent_r := _agent_radius(body)
  var reminted := _PathClear.resolve_step_objective(map_rid, pos_after, ultimate, agent_r)
  _assign_resolved_step_goal(state, body, ultimate, reminted, motor_v3, delta)
  state["force_align_turn_before_move"] = true





## Drop overshot explore latch; rim overshoot routes inward, interior rotates 60°.
static func _apply_explore_waypoint_passed(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  _apply_explore_stuck_or_rim_replan(state, body, motor_v3)


## Resets explore fields after §9 seek fallback so the next sync can mint a waypoint.
static func _seed_explore_after_seek(state: Dictionary, _ctx: Dictionary) -> void:
  state["explore_dir"] = Vector3.ZERO
  state["explore_waypoint"] = Vector3.ZERO
  state["explore_waypoint_set"] = false
  state["step_goal"] = Vector3.ZERO
  state["step_goal_set"] = false
  state["step_instance_id"] = 0
  state["step_source"] = &"explore"
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  _reset_explore_align_progress_state(state)


static func _reset_explore_align_progress_state(state: Dictionary) -> void:
  state["explore_no_progress_ticks"] = 0
  state["explore_last_facing_dot"] = -2.0
  state["explore_last_move_disp_len"] = -1.0


static func _note_explore_align_progress(
  state: Dictionary,
  body: CharacterBody3D,
  step_goal: Vector3,
  explore_idle_stuck: bool,
) -> void:
  if step_goal.length_squared() < 1e-8:
    return
  var dot := _facing_dot_to_target(body, step_goal)
  var last_dot := float(state.get("explore_last_facing_dot", -2.0))
  if last_dot <= -1.5:
    state["explore_last_facing_dot"] = dot
    return
  if dot < 0.0:
    if explore_idle_stuck:
      state["explore_no_progress_ticks"] = int(state.get("explore_no_progress_ticks", 0)) + 1
  elif dot > last_dot + 0.01:
    state["explore_no_progress_ticks"] = 0
  elif explore_idle_stuck:
    state["explore_no_progress_ticks"] = int(state.get("explore_no_progress_ticks", 0)) + 1
  state["explore_last_facing_dot"] = dot


static func _playfield_hug_band(motor_v3: Dictionary) -> float:
  return maxf(4.0, float(motor_v3.get("playfield_hug_band", 14.0)))


static func _playfield_hug_info(body: CharacterBody3D, motor_v3: Dictionary) -> Dictionary:
  return _MotorPlane.playfield_boundary_hug(body, motor_v3, _playfield_hug_band(motor_v3))


static func _is_near_playfield_boundary(body: CharacterBody3D, motor_v3: Dictionary) -> bool:
  return bool(_playfield_hug_info(body, motor_v3).get("near", false))


## Footprint within fixed world margin of playfield edge (clamp ground truth; not scaled hug band).
static func _is_at_playfield_rim(body: CharacterBody3D, motor_v3: Dictionary) -> bool:
  var rim_margin := maxf(0.5, float(motor_v3.get("playfield_rim_margin", 2.0)))
  return bool(_MotorPlane.playfield_boundary_hug(body, motor_v3, rim_margin).get("near", false))


## True when post-scan egress may end after a forward step (creature left the tight rim band).
static func _rim_egress_move_cleared(body: CharacterBody3D, motor_v3: Dictionary) -> bool:
  return not _is_at_playfield_rim(body, motor_v3)


static func _playfield_clamp_latch_ttl(motor_v3: Dictionary) -> int:
  var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
  return min_ticks + _boundary_scan_turn_budget(motor_v3)


static func _should_explore_boundary_scan(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  boundary_clamped: bool,
) -> bool:
  if boundary_clamped:
    return true
  if int(state.get("playfield_clamp_latch_ticks", 0)) > 0:
    return true
  if _is_at_playfield_rim(body, motor_v3):
    return true
  return _is_near_playfield_boundary(body, motor_v3)


static func _boundary_scan_turn_budget(motor_v3: Dictionary) -> int:
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  if turn_deg <= 0.0:
    return 16
  return maxi(1, int(ceil(360.0 / turn_deg)))


## Horizontal bearing toward playfield interior after rim boundary scan (inbound normal, not rim tangent).
## True when a latched explore bearing at the rim is tangent/outward vs playfield inbound.
static func _explore_latch_needs_rim_realign(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
) -> bool:
  if body == null or not _is_near_playfield_boundary(body, motor_v3):
    return false
  var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
  if explore.length_squared() < 1e-12:
    return true
  var inward := _rim_escape_explore_dir(body, motor_v3)
  if inward.length_squared() < 1e-12:
    return false
  return explore.normalized().dot(inward.normalized()) < _move_alignment_min_dot(motor_v3)


static func _rim_escape_explore_dir(body: CharacterBody3D, motor_v3: Dictionary) -> Vector3:
  var hug := _playfield_hug_info(body, motor_v3)
  var inbound: Vector3 = hug.get("inbound_normal", Vector3.ZERO)
  if inbound.length_squared() > 1e-12:
    return inbound.normalized()
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO)
  if facing.length_squared() > 1e-12:
    return facing.normalized()
  return _MotorPlane.HORIZONTAL_FORWARD


## Clear explore latch and pick an interior bearing after rim clamp (avoids scan ↔ tangent loop).
static func _apply_explore_rim_escape_replan(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
  state["explore_waypoint"] = Vector3.ZERO
  state["explore_waypoint_set"] = false
  state["step_goal"] = Vector3.ZERO
  state["step_goal_set"] = false
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  state["playfield_clamp_latch_ticks"] = 0
  state["boundary_scan_egress_ticks"] = 0
  _reset_explore_align_progress_state(state)


static func _pick_boundary_scan_sign(body: CharacterBody3D, hug: Dictionary, motor_v3: Dictionary) -> int:
  var inbound: Vector3 = hug.get("inbound_normal", Vector3.ZERO)
  if inbound.length_squared() < 1e-12:
    return 1
  var tangent_ccw := inbound.cross(Vector3.UP).normalized()
  var tangent_cw := -tangent_ccw
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), tangent_ccw)
  if facing.length_squared() < 1e-12:
    return 1
  facing = facing.normalized()
  var prefer := tangent_ccw if facing.dot(tangent_ccw) >= facing.dot(tangent_cw) else tangent_cw
  var turn_rad := deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5)))
  var left_after := facing.rotated(Vector3.UP, turn_rad).dot(prefer)
  var right_after := facing.rotated(Vector3.UP, -turn_rad).dot(prefer)
  return 1 if left_after >= right_after else -1


static func _pick_shorter_arc_turn_sign(
  body: CharacterBody3D,
  reference_dir: Vector3,
  motor_v3: Dictionary,
) -> int:
  ## Pick turn direction that improves dot toward [param reference_dir] after one turn step.
  var ref := reference_dir
  if ref.length_squared() < 1e-12:
    return 1
  ref = ref.normalized()
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), ref)
  if facing.length_squared() < 1e-12:
    return 1
  facing = facing.normalized()
  var turn_rad := deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5)))
  var left_after := facing.rotated(Vector3.UP, turn_rad).dot(ref)
  var right_after := facing.rotated(Vector3.UP, -turn_rad).dot(ref)
  return _resolve_turn_sign_tie(left_after, right_after, motor_v3)


## §7.3.0 align turn pick toward world [param target] (fewest-turn + chaos at ±180°).
static func _pick_align_turn_sign(
  body: CharacterBody3D,
  target: Vector3,
  motor_v3: Dictionary,
) -> int:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-12:
    return 1
  return _pick_shorter_arc_turn_sign(body, to_target, motor_v3)


static func _resolve_turn_sign_tie(left_after: float, right_after: float, motor_v3: Dictionary) -> int:
  const tie_eps := 1e-5
  if left_after > right_after + tie_eps:
    return 1
  if right_after > left_after + tie_eps:
    return -1
  var chaos := clampf(float(motor_v3.get("goal_consideration_chaos", 0.15)), 0.0, 1.0)
  if chaos > 0.0 and randf() < chaos:
    return 1 if randf() < 0.5 else -1
  return 1


static func _begin_boundary_scan(
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  var hug := _playfield_hug_info(body, motor_v3)
  var scan_sign := int(state.get("boundary_scan_sign", 0))
  if scan_sign == 0:
    scan_sign = _pick_boundary_scan_sign(body, hug, motor_v3)
  state["boundary_scan_active"] = true
  state["boundary_scan_sign"] = scan_sign
  state["boundary_scan_turns"] = 0
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  state["playfield_clamp_latch_ticks"] = 0
  state["blocked_objective_action"] = &"boundary_scan"


## Ticks after [method _end_boundary_scan] during which inward-align turns don't re-arm the scan.
## Sized to a full turn (align to inward waypoint) plus a short forward-egress margin.
static func _boundary_scan_egress_budget(motor_v3: Dictionary) -> int:
  return _boundary_scan_turn_budget(motor_v3) + int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))


static func _end_boundary_scan(
  state: Dictionary,
  body: CharacterBody3D,
  action: StringName,
  motor_v3: Dictionary,
) -> void:
  state["boundary_scan_active"] = false
  state["boundary_scan_turns"] = 0
  state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
  state["explore_waypoint"] = Vector3.ZERO
  state["explore_waypoint_set"] = false
  state["step_goal"] = Vector3.ZERO
  state["step_goal_set"] = false
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  state["playfield_clamp_latch_ticks"] = 0
  state["blocked_objective_action"] = action
  if action == &"boundary_scan_done":
    state["boundary_scan_egress_ticks"] = _boundary_scan_egress_budget(motor_v3)
  _reset_explore_align_progress_state(state)


static func _boundary_scan_action(body: CharacterBody3D, motor_v3: Dictionary, state: Dictionary) -> int:
  var scan_sign := int(state.get("boundary_scan_sign", 0))
  if scan_sign == 0:
    scan_sign = _pick_boundary_scan_sign(body, _playfield_hug_info(body, motor_v3), motor_v3)
    state["boundary_scan_sign"] = scan_sign
  return _MotorAction.TURN_LEFT if scan_sign > 0 else _MotorAction.TURN_RIGHT


static func _reset_precise_progress_state(state: Dictionary) -> void:
  state["precise_no_progress_ticks"] = 0
  state["precise_last_bearing_err_deg"] = INF
  state["precise_last_dist_sq"] = INF


static func _reset_locale_progress_state(state: Dictionary) -> void:
  state["locale_no_progress_ticks"] = 0
  state["locale_last_bearing_err_deg"] = INF
  state["locale_last_dist_sq"] = INF


## Bearing- or distance-improved progress toward [param step_goal] for fixed-objective stuck escalation.
static func _note_fixed_objective_position_progress(
  state: Dictionary,
  body: CharacterBody3D,
  stuck_eps: float,
  no_progress_key: String,
  last_err_key: String,
  last_dist_key: String,
) -> void:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return
  var err_deg := absf(_signed_bearing_error_deg(body, step_goal))
  var dist_sq := body.global_position.distance_squared_to(step_goal)
  var last_err := float(state.get(last_err_key, INF))
  var last_dist := float(state.get(last_dist_key, INF))
  if is_inf(last_err) or is_inf(last_dist):
    state[last_err_key] = err_deg
    state[last_dist_key] = dist_sq
    return
  var improve_thresh := stuck_eps * stuck_eps
  var bearing_improved := err_deg + 0.25 < last_err
  var dist_improved := dist_sq + improve_thresh < last_dist
  if bearing_improved or dist_improved:
    state[no_progress_key] = 0
  else:
    state[no_progress_key] = int(state.get(no_progress_key, 0)) + 1
  state[last_err_key] = err_deg
  state[last_dist_key] = dist_sq


static func _note_precise_position_progress(
  state: Dictionary,
  body: CharacterBody3D,
  stuck_eps: float,
) -> void:
  _note_fixed_objective_position_progress(
    state,
    body,
    stuck_eps,
    "precise_no_progress_ticks",
    "precise_last_bearing_err_deg",
    "precise_last_dist_sq",
  )


static func _note_locale_position_progress(
  state: Dictionary,
  body: CharacterBody3D,
  stuck_eps: float,
) -> void:
  _note_fixed_objective_position_progress(
    state,
    body,
    stuck_eps,
    "locale_no_progress_ticks",
    "locale_last_bearing_err_deg",
    "locale_last_dist_sq",
  )


static func _note_boundary_scan_progress(
  state: Dictionary,
  body: CharacterBody3D,
  act: int,
  motor_v3: Dictionary,
  stuck_this_tick: bool,
) -> void:
  if not bool(state.get("boundary_scan_active", false)):
    return
  if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
    state["boundary_scan_turns"] = int(state.get("boundary_scan_turns", 0)) + 1
  var budget := _boundary_scan_turn_budget(motor_v3)
  if int(state.get("boundary_scan_turns", 0)) >= budget:
    _end_boundary_scan(state, body, &"boundary_scan_done", motor_v3)
  elif act == _MotorAction.MOVE_FORWARD and not stuck_this_tick:
    _end_boundary_scan(state, body, &"boundary_scan_done", motor_v3)


static func _record_blocked_approach(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
) -> void:
  var pos_after := body.global_position
  var disp := outcome.displacement if outcome != null else Vector3.ZERO
  disp.y = 0.0
  var pos_before := pos_after - disp
  var approach := _BlockedApproach.infer_approach_dir(
    pos_after,
    pos_before,
    _MotorPlane.body_motor_velocity(body),
    [],
    _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO),
  )
  var ttl := int(motor_v3.get("blocked_approach_memory_ticks", 45))
  _BlockedApproach.record(state["blocked_approach"], approach, physics_tick, ttl)


## Updates [param state] after locomotion + playfield clamp for this tick.
## Returns true when blocked objective resolution should run (precise / live latched paths).
static func note_outcome(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
  pos_before_tick: Vector3 = Vector3.ZERO,
  boundary_clamped: bool = false,
  delta: float = 1.0 / 60.0,
  planner_ctx: Dictionary = {},
) -> bool:
  var act: int = _MotorAction.STAY
  if outcome != null:
    act = _MotorAction.normalize(outcome.action)
  var step_source: StringName = state.get("step_source", &"live")
  var is_latched := _is_latched_step_source(step_source)
  var executor_blocked: bool = outcome != null and outcome.blocked
  var pos_after := body.global_position
  var tick_disp := Vector3(
    pos_after.x - pos_before_tick.x, 0.0, pos_after.z - pos_before_tick.z
  )
  var stuck_eps := _latched_stuck_move_epsilon(motor_v3, body, delta)
  var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
  var no_progress := tick_disp.length_squared() < stuck_eps * stuck_eps
  var boundary_stuck := boundary_clamped and act == _MotorAction.MOVE_FORWARD
  var move_stuck: bool = executor_blocked or boundary_stuck
  var scan_active := bool(state.get("boundary_scan_active", false))
  ## Cold-start acceleration ramp (`apply_horizontal_move_intent`) can hold a genuinely-progressing
  ## MOVE_FORWARD below `stuck_eps` for several ticks after a stop (e.g. right after an align turn) —
  ## treating that as a dead end fired a stuck-replan before the creature ever reached cruising speed.
  ## Displacement still climbing tick-over-tick means it's ramping, not stuck, so it's exempted from
  ## the no-progress count until it plateaus (same "improving disqualifies" idiom as the facing-dot
  ## check just above).
  var still_ramping := false
  if step_source == &"explore" and act == _MotorAction.MOVE_FORWARD:
    var last_disp_len := float(state.get("explore_last_move_disp_len", -1.0))
    var disp_len := tick_disp.length()
    still_ramping = last_disp_len >= 0.0 and disp_len > last_disp_len + 0.001
    state["explore_last_move_disp_len"] = disp_len
  elif step_source == &"explore":
    state["explore_last_move_disp_len"] = -1.0
  var explore_idle_stuck := (
    step_source == &"explore"
    and is_latched
    and no_progress
    and not scan_active
    and not still_ramping
  )
  var stuck_this_tick: bool = move_stuck or explore_idle_stuck

  state["last_outcome_blocked"] = stuck_this_tick
  if outcome != null and stuck_this_tick:
    outcome.blocked = true

  if step_source == &"precise" and is_latched:
    _note_precise_position_progress(state, body, stuck_eps)

  if step_source == &"locale":
    _note_locale_position_progress(state, body, stuck_eps)

  if step_source == &"explore" and is_latched:
    var align_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    _note_explore_align_progress(state, body, align_goal, explore_idle_stuck)
    if move_stuck:
      state["explore_no_progress_ticks"] = maxi(
        int(state.get("explore_no_progress_ticks", 0)),
        min_ticks,
      )

  if step_source == &"explore":
    if boundary_clamped:
      state["playfield_clamp_latch_ticks"] = _playfield_clamp_latch_ttl(motor_v3)
    elif int(state.get("playfield_clamp_latch_ticks", 0)) > 0:
      state["playfield_clamp_latch_ticks"] = int(state["playfield_clamp_latch_ticks"]) - 1

  if int(state.get("locale_arrival_clear_cooldown_ticks", 0)) > 0:
    state["locale_arrival_clear_cooldown_ticks"] = (
      int(state["locale_arrival_clear_cooldown_ticks"]) - 1
    )

  # Post-scan inward-egress grace: run down while turning inward; clear on a real forward step
  # off the tight rim band (not a tangent slide still at the wall) or on rim clamp / scan re-entry.
  if step_source == &"explore" and int(state.get("boundary_scan_egress_ticks", 0)) > 0:
    var egress_move_ok := (
      act == _MotorAction.MOVE_FORWARD
      and not move_stuck
      and not no_progress
      and _rim_egress_move_cleared(body, motor_v3)
    )
    var egress_align_turn := (
      act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT
    )
    var egress_rim_move_hold := (
      act == _MotorAction.MOVE_FORWARD
      and body != null
      and _is_at_playfield_rim(body, motor_v3)
      and not egress_move_ok
    )
    if egress_move_ok or boundary_stuck or scan_active:
      state["boundary_scan_egress_ticks"] = 0
    elif not egress_align_turn and not egress_rim_move_hold:
      state["boundary_scan_egress_ticks"] = int(state["boundary_scan_egress_ticks"]) - 1

  if stuck_this_tick:
    state["consecutive_blocked"] = int(state.get("consecutive_blocked", 0)) + 1
    if move_stuck:
      _record_blocked_approach(state, body, outcome, motor_v3, physics_tick)
      if step_source == &"explore":
        state["explore_waypoint"] = Vector3.ZERO
        state["explore_waypoint_set"] = false
  elif is_latched:
    var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    if _tick_had_meaningful_progress(body, step_goal, tick_disp, act, motor_v3, stuck_eps):
      state["consecutive_blocked"] = 0
      if step_source == &"precise":
        _reset_precise_progress_state(state)
      elif step_source == &"explore" and not boundary_clamped:
        state["playfield_clamp_latch_ticks"] = 0
        _reset_explore_align_progress_state(state)
  elif step_source == &"locale":
    var locale_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    if _tick_had_meaningful_progress(body, locale_goal, tick_disp, act, motor_v3, stuck_eps):
      _reset_locale_progress_state(state)
  else:
    state["consecutive_blocked"] = 0

  _note_boundary_scan_progress(state, body, act, motor_v3, stuck_this_tick)

  if (
    act == _MotorAction.MOVE_FORWARD
    and not stuck_this_tick
    and not planner_ctx.is_empty()
  ):
    _maybe_apply_fixed_objective_overshoot(
      planner_ctx, state, body, motor_v3, pos_before_tick, delta
    )

  if step_source == &"precise" and int(state.get("precise_no_progress_ticks", 0)) >= min_ticks:
    state["last_outcome_blocked"] = true
    if outcome != null:
      outcome.blocked = true
    state["consecutive_blocked"] = maxi(int(state.get("consecutive_blocked", 0)), min_ticks)
    return true

  if step_source == &"locale" and int(state.get("locale_no_progress_ticks", 0)) >= min_ticks:
    state["last_outcome_blocked"] = true
    if outcome != null:
      outcome.blocked = true
    state["consecutive_blocked"] = maxi(int(state.get("consecutive_blocked", 0)), min_ticks)
    return true

  if int(state.get("consecutive_blocked", 0)) < min_ticks:
    return false

  if step_source == &"explore":
    # During post-scan inward egress, turning toward the inward waypoint must not re-arm the
    # scan (that was the Fox turn-only scan-loop bug). Only a fresh rim clamp escapes here.
    var in_egress := int(state.get("boundary_scan_egress_ticks", 0)) > 0
    if _should_explore_boundary_scan(body, motor_v3, state, boundary_clamped):
      if not bool(state.get("boundary_scan_active", false)):
        var post_scan_clamp: bool = (
          state.get("blocked_objective_action") == &"boundary_scan_done"
          and boundary_clamped
          and not executor_blocked
        )
        if post_scan_clamp:
          _apply_explore_rim_escape_replan(state, body, motor_v3)
          state["blocked_objective_action"] = &"explore_replan"
        elif not in_egress:
          _begin_boundary_scan(state, body, motor_v3)
    elif not in_egress and int(state.get("explore_no_progress_ticks", 0)) >= min_ticks:
      _apply_explore_stuck_or_rim_replan(state, body, motor_v3)
    return false

  return true


## Alias for [method note_outcome] with explicit tick-boundary arguments.
static func note_tick_completion(
  state: Dictionary,
  body: CharacterBody3D,
  outcome: _ActionOutcome,
  motor_v3: Dictionary,
  physics_tick: int,
  pos_before_tick: Vector3,
  boundary_clamped: bool,
  delta: float = 1.0 / 60.0,
  planner_ctx: Dictionary = {},
) -> bool:
  return note_outcome(
    state,
    body,
    outcome,
    motor_v3,
    physics_tick,
    pos_before_tick,
    boundary_clamped,
    delta,
    planner_ctx,
  )


static func _sync_step_objective(ctx: Dictionary, state: Dictionary, goal_kind: StringName) -> void:
  if state.get("goal_kind", &"") != goal_kind:
    state["goal_kind"] = goal_kind
    state["step_goal"] = Vector3.ZERO
    state["step_goal_set"] = false
    state["step_instance_id"] = 0
    state["explore_dir"] = Vector3.ZERO
    state["explore_waypoint"] = Vector3.ZERO
    state["explore_waypoint_set"] = false
    state["boundary_scan_active"] = false
    state["boundary_scan_sign"] = 0
    state["boundary_scan_turns"] = 0
    state["boundary_scan_egress_ticks"] = 0
    state["playfield_clamp_latch_ticks"] = 0
    _reset_precise_progress_state(state)
    _reset_locale_progress_state(state)
    state["locale_arrival_clear_anchor"] = Vector3.ZERO
    state["locale_arrival_clear_anchor_set"] = false
    state["locale_arrival_clear_cooldown_ticks"] = 0
    _reset_explore_align_progress_state(state)
    _clear_prey_engagement(state)
    _clear_pursuit_detour_latch(state)
    state["step_ultimate_pos"] = Vector3.ZERO
    state["step_ultimate_pos_set"] = false
    state["force_align_turn_before_move"] = false
    state["eat_orbit_turn_deg_accumulated"] = 0.0
  var refresh_targets := bool(ctx.get("refresh_step_objective", false))
  var has_step_goal := bool(state.get("step_goal_set", false))
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  var scan: Dictionary = ctx.get("scan", {})
  var map_rid: RID = ctx.get("map_rid", RID())
  var creature_pos := body.global_position
  var agent_r := _agent_radius(body)

  match goal_kind:
    _GkReg.GK_FIND_FOOD:
      _maybe_locale_arrival_bind_or_clear(
        ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
      )
      has_step_goal = bool(state.get("step_goal_set", false))
      var live_food := _AwarenessScan.best_ready_food_target(
        scan.get("food_split", {}), creature_pos
      )
      var live_moving := (
        not live_food.is_empty() and bool(live_food.get("is_moving", false))
      )
      if live_moving:
        _derive_find_food_step_objective(
          ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
        )
      elif refresh_targets or not has_step_goal:
        _derive_find_food_step_objective(
          ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
        )
      elif _food_inventory_mode_changed(ctx, state, motor_v3):
        _clear_explore_latch_for_remint(state)
        _derive_find_food_step_objective(
          ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
        )
      elif live_food.is_empty() and _find_food_memory_tier_stale(
        ctx, state, creature_pos, motor_v3, scan
      ):
        # Incumbent precise/coarse/locale belief no longer consults active — fall
        # through the tier hierarchy again instead of holding a stale step_goal.
        _derive_find_food_step_objective(
          ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
        )
      elif not live_food.is_empty() and state.get("step_source", &"") != &"locale":
        # Non-moving live remint while already bound (not holding a locale approach).
        if _pursuit_detour_latch_valid(state) and _prey_engagement_latch_valid(state):
          state["step_goal"] = state.get("pursuit_detour_waypoint", Vector3.ZERO)
          state["step_goal_set"] = true
          state["step_source"] = &"live"
          _refresh_live_prey_meta_only(ctx, state, live_food, motor_v3)
        else:
          var tick_delta := float(ctx.get("delta", 1.0 / 60.0))
          _apply_live_food_objective(
            state, live_food, map_rid, creature_pos, agent_r, body, motor_v3, tick_delta
          )
          _arm_prey_engagement_from_live_food(ctx, state, live_food, motor_v3)
        _store_food_inventory_step_mode(ctx, state, motor_v3)
      elif state.get("step_source", &"") == &"explore":
        _maintain_explore_latch(ctx, state, motor_v3)
    _GkReg.GK_AVOID_HOSTILES:
      if refresh_targets or not has_step_goal:
        ## `_flee_objective` returns `Vector3.ZERO` as an ambiguous "no threat" sentinel (see its
        ## doc comment) — this call site previously stored that return value unconditionally, so a
        ## no-threat tick could latch `step_goal` onto the world origin as if it were a real flee
        ## target (the same bug class as CLEANUP C9's 7th fix, left unguarded here). Gate on
        ## `_flee_has_visible_threat` the same way `_mint_flee_waypoint` already does.
        var flee_valid := _flee_has_visible_threat(ctx)
        state["step_goal"] = _flee_objective(ctx, creature_pos, motor_v3) if flee_valid else Vector3.ZERO
        state["step_goal_set"] = flee_valid
        state["step_instance_id"] = 0
        state["step_source"] = &"live"
    _GkReg.GK_SHELTER:
      if refresh_targets or not has_step_goal:
        _sync_shelter_objective(ctx, state, creature_pos, motor_v3)
      elif state.get("step_source", &"") == &"explore":
        _maintain_explore_latch(ctx, state, motor_v3)
    _MotorGoalHub.GOAL_REST:
      if refresh_targets or not has_step_goal:
        if not _sync_shelter_or_rest_objective(ctx, state, creature_pos, motor_v3, goal_kind):
          _mint_explore_objective_for_goal(ctx, state, creature_pos, motor_v3, goal_kind)
      elif state.get("step_source", &"") == &"explore":
        _maintain_explore_latch(ctx, state, motor_v3)
    _:
      if refresh_targets or not has_step_goal:
        _mint_explore_objective_for_goal(ctx, state, creature_pos, motor_v3, goal_kind)
      elif state.get("step_source", &"") == &"explore":
        _maintain_explore_latch(ctx, state, motor_v3)


static func _derive_find_food_step_objective(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  scan: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> void:
  if _try_maintain_pursuit_detour_latch(ctx, state, motor_v3, scan, creature_pos):
    _store_food_inventory_step_mode(ctx, state, motor_v3)
    return
  var food := _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), creature_pos)
  if not food.is_empty():
    var body: CharacterBody3D = ctx.get("body")
    var tick_delta := float(ctx.get("delta", 1.0 / 60.0))
    # Moving prey always remints live (Pass 1); handoff scoring is for stationary food only.
    if not bool(food.get("is_moving", false)):
      var locale_candidate := _peek_locale_memory_tier_winner(
        ctx, creature_pos, motor_v3, scan
      )
      if not locale_candidate.is_empty():
        var adapter: RefCounted = ctx.get("memory_adapter")
        if not _live_vs_locale_handoff_prefers_live(
          food, locale_candidate, adapter, motor_v3
        ):
          _apply_locale_food_objective(
            ctx, state, locale_candidate, creature_pos, motor_v3, map_rid, agent_r
          )
          _store_food_inventory_step_mode(ctx, state, motor_v3)
          return
    _apply_live_food_objective(
      state, food, map_rid, creature_pos, agent_r, body, motor_v3, tick_delta
    )
    _arm_prey_engagement_from_live_food(ctx, state, food, motor_v3)
    _store_food_inventory_step_mode(ctx, state, motor_v3)
    return
  var inv_mode := _resolve_food_inventory_step_mode(ctx, motor_v3)
  if _food_inventory_mode_changed(ctx, state, motor_v3):
    _clear_explore_latch_for_remint(state)
  _store_food_inventory_step_mode(ctx, state, motor_v3)
  if _prey_engagement_latch_valid(state):
    if _sync_moving_prey_memory_objective(
      ctx, state, creature_pos, motor_v3, scan, map_rid, agent_r
    ):
      return
  var explore_first := (
    inv_mode == _FOOD_INV_UNDERSTOCKED and not _prey_engagement_latch_valid(state)
  )
  if explore_first:
    _mint_explore_objective_for_goal(ctx, state, creature_pos, motor_v3, _GkReg.GK_FIND_FOOD)
    if not bool(state.get("step_goal_set", false)):
      _sync_food_memory_objective(ctx, state, creature_pos, motor_v3, map_rid, agent_r)
  elif not _sync_food_memory_objective(ctx, state, creature_pos, motor_v3, map_rid, agent_r):
    _mint_explore_objective_for_goal(ctx, state, creature_pos, motor_v3, _GkReg.GK_FIND_FOOD)


## Calories-per-EAT v1 from live sample [code]kind_yield[/code] × reference calories.
static func _calories_per_eat_from_live_food(food: Dictionary, motor_v3: Dictionary) -> float:
  var ref := maxf(1.0, float(motor_v3.get("kind_nutrition_yield_reference_calories", 5.0)))
  var neutral := float(motor_v3.get("kind_profile_neutral_prior", 0.5))
  return float(food.get("kind_yield", neutral)) * ref


## Locale calories-per-EAT v1: kind-facet when [code]stimulus_kind_id[/code] known, else neutral prior.
static func _calories_per_eat_from_locale(
  locale: Dictionary,
  adapter: RefCounted,
  motor_v3: Dictionary,
) -> float:
  var ref := maxf(1.0, float(motor_v3.get("kind_nutrition_yield_reference_calories", 5.0)))
  var neutral := float(motor_v3.get("kind_profile_neutral_prior", 0.5))
  var kind: StringName = locale.get("stimulus_kind_id", &"")
  var yield_v := neutral
  if kind != &"" and adapter != null and adapter.has_method(&"consult_kind_facet"):
    yield_v = float(
      adapter.consult_kind_facet(_LearnReg.FACET_NUTRITION_YIELD, kind, motor_v3)
    )
  return yield_v * ref


## Resolve locale kind for handoff: consult field, or live kind when food is at the locale anchor.
static func _locale_kind_for_handoff(
  locale: Dictionary,
  live_food: Dictionary,
  motor_v3: Dictionary,
) -> StringName:
  var kind: StringName = locale.get("stimulus_kind_id", &"")
  if kind != &"":
    return kind
  var eat_max := float(motor_v3.get("eat_action_max_distance", 5.0))
  var anchor: Vector3 = locale.get("anchor", Vector3.ZERO)
  var food_pos: Vector3 = live_food.get("pos", Vector3.ZERO)
  if anchor.length_squared() > 1e-8 and food_pos.distance_to(anchor) <= eat_max:
    return live_food.get("stimulus_kind_id", &"")
  return &""


## Pass 4 C2 handoff: same [code]stimulus_kind_id[/code] → prefer live; else higher calories-per-EAT.
static func _live_vs_locale_handoff_prefers_live(
  live_food: Dictionary,
  locale: Dictionary,
  adapter: RefCounted,
  motor_v3: Dictionary,
) -> bool:
  var live_kind: StringName = live_food.get("stimulus_kind_id", &"")
  var locale_kind := _locale_kind_for_handoff(locale, live_food, motor_v3)
  if live_kind != &"" and locale_kind != &"" and live_kind == locale_kind:
    return true
  var live_cal := _calories_per_eat_from_live_food(live_food, motor_v3)
  var locale_cal := _calories_per_eat_from_locale(locale, adapter, motor_v3)
  return live_cal >= locale_cal


## True when the incumbent precise/coarse/locale [code]step_source[/code] no longer
## consults active (e.g. its belief was erased) — C6: without this, a stale
## [code]step_goal[/code] latches forever since nothing else re-triggers a tier fallback.
static func _find_food_memory_tier_stale(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  scan: Dictionary,
) -> bool:
  var step_source: StringName = state.get("step_source", &"")
  ## CLEANUP C13 (2026-08-10): a `live` step target (e.g. a just-eaten shrub now on regrow
  ## cooldown) had no staleness check of its own. Only treat it stale when the scan positively
  ## confirms our tracked instance is still visible but not consumable (`food_split.unready`) —
  ## not merely whenever the "ready" search comes up empty, which also happens for synthetic/
  ## unit-test scans (see `_test_motor_planner_eat_uses_ultimate_not_step_goal`) and for a
  ## pinned-prey EAT target that never appears in the plant-only ready/unready lists at all.
  if step_source == &"live":
    var tracked_id := int(state.get("step_instance_id", 0))
    if tracked_id == 0:
      return false
    var unready: Array = scan.get("food_split", {}).get("unready", [])
    for entry_v in unready:
      if int((entry_v as Dictionary).get("instance_id", 0)) == tracked_id:
        return true
    return false
  if step_source != &"precise" and step_source != &"coarse" and step_source != &"locale":
    return false
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return false
  var food_split: Dictionary = scan.get("food_split", {})
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  if step_source == &"precise":
    if not adapter.has_method(&"consult_precise_food"):
      return false
    var precise: Dictionary = adapter.consult_precise_food(
      creature_pos, motor_v3, food_split, now_ms
    )
    if not bool(precise.get("active", false)):
      return true
    return int(precise.get("instance_id", 0)) != int(state.get("step_instance_id", 0))
  if step_source == &"coarse":
    if not adapter.has_method(&"consult_coarse_bearing"):
      return false
    var coarse: Dictionary = adapter.consult_coarse_bearing(
      creature_pos, motor_v3, food_split, int(state.get("step_instance_id", 0)), now_ms
    )
    return not bool(coarse.get("active", false))
  if not adapter.has_method(&"consult_locale_seek"):
    return false
  var env_grid: Variant = ctx.get("environment_grid", null)
  var locale: Dictionary = adapter.consult_locale_seek(creature_pos, motor_v3, env_grid, {})
  return not bool(locale.get("active", false))


## Locale consult when precise/coarse are inactive (memory-tier winner would be locale).
static func _peek_locale_memory_tier_winner(
  ctx: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  scan: Dictionary,
) -> Dictionary:
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return {}
  var food_split: Dictionary = scan.get("food_split", {})
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  if adapter.has_method(&"consult_precise_food"):
    var precise: Dictionary = adapter.consult_precise_food(
      creature_pos, motor_v3, food_split, now_ms
    )
    if bool(precise.get("active", false)):
      return {}
  if adapter.has_method(&"consult_coarse_bearing"):
    var coarse: Dictionary = adapter.consult_coarse_bearing(
      creature_pos, motor_v3, food_split, 0, now_ms
    )
    if bool(coarse.get("active", false)):
      return {}
  if not adapter.has_method(&"consult_locale_seek"):
    return {}
  var env_grid: Variant = ctx.get("environment_grid", null)
  var locale: Dictionary = adapter.consult_locale_seek(
    creature_pos, motor_v3, env_grid, {}
  )
  if bool(locale.get("active", false)):
    return locale
  return {}


## Clears locale approach fields so orbit stops (Pass 4 arrival without consumable).
## Stamps the cleared anchor + a short cooldown (CLEANUP C2 duel-manual finding, 2026-07-17) so
## `_sync_food_memory_objective` doesn't immediately re-pick the same empty spot next tick — see
## `locale_arrival_clear_anchor` in `new_state()`.
static func _clear_locale_step_fields(state: Dictionary, motor_v3: Dictionary = {}) -> void:
  var cleared_anchor: Vector3 = state.get("step_ultimate_pos", Vector3.ZERO)
  var cleared_anchor_valid := bool(state.get("step_ultimate_pos_set", false))
  if not cleared_anchor_valid:
    cleared_anchor = state.get("step_goal", Vector3.ZERO)
    cleared_anchor_valid = bool(state.get("step_goal_set", false))
  state["step_goal"] = Vector3.ZERO
  state["step_goal_set"] = false
  state["step_ultimate_pos"] = Vector3.ZERO
  state["step_ultimate_pos_set"] = false
  state["step_instance_id"] = 0
  state["step_stimulus_kind_id"] = &""
  state["step_source"] = &""
  _reset_locale_progress_state(state)
  if cleared_anchor_valid:
    state["locale_arrival_clear_anchor"] = cleared_anchor
    state["locale_arrival_clear_anchor_set"] = true
    state["locale_arrival_clear_cooldown_ticks"] = int(
      motor_v3.get("locale_revisit_cooldown_ticks", 300)
    )


## Apply a locale memory-tier seek objective (anchor + nav substep).
static func _apply_locale_food_objective(
  ctx: Dictionary,
  state: Dictionary,
  locale: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> void:
  if state.get("step_source", &"") != &"locale":
    _reset_locale_progress_state(state)
  var anchor: Vector3 = locale.get("anchor", Vector3.ZERO)
  var resolved := _PathClear.resolve_step_objective(map_rid, creature_pos, anchor, agent_r)
  var body: CharacterBody3D = ctx.get("body")
  var tick_delta := float(ctx.get("delta", 1.0 / 60.0))
  if body != null:
    _assign_resolved_step_goal(state, body, anchor, resolved, motor_v3, tick_delta)
  else:
    state["step_goal"] = resolved
    state["step_goal_set"] = true
    state["step_ultimate_pos"] = anchor
    state["step_ultimate_pos_set"] = true
  state["step_instance_id"] = 0
  state["step_stimulus_kind_id"] = locale.get("stimulus_kind_id", &"")
  state["step_source"] = &"locale"


## At locale ultimate within eat range: bind nearby live food or clear locale orbit.
static func _maybe_locale_arrival_bind_or_clear(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  scan: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> void:
  if state.get("step_source", &"") != &"locale":
    return
  var ultimate: Vector3 = state.get("step_ultimate_pos", Vector3.ZERO)
  var ultimate_valid := bool(state.get("step_ultimate_pos_set", false))
  if not ultimate_valid:
    ultimate = state.get("step_goal", Vector3.ZERO)
    ultimate_valid = bool(state.get("step_goal_set", false))
  if not ultimate_valid:
    return
  var eat_max := float(motor_v3.get("eat_action_max_distance", 5.0))
  var d := creature_pos.distance_to(ultimate)
  if d > eat_max:
    return
  var food := _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), creature_pos)
  if not food.is_empty():
    var food_pos: Vector3 = food.get("pos", Vector3.ZERO)
    if (
      food_pos.distance_to(ultimate) <= eat_max
      or food_pos.distance_to(creature_pos) <= eat_max
    ):
      var body: CharacterBody3D = ctx.get("body")
      var tick_delta := float(ctx.get("delta", 1.0 / 60.0))
      _apply_live_food_objective(
        state, food, map_rid, creature_pos, agent_r, body, motor_v3, tick_delta
      )
      _arm_prey_engagement_from_live_food(ctx, state, food, motor_v3)
      _store_food_inventory_step_mode(ctx, state, motor_v3)
      return
  ## CLEANUP C15: record the empty arrival against this anchor's memory row (not just the
  ## short cooldown below) so a locale cell that keeps producing nothing here erodes its own
  ## rank over repeated visits — see `notify_locale_food_arrival_empty`.
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter != null and adapter.has_method(&"notify_locale_food_arrival_empty"):
    adapter.notify_locale_food_arrival_empty(ultimate, motor_v3, ctx.get("environment_grid", null))
  _clear_locale_step_fields(state, motor_v3)


static func _apply_live_food_objective(
  state: Dictionary,
  food: Dictionary,
  map_rid: RID,
  creature_pos: Vector3,
  agent_r: float,
  body: CharacterBody3D = null,
  motor_v3: Dictionary = {},
  delta: float = 1.0 / 60.0,
) -> void:
  var ultimate: Vector3 = food.get("pos", Vector3.ZERO)
  var resolved := _PathClear.resolve_step_objective(map_rid, creature_pos, ultimate, agent_r)
  var iid := int(food.get("instance_id", 0))
  var flag_material := not _is_continuous_objective_retarget(state, &"live", iid)
  if body != null:
    _assign_resolved_step_goal(state, body, ultimate, resolved, motor_v3, delta, flag_material)
  else:
    state["step_goal"] = resolved
    state["step_goal_set"] = true
    state["step_ultimate_pos"] = ultimate
    state["step_ultimate_pos_set"] = true
  state["step_instance_id"] = int(food.get("instance_id", 0))
  state["step_stimulus_kind_id"] = food.get("stimulus_kind_id", &"")
  state["step_source"] = &"live"


static func _mint_explore_objective_for_goal(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  goal_kind: StringName,
) -> void:
  state["step_goal"] = _ExploreSeek.mint_explore_step(goal_kind, creature_pos, state, motor_v3, ctx)
  state["step_goal_set"] = true
  state["step_instance_id"] = 0


## GK_SHELTER step-objective sync (CREATURE_MOVEMENT_V3.md §6.4): while not holding a bound
## candidate, opportunistically ring-probe a point ahead of facing once per consideration cycle
## (cheap — cooldown-gated on a miss); once bound and arrived, run STAY-evaluate. Falls through to
## generic explore when nothing is bound yet, matching the doc's own "candidate known? no → seek/
## explore" branch.
static func _sync_shelter_objective(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
) -> void:
  var body: CharacterBody3D = ctx.get("body")
  if state.get("step_source", &"") == &"precise" and int(state.get("shelter_candidate_instance_id", 0)) != 0:
    var anchor: Vector3 = state.get("shelter_candidate_anchor", Vector3.ZERO)
    if body != null and _at_arrival(body, anchor, motor_v3):
      _begin_or_continue_shelter_eval(ctx, state, motor_v3, anchor)
    else:
      state["shelter_eval_active"] = false
      state["shelter_eval_cycles"] = 0
    return
  if int(state.get("shelter_probe_cooldown_cycles", 0)) > 0:
    state["shelter_probe_cooldown_cycles"] = int(state["shelter_probe_cooldown_cycles"]) - 1
  elif body != null and _try_nominate_shelter_candidate(ctx, state, creature_pos, motor_v3, body):
    return
  _mint_explore_objective_for_goal(ctx, state, creature_pos, motor_v3, _GkReg.GK_SHELTER)


## Ring-probes a point [code]shelter_probe_lookahead_dist[/code] ahead of [param body]'s facing;
## binds it as a `"precise"` step objective (with a synthetic grid-cell instance id, so the
## generic blocked-approach/dead-end plumbing works for free) when enclosure clears the detect
## threshold. Returns false (and arms a retry cooldown) when nothing qualifies.
static func _try_nominate_shelter_candidate(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  body: CharacterBody3D,
) -> bool:
  var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
  if space == null:
    return false
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_FORWARD).normalized()
  var probe_center := creature_pos + facing * float(motor_v3.get("shelter_probe_lookahead_dist", 3.0))
  var probe_radius := float(motor_v3.get("shelter_enclosure_probe_radius", 2.5))
  var blocker_mask := int(motor_v3.get("shelter_enclosure_blocker_mask", 8))
  var frac := _ShelterProbe.enclosure_fraction(space, probe_center, probe_radius, blocker_mask)
  if frac < float(motor_v3.get("shelter_enclosure_detect_threshold", 0.5)):
    state["shelter_probe_cooldown_cycles"] = int(motor_v3.get("shelter_probe_retry_cooldown_cycles", 2))
    return false
  var iid := _shelter_candidate_instance_id(probe_center, motor_v3)
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter != null and adapter.has_method(&"shelter_candidate_recently_failed") and adapter.shelter_candidate_recently_failed(iid):
    state["shelter_probe_cooldown_cycles"] = int(motor_v3.get("shelter_probe_retry_cooldown_cycles", 2))
    return false
  state["shelter_candidate_anchor"] = probe_center
  state["shelter_candidate_anchor_set"] = true
  state["shelter_candidate_instance_id"] = iid
  state["step_instance_id"] = iid
  state["step_goal"] = probe_center
  state["step_goal_set"] = true
  state["step_ultimate_pos"] = probe_center
  state["step_ultimate_pos_set"] = true
  state["step_source"] = &"precise"
  state["shelter_eval_active"] = false
  state["shelter_eval_cycles"] = 0
  state["shelter_eval_total_ticks"] = 0
  return true


## Synthetic per-cell instance id for a shelter candidate anchor — reuses the same grid-cell hash
## the locale-write system dedups on, so repeated probes near the same spot collapse onto one
## belief row instead of minting a new synthetic id per centimeter of drift.
static func _shelter_candidate_instance_id(anchor: Vector3, motor_v3: Dictionary) -> int:
  var idx := _GoalSource.grid_indices_for_anchor(anchor, motor_v3)
  return hash([&"shelter_candidate", idx.x, idx.y])


## STAY-evaluate: re-probes the bound candidate every consideration cycle, accumulating consecutive
## passing cycles (mirrors `_update_safety_on_consideration`'s consecutive-cycle idiom) toward
## confirm; a run of non-passing cycles resets the streak. Gives up (fails) after
## `shelter_eval_max_cycles` total ticks without confirming.
static func _begin_or_continue_shelter_eval(
  ctx: Dictionary,
  state: Dictionary,
  motor_v3: Dictionary,
  anchor: Vector3,
) -> void:
  state["step_goal"] = anchor
  state["step_goal_set"] = true
  var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
  var probe_radius := float(motor_v3.get("shelter_enclosure_probe_radius", 2.5))
  var blocker_mask := int(motor_v3.get("shelter_enclosure_blocker_mask", 8))
  var frac := _ShelterProbe.enclosure_fraction(space, anchor, probe_radius, blocker_mask)
  state["shelter_eval_last_fraction"] = frac
  var confirm_thresh := float(motor_v3.get("shelter_enclosure_confirm_threshold", 0.65))
  state["shelter_eval_cycles"] = (
    int(state.get("shelter_eval_cycles", 0)) + 1 if frac >= confirm_thresh else 0
  )
  state["shelter_eval_active"] = true
  state["shelter_eval_total_ticks"] = int(state.get("shelter_eval_total_ticks", 0)) + 1
  var required := maxi(1, int(motor_v3.get("shelter_eval_confirm_cycles", 5)))
  var max_cycles := maxi(required, int(motor_v3.get("shelter_eval_max_cycles", 15)))
  if int(state["shelter_eval_cycles"]) >= required:
    state["shelter_eval_result"] = &"confirmed"
  elif int(state["shelter_eval_total_ticks"]) >= max_cycles:
    state["shelter_eval_result"] = &"failed"
  else:
    state["shelter_eval_result"] = &""


## CLEANUP (2026-08-26): `GOAL_REST` only ever wins arbitration once `_MotorGoalHub`'s own
## `_REST_CALORIE_FLOOR`/`safety_met` gate has already confirmed the creature is fed and safe
## (`motor_goal_hub.gd:46-47`) — unlike shelter, REST has no *site* to seek, so it never needed a
## belief consult of its own. Its only real gap was that `select_action` had nowhere to route a
## reached REST goal to the actual `MotorAction.REST` (see the new branch there) — this just holds
## the current position as the step goal so `_at_arrival` is immediately true and `select_action`
## has something to act on. (Shelter has its own real implementation — `_sync_shelter_objective` —
## above; unaffected by this.)
static func _sync_shelter_or_rest_objective(
  _ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  _motor_v3: Dictionary,
  _goal_kind: StringName,
) -> bool:
  state["step_goal"] = creature_pos
  state["step_goal_set"] = true
  state["step_instance_id"] = 0
  state["step_source"] = &"live"
  return true


static func _live_ready_food_present(scan: Dictionary, creature_pos: Vector3) -> bool:
  return not _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), creature_pos).is_empty()


static func _calorie_ratio_from_ctx(ctx: Dictionary, body: CharacterBody3D) -> float:
  if ctx.has("calorie_ratio"):
    return clampf(float(ctx.get("calorie_ratio", 1.0)), 0.0, 1.0)
  if body == null:
    return 1.0
  var cap := maxf(1.0, float(body.get("caloric_needs")))
  return clampf(float(body.get("current_calories")) / cap, 0.0, 1.0)


static func _known_food_count(ctx: Dictionary, motor_v3: Dictionary, creature_pos: Vector3) -> float:
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null or not adapter.has_method(&"count_known_objectives"):
    return 0.0
  var scan: Dictionary = ctx.get("scan", {})
  var food_split: Dictionary = scan.get("food_split", {})
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  return float(
    adapter.count_known_objectives(
      _GkReg.GK_FIND_FOOD, creature_pos, motor_v3, food_split, now_ms
    )
  )


static func _resolve_food_inventory_step_mode(ctx: Dictionary, motor_v3: Dictionary) -> int:
  var body: CharacterBody3D = ctx.get("body")
  var calorie_ratio := _calorie_ratio_from_ctx(ctx, body)
  var urgency_eat := _MotorGoalHub.urgency_eat(calorie_ratio, motor_v3)
  var seek_ceil := float(motor_v3.get("seek_priority_food_ceiling", 0.80))
  if urgency_eat >= seek_ceil - 1e-6:
    return _FOOD_INV_HUNGRY
  var creature_pos := body.global_position if body != null else Vector3.ZERO
  var known := _known_food_count(ctx, motor_v3, creature_pos)
  var min_inv := float(motor_v3.get("goal_inventory_min_find_food", 3.0))
  if known >= min_inv - 1e-6:
    return _FOOD_INV_STOCKED
  return _FOOD_INV_UNDERSTOCKED


static func _store_food_inventory_step_mode(ctx: Dictionary, state: Dictionary, motor_v3: Dictionary) -> void:
  state["food_inventory_step_mode"] = _resolve_food_inventory_step_mode(ctx, motor_v3)


static func _food_inventory_mode_changed(ctx: Dictionary, state: Dictionary, motor_v3: Dictionary) -> bool:
  var prev := int(state.get("food_inventory_step_mode", -1))
  if prev < 0:
    return false
  return prev != _resolve_food_inventory_step_mode(ctx, motor_v3)


static func _clear_explore_latch_for_remint(state: Dictionary) -> void:
  state["explore_dir"] = Vector3.ZERO
  state["explore_waypoint"] = Vector3.ZERO
  state["explore_waypoint_set"] = false
  _reset_explore_align_progress_state(state)


static func _prey_engagement_latch_valid(state: Dictionary) -> bool:
  return (
    int(state.get("prey_engagement_instance_id", 0)) != 0
    and int(state.get("prey_engagement_ticks_remaining", 0)) > 0
  )


static func _pursuit_detour_latch_valid(state: Dictionary) -> bool:
  return (
    _LatchHold.is_active(state, "pursuit_detour")
    and bool(state.get("pursuit_detour_waypoint_set", false))
  )


static func _clear_pursuit_detour_latch(state: Dictionary) -> void:
  state["pursuit_detour_waypoint"] = Vector3.ZERO
  state["pursuit_detour_waypoint_set"] = false
  state["pursuit_detour_alt_flip"] = false
  _LatchHold.clear(state, "pursuit_detour")


## Live prey refresh without overwriting an active pursuit detour substep (C1 residual).
static func _refresh_live_prey_meta_only(
  ctx: Dictionary,
  state: Dictionary,
  food: Dictionary,
  motor_v3: Dictionary,
) -> void:
  state["step_ultimate_pos"] = food.get("pos", Vector3.ZERO)
  state["step_ultimate_pos_set"] = true
  state["step_instance_id"] = int(food.get("instance_id", 0))
  state["step_stimulus_kind_id"] = food.get("stimulus_kind_id", &"")
  _arm_prey_engagement_from_live_food(ctx, state, food, motor_v3)


## §9 pre-call gate (C1): skip persist/switch/seek while live prey visible + engagement latch.
static func should_suppress_live_pursuit_blocked_resolution(
  ctx: Dictionary,
  state: Dictionary,
) -> bool:
  if not _prey_engagement_latch_valid(state):
    return false
  var body: CharacterBody3D = ctx.get("body")
  if body == null:
    return false
  var scan: Dictionary = ctx.get("scan", {})
  return _live_ready_food_present(scan, body.global_position)


## Hold post-blocked-reeval detour substep during live prey pursuit (post-6d-approach-geometry C1).
static func _try_maintain_pursuit_detour_latch(
  ctx: Dictionary,
  state: Dictionary,
  motor_v3: Dictionary,
  scan: Dictionary,
  creature_pos: Vector3,
) -> bool:
  if not _pursuit_detour_latch_valid(state):
    return false
  if not _prey_engagement_latch_valid(state):
    _clear_pursuit_detour_latch(state)
    return false
  var latched: Vector3 = state.get("pursuit_detour_waypoint", Vector3.ZERO)
  state["step_goal"] = latched
  state["step_goal_set"] = true
  state["step_source"] = &"live"
  _LatchHold.decrement(state, "pursuit_detour")
  var food := _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), creature_pos)
  if not food.is_empty():
    state["step_ultimate_pos"] = food.get("pos", Vector3.ZERO)
    state["step_ultimate_pos_set"] = true
    state["step_instance_id"] = int(food.get("instance_id", 0))
    state["step_stimulus_kind_id"] = food.get("stimulus_kind_id", &"")
    _arm_prey_engagement_from_live_food(ctx, state, food, motor_v3)
  return true


static func _maybe_mint_pursuit_detour_latch(
  ctx: Dictionary,
  state: Dictionary,
  motor_v3: Dictionary,
) -> void:
  if not _prey_engagement_latch_valid(state):
    return
  if state.get("step_source", &"") != &"live":
    return
  var body: CharacterBody3D = ctx.get("body")
  if body == null:
    return
  var scan: Dictionary = ctx.get("scan", {})
  if not _live_ready_food_present(scan, body.global_position):
    return
  if not bool(state.get("step_goal_set", false)):
    return
  var wp: Vector3 = state.get("step_goal", Vector3.ZERO)
  var latch_ticks := maxi(1, int(motor_v3.get("pursuit_detour_latch_ticks", 32)))
  state["pursuit_detour_waypoint"] = wp
  state["pursuit_detour_waypoint_set"] = true
  state["step_goal"] = wp
  state["step_goal_set"] = true
  _LatchHold.start(state, "pursuit_detour", latch_ticks)
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  var food := _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), body.global_position)
  if not food.is_empty():
    state["step_ultimate_pos"] = food.get("pos", Vector3.ZERO)
    state["step_ultimate_pos_set"] = true


## Mint a fresh pursuit detour on the opposite side after persistent block (C1 residual).
static func _remint_alternate_pursuit_detour(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  # CLEANUP C9 follow-up (2026-08-05, boundary-ping-pong root cause): alternating +-60 deg tries
  # "the other side" of a blocked detour, but near a boundary/corner both sides can be equally
  # blocked, so this alone just flips between two dead-end waypoints forever (confirmed live via
  # forced-repro capture — `cblk` cycling 0-1-2-0 with `tgt` alternating between exactly 2 points,
  # `dist` pinned at this function's `maxf(dist, 3.0)` floor). After both sides have been tried
  # once (escalation 1 then 2) and blocked again, give up on detouring around this waypoint and
  # clear the latch so `_derive_find_food_step_objective` falls through to a full fresh
  # `_apply_live_food_objective` recompute next tick, using the prey's actual current position
  # instead of another blind bearing rotation.
  var max_escalations := int(motor_v3.get("pursuit_detour_max_escalations", 2))
  var escalation_result := _LatchHold.escalate(state, "pursuit_detour", max_escalations)
  if bool(escalation_result.get("gave_up", false)):
    _clear_pursuit_detour_latch(state)
    state["consecutive_blocked"] = 0
    return
  var creature_pos := body.global_position
  if not bool(state.get("step_ultimate_pos_set", false)):
    return
  var ultimate: Vector3 = state.get("step_ultimate_pos", Vector3.ZERO)
  var latched: Vector3 = state.get("pursuit_detour_waypoint", Vector3.ZERO)
  var to_latched := Vector3(latched.x - creature_pos.x, 0.0, latched.z - creature_pos.z)
  var dist := to_latched.length()
  if dist < 1e-6:
    to_latched = Vector3(ultimate.x - creature_pos.x, 0.0, ultimate.z - creature_pos.z)
    dist = to_latched.length()
  if dist < 1e-6:
    return
  var dir := to_latched.normalized()
  var alt_sign := -1.0 if bool(state.get("pursuit_detour_alt_flip", false)) else 1.0
  state["pursuit_detour_alt_flip"] = not bool(state.get("pursuit_detour_alt_flip", false))
  dir = dir.rotated(Vector3.UP, deg_to_rad(60.0 * alt_sign))
  var wp := creature_pos + dir * maxf(dist, 3.0)
  var map_rid: RID = ctx.get("map_rid", RID())
  var agent_r := _agent_radius(body)
  wp = _PathClear.resolve_step_objective(map_rid, creature_pos, wp, agent_r)
  var latch_ticks := maxi(1, int(motor_v3.get("pursuit_detour_latch_ticks", 32)))
  state["pursuit_detour_waypoint"] = wp
  state["pursuit_detour_waypoint_set"] = true
  state["step_goal"] = wp
  state["step_goal_set"] = true
  state["pursuit_detour_ticks_remaining"] = latch_ticks
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  state["force_align_turn_before_move"] = true
  var scan: Dictionary = ctx.get("scan", {})
  var food := _AwarenessScan.best_ready_food_target(scan.get("food_split", {}), creature_pos)
  if not food.is_empty():
    state["step_ultimate_pos"] = food.get("pos", Vector3.ZERO)
    state["step_ultimate_pos_set"] = true


static func _clear_prey_engagement(state: Dictionary) -> void:
  state["prey_engagement_instance_id"] = 0
  state["prey_engagement_ticks_remaining"] = 0
  state["prey_engagement_latch_total"] = 0


static func _effective_prey_engagement_latch_ticks(ctx: Dictionary, motor_v3: Dictionary) -> int:
  var traits: Dictionary = ctx.get("traits", {})
  var change_stability := float(traits.get("change_stability", 0.0))
  var t := clampf((change_stability + 100.0) / 200.0, 0.0, 1.0)
  var scale_min := float(motor_v3.get("predator_prey_engagement_latch_scale_min", 0.5))
  var scale_max := float(motor_v3.get("predator_prey_engagement_latch_scale_max", 1.5))
  var base_ticks := float(motor_v3.get("predator_prey_engagement_latch_base_ticks", 40.0))
  var ticks_min := int(
    motor_v3.get(
      "predator_prey_engagement_latch_ticks_min",
      motor_v3.get("goal_replan_base_ticks", 8),
    )
  )
  var ticks_max := int(motor_v3.get("predator_prey_engagement_latch_ticks_max", 120))
  var scaled := roundi(base_ticks * lerpf(scale_min, scale_max, t))
  return clampi(scaled, ticks_min, ticks_max)


static func _arm_prey_engagement_from_live_food(
  ctx: Dictionary,
  state: Dictionary,
  food: Dictionary,
  motor_v3: Dictionary,
) -> void:
  if not bool(food.get("is_moving", false)):
    return
  var iid := int(food.get("instance_id", 0))
  if iid == 0:
    return
  var effective := _effective_prey_engagement_latch_ticks(ctx, motor_v3)
  state["prey_engagement_instance_id"] = iid
  state["prey_engagement_ticks_remaining"] = effective
  state["prey_engagement_latch_total"] = effective


static func _live_food_instance_visible(scan: Dictionary, instance_id: int) -> bool:
  if instance_id == 0:
    return false
  var ready: Array = scan.get("food_split", {}).get("ready", [])
  for entry_v in ready:
    if typeof(entry_v) != TYPE_DICTIONARY:
      continue
    if int((entry_v as Dictionary).get("instance_id", 0)) == instance_id:
      return true
  return false


static func _tick_prey_engagement_latch(ctx: Dictionary, state: Dictionary) -> void:
  if not _prey_engagement_latch_valid(state):
    return
  var scan: Dictionary = ctx.get("scan", {})
  var iid := int(state.get("prey_engagement_instance_id", 0))
  if _live_food_instance_visible(scan, iid):
    return
  var rem := int(state.get("prey_engagement_ticks_remaining", 0)) - 1
  state["prey_engagement_ticks_remaining"] = rem
  if rem <= 0:
    _clear_prey_engagement(state)


static func _sync_moving_prey_memory_objective(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  scan: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> bool:
  if not _prey_engagement_latch_valid(state):
    return false
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null or not adapter.has_method(&"consult_moving_prey_food"):
    return false
  var food_split: Dictionary = scan.get("food_split", {})
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  var consult_ctx := {
    "flight_fast_path_active": bool(ctx.get("flight_fast_path_active", false)),
    "threat_samples": ctx.get("threat_samples", scan.get("threat_samples", [])),
  }
  var moving: Dictionary = adapter.consult_moving_prey_food(
    int(state.get("prey_engagement_instance_id", 0)),
    creature_pos,
    motor_v3,
    food_split,
    now_ms,
    consult_ctx,
  )
  if not bool(moving.get("active", false)):
    return false
  var new_iid := int(moving.get("instance_id", 0))
  if int(state.get("step_instance_id", 0)) != new_iid:
    _reset_precise_progress_state(state)
  var ultimate: Vector3 = moving.get("pos", Vector3.ZERO)
  var resolved := _PathClear.resolve_step_objective(map_rid, creature_pos, ultimate, agent_r)
  var body: CharacterBody3D = ctx.get("body")
  var tick_delta := float(ctx.get("delta", 1.0 / 60.0))
  var flag_material := not _is_continuous_objective_retarget(state, &"memory_moving", new_iid)
  if body != null:
    _assign_resolved_step_goal(state, body, ultimate, resolved, motor_v3, tick_delta, flag_material)
  else:
    state["step_goal"] = resolved
    state["step_goal_set"] = true
    state["step_ultimate_pos"] = ultimate
    state["step_ultimate_pos_set"] = true
  state["step_instance_id"] = new_iid
  state["step_stimulus_kind_id"] = moving.get("stimulus_kind_id", &"")
  state["step_source"] = &"memory_moving"
  return true


## Overshoot / rim / dead-end maintenance on a held explore latch (runs between consideration ticks).
static func _maintain_explore_latch(
  ctx: Dictionary,
  state: Dictionary,
  motor_v3: Dictionary,
) -> void:
  var body: CharacterBody3D = ctx.get("body")
  if body == null:
    return
  var creature_pos := body.global_position
  if not bool(state.get("explore_waypoint_set", false)):
    return
  var latched: Vector3 = state.get("explore_waypoint", Vector3.ZERO)
  var arrival_tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  if creature_pos.distance_to(latched) <= arrival_tol:
    state["explore_waypoint"] = Vector3.ZERO
    state["explore_waypoint_set"] = false
    state["step_goal"] = Vector3.ZERO
    state["step_goal_set"] = false
    return
  if _passed_explore_waypoint(body, latched, state):
    _apply_explore_waypoint_passed(state, body, motor_v3)
    return
  if _explore_latch_needs_rim_realign(body, motor_v3, state):
    _apply_explore_rim_escape_replan(state, body, motor_v3)
    return
  var adapter_hold: RefCounted = ctx.get("memory_adapter")
  var latch_goal_kind: StringName = state.get("goal_kind", _GkReg.GK_FIND_FOOD)
  if adapter_hold != null and adapter_hold.has_method(&"is_waypoint_dead_end"):
    if adapter_hold.is_waypoint_dead_end(creature_pos, latched, latch_goal_kind, motor_v3):
      if _is_near_playfield_boundary(body, motor_v3):
        state["explore_dir"] = _rim_escape_explore_dir(body, motor_v3)
      else:
        var explore: Vector3 = state.get("explore_dir", Vector3.ZERO)
        if explore.length_squared() < 1e-8:
          explore = _MotorPlane.HORIZONTAL_FORWARD
        state["explore_dir"] = explore.rotated(Vector3.UP, deg_to_rad(60.0)).normalized()
      state["explore_waypoint"] = Vector3.ZERO
      state["explore_waypoint_set"] = false
      state["step_goal"] = Vector3.ZERO
      state["step_goal_set"] = false
      return
  state["step_goal"] = latched
  state["step_goal_set"] = true


static func _sync_food_memory_objective(
  ctx: Dictionary,
  state: Dictionary,
  creature_pos: Vector3,
  motor_v3: Dictionary,
  map_rid: RID,
  agent_r: float,
) -> bool:
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return false
  var scan: Dictionary = ctx.get("scan", {})
  var food_split: Dictionary = scan.get("food_split", {})
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  var env_grid: Variant = ctx.get("environment_grid", null)
  var motor_ctx: Dictionary = {}
  var body: CharacterBody3D = ctx.get("body")
  var tick_delta := float(ctx.get("delta", 1.0 / 60.0))
  var precise: Dictionary = adapter.consult_precise_food(creature_pos, motor_v3, food_split, now_ms)
  if bool(precise.get("active", false)):
    var new_iid := int(precise.get("instance_id", 0))
    if int(state.get("step_instance_id", 0)) != new_iid:
      _reset_precise_progress_state(state)
    var precise_pos: Vector3 = precise.get("pos", Vector3.ZERO)
    if body != null:
      _assign_resolved_step_goal(state, body, precise_pos, precise_pos, motor_v3, tick_delta)
    else:
      state["step_goal"] = precise_pos
      state["step_goal_set"] = true
      state["step_ultimate_pos"] = precise_pos
      state["step_ultimate_pos_set"] = true
    state["step_instance_id"] = new_iid
    state["step_stimulus_kind_id"] = precise.get("stimulus_kind_id", &"")
    state["step_source"] = &"precise"
    return true
  var incumbent_iid := int(state.get("step_instance_id", 0))
  var coarse: Dictionary = adapter.consult_coarse_bearing(
    creature_pos, motor_v3, food_split, incumbent_iid, now_ms
  )
  if bool(coarse.get("active", false)):
    var reach := float(motor_v3.get("awareness_radius", 150.0)) * 0.5
    var bearing: Vector3 = coarse.get("bearing", Vector3.ZERO)
    state["step_goal"] = creature_pos + bearing.normalized() * reach
    state["step_goal_set"] = true
    state["step_instance_id"] = int(coarse.get("instance_id", 0))
    state["step_source"] = &"coarse"
    return true
  var locale: Dictionary = adapter.consult_locale_seek(creature_pos, motor_v3, env_grid, motor_ctx)
  var on_cd := _locale_anchor_on_arrival_cooldown(state, locale.get("anchor", Vector3.ZERO))
  if bool(locale.get("active", false)) and not on_cd:
    _apply_locale_food_objective(ctx, state, locale, creature_pos, motor_v3, map_rid, agent_r)
    return true
  return false


## True when [param anchor] matches the locale spot just cleared by an empty arrival and its
## cooldown hasn't expired yet — prevents immediately re-picking a point the creature is already
## standing on (degenerate bearing math -> in-place turn-storm; CLEANUP C2, 2026-07-17).
static func _locale_anchor_on_arrival_cooldown(state: Dictionary, anchor: Vector3) -> bool:
  if int(state.get("locale_arrival_clear_cooldown_ticks", 0)) <= 0:
    return false
  var cleared: Vector3 = state.get("locale_arrival_clear_anchor", Vector3.ZERO)
  return cleared.distance_squared_to(anchor) < 1.0


## Clears acute Flight flee latch (stack calls on [code]ff=0[/code] episode exit).
static func clear_flee_waypoint_latch(state: Dictionary) -> void:
  state["flee_waypoint"] = Vector3.ZERO
  state["flee_waypoint_set"] = false
  _LatchHold.clear(state, "flee_waypoint")
  state["flee_backtrack_streak"] = 0
  state["flee_recent_dirs"] = []
  state["flee_give_up_active"] = false


## P3 — drop stale non-Flight objective fields on first [code]ff=1[/code] tick (§12.2 post-6d).
static func _reset_flight_entry_telemetry(state: Dictionary) -> void:
  state["step_instance_id"] = 0
  state["step_stimulus_kind_id"] = &""
  state["blocked_objective_action"] = &""
  state["consecutive_blocked"] = 0
  state["los_blocked_latched"] = false
  state["los_verdict_streak"] = 0
  state["boundary_scan_active"] = false
  state["boundary_scan_sign"] = 0


## Real reachable distance and endpoint toward [code]creature_pos + dir * dist[/code], per the
## navmesh — clamped short of the requested distance when geometry blocks the way (CLEANUP C9,
## 2026-08-06: a candidate-scoring signal for [method _mint_flee_waypoint] so bearing selection can
## tell "open" from "corner" instead of reasoning about direction alone). Falls back to the full
## requested distance when no navmesh map is available (e.g. synthetic headless fixtures with no
## baked nav).
## CLEANUP C17 (2026-08-12): previously returned only the straight-line distance to the navmesh
## path's last point (`reach`) while discarding the endpoint itself — callers then re-derived a
## waypoint by walking straight in `dir` for that many units. Near a boundary corner, the queried
## `NavigationServer3D.map_get_path` snaps an off-navmesh candidate to the nearest *reachable* point,
## which the path may only reach by bending around the corner — the straight-line distance to that
## snapped point can read close to the full requested `dist` even though a straight cast in `dir`
## walks off the navmesh partway there. That mismatch let flee-waypoint scoring rate a direction as
## "clear" while the resulting straight-line waypoint still hit the boundary, cycling through the
## same handful of equally-miscalibrated candidates (confirmed live: rabbit fleeing near the west
## wall spun/re-minted between 3 fixed waypoints for ~2s before finding a real opening). Returning
## the actual path endpoint alongside `reach` lets callers target where the navmesh really goes
## instead of re-deriving a straight-line point that ignores the bend.
static func _flee_candidate_probe(
  map_rid: RID,
  creature_pos: Vector3,
  dir: Vector3,
  dist: float,
) -> Dictionary:
  if not map_rid.is_valid() or dist <= 0.0:
    return {"reach": dist, "endpoint": creature_pos + dir * dist}
  var candidate := creature_pos + dir * dist
  var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, creature_pos, candidate, true)
  if path.size() < 2:
    return {"reach": 0.0, "endpoint": creature_pos}
  var endpoint: Vector3 = path[path.size() - 1]
  return {"reach": creature_pos.distance_to(endpoint), "endpoint": endpoint}


## True when at least one [code]threat_samples[/code] entry is currently [code]in_awareness[/code].
## [method _flee_objective] has no meaningful answer without one (returns [code]Vector3.ZERO[/code]
## as a "no threat" sentinel) — callers must check this directly rather than trust that return
## value, since [code]Vector3.ZERO[/code] is also a valid world position (CLEANUP C9, 2026-08-07).
static func _flee_has_visible_threat(ctx: Dictionary) -> bool:
  for sample_v in ctx.get("threat_samples", []):
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    if bool((sample_v as Dictionary).get("in_awareness", false)):
      return true
  return false


static func _mint_flee_waypoint(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> Vector3:
  var creature_pos := body.global_position
  if not _flee_has_visible_threat(ctx):
    # CLEANUP C9 (2026-08-07): the raw per-tick `in_awareness` LoS check (awareness_zone.gd,
    # unlike path-clearance LoS it has no hysteresis) can flicker false for a tick near corner
    # geometry — exactly where flee is most likely to be re-minting — even while
    # `_flight_fast_path_active` stays latched true (it doesn't require a fresh acute threat every
    # tick). When that flicker lands on the tick the flee latch expires, minting from
    # `_flee_objective`'s `Vector3.ZERO` "no threat" sentinel previously produced a nonsense
    # waypoint literally targeting the world origin (found via the give-up escalation's tick-927
    # headless trip — the escalation didn't cause this, it just searched hard enough to land on
    # it). A real animal that loses sight of a predator for a moment keeps running the way it was
    # already going, it doesn't reroute toward a fixed point — hold the existing latched waypoint.
    var prior: Vector3 = state.get("flee_waypoint", Vector3.ZERO)
    if bool(state.get("flee_waypoint_set", false)):
      _LatchHold.start(state, "flee_waypoint", maxi(1, int(motor_v3.get("flee_waypoint_latch_ticks", 16))))
      return prior
    # No prior waypoint to hold (Flight entry with no live threat this exact tick — shouldn't
    # normally happen since entry requires an acute threat, but stay defensive): fall back to
    # spawn-facing, matching `_flee_objective`'s own co-located-threat fallback below.
    # CLEANUP C16 (2026-08-12): unlike the main candidate-scored mint path below, this branch has no
    # threat position to compute an "away" bearing from at all — `HORIZONTAL_FORWARD` is a fixed
    # compass direction with zero awareness of nearby geometry, so it can (and did, live: a rabbit
    # spawned 10 units off the map edge) point straight at a wall. Clamp to the direction's own
    # measured reach same as the main path, so this bootstrapping-only fallback can't overshoot past
    # the map edge either; a reach of 0 just holds position for this one tick until the next
    # reconsideration has real threat data to steer by.
    var fallback_dist := float(motor_v3.get("awareness_radius", 150.0))
    var fallback_probe := _flee_candidate_probe(
      ctx.get("map_rid", RID()), creature_pos, _MotorPlane.HORIZONTAL_FORWARD, fallback_dist,
    )
    var fallback_wp: Vector3 = fallback_probe.get("endpoint", creature_pos)
    state["flee_waypoint"] = fallback_wp
    state["flee_waypoint_set"] = true
    _LatchHold.start(state, "flee_waypoint", maxi(1, int(motor_v3.get("flee_waypoint_latch_ticks", 16))))
    state["flee_backtrack_streak"] = 0
    return fallback_wp

  var wp := _flee_objective(ctx, creature_pos, motor_v3)
  var to_wp := Vector3(wp.x - creature_pos.x, 0.0, wp.z - creature_pos.z)
  var physics_tick := int(ctx.get("physics_tick", 0))
  var backtrack_dot := float(motor_v3.get("blocked_approach_backtrack_dot", 0.55))
  var history: Array = []
  for entry_v in state.get("flee_recent_dirs", []):
    if typeof(entry_v) != TYPE_DICTIONARY:
      continue
    var entry: Dictionary = entry_v
    if physics_tick < int(entry.get("until_tick", 0)):
      history.append(entry)
  # CLEANUP C9 follow-up (2026-08-05 -> 2026-08-06, boundary-ping-pong root cause, 3rd pass):
  # rotating a fixed +60° away from only the single most-recently-blocked direction produced an
  # exact 2-point limit cycle when cornered (confirmed live + headless, see
  # CREATURE_MOVEMENT_V3_CLEANUP.md C9): mint N gets flagged as a backtrack vs the direction it
  # was just physically blocked walking and rotates +60°; mint N+1's raw re-derived bearing
  # (`_flee_objective` has no obstacle awareness, so it's ~unchanged while cornered) is only 60°
  # off *that* rotated escape — dot(60°) = 0.5, just under the 0.55 backtrack threshold — so it
  # reads as clear and un-rotates straight back to the original blocked bearing. The single-slot
  # `blocked_approach` memory has no way to remember "the rotated direction was *also* tried and
  # failed" once a later block overwrites it. Checking against a short rolling history of this
  # Flight episode's last few minted directions (4th pass, still 2026-08-06) closed the exact
  # resonance, but headless re-verification showed it just cycles a *wider* set of equally bad
  # nearby points near a real corner — zero net progress, invariant still trips — because bearing
  # rotation alone never asks whether a candidate direction actually leads anywhere open. Fix
  # (5th pass): score each of 6 candidate bearings (60° apart) by how far the navmesh actually
  # lets the creature travel toward it — same `NavigationServer3D.map_get_path` primitive
  # `_remint_alternate_pursuit_detour` already uses for C1 — and pick the best-reaching candidate
  # that isn't a recent-history backtrack, falling back to the best-reaching candidate overall if
  # every one collides with history.
  state["flee_give_up_active"] = false
  if to_wp.length_squared() > 1e-8:
    var avoid_dirs: Array = []
    var blocked_dir := _BlockedApproach.active_dir(
      state.get("blocked_approach", {}),
      physics_tick,
    )
    if blocked_dir.length_squared() > 1e-12:
      avoid_dirs.append(blocked_dir)
    for entry_v in history:
      avoid_dirs.append((entry_v as Dictionary).get("dir", Vector3.ZERO))

    var map_rid: RID = ctx.get("map_rid", RID())
    var base_dir := to_wp.normalized()
    var flee_dist := to_wp.length()

    # RANDOMTESTS RT4 Slice 2 (2026-08-26): bias candidate selection toward a confirmed shelter
    # belief, when one is known and roughly in range, on top of the pure reach-scoring below.
    # `consult_shelter_beliefs` already picks the *nearest* confirmed shelter across all belief
    # rows, so multi-shelter selection is handled upstream — this only ever sees a single
    # candidate. The bonus is added as a 7th candidate direction, scaled down linearly with
    # distance (near-full bonus close by, near-zero approaching `goal_memory_forget_radius_shelter`)
    # so a known-but-distant shelter can't out-compete much-closer open ground. Deliberately doesn't
    # touch `best_reach`/`final_reach` themselves (tracked separately as the true, unbiased reach)
    # so the give-up escalation and `reach_known` boxed-in handling below stay exactly as tuned by
    # RT1/C9/C16/C17 — the bonus only ever influences *which* direction wins, never whether the
    # creature is treated as cornered.
    var shelter_dir := Vector3.ZERO
    var shelter_bias_reach := 0.0
    var shelter_active := false
    var adapter: RefCounted = ctx.get("memory_adapter")
    if adapter != null and adapter.has_method(&"consult_shelter_beliefs"):
      var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
      var shelter: Dictionary = adapter.consult_shelter_beliefs(creature_pos, motor_v3, now_ms)
      if bool(shelter.get("active", false)):
        var shelter_pos: Vector3 = shelter.get("pos", Vector3.ZERO)
        var to_shelter := Vector3(shelter_pos.x - creature_pos.x, 0.0, shelter_pos.z - creature_pos.z)
        var shelter_dist := to_shelter.length()
        if shelter_dist > 1e-6:
          shelter_dir = to_shelter / shelter_dist
          var forget_r := float(motor_v3.get("goal_memory_forget_radius_shelter", motor_v3.get("goal_memory_forget_radius", 2400.0)))
          var proximity := 1.0 - clampf(shelter_dist / maxf(forget_r, 1.0), 0.0, 1.0)
          var bonus_frac := float(motor_v3.get("flee_shelter_bias_bonus", 0.15)) * proximity
          shelter_bias_reach = flee_dist * bonus_frac
          shelter_active = true

    var candidate_dirs: Array = []
    for i in range(6):
      candidate_dirs.append(base_dir.rotated(Vector3.UP, deg_to_rad(60.0 * i)))
    if shelter_active:
      candidate_dirs.append(shelter_dir)

    var best_dir := base_dir
    var best_reach := -1.0
    var best_effective := -1.0
    var best_endpoint := creature_pos
    var best_clear_dir := Vector3.ZERO
    var best_clear_reach := -1.0
    var best_clear_effective := -1.0
    var best_clear_endpoint := creature_pos
    var found_clear := false
    for i in range(candidate_dirs.size()):
      var candidate_dir: Vector3 = candidate_dirs[i]
      var probe := _flee_candidate_probe(map_rid, creature_pos, candidate_dir, flee_dist)
      var reach := float(probe.get("reach", 0.0))
      var endpoint: Vector3 = probe.get("endpoint", creature_pos)
      var is_shelter_candidate := shelter_active and i == candidate_dirs.size() - 1
      var effective := reach + (shelter_bias_reach if is_shelter_candidate else 0.0)
      if effective > best_effective:
        best_effective = effective
        best_reach = reach
        best_dir = candidate_dir
        best_endpoint = endpoint
      var avoided := false
      for avoid_v in avoid_dirs:
        if _BlockedApproach.is_backtrack_step(candidate_dir, avoid_v as Vector3, backtrack_dot):
          avoided = true
          break
      if not avoided and effective > best_clear_effective:
        best_clear_effective = effective
        best_clear_reach = reach
        best_clear_dir = candidate_dir
        best_clear_endpoint = endpoint
        found_clear = true
    var final_dir := best_clear_dir if found_clear else best_dir
    var final_reach := best_clear_reach if found_clear else best_reach
    var final_endpoint := best_clear_endpoint if found_clear else best_endpoint

    # CLEANUP C9 give-up escalation (2026-08-07): the 6-candidate sweep above only samples every
    # 60° — in a genuine corner none of those 6 may reach anywhere close to `flee_dist`, but a
    # real gap can still exist between them (a narrow opening the coarse spacing straddled). A
    # cornered animal doesn't keep carefully weighing "away from the predator" once every careful
    # option has come up bad — it takes the first real opening it finds, full stop. Escalate to a
    # much finer full-circle sweep, and — unlike the sweep above — don't filter by recent-backtrack
    # history at all: a direction that was blocked a moment ago and is now the only way out is
    # still the only way out.
    var give_up_reach_frac := float(motor_v3.get("flee_give_up_reach_frac", 0.35))
    if final_reach < flee_dist * give_up_reach_frac:
      var scan_n := maxi(1, int(motor_v3.get("flee_give_up_scan_directions", 16)))
      var scan_best_dir := final_dir
      var scan_best_reach := final_reach
      var scan_best_endpoint := final_endpoint
      for i in range(scan_n):
        var ang := TAU * float(i) / float(scan_n)
        var candidate_dir: Vector3 = base_dir.rotated(Vector3.UP, ang)
        var probe := _flee_candidate_probe(map_rid, creature_pos, candidate_dir, flee_dist)
        var reach := float(probe.get("reach", 0.0))
        if reach > scan_best_reach:
          scan_best_reach = reach
          scan_best_dir = candidate_dir
          scan_best_endpoint = probe.get("endpoint", creature_pos)
      if scan_best_reach > final_reach:
        final_dir = scan_best_dir
        state["flee_give_up_active"] = true
        final_reach = scan_best_reach
        final_endpoint = scan_best_endpoint

    # CLEANUP RANDOMTESTS RT1 (2026-08-10): both scans above score every candidate purely by
    # navmesh reach — when the creature is near/past the edge of the baked navmesh (confirmed via
    # instrumented repro: near the playfield boundary, not a steep-terrain bake gap), reach comes
    # back `0.0` in literally every direction, including the 16-way escalation. With no usable
    # signal, `best_dir`/`best_clear_dir` silently default to whichever candidate's loop iteration
    # happened to run first — a fixed 60°-rotation order, not a real choice — which swung the
    # picked bearing nearly 180° between consecutive re-mints in the live repro (a valley-facing
    # rabbit "fled" back toward its own dead end just as often as toward the real exit). When every
    # candidate is equally uninformative, prefer holding the previous flee heading (at least
    # consistent, not thrashing) over re-rolling an arbitrary new one; fall back to the raw
    # straight-away-from-threat `base_dir` only when there's no prior waypoint yet to hold.
    var reach_known := true
    if final_reach <= 0.0:
      # No usable reach signal in any of the 22 tested directions — genuinely boxed in, not just
      # limited. Hold a stable heading (as before), but explicitly don't trust a reach value for it
      # (see the travel-distance note below): re-measuring here would legitimately come back ~0 too,
      # and projecting the waypoint that close collapses the bearing math to noise.
      reach_known = false
      final_dir = base_dir
      if bool(state.get("flee_waypoint_set", false)):
        var prior_wp: Vector3 = state.get("flee_waypoint", Vector3.ZERO)
        var prior_dir := prior_wp - creature_pos
        prior_dir.y = 0.0
        if prior_dir.length_squared() > 1e-8:
          final_dir = prior_dir.normalized()

    # CLEANUP C16 (2026-08-12): every branch above already scores candidate bearings by how far the
    # navmesh actually lets the creature travel (`_flee_candidate_probe`) — including preferring a
    # roughly wall-parallel bearing over "straight away" once straight-away scores near-zero reach,
    # since a wall-hugging direction travels much farther before hitting anything. But the waypoint
    # itself used to always land the full requested `flee_dist` out regardless of that measured
    # reach, so a correctly-chosen direction could still project a target past where the creature
    # could actually go — confirmed live: a rabbit spawned 10 units off the map edge minted a flee
    # waypoint ~6 units past the boundary, then spent several real seconds fighting the wall
    # (repeated boundary-scan/backtrack) before it found the real opening, while the predator closed
    # distance uncontested. Use the winning candidate's own measured navmesh endpoint (`final_endpoint`)
    # as the waypoint directly rather than re-deriving a straight-line point from direction × distance
    # — but only when a real (positive) reach was actually measured for it (`reach_known`); see CLEANUP
    # C17 above for why a straight-line re-derivation from a bent-path reach was still wrong. Applying
    # this to the "nothing reachable anywhere" fallback below instead collapsed the waypoint to ~0
    # distance from the creature's own position, which is functionally "flee to here I already am" —
    # the bearing to a near-zero-distance target is dominated by floating-point noise tick to tick,
    # which is exactly the spinning/thrashing this fix is supposed to prevent (confirmed live: tripped
    # the C9
    # ping-pong invariant with `err` swinging ~180° across consecutive ticks while genuinely
    # cornered). A fully-boxed-in creature is better served holding a stable, well-defined heading
    # at full `flee_dist` and pushing against it than degenerating into a self-referential point.
    if reach_known:
      wp = final_endpoint
    else:
      wp = creature_pos + final_dir * flee_dist

  var ttl := int(motor_v3.get("blocked_approach_memory_ticks", 45))
  history.append({"dir": (wp - creature_pos).normalized(), "until_tick": physics_tick + ttl})
  if history.size() > 3:
    history = history.slice(history.size() - 3, history.size())
  state["flee_recent_dirs"] = history

  state["flee_waypoint"] = wp
  state["flee_waypoint_set"] = true
  var latch_ticks := maxi(1, int(motor_v3.get("flee_waypoint_latch_ticks", 16)))
  if bool(state.get("flee_give_up_active", false)):
    latch_ticks = maxi(1, int(motor_v3.get("flee_give_up_latch_ticks", 5)))
  _LatchHold.start(state, "flee_waypoint", latch_ticks)
  state["flee_backtrack_streak"] = 0
  return wp


## Hold latched [code]flee_waypoint[/code] between remints during acute Flight (§12.2 post-6d O1).
static func _maintain_flee_latch(
  ctx: Dictionary,
  state: Dictionary,
  motor_v3: Dictionary,
) -> void:
  var body: CharacterBody3D = ctx.get("body")
  if body == null:
    return
  if bool(ctx.get("flight_just_entered", false)):
    _reset_flight_entry_telemetry(state)
    state["step_goal"] = _mint_flee_waypoint(ctx, state, body, motor_v3)
    state["step_goal_set"] = true
    return
  var latched: Vector3 = state.get("flee_waypoint", Vector3.ZERO)
  if not _LatchHold.is_active(state, "flee_waypoint") or not bool(state.get("flee_waypoint_set", false)):
    state["step_goal"] = _mint_flee_waypoint(ctx, state, body, motor_v3)
    state["step_goal_set"] = true
    return
  state["step_goal"] = latched
  state["step_goal_set"] = true
  _LatchHold.decrement(state, "flee_waypoint")


static func _select_flight_action(ctx: Dictionary, state: Dictionary) -> int:
  state["goal_kind"] = _GkReg.GK_AVOID_HOSTILES
  var body: CharacterBody3D = ctx.get("body")
  var motor_v3: Dictionary = ctx.get("motor_v3", {})
  _maintain_flee_latch(ctx, state, motor_v3)
  state["step_source"] = &"live"
  if not bool(state.get("step_goal_set", false)):
    return _MotorAction.STAY
  return _locomote_toward_step_goal(body, motor_v3, state, ctx)


static func _flee_objective(ctx: Dictionary, creature_pos: Vector3, motor_v3: Dictionary) -> Vector3:
  var threats: Array = ctx.get("threat_samples", [])
  if threats.is_empty():
    return Vector3.ZERO
  var nearest: Dictionary = {}
  var nearest_d := INF
  for sample_v in threats:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    var d := float(sample.get("gate_dist", INF))
    if d < nearest_d:
      nearest_d = d
      nearest = sample
  if nearest.is_empty():
    return Vector3.ZERO
  var threat_pos := Vector3.ZERO
  if nearest.has("world_pos_3d"):
    threat_pos = nearest["world_pos_3d"]
  else:
    var wp: Vector2 = nearest.get("world_pos", Vector2.ZERO)
    threat_pos = Vector3(wp.x, creature_pos.y, wp.y)
  var away := creature_pos - threat_pos
  away.y = 0.0
  if away.length_squared() < 1e-8:
    away = _MotorPlane.HORIZONTAL_FORWARD
  # CLEANUP RT1 follow-up (2026-08-12): was `awareness_radius * 0.5` — on a small (playfield-
  # scaled-down) arena that put the flee waypoint only halfway to the edge of the creature's own
  # (already-shrunk) awareness disc, well inside the fox's fixed, unscaled `eat_action_max_distance`
  # bite range — the rabbit took a token hop and was immediately back in striking range. Flee to the
  # full edge of the awareness disc instead; `awareness_radius` itself already scales down with
  # playfield size (`scale_creature_motor_v3_for_playfield`), so this stays proportionate as arenas
  # grow.
  var flee_dist := float(motor_v3.get("awareness_radius", 150.0))
  return creature_pos + away.normalized() * flee_dist


static func _explore_step_goal(creature_pos: Vector3, state: Dictionary, motor_v3: Dictionary, ctx: Dictionary) -> Vector3:
  var goal_kind: StringName = state.get("goal_kind", _GkReg.GK_FIND_FOOD)
  return _ExploreSeek.mint_explore_step(goal_kind, creature_pos, state, motor_v3, ctx)


## Horizontal facing at first explore pick — duel spawn facing, not random (§3 explore latch).
static func _initial_explore_dir(ctx: Dictionary) -> Vector3:
  var body: CharacterBody3D = ctx.get("body")
  if body != null:
    var facing := _MotorPlane.read_dir(body.get("last_move_direction"), Vector3.ZERO)
    if facing.length_squared() > 1e-12:
      return facing.normalized()
  return _MotorPlane.HORIZONTAL_FORWARD


## World point used for EAT distance/facing — prefers [code]step_ultimate_pos[/code], else [param step_goal].
static func _resolve_eat_target_pos(state: Dictionary, step_goal: Vector3) -> Vector3:
  if bool(state.get("step_ultimate_pos_set", false)):
    return state.get("step_ultimate_pos", Vector3.ZERO)
  return step_goal


## True when [param body] is within [code]eat_action_max_distance[/code] world meters of [param target].
## [param delta] kept for call-site stability; unused for the meter range gate.
static func _is_within_eat_range(
  body: CharacterBody3D,
  target: Vector3,
  motor_v3: Dictionary,
  _delta: float,
) -> bool:
  var max_dist := float(motor_v3.get("eat_action_max_distance", 5.0))
  return body.global_position.distance_to(target) <= max_dist


## Find-food EAT gate: ultimate within [code]eat_action_max_distance[/code] + facing arc + non-zero
## [code]step_instance_id[/code] + no solid on the eater's own [code]collision_mask[/code] standing
## between it and the target (C18 — straight-line range alone let a predator "bite" through an
## impassable barrier like a species-only `MobBlocker` refuge wall).
## [param delta] retained for API/orbit callers; range uses world meters (not move-steps).
static func _can_eat_now(
  body: CharacterBody3D,
  step_goal: Vector3,
  state: Dictionary,
  motor_v3: Dictionary,
  delta: float = 1.0 / 60.0,
  ctx: Dictionary = {},
) -> bool:
  if int(state.get("step_instance_id", 0)) == 0:
    return false
  var eat_tgt := _resolve_eat_target_pos(state, step_goal)
  if eat_tgt.length_squared() < 1e-8:
    return false
  if not _is_within_eat_range(body, eat_tgt, motor_v3, delta):
    return false
  if not _is_facing_aligned_for_eat(body, eat_tgt, motor_v3):
    return false
  return _has_clear_contact_path_for_action(body, eat_tgt, ctx)


## Shared solid-blocker gate for contact actions (EAT today; reuse for combat once it lands) —
## true when nothing on [param body]'s own [code]collision_mask[/code] separates it from
## [param target_pos]. Permissive (returns [code]true[/code]) when [param ctx] carries no
## [code]space_state[/code] so callers without a live physics world (most unit tests) are
## unaffected.
static func _has_clear_contact_path_for_action(
  body: CharacterBody3D,
  target_pos: Vector3,
  ctx: Dictionary,
) -> bool:
  var space_state: PhysicsDirectSpaceState3D = ctx.get("space_state")
  if space_state == null:
    return true
  var eye_h := float(ctx.get("eye_height", 1.0))
  var creature_pos := body.global_position
  var from := Vector3(creature_pos.x, creature_pos.y + eye_h, creature_pos.z)
  var to := Vector3(target_pos.x, from.y, target_pos.z)
  return _PathClear.has_clear_contact_path(
    space_state, from, to, body.collision_mask, [body.get_rid()],
  )


## While in eat range but not facing for EAT: turn toward ultimate; after N revolutions, one MOVE_BACKWARD.
## Returns a motor action id, or [code]-1[/code] when the orbit path does not apply (caller continues normally).
static func _select_eat_orbit_or_align(
  body: CharacterBody3D,
  step_goal: Vector3,
  state: Dictionary,
  motor_v3: Dictionary,
  delta: float,
) -> int:
  if int(state.get("step_instance_id", 0)) == 0:
    state["eat_orbit_turn_deg_accumulated"] = 0.0
    return -1
  var eat_tgt := _resolve_eat_target_pos(state, step_goal)
  if eat_tgt.length_squared() < 1e-8:
    state["eat_orbit_turn_deg_accumulated"] = 0.0
    return -1
  if not _is_within_eat_range(body, eat_tgt, motor_v3, delta):
    state["eat_orbit_turn_deg_accumulated"] = 0.0
    return -1
  if _is_facing_aligned_for_eat(body, eat_tgt, motor_v3):
    state["eat_orbit_turn_deg_accumulated"] = 0.0
    return -1
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  var revs := float(motor_v3.get("eat_orbit_break_revolutions", 3.0))
  var limit_deg := revs * 360.0
  var acc := float(state.get("eat_orbit_turn_deg_accumulated", 0.0))
  if acc + turn_deg >= limit_deg:
    state["eat_orbit_turn_deg_accumulated"] = 0.0
    return _MotorAction.MOVE_BACKWARD
  state["eat_orbit_turn_deg_accumulated"] = acc + turn_deg
  var turn_sign := _pick_align_turn_sign(body, eat_tgt, motor_v3)
  return _MotorAction.TURN_LEFT if turn_sign > 0 else _MotorAction.TURN_RIGHT


static func _locomote_toward_step_goal(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> int:
  resolve_path_to_step_goal(body, motor_v3, state, ctx)
  return align_and_move(body, motor_v3, state)


## §3.1 path clearance — LoS + nav substep when [code]run_path_clearance[/code] is set (§6e.2 cadence).
static func resolve_path_to_step_goal(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> void:
  if not bool(ctx.get("run_path_clearance", false)):
    return
  _run_path_clearance_los_nav(body, motor_v3, state, ctx)


## §3.2 immediate blocked-MOVE recheck — backtrack detour + clearance (not on consideration cadence).
static func apply_immediate_blocked_path_reevaluation(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  if (
    _pursuit_detour_latch_valid(state)
    and _prey_engagement_latch_valid(state)
    and state.get("step_source", &"") == &"live"
  ):
    var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
    if int(state.get("consecutive_blocked", 0)) >= min_ticks:
      _remint_alternate_pursuit_detour(ctx, state, body, motor_v3)
    return
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return
  var old_goal := step_goal
  var creature_pos := body.global_position
  var to_goal := Vector3(step_goal.x - creature_pos.x, 0.0, step_goal.z - creature_pos.z)
  if to_goal.length_squared() < 1e-8:
    return
  var move_dir := to_goal.normalized()
  var blocked_dir := _BlockedApproach.active_dir(
    state.get("blocked_approach", {}),
    int(ctx.get("physics_tick", 0)),
  )
  var backtrack_dot := float(motor_v3.get("blocked_approach_backtrack_dot", 0.55))
  if (
    blocked_dir.length_squared() > 1e-12
    and _BlockedApproach.is_backtrack_step(move_dir, blocked_dir, backtrack_dot)
  ):
    move_dir = move_dir.rotated(Vector3.UP, deg_to_rad(60.0))
    var deflected := creature_pos + move_dir * to_goal.length()
    state["step_goal"] = deflected
    state["step_goal_set"] = true
    # CLEANUP C9 follow-up (2026-08-05, boundary-ping-pong root cause): when the goal being
    # deflected *is* the latched `flee_waypoint`, this per-tick rotation never sticks —
    # `_maintain_flee_latch` restores the original (still-blocked) waypoint next tick, so a
    # waypoint pinned against the playfield boundary makes the rabbit alternate forever between
    # the wall-facing latch and this tick's escape deflection, never net-progressing.
    #
    # First attempt (superseded below): re-derive via `_mint_flee_waypoint` after a sustained
    # streak. Verified live 2026-08-05 that this doesn't help — `_flee_objective` is a pure
    # bearing-away-from-threat calculation with no boundary/geometry awareness, so when both
    # creatures are stalemated near a corner the threat bearing barely changes tick to tick and
    # the "fresh" mint recomputes essentially the same wall-facing point every time.
    #
    # Escalate instead by *promoting* this tick's already-rotated `deflected` point into the
    # persistent `flee_waypoint` latch — a point we know points somewhere directionally different
    # from the blocked bearing, unlike a from-scratch `_flee_objective` recompute. This only fires
    # after `dead_end_record_min_blocked_ticks` sustained backtrack deflections off the *same*
    # latched waypoint (not every blocked tick, unlike the original C9 bug this guards against),
    # and each escalation re-reads the then-current `flee_waypoint` as its rotation base, so
    # repeated escalations walk incrementally around rather than compounding into unbounded drift.
    var flee_latched: Vector3 = state.get("flee_waypoint", Vector3.ZERO)
    if bool(state.get("flee_waypoint_set", false)) and old_goal.is_equal_approx(flee_latched):
      var streak := int(state.get("flee_backtrack_streak", 0)) + 1
      state["flee_backtrack_streak"] = streak
      if streak >= int(motor_v3.get("dead_end_record_min_blocked_ticks", 3)):
        state["flee_waypoint"] = deflected
        state["flee_waypoint_set"] = true
        _LatchHold.start(state, "flee_waypoint", maxi(1, int(motor_v3.get("flee_waypoint_latch_ticks", 16))))
        state["flee_backtrack_streak"] = 0
  _run_path_clearance_los_nav(body, motor_v3, state, ctx)
  var new_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  _maybe_flag_material_step_goal_change(state, body, old_goal, new_goal, motor_v3, float(ctx.get("delta", 1.0 / 60.0)))
  # Deliberately NOT stamped back into `flee_waypoint` (removed CLEANUP R1 follow-up,
  # 2026-07-16 duel review — rabbit stuck at playfield edge): this function's backtrack/LOS
  # deflection is meant to be an ephemeral per-tick correction. Persisting it into the latch used
  # to make each blocked tick's deflection become the "ultimate" input to the next tick's own
  # deflection — a self-referential drift with no path back to the real flee objective until the
  # whole Flight episode exited. `_maintain_flee_latch` already re-holds the true flee_waypoint
  # every tick the countdown hasn't expired, and `_locomote_toward_step_goal` (`_select_flight_action`'s
  # own call, not just this reactive recheck) re-derives a fresh LOS/nav deflection from that stable
  # target on every consideration tick, so no separate stamp is needed here.
  _maybe_mint_pursuit_detour_latch(ctx, state, motor_v3)


static func _run_path_clearance_los_nav(
  body: CharacterBody3D,
  motor_v3: Dictionary,
  state: Dictionary,
  ctx: Dictionary,
) -> void:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return
  if not _is_facing_aligned_for_move(body, step_goal, motor_v3):
    return
  var space: PhysicsDirectSpaceState3D = ctx.get("space_state")
  var eye_h := float(ctx.get("eye_height", 1.0))
  var creature_pos := body.global_position
  var raw_blocked := not _PathClear.has_clear_los(space, creature_pos, eye_h, step_goal, motor_v3)
  var latched := _latch_los_blocked(state, motor_v3, raw_blocked)
  if latched:
    var map_rid: RID = ctx.get("map_rid", RID())
    var agent_r := _agent_radius(body)
    var resolved := _PathClear.resolve_step_objective(
      map_rid, creature_pos, step_goal, agent_r,
    )
    state["step_goal"] = resolved
    state["step_goal_set"] = true


## Debounces the raw per-tick LoS verdict so a flip only lands after
## [code]los_hysteresis_ticks[/code] consecutive same-direction raw reads (default 3, matching
## [code]dead_end_record_min_blocked_ticks[/code]) — stops single grazing rays at a tight
## obstacle pocket (e.g. a plant wedged between two rocks) from alternating the step goal
## clear/blocked every tick.
static func _latch_los_blocked(
  state: Dictionary,
  motor_v3: Dictionary,
  raw_blocked: bool,
) -> bool:
  var latched := bool(state.get("los_blocked_latched", false))
  if raw_blocked == latched:
    state["los_verdict_streak"] = 0
    return latched
  var min_ticks := int(motor_v3.get("los_hysteresis_ticks", 3))
  var streak := int(state.get("los_verdict_streak", 0)) + 1
  if streak >= min_ticks:
    state["los_blocked_latched"] = raw_blocked
    state["los_verdict_streak"] = 0
    return raw_blocked
  state["los_verdict_streak"] = streak
  return latched


## True when the tick's action completed a step objective (EAT or arrival STAY).
static func completed_step_objective(
  body: CharacterBody3D,
  state: Dictionary,
  motor_v3: Dictionary,
  action: int,
) -> bool:
  if action == _MotorAction.EAT:
    return true
  if action == _MotorAction.STAY:
    if state.get("goal_kind", &"") == _GkReg.GK_SHELTER and bool(state.get("shelter_eval_active", false)):
      var result: StringName = state.get("shelter_eval_result", &"")
      return result == &"confirmed" or result == &"failed"
    var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
    if bool(state.get("step_goal_set", false)) and _at_arrival(body, step_goal, motor_v3):
      return true
  return false


## §7.3.0 facing-relative one-action pick toward current [code]step_goal[/code].
static func align_and_move(body: CharacterBody3D, motor_v3: Dictionary, state: Dictionary) -> int:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return _MotorAction.STAY
  ## Sole source of MOVE_FORWARD (CLEANUP R1) — computed here so it's fresh on any tick the
  ## executor sees that action, and available to any future consumer that needs "how far to the
  ## current step objective" without recomputing (e.g. ranged-combat reachability checks).
  state["dist_to_goal"] = _horizontal_distance(body, step_goal)
  if bool(state.get("force_align_turn_before_move", false)):
    state["force_align_turn_before_move"] = false
    var forced_sign := _pick_align_turn_sign(body, step_goal, motor_v3)
    return _MotorAction.TURN_LEFT if forced_sign > 0 else _MotorAction.TURN_RIGHT
  if _is_within_move_blend_arc(body, step_goal, motor_v3):
    return _MotorAction.MOVE_FORWARD
  var turn_sign := _pick_align_turn_sign(body, step_goal, motor_v3)
  return _MotorAction.TURN_LEFT if turn_sign > 0 else _MotorAction.TURN_RIGHT


## Widened MOVE_FORWARD gate (CLEANUP R1 mitigation #2 — blend turn+move in one tick). True
## whenever heading error is within [code]move_blend_max_error_deg[/code] — wider than
## [method _is_facing_aligned_for_move]'s tight `turn_increment_deg` cone — because the executor
## now blends a bounded turn toward the target into the same tick's move instead of requiring full
## alignment before `MOVE_FORWARD` is legal. Only gates action *selection*; LOS/nav path clearance
## (`_run_path_clearance_los_nav`) still uses the tight cone unchanged.
static func _is_within_move_blend_arc(body: CharacterBody3D, target: Vector3, motor_v3: Dictionary) -> bool:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return true
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var arc_deg := float(motor_v3.get("move_blend_max_error_deg", 60.0))
  var min_dot := cos(deg_to_rad(arc_deg))
  return facing.dot(to_target.normalized()) >= min_dot


static func _is_facing_aligned_with_tolerance(
  body: CharacterBody3D,
  target: Vector3,
  motor_v3: Dictionary,
  tolerance_multiplier: float,
) -> bool:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return true
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  var min_dot := cos(deg_to_rad(turn_deg * tolerance_multiplier))
  return facing.dot(to_target.normalized()) >= min_dot


## EAT facing uses [code]eat_facing_arc_deg[/code] full arc (default 90° → half-angle 45°, [code]dot ≥ cos(45°)[/code]).
static func _is_facing_aligned_for_eat(body: CharacterBody3D, target: Vector3, motor_v3: Dictionary) -> bool:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return true
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var arc_deg := float(motor_v3.get("eat_facing_arc_deg", 90.0))
  var min_dot := cos(deg_to_rad(arc_deg * 0.5))
  return facing.dot(to_target.normalized()) >= min_dot


static func _is_facing_aligned_for_move(body: CharacterBody3D, target: Vector3, motor_v3: Dictionary) -> bool:
  # One full turn increment: a single atomic turn can overshoot the half-increment EAT cone.
  return _is_facing_aligned_with_tolerance(body, target, motor_v3, 1.0)


static func _horizontal_distance(body: CharacterBody3D, target: Vector3) -> float:
  var creature_pos := body.global_position
  return Vector2(target.x - creature_pos.x, target.z - creature_pos.z).length()


static func _facing_dot_to_target(body: CharacterBody3D, target: Vector3) -> float:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return 1.0
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  return clampf(facing.dot(to_target.normalized()), -1.0, 1.0)


static func _move_alignment_min_dot(motor_v3: Dictionary) -> float:
  var turn_deg := float(motor_v3.get("turn_increment_deg", 22.5))
  return cos(deg_to_rad(turn_deg))


static func _signed_bearing_error_deg(body: CharacterBody3D, target: Vector3) -> float:
  var creature_pos := body.global_position
  var to_target := Vector3(target.x - creature_pos.x, 0.0, target.z - creature_pos.z)
  if to_target.length_squared() < 1e-8:
    return 0.0
  var facing := _MotorPlane.read_dir(body.get("last_move_direction"), _MotorPlane.HORIZONTAL_RIGHT)
  var to_n := to_target.normalized()
  var cross := facing.x * to_n.z - facing.z * to_n.x
  var dot := clampf(facing.dot(to_n), -1.0, 1.0)
  return rad_to_deg(atan2(cross, dot))


static func _agent_radius(body: CharacterBody3D) -> float:
  if body.has_method(&"get_collision_capsule_radius"):
    return maxf(0.1, float(body.call(&"get_collision_capsule_radius")))
  return 0.35


static func _at_arrival(body: CharacterBody3D, step_goal: Vector3, motor_v3: Dictionary) -> bool:
  var tol := float(motor_v3.get("arrival_tolerance", motor_v3.get("eat_action_max_distance", 5.0)))
  return body.global_position.distance_to(step_goal) <= tol


## Applies §9 persist/switch/seek after blocked locomotion; mutates [param state] step fields.
static func apply_blocked_objective_resolution(
  ctx: Dictionary,
  state: Dictionary,
  body: CharacterBody3D,
  motor_v3: Dictionary,
) -> void:
  var min_ticks := int(motor_v3.get("dead_end_record_min_blocked_ticks", 3))
  if int(state.get("consecutive_blocked", 0)) < min_ticks:
    return
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return
  var iid := int(state.get("step_instance_id", 0))
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  if iid != 0 and adapter.has_method(&"increment_passibility_fail"):
    adapter.increment_passibility_fail(iid, now_ms)
  var approach := _BlockedApproach.active_dir(
    state.get("blocked_approach", {}),
    int(ctx.get("physics_tick", 0)),
  )
  if approach.length_squared() > 1e-8 and adapter.has_method(&"record_dead_end_mark"):
    adapter.record_dead_end_mark(
      body.global_position,
      approach,
      state.get("goal_kind", _GkReg.GK_FIND_FOOD),
      iid,
      now_ms,
    )
  var blocked_ctx := ctx.duplicate(true)
  blocked_ctx["creature_pos"] = body.global_position
  var resolution := _BlockedObjective.resolve(
    blocked_ctx,
    iid,
    state.get("step_stimulus_kind_id", &""),
    motor_v3,
  )
  state["blocked_objective_action"] = resolution.get("action", &"persist")
  match resolution.get("action", &"persist"):
    _BlockedObjective.ACTION_SWITCH:
      state["explore_dir"] = Vector3.ZERO
      state["explore_waypoint"] = Vector3.ZERO
      state["explore_waypoint_set"] = false
      state["step_goal"] = Vector3.ZERO
      state["step_goal_set"] = false
    _BlockedObjective.ACTION_SEEK:
      _seed_explore_after_seek(state, ctx)
    _:
      pass
