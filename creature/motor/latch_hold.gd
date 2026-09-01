extends RefCounted
class_name LatchHold
## Shared hold/decrement/escalate/expire primitive for target-hold latches
## ([CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §4](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md)).
##
## Scaffolding only — not yet wired to any consumer. Scope is flee's and pursuit-detour's
## ticks-remaining + escalation-tier bookkeeping; the waypoint/target payload itself, and all
## goal-specific "am I stuck" / "how do I escalate" policy, stay caller-owned. Operates on the
## caller's own [param state] dict under [code]"<prefix>_ticks_remaining"[/code] and
## [code]"<prefix>_escalation_tier"[/code] keys so each consumer keeps its existing field names
## (e.g. [code]pursuit_detour_ticks_remaining[/code], [code]flee_waypoint_ticks_remaining[/code]
## once migrated) rather than forcing a shared nested-dict storage shape.

## True while the latch still has ticks remaining.
static func is_active(state: Dictionary, prefix: String) -> bool:
  return int(state.get(prefix + "_ticks_remaining", 0)) > 0


## (Re)starts the hold window; resets escalation back to tier 0.
static func start(state: Dictionary, prefix: String, ticks: int) -> void:
  state[prefix + "_ticks_remaining"] = maxi(1, ticks)
  state[prefix + "_escalation_tier"] = 0


## One tick of countdown. No-op past zero (caller decides what "expired" means).
static func decrement(state: Dictionary, prefix: String) -> void:
  state[prefix + "_ticks_remaining"] = int(state.get(prefix + "_ticks_remaining", 0)) - 1


## Advances the escalation tier by one. [param max_tier] < 0 means unbounded (flee's shape);
## [param max_tier] >= 0 caps it (pursuit-detour's shape) — once the next tier would exceed the
## cap, the tier is NOT stored and [code]gave_up[/code] comes back true so the caller can hard-clear
## instead of minting another escalation.
static func escalate(state: Dictionary, prefix: String, max_tier: int = -1) -> Dictionary:
  var tier := int(state.get(prefix + "_escalation_tier", 0)) + 1
  if max_tier >= 0 and tier > max_tier:
    return {"tier": tier, "gave_up": true}
  state[prefix + "_escalation_tier"] = tier
  return {"tier": tier, "gave_up": false}


## Resets ticks-remaining and escalation tier to their unarmed state. Caller still owns clearing
## its own waypoint/target payload fields.
static func clear(state: Dictionary, prefix: String) -> void:
  state[prefix + "_ticks_remaining"] = 0
  state[prefix + "_escalation_tier"] = 0
