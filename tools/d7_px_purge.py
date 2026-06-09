#!/usr/bin/env python3
"""One-shot D7 rename: purge px from identifiers, config keys, and comments in motor paths."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

GLOBS = [
    "AI_int_lib/**/*.gd",
    "creature/**/*.gd",
    "environment/**/*.gd",
    "main_3d.gd",
    "tests/run_all.gd",
    "game_config.json",
    "assets/creatures/**/*.json",
]

# Order matters: longer / special keys first.
KEY_REPLACEMENTS = [
    ("calorie_cost_per_px_moved", "calorie_cost_per_unit_moved"),
    ("motor_cardinal_block_min_clearance_px", "motor_cardinal_block_min_clearance"),
    ("motor_patrol_min_step_clearance_px", "motor_patrol_min_step_clearance"),
    ("vegetation_blocking_forage_clearance_px", "vegetation_blocking_forage_clearance"),
    ("food_seek_imminent_mob_radius_px", "food_seek_imminent_mob_radius"),
    ("goal_memory_moving_last_known_radius_px", "goal_memory_moving_last_known_radius"),
    ("predator_prey_memory_forget_radius_px", "predator_prey_memory_forget_radius"),
    ("believed_goal_seek_escalate_radius_px", "believed_goal_seek_escalate_radius"),
    ("believed_goal_hotspot_near_radius_px", "believed_goal_hotspot_near_radius"),
    ("herbivore_flee_obstacle_approach_px", "herbivore_flee_obstacle_approach"),
    ("herbivore_flee_corner_threat_move_px", "herbivore_flee_corner_threat_move"),
    ("herbivore_flee_panic_radius_px", "herbivore_flee_panic_radius"),
    ("herbivore_jeopardy_imminent_radius_px", "herbivore_jeopardy_imminent_radius"),
    ("motor_forage_plateau_radius_px", "motor_forage_plateau_radius"),
    ("goal_memory_precise_radius_px", "goal_memory_precise_radius"),
    ("goal_memory_forget_radius_px", "goal_memory_forget_radius"),
    ("tactic_conspecific_aid_radius_px", "tactic_conspecific_aid_radius"),
    ("predator_edge_kill_close_pad_px", "predator_edge_kill_close_pad"),
    ("predator_chase_edge_band_px", "predator_chase_edge_band"),
    ("motor_playfield_corner_band_px", "motor_playfield_corner_band"),
    ("motor_stuck_move_epsilon_px", "motor_stuck_move_epsilon"),
    ("explore_coverage_cell_px", "explore_coverage_cell"),
    ("predator_obstacle_probe_px", "predator_obstacle_probe"),
    ("herbivore_obstacle_probe_px", "herbivore_obstacle_probe"),
    ("tactic_squeeze_clearance_px", "tactic_squeeze_clearance"),
    ("interior_env_near_mob_px", "interior_env_near_mob"),
    ("herbivore_flee_corner_edge_px", "herbivore_flee_corner_edge"),
    ("herbivore_flee_probe_px", "herbivore_flee_probe"),
    ("obstacle_lookahead_px", "obstacle_lookahead"),
    ("imminent_radius_px", "imminent_radius"),
    ("nearest_prior_dist_px", "nearest_prior_dist"),
    ("inward_radial_px_s", "inward_radial_speed"),
    ("cell_size_px", "cell_size"),
]

IDENT_REPLACEMENTS = [
    ("REFERENCE_MOTOR_PLAYFIELD_PX", "REFERENCE_MOTOR_PLAYFIELD_EDGE"),
    ("_viewport_playfield_size_px", "_viewport_playfield_size"),
    ("_predator_edge_kill_close_band_px", "_predator_edge_kill_close_band"),
    ("_calorie_cost_per_px_moved", "_calorie_cost_per_unit_moved"),
    ("cell_px_from_motor", "coverage_cell_from_motor"),
    ("obstacle_lookahead_px", "obstacle_lookahead"),
    ("min_clearance_px", "min_clearance"),
    ("hug_band_px", "hug_band"),
    ("lookahead_px", "lookahead"),
    ("clearance_px", "clearance_dist"),
    ("radius_px", "radius"),
    ("probe_px", "probe_dist"),
    ("approach_px", "approach_dist"),
    ("cell_px", "coverage_cell"),
    ("closing_px", "closing_delta"),
    ("speed_px_s", "speed_units_s"),
    ("per_px", "per_unit"),
    ("margin_px", "margin"),
]

COMMENT_FIXES = [
    ("per-px movement", "per-unit movement"),
    ("per pixel traveled", "per world unit traveled"),
    ("pixel size for 1:1 art", "world meters per cell edge"),
    ("cell_size_px", "cell_size"),
    ("explore_coverage_cell_px", "explore_coverage_cell"),
    ("motor_stuck_move_epsilon_px", "motor_stuck_move_epsilon"),
    ("goal_memory_precise_radius_px", "goal_memory_precise_radius"),
    ("legacy pixel-tuned", "legacy reference-playfield-tuned"),
    ("*_px[/code]", "distance params[/code]"),
    ("[code]*_px[/code]", "[code]distance params[/code]"),
]


def iter_files() -> list[Path]:
    out: list[Path] = []
    for pattern in GLOBS:
        out.extend(ROOT.glob(pattern))
    return sorted(set(out))


def apply_replacements(text: str) -> str:
    for old, new in KEY_REPLACEMENTS:
        text = text.replace(old, new)
    for old, new in IDENT_REPLACEMENTS:
        text = text.replace(old, new)
    for old, new in COMMENT_FIXES:
        text = text.replace(old, new)
    # Generic quoted keys ending in _px (leftovers).
    text = re.sub(r"([\"&][a-z0-9_]+)_px([\"&])", r"\1\2", text)
    return text


def patch_motor_plane(text: str) -> str:
    old = """## Scales distance-like [code]creature_motor[/code] keys ([code]*_px[/code], awareness radii) for 3D world units.
static func scale_motor_distance_params(motor_p: Dictionary, scale: float) -> Dictionary:
  if is_equal_approx(scale, 1.0):
    return motor_p
  var out := motor_p.duplicate(true)
  for key in [&"awareness_radius", &"awareness_cone_extra"]:
    if out.has(key):
      out[key] = float(out[key]) * scale
  for key in out.keys():
    if str(key).ends_with("_px"):
      out[key] = float(out[key]) * scale
  return out"""
    new = """## Scales distance-like [code]creature_motor[/code] keys for 3D world units ([CONVERT_TO_3D.md §4 D7](../../Project_Docs/Draft_Features/CONVERT_TO_3D.md)).
static func scale_motor_distance_params(motor_p: Dictionary, scale: float) -> Dictionary:
  if is_equal_approx(scale, 1.0):
    return motor_p
  var out := motor_p.duplicate(true)
  for key in out.keys():
    if _is_distance_motor_param_key(key):
      out[key] = float(out[key]) * scale
  return out


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
  return false"""
    return text.replace(old, new) if old in text else text


def main() -> None:
    changed = 0
    for path in iter_files():
        raw = path.read_text(encoding="utf-8")
        text = apply_replacements(raw)
        if path.name == "motor_plane.gd":
            text = patch_motor_plane(text)
        if text != raw:
            path.write_text(text, encoding="utf-8", newline="\n")
            changed += 1
            print(f"updated {path.relative_to(ROOT)}")
    print(f"done: {changed} files")


if __name__ == "__main__":
    main()
