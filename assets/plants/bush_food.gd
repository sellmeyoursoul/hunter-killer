extends Node2D
## Shared calorie pool, regrowth, sprite swap, and player-only burst pickup for food shrubs (hunger POC).
## Params: [member texture_not_ready] / [member texture_ready] per archetype in each scene; child CalorieArea uses ENVIRONMENT_MODEL_PLAN §6 masks.
## Solid blockers: [member CalorieArea] pickup shape should extend past the static collision circle, or [method CharacterBody2D.move_and_slide] leaves the player flush outside and [signal Area2D.body_entered] never fires. [method _try_proximity_pickup_for_players] mirrors that rule using footprint clearance so tall capsules can eat when blocked adjacent to the bush circle.
const _Cardinal := preload("res://creature/motor/cardinal_avoidance.gd")
## **Food-source memory (stationary):** ENGINE belief should key on this node's [code]get_instance_id()[/code], store [code]global_position[/code] while in awareness, and refresh [method is_pickup_ready_for_motor] only when the bush is seen again. Position is fixed in world space — unlike predator prey, no velocity field is required.

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
  _try_proximity_pickup_for_players()


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
  _try_grant_pickup(body)


## Footprint clearance pickup when the player is flush against the static bush circle but the body center never enters [member CalorieArea].
func _try_proximity_pickup_for_players() -> void:
  if not is_pickup_ready_for_motor():
    return
  var tree := get_tree()
  if tree == null:
    return
  var pickup_r := _pickup_radius_px()
  var bush_pt := global_position
  for n in tree.get_nodes_in_group(&"player"):
    if not (n is Node2D):
      continue
    var body := n as Node2D
    var he := _creature_half_extents(body)
    var clr := _Cardinal.minimum_footprint_point_clearance(body.global_position, he, [bush_pt])
    if clr <= pickup_r:
      _try_grant_pickup(body)
      return


## Reads CalorieArea circle radius when present; otherwise a conservative default for headless bush nodes.
func _pickup_radius_px() -> float:
  if _calorie_area == null:
    return 58.0
  var cs := _calorie_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs != null and cs.shape is CircleShape2D:
    return maxf(0.0, (cs.shape as CircleShape2D).radius)
  return 58.0


## Capsule half-extents for footprint clearance (matches motor / awareness gating).
func _creature_half_extents(body: Node2D) -> Vector2:
  var cs := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs != null and cs.shape is CapsuleShape2D:
    var cap := cs.shape as CapsuleShape2D
    return Vector2(
      maxf(0.0, cap.radius),
      maxf(0.0, cap.radius + cap.height * 0.5),
    )
  return Vector2.ZERO


## Grants a full burst when [param body] is in group [code]player[/code] and the bush pool is ready.
func _try_grant_pickup(body: Node2D) -> void:
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
  var ad := get_node_or_null("/root/AiDriver")
  if ad != null and ad.has_method(&"notify_food_consumption_outcome"):
    ad.call(&"notify_food_consumption_outcome", body, self, false)
  current_calories = 0.0
  _player_visit_locked = true
  _refresh_sprite()
  calories_changed.emit()


func _on_calorie_body_exited(body: Node2D) -> void:
  if body.is_in_group(&"player"):
    _player_visit_locked = false
