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


## Returns one named group list from a [FoodIntakePolicy] ([code]plant_groups[/code] or [code]prey_groups[/code]).
static func policy_groups(policy: Resource, key: String) -> Array:
  if policy == null:
    return []
  var raw: Variant = policy.get(key)
  if typeof(raw) != TYPE_ARRAY:
    return []
  return raw as Array


## Resolves [enum CreatureDefinition.FeedingMode] for motor / awareness ingest.
static func feeding_mode_for_body(body: Node) -> int:
  if body != null and body.has_method(&"get_feeding_mode"):
    return int(body.call(&"get_feeding_mode"))
  if body != null and body.is_in_group(&"mobs") and not body.is_in_group(&"prey"):
    return _CreatureDefinition.FeedingMode.CARNIVORE
  return _CreatureDefinition.FeedingMode.HERBIVORE


## Resolves the intake policy used to filter live food ingress ([CREATURE_MOVEMENT_V2 §B.2](../../Project_Docs/Completed_Features/CREATURE_MOVEMENT_V2.md)).
static func food_intake_policy_for_body(body: Node) -> Resource:
  if body != null and body.has_method(&"get_food_intake_policy"):
    var pol: Variant = body.call(&"get_food_intake_policy")
    if pol is Resource:
      return pol as Resource
  return default_food_intake_policy(feeding_mode_for_body(body))


## True when [param node] is in any plant or prey group allowed by [param policy].
static func node_is_valid_food_for_policy(node: Node, policy: Resource) -> bool:
  if node == null or policy == null:
    return false
  for group_name in policy_groups(policy, "plant_groups"):
    if node.is_in_group(StringName(str(group_name))):
      return true
  for group_name in policy_groups(policy, "prey_groups"):
    if node.is_in_group(StringName(str(group_name))):
      return true
  return false


## True when [param body] may consume plant-group food sources.
static func body_accepts_plant_intake(body: Node) -> bool:
  return not policy_groups(food_intake_policy_for_body(body), "plant_groups").is_empty()
