extends Object
class_name MotorWaypointChain
## Reusable multi-hop steering chain: turns a raw [code]NavigationServer3D.map_get_path[/code]
## route into a sparse waypoint list, and steps a creature through it one hop at a time — so a
## destination that's only reachable by curving around an obstacle doesn't get collapsed to its
## final point and driven at in a straight line (which clips the very obstacle the path routed
## around). [param target]/[method advance] leave the caller's own "ultimate destination" field
## (e.g. [code]step_ultimate_pos[/code]) untouched; this only governs the immediate steering point.


## Reduces [param path] to its interior bends plus the final point (drops the start point — a
## chain never targets "where I already am" — and any point collinear with its neighbors, so the
## controller isn't fed a fresh micro-turn at every navmesh triangle seam). A 0/1/2-point path
## passes through unchanged (already as sparse as it can be).
static func simplify(path: PackedVector3Array, collinear_dot: float = 0.995) -> PackedVector3Array:
  if path.size() <= 2:
    return path.duplicate()
  var out := PackedVector3Array()
  var prev: Vector3 = path[0]
  for i in range(1, path.size() - 1):
    var cur: Vector3 = path[i]
    var next: Vector3 = path[i + 1]
    var a := cur - prev
    var b := next - cur
    if a.length_squared() > 1e-6 and b.length_squared() > 1e-6:
      if a.normalized().dot(b.normalized()) < collinear_dot:
        out.append(cur)
        prev = cur
        continue
    # Collinear (or a degenerate zero-length leg) with the last kept point: drop `cur` and keep
    # comparing forward against `prev` unchanged, so a run of near-straight points collapses to
    # none of them rather than needing every consecutive pair to individually clear the test.
  out.append(path[path.size() - 1])
  return out


## Current immediate sub-target given [param chain]/[param index] and [param creature_pos];
## advances past any waypoints already within [param arrival_tolerance] (a chain never stalls on a
## hop the creature has effectively already reached). Returns
## [code]{"target": Vector3, "index": int, "done": bool}[/code] — [code]done[/code] once the
## returned target is the chain's last point. An empty chain returns [param creature_pos] itself
## with [code]done: true[/code] (nothing left to steer toward).
static func advance(
  chain: PackedVector3Array,
  index: int,
  creature_pos: Vector3,
  arrival_tolerance: float,
) -> Dictionary:
  if chain.is_empty():
    return {"target": creature_pos, "index": 0, "done": true}
  var idx := clampi(index, 0, chain.size() - 1)
  while idx < chain.size() - 1 and creature_pos.distance_to(chain[idx]) <= arrival_tolerance:
    idx += 1
  return {"target": chain[idx], "index": idx, "done": idx == chain.size() - 1}
