extends Area2D
signal hit

@export var isHostile = false
@export var speed = 400 # How fast this creature moves (pixels/sec); human-held or scripted under same rules.
var screen_size # Size of the game window (playfield clamp rectangle).
var creature_move_intent: Vector2 = Vector2.ZERO ## Sticky direction when ENGINE or AI owns movement.
var current_velocity: Vector2 = Vector2.ZERO

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


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  screen_size = get_viewport_rect().size
  hide()


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


## Integrates this creature's movement each physics tick (human vs engine-held uses the same clamps).
## Params:
## - delta: Physics step duration in seconds.
## Returns / side effects:
## - Updates position, sprite animation, and current_velocity.
## Usage:
## - Godot callback; do not call directly from other scripts.
func _physics_process(delta: float) -> void:
  var intent := _read_move_intent()
  current_velocity = intent * float(speed)
  if current_velocity.length() > 0.0:
    $AnimatedSprite2D.play()
  else:
    $AnimatedSprite2D.stop()

  position += current_velocity * delta
  position = position.clamp(Vector2.ZERO, screen_size)

  if current_velocity.x != 0.0:
    $AnimatedSprite2D.animation = "walk"
    $AnimatedSprite2D.flip_v = false
    $AnimatedSprite2D.flip_h = current_velocity.x < 0.0
  elif current_velocity.y != 0.0:
    $AnimatedSprite2D.animation = "up"
    $AnimatedSprite2D.flip_v = current_velocity.y > 0.0


func _on_body_entered(body: Node2D) -> void:
  if body.get("isHostile"):
    hide() # Creature disappears after being hit.
    hit.emit()
    # Must be deferred as we can't change physics properties on a physics callback.
    $CollisionShape2D.set_deferred("disabled", true)


## Resets this creature's runtime state for a new round.
## Params:
## - pos: Spawn position in world space.
## Returns / side effects:
## - Repositions and enables collision, shows this creature node, clears velocity.
## Usage:
## - Called from Main.new_game().
func start(pos: Vector2) -> void:
  position = pos
  current_velocity = Vector2.ZERO
  show()
  $CollisionShape2D.disabled = false


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

# func game_over() -> void:
#	pass # Replace with function body.
