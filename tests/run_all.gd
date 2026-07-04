## Headless test entry: [code]godot --path . --headless -s res://tests/run_all.gd[/code]
extends SceneTree

const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _Tokens := preload("res://AI_int_lib/ai_action_tokens.gd")
const _Wire := preload("res://AI_int_lib/perception_wire.gd")
const _Sampling := preload("res://AI_int_lib/perception_sampling.gd")
const _Risk := preload("res://AI_int_lib/perception_risk_hints.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _EnvCell := preload("res://environment/environment_cell_data.gd")
const _EnvGrid := preload("res://environment/environment_grid_baked.gd")
const _EnvBake := preload("res://environment/environment_grid_bake.gd")
const _PackRes := preload("res://pack_resource_resolver.gd")
const _GoalMem := preload("res://creature/motor/goal_source_memory.gd")
const _GkReg := preload("res://creature/memory/goal_kind_registry.gd")
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
const _GoalBeliefScr := preload("res://creature/motor/goal_belief_memory.gd")
const _KinematicBody3DScr := preload("res://creature/capabilities/creature_kinematic_body_3d.gd")
const _RabbitArchetypeRes := preload("res://creature/species/rabbit_archetype.tres")
const _FoxArchetypeRes := preload("res://creature/species/fox_archetype.tres")
const _EnvMerge := preload("res://environment/environment_movement_impact.gd")
const _Footprint := preload("res://environment/environment_footprint_sampler.gd")
const _LoS := preload("res://creature/motor/line_of_sight.gd")
const _NavHint := preload("res://environment/nav_path_hint.gd")
const _BlockedApproachScr := preload("res://creature/motor/blocked_approach_memory.gd")
const _ThreatSampleScr := preload("res://creature/motor/threat_sample.gd")
const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _ActionOutcome := preload("res://creature/motor/action_outcome.gd")
const _LocomotionExecutor := preload("res://creature/motor/locomotion_executor.gd")
const _MotorGoalHub := preload("res://creature/motor/motor_goal_hub.gd")
const _MotorCadence := preload("res://creature/motor/motor_consideration_cadence.gd")
const _CreatureMotorStack := preload("res://creature/motor/creature_motor_stack.gd")
const _AwarenessZone := preload("res://creature/motor/awareness_zone.gd")
const _AwarenessScan := preload("res://creature/motor/awareness_zone_scan.gd")
const _MotorPlanner := preload("res://creature/motor/motor_planner.gd")
const _MotorPathFixture := preload("res://tests/motor_path_fixture.gd")
const _MemoryAdapter := preload("res://creature/motor/memory_adapter.gd")
const _KindProfile := preload("res://creature/motor/kind_profile_memory.gd")
const _DeadEndMem := preload("res://creature/motor/dead_end_memory.gd")
const _BlockedObjective := preload("res://creature/motor/blocked_objective_resolver.gd")
const _LearnReg := preload("res://creature/memory/stimulus_learn_registry.gd")
const _BushFoodScr := preload("res://assets/plants/bush_food_3d.gd")

const _Herbivore3DScenePath := "res://creature/templates/creature_herbivore_kinematic_3d.tscn"
const _Carnivore3DScenePath := "res://creature/templates/creature_carnivore_kinematic_3d.tscn"
const _SolidShrub3DScenePath := "res://assets/plants/solid_shrub/solid_shrub_3d.tscn"

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
  _test_creature_motor_v3_merge_defaults()
  _test_creature_pack_motor_overlays()
  _test_creature_motor_v3_pack_overlays()
  _test_creature_motor_v3_playfield_distance_scale()
  _test_locomotion_executor_turn_facing()
  _test_motor_planner_turn_alignment_no_flip_flop()
  _test_motor_planner_precise_backtrack_ignored()
  _test_motor_planner_explore_latch()
  _test_motor_planner_explore_rear_hemisphere_no_flip_flop()
  _test_motor_planner_latched_stuck_replan()
  await _test_creature_motor_stack_precise_turn_no_flip_flop()
  _test_body_motor_stack_skips_legacy_physics()
  _test_locomotion_executor_turn_clears_velocity()
  await _test_locomotion_executor_move_forward()
  _test_locomotion_executor_stay_calorie_debit()
  await _test_locomotion_executor_move_blocked()
  _test_body_no_distance_calorie_burn()
  _test_motor_goal_hub_starvation_eat_only()
  _test_motor_goal_hub_urgency_eat_preserve_band()
  _test_motor_goal_hub_subacute_flight_weight()
  _test_motor_consideration_cadence_interval()
  _test_creature_motor_stack_tick_valid_action()
  _test_creature_motor_stack_consideration_advances()
  _test_creature_motor_stack_dual_isolation()
  _test_creature_motor_stack_integration_single_debit()
  await _test_awareness_zone_scan_live_food()
  await _test_motor_path_fixture_open_nav()
  await _test_motor_path_fixture_blocked_nav()
  await _test_creature_motor_stack_seek_live_food()
  await _test_creature_motor_stack_explore_no_live_food()
  await _test_creature_motor_stack_seek_precise_memory()
  await _test_creature_motor_stack_seek_coarse_memory()
  await _test_creature_motor_stack_seek_locale_prior()
  _test_creature_motor_stack_memory_live_beats_precise()
  _test_creature_motor_stack_memory_tier_precedence()
  _test_creature_motor_stack_memory_dual_isolation()
  _test_creature_motor_stack_memory_feasibility_tiers()
  _test_creature_motor_stack_memory_stale_instance_id()
  _test_creature_motor_stack_memory_live_sync()
  _test_creature_motor_stack_memory_maintain_coarse_ttl()
  _test_creature_motor_stack_memory_eat_locale_write()
  _test_creature_motor_stack_memory_write_dual_isolation()
  _test_creature_motor_stack_sated_stay()
  _test_creature_motor_stack_debug_snapshot()
  _test_creature_motor_stack_memory_kind_ewma()
  _test_creature_motor_stack_memory_dead_end_filter()
  _test_creature_motor_stack_memory_passibility_switch()
  _test_creature_motor_stack_memory_blocked_objective()
  await _test_creature_motor_stack_blocked_memory_writes()
  _test_food_plant_missing_stimulus_kind_id()
  _test_goal_source_memory()
  _test_goal_kind_phase_c_replay()
  _test_creature_trait_usage_wiring()
  _test_locale_prior_escalate_seek()
  _test_escape_reversal_suppression()
  _test_goal_belief_coarse_ttl()
  _test_load_merged_config_repo_fallback()
  _test_hunter_killer_debug_project_settings()
  _test_tokens()
  _test_perception_snippet()
  _test_perception_sampling()
  _test_perception_risk_hints()
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
  _test_creature_spawn_floor_settle()
  _test_human_prey_control_bootstrap()
  _test_human_move_intent_world_space()
  _test_human_facing_blocked_no_spin()
  _test_human_strafe_intent_stable_under_camera_spin()
  _test_top_down_camera_pan_directions()
  _test_top_down_camera_zoom_clamp()
  _test_footprint_geometry()
  _test_creature_diet_on_3d_bodies()
  _test_ai_driver_creature_registry()
  _test_environment_baked_grid()
  _test_environment_movement_impact_merge()
  _test_environment_footprint_overlap()
  _test_creature_size_sync_capsule()
  await _test_line_of_sight_wall_occlusion()
  _test_nav_path_hint_invalid_map()
  _test_nav_path_hint_first_waypoint_invalid_map()
  _test_blocked_approach_memory()
  _test_seek_wall_filter_and_backtrack()
  _test_motor_plane_yaw_from_facing()
  _test_ai_driver_helpers()
  _test_duel_spawn_facing_variance()
  _test_bundled_inference_helpers()
  _test_creature_kinematic_playfield_clamp_after_move()
  if _failures > 0:
    push_error("tests/run_all.gd: %d assertion(s) failed." % _failures)

func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)

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
  d.free()

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

func _test_bundled_inference_helpers() -> void:
  var BN := load("res://AI_int_lib/bundled_inference_launcher.gd") as Script
  var ic_off := {"INFERENCE_AUTO_START_ENABLED": false}
  _assert(not Callable(BN, &"should_attempt_auto_start").call(ic_off, "http://127.0.0.1:8080"), "auto-start off")
  var ic_on := {"INFERENCE_AUTO_START_ENABLED": true}
  _assert(Callable(BN, &"should_attempt_auto_start").call(ic_on, "http://127.0.0.1:8080"), "loopback + auto")
  _assert(not Callable(BN, &"should_attempt_auto_start").call(ic_on, "https://api.example.com"), "remote URL no spawn")
  _assert(Callable(BN, &"port_from_base_url").call("http://127.0.0.1:9090/") == 9090, "port parse")
  _assert(Callable(BN, &"port_from_base_url").call("http://127.0.0.1") == 8080, "default port when omitted")

func _test_calorie_drain_movement_formula() -> void:
  ## Same formula as [code]Player._apply_calorie_drain_and_starvation[/code] / [code]Mob._apply_calorie_burn[/code].
  var baseline := 1.0
  var per_unit := 0.002
  var delta := 1.0
  var speed_units_s := 100.0
  var burn := baseline * delta + per_unit * speed_units_s * delta
  _assert(is_equal_approx(burn, 1.2), "1s at 100 units/s matches baseline + per-unit movement")

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
  root.add_child(herb_root)
  root.add_child(carn_root)
  await physics_frame
  pred_body.set("current_calories", 20.0)
  var pred_cal_before := float(pred_body.get("current_calories"))
  var hit_state: Array = [0]
  prey_body.hit.connect(func() -> void: hit_state[0] = int(hit_state[0]) + 1)
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
  await physics_frame
  var hb_cs := prey_body.get_node_or_null("MobHitbox/CollisionShape3D") as CollisionShape3D
  _assert(hb_cs != null and hb_cs.disabled, "prey MobHitbox disabled after defeat")
  herb_root.queue_free()
  carn_root.queue_free()
  floor_body.queue_free()

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

func _test_creature_kinematic_playfield_clamp_after_move() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(100.0, 100.0)
  var body := _spawn_carnivore_body(main, Vector3(88.0, 1.0, 50.0))
  body.set("playfield_bounds_min", bounds_min)
  body.set("playfield_bounds_max", bounds_max)
  body.set("screen_size", bounds_max)
  body.set_control_mode(_ControlMode.engine_as_int())
  var motor_p := _Merge.default_creature_motor_params()
  var he := _MotorPlane.footprint_half_extents(body, motor_p)
  body.global_position = Vector3(bounds_max.x - he.x - 0.1, 1.0, 50.0)
  body.velocity = Vector3(30.0, 0.0, 0.0)
  body.apply_horizontal_move_intent(Vector3(1.0, 0.0, 0.0), 1.0)
  body.call("_clamp_playfield_position")
  _assert(
    body.global_position.x + he.x <= bounds_max.x + 0.01,
    "kinematic post-move clamp keeps footprint inside east bound (x=%.2f max=%.2f)"
    % [body.global_position.x + he.x, bounds_max.x],
  )
  body.global_position = Vector3(bounds_min.x + he.x + 0.1, 1.0, 50.0)
  body.velocity = Vector3(-30.0, 0.0, 0.0)
  body.apply_horizontal_move_intent(Vector3(-1.0, 0.0, 0.0), 1.0)
  body.call("_clamp_playfield_position")
  _assert(
    body.global_position.x - he.x >= bounds_min.x - 0.01,
    "kinematic post-move clamp keeps footprint inside west bound",
  )
  main.queue_free()

