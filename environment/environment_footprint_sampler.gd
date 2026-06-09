## Footprint vs environment grid sampling (≥25% cell overlap — ENVIRONMENT_MODEL §11).
class_name EnvironmentFootprintSampler
extends RefCounted

const _EnvGrid := preload("res://environment/environment_grid_baked.gd")
const _EnvCell := preload("res://environment/environment_cell_data.gd")
const _Merge := preload("res://environment/environment_movement_impact.gd")

const MIN_OVERLAP_FRACTION := 0.25


## Circle–axis-aligned-cell overlap fraction in XZ (world meters).
static func circle_cell_overlap_fraction(
  center: Vector2,
  radius: float,
  cell_origin: Vector2,
  cell_size: float,
) -> float:
  if radius <= 0.0 or cell_size <= 0.0:
    return 0.0
  var cell_min := cell_origin
  var cell_max := cell_origin + Vector2(cell_size, cell_size)
  var closest := Vector2(
    clampf(center.x, cell_min.x, cell_max.x),
    clampf(center.y, cell_min.y, cell_max.y),
  )
  var dist_sq := center.distance_squared_to(closest)
  if dist_sq >= radius * radius:
    return 0.0
  var r2 := radius * radius
  if closest == cell_min or closest == cell_max:
    return minf(1.0, (r2 - dist_sq) / (cell_size * cell_size))
  return 1.0


## Collects [EnvironmentCellData] layers for cells overlapping [param footprint_radius] by ≥25%.
static func overlapping_cell_layers(
  grid: EnvironmentGridBaked,
  center_world: Vector2,
  footprint_radius: float,
  min_overlap: float = MIN_OVERLAP_FRACTION,
) -> Array:
  var out: Array = []
  if grid == null or not grid.is_valid_shape() or footprint_radius <= 0.0:
    return out
  var cs := grid.cell_size
  var min_cx := int(floor((center_world.x - footprint_radius - grid.origin_world.x) / cs))
  var max_cx := int(floor((center_world.x + footprint_radius - grid.origin_world.x) / cs))
  var min_cy := int(floor((center_world.y - footprint_radius - grid.origin_world.y) / cs))
  var max_cy := int(floor((center_world.y + footprint_radius - grid.origin_world.y) / cs))
  for cy in range(maxi(0, min_cy), mini(grid.cell_height, max_cy + 1)):
    for cx in range(maxi(0, min_cx), mini(grid.cell_width, max_cx + 1)):
      var cell_origin := grid.origin_world + Vector2(float(cx) * cs, float(cy) * cs)
      var frac := circle_cell_overlap_fraction(center_world, footprint_radius, cell_origin, cs)
      if frac < min_overlap:
        continue
      var data := grid.get_cell_data(cx, cy)
      if data is EnvironmentCellData:
        out.append(data)
  return out


## Merged environment at [param world_pos] using footprint overlap (not center-cell only).
static func merged_env_at_footprint(
  grid: EnvironmentGridBaked,
  world_pos: Vector3,
  footprint_radius: float,
) -> EnvironmentCellData:
  var center := Vector2(world_pos.x, world_pos.z)
  var layers := overlapping_cell_layers(grid, center, footprint_radius)
  if layers.is_empty():
    return null
  return _Merge.merge_greatest_impact(layers)
