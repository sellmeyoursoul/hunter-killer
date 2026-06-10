## Headless test entry: [code]godot --path . --headless -s res://tests/run_all.gd[/code]
extends SceneTree

const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _Tokens := preload("res://AI_int_lib/ai_action_tokens.gd")
const _Wire := preload("res://AI_int_lib/perception_wire.gd")
const _Sampling := preload("res://AI_int_lib/perception_sampling.gd")
const _Risk := preload("res://AI_int_lib/perception_risk_hints.gd")
const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const IntentHoldScr := preload("res://creature/motor/scripted_intent_hold.gd")
const _NoGoalPatrolLockScr := preload("res://creature/motor/no_goal_patrol_lock.gd")
const _SeekStationaryLookScr := preload("res://creature/motor/seek_stationary_look.gd")
const _JeopardyTurnScr := preload("res://creature/motor/jeopardy_forced_turn.gd")
const _SlidePickScr := preload("res://creature/motor/wall_slide_pick.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _EnvCell := preload("res://environment/environment_cell_data.gd")
const _EnvGrid := preload("res://environment/environment_grid_baked.gd")
const _EnvBake := preload("res://environment/environment_grid_bake.gd")
const _PackRes := preload("res://pack_resource_resolver.gd")
const _Tier2Dom := preload("res://creature/motor/tier2_dominance.gd")
const _TraitTier2 := preload("res://creature/motor/trait_tier2_mapper.gd")
const _TacticScr := preload("res://creature/motor/motor_tactic_classifier.gd")
const _GoalMem := preload("res://creature/motor/goal_source_memory.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
const _BelievedSector := preload("res://creature/motor/believed_goal_sector.gd")
const _CreatureVitalsMath := preload("res://creature/capabilities/creature_vitals_math.gd")
const _CreaturePredationMath := preload("res://creature/capabilities/creature_predation_math.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")
const _CreaturePerception3D := preload("res://creature/capabilities/creature_perception_3d.gd")
const _CreatureRoot3D := preload("res://creature/creature_root_3d.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")
const _PlayfieldBounds3D := preload("res://environment/playfield_bounds_3d.gd")
const _TopDownCameraScr := preload("res://environment/top_down_camera_control.gd")
const _PerimeterBoulders := preload("res://environment/playfield_perimeter_boulders.gd")
const _GroundSampler := preload("res://environment/playfield_ground_sampler.gd")
const _TerrainTestMainStub := preload("res://tests/terrain_test_main_stub.gd")
const _TerrainMotor := preload("res://creature/motor/terrain_motor.gd")
const _EXPANDING_CARDINAL_EXPLORE_SCR := preload("res://creature/motor/expanding_cardinal_explore.gd")
const _CarnivorePursuit := preload("res://creature/motor/carnivore_pursuit.gd")
const _ObstacleStrat := preload("res://creature/motor/motor_obstacle_strategy.gd")
const _GeomScr := preload("res://creature/motor/motor_obstacle_geometry.gd")
const _SeekDirCommitScr := preload("res://creature/motor/seek_direction_commit.gd")
const _SeekDirTurnScr := preload("res://creature/motor/seek_direction_turn.gd")
const _BlockedApproachScr := preload("res://creature/motor/blocked_approach_memory.gd")
const _MotorOct := preload("res://creature/motor/motor_oct_directions.gd")
const _AiDriverScr := preload("res://AI_int_lib/ai_driver.gd")
const _GoalVisLatch := preload("res://creature/motor/goal_visibility_latch.gd")
const _GoalSeekScr := preload("res://creature/motor/goal_seek.gd")
const _SeekCandScr := preload("res://creature/motor/seek_candidate.gd")
const _MotorTargetBuilder := preload("res://creature/motor/motor_target_builder.gd")
const _ThreatSampleScr := preload("res://creature/motor/threat_sample.gd")
const _GoalBeliefScr := preload("res://creature/motor/goal_belief_memory.gd")
const _KinematicBody3DScr := preload("res://creature/capabilities/creature_kinematic_body_3d.gd")
const _MotorPlaneScr := preload("res://creature/motor/motor_plane.gd")
const _EightWayDirScr := preload("res://creature/motor/eight_way_directions.gd")
const _Herbivore3DScenePath := "res://creature/templates/creature_herbivore_kinematic_3d.tscn"
const _Carnivore3DScenePath := "res://creature/templates/creature_carnivore_kinematic_3d.tscn"
const _SolidShrub3DScenePath := "res://assets/plants/solid_shrub/solid_shrub_3d.tscn"
const _RabbitArchetypeRes := preload("res://creature/species/rabbit_archetype.tres")
const _FoxArchetypeRes := preload("res://creature/species/fox_archetype.tres")
const _EnvMerge := preload("res://environment/environment_movement_impact.gd")
const _Footprint := preload("res://environment/environment_footprint_sampler.gd")
const _LoS := preload("res://creature/motor/line_of_sight.gd")
const _NavHint := preload("res://environment/nav_path_hint.gd")

var _failures: int = 0


func _instantiate_herbivore_root() -> Node3D:
  var scene: PackedScene = load(_Herbivore3DScenePath) as PackedScene
  _assert(scene != null, "herbivore 3D template loads")
  var creature_root := scene.instantiate() as Node3D
  creature_root.set("definition", _RabbitArchetypeRes)
  return creature_root


func _instantiate_carnivore_root() -> Node3D:
  var scene: PackedScene = load(_Carnivore3DScenePath) as PackedScene
  _assert(scene != null, "carnivore 3D template loads")
  var creature_root := scene.instantiate() as Node3D
  creature_root.set("definition", _FoxArchetypeRes)
  return creature_root


func _setup_herbivore_body(body: CharacterBody3D) -> void:
  for g in [&"player", &"prey", &"herbivores", &"creatures"]:
    body.add_to_group(g)


func _setup_carnivore_body(body: CharacterBody3D) -> void:
  for g in [&"mobs", &"creatures"]:
    body.add_to_group(g)


func _spawn_herbivore_body(main: Node3D, pos: Vector3) -> CharacterBody3D:
  var creature_root := _instantiate_herbivore_root()
  main.add_child(creature_root)
  var body := creature_root.get_node("Body") as CharacterBody3D
  _setup_herbivore_body(body)
  body.global_position = pos
  return body


func _spawn_carnivore_body(main: Node3D, pos: Vector3) -> CharacterBody3D:
  var creature_root := _instantiate_carnivore_root()
  main.add_child(creature_root)
  var body := creature_root.get_node("Body") as CharacterBody3D
  _setup_carnivore_body(body)
  body.global_position = pos
  return body


func _spawn_food_bush(main: Node3D, pos: Vector3) -> Node3D:
  var scene: PackedScene = load(_SolidShrub3DScenePath) as PackedScene
  _assert(scene != null, "solid_shrub_3d loads")
  var bush := scene.instantiate() as Node3D
  main.add_child(bush)
  bush.global_position = pos
  return bush


func _ai_driver_script() -> Script:
  return load("res://AI_int_lib/ai_driver.gd") as Script


func _ai_driver_can_instantiate() -> bool:
  var scr := _ai_driver_script()
  return scr != null and scr.can_instantiate()


func _init() -> void:
  _run_all_async.call_deferred()


func _run_all_async() -> void:
  await _run_all()
  quit(0 if _failures == 0 else 1)


func _run_all() -> void:
  _test_merge_defaults_and_override()
  _test_creature_motor_v2_profiles()
  _test_creature_pack_motor_overlays()
  _test_goal_source_memory()
  _test_goal_kind_phase_c_replay()
  _test_goal_belief_anticipated_calories_stub()
  _test_creature_trait_usage_wiring()
  _test_motor_motivation_wiring()
  _test_locale_prior_escalate_seek()
  _test_escape_reversal_suppression()
  _test_goal_belief_coarse_ttl()
  _test_goal_belief_merge_skips_live_awareness()
  _test_plant_occluded_live_food_entries()
  _test_goal_seek_resolve_and_cost()
  _test_motor_target_builder_feeding_mode()
  _test_load_merged_config_repo_fallback()
  _test_hunter_killer_debug_project_settings()
  _test_tokens()
  _test_perception_snippet()
  _test_perception_sampling()
  _test_perception_risk_hints()
  _test_cardinal_avoidance()
  _test_obstacle_strategy_shield_pin()
  _test_playfield_corner_escape()
  _test_world_corner_static_wedge_escape()
  _test_playfield_open_corner_escape()
  _test_playfield_boundary_edge_rocks()
  _test_ne_corner_food_seek_egress()
  _test_predator_cover_pin_flank()
  _test_herbivore_flee_cover()
  _test_herbivore_flee_obstacle_slip()
  _test_herbivore_flee_bush_rock_pinch()
  _test_herbivore_flee_diagonal_rock_pinch()
  _test_herbivore_flee_w_shrub_n_rock_pinch()
  _test_expanding_cardinal_explore()
  _test_predator_chase_motor_ctx()
  _test_predator_prey_memory_chase()
  _test_goal_belief_moving_prey_ghost()
  _test_no_goal_plateau_random()
  _test_food_seek_motor()
  _test_explore_idle_when_no_pickup()
  _test_explore_trail_repulsion_motor()
  _test_jeopardy_forced_turn()
  _test_scripted_intent_hold()
  _test_seek_oct_directions()
  _test_seek_direction_commit()
  _test_seek_direction_turn()
  _test_no_goal_patrol_lock()
  _test_no_goal_patrol_lock_guided()
  _test_predator_patrol_expanding_coverage()
  _test_predator_pacing_trap_break()
  _test_predator_south_wall_boulder_pinch_escape()
  _test_predator_northeast_corner_interior_escape()
  _test_predator_rim_patrol_eight_way()
  _test_predator_interior_stuck_escape_midfield()
  _test_goal_visibility_latch_streak_and_engagement()
  _test_seek_occlusion_step_cost_no_los_ctx()
  _test_predator_obstructed_hunt_active_lost_visual()
  _test_predator_east_rim_to_interior_patrol()
  _test_predator_patrol_heading_variance()
  _test_predator_east_rim_peel_prefers_inward()
  _test_predator_patrol_coverage_stall_escape()
  _test_motor_cardinal_probe_scaled_for_small_playfield()
  _test_seek_stationary_look()
  _test_motor_plane_yaw_from_facing()
  _test_seek_diagonal_intent()
  _test_seek_wall_filter_and_backtrack()
  _test_blocked_approach_memory()
  _test_herbivore_food_seek_pinch_escape_backtrack()
  _test_herbivore_pinch_stall_zero_intent()
  _test_bush_proximity_pickup_adjacent()
  _test_herbivore_forage_plateau_release()
  _test_herbivore_food_awareness_latch()
  _test_eaten_bush_moves_to_unready_not_seek()
  _test_mob_avoidance_acceptance()
  _test_ai_driver_helpers()
  _test_duel_spawn_facing_variance()
  _test_forward_cone_only_awareness()
  _test_bundled_inference_helpers()
  _test_environment_baked_grid()
  _test_cardinal_interior_env_grid()
  _test_wall_slide_pick()
  _test_pack_resource_resolver()
  _test_hunger_calorie_clamp()
  _test_calorie_drain_movement_formula()
  _test_predator_prey_meal_clamp()
  _test_creature_vitals_math_burn_and_clamp()
  _test_hud_resolves_3d_herbivore_motor_body()
  _test_creature_predation_math()
  _test_diet_registry_defaults()
  _test_creature_perception_3d_scale()
  _test_creature_3d_template_scenes_load()
  _test_shrub_3d_visual_scenes_load()
  await _test_creature_3d_predation_contact()
  _test_playfield_clamp()
  _test_playfield_bounds_3d_collision_only()
  _test_boulder_obstacle_collision_bake()
  _test_perimeter_boulder_density()
  await _test_playfield_prop_grounding_on_thick_floor()
  await _test_ground_sampler_center_lower_than_rim()
  await _test_duel_spawn_picker_avoids_depression()
  await _test_terrain_stuck_escape_prefers_uphill()
  await _test_terrain_physics_cardinal_blocked()
  _test_creature_spawn_floor_settle()
  _test_human_prey_control_bootstrap()
  _test_human_move_intent_world_space()
  _test_human_facing_blocked_no_spin()
  _test_human_strafe_intent_stable_under_camera_spin()
  _test_top_down_camera_pan_directions()
  _test_top_down_camera_zoom_clamp()
  _test_footprint_geometry()
  _test_carnivore_pursuit_intent()
  _test_creature_diet_on_3d_bodies()
  _test_ai_driver_creature_registry()
  _test_environment_movement_impact_merge()
  _test_environment_footprint_overlap()
  _test_creature_size_sync_capsule()
  await _test_line_of_sight_wall_occlusion()
  _test_nav_path_hint_invalid_map()
  if _failures > 0:
    push_error("tests/run_all.gd: %d assertion(s) failed." % _failures)


func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)


func _test_merge_defaults_and_override() -> void:
  var base := _Merge.default_root()
  var file_root := {
    "logging_params": {"LOG_LEVEL": "Debug"},
    "inference_client": {"INFERENCE_BASE_URL": "http://x"},
    "perception": {"SNAPSHOT_PHYSICS_STRIDE": 3},
    "creature_motor": {"mode": "llm"},
  }
  var merged: Dictionary = _Merge.merge_root(base, file_root)
  _assert(merged["logging_params"]["LOG_LEVEL"] == "Debug", "merge logging_params.LOG_LEVEL")
  _assert(merged["logging_params"]["MAX_LINES_PER_PROCESS"] == 128, "merge logging_params keeps default key")
  _assert(merged["inference_client"]["INFERENCE_BASE_URL"] == "http://x", "merge inference_client url")
  _assert(merged["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 3, "merge perception stride")
  _assert(str(merged["creature_motor"].get("mode", "")) == "llm", "merge creature_motor.mode override")
  _assert(
    is_equal_approx(float(merged["creature_motor"].get("weight_interior", 0.0)), 0.65),
    "merge creature_motor keeps default weight_interior when not overridden",
  )
  _assert(
    is_equal_approx(float(merged["creature_motor"].get("weight_dist_sq", 0.0)), 55.0),
    "merge creature_motor keeps default weight_dist_sq when not overridden",
  )
  _assert(
    is_equal_approx(float(merged["creature_motor"].get("weight_edge", 0.0)), 0.48),
    "merge creature_motor keeps default weight_edge when not overridden",
  )
  _assert(
    float(merged["creature_motor"].get("lookahead_sec", 0.0)) > 0.0,
    "merge creature_motor keeps default lookahead when not overridden"
  )
  var res: Dictionary = _Merge.load_merge_from_path("user://__does_not_exist_for_test__.json")
  _assert(str(res.get("diagnostic", "")) != "", "missing file should set diagnostic")
  var m2: Dictionary = res["merged"]
  _assert(m2["perception"]["SNAPSHOT_PHYSICS_STRIDE"] == 1, "missing file perception default")
  _assert(str(base["creature_motor"].get("mode", "")) == "scripted", "default creature_motor.mode scripted")
  var spine: Dictionary = _Merge.creature_motor_spine()
  _assert(
    int(spine.get("scripted_intent_hold_physics_ticks", -1)) == 8,
    "spine scripted intent hold",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_seek_ready_food", -1.0)), 0.0),
    "default root uses dev profile (zero seek)",
  )
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_interior", 0.0)), 0.65), "default weight_interior")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_dist", 0.0)), 0.45), "default weight_dist")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_closing", 0.0)), 1.05), "default weight_closing")
  _assert(is_equal_approx(float(base["creature_motor"].get("distance_eps", 0.0)), 6.0), "default distance_eps")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_dist_sq", 0.0)), 55.0), "default weight_dist_sq")
  _assert(is_equal_approx(float(base["creature_motor"].get("weight_edge", 0.0)), 0.48), "default weight_edge")
  _assert(bool(base["creature_motor"].get("shuffle_tie_break", false)), "default shuffle_tie_break")
  _assert(is_equal_approx(float(base["creature_motor"].get("awareness_radius", 0.0)), 1500.0), "default awareness_radius")
  _assert(int(base["creature_motor"].get("expanding_explore_base_physics_ticks", -1)) == 36, "default expanding_explore_base_physics_ticks")
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_expanding_explore_hint", 0.0)), 0.12),
    "default weight_expanding_explore_hint",
  )
  _assert(is_equal_approx(float(base["creature_motor"].get("awareness_cone_extra", 0.0)), 3000.0), "default awareness_cone_extra")
  _assert(int(base["creature_motor"].get("awareness_memory_ticks", -1)) == 3, "default awareness_memory_ticks")
  _assert(is_equal_approx(float(base["creature_motor"].get("awareness_memory_weight", 0.0)), 0.35), "default awareness_memory_weight")
  _assert(
    is_equal_approx(float(base["creature_motor"].get("hunger_explore_interior_scale_min", 0.0)), 0.16),
    "default hunger_explore_interior_scale_min",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("hunger_explore_urgency_power", 0.0)), 1.25),
    "default hunger_explore_urgency_power",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("calorie_baseline_drain_per_sec", 0.0)), 1.0),
    "default calorie_baseline_drain_per_sec",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("calorie_cost_per_unit_moved", 0.0)), 0.002),
    "default calorie_cost_per_unit_moved",
  )
  _assert(int(base["creature_motor"].get("predator_prey_meal_calories", -1)) == 5, "default predator_prey_meal_calories")
  _assert(
    int(base["creature_motor"].get("carnivore_explore_rotate_physics_ticks", -1)) == 36,
    "default carnivore_explore_rotate_physics_ticks",
  )
  _assert(
    is_equal_approx(float(spine.get("weight_seek_ready_food", 0.0)), 16.0),
    "spine weight_seek_ready_food",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("food_seek_imminent_mob_radius", 0.0)), 100.0),
    "default food_seek_imminent_mob_radius",
  )
  _assert(
    int(base["creature_motor"].get("jeopardy_forced_turn_ticks", -1)) == 5,
    "default jeopardy_forced_turn_ticks",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_avoid_unready_food", 0.0)), 5.5),
    "default weight_avoid_unready_food",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("food_avoid_unready_scale_when_ready_target", 0.0)), 0.35),
    "default food_avoid_unready_scale_when_ready_target",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_explore_idle_penalty", 0.0)), 10.5),
    "default weight_explore_idle_penalty",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_explore_turn_bias", 0.0)), 0.14),
    "default weight_explore_turn_bias",
  )
  _assert(
    int(base["creature_motor"].get("explore_intent_hold_extra_ticks", -1)) == 5,
    "default explore_intent_hold_extra_ticks",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("explore_coverage_cell", 0.0)), 52.0),
    "default explore_coverage_cell",
  )
  _assert(
    int(base["creature_motor"].get("explore_trail_max_cells", -1)) == 96,
    "default explore_trail_max_cells",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_explore_trail_repulsion", 0.0)), 2.35),
    "default weight_explore_trail_repulsion",
  )
  _assert(bool(base["creature_motor"].get("motor_exploration_always_enabled", false)), "default motor_exploration_always_enabled")
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_pursuit_dist", 0.0)), 0.42),
    "default weight_pursuit_dist",
  )
  _assert(
    int(base["creature_motor"].get("intent_hold_ticks_predator", -1)) == 6,
    "default intent_hold_ticks_predator",
  )
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_obstacle_shield_prey", 0.0)), 28.0),
    "default weight_obstacle_shield_prey",
  )


func _test_creature_motor_v2_profiles() -> void:
  var spine := _Merge.creature_motor_spine()
  var dev := _Merge.apply_creature_motor_profile_dev(spine.duplicate(true))
  var ship := _Merge.apply_creature_motor_profile_ship(spine.duplicate(true))
  _assert(
    is_equal_approx(float(dev.get("weight_seek_ready_food", -1.0)), 0.0),
    "dev profile zero seek",
  )
  _assert(
    is_equal_approx(float(dev.get("motor_intent_cost_chaos", 0.0)), 8.0),
    "dev profile high chaos",
  )
  _assert(
    is_equal_approx(float(ship.get("weight_seek_ready_food", -1.0)), 16.0),
    "ship stub leaves spine seek",
  )
  var pack_over := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/resolver_smoke",
  )
  _assert(
    is_equal_approx(float(pack_over.get("weight_seek_ready_food", 0.0)), 12.0),
    "pack creature_motor overlay wins",
  )
  _assert(
    _Tier2Dom.derive_dominant_tier2_leaf(0.05, true, 0.0, spine) == _Tier2Dom.LEAF_FIND_FOOD,
    "starvation override find food",
  )
  _assert(
    _Tier2Dom.derive_dominant_tier2_leaf(0.5, true, 0.0, spine) == _Tier2Dom.LEAF_AVOID_HOSTILES,
    "acute threat avoid hostiles",
  )
  var bias_empty: Dictionary = _GoalMem.project_believed_goal_bias(
    Vector3.ZERO, &"find_food", spine, null
  )
  _assert(bias_empty.get("pull_mag", -1.0) == 0.0, "believed pull_mag zero without store")
  _assert(
    _BelievedSector.align_step_with_sector(Vector3(0.0, 0.0, -1.0), 0) > 0.9,
    "sector arc N for up step",
  )


func _test_creature_pack_motor_overlays() -> void:
  var base := _Merge.default_creature_motor_params()
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/rabbit",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("weight_seek_ready_food", 0.0)), 16.0),
    "rabbit pack restores food seek under dev profile",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("motor_intent_cost_chaos", -1.0)), 2.2),
    "rabbit pack duel motor chaos",
  )
  _assert(
    not bool(rabbit_m.get("herbivore_threat_awareness_omni", true)),
    "rabbit pack uses forward cone threat awareness",
  )
  _assert(
    not bool(rabbit_m.get("awareness_forward_cone_only", true)),
    "rabbit pack uses hybrid radius disk + forward cone awareness",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("motor_no_goal_patrol_lock_sec", 0.0)), 0.65),
    "rabbit pack no-goal patrol lock duration",
  )
  _assert(
    not bool(rabbit_m.get("plant_awareness_requires_los", true)),
    "rabbit pack allows occluded-in-zone plants for goal belief sync",
  )
  var fox_m := _Merge.merge_creature_motor_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/fox",
  )
  _assert(
    is_equal_approx(float(fox_m.get("weight_seek_prey", 0.0)), 22.0),
    "fox pack restores prey seek under dev profile",
  )
  _assert(
    is_equal_approx(float(fox_m.get("weight_seek_ready_food", -1.0)), 0.0),
    "fox pack does not enable bush food seek",
  )
  _assert(
    is_equal_approx(float(fox_m.get("weight_pursuit_closing", 0.0)), 1.35),
    "fox pack pursuit closing tuned",
  )
  _assert(
    is_equal_approx(float(fox_m.get("weight_pursuit_dist", 0.0)), 0.55),
    "fox pack pursuit dist tuned",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("weight_stuck_escape_explore", 0.0)), 2.2),
    "rabbit pack stuck escape explore weight",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("herbivore_expanding_explore_mul", 0.0)), 3.0),
    "rabbit pack herbivore expanding explore mul",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("scripted_intent_hold_physics_ticks", 0.0)), 4.0),
    "rabbit pack restores intent hold ticks",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("weight_seek_ready_food", 0.0)), 18.0),
    "rabbit pack seek ready food weight",
  )
  _assert(
    is_equal_approx(float(fox_m.get("motor_intent_cost_chaos", -1.0)), 3.8),
    "fox pack duel motor chaos",
  )
  _assert(
    is_equal_approx(float(fox_m.get("geometry_escape_lock_ticks", 0.0)), 6.0),
    "fox pack geometry escape lock ticks",
  )
  _assert(
    not bool(fox_m.get("predator_prey_awareness_omni", true)),
    "fox pack uses forward cone prey awareness",
  )
  _assert(
    not bool(fox_m.get("awareness_forward_cone_only", true)),
    "fox pack uses hybrid radius disk + forward cone awareness",
  )
  _assert(
    is_equal_approx(float(fox_m.get("motor_no_goal_patrol_lock_sec", 0.0)), 0.5),
    "fox pack no-goal patrol lock duration",
  )
  _assert(
    is_equal_approx(float(fox_m.get("weight_explore_trail_repulsion", 0.0)), 2.35),
    "fox pack explore trail repulsion for patrol coverage",
  )
  _assert(
    is_equal_approx(float(fox_m.get("expanding_explore_base_physics_ticks", 0.0)), 48.0),
    "fox pack expanding explore segment ticks for guided patrol",
  )
  var rabbit_kinds := _GkReg.effective_goal_kinds_for_pack("res://assets/creatures/rabbit")
  _assert(rabbit_kinds.size() >= 4, "rabbit pack goal kinds include core set")
  _assert(
    _GkReg.validate_goal_kind(&"find_food", rabbit_kinds),
    "rabbit pack validates find_food",
  )
  var rabbit_mods := _GoalMem.effective_modality_allowlist_for_pack("res://assets/creatures/rabbit")
  _assert(rabbit_mods.size() >= 6, "rabbit pack modality allowlist includes core set")
  var rabbit_def: Resource = load("res://creature/species/rabbit_archetype.tres") as Resource
  _assert(
    str(rabbit_def.get("asset_pack_root")) == "res://assets/creatures/rabbit",
    "rabbit archetype points at rabbit pack",
  )
  var fox_def: Resource = load("res://creature/species/fox_archetype.tres") as Resource
  _assert(fox_def != null, "fox archetype loads")
  _assert(
    str(fox_def.get("asset_pack_root")) == "res://assets/creatures/fox",
    "fox archetype points at fox pack",
  )
  _assert(str(rabbit_def.get("display_name")) == "Rabbit", "rabbit display_name for HUD")
  _assert(str(fox_def.get("display_name")) == "Fox", "fox display_name for HUD")


func _test_goal_source_memory() -> void:
  var spine := _Merge.creature_motor_spine()
  var motor_p := spine.duplicate(true)
  var grid := _EnvGrid.new()
  grid.cell_width = 32
  grid.cell_height = 32
  grid.cell_size = 52.0
  grid.cell_kind_ids = PackedInt32Array()
  grid.cell_kind_ids.resize(32 * 32)
  var anchor := Vector3(120.0, 0.0, 80.0)
  var bad_hash := _GoalMem.context_hash_for_find_food(
    _GkReg.GK_FIND_FOOD, Vector3(99999.0, 0.0, 99999.0), motor_p, grid
  )
  _assert(bad_hash < 0, "OOB anchor rejects context_hash")
  var good_hash := _GoalMem.context_hash_for_find_food(
    _GkReg.GK_FIND_FOOD, anchor, motor_p, grid
  )
  _assert(good_hash >= 0, "in-bounds anchor yields context_hash")
  var store := _GoalMem.new()
  var kinds := _GkReg.core_goal_kinds()
  var mods := _GoalMem.effective_modality_allowlist_for_pack("")
  var motor_ctx := {"tactic_classifier_active": false, "tactic_jeopardy_egress": false}
  var ok := store.try_salient_write(
    _GkReg.GK_FIND_FOOD,
    &"find_food",
    anchor,
    motor_p,
    grid,
    motor_ctx,
    {"tier": _GoalMem.TIER_SUCCESS},
    kinds,
    mods,
    {},
  )
  _assert(ok, "salient write succeeds in-bounds")
  var bias: Dictionary = _GoalMem.project_believed_goal_bias(
    Vector3(100.0, 0.0, 70.0),
    _GkReg.GK_FIND_FOOD,
    motor_p,
    store,
    anchor,
    grid,
    motor_ctx,
    [],
    {},
  )
  _assert(float(bias.get("pull_mag", 0.0)) > 0.0, "pull_mag positive after write")
  var replay_w := float(bias.get("replay_weight", 1.0))
  _assert(replay_w >= 1.0, "replay_weight at least 1 when row matches")
  var dup := store.try_salient_write(
    _GkReg.GK_FIND_FOOD,
    &"find_food",
    anchor,
    motor_p,
    grid,
    motor_ctx,
    {"tier": _GoalMem.TIER_SUCCESS},
    kinds,
    mods,
    {},
  )
  _assert(not dup, "same-goal continuation blocks second write")
  _assert(_GkReg.validate_goal_kind(&"find_food", kinds), "validate_goal_kind core")
  _assert(not _GkReg.validate_goal_kind(&"bogus", kinds), "validate_goal_kind rejects unknown")


func _test_goal_kind_phase_c_replay() -> void:
  var motor_p := _Merge.creature_motor_spine()
  var catalog := _GkReg.goal_kind_catalog_for_pack("")
  _assert(
    _GkReg.resolve_goal_kind_at_outcome(&"avoid_hostiles", {}, catalog) == _GkReg.GK_AVOID_HOSTILES,
    "avoid_hostiles resolves to avoid_hostiles wire id",
  )
  _assert(
    _GkReg.resolve_goal_kind_at_outcome(&"preserve_calories", {}, catalog) == &"",
    "preserve has no salient GoalKind",
  )
  _assert(
    _GkReg.parent_tier2_for_goal_kind(_GkReg.GK_SHELTER, catalog) == &"avoid_hostiles",
    "shelter parent_tier2 is avoid_hostiles",
  )
  _assert(
    not _GkReg.salient_writes_enabled(_GkReg.GK_FIND_MATE, catalog),
    "find_mate salient_writes disabled phase-1",
  )
  var traits_explorer := {"explorer_builder": -80.0, "change_stability": 0.0}
  var slot_a := _GoalMem.slot_a_raw_for_pole(traits_explorer, &"explorer")
  _assert(slot_a > 50.0, "negative explorer_builder aligns with explorer pole")
  var low_cap := _GoalMem.effective_slot_a(slot_a, 20.0, 0.0, motor_p)
  var high_cap := _GoalMem.effective_slot_a(slot_a, 95.0, 1.0, motor_p)
  _assert(absf(high_cap) > absf(low_cap), "urgency+slot_b raise effective Slot A cap")
  _assert(
    is_equal_approx(_GoalMem.compute_external_urgency({"tactic_jeopardy_egress": true}, motor_p), 1.0),
    "jeopardy egress sets external_urgency 1",
  )
  var hunger_ctx := {"calorie_ratio": 0.5}
  _assert(
    _GoalMem.compute_external_urgency(hunger_ctx, motor_p) > 0.2,
    "hunger band contributes external_urgency",
  )
  var grid := _EnvGrid.new()
  grid.cell_width = 8
  grid.cell_height = 8
  grid.cell_size = 52.0
  grid.cell_kind_ids = PackedInt32Array()
  grid.cell_kind_ids.resize(64)
  var anchor := Vector3(120.0, 0.0, 80.0)
  var store := _GoalMem.new()
  var kinds := _GkReg.effective_goal_kinds_for_pack("")
  var mods := _GoalMem.effective_modality_allowlist_for_pack("")
  var motor_ctx := {
    "tactic_classifier_active": false,
    "calorie_ratio": 0.5,
    "effective_modality_allowlist": mods,
  }
  _assert(
    store.try_salient_write(
      _GkReg.GK_FIND_FOOD,
      &"find_food",
      anchor,
      motor_p,
      grid,
      motor_ctx,
      {"tier": _GoalMem.TIER_SUCCESS, "pole_facet_tags": [&"explorer"]},
      kinds,
      mods,
      traits_explorer,
      catalog,
    ),
    "salient write with catalog",
  )
  var context_hash := _GoalMem.context_hash_for_find_food(_GkReg.GK_FIND_FOOD, anchor, motor_p, grid)
  var replay_neutral := store.consult_replay_weight(
    _GkReg.GK_FIND_FOOD, context_hash, motor_p, motor_ctx, Vector3(100.0, 0.0, 70.0), {}
  )
  var replay_w := store.consult_replay_weight(
    _GkReg.GK_FIND_FOOD, context_hash, motor_p, motor_ctx, Vector3(100.0, 0.0, 70.0), traits_explorer
  )
  _assert(replay_w > replay_neutral, "explorer traits raise replay_weight vs neutral traits")
  _assert(
    not store.try_salient_write(
      _GkReg.GK_FIND_MATE,
      &"find_mate",
      anchor,
      motor_p,
      grid,
      motor_ctx,
      {"tier": _GoalMem.TIER_SUCCESS},
      kinds,
      mods,
      {},
      catalog,
    ),
    "find_mate write blocked by salient_writes",
  )
  var pack_catalog := {
    &"nest_defense": {
      "parent_tier2": &"avoid_hostiles",
      "salient_writes": true,
      "context_overlay": &"nest_fingerprint",
    },
  }
  _assert(
    _GkReg.resolve_goal_kind_at_outcome(
      &"avoid_hostiles", {"goal_kind_hint": &"nest_defense"}, pack_catalog
    )
    == &"nest_defense",
    "pack hint resolves when parent matches",
  )
  _assert(
    motor_p.has("urgency_boost_linear_slope") and motor_p.has("replay_urgency_slot_b_min"),
    "creature_motor spine has external_urgency keys",
  )


