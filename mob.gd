extends RigidBody2D

const _SlidePickScr := preload("res://creature/motor/wall_slide_pick.gd")
const _CreatureVitalsMath := preload("res://creature/capabilities/creature_vitals_math.gd")
const _CreaturePredationMath := preload("res://creature/capabilities/creature_predation_math.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")
const _PlayerScr := preload("res://player.gd")

@export var isHostile = true
@export var definition: Resource
## ENGINE duel cruise speed (px/s); matches [code]Player.speed[/code] so carnivore keeps pace with prey.
@export var speed: float = 400.0
@export var creature_size: float = 48.0
@export var caloric_needs: int = 30
@export var obstacle_lookahead_px: float = 96.0
@export var obstacle_ray_margin_px: float = 14.0
@export var env_ahead_probe_px: float = 52.0
@export_range(8.0, 45.0, 1.0)
var obstacle_cone_half_angle_deg: float = 22.0

var _calorie_baseline_drain_per_sec: float = 1.0
var _calorie_cost_per_px_moved: float = 0.002
var current_calories: float = 30.0
var creature_move_intent: Vector2 = Vector2.ZERO
var last_move_direction: Vector2 = Vector2.RIGHT
var screen_size: Vector2

var _main: Node = null
var _spawn_cruise_speed: float = 200.0
var _last_heading: Vector2 = Vector2.RIGHT
var _wall_slide_pick: RefCounted
var _food_intake_policy: Resource
var _starvation_fired: bool = false
var control_mode: int = 0

const _STALL_SPEED_PX_PER_SEC := 4.0


static func engine_control_as_int() -> int:
  return _PlayerScr.engine_control_as_int()


func get_feeding_mode() -> int:
  if definition != null and definition.get_script() == _CreatureDefinition:
    return int((definition as Resource).get("feeding_mode"))
  return _CreatureDefinition.FeedingMode.CARNIVORE


func _ready() -> void:
  add_to_group(&"mobs")
  add_to_group(&"creatures")
  gravity_scale = 0.0
  lock_rotation = true
  set_can_sleep(false)
  screen_size = get_viewport_rect().size
  _wall_slide_pick = _SlidePickScr.new()
  _apply_diet_defaults()
  _spawn_cruise_speed = maxf(speed, maxf(120.0, linear_velocity.length()))
  var v0 := linear_velocity
  if v0.length_squared() > 1e-6:
    _last_heading = v0.normalized()
  current_calories = float(caloric_needs)
  _refresh_calorie_burn_params()
  control_mode = engine_control_as_int()
  var mob_animations: Array[StringName] = [&"fly", &"swim", &"walk"]
  $AnimatedSprite2D.animation = mob_animations.pick_random()
  $AnimatedSprite2D.play()


func prepare_duel_spawn() -> void:
  control_mode = engine_control_as_int()
  _starvation_fired = false
  current_calories = float(caloric_needs)
  if is_inside_tree():
    screen_size = get_viewport_rect().size


func _apply_diet_defaults() -> void:
  if definition == null:
    var def := _CreatureDefinition.new()
    def.feeding_mode = _CreatureDefinition.FeedingMode.CARNIVORE
    definition = def
  elif definition.get_script() == _CreatureDefinition:
    var cap: Variant = (definition as Resource).get("caloric_needs")
    if typeof(cap) == TYPE_INT:
      caloric_needs = int(cap)
      current_calories = float(caloric_needs)
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


func add_calories_from_prey(amount: int) -> void:
  current_calories = _CreaturePredationMath.apply_meal_to_predator(current_calories, caloric_needs, amount)


func set_control_mode(mode: int) -> void:
  control_mode = mode


func set_creature_move_intent(dir: Vector2) -> void:
  creature_move_intent = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO


func _footprint_half_for_clamp() -> Vector2:
  var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs != null and cs.shape is CapsuleShape2D:
    var cap := cs.shape as CapsuleShape2D
    return Vector2(cap.radius, cap.radius + cap.height * 0.5)
  return Vector2(18.0, 44.5)


