## Eight-way seek locomotion set (horizontal XZ: −Z = north).
extends Object

const SQ2 := 0.7071067811865476

const CARDINALS: Array[Vector3] = [
  Vector3(0.0, 0.0, -1.0),
  Vector3(1.0, 0.0, 0.0),
  Vector3(0.0, 0.0, 1.0),
  Vector3(-1.0, 0.0, 0.0),
]

const DIAGONALS: Array[Vector3] = [
  Vector3(SQ2, 0.0, -SQ2),
  Vector3(SQ2, 0.0, SQ2),
  Vector3(-SQ2, 0.0, SQ2),
  Vector3(-SQ2, 0.0, -SQ2),
]

## N, NE, E, SE, S, SW, W, NW — unit vectors for active seek scoring.
const SEEK_DIRECTIONS: Array[Vector3] = [
  Vector3(0.0, 0.0, -1.0),
  Vector3(SQ2, 0.0, -SQ2),
  Vector3(1.0, 0.0, 0.0),
  Vector3(SQ2, 0.0, SQ2),
  Vector3(0.0, 0.0, 1.0),
  Vector3(-SQ2, 0.0, SQ2),
  Vector3(-1.0, 0.0, 0.0),
  Vector3(-SQ2, 0.0, -SQ2),
]


## True when [param d] is a normalized diagonal (both axes significant).
static func is_diagonal(d: Vector3) -> bool:
  if d.length_squared() < 1e-12:
    return false
  var u := d.normalized()
  return absf(u.x) > 0.35 and absf(u.z) > 0.35


## Nearest seek direction to arbitrary [param d] (for override snap / tests).
static func snap_to_seek_direction(d: Vector3) -> Vector3:
  if d.length_squared() < 1e-12:
    return Vector3.ZERO
  var u := d.normalized()
  var best := Vector3.ZERO
  var best_dot := -INF
  for s in SEEK_DIRECTIONS:
    var dot := u.dot(s)
    if dot > best_dot:
      best_dot = dot
      best = s
  return best
