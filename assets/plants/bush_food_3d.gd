extends Node3D
## 3D calorie pool + player-only pickup for food shrubs ([ENVIRONMENT_MODEL_PLAN.md §6](../../Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)).

const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")
const _StaticObstacleCollision := preload("res://environment/static_obstacle_collision.gd")

signal calories_changed

@export var max_calories: int = 5
@export var growth_rate: float = 1.0
@export var stimulus_kind_id: StringName = &"shrub_berries"

var current_calories: float = 5.0

var _ready_visual: Node3D
var _depleted_visual: Node3D
var _calorie_area: Area3D
var _player_visit_locked: bool = false


func _ready() -> void:
  add_to_group(&"food_plants")
  if stimulus_kind_id == &"":
    _OLogSafe.error("bush_food_3d missing stimulus_kind_id on %s — fix scene before spawn" % name, false, "FoodPlant")
    queue_free()
    return
  _ready_visual = get_node_or_null("Visual/ReadyVisual") as Node3D
  if _ready_visual == null:
    _ready_visual = get_node_or_null("ReadyVisual") as Node3D
  _depleted_visual = get_node_or_null("Visual/DepletedVisual") as Node3D
  if _depleted_visual == null:
    _depleted_visual = get_node_or_null("DepletedVisual") as Node3D
  _strip_editor_only_nodes(_ready_visual)
  _strip_editor_only_nodes(_depleted_visual)
  _calorie_area = get_node_or_null("CalorieArea") as Area3D
  if _calorie_area != null:
    _calorie_area.body_entered.connect(_on_calorie_body_entered)
    _calorie_area.body_exited.connect(_on_calorie_body_exited)
  current_calories = float(max_calories)
  _refresh_visual()
  call_deferred("_sync_mesh_collision_from_visual")


func _sync_mesh_collision_from_visual() -> void:
  var visual := _active_visual_root()
  if visual == null:
    return
  var blocker := _find_blocker_body()
  if blocker != null:
    var shapes := _StaticObstacleCollision.sync_convex_blocker_from_visual(blocker, visual)
    if shapes <= 0:
      _OLogSafe.error(
        "bush_food_3d failed to bake blocker collision on %s — check Visual mesh" % name,
        false,
        "FoodPlant",
      )
  if _calorie_area != null:
    _StaticObstacleCollision.fit_pickup_sphere_from_visual(_calorie_area, visual, 0.15)
    var aabb := _StaticObstacleCollision.world_mesh_aabb(visual)
    if bool(aabb.get("valid", false)):
      var center: Vector3 = aabb.get("center", global_position)
      _calorie_area.position = global_transform.affine_inverse() * center


func _find_blocker_body() -> StaticBody3D:
  var sb := get_node_or_null("StaticBody3D") as StaticBody3D
  if sb != null:
    return sb
  return get_node_or_null("MobBlocker") as StaticBody3D


func _active_visual_root() -> Node3D:
  if _ready_visual != null and _ready_visual.visible:
    return _ready_visual
  if _depleted_visual != null and _depleted_visual.visible:
    return _depleted_visual
  if _ready_visual != null:
    return _ready_visual
  return _depleted_visual


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
  var full := current_calories >= float(max_calories) - 1e-3
  if _ready_visual != null:
    _ready_visual.visible = full
  if _depleted_visual != null:
    _depleted_visual.visible = not full
  call_deferred("_sync_mesh_collision_from_visual")


## Remove Blender preview Light3D / Camera3D nodes bundled in imported .blend scenes.
func _strip_editor_only_nodes(root: Node3D) -> void:
  if root == null:
    return
  var to_remove: Array[Node] = []
  _collect_editor_only_nodes(root, to_remove)
  for node in to_remove:
    node.queue_free()


func _collect_editor_only_nodes(node: Node, out: Array[Node]) -> void:
  for child in node.get_children():
    if child is Light3D or child is Camera3D:
      out.append(child)
    else:
      _collect_editor_only_nodes(child, out)


func is_pickup_ready_for_motor() -> bool:
  if _player_visit_locked:
    return false
  return current_calories >= float(max_calories) - 1e-3


## ENGINE creature EAT completion — grants calories when in range ([CREATURE_MOVEMENT_V3.md §6.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func try_grant_engine_creature(body: Node3D) -> int:
  if not DietRegistry.body_accepts_plant_intake(body):
    return 0
  if not is_pickup_ready_for_motor():
    return 0
  if body == null or not body.has_method(&"add_calories_from_food"):
    return 0
  var grant: int = maxi(0, max_calories)
  body.call(&"add_calories_from_food", grant, global_position, stimulus_kind_id)
  current_calories = 0.0
  _refresh_visual()
  calories_changed.emit()
  return grant


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
  body.call(&"add_calories_from_food", grant, global_position, stimulus_kind_id)
  current_calories = 0.0
  _player_visit_locked = true
  _refresh_visual()
  calories_changed.emit()


func _on_calorie_body_exited(body: Node3D) -> void:
  if body.is_in_group(&"player"):
    _player_visit_locked = false
