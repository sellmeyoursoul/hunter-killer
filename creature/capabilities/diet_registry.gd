extends RefCounted
class_name DietRegistry

const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _FoodIntakePolicy := preload("res://creature/definition/food_intake_policy.gd")


## Single place to map [enum CreatureDefinition.FeedingMode] → default [FoodIntakePolicy].
## Omnivore merges plant + prey group lists for one policy instance.
static func default_food_intake_policy(mode: int) -> Resource:
  var p = _FoodIntakePolicy.new()
  match mode:
    _CreatureDefinition.FeedingMode.HERBIVORE:
      p.plant_groups = [&"food_plants"]
      p.prey_groups = []
    _CreatureDefinition.FeedingMode.CARNIVORE:
      p.plant_groups = []
      p.prey_groups = [&"player", &"herbivores", &"prey"]
    _CreatureDefinition.FeedingMode.OMNIVORE:
      p.plant_groups = [&"food_plants"]
      p.prey_groups = [&"player", &"herbivores", &"prey"]
  return p