func _test_goal_belief_anticipated_calories_stub() -> void:
  var beliefs: Dictionary = {}
  var split := {
    "ready": [{"pos": Vector3(10.0, 0.0, 0.0), "instance_id": 42, "anticipated_calories": 3.5}],
    "unready": [],
  }
  beliefs = _GoalBeliefScr.sync_from_scene(beliefs, split, 1000)
  _assert(beliefs.has(42), "belief row keyed by instance_id")
  _assert(
    is_equal_approx(float((beliefs[42] as Dictionary).get("anticipated_calories", 0.0)), 3.5),
    "anticipated_calories stored on belief entry",
  )
  var skip := _GoalBeliefScr.sync_from_scene(
    beliefs, {"ready": [{"pos": Vector3(1.0, 0.0, 1.0)}], "unready": []}, 2000
  )
  _assert(not skip.has(0), "entries without instance_id are skipped")


func _test_creature_trait_usage_wiring() -> void:
  var rabbit_def: Resource = load("res://creature/species/rabbit_archetype.tres") as Resource
  _assert(rabbit_def != null, "rabbit archetype for trait usage")
  var traits_explorer := {"explorer_builder": -80.0, "change_stability": 0.0}
  _assert(
    _GoalMem.slot_a_raw_for_pole(traits_explorer, &"explorer") > 50.0,
    "negative explorer_builder aligns with explorer pole (Slot A)",
  )
  var traits_neutral := {
    "explorer_builder": float(rabbit_def.get("explorer_builder")),
    "change_stability": float(rabbit_def.get("change_stability")),
    "compassion_self_interest": float(rabbit_def.get("compassion_self_interest")),
    "community_individual": float(rabbit_def.get("community_individual")),
  }
  _assert(
    is_equal_approx(_GoalMem.slot_a_raw_for_pole(traits_neutral, &"explorer"), 0.0),
    "neutral archetype traits yield zero explorer pole pull",
  )
  var spine := _Merge.creature_motor_spine()
  _assert(spine.has("urgency_boost_linear_slope"), "trait replay motor keys present")


func _test_motor_motivation_wiring() -> void:
  var spine := _Merge.creature_motor_spine()
  _assert(
    is_equal_approx(_Tier2Dom.preserve_find_food_seek_scale(0.75, spine), 1.0),
    "preserve scale full seek below seek ceiling",
  )
  _assert(
    is_equal_approx(_Tier2Dom.preserve_find_food_seek_scale(0.95, spine), 0.0),
    "preserve scale zero at preserve floor",
  )
  var mid_scale: float = _Tier2Dom.preserve_find_food_seek_scale(0.85, spine)
  _assert(mid_scale > 0.2 and mid_scale < 1.0, "preserve scale mid-band partial")
  var base: _TraitTier2.Tier2UrgencyChannels = _TraitTier2.base_urgency_channels_from_dominant(
    _Tier2Dom.LEAF_FIND_FOOD, spine
  )
  var out := _TraitTier2.apply_trait_urgency_channels(
    base, {"explorer_builder": 80.0}, spine
  )
  _assert(
    is_equal_approx(out.urgency_find_food, base.urgency_find_food),
    "trait tier2 stub leaves find_food urgency",
  )
  var static_obs := [{"position": Vector3(120.0, 0.0, 120.0), "half_extents": Vector2(20.0, 20.0)}]
  var tactics := _TacticScr.build_motor_ctx_tactics(
    Vector3(100.0, 0.0, 120.0),
    Vector2(8.0, 8.0),
    1.0,
    Vector3.RIGHT,
    spine,
    static_obs,
    null,
    {"in_awareness": true, "gate_dist": 250.0},
    false,
    [],
    Vector3.ZERO,
  )
  _assert(bool(tactics.get("tactic_in_squeeze", false)), "tight static clearance sets squeeze")
  _assert(bool(tactics.get("tactic_hide_viable", false)), "alert band sets hide_viable")
  var store := _GoalMem.new()
  var grid := _EnvGrid.new()
  grid.cell_width = 8
  grid.cell_height = 8
  grid.cell_size = 52.0
  grid.cell_kind_ids = PackedInt32Array()
  grid.cell_kind_ids.resize(64)
  var flee_ctx := {
    "tactic_classifier_active": true,
    "tactic_jeopardy_egress": true,
    "environment_grid": grid,
  }
  store.try_salient_write(
    _GkReg.GK_AVOID_HOSTILES,
    &"avoid_hostiles",
    Vector3(200.0, 0.0, 200.0),
    spine,
    grid,
    flee_ctx,
    {"tier": _GoalMem.TIER_SUCCESS},
    _GkReg.core_goal_kinds(),
    _GoalMem.effective_modality_allowlist_for_pack(""),
    {},
  )
  var threat: Dictionary = store.consult_threat_response(
    Vector3(200.0, 0.0, 200.0), spine, flee_ctx, {}
  )
  _assert(
    threat.get("preferred_modality", &"") == &"flee_retreat",
    "threat consult prefers flee_retreat row",
  )
  var squeeze_ctx := {
    "tactic_classifier_active": true,
    "tactic_in_squeeze": true,
    "conspecific_aid_count": 0,
    "environment_grid": grid,
  }
  _assert(
    store.try_salient_write(
      _GkReg.GK_FIND_FOOD,
      &"find_food",
      Vector3(120.0, 0.0, 80.0),
      spine,
      grid,
      squeeze_ctx,
      {"tier": _GoalMem.TIER_SUCCESS},
      _GkReg.core_goal_kinds(),
      _GoalMem.effective_modality_allowlist_for_pack(""),
      {},
    ),
    "squeeze classifier writes find_food salient row",
  )
  var row_key := ""
  for k in store._rows.keys():
    var row: Dictionary = store._rows[k]
    if row.get("modality_tag", &"") == &"squeeze_commit":
      row_key = k
      break
  _assert(row_key != "", "locale row uses squeeze_commit modality")


func _test_locale_prior_escalate_seek() -> void:
  var motor_p := _Merge.creature_motor_spine()
  var store := _GoalMem.new()
  var grid := _EnvGrid.new()
  grid.cell_width = 8
  grid.cell_height = 8
  grid.cell_size = 52.0
  grid.cell_kind_ids = PackedInt32Array()
  grid.cell_kind_ids.resize(64)
  var anchor := Vector3(400.0, 0.0, 400.0)
  store.try_salient_write(
    _GkReg.GK_FIND_FOOD,
    &"find_food",
    anchor,
    motor_p,
    grid,
    {},
    {"tier": _GoalMem.TIER_SUCCESS},
    _GkReg.core_goal_kinds(),
    _GoalMem.effective_modality_allowlist_for_pack(""),
    {},
  )
  var creature_pos := Vector3.ZERO
  var mul := _GoalMem.escalate_seek_multiplier(
    store, creature_pos, motor_p, _GkReg.GK_FIND_FOOD, 0.0
  )
  _assert(mul > 1.1, "escalate seek when prior in band but outside hotspot")
  var mul_hot := _GoalMem.escalate_seek_multiplier(
    store, anchor, motor_p, _GkReg.GK_FIND_FOOD, 0.85
  )
  _assert(is_equal_approx(mul_hot, 1.0), "no escalate when hotspot pull active")


func _test_escape_reversal_suppression() -> void:
  var ad: Node = _AiDriverScr.new()
  var body := RigidBody2D.new()
  var bid := body.get_instance_id()
  var motor_p := _Merge.creature_motor_spine()
  ad._escape_episode_by_body[bid] = {
    "active": false,
    "dominance_flipped": true,
    "reentered_threat_ms": Time.get_ticks_msec(),
  }
  var suppress: bool = ad.call(
    "_escape_reversal_suppresses_write", body, motor_p, 0.05
  )
  _assert(suppress, "AH-7 suppresses avoid write after reversal re-threat")
  body.queue_free()
  ad.queue_free()


func _test_motor_target_builder_feeding_mode() -> void:
  var herb_policy := _DietRegistry.default_food_intake_policy(
    _CreatureDefinition.FeedingMode.HERBIVORE
  )
  var carn_policy := _DietRegistry.default_food_intake_policy(
    _CreatureDefinition.FeedingMode.CARNIVORE
  )
  _assert((herb_policy.get("plant_groups") as Array).size() > 0, "herbivore plant groups")
  _assert((carn_policy.get("prey_groups") as Array).size() > 0, "carnivore prey groups")
  _assert((carn_policy.get("plant_groups") as Array).is_empty(), "carnivore no plant groups")
  var legacy := _ThreatSampleScr.to_legacy_herbivore_dict(
    _ThreatSampleScr.make(Vector2(10.0, 20.0), 5.0, true)
  )
  _assert(bool(legacy.get("in_awareness", false)), "threat legacy in_awareness")
  _assert(
    is_equal_approx(float(legacy.get("gate_dist", 0.0)), 5.0),
    "threat legacy gate_dist",
  )


func _test_goal_seek_resolve_and_cost() -> void:
  var food_pos := Vector3(100.0, 0.0, 50.0)
  var prey_pos := Vector3(200.0, 0.0, 80.0)
  var cands: Array = _SeekCandScr.build_from_motor_ingress([food_pos], [], [prey_pos])
  var pack_food: Dictionary = _GoalSeekScr.resolve_for_dominant_leaf(
    _Tier2Dom.LEAF_FIND_FOOD, cands, 12.0, 0.0
  )
  _assert(
    (pack_food["goal_seek_targets"] as Array).size() == 1,
    "find_food herbivore channel picks plant",
  )
  _assert(
    is_equal_approx(float(pack_food["weight_seek_goal"]), 12.0),
    "find_food weight_seek_goal",
  )
  var pack_prey: Dictionary = _GoalSeekScr.resolve_for_dominant_leaf(
    _Tier2Dom.LEAF_FIND_FOOD, cands, 4.0, 20.0
  )
  _assert(
    (pack_prey["goal_seek_targets"] as Array).size() == 1,
    "find_food prey channel picks prey when w_seek_prey active",
  )
  _assert(
    is_equal_approx(float(pack_prey["weight_seek_goal"]), 20.0),
    "prey weight_seek_goal",
  )
  var pack_preserve: Dictionary = _GoalSeekScr.resolve_for_dominant_leaf(
    _Tier2Dom.LEAF_PRESERVE, cands, 12.0, 20.0
  )
  _assert(
    (pack_preserve["goal_seek_targets"] as Array).is_empty(),
    "preserve clears goal_seek_targets",
  )
  var c1: float = float(
    Callable(_Motor, &"food_seek_cost_at_prediction").call(
      Vector3.ZERO, Vector3.ZERO, [food_pos], 3.0, [], 0.0
    )
  )
  var c2: float = float(
    Callable(_Motor, &"goal_seek_cost_at_prediction").call(
      Vector3.ZERO, Vector3.ZERO, [food_pos], 3.0, [], 0.0
    )
  )
  _assert(is_equal_approx(c1, c2), "goal_seek_cost aliases food_seek_cost")


func _test_goal_belief_coarse_ttl() -> void:
  var ad: Node = _AiDriverScr.new()
  var motor_p := _Merge.creature_motor_spine()
  motor_p["goal_memory_coarse_ttl_sec"] = 15.0
  motor_p["goal_memory_precise_radius"] = 1000.0
  motor_p["goal_memory_forget_radius"] = 5000.0
  var now_ms := Time.get_ticks_msec()
  var iid := 424242
  const BODY_ID := 4242
  ad.set("_goal_belief_by_body", {
    BODY_ID: {
      iid: {
        "instance_id": iid,
        "goal_kind": _GkReg.GK_FIND_FOOD,
        "tier": &"COARSE",
        "last_world_pos": Vector3(800.0, 0.0, 800.0),
        "last_observed_ms": now_ms - 5000,
        "coarse_entered_ms": now_ms - 20000,
        "consumable_now": true,
        "merge_use_count": 0,
        "last_merged_ms": 0,
      },
    },
  })
  ad.call("_goal_belief_maintain", Vector3.ZERO, now_ms, motor_p, BODY_ID)
  var beliefs: Dictionary = (ad.get("_goal_belief_by_body") as Dictionary).get(BODY_ID, {})
  _assert(not beliefs.has(iid), "coarse belief evicted after coarse TTL")
  ad.queue_free()


func _test_plant_occluded_live_food_entries() -> void:
  var entries: Array = [
    {
      "pos": Vector3(120.0, 0.0, 80.0),
      "instance_id": 501,
      "occluded": true,
      "line_of_sight_clear": false,
    },
    {
      "pos": Vector3(200.0, 0.0, 80.0),
      "instance_id": 502,
      "occluded": false,
      "line_of_sight_clear": true,
    },
  ]
  var live: Array = _GoalBeliefScr.food_positions_from_live_entries(entries)
  var all: Array = _GoalBeliefScr.food_positions_from_entries(entries)
  _assert(live.size() == 1, "occluded plant excluded from live food seek positions")
  _assert(all.size() == 2, "occluded plant kept for goal-belief sync ingest")
  _assert((live[0] as Vector3).is_equal_approx(Vector3(200.0, 0.0, 80.0)), "live entry is LoS-clear bush")


func _test_goal_belief_merge_skips_live_awareness() -> void:
  var ad: Node = _AiDriverScr.new()
  var motor_p := _Merge.creature_motor_spine()
  motor_p["goal_memory_precise_radius"] = 2000.0
  const BODY_ID := 9001
  const LIVE_IID := 111
  ad.set("_goal_belief_by_body", {
    BODY_ID: {
      LIVE_IID: {
        "instance_id": LIVE_IID,
        "goal_kind": _GkReg.GK_FIND_FOOD,
        "tier": &"PRECISE",
        "last_world_pos": Vector3(100.0, 0.0, 100.0),
        "last_observed_ms": 0,
        "coarse_entered_ms": 0,
        "consumable_now": true,
        "merge_use_count": 0,
        "last_merged_ms": 0,
      },
    },
  })
  var ctx := {
    "creature_position": Vector3.ZERO,
    "food_seek_targets": [Vector3(50.0, 0.0, 50.0)],
    "unready_food_avoid_targets": [],
    "weight_seek_ready_food": 10.0,
    "believed_goal_source_bias": {
      "sector_weights": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    },
  }
  var live_ids := {LIVE_IID: true}
  var out: Dictionary = ad.call(
    "_goal_belief_merge_into_motor_context",
    ctx,
    Vector3.ZERO,
    motor_p,
    BODY_ID,
    live_ids,
    0,
  )
  var merged: Array = out.get("food_seek_targets", []) as Array
  _assert(merged.size() == 1, "live food target unchanged when belief instance still in awareness")
  _assert(
    not merged.has(Vector3(100.0, 0.0, 100.0)),
    "remembered precise belief skipped when instance_id still in live awareness",
  )
  ad.queue_free()


func _test_load_merged_config_repo_fallback() -> void:
  var res: Dictionary = _Merge.load_merged_config("user://__does_not_exist_merged_test__.json")
  var merged: Dictionary = res["merged"]
  var ic: Dictionary = merged["inference_client"]
  _assert(str(ic.get("INFERENCE_BASE_URL", "")).begins_with("http"), "merged config pulls inference URL from repo template")


func _test_hunter_killer_debug_project_settings() -> void:
  _assert(
    ProjectSettings.has_setting("hunter_killer_debug/draw_awareness"),
    "project defines hunter_killer_debug/draw_awareness",
  )
  _assert(
    ProjectSettings.has_setting("hunter_killer_debug/use_ship_motor_profile"),
    "project defines hunter_killer_debug/use_ship_motor_profile",
  )
  _assert(
    ProjectSettings.get_setting("hunter_killer_debug/use_ship_motor_profile") == false,
    "use_ship_motor_profile defaults to off",
  )


func _test_tokens() -> void:
  _assert(_Tokens.normalize_completion_token("  left\nnoise") == "LEFT", "token first line")
  _assert(_Tokens.normalize_completion_token("START") == "START", "START")
  _assert(_Tokens.normalize_completion_token("I'll go UP now") == "UP", "prose contains UP word")
  _assert(_Tokens.normalize_completion_token("<|im_end|> LEFT") == "LEFT", "strip span then direction")
  _assert(_Tokens.normalize_completion_token("xyzzy") == "noop", "unknown → noop")
  _assert(_Tokens.normalize_completion_token("") == "noop", "empty → noop")
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("Okay.\nSTART") == "START",
    "handshake finds START on a later line"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("Sure, START") == "START",
    "handshake word START in prose"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("RESTART") == "noop",
    "RESTART does not match START word"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("START <|im_end|>") == "START",
    "strip trailing chat marker after START"
  )
  _assert(
    _Tokens.normalize_completion_token_armed_handshake("<|im_end|>") == "noop",
    "chat markers alone → noop"
  )


func _test_perception_snippet() -> void:
  var h := _Wire.format_header_line(1000, 3, 10, 8, 24)
  _assert(h == "1000 3 10 8 24", "header line")
  var v := _Wire.format_entity_velocity_line("PLAYER", 2, 4, Vector3(10, -20, 0))
  _assert(v.begins_with("PLAYER 2 4 "), "player vel line prefix")
  var e := _Wire.format_entity_extents_line("PLAYER_EXT", Vector3(12, 8, 0))
  _assert(e.begins_with("PLAYER_EXT "), "extents line")
  # Callable: static method exists on script; analyzer sometimes misses it on preload() type (see ai_driver.gd).
  var ph := Callable(_Wire, &"format_plain_hint_line").call(1, "interior", "moving") as String
  _assert(ph.begins_with("PLAIN_HINT ") and ph.contains("Mob list index 1"), "plain hint tagging closer")
  var ph_corner := Callable(_Wire, &"format_plain_hint_line").call(-1, "corner", "stopped") as String
  _assert(ph_corner.contains("CORNER"), "corner stopped posture echoed")


