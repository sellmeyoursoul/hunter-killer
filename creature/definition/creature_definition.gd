extends Resource
class_name CreatureDefinition
## Leaf **data** for one species (or archetype): diet, vitals caps, locomotion, perception scales, asset root.
## Behaviors live in `res://creature/capabilities/*`; see [CREATURE_MODEL_PLAN.md](../../Project_Docs/Draft_Features/CREATURE_MODEL_PLAN.md) for field intent.

const _StatMath := preload("res://creature/stat_math.gd")

enum FeedingMode {
  HERBIVORE,
  CARNIVORE,
  OMNIVORE,
}

@export var species_id: StringName = &""
@export var display_name: String = ""
## Pack root under `res://` or `user://` for [code]pack_resources.json[/code] resolution.
@export var asset_pack_root: String = ""

@export var feeding_mode: FeedingMode = FeedingMode.HERBIVORE

@export var caloric_needs: int = 30
## Multiplies merged [code]creature_motor[/code] baseline drain after global defaults are applied.
@export var calorie_baseline_drain_multiplier: float = 1.0
## Multiplies distance-based calorie cost (world units on 3D playfields).
@export var calorie_movement_cost_multiplier: float = 1.0

@export var perception_radius_scale: float = 1.0
@export var awareness_cone_half_angle_scale: float = 1.0

## Longest body dimension in **simulation units** (see CREATURE_MODEL basic info).
@export var creature_size: float = 1.0
@export var collision_capsule_radius: float = 0.35
@export var collision_capsule_height: float = 1.2

## Motivation traits (-100..100). Live: locale-prior replay (Slot A/B) via [CREATURE_TRAIT_USAGE.md](../../Project_Docs/Definitive_Features/CREATURE_TRAIT_USAGE.md); semantics [CREATURE_GOAL_DRIVERS.md](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md) §3.
@export_range(-100, 100) var explorer_builder: int = 0
@export_range(-100, 100) var change_stability: int = 0
@export_range(-100, 100) var compassion_self_interest: int = 0
@export_range(-100, 100) var community_individual: int = 0

@export var locomotion_profile: Resource
## Optional UI / swap skin / audio variant — heavy content stays in scenes.
@export var variant_scene: PackedScene
## Creature root scene to instantiate for this species (`res://creature/templates/*.tscn`) — spawn
## code ([CM_V3_MULTI_MOBS.md](../../Project_Docs/Draft_Features/CM_V3_MULTI_MOBS.md)) reads this
## instead of switching on herbivore/carnivore, so a new species is just a new archetype resource,
## not a new code path. Every template wraps the same generic scripts; [member feeding_mode] (not
## which template is used) is what makes a creature hostile/edible.
@export var body_scene: PackedScene

## Stat pool baseline (1-25 authored table, `stat_to_point` §[SHARED_STATTOPOINT_PLAN.md](../../Project_Docs/Completed_Features/SHARED_STATTOPOINT_PLAN.md)).
## Composure is otherwise **semantic only / reserved** ([CREATURE_ATTRIBUTES_USAGE.md](../../Project_Docs/Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md) §3.4) —
## this is a minimal stub (baseline + always-full point pool) so `curr_point_comp/max_point_comp`
## exist to read; nothing spends composure yet, so `curr_point_comp` never falls below
## `max_point_comp` until a future system drains it.
@export_range(1, 25) var stat_composure: int = 10
## Same stub caveat as [member stat_composure] — [CREATURE_ATTRIBUTES_USAGE.md §3.5](../../Project_Docs/Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md).
## Live consumer: predator prey-race giveaway ([CREATURE_MOVEMENT_V3.md §6.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md), 2026-09-12) —
## higher observation shortens how long a predator chases a live-visible prey that isn't closing
## distance before recognizing the race is lost.
@export_range(1, 25) var stat_observation: int = 10
## Same stub caveat as [member stat_composure] — [CREATURE_ATTRIBUTES_USAGE.md §3.8](../../Project_Docs/Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md).
## Live consumer (2026-09-15): per-creature turn rate — both the continuous goal-directed turn law
## and boundary-scan/EAT-orbit's turn stepping, unified onto one dexterity-derived rate
## (`creature_motor_stack.gd::_refresh_move_turn_rate`, `StatMath.peg_curve`) — see
## [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md).
@export_range(1, 25) var stat_dexterity: int = 10


## Max composure point pool via the shared [code]stat_to_point[/code] conversion.
func max_point_comp() -> float:
  return _StatMath.stat_to_point(stat_composure)


## Current composure point pool — always full until a future system spends composure.
func curr_point_comp() -> float:
  return max_point_comp()


## Max observation point pool via the shared [code]stat_to_point[/code] conversion.
func max_point_observ() -> float:
  return _StatMath.stat_to_point(stat_observation)


## Current observation point pool — always full until a future system spends observation.
func curr_point_observ() -> float:
  return max_point_observ()


## Max dexterity point pool via the shared [code]stat_to_point[/code] conversion.
func max_point_dex() -> float:
  return _StatMath.stat_to_point(stat_dexterity)


## Current dexterity point pool — always full until a future system spends dexterity.
func curr_point_dex() -> float:
  return max_point_dex()
