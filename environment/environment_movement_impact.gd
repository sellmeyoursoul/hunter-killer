## Greatest-impact-first merge for terrain / plant environment layers (M4).
## Bake-time and runtime use the same precedence: impassible beats slowdowns; highest [member EnvironmentCellData.movement_impact] wins.
class_name EnvironmentMovementImpact
extends RefCounted

const _EnvCell := preload("res://environment/environment_cell_data.gd")


## Merges [param layers] into one effective [EnvironmentCellData] cell.
## Params:
## - layers: Array of [EnvironmentCellData] or null entries.
## Returns:
## - New [EnvironmentCellData] with merged semantics, or null if [param layers] is empty.
static func merge_greatest_impact(layers: Array) -> EnvironmentCellData:
  var cells: Array[EnvironmentCellData] = []
  for raw in layers:
    if raw is EnvironmentCellData:
      cells.append(raw as EnvironmentCellData)
  if cells.is_empty():
    return null
  var out := EnvironmentCellData.new()
  out.passible = true
  out.movement_impact = 0.0
  out.fit_size = -1.0
  var best_slow := 0.0
  var has_solid := false
  var squeeze_fit := -1.0
  for e in cells:
    if not e.passible:
      has_solid = true
      var fs := e.fit_size
      if fs > 0.0 and not is_nan(fs):
        if squeeze_fit < 0.0 or fs < squeeze_fit:
          squeeze_fit = fs
    if e.is_movement_impact_active() and e.movement_impact > best_slow:
      best_slow = e.movement_impact
      out.fit_size = e.fit_size
      out.terrain_kind_id = e.terrain_kind_id
  if has_solid:
    out.passible = false
    if squeeze_fit > 0.0:
      out.fit_size = squeeze_fit
  out.movement_impact = best_slow
  return out


## Effective speed multiplier after merge at a footprint sample point.
static func movement_speed_multiplier_merged(layers: Array, creature_size: float) -> float:
  var merged := merge_greatest_impact(layers)
  if merged == null:
    return 1.0
  if not merged.can_enter(creature_size):
    return 0.0
  return merged.movement_speed_multiplier(creature_size)
