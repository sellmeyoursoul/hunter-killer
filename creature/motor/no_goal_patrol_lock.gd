## Holds a random or guided 8-way direction (or idle) while no motor goal is active ([Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md) §A.3.1).
extends Object

const _EightWay := preload("res://creature/motor/eight_way_directions.gd")


## Clears patrol lock state (driver calls when a goal surfaces or scripted motor resets).
static func reset_state(io_state: Dictionary) -> void:
  io_state.clear()


## Wall-clock hold aligned to one expanding-explore segment ([param segment_ticks] / physics rate), capped by [param cap_sec].
static func segment_lock_sec(segment_ticks: int, cap_sec: float = 1.0) -> float:
  var physics_hz := maxf(1.0, float(Engine.physics_ticks_per_second))
  var raw := float(maxi(1, segment_ticks)) / physics_hz
  return clampf(raw, 0.35, maxf(0.35, cap_sec))


## Picks or reuses a locked patrol intent when no actionable goal is present.
## Params:
## - io_state: Per-body mutable dict; stores [code]locked_intent[/code], [code]locked_until_ms[/code], [code]reroll_count[/code].
## - lock_sec: Wall-clock hold duration before a new random pick (seconds).
## - rng_seed: Mixed with [code]reroll_count[/code] for deterministic re-roll seeds.
## - is_blocked: Optional [code]Callable(Vector3) -> bool[/code]; when valid, only unblocked directions / idle are eligible.
## Returns:
## - Unit direction or [code]Vector3.ZERO[/code] (stay still).
static func pick_or_hold(
  io_state: Dictionary, lock_sec: float, rng_seed: int, is_blocked: Callable = Callable()
) -> Vector3:
  return pick_or_hold_guided(
    io_state, lock_sec, rng_seed, Vector3.ZERO, is_blocked, true
  )


## Guided patrol: prefer [param preferred_dir] when unblocked; else random unblocked pick.
## When [param allow_idle] is false, stay-still is excluded from the fallback pool.
static func pick_or_hold_guided(
  io_state: Dictionary,
  lock_sec: float,
  rng_seed: int,
  preferred_dir: Vector3,
  is_blocked: Callable = Callable(),
  allow_idle: bool = true,
) -> Vector3:
  var now_ms := Time.get_ticks_msec()
  var locked_until: int = int(io_state.get("locked_until_ms", -1))
  var locked_intent: Variant = io_state.get("locked_intent", null)
  if typeof(locked_intent) == TYPE_VECTOR3 and locked_until > now_ms:
    var held := locked_intent as Vector3
    if is_blocked.is_valid() and held.length_squared() > 1e-12 and bool(is_blocked.call(held)):
      io_state.erase("locked_until_ms")
      io_state.erase("locked_intent")
    else:
      return held

  var reroll := int(io_state.get("reroll_count", 0)) + 1
  io_state["reroll_count"] = reroll
  var rng := RandomNumberGenerator.new()
  rng.seed = maxi(1, absi(rng_seed ^ reroll))
  var picked: Vector3 = _pick_guided_unblocked(preferred_dir, rng, is_blocked, allow_idle)
  io_state["locked_intent"] = picked
  io_state["locked_until_ms"] = now_ms + int(maxf(0.0, lock_sec) * 1000.0)
  return picked


## Prefer normalized [param preferred_dir] when not blocked; else random from eligible pool.
static func _pick_guided_unblocked(
  preferred_dir: Vector3,
  rng: RandomNumberGenerator,
  is_blocked: Callable,
  allow_idle: bool,
) -> Vector3:
  if preferred_dir.length_squared() > 1e-12:
    var hint := preferred_dir.normalized()
    if not is_blocked.is_valid() or not bool(is_blocked.call(hint)):
      return hint
  return _pick_random_unblocked(rng, is_blocked, allow_idle)


## Random patrol option, optionally excluding directions [param is_blocked] marks true.
static func _pick_random_unblocked(
  rng: RandomNumberGenerator, is_blocked: Callable, allow_idle: bool = true
) -> Vector3:
  var options: Array[Vector3] = []
  for d in _EightWay.DIRECTIONS:
    options.append(d)
  if allow_idle:
    options.append(Vector3.ZERO)
  if not is_blocked.is_valid():
    return options[rng.randi_range(0, options.size() - 1)]
  var pool: Array[Vector3] = []
  for opt in options:
    if not bool(is_blocked.call(opt)):
      pool.append(opt)
  if pool.is_empty():
    return Vector3.ZERO
  return pool[rng.randi_range(0, pool.size() - 1)]