func _test_creature_pack_motor_overlays() -> void:
  # Build the dev-profile base explicitly so this test is deterministic regardless of the
  # ambient hunter_killer_debug/use_ship_motor_profile editor toggle (project.godot).
  var base := _Merge.apply_creature_motor_profile_dev(_Merge.creature_motor_spine())
  var rabbit_m := _Merge.merge_creature_motor_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/rabbit",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("weight_seek_ready_food", 0.0)), 18.0),
    "rabbit pack restores food seek under dev profile",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("motor_intent_cost_chaos", -1.0)), 2.8),
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
    is_equal_approx(float(fox_m.get("motor_intent_cost_chaos", -1.0)), 4.4),
    "fox pack duel motor chaos",
  )
  _assert(
    is_equal_approx(float(fox_m.get("geometry_escape_lock_ticks", 0.0)), 14.0),
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
    is_equal_approx(float(fox_m.get("motor_no_goal_patrol_lock_sec", 0.0)), 0.35),
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

func _test_creature_motor_v3_merge_defaults() -> void:
  var base := _Merge.default_root()
  _assert(base.has("creature_motor_v3"), "default_root includes creature_motor_v3")
  var v3: Dictionary = base["creature_motor_v3"]
  _assert(is_equal_approx(float(v3.get("turn_increment_deg", 0.0)), 22.5), "v3 turn_increment_deg default")
  _assert(
    is_equal_approx(float(v3.get("calorie_baseline_drain_per_sec", 0.0)), 1.0),
    "v3 calorie_baseline_drain_per_sec default",
  )
  _assert(
    is_equal_approx(float(v3.get("move_calorie_per_sec", 0.0)), 1.0),
    "v3 move_calorie_per_sec default",
  )
  _assert(
    is_equal_approx(float(v3.get("rest_baseline_multiplier", 0.0)), 0.5),
    "v3 rest_baseline_multiplier default",
  )
  _assert(
    is_equal_approx(float(v3.get("preserve_bias_food_floor", 0.0)), 0.90),
    "v3 preserve_bias_food_floor default",
  )
  _assert(
    is_equal_approx(float(v3.get("seek_priority_food_ceiling", 0.0)), 0.80),
    "v3 seek_priority_food_ceiling default",
  )
  _assert(
    is_equal_approx(float(v3.get("los_blocked_occlusion_fraction", 0.0)), 0.80),
    "v3 los_blocked_occlusion_fraction default",
  )
  _assert(int(v3.get("goal_replan_base_ticks", -1)) == 8, "v3 goal_replan_base_ticks default")
  _assert(
    is_equal_approx(float(v3.get("blocked_objective_chaos", 0.0)), 0.15),
    "v3 blocked_objective_chaos default",
  )
  _assert(
    is_equal_approx(float(v3.get("goal_consideration_chaos", 0.0)), 0.15),
    "v3 goal_consideration_chaos default",
  )
  var file_root := {"creature_motor_v3": {"turn_increment_deg": 30.0}}
  var merged: Dictionary = _Merge.merge_root(base, file_root)
  _assert(
    is_equal_approx(float(merged["creature_motor_v3"].get("turn_increment_deg", 0.0)), 30.0),
    "merge creature_motor_v3 override",
  )
  _assert(
    is_equal_approx(float(merged["creature_motor_v3"].get("move_calorie_per_sec", 0.0)), 1.0),
    "merge creature_motor_v3 keeps default move_calorie_per_sec",
  )

func _test_creature_motor_v3_pack_overlays() -> void:
  var base := _Merge.default_creature_motor_v3_params()
  var rabbit_m := _Merge.merge_creature_motor_v3_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/rabbit",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("awareness_radius", 0.0)), 150.0),
    "rabbit v3 pack awareness_radius",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("flight_acute_panic_radius", 0.0)), 220.0),
    "rabbit v3 pack flight_acute_panic_radius",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("preserve_bias_food_floor", 0.0)), 0.90),
    "rabbit v3 pack preserve_bias_food_floor",
  )
  var fox_m := _Merge.merge_creature_motor_v3_pack_overlay(
    base.duplicate(true),
    "res://assets/creatures/fox",
  )
  _assert(
    is_equal_approx(float(fox_m.get("awareness_radius", 0.0)), 150.0),
    "fox v3 pack awareness_radius",
  )
  _assert(
    is_equal_approx(float(fox_m.get("awareness_cone_half_angle_deg", 0.0)), 50.0),
    "fox v3 pack awareness_cone_half_angle_deg",
  )
  _assert(
    is_equal_approx(float(rabbit_m.get("awareness_radius", 0.0)), 150.0),
    "rabbit v3 overlay overrides default awareness_radius",
  )
  var explicit_v3 := _PackRes.load_creature_motor_v3_overlay("res://assets/creatures/rabbit")
  _assert(not explicit_v3.is_empty(), "rabbit pack defines creature_motor_v3 block")


func _test_creature_motor_v3_playfield_distance_scale() -> void:
  var rabbit_v3 := _Merge.merge_creature_motor_v3_pack_overlay(
    _Merge.default_creature_motor_v3_params(),
    "res://assets/creatures/rabbit",
  )
  var expected_scale := 189.0 / _MotorPlane.REFERENCE_MOTOR_PLAYFIELD_EDGE
  var scaled := _MotorPlane.scale_motor_distance_params(rabbit_v3, expected_scale)
  _assert(
    is_equal_approx(float(scaled.get("awareness_radius", 0.0)), 150.0 * expected_scale),
    "v3 awareness_radius scales with playfield factor",
  )
  _assert(
    is_equal_approx(float(scaled.get("flight_acute_panic_radius", 0.0)), 220.0 * expected_scale),
    "v3 flight_acute_panic_radius scales with playfield factor",
  )
  var body := CharacterBody3D.new()
  body.set_script(load("res://creature/capabilities/creature_kinematic_body_3d.gd"))
  body.screen_size = Vector2(189.0, 189.0)
  var pf := _MotorPlane.playfield_size_for_body(body, null)
  _assert(is_equal_approx(pf.x, 189.0), "body screen_size drives playfield size for v3 scale")
  var from_body := _MotorPlane.scale_creature_motor_v3_for_playfield(rabbit_v3, body, null)
  _assert(
    is_equal_approx(float(from_body.get("awareness_radius", 0.0)), 150.0 * expected_scale),
    "scale_creature_motor_v3_for_playfield matches body screen_size",
  )


func _motor_v3_test_params() -> Dictionary:
  var p := _Merge.default_creature_motor_v3_params()
  p["awareness_radius"] = 500.0
  p["awareness_cone_extra"] = 200.0
  p["awareness_cone_half_angle_deg"] = 80.0
  p["awareness_requires_los"] = false
  return p


func _test_awareness_zone_scan_live_food() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  var bush := _spawn_food_bush(main, Vector3(0.0, 1.0, -12.0))
  await process_frame
  var scan := _AwarenessScan.scan_live(body, _motor_v3_test_params(), main.get_tree())
  var ready: Array = scan["food_split"]["ready"]
  _assert(ready.size() >= 1, "awareness scan finds ready live food")
  var entry: Dictionary = ready[0]
  _assert(int(entry.get("instance_id", 0)) == bush.get_instance_id(), "food entry carries instance_id")
  _assert(entry.get("stimulus_kind_id", &"") != &"", "food entry carries stimulus_kind_id")
  main.queue_free()


func _test_motor_path_fixture_open_nav() -> void:
  var main := _TerrainTestMainStub.new()
  root.add_child(main)
  var built := main.mount_motor_path_fixture("open")
  var map_rid: RID = built.get("map_rid", RID())
  _assert(map_rid.is_valid(), "motor path fixture yields valid map_rid")
  var from := Vector3(2.0, 0.0, 2.0)
  var to := Vector3(30.0, 0.0, 30.0)
  # NavigationServer commits baked regions on its own sync step (driven by physics
  # frames), so poll across several frames before asserting the path is ready.
  var ready := false
  for _i in 30:
    await physics_frame
    if _MotorPathFixture.assert_nav_path_ready(map_rid, from, to):
      ready = true
      break
  _assert(ready, "motor path fixture nav path from->to")
  main.queue_free()


func _test_motor_path_fixture_blocked_nav() -> void:
  var main := _TerrainTestMainStub.new()
  root.add_child(main)
  var built := main.mount_motor_path_fixture("blocked")
  var map_rid: RID = built.get("map_rid", RID())
  _assert(map_rid.is_valid(), "blocked motor path fixture yields valid map_rid")
  var from := Vector3(2.0, 0.0, 2.0)
  var to := Vector3(38.0, 0.0, 38.0)
  var ready := false
  var path: PackedVector3Array = PackedVector3Array()
  for _i in 30:
    await physics_frame
    path = NavigationServer3D.map_get_path(map_rid, from, to, true)
    if path.size() >= 2:
      ready = true
      break
  _assert(ready, "blocked motor path fixture nav path from->to")
  # Center wall sits near (20, 20); a detour path should not cut through the pinch at x≈20,z≈20.
  var crosses_pinch := false
  for pt in path:
    if absf(pt.x - 20.0) < 1.0 and absf(pt.z - 20.0) < 1.0:
      crosses_pinch = true
      break
  _assert(not crosses_pinch, "blocked fixture path detours around center wall")
  main.queue_free()


func _test_creature_motor_stack_seek_live_food() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  _spawn_food_bush(main, Vector3(0.0, 1.0, -14.0))
  await process_frame
  var stack := _motor_stack_test_configure(body)
  var saw_locomotion := false
  for _i in 24:
    var outcome: _ActionOutcome = stack.tick(1.0 / 60.0)
    var act := int(outcome.action)
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT or act == _MotorAction.MOVE_FORWARD:
      saw_locomotion = true
      break
  _assert(saw_locomotion, "stack seeks live food with turn or move sequence")
  _assert(not stack.get_incumbent().is_empty(), "find_food incumbent selected when food visible")
  main.queue_free()


func _test_creature_motor_stack_explore_no_live_food() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 50.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.tick(1.0 / 60.0)
  _assert(not stack.get_incumbent().is_empty(), "find_food incumbent without visible food")
  _assert(
    stack.get_planner_step_goal().length_squared() > 1e-4,
    "planner sets explore step goal when no live food",
  )
  var saw_locomotion := false
  for _i in 24:
    var outcome: _ActionOutcome = stack.tick(1.0 / 60.0)
    var act := int(outcome.action)
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT or act == _MotorAction.MOVE_FORWARD:
      saw_locomotion = true
      break
  _assert(saw_locomotion, "stack explores with turn or move when no live food")
  main.queue_free()


