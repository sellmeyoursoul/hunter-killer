## Shared goal visibility streak + engagement latch (predator prey / herbivore food cone-edge flicker).
extends RefCounted


## Increments per-body streak when [param visible_now]; returns true once [param required_ticks] consecutive visible ticks met.
static func streak_confirmed(
  io_streak_by_body: Dictionary, body_id: int, visible_now: bool, required_ticks: int
) -> bool:
  var need := maxi(1, required_ticks)
  if visible_now:
    var s := int(io_streak_by_body.get(body_id, 0)) + 1
    io_streak_by_body[body_id] = s
    return s >= need
  io_streak_by_body.erase(body_id)
  return false


## True while physics tick is before the latched engagement expiry.
static func engagement_active(
  engagement_by_body: Dictionary, body_id: int, physics_tick: int
) -> bool:
  var rec_v: Variant = engagement_by_body.get(body_id, null)
  if typeof(rec_v) != TYPE_DICTIONARY:
    return false
  return physics_tick < int((rec_v as Dictionary).get("until_tick", 0))


## Records engagement until [param physics_tick] + [param latch_ticks] and stores last visible target positions.
static func record_engagement(
  io_engagement_by_body: Dictionary,
  body_id: int,
  physics_tick: int,
  latch_ticks: int,
  positions: Array,
) -> void:
  if positions.is_empty():
    return
  io_engagement_by_body[body_id] = {
    "until_tick": physics_tick + maxi(1, latch_ticks),
    "positions": positions.duplicate(),
  }


## Merges latched positions into [param out_targets] when engagement is active.
static func merge_engagement_positions(
  engagement_by_body: Dictionary,
  body_id: int,
  physics_tick: int,
  out_targets: Array,
) -> bool:
  var rec_v: Variant = engagement_by_body.get(body_id, null)
  if typeof(rec_v) != TYPE_DICTIONARY:
    return false
  var rec: Dictionary = rec_v
  if physics_tick >= int(rec.get("until_tick", 0)):
    engagement_by_body.erase(body_id)
    return false
  var latched: Array = rec.get("positions", []) as Array
  if latched.is_empty():
    return false
  for p in latched:
    if typeof(p) != TYPE_VECTOR3:
      continue
    var p3 := p as Vector3
    var dup := false
    for existing in out_targets:
      if typeof(existing) == TYPE_VECTOR3 and (existing as Vector3).distance_squared_to(p3) < 64.0:
        dup = true
        break
    if not dup:
      out_targets.append(p3)
  return true
