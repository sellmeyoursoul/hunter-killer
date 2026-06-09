## Baked 2D environment grid: each cell stores a **kind id** into [member kind_presets] ([EnvironmentCellData]).
## Built at edit or load time from **`res://art/env/`** palette PNGs via [EnvironmentGridBake.bake_from_image] — runtime queries are array lookups only.
class_name EnvironmentGridBaked
extends Resource

@export var cell_width: int = 0
@export var cell_height: int = 0

## World-space edge length of one square cell (meters — match [member origin_world]).
@export var cell_size: float = 32.0

## World position of the **top-left** corner of cell **(0, 0)** (same frame as gameplay / [method world_to_cell]).
@export var origin_world: Vector2 = Vector2.ZERO

## Index **i** = kind id; dense **0 .. size-1**. Each entry should be [EnvironmentCellData].
@export var kind_presets: Array = []

## Row-major: index **`x + y * cell_width`**, each value is a kind id into [member kind_presets].
@export var cell_kind_ids: PackedInt32Array = PackedInt32Array()


## Returns kind id at cell **[param cx], [param cy]**, or **-1** if out of range / data mismatch.
func get_kind_id_at(cx: int, cy: int) -> int:
  if cell_width <= 0 or cell_height <= 0:
    return -1
  if cx < 0 or cy < 0 or cx >= cell_width or cy >= cell_height:
    return -1
  var idx := cx + cy * cell_width
  if idx < 0 or idx >= cell_kind_ids.size():
    return -1
  return int(cell_kind_ids[idx])


## Returns [EnvironmentCellData] for cell **[param cx], [param cy]**, or **null** if missing / invalid id.
func get_cell_data(cx: int, cy: int) -> Resource:
  var kid := get_kind_id_at(cx, cy)
  if kid < 0 or kid >= kind_presets.size():
    return null
  return kind_presets[kid] as Resource


## Converts world [param world] to cell indices using [member origin_world] and [member cell_size].
func world_to_cell(world: Vector2) -> Vector2i:
  if cell_size <= 0.0:
    return Vector2i(0, 0)
  var rel := world - origin_world
  return Vector2i(
    int(floor(rel.x / cell_size)),
    int(floor(rel.y / cell_size)),
  )


## Samples [method get_cell_data] at [param world] (after [method world_to_cell]).
func sample_cell_data_at_world(world: Vector2) -> Resource:
  var c := world_to_cell(world)
  return get_cell_data(c.x, c.y)


## True if dimensions and buffer length are consistent.
func is_valid_shape() -> bool:
  if cell_width <= 0 or cell_height <= 0:
    return false
  return cell_kind_ids.size() == cell_width * cell_height