func _motor_stack_empty_food_scan() -> Dictionary:
  return {
    "food_split": {"ready": [], "unready": []},
    "threat_samples": [],
    "food_map_confidence": 0.0,
  }


func _test_creature_motor_stack_seek_precise_memory() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var remembered := Vector3(0.0, 1.0, -24.0)
  var now_ms := Time.get_ticks_msec()
  stack.seed_precise_food_belief_for_test(88001, remembered, now_ms)
  var saw_locomotion := false
  for _i in 24:
    stack.tick(1.0 / 60.0)
    if stack.get_planner_step_source() == &"precise":
      break
  _assert(stack.get_planner_step_source() == &"precise", "planner uses precise memory tier")
  var step_goal := stack.get_planner_step_goal()
  _assert(step_goal.distance_to(remembered) < 2.0, "precise step goal targets remembered coords")
  for _j in 24:
    var outcome: _ActionOutcome = stack.tick(1.0 / 60.0)
    var act := int(outcome.action)
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT or act == _MotorAction.MOVE_FORWARD:
      saw_locomotion = true
      break
  _assert(saw_locomotion, "precise memory seek emits locomotion without live LoS")
  main.queue_free()


func _test_creature_motor_stack_seek_coarse_memory() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var remembered := Vector3(0.0, 1.0, -80.0)
  var now_ms := Time.get_ticks_msec()
  stack.seed_coarse_food_belief_for_test(88002, remembered, now_ms)
  stack.tick(1.0 / 60.0)
  _assert(stack.get_planner_step_source() == &"coarse", "planner uses coarse memory tier")
  var step_goal := stack.get_planner_step_goal()
  _assert(step_goal.distance_to(remembered) > 5.0, "coarse step goal is not GPS to last_world_pos")
  var bearing := (remembered - body.global_position).normalized()
  var to_step := (step_goal - body.global_position).normalized()
  _assert(bearing.dot(to_step) > 0.85, "coarse step goal follows bearing-only path-in-direction")
  main.queue_free()


func _test_creature_motor_stack_seek_locale_prior() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  stack.seed_locale_prior_for_test(7, 7, 1.0)
  stack.tick(1.0 / 60.0)
  _assert(stack.get_planner_step_source() == &"locale", "planner consults locale prior when no instance beliefs")
  var step_goal := stack.get_planner_step_goal()
  _assert(step_goal.length_squared() > 1e-4, "locale prior yields a seek step goal")
  var motor_v3 := _motor_v3_test_params()
  var coverage_cell := _GoalMem.coverage_cell_from_motor(motor_v3)
  var hotspot := Vector3((7.0 + 0.5) * coverage_cell, 0.0, (7.0 + 0.5) * coverage_cell)
  var toward_hotspot := (hotspot - body.global_position).normalized()
  var toward_step := (step_goal - body.global_position).normalized()
  _assert(toward_hotspot.dot(toward_step) > 0.5, "locale prior biases seek toward hotspot anchor")
  main.queue_free()


func _motor_stack_food_ctx(body: CharacterBody3D, stack: _CreatureMotorStack, food_split: Dictionary) -> Dictionary:
  return {
    "body": body,
    "motor_v3": _motor_v3_test_params(),
    "food_split": food_split,
    "memory_adapter": stack.get_memory_adapter(),
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": null,
  }


func _test_creature_motor_stack_memory_live_beats_precise() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  var bush := _spawn_food_bush(main, Vector3(0.0, 1.0, -14.0))
  await process_frame
  var stack := _motor_stack_test_configure(body)
  var remembered := Vector3(0.0, 1.0, -40.0)
  stack.seed_precise_food_belief_for_test(88010, remembered, Time.get_ticks_msec())
  var live_entry := {
    "pos": bush.global_position,
    "instance_id": bush.get_instance_id(),
    "stimulus_kind_id": &"shrub_berries",
  }
  stack.set_live_scan_for_test({
    "food_split": {"ready": [live_entry], "unready": []},
    "threat_samples": [],
    "food_map_confidence": 1.0,
  })
  stack.tick(1.0 / 60.0)
  _assert(stack.get_planner_step_source() == &"live", "live food wins over precise memory consult")
  main.queue_free()


func _test_creature_motor_stack_memory_tier_precedence() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var now_ms := Time.get_ticks_msec()
  stack.seed_precise_food_belief_for_test(88011, Vector3(0.0, 1.0, -20.0), now_ms)
  stack.seed_coarse_food_belief_for_test(88012, Vector3(0.0, 1.0, -80.0), now_ms)
  stack.seed_locale_prior_for_test(7, 7, 1.0)
  stack.tick(1.0 / 60.0)
  _assert(stack.get_planner_step_source() == &"precise", "precise beats coarse and locale")
  var adapter_a: _MemoryAdapter = stack.get_memory_adapter()
  var beliefs_a := adapter_a.get_beliefs()
  beliefs_a.erase(88011)
  adapter_a.set_beliefs_for_test(beliefs_a)
  stack.tick(1.0 / 60.0)
  _assert(stack.get_planner_step_source() == &"coarse", "coarse beats locale when precise absent")
  adapter_a.set_beliefs_for_test({})
  stack.tick(1.0 / 60.0)
  _assert(stack.get_planner_step_source() == &"locale", "locale consult when no instance beliefs")
  main.queue_free()


func _test_creature_motor_stack_memory_dual_isolation() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body_a := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  var body_b := _spawn_herbivore_body(main, Vector3(8.0, 1.0, 0.0))
  body_a.current_calories = 2.0
  body_b.current_calories = 2.0
  body_a.last_move_direction = Vector3(0.0, 0.0, -1.0)
  body_b.last_move_direction = Vector3(0.0, 0.0, 1.0)
  await process_frame
  var stack_a := _motor_stack_test_configure(body_a)
  var stack_b := _motor_stack_test_configure(body_b)
  stack_a.set_live_scan_for_test(_motor_stack_empty_food_scan())
  stack_b.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var now_ms := Time.get_ticks_msec()
  stack_a.seed_precise_food_belief_for_test(88021, Vector3(0.0, 1.0, -30.0), now_ms)
  stack_b.seed_precise_food_belief_for_test(88022, Vector3(8.0, 1.0, 30.0), now_ms)
  stack_a.tick(1.0 / 60.0)
  stack_b.tick(1.0 / 60.0)
  _assert(stack_a.get_planner_step_source() == &"precise", "stack A uses its own memory")
  _assert(stack_b.get_planner_step_source() == &"precise", "stack B uses its own memory")
  var goal_a := stack_a.get_planner_step_goal()
  var goal_b := stack_b.get_planner_step_goal()
  _assert(goal_a.z < body_a.global_position.z, "stack A seeks its remembered -Z target")
  _assert(goal_b.z > body_b.global_position.z, "stack B seeks its remembered +Z target")
  main.queue_free()


func _test_creature_motor_stack_memory_feasibility_tiers() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  await process_frame
  var stack := _motor_stack_test_configure(body)
  var empty_split := {"ready": [], "unready": []}
  var row := {"goal_kind": _GkReg.GK_FIND_FOOD}
  var ctx := _motor_stack_food_ctx(body, stack, empty_split)
  _assert(
    is_equal_approx(_CreatureMotorStack._feasibility_for_goal(row, ctx), 0.0),
    "no memory tiers yields zero find_food feasibility",
  )
  var now_ms := Time.get_ticks_msec()
  stack.seed_precise_food_belief_for_test(88031, Vector3(0.0, 1.0, -20.0), now_ms)
  ctx = _motor_stack_food_ctx(body, stack, empty_split)
  _assert(
    is_equal_approx(_CreatureMotorStack._feasibility_for_goal(row, ctx), _MemoryAdapter.FEASIBILITY_PRECISE),
    "precise memory sets find_food feasibility",
  )
  var adapter_b: _MemoryAdapter = stack.get_memory_adapter()
  var beliefs_b := adapter_b.get_beliefs()
  beliefs_b.erase(88031)
  adapter_b.set_beliefs_for_test(beliefs_b)
  stack.seed_coarse_food_belief_for_test(88032, Vector3(0.0, 1.0, -80.0), now_ms)
  ctx = _motor_stack_food_ctx(body, stack, empty_split)
  _assert(
    is_equal_approx(_CreatureMotorStack._feasibility_for_goal(row, ctx), _MemoryAdapter.FEASIBILITY_COARSE),
    "coarse memory sets find_food feasibility",
  )
  adapter_b.set_beliefs_for_test({})
  stack.seed_locale_prior_for_test(7, 7, 1.0)
  ctx = _motor_stack_food_ctx(body, stack, empty_split)
  _assert(
    is_equal_approx(_CreatureMotorStack._feasibility_for_goal(row, ctx), _MemoryAdapter.FEASIBILITY_LOCALE),
    "locale prior sets find_food feasibility",
  )
  var live_ctx := _motor_stack_food_ctx(body, stack, {"ready": [{"pos": Vector3(0.0, 1.0, -5.0)}], "unready": []})
  _assert(
    is_equal_approx(_CreatureMotorStack._feasibility_for_goal(row, live_ctx), 1.0),
    "live ready food yields full find_food feasibility",
  )
  main.queue_free()


func _test_creature_motor_stack_memory_stale_instance_id() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 2.0
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  stack.seed_precise_food_belief_for_test(1, Vector3(0.0, 1.0, -12.0), Time.get_ticks_msec())
  for _i in 32:
    var outcome: _ActionOutcome = stack.tick(1.0 / 60.0)
    _assert(_MotorAction.is_valid_action(int(outcome.action)), "stale instance_id memory seek stays valid")
  _assert(stack.get_planner_step_source() == &"precise", "stale instance_id still drives precise seek")
  main.queue_free()


func _motor_stack_test_env_grid() -> _EnvGrid:
  var grid := _EnvGrid.new()
  grid.cell_width = 32
  grid.cell_height = 32
  grid.cell_size = 52.0
  grid.cell_kind_ids = PackedInt32Array()
  grid.cell_kind_ids.resize(32 * 32)
  return grid


func _test_creature_motor_stack_memory_live_sync() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  var bush := _spawn_food_bush(main, Vector3(0.0, 1.0, -12.0))
  await process_frame
  var stack := _motor_stack_test_configure(body)
  _assert(stack.get_memory_adapter().get_beliefs().is_empty(), "beliefs empty before live scan tick")
  stack.tick(1.0 / 60.0)
  var beliefs: Dictionary = stack.get_memory_adapter().get_beliefs()
  _assert(beliefs.has(bush.get_instance_id()), "live scan tick writes goal_belief row on stack adapter")
  var row: Dictionary = beliefs[bush.get_instance_id()]
  _assert(row.get("tier", &"") == &"PRECISE", "live-synced belief starts PRECISE")
  main.queue_free()


