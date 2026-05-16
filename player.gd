extends CharacterBody2D
signal hit

const _CreatureVitalsMath := preload("res://creature/capabilities/creature_vitals_math.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")

@export var isHostile = false
@export var definition: Resource
@export var speed = 400
@export var creature_size: float = 26.0
@export var caloric_needs: int = 10

var screen_size: Vector2
var current_calories: float = 10.0
var _starvation_fired: bool = false
var _calorie_baseline_drain_per_sec: float = 1.0
var _calorie_cost_per_px_moved: float = 0.002
var creature_move_intent: Vector2 = Vector2.ZERO
var current_velocity: Vector2 = Vector2.ZERO
var last_move_direction: Vector2 = Vector2.RIGHT
var _food_intake_policy: Resource

enum ControlMode {
  HUMAN,
  ENGINE,
  AI,
}

var control_mode: ControlMode = ControlMode.HUMAN


static func human_control_as_int() -> int:
  return ControlMode.HUMAN


static func engine_control_as_int() -> int:
  return ControlMode.ENGINE


static func ai_control_as_int() -> int:
  return ControlMode.AI


## Returns [enum CreatureDefinition.FeedingMode] for motor / AI registration.
func get_feeding_mode() -> int:
  if definition != null and definition.get_script() == _CreatureDefinition:
    return int((definition as Resource).get("feeding_mode"))
  return _CreatureDefinition.FeedingMode.HERBIVORE


func _ready() -> void:
  add_to_group(&"player")
  add_to_group(&"herbivores")
  add_to_group(&"prey")
  add_to_group(&"creatures")
  screen_size = get_viewport_rect().size
  collision_layer = 2
  collision_mask = 1
  motion_mode = MOTION_MODE_FLOATING
  hide()
  _apply_diet_defaults()
  _refresh_calorie_burn_params()
  var ad := get_node_or_null("/root/AiDriver")
  if ad != null and ad.has_method(&"register_creature"):
    ad.call(&"register_creature", self)


func _apply_diet_defaults() -> void:
  if definition == null:
    var def := _CreatureDefinition.new()
    def.feeding_mode = _CreatureDefinition.FeedingMode.HERBIVORE
    definition = def
  _food_intake_policy = _DietRegistry.default_food_intake_policy(get_feeding_mode())


func get_food_intake_policy() -> Resource:
  if _food_intake_policy == null:
    _food_intake_policy = _DietRegistry.default_food_intake_policy(get_feeding_mode())
  return _food_intake_policy


func _refresh_calorie_burn_params() -> void:
  _calorie_baseline_drain_per_sec = 1.0
  _calorie_cost_per_px_moved = 0.002
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    var cm: Dictionary = gc.get_creature_motor_params()
    _calorie_baseline_drain_per_sec = float(cm.get("calorie_baseline_drain_per_sec", _calorie_baseline_drain_per_sec))
    _calorie_cost_per_px_moved = float(cm.get("calorie_cost_per_px_moved", _calorie_cost_per_px_moved))


func add_calories_from_food(amount: int) -> void:
  current_calories = _CreatureVitalsMath.add_food_clamped(current_calories, amount, caloric_needs)


func was_defeated_by_starvation() -> bool:
  return _starvation_fired


func _apply_calorie_drain_and_starvation(delta: float) -> void:
  if not visible or _starvation_fired:
    return
  var dist_px := current_velocity.length() * delta
  var burn: float = _CreatureVitalsMath.burn_amount(
    _calorie_baseline_drain_per_sec,
    _calorie_cost_per_px_moved,
    dist_px,
    delta,
    1.0,
    1.0,
  )
  current_calories = maxf(0.0, current_calories - burn)
  if current_calories > 0.0:
    return
  _starvation_fired = true
  _apply_defeat_local()
  hit.emit()