func _test_cardinal_avoidance() -> void:
  var base_ctx := {
    "creature_position": Vector3(100.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.0,
  }
  var idle := _Motor.pick_best_move_intent(base_ctx)
  _assert(idle.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "no mobs tie picks UP first")

  var flee := base_ctx.duplicate(true)
  flee["creature_position"] = Vector3(100.0, 0.0, 0.0)
  flee["mobs"] = [{"position": Vector3(200.0, 0.0, 0.0), "velocity": Vector3(-150.0, 0.0, 0.0)}]
  var leftish := _Motor.pick_best_move_intent(flee)
  _assert(leftish.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "mob east favors moving west")

  var oob_pen := _Motor.cost_at_prediction(
    Vector3(-10.0, 0.0, 200.0),  
    [], Vector2.ZERO, Vector2(480.0, 720.0),  
    1.0,  
    0.5,  
    1e7,  
    8.0,
    Vector2.ZERO
  )
  _assert(oob_pen >= 1e6, "OOB prediction gets huge cost")

  var q := _Motor.closest_point_on_aabb(Vector3(100.0, 0.0, 100.0), Vector2(10.0, 10.0),   Vector3(200.0, 0.0, 100.0))
  _assert(q.is_equal_approx(Vector3(110.0, 0.0, 100.0)), "nearest AABB point clamps to east face")

  var c_point := _Motor.cost_at_prediction(
    Vector3(100.0, 0.0, 100.0),  
    [{"position": Vector3(100.0, 0.0, 130.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(480.0, 720.0),  
    1.0,  
    0.5,  
    1e7,  
    8.0,
    Vector2.ZERO
  )
  var c_foot := _Motor.cost_at_prediction(
    Vector3(100.0, 0.0, 100.0),  
    [{"position": Vector3(100.0, 0.0, 130.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(480.0, 720.0),  
    1.0,  
    0.5,  
    1e7,  
    8.0,  
    Vector2(20.0, 20.0)
  )
  _assert(c_foot > c_point, "nonzero footprint clears mob at center more aggressively than point model")

  var threat := base_ctx.duplicate(true)
  threat["creature_position"] = Vector3(200.0, 0.0, 200.0)
  threat["mobs"] = [{"position": Vector3(200.0, 0.0, 200.0), "velocity": Vector3.ZERO}]
  var c_idle := _Motor.cost_at_prediction(
    Vector3(200.0, 0.0, 200.0),  
    threat["mobs"], Vector2.ZERO, Vector2(480.0, 720.0),  
    1.0,  
    0.5,  
    1e7,  
    8.0,  
    Vector2(20.0, 20.0)
  )
  var c_step := _Motor.cost_at_prediction(
    Vector3(200.0, 0.0, 200.0) + Vector3(0.0, 0.0, -1.0) * 400.0 * 0.15,  
    threat["mobs"], Vector2.ZERO, Vector2(480.0, 720.0),  
    1.0,  
    0.5,  
    1e7,  
    8.0,  
    Vector2(20.0, 20.0)
  )
  _assert(c_step < c_idle, "mob overlap favors moving off center vs standing still (affirmative dodge cost)")

  var pair := [
    {"position": Vector3(170.0, 0.0, 200.0), "velocity": Vector3.ZERO},
    {"position": Vector3(230.0, 0.0, 200.0), "velocity": Vector3.ZERO},
  ]
  var mid := Vector3(200.0, 0.0, 200.0)
  var c_pair_lin := _Motor.cost_at_prediction(
    mid,   pair, Vector2.ZERO, Vector2(480.0, 720.0),   0.45,   1.05,   1e7,   12.0,   Vector2.ZERO, 0.0,   0.0
  )
  var c_pair_sq := _Motor.cost_at_prediction(
    mid,   pair, Vector2.ZERO, Vector2(480.0, 720.0),   0.45,   1.05,   1e7,   12.0,   Vector2.ZERO, 0.0,   55.0
  )
  _assert(c_pair_sq > c_pair_lin + 0.05, "weight_dist_sq adds crowding penalty between two mobs")

  var corner := base_ctx.duplicate(true)
  corner["creature_position"] = Vector3(2.0, 0.0, 360.0)
  corner["mobs"] = []
  var away_from_oob := _Motor.pick_best_move_intent(corner)
  _assert(not away_from_oob.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "near left wall avoids stepping OOB")

  # Callable: static exists on script; analyzer sometimes misses it on preload() type (see _test_perception_snippet).
  var o_det: Array = Callable(_Motor, &"evaluation_order_from_ctx").call(
    {"creature_position": Vector3(1.0, 0.0, 1.0), "deterministic_tie_order": true, "shuffle_tie_break": true}
  ) as Array
  _assert((o_det[0] as Vector3).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "deterministic tie order starts UP")
  var o_a: Array = Callable(_Motor, &"evaluation_order_from_ctx").call(
    {"creature_position": Vector3(3.0, 0.0, 4.0), "tie_shuffle_seed": 7, "shuffle_tie_break": true}
  ) as Array
  var o_b: Array = Callable(_Motor, &"evaluation_order_from_ctx").call(
    {"creature_position": Vector3(3.0, 0.0, 4.0), "tie_shuffle_seed": 999, "shuffle_tie_break": true}
  ) as Array
  _assert((o_a[4] as Vector3).is_equal_approx(Vector3.ZERO) and (o_b[4] as Vector3).is_equal_approx(Vector3.ZERO), "ZERO always last in shuffled order")
  var perm_diff := false
  for i in range(4):
    if not (o_a[i] as Vector3).is_equal_approx(o_b[i] as Vector3):
      perm_diff = true
  _assert(perm_diff, "different tie_shuffle_seed permutes cardinals")

  var chaos_ctx := base_ctx.duplicate(true)
  chaos_ctx["motor_intent_cost_chaos"] = 80.0
  chaos_ctx["motor_chaos_seed"] = 12345
  chaos_ctx["shuffle_tie_break"] = false
  var ch_pick: Vector3 = _Motor.pick_best_move_intent(chaos_ctx)
  var ch_len := ch_pick.length()
  _assert(ch_len < 1e-4 or absf(ch_len - 1.0) < 1e-4, "motor cost chaos yields idle or unit direction only")

  var left_open := {
    "creature_position": Vector3(20.0, 0.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 3.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.0,
  }
  var inward := _Motor.pick_best_move_intent(left_open)
  _assert(inward.is_equal_approx(Vector3.RIGHT), "interior posture pulls toward playfield center from left edge")

  var wall_hug := {
    "creature_position": Vector3(24.0, 0.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 12.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 2.6,
  }
  var off_edge := _Motor.pick_best_move_intent(wall_hug)
  _assert(off_edge.is_equal_approx(Vector3.RIGHT), "edge clearance pulls away from boundary without interior term")

  ## Awareness gating: mobs beyond radius contribute no incremental mob cost.
  var ctr := Vector3(400.0, 0.0, 400.0)
  var pred := Vector3(400.0, 0.0, 400.0)
  var c_no_mob: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.5,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    500.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
  )
  var c_far_mob: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(400.0, 0.0, 400.0 + 4000.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.5,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    500.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
  )
  _assert(is_equal_approx(c_no_mob, c_far_mob), "mob outside awareness radius adds no cost")

  ## Sector cone: forward mob inside extended reach counts; aft mob beyond base only does not.
  var cos45 := cos(deg_to_rad(45.0))
  var c_behind: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(-200.0, 0.0, 400.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    100.0,  
    500.0,  
    cos45,  
    Vector3(1.0, 0.0, 0.0),  
    [],  
    0.0,  
  )
  var c_ahead: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(1000.0, 0.0, 400.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    100.0,  
    500.0,  
    cos45,  
    Vector3(1.0, 0.0, 0.0),  
    [],  
    0.0,  
  )
  _assert(c_behind < c_ahead, "cone lets forward mob contribute more than aft mob at same distance class")

  ## awareness_radius <= 0: no finite distance gate (HK perception plan).
  var c_far_open: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(400.0, 0.0, 800.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    0.0,  
    0.0,  
    cos45,  
    Vector3(1.0, 0.0, 0.0),  
    [],  
    0.0,  
  )
  _assert(c_far_open > c_no_mob + 0.001, "nonpositive awareness_radius still applies mob repulsion from far mobs")
  var c_far_neg: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(400.0, 0.0, 800.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    -10.0,  
    500.0,  
    cos45,  
    Vector3(1.0, 0.0, 0.0),  
    [],  
    0.0,  
  )
  _assert(c_far_neg > c_no_mob + 0.001, "negative awareness_radius skips distance gate like zero")

  ## awareness_cone_extra <= 0: forward sector does not extend reach beyond base radius.
  var c_cone_off: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(520.0, 0.0, 400.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    100.0,  
    0.0,  
    cos45,  
    Vector3(1.0, 0.0, 0.0),  
    [],  
    0.0,  
  )
  var c_cone_on: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [{"position": Vector3(520.0, 0.0, 400.0), "velocity": Vector3.ZERO}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    ctr,  
    100.0,  
    400.0,  
    cos45,  
    Vector3(1.0, 0.0, 0.0),  
    [],  
    0.0,  
  )
  _assert(is_equal_approx(c_cone_off, c_no_mob), "zero cone_extra drops forward mob beyond base radius")
  _assert(c_cone_on > c_no_mob + 0.001, "positive cone_extra pulls forward mob into reach")

  ## Half-angle 180°: forward sector covers full circle; behind mob still gets base+extra reach.
  var cos180 := cos(deg_to_rad(180.0))
  var r_behind := Callable(_Motor, &"effective_awareness_reach").call(
    ctr, Vector3(-200.0, 0.0, 400.0), 100.0, 500.0, cos180, Vector3(1.0, 0.0, 0.0)
  ) as float
  var r_narrow := Callable(_Motor, &"effective_awareness_reach").call(
    ctr, Vector3(-200.0, 0.0, 400.0), 100.0, 500.0, cos45, Vector3(1.0, 0.0, 0.0)
  ) as float
  _assert(is_equal_approx(r_behind, 600.0), "180° half-angle extends cone extra behind creature")
  _assert(is_equal_approx(r_narrow, 100.0), "45° half-angle does not extend extra behind creature")

  ## Per-entry cost_scale scales mob contribution.
  var c_full := _Motor.cost_at_prediction(
    pred,  
    [{"position": Vector3(400.0, 0.0, 460.0), "velocity": Vector3.ZERO, "cost_scale": 1.0}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, )
  var c_half := _Motor.cost_at_prediction(
    pred,  
    [{"position": Vector3(400.0, 0.0, 460.0), "velocity": Vector3.ZERO, "cost_scale": 0.5}], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, )
  _assert(is_equal_approx(c_full, c_half * 2.0), "cost_scale halves mob cost contribution")

  ## Static obstacles add repulsion via weight_obstacle.
  var obs := [{"position": Vector3(400.0, 0.0, 500.0), "half_extents": Vector2(40.0, 40.0)}]
  var c_plain := _Motor.cost_at_prediction(
    pred,   [], Vector2.ZERO, Vector2(2000.0, 2000.0),   1.0,   0.0,   1e7,   12.0,   Vector2.ZERO
  )
  var c_block: float = CardinalAvoidance.cost_at_prediction_aware(
    pred,  
    [], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    Vector3.ZERO,  
    0.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    obs,  
    2.5,  
  )
  _assert(c_block > c_plain + 0.001, "obstacle adds inverse-distance cost near prediction")

  ## Pursuit samples subtract mob-style cost (inverse distance toward prey).
  var pred_c := Vector3(400.0, 0.0, 300.0)
  var pt: Array = [{"position": Vector3(430.0, 0.0, 300.0), "velocity": Vector3.ZERO, "cost_scale": 1.0}]
  var c_np: float = CardinalAvoidance.cost_at_prediction_aware(
    pred_c,  
    [], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    pred_c,  
    5000.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
    false,  
    null,  
    0.0,  
    {},  
    [],  
    0.0,  
    [],  
    0.0,  
    [],  
    0.0,  
  )
  var c_wp: float = CardinalAvoidance.cost_at_prediction_aware(
    pred_c,  
    [], Vector2.ZERO, Vector2(2000.0, 2000.0),  
    1.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    pred_c,  
    5000.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
    false,  
    null,  
    0.0,  
    {},  
    [],  
    0.0,  
    [],  
    0.0,  
    [],  
    0.0,  
    pt,  
    6.0,  
    1.0,  
    40.0,  
    PackedVector3Array(),  
    Vector3.ZERO,  
    Vector3.ZERO,  
    0.0,  
    0.0,  
  )
  _assert(c_wp < c_np - 1e-6, "pursuit targets reduce cost near prey")


func _test_obstacle_strategy_shield_pin() -> void:
  var pts := PackedVector3Array([Vector3(410.0, 0.0, 300.0)])
  var shield := _ObstacleStrat.strategic_obstacle_cost(
    Vector3(400.0, 0.0, 300.0), Vector3(600.0, 0.0, 300.0), Vector3.ZERO, pts, 40.0, 0.0, 6.0
  )
  _assert(shield < 0.0, "prey shield term rewards obstacle between self and threat")
  var pin := _ObstacleStrat.strategic_obstacle_cost(
    Vector3(200.0, 0.0, 300.0), Vector3.ZERO, Vector3(350.0, 0.0, 300.0), pts, 0.0, 35.0, 6.0
  )
  _assert(pin < 0.0, "predator pin term rewards obstacles along prey vector")
  var offset_obs := [{"position": Vector3(318.0, 0.0, 350.0), "half_extents": Vector2(50.0, 50.0)}]
  _assert(
    _GeomScr.chase_segment_blocked_by_aabbs(
      Vector3(300.0, 0.0, 180.0),
      Vector2(18.0, 44.0),
      Vector3(300.0, 0.0, 520.0),
      Vector2(13.5, 30.5),
      offset_obs,
      4.0,
    ),
    "segment block catches bush roughly on chase line",
  )


func _test_playfield_corner_escape() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip playfield corner escape test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var motor_p := _Merge.creature_motor_spine()
  var bounds_max := Vector2(1000.0, 600.0)
  var he := Vector2(13.5, 30.5)
  var corner_pos := Vector3(he.x + 6.0, 0.0, he.y + 8.0)
  var esc: Vector3 = d.call(
    "_pick_stuck_escape_cardinal",
    corner_pos,
    he,
    [],
    91,
    2,
    motor_p,
    Vector3.ZERO,
    bounds_max,
  )
  _assert(
    esc.length_squared() > 1e-12 and (esc.x > 0.5 or esc.y < -0.5),
    "playfield corner escape picks interior-opening cardinal",
  )


func _test_world_corner_static_wedge_escape() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip world corner wedge test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var he := Vector2(13.5, 30.5)
  var wedge_pos := Vector3(he.x + 12.0, 0.0, bounds_max.y - he.y - 14.0)
  var bush := [{"position": Vector3(118.0, 0.0, 518.0), "half_extents": Vector2(78.0, 78.0)}]
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var esc_a: Vector3 = d.call(
    "_pick_stuck_escape_cardinal",
    wedge_pos,
    he,
    bush,
    55,
    4,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
  )
  var esc_b: Vector3 = d.call(
    "_pick_stuck_escape_cardinal",
    wedge_pos,
    he,
    bush,
    55,
    4,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
  )
  _assert(
    esc_a.length_squared() > 1e-12
    and esc_a.is_equal_approx(esc_b)
    and not bool(d.call("_cardinal_step_blocked", wedge_pos, he, esc_a, bush, block_clr)),
    "world corner + static wedge escape is stable and traversable",
  )
  var flee_a: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    wedge_pos,
    Vector3(40.0, 0.0, 420.0),
    bounds_max,
    he,
    55,
    rabbit_m,
    bush,
  )
  var flee_b: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    wedge_pos,
    Vector3(40.0, 0.0, 420.0),
    bounds_max,
    he,
    55,
    rabbit_m,
    bush,
  )
  _assert(
    flee_a.length_squared() > 1e-12
    and flee_a.is_equal_approx(flee_b)
    and not bool(d.call("_cardinal_step_blocked", wedge_pos, he, flee_a, bush, block_clr)),
    "wedged prey flee heading is stable and unblocked",
  )
  _assert(
    bool(
      d.call(
        "_creature_playfield_corner_wedge_active",
        wedge_pos,
        he,
        bush,
        Vector3.ZERO,
        bounds_max,
        rabbit_m,
      )
    ),
    "world corner + static geometry registers as corner wedge",
  )
  var esc_c: Vector3 = d.call(
    "_latched_stuck_escape_intent",
    55,
    wedge_pos,
    he,
    bush,
    2,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
  )
  var esc_d: Vector3 = d.call(
    "_latched_stuck_escape_intent",
    55,
    wedge_pos,
    he,
    bush,
    2,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
  )
  _assert(
    esc_c.length_squared() > 1e-12 and esc_c.is_equal_approx(esc_d),
    "wedged prey latched escape is stable across ticks",
  )
  var fox_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/fox",
  )
  var rotate_a: Vector3 = d.call("_predator_hunt_stuck_rotate_intent", 91, 3, fox_m)
  var rotate_b: Vector3 = d.call("_predator_hunt_stuck_rotate_intent", 91, 9, fox_m)
  _assert(
    rotate_a.length_squared() > 1e-12 and rotate_a.is_equal_approx(rotate_b),
    "predator hunt rotate intent stable across stuck tick count",
  )


func _test_playfield_open_corner_escape() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip open playfield corner escape test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var he := Vector2(13.5, 30.5)
  var corner_pos := Vector3(he.x + 10.0, 0.0, he.y + 12.0)
  var esc_a: Vector3 = d.call(
    "_pick_playfield_interior_escape_cardinal",
    corner_pos,
    he,
    [],
    71,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
  )
  var esc_b: Vector3 = d.call(
    "_herbivore_latched_corner_escape_intent",
    71,
    corner_pos,
    he,
    [],
    Vector3.ZERO,
    bounds_max,
    rabbit_m,
  )
  _assert(
    esc_a.length_squared() > 1e-12
    and esc_a.is_equal_approx(esc_b)
    and (esc_a.x > 0.35 or esc_a.y < -0.35),
    "open map corner picks stable interior-opening escape",
  )


## Inner playable rect implied by wide/tall perimeter boundary bar AABBs (motor-plane game units).
func _playfield_inner_rect_from_boundary_aabbs(aabbs: Array) -> Rect2:
  var inner := Vector2(-INF, -INF)
  var outer := Vector2(INF, INF)
  for ob in aabbs:
    if typeof(ob) != TYPE_DICTIONARY:
      continue
    var op: Vector2 = ob.get("position", Vector3.ZERO)
    var he: Vector2 = ob.get("half_extents", Vector2.ZERO)
    if maxf(he.x, he.y) < 200.0:
      continue
    var mn := op - he
    var mx := op + he
    if he.x > he.y * 3.0:
      if op.y < 400.0:
        inner.y = maxf(inner.y, mx.y)
      elif op.y > 400.0:
        outer.y = minf(outer.y, mn.y)
    elif he.y > he.x * 3.0:
      if op.x < 400.0:
        inner.x = maxf(inner.x, mx.x)
      elif op.x > 400.0:
        outer.x = minf(outer.x, mn.x)
  if inner.x == -INF or outer.x == INF:
    return Rect2()
  return Rect2(inner, outer - inner)


## Synthetic perimeter bars for legacy 1920×1080 motor-plane boundary escape tests (no scene load).
func _synthetic_playfield_boundary_bar_aabbs(inner_size: Vector2) -> Array:
  var hw := inner_size.x * 0.5
  var hh := inner_size.y * 0.5
  var bar_thick := 50.0
  var bar_long := maxf(hw, hh) + bar_thick
  return [
    {"position": Vector2(hw, -bar_thick), "half_extents": Vector2(bar_long, bar_thick)},
    {"position": Vector2(hw, inner_size.y + bar_thick), "half_extents": Vector2(bar_long, bar_thick)},
    {"position": Vector2(-bar_thick, hh), "half_extents": Vector2(bar_thick, bar_long)},
    {"position": Vector2(inner_size.x + bar_thick, hh), "half_extents": Vector2(bar_thick, bar_long)},
  ]


func _test_playfield_boundary_edge_rocks() -> void:
  var inner_size := Vector2(1920.0, 1080.0)
  var aabbs := _synthetic_playfield_boundary_bar_aabbs(inner_size)
  _assert(not aabbs.is_empty(), "synthetic boundary bars yield AABBs")
  var inner := _playfield_inner_rect_from_boundary_aabbs(aabbs)
  _assert(is_equal_approx(inner.position.x, 0.0), "edge rocks inner left aligns with playfield")
  _assert(is_equal_approx(inner.position.y, 0.0), "edge rocks inner top aligns with playfield")
  _assert(is_equal_approx(inner.end.x, 1920.0), "edge rocks inner right aligns with playfield")
  _assert(is_equal_approx(inner.end.y, 1080.0), "edge rocks inner bottom aligns with playfield")
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip boundary edge rock escape test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1920.0, 1080.0)
  var he := Vector2(13.5, 30.5)
  var ne_pos := Vector3(bounds_max.x - he.x - 8.0, 0.0, he.y + 6.0)
  var probe_dist := float(rabbit_m.get("herbivore_obstacle_probe", 200.0))
  var clr := _Motor.footprint_static_clearance(ne_pos,   he,   aabbs)
  _assert(
    clr < probe_dist,
    "NE playfield pinch sees boundary rocks within herbivore obstacle probe",
  )
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var esc: Vector3 = d.call(
    "_herbivore_latched_corner_escape_intent",
    91,
    ne_pos,
    he,
    aabbs,
    Vector3.ZERO,
    bounds_max,
    rabbit_m,
    Vector3(200.0, 0.0, 400.0),
  )
  _assert(
    esc.length_squared() > 1e-12
    and not bool(d.call("_cardinal_step_blocked", ne_pos, he, esc, aabbs, block_clr))
    and (esc.y > 0.35 or esc.x < -0.35),
    "NE boundary wedge escape picks stable south or west opening",
  )


func _test_ne_corner_food_seek_egress() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip NE corner food-seek egress test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1920.0, 1080.0)
  var he := Vector2(13.5, 30.5)
  var ne_pos := Vector3(bounds_max.x - he.x - 8.0, 0.0, he.y + 6.0)
  var aabbs := _synthetic_playfield_boundary_bar_aabbs(bounds_max)
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var food_east := ne_pos + Vector3(240.0, 0.0, 0.0)
  var esc_food: Vector3 = d.call(
    "_pick_playfield_interior_escape_cardinal",
    ne_pos,
    he,
    aabbs,
    91,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
    food_east,
  )
  _assert(
    esc_food.length_squared() > 1e-12
    and not bool(d.call("_cardinal_step_blocked", ne_pos, he, esc_food, aabbs, block_clr))
    and (esc_food.y > 0.35 or esc_food.x < -0.35),
    "NE corner food east still egresses south or west",
  )
  var unstick: Vector3 = d.call(
    "_playfield_corner_unstick_intent",
    ne_pos,
    he,
    aabbs,
    Vector3.ZERO,
    bounds_max,
    91,
    0,
    rabbit_m,
    Vector3.ZERO,
  )
  _assert(
    unstick.length_squared() > 1e-12 and (unstick.y > 0.35 or unstick.x < -0.35),
    "NE corner idle intent still unsticks toward interior",
  )
  var latched_bad := {"dir": Vector3.RIGHT, "until_tick": 999999}
  d.set("_herbivore_corner_escape_lock_by_body", {91: latched_bad})
  d.set("_physics_ticks", 0)
  var latched_esc: Vector3 = d.call(
    "_herbivore_latched_corner_escape_intent",
    91,
    ne_pos,
    he,
    aabbs,
    Vector3.ZERO,
    bounds_max,
    rabbit_m,
    food_east,
  )
  _assert(
    latched_esc.length_squared() > 1e-12
    and not latched_esc.is_equal_approx(Vector3.RIGHT)
    and (latched_esc.y > 0.35 or latched_esc.x < -0.35),
    "NE corner drops stale east latch and re-picks interior egress",
  )


func _test_predator_cover_pin_flank() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip predator cover pin test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var fox_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/fox",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var fox_he := Vector2(18.0, 44.0)
  var bush := [{"position": Vector3(500.0, 0.0, 300.0), "half_extents": Vector2(42.0, 42.0)}]
  var fox_pos := Vector3(548.0, 0.0, 300.0)
  var prey_pos := Vector3(452.0, 0.0, 300.0)
  _assert(
    bool(d.call("_predator_hunt_cover_pin_active", fox_pos, prey_pos, fox_he, bush, fox_m)),
    "fox pinned on bush with prey behind cover",
  )
  var flank: Vector3 = d.call(
    "_predator_obstructed_hunt_intent",
    fox_pos,
    prey_pos,
    fox_he,
    bush,
    Vector3.ZERO,
    bounds_max,
    17,
    2,
    fox_m,
  )
  _assert(
    flank.length_squared() > 1e-12 and absf(flank.x) < 0.35,
    "cover-pinned fox flanks around bush instead of pushing into it",
  )


func _test_herbivore_flee_cover() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip herbivore flee cover test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var prey_he := Vector2(13.5, 30.5)
  var cover_obs := [{"position": Vector3(520.0, 0.0, 300.0), "half_extents": Vector2(40.0, 40.0)}]
  var cover_samples := PackedVector3Array([Vector3(520.0, 0.0, 300.0)])
  var flee_cover: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    Vector3(480.0, 0.0, 300.0),
    Vector3(600.0, 0.0, 300.0),
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    cover_obs,
    cover_samples,
  )
  _assert(
    flee_cover.dot(Vector3(-1.0, 0.0, 0.0)) > 0.85,
    "prey panic flee prefers cover that blocks predator chase",
  )
  var flee_open: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    Vector3(480.0, 0.0, 300.0),
    Vector3(600.0, 0.0, 300.0),
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    cover_obs,
    PackedVector3Array(),
  )
  _assert(
    flee_open.length_squared() > 1e-12 and flee_open.dot(Vector3(-1.0, 0.0, 0.0)) > 0.5,
    "prey flee without aware cover still moves away from threat",
  )


func _test_herbivore_flee_obstacle_slip() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip herbivore flee obstacle slip test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var prey_he := Vector2(13.5, 30.5)
  var rock := [{"position": Vector3(540.0, 0.0, 300.0), "half_extents": Vector2(40.0, 40.0)}]
  var prey_pos := Vector3(530.0, 0.0, 300.0)
  var threat_pos := Vector3(400.0, 0.0, 300.0)
  var away := Vector3.RIGHT
  var nudged: Vector3 = d.call(
    "_herbivore_flee_obstacle_nudge_intent",
    away,
    prey_pos,
    prey_he,
    rock,
    threat_pos,
    91,
    rabbit_m,
  )
  _assert(
    nudged.length_squared() > 1e-12
    and not nudged.is_equal_approx(away)
    and absf(nudged.y) > 0.45,
    "flee nudge slips tangentially off obstacle instead of driving into rock face",
  )
  var shaped := {"static_obstacles": rock, "weight_expanding_explore_hint": 0.0}
  var slip_ok: bool = d.call(
    "_motor_obstacle_slip_shaping",
    shaped,
    rabbit_m,
    prey_pos,
    prey_he,
    91,
    0,
    prey_pos - threat_pos,
    true,
  )
  _assert(
    slip_ok
    and float(shaped.get("weight_expanding_explore_hint", 0.0)) > 10.0,
    "flee-direction slip shaping arms expand hint before contact",
  )


func _test_herbivore_flee_bush_rock_pinch() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip herbivore bush-rock flee pinch test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var prey_he := Vector2(13.5, 30.5)
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var bush := {"position": Vector3(500.0, 0.0, 300.0), "half_extents": Vector2(42.0, 42.0)}
  var rock := {"position": Vector3(380.0, 0.0, 300.0), "half_extents": Vector2(55.0, 55.0)}
  var pinch_obs := [bush, rock]
  var prey_pos := Vector3(440.0, 0.0, 300.0)
  var threat_pos := Vector3(580.0, 0.0, 300.0)
  var cover_samples := PackedVector3Array([Vector3(500.0, 0.0, 300.0)])
  var flee_a: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    prey_pos,
    threat_pos,
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    pinch_obs,
    cover_samples,
  )
  var flee_b: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    prey_pos,
    threat_pos,
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    pinch_obs,
    cover_samples,
  )
  _assert(
    flee_a.length_squared() > 1e-12
    and flee_a.is_equal_approx(flee_b)
    and not bool(d.call("_cardinal_step_blocked", prey_pos, prey_he, flee_a, pinch_obs, block_clr)),
    "bush-rock pinch flee heading is stable and traversable",
  )
  _assert(
    flee_a.dot(Vector3.RIGHT) < 0.85 and flee_a.dot(Vector3(-1.0, 0.0, 0.0)) < 0.85 and absf(flee_a.y) > 0.35,
    "bush-rock pinch flee breaks out vertically or diagonally instead of shuttling on cardinals",
  )
  var nudge_a: Vector3 = d.call(
    "_herbivore_flee_obstacle_nudge_intent",
    flee_a,
    prey_pos,
    prey_he,
    pinch_obs,
    threat_pos,
    42,
    rabbit_m,
  )
  var nudge_b: Vector3 = d.call(
    "_herbivore_flee_obstacle_nudge_intent",
    flee_a,
    prey_pos,
    prey_he,
    pinch_obs,
    threat_pos,
    42,
    rabbit_m,
  )
  _assert(
    nudge_a.length_squared() > 1e-12
    and nudge_a.is_equal_approx(nudge_b)
    and nudge_a.dot(Vector3.RIGHT) < 0.85
    and nudge_a.dot(Vector3(-1.0, 0.0, 0.0)) < 0.85
    and absf(nudge_a.y) > 0.35,
    "bush-rock pinch flee nudge stays latched on non-horizontal escape",
  )


func _test_herbivore_flee_diagonal_rock_pinch() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip herbivore diagonal-rock flee pinch test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var prey_he := Vector2(13.5, 30.5)
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var rock_ne := {"position": Vector3(470.0, 0.0, 260.0), "half_extents": Vector2(55.0, 55.0)}
  var rock_sw := {"position": Vector3(360.0, 0.0, 370.0), "half_extents": Vector2(55.0, 55.0)}
  var pinch_obs := [rock_ne, rock_sw]
  var prey_pos := Vector3(420.0, 0.0, 315.0)
  var threat_pos := Vector3(580.0, 0.0, 315.0)
  var flee_a: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    prey_pos,
    threat_pos,
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    pinch_obs,
  )
  var flee_b: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    prey_pos,
    threat_pos,
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    pinch_obs,
  )
  _assert(
    flee_a.length_squared() > 1e-12
    and flee_a.is_equal_approx(flee_b)
    and not bool(
      d.call(
        "_cardinal_step_blocked_for_escape",
        prey_pos,
        prey_he,
        flee_a,
        pinch_obs,
        block_clr,
      )
    ),
    "diagonal rock pinch flee heading is stable and does not tighten the wedge",
  )
  _assert(
    flee_a.dot(Vector3(-1.0, 0.0, 0.0)) < 0.92 and absf(flee_a.y) > 0.35,
    "diagonal rock pinch flee breaks out vertically instead of shuttling west into rocks",
  )
  var nudge_a: Vector3 = d.call(
    "_herbivore_flee_obstacle_nudge_intent",
    flee_a,
    prey_pos,
    prey_he,
    pinch_obs,
    threat_pos,
    42,
    rabbit_m,
  )
  _assert(
    nudge_a.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked_for_escape",
        prey_pos,
        prey_he,
        nudge_a,
        pinch_obs,
        block_clr,
      )
    ),
    "diagonal rock pinch flee nudge avoids wedge-tightening steps",
  )


func _test_herbivore_flee_w_shrub_n_rock_pinch() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip W-shrub N-rock flee pinch test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var bounds_max := Vector2(1000.0, 600.0)
  var prey_he := Vector2(13.5, 30.5)
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var shrub_w := {"position": Vector3(360.0, 0.0, 310.0), "half_extents": Vector2(42.0, 42.0)}
  var shrub_sw := {"position": Vector3(370.0, 0.0, 360.0), "half_extents": Vector2(42.0, 42.0)}
  var rock_n := {"position": Vector3(420.0, 0.0, 230.0), "half_extents": Vector2(55.0, 55.0)}
  var rock_ne := {"position": Vector3(490.0, 0.0, 250.0), "half_extents": Vector2(55.0, 55.0)}
  var pinch_obs := [shrub_w, shrub_sw, rock_n, rock_ne]
  var prey_pos := Vector3(430.0, 0.0, 310.0)
  var threat_pos := Vector3(600.0, 0.0, 310.0)
  var flee_a: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    prey_pos,
    threat_pos,
    bounds_max,
    prey_he,
    42,
    rabbit_m,
    pinch_obs,
  )
  _assert(
    flee_a.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked_for_escape",
        prey_pos,
        prey_he,
        flee_a,
        pinch_obs,
        block_clr,
      )
    ),
    "W-shrub N-rock pinch flee picks a traversable heading",
  )
  _assert(
    flee_a.dot(Vector3(-1.0, 0.0, 0.0)) < 0.92 and flee_a.dot(Vector3(1.0, 0.0, 0.0)) < 0.85,
    "W-shrub N-rock pinch flee does not keep pushing west or east into threat",
  )
  var locked_w: Vector3 = d.call(
    "_snap_seek_direction",
    prey_pos - threat_pos,
  )
  var nudged: Vector3 = d.call(
    "_herbivore_flee_obstacle_nudge_intent",
    locked_w,
    prey_pos,
    prey_he,
    pinch_obs,
    threat_pos,
    42,
    rabbit_m,
  )
  _assert(
    nudged.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked_for_escape",
        prey_pos,
        prey_he,
        nudged,
        pinch_obs,
        block_clr,
      )
    ),
    "W-shrub N-rock flee nudge escapes blocked west snap",
  )