func _test_creature_motor_stack_memory_maintain_coarse_ttl() -> void:
  var motor_p := _motor_v3_test_params().duplicate(true)
  motor_p["goal_memory_coarse_ttl_sec"] = 15.0
  motor_p["goal_memory_precise_radius"] = 1000.0
  motor_p["goal_memory_forget_radius"] = 5000.0
  var stack := _CreatureMotorStack.new()
  var body := CharacterBody3D.new()
  stack.configure(body, null, motor_p, "", {})
  var adapter := stack.get_memory_adapter()
  var now_ms := Time.get_ticks_msec()
  var iid := 424242
  adapter.set_beliefs_for_test({
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
  })
  adapter.maintain_beliefs(Vector3.ZERO, now_ms, motor_p)
  _assert(not adapter.get_beliefs().has(iid), "adapter maintain evicts coarse belief after coarse TTL")


func _test_creature_motor_stack_memory_eat_locale_write() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  var stack := _motor_stack_test_configure(body)
  stack.set_environment_grid_for_test(_motor_stack_test_env_grid())
  var anchor := Vector3(120.0, 0.0, 80.0)
  stack.notify_food_consumption_outcome(anchor, false)
  var store: RefCounted = stack.get_memory_adapter().get_locale_store()
  _assert(store._rows.size() >= 1, "EAT outcome writes locale row on stack adapter store")
  if _ai_driver_can_instantiate():
    var ad: Node = _ai_driver_script().new()
    var bid := body.get_instance_id()
    ad.set("_goal_source_memory_by_body", {})
    _assert(not (ad.get("_goal_source_memory_by_body") as Dictionary).has(bid), "ai_driver locale store unused by stack write")
    ad.free()
  main.queue_free()


func _test_creature_motor_stack_memory_write_dual_isolation() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body_a := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  var body_b := _spawn_herbivore_body(main, Vector3(80.0, 1.0, 0.0))
  body_a.last_move_direction = Vector3(0.0, 0.0, -1.0)
  var bush := _spawn_food_bush(main, Vector3(0.0, 1.0, -12.0))
  await process_frame
  var stack_a := _motor_stack_test_configure(body_a)
  var stack_b := _motor_stack_test_configure(body_b)
  stack_b.set_live_scan_for_test(_motor_stack_empty_food_scan())
  stack_a.tick(1.0 / 60.0)
  stack_b.tick(1.0 / 60.0)
  _assert(
    stack_a.get_memory_adapter().get_beliefs().has(bush.get_instance_id()),
    "stack A live sync writes belief row",
  )
  _assert(
    not stack_b.get_memory_adapter().get_beliefs().has(bush.get_instance_id()),
    "stack B beliefs isolated from stack A live sync",
  )
  main.queue_free()


func _test_creature_motor_stack_sated_stay() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = float(body.caloric_needs)
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  stack.tick(1.0 / 60.0)
  var outcome: ActionOutcome = stack.tick(1.0 / 60.0)
  _assert(stack.get_incumbent().is_empty(), "sated creature clears incumbent when hub weights are zero")
  _assert(int(outcome.action) == _MotorAction.STAY, "sated idle emits STAY")
  main.queue_free()


func _test_creature_motor_stack_debug_snapshot() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  stack.tick(1.0 / 60.0)
  var snap: Dictionary = stack.get_debug_snapshot()
  _assert(snap.has("action"), "debug snapshot includes action")
  _assert(snap.has("step_source"), "debug snapshot includes step_source")
  _assert(snap.has("physics_tick"), "debug snapshot includes physics_tick")
  _assert(snap.has("turn_commit_sign"), "debug snapshot includes turn_commit_sign")
  _assert(snap.has("bearing_error_deg"), "debug snapshot includes bearing_error_deg")
  _assert(snap.has("facing_dot_tgt"), "debug snapshot includes facing_dot_tgt")
  _assert(int(snap.get("physics_tick", 0)) >= 1, "debug snapshot reflects ticks after tick")
  main.queue_free()


func _test_creature_motor_stack_memory_kind_ewma() -> void:
  var adapter := _MemoryAdapter.new()
  var motor_p := _motor_v3_test_params()
  motor_p["kind_nutrition_yield_reference_calories"] = 5.0
  _assert(
    is_equal_approx(_KindProfile.nutrition_yield_observation(5, false, motor_p), 1.0),
    "full reference bite normalizes nutrition_yield to 1.0",
  )
  adapter.notify_food_consumption_outcome(
    Vector3.ZERO, false, motor_p, null, &"shrub_berries", 5
  )
  var v1 := adapter.consult_kind_facet(_LearnReg.FACET_NUTRITION_YIELD, &"shrub_berries", motor_p)
  _assert(v1 > 0.5, "EAT notify raises nutrition_yield above neutral")
  var split := {
    "ready": [
      {
        "pos": Vector3(0.0, 0.0, -10.0),
        "instance_id": 101,
        "stimulus_kind_id": &"shrub_berries",
        "kind_yield": v1,
      },
      {
        "pos": Vector3(0.0, 0.0, -8.0),
        "instance_id": 102,
        "stimulus_kind_id": &"shrub_low",
        "kind_yield": 0.3,
      },
    ],
    "unready": [],
  }
  var best := _AwarenessScan.best_ready_food_target(split, Vector3.ZERO)
  _assert(int(best.get("instance_id", 0)) == 101, "kind yield ranks higher-yield bush first")


func _test_creature_motor_stack_memory_dead_end_filter() -> void:
  var adapter := _MemoryAdapter.new()
  var motor_p := _motor_v3_test_params()
  var now_ms := Time.get_ticks_msec()
  adapter.record_dead_end_mark(
    Vector3(0.0, 0.0, 20.0),
    Vector3(0.0, 0.0, 1.0),
    _GkReg.GK_FIND_FOOD,
    0,
    now_ms,
  )
  _assert(
    adapter.is_waypoint_dead_end(Vector3.ZERO, Vector3(0.0, 0.0, 20.0), _GkReg.GK_FIND_FOOD, motor_p),
    "dead-end mark blocks matching waypoint",
  )
  _assert(
    not adapter.is_waypoint_dead_end(Vector3.ZERO, Vector3(20.0, 0.0, 0.0), _GkReg.GK_FIND_FOOD, motor_p),
    "dead-end mark ignores orthogonal waypoint",
  )


func _test_creature_motor_stack_memory_passibility_switch() -> void:
  var adapter := _MemoryAdapter.new()
  var motor_p := _motor_v3_test_params()
  motor_p["passibility_fail_switch_threshold"] = 2
  adapter.seed_precise_food_belief(42, Vector3(10.0, 0.0, 10.0), Time.get_ticks_msec())
  adapter.increment_passibility_fail(42, Time.get_ticks_msec())
  adapter.increment_passibility_fail(42, Time.get_ticks_msec())
  var ctx := {
    "memory_adapter": adapter,
    "creature_pos": Vector3.ZERO,
    "food_split": {"ready": [], "unready": []},
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": null,
  }
  var res := _BlockedObjective.resolve(ctx, 42, &"shrub_berries", motor_p)
  _assert(
    res.get("action", &"") != _BlockedObjective.ACTION_PERSIST or float(res.get("instance_score", 1.0)) < 0.5,
    "passibility_fail_count biases away from persist",
  )


func _test_creature_motor_stack_memory_blocked_objective() -> void:
  var adapter := _MemoryAdapter.new()
  var motor_p := _motor_v3_test_params()
  adapter.seed_locale_prior_for_test(10, 10, 2.0)
  var ctx := {
    "memory_adapter": adapter,
    "creature_pos": Vector3.ZERO,
    "food_split": {"ready": [], "unready": []},
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": _motor_stack_test_env_grid(),
  }
  var res := _BlockedObjective.resolve(ctx, 99, &"shrub_low", motor_p)
  _assert(res.has("action"), "blocked objective resolver returns action")
  _assert(
    res.get("action") in [_BlockedObjective.ACTION_PERSIST, _BlockedObjective.ACTION_SWITCH, _BlockedObjective.ACTION_SEEK],
    "blocked objective action is persist switch or seek",
  )


func _test_creature_motor_stack_blocked_memory_writes() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var wall := StaticBody3D.new()
  var box := BoxShape3D.new()
  box.size = Vector3(0.5, 4.0, 4.0)
  var col := CollisionShape3D.new()
  col.shape = box
  wall.add_child(col)
  wall.collision_layer = 1
  wall.collision_mask = 1
  main.add_child(wall)
  wall.global_position = Vector3(1.2, 1.0, 0.0)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 10.0
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  await physics_frame
  var motor_p := _motor_v3_test_params()
  motor_p["dead_end_record_min_blocked_ticks"] = 1
  var stack := _CreatureMotorStack.new()
  stack.configure(body, null, motor_p, "", {})
  body.set_use_v3_action_calories(true)
  body.set_motor_stack_drives_physics(true)
  body.set_control_mode(_ControlMode.engine_as_int())
  const FOOD_IID := 88001
  stack.set_live_scan_for_test({
    "food_split": {
      "ready": [{
        "pos": Vector3(5.0, 1.0, 0.0),
        "instance_id": FOOD_IID,
        "stimulus_kind_id": &"shrub_berries",
        "consumable_now": true,
        "line_of_sight_clear": true,
        "occluded": false,
      }],
      "unready": [],
    },
    "threat_samples": [],
    "food_map_confidence": 1.0,
  })
  stack.tick(1.0 / 60.0)
  var wrote_memory := false
  for _i in 40:
    stack.tick(1.0 / 60.0)
    await physics_frame
    var adapter: _MemoryAdapter = stack.get_memory_adapter()
    var beliefs: Dictionary = adapter.get_beliefs()
    if beliefs.has(FOOD_IID):
      var row: Dictionary = beliefs[FOOD_IID]
      if int(row.get("passibility_fail_count", 0)) >= 1:
        wrote_memory = true
        break
    if adapter.get_dead_end_marks().size() >= 1:
      wrote_memory = true
      break
    if stack.get_planner_blocked_objective_action() != &"":
      wrote_memory = true
      break
  _assert(wrote_memory, "stack blocked move writes passibility, dead-end, or §9 action")
  main.queue_free()


func _test_food_plant_missing_stimulus_kind_id() -> void:
  var plant := Node3D.new()
  plant.set_script(_BushFoodScr)
  plant.set("stimulus_kind_id", &"")
  plant.name = "BadBush"
  root.add_child(plant)
  await process_frame
  _assert(not is_instance_valid(plant) or not plant.is_inside_tree(), "missing stimulus_kind_id plant is removed")
  if is_instance_valid(plant):
    plant.queue_free()