func _read_move_intent() -> Vector2:
  if control_mode == ControlMode.ENGINE or control_mode == ControlMode.AI:
    return creature_move_intent
  var move := Vector2.ZERO
  if Input.is_action_pressed("move_right"):
    move.x += 1
  if Input.is_action_pressed("move_left"):
    move.x -= 1
  if Input.is_action_pressed("move_down"):
    move.y += 1
  if Input.is_action_pressed("move_up"):
    move.y -= 1
  return move.normalized() if move.length() > 0.0 else Vector2.ZERO


func _footprint_half_for_clamp() -> Vector2:
  var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs != null and cs.shape is CapsuleShape2D:
    var cap := cs.shape as CapsuleShape2D
    return Vector2(cap.radius, cap.radius + cap.height * 0.5)
  return Vector2(13.5, 30.5)


func _sample_movement_speed_multiplier() -> float:
  var m := get_tree().current_scene
  if m == null or not m.has_method("get_environment_grid"):
    return 1.0
  var grid_r: Variant = m.call("get_environment_grid")
  if grid_r == null or not (grid_r is EnvironmentGridBaked):
    return 1.0
  var grid := grid_r as EnvironmentGridBaked
  if not grid.is_valid_shape():
    return 1.0
  var cell_r := grid.sample_cell_data_at_world(global_position)
  if cell_r == null or not (cell_r is EnvironmentCellData):
    return 1.0
  var env := cell_r as EnvironmentCellData
  if not env.can_enter(creature_size):
    return 1.0
  return env.movement_speed_multiplier(creature_size)


func _clamp_to_playfield() -> void:
  position = _PlayfieldClamp.clamp_position(position, _footprint_half_for_clamp(), screen_size)


func _physics_process(delta: float) -> void:
  var intent := _read_move_intent()
  var env_mult := _sample_movement_speed_multiplier()
  var target_speed := float(speed) * env_mult
  velocity = intent * target_speed
  move_and_slide()
  _clamp_to_playfield()

  current_velocity = velocity
  _apply_calorie_drain_and_starvation(delta)
  if current_velocity.length() > 0.0:
    $AnimatedSprite2D.play()
  else:
    $AnimatedSprite2D.stop()

  if current_velocity.length() > 1.0:
    last_move_direction = current_velocity.normalized()

  if current_velocity.x != 0.0:
    $AnimatedSprite2D.animation = "walk"
    $AnimatedSprite2D.flip_v = false
    $AnimatedSprite2D.flip_h = current_velocity.x < 0.0
  elif current_velocity.y != 0.0:
    $AnimatedSprite2D.animation = "up"
    $AnimatedSprite2D.flip_v = current_velocity.y > 0.0


func _apply_defeat_local() -> void:
  hide()
  $CollisionShape2D.set_deferred("disabled", true)
  var hb := get_node_or_null("MobHitbox/CollisionShape2D") as CollisionShape2D
  if hb != null:
    hb.set_deferred("disabled", true)


func _on_mob_hitbox_body_entered(body: Node2D) -> void:
  if body.get("isHostile"):
    var meal := 5
    var gc := get_node_or_null("/root/GameConfig")
    if gc != null and gc.has_method(&"get_creature_motor_params"):
      meal = int(gc.get_creature_motor_params().get("predator_prey_meal_calories", meal))
    if body.has_method(&"add_calories_from_prey"):
      body.call(&"add_calories_from_prey", meal)
    _apply_defeat_local()
    hit.emit()


func start(pos: Vector2) -> void:
  position = pos
  velocity = Vector2.ZERO
  current_velocity = Vector2.ZERO
  last_move_direction = Vector2.RIGHT
  screen_size = get_viewport_rect().size
  _refresh_calorie_burn_params()
  current_calories = float(caloric_needs)
  _starvation_fired = false
  show()
  $CollisionShape2D.disabled = false
  var hb := get_node_or_null("MobHitbox/CollisionShape2D") as CollisionShape2D
  if hb != null:
    hb.disabled = false


func set_control_mode(mode: ControlMode) -> void:
  control_mode = mode


func set_creature_move_intent(dir: Vector2) -> void:
  creature_move_intent = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO
