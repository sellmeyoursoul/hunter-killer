## Unit 8-way directions aligned with [BelievedGoalSector] indices (+Y = N).
class_name EightWayDirections
extends Object

const DIRECTION_COUNT: int = 8
const SQRT2_INV: float = 0.7071067811865475

## N, NE, E, SE, S, SW, W, NW — sector index 0..7 matches [method BelievedGoalSector.sector_index_for_step].
static var DIRECTIONS: Array[Vector2] = [
  Vector2(0.0, -1.0),
  Vector2(SQRT2_INV, -SQRT2_INV),
  Vector2(1.0, 0.0),
  Vector2(SQRT2_INV, SQRT2_INV),
  Vector2(0.0, 1.0),
  Vector2(-SQRT2_INV, SQRT2_INV),
  Vector2(-1.0, 0.0),
  Vector2(-SQRT2_INV, -SQRT2_INV),
]


## Picks the unit direction from [member DIRECTIONS] with highest dot product to [param world_dir].
static func best_aligned_to(world_dir: Vector2) -> Vector2:
  if world_dir.length_squared() < 1e-12:
    return Vector2.ZERO
  var u := world_dir.normalized()
  var best := DIRECTIONS[0]
  var best_dot := -INF
  for d in DIRECTIONS:
    var dot := u.dot(d)
    if dot > best_dot:
      best_dot = dot
      best = d
  return best
