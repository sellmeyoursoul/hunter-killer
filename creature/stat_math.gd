extends RefCounted
class_name StatMath
## Stat baseline (1-25 authored table, >25 asymptotic extrapolation) → point-pool conversion
## ([SHARED_STATTOPOINT_PLAN.md](../Project_Docs/Completed_Features/SHARED_STATTOPOINT_PLAN.md)).
##
## **The project's one stat-curve convention (2026-09-15):** this table's *shape* (huge 1-10
## growth, moderate 11-25, diminishing-but-never-plateauing beyond) is also the reference curve
## for every other stat-driven gameplay scalar, via [method peg_curve] below — not just pool
## sizing. A prior single-anchor alternative (`CreatureStatCurve.saturating`) was retired: it could
## only pin one reference value plus implicit 0/1 asymptotes, which turned out to be a strictly
## weaker special case of pinning three real values directly in the consumer's own units. Always
## peg stat 1, 10, and 25 explicitly when wiring a new stat-driven scalar — see dexterity's
## turn-rate curve and Composure/Observation's migration (CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9,
## 2026-09-15) for worked examples.

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


## Generic three-peg stat curve: same relative shape as [method stat_to_point] (steep 1-10,
## moderate 11-25, diminishing-never-plateauing 26+), remapped onto caller-chosen values at
## stat 1/10/25 — in the consumer's own units, not an abstract point pool or 0..1 fraction.
## [param v1]/[param v10]/[param v25] are hit exactly at those stat values; 2-9 and 11-24
## interpolate using each stat's own normalized position within [const _TABLE]'s matching segment
## (not a straight line — preserves the table's real curvature); 26+ extrapolates via the same
## decaying-modifier technique as [method stat_to_point] (next increment = the 24→25 segment's own
## increment, scaled into [param v25]'s units, decaying ×0.9 per additional point — converges to a
## finite ceiling it never reaches). Values below 1 clamp to the stat-1 entry.
static func peg_curve(stat_num: int, v1: float, v10: float, v25: float) -> float:
  var clamped := maxi(1, stat_num)
  if clamped <= 10:
    var frac: float = (_TABLE[clamped - 1] - _TABLE[0]) / (_TABLE[9] - _TABLE[0])
    return v1 + (v10 - v1) * frac
  if clamped <= _TABLE.size():
    var frac: float = (_TABLE[clamped - 1] - _TABLE[9]) / (_TABLE[_TABLE.size() - 1] - _TABLE[9])
    return v10 + (v25 - v10) * frac
  var last_frac: float = (_TABLE[23] - _TABLE[9]) / (_TABLE[_TABLE.size() - 1] - _TABLE[9])
  var value_at_24 := v10 + (v25 - v10) * last_frac
  var points := v25
  var modifier: float = v25 - value_at_24
  var diff := clamped - _TABLE.size()
  while diff > 0:
    points += modifier * 0.9
    modifier -= modifier * 0.1
    diff -= 1
  return points