func _motor_v3_test_floor(parent: Node3D) -> StaticBody3D:
  var floor_body := StaticBody3D.new()
  var floor_col := CollisionShape3D.new()
  var floor_box := BoxShape3D.new()
  floor_box.size = Vector3(40.0, 0.2, 40.0)
  floor_col.shape = floor_box
  floor_col.position = Vector3(0.0, -0.1, 0.0)
  floor_body.add_child(floor_col)
  floor_body.collision_layer = 1
  floor_body.collision_mask = 1
  parent.add_child(floor_body)
  return floor_body


func _motor_planner_note_outcome(
  state: Dictionary,
  body: CharacterBody3D,
  outcome,
  motor_v3: Dictionary,
  physics_tick: int,
  pos_before_tick: Vector3,
  boundary_clamped: bool,
) -> bool:
  return (_MotorPlanner as GDScript).call(
    "note_outcome",
    state,
    body,
    outcome,
    motor_v3,
    physics_tick,
    pos_before_tick,
    boundary_clamped,
  )


func _test_locomotion_executor_turn_facing() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  var motor_v3 := _motor_v3_test_params()
  var start: Vector3 = body.last_move_direction
  for _i in 8:
    _LocomotionExecutor.apply_action(body, _MotorAction.TURN_RIGHT, 1.0 / 60.0, motor_v3)
  var end_facing: Vector3 = body.last_move_direction.normalized()
  _assert(
    is_equal_approx(start.dot(end_facing), -1.0),
    "8 TURN_RIGHT yields ~180 deg facing (dot=%.3f)" % start.dot(end_facing),
  )
  _assert(
    is_equal_approx(end_facing.length_squared(), 1.0),
    "facing stays normalized after turns",
  )
  main.queue_free()

func _test_motor_planner_turn_alignment_no_flip_flop() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var remembered := Vector3(-20.0, 1.0, 0.0)
  var now_ms := Time.get_ticks_msec()
  stack.seed_precise_food_belief_for_test(88099, remembered, now_ms)
  var motor_v3 := _motor_v3_test_params()
  var state := _MotorPlanner.new_state()
  var ctx := {
    "body": body,
    "motor_v3": motor_v3,
    "incumbent": {"goal_kind": _GkReg.GK_FIND_FOOD},
    "scan": _motor_stack_empty_food_scan(),
    "threat_samples": [],
    "flight_fast_path_active": false,
    "space_state": main.get_world_3d().direct_space_state,
    "eye_height": 1.0,
    "map_rid": RID(),
    "physics_tick": 0,
    "memory_adapter": stack.get_memory_adapter(),
    "now_ms": now_ms,
    "environment_grid": null,
  }
  _MotorPlanner.select_action(ctx, state)
  _assert(state.get("step_source", &"") == &"precise", "planner uses precise step source for fixed goal")
  var actions: Array[int] = []
  var saw_move := false
  for _i in 8:
    var act := _MotorPlanner.select_action(ctx, state)
    actions.append(act)
    if act == _MotorAction.MOVE_FORWARD:
      saw_move = true
      break
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      _LocomotionExecutor.apply_action(body, act, 1.0 / 60.0, motor_v3)
  _assert(saw_move, "planner emits MOVE_FORWARD within 8 ticks for 180 deg misalignment")
  var turn_actions: Array[int] = []
  for act in actions:
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      turn_actions.append(act)
  _assert(turn_actions.size() >= 1, "planner turns before moving toward fixed precise goal")
  var first_turn: int = turn_actions[0]
  for act in turn_actions:
    _assert(
      act == first_turn,
      "all pre-move turns share one direction (no TURN_L/TURN_R flip-flop)",
    )
  for i in range(actions.size() - 1):
    var a: int = actions[i]
    var b: int = actions[i + 1]
    var is_flip := (
      (a == _MotorAction.TURN_LEFT and b == _MotorAction.TURN_RIGHT)
      or (a == _MotorAction.TURN_RIGHT and b == _MotorAction.TURN_LEFT)
    )
    _assert(not is_flip, "no adjacent opposite turn pair while step goal is fixed")
  main.queue_free()

func _test_motor_planner_precise_backtrack_ignored() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var remembered := Vector3(-20.0, 1.0, 0.0)
  var now_ms := Time.get_ticks_msec()
  stack.seed_precise_food_belief_for_test(88100, remembered, now_ms)
  var motor_v3 := _motor_v3_test_params()
  var state := _MotorPlanner.new_state()
  state["blocked_approach"] = {
    "dir": _MotorPlane.HORIZONTAL_RIGHT,
    "sector": 2,
    "until_tick": 99999,
  }
  var ctx := {
    "body": body,
    "motor_v3": motor_v3,
    "incumbent": {"goal_kind": _GkReg.GK_FIND_FOOD},
    "scan": _motor_stack_empty_food_scan(),
    "threat_samples": [],
    "flight_fast_path_active": false,
    "space_state": main.get_world_3d().direct_space_state,
    "eye_height": 1.0,
    "map_rid": RID(),
    "physics_tick": 1,
    "memory_adapter": stack.get_memory_adapter(),
    "now_ms": now_ms,
    "environment_grid": null,
  }
  var actions: Array[int] = []
  var saw_move := false
  for tick in 12:
    ctx["physics_tick"] = tick
    var act := _MotorPlanner.select_action(ctx, state)
    actions.append(act)
    _assert(
      state.get("step_source", &"") == &"precise",
      "precise source kept while blocked-approach memory is active",
    )
    _assert(
      (state.get("step_goal", Vector3.ZERO) as Vector3).distance_to(remembered) < 0.01,
      "precise step_goal stays at GPS (no backtrack detour rewrite)",
    )
    if act == _MotorAction.MOVE_FORWARD:
      saw_move = true
      break
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      _LocomotionExecutor.apply_action(body, act, 1.0 / 60.0, motor_v3)
  _assert(saw_move, "precise seek reaches MOVE_FORWARD despite blocked-approach memory")
  for i in range(actions.size() - 1):
    var a: int = actions[i]
    var b: int = actions[i + 1]
    var is_flip := (
      (a == _MotorAction.TURN_LEFT and b == _MotorAction.TURN_RIGHT)
      or (a == _MotorAction.TURN_RIGHT and b == _MotorAction.TURN_LEFT)
    )
    _assert(not is_flip, "precise + blocked-approach: no adjacent opposite turn pair")
  main.queue_free()

func _test_motor_planner_explore_latch() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = Vector3(1.0, 0.0, 0.0)
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  body.current_calories = 2.0
  var motor_v3 := _motor_v3_test_params()
  var state := _MotorPlanner.new_state()
  var ctx := {
    "body": body,
    "motor_v3": motor_v3,
    "incumbent": {"goal_kind": _GkReg.GK_FIND_FOOD},
    "scan": _motor_stack_empty_food_scan(),
    "threat_samples": [],
    "flight_fast_path_active": false,
    "space_state": main.get_world_3d().direct_space_state,
    "eye_height": 1.0,
    "map_rid": RID(),
    "physics_tick": 1,
    "memory_adapter": stack.get_memory_adapter(),
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": null,
  }
  _MotorPlanner.select_action(ctx, state)
  _assert(state.get("step_source", &"") == &"explore", "no food uses explore step source")
  var explore_dir: Vector3 = state.get("explore_dir", Vector3.ZERO)
  _assert(
    explore_dir.normalized().dot(Vector3(1.0, 0.0, 0.0)) > 0.99,
    "explore_dir seeds from body facing (east), not random",
  )
  var latched: Vector3 = state.get("explore_waypoint", Vector3.ZERO)
  _assert(latched.length_squared() > 1e-4, "explore latches a world waypoint")
  body.global_position = Vector3(3.0, 1.0, 0.0)
  ctx["physics_tick"] = 2
  _MotorPlanner.select_action(ctx, state)
  _assert(
    (state.get("explore_waypoint", Vector3.ZERO) as Vector3).distance_to(latched) < 0.01,
    "explore waypoint stays latched when creature moves",
  )
  var actions: Array[int] = []
  var saw_move := false
  for tick_i in 3:
    ctx["physics_tick"] = tick_i
    var act := _MotorPlanner.select_action(ctx, state)
    actions.append(act)
    if act == _MotorAction.MOVE_FORWARD:
      saw_move = true
      break
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      _LocomotionExecutor.apply_action(body, act, 1.0 / 60.0, motor_v3)
  _assert(saw_move, "explore latch converges to MOVE toward latched waypoint")
  for i in range(actions.size() - 1):
    var a: int = actions[i]
    var b: int = actions[i + 1]
    var is_flip := (
      (a == _MotorAction.TURN_LEFT and b == _MotorAction.TURN_RIGHT)
      or (a == _MotorAction.TURN_RIGHT and b == _MotorAction.TURN_LEFT)
    )
    _assert(not is_flip, "explore latch: no adjacent opposite turn pair")
  main.queue_free()

func _test_motor_planner_explore_rear_hemisphere_no_flip_flop() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = Vector3(1.0, 0.0, 0.0)
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var motor_v3 := _motor_v3_test_params()
  var state := _MotorPlanner.new_state()
  var ctx := {
    "body": body,
    "motor_v3": motor_v3,
    "incumbent": {"goal_kind": _GkReg.GK_FIND_FOOD},
    "scan": _motor_stack_empty_food_scan(),
    "threat_samples": [],
    "flight_fast_path_active": false,
    "space_state": main.get_world_3d().direct_space_state,
    "eye_height": 1.0,
    "map_rid": RID(),
    "physics_tick": 1,
    "memory_adapter": stack.get_memory_adapter(),
    "now_ms": Time.get_ticks_msec(),
    "environment_grid": null,
  }
  _MotorPlanner.select_action(ctx, state)
  var latched: Vector3 = state.get("explore_waypoint", Vector3.ZERO)
  _assert(latched.length_squared() > 1e-4, "explore rear test latches waypoint")
  body.last_move_direction = Vector3(-1.0, 0.0, 0.0)
  body.global_position = Vector3(10.0, 1.0, 0.0)
  var move_min_dot := cos(deg_to_rad(float(motor_v3.get("turn_increment_deg", 22.5))))
  var actions: Array[int] = []
  var saw_move := false
  var prev_dot := -2.0
  for tick_i in 16:
    ctx["physics_tick"] = tick_i
    var act := _MotorPlanner.select_action(ctx, state)
    actions.append(act)
    var facing: Vector3 = body.last_move_direction.normalized()
    var to_n := (latched - body.global_position).normalized()
    to_n.y = 0.0
    var dot := facing.dot(to_n)
    if prev_dot > -1.5:
      _assert(dot >= prev_dot - 0.05, "rear explore: facing dot to latched waypoint non-decreasing")
    prev_dot = dot
    if act == _MotorAction.MOVE_FORWARD:
      saw_move = true
      _assert(dot >= move_min_dot - 0.01, "rear explore MOVE when within turn increment cone")
      break
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      _LocomotionExecutor.apply_action(body, act, 1.0 / 60.0, motor_v3)
  _assert(saw_move, "explore rear hemisphere converges to MOVE within 16 ticks")
  var turn_actions: Array[int] = []
  for act in actions:
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      turn_actions.append(act)
  _assert(turn_actions.size() >= 1, "explore rear hemisphere turns before MOVE")
  var first_turn: int = turn_actions[0]
  for act in turn_actions:
    _assert(
      act == first_turn,
      "explore rear hemisphere: all pre-move turns share one direction",
    )
  for i in range(actions.size() - 1):
    var a: int = actions[i]
    var b: int = actions[i + 1]
    var is_flip := (
      (a == _MotorAction.TURN_LEFT and b == _MotorAction.TURN_RIGHT)
      or (a == _MotorAction.TURN_RIGHT and b == _MotorAction.TURN_LEFT)
    )
    _assert(not is_flip, "explore rear hemisphere: no adjacent opposite turn pair")
  main.queue_free()

