extends Node
class_name CreatureVitalsComponent
## Node-attached runtime vitals; **logic** is [CreatureVitalsMath]. [member definition] supplies per-species multipliers.

const _CreatureVitalsMath := preload("res://creature/capabilities/creature_vitals_math.gd")

signal calories_depleted

@export var definition: Variant
var current_calories: float = 0.0

func _ready() -> void:
  if definition != null:
    var cap0: Variant = definition.get("caloric_needs")
    if cap0 != null:
      current_calories = float(cap0)


## Called from [code]CreatureRoot3D[/code] after spawn so vitals see species data when child [code]_ready[/code] order would miss parent exports.
func apply_parent_definition(def: Variant) -> void:
  definition = def
  if definition != null:
    var cap: Variant = definition.get("caloric_needs")
    current_calories = float(cap) if cap != null else 30.0


## Params:
## - baseline_per_sec, cost_per_unit_moved: merged globals (e.g. [code]GameConfig[/code] / [code]creature_motor[/code]).
## - distance_moved: units consistent with cost (pixels in 2D POC; 3D world units when wired).
## - delta: tick seconds.
func apply_burn_from_globals(baseline_per_sec: float, cost_per_unit_moved: float, distance_moved: float, delta: float) -> void:
  var bmul := 1.0
  var mmul := 1.0
  if definition != null:
    var b: Variant = definition.get("calorie_baseline_drain_multiplier")
    if b != null:
      bmul = float(b)
    var m: Variant = definition.get("calorie_movement_cost_multiplier")
    if m != null:
      mmul = float(m)
  var burn := _CreatureVitalsMath.burn_amount(baseline_per_sec, cost_per_unit_moved, distance_moved, delta, bmul, mmul)
  current_calories = maxf(0.0, current_calories - burn)
  if current_calories <= 0.0:
    calories_depleted.emit()


## Adds bush-style calories; clamps at [member CreatureDefinition.caloric_needs] when definition set.
func add_calories_from_plant(grant: int) -> void:
  var cap := 30
  if definition != null:
    var c: Variant = definition.get("caloric_needs")
    if c != null:
      cap = int(c)
  current_calories = _CreatureVitalsMath.add_food_clamped(current_calories, grant, cap)