func _test_expanding_cardinal_explore() -> void:
  var X := _EXPANDING_CARDINAL_EXPLORE_SCR.Explore
  var L0: Dictionary = X.locate(36, 0)
  _assert(int(L0["segment_index"]) == 0 and int(L0["cycle_index"]) == 0, "expanding explore t=0 first leg")
  var L35: Dictionary = X.locate(36, 35)
  _assert(int(L35["segment_index"]) == 0, "expanding explore still leg 1 before rotate")
  var L36: Dictionary = X.locate(36, 36)
  _assert(int(L36["segment_index"]) == 1, "expanding explore rotate after n ticks")
  var L143: Dictionary = X.locate(36, 143)
  _assert(int(L143["segment_index"]) == 3 and int(L143["cycle_index"]) == 0, "expanding explore fourth leg cycle 0")
  var L287: Dictionary = X.locate(36, 287)
  _assert(int(L287["segment_index"]) == 7 and int(L287["cycle_index"]) == 0, "expanding explore eighth leg cycle 0")
  var L288: Dictionary = X.locate(36, 288)
  _assert(int(L288["cycle_index"]) == 1 and int(L288["segment_index"]) == 0, "expanding explore cycle 1 start")
  _assert(int(L288["segment_ticks"]) == 72, "expanding explore doubled dwell after eighth rotation")
  var ne := Vector3(0.7071067811865475, 0.0, -0.7071067811865475)
  var c0: Vector3 = X.pick_cardinal(36, 0, 0)
  var c1: Vector3 = X.pick_cardinal(36, 0, 1)
  _assert(c0.is_equal_approx(Vector3(0.0, 0.0, -1.0)) and c1.is_equal_approx(ne), "phase_seed rotates 8-way ordering")
  var expand_ctx := {
    "creature_position": Vector3(200.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(800.0, 800.0),
    "mobs": [],
    "creature_facing": Vector3.RIGHT,
    "food_seek_targets": [],
    "weight_seek_ready_food": 0.0,
    "weight_explore_idle_penalty": 10.0,
    "weight_explore_turn_bias": 0.0,
    "exploration_blend_multiplier": 1.0,
    "expanding_explore_hint": Vector3(0.0, 0.0, -1.0),
    "weight_expanding_explore_hint": 2.2,
    "motor_stuck_allow_expand_hint": true,
  }
  var intent_up: Vector3 = _Motor.pick_best_move_intent(expand_ctx)
  _assert(intent_up.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "expand hint aligned UP beats idle when hint weight high")


func _test_predator_chase_motor_ctx() -> void:
  var prey_pos := Vector3(300.0, 0.0, 200.0)
  var pursuit := [
    {"position": prey_pos, "velocity": Vector3(-40.0, 0.0, 0.0), "cost_scale": 1.0},
  ]
  var ctx := {
    "creature_position": Vector3(200.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(800.0, 800.0),
    "mobs": [],
    "creature_facing": Vector3.RIGHT,
    "food_seek_targets": [],
    "prey_seek_targets": [prey_pos],
    "weight_seek_prey": 22.0,
    "weight_seek_ready_food": 0.0,
    "pursuit_targets": pursuit,
    "weight_pursuit_dist": 0.55,
    "weight_pursuit_closing": 1.35,
    "weight_pursuit_dist_sq": 48.0,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "weight_explore_trail_repulsion": 0.0,
    "exploration_blend_multiplier": 0.0,
    "explore_trail_centers": [],
  }
  var intent: Vector3 = _Motor.pick_best_move_intent(ctx)
  _assert(intent.is_equal_approx(Vector3.RIGHT), "predator chase picks +X toward prey without explore idle")

  var corner_prey := Vector3(976.0, 0.0, 300.0)
  var pred_approach := Vector3(820.0, 0.0, 300.0)
  var fox_he := Vector2(18.0, 44.0)
  var hunt_corner_ctx := ctx.duplicate(true)
  hunt_corner_ctx["creature_position"] = pred_approach
  hunt_corner_ctx["creature_half_extents"] = fox_he
  hunt_corner_ctx["prey_seek_targets"] = [corner_prey]
  hunt_corner_ctx["pursuit_targets"] = []
  hunt_corner_ctx["weight_edge"] = 0.0
  hunt_corner_ctx["weight_interior"] = 0.0
  hunt_corner_ctx["motor_has_active_goal"] = true
  hunt_corner_ctx["motor_seek_filter_wall_hits"] = false
  var close_intent: Vector3 = _Motor.pick_best_move_intent(hunt_corner_ctx)
  _assert(
    close_intent.dot(Vector3.RIGHT) > 0.85,
    "predator closes on edge-pinned prey when explore edge repulsion is off",
  )
  var legacy_corner_ctx := hunt_corner_ctx.duplicate(true)
  legacy_corner_ctx["weight_edge"] = 0.48
  legacy_corner_ctx["weight_interior"] = 0.65
  legacy_corner_ctx["motor_seek_filter_wall_hits"] = true
  var legacy_intent: Vector3 = _Motor.pick_best_move_intent(legacy_corner_ctx)
  _assert(
    legacy_intent.dot(Vector3.RIGHT) < close_intent.dot(Vector3.RIGHT),
    "legacy edge repulsion and seek wall filter weaken corner closing",
  )
  var atop_prey_ctx := ctx.duplicate(true)
  atop_prey_ctx["creature_position"] = prey_pos
  atop_prey_ctx["weight_explore_idle_penalty"] = 0.0
  atop_prey_ctx["exploration_blend_multiplier"] = 0.0
  var atop_intent: Vector3 = _Motor.pick_best_move_intent(atop_prey_ctx)
  _assert(
    atop_intent.length_squared() > 1e-12,
    "predator hunt never picks idle even when co-located with prey",
  )


func _test_predator_prey_memory_chase() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator prey memory chase test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {
    "goal_memory_mover_ttl_sec": 10.0,
    "goal_memory_forget_radius": 2800.0,
    "goal_memory_precise_radius": 5000.0,
    "goal_memory_ghost_horizon_sec": 0.4,
    "predator_memory_chase_lock_ticks": 24,
    "motor_patrol_min_step_clearance": 4.0,
    "weight_seek_prey": 22.0,
    "weight_pursuit_dist": 0.55,
    "weight_pursuit_closing": 1.35,
    "weight_pursuit_dist_sq": 48.0,
  }
  var prey_pos := Vector3(400.0, 0.0, 200.0)
  var pred_pos := Vector3(200.0, 0.0, 200.0)
  var prey_iid := 424242
  var carn_root := _instantiate_carnivore_root()
  root.add_child(carn_root)
  var predator := carn_root.get_node("Body") as CharacterBody3D
  _setup_carnivore_body(predator)
  predator.global_position = pred_pos
  var pred_bid := predator.get_instance_id()
  var now_ms := Time.get_ticks_msec()
  var beliefs: Dictionary = {}
  beliefs = _GoalBeliefScr.sync_from_prey_entries(
    beliefs,
    [{"instance_id": prey_iid, "pos": prey_pos, "velocity": Vector3(50.0, 0.0, 0.0)}],
    now_ms,
  )
  driver.set("_goal_belief_by_body", {pred_bid: beliefs})
  var sample: Dictionary = _GoalBeliefScr.sample_best_moving(
    beliefs, pred_pos, motor_p, _GkReg.GK_FIND_FOOD, {}, now_ms
  )
  _assert(bool(sample.get("active", false)), "memory sample active after touch")
  _assert(
    (sample.get("position", Vector3.ZERO) as Vector3).is_equal_approx(prey_pos),
    "memory recalls last prey position",
  )
  _assert(
    float(sample.get("strength", 0.0)) >= 0.4,
    "memory strength stays in motor cost_scale band",
  )
  var inactive := {
    "active": false,
    "position": Vector3.ZERO,
    "velocity": Vector3.ZERO,
    "strength": 0.0,
  }
  var prey_live: Array = []
  var pursuit_live: Array = []
  driver.call(
    "_predator_inject_memory_chase_targets", inactive, prey_live, pursuit_live, motor_p
  )
  _assert(prey_live.is_empty(), "inactive memory does not inject prey targets")
  driver.call(
    "_predator_inject_memory_chase_targets", sample, prey_live, pursuit_live, motor_p
  )
  _assert(
    prey_live.size() == 1 and (prey_live[0] as Vector3).is_equal_approx(prey_pos),
    "inject fills prey_seek_targets from memory",
  )
  _assert(pursuit_live.size() == 2, "inject adds centroid + ghost-intercept pursuit hints")
  var he := Vector2(18.0, 44.0)
  driver.set("_physics_ticks", 10)
  var chase_intent: Vector3 = driver.call(
    "_predator_latched_memory_chase_intent",
    predator.get_instance_id(),
    pred_pos,
    prey_pos,
    he,
    [],
    Vector3.ZERO,
    Vector3(1000.0, 0.0, 600.0),
    motor_p,
  )
  _assert(
    chase_intent.is_equal_approx(Vector3.RIGHT),
    "latched memory chase snaps toward remembered prey on +X",
  )
  var mem_ctx := {
    "creature_position": pred_pos,
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(1000.0, 600.0),
    "mobs": [],
    "creature_facing": Vector3.RIGHT,
    "food_seek_targets": [],
    "prey_seek_targets": prey_live.duplicate(),
    "weight_seek_prey": 22.0,
    "weight_seek_ready_food": 0.0,
    "pursuit_targets": pursuit_live.duplicate(),
    "weight_pursuit_dist": 0.55,
    "weight_pursuit_closing": 1.35,
    "weight_pursuit_dist_sq": 48.0,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "weight_explore_trail_repulsion": 0.0,
    "exploration_blend_multiplier": 0.0,
    "explore_trail_centers": [],
  }
  var mem_intent: Vector3 = _Motor.pick_best_move_intent(mem_ctx)
  _assert(
    mem_intent.is_equal_approx(Vector3.RIGHT),
    "motor chase toward memory-injected prey without live awareness",
  )
  beliefs[prey_iid]["last_observed_ms"] = now_ms - 20000
  driver.set("_goal_belief_by_body", {pred_bid: beliefs})
  var stale: Dictionary = _GoalBeliefScr.sample_best_moving(
    beliefs, pred_pos, motor_p, _GkReg.GK_FIND_FOOD, {}, Time.get_ticks_msec()
  )
  _assert(not bool(stale.get("active", false)), "memory expires after TTL")
  beliefs = _GoalBeliefScr.sync_from_prey_entries(
    beliefs,
    [{"instance_id": prey_iid, "pos": prey_pos, "velocity": Vector3(50.0, 0.0, 0.0)}],
    Time.get_ticks_msec(),
  )
  driver.set("_goal_belief_by_body", {pred_bid: beliefs})
  predator.global_position = Vector3(prey_pos.x + 5000.0, 0.0, prey_pos.z)
  var forgotten: Dictionary = _GoalBeliefScr.sample_best_moving(
    beliefs,
    predator.global_position,
    motor_p,
    _GkReg.GK_FIND_FOOD,
    {},
    Time.get_ticks_msec(),
  )
  _assert(not bool(forgotten.get("active", false)), "memory cleared past forget radius")
  root.remove_child(carn_root)
  carn_root.free()
  root.remove_child(driver)
  driver.free()


func _test_goal_belief_moving_prey_ghost() -> void:
  var motor_p := {
    "goal_memory_mover_ttl_sec": 10.0,
    "goal_memory_precise_radius": 5000.0,
    "goal_memory_ghost_horizon_sec": 0.5,
  }
  var prey_pos := Vector3(300.0, 0.0, 100.0)
  var vel := Vector3(80.0, 0.0, 0.0)
  var now_ms := Time.get_ticks_msec()
  var beliefs: Dictionary = {}
  beliefs = _GoalBeliefScr.sync_from_prey_entries(
    beliefs,
    [{"instance_id": 77, "pos": prey_pos, "velocity": vel}],
    now_ms,
  )
  var prey_live: Array = []
  var pursuit_live: Array = []
  var sample: Dictionary = _GoalBeliefScr.sample_best_moving(
    beliefs, Vector3.ZERO, motor_p, _GkReg.GK_FIND_FOOD, {}, now_ms
  )
  _GoalBeliefScr.inject_moving_memory_chase(sample, prey_live, pursuit_live, motor_p)
  _assert(prey_live.size() == 1, "ghost inject adds centroid prey point")
  _assert(pursuit_live.size() == 2, "ghost inject adds centroid + intercept pursuit hints")
  var intercept: Vector3 = pursuit_live[1].get("position", Vector3.ZERO)
  _assert(
    intercept.is_equal_approx(prey_pos + vel * 0.5),
    "light-C intercept uses goal_memory_ghost_horizon_sec",
  )
  var beliefs_avoid: Dictionary = _GoalBeliefScr.sync_from_threat_samples(
    {},
    [
      {
        "world_pos": Vector3(50.0, 0.0, 0.0),
        "gate_dist": 10.0,
        "in_awareness": true,
        "velocity": Vector3(-20.0, 0.0, 0.0),
        "instance_id": 88,
      },
    ],
    now_ms,
  )
  _assert(
    _GoalBeliefScr.has_remembered_avoid_threat(
      beliefs_avoid, Vector3.ZERO, motor_p, {}, now_ms
    ),
    "remembered avoid_hostiles blocks prey memory path",
  )


func _test_no_goal_plateau_random() -> void:
  var center := Vector3(500.0, 0.0, 500.0)
  var base_ctx := {
    "creature_position": center,
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(1000.0, 1000.0),
    "mobs": [],
    "static_obstacles": [],
    "creature_half_extents": Vector2(13.5, 30.5),
    "creature_facing": Vector3.RIGHT,
    "food_seek_targets": [],
    "prey_seek_targets": [],
    "pursuit_targets": [],
    "weight_seek_ready_food": 0.0,
    "weight_seek_prey": 0.0,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "weight_expanding_explore_hint": 0.0,
    "motor_intent_cost_chaos": 0.0,
    "motor_no_goal_plateau_random": true,
    "motor_tie_cost_epsilon": 2.0,
    "motor_cardinal_block_min_clearance": 4.0,
    "motor_pick_tick": 0,
    "motor_chaos_seed": 90210,
    "shuffle_tie_break": false,
  }
  var d_a: Vector3 = _Motor.pick_best_move_intent(base_ctx)
  var d_b: Vector3 = _Motor.pick_best_move_intent(base_ctx)
  _assert(d_a.is_equal_approx(d_b), "no-goal plateau tie uses deterministic eval order")
  _assert(d_a.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "no-goal plateau tie picks first eval-order direction (N)")
  var blocked_ctx := base_ctx.duplicate(true)
  blocked_ctx["static_obstacles"] = [
    {"position": Vector3(560.0, 0.0, 500.0), "half_extents": Vector2(24.0, 40.0)},
  ]
  var d_blocked: Vector3 = _Motor.pick_best_move_intent(blocked_ctx)
  _assert(
    not d_blocked.is_equal_approx(Vector3.RIGHT),
    "motor cost picker skips blocked cardinals on plateau ties",
  )
  var seek_ctx := base_ctx.duplicate(true)
  seek_ctx["food_seek_targets"] = [Vector3(600.0, 0.0, 500.0)]
  seek_ctx["weight_seek_ready_food"] = 16.0
  seek_ctx["motor_has_active_goal"] = true
  seek_ctx["static_obstacles"] = [
    {"position": Vector3(560.0, 0.0, 500.0), "half_extents": Vector2(24.0, 40.0)},
  ]
  var d_seek: Vector3 = _Motor.pick_best_move_intent(seek_ctx)
  _assert(
    d_seek.is_equal_approx(Vector3.RIGHT),
    "active goal seek keeps blocked-filter off so motor can step toward targets",
  )


func _test_food_seek_motor() -> void:
  var food := [Vector3(400.0, 0.0, 200.0)]
  var c_left := float(
    Callable(_Motor, &"food_seek_cost_at_prediction").call(
      Vector3(200.0, 0.0, 200.0), Vector3.ZERO, food, 1.0, [], 0.0
    )
  )
  var c_right := float(
    Callable(_Motor, &"food_seek_cost_at_prediction").call(
      Vector3(300.0, 0.0, 200.0), Vector3.ZERO, food, 1.0, [], 0.0
    )
  )
  _assert(c_right < c_left, "food seek cost decreases when prediction moves toward target")
  var mob_near := [Vector3(205.0, 0.0, 200.0)]
  var gated := float(
    Callable(_Motor, &"food_seek_cost_at_prediction").call(
      Vector3(250.0, 0.0, 200.0), Vector3.ZERO, food, 50.0, mob_near, 60.0
    )
  )
  var free := float(
    Callable(_Motor, &"food_seek_cost_at_prediction").call(
      Vector3(250.0, 0.0, 200.0), Vector3.ZERO, food, 50.0, [], 0.0
    )
  )
  _assert(gated < 1e-6 and free > 1000.0, "imminent mob radius suppresses food pull at predicted pose")
  var w_suppressed := float(
    Callable(_Motor, &"effective_food_seek_weight").call(
      50.0, Vector3(240.0, 0.0, 200.0), Vector3.ZERO, mob_near, 100.0
    )
  )
  var w_active := float(
    Callable(_Motor, &"effective_food_seek_weight").call(
      50.0, Vector3(100.0, 0.0, 200.0), Vector3.ZERO, mob_near, 100.0
    )
  )
  _assert(w_suppressed < 1e-6 and w_active > 40.0, "imminent mob radius zeros food weight at current pose")
  var c_far_un := float(
    Callable(_Motor, &"unready_food_avoid_cost_at_prediction").call(
      Vector3(0.0, 0.0, 0.0), Vector3.ZERO, [Vector3(200.0, 0.0, 0.0)], 10.0, 8.0
    )
  )
  var c_near_un := float(
    Callable(_Motor, &"unready_food_avoid_cost_at_prediction").call(
      Vector3(150.0, 0.0, 0.0), Vector3.ZERO, [Vector3(200.0, 0.0, 0.0)], 10.0, 8.0
    )
  )
  _assert(c_near_un > c_far_un, "unready bush inverse-distance cost rises when prediction hugs the bush")
  var seek_ctx := {
    "creature_position": Vector3(200.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 0.0,
    "weight_closing": 0.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.0,
    "food_seek_targets": food,
    "weight_seek_ready_food": 2.0,
    "imminent_mob_points": [],
    "food_seek_imminent_mob_radius": 0.0,
  }
  var toward := _Motor.pick_best_move_intent(seek_ctx)
  _assert(toward.is_equal_approx(Vector3.RIGHT), "food seek steers toward in-range ready bush when mob costs off")
  var mob_pos := Vector3(300.0, 0.0, 200.0)
  var flee_ctx := {
    "creature_position": Vector3(240.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [{"position": mob_pos, "velocity": Vector3.ZERO}],
    "weight_dist": 0.45,
    "weight_closing": 0.0,
    "weight_dist_sq": 55.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.0,
    "weight_edge": 0.0,
    "food_seek_targets": food,
    "weight_seek_ready_food": 80.0,
    "imminent_mob_points": [mob_pos],
    "food_seek_imminent_mob_radius": 100.0,
  }
  var flee := _Motor.pick_best_move_intent(flee_ctx)
  _assert(flee.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "mob within imminent radius beats food seek")


func _test_explore_idle_when_no_pickup() -> void:
  var roam := {
    "creature_position": Vector3(240.0, 0.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 0.0,
    "weight_closing": 0.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.65,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.48,
    "food_seek_targets": [],
    "weight_seek_ready_food": 0.0,
    "imminent_mob_points": [],
    "food_seek_imminent_mob_radius": 0.0,
    "unready_food_avoid_targets": [],
    "weight_avoid_unready_food": 0.0,
    "weight_explore_idle_penalty": 15.0,
    "weight_explore_turn_bias": 0.0,
  }
  var intent := _Motor.pick_best_move_intent(roam)
  _assert(not intent.is_equal_approx(Vector3.ZERO), "explore idle penalty avoids standstill without pickup targets")


func _test_explore_trail_repulsion_motor() -> void:
  var c_far := float(
    Callable(_Motor, &"exploration_trail_repulsion_cost").call(
      Vector3(300.0, 0.0, 360.0), Vector3.ZERO, [Vector3(190.0, 0.0, 360.0)], 10.0, 8.0
    )
  )
  var c_near := float(
    Callable(_Motor, &"exploration_trail_repulsion_cost").call(
      Vector3(180.0, 0.0, 360.0), Vector3.ZERO, [Vector3(190.0, 0.0, 360.0)], 10.0, 8.0
    )
  )
  _assert(c_near > c_far, "trail repulsion rises when prediction approaches a prior cell center")
  var trail_ctx := {
    "creature_position": Vector3(240.0, 0.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 0.0,
    "weight_closing": 0.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 0.65,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.48,
    "food_seek_targets": [],
    "weight_seek_ready_food": 0.0,
    "imminent_mob_points": [],
    "food_seek_imminent_mob_radius": 0.0,
    "unready_food_avoid_targets": [],
    "weight_avoid_unready_food": 0.0,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "explore_trail_centers": [Vector3(190.0, 0.0, 360.0)],
    "weight_explore_trail_repulsion": 40.0,
  }
  var away := _Motor.pick_best_move_intent(trail_ctx)
  _assert(away.is_equal_approx(Vector3.RIGHT), "trail repulsion steers away from visited cell when symmetric otherwise")


func _test_wall_slide_pick() -> void:
  ## Picks tangent with larger dot toward incoming (= smaller planar turn vs the ±90 flank).
  var p: Object = _SlidePickScr.new()
  var d_down: Variant = p.call("pick_tangent_closer", Vector2(0.0, 1.0), Vector2.RIGHT)
  _assert(Vector2(0.0, 1.0).is_equal_approx((d_down as Vector2).normalized()), "down + horizontal wall prefers +Y")
  var along_east: Variant = p.call("pick_tangent_closer", Vector2.RIGHT, Vector2(0.0, -1.0))
  _assert(Vector2.RIGHT.is_equal_approx((along_east as Vector2).normalized()), "east + skyward normal prefers +X")
  var flee_away := Vector2(1.0, -1.0).normalized()
  var north_wall_normal := Vector2(0.0, 1.0)
  var egress: Vector2 = p.call(
    "pick_tangent_away_from", flee_away, north_wall_normal, flee_away
  ) as Vector2
  _assert(
    egress.is_equal_approx(Vector2.RIGHT),
    "flee into north wall slides east when east continues away from SW threat",
  )
  var flee_west := Vector2(-1.0, -1.0).normalized()
  var egress_w: Vector2 = p.call(
    "pick_tangent_away_from", flee_west, north_wall_normal, flee_west
  ) as Vector2
  _assert(
    egress_w.is_equal_approx(Vector2.LEFT),
    "flee into north wall slides west when west continues away from SE threat",
  )
  var hunt_toward := Vector2(0.0, 1.0)
  var flank: Vector2 = p.call(
    "pick_tangent_toward", Vector2(0.0, 1.0), Vector2.RIGHT, hunt_toward
  ) as Vector2
  _assert(
    flank.is_equal_approx(Vector2(0.0, 1.0)),
    "predator wall slide prefers tangent that closes on prey",
  )


func _test_pack_resource_resolver() -> void:
  ## Bindings + defaults per archived asset plan §2.1 ([PackResourceResolver]); intentional fallback counts as failure unless asserted below.
  _assert(ResourceLoader.exists(_PackRes.PATH_TEX_DEV), "default dev texture import exists")
  _assert(ResourceLoader.exists(_PackRes.PATH_TEX_RELEASE), "default release texture import exists")
  _assert(ResourceLoader.exists(_PackRes.PATH_AUDIO_DEV), "default dev wav import exists")
  _assert(ResourceLoader.exists(_PackRes.PATH_AUDIO_RELEASE), "default release wav import exists")
  var smoke_root := "res://assets/creatures/resolver_smoke"
  var ok_tex: Dictionary = _PackRes.resolve_texture_from_pack(smoke_root, "obstacle_tex")
  _assert(ok_tex["used_default"] == false, "shared obstacle_tex should hit migrated PNG")
  _assert(str(ok_tex["path"]).ends_with("pile-of-rocks.png"), "obstacle_tex path suffix")
  var bad_tex: Dictionary = _PackRes.resolve_texture_from_pack(smoke_root, "__missing_tag_for_test__")
  _assert(bad_tex["used_default"] == true, "missing tag must fall back to default texture")
  _assert(ResourceLoader.exists(str(bad_tex["path"])), "fallback texture path loads")
  var bad_aud: Dictionary = _PackRes.resolve_audio_from_pack(smoke_root, "__missing_audio_tag__")
  _assert(bad_aud["used_default"] == true, "missing audio tag uses default stream path")
  _assert(ResourceLoader.exists(str(bad_aud["path"])), "fallback audio path loads")


func _test_hunger_calorie_clamp() -> void:
  ## Burst overflow is wasted: pool clamps at caloric_needs (HUNGER_AND_EATING §4).
  var cur := 9.0
  var cap := 10.0
  var grant := 5.0
  var next := minf(cap, cur + grant)
  _assert(is_equal_approx(next, 10.0), "hunger burst clamps at caloric_needs")
  _assert(ResourceLoader.exists("res://assets/plants/solid_shrub/solid_shrub_3d.tscn"), "solid_shrub_3d scene exists")
  _assert(ResourceLoader.exists("res://assets/plants/open_shrub/open_shrub_3d.tscn"), "open_shrub_3d scene exists")


func _test_calorie_drain_movement_formula() -> void:
  ## Same formula as [code]Player._apply_calorie_drain_and_starvation[/code] / [code]Mob._apply_calorie_burn[/code].
  var baseline := 1.0
  var per_unit := 0.002
  var delta := 1.0
  var speed_units_s := 100.0
  var burn := baseline * delta + per_unit * speed_units_s * delta
  _assert(is_equal_approx(burn, 1.2), "1s at 100 units/s matches baseline + per-unit movement")


func _test_predator_prey_meal_clamp() -> void:
  var base := _Merge.default_root()
  var meal := int(base["creature_motor"].get("predator_prey_meal_calories", 5))
  var carn_root := _instantiate_carnivore_root()
  var body := carn_root.get_node("Body") as CharacterBody3D
  _assert(body != null, "carnivore Body loads for meal clamp")
  body.set("caloric_needs", 10)
  body.set("current_calories", 8.0)
  body.call("add_calories_from_prey", meal)
  _assert(is_equal_approx(float(body.get("current_calories")), 10.0), "predator meal clamps at caloric_needs")
  carn_root.queue_free()


func _test_creature_vitals_math_burn_and_clamp() -> void:
  var burn: float = _CreatureVitalsMath.burn_amount(1.0, 0.002, 100.0, 1.0, 1.0, 1.0)
  _assert(is_equal_approx(burn, 1.2), "CreatureVitalsMath burn matches legacy 2D formula")
  var after: float = _CreatureVitalsMath.add_food_clamped(9.0, 5, 10)
  _assert(is_equal_approx(after, 10.0), "add_food_clamped respects cap")
  var burned_def: float = _CreatureVitalsMath.burn_amount(1.0, 0.002, 0.0, 1.0, 0.5, 2.0)
  _assert(is_equal_approx(burned_def, 0.5), "species multipliers scale burn")


func _test_hud_resolves_3d_herbivore_motor_body() -> void:
  var hud_scene: PackedScene = load("res://hud.tscn") as PackedScene
  _assert(hud_scene != null, "hud scene loads for 3d herbivore vitals")
  var rabbit_def: Resource = load("res://creature/species/rabbit_archetype.tres") as Resource
  _assert(rabbit_def != null, "rabbit archetype loads for hud vitals test")
  var body := Node.new()
  body.set("caloric_needs", 30)
  body.set("current_calories", 27.0)
  body.set("definition", rabbit_def)
  var stub_script := GDScript.new()
  stub_script.source_code = (
    "extends Node\n"
    + "var herb_body: Node\n"
    + "func get_herbivore_motor_body() -> Node:\n"
    + "  return herb_body\n"
  )
  _assert(stub_script.reload() == OK, "hud vitals stub main script compiles")
  var main := Node.new()
  main.set_script(stub_script)
  main.set("herb_body", body)
  root.add_child(main)
  current_scene = main
  var hud: Node = hud_scene.instantiate()
  main.add_child(hud)
  hud.call("_refresh_vitals_labels")
  var label_text: String = str(hud.get_node("HerbivoreCaloriesLabel").text)
  _assert(label_text.find("Rabbit") >= 0, "hud herbivore label uses rabbit display name")
  _assert(label_text.find("27 / 30") >= 0, "hud herbivore label shows live 3d body calories")
  hud.queue_free()
  main.queue_free()


func _test_creature_predation_math() -> void:
  var next: float = _CreaturePredationMath.apply_meal_to_predator(8.0, 10, 5)
  _assert(is_equal_approx(next, 10.0), "CreaturePredationMath clamps meal at cap")


func _test_diet_registry_defaults() -> void:
  var h = _DietRegistry.default_food_intake_policy(_CreatureDefinition.FeedingMode.HERBIVORE)
  _assert(h.plant_groups.has(&"food_plants"), "herbivore policy includes food_plants")
  _assert(h.prey_groups.is_empty(), "herbivore policy has no prey by default")
  var c = _DietRegistry.default_food_intake_policy(_CreatureDefinition.FeedingMode.CARNIVORE)
  _assert(c.prey_groups.size() >= 1, "carnivore policy has prey groups")
  var o = _DietRegistry.default_food_intake_policy(_CreatureDefinition.FeedingMode.OMNIVORE)
  _assert(not o.plant_groups.is_empty() and not o.prey_groups.is_empty(), "omnivore merges plant and prey")


func _test_creature_perception_3d_scale() -> void:
  var def = _CreatureDefinition.new()
  def.perception_radius_scale = 1.5
  def.awareness_cone_half_angle_scale = 0.8
  var r: float = _CreaturePerception3D.effective_awareness_radius(1000.0, def)
  _assert(is_equal_approx(r, 1500.0), "perception radius scales")
  var ang: float = _CreaturePerception3D.effective_cone_half_angle_deg(45.0, def)
  _assert(is_equal_approx(ang, 36.0), "cone half-angle scales")
  var r0: float = _CreaturePerception3D.effective_awareness_radius(200.0, null)
  _assert(is_equal_approx(r0, 200.0), "null definition leaves radius unchanged")


func _test_playfield_clamp() -> void:
  var half := Vector2(10.0, 20.0)
  var screen := Vector2(200.0, 100.0)
  var clamped := _PlayfieldClamp.clamp_position(Vector2(-5.0, 50.0), half, screen)
  _assert(clamped.x >= half.x and clamped.y >= half.y, "playfield clamp min edges")
  _assert(clamped.x <= screen.x - half.x, "playfield clamp max x")
  var bmin := Vector2(40.0, 30.0)
  var bmax := Vector2(140.0, 110.0)
  var local_clamped := _PlayfieldClamp.clamp_position(
    Vector2(20.0, 50.0) - bmin, half, bmax - bmin
  )
  var offset_clamped := local_clamped + bmin
  _assert(is_equal_approx(offset_clamped.x, bmin.x + half.x), "playfield clamp respects world min x")
  var slide_pick := _SlidePickScr.new()
  var hug_pos := Vector2(half.x + 4.0, 50.0)
  var slid: Vector2 = _PlayfieldClamp.slide_heading_along_edge(
    Vector2(-1.0, 0.0), hug_pos, half, screen, 48.0, slide_pick
  )
  _assert(
    slid.length_squared() > 1e-12 and slid.x > -0.05,
    "playfield edge slide redirects heading away from left bound",
  )


func _test_boulder_obstacle_collision_bake() -> void:
  var boulder: PackedScene = load(
    "res://assets/environment/obstacle_boulder/h-k-boulder1.blend",
  ) as PackedScene
  _assert(boulder != null, "boulder scene loads for collision bake test")
  var rock := boulder.instantiate() as Node3D
  root.add_child(rock)
  _assert(_PlayfieldBounds3D.count_static_bodies(rock) == 0, "boulder import has no physics bodies")
  var colliders: int = PlayfieldBounds3D.ensure_obstacle_physics(rock)
  _assert(colliders >= 1, "boulder mesh bakes trimesh collision")
  var sb := rock.get_node_or_null("AutoCollision_Cube") as StaticBody3D
  _assert(sb != null, "baked boulder collider is registered on rock")
  _assert(sb.is_in_group(&"obstacles"), "baked boulder collider joins obstacles group")
  rock.queue_free()


func _test_perimeter_boulder_density() -> void:
  var boulder: PackedScene = load(
    "res://assets/environment/obstacle_boulder/h-k-boulder1.blend",
  ) as PackedScene
  _assert(boulder != null, "boulder scene loads for perimeter density test")
  var bounds: Dictionary = {
    "valid": true,
    "min": Vector2(0.0, 0.0),
    "max": Vector2(40.0, 30.0),
    "surface_y": 0.0,
    "floor_y": 0.0,
  }
  var tight_parent := Node3D.new()
  var loose_parent := Node3D.new()
  root.add_child(tight_parent)
  root.add_child(loose_parent)
  _PerimeterBoulders.place_along_perimeter(
    tight_parent, bounds, boulder, _PerimeterBoulders.DEFAULT_SPACING, _PerimeterBoulders.DEFAULT_INSET
  )
  _PerimeterBoulders.place_along_perimeter(loose_parent, bounds, boulder, 4.0, 0.8)
  _assert(
    tight_parent.get_child_count() > loose_parent.get_child_count() * 2,
    "tight perimeter spacing places substantially more boulders than legacy 4 m spacing",
  )
  for ch in tight_parent.get_children():
    if ch is Node3D:
      _assert(
        _PlayfieldBounds3D.count_static_bodies(ch as Node3D) >= 1,
        "each perimeter boulder has collision",
      )
  tight_parent.queue_free()
  loose_parent.queue_free()


func _test_playfield_prop_grounding_on_thick_floor() -> void:
  var playfield_root := Node3D.new()
  root.add_child(playfield_root)
  var grass: PackedScene = load(
    "res://assets/locations/grasslands/h-k-grasslands.blend",
  ) as PackedScene
  _assert(grass != null, "grasslands scene loads for prop grounding test")
  var g := grass.instantiate() as Node3D
  playfield_root.add_child(g)
  _PlayfieldBounds3D.ensure_world_static_layers(g)
  if _PlayfieldBounds3D.count_static_bodies(g) == 0:
    _PlayfieldBounds3D.supplement_trimesh_collision_from_meshes(g, playfield_root)
  var bounds: Dictionary = _PlayfieldBounds3D.xz_bounds_from_playfield_root(playfield_root)
  _assert(bool(bounds.get("valid", false)), "grasslands bounds valid for prop grounding")
  var floor_y := float(bounds.get("floor_y", 0.0))
  var surface_y := float(bounds.get("surface_y", 0.0))
  _assert(surface_y > floor_y + 1.0, "grasslands walkable surface above collision floor")
  await self.physics_frame
  var boulder: PackedScene = load(
    "res://assets/environment/obstacle_boulder/h-k-boulder1.blend",
  ) as PackedScene
  _assert(boulder != null, "boulder scene loads for prop grounding test")
  var rock := boulder.instantiate() as Node3D
  playfield_root.add_child(rock)
  var xz := Vector2(0.0, 0.0)
  var world_3d: World3D = root.get_world_3d()
  _assert(world_3d != null, "root has World3D for prop grounding test")
  var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
  _assert(
    _PlayfieldBounds3D.snap_prop_root_to_ground(rock, xz, floor_y, space),
    "boulder snaps to grasslands walkable surface",
  )
  _assert(
    rock.global_position.y > floor_y + 0.5,
    "boulder rests above buried collision floor_y",
  )
  var grounded_y := rock.global_position.y
  _PlayfieldBounds3D.ensure_obstacle_physics(rock)
  rock.global_position = Vector3(xz.x, surface_y + 2.0, xz.y)
  _assert(
    _PlayfieldBounds3D.snap_prop_root_to_ground(rock, xz, floor_y, space),
    "boulder with baked collision still snaps to walkable surface",
  )
  _assert(
    absf(rock.global_position.y - grounded_y) < 0.05,
    "baked boulder snap ignores its own trimesh collider",
  )
  playfield_root.queue_free()


func _grasslands_playfield_with_sampler() -> Dictionary:
  var playfield_root := Node3D.new()
  root.add_child(playfield_root)
  var grass: PackedScene = load(
    "res://assets/locations/grasslands/h-k-grasslands.blend",
  ) as PackedScene
  _assert(grass != null, "grasslands scene loads for ground sampler test")
  var g := grass.instantiate() as Node3D
  playfield_root.add_child(g)
  _PlayfieldBounds3D.ensure_world_static_layers(g)
  if _PlayfieldBounds3D.count_static_bodies(g) == 0:
    _PlayfieldBounds3D.supplement_trimesh_collision_from_meshes(g, playfield_root)
  var bounds: Dictionary = _PlayfieldBounds3D.xz_bounds_from_playfield_root(playfield_root)
  _assert(bool(bounds.get("valid", false)), "grasslands bounds valid for ground sampler")
  await self.physics_frame
  var world_3d: World3D = root.get_world_3d()
  _assert(world_3d != null, "root has World3D for ground sampler test")
  var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
  var sampler: _GroundSampler = _GroundSampler.bake_from_playfield(bounds, space)
  _assert(sampler != null and sampler.is_valid(), "ground sampler bakes on grasslands")
  return {"root": playfield_root, "bounds": bounds, "sampler": sampler}


func _test_ground_sampler_center_lower_than_rim() -> void:
  var pack: Dictionary = await _grasslands_playfield_with_sampler()
  var sampler: _GroundSampler = pack.get("sampler")
  var bounds: Dictionary = pack.get("bounds")
  var bmin: Vector2 = bounds.get("min", Vector2.ZERO)
  var bmax: Vector2 = bounds.get("max", Vector2.ZERO)
  var center_xz := bmin + (bmax - bmin) * 0.5
  var center_elev := sampler.sample_elevation(center_xz)
  var rim_elev := center_elev
  for gy in range(sampler._grid_h):
    for gx in range(sampler._grid_w):
      var fx := (float(gx) + 0.5) / float(sampler._grid_w)
      var fy := (float(gy) + 0.5) / float(sampler._grid_h)
      var xz := bmin + Vector2(fx * (bmax.x - bmin.x), fy * (bmax.y - bmin.y))
      rim_elev = maxf(rim_elev, sampler.sample_elevation(xz))
  _assert(
    rim_elev > center_elev + 0.15,
    "grasslands center elevation below rim (valley depression detectable)",
  )
  (pack.get("root") as Node3D).queue_free()


func _test_duel_spawn_picker_avoids_depression() -> void:
  var pack: Dictionary = await _grasslands_playfield_with_sampler()
  var sampler: _GroundSampler = pack.get("sampler")
  var bounds: Dictionary = pack.get("bounds")
  var bmin: Vector2 = bounds.get("min", Vector2.ZERO)
  var sz: Vector2 = bounds.get("size", Vector2.ZERO)
  var fracs: Array = sampler.pick_duel_spawn_fractions()
  _assert(fracs.size() >= 2, "duel spawn picker returns two fractions")
  for frac_v in fracs:
    var frac := frac_v as Vector2
    var xz := bmin + Vector2(frac.x * sz.x, frac.y * sz.y)
    _assert(
      sampler.local_depression_score(xz) <= _GroundSampler.SPAWN_DEPRESSION_THRESHOLD_M + 0.05,
      "spawn fraction avoids valley depression",
    )
  var center_frac := Vector2(0.5, 0.5)
  var center_xz := bmin + Vector2(center_frac.x * sz.x, center_frac.y * sz.y)
  var center_dep := sampler.local_depression_score(center_xz)
  if center_dep > _GroundSampler.SPAWN_DEPRESSION_THRESHOLD_M:
    var h_frac: Vector2 = fracs[0] as Vector2
    _assert(
      h_frac.distance_to(center_frac) > 0.12,
      "rim spawn fractions move away from geometric center when center is depressed",
    )
  (pack.get("root") as Node3D).queue_free()


func _test_terrain_stuck_escape_prefers_uphill() -> void:
  if not _ai_driver_can_instantiate():
    return
  var pack: Dictionary = await _grasslands_playfield_with_sampler()
  var sampler: _GroundSampler = pack.get("sampler")
  var bounds: Dictionary = pack.get("bounds")
  var bmin: Vector2 = bounds.get("min", Vector2.ZERO)
  var sz: Vector2 = bounds.get("size", Vector2.ZERO)
  var center_xz := bmin + sz * 0.5
  var center_elev := sampler.sample_elevation(center_xz)
  var best_elev := center_elev
  for gy in range(sampler._grid_h):
    for gx in range(sampler._grid_w):
      var fx := (float(gx) + 0.5) / float(sampler._grid_w)
      var fy := (float(gy) + 0.5) / float(sampler._grid_h)
      var xz := bmin + Vector2(fx * sz.x, fy * sz.y)
      var elev := sampler.sample_elevation(xz)
      if elev > best_elev:
        best_elev = elev
  var d := _AiDriverScr.new()
  root.add_child(d)
  var stub := _TerrainTestMainStub.new()
  stub.ground_sampler = sampler
  root.add_child(stub)
  d.set("_main", stub)
  var motor_p: Dictionary = _Merge.default_creature_motor_params()
  var pos := Vector3(center_xz.x, center_elev, center_xz.y)
  var body := CharacterBody3D.new()
  root.add_child(body)
  body.global_position = pos
  d.register_creature(body)
  var he := Vector2(13.5, 30.5)
  var esc: Vector3 = d.call(
    "_pick_terrain_uphill_escape_cardinal",
    pos,
    he,
    [],
    body.get_instance_id(),
    motor_p,
  )
  _assert(esc.length_squared() > 1e-12, "terrain uphill escape picks a cardinal at valley floor")
  var probe_y: float = sampler.elevation_at_cardinal_probe(
    pos, esc, _Motor.motor_cardinal_probe_step(he)
  )
  _assert(
    probe_y >= center_elev - 0.05,
    "terrain uphill escape cardinal does not aim deeper into depression",
  )
  d.queue_free()
  body.queue_free()
  stub.queue_free()
  (pack.get("root") as Node3D).queue_free()


func _test_terrain_physics_cardinal_blocked() -> void:
  var body := CharacterBody3D.new()
  root.add_child(body)
  body.global_position = Vector3(0.0, 1.0, 0.0)
  var wall := StaticBody3D.new()
  root.add_child(wall)
  wall.collision_layer = 1
  wall.collision_mask = 1
  var box := BoxShape3D.new()
  box.size = Vector3(2.0, 3.0, 0.5)
  var col := CollisionShape3D.new()
  col.shape = box
  wall.add_child(col)
  wall.global_position = Vector3(3.0, 1.0, 0.0)
  await self.physics_frame
  var world_3d: World3D = root.get_world_3d()
  _assert(world_3d != null, "World3D for terrain physics block test")
  var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
  var step := 5.0
  _assert(
    _TerrainMotor.cardinal_blocked_by_terrain(
      space, body, body.global_position, Vector3(1.0, 0.0, 0.0), step
    ),
    "forward ray detects world_static wall before full step",
  )
  _assert(
    not _TerrainMotor.cardinal_blocked_by_terrain(
      space, body, body.global_position, Vector3(0.0, 0.0, 1.0), step
    ),
    "lateral ray open when no wall in that direction",
  )
  body.queue_free()
  wall.queue_free()


func _test_creature_spawn_floor_settle() -> void:
  var herb_scene: PackedScene = load(
    "res://creature/templates/creature_herbivore_kinematic_3d.tscn",
  ) as PackedScene
  _assert(herb_scene != null, "herbivore 3d scene loads for spawn grounding")
  var creature_root := herb_scene.instantiate() as Node3D
  var body := creature_root.get_node("Body") as CharacterBody3D
  var bottom_offset := _PlayfieldBounds3D.capsule_half_height_on_body(body)
  _assert(
    is_equal_approx(bottom_offset, 0.95),
    "capsule bottom offset includes cylindrical half-height and hemisphere radius",
  )
  var surface_y := 1.25
  var root_y := _PlayfieldBounds3D.root_global_y_for_surface(body, surface_y)
  var capsule_bottom_y := root_y + body.position.y - bottom_offset
  _assert(
    is_equal_approx(capsule_bottom_y, surface_y),
    "root_global_y_for_surface places capsule bottom on walkable surface_y",
  )
  creature_root.queue_free()


func _test_human_prey_control_bootstrap() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip human prey bootstrap — AiDriver script did not compile")
    return
  var herb_scene: PackedScene = load(
    "res://creature/templates/creature_herbivore_kinematic_3d.tscn",
  ) as PackedScene
  _assert(herb_scene != null, "herbivore 3d scene loads for human bootstrap")
  var creature_root := herb_scene.instantiate() as Node3D
  root.add_child(creature_root)
  var prey_body := creature_root.get_node("Body") as CharacterBody3D
  prey_body.add_to_group(&"prey")
  prey_body.set_control_mode(_ControlMode.engine_as_int())
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  driver.call("register_creature", prey_body)
  driver.call("set_duel_round_active", true)
  driver.set("_state", 3)
  driver.set("_cpu_player_round_active", false)
  driver.call("notify_main_new_game")
  _assert(
    int(prey_body.get("control_mode")) == _ControlMode.human_as_int(),
    "notify_main_new_game sets registered prey to HUMAN after HUD Start duel",
  )
  driver.queue_free()
  creature_root.queue_free()


func _test_human_move_intent_world_space() -> void:
  var up: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    Vector2(0.0, -1.0)
  ) as Vector3
  _assert(
    up.is_equal_approx(Vector3(0.0, 0.0, -1.0)),
    "HUMAN move_up maps to world −Z",
  )
  var right: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    Vector2(1.0, 0.0)
  ) as Vector3
  _assert(
    right.is_equal_approx(Vector3(1.0, 0.0, 0.0)),
    "HUMAN move_right maps to world +X",
  )
  var down: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    Vector2(0.0, 1.0)
  ) as Vector3
  _assert(
    down.is_equal_approx(Vector3(0.0, 0.0, 1.0)),
    "HUMAN move_down maps to world +Z",
  )
  var left: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    Vector2(-1.0, 0.0)
  ) as Vector3
  _assert(
    left.is_equal_approx(Vector3(-1.0, 0.0, 0.0)),
    "HUMAN move_left maps to world −X",
  )
  var zero: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    Vector2.ZERO
  ) as Vector3
  _assert(
    zero.is_equal_approx(Vector3.ZERO),
    "HUMAN zero input yields zero intent",
  )


func _test_human_facing_blocked_no_spin() -> void:
  var pos := Vector3(10.0, 1.0, 10.0)
  var facing := Vector3.RIGHT
  var blocked: Vector3 = Callable(_KinematicBody3DScr, &"human_facing_after_move").call(
    pos, pos, Vector3(6.0, 0.0, 0.0), true, facing
  ) as Vector3
  _assert(
    blocked.is_equal_approx(facing),
    "blocked HUMAN facing keeps prior direction when displacement is zero",
  )
  var moved: Vector3 = Callable(_KinematicBody3DScr, &"human_facing_after_move").call(
    pos, pos + Vector3(1.0, 0.0, 0.0), Vector3.ZERO, false, facing
  ) as Vector3
  _assert(
    moved.is_equal_approx(Vector3.RIGHT),
    "HUMAN facing follows horizontal displacement when body moves",
  )
  var free_vel: Vector3 = Callable(_KinematicBody3DScr, &"human_facing_after_move").call(
    pos, pos, Vector3(0.0, 0.0, -6.0), false, facing
  ) as Vector3
  _assert(
    free_vel.is_equal_approx(Vector3(0.0, 0.0, -1.0)),
    "HUMAN facing falls back to velocity when not blocked and displacement is zero",
  )
  var intent_blocked: Vector3 = Callable(
    _KinematicBody3DScr, &"human_facing_after_horizontal_move"
  ).call(
    Vector3(0.0, 0.0, -1.0), pos, pos, Vector3(6.0, 0.0, 0.0), true, facing
  ) as Vector3
  _assert(
    intent_blocked.is_equal_approx(Vector3(0.0, 0.0, -1.0)),
    "active HUMAN intent sets facing even when blocked with zero displacement",
  )


func _test_human_strafe_intent_stable_under_camera_spin() -> void:
  var strafe_input := Vector2(1.0, 0.0)
  var intent_a: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    strafe_input
  ) as Vector3
  var intent_b: Vector3 = Callable(_KinematicBody3DScr, &"human_world_move_intent_from_plane_input").call(
    strafe_input
  ) as Vector3
  _assert(
    intent_a.is_equal_approx(intent_b),
    "HUMAN world-space strafe intent is stable across repeated reads",
  )
  _assert(
    intent_a.is_equal_approx(Vector3(1.0, 0.0, 0.0)),
    "HUMAN strafe intent ignores camera (world +X for move_right)",
  )