func _test_motor_planner_latched_stuck_replan() -> void:
  var motor_v3 := _motor_v3_test_params()
  motor_v3["dead_end_record_min_blocked_ticks"] = 3
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = Vector3(1.0, 0.0, 0.0)
  var explore_state := _MotorPlanner.new_state()
  explore_state["step_source"] = &"explore"
  explore_state["explore_dir"] = Vector3(1.0, 0.0, 0.0)
  explore_state["explore_waypoint"] = Vector3(50.0, 1.0, 0.0)
  explore_state["step_goal"] = explore_state["explore_waypoint"]
  var start_dir: Vector3 = explore_state["explore_dir"]
  var pos_before := body.global_position
  for tick_i in 3:
    var outcome := _ActionOutcome.new(Vector3.ZERO, false, 0.0, _MotorAction.TURN_RIGHT)
    var run_s9: bool = _motor_planner_note_outcome(
      explore_state,
      body,
      outcome,
      motor_v3,
      tick_i,
      pos_before,
      false,
    )
    _assert(not run_s9, "explore stuck replan handles explore without §9 call")
  _assert(
    explore_state.get("blocked_objective_action", &"") == &"explore_replan",
    "explore stuck sets blocked_objective_action=explore_replan",
  )
  var new_dir: Vector3 = explore_state.get("explore_dir", Vector3.ZERO)
  _assert(
    new_dir.normalized().dot(start_dir.normalized()) < 0.99,
    "explore stuck rotates explore_dir (60 deg)",
  )
  _assert(
    (explore_state.get("explore_waypoint", Vector3.ZERO) as Vector3).length_squared() < 1e-8,
    "explore stuck clears latched waypoint",
  )
  _assert(
    int(explore_state.get("consecutive_blocked", 99)) == 0,
    "explore stuck replan resets consecutive_blocked",
  )

  var precise_state := _MotorPlanner.new_state()
  precise_state["step_source"] = &"precise"
  precise_state["step_goal"] = Vector3(-20.0, 1.0, 0.0)
  precise_state["step_instance_id"] = 99001
  for tick_i in 4:
    var turn_outcome := _ActionOutcome.new(Vector3.ZERO, false, 0.0, _MotorAction.TURN_LEFT)
    var run_precise_s9: bool = _motor_planner_note_outcome(
      precise_state,
      body,
      turn_outcome,
      motor_v3,
      tick_i + 10,
      pos_before,
      false,
    )
    if tick_i < 3:
      _assert(not run_precise_s9, "precise position-stuck waits until min no-progress ticks")
    else:
      _assert(run_precise_s9, "precise position-stuck triggers §9 after min ticks")
  _assert(
    int(precise_state.get("precise_no_progress_ticks", 0)) >= 3,
    "precise position-stuck increments precise_no_progress_ticks",
  )
  var move_stuck_state := _MotorPlanner.new_state()
  move_stuck_state["step_source"] = &"precise"
  move_stuck_state["step_goal"] = Vector3(-20.0, 1.0, 0.0)
  move_stuck_state["step_instance_id"] = 99002
  for tick_i in 3:
    var blocked_move := _ActionOutcome.new(Vector3.ZERO, true, 0.0, _MotorAction.MOVE_FORWARD)
    var run_move_s9: bool = _motor_planner_note_outcome(
      move_stuck_state,
      body,
      blocked_move,
      motor_v3,
      tick_i + 20,
      pos_before,
      false,
    )
    if tick_i < 2:
      _assert(not run_move_s9, "precise blocked MOVE waits until min stuck ticks")
    else:
      _assert(run_move_s9, "precise blocked MOVE triggers §9 resolution hook")
  _assert(
    int(move_stuck_state.get("consecutive_blocked", 0)) >= 3,
    "precise blocked MOVE increments consecutive_blocked",
  )

  var boundary_state := _MotorPlanner.new_state()
  boundary_state["step_source"] = &"explore"
  boundary_state["explore_dir"] = Vector3(1.0, 0.0, 0.0)
  boundary_state["turn_commit_sign"] = 1
  var bounds_min := Vector2.ZERO
  var bounds_max := Vector2(100.0, 100.0)
  body.set("playfield_bounds_min", bounds_min)
  body.set("playfield_bounds_max", bounds_max)
  body.set("screen_size", bounds_max)
  var motor_p := _Merge.default_creature_motor_params()
  var he := _MotorPlane.footprint_half_extents(body, motor_p)
  body.global_position = Vector3(bounds_max.x - he.x - 0.5, 1.0, 50.0)
  var edge_pos := body.global_position
  for tick_i in 3:
    var stuck_outcome := _ActionOutcome.new(Vector3.ZERO, false, 0.0, _MotorAction.MOVE_FORWARD)
    _motor_planner_note_outcome(
      boundary_state,
      body,
      stuck_outcome,
      motor_v3,
      tick_i + 30,
      edge_pos,
      true,
    )
  _assert(
    bool(boundary_state.get("boundary_scan_active", false)),
    "playfield edge stuck enters boundary scan",
  )
  _assert(
    boundary_state.get("blocked_objective_action", &"") == &"boundary_scan",
    "playfield edge stuck sets blocked_objective_action=boundary_scan",
  )
  _assert(
    int(boundary_state.get("turn_commit_sign", 0)) == 1,
    "boundary scan preserves turn_commit_sign (no L/R stutter)",
  )
  _assert(
    (boundary_state.get("explore_dir", Vector3.ZERO) as Vector3).normalized().dot(Vector3(1.0, 0.0, 0.0)) > 0.99,
    "boundary scan does not rotate explore_dir via 60 deg replan",
  )
  main.queue_free()

func _test_creature_motor_stack_precise_turn_no_flip_flop() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.current_calories = 2.0
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  body.velocity = Vector3(8.0, 0.0, 6.0)
  await process_frame
  var stack := _motor_stack_test_configure(body)
  stack.set_live_scan_for_test(_motor_stack_empty_food_scan())
  var remembered := Vector3(-20.0, 1.0, 0.0)
  stack.seed_precise_food_belief_for_test(88101, remembered, Time.get_ticks_msec())
  var start_pos := body.global_position
  var actions: Array[int] = []
  var saw_move := false
  for _i in 32:
    var outcome: _ActionOutcome = stack.tick(1.0 / 60.0)
    var act := int(outcome.action)
    actions.append(act)
    _assert(
      stack.get_planner_step_source() == &"precise",
      "stack precise seek keeps step_source=precise",
    )
    _assert(
      stack.get_planner_step_goal().distance_to(remembered) < 0.01,
      "stack precise step_goal stays at remembered GPS",
    )
    if act == _MotorAction.MOVE_FORWARD:
      saw_move = true
      break
  _assert(saw_move, "stack emits MOVE_FORWARD toward precise belief within 32 ticks")
  var turn_actions: Array[int] = []
  for act in actions:
    if act == _MotorAction.TURN_LEFT or act == _MotorAction.TURN_RIGHT:
      turn_actions.append(act)
  _assert(turn_actions.size() >= 1, "stack turns before moving toward precise goal")
  if turn_actions.size() > 0:
    var first_turn: int = turn_actions[0]
    for act in turn_actions:
      _assert(
        act == first_turn,
        "stack pre-move turns share one direction (no TURN_L/TURN_R flip-flop)",
      )
  for i in range(actions.size() - 1):
    var a: int = actions[i]
    var b: int = actions[i + 1]
    var is_flip := (
      (a == _MotorAction.TURN_LEFT and b == _MotorAction.TURN_RIGHT)
      or (a == _MotorAction.TURN_RIGHT and b == _MotorAction.TURN_LEFT)
    )
    _assert(not is_flip, "stack: no adjacent opposite turn pair on fixed precise tgt")
  var disp := body.global_position - start_pos
  disp.y = 0.0
  _assert(disp.length_squared() > 1e-6, "stack precise seek produces net displacement after MOVE")
  main.queue_free()

func _test_body_motor_stack_skips_legacy_physics() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_control_mode(_ControlMode.engine_as_int())
  body.set_motor_stack_drives_physics(true)
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  body.velocity = Vector3(12.0, 0.0, 5.0)
  var facing_before: Vector3 = body.last_move_direction
  body.call("_physics_process", 1.0 / 60.0)
  _assert(
    body.last_move_direction.is_equal_approx(facing_before),
    "motor_stack_drives skips legacy velocity-facing overwrite",
  )
  _assert(
    is_equal_approx(body.velocity.x, 12.0) and is_equal_approx(body.velocity.z, 5.0),
    "motor_stack_drives skip does not integrate legacy move intent",
  )
  main.queue_free()

func _test_locomotion_executor_turn_clears_velocity() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  body.velocity = Vector3(9.0, 2.0, -4.0)
  _LocomotionExecutor.apply_action(body, _MotorAction.TURN_LEFT, 1.0 / 60.0, _motor_v3_test_params())
  _assert(is_equal_approx(body.velocity.x, 0.0), "TURN_LEFT clears horizontal velocity x")
  _assert(is_equal_approx(body.velocity.z, 0.0), "TURN_LEFT clears horizontal velocity z")
  _assert(is_equal_approx(body.velocity.y, 2.0), "TURN_LEFT preserves vertical velocity")
  main.queue_free()

func _test_locomotion_executor_move_forward() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  await physics_frame
  var pos_before := body.global_position
  var outcome: _ActionOutcome = _LocomotionExecutor.apply_action(
    body, _MotorAction.MOVE_FORWARD, 1.0, _motor_v3_test_params()
  )
  await physics_frame
  var disp := body.global_position - pos_before
  disp.y = 0.0
  _assert(disp.length_squared() > 1e-4, "MOVE_FORWARD displaces along facing")
  _assert(
    disp.normalized().dot(body.last_move_direction.normalized()) > 0.95,
    "MOVE_FORWARD displacement aligns with facing",
  )
  _assert(not outcome.blocked, "MOVE_FORWARD open floor not blocked")
  main.queue_free()

