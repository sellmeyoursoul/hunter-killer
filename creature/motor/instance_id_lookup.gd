extends RefCounted
## ObjectDB-safe lookups for instance ids carried in motor/memory dictionaries (scan entries,
## beliefs, threat samples, planner `step_instance_id`).
##
## Why this exists: Godot's `instance_from_id()` and `is_instance_id_valid()` both go through
## `ObjectDB::get_instance`, which raises an engine-level `Condition "slot >= slot_max"` error (not a
## silent null) whenever the id's slot bits point past the ObjectDB's allocated capacity. That can
## never happen for an id that came from a real `get_instance_id()` — slots are never shrunk, and a
## freed object's id resolves quietly to null — but it does happen for ids that were never ObjectDB
## ids at all: synthetic fixture ids (tests use small literals like `88050`), and the hash-derived
## ids some belief rows use as keys (`goal_belief_memory.gd`'s shelter-candidate/choke-point rows).
## Caveat: the validator pre-filter below only catches ids < 2^24. A 32-bit `hash()` id usually has
## nonzero bits 24..31, so it passes the filter and can still raise the engine error if resolved —
## harmless today because no call site resolves hash-id rows; tag or range-reserve them if one ever does.
##
## Every real ObjectDB id carries a nonzero validator in the bits above the slot field (the engine's
## validator counter skips 0 — see `ObjectDB::add_instance`), so an id whose validator field is 0 can
## be rejected without touching the ObjectDB at all. Layout (Godot 4.x `core/object/object.h`):
## bits 0..23 slot, bits 24..62 validator, bit 63 RefCounted flag.

const _SLOT_BITS := 24
const _VALIDATOR_MASK := (1 << 39) - 1


## True when [param instance_id] is shaped like a real ObjectDB id (nonzero validator field), i.e.
## it is safe to hand to `instance_from_id` without an engine error. Does not mean the object is
## still alive — a freed object's id still returns true here and resolves to null in [method resolve].
## Example: `can_be_object_id(88050)` is false; `can_be_object_id(node.get_instance_id())` is true.
static func can_be_object_id(instance_id: int) -> bool:
  if instance_id == 0:
    return false
  return ((instance_id >> _SLOT_BITS) & _VALIDATOR_MASK) != 0


## Returns the live Object for [param instance_id], or null when the id is 0, not ObjectDB-shaped
## (see [method can_be_object_id]), or refers to an object that has since been freed. Never raises
## an engine error — drop-in replacement for bare `instance_from_id` on dictionary-carried ids.
static func resolve(instance_id: int) -> Object:
  if not can_be_object_id(instance_id):
    return null
  return instance_from_id(instance_id)
