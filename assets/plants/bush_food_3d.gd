extends Node3D
## 3D calorie pool + player-only pickup for food shrubs ([ENVIRONMENT_MODEL_PLAN.md §6](../../Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)).

signal calories_changed

@export var max_calories: int = 5
@export var growth_rate: float = 1.0

var current_calories: float = 5.0

var _mesh: MeshInstance3D
var _calorie_area: Area3D
var _player_visit_locked: bool = false


func _ready() -> void:
  add_to_group(&"food_plants")
  _mesh = get_node_or_null("Mesh") as MeshInstance3D
  _calorie_area = get_node_or_null("CalorieArea") as Area3D
  if _calorie_area != null:
    _calorie_area.body_entered.connect(_on_calorie_body_entered)
    _calorie_area.body_exited.connect(_on_calorie_body_exited)
  current_calories = float(max_calories)
  _refresh_visual()


func reset_session() -> void:
  current_calories = float(max_calories)
  _player_visit_locked = false
  _refresh_visual()
  calories_changed.emit()


func _process(delta: float) -> void:
  if current_calories < float(max_calories) - 1e-5:
    current_calories = minf(float(max_calories), current_calories + growth_rate * delta)
    _refresh_visual()
  _try_proximity_pickup_for_players()


func _refresh_visual() -> void:
  if _mesh == null:
    return
  var full := current_calories >= float(max_calories) - 1e-3
  _mesh.visible = true
  if _mesh.material_override is StandardMaterial3D:
    var mat := _mesh.material_override as StandardMaterial3D
    mat.albedo_color = Color(0.25, 0.55, 0.2) if full else Color(0.35, 0.3, 0.15)


func is_pickup_ready_for_motor() -> bool:
  if _player_visit_locked:
    return false
  return current_calories >= float(max_calories) - 1e-3


func _on_calorie_body_entered(body: Node3D) -> void:
  _try_grant_pickup(body)


func _try_proximity_pickup_for_players() -> void:
  if not is_pickup_ready_for_motor():
    return
  var tree := get_tree()
  if tree == null:
    return
  var pickup_r := _pickup_radius_world()
  var bush_pt := global_position
  for n in tree.get_nodes_in_group(&"player"):
    if not (n is Node3D):
      continue
    var body := n as Node3D
    var he := _creature_half_extents(body)
    var clr := _footprint_point_clearance(body.global_position, he, bush_pt)
    if clr <= pickup_r:
      _try_grant_pickup(body)
      return


func _pickup_radius_world() -> float:
  if _calorie_area == null:
    return 1.2
  var cs := _calorie_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs != null and cs.shape is SphereShape3D:
    return maxf(0.0, (cs.shape as SphereShape3D).radius)
  return 1.2


func _creature_half_extents(body: Node3D) -> Vector2:
  var cs := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs != null and cs.shape is CapsuleShape3D:
    var cap := cs.shape as CapsuleShape3D
    return Vector2(
      maxf(0.0, cap.radius),
      maxf(0.0, cap.radius + cap.height * 0.5),
    )
  return Vector2.ZERO


func _footprint_point_clearance(center: Vector3, half: Vector2, pt: Vector3) -> float:
  if half.x <= 0.0 or half.y <= 0.0:
    return center.distance_to(pt)
  var closest := Vector3(
    clampf(pt.x, center.x - half.x, center.x + half.x),
    center.y,
    clampf(pt.z, center.z - half.y, center.z + half.y),
  )
  return closest.distance_to(pt)


func _try_grant_pickup(body: Node3D) -> void:
  if not body.is_in_group(&"player"):
    return
  if _player_visit_locked:
    return
  if current_calories < float(max_calories) - 1e-3:
    return
  if not body.has_method(&"add_calories_from_food"):
    return
  var grant: int = maxi(0, max_calories)
  body.call(&"add_calories_from_food", grant, global_position)
  current_calories = 0.0
  _player_visit_locked = true
  _refresh_visual()
  calories_changed.emit()


func _on_calorie_body_exited(body: Node3D) -> void:
  if body.is_in_group(&"player"):
    _player_visit_locked = false