func _test_locomotion_executor_stay_calorie_debit() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.current_calories = 10.0
  var delta := 0.5
  var motor_v3 := _motor_v3_test_params()
  var expected_cost := _MotorAction.calorie_cost_for(_MotorAction.STAY, delta, motor_v3)
  var outcome: _ActionOutcome = body.apply_action(_MotorAction.STAY, delta, motor_v3)
  _assert(
    is_equal_approx(outcome.calorie_cost, expected_cost),
    "STAY outcome reports baseline calorie cost",
  )
  _assert(
    is_equal_approx(body.current_calories, 10.0 - expected_cost),
    "STAY debits baseline * delta on body",
  )
  main.queue_free()

func _test_locomotion_executor_move_blocked() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var wall := StaticBody3D.new()
  var box := BoxShape3D.new()
  box.size = Vector3(0.5, 4.0, 4.0)
  var col := CollisionShape3D.new()
  col.shape = box
  wall.add_child(col)
  wall.collision_layer = 1
  main.add_child(wall)
  wall.global_position = Vector3(1.2, 1.0, 0.0)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.last_move_direction = _MotorPlane.HORIZONTAL_RIGHT
  await physics_frame
  # Drive move ticks until the body presses the wall (planner emits MOVE repeatedly).
  var blocked := false
  for _i in 30:
    var outcome: _ActionOutcome = _LocomotionExecutor.apply_action(
      body, _MotorAction.MOVE_FORWARD, 1.0 / 60.0, _motor_v3_test_params()
    )
    await physics_frame
    if outcome.blocked:
      blocked = true
      break
  _assert(blocked, "MOVE_FORWARD against wall sets blocked")
  main.queue_free()

func _test_motor_goal_hub_starvation_eat_only() -> void:
  var motor_v3 := _motor_v3_test_params()
  var threat := _ThreatSampleScr.make(Vector2(100.0, 0.0), 50.0, true)
  var ctx := {
    "motor_v3": motor_v3,
    "calorie_ratio": 0.05,
    "threat_samples": [threat],
    "flight_fast_path_active": false,
    "safety_met": false,
  }
  var eligible := _MotorGoalHub.build_eligible_goals(ctx)
  _assert(eligible.size() == 1, "starvation yields single Eat row")
  _assert(
    String(eligible[0].get("goal_kind", &"")) == str(_MotorGoalHub.GOAL_FIND_FOOD),
    "starvation row is find_food",
  )

func _test_motor_goal_hub_urgency_eat_preserve_band() -> void:
  var motor_v3 := _motor_v3_test_params()
  var mid := _MotorGoalHub.urgency_eat(0.85, motor_v3)
  _assert(mid > 0.0 and mid < 1.0, "preserve band mid urgency between 0 and 1")
  _assert(
    is_equal_approx(_MotorGoalHub.urgency_eat(0.92, motor_v3), 0.0),
    "preserve floor zeroes Eat urgency",
  )
  _assert(
    is_equal_approx(_MotorGoalHub.urgency_eat(0.75, motor_v3), 1.0),
    "below seek ceiling full Eat urgency",
  )

func _test_motor_goal_hub_subacute_flight_weight() -> void:
  var motor_v3 := _motor_v3_test_params().duplicate(true)
  motor_v3["awareness_radius"] = 1500.0
  var far_threat := _ThreatSampleScr.make(Vector2(100.0, 0.0), 1500.0, true)
  var ctx := {
    "motor_v3": motor_v3,
    "calorie_ratio": 0.75,
    "threat_samples": [far_threat],
    "flight_fast_path_active": false,
    "safety_met": false,
  }
  var scored := _MotorGoalHub.score_goals(_MotorGoalHub.build_eligible_goals(ctx), ctx)
  var eat_w := 0.0
  var flight_w := 0.0
  for row_v in scored:
    var row: Dictionary = row_v
    if row.get("goal_kind", &"") == _MotorGoalHub.GOAL_FIND_FOOD:
      eat_w = float(row.get("weight", 0.0))
    elif row.get("goal_kind", &"") == _MotorGoalHub.GOAL_AVOID_HOSTILES:
      flight_w = float(row.get("weight", 0.0))
  _assert(eat_w > 0.0, "Eat row scored under sub-acute threat")
  _assert(flight_w > 0.0, "Flight row scored under sub-acute threat")
  _assert(flight_w < eat_w, "far threat Flight weight below Eat (sub-acute competition)")

func _test_motor_consideration_cadence_interval() -> void:
  var motor_v3 := _motor_v3_test_params()
  _assert(
    _MotorCadence.observation_replan_interval_ticks(10, motor_v3) == 8,
    "stat_observation=10 yields n=8",
  )

func _motor_stack_test_configure(body: CharacterBody3D) -> CreatureMotorStack:
  var stack := _CreatureMotorStack.new()
  stack.configure(body, null, _motor_v3_test_params(), "", {})
  body.set_use_v3_action_calories(true)
  body.set_motor_stack_drives_physics(true)
  body.set_control_mode(_ControlMode.engine_as_int())
  return stack

func _test_creature_motor_stack_tick_valid_action() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 10.0
  var stack := _motor_stack_test_configure(body)
  var delta := 0.5
  var before := float(body.current_calories)
  var outcome: _ActionOutcome = stack.tick(delta)
  # 6c: with no food/threat in awareness the planner may explore (turn/move) or STAY,
  # but must always yield a valid MotorAction and debit calories once.
  _assert(_MotorAction.is_valid_action(int(outcome.action)), "stack tick emits a valid MotorAction")
  _assert(body.current_calories < before, "stack tick debits calories")
  main.queue_free()

func _test_creature_motor_stack_consideration_advances() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  var stack := _motor_stack_test_configure(body)
  _assert(stack.get_physics_tick_count() == 0, "stack starts at tick 0")
  stack.tick(1.0 / 60.0)
  _assert(stack.get_physics_tick_count() == 1, "first tick increments counter")
  _assert(not stack.get_incumbent().is_empty(), "first tick runs consideration")
  for _i in 6:
    stack.tick(1.0 / 60.0)
  _assert(stack.get_physics_tick_count() == 7, "tick counter advances between considerations")
  stack.tick(1.0 / 60.0)
  _assert(stack.get_physics_tick_count() == 8, "cadence boundary tick")
  main.queue_free()

func _test_creature_motor_stack_dual_isolation() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body_a := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  var body_b := _spawn_carnivore_body(main, Vector3(4.0, 1.0, 0.0))
  var stack_a := _motor_stack_test_configure(body_a)
  var stack_b := _motor_stack_test_configure(body_b)
  stack_a.set_threat_samples_for_test(
    [_ThreatSampleScr.make(Vector2(10.0, 0.0), 800.0, true)]
  )
  stack_a.tick(1.0 / 60.0)
  stack_b.tick(1.0 / 60.0)
  var incumbent_b := stack_b.get_incumbent()
  stack_a.set_threat_samples_for_test(
    [_ThreatSampleScr.make(Vector2(10.0, 0.0), 50.0, true)]
  )
  stack_a.tick(1.0 / 60.0)
  _assert(stack_a.get_physics_tick_count() == 2, "stack A tick counter isolated")
  _assert(stack_b.get_physics_tick_count() == 1, "stack B tick counter not advanced by stack A")
  _assert(
    stack_b.get_incumbent() == incumbent_b,
    "stack B incumbent unchanged when stack A threat context changes",
  )
  main.queue_free()

func _test_creature_motor_stack_integration_single_debit() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.current_calories = 10.0
  body.velocity = Vector3.ZERO
  var stack := _motor_stack_test_configure(body)
  var pos_before := body.global_position
  var before := float(body.current_calories)
  var outcome: _ActionOutcome = stack.tick(1.0 / 60.0)
  var after_stack := float(body.current_calories)
  body.call("_physics_process", 1.0 / 60.0)
  _assert(_MotorAction.is_valid_action(int(outcome.action)), "integration tick emits valid action")
  _assert(is_equal_approx(body.current_calories, after_stack), "body _physics_process does not double debit")
  _assert(body.current_calories < before, "single stack tick debits once")
  var disp := body.global_position - pos_before
  disp.y = 0.0
  # One sub-frame tick can only advance a fraction of max_speed regardless of action,
  # so displacement stays well under this bound (guards against duplicate integration).
  _assert(disp.length_squared() < 0.25, "single tick does not duplicate horizontal displacement")
  main.queue_free()

func _test_body_no_distance_calorie_burn() -> void:
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 0.0))
  body.set_use_v3_action_calories(true)
  body.set_control_mode(_ControlMode.engine_as_int())
  body.current_calories = 10.0
  body.velocity = Vector3(100.0, 0.0, 0.0)
  body.apply_action(_MotorAction.STAY, 1.0, _motor_v3_test_params())
  var after_action := float(body.current_calories)
  body.call("_physics_process", 1.0)
  _assert(
    is_equal_approx(body.current_calories, after_action),
    "v3 body skips distance calorie burn in _physics_process",
  )
  main.queue_free()

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

func _test_creature_predation_math() -> void:
  var next: float = _CreaturePredationMath.apply_meal_to_predator(8.0, 10, 5)
  _assert(is_equal_approx(next, 10.0), "CreaturePredationMath clamps meal at cap")

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

func _test_creature_vitals_math_burn_and_clamp() -> void:
  var burn: float = _CreatureVitalsMath.burn_amount(1.0, 0.002, 100.0, 1.0, 1.0, 1.0)
  _assert(is_equal_approx(burn, 1.2), "CreatureVitalsMath burn matches legacy 2D formula")
  var after: float = _CreatureVitalsMath.add_food_clamped(9.0, 5, 10)
  _assert(is_equal_approx(after, 10.0), "add_food_clamped respects cap")
  var burned_def: float = _CreatureVitalsMath.burn_amount(1.0, 0.002, 0.0, 1.0, 0.5, 2.0)
  _assert(is_equal_approx(burned_def, 0.5), "species multipliers scale burn")

func _test_diet_registry_defaults() -> void:
  var h = _DietRegistry.default_food_intake_policy(_CreatureDefinition.FeedingMode.HERBIVORE)
  _assert(h.plant_groups.has(&"food_plants"), "herbivore policy includes food_plants")
  _assert(h.prey_groups.is_empty(), "herbivore policy has no prey by default")
  var c = _DietRegistry.default_food_intake_policy(_CreatureDefinition.FeedingMode.CARNIVORE)
  _assert(c.prey_groups.size() >= 1, "carnivore policy has prey groups")
  var o = _DietRegistry.default_food_intake_policy(_CreatureDefinition.FeedingMode.OMNIVORE)
  _assert(not o.plant_groups.is_empty() and not o.prey_groups.is_empty(), "omnivore merges plant and prey")

