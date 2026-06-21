extends RefCounted
class_name CreatureMotorStack
## Per-creature V3 motor runtime — hub + cadence + execution shell ([CREATURE_MOVEMENT_V3.md §1 / §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const _MotorAction := preload("res://creature/motor/motor_action.gd")
const _LocomotionExecutor := preload("res://creature/motor/locomotion_executor.gd")
const _MotorGoalHub := preload("res://creature/motor/motor_goal_hub.gd")
const _MotorCadence := preload("res://creature/motor/motor_consideration_cadence.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")

var _body: CharacterBody3D
var _vitals: Node
var _motor_v3: Dictionary = {}
var _pack_root: String = ""
var _goal_catalog: Dictionary = {}

var _physics_tick_count: int = 0
var _consideration_interval: int = 8
var _active_goals: Array = []
var _incumbent: Dictionary = {}
var _flight_fast_path_active: bool = false
var _safety_met: bool = false
var _threat_samples: Array = []
var _stat_observation: int = 10
var _food_map_confidence: float = 0.0


## Wires body, vitals, merged [code]creature_motor_v3[/code], and goal catalog at spawn.
func configure(
  body: CharacterBody3D,
  vitals: Node,
  motor_v3: Dictionary,
  pack_root: String,
  goal_catalog: Dictionary,
) -> void:
  _body = body
  _vitals = vitals
  _motor_v3 = motor_v3.duplicate(true)
  _pack_root = str(pack_root).strip_edges()
  _goal_catalog = goal_catalog.duplicate(true) if typeof(goal_catalog) == TYPE_DICTIONARY else {}
  _stat_observation = _resolve_stat_observation()
  _consideration_interval = _MotorCadence.observation_replan_interval_ticks(
    _stat_observation,
    _motor_v3,
  )
  _physics_tick_count = 0
  _active_goals = []
  _incumbent = {}
  _flight_fast_path_active = false


## One physics tick: consideration cadence + hub (6b always emits [code]STAY[/code]).
func tick(delta: float) -> ActionOutcome:
  _physics_tick_count += 1
  var ctx := _build_context()
  _update_flight_fast_path_stub(ctx)
  ctx["flight_fast_path_active"] = _flight_fast_path_active

  if _should_run_consideration():
    _run_consideration(ctx)

  var action := _MotorAction.STAY
  var outcome := _LocomotionExecutor.apply_action(_body, action, delta, _motor_v3)
  _apply_gravity_if_stationary(action, delta)
  _clamp_playfield_if_needed()
  return outcome


func get_physics_tick_count() -> int:
  return _physics_tick_count


func get_consideration_interval() -> int:
  return _consideration_interval


func get_active_goals() -> Array:
  return _active_goals.duplicate(true)


func get_incumbent() -> Dictionary:
  return _incumbent.duplicate(true)


func is_flight_fast_path_active() -> bool:
  return _flight_fast_path_active


## Test / harness injection for threat geometry (6b).
func set_threat_samples_for_test(samples: Array) -> void:
  _threat_samples = samples.duplicate(true)


func set_safety_met_for_test(met: bool) -> void:
  _safety_met = met


func set_food_map_confidence_for_test(confidence: float) -> void:
  _food_map_confidence = clampf(confidence, 0.0, 1.0)


func _build_context() -> Dictionary:
  return {
    "motor_v3": _motor_v3,
    "calorie_ratio": _calorie_ratio(),
    "threat_samples": _threat_samples,
    "flight_fast_path_active": _flight_fast_path_active,
    "safety_met": _safety_met,
    "food_map_confidence": _food_map_confidence,
    "pack_root": _pack_root,
    "goal_catalog": _goal_catalog,
  }


func _calorie_ratio() -> float:
  if _body == null:
    return 1.0
  var cap := maxf(1.0, float(_body.get("caloric_needs")))
  var current := float(_body.get("current_calories"))
  if _vitals != null:
    var vc: Variant = _vitals.get("current_calories")
    if typeof(vc) == TYPE_FLOAT or typeof(vc) == TYPE_INT:
      current = float(vc)
  return clampf(current / cap, 0.0, 1.0)


func _resolve_stat_observation() -> int:
  if _body == null:
    return 10
  var def_v: Variant = _body.get("definition")
  if def_v is Resource:
    var stat_v: Variant = (def_v as Resource).get("stat_observation")
    if typeof(stat_v) == TYPE_INT or typeof(stat_v) == TYPE_FLOAT:
      return maxi(10, int(stat_v))
  return 10


func _update_flight_fast_path_stub(ctx: Dictionary) -> void:
  var panic_r := float(_motor_v3.get("flight_acute_panic_radius", 220.0))
  _flight_fast_path_active = false
  for sample_v in ctx.get("threat_samples", []):
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = sample_v
    if not bool(sample.get("in_awareness", false)):
      continue
    if float(sample.get("gate_dist", INF)) <= panic_r:
      _flight_fast_path_active = true
      return


func _should_run_consideration() -> bool:
  if _physics_tick_count == 1:
    return true
  return _physics_tick_count % _consideration_interval == 0


func _run_consideration(ctx: Dictionary) -> void:
  var eligible := _MotorGoalHub.build_eligible_goals(ctx)
  var scored := _MotorGoalHub.score_goals(eligible, ctx)
  _active_goals = scored
  _incumbent = _MotorGoalHub.pick_winner(scored, _motor_v3)


func _apply_gravity_if_stationary(action: int, delta: float) -> void:
  if _body == null:
    return
  match action:
    _MotorAction.STAY, _MotorAction.TURN_LEFT, _MotorAction.TURN_RIGHT, _MotorAction.REST, _MotorAction.EAT:
      if _body.has_method(&"apply_horizontal_move_intent"):
        _body.call(&"apply_horizontal_move_intent", Vector3.ZERO, delta)


func _clamp_playfield_if_needed() -> void:
  if _body == null:
    return
  var mode := int(_body.get("control_mode"))
  if mode != _ControlMode.engine_as_int() and mode != _ControlMode.ai_as_int():
    return
  if _body.has_method(&"_clamp_playfield_position"):
    _body.call(&"_clamp_playfield_position")