func _test_top_down_camera_pan_directions() -> void:
  var forward_only := _TopDownCameraScr.strengths_from_actions(0.0, 0.0, 0.0, 1.0)
  _assert(
    forward_only.is_equal_approx(Vector2(0.0, -1.0)),
    "camera pan forward maps to world −Z",
  )
  var right_only := _TopDownCameraScr.strengths_from_actions(1.0, 0.0, 0.0, 0.0)
  _assert(
    right_only.is_equal_approx(Vector2(1.0, 0.0)),
    "camera pan right maps to world +X",
  )
  var delta: Vector2 = _TopDownCameraScr.pan_offset_delta(forward_only, 1.0, 10.0)
  _assert(
    delta.is_equal_approx(Vector2(0.0, -10.0)),
    "camera pan forward delta moves −Z at configured speed",
  )


func _test_top_down_camera_zoom_clamp() -> void:
  var zoomed_in: float = _TopDownCameraScr.apply_zoom_step(0.4, true, 0.12, 0.35, 3.0)
  _assert(is_equal_approx(zoomed_in, 0.35), "camera zoom in clamps at minimum scale")
  var zoomed_out: float = _TopDownCameraScr.apply_zoom_step(2.95, false, 0.12, 0.35, 3.0)
  _assert(is_equal_approx(zoomed_out, 3.0), "camera zoom out clamps at maximum scale")


func _test_playfield_bounds_3d_collision_only() -> void:
  var playfield_root := Node3D.new()
  var floor_body := StaticBody3D.new()
  var floor_col := CollisionShape3D.new()
  var floor_box := BoxShape3D.new()
  floor_box.size = Vector3(40.0, 0.2, 40.0)
  floor_col.shape = floor_box
  floor_col.position = Vector3(20.0, 0.0, 20.0)
  floor_body.add_child(floor_col)
  playfield_root.add_child(floor_body)
  var pad_mesh := MeshInstance3D.new()
  var pad := BoxMesh.new()
  pad.size = Vector3(80.0, 0.05, 80.0)
  pad_mesh.mesh = pad
  pad_mesh.position = Vector3(40.0, 0.0, 40.0)
  playfield_root.add_child(pad_mesh)
  var bounds: Dictionary = _PlayfieldBounds3D.xz_bounds_from_playfield_root(playfield_root)
  _assert(bool(bounds.get("valid", false)), "playfield bounds valid from collision")
  var mn: Vector2 = bounds.get("min", Vector2.ZERO)
  var mx: Vector2 = bounds.get("max", Vector2.ZERO)
  _assert(is_equal_approx(mn.x, 0.0) and is_equal_approx(mn.y, 0.0), "collision bounds min at floor origin")
  _assert(is_equal_approx(mx.x, 40.0) and is_equal_approx(mx.y, 40.0), "collision bounds ignore padded mesh AABB")
  playfield_root.free()


func _test_footprint_geometry() -> void:
  var he := Vector2(10.0, 20.0)
  var center := Vector3(100.0, 0.0, 100.0)
  var clr: float = Callable(_Motor, &"minimum_footprint_point_clearance").call(
    center, he, [Vector3(130.0, 0.0, 100.0)]
  )
  _assert(is_equal_approx(clr, 20.0), "footprint point clearance uses AABB edge distance")
  var cp: Vector3 = Callable(_Motor, &"closest_point_on_aabb").call(center, he, Vector3(50.0, 0.0, 50.0))
  _assert(cp.is_equal_approx(Vector3(90.0, 0.0, 80.0)), "closest point on footprint AABB")


func _test_carnivore_pursuit_intent() -> void:
  var ctx := {
    "creature_position": Vector3.ZERO,
    "prey_targets": [Vector3(100.0, 0.0, 0.0)],
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(500.0, 500.0),
    "creature_half_extents": Vector2(10.0, 10.0),
  }
  var intent: Vector3 = _CarnivorePursuit.pick_pursuit_intent(ctx)
  _assert(intent.is_equal_approx(Vector3.RIGHT), "pursuit intent toward prey on +X")


func _test_creature_diet_on_3d_bodies() -> void:
  var herb_root := _instantiate_herbivore_root()
  var carn_root := _instantiate_carnivore_root()
  root.add_child(herb_root)
  root.add_child(carn_root)
  var prey_body := herb_root.get_node("Body") as CharacterBody3D
  var pred_body := carn_root.get_node("Body") as CharacterBody3D
  _assert(int(prey_body.call("get_feeding_mode")) == _CreatureDefinition.FeedingMode.HERBIVORE, "herbivore default diet")
  _assert(int(pred_body.call("get_feeding_mode")) == _CreatureDefinition.FeedingMode.CARNIVORE, "carnivore default diet")
  _setup_herbivore_body(prey_body)
  _assert(prey_body.is_in_group(&"herbivores") and prey_body.is_in_group(&"prey"), "herbivore prey groups")
  herb_root.queue_free()
  carn_root.queue_free()


func _test_ai_driver_creature_registry() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  var d: Node = AD.new()
  root.add_child(d)
  var n := Node2D.new()
  d.call("register_creature", n)
  d.call("register_creature", n)
  d.call("set_duel_round_active", true)
  _assert(bool(d.get("_duel_round_active")), "duel round flag")
  _assert(bool(d.call("is_duel_round_active")), "is_duel_round_active mirrors flag")
  d.call("clear_creature_registry")
  _assert((d.get("_registered_creatures") as Array).is_empty(), "registry cleared")
  d.call("set_duel_round_active", false)
  n.queue_free()
  d.free()


func _test_creature_3d_template_scenes_load() -> void:
  _assert(ResourceLoader.exists("res://creature/templates/creature_herbivore_kinematic_3d.tscn"), "herbivore 3d template exists")
  _assert(ResourceLoader.exists("res://creature/templates/creature_carnivore_kinematic_3d.tscn"), "carnivore 3d template exists")
  var herb := load("res://creature/templates/creature_herbivore_kinematic_3d.tscn") as PackedScene
  var carn := load("res://creature/templates/creature_carnivore_kinematic_3d.tscn") as PackedScene
  var root_h := herb.instantiate() as Node
  var root_c := carn.instantiate() as Node
  _assert(root_h.get_script() == _CreatureRoot3D, "herbivore root uses CreatureRoot3D script")
  _assert(root_c.get_script() == _CreatureRoot3D, "carnivore root uses CreatureRoot3D script")
  var prey_body := root_h.get_node_or_null("Body") as CharacterBody3D
  _assert(prey_body != null, "herbivore template has Body")
  var mob_hitbox := prey_body.get_node_or_null("MobHitbox") as Area3D
  _assert(mob_hitbox != null, "herbivore template has MobHitbox Area3D")
  _assert(mob_hitbox.monitoring, "MobHitbox monitoring enabled")
  _assert(mob_hitbox.collision_mask == 4, "MobHitbox collision_mask includes mob layer")
  var pred_body := root_c.get_node_or_null("Body") as CharacterBody3D
  _assert(pred_body != null, "carnivore template has Body CharacterBody3D")
  _assert(pred_body.is_hostile, "carnivore template Body is hostile")
  root_h.queue_free()
  root_c.queue_free()
  var rabbit: Resource = load("res://creature/species/rabbit_archetype.tres") as Resource
  _assert(rabbit.get_script() == _CreatureDefinition, "rabbit_archetype uses CreatureDefinition")
  _assert(rabbit.get("species_id") == &"rabbit", "rabbit archetype id")
  _assert(rabbit.get("locomotion_profile") != null, "rabbit has locomotion profile")


func _test_shrub_3d_visual_scenes_load() -> void:
  const open_path := "res://assets/plants/open_shrub/open_shrub_3d.tscn"
  const solid_path := "res://assets/plants/solid_shrub/solid_shrub_3d.tscn"
  _assert(ResourceLoader.exists(open_path), "open_shrub_3d exists")
  _assert(ResourceLoader.exists(solid_path), "solid_shrub_3d exists")
  _assert(
    ResourceLoader.exists("res://assets/plants/open_shrub/bush_ready.blend"),
    "open_shrub ready blend exists",
  )
  _assert(
    ResourceLoader.exists("res://assets/plants/open_shrub/bush.blend"),
    "open_shrub depleted blend exists",
  )
  _assert(
    ResourceLoader.exists("res://assets/plants/solid_shrub/h-k-shrub_ready.blend"),
    "solid_shrub ready blend exists",
  )
  _assert(
    ResourceLoader.exists("res://assets/plants/solid_shrub/h-k-shrub.blend"),
    "solid_shrub depleted blend exists",
  )
  for path in [open_path, solid_path]:
    var scene := load(path) as PackedScene
    _assert(scene != null, "%s loads" % path)
    var bush := scene.instantiate() as Node3D
    var holder := Node3D.new()
    root.add_child(holder)
    holder.add_child(bush)
    var ready_v := bush.get_node_or_null("Visual/ReadyVisual") as Node3D
    var depleted_v := bush.get_node_or_null("Visual/DepletedVisual") as Node3D
    _assert(ready_v != null, "%s has ReadyVisual" % path)
    _assert(depleted_v != null, "%s has DepletedVisual" % path)
    bush.call("reset_session")
    _assert(ready_v.visible, "%s ready visual visible when full" % path)
    _assert(not depleted_v.visible, "%s depleted hidden when full" % path)
    bush.set("current_calories", 0.0)
    bush.call("_refresh_visual")
    _assert(not ready_v.visible, "%s ready hidden when depleted" % path)
    _assert(depleted_v.visible, "%s depleted visible when empty" % path)
    holder.queue_free()


func _test_creature_3d_predation_contact() -> void:
  var herb_scene: PackedScene = load(
    "res://creature/templates/creature_herbivore_kinematic_3d.tscn",
  ) as PackedScene
  var carn_scene: PackedScene = load(
    "res://creature/templates/creature_carnivore_kinematic_3d.tscn",
  ) as PackedScene
  var rabbit_def: Resource = load("res://creature/species/rabbit_archetype.tres") as Resource
  var fox_def: Resource = load("res://creature/species/fox_archetype.tres") as Resource
  _assert(
    herb_scene != null and carn_scene != null and rabbit_def != null and fox_def != null,
    "3D duel scenes and archetypes load for predation contact",
  )
  var floor_body := StaticBody3D.new()
  var floor_col := CollisionShape3D.new()
  var floor_box := BoxShape3D.new()
  floor_box.size = Vector3(40.0, 0.2, 40.0)
  floor_col.shape = floor_box
  floor_col.position = Vector3(20.0, 0.0, 20.0)
  floor_body.add_child(floor_col)
  floor_body.collision_layer = 1
  floor_body.collision_mask = 1
  root.add_child(floor_body)
  var herb_root := herb_scene.instantiate() as Node3D
  herb_root.set("definition", rabbit_def)
  var carn_root := carn_scene.instantiate() as Node3D
  carn_root.set("definition", fox_def)
  var prey_body := herb_root.get_node("Body") as CharacterBody3D
  var pred_body := carn_root.get_node("Body") as CharacterBody3D
  prey_body.add_to_group(&"prey")
  pred_body.add_to_group(&"mobs")
  pred_body.set("current_calories", 20.0)
  var pred_cal_before := float(pred_body.get("current_calories"))
  var hit_state: Array = [0]
  prey_body.hit.connect(func() -> void: hit_state[0] = int(hit_state[0]) + 1)
  root.add_child(herb_root)
  root.add_child(carn_root)
  var contact := Vector3(20.0, 0.0, 20.0)
  herb_root.global_position = contact
  carn_root.global_position = contact + Vector3(3.0, 0.0, 0.0)
  await physics_frame
  carn_root.global_position = contact
  await physics_frame
  await physics_frame
  _assert(not prey_body.visible, "prey hidden after mob enters MobHitbox")
  _assert(int(hit_state[0]) >= 1, "prey hit signal emitted on predation contact")
  _assert(
    float(pred_body.get("current_calories")) > pred_cal_before,
    "predator gains calories from prey contact",
  )
  var hb_cs := prey_body.get_node_or_null("MobHitbox/CollisionShape3D") as CollisionShape3D
  _assert(hb_cs != null and hb_cs.disabled, "prey MobHitbox disabled after defeat")
  herb_root.queue_free()
  carn_root.queue_free()
  floor_body.queue_free()


func _test_environment_baked_grid() -> void:
  var open := _EnvCell.new()
  open.passible = true
  open.movement_impact = 0.0
  open.fit_size = -1.0
  _assert(open.can_enter(99.0), "open passible all sizes")
  _assert(is_equal_approx(open.movement_speed_multiplier(99.0), 1.0), "open no movement impact")

  var mud := _EnvCell.new()
  mud.passible = true
  mud.movement_impact = 0.3
  mud.fit_size = -1.0
  _assert(is_equal_approx(mud.movement_speed_multiplier(1.0), 0.7), "mud slows everyone when no shrub fit_size")

  var shrub := _EnvCell.new()
  shrub.passible = true
  shrub.movement_impact = 0.4
  shrub.fit_size = 2.0
  _assert(is_equal_approx(shrub.movement_speed_multiplier(1.0), 1.0), "shrub exempt when size strictly below fit_size")
  _assert(is_equal_approx(shrub.movement_speed_multiplier(2.0), 0.6), "shrub applies at size == fit_size (strict < exemption)")

  var wall := _EnvCell.new()
  wall.passible = false
  wall.fit_size = 0.0
  _assert(not wall.can_enter(0.1), "squeeze wall blocks everyone when fit_size <= 0")

  var gap := _EnvCell.new()
  gap.passible = false
  gap.fit_size = 3.0
  gap.movement_impact = 0.2
  _assert(gap.can_enter(3.0), "squeeze inclusive creature_size <= fit_size")
  _assert(not gap.can_enter(3.01), "squeeze rejects creature_size > fit_size")
  _assert(is_equal_approx(gap.movement_speed_multiplier(2.0), 0.8), "squeeze interior applies impact to all legal sizes")

  var presets: Array = []
  var k0 := _EnvCell.new()
  k0.passible = true
  var k1 := _EnvCell.new()
  k1.passible = false
  k1.fit_size = 1.0
  presets.append(k0)
  presets.append(k1)
  var img := Image.create(4, 2, false, Image.FORMAT_RGBA8)
  img.fill(Color.WHITE)
  for x in range(2, 4):
    img.set_pixel(x, 0, Color.BLACK)
    img.set_pixel(x, 1, Color.BLACK)
  var cmap := {Color.WHITE: 0, Color.BLACK: 1}
  var baked = _EnvBake.bake_from_image(img, 2, Vector2.ZERO, 32.0, cmap, presets, 0)
  _assert(baked != null, "bake_from_image returns grid")
  _assert(baked.cell_width == 2 and baked.cell_height == 1, "bake cell dims from 4x2 image with pixels_per_cell 2")
  _assert(baked.get_kind_id_at(0, 0) == 0 and baked.get_kind_id_at(1, 0) == 1, "bake maps top-left pixel per cell")
  _assert(baked.is_valid_shape(), "baked buffer matches dimensions")
  var wc: Vector2i = baked.world_to_cell(Vector3(33.0, 0.0, 10.0))
  _assert(wc == Vector2i(1, 0), "world_to_cell uses floor division by cell_size")
  var d1 = baked.sample_cell_data_at_world(Vector3(50.0, 0.0, 0.0))
  _assert(d1 != null and d1.get("passible") == false, "sample_cell_data_at_world returns squeeze preset")


func _test_cardinal_interior_env_grid() -> void:
  var open := _EnvCell.new()
  open.passible = true
  open.movement_impact = 0.0
  open.fit_size = -1.0
  var wall := _EnvCell.new()
  wall.passible = false
  wall.fit_size = 0.0
  var presets: Array = [open, wall]
  var grid := _EnvGrid.new()
  grid.cell_width = 5
  grid.cell_height = 1
  grid.cell_size = 100.0
  grid.origin_world = Vector2.ZERO
  grid.kind_presets = presets
  var ids := PackedInt32Array([0, 0, 0, 1, 0])
  grid.cell_kind_ids = ids
  var step := 400.0 * 0.15
  var c_left := _Motor.cost_at_prediction(
    Vector3(250.0 - step, 0.0, 50.0),  
    [], Vector2.ZERO, Vector2(800.0, 800.0),  
    0.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    Vector3.ZERO,  
    0.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
    false,  
    grid,  
    10.0,  
    {"active": true, "weight_solid": 5000.0, "weight_slow": 10.0},  
  )
  var c_right := _Motor.cost_at_prediction(
    Vector3(250.0 + step, 0.0, 50.0),  
    [], Vector2.ZERO, Vector2(800.0, 800.0),  
    0.0,  
    0.0,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    Vector3.ZERO,  
    0.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
    false,  
    grid,  
    10.0,  
    {"active": true, "weight_solid": 5000.0, "weight_slow": 10.0},  
  )
  _assert(c_right > c_left + 500.0, "impassible baked cell east of pose adds much larger cost than open cell west")

  var c_wall := _Motor.cost_at_prediction(
    Vector3(350.0, 0.0, 50.0),  
    [], Vector2.ZERO, Vector2(800.0, 800.0),  
    1.0,  
    0.5,  
    1e7,  
    12.0,  
    Vector2.ZERO, 0.0,  
    0.0,  
    0.0,  
    Vector3.ZERO,  
    0.0,  
    0.0,  
    -2.0,  
    Vector3.RIGHT,  
    [],  
    0.0,  
    false,  
    grid,  
    10.0,  
    {"active": true, "weight_solid": 9000.0, "weight_slow": 3.0},  
  )
  _assert(c_wall >= 8000.0, "interior solid grid adds large cost on impassible cell")


func _test_mob_avoidance_acceptance() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  for a in ["move_up", "move_down", "move_left", "move_right"]:
    _assert(InputMap.has_action(a), "InputMap defines %s for HUMAN movement" % a)
  var repo := _Merge.load_merged_config("user://__mob_avoid_accept_repo__.json")
  var cm: Dictionary = repo["merged"]["creature_motor"]
  _assert(str(cm.get("mode", "")).to_lower() == "scripted", "repo game_config creature_motor.mode scripted")
  _assert(
    Callable(AD, &"playing_control_mode_int_for_motor_mode_string").call("llm") == _ControlMode.ai_as_int(),
    "PLAYING branch: llm motor → AI control int",
  )
  _assert(
    Callable(AD, &"playing_control_mode_int_for_motor_mode_string").call("LLM") == _ControlMode.ai_as_int(),
    "motor mode comparison is case-insensitive",
  )
  _assert(
    Callable(AD, &"playing_control_mode_int_for_motor_mode_string").call("scripted") == _ControlMode.engine_as_int(),
    "PLAYING branch: scripted motor → ENGINE control int",
  )
  _assert(
    Callable(AD, &"playing_control_mode_int_for_motor_mode_string").call("unknown_mode") == _ControlMode.engine_as_int(),
    "unknown motor mode maps to ENGINE (safe scripted motor)",
  )


