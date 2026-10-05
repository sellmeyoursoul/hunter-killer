extends RefCounted
class_name RoutePlausibilityScan
## Route plausibility scan ([PHYSICS_SQUEEZE.md](../../Project_Docs/Draft_Features/PHYSICS_SQUEEZE.md)
## §8a / decision 22). The shared navmesh's bake deliberately excludes the movement-inert "ghost"
## object-scale layer entirely (decision 22, §9 slice 1) — so a navmesh path is only a claim about
## open floor, never a claim that *this specific creature* can actually use all of it. This walks
## an already-computed navmesh path and finds the first point along it where a creature's own
## capsule can't clear a ghost-layer object, so a candidate route gets scored (or disqualified) on
## what a creature can actually do, not on what the species-blind navmesh thinks is open.
##
## Mode-B `movement_impact` slowdown merging (decision 16 §3) is deliberately not modeled here —
## no ghost-layer object in the game today carries any `movement_impact`/`EnvironmentCellData`
## data to merge (only the unrelated field-scale grid does); wire that in once such data exists
## rather than fabricating a value now.

const _GhostObstacleQuery := preload("res://creature/motor/ghost_obstacle_query.gd")


## [param path] holds body-origin (navmesh-surface / feet) points; [param centre_offset_y] is the
## occupant's capsule-centre height above its origin (`get_capsule_center_offset_y()`; `0.0` =
## centred capsule) and [param threat_centre_offset_y] the same for the threat capsule (a threat
## resting on the ground: `max(threat_height, 2 * threat_radius) / 2`). Returned `reach_point` /
## `path` stay in the same origin space as [param path] — the offset is applied only inside the sweep.
## Walks [param path] from its start, sweeping a capsule of [param radius]/[param height] along
## each segment against the ghost layer. Returns a Dictionary:
## - reach: world-unit distance travelable along the path before the first real blocker (or the
##   full path length when nothing blocks it).
## - reach_point: the world position at that distance.
## - blocked: true when a real blocker was found before the path's end.
## - path: [param path] truncated to end at [code]reach_point[/code] when blocked, or [param path]
##   unchanged otherwise — safe to feed straight back into a waypoint-chain builder.
## - start_overlap: `&"none"` (the capsule is clear at the path start), `&"escaping"` (it already overlaps the
##   ghost layer at the start but the first segment leads out of the overlap, so the scan proceeds from the
##   exit point; matches [method GhostObstacleQuery.escaping_overlap] / `_clamp_velocity_to_ghost_fit`, 8e) or
##   `&"blocked"` (overlapping and the first segment does not leave it: reach 0, `blocked` true). Needed
##   because `cast_motion` reports a capsule that already overlaps at the sweep start as fully clear
##   (decision 46 E); the same guard `ShelterEnclosureProbe` has (decision 33).
## - detour_forcing: true when [param threat_radius] > 0 and at least one segment within the
##   returned reach that [param radius] clears fully is NOT fully clear at [param threat_radius] —
##   decision 23 (§9 slice 10): an object this creature fits through but a specific pursuer doesn't.
##   Always false when [param threat_radius] <= 0 (the default — no threat to differentiate
##   against, e.g. every non-`avoid_hostiles` consumer of this scan).
static func scan_path(
  space_state: PhysicsDirectSpaceState3D,
  path: PackedVector3Array,
  radius: float,
  height: float,
  exclude_rids: Array = [],
  threat_radius: float = -1.0,
  threat_height: float = -1.0,
  centre_offset_y: float = 0.0,
  threat_centre_offset_y: float = 0.0,
) -> Dictionary:
  if path.size() < 2:
    var only: Vector3 = path[0] if path.size() > 0 else Vector3.ZERO
    return {
      "reach": 0.0, "reach_point": only, "blocked": false, "path": path, "detour_forcing": false,
      "start_overlap": &"none",
    }
  if space_state == null or radius <= 0.0:
    return {
      "reach": _path_length(path),
      "reach_point": path[path.size() - 1],
      "blocked": false,
      "path": path,
      "detour_forcing": false,
      "start_overlap": &"none",
    }
  var traveled := 0.0
  var detour_forcing := false
  var start := _start_overlap(space_state, path, radius, height, exclude_rids, centre_offset_y)
  var start_state: StringName = start["state"]
  if start_state == &"blocked":
    return {
      "reach": 0.0,
      "reach_point": path[0],
      "blocked": true,
      "path": PackedVector3Array([path[0], path[0]]),
      "detour_forcing": false,
      "start_overlap": &"blocked",
    }
  var escape_pending := start_state == &"escaping"
  for i in range(path.size() - 1):
    var a: Vector3 = path[i]
    var b: Vector3 = path[i + 1]
    var seg_len := a.distance_to(b)
    if seg_len < 1e-6:
      continue
    if escape_pending:
      escape_pending = false
      # Sweep from where the capsule first clears the overlap; the distance walked inside it still counts.
      var exit_d: float = start["exit_distance"]
      a = a.lerp(b, clampf(exit_d / seg_len, 0.0, 1.0))
      traveled += minf(exit_d, seg_len)
      seg_len = a.distance_to(b)
      if seg_len < 1e-6:
        continue
    var clear_frac := clampf(
      _GhostObstacleQuery.sweep_capsule_along_segment(
        space_state, a, b, radius, height, exclude_rids,
        _GhostObstacleQuery.GHOST_LAYER_MASK, centre_offset_y,
      ),
      0.0,
      1.0,
    )
    if clear_frac < 1.0 - 1e-6:
      var reach_point := a.lerp(b, clear_frac)
      traveled += seg_len * clear_frac
      var truncated := path.slice(0, i + 1)
      truncated.append(reach_point)
      return {
        "reach": traveled,
        "reach_point": reach_point,
        "blocked": true,
        "path": truncated,
        "detour_forcing": detour_forcing,
        "start_overlap": start_state,
      }
    if threat_radius > 0.0 and not detour_forcing:
      var threat_frac := clampf(
        _GhostObstacleQuery.sweep_capsule_along_segment(
          space_state, a, b, threat_radius, threat_height, exclude_rids,
          _GhostObstacleQuery.GHOST_LAYER_MASK, threat_centre_offset_y,
        ),
        0.0,
        1.0,
      )
      if threat_frac < 1.0 - 1e-6:
        detour_forcing = true
    traveled += seg_len
  return {
    "reach": traveled,
    "reach_point": path[path.size() - 1],
    "blocked": false,
    "path": path,
    "detour_forcing": detour_forcing,
    "start_overlap": start_state,
  }


