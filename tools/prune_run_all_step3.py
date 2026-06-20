#!/usr/bin/env python3
"""Prune tests/run_all.gd for CREATURE_MOVEMENT_V3 Step 3."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN_ALL = ROOT / "tests" / "run_all.gd"

KEEP_FUNCS = {
    "_instantiate_herbivore_root",
    "_instantiate_carnivore_root",
    "_setup_herbivore_body",
    "_setup_carnivore_body",
    "_spawn_herbivore_body",
    "_spawn_carnivore_body",
    "_spawn_food_bush",
    "_ai_driver_script",
    "_ai_driver_can_instantiate",
    "_init",
    "_run_all_async",
    "_run_all",
    "_assert",
    "_grasslands_playfield_with_sampler",
    "_test_merge_defaults_and_override",
    "_test_creature_pack_motor_overlays",
    "_test_goal_source_memory",
    "_test_goal_kind_phase_c_replay",
    "_test_creature_trait_usage_wiring",
    "_test_locale_prior_escalate_seek",
    "_test_escape_reversal_suppression",
    "_test_goal_belief_coarse_ttl",
    "_test_load_merged_config_repo_fallback",
    "_test_hunter_killer_debug_project_settings",
    "_test_tokens",
    "_test_perception_snippet",
    "_test_perception_sampling",
    "_test_perception_risk_hints",
    "_test_pack_resource_resolver",
    "_test_hunger_calorie_clamp",
    "_test_calorie_drain_movement_formula",
    "_test_predator_prey_meal_clamp",
    "_test_creature_vitals_math_burn_and_clamp",
    "_test_hud_resolves_3d_herbivore_motor_body",
    "_test_creature_predation_math",
    "_test_diet_registry_defaults",
    "_test_creature_perception_3d_scale",
    "_test_playfield_clamp",
    "_test_boulder_obstacle_collision_bake",
    "_test_perimeter_boulder_density",
    "_test_playfield_prop_grounding_on_thick_floor",
    "_test_ground_sampler_center_lower_than_rim",
    "_test_duel_spawn_picker_avoids_depression",
    "_test_creature_spawn_floor_settle",
    "_test_human_prey_control_bootstrap",
    "_test_human_move_intent_world_space",
    "_test_human_facing_blocked_no_spin",
    "_test_human_strafe_intent_stable_under_camera_spin",
    "_test_top_down_camera_pan_directions",
    "_test_top_down_camera_zoom_clamp",
    "_test_playfield_bounds_3d_collision_only",
    "_test_footprint_geometry",
    "_test_creature_diet_on_3d_bodies",
    "_test_ai_driver_creature_registry",
    "_test_creature_3d_template_scenes_load",
    "_test_shrub_3d_visual_scenes_load",
    "_test_creature_3d_predation_contact",
    "_test_environment_baked_grid",
    "_test_environment_movement_impact_merge",
    "_test_environment_footprint_overlap",
    "_test_creature_size_sync_capsule",
    "_test_line_of_sight_wall_occlusion",
    "_test_nav_path_hint_invalid_map",
    "_test_nav_path_hint_first_waypoint_invalid_map",
    "_test_blocked_approach_memory",
    "_test_seek_wall_filter_and_backtrack",
    "_test_motor_plane_yaw_from_facing",
    "_test_ai_driver_helpers",
    "_test_duel_spawn_facing_variance",
    "_test_bundled_inference_helpers",
    "_test_creature_kinematic_playfield_clamp_after_move",
}

NEW_HEADER = '''extends SceneTree

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
const _AiDriverScr := preload("res://AI_int_lib/ai_driver.gd")
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

var _failures: int = 0
'''

NEW_RUN_ALL_BODY = '''func _run_all() -> void:
  _test_merge_defaults_and_override()
  _test_creature_pack_motor_overlays()
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
'''


def split_functions(text: str) -> dict[str, str]:
    pattern = re.compile(r"^func (\w+)\(", re.MULTILINE)
    matches = list(pattern.finditer(text))
    funcs: dict[str, str] = {}
    for i, m in enumerate(matches):
        name = m.group(1)
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        funcs[name] = text[start:end].rstrip() + "\n"
    return funcs


def patch_test(name: str, body: str) -> str:
    if name == "_test_escape_reversal_suppression":
        return '''func _test_escape_reversal_suppression() -> void:
  push_warning("skip _test_escape_reversal_suppression — V3 Step 3 stub; port at §12.2 6d")
'''
    if name == "_test_blocked_approach_memory":
        # Drop cardinal pinch slice; keep BlockedApproachMemory unit checks only.
        marker = "  var he := Vector2(13.5, 30.5)\n  var pinch_ctx"
        if marker in body:
            body = body.split(marker)[0].rstrip() + "\n"
    if name == "_test_seek_wall_filter_and_backtrack":
        return '''func _test_seek_wall_filter_and_backtrack() -> void:
  push_warning("skip _test_seek_wall_filter_and_backtrack — cardinal seek removed Step 3; port at §12.2 6c")
'''
    if name == "_test_ai_driver_helpers":
        marker = "  var motor_p := _Merge.creature_motor_spine()"
        if marker in body:
            body = body.split(marker)[0].rstrip() + "\n"
    return body


def main() -> None:
    src = RUN_ALL.read_text(encoding="utf-8")
    funcs = split_functions(src)
    missing = KEEP_FUNCS - set(funcs.keys())
    if missing:
        raise SystemExit(f"Missing functions in run_all.gd: {sorted(missing)}")

    out_parts = [NEW_HEADER.rstrip(), ""]
    order = [
        "_instantiate_herbivore_root",
        "_instantiate_carnivore_root",
        "_setup_herbivore_body",
        "_setup_carnivore_body",
        "_spawn_herbivore_body",
        "_spawn_carnivore_body",
        "_spawn_food_bush",
        "_ai_driver_script",
        "_ai_driver_can_instantiate",
        "_init",
        "_run_all_async",
        "_run_all",
        "_assert",
    ]
    for name in order:
        if name == "_run_all":
            out_parts.append(NEW_RUN_ALL_BODY.rstrip())
        else:
            out_parts.append(funcs[name].rstrip())

    rest = sorted(KEEP_FUNCS - set(order))
    for name in rest:
        out_parts.append(patch_test(name, funcs[name]).rstrip())

    RUN_ALL.write_text("\n\n".join(out_parts) + "\n", encoding="utf-8")
    print(f"Wrote pruned {RUN_ALL} ({len(rest) + len(order)} functions)")


if __name__ == "__main__":
    main()