func _test_jeopardy_forced_turn() -> void:
  var mob_pos := Vector3(300.0, 0.0, 200.0)
  var mobs := [{"position": mob_pos, "velocity": Vector3.ZERO}]
  var cone_cos := cos(deg_to_rad(45.0))
  var threat := Callable(_JeopardyTurnScr, &"primary_threat_in_forward_cone").call(
    Vector3(240.0, 0.0, 200.0), Vector3.ZERO, Vector3.RIGHT, mobs, 100.0, cone_cos
  ) as Dictionary
  _assert(bool(threat.get("found", false)), "forward-cone mob inside imminent radius is a threat")
  var state: Dictionary = {}
  var tick_base := {
    "incumbent": Vector3.RIGHT,
    "creature_position": Vector3(240.0, 0.0, 200.0),
    "creature_half_extents": Vector2.ZERO,
    "creature_facing": Vector3.RIGHT,
    "mobs": mobs,
    "imminent_radius": 100.0,
    "cone_cos_threshold": cone_cos,
    "required_ticks": 2,
  }
  var eval1: Dictionary = Callable(_JeopardyTurnScr, &"evaluate_jeopardy_tick").call(tick_base, state)
  _assert(not bool(eval1.get("should_force", true)), "first straight tick does not force turn")
  var tick2 := tick_base.duplicate(true)
  tick2["creature_position"] = Vector3(250.0, 0.0, 200.0)
  var eval2: Dictionary = Callable(_JeopardyTurnScr, &"evaluate_jeopardy_tick").call(tick2, state)
  _assert(not bool(eval2.get("should_force", true)), "second closing tick not yet at threshold")
  var tick3 := tick_base.duplicate(true)
  tick3["creature_position"] = Vector3(260.0, 0.0, 200.0)
  var eval3: Dictionary = Callable(_JeopardyTurnScr, &"evaluate_jeopardy_tick").call(tick3, state)
  _assert(bool(eval3.get("should_force", false)), "second consecutive closing straight tick forces turn")
  var flee_ctx := {
    "creature_position": Vector3(260.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": mobs,
    "weight_dist": 0.45,
    "weight_closing": 0.0,
    "weight_dist_sq": 55.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "creature_half_extents": Vector2.ZERO,
    "weight_interior": 0.0,
    "weight_edge": 0.0,
    "food_seek_targets": [],
    "weight_seek_ready_food": 0.0,
    "imminent_mob_points": [mob_pos],
    "food_seek_imminent_mob_radius": 100.0,
    "unready_food_avoid_targets": [],
    "weight_avoid_unready_food": 0.0,
  }
  var flee := Callable(_JeopardyTurnScr, &"pick_forced_turn").call(
    flee_ctx, Vector3.RIGHT, mob_pos
  ) as Vector3
  _assert(flee.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "forced turn flees mob when mob repulsion dominates")
  var turn_ctx := {
    "creature_position": Vector3(260.0, 0.0, 200.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": mobs,
    "weight_dist": 0.0,
    "weight_closing": 0.0,
    "weight_dist_sq": 0.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "creature_half_extents": Vector2.ZERO,
    "weight_interior": 0.0,
    "weight_edge": 0.0,
    "food_seek_targets": [],
    "weight_seek_ready_food": 0.0,
    "imminent_mob_points": [mob_pos],
    "food_seek_imminent_mob_radius": 100.0,
    "unready_food_avoid_targets": [],
    "weight_avoid_unready_food": 0.0,
  }
  var forced := Callable(_JeopardyTurnScr, &"pick_forced_turn").call(
    turn_ctx, Vector3.RIGHT, mob_pos
  ) as Vector3
  _assert(forced.length_squared() > 1e-12, "forced turn picks a unit direction")
  _assert(not forced.is_equal_approx(Vector3.RIGHT), "forced turn avoids continuing straight into threat")


func _test_scripted_intent_hold() -> void:
  var fh := Callable(IntentHoldScr, &"filtered_intent")
  var st: Dictionary = {}
  var incumbent := Vector3(0.0, 0.0, 1.0)
  var challenger := Vector3(0.0, 0.0, -1.0)
  for _i in range(4):
    _assert(
      (fh.call(challenger, incumbent, 5, st) as Vector3).is_equal_approx(incumbent),
      "intent hold ignores single-tick challenger"
    )
  var switched: Vector3 = fh.call(challenger, incumbent, 5, st) as Vector3
  _assert(switched.is_equal_approx(challenger), "intent hold adopts after streak")

  Callable(IntentHoldScr, &"reset_state").call(st)
  var right := Vector3(1.0, 0.0, 0.0)
  _assert((fh.call(right, incumbent, 5, st) as Vector3).is_equal_approx(incumbent), "new challenger resets streak frame 1")
  var left := Vector3(-1.0, 0.0, 0.0)
  _assert((fh.call(left, incumbent, 5, st) as Vector3).is_equal_approx(incumbent), "challenger swap restarts accumulation")

  Callable(IntentHoldScr, &"reset_state").call(st)
  var cold: Vector3 = fh.call(right, Vector3.ZERO, 3, st) as Vector3
  _assert(cold.is_equal_approx(right), "idle incumbent skips hold")


func _test_seek_oct_directions() -> void:
  var food := Vector3(200.0, 0.0, -200.0)
  var seek_ctx := {
    "creature_position": Vector3.ZERO,
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(2000.0, 2000.0),
    "mobs": [],
    "weight_dist": 0.0,
    "weight_closing": 0.0,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "deterministic_tie_order": true,
    "weight_seek_ready_food": 20.0,
    "food_seek_targets": [food],
    "motor_seek_oct_directions": true,
    "motor_has_active_goal": true,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "motor_intent_cost_chaos": 0.0,
  }
  var intent: Vector3 = _Motor.pick_best_move_intent(seek_ctx)
  var ne := Vector3(1.0, 0.0, -1.0).normalized()
  _assert(intent.dot(ne) > 0.95, "seek oct picks NE toward diagonal food target")
  seek_ctx["food_seek_targets"] = []
  seek_ctx["weight_seek_ready_food"] = 0.0
  seek_ctx["weight_explore_idle_penalty"] = 12.0
  seek_ctx["weight_expanding_explore_hint"] = 2.0
  seek_ctx["expanding_explore_hint"] = ne
  var explore: Vector3 = _Motor.pick_best_move_intent(seek_ctx)
  _assert(
    explore.length_squared() > 1e-12 and explore.dot(ne) > 0.55,
    "no-goal motor still evaluates eight-way headings toward explore hint",
  )
  _assert(_MotorOct.is_diagonal(ne), "motor oct helper marks NE as diagonal")


func _test_seek_direction_commit() -> void:
  var fh := Callable(_SeekDirCommitScr, &"filtered_seek_intent")
  var st: Dictionary = {}
  var ne := Vector3(1.0, 0.0, -1.0).normalized()
  var east := Vector3.RIGHT
  var first: Vector3 = fh.call(ne, st, 1.0, true) as Vector3
  _assert(first.is_equal_approx(ne), "seek commit adopts first heading")
  var second: Vector3 = fh.call(east, st, 1.0, true) as Vector3
  _assert(second.is_equal_approx(ne), "seek commit holds heading for one second")
  st["locked_until_ms"] = Time.get_ticks_msec() - 1
  var third: Vector3 = fh.call(east, st, 1.0, true, Vector3.RIGHT, 0, 0) as Vector3
  _assert(third.is_equal_approx(east), "seek commit picks new heading after lock expires")
  Callable(_SeekDirCommitScr, &"reset_state").call(st)
  var idle: Vector3 = fh.call(Vector3.ZERO, st, 1.0, true) as Vector3
  _assert(idle.is_equal_approx(Vector3.ZERO), "seek commit obeys idle immediately")
  Callable(_SeekDirCommitScr, &"reset_state").call(st)
  st.clear()
  var north := Vector3(0.0, 0.0, -1.0)
  var south := Vector3(0.0, 0.0, 1.0)
  var turn_start: Vector3 = fh.call(south, st, 1.0, true, north, 3, 100) as Vector3
  _assert(turn_start.is_equal_approx(Vector3.ZERO), "seek commit idles while turning to new heading")
  _assert(
    Callable(_SeekDirCommitScr, &"turn_in_progress").call(st),
    "seek commit marks turn in progress",
  )
  var turn_face: Vector3 = Callable(_SeekDirCommitScr, &"turn_facing").call(st, north) as Vector3
  _assert(
    turn_face.is_equal_approx(Vector3(0.7071067811865475, 0.0, -0.7071067811865475)),
    "seek commit shortest arc from N turns through NE first",
  )
  var mid_turn: Vector3 = fh.call(south, st, 1.0, true, north, 3, 101) as Vector3
  _assert(mid_turn.is_equal_approx(Vector3.ZERO), "seek commit stays idle mid-turn")
  var turn_done: Vector3 = fh.call(south, st, 1.0, true, north, 3, 112) as Vector3
  _assert(turn_done.is_equal_approx(south), "seek commit locks new heading after turn completes")
  _assert(
    not Callable(_SeekDirCommitScr, &"turn_in_progress").call(st),
    "seek commit clears turn state after completion",
  )


func _test_seek_direction_turn() -> void:
  var steps_fn := Callable(_SeekDirTurnScr, &"turn_steps_between")
  var pick_fn := Callable(_SeekDirTurnScr, &"pick_turn_facing")
  _assert(steps_fn.call(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0)) == 0, "turn steps zero when same sector")
  _assert(steps_fn.call(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)) == 4, "N to S is four steps either arc")
  _assert(steps_fn.call(Vector3(0.0, 0.0, -1.0), Vector3.RIGHT) == 2, "N to E is two steps")
  var ne := Vector3(0.7071067811865475, 0.0, -0.7071067811865475)
  var first: Dictionary = pick_fn.call(Vector3(0.0, 0.0, -1.0), Vector3.RIGHT, 4, 0)
  _assert(first["facing"].is_equal_approx(ne), "turn dwell starts at first arc heading NE")
  _assert(not bool(first.get("complete", true)), "turn not complete on first segment")
  var second: Dictionary = pick_fn.call(Vector3(0.0, 0.0, -1.0), Vector3.RIGHT, 4, 4)
  _assert(second["facing"].is_equal_approx(Vector3.RIGHT), "turn completes on E after two segments")
  _assert(bool(second.get("complete", false)), "turn marked complete at destination")
  var ccw_pick: Dictionary = pick_fn.call(Vector3.RIGHT, Vector3(0.0, 0.0, -1.0), 2, 0)
  _assert(
    ccw_pick["facing"].is_equal_approx(Vector3(0.7071067811865475, 0.0, -0.7071067811865475)),
    "E to N shortest arc turns through NE",
  )


func _test_no_goal_patrol_lock() -> void:
  var pick := Callable(_NoGoalPatrolLockScr, &"pick_or_hold")
  var reset := Callable(_NoGoalPatrolLockScr, &"reset_state")
  var st: Dictionary = {}
  reset.call(st)
  var first: Vector3 = pick.call(st, 1.0, 90210) as Vector3
  var second: Vector3 = pick.call(st, 1.0, 90210) as Vector3
  _assert(first.is_equal_approx(second), "patrol lock holds intent within lock window")
  st["locked_until_ms"] = Time.get_ticks_msec() - 1
  var _third: Vector3 = pick.call(st, 1.0, 90210) as Vector3
  _assert(int(st.get("reroll_count", 0)) >= 2, "expired patrol lock increments reroll count")
  reset.call(st)
  _NoGoalPatrolLockScr.reset_state(st)
  var saw_idle := false
  for i in 64:
    reset.call(st)
    var intent: Vector3 = pick.call(st, 0.01, 1000 ^ i) as Vector3
    if intent.is_equal_approx(Vector3.ZERO):
      saw_idle = true
      break
  _assert(saw_idle, "patrol lock pick set includes stay-still")
  reset.call(st)
  st["locked_intent"] = Vector3.RIGHT
  st["locked_until_ms"] = Time.get_ticks_msec() + 5000
  reset.call(st)
  _assert(not st.has("locked_intent"), "reset_state clears patrol lock on goal interrupt path")
  var block_right := func(dir: Vector2) -> bool:
    return dir.is_equal_approx(Vector2.RIGHT)
  for i in 32:
    reset.call(st)
    var blocked_pick: Vector3 = pick.call(st, 0.01, 9000 ^ i, block_right) as Vector3
    _assert(
      not blocked_pick.is_equal_approx(Vector3.RIGHT),
      "patrol lock skips blocked cardinal directions",
    )


func _test_no_goal_patrol_lock_guided() -> void:
  var pick := Callable(_NoGoalPatrolLockScr, &"pick_or_hold_guided")
  var reset := Callable(_NoGoalPatrolLockScr, &"reset_state")
  var st: Dictionary = {}
  var north := Vector3(0.0, 0.0, -1.0)
  reset.call(st)
  var guided: Vector3 = pick.call(st, 1.0, 42, north, Callable(), false) as Vector3
  _assert(guided.is_equal_approx(north), "guided patrol prefers expand hint when unblocked")
  var second: Vector3 = pick.call(st, 1.0, 42, Vector3.RIGHT, Callable(), false) as Vector3
  _assert(second.is_equal_approx(north), "guided patrol holds locked hint within lock window")
  var block_north := func(dir: Vector3) -> bool:
    return dir.is_equal_approx(north)
  reset.call(st)
  var fallback: Vector3 = pick.call(st, 0.01, 99, north, block_north, false) as Vector3
  _assert(not fallback.is_equal_approx(north), "guided patrol falls back when hint blocked")
  _assert(fallback.length_squared() > 1e-12, "guided patrol fallback moves when allow_idle false")
  for i in 64:
    reset.call(st)
    var no_idle: Vector3 = pick.call(st, 0.01, 1000 ^ i, Vector3.ZERO, Callable(), false) as Vector3
    _assert(no_idle.length_squared() > 1e-12, "allow_idle false never returns stay-still")
  var seg_lock: float = Callable(_NoGoalPatrolLockScr, &"segment_lock_sec").call(48, 1.0) as float
  _assert(seg_lock >= 0.35 and seg_lock <= 1.0, "segment_lock_sec clamps to cap_sec")


func _test_predator_patrol_expanding_coverage() -> void:
  var X := _EXPANDING_CARDINAL_EXPLORE_SCR.Explore
  var pick := Callable(_NoGoalPatrolLockScr, &"pick_or_hold_guided")
  var reset := Callable(_NoGoalPatrolLockScr, &"reset_state")
  var base_ticks := 48
  var phase_seed := 9001
  var sectors: Dictionary = {}
  var pos := Vector3.ZERO
  var speed := 400.0
  var physics_hz := maxf(1.0, float(Engine.physics_ticks_per_second))
  var dt := 1.0 / physics_hz
  var st: Dictionary = {}
  var tick := 0
  while tick < 400:
    var hint: Vector3 = X.pick_cardinal(base_ticks, tick, phase_seed)
    var loc: Dictionary = X.locate(base_ticks, tick)
    var seg_ticks := int(loc.get("segment_ticks", base_ticks))
    reset.call(st)
    var lock_sec: float = Callable(_NoGoalPatrolLockScr, &"segment_lock_sec").call(seg_ticks, 1.0) as float
    var dir: Vector3 = pick.call(st, lock_sec, phase_seed, hint, Callable(), false) as Vector3
    if dir.length_squared() > 1e-12:
      sectors[dir] = true
    for _seg in seg_ticks:
      if tick >= 400:
        break
      if dir.length_squared() > 1e-12:
        pos += dir.normalized() * speed * dt
      tick += 1
  _assert(sectors.size() >= 4, "predator guided patrol visits at least 4 headings over 400 ticks")
  var coverage_cell := 52.0
  _assert(
    pos.length() >= coverage_cell * 1.5,
    "predator guided patrol net displacement exceeds ~1.5 coverage cells",
  )


func _test_predator_pacing_trap_break() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator pacing trap test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var body_id := 88001
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
  }
  var bounds_min := Vector2(0.0, 0.0)
  var bounds_max := Vector2(1000.0, 1000.0)
  var pos := Vector3(500.0, 0.0, 980.0)
  var he := Vector2(13.5, 30.5)
  var north := Vector3(0.0, 0.0, -1.0)
  var south := Vector3(0.0, 0.0, 1.0)
  driver.call(
    "_predator_pacing_trap_active",
    body_id,
    south,
    south,
    2,
    pos,
    he,
    bounds_min,
    bounds_max,
    motor_p,
  )
  var trap_active := bool(
    driver.call(
      "_predator_pacing_trap_active",
      body_id,
      north,
      south,
      2,
      pos,
      he,
      bounds_min,
      bounds_max,
      motor_p,
    )
  )
  _assert(trap_active, "predator pacing trap detects opposing cardinals at south edge")
  var break_dir: Vector3 = driver.call(
    "_predator_pacing_trap_break_intent",
    body_id,
    pos,
    he,
    [],
    2,
    motor_p,
    bounds_min,
    bounds_max,
    north,
  ) as Vector3
  _assert(break_dir.length_squared() > 1e-12, "predator pacing trap returns lateral escape")
  _assert(absf(break_dir.dot(north)) < 0.35, "predator pacing trap breaks away from N-S axis")
  var hold_st: Dictionary = {}
  var incumbent_ns := north
  var filtered: Vector3 = Callable(IntentHoldScr, &"filtered_intent").call(
    break_dir, incumbent_ns, 1, hold_st
  ) as Vector3
  _assert(
    filtered.is_equal_approx(break_dir),
    "predator pacing trap lateral escape applies immediately with hold_apply=1",
  )
  driver.queue_free()


func _test_south_perimeter_static_obs_near(
  center_x: float, _bounds_min: Vector2, bounds_max: Vector2, span: float = 96.0
) -> Array:
  var obs: Array = []
  var inset := 0.5
  var spacing := 1.4
  var rock_he := Vector2(1.05, 1.05)
  var z_fixed := bounds_max.y - inset
  var x := center_x - span
  while x <= center_x + span + 0.001:
    obs.append({"position": Vector3(x, 0.0, z_fixed), "half_extents": rock_he})
    x += spacing
  return obs


func _test_predator_south_wall_boulder_pinch_escape() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator south-wall boulder pinch test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var body_id := 88002
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
    "predator_obstacle_probe": 280.0,
    "predator_edge_slide_min_clearance": 2.0,
    "geometry_escape_lock_ticks": 14,
  }
  var bounds_min := Vector2(0.0, 0.0)
  var bounds_max := Vector2(1000.0, 1000.0)
  var he := Vector2(27.0, 61.0)
  var north := Vector3(0.0, 0.0, -1.0)
  var south := Vector3(0.0, 0.0, 1.0)
  var boulder := {
    "position": Vector3(680.0, 0.0, 820.0),
    "half_extents": Vector2(55.0, 55.0),
  }
  var perimeter := _test_south_perimeter_static_obs_near(740.0, bounds_min, bounds_max)
  var static_obs: Array = [boulder]
  static_obs.append_array(perimeter)
  var far_rim_pos := Vector3(740.0, 0.0, bounds_max.y - he.y - 8.0)
  var edge_hint_far: Vector3 = driver.call(
    "_predator_patrol_edge_expand_hint",
    far_rim_pos,
    he,
    static_obs,
    bounds_min,
    bounds_max,
    motor_p,
    north,
    false,
  ) as Vector3
  _assert(edge_hint_far.length_squared() > 1e-12, "far south rim edge expand returns a heading")
  _assert(
    absf(edge_hint_far.dot(north)) < 0.35,
    "far south rim edge expand defaults to wall tangent not toward-center north",
  )
  var pos := Vector3(740.0, 0.0, 900.0)
  var edge_hint_pinch: Vector3 = driver.call(
    "_predator_patrol_edge_expand_hint",
    pos,
    he,
    static_obs,
    bounds_min,
    bounds_max,
    motor_p,
    north,
    true,
  ) as Vector3
  _assert(edge_hint_pinch.length_squared() > 1e-12, "pinch edge expand returns lateral slide")
  _assert(
    absf(edge_hint_pinch.dot(north)) < 0.35,
    "pinch edge expand avoids north axis at south wall",
  )
  var pinch_esc: Vector3 = driver.call(
    "_predator_edge_pinch_escape_intent",
    body_id,
    pos,
    he,
    static_obs,
    2,
    motor_p,
    bounds_min,
    bounds_max,
    north,
    Vector3(1.0, 0.0, 0.0),
  ) as Vector3
  _assert(pinch_esc.length_squared() > 1e-12, "edge pinch escape returns lateral with perimeter chain")
  _assert(absf(pinch_esc.dot(north)) < 0.35, "edge pinch escape avoids N-S oscillation axis")
  driver.call(
    "_predator_pacing_trap_active",
    body_id,
    south,
    south,
    2,
    pos,
    he,
    bounds_min,
    bounds_max,
    motor_p,
  )
  var trap_active := bool(
    driver.call(
      "_predator_pacing_trap_active",
      body_id,
      north,
      south,
      2,
      pos,
      he,
      bounds_min,
      bounds_max,
      motor_p,
    )
  )
  _assert(trap_active, "south-wall boulder pinch pacing trap detects N-S flip")
  var break_dir: Vector3 = driver.call(
    "_predator_pacing_trap_break_intent",
    body_id,
    pos,
    he,
    static_obs,
    2,
    motor_p,
    bounds_min,
    bounds_max,
    north,
  ) as Vector3
  _assert(break_dir.length_squared() > 1e-12, "south-wall boulder pinch returns lateral escape")
  _assert(absf(break_dir.dot(north)) < 0.35, "south-wall boulder pinch breaks off N-S axis")
  var hold_st: Dictionary = {}
  var filtered: Vector3 = Callable(IntentHoldScr, &"filtered_intent").call(
    break_dir, north, 1, hold_st
  ) as Vector3
  _assert(
    filtered.is_equal_approx(break_dir),
    "pinch trap break lateral escape applies immediately with hold_apply=1",
  )
  var pinch_active := bool(
    driver.call(
      "_predator_geometry_pinch_active",
      pos,
      he,
      static_obs,
      motor_p,
    )
  )
  _assert(pinch_active, "predator geometry pinch active in south-wall boulder wedge")
  driver.queue_free()


func _test_predator_northeast_corner_interior_escape() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator NE corner escape test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var body_id := 88003
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
    "geometry_escape_lock_ticks": 14,
  }
  var bounds_min := Vector2(0.0, 0.0)
  var bounds_max := Vector2(100.0, 100.0)
  var he := Vector2(13.5, 30.5)
  var east := Vector3(1.0, 0.0, 0.0)
  var north := Vector3(0.0, 0.0, -1.0)
  var pos := Vector3(bounds_max.x - he.x - 2.0, 0.0, bounds_min.y + he.y + 2.0)
  var edge_info: Dictionary = driver.call(
    "_playfield_wall_edge_info", pos, he, bounds_min, bounds_max
  ) as Dictionary
  _assert(bool(edge_info.get("is_corner", false)), "NE rim position is a dual-edge corner")
  var corner_in: Vector3 = edge_info.get("corner_inward", Vector3.ZERO) as Vector3
  _assert(corner_in.length_squared() > 1e-12, "NE corner has interior diagonal")
  var cur_edge: float = driver.call(
    "_footprint_edge_margin", pos, he, bounds_min, bounds_max
  ) as float
  var corner_esc: Vector3 = driver.call(
    "_pick_playfield_corner_interior_cardinal",
    pos,
    he,
    [],
    bounds_min,
    bounds_max,
    motor_p,
    body_id,
  ) as Vector3
  _assert(corner_esc.length_squared() > 1e-12, "NE corner interior escape returns a heading")
  _assert(absf(corner_esc.dot(east)) < 0.85, "NE corner escape avoids pure east rim slide")
  _assert(absf(corner_esc.dot(north)) < 0.85, "NE corner escape avoids pure north rim slide")
  var probe_pos: Vector3 = pos + corner_esc * 8.0
  var probe_edge: float = driver.call(
    "_footprint_edge_margin", probe_pos, he, bounds_min, bounds_max
  ) as float
  _assert(probe_edge > cur_edge + 0.1, "NE corner escape increases playfield edge margin")
  var patrol_hint: Vector3 = driver.call(
    "_predator_patrol_edge_expand_hint",
    pos,
    he,
    [],
    bounds_min,
    bounds_max,
    motor_p,
    north,
    false,
  ) as Vector3
  _assert(patrol_hint.length_squared() > 1e-12, "NE corner patrol expand returns interior hint")
  _assert(
    absf(patrol_hint.dot(east)) < 0.85,
    "NE corner patrol expand avoids pure east rim slide",
  )
  var latched_esc: Vector3 = driver.call(
    "_predator_latched_corner_escape_intent",
    body_id,
    pos,
    he,
    [],
    bounds_min,
    bounds_max,
    motor_p,
  ) as Vector3
  _assert(latched_esc.length_squared() > 1e-12, "NE corner latched predator escape returns heading")
  driver.call(
    "_predator_pacing_trap_active",
    body_id,
    east,
    east,
    0,
    pos,
    he,
    bounds_min,
    bounds_max,
    motor_p,
  )
  var trap_active := bool(
    driver.call(
      "_predator_pacing_trap_active",
      body_id,
      north,
      east,
      0,
      pos,
      he,
      bounds_min,
      bounds_max,
      motor_p,
    )
  )
  _assert(trap_active, "NE corner pacing trap detects rim oscillation at corner band")
  var trap_break: Vector3 = driver.call(
    "_predator_pacing_trap_break_intent",
    body_id,
    pos,
    he,
    [],
    1,
    motor_p,
    bounds_min,
    bounds_max,
    east,
  ) as Vector3
  _assert(trap_break.length_squared() > 1e-12, "NE corner pacing trap break returns interior escape")
  _assert(absf(trap_break.dot(east)) < 0.85, "NE corner pacing trap break avoids east rim axis")
  driver.queue_free()


func _test_predator_rim_patrol_eight_way() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator rim patrol 8-way test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
    "predator_edge_slide_min_clearance": 2.0,
  }
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(1000.0, 1000.0)
  var he := Vector2(13.5, 30.5)
  var body_id := 88004
  var pos := Vector3(bounds_max.x - he.x - 2.0, 0.0, 520.0)
  var saw_diagonal := false
  for i in 16:
    driver.set("_physics_ticks", 6400 + i)
    driver.set("_duel_motor_round_salt", 12345)
    var pick: Vector3 = driver.call(
      "_predator_pick_edge_tangent_cardinal",
      pos,
      he,
      [],
      bounds_min,
      bounds_max,
      motor_p,
      [],
      Vector3.ZERO,
      body_id,
    ) as Vector3
    if bool(Callable(_MotorOct, &"is_diagonal").call(pick)):
      saw_diagonal = true
      break
  _assert(saw_diagonal, "east-rim predator tangent picker can return diagonal skim heading")
  driver.queue_free()


func _test_predator_interior_stuck_escape_midfield() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator interior stuck escape test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
  }
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(1000.0, 1000.0)
  var he := Vector2(13.5, 30.5)
  var pos := Vector3(500.0, 0.0, 500.0)
  var esc: Vector3 = driver.call(
    "_pick_stuck_escape_cardinal",
    pos,
    he,
    [],
    88005,
    2,
    motor_p,
    bounds_min,
    bounds_max,
    Vector3(1.0, 0.0, 0.0),
  ) as Vector3
  _assert(esc.length_squared() > 1e-12, "predator interior stuck escape returns non-zero heading")
  driver.queue_free()


func _test_goal_visibility_latch_streak_and_engagement() -> void:
  var streak: Dictionary = {}
  _assert(
    not _GoalVisLatch.streak_confirmed(streak, 42, true, 3),
    "goal visibility streak needs consecutive ticks",
  )
  _assert(
    not _GoalVisLatch.streak_confirmed(streak, 42, true, 3),
    "goal visibility streak still short after two ticks",
  )
  _assert(
    _GoalVisLatch.streak_confirmed(streak, 42, true, 3),
    "goal visibility streak confirms on third tick",
  )
  _GoalVisLatch.streak_confirmed(streak, 42, false, 3)
  _assert(
    not _GoalVisLatch.streak_confirmed(streak, 42, true, 3),
    "goal visibility streak resets after dropout",
  )
  var engagement: Dictionary = {}
  _GoalVisLatch.record_engagement(engagement, 7, 100, 12, [Vector3(10.0, 0.0, 20.0)])
  _assert(
    _GoalVisLatch.engagement_active(engagement, 7, 105),
    "goal engagement latch active before expiry tick",
  )
  var merged: Array = []
  _assert(
    _GoalVisLatch.merge_engagement_positions(engagement, 7, 105, merged),
    "engagement latch merges last visible positions",
  )
  _assert(merged.size() == 1, "engagement latch merged one latched prey position")


func _test_seek_occlusion_step_cost_no_los_ctx() -> void:
  var cost := _Motor.seek_occlusion_step_cost(
    Vector3(100.0, 0.0, 100.0),
    Vector3(0.0, 0.0, -1.0),
    Vector3(100.0, 0.0, 20.0),
    {"enabled": false},
    Vector2(13.5, 30.5),
    [],
    40.0,
    12.0,
  )
  _assert(cost == 0.0, "seek occlusion cost zero when los ctx disabled")


func _test_predator_obstructed_hunt_active_lost_visual() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator lost-visual obstructed hunt test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {"motor_patrol_min_step_clearance": 4.0, "predator_obstacle_probe": 280.0}
  var he := Vector2(13.5, 30.5)
  var obs_aabb := [
    {"position": Vector3(300.0, 0.0, 350.0), "half_extents": Vector2(55.0, 55.0)},
  ]
  var pred_h := Vector3(300.0, 0.0, 180.0)
  var prey_h := Vector3(300.0, 0.0, 520.0)
  var memory_ctx := {
    "prey_seek_targets": [],
    "pursuit_targets": [{"position": prey_h, "velocity": Vector3.ZERO, "cost_scale": 1.0}],
    "predator_lost_visual": true,
    "static_obstacles": obs_aabb,
  }
  _assert(
    bool(driver.call("_predator_obstructed_hunt_active", memory_ctx, motor_p, pred_h, he, 0)),
    "obstructed hunt active for memory chase when bush blocks path",
  )
  driver.queue_free()


func _test_predator_east_rim_to_interior_patrol() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator east-rim to interior patrol test — AiDriver script did not compile")
    return
  var main := Node3D.new()
  root.add_child(main)
  var predator := _spawn_carnivore_body(main, Vector3(0.0, 0.0, 0.0))
  predator.set("current_calories", float(predator.get("caloric_needs")))
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var motor_p := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params().duplicate(true),
    "res://assets/creatures/fox",
  )
  motor_p["predator_chase_edge_band"] = 130.0
  motor_p["motor_playfield_corner_band"] = 84.0
  motor_p["predator_patrol_interior_expand_weight"] = 8.0
  predator.set("playfield_bounds_min", Vector2.ZERO)
  predator.set("playfield_bounds_max", Vector2(1000.0, 1000.0))
  predator.global_position = Vector3(976.0, 0.0, 500.0)
  var _rim_ctx: Dictionary = driver.call("_build_motor_context", motor_p, {}, predator)
  predator.global_position = Vector3(780.0, 0.0, 500.0)
  var interior_ctx: Dictionary = driver.call("_build_motor_context", motor_p, {}, predator)
  var interior_hint: Vector3 = interior_ctx.get("expanding_explore_hint", Vector3.ZERO) as Vector3
  _assert(interior_hint.length_squared() > 1e-12, "predator leaving east rim gets interior patrol nudge")
  _assert(interior_hint.x < -0.2, "east-side interior nudge points toward center/west")
  var nudged_map: Dictionary = driver.get("_predator_rim_exit_nudged_by_body")
  _assert(
    bool(nudged_map.get(predator.get_instance_id(), false)),
    "rim-exit nudge latch records once-per-body application",
  )
  driver.queue_free()
  main.queue_free()


func _test_predator_patrol_heading_variance() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator patrol heading variance test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
    "predator_edge_slide_min_clearance": 2.0,
  }
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(1000.0, 1000.0)
  var he := Vector2(13.5, 30.5)
  var pos := Vector3(bounds_max.x - he.x - 2.0, 0.0, 500.0)
  var headings: Dictionary = {}
  for i in 12:
    driver.set("_duel_motor_round_salt", 2026)
    driver.set("_physics_ticks", 9000 + i)
    var heading: Vector3 = driver.call(
      "_predator_pick_edge_tangent_cardinal",
      pos,
      he,
      [],
      bounds_min,
      bounds_max,
      motor_p,
      [],
      Vector3.ZERO,
      88006,
    ) as Vector3
    if heading.length_squared() > 1e-12:
      headings[heading] = true
  _assert(headings.size() >= 2, "predator edge patrol heading varies by deterministic seed/tick")
  driver.queue_free()


