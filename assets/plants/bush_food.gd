extends Node2D
## Shared calorie pool, regrowth, sprite swap, and player-only burst pickup for food shrubs (hunger POC).
## Params: [member texture_not_ready] / [member texture_ready] per archetype in each scene; child CalorieArea uses ENVIRONMENT_MODEL_PLAN §6 masks.
## Solid blockers: [member CalorieArea] pickup shape should extend past the static collision circle, or [method CharacterBody2D.move_and_slide] leaves the player flush outside and [signal Area2D.body_entered] never fires.

signal calories_changed

@export var max_calories: int = 5
## Calories restored per second toward [member max_calories] when depleted (POC: 1.0).
@export var growth_rate: float = 1.0
@export var texture_not_ready: Texture2D
@export var texture_ready: Texture2D

var current_calories: float = 5.0

var _sprite: Sprite2D
var _calorie_area: Area2D
var _player_visit_locked: bool = false


func _ready() -> void:
  add_to_group(&"food_plants")
  _sprite = get_node_or_null("Sprite2D") as Sprite2D
  _calorie_area = get_node_or_null("CalorieArea") as Area2D
  if _calorie_area != null:
    _calorie_area.body_entered.connect(_on_calorie_body_entered)
    _calorie_area.body_exited.connect(_on_calorie_body_exited)
  current_calories = float(max_calories)
  _refresh_sprite()


## Resets this bush for a new session (full pool, re-arm pickup after exit cycle).
func reset_session() -> void:
  current_calories = float(max_calories)
  _player_visit_locked = false
  _refresh_sprite()
  calories_changed.emit()


func _process(delta: float) -> void:
  if current_calories < float(max_calories) - 1e-5:
    current_calories = minf(float(max_calories), current_calories + growth_rate * delta)
    _refresh_sprite()


func _refresh_sprite() -> void:
  if _sprite == null:
    return
  var full := current_calories >= float(max_calories) - 1e-3
  _sprite.texture = texture_ready if full else texture_not_ready


## Whether the motor may treat this bush as a seek target (full pool, not in post-pickup lock).
## Params:
## - none
## Returns:
## - [code]true[/code] when a player could still receive a burst on contact this session.
func is_pickup_ready_for_motor() -> bool:
  if _player_visit_locked:
    return false
  return current_calories >= float(max_calories) - 1e-3


func _on_calorie_body_entered(body: Node2D) -> void:
  if not body.is_in_group(&"player"):
    return
  if _player_visit_locked:
    return
  if current_calories < float(max_calories) - 1e-3:
    return
  if not body.has_method(&"add_calories_from_food"):
    return
  var grant: int = maxi(0, max_calories)
  body.call(&"add_calories_from_food", grant)
  current_calories = 0.0
  _player_visit_locked = true
  _refresh_sprite()
  calories_changed.emit()


func _on_calorie_body_exited(body: Node2D) -> void:
  if body.is_in_group(&"player"):
    _player_visit_locked = false
