extends RefCounted
class_name ActionOutcome
## Observed result of one V3 locomotion [code]apply_action[/code] tick ([CREATURE_MOVEMENT_V3.md §7.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

var displacement: Vector3 = Vector3.ZERO
var blocked: bool = false
var calorie_cost: float = 0.0
var action: int = -1


func _init(
  disp: Vector3 = Vector3.ZERO,
  is_blocked: bool = false,
  cost: float = 0.0,
  act: int = -1,
) -> void:
  displacement = disp
  blocked = is_blocked
  calorie_cost = cost
  action = act
