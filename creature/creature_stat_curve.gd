extends RefCounted
class_name CreatureStatCurve
## Shared stat → 0..1 quality curve: steep early climb, flattening but never plateauing —
## `saturating(stat, anchor_stat, anchor_value)` pins the curve's value at [param anchor_stat]
## to [param anchor_value] and asymptotically approaches [code]1.0[/code] beyond it, so every
## additional point still adds a little value, just ever less (2026-09-12 concealment-rest
## design review). Distinct from [StatMath]'s point-pool table — this is a generic normalized
## multiplier curve usable for any stat-driven gameplay scalar, not a pool sizing conversion.


## Normalized [code]0..1[/code] curve value for [param stat_num], pinned so
## [code]saturating(anchor_stat, anchor_stat, anchor_value) == anchor_value[/code].
static func saturating(stat_num: float, anchor_stat: float = 10.0, anchor_value: float = 0.75) -> float:
  var stat := maxf(0.0, stat_num)
  var anchor := maxf(1e-6, anchor_stat)
  var target := clampf(anchor_value, 1e-6, 1.0 - 1e-6)
  return 1.0 - pow(1.0 - target, stat / anchor)