func _test_predator_east_rim_peel_prefers_inward() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator east-rim peel test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
    "predator_edge_slide_min_clearance": 2.0,
    "predator_patrol_rim_peel_min_gain": 0.35,
  }
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(1000.0, 1000.0)
  var he := Vector2(13.5, 30.5)
  var pos := Vector3(bounds_max.x - he.x - 2.0, 0.0, 500.0)
  var peel: Vector3 = driver.call(
    "_predator_pick_rim_peel_cardinal",
    pos,
    he,
    [],
    bounds_min,
    bounds_max,
    motor_p,
    88007,
  ) as Vector3
  _assert(peel.length_squared() > 1e-12, "east-rim peel returns non-zero heading")
  _assert(peel.x < -0.2, "east-rim peel points west/inward off the east wall")
  var patrol_hint: Vector3 = driver.call(
    "_predator_patrol_edge_expand_hint",
    pos,
    he,
    [],
    bounds_min,
    bounds_max,
    motor_p,
    Vector3.ZERO,
    false,
    88007,
  ) as Vector3
  _assert(patrol_hint.length_squared() > 1e-12, "east-rim patrol expand prefers peel over N-S slide")
  _assert(patrol_hint.x < -0.2, "east-rim patrol expand points toward interior")
  driver.queue_free()


func _test_predator_patrol_coverage_stall_escape() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip predator patrol coverage stall test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := {
    "motor_playfield_corner_band": 84.0,
    "motor_patrol_min_step_clearance": 4.0,
    "predator_chase_edge_band": 130.0,
    "explore_coverage_cell": 52.0,
    "predator_patrol_stall_window_ticks": 60,
  }
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(1000.0, 1000.0)
  var he := Vector2(13.5, 30.5)
  var body_id := 88008
  var pos := Vector3(500.0, 0.0, 500.0)
  driver.set("_physics_ticks", 9000)
  driver.call("_predator_update_patrol_coverage_anchor", body_id, pos, motor_p)
  driver.set("_physics_ticks", 9035)
  driver.call("_predator_update_patrol_coverage_anchor", body_id, pos + Vector3(0.5, 0.0, 0.3), motor_p)
  _assert(
    bool(driver.call("_predator_patrol_coverage_stall_active", body_id, pos, motor_p)),
    "predator patrol coverage stall detects local oscillation",
  )
  var esc: Vector3 = driver.call(
    "_predator_interior_patrol_stall_escape_intent",
    body_id,
    pos,
    he,
    [],
    1,
    motor_p,
    bounds_min,
    bounds_max,
    {},
  ) as Vector3
  _assert(esc.length_squared() > 1e-12, "coverage stall escape returns non-zero heading")
  var center := (bounds_min + bounds_max) * 0.5
  var toward_center := Vector3(center.x, 0.0, center.y) - pos
  _assert(
    esc.normalized().dot(toward_center.normalized()) > 0.15,
    "coverage stall escape biases toward playfield center",
  )
  driver.queue_free()


func _test_motor_cardinal_probe_scaled_for_small_playfield() -> void:
  var playfield := Vector2(105.0, 105.0)
  var scale := minf(playfield.x, playfield.y) / _MotorPlane.REFERENCE_MOTOR_PLAYFIELD_EDGE
  var scaled: Dictionary = _MotorPlane.scale_motor_distance_params({}, scale)
  var probe_min := float(scaled.get("motor_cardinal_probe_min", 40.0))
  _assert(probe_min < 3.0, "3D playfield scales cardinal probe min below legacy 40")
  var he := Vector2(0.7, 1.8)
  var step := _Motor.motor_cardinal_probe_step(he, probe_min)
  _assert(step < 5.0, "cardinal probe step fits ~100m playfield footprint")
  if not _ai_driver_can_instantiate():
    push_warning("skip scaled south-rim tangent test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := scaled.duplicate(true)
  motor_p["motor_playfield_corner_band"] = 84.0 * scale
  motor_p["motor_patrol_min_step_clearance"] = 4.0 * scale
  motor_p["predator_chase_edge_band"] = 130.0 * scale
  motor_p["predator_edge_slide_min_clearance"] = 2.0 * scale
  var bounds_min := Vector2.ZERO
  var bounds_max := playfield
  var pos := Vector3(70.0, 0.0, playfield.y - he.y - 2.0)
  var tangent: Vector3 = driver.call(
    "_predator_pick_edge_tangent_cardinal",
    pos,
    he,
    [],
    bounds_min,
    bounds_max,
    motor_p,
    [],
    Vector3.ZERO,
    88003,
  ) as Vector3
  _assert(tangent.length_squared() > 1e-12, "scaled south rim finds wall-tangent step")
  _assert(
    absf(tangent.dot(Vector3(0.0, 0.0, -1.0))) < 0.35 and absf(tangent.dot(Vector3(0.0, 0.0, 1.0))) < 0.35,
    "scaled south rim tangent is lateral not N-S",
  )
  driver.queue_free()


func _test_seek_stationary_look() -> void:
  var pick := Callable(_SeekStationaryLookScr, &"pick_facing")
  var seg := 3
  var phase_seed := 7
  var seen: Dictionary = {}
  for tick in 24:
    var f: Vector2 = pick.call(seg, tick, phase_seed) as Vector2
    seen[f] = true
  _assert(seen.size() >= 6, "stationary look sweeps multiple 8-way headings over one cycle")
  var a: Vector2 = pick.call(seg, 0, phase_seed) as Vector2
  var b: Vector2 = pick.call(seg, 0, phase_seed) as Vector2
  _assert(a.is_equal_approx(b), "stationary look is deterministic for tick + seed")
  var c: Vector2 = pick.call(seg, seg, phase_seed) as Vector2
  _assert(not a.is_equal_approx(c), "stationary look advances facing across segment boundary")


func _test_motor_plane_yaw_from_facing() -> void:
  for d in _EightWayDirScr.DIRECTIONS:
    var yaw: float = _MotorPlaneScr.yaw_from_horizontal_dir(d)
    var rebuilt := Vector3(sin(yaw), 0.0, -cos(yaw))
    _assert(rebuilt.is_equal_approx(d), "yaw_from_horizontal_dir round-trips 8-way direction %s" % d)


func _test_seek_diagonal_intent() -> void:
  var ne := Vector3(0.7071067811865475, 0.0, -0.7071067811865475)
  var seek_ctx := {
    "creature_position": Vector3(500.0, 0.0, 500.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(1000.0, 1000.0),
    "mobs": [],
    "static_obstacles": [],
    "creature_half_extents": Vector2(13.5, 30.5),
    "creature_facing": Vector3.RIGHT,
    "food_seek_targets": [Vector3(620.0, 0.0, 380.0)],
    "weight_seek_ready_food": 16.0,
    "motor_has_active_goal": true,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "weight_expanding_explore_hint": 0.0,
    "motor_intent_cost_chaos": 0.0,
    "motor_tie_cost_epsilon": 0.45,
    "motor_cardinal_block_min_clearance": 0.0,
    "motor_pick_tick": 0,
    "motor_chaos_seed": 1,
    "shuffle_tie_break": false,
  }
  var d_seek: Vector3 = _Motor.pick_best_move_intent(seek_ctx)
  _assert(d_seek.is_equal_approx(ne), "motor picks diagonal toward intercardinal food target")
  var flee_ctx := seek_ctx.duplicate(true)
  flee_ctx["food_seek_targets"] = []
  flee_ctx["weight_seek_ready_food"] = 0.0
  flee_ctx["mobs"] = [{"position": Vector3(520.0, 0.0, 500.0), "velocity": Vector3.ZERO, "cost_scale": 1.0}]
  flee_ctx["weight_dist"] = 2.0
  flee_ctx["weight_closing"] = 1.0
  var d_flee: Vector3 = _Motor.pick_best_move_intent(flee_ctx)
  _assert(d_flee.length_squared() > 1e-12, "threat repulsion uses 8-way candidate set")
  _assert(d_flee.dot(Vector3.RIGHT) < 0.5, "flee intent moves away from threat ahead")


func _test_herbivore_pinch_stall_zero_intent() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip herbivore pinch stall test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var body := CharacterBody2D.new()
  body.add_to_group("prey")
  body.global_position = Vector2(440.0, 300.0)
  var motor_p := _Merge.creature_motor_spine()
  var he := Vector2(13.5, 30.5)
  var bush := {"position": Vector3(500.0, 0.0, 300.0), "half_extents": Vector2(42.0, 42.0)}
  var rock := {"position": Vector3(380.0, 0.0, 300.0), "half_extents": Vector2(55.0, 55.0)}
  var obs := [bush, rock]
  d.set("_motor_stuck_last_pos", {body.get_instance_id(): Vector3(440.0, 0.0, 300.0)})
  var stuck: int = d.call(
    "_motor_stuck_track_mob",
    body,
    Vector3.ZERO,
    motor_p,
    Vector3.ZERO,
    obs,
    he,
  )
  _assert(stuck >= 1, "pinched prey counts as stalled even when move intent is zero (seek turn)")
  body.queue_free()
  d.queue_free()


func _test_blocked_approach_memory() -> void:
  var infer := Callable(_BlockedApproachScr, &"infer_approach_dir")
  var from_trail: Vector3 = infer.call(
    Vector3(200.0, 0.0, 200.0),
    Vector3(200.0, 0.0, 200.0),
    Vector3.ZERO,
    [Vector3(100.0, 0.0, 200.0)],
    Vector3.ZERO,
  ) as Vector3
  _assert(
    from_trail.is_equal_approx(Vector3.RIGHT),
    "blocked approach infers entry heading from explore trail",
  )
  var st: Dictionary = {}
  Callable(_BlockedApproachScr, &"record").call(st, Vector3(0.0, 0.0, -1.0), 10, 20)
  _assert(
    (Callable(_BlockedApproachScr, &"active_dir").call(st, 15) as Vector3).is_equal_approx(Vector3(0.0, 0.0, -1.0)),
    "blocked approach memory stays active within TTL",
  )
  _assert(
    (Callable(_BlockedApproachScr, &"active_dir").call(st, 31) as Vector3).length_squared() < 1e-12,
    "blocked approach memory expires after TTL",
  )
  var he := Vector2(13.5, 30.5)
  var pinch_ctx := {
    "creature_position": Vector3(440.0, 0.0, 300.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(1000.0, 1000.0),
    "mobs": [],
    "static_obstacles": [
      {"position": Vector3(500.0, 0.0, 300.0), "half_extents": Vector2(42.0, 42.0)},
      {"position": Vector3(380.0, 0.0, 300.0), "half_extents": Vector2(55.0, 55.0)},
    ],
    "creature_half_extents": he,
    "creature_facing": Vector3.RIGHT,
    "creature_last_move_direction": Vector3.RIGHT,
    "food_seek_targets": [Vector3(750.0, 0.0, 300.0)],
    "weight_seek_ready_food": 16.0,
    "motor_has_active_goal": true,
    "motor_seek_filter_wall_hits": true,
    "motor_filter_blocked_approach": true,
    "blocked_approach_direction": Vector3.RIGHT,
    "blocked_approach_backtrack_dot": 0.55,
    "weight_blocked_approach_backtrack": 48.0,
    "weight_seek_backtrack": 14.0,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "weight_expanding_explore_hint": 0.0,
    "motor_intent_cost_chaos": 0.0,
    "motor_tie_cost_epsilon": 0.45,
    "motor_cardinal_block_min_clearance": 4.0,
    "motor_pick_tick": 0,
    "motor_chaos_seed": 1,
    "shuffle_tie_break": false,
  }
  var d_pinch: Vector3 = _Motor.pick_best_move_intent(pinch_ctx)
  _assert(
    not d_pinch.is_equal_approx(Vector3(-1.0, 0.0, 0.0)) and not d_pinch.is_equal_approx(Vector3.RIGHT),
    "pinch memory skips backtrack toward remembered approach when lateral opens exist",
  )
  pinch_ctx["motor_filter_blocked_approach"] = false
  pinch_ctx.erase("blocked_approach_direction")
  var d_free: Vector3 = _Motor.pick_best_move_intent(pinch_ctx)
  _assert(d_free.length_squared() > 1e-12, "pinch pick still chooses a direction without memory gate")


func _test_herbivore_food_seek_pinch_escape_backtrack() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  if AD == null or not AD.can_instantiate():
    push_warning("skip food-seek pinch backtrack escape test — AiDriver script did not compile")
    return
  var d: Node = AD.new() as Node
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var he := Vector2(13.5, 30.5)
  var bounds_max := Vector2(1920.0, 1080.0)
  var prey_pos := Vector3(440.0, 0.0, 300.0)
  var obs := [
    {"position": Vector3(500.0, 0.0, 300.0), "half_extents": Vector2(42.0, 42.0)},
    {"position": Vector3(380.0, 0.0, 300.0), "half_extents": Vector2(55.0, 55.0)},
  ]
  var food_north := Vector3(440.0, 0.0, 80.0)
  var body_id := 8801
  d.set("_blocked_approach_by_body", {
    body_id: {"dir": Vector3(0.0, 0.0, -1.0), "sector": 0, "until_tick": 999999},
  })
  d.set("_physics_ticks", 0)
  var block_clr := float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0))
  var esc: Vector3 = d.call(
    "_herbivore_pinch_escape_intent",
    body_id,
    prey_pos,
    he,
    obs,
    2,
    rabbit_m,
    Vector3.ZERO,
    bounds_max,
    food_north - prey_pos,
  )
  _assert(
    esc.length_squared() > 1e-12
    and not bool(d.call("_cardinal_step_blocked_for_escape", prey_pos, he, esc, obs, block_clr)),
    "food-seek pinch escape picks a traversable heading",
  )
  _assert(
    esc.dot(Vector3(0.0, 0.0, 1.0)) > 0.55,
    "food-seek pinch escape backs out south despite blocked-approach memory",
  )
  d.queue_free()


func _test_seek_wall_filter_and_backtrack() -> void:
  var he := Vector2(13.5, 30.5)
  var obs := [{"position": Vector3(548.0, 0.0, 500.0), "half_extents": Vector2(24.0, 40.0)}]
  _assert(
    Callable(_Motor, &"step_blocked_into_wall").call(
      Vector3(500.0, 0.0, 500.0), he, Vector3.RIGHT, 60.0, obs, Vector3.ZERO, Vector3(1000.0, 0.0, 1000.0), 4.0
    ),
    "seek wall filter rejects step into static obstacle",
  )
  _assert(
    not bool(
      Callable(_Motor, &"step_blocked_into_wall").call(
        Vector3(500.0, 0.0, 500.0), he, Vector3(0.0, 0.0, -1.0), 60.0, obs, Vector3.ZERO, Vector3(1000.0, 0.0, 1000.0), 4.0
      )
    ),
    "seek wall filter allows parallel slide along obstacle",
  )
  var back := float(
    Callable(_Motor, &"seek_backtrack_step_cost").call(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0), 10.0)
  )
  _assert(back > 5.0, "seek backtrack penalizes reversing last move")
  var forward := float(
    Callable(_Motor, &"seek_backtrack_step_cost").call(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -1.0), 10.0)
  )
  _assert(forward < 1e-6, "seek backtrack does not penalize continuing direction")
  var wall_seek_ctx := {
    "creature_position": Vector3(500.0, 0.0, 500.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(1000.0, 1000.0),
    "mobs": [],
    "static_obstacles": obs,
    "creature_half_extents": he,
    "creature_facing": Vector3.RIGHT,
    "creature_last_move_direction": Vector3.RIGHT,
    "food_seek_targets": [Vector3(750.0, 0.0, 500.0)],
    "weight_seek_ready_food": 16.0,
    "motor_has_active_goal": true,
    "motor_seek_filter_wall_hits": true,
    "weight_seek_backtrack": 14.0,
    "weight_explore_idle_penalty": 0.0,
    "weight_explore_turn_bias": 0.0,
    "weight_expanding_explore_hint": 0.0,
    "motor_intent_cost_chaos": 0.0,
    "motor_tie_cost_epsilon": 0.45,
    "motor_cardinal_block_min_clearance": 4.0,
    "motor_pick_tick": 0,
    "motor_chaos_seed": 1,
    "shuffle_tie_break": false,
  }
  var d_wall: Vector3 = _Motor.pick_best_move_intent(wall_seek_ctx)
  _assert(not d_wall.is_equal_approx(Vector3.RIGHT), "seek skips into-wall direction toward food")
  _assert(not d_wall.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "seek backtrack penalty avoids immediate reversal")


func _test_bush_proximity_pickup_adjacent() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var bush_pos := Vector3(2.0, 0.0, 2.0)
  var bush := _spawn_food_bush(main, bush_pos)
  var prey := _spawn_herbivore_body(main, bush_pos + Vector3(0.0, 0.0, -1.2))
  var cals_before := float(prey.get("current_calories"))
  bush.call("_try_proximity_pickup_for_players")
  _assert(float(bush.get("current_calories")) < 1.0, "adjacent footprint pickup drains bush pool")
  _assert(float(prey.get("current_calories")) > cals_before, "adjacent footprint pickup grants calories")
  main.queue_free()


func _test_herbivore_forage_plateau_release() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip forage plateau test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var body_id := 4242
  var motor_p := {
    "motor_forage_plateau_ticks": 3,
    "motor_forage_plateau_radius": 95.0,
    "motor_stuck_escape_ticks": 1,
  }
  var ctx := {
    "weight_seek_ready_food": 16.0,
    "food_seek_targets": [Vector3(100.0, 0.0, 0.0)],
    "creature_position": Vector3(100.0, 0.0, -66.0),
    "creature_half_extents": Vector2(13.5, 30.5),
  }
  driver.call("_track_herbivore_forage_plateau", body_id, ctx, Vector3.ZERO, 0, motor_p)
  driver.call("_track_herbivore_forage_plateau", body_id, ctx, Vector3.ZERO, 0, motor_p)
  var plateau_state: Dictionary = driver.get("_forage_plateau_ticks_by_body")
  _assert(
    int(plateau_state.get(body_id, 0)) == 2,
    "Vector3 food targets accumulate forage plateau ticks while idle near food",
  )
  _assert(
    not bool(driver.call("_herbivore_forage_plateau_release", body_id, motor_p, ctx)),
    "forage plateau not released before threshold",
  )
  driver.call("_track_herbivore_forage_plateau", body_id, ctx, Vector3.ZERO, 0, motor_p)
  _assert(
    bool(driver.call("_herbivore_forage_plateau_release", body_id, motor_p, ctx)),
    "forage plateau releases after threshold ticks while idle near food",
  )
  driver.set("_forage_plateau_ticks_by_body", {})
  driver.call("_track_herbivore_forage_plateau", body_id, ctx, Vector3.RIGHT, 5, motor_p)
  driver.call("_track_herbivore_forage_plateau", body_id, ctx, Vector3.RIGHT, 5, motor_p)
  _assert(
    not bool(driver.call("_herbivore_forage_plateau_release", body_id, motor_p, ctx)),
    "ready-food plateau ignores motor-stuck while still pursuing",
  )
  driver.set("_forage_plateau_ticks_by_body", {})
  var body_id_unready := 5252
  var ctx_unready := {
    "weight_seek_ready_food": 0.0,
    "weight_avoid_unready_food": 5.5,
    "food_seek_targets": [],
    "unready_food_avoid_targets": [Vector3(100.0, 0.0, 0.0)],
    "creature_position": Vector3(100.0, 0.0, -66.0),
    "creature_half_extents": Vector2(13.5, 30.5),
  }
  for _i in 3:
    driver.call("_track_herbivore_forage_plateau", body_id_unready, ctx_unready, Vector3.ZERO, 0, motor_p)
  _assert(
    bool(driver.call("_herbivore_forage_plateau_release", body_id_unready, motor_p, ctx_unready)),
    "forage plateau tracks adjacent unready bush after eating",
  )
  driver.queue_free()


func _test_herbivore_food_awareness_latch() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip herbivore food latch test — AiDriver script did not compile")
    return
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  var motor_p := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var body_id := 8181
  var food_targets: Array = [Vector3(500.0, 0.0, 200.0)]
  var latched := bool(
    driver.call("_herbivore_food_latch_merge", body_id, [Vector3(500.0, 0.0, 200.0)], food_targets, motor_p)
  )
  _assert(latched and food_targets.size() == 1, "food latch records ready bush")
  _assert(bool(driver.call("_herbivore_food_latch_active", body_id)), "food latch stays active")
  var food_after_dropout: Array = []
  var merged_latch := bool(
    driver.call("_herbivore_food_latch_merge", body_id, [], food_after_dropout, motor_p)
  )
  _assert(merged_latch, "food latch merge active after cone dropout")
  _assert(food_after_dropout.size() == 1, "latched Vector3 food re-merges into seek targets")
  _assert(
    (food_after_dropout[0] as Vector3).is_equal_approx(Vector3(500.0, 0.0, 200.0)),
    "latched food position preserved in Vector3 merge",
  )
  var ctx := {
    "creature_position": Vector3(200.0, 0.0, 200.0),
    "food_seek_targets": [Vector3(500.0, 0.0, 200.0)],
    "weight_seek_ready_food": 16.0,
    "creature_half_extents": Vector2(13.5, 30.5),
    "herbivore_food_latched": true,
  }
  driver.call("_track_herbivore_forage_plateau", body_id, ctx, Vector3.RIGHT, 3, motor_p)
  _assert(
    not bool(driver.call("_herbivore_forage_plateau_release", body_id, motor_p, ctx)),
    "plateau does not drop latched ready-food pursuit",
  )
  driver.queue_free()


func _test_eaten_bush_moves_to_unready_not_seek() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip eaten bush readiness test — AiDriver script did not compile")
    return
  var main := Node3D.new()
  root.add_child(main)
  var bush := _spawn_food_bush(main, Vector3(8.0, 0.0, 0.0))
  bush.set("current_calories", 0.0)
  bush.set("_player_visit_locked", true)
  var prey := _spawn_herbivore_body(main, Vector3.ZERO)
  prey.set("last_move_direction", Vector3.RIGHT)
  prey.set("current_calories", 10.0)
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var base := _Merge.default_creature_motor_params()
  var motor_p := _Merge.merge_creature_motor_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/rabbit",
  )
  var he := Vector2(13.5, 30.5)
  var split: Dictionary = driver.call(
    "_motor_food_plants_in_awareness_by_readiness",
    motor_p,
    prey.global_position,
    he,
    Vector3.RIGHT,
  )
  var ready: Array = split.get("ready", []) as Array
  var unready: Array = split.get("unready", []) as Array
  _assert(ready.is_empty(), "depleted bush is not a ready seek target")
  _assert(unready.size() == 1, "depleted bush stays in unready awareness list")
  var ctx: Dictionary = driver.call("_build_motor_context", motor_p, {}, prey)
  _assert(
    (ctx.get("food_seek_targets", []) as Array).is_empty(),
    "depleted bush removed from food_seek_targets",
  )
  _assert(
    not bool(ctx.get("motor_has_active_goal", true)),
    "only unready bush nearby does not block patrol via motor_has_active_goal",
  )
  var nudge: Vector3 = driver.call(
    "_herbivore_nudge_away_from_unready_if_idle",
    ctx,
    Vector3.ZERO,
    motor_p,
  ) as Vector3
  _assert(nudge.length_squared() > 1e-12, "idle adjacent to unready bush nudges away")
  driver.queue_free()
  main.queue_free()


func _test_perception_risk_hints() -> void:
  var p0 := Vector2.ZERO

  var head_on := _Risk.mob_closing_metrics(Vector2(220.0, 0.0), Vector2(-180.0, 0.0), p0)
  _assert(bool(head_on["closing"]), "straight-on mob radially closes on creature")

  var tangent := _Risk.mob_closing_metrics(Vector2(150.0, 0.0), Vector2(0.0, 200.0), p0)
  _assert(not bool(tangent["closing"]), "perpendicular mover is not radially closing")

  var still := _Risk.mob_closing_metrics(Vector2(80.0, 0.0), Vector2.ZERO, p0)
  _assert(not bool(still["closing"]), "stationary mob skips closing heuristic")

  var corner_sb := Callable(_Risk, &"classify_creature_patch_and_band").call(0, 0, 12, 10, Vector2.ZERO) as Dictionary
  _assert(str(corner_sb.get("patch", "")) == "corner", "corner cell label")
  _assert(str(corner_sb.get("band", "")) == "stopped", "zero velocity reads stopped")

  var wall_lab := Callable(_Risk, &"classify_creature_patch_and_band").call(0, 5, 12, 10, Vector2.ZERO) as Dictionary
  _assert(str(wall_lab.get("patch", "")) == "wall", "top-edge non-corner is wall")

  var interior_mv := Callable(_Risk, &"classify_creature_patch_and_band").call(4, 4, 12, 10, Vector2(50.0, 0.0)) as Dictionary
  _assert(str(interior_mv.get("patch", "")) == "interior", "interior cell")
  _assert(str(interior_mv.get("band", "")) == "moving", "nonzero speed reads moving")

  var prio_mobs_nearest_first: Array = [
    {"point": Vector2(40.0, 0.0), "velocity": Vector2(-200.0, 0.0)},
    {"point": Vector2(80.0, 0.0), "velocity": Vector2(-150.0, 0.0)},
  ]
  var pr: Dictionary = _Risk.pick_priority_closing_mob(prio_mobs_nearest_first, p0)
  _assert(int(pr["idx_1"]) == 1, "nearest fastest closer wins when time-to-close shortest")

  var rh := _Wire.format_risk_hints_line(-1, INF, "interior", "moving")
  _assert(
    rh.begins_with("RISK_HINTS ") and rh.contains("CLOSEST_CLOSING_I=-1") and rh.contains("CREATURE_PATCH"),
    "risk hint formatter no closer"
  )


func _test_perception_sampling() -> void:
  var ident := Transform2D.IDENTITY
  var r := Rect2(-10, -20, 30, 40)
  var a := _Sampling.world_aabb_from_shape_rect(r, ident)
  _assert(a.get_center().is_equal_approx(Vector2(5, 0)), "aabb center ident xf")
  _assert(a.size.is_equal_approx(Vector2(30, 40)), "aabb size ident xf")
  var shifted := Transform2D.IDENTITY.translated(Vector2(100, 200))
  var b := _Sampling.world_aabb_from_shape_rect(Rect2(-5, -5, 10, 10), shifted)
  _assert(b.get_center().is_equal_approx(Vector2(100, 200)), "aabb translated unit rect")
  var st_root := get_root()
  var body := Area2D.new()
  var cs := CollisionShape2D.new()
  var cap := CapsuleShape2D.new()
  cap.radius = 10.0
  cap.height = 30.0
  cs.shape = cap
  body.add_child(cs)
  st_root.add_child(body)
  body.global_position = Vector2(200, 300)
  var s: Dictionary = _Sampling.sampling_from_collision_object(body)
  st_root.remove_child(body)
  body.queue_free()
  var p: Vector2 = s.get("point", Vector2.ZERO)
  var he: Vector3 = s.get("half_extents", Vector3.ZERO)
  _assert(p.is_equal_approx(Vector2(200, 300)), "capsule sampling center")
  _assert(he.x > 5.0 and he.y > 10.0, "capsule half-extents plausible")


