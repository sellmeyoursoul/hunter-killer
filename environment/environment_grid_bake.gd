## Builds [EnvironmentGridBaked] from an [Image] palette map (OBJECT_AVOIDANCE_PLAN §8.1).
## Author palette PNGs live under **res://art/env/** (project convention).
## Each logical cell samples the **top-left** pixel of a **`pixels_per_cell` × `pixels_per_cell`** block.
class_name EnvironmentGridBake
extends RefCounted

const _Baked := preload("res://environment/environment_grid_baked.gd")


## Rasterizes [param image] into a baked grid.
## Params:
## - image: Authored map (nearest filter recommended). Size should be divisible by [param pixels_per_cell] (extra pixels truncated).
## - pixels_per_cell: Source pixels per logical cell edge (>= 1).
## - origin_world: World-space origin of cell (0,0)'s **top-left** corner.
## - cell_size: World size of one cell edge (often matches world meters per cell edge).
## - color_to_kind_id: Maps sampled [Color] (exact match after [method Image.get_pixel]) to kind id.
## - kind_presets: Dense array; id **i** references **kind_presets[i]**.
## - default_kind_id: Used when a pixel color is missing from [param color_to_kind_id].
## Returns:
## - New baked grid resource, or **null** if [param kind_presets] is empty or [param pixels_per_cell] < 1.
static func bake_from_image(
  image: Image,
  pixels_per_cell: int,
  origin_world: Vector2,
  cell_size: float,
  color_to_kind_id: Dictionary,
  kind_presets: Array,
  default_kind_id: int = 0,
) -> Resource:
  if kind_presets.is_empty() or pixels_per_cell < 1:
    return null
  var iw := image.get_width()
  var ih := image.get_height()
  var cw: int = int(floor(float(iw) / float(pixels_per_cell)))
  var ch: int = int(floor(float(ih) / float(pixels_per_cell)))
  if cw <= 0 or ch <= 0:
    return null
  var cells := PackedInt32Array()
  cells.resize(cw * ch)
  for cy in ch:
    for cx in cw:
      var src_x := cx * pixels_per_cell
      var src_y := cy * pixels_per_cell
      var col := image.get_pixel(src_x, src_y)
      var kid: int = default_kind_id
      if color_to_kind_id.has(col):
        kid = int(color_to_kind_id[col])
      elif color_to_kind_id.size() > 0:
        kid = default_kind_id
      kid = clampi(kid, 0, kind_presets.size() - 1)
      cells[cx + cy * cw] = kid
  var out = _Baked.new()
  out.cell_width = cw
  out.cell_height = ch
  out.cell_size = cell_size
  out.origin_world = origin_world
  out.kind_presets = kind_presets.duplicate()
  out.cell_kind_ids = cells
  return out
