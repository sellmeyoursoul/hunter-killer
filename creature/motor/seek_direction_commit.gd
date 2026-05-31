## Wall-clock lock for active seek intents so chosen headings run stepwise for a full second.
## When a new heading differs from current facing, rotates through the shortest 8-way arc first.
extends Object

const _TurnScr := preload("res://creature/motor/seek_direction_turn.gd")


## Holds [param computed_normalized] for [param lock_sec] after each new non-idle pick while [param seek_active].
## Params:
## - computed_normalized: Fresh motor / override intent (unit vector or zero).
## - io_state: Per-body dict with [code]locked_intent[/code], [code]locked_until_ms[/code], optional turn keys.
## - lock_sec: Wall-clock hold duration (seconds); [code]0[/code] disables locking.
## - seek_active: When false, clears state and returns [param computed_normalized] unchanged.
## - current_facing: Awareness / last-move heading used as turn start (normalized when turning).
## - turn_segment_ticks: Physics ticks per intermediate heading; [code]0[/code] skips turn sweep.
## - physics_tick: Monotonic physics tick for turn elapsed time.
## Returns:
## - Intent to apply this tick ([code]Vector2.ZERO[/code] while turning; locked direction until expiry).
static func filtered_seek_intent(
  computed_normalized: Vector2,
  io_state: Dictionary,
  lock_sec: float,
  seek_active: bool,
  current_facing: Vector2 = Vector2.RIGHT,
  turn_segment_ticks: int = 0,
  physics_tick: int = 0,
) -> Vector2:
  if not seek_active or lock_sec <= 0.0:
    io_state.clear()
    return computed_normalized
  if computed_normalized.length_squared() <= 25e-8:
    io_state.clear()
    return Vector2.ZERO
  var turn_target_v: Variant = io_state.get("turn_target", null)
  if typeof(turn_target_v) == TYPE_VECTOR2:
    var to_d := turn_target_v as Vector2
    var from_d: Vector2 = io_state.get("turn_from", current_facing) as Vector2
    var elapsed := maxi(0, physics_tick - int(io_state.get("turn_started_tick", physics_tick)))
    var turn_pick: Dictionary = Callable(_TurnScr, &"pick_turn_facing").call(
      from_d, to_d, turn_segment_ticks, elapsed
    )
    io_state["turn_facing"] = turn_pick["facing"]
    if bool(turn_pick.get("complete", false)):
      _clear_turn_keys(io_state)
      return _lock_new_intent(io_state, to_d, lock_sec)
    return Vector2.ZERO
  var now_ms := Time.get_ticks_msec()
  var locked_until := int(io_state.get("locked_until_ms", -1))
  var locked_v: Variant = io_state.get("locked_intent", null)
  if typeof(locked_v) == TYPE_VECTOR2 and locked_until > now_ms:
    return locked_v as Vector2
  var new_dir := computed_normalized
  if (
    turn_segment_ticks > 0
    and current_facing.length_squared() > 1e-12
    and Callable(_TurnScr, &"turn_steps_between").call(current_facing, new_dir) > 0
  ):
    io_state["turn_target"] = new_dir
    io_state["turn_from"] = current_facing.normalized()
    io_state["turn_started_tick"] = physics_tick
    var first_pick: Dictionary = Callable(_TurnScr, &"pick_turn_facing").call(
      current_facing, new_dir, turn_segment_ticks, 0
    )
    io_state["turn_facing"] = first_pick["facing"]
    return Vector2.ZERO
  return _lock_new_intent(io_state, new_dir, lock_sec)


## True when an arc turn is in progress ([code]turn_target[/code] set).
static func turn_in_progress(io_state: Dictionary) -> bool:
  return typeof(io_state.get("turn_target", null)) == TYPE_VECTOR2


## Current sweep facing during an in-progress turn; [param fallback] when idle.
static func turn_facing(io_state: Dictionary, fallback: Vector2 = Vector2.RIGHT) -> Vector2:
  var tf: Variant = io_state.get("turn_facing", null)
  if typeof(tf) == TYPE_VECTOR2:
    return tf as Vector2
  return fallback


## Clears lock state (goal lost, flee, jeopardy, round end).
static func reset_state(io_state: Dictionary) -> void:
  io_state.clear()


static func _lock_new_intent(io_state: Dictionary, intent: Vector2, lock_sec: float) -> Vector2:
  var lock_ms := int(maxf(0.0, lock_sec) * 1000.0)
  io_state["locked_intent"] = intent
  io_state["locked_until_ms"] = Time.get_ticks_msec() + lock_ms
  return intent


static func _clear_turn_keys(io_state: Dictionary) -> void:
  io_state.erase("turn_target")
  io_state.erase("turn_from")
  io_state.erase("turn_started_tick")
  io_state.erase("turn_facing")
