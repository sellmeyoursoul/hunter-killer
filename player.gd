extends CharacterBody2D
signal hit

@export var isHostile = false
@export var speed = 400 # How fast this creature moves (pixels/sec); human-held or scripted under same rules.
## Longest body dimension for OBJECT §3.5 / §3.6 (must be **<** mob [member Mob.creature_size] for squeeze/shrub asymmetry).
@export var creature_size: float = 26.0
## Upper bound for the hunger calorie pool this phase (HUNGER_AND_EATING §3 constants).
@export var caloric_needs: int = 10

var screen_size: Vector2 ## Size of the game window (playfield clamp rectangle).
## Current hunger calories; drains ~1/s while visible; starvation triggers Main.game_over.
var current_calories: float = 10.0
var _starvation_fired: bool = false
var creature_move_intent: Vector2 = Vector2.ZERO ## Sticky direction when ENGINE or AI owns movement.
var current_velocity: Vector2 = Vector2.ZERO ## Mirrors [member velocity] after integration for perception / HUD.
## Last non-zero movement direction (normalized), for motor cone awareness; unchanged while idle.
var last_move_direction: Vector2 = Vector2.RIGHT

enum ControlMode {
  HUMAN,
  ENGINE,
  AI,
}

var control_mode: ControlMode = ControlMode.HUMAN


## Stable int backing for [enum ControlMode.HUMAN]; use with [method Object.call] from autoload drivers.
static func human_control_as_int() -> int:
  return ControlMode.HUMAN


## Stable int backing for [enum ControlMode.ENGINE].
static func engine_control_as_int() -> int:
  return ControlMode.ENGINE


## Stable int backing for [enum ControlMode.AI].
static func ai_control_as_int() -> int:
  return ControlMode.AI


func _ready() -> void:
  add_to_group(&"player")
  screen_size = get_viewport_rect().size
  collision_layer = 2
  collision_mask = 1
  motion_mode = MOTION_MODE_FLOATING
  hide()


## Adds bush burst calories, clamping at [member caloric_needs]; overflow is discarded (hunger POC).
## Params:
## - amount: whole calories granted in one burst (typically bush [code]max_calories[/code]).
## Returns:
## - none
func add_calories_from_food(amount: int) -> void:
  current_calories = minf(float(caloric_needs), current_calories + float(max(amount, 0)))


## Drains hunger and ends the round at 0 calories via the same [code]game_over[/code] path as mob contact.
## Params:
## - delta: elapsed seconds since last frame.
## Returns:
## - none
func _process(delta: float) -> void:
  if not visible:
    return
  if _starvation_fired:
    return
  current_calories = maxf(0.0, current_calories - 1.0 * delta)
  if current_calories > 0.0:
    return
  _starvation_fired = true
  _apply_defeat_local()
  hit.emit()


## Computes movement intent from human [code]Input[/code] or sticky non-human intent ([enum ControlMode.ENGINE], [enum ControlMode.AI]).
## Params:
## - none
## Returns:
## - Normalized movement direction in local screen axes, or Vector2.ZERO.
## Usage:
## - Called by _physics_process() before integrating velocity.
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


## Half-extents of the primary [code]CollisionShape2D[/code] for viewport clamping (capsule max radius / half-height).
func _footprint_half_for_clamp() -> Vector2:
  var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs != null and cs.shape is CapsuleShape2D:
    var cap := cs.shape as CapsuleShape2D
    return Vector2(cap.radius, cap.radius + cap.height * 0.5)
  return Vector2(13.5, 30.5)


## Samples [method EnvironmentCellData.movement_speed_multiplier] at this body's position from Main's grid (OBJECT §3.6).
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
  var h := _footprint_half_for_clamp()
  position = position.clamp(
    Vector2(h.x, h.y),
    screen_size - h,
  )


## Integrates [method move_and_slide] each physics tick; applies terrain speed multiplier from the baked env grid.
## Params:
## - _delta: Physics step duration in seconds (reserved; movement uses velocity per tick, not delta scaling).
## Returns / side effects:
## - Updates [member velocity], position via slide, [member current_velocity], sprite animation, [member last_move_direction].
## Usage:
## - Godot callback; do not call directly from other scripts.
func _physics_process(_delta: float) -> void:
  var intent := _read_move_intent()
  var env_mult := _sample_movement_speed_multiplier()
  var target_speed := float(speed) * env_mult
  velocity = intent * target_speed
  move_and_slide()
  _clamp_to_playfield()

  current_velocity = velocity
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


## Hides the creature and disables collision shapes used during play (mob hit or starvation).
func _apply_defeat_local() -> void:
  hide()
  $CollisionShape2D.set_deferred("disabled", true)
  var hb := get_node_or_null("MobHitbox/CollisionShape2D") as CollisionShape2D
  if hb != null:
    hb.set_deferred("disabled", true)


## Mob overlap uses child [code]MobHitbox[/code] [Area2D] so the kinematic body does not need mob collision mask bits.
func _on_mob_hitbox_body_entered(body: Node2D) -> void:
  if body.get("isHostile"):
    _apply_defeat_local()
    hit.emit()


## Resets this creature's runtime state for a new round.
## Params:
## - pos: Spawn position in world space.
## Returns / side effects:
## - Repositions and enables collision, shows this creature node, clears velocity.
## Usage:
## - Called from Main.new_game().
func start(pos: Vector2) -> void:
  position = pos
  velocity = Vector2.ZERO
  current_velocity = Vector2.ZERO
  last_move_direction = Vector2.RIGHT
  current_calories = float(caloric_needs)
  _starvation_fired = false
  show()
  $CollisionShape2D.disabled = false
  var hb := get_node_or_null("MobHitbox/CollisionShape2D") as CollisionShape2D
  if hb != null:
    hb.disabled = false


## Sets exclusive control mode for movement source selection.
## Params:
## - mode: [enum ControlMode.HUMAN] (local input), [enum ControlMode.ENGINE] (scripted motor), or [enum ControlMode.AI] (LLM / TM via same intent API).
## Returns / side effects:
## - Switches intent source in [_read_move_intent].
## Usage:
## - Called by AiDriver as session state changes.
func set_control_mode(mode: ControlMode) -> void:
  control_mode = mode


## Updates sticky move intent used when [member control_mode] is [enum ControlMode.ENGINE] or [enum ControlMode.AI].
## Params:
## - dir: Intended direction vector (normalized or zeroed).
## Returns / side effects:
## - Stores [member creature_move_intent] for later physics ticks.
## Usage:
## - Called by AiDriver scripted motor or LLM token handlers.
func set_creature_move_intent(dir: Vector2) -> void:
  creature_move_intent = dir.normalized() if dir.length() > 0.0 else Vector2.ZERO