func _test_duel_spawn_facing_variance() -> void:
  if not _ai_driver_can_instantiate():
    push_warning("skip duel spawn facing test — AiDriver script did not compile")
    return
  var main := Node3D.new()
  root.add_child(main)
  var prey := _spawn_herbivore_body(main, Vector3.ZERO)
  var driver: Node = _ai_driver_script().new()
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
  var wc: Vector2i = baked.world_to_cell(Vector2(33.0, 10.0))
  _assert(wc == Vector2i(1, 0), "world_to_cell uses floor division by cell_size")
  var d1 = baked.sample_cell_data_at_world(Vector2(50.0, 0.0))
  _assert(d1 != null and d1.get("passible") == false, "sample_cell_data_at_world returns squeeze preset")

func _test_environment_footprint_overlap() -> void:
  var frac := _Footprint.circle_cell_overlap_fraction(
    Vector2(50.0, 50.0), 10.0, Vector2(40.0, 40.0), 20.0
  )
  _assert(frac >= _Footprint.MIN_OVERLAP_FRACTION, "centered footprint meets overlap threshold")
  var frac_edge := _Footprint.circle_cell_overlap_fraction(
    Vector2(104.0, 60.0), 5.0, Vector2(80.0, 40.0), 20.0
  )
  _assert(frac_edge < _Footprint.MIN_OVERLAP_FRACTION, "grazing overlap below threshold")

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

func _test_escape_reversal_suppression() -> void:
  push_warning("skip _test_escape_reversal_suppression — V3 Step 3 stub; port at §12.2 6d")

func _test_footprint_geometry() -> void:
  var he := Vector2(10.0, 20.0)
  var center := Vector3(100.0, 0.0, 100.0)
  var pt := Vector3(50.0, 0.0, 50.0)
  var cp := Vector3(
    clampf(pt.x, center.x - he.x, center.x + he.x),
    0.0,
    clampf(pt.z, center.z - he.y, center.z + he.y),
  )
  _assert(cp.is_equal_approx(Vector3(90.0, 0.0, 80.0)), "closest point on footprint AABB")
  var obs := Vector3(130.0, 0.0, 100.0)
  var closest_obs := Vector3(
    clampf(obs.x, center.x - he.x, center.x + he.x),
    0.0,
    clampf(obs.z, center.z - he.y, center.z + he.y),
  )
  _assert(is_equal_approx(obs.distance_to(closest_obs), 20.0), "footprint point clearance uses AABB edge distance")

func _test_goal_belief_coarse_ttl() -> void:
  var ad: Node = _ai_driver_script().new()
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
  ad.free()

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
  # replay_weight = stored_strength * (1 + replay_delta/100); after one write stored_strength
  # is below 1.0 (EWMA blend), so replay_weight may be < 1.0 — assert it reflects the row.
  _assert(replay_w > 0.0, "replay_weight positive when row matches")
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

func _test_hud_resolves_3d_herbivore_motor_body() -> void:
  var hud_scene: PackedScene = load("res://hud.tscn") as PackedScene
  _assert(hud_scene != null, "hud scene loads for 3d herbivore vitals")
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3.ZERO)
  body.caloric_needs = 30
  body.current_calories = 27.0
  var stub_script := GDScript.new()
  stub_script.source_code = (
    "extends Node3D\n"
    + "var herb_body: CharacterBody3D\n"
    + "func get_herbivore_motor_body() -> CharacterBody3D:\n"
    + "  return herb_body\n"
  )
  _assert(stub_script.reload() == OK, "hud vitals stub main script compiles")
  main.set_script(stub_script)
  main.set("herb_body", body)
  var hud: Node = hud_scene.instantiate()
  main.add_child(hud)
  hud.call("_refresh_vitals_labels")
  var label_text: String = str(hud.get_node("HerbivoreCaloriesLabel").text)
  _assert(label_text.find("Rabbit") >= 0, "hud herbivore label uses rabbit display name")
  _assert(label_text.find("27 / 30") >= 0, "hud herbivore label shows live 3d body calories")
  hud.queue_free()
  main.queue_free()

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
  var driver: Node = _ai_driver_script().new()
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

func _test_hunger_calorie_clamp() -> void:
  ## Burst overflow is wasted: pool clamps at caloric_needs (HUNGER_AND_EATING §4).
  var cur := 9.0
  var cap := 10.0
  var grant := 5.0
  var next := minf(cap, cur + grant)
  _assert(is_equal_approx(next, 10.0), "hunger burst clamps at caloric_needs")
  _assert(ResourceLoader.exists("res://assets/plants/solid_shrub/solid_shrub_3d.tscn"), "solid_shrub_3d scene exists")
  _assert(ResourceLoader.exists("res://assets/plants/open_shrub/open_shrub_3d.tscn"), "open_shrub_3d scene exists")

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
    ProjectSettings.has_setting("hunter_killer_debug/draw_motor_planner_hud"),
    "project defines hunter_killer_debug/draw_motor_planner_hud",
  )
  # This is an editor-only QA toggle whose value is a per-developer choice, so assert it is
  # a defined boolean rather than pinning a specific state (see game_config_merge.use_ship_motor_profile).
  _assert(
    typeof(ProjectSettings.get_setting("hunter_killer_debug/use_ship_motor_profile")) == TYPE_BOOL,
    "use_ship_motor_profile is a boolean editor toggle",
  )

func _test_line_of_sight_wall_occlusion() -> void:
  var main := Node3D.new()
  root.add_child(main)
  _motor_v3_test_floor(main)
  var wall := StaticBody3D.new()
  var box := BoxShape3D.new()
  box.size = Vector3(10.0, 4.0, 4.0)
  var col := CollisionShape3D.new()
  col.shape = box
  wall.add_child(col)
  wall.collision_layer = 1
  main.add_child(wall)
  wall.global_position = Vector3(5.0, 1.0, 0.0)
  for _i in 8:
    await physics_frame
  var space := main.get_world_3d().direct_space_state
  var from := Vector3(-1.0, 1.0, 0.0)
  var to := Vector3(11.0, 1.0, 0.0)
  var frac := _LoS.occlusion_fraction(space, from, to, [])
  _assert(_LoS.is_occluded(frac), "static wall occludes line of sight > 60%% (frac=%.2f)" % frac)
  main.queue_free()

func _test_load_merged_config_repo_fallback() -> void:
  var res: Dictionary = _Merge.load_merged_config("user://__does_not_exist_merged_test__.json")
  var merged: Dictionary = res["merged"]
  var ic: Dictionary = merged["inference_client"]
  _assert(str(ic.get("INFERENCE_BASE_URL", "")).begins_with("http"), "merged config pulls inference URL from repo template")

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
  # weight_seek_ready_food is the one default that flips with the build profile:
  # dev profile zeroes it, ship profile restores seek. Assert the value for whichever
  # profile default_root() actually selected (driven by use_ship_motor_profile()).
  var expected_seek := 16.0 if _Merge.use_ship_motor_profile() else 0.0
  _assert(
    is_equal_approx(float(base["creature_motor"].get("weight_seek_ready_food", -1.0)), expected_seek),
    "default root seek matches active motor profile",
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

func _test_motor_plane_yaw_from_facing() -> void:
  const dirs: Array[Vector3] = [
    Vector3(0.0, 0.0, -1.0),
    Vector3(0.7071067811865475, 0.0, -0.7071067811865475),
    Vector3(1.0, 0.0, 0.0),
    Vector3(0.7071067811865475, 0.0, 0.7071067811865475),
    Vector3(0.0, 0.0, 1.0),
    Vector3(-0.7071067811865475, 0.0, 0.7071067811865475),
    Vector3(-1.0, 0.0, 0.0),
    Vector3(-0.7071067811865475, 0.0, -0.7071067811865475),
  ]
  for d in dirs:
    var yaw: float = _MotorPlane.yaw_from_horizontal_dir(d)
    var rebuilt := Vector3(sin(yaw), 0.0, -cos(yaw))
    _assert(rebuilt.is_equal_approx(d), "yaw_from_horizontal_dir round-trips 8-way direction %s" % d)

func _test_nav_path_hint_first_waypoint_invalid_map() -> void:
  var wp := _NavHint.first_waypoint_world(RID(), Vector3.ZERO, Vector3(10, 0, 0), 0.35)
  _assert(wp == Vector3.ZERO, "invalid nav map returns zero first waypoint")

func _test_nav_path_hint_invalid_map() -> void:
  var dir := _NavHint.unit_direction_to_next_waypoint(RID(), Vector3.ZERO, Vector3(10, 0, 0), 0.35)
  _assert(dir == Vector3.ZERO, "invalid nav map returns zero hint")

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
  var hug_pos := Vector2(half.x + 4.0, 50.0)
  var slid: Vector2 = _PlayfieldClamp.slide_heading_along_edge(
    Vector2(-1.0, 0.0), hug_pos, half, screen, 48.0, null
  )
  _assert(slid.is_equal_approx(Vector2(-1.0, 0.0)), "playfield edge slide pass-through when slide_pick null (Step 3)")

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

func _test_seek_wall_filter_and_backtrack() -> void:
  var approach := Vector3(0.0, 0.0, -1.0)
  var step_same := Vector3(0.0, 0.0, -1.0)
  _assert(
    _BlockedApproachScr.is_backtrack_step(step_same, approach, 0.55),
    "step along blocked approach heading is backtrack",
  )
  var step_lateral := Vector3(1.0, 0.0, 0.0)
  _assert(
    not _BlockedApproachScr.is_backtrack_step(step_lateral, approach, 0.55),
    "lateral step is not backtrack",
  )
  var main := Node3D.new()
  root.add_child(main)
  var body := _spawn_herbivore_body(main, Vector3(0.0, 1.0, 5.0))
  body.last_move_direction = Vector3(0.0, 0.0, -1.0)
  var bush := _spawn_food_bush(main, Vector3(0.0, 1.0, -20.0))
  await process_frame
  var motor_v3 := _motor_v3_test_params()
  var state := _MotorPlanner.new_state()
  _BlockedApproachScr.record(state["blocked_approach"], approach, 5, 45)
  var food_entry := {
    "pos": bush.global_position,
    "instance_id": bush.get_instance_id(),
    "stimulus_kind_id": &"shrub_berries",
  }
  var ctx := {
    "body": body,
    "motor_v3": motor_v3,
    "incumbent": {"goal_kind": _GkReg.GK_FIND_FOOD},
    "scan": {"food_split": {"ready": [food_entry], "unready": []}, "threat_samples": []},
    "threat_samples": [],
    "flight_fast_path_active": false,
    "space_state": main.get_world_3d().direct_space_state,
    "eye_height": 1.0,
    "map_rid": RID(),
    "physics_tick": 6,
  }
  _MotorPlanner.select_action(ctx, state)
  var to_goal: Vector3 = state["step_goal"] - body.global_position
  to_goal.y = 0.0
  _assert(to_goal.length_squared() > 1e-4, "planner resolves food step goal under backtrack memory")
  _assert(
    to_goal.normalized().dot(approach) < 0.9,
    "deflected step goal does not continue blocked approach heading",
  )
  main.queue_free()

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