func _clamp_to_playfield() -> void:
  global_position = _PlayfieldClamp.clamp_position(global_position, _footprint_half_for_clamp(), screen_size)


func _apply_calorie_burn_and_starvation(delta: float) -> void:
  if _starvation_fired:
    return
  var dist_px := linear_velocity.length() * delta
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
  var main := get_tree().current_scene
  if main != null and main.has_method(&"end_round"):
    main.call(&"end_round", "starvation_carn_herb_win", "herbivore")


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
  queue_free()


func _environment_grid() -> EnvironmentGridBaked:
  if _main == null:
    _main = get_tree().current_scene
  if _main == null or not _main.has_method("get_environment_grid"):
    return null
  var gr: Variant = _main.call("get_environment_grid")
  if gr == null or not (gr is EnvironmentGridBaked):
    return null
  var grid := gr as EnvironmentGridBaked
  if not grid.is_valid_shape():
    return null
  return grid


func _terrain_speed_multiplier_here(grid: EnvironmentGridBaked) -> float:
  if grid == null:
    return 1.0
  var cell_r := grid.sample_cell_data_at_world(global_position)
  if not (cell_r is EnvironmentCellData):
    return 1.0
  var env := cell_r as EnvironmentCellData
  if not env.can_enter(creature_size):
    return 1.0
  return env.movement_speed_multiplier(creature_size)


func _physics_process(delta: float) -> void:
  if control_mode == engine_control_as_int():
    _physics_process_engine(delta)
    return
  _physics_process_legacy_cruise(delta)


func _engine_heading_with_wall_slide(heading: Vector2) -> Vector2:
  if heading.length_squared() < 1e-8:
    return heading
  var inc := heading.normalized()
  var space := get_world_2d().direct_space_state
  if space == null:
    return inc
  var lookahead := maxf(obstacle_lookahead_px, 48.0)
  var origin := global_position
  var target := origin + inc * lookahead
  var query := PhysicsRayQueryParameters2D.create(origin, target)
  query.collision_mask = 1
  query.exclude = [get_rid()]
  var hit: Dictionary = space.intersect_ray(query)
  if hit.is_empty():
    return inc
  var normal_v: Variant = hit.get("normal", Vector2.ZERO)
  if typeof(normal_v) != TYPE_VECTOR2:
    return inc
  var n := normal_v as Vector2
  if n.length_squared() < 1e-12:
    return inc
  return _wall_slide_pick.pick_tangent_closer(inc, n)


func _physics_process_engine(delta: float) -> void:
  var grid := _environment_grid()
  var mult := _terrain_speed_multiplier_here(grid)
  var heading := creature_move_intent
  if heading.length_squared() < 1e-8:
    heading = _last_heading
  else:
    _last_heading = heading
  heading = _engine_heading_with_wall_slide(heading)
  if heading.length_squared() > 1e-6:
    _last_heading = heading.normalized()
  linear_velocity = heading * (speed * mult)
  _clamp_to_playfield()
  if heading.length_squared() > 1e-6:
    last_move_direction = heading.normalized()
  _apply_calorie_burn_and_starvation(delta)


func _physics_process_legacy_cruise(delta: float) -> void:
  var grid := _environment_grid()
  var spd := linear_velocity.length()
  var incoming := linear_velocity.normalized() if spd > 1e-4 else Vector2.ZERO
  if incoming.length_squared() < 1e-8:
    incoming = _last_heading
  if spd < _STALL_SPEED_PX_PER_SEC:
    linear_velocity = _last_heading * _spawn_cruise_speed
    _clamp_to_playfield()
    _apply_calorie_burn_and_starvation(delta)
    return
  _last_heading = incoming
  var mult_fin := _terrain_speed_multiplier_here(grid)
  linear_velocity = incoming * (_spawn_cruise_speed * mult_fin)
  _clamp_to_playfield()
  _apply_calorie_burn_and_starvation(delta)
