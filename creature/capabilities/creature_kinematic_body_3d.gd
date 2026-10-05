extends CharacterBody3D
## Kinematic 3D creature: **horizontal move intent** uses **X and Z only**; Y is ignored for steering.
## **Gravity and jump** are owned here so [code]AiDriver[/code] can stay thin (2D-style direction promoted to XZ).
## Motor bridge: [method set_creature_move_intent] accepts [code]Vector3[/code] or legacy [code]Vector2[/code] motor-plane intent.

## `predator` is the specific carnivore body that caused this defeat (null for starvation) — lets a
## listener with more than one carnivore in play ([CM_V3_MULTI_MOBS.md]
## (../../Project_Docs/Draft_Features/CM_V3_MULTI_MOBS.md)) attribute the round outcome to the right one.
signal hit(predator: Node)

const _LocoProfile := preload("res://creature/definition/locomotion_profile.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _DefScript := _CreatureDefinition
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")
const _CreatureMeshFootprint := preload("res://creature/capabilities/creature_mesh_footprint.gd")
const _BodyDims := preload("res://creature/capabilities/creature_body_dimensions.gd")
const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")
const _CreatureVitalsMath := preload("res://creature/capabilities/creature_vitals_math.gd")
const _CreaturePredationMath := preload("res://creature/capabilities/creature_predation_math.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _ConfigMerge := preload("res://AI_int_lib/game_config_merge.gd")
const _LocomotionExecutor := preload("res://creature/motor/locomotion_executor.gd")
const _GhostObstacleQuery := preload("res://creature/motor/ghost_obstacle_query.gd")

@export var definition: Variant
@export var is_hostile: bool = false
@export var obstacle_lookahead: float = 96.0
## Extra Y rotation on [code]Visual[/code] when imported mesh forward != -Z.
@export var visual_yaw_offset_rad: float = 0.0

var creature_move_intent: Vector3 = Vector3.ZERO
var last_move_direction: Vector3 = _MotorPlane.HORIZONTAL_RIGHT
var control_mode: int = 0
var speed: float = 5.0
var screen_size: Vector2 = Vector2.ZERO
var playfield_bounds_min: Vector2 = Vector2.ZERO
var playfield_bounds_max: Vector2 = Vector2.ZERO
var creature_size: float = 1.0
var _base_creature_size: float = 1.0
## True until the definition authors body_length / width / height (deprecated radius / height fallback).
var _legacy_dims: bool = true
var _legacy_radius: float = 0.35
var _legacy_height: float = 1.2
## Authored dimensions at size factor 1 (game units); unused while [member _legacy_dims].
var _base_length: float = 1.0
var _base_width: float = 1.0
var _base_height: float = 1.0
var _reach_override: float = 0.0
## Uniform runtime size factor (decision 5): [code]creature_size / _base_creature_size[/code].
var _size_factor: float = 1.0
## True once a definition was cached; before that the template's own shapes are left untouched.
var _shapes_driven: bool = false
## Legacy mode only: capsule centre measured from the mounted mesh at factor 1 (Vector3) or null.
var _legacy_capsule_center: Variant = null
var _visual_base_scale: Vector3 = Vector3.ONE
var _visual_fit_scale: Vector3 = Vector3.ONE
var _visual_fitted: bool = false
## Placeholder re-centre (B19): bottom-centre of the rest-pose AABB in Visual-local space.
var _visual_recentre: bool = false
var _visual_pivot_local: Vector3 = Vector3.ZERO
## Species already reported by the once-per-session body-dimension logs (keyed "kind:species").
static var _logged_once: Dictionary = {}
static var _fallback_margins: Dictionary = {}
var caloric_needs: int = 30
var current_calories: float = 30.0
## Stable per-instance identity for logs/debugging (distinct from `definition.species_id`, which is
## shared by every creature of that species) — set once in `_ready()` from `get_instance_id()`.
var creature_instance_id: int = 0

## PHYSICS_SQUEEZE.md §3 decision 25 (2026-09-18): whether the most recent [method
## apply_horizontal_move_intent] call had its horizontal velocity zeroed by [method
## _clamp_velocity_to_ghost_fit] (a real, non-escaping ghost-layer overlap) — read by
## [LocomotionExecutor]'s blocked-detection, which otherwise only sees real physics-layer contact
## (`is_on_wall()`) and has no visibility into this query-only layer at all.
var _last_ghost_layer_blocked: bool = false

var _food_intake_policy: Resource
var _starvation_fired: bool = false
var _calorie_baseline_drain_per_sec: float = 1.0
var _calorie_cost_per_unit_moved: float = 0.002
var _defeat_hidden: bool = false
var _wall_slide_away_hint: Vector3 = Vector3.ZERO
## When true, ENGINE/AI calorie burn is owned by V3 [method apply_action] / [LocomotionExecutor] (§7.5).
var _use_v3_action_calories: bool = false
## When true, V3 [code]CreatureMotorStack[/code] owns ENGINE/AI [method _physics_process] motion (§7.4).
var _motor_stack_drives_physics: bool = false


func _ready() -> void:
  creature_instance_id = get_instance_id()
  control_mode = _ControlMode.engine_as_int()
  _apply_definition_defaults()
  _sync_calories_from_vitals()
  _refresh_calorie_burn_params()
  _apply_physics_layers()
  _connect_mob_hitbox()


func _resolve_definition() -> Variant:
  var local_def: Variant = get("definition")
  if local_def != null and local_def.get_script() == _DefScript:
    return local_def
  var p := get_parent()
  if p:
    var pd: Variant = p.get("definition")
    if pd != null and pd.get_script() == _DefScript:
      return pd
  return null


func _resolve_locomotion() -> Variant:
  var def: Variant = _resolve_definition()
  if def != null:
    var lp: Variant = def.get("locomotion_profile")
    if lp != null:
      return lp
  return _LocoProfile.new()


func _vitals_node() -> Node:
  var p := get_parent()
  if p == null:
    return null
  return p.get_node_or_null("Vitals")


func _sync_calories_from_vitals() -> void:
  var vit := _vitals_node()
  if vit != null:
    var cc: Variant = vit.get("current_calories")
    if typeof(cc) == TYPE_FLOAT or typeof(cc) == TYPE_INT:
      current_calories = float(cc)


func _apply_definition_defaults() -> void:
  var def: Variant = _resolve_definition()
  if def == null:
    _food_intake_policy = _DietRegistry.default_food_intake_policy(
      _CreatureDefinition.FeedingMode.HERBIVORE
    )
    return
  var cap: Variant = def.get("caloric_needs")
  if cap != null:
    caloric_needs = int(cap)
    current_calories = float(caloric_needs)
  _cache_baseline_geometry(def)
  _refresh_shapes()
  var lp: Variant = def.get("locomotion_profile")
  if lp != null:
    speed = float(lp.get("max_speed"))
  _food_intake_policy = _DietRegistry.default_food_intake_policy(int(def.get("feeding_mode")))
  if int(def.get("feeding_mode")) == _CreatureDefinition.FeedingMode.CARNIVORE:
    is_hostile = true


## Caches authored geometry from [param def]: body_length / width / height when all are > 0, otherwise the
## deprecated creature_size / collision_capsule_* fallbacks. Resets the runtime size factor to 1.
func _cache_baseline_geometry(def: Variant) -> void:
  var ro: Variant = def.get("reach_override")
  _reach_override = 0.0 if ro == null else maxf(0.0, float(ro))
  _size_factor = 1.0
  _shapes_driven = true
  if _BodyDims.has_authored_dimensions(def):
    _legacy_dims = false
    _base_length = float(def.get("body_length"))
    _base_width = float(def.get("body_width"))
    _base_height = float(def.get("body_height"))
    _base_creature_size = _BodyDims.max_dimension(Vector3(_base_width, _base_height, _base_length))
    creature_size = _base_creature_size
    return
  _legacy_dims = true
  var sz_v: Variant = def.get("creature_size")
  var sz := 1.0 if sz_v == null else float(sz_v)
  if sz > 0.0:
    _base_creature_size = sz
    creature_size = sz
  var cr_v: Variant = def.get("collision_capsule_radius")
  var cr := 0.35 if cr_v == null else float(cr_v)
  var ch_v: Variant = def.get("collision_capsule_height")
  var ch := 1.2 if ch_v == null else float(ch_v)
  if cr > 0.0:
    _legacy_radius = cr
  if ch > 0.0:
    _legacy_height = ch


## Applies a runtime size buff / debuff (decision 5, M8): re-derives every shape from the live dimensions
## and re-fits the Visual. The CharacterBody3D is never scaled (M3).
## Params:
## - size: Target [member creature_size]; the uniform factor is [code]size / base creature size[/code].
func apply_effective_creature_size(size: float) -> void:
  if size <= 0.0 or _base_creature_size <= 0.0:
    return
  _size_factor = size / _base_creature_size
  creature_size = size
  _refresh_shapes()
  _refit_visual()


## Width margin from GameConfig ([code]get_width_margin[/code]); merge default when the autoload is absent.
func _width_margin() -> float:
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_width_margin"):
    return float(gc.call(&"get_width_margin"))
  return _fallback_margin("width_margin")


## Reach margin fraction from GameConfig ([code]get_reach_margin_fraction[/code]); merge default when absent.
func _reach_margin_fraction() -> float:
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_reach_margin_fraction"):
    return float(gc.call(&"get_reach_margin_fraction"))
  return _fallback_margin("reach_margin_fraction")


static func _fallback_margin(key: String) -> float:
  if _fallback_margins.is_empty():
    var d: Dictionary = _ConfigMerge.default_creature_motor_v3_params()
    _fallback_margins["width_margin"] = float(d.get("width_margin", 0.0))
    _fallback_margins["reach_margin_fraction"] = float(d.get("reach_margin_fraction", 0.0))
  return float(_fallback_margins.get(key, 0.0))


## Live body dimensions as [code]Vector3(width X, height Y, length Z)[/code] in game units (+Z forward):
## authored dimensions times the uniform size factor. In legacy mode (no authored dimensions) width and
## height are derived from the deprecated radius / height fields and length is creature_size.
func get_body_dimensions() -> Vector3:
  if _legacy_dims:
    var f := _size_factor
    var r := _legacy_radius * f
    var w := 2.0 * r / (1.0 + maxf(0.0, _width_margin()))
    return Vector3(w, _legacy_height * f, _base_creature_size * f)
  return Vector3(_base_width, _base_height, _base_length) * _size_factor


## Movement-capsule radius: [code]live_width / 2 * (1 + width_margin)[/code] (B5). Body-radius class
## consumers (path clearance, gap fit, ghost fit) use this.
func get_body_radius() -> float:
  if _legacy_dims:
    return _legacy_radius * _size_factor
  return _BodyDims.body_radius(_base_width * _size_factor, _width_margin())


## Reach extent: distance from the body centre along facing (B25): [code]reach_override * size_factor[/code]
## when the definition sets one, else [code]live_length * (0.5 + reach_margin_fraction)[/code].
func get_reach_extent() -> float:
  return _BodyDims.reach_extent(
    get_body_dimensions().z, _reach_margin_fraction(), _reach_override, _size_factor
  )


## Alias of [method get_body_radius] kept so older callers still compile.
func get_collision_capsule_radius() -> float:
  return get_body_radius()


## Capsule total height (Godot 4 semantics, B24): [code]max(live_height, 2 * body_radius)[/code].
func get_collision_capsule_height() -> float:
  return _BodyDims.capsule_height(get_body_dimensions().y, get_body_radius())


## PHYSICS_SQUEEZE.md §3 decision 30 (2026-09-21): public read for [method
## apply_horizontal_move_intent]'s own gravity scale, so a caller estimating this body's fall
## kinematics (the C10 airborne-invariant threshold's terrain-scaled buffer; later, jump-distance/
## fall-damage decisions) matches the actual physics instead of assuming a fixed 1.0.
func get_gravity_multiplier() -> float:
  return float(_resolve_locomotion().get("gravity_multiplier"))


## Default LoS ray origin height unless overridden in [code]creature_motor.los_eye_height[/code]:
## 0.9 x capsule height.
func get_los_eye_height() -> float:
  return get_collision_capsule_height() * 0.9


## Re-derives the body capsule and the legacy [code]MobHitbox[/code] capsule (1.15 x body radius, B21)
## from the live dimensions. The body's own scale is never touched (M3). Logs once per species when the
## capsule height had to clamp up to 2r (B14 / B24).
func _refresh_shapes() -> void:
  if not _shapes_driven:
    return
  var r := get_body_radius()
  var h := get_collision_capsule_height()
  if not _legacy_dims and _BodyDims.capsule_height_clamped(get_body_dimensions().y, r):
    _log_once(
      "clamp",
      "BodyDims capsule height clamped up to 2r species=%s height=%.2f r=%.2f" % [
        _species_label(), get_body_dimensions().y, r
      ],
    )
  var has_center := false
  var center := Vector3.ZERO
  if _legacy_dims:
    if _legacy_capsule_center != null:
      has_center = true
      center = (_legacy_capsule_center as Vector3) * _size_factor
  else:
    has_center = true
    center = Vector3(0.0, h * 0.5, 0.0)
  var body_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
  if body_col != null:
    var body_cap := CapsuleShape3D.new()
    body_cap.radius = r
    body_cap.height = h
    body_col.shape = body_cap
    if has_center:
      body_col.position = center
  var hit_col := get_node_or_null("MobHitbox/CollisionShape3D") as CollisionShape3D
  if hit_col != null:
    var hit_cap := CapsuleShape3D.new()
    hit_cap.radius = r * 1.15
    hit_cap.height = maxf(h, hit_cap.radius * 2.0)
    hit_col.shape = hit_cap
    if has_center:
      hit_col.position = center


func _species_label() -> String:
  var def: Variant = _resolve_definition()
  if def == null:
    return "unknown"
  return str(def.get("species_id"))


## Logs [param msg] once per (kind, species) per session (OLog hygiene: short, no PII).
## Params:
## - kind: Log category key for the once-per-species gate.
## - as_error: True routes to error level; otherwise info.
func _log_once(kind: String, msg: String, as_error: bool = false) -> void:
  var key := "%s:%s" % [kind, _species_label()]
  if _logged_once.has(key):
    return
  _logged_once[key] = true
  if as_error:
    _OLogSafe.error(msg, false, "BodyDims")
  else:
    _OLogSafe.info(msg, false, "BodyDims")


## Fits the mounted [param visual_root] to the authored dimensions and sizes the shapes (CREATURE_BODY_DIMENSIONS
## section 4.3). Measures the rest-pose AABB before any facing yaw; production = uniform fit on length applied
## to the Visual node only; placeholder = per-axis fit plus origin re-centre (bottom-centre of the scaled AABB
## on the body origin, kept through facing yaw). Logs a proportion warning / fail once per species.
## With no authored dimensions (legacy mode) the Visual is not stretched and the capsule centre follows the mesh.
## Params:
## - visual_root: Mounted [code]Visual[/code] child of this body (no collision).
## - placeholder: True when the pack's pack_resources.json flags the model as a placeholder (B19).
## Returns true when the mesh was measured and shapes applied.
func apply_visual_fit(visual_root: Node3D, placeholder: bool = false) -> bool:
  if visual_root == null:
    return false
  var saved_yaw := visual_root.rotation.y
  visual_root.rotation.y = 0.0
  _visual_base_scale = visual_root.scale
  _visual_fit_scale = Vector3.ONE
  _visual_recentre = false
  var m := _CreatureMeshFootprint.mesh_aabb_in_body_local(self, visual_root)
  var pivot_body: Vector3 = m.get("pivot_offset", Vector3.ZERO)
  var pivot_local := visual_root.transform.affine_inverse() * pivot_body
  visual_root.rotation.y = saved_yaw
  if not bool(m.get("valid", false)):
    return false
  if _legacy_dims:
    _legacy_capsule_center = m.get("center", Vector3.ZERO)
  else:
    var model_size: Vector3 = m.get("size", Vector3.ZERO)
    var live := Vector3(_base_width, _base_height, _base_length)
    _visual_fit_scale = _BodyDims.fit_scale(model_size, live, placeholder)
    _report_proportions(model_size, live, placeholder)
    if placeholder:
      _visual_recentre = true
      _visual_pivot_local = pivot_local
  _visual_fitted = true
  _refit_visual()
  _refresh_shapes()
  return true


## Logs the proportion verdict once per species. Production fail is an error-level art bug (still mounts,
## B8); placeholder deviation is always info-level (B13).
func _report_proportions(model_size: Vector3, live: Vector3, placeholder: bool) -> void:
  var tol := _BodyDims.load_tolerances()
  var report := _BodyDims.proportion_report(model_size, live, float(tol["warn"]), float(tol["fail"]))
  var level := int(report["level"])
  if level == _BodyDims.LEVEL_OK:
    return
  var is_fail := level == _BodyDims.LEVEL_FAIL and not placeholder
  var msg := "BodyFit %s species=%s axis=%s dev=%.0f%% model_whl=(%.2f,%.2f,%.2f) live_whl=(%.2f,%.2f,%.2f)" % [
    "FAIL" if is_fail else "warn", _species_label(), str(report["worst_axis"]),
    float(report["worst_dev"]) * 100.0,
    model_size.x, model_size.y, model_size.z, live.x, live.y, live.z,
  ]
  _log_once("fit", msg, is_fail)


## Re-applies the Visual scale ([code]base * fit * size_factor[/code]) and the placeholder re-centre.
func _refit_visual() -> void:
  if not _visual_fitted:
    return
  var visual := get_node_or_null("Visual") as Node3D
  if visual == null:
    return
  visual.scale = _visual_base_scale * _visual_fit_scale * _size_factor
  _apply_visual_pivot(visual)


## Placeholder re-centre: keeps the rest-pose AABB bottom-centre on the body origin for the Visual's
## current yaw and scale. No-op for production / legacy visuals.
func _apply_visual_pivot(visual: Node3D) -> void:
  if _visual_recentre:
    visual.position = -(visual.basis * _visual_pivot_local)


## PHYSICS_SQUEEZE.md §3 decision 33 (2026-09-21): the diet-role `+8` bit (carnivore-only real
## collision against the retired `plant_mob_block` layer) is retired — nothing in the project has
## been on real layer 8 since decision 25 migrated object-scale obstacles onto the query-only
## ghost layer (16), and `MotorPathClear.has_clear_contact_path`'s ghost-layer raycast (decision 28)
## already independently catches every case this bit used to gate. Both diet roles now share the
## same real mask (terrain only) — real-physics solidity no longer distinguishes predator/prey.
func _apply_physics_layers() -> void:
  if is_hostile:
    collision_layer = 4
    collision_mask = 1
  else:
    collision_layer = 2
    collision_mask = 1


func _connect_mob_hitbox() -> void:
  var hb := get_node_or_null("MobHitbox") as Area3D
  if hb == null:
    return
  if not hb.body_entered.is_connected(_on_mob_hitbox_body_entered):
    hb.body_entered.connect(_on_mob_hitbox_body_entered)


## Returns [enum CreatureDefinition.FeedingMode] for motor / diet registration.
func get_feeding_mode() -> int:
  var def: Variant = _resolve_definition()
  if def != null:
    return int(def.get("feeding_mode"))
  return _CreatureDefinition.FeedingMode.HERBIVORE


func get_food_intake_policy() -> Resource:
  if _food_intake_policy == null:
    _food_intake_policy = _DietRegistry.default_food_intake_policy(get_feeding_mode())
  return _food_intake_policy


func set_control_mode(mode: int) -> void:
  control_mode = mode


## AiDriver motor contract: [code]Vector3(x, 0, z)[/code] or legacy [code]Vector2(x, z)[/code] on the horizontal plane.
## @deprecated V3 ENGINE path — use [method apply_action] / [LocomotionExecutor] instead ([CREATURE_MOVEMENT_V3.md §7.4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func set_creature_move_intent(dir: Variant) -> void:
  var h := _MotorPlane.read_dir(dir, _MotorPlane.HORIZONTAL_ZERO)
  creature_move_intent = h if h.length_squared() > 1e-12 else Vector3.ZERO


## Sets initial duel facing from [method AiDriver._randomize_duel_spawn_facing].
func apply_duel_spawn_facing(facing: Variant) -> void:
  var h := _MotorPlane.read_dir(facing, _MotorPlane.HORIZONTAL_ZERO)
  if h.length_squared() > 1e-12:
    last_move_direction = h
    _sync_visual_facing()


## Biases [method _engine_heading_with_wall_slide] during flee/jeopardy (away from threat).
func set_wall_slide_away_hint(dir: Variant) -> void:
  _wall_slide_away_hint = _MotorPlane.read_dir(dir, _MotorPlane.HORIZONTAL_ZERO)


func clear_wall_slide_away_hint() -> void:
  _wall_slide_away_hint = Vector3.ZERO


func was_defeated_by_starvation() -> bool:
  return _starvation_fired


func add_calories_from_food(
  amount: int,
  food_anchor: Variant = Vector2.ZERO,
  stimulus_kind_id: StringName = &"",
) -> void:
  current_calories = _CreatureVitalsMath.add_food_clamped(current_calories, amount, caloric_needs)
  _push_calories_to_vitals()
  var anchor2 := Vector2.ZERO
  if typeof(food_anchor) == TYPE_VECTOR2:
    anchor2 = food_anchor as Vector2
  elif typeof(food_anchor) == TYPE_VECTOR3:
    anchor2 = _MotorPlane.from_vec3(food_anchor as Vector3)
  if anchor2 == Vector2.ZERO:
    return
  var cneed_f := maxf(1.0, float(caloric_needs))
  var seek_ceil := _seek_priority_food_ceiling()
  var insufficient := current_calories / cneed_f < seek_ceil
  if _motor_stack_drives_physics:
    var creature_root := get_parent()
    if creature_root != null and creature_root.has_method(&"notify_food_consumption_outcome"):
      creature_root.call(
        &"notify_food_consumption_outcome",
        anchor2,
        insufficient,
        stimulus_kind_id,
        amount,
      )
      return
  var ad := get_node_or_null("/root/AiDriver")
  if ad == null or not ad.has_method(&"notify_food_consumption_outcome"):
    return
  ad.call(&"notify_food_consumption_outcome", self, anchor2, insufficient)


func _seek_priority_food_ceiling() -> float:
  var seek_ceil := 0.80
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_v3_params"):
    seek_ceil = float(gc.get_creature_motor_v3_params().get("seek_priority_food_ceiling", seek_ceil))
  elif gc != null and gc.has_method(&"get_creature_motor_params"):
    seek_ceil = float(gc.get_creature_motor_params().get("seek_priority_food_ceiling", seek_ceil))
  return seek_ceil


func add_calories_from_prey(amount: int) -> void:
  current_calories = _CreaturePredationMath.apply_meal_to_predator(
    current_calories, caloric_needs, amount
  )
  _push_calories_to_vitals()


func _push_calories_to_vitals() -> void:
  var vit := _vitals_node()
  if vit != null:
    vit.set("current_calories", current_calories)


func _refresh_calorie_burn_params() -> void:
  _calorie_baseline_drain_per_sec = 1.0
  _calorie_cost_per_unit_moved = 0.002
  var gc := get_node_or_null("/root/GameConfig")
  if gc == null:
    return
  if _use_v3_action_calories and gc.has_method(&"get_creature_motor_v3_params"):
    var v3: Dictionary = gc.get_creature_motor_v3_params()
    _calorie_baseline_drain_per_sec = float(
      v3.get("calorie_baseline_drain_per_sec", _calorie_baseline_drain_per_sec)
    )
    return
  if gc.has_method(&"get_creature_motor_params"):
    var cm: Dictionary = gc.get_creature_motor_params()
    _calorie_baseline_drain_per_sec = float(
      cm.get("calorie_baseline_drain_per_sec", _calorie_baseline_drain_per_sec)
    )
    _calorie_cost_per_unit_moved = float(
      cm.get("calorie_cost_per_unit_moved", _calorie_cost_per_unit_moved)
    )


func _apply_calorie_drain_and_starvation(delta: float) -> void:
  if _defeat_hidden or _starvation_fired:
    return
  var dist_moved := Vector2(velocity.x, velocity.z).length() * delta
  var burn: float = _CreatureVitalsMath.burn_amount(
    _calorie_baseline_drain_per_sec,
    _calorie_cost_per_unit_moved,
    dist_moved,
    delta,
    1.0,
    1.0,
  )
  current_calories = maxf(0.0, current_calories - burn)
  _push_calories_to_vitals()
  _check_starvation_after_calorie_debit()


## Debits per-action V3 calorie cost ([CREATURE_MOVEMENT_V3.md §7.5](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func debit_action_calories(cost: float) -> void:
  if _defeat_hidden or _starvation_fired:
    return
  current_calories = maxf(0.0, current_calories - maxf(0.0, cost))
  _push_calories_to_vitals()
  _check_starvation_after_calorie_debit()


func _check_starvation_after_calorie_debit() -> void:
  if current_calories > 0.0:
    return
  _starvation_fired = true
  _apply_defeat_local()
  hit.emit(null)
  var main := get_tree().current_scene
  if main != null and main.has_method(&"end_round") and is_hostile:
    main.call(&"end_round", "starvation_carn_herb_win", "herbivore")


## Enables V3 per-action calorie debit; skips distance-based drain in [method _physics_process] for ENGINE/AI.
func set_use_v3_action_calories(enabled: bool) -> void:
  _use_v3_action_calories = enabled
  if enabled:
    _refresh_calorie_burn_params()


func use_v3_action_calories() -> bool:
  return _use_v3_action_calories


## When enabled, [code]CreatureMotorStack[/code] applies actions; body skips deprecated intent path (§7.4).
func set_motor_stack_drives_physics(enabled: bool) -> void:
  _motor_stack_drives_physics = enabled


func _resolve_creature_motor_v3_params(override: Dictionary) -> Dictionary:
  if not override.is_empty():
    return override
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_v3_params"):
    return gc.get_creature_motor_v3_params()
  return _ConfigMerge.default_creature_motor_v3_params()


## V3 locomotion entry — delegates to [LocomotionExecutor] (headless tests + future motor stack).
func apply_action(action: Variant, delta: float, motor_v3: Dictionary = {}) -> ActionOutcome:
  return _LocomotionExecutor.apply_action(
    self, action, delta, _resolve_creature_motor_v3_params(motor_v3)
  )


func _apply_defeat_local() -> void:
  _defeat_hidden = true
  visible = false
  var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs != null:
    cs.set_deferred("disabled", true)
  var hb_cs := get_node_or_null("MobHitbox/CollisionShape3D") as CollisionShape3D
  if hb_cs != null:
    hb_cs.set_deferred("disabled", true)


func try_grant_as_prey_to(predator: CharacterBody3D) -> bool:
  if _defeat_hidden or predator == null:
    return false
  if not predator.has_method(&"add_calories_from_prey"):
    return false
  var policy: Resource = _DietRegistry.food_intake_policy_for_body(predator)
  if policy == null or not _DietRegistry.node_is_valid_food_for_policy(self, policy):
    return false
  var meal := 5
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    meal = int(gc.get_creature_motor_params().get("predator_prey_meal_calories", meal))
  predator.call(&"add_calories_from_prey", meal)
  _apply_defeat_local()
  hit.emit(predator)
  return true


func _on_mob_hitbox_body_entered(_body: Node3D) -> void:
  ## D11 — contact predation retired; prey defeat via V3 [code]EAT[/code] only.
  return


func _motor_distance_scale() -> float:
  var main := get_tree().current_scene if is_inside_tree() else null
  return _MotorPlane.motor_distance_scale_for_main(main, screen_size)


func _footprint_half_for_clamp() -> Vector2:
  var gc := get_node_or_null("/root/GameConfig")
  var motor_p: Dictionary = {}
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    motor_p = gc.get_creature_motor_params()
  return _MotorPlane.footprint_half_extents(self, motor_p)


func _playfield_bounds_for_clamp() -> Dictionary:
  var bmax := playfield_bounds_max
  if bmax == Vector2.ZERO:
    bmax = screen_size
  return {"min": playfield_bounds_min, "max": bmax}


## V3 Step 3 pass-through until §12.2 **6a** restores wall-slide pick ([CREATURE_MOVEMENT_V3.md](Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func _engine_heading_with_wall_slide(heading: Vector3) -> Vector3:
  if heading.length_squared() < 1e-8:
    return heading
  return Vector3(heading.x, 0.0, heading.z).normalized()


## World-space HUMAN intent from motor-plane input ([code](right−left, down−up)[/code] action strengths).
## Params:
## - plane_input: [code]Vector2(move_right−move_left, move_down−move_up)[/code].
## Returns:
## - Normalized ground intent; [member _MotorPlane.HORIZONTAL_ZERO] when input is zero.
static func human_world_move_intent_from_plane_input(plane_input: Vector2) -> Vector3:
  if plane_input.length_squared() < 1e-8:
    return Vector3.ZERO
  return _MotorPlane.to_horizontal_vec3(plane_input.normalized())


func _read_move_intent() -> Vector3:
  if control_mode == _ControlMode.engine_as_int() or control_mode == _ControlMode.ai_as_int():
    return creature_move_intent
  var input := Vector2(
    Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
    Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
  )
  return human_world_move_intent_from_plane_input(input)


## Params:
## - intent: movement direction; **Y component is ignored** (flattened to XZ).
## - delta: physics step seconds.
func apply_horizontal_move_intent(intent: Vector3, delta: float) -> void:
  var loco: Variant = _resolve_locomotion()
  var max_spd := float(loco.get("max_speed"))
  var accel := float(loco.get("acceleration"))
  var fric := float(loco.get("friction"))
  var grav_mul := float(loco.get("gravity_multiplier"))
  var h := Vector3(intent.x, 0.0, intent.z)
  if h.length_squared() > 1.0 + 1e-6:
    h = h.normalized()
  var target := h * max_spd
  velocity.x = move_toward(velocity.x, target.x, accel * delta)
  velocity.z = move_toward(velocity.z, target.z, accel * delta)
  if h.length_squared() < 1e-8:
    velocity.x = move_toward(velocity.x, 0.0, fric * delta)
    velocity.z = move_toward(velocity.z, 0.0, fric * delta)
  if not is_on_floor():
    var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
    velocity.y -= g * grav_mul * delta
  _last_ghost_layer_blocked = _clamp_velocity_to_ghost_fit(delta)
  move_and_slide()


## PHYSICS_SQUEEZE.md §3 decision 25 (2026-09-18): read by [LocomotionExecutor] to fold a
## ghost-layer stop into its own blocked-detection — see [member _last_ghost_layer_blocked].
func was_ghost_layer_blocked_last_move() -> bool:
  return _last_ghost_layer_blocked


## PHYSICS_SQUEEZE.md decision 16 (2026-09-18): object-scale obstacles are query-only — never on
## any creature's real `collision_mask`, so `move_and_slide` alone never stops a body from walking
## straight through one. This is the live per-step gate that actually enforces per-instance fit:
## before committing this tick's move, shape-cast this body's own real capsule at where it's about
## to end up; if that overlaps the ghost layer, cancel the horizontal move so the body doesn't
## tunnel into geometry it doesn't fit through. A body whose capsule *does* fit takes no penalty
## here — Mode-B `movement_impact` slowdown (decision 16 §3) is a separate, not-yet-wired concern.
## Point-check at the tick's destination, not a full motion sweep (§8a's route scan is the
## sweep-based version, used ahead of time for candidate scoring, not here).
##
## §8e escape hatch (2026-09-18, added after a live repro): a creature that ends up overlapping a
## ghost-layer shape — confirmed live: an herbivore approaching `open_shrub_3d` to EAT, then
## getting trapped once the shrub's `MobBlocker` re-syncs its collision to the depleted-visual mesh
## right as eating completes (`bush_food_3d.gd`'s `_refresh_visual()`) — would otherwise never
## recover, since nearly every nearby destination still reads as "overlapping" once already inside.
## Before blocking, check whether the body is already overlapping the ghost layer at its *current*
## position; if so and this move doesn't get closer to whatever it's overlapping, allow it anyway.
##
## Returns true when this call actually zeroed horizontal velocity for a real, non-escaping
## overlap — decision 25 (2026-09-18): the caller ([method apply_horizontal_move_intent]) surfaces
## this via [member _last_ghost_layer_blocked] so [LocomotionExecutor] can fold it into its own
## blocked-detection, which otherwise never sees this query-only layer at all (`is_on_wall()` only
## reports real physics-layer contact).
func _clamp_velocity_to_ghost_fit(delta: float) -> bool:
  var world := get_world_3d()
  if world == null:
    return false
  var space_state := world.direct_space_state
  if space_state == null:
    return false
  var radius := get_collision_capsule_radius()
  var height := get_collision_capsule_height()
  var self_rid := [get_rid()]
  var next_pos := global_position + Vector3(velocity.x, 0.0, velocity.z) * delta
  var blocked := _GhostObstacleQuery.capsule_overlaps_ghost_layer(
    space_state, next_pos, radius, height, self_rid,
  )
  if not blocked:
    return false
  if _GhostObstacleQuery.escaping_overlap(space_state, global_position, next_pos, radius, height, self_rid):
    return false
  velocity.x = 0.0
  velocity.z = 0.0
  return true


## Snaps world XZ inside playfield AABB after movement (row 55 safety net).
## Returns true when [member global_position] XZ was adjusted.
func _clamp_playfield_position() -> bool:
  var half := _footprint_half_for_clamp()
  var pos2 := _MotorPlane.from_vec3(global_position)
  var bounds: Dictionary = _playfield_bounds_for_clamp()
  var bmin: Vector2 = bounds.get("min", Vector2.ZERO)
  var bmax: Vector2 = bounds.get("max", screen_size)
  if bmax == Vector2.ZERO or (bmax.x <= bmin.x and bmax.y <= bmin.y):
    return false
  var pos2_local := pos2 - bmin
  var bmax_local := bmax - bmin
  var clamped_local := _PlayfieldClamp.clamp_position(pos2_local, half, bmax_local, Vector2.ZERO)
  var clamped_world := clamped_local + bmin
  if not pos2.is_equal_approx(clamped_world):
    global_position = Vector3(clamped_world.x, global_position.y, clamped_world.y)
    return true
  return false


## Public playfield clamp for [code]CreatureMotorStack[/code]; returns whether position changed.
func clamp_playfield_position() -> bool:
  return _clamp_playfield_position()


func apply_jump_if_floor() -> void:
  var loco: Variant = _resolve_locomotion()
  var jv := float(loco.get("jump_velocity"))
  if is_on_floor():
    velocity.y = jv


## Picks HUMAN facing from horizontal displacement; uses velocity only when moving freely.
## Params:
## - pos_before: [code]global_position[/code] before [method apply_horizontal_move_intent].
## - pos_after: [code]global_position[/code] after [method CharacterBody3D.move_and_slide].
## - body_velocity: Body velocity after the move step.
## - blocked_by_wall: [method CharacterBody3D.is_on_wall] after the move step.
## - fallback_facing: Prior [member last_move_direction] when blocked with no displacement.
## Returns:
## - Normalized horizontal facing vector.
static func human_facing_after_move(
  pos_before: Vector3,
  pos_after: Vector3,
  body_velocity: Vector3,
  blocked_by_wall: bool,
  fallback_facing: Vector3,
) -> Vector3:
  var disp := pos_after - pos_before
  disp.y = 0.0
  if disp.length_squared() > 1e-10:
    return disp.normalized()
  var hvel := Vector3(body_velocity.x, 0.0, body_velocity.z)
  if hvel.length_squared() > 1e-8 and not blocked_by_wall:
    return hvel.normalized()
  if fallback_facing.length_squared() > 1e-12:
    return fallback_facing.normalized()
  return _MotorPlane.HORIZONTAL_RIGHT


## HUMAN facing after a horizontal move step: active intent wins; coasting uses displacement/velocity.
## Params:
## - intent: Move intent applied this tick.
## - pos_before: [code]global_position[/code] before [method apply_horizontal_move_intent].
## - pos_after: [code]global_position[/code] after [method CharacterBody3D.move_and_slide].
## - body_velocity: Body velocity after the move step.
## - blocked_by_wall: [method CharacterBody3D.is_on_wall] after the move step.
## - fallback_facing: Prior facing when coasting with no displacement/velocity signal.
## Returns:
## - Normalized horizontal facing vector.
static func human_facing_after_horizontal_move(
  intent: Vector3,
  pos_before: Vector3,
  pos_after: Vector3,
  body_velocity: Vector3,
  blocked_by_wall: bool,
  fallback_facing: Vector3,
) -> Vector3:
  var h := Vector3(intent.x, 0.0, intent.z)
  if h.length_squared() > 1e-8:
    return h.normalized()
  return human_facing_after_move(
    pos_before, pos_after, body_velocity, blocked_by_wall, fallback_facing
  )


func _apply_facing_after_horizontal_move(pos_before: Vector3, intent: Vector3) -> void:
  if control_mode == _ControlMode.human_as_int():
    last_move_direction = human_facing_after_horizontal_move(
      intent,
      pos_before,
      global_position,
      velocity,
      is_on_wall(),
      last_move_direction,
    )
    return
  var hvel := Vector3(velocity.x, 0.0, velocity.z)
  if hvel.length_squared() > 1e-8:
    last_move_direction = hvel.normalized()


## Rotates [code]Visual[/code] to match [member last_move_direction] (awareness cone facing); capsule stays axis-aligned.
func _sync_visual_facing() -> void:
  var visual := get_node_or_null("Visual") as Node3D
  if visual == null:
    return
  visual.rotation.y = (
    _MotorPlane.yaw_from_horizontal_dir(last_move_direction) + visual_yaw_offset_rad
  )
  _apply_visual_pivot(visual)


func _physics_process(delta: float) -> void:
  if _defeat_hidden:
    return
  # V3 stack owns facing + locomotion; legacy intent/velocity-facing must not run (§7.4).
  if _motor_stack_drives_physics:
    return
  var pos_before := global_position
  var intent := _read_move_intent()
  if control_mode == _ControlMode.engine_as_int() or control_mode == _ControlMode.ai_as_int():
    intent = _engine_heading_with_wall_slide(intent)
  apply_horizontal_move_intent(intent, delta)
  if control_mode == _ControlMode.engine_as_int() or control_mode == _ControlMode.ai_as_int():
    _clamp_playfield_position()
  _apply_facing_after_horizontal_move(pos_before, intent)
  _sync_visual_facing()
  _sync_calories_from_vitals()
  if _should_skip_v3_legacy_calorie_drain():
    return
  _apply_calorie_drain_and_starvation(delta)


func _should_skip_v3_legacy_calorie_drain() -> bool:
  if not _use_v3_action_calories:
    return false
  return (
    control_mode == _ControlMode.engine_as_int()
    or control_mode == _ControlMode.ai_as_int()
  )


func _process(_delta: float) -> void:
  if _defeat_hidden:
    return
  _sync_visual_facing()


## Resets duel spawn state (position set by parent).
func start_duel_spawn() -> void:
  _starvation_fired = false
  _defeat_hidden = false
  visible = true
  velocity = Vector3.ZERO
  current_calories = float(caloric_needs)
  _push_calories_to_vitals()
  _refresh_calorie_burn_params()
  var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs != null:
    cs.disabled = false
  var hb_cs := get_node_or_null("MobHitbox/CollisionShape3D") as CollisionShape3D
  if hb_cs != null:
    hb_cs.disabled = false
