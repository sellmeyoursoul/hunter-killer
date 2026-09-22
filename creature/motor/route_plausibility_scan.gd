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


## Walks [param path] from its start, sweeping a capsule of [param radius]/[param height] along
## each segment against the ghost layer. Returns a Dictionary:
## - reach: world-unit distance travelable along the path before the first real blocker (or the
##   full path length when nothing blocks it).
## - reach_point: the world position at that distance.
## - blocked: true when a real blocker was found before the path's end.
## - path: [param path] truncated to end at [code]reach_point[/code] when blocked, or [param path]
##   unchanged otherwise — safe to feed straight back into a waypoint-chain builder.
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
) -> Dictionary:
  if path.size() < 2:
    var only: Vector3 = path[0] if path.size() > 0 else Vector3.ZERO
    return {"reach": 0.0, "reach_point": only, "blocked": false, "path": path, "detour_forcing": false}
  if space_state == null or radius <= 0.0:
    return {
      "reach": _path_length(path),
      "reach_point": path[path.size() - 1],
      "blocked": false,
      "path": path,
      "detour_forcing": false,
    }
  var traveled := 0.0
  var detour_forcing := false
  for i in range(path.size() - 1):
    var a: Vector3 = path[i]
    var b: Vector3 = path[i + 1]
    var seg_len := a.distance_to(b)
    if seg_len < 1e-6:
      continue
    var clear_frac := clampf(
      _GhostObstacleQuery.sweep_capsule_along_segment(
        space_state, a, b, radius, height, exclude_rids
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
      }
    if threat_radius > 0.0 and not detour_forcing:
      var threat_frac := clampf(
        _GhostObstacleQuery.sweep_capsule_along_segment(
          space_state, a, b, threat_radius, threat_height, exclude_rids
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
  }


static func _path_length(path: PackedVector3Array) -> float:
  var total := 0.0
  for i in range(path.size() - 1):
    total += path[i].distance_to(path[i + 1])
  return total