## Start-of-sweep overlap pre-check for [method scan_path] (`cast_motion` cannot see an overlap that already
## exists at the sweep start). Returns `{state, exit_distance}`: `state` is `&"none"` when the capsule at
## `path[0]` is clear; `&"escaping"` when it overlaps but a short step along the first segment does not get
## closer to any overlapped shape ([method GhostObstacleQuery.escaping_overlap]) AND the capsule clears the
## overlap somewhere along that segment (`exit_distance` = distance from `path[0]` of the first clear sample,
## sampled at most 64 times); `&"blocked"` otherwise (also when escape cannot be confirmed within the segment).
## Points are body-origin (see [GhostObstacleQuery] point convention); [param centre_offset_y] lifts to the
## capsule centre. `escaping_overlap` is given capsule-centre points like the body's own gate: it compares
## centre-to-collider-origin distances, a monotone proxy for the horizontal approach/retreat decision.
static func _start_overlap(
  space_state: PhysicsDirectSpaceState3D,
  path: PackedVector3Array,
  radius: float,
  height: float,
  exclude_rids: Array,
  centre_offset_y: float,
) -> Dictionary:
  var none := {"state": &"none", "exit_distance": 0.0}
  var origin: Vector3 = path[0]
  if not _GhostObstacleQuery.capsule_overlaps_ghost_layer(
    space_state, origin, radius, height, exclude_rids, centre_offset_y
  ):
    return none
  var seg_end := origin
  for k in range(1, path.size()):
    if origin.distance_to(path[k]) > 1e-6:
      seg_end = path[k]
      break
  var seg_len := origin.distance_to(seg_end)
  var blocked := {"state": &"blocked", "exit_distance": 0.0}
  if seg_len < 1e-6:
    return blocked
  var dir := (seg_end - origin) / seg_len
  var centre_now := origin + Vector3.UP * centre_offset_y
  var probe_step := minf(seg_len, maxf(radius, 0.25))
  if not _GhostObstacleQuery.escaping_overlap(
    space_state, centre_now, centre_now + dir * probe_step, radius, height, exclude_rids, 0.0
  ):
    return blocked
  var sample_step := maxf(maxf(radius * 0.5, 0.1), seg_len / 64.0)
  var d := sample_step
  while d < seg_len + sample_step:
    var dd := minf(d, seg_len)
    if not _GhostObstacleQuery.capsule_overlaps_ghost_layer(
      space_state, origin + dir * dd, radius, height, exclude_rids, centre_offset_y
    ):
      return {"state": &"escaping", "exit_distance": dd}
    d += sample_step
  return blocked


static func _path_length(path: PackedVector3Array) -> float:
  var total := 0.0
  for i in range(path.size() - 1):
    total += path[i].distance_to(path[i + 1])
  return total
