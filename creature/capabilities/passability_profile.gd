extends RefCounted
## Per-creature passability data for navigation (NAVIGATION_PASSABILITY_PLAN.md section 8 Phase 0 (a), D6 / D7).
## Pure data plus accessors: every field is DERIVED from the live body, nothing is authored per creature or
## species, and no navigation queries live here. Build with [method from_body]; the body caches the result
## ([code]CreatureKinematicBody3D.get_passability_profile()[/code]).

## Capability bits (D6): reserved extension points; nothing sets them yet.
const CAP_NONE := 0
const CAP_CLIMB := 1
const CAP_SWIM := 2

## Class default step-up height (game units) used when the body exposes no usable [code]floor_snap_length[/code].
## Single place for this fallback.
const DEFAULT_MAX_CLIMB := 0.15
## Class default slope limit (radians, ~45 degrees) used when the body exposes no [code]floor_max_angle[/code].
const DEFAULT_MAX_SLOPE := 0.7853981633974483
## Default creature weight (arbitrary units) until the definition grows a weight / mass field (none today).
const DEFAULT_WEIGHT := 1.0
## Single placeholder size class id. Layer 1's size -> class lookup does not exist until Phase 1.
const DEFAULT_SIZE_CLASS := &"default"

## Movement-capsule radius ([code]get_body_radius()[/code]).
var radius: float = 0.0
## Capsule total height.
var height: float = 0.0
## B11 creature size (max live body dimension); input to B17 class membership.
var creature_size: float = 0.0
## Highest step the body can climb (game units).
var max_climb: float = DEFAULT_MAX_CLIMB
## Steepest walkable slope (radians), from the body's [code]floor_max_angle[/code].
var max_slope: float = DEFAULT_MAX_SLOPE
## Body weight (crush class input, D6).
var weight: float = DEFAULT_WEIGHT
## Bitmask of [constant CAP_CLIMB] / [constant CAP_SWIM]; reserved, 0 today.
var capabilities: int = CAP_NONE


## Builds a profile from [param body] (a CreatureKinematicBody3D); null yields an all-default profile.
## Derivation: radius / height / size from live body dimensions; max_slope from [code]floor_max_angle[/code];
## max_climb from [code]floor_snap_length[/code] when > 0 else [constant DEFAULT_MAX_CLIMB]; weight from the
## definition's [code]weight[/code] field when present and > 0 else [constant DEFAULT_WEIGHT].
static func from_body(body: Object) -> RefCounted:
  var p = new()
  if body == null:
    return p
  p.radius = float(body.call(&"get_body_radius"))
  p.height = float(body.call(&"get_collision_capsule_height"))
  p.creature_size = float(body.get("creature_size"))
  var ang_v: Variant = body.get("floor_max_angle")
  if ang_v != null and float(ang_v) > 0.0:
    p.max_slope = float(ang_v)
  var snap_v: Variant = body.get("floor_snap_length")
  if snap_v != null and float(snap_v) > 0.0:
    p.max_climb = float(snap_v)
  var def: Variant = body.call(&"_resolve_definition")
  if def != null:
    var w_v: Variant = def.get("weight")
    if w_v != null and float(w_v) > 0.0:
      p.weight = float(w_v)
  return p


## True when every bit of [param cap] is set in [member capabilities].
func has_capability(cap: int) -> bool:
  return cap != 0 and (capabilities & cap) == cap


## Placeholder size-class id (D7: derived at runtime, never authored). Always [constant DEFAULT_SIZE_CLASS]
## until Phase 1 adds the Layer 1 size -> class lookup against the config class table; callers should not
## assume more than one class exists yet.
func size_class_key() -> StringName:
  return DEFAULT_SIZE_CLASS
