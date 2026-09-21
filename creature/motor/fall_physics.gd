extends RefCounted
class_name FallPhysics
## Shared free-fall kinematics (PHYSICS_SQUEEZE.md §3 decision 30). Currently backs the C10
## airborne-invariant's terrain-scaled threshold ([CreatureMotorStack]); kept as its own module
## rather than inlined there so a later mechanic that needs the same height/time relationship —
## a creature deciding whether to jump off a ledge, or a fall-damage estimate ("guaranteed small
## damage now vs. facing something lethal") — has one physically-consistent place to compute it
## instead of re-deriving or duplicating the math. Not wired into any decision-making yet.

const DEFAULT_GRAVITY := 9.8


## Physics ticks (at [param physics_fps]) for a body to free-fall [param height] meters from rest
## under [param gravity] — `d = 0.5*g*t^2` solved for t, rounded up to a whole tick. A real fall
## usually starts with some existing horizontal/vertical velocity and air resistance isn't modeled,
## so this is a slight underestimate of an actual in-game fall's duration, not an overestimate —
## callers needing a safety margin (e.g. the C10 invariant) should add their own buffer on top
## rather than treating this value alone as sufficient.
static func ticks_to_fall(height: float, gravity: float = DEFAULT_GRAVITY, physics_fps: float = 60.0) -> int:
  if height <= 0.0 or gravity <= 0.0 or physics_fps <= 0.0:
    return 0
  var seconds := sqrt(2.0 * height / gravity)
  return int(ceil(seconds * physics_fps))
