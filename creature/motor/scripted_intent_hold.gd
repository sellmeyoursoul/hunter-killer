## Filters successive cardinal intents so fleeting cost flips do not jitter the creature ([Project_Docs/Completed_Features/MOB_AVOIDANCE_PLAN.md](../../Project_Docs/Completed_Features/MOB_AVOIDANCE_PLAN.md)).
extends Object


## Approximate equality for normalized cardinal or zero intents.
static func _intent_match(a: Vector3, b: Vector3, eps_sq: float = 25e-8) -> bool:
  return (a - b).length_squared() <= eps_sq


## Picks intent for this physics tick with **sticky hold**: a new cardinal must win for [param hold_physics_ticks] consecutive ticks before replacing the incumbent (idle counts as incumbent only when approximate zero).
## Params:
## - computed_normalized: Fresh output from `CardinalAvoidance.pick_best_move_intent` (already normalized/zero).
## - incumbent_normalized: Current `creature_move_intent` from the playable body ([code]Vector2.ZERO[/code] when idle).
## - hold_physics_ticks: Minimum consecutive ticks the challenger must persist (clamped to at least `1`).
## - io_state: Driver-owned dictionary; mutated with keys `challenger` ([code]Vector2[/code]), `frames` ([code]int[/code]); cleared when challenger resets.
## Returns:
## - Intent vector to pass to `set_creature_move_intent` this tick (normally same as incumbent until hold satisfied).
static func filtered_intent(
  computed_normalized: Vector3,
  incumbent_normalized: Vector3,
  hold_physics_ticks: int,
  io_state: Dictionary
) -> Vector3:
  var hold := maxi(1, hold_physics_ticks)
  ## Cold start / idle incumbent: obey motor immediately without waiting on a streak (feels responsive at round start).
  if incumbent_normalized.length_squared() <= 25e-8:
    io_state.clear()
    return computed_normalized
  if _intent_match(computed_normalized, incumbent_normalized):
    io_state.clear()
    return computed_normalized

  var ch: Variant = io_state.get("challenger", null)
  if typeof(ch) != TYPE_VECTOR3 or not _intent_match(computed_normalized, ch as Vector3):
    io_state["challenger"] = computed_normalized
    io_state["frames"] = 1
  else:
    io_state["frames"] = int(io_state["frames"]) + 1

  if int(io_state["frames"]) >= hold:
    io_state.clear()
    return computed_normalized
  return incumbent_normalized


## Clears challenger streak (driver calls when scripted motor path leaves scope or PLAYING stops).
static func reset_state(io_state: Dictionary) -> void:
  io_state.clear()