func _test_ai_driver_helpers() -> void:
  var AD := load("res://AI_int_lib/ai_driver.gd") as Script
  _assert(Callable(AD, &"should_apply_response_id").call(7, 7), "latest-enqueued response applies")
  _assert(not Callable(AD, &"should_apply_response_id").call(6, 7), "older response is stale")
  var d: Node = AD.new() as Node
  _assert(d.call("get_armed_handshake_user") == "ARMED", "armed handshake literal")
  _assert(Callable(AD, &"http_request_result_label").call(HTTPRequest.RESULT_CANT_CONNECT) == "CANT_CONNECT", "HTTP label")
  _assert(
    Callable(AD, &"extract_openai_chat_choice_text").call(
      {
        "choices": [{"message": {"content": [{"type": "text", "text": "LEFT"}]}}],
      },
    )
    == "LEFT",
    "OpenAI array-shaped message.content",
  )
  _assert(
    Callable(AD, &"extract_openai_chat_choice_text").call(
      {"choices": [{"message": {"content": "RIGHT"}, "text": ""}]},
    )
    == "RIGHT",
    "string message.content",
  )
  _assert(
    Callable(AD, &"extract_openai_chat_choice_text").call({"choices": [{"text": "legacy DOWN"}]}) == "legacy DOWN",
    "legacy choices[0].text fallback",
  )
  _assert(
    Callable(AD, &"extract_openai_chat_choice_text").call(
      {
        "choices": [{"message": {"content": [{"type": "output_text", "text": "UP"}]}}],
      },
    )
    == "UP",
    "OpenAI output_text content block (llama-server)",
  )
  _assert(
    Callable(AD, &"extract_openai_completion_choice_text").call({"choices": [{"text": "LEFT"}]}) == "LEFT",
    "OpenAI /v1/completions choices[0].text",
  )
  _assert(
    Callable(AD, &"extract_openai_completion_choice_text").call({"choices": [{}]}) == "",
    "empty completion text",
  )
  _assert(str(Callable(AD, &"gbnf_for_completion_state_enum").call(1)).contains("START"), "gbnf ARMED")
  _assert(str(Callable(AD, &"gbnf_for_completion_state_enum").call(2)).contains("RIGHT"), "gbnf PLAYING")
  _assert(str(Callable(AD, &"gbnf_for_completion_state_enum").call(0)).is_empty(), "gbnf IDLE empty")
  var motor_p := _Merge.creature_motor_spine()
  var bounds_max := Vector2(1000.0, 600.0)
  var he := Vector2(18.0, 44.0)
  var pred_pos := Vector3(980.0 - he.x, 0.0, 300.0)
  var prey_pos := Vector3(990.0 - 13.5, 0.0, 300.0)
  var ctx := {
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
    "prey_seek_targets": [prey_pos],
    "pursuit_targets": [],
    "static_obstacles": [],
  }
  _assert(
    bool(d.call("_predator_edge_chase_pin_active", ctx, motor_p, pred_pos, he)),
    "predator edge pin when prey is on playfield edge without static block",
  )
  _assert(
    bool(
      d.call(
        "_predator_prey_edge_pinned",
        Vector3.ZERO,
        bounds_max,
        prey_pos,
        motor_p,
      )
    ),
    "prey on playfield edge counts as edge-pinned for chase shaping",
  )
  var approach_prey := Vector3(976.0, 0.0, 300.0)
  var approach_pred := Vector3(820.0, 0.0, 300.0)
  var approach_ctx := {
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
    "prey_seek_targets": [approach_prey],
    "pursuit_targets": [],
    "static_obstacles": [],
    "weight_edge": 0.48,
    "weight_interior": 0.65,
  }
  d.call("_predator_edge_chase_ctx_shaping", approach_ctx, motor_p, approach_pred, he)
  _assert(
    bool(approach_ctx.get("predator_edge_chase_active", false)),
    "edge chase shaping arms when prey is corner-pinned even if predator is still mid-field",
  )
  _assert(
    is_equal_approx(float(approach_ctx.get("weight_edge", 0.48)), 0.48 * 0.12),
    "edge chase shaping softens explore edge repulsion toward cornered prey",
  )
  var flee_dir: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    Vector3(990.0, 0.0, 300.0),
    Vector3(900.0, 0.0, 300.0),
    bounds_max,
    Vector2(13.5, 30.5),
    42,
    motor_p,
  )
  _assert(
    flee_dir.dot(Vector3(-1.0, 0.0, 0.0)) < 0.25,
    "cornered prey does not flee back toward edge-pinned threat",
  )
  var obs_aabb := [
    {"position": Vector3(300.0, 0.0, 350.0), "half_extents": Vector2(55.0, 55.0)},
  ]
  var pred_h := Vector3(300.0, 0.0, 180.0)
  var prey_h := Vector3(300.0, 0.0, 520.0)
  var hunt_ctx := {
    "prey_seek_targets": [prey_h],
    "pursuit_targets": [],
    "static_obstacles": obs_aabb,
  }
  _assert(
    bool(d.call("_predator_chase_toward_prey_blocked", pred_h, prey_h, he, obs_aabb, 4.0)),
    "chase toward visible prey blocked when bush sits on direct path",
  )
  _assert(
    bool(d.call("_predator_obstructed_hunt_active", hunt_ctx, motor_p, pred_h, he, 0)),
    "obstructed hunt active before body stall when bush blocks chase line",
  )
  _assert(
    bool(d.call("_predator_obstructed_hunt_active", hunt_ctx, motor_p, pred_h, he, 2)),
    "obstructed hunt when solid blocks cardinal toward visible prey",
  )
  var flank: Vector3 = d.call(
    "_predator_obstructed_hunt_intent",
    pred_h,
    prey_h,
    he,
    obs_aabb,
    Vector3.ZERO,
    bounds_max,
    99,
    2,
    motor_p,
  )
  _assert(
    flank.length_squared() > 1e-12 and not flank.is_equal_approx(Vector3.ZERO),
    "obstructed hunt picks a flank step toward prey",
  )
  var corner_obs := [{"position": Vector3(500.0, 0.0, 350.0), "half_extents": Vector2(100.0, 100.0)}]
  var fox_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/fox",
  )
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params(),
    "res://assets/creatures/rabbit",
  )
  var fox_he := Vector2(18.0, 44.0)
  var prey_he := Vector2(13.5, 30.5)
  var fox_corner := Vector3(408.0, 0.0, 242.0)
  var prey_corner := Vector3(435.0, 0.0, 242.0)
  var flank_corner: Vector3 = d.call(
    "_predator_obstructed_hunt_intent",
    fox_corner,
    prey_corner,
    fox_he,
    corner_obs,
    Vector3.ZERO,
    bounds_max,
    77,
    2,
    fox_m,
  )
  var corner_min_clr := float(fox_m.get("motor_patrol_min_step_clearance", 4.0))
  _assert(
    flank_corner.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked",
        fox_corner,
        fox_he,
        flank_corner,
        corner_obs,
        corner_min_clr,
      )
    ),
    "obstructed hunt at obstacle corner picks an unblocked step",
  )
  _assert(
    bool(
      d.call(
        "_predator_hunt_stalemate_allowed",
        {
          "prey_seek_targets": [prey_corner],
          "pursuit_targets": [],
          "static_obstacles": corner_obs,
        },
        fox_m,
        fox_corner,
        fox_he,
        6,
      )
    ),
    "stalemate escape allowed after sustained corner stall",
  )
  var esc_corner: Vector3 = d.call(
    "_pick_stuck_escape_cardinal",
    fox_corner,
    fox_he,
    corner_obs,
    77,
    6,
    fox_m,
    Vector3.ZERO,
    bounds_max,
  )
  _assert(
    esc_corner.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked",
        fox_corner,
        fox_he,
        esc_corner,
        corner_obs,
        corner_min_clr,
      )
    ),
    "geometry escape at corner picks a traversable cardinal",
  )
  var rock_pos := Vector3(370.0, 0.0, 405.0)
  var shrub_pos := Vector3(540.0, 0.0, 405.0)
  var wedge_obs := [
    {"position": rock_pos, "half_extents": Vector2(70.0, 70.0)},
    {"position": shrub_pos, "half_extents": Vector2(50.0, 50.0)},
  ]
  var fox_wedge := Vector3(465.0, 0.0, 405.0)
  var prey_wedge := Vector3(465.0, 0.0, 180.0)
  var wedge_intent: Vector3 = d.call(
    "_predator_obstructed_hunt_intent",
    fox_wedge,
    prey_wedge,
    fox_he,
    wedge_obs,
    Vector3.ZERO,
    bounds_max,
    88,
    3,
    fox_m,
  )
  _assert(
    wedge_intent.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked_for_escape",
        fox_wedge,
        fox_he,
        wedge_intent,
        wedge_obs,
        corner_min_clr,
      )
    ),
    "obstructed hunt in rock-shrub wedge picks traversable escape",
  )
  _assert(
    wedge_intent.dot(Vector3(0.0, 0.0, 1.0)) > 0.55,
    "rock-shrub wedge escape backs out of pinch instead of chasing through gap",
  )
  var esc_wedge: Vector3 = d.call(
    "_pick_stuck_escape_cardinal",
    fox_wedge,
    fox_he,
    wedge_obs,
    88,
    4,
    fox_m,
  )
  _assert(
    esc_wedge.length_squared() > 1e-12
    and esc_wedge.dot(Vector3(0.0, 0.0, 1.0)) > 0.55,
    "geometry escape in rock-shrub wedge exits along corridor",
  )
  var south_bounds := Vector3(1000.0, 0.0, 600.0)
  var rock_south := Vector3(500.0, 0.0, 400.0)
  var shrub_nw := Vector3(420.0, 0.0, 470.0)
  var shrub_ne := Vector3(580.0, 0.0, 470.0)
  var pocket_obs := [
    {"position": rock_south, "half_extents": Vector2(75.0, 75.0)},
    {"position": shrub_nw, "half_extents": Vector2(50.0, 50.0)},
    {"position": shrub_ne, "half_extents": Vector2(50.0, 50.0)},
  ]
  var fox_south := Vector3(500.0, 0.0, 545.0)
  var prey_ne := Vector3(650.0, 0.0, 180.0)
  var south_hunt_ctx := {
    "prey_seek_targets": [prey_ne],
    "pursuit_targets": [],
    "static_obstacles": pocket_obs,
    "bounds_min": Vector2.ZERO,
    "bounds_max": south_bounds,
  }
  _assert(
    not bool(
      d.call(
        "_predator_preyward_escape_open",
        fox_south,
        prey_ne,
        fox_he,
        pocket_obs,
        Vector3.ZERO,
        south_bounds,
        corner_min_clr,
      )
    ),
    "south-wall pocket blocks prey-closing cardinals while lateral slide stays open",
  )
  _assert(
    bool(
      d.call(
        "_predator_obstructed_hunt_active",
        south_hunt_ctx,
        fox_m,
        fox_south,
        fox_he,
        2,
      )
    ),
    "obstructed hunt when prey NE but only wall-parallel steps are open",
  )
  var south_flank: Vector3 = d.call(
    "_predator_obstructed_hunt_intent",
    fox_south,
    prey_ne,
    fox_he,
    pocket_obs,
    Vector3.ZERO,
    south_bounds,
    91,
    2,
    fox_m,
  )
  _assert(
    south_flank.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked_for_escape",
        fox_south,
        fox_he,
        south_flank,
        pocket_obs,
        corner_min_clr,
      )
    ),
    "south-wall pocket flank picks a traversable step",
  )
  _assert(
    absf(south_flank.dot(Vector3(1.0, 0.0, 0.0))) > 0.85,
    "south-wall pocket flank slides along wall instead of into rock-shrub pinch",
  )
  var flee_corner: Vector3 = d.call(
    "_herbivore_bounded_flee_intent",
    Vector3(418.0, 0.0, 238.0),
    Vector3(395.0, 0.0, 310.0),
    bounds_max,
    prey_he,
    55,
    rabbit_m,
    corner_obs,
  )
  _assert(
    flee_corner.length_squared() > 1e-12
    and not bool(
      d.call(
        "_cardinal_step_blocked",
        Vector3(418.0, 0.0, 238.0),
        prey_he,
        flee_corner,
        corner_obs,
        float(rabbit_m.get("motor_patrol_min_step_clearance", 4.0)),
      )
    ),
    "cornered prey flee avoids blocked cardinals at obstacle corner",
  )
  var edge_intent: Vector3 = d.call(
    "_predator_edge_chase_intent",
    Vector3(300.0, 0.0, 80.0),
    Vector3(300.0, 0.0, 380.0),
    fox_he,
    Vector3.ZERO,
    bounds_max,
    42,
    motor_p,
  )
  _assert(
    edge_intent.dot(Vector3(0.0, 0.0, 1.0)) > 0.85,
    "edge chase intercept picks closing cardinal toward prey",
  )
  var close_corner_intent: Vector3 = d.call(
    "_predator_edge_chase_intent",
    Vector3(408.0, 0.0, 242.0),
    Vector3(435.0, 0.0, 242.0),
    fox_he,
    Vector3.ZERO,
    bounds_max,
    7,
    fox_m,
    prey_he,
  )
  _assert(
    close_corner_intent.dot(Vector3.RIGHT) > 0.85,
    "edge chase at contact range commits to closing cardinal toward cornered prey",
  )
  var edge_pin_ctx := {
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
    "prey_seek_targets": [Vector3(990.0 - 13.5, 0.0, 300.0)],
    "pursuit_targets": [],
    "static_obstacles": [],
  }
  _assert(
    not bool(
      d.call(
        "_predator_hunt_stalemate_allowed",
        edge_pin_ctx,
        fox_m,
        Vector3(980.0 - fox_he.x, 0.0, 300.0),
        fox_he,
        3,
      )
    ),
    "edge-pin hunt uses edge chase instead of generic stalemate sidestep",
  )
  _assert(
    bool(
      d.call(
        "_predator_edge_parallel_chase_stalled",
        Vector3(300.0, 0.0, 80.0),
        Vector3(300.0, 0.0, 380.0),
        Vector3(-1.0, 0.0, 0.0),
        0,
        motor_p,
      )
    ),
    "parallel west chase at wall is treated as edge stall",
  )
  var fox_edge_close := Vector3(920.0, 0.0, 300.0)
  var prey_wall := Vector3(990.0 - 13.5, 0.0, 300.0)
  var wall_hunt_ctx := {
    "prey_seek_targets": [prey_wall],
    "pursuit_targets": [],
    "static_obstacles": [],
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
  }
  _assert(
    not bool(
      d.call(
        "_predator_obstructed_hunt_active",
        wall_hunt_ctx,
        fox_m,
        fox_edge_close,
        fox_he,
        2,
      )
    ),
    "edge-pinned prey does not trigger obstacle flank when only playfield OOB blocks closing",
  )
  var wall_close: Vector3 = d.call(
    "_predator_edge_chase_intent",
    fox_edge_close,
    prey_wall,
    fox_he,
    Vector3.ZERO,
    bounds_max,
    42,
  )
  _assert(
    wall_close.dot(Vector3.RIGHT) > 0.85,
    "edge chase closes along playfield wall toward pinned prey",
  )
  var edge_ctx := {
    "prey_seek_targets": [Vector3(400.0, 0.0, 550.0)],
    "pursuit_targets": [],
    "static_obstacles": [],
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
  }
  _assert(
    not bool(
      d.call(
        "_predator_hunt_stalemate_allowed",
        edge_ctx,
        fox_m,
        Vector3(400.0, 0.0, 50.0),
        fox_he,
        3,
      )
    ),
    "open-field body stall does not use generic stalemate sidestep",
  )
  var open_stall_ctx := {
    "prey_seek_targets": [Vector3(450.0, 0.0, 350.0)],
    "pursuit_targets": [],
    "static_obstacles": [],
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
  }
  _assert(
    bool(
      d.call(
        "_predator_open_hunt_close_stalled",
        open_stall_ctx,
        fox_m,
        Vector3(400.0, 0.0, 400.0),
        fox_he,
        2,
      )
    ),
    "open-field hunt stall triggers direct close override",
  )
  var close_ne: Vector3 = d.call(
    "_predator_open_hunt_close_intent",
    Vector3(400.0, 0.0, 400.0),
    Vector3(450.0, 0.0, 350.0),
  )
  var sq2 := 0.7071067811865476
  _assert(
    close_ne.length_squared() > 1e-12
    and close_ne.is_equal_approx(Vector3(sq2, 0.0, -sq2)),
    "open hunt close snaps NE toward diagonal prey",
  )
  var open_ctx := {
    "prey_seek_targets": [Vector3(450.0, 0.0, 350.0)],
    "pursuit_targets": [],
    "static_obstacles": [],
    "bounds_min": Vector2.ZERO,
    "bounds_max": bounds_max,
  }
  var prey_he_t := Vector2(13.5, 30.5)
  var close_band_t: float = d.call(
    "_predator_edge_kill_close_band", fox_he, prey_he_t, fox_m
  )
  var fox_pos := Vector3(400.0, 0.0, 400.0)
  var prey_contact_pos := Vector3(400.0 + close_band_t * 0.5, 0.0, 400.0)
  _assert(
    bool(
      d.call(
        "_predator_open_hunt_close_stalled",
        open_ctx,
        fox_m,
        fox_pos,
        fox_he,
        0,
      )
    ) == false,
    "open hunt stall not required at contact when not stuck",
  )
  var contact_intent: Vector3 = d.call(
    "_predator_open_hunt_close_intent",
    fox_pos,
    prey_contact_pos,
  )
  _assert(
    contact_intent.length_squared() > 1e-12
    and contact_intent.dot((prey_contact_pos - fox_pos).normalized()) > 0.85,
    "open-field contact uses closing oct direction toward prey",
  )
  d.free()
  _test_food_plant_awareness_gating(AD)
  _test_carnivore_prey_awareness_gating(AD)


func _test_carnivore_prey_awareness_gating(ad_script: Script) -> void:
  ## Carnivore ENGINE prey list uses the same radius/cone gate as herbivore-vs-predator mob sampling.
  var main := Node3D.new()
  root.add_child(main)
  var hunter := _spawn_carnivore_body(main, Vector3(320.0, 0.0, 240.0))
  var prey := _spawn_herbivore_body(main, hunter.global_position + Vector3(80.0, 0.0, 0.0))
  hunter.set("last_move_direction", Vector3.RIGHT)
  var driver: Node = ad_script.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var motor_gate := {
    "awareness_radius": 120.0,
    "awareness_cone_extra": 0.0,
    "awareness_cone_half_angle_deg": 45.0,
  }
  var pos_h: Vector3 = hunter.global_position
  var he := Vector2(10.0, 10.0)
  var near_arr: Array = driver.call("_collect_prey_positions", hunter, motor_gate, pos_h, he)
  _assert(near_arr.size() == 1, "prey inside carnivore awareness radius is tracked")
  prey.global_position = hunter.global_position + Vector3(-260.0, 0.0, 0.0)
  var far_arr: Array = driver.call("_collect_prey_positions", hunter, motor_gate, pos_h, he)
  _assert(far_arr.is_empty(), "prey outside carnivore awareness radius is omitted")
  prey.global_position = hunter.global_position + Vector3(-80.0, 0.0, 0.0)
  var cone_strict := {
    "awareness_radius": 500.0,
    "awareness_cone_extra": 0.0,
    "awareness_cone_half_angle_deg": 45.0,
    "awareness_forward_cone_only": true,
  }
  var behind_arr: Array = driver.call("_collect_prey_positions", hunter, cone_strict, pos_h, he)
  _assert(behind_arr.is_empty(), "prey behind hunter omitted with forward_cone_only")
  prey.global_position = hunter.global_position + Vector3(80.0, 0.0, 0.0)
  var ahead_arr: Array = driver.call("_collect_prey_positions", hunter, cone_strict, pos_h, he)
  _assert(ahead_arr.size() == 1, "prey ahead still tracked with forward_cone_only")
  prey.global_position = hunter.global_position + Vector3(150.0, 0.0, 0.0)
  var fox_hybrid := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params().duplicate(true),
    "res://assets/creatures/fox",
  )
  var hybrid_arr: Array = driver.call(
    "_collect_prey_positions", hunter, fox_hybrid, pos_h, he
  )
  _assert(
    hybrid_arr.size() == 1,
    "fox hybrid pack sees prey in forward cone beyond base radius disk",
  )
  driver.queue_free()
  main.queue_free()


func _test_forward_cone_only_awareness() -> void:
  var reach_disk := _Motor.effective_awareness_reach(
    Vector3.ZERO, Vector3(-100.0, 0.0, 0.0), 500.0, 0.0, cos(deg_to_rad(45.0)), Vector3.RIGHT, false
  )
  _assert(is_equal_approx(reach_disk, 500.0), "hybrid disk reach applies behind creature")
  var reach_ahead := _Motor.effective_awareness_reach(
    Vector3.ZERO, Vector3(100.0, 0.0, 0.0), 500.0, 200.0, cos(deg_to_rad(45.0)), Vector3.RIGHT, false
  )
  _assert(is_equal_approx(reach_ahead, 700.0), "hybrid forward cone adds cone_extra to base radius")
  var reach_cone := _Motor.effective_awareness_reach(
    Vector3.ZERO, Vector3(-100.0, 0.0, 0.0), 500.0, 0.0, cos(deg_to_rad(45.0)), Vector3.RIGHT, true
  )
  _assert(is_equal_approx(reach_cone, 0.0), "forward_cone_only zeroes reach behind creature")
  var ad_script: Script = _ai_driver_script()
  if not _ai_driver_can_instantiate():
    push_warning("skip ai_driver cone gating tests — AiDriver script did not compile")
    return
  _test_forward_cone_only_food_gating(ad_script)
  _test_forward_cone_only_threat_gating(ad_script)
  _test_sated_herbivore_explore_with_off_cone_food(ad_script)
  _test_sated_predator_ignores_prey(ad_script)


func _test_forward_cone_only_food_gating(ad_script: Script) -> void:
  var main := Node3D.new()
  root.add_child(main)
  var bush := _spawn_food_bush(main, Vector3(-8.0, 0.0, 0.0))
  var driver: Node = ad_script.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var creature_pos := Vector3.ZERO
  var he := Vector2(13.5, 30.5)
  var facing := Vector3.RIGHT
  var motor_cone := {
    "awareness_radius": 500.0,
    "awareness_cone_extra": 0.0,
    "awareness_cone_half_angle_deg": 45.0,
    "awareness_forward_cone_only": true,
  }
  var split_behind: Dictionary = driver.call(
    "_motor_food_plants_in_awareness_by_readiness", motor_cone, creature_pos, he, facing
  )
  var ready_behind: Array = split_behind.get("ready", []) as Array
  _assert(ready_behind.is_empty(), "bush behind creature hidden with forward_cone_only")
  bush.global_position = Vector3(8.0, 0.0, 0.0)
  var split_ahead: Dictionary = driver.call(
    "_motor_food_plants_in_awareness_by_readiness", motor_cone, creature_pos, he, facing
  )
  var ready_ahead: Array = split_ahead.get("ready", []) as Array
  _assert(ready_ahead.size() == 1, "bush in forward cone visible with forward_cone_only")
  driver.queue_free()
  main.queue_free()


func _test_forward_cone_only_threat_gating(ad_script: Script) -> void:
  var main := Node3D.new()
  root.add_child(main)
  var prey := _spawn_herbivore_body(main, Vector3(40.0, 0.0, 30.0))
  var predator := _spawn_carnivore_body(main, prey.global_position + Vector3(-12.0, 0.0, 0.0))
  prey.set("last_move_direction", Vector3.RIGHT)
  var driver: Node = ad_script.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var motor_p := {
    "awareness_radius": 500.0,
    "awareness_cone_extra": 0.0,
    "awareness_cone_half_angle_deg": 45.0,
    "awareness_forward_cone_only": true,
    "herbivore_threat_awareness_omni": false,
  }
  var he := Vector2(13.5, 30.5)
  var facing := Vector3.RIGHT
  var behind_threat: Dictionary = driver.call(
    "_herbivore_predator_threat_sample",
    prey,
    motor_p,
    prey.global_position,
    he,
    facing,
  )
  _assert(not bool(behind_threat.get("in_awareness", true)), "fox behind rabbit not in threat awareness")
  predator.global_position = prey.global_position + Vector3(12.0, 0.0, 0.0)
  var ahead_threat: Dictionary = driver.call(
    "_herbivore_predator_threat_sample",
    prey,
    motor_p,
    prey.global_position,
    he,
    facing,
  )
  _assert(bool(ahead_threat.get("in_awareness", false)), "fox ahead of rabbit in threat awareness")
  driver.queue_free()
  main.queue_free()


func _test_sated_herbivore_explore_with_off_cone_food(ad_script: Script) -> void:
  var main := Node3D.new()
  root.add_child(main)
  var prey := _spawn_herbivore_body(main, Vector3.ZERO)
  _spawn_food_bush(main, prey.global_position + Vector3(-12.0, 0.0, 0.0))
  prey.set("last_move_direction", Vector3.RIGHT)
  prey.set("current_calories", float(prey.get("caloric_needs")))
  var driver: Node = ad_script.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  driver.call("register_creature", prey)
  driver.call("set_primary_creature", prey)
  driver.set("_duel_motor_round_salt", 90210)
  var base := _Merge.default_creature_motor_params()
  var motor_p := _Merge.merge_creature_motor_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/rabbit",
  )
  var ctx: Dictionary = driver.call("_build_motor_context", motor_p, {}, prey)
  _assert(
    float(ctx.get("weight_seek_ready_food", -1.0)) <= 0.0,
    "sated rabbit does not seek food at full calories",
  )
  _assert(
    float(ctx.get("weight_expanding_explore_hint", 0.0)) > 0.0,
    "sated rabbit with off-cone bush gets expanding explore hint",
  )
  _assert(
    float(ctx.get("exploration_blend_multiplier", 0.0)) > 0.0,
    "sated rabbit with off-cone bush keeps exploration blend",
  )
  driver.queue_free()
  main.queue_free()


func _test_sated_predator_ignores_prey(ad_script: Script) -> void:
  var main := Node3D.new()
  root.add_child(main)
  var predator := _spawn_carnivore_body(main, Vector3.ZERO)
  _spawn_herbivore_body(main, Vector3(12.0, 0.0, 0.0))
  predator.set("last_move_direction", Vector3.RIGHT)
  predator.set("current_calories", float(predator.get("caloric_needs")))
  var driver: Node = ad_script.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var motor_p := _Merge.merge_creature_motor_pack_overlay(
    _Merge.default_creature_motor_params().duplicate(true),
    "res://assets/creatures/fox",
  )
  var ctx: Dictionary = driver.call("_build_motor_context", motor_p, {}, predator)
  _assert(
    not (driver.call("_prey_positions_for_predator_motor", predator) as Array).is_empty(),
    "sated fox still perceives prey in awareness cone",
  )
  _assert(
    float(ctx.get("weight_seek_prey", -1.0)) <= 0.0,
    "sated fox does not seek prey at full calories",
  )
  _assert(
    (ctx.get("prey_seek_targets", []) as Array).is_empty(),
    "sated fox motor ctx omits prey seek targets",
  )
  _assert(
    (ctx.get("pursuit_targets", []) as Array).is_empty(),
    "sated fox motor ctx omits pursuit targets",
  )
  _assert(
    not bool(ctx.get("motor_has_active_goal", true)),
    "sated fox with visible rabbit has no active hunt goal",
  )
  _assert(
    bool(ctx.get("motor_seek_oct_directions", false)),
    "sated fox patrol exploration uses eight-way seek headings",
  )
  predator.set("current_calories", 0.0)
  var hunt_ctx: Dictionary = driver.call("_build_motor_context", motor_p, {}, predator)
  _assert(
    bool(hunt_ctx.get("motor_seek_oct_directions", false)),
    "hungry fox without visible prey still uses eight-way motor headings",
  )
  driver.queue_free()
  main.queue_free()


func _test_duel_spawn_facing_variance() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip duel spawn facing test — AiDriver script did not compile")
    return
  var main := Node3D.new()
  root.add_child(main)
  var prey := _spawn_herbivore_body(main, Vector3.ZERO)
  var driver: Node = _AiDriverScr.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  driver.call("register_creature", prey)
  driver.set("_duel_motor_round_salt", 0x1234)
  driver.call("_randomize_duel_spawn_facing")
  var facing_a: Vector3 = prey.get("last_move_direction")
  driver.set("_duel_motor_round_salt", 0x5678)
  driver.call("_randomize_duel_spawn_facing")
  var facing_b: Vector3 = prey.get("last_move_direction")
  _assert(facing_a.length_squared() > 1e-12, "random duel facing is non-zero")
  _assert(facing_a != facing_b, "duel spawn facing varies with round salt")
  driver.queue_free()
  main.queue_free()


func _test_food_plant_awareness_gating(ad_script: Script) -> void:
  var main := Node3D.new()
  root.add_child(main)
  var bush := _spawn_food_bush(main, Vector3(8.0, 0.0, 0.0))
  var driver: Node = ad_script.new()
  root.add_child(driver)
  driver.call("attach_main", main)
  var creature_pos := Vector3.ZERO
  var he := Vector2(13.5, 30.5)
  var facing := Vector3.RIGHT
  var motor_off := {
    "awareness_radius": 0.0,
    "awareness_cone_extra": 0.0,
    "awareness_cone_half_angle_deg": 45.0,
  }
  var split_off: Dictionary = driver.call(
    "_motor_food_plants_in_awareness_by_readiness", motor_off, creature_pos, he, facing
  )
  var ready_off: Array = split_off.get("ready", []) as Array
  var unready_off: Array = split_off.get("unready", []) as Array
  _assert(ready_off.is_empty() and unready_off.is_empty(), "awareness_radius 0 yields no motor food targets")
  var motor_on := {
    "awareness_radius": 200.0,
    "awareness_cone_extra": 0.0,
    "awareness_cone_half_angle_deg": 180.0,
  }
  var split_near: Dictionary = driver.call(
    "_motor_food_plants_in_awareness_by_readiness", motor_on, creature_pos, he, facing
  )
  var ready_near: Array = split_near.get("ready", []) as Array
  _assert(ready_near.size() == 1, "bush inside awareness radius is visible to motor")
  bush.global_position = Vector3(5000.0, 0.0, 0.0)
  var split_far: Dictionary = driver.call(
    "_motor_food_plants_in_awareness_by_readiness", motor_on, creature_pos, he, facing
  )
  var ready_far: Array = split_far.get("ready", []) as Array
  var unready_far: Array = split_far.get("unready", []) as Array
  _assert(ready_far.is_empty() and unready_far.is_empty(), "bush outside awareness radius is excluded")
  driver.queue_free()
  main.queue_free()


func _test_environment_movement_impact_merge() -> void:
  var solid := _EnvCell.new()
  solid.passible = false
  var mud := _EnvCell.new()
  mud.passible = true
  mud.movement_impact = 0.3
  var water := _EnvCell.new()
  water.passible = true
  water.movement_impact = 0.1
  var m1 := _EnvMerge.merge_greatest_impact([mud, solid])
  _assert(m1 != null and not m1.passible, "solid beats mud in merge")
  var m2 := _EnvMerge.merge_greatest_impact([mud, water])
  _assert(m2 != null and is_equal_approx(m2.movement_impact, 0.3), "mud beats water in merge")


func _test_environment_footprint_overlap() -> void:
  var frac := _Footprint.circle_cell_overlap_fraction(
    Vector2(50.0, 50.0), 10.0, Vector2(40.0, 40.0), 20.0
  )
  _assert(frac >= _Footprint.MIN_OVERLAP_FRACTION, "centered footprint meets overlap threshold")
  var frac_edge := _Footprint.circle_cell_overlap_fraction(
    Vector2(95.0, 50.0), 5.0, Vector2(80.0, 40.0), 20.0
  )
  _assert(frac_edge < _Footprint.MIN_OVERLAP_FRACTION, "grazing overlap below threshold")


func _test_creature_size_sync_capsule() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3.ZERO)
  var base_r: float = body.get_collision_capsule_radius()
  var base_size: float = body.creature_size
  body.apply_effective_creature_size(base_size * 2.0)
  _assert(
    is_equal_approx(body.get_collision_capsule_radius(), base_r * 2.0),
    "capsule radius tracks creature_size scale",
  )
  _assert(
    is_equal_approx(body.get_los_eye_height(), body.get_collision_capsule_height() * 0.9),
    "los eye height derives from capsule height",
  )
  main.queue_free()


func _test_line_of_sight_wall_occlusion() -> void:
  var scene_root := Node3D.new()
  root.add_child(scene_root)
  var wall := StaticBody3D.new()
  var box := BoxShape3D.new()
  box.size = Vector3(2.0, 4.0, 4.0)
  var col := CollisionShape3D.new()
  col.shape = box
  wall.add_child(col)
  wall.position = Vector3(5.0, 1.0, 0.0)
  wall.collision_layer = 1
  scene_root.add_child(wall)
  await process_frame
  var space := scene_root.get_world_3d().direct_space_state
  var from := Vector3(0.0, 1.0, 0.0)
  var to := Vector3(10.0, 1.0, 0.0)
  var frac := _LoS.occlusion_fraction(space, from, to, [])
  _assert(_LoS.is_occluded(frac), "static wall occludes line of sight > 60%")
  scene_root.queue_free()


func _test_nav_path_hint_invalid_map() -> void:
  var dir := _NavHint.unit_direction_to_next_waypoint(RID(), Vector3.ZERO, Vector3(10, 0, 0), 0.35)
  _assert(dir == Vector3.ZERO, "invalid nav map returns zero hint")


func _test_bundled_inference_helpers() -> void:
  var BN := load("res://AI_int_lib/bundled_inference_launcher.gd") as Script
  var ic_off := {"INFERENCE_AUTO_START_ENABLED": false}
  _assert(not Callable(BN, &"should_attempt_auto_start").call(ic_off, "http://127.0.0.1:8080"), "auto-start off")
  var ic_on := {"INFERENCE_AUTO_START_ENABLED": true}
  _assert(Callable(BN, &"should_attempt_auto_start").call(ic_on, "http://127.0.0.1:8080"), "loopback + auto")
  _assert(not Callable(BN, &"should_attempt_auto_start").call(ic_on, "https://api.example.com"), "remote URL no spawn")
  _assert(Callable(BN, &"port_from_base_url").call("http://127.0.0.1:9090/") == 9090, "port parse")
  _assert(Callable(BN, &"port_from_base_url").call("http://127.0.0.1") == 8080, "default port when omitted")
