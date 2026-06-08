extends CharacterBody3D
## Kinematic 3D creature: **horizontal move intent** uses **X and Z only**; Y is ignored for steering.
## **Gravity and jump** are owned here so [code]AiDriver[/code] can stay thin (2D-style direction promoted to XZ).
## Motor bridge: [method set_creature_move_intent] accepts [code]Vector3[/code] or legacy [code]Vector2[/code] motor-plane intent.

signal hit

const _LocoProfile := preload("res://creature/definition/locomotion_profile.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")
const _DefScript := _CreatureDefinition
const _DietRegistry := preload("res://creature/capabilities/diet_registry.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _PlayfieldClamp := preload("res://creature/capabilities/playfield_clamp.gd")
const _SlidePickScr := preload("res://creature/motor/wall_slide_pick.gd")
const _CreatureVitalsMath := preload("res://creature/capabilities/creature_vitals_math.gd")
const _CreaturePredationMath := preload("res://creature/capabilities/creature_predation_math.gd")
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")

@export var definition: Variant
@export var is_hostile: bool = false
@export var obstacle_lookahead_px: float = 96.0

var creature_move_intent: Vector3 = Vector3.ZERO
var last_move_direction: Vector3 = _MotorPlane.HORIZONTAL_RIGHT
var control_mode: int = 0
var speed: float = 5.0
var screen_size: Vector2 = Vector2.ZERO
var playfield_bounds_min: Vector2 = Vector2.ZERO
var playfield_bounds_max: Vector2 = Vector2.ZERO
var creature_size: float = 1.0
var caloric_needs: int = 30
var current_calories: float = 30.0

var _food_intake_policy: Resource
var _starvation_fired: bool = false
var _calorie_baseline_drain_per_sec: float = 1.0
var _calorie_cost_per_px_moved: float = 0.002
var _defeat_hidden: bool = false
var _wall_slide_pick: RefCounted
var _wall_slide_away_hint: Vector3 = Vector3.ZERO


func _ready() -> void:
  control_mode = _ControlMode.engine_as_int()
  _apply_definition_defaults()
  _sync_calories_from_vitals()
  _refresh_calorie_burn_params()
  _apply_physics_layers()
  _connect_mob_hitbox()
  _wall_slide_pick = _SlidePickScr.new()


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
  var sz: Variant = def.get("creature_size")
  if sz != null:
    creature_size = float(sz)
  var lp: Variant = def.get("locomotion_profile")
  if lp != null:
    speed = float(lp.get("max_speed"))
  _food_intake_policy = _DietRegistry.default_food_intake_policy(int(def.get("feeding_mode")))
  if int(def.get("feeding_mode")) == _CreatureDefinition.FeedingMode.CARNIVORE:
    is_hostile = true


func _apply_physics_layers() -> void:
  if is_hostile:
    collision_layer = 4
    collision_mask = 9
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
func set_creature_move_intent(dir: Variant) -> void:
  var h := _MotorPlane.read_dir(dir, _MotorPlane.HORIZONTAL_ZERO)
  creature_move_intent = h if h.length_squared() > 1e-12 else Vector3.ZERO


## Sets initial duel facing from [method AiDriver._randomize_duel_spawn_facing].
func apply_duel_spawn_facing(facing: Variant) -> void:
  var h := _MotorPlane.read_dir(facing, _MotorPlane.HORIZONTAL_ZERO)
  if h.length_squared() > 1e-12:
    last_move_direction = h


## Biases [method _engine_heading_with_wall_slide] during flee/jeopardy (away from threat).
func set_wall_slide_away_hint(dir: Variant) -> void:
  _wall_slide_away_hint = _MotorPlane.read_dir(dir, _MotorPlane.HORIZONTAL_ZERO)


func clear_wall_slide_away_hint() -> void:
  _wall_slide_away_hint = Vector3.ZERO


func was_defeated_by_starvation() -> bool:
  return _starvation_fired


func add_calories_from_food(amount: int, food_anchor: Variant = Vector2.ZERO) -> void:
  current_calories = _CreatureVitalsMath.add_food_clamped(current_calories, amount, caloric_needs)
  _push_calories_to_vitals()
  var anchor2 := Vector2.ZERO
  if typeof(food_anchor) == TYPE_VECTOR2:
    anchor2 = food_anchor as Vector2
  elif typeof(food_anchor) == TYPE_VECTOR3:
    anchor2 = _MotorPlane.from_vec3(food_anchor as Vector3)
  if anchor2 == Vector2.ZERO:
    return
  var ad := get_node_or_null("/root/AiDriver")
  if ad == null or not ad.has_method(&"notify_food_consumption_outcome"):
    return
  var cneed_f := maxf(1.0, float(caloric_needs))
  var seek_ceil := 0.80
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    seek_ceil = float(gc.get_creature_motor_params().get("seek_priority_food_ceiling", seek_ceil))
  var insufficient := current_calories / cneed_f < seek_ceil
  ad.call(&"notify_food_consumption_outcome", self, anchor2, insufficient)


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
  _calorie_cost_per_px_moved = 0.002
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    var cm: Dictionary = gc.get_creature_motor_params()
    _calorie_baseline_drain_per_sec = float(cm.get("calorie_baseline_drain_per_sec", _calorie_baseline_drain_per_sec))
    _calorie_cost_per_px_moved = float(cm.get("calorie_cost_per_px_moved", _calorie_cost_per_px_moved))


func _apply_calorie_drain_and_starvation(delta: float) -> void:
  if _defeat_hidden or _starvation_fired:
    return
  var dist_moved := Vector2(velocity.x, velocity.z).length() * delta
  var burn: float = _CreatureVitalsMath.burn_amount(
    _calorie_baseline_drain_per_sec,
    _calorie_cost_per_px_moved,
    dist_moved,
    delta,
    1.0,
    1.0,
  )
  current_calories = maxf(0.0, current_calories - burn)
  _push_calories_to_vitals()
  if current_calories > 0.0:
    return
  _starvation_fired = true
  _apply_defeat_local()
  hit.emit()
  var main := get_tree().current_scene
  if main != null and main.has_method(&"end_round") and is_hostile:
    main.call(&"end_round", "starvation_carn_herb_win", "herbivore")


func _apply_defeat_local() -> void:
  _defeat_hidden = true
  visible = false
  var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
  if cs != null:
    cs.set_deferred("disabled", true)
  var hb_cs := get_node_or_null("MobHitbox/CollisionShape3D") as CollisionShape3D
  if hb_cs != null:
    hb_cs.set_deferred("disabled", true)


func _on_mob_hitbox_body_entered(body: Node3D) -> void:
  if is_hostile:
    return
  var hostile := false
  if body.get("is_hostile") != null:
    hostile = bool(body.get("is_hostile"))
  elif body.get("isHostile") != null:
    hostile = bool(body.get("isHostile"))
  if not hostile:
    return
  var meal := 5
  var gc := get_node_or_null("/root/GameConfig")
  if gc != null and gc.has_method(&"get_creature_motor_params"):
    meal = int(gc.get_creature_motor_params().get("predator_prey_meal_calories", meal))
  if body.has_method(&"add_calories_from_prey"):
    body.call(&"add_calories_from_prey", meal)
  _apply_defeat_local()
  hit.emit()


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


## Port of [method Player._engine_heading_with_wall_slide] for 3D physics + playfield edges.
func _engine_heading_with_wall_slide(heading: Vector3) -> Vector3:
  if heading.length_squared() < 1e-8:
    return heading
  var inc := Vector3(heading.x, 0.0, heading.z).normalized()
  var half := _footprint_half_for_clamp()
  var pos2 := _MotorPlane.from_vec3(global_position)
  var bounds: Dictionary = _playfield_bounds_for_clamp()
  var bmin: Vector2 = bounds.get("min", Vector2.ZERO)
  var bmax: Vector2 = bounds.get("max", screen_size)
  # Playfield clamp helpers expect a zero-origin AABB; translate world XZ into that space.
  var pos2_local := pos2 - bmin
  var bmax_local := bmax - bmin
  var dist_scale := _motor_distance_scale()
  var lookahead := maxf(obstacle_lookahead_px, 48.0) * dist_scale
  if _wall_slide_pick == null:
    return _MotorPlane.to_horizontal_vec3(
      _PlayfieldClamp.slide_heading_along_edge(
        _MotorPlane.from_vec3(inc),
        pos2_local,
        half,
        bmax_local,
        lookahead,
        _wall_slide_pick,
        _MotorPlane.from_vec3(_wall_slide_away_hint),
      )
    )
  var space := get_world_3d().direct_space_state
  if space == null:
    return _MotorPlane.to_horizontal_vec3(
      _PlayfieldClamp.slide_heading_along_edge(
        _MotorPlane.from_vec3(inc),
        pos2_local,
        half,
        bmax_local,
        lookahead,
        _wall_slide_pick,
        _MotorPlane.from_vec3(_wall_slide_away_hint),
      )
    )
  var origin := global_position
  var target := origin + inc * lookahead
  var query := PhysicsRayQueryParameters3D.create(origin, target)
  query.collision_mask = collision_mask
  query.exclude = [get_rid()]
  var ray_hit: Dictionary = space.intersect_ray(query)
  if ray_hit.is_empty():
    return _MotorPlane.to_horizontal_vec3(
      _PlayfieldClamp.slide_heading_along_edge(
        _MotorPlane.from_vec3(inc),
        pos2_local,
        half,
        bmax_local,
        lookahead,
        _wall_slide_pick,
        _MotorPlane.from_vec3(_wall_slide_away_hint),
      )
    )
  var normal_v: Variant = ray_hit.get("normal", Vector3.ZERO)
  if typeof(normal_v) != TYPE_VECTOR3:
    return _MotorPlane.to_horizontal_vec3(
      _PlayfieldClamp.slide_heading_along_edge(
        _MotorPlane.from_vec3(inc),
        pos2_local,
        half,
        bmax_local,
        lookahead,
        _wall_slide_pick,
        _MotorPlane.from_vec3(_wall_slide_away_hint),
      )
    )
  var n_raw := normal_v as Vector3
  var n_flat := Vector3(n_raw.x, 0.0, n_raw.z)
  var n := Vector3.ZERO
  if n_flat.length_squared() > 1e-8:
    n = n_flat.normalized()
  elif absf(n_raw.y) > 0.08:
    var ramp := Vector3(n_raw.x, 0.0, n_raw.z)
    if ramp.length_squared() > 1e-8:
      n = ramp.normalized()
  if n.length_squared() < 1e-12:
    return _MotorPlane.to_horizontal_vec3(
      _PlayfieldClamp.slide_heading_along_edge(
        _MotorPlane.from_vec3(inc),
        pos2_local,
        half,
        bmax_local,
        lookahead,
        _wall_slide_pick,
        _MotorPlane.from_vec3(_wall_slide_away_hint),
      )
    )
  n = n.normalized()
  if _wall_slide_away_hint.length_squared() > 1e-12:
    inc = _MotorPlane.to_horizontal_vec3(
      _wall_slide_pick.pick_tangent_away_from(
        _MotorPlane.from_vec3(inc),
        _MotorPlane.from_vec3(n),
        _MotorPlane.from_vec3(_wall_slide_away_hint),
      )
    )
  else:
    inc = _MotorPlane.to_horizontal_vec3(
      _wall_slide_pick.pick_tangent_closer(
        _MotorPlane.from_vec3(inc),
        _MotorPlane.from_vec3(n),
      )
    )
  return _MotorPlane.to_horizontal_vec3(
    _PlayfieldClamp.slide_heading_along_edge(
      _MotorPlane.from_vec3(inc),
      pos2_local,
      half,
      bmax_local,
      lookahead,
      _wall_slide_pick,
      _MotorPlane.from_vec3(_wall_slide_away_hint),
    )
  )


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
  move_and_slide()


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


func _physics_process(delta: float) -> void:
  if _defeat_hidden:
    return
  var pos_before := global_position
  var intent := _read_move_intent()
  if control_mode == _ControlMode.engine_as_int() or control_mode == _ControlMode.ai_as_int():
    intent = _engine_heading_with_wall_slide(intent)
  apply_horizontal_move_intent(intent, delta)
  _apply_facing_after_horizontal_move(pos_before, intent)
  _sync_calories_from_vitals()
  _apply_calorie_drain_and_starvation(delta)


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
