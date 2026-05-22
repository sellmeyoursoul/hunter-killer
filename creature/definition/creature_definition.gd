extends Resource
class_name CreatureDefinition
## Leaf **data** for one species (or archetype): diet, vitals caps, locomotion, perception scales, asset root.
## Behaviors live in `res://creature/capabilities/*`; see [CREATURE_MODEL_PLAN.md](../../Project_Docs/Draft_Features/CREATURE_MODEL_PLAN.md) for field intent.

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
## Multiplies distance-based calorie cost (2D uses px; 3D uses world units — keep consistent per phase).
@export var calorie_movement_cost_multiplier: float = 1.0

@export var perception_radius_scale: float = 1.0
@export var awareness_cone_half_angle_scale: float = 1.0

## Longest body dimension in **simulation units** (see CREATURE_MODEL basic info).
@export var creature_size: float = 1.0
@export var collision_capsule_radius: float = 0.35
@export var collision_capsule_height: float = 1.2

## Motivation traits (-100..100); reserved for future utility weighting ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)).
@export_range(-100, 100) var explorer_builder: int = 0
@export_range(-100, 100) var change_stability: int = 0
@export_range(-100, 100) var compassion_self_interest: int = 0
@export_range(-100, 100) var community_individual: int = 0

@export var locomotion_profile: Resource
## Optional UI / swap skin / audio variant — heavy content stays in scenes.
@export var variant_scene: PackedScene
