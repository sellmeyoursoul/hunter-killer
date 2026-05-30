## Holds a random 8-way direction or idle intent while no motor goal is active ([Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md) §A.3.1).
extends Object

const _MotorOctScr := preload("res://creature/motor/motor_oct_directions.gd")

const _EightWay := preload("res://creature/motor/eight_way_directions.gd")


## Clears patrol lock state (driver calls when a goal surfaces or scripted motor resets).
static func reset_state(io_state: Dictionary) -> void:
  io_state.clear()


## Picks or reuses a locked patrol intent when no actionable goal is present.
## Params:
## - io_state: Per-body mutable dict; stores [code]locked_intent[/code], [code]locked_until_ms[/code], [code]reroll_count[/code].
## - lock_sec: Wall-clock hold duration before a new random pick (seconds).
## - rng_seed: Mixed with [code]reroll_count[/code] for deterministic re-roll seeds.
## - is_blocked: Optional [code]Callable(Vector2) -> bool[/code]; when valid, only unblocked directions / idle are eligible.
## Returns:
## - Unit direction or [code]Vector2.ZERO[/code] (stay still).
static func pick_or_hold(
  io_state: Dictionary, lock_sec: float, rng_seed: int, is_blocked: Callable = Callable()
) -> Vector2:
  var now_ms := Time.get_ticks_msec()
  var locked_until: int = int(io_state.get("locked_until_ms", -1))
  var locked_intent: Variant = io_state.get("locked_intent", null)
  if typeof(locked_intent) == TYPE_VECTOR2 and locked_until > now_ms:
    return locked_intent as Vector2

  var reroll := int(io_state.get("reroll_count", 0)) + 1
  io_state["reroll_count"] = reroll
  var rng := RandomNumberGenerator.new()
  rng.seed = maxi(1, absi(rng_seed ^ reroll))
  var picked: Vector2 = _pick_random_unblocked(rng, is_blocked)
  io_state["locked_intent"] = picked
  io_state["locked_until_ms"] = now_ms + int(maxf(0.0, lock_sec) * 1000.0)
  return picked


## Random patrol option, optionally excluding directions [param is_blocked] marks true.
static func _pick_random_unblocked(rng: RandomNumberGenerator, is_blocked: Callable) -> Vector2:
  var options: Array[Vector2] = _EightWay.DIRECTIONS.duplicate()
  options.append(Vector2.ZERO)
  if not is_blocked.is_valid():
    return options[rng.randi_range(0, options.size() - 1)]
  var pool: Array[Vector2] = []
  for opt in options:
    if not bool(is_blocked.call(opt)):
      pool.append(opt)
  if pool.is_empty():
    return Vector2.ZERO
  return pool[rng.randi_range(0, pool.size() - 1)]
