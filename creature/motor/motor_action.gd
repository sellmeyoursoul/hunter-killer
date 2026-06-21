extends RefCounted
class_name MotorAction
## V3 locomotion action ids and per-tick calorie costs ([CREATURE_MOVEMENT_V3.md §7](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

enum Action {
  TURN_LEFT,
  TURN_RIGHT,
  MOVE_FORWARD,
  MOVE_BACKWARD,
  STAY,
  REST,
  EAT,
}

const TURN_LEFT := Action.TURN_LEFT
const TURN_RIGHT := Action.TURN_RIGHT
const MOVE_FORWARD := Action.MOVE_FORWARD
const MOVE_BACKWARD := Action.MOVE_BACKWARD
const STAY := Action.STAY
const REST := Action.REST
const EAT := Action.EAT

const _NAME_TO_ACTION := {
  &"TURN_LEFT": Action.TURN_LEFT,
  &"TURN_RIGHT": Action.TURN_RIGHT,
  &"MOVE_FORWARD": Action.MOVE_FORWARD,
  &"MOVE_BACKWARD": Action.MOVE_BACKWARD,
  &"STAY": Action.STAY,
  &"REST": Action.REST,
  &"EAT": Action.EAT,
}


## Coerces [param action] ([code]int[/code] or [code]StringName[/code]) to [enum Action]; [code]-1[/code] when unknown.
static func normalize(action: Variant) -> int:
  if typeof(action) == TYPE_INT:
    return int(action)
  if typeof(action) == TYPE_STRING or typeof(action) == TYPE_STRING_NAME:
    var key: StringName = StringName(action)
    if _NAME_TO_ACTION.has(key):
      return int(_NAME_TO_ACTION[key])
  return -1


## Per-tick calorie debit for [param action] using merged [param motor_v3] keys (§7.5).
static func calorie_cost_for(action: Variant, delta: float, motor_v3: Dictionary) -> float:
  var act := normalize(action)
  var dt := maxf(0.0, delta)
  var baseline := float(motor_v3.get("calorie_baseline_drain_per_sec", 1.0))
  var move_rate := float(motor_v3.get("move_calorie_per_sec", 1.0))
  var rest_mul := float(motor_v3.get("rest_baseline_multiplier", 0.5))
  match act:
    Action.MOVE_FORWARD, Action.MOVE_BACKWARD, Action.TURN_LEFT, Action.TURN_RIGHT:
      return move_rate * dt
    Action.STAY, Action.EAT:
      return baseline * dt
    Action.REST:
      return baseline * rest_mul * dt
    _:
      return baseline * dt
