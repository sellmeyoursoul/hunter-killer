extends RefCounted
class_name StatMath
## Stat baseline (1-25 authored table, >25 asymptotic extrapolation) → point-pool conversion
## ([SHARED_STATTOPOINT_PLAN.md](../Project_Docs/Draft_Features/SHARED_STATTOPOINT_PLAN.md)).

const _TABLE := [
  132.82, 158.62, 187.29, 219.15, 254.54, 293.87, 337.56, 386.11, 440.06, 500.00,
  559.94, 613.89, 662.44, 706.13, 745.46, 780.85, 812.71, 841.38, 867.18, 890.40,
  911.30, 930.11, 947.04, 962.28, 975.99,
]
const _EXTRAPOLATE_BASE_MODIFIER := 13.71


## Max point pool for [param stat_num] — table lookup for 1..25, asymptotic loop beyond
## (diminishing per-point gains, never plateauing). Values below 1 clamp to the stat-1 entry.
static func stat_to_point(stat_num: int) -> float:
  var clamped := maxi(1, stat_num)
  if clamped <= _TABLE.size():
    return _TABLE[clamped - 1]
  var points: float = _TABLE[_TABLE.size() - 1]
  var modifier := _EXTRAPOLATE_BASE_MODIFIER
  var diff := clamped - _TABLE.size()
  while diff > 0:
    points += modifier * 0.9
    modifier -= modifier * 0.1
    diff -= 1
  return points
