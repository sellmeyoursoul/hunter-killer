## Authoring preset for one environment **kind** (passibility, squeeze, shrub slowdown).
## Palette index PNGs for baking live under **res://art/env/** (project convention).
## Params are consumed by [method can_enter] and [method movement_speed_multiplier] per
## [OBJECT_AVOIDANCE_PLAN.md](../Project_Docs/OBJECT_AVOIDANCE_PLAN.md) §3.
class_name EnvironmentCellData
extends Resource

## When false, [member fit_size] gates squeeze entry (Mode A). When true, all sizes may enter.
@export var passible: bool = true

## Slowdown strength; **0.0** means inactive (spec `null`/`0`). Applied only via [method movement_speed_multiplier].
@export var movement_impact: float = 0.0

## Mode A ([member passible] false): **> 0** = inclusive squeeze **`creature_size <= fit_size`**; **<= 0** or NaN = nobody enters.
## Mode B ([member passible] true + active [member movement_impact]): **> 0** = small creatures exempt (**strict `creature_size < fit_size`**); else everyone pays impact.
## **< 0** = unset (treat as no valid shrub gate — everyone pays [member movement_impact] when impact is active).
@export var fit_size: float = -1.0

## Optional stable id for future experiential memory ([OBJECT_AVOIDANCE_PLAN.md](../Project_Docs/OBJECT_AVOIDANCE_PLAN.md) §10).
@export var terrain_kind_id: StringName = StringName()


## Whether [member movement_impact] is considered active for Mode B eligibility (§3.3).
func is_movement_impact_active() -> bool:
  var mi := movement_impact
  if is_nan(mi):
    return false
  return mi > 0.0


## Returns whether [param creature_size] may enter this cell (enterability only; §3.5).
## Params:
## - creature_size: Same units as [member fit_size].
## Returns:
## - True if [member passible] or squeeze allows this size; false if fully blocked or too large for squeeze.
func can_enter(creature_size: float) -> bool:
  if passible:
    return true
  var fs := fit_size
  if is_nan(fs) or fs <= 0.0:
    return false
  return creature_size <= fs


## Speed multiplier while **legally inside** this cell (§3.6). Uses **`1.0 - movement_impact`** when a penalty applies.
## Params:
## - creature_size: Same units as [member fit_size].
## Returns:
## - Multiplier in **[0, 1]** when penalized, or **1.0** when exempt / no impact.
func movement_speed_multiplier(creature_size: float) -> float:
  var mi := movement_impact
  if is_nan(mi) or mi <= 0.0:
    return 1.0
  if passible:
    var fs := fit_size
    if fs > 0.0 and not is_nan(fs) and creature_size < fs:
      return 1.0
    return maxf(0.0, 1.0 - mi)
  return maxf(0.0, 1.0 - mi)
