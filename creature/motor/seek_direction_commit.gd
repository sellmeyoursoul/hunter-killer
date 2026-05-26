## Wall-clock lock for active seek intents so chosen headings run stepwise for a full second.
extends Object


## Holds [param computed_normalized] for [param lock_sec] after each new non-idle pick while [param seek_active].
## Params:
## - computed_normalized: Fresh motor / override intent (unit vector or zero).
## - io_state: Per-body dict with [code]locked_intent[/code] and [code]locked_until_ms[/code].
## - lock_sec: Wall-clock hold duration (seconds); [code]0[/code] disables locking.
## - seek_active: When false, clears state and returns [param computed_normalized] unchanged.
## Returns:
## - Intent to apply this tick (locked direction until expiry, unless computed is idle).
static func filtered_seek_intent(
  computed_normalized: Vector2,
  io_state: Dictionary,
  lock_sec: float,
  seek_active: bool,
) -> Vector2:
  if not seek_active or lock_sec <= 0.0:
    io_state.clear()
    return computed_normalized
  if computed_normalized.length_squared() <= 25e-8:
    io_state.clear()
    return Vector2.ZERO
  var now_ms := Time.get_ticks_msec()
  var locked_until := int(io_state.get("locked_until_ms", -1))
  var locked_v: Variant = io_state.get("locked_intent", null)
  if typeof(locked_v) == TYPE_VECTOR2 and locked_until > now_ms:
    return locked_v as Vector2
  var lock_ms := int(maxf(0.0, lock_sec) * 1000.0)
  io_state["locked_intent"] = computed_normalized
  io_state["locked_until_ms"] = now_ms + lock_ms
  return computed_normalized


## Clears lock state (goal lost, flee, jeopardy, round end).
static func reset_state(io_state: Dictionary) -> void:
  io_state.clear()
