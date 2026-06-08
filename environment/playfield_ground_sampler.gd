extends RefCounted
class_name PlayfieldGroundSampler
## Baked ground-elevation grid over playfield XZ for rim spawn placement and terrain-aware motor.


const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")

const DEFAULT_GRID_CELLS := 32
const DEPRESSION_RADIUS_CELLS := 2
## Cells at or above this elevation percentile qualify as rim spawn candidates.
const SPAWN_ELEVATION_PERCENTILE := 0.70
const SPAWN_DEPRESSION_THRESHOLD_M := 0.35
const SPAWN_MIN_SEPARATION_FRAC := 0.35
const FALLBACK_HERB_FRAC := Vector2(0.28, 0.32)
const FALLBACK_CARN_FRAC := Vector2(0.72, 0.32)


var _valid := false
var _grid_w := 0
var _grid_h := 0
var _bounds_min := Vector2.ZERO
var _bounds_max := Vector2.ZERO
var _floor_y_hint := 0.0
var _elevations := PackedFloat32Array()


## Builds a sampler from playfield bounds and downward ground raycasts.
## Params:
## - bounds: [PlayfieldBounds3D.xz_bounds_from_playfield_root] dictionary.
## - space: Active [PhysicsDirectSpaceState3D] (scene must be in tree).
## - grid_cells: Square grid resolution per axis.
## Returns:
## - Configured sampler (may be invalid when bounds or space are missing).
static func bake_from_playfield(
  bounds: Dictionary,
  space: PhysicsDirectSpaceState3D,
  grid_cells: int = DEFAULT_GRID_CELLS,
) -> PlayfieldGroundSampler:
  var sampler := PlayfieldGroundSampler.new()
  sampler._bake(bounds, space, maxi(4, grid_cells))
  return sampler


func is_valid() -> bool:
  return _valid and _elevations.size() == _grid_w * _grid_h


## Bilinear ground elevation (meters) at world XZ; returns [param fallback_y] when invalid.
func sample_elevation(xz: Vector2, fallback_y: float = 0.0) -> float:
  if not is_valid():
    return fallback_y
  var sz := _bounds_max - _bounds_min
  if sz.x < 1e-6 or sz.y < 1e-6:
    return fallback_y
  var u := clampf((xz.x - _bounds_min.x) / sz.x, 0.0, 1.0)
  var v := clampf((xz.y - _bounds_min.y) / sz.y, 0.0, 1.0)
  var gx := u * float(_grid_w - 1)
  var gy := v * float(_grid_h - 1)
  var x0 := int(floor(gx))
  var y0 := int(floor(gy))
  var x1 := mini(x0 + 1, _grid_w - 1)
  var y1 := mini(y0 + 1, _grid_h - 1)
  var tx := gx - float(x0)
  var ty := gy - float(y0)
  var e00 := _cell_elevation(x0, y0)
  var e10 := _cell_elevation(x1, y0)
  var e01 := _cell_elevation(x0, y1)
  var e11 := _cell_elevation(x1, y1)
  var e0 := lerpf(e00, e10, tx)
  var e1 := lerpf(e01, e11, tx)
  return lerpf(e0, e1, ty)


## Positive when [param xz] sits below its neighborhood mean (local depression / valley floor).
func local_depression_score(xz: Vector2, radius_cells: int = DEPRESSION_RADIUS_CELLS) -> float:
  if not is_valid():
    return 0.0
  var center_y := sample_elevation(xz, _floor_y_hint)
  var r := maxi(1, radius_cells)
  var gx := _grid_x_from_world(xz.x)
  var gy := _grid_y_from_world(xz.y)
  var sum := 0.0
  var count := 0
  for dy in range(-r, r + 1):
    for dx in range(-r, r + 1):
      var cx := clampi(gx + dx, 0, _grid_w - 1)
      var cy := clampi(gy + dy, 0, _grid_h - 1)
      sum += _cell_elevation(cx, cy)
      count += 1
  if count <= 0:
    return 0.0
  return (sum / float(count)) - center_y


## Ground elevation at a cardinal motor probe step from [param pos].
func elevation_at_cardinal_probe(pos: Vector3, dir: Vector3, step: float) -> float:
  if dir.length_squared() < 1e-12:
    return sample_elevation(Vector2(pos.x, pos.z), pos.y)
  var probe := pos + Vector3(dir.x, 0.0, dir.z).normalized() * step
  return sample_elevation(Vector2(probe.x, probe.z), pos.y)


## Normalized playfield fractions for herbivore and carnivore duel spawns on elevated rim.
## Returns:
## - [code][herb_frac, carn_frac][/code] as [code]Vector2[/code] entries.
func pick_duel_spawn_fractions(separation_min_frac: float = SPAWN_MIN_SEPARATION_FRAC) -> Array:
  if not is_valid():
    return [FALLBACK_HERB_FRAC, FALLBACK_CARN_FRAC]
  var candidates: Array = []
  var all_elevations: Array = []
  for gy in range(_grid_h):
    for gx in range(_grid_w):
      all_elevations.append(_cell_elevation(gx, gy))
  all_elevations.sort()
  var pct_idx := int(round(float(all_elevations.size() - 1) * SPAWN_ELEVATION_PERCENTILE))
  pct_idx = clampi(pct_idx, 0, all_elevations.size() - 1)
  var elev_thresh: float = all_elevations[pct_idx]
  for gy in range(_grid_h):
    for gx in range(_grid_w):
      var elev := _cell_elevation(gx, gy)
      if elev < elev_thresh - 0.01:
        continue
      var frac := _fraction_from_cell(gx, gy)
      var xz := _world_xz_from_fraction(frac)
      if local_depression_score(xz) > SPAWN_DEPRESSION_THRESHOLD_M:
        continue
      candidates.append({"frac": frac, "elev": elev, "xz": xz})
  if candidates.is_empty():
    return [FALLBACK_HERB_FRAC, FALLBACK_CARN_FRAC]
  candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
    return float(a.get("elev", 0.0)) > float(b.get("elev", 0.0))
  )
  var first: Dictionary = candidates[0]
  var best_second: Dictionary = {}
  var best_sep := -1.0
  for i in range(candidates.size()):
    var c: Dictionary = candidates[i]
    var sep := (c.get("frac", Vector2.ZERO) as Vector2).distance_to(
      first.get("frac", Vector2.ZERO) as Vector2
    )
    if sep >= separation_min_frac and sep > best_sep:
      best_sep = sep
      best_second = c
  if best_second.is_empty():
    for i in range(candidates.size() - 1, -1, -1):
      var c2: Dictionary = candidates[i]
      var sep2 := (c2.get("frac", Vector2.ZERO) as Vector2).distance_to(
        first.get("frac", Vector2.ZERO) as Vector2
      )
      if sep2 > best_sep:
        best_sep = sep2
        best_second = c2
  if best_second.is_empty():
    return [first.get("frac", FALLBACK_HERB_FRAC), FALLBACK_CARN_FRAC]
  return [first.get("frac", FALLBACK_HERB_FRAC), best_second.get("frac", FALLBACK_CARN_FRAC)]


func _bake(bounds: Dictionary, space: PhysicsDirectSpaceState3D, grid_cells: int) -> void:
  _valid = false
  _elevations = PackedFloat32Array()
  if space == null or not bool(bounds.get("valid", false)):
    return
  _bounds_min = bounds.get("min", Vector2.ZERO)
  _bounds_max = bounds.get("max", Vector2.ZERO)
  _floor_y_hint = float(bounds.get("floor_y", 0.0))
  var sz := _bounds_max - _bounds_min
  if sz.x < 1.0 or sz.y < 1.0:
    return
  _grid_w = grid_cells
  _grid_h = grid_cells
  _elevations.resize(_grid_w * _grid_h)
  for gy in range(_grid_h):
    for gx in range(_grid_w):
      var fx := (float(gx) + 0.5) / float(_grid_w)
      var fy := (float(gy) + 0.5) / float(_grid_h)
      var xz := _bounds_min + Vector2(fx * sz.x, fy * sz.y)
      var ground: Dictionary = _Bounds3D.raycast_ground_surface(space, xz, _floor_y_hint)
      _elevations[gy * _grid_w + gx] = float(ground.get("surface_y", _floor_y_hint))
  _valid = true


func _cell_elevation(gx: int, gy: int) -> float:
  return _elevations[gy * _grid_w + gx]


func _grid_x_from_world(x: float) -> int:
  var sz := _bounds_max.x - _bounds_min.x
  if sz < 1e-6:
    return 0
  var u := clampf((x - _bounds_min.x) / sz, 0.0, 1.0)
  return clampi(int(u * float(_grid_w - 1)), 0, _grid_w - 1)


func _grid_y_from_world(z: float) -> int:
  var sz := _bounds_max.y - _bounds_min.y
  if sz < 1e-6:
    return 0
  var v := clampf((z - _bounds_min.y) / sz, 0.0, 1.0)
  return clampi(int(v * float(_grid_h - 1)), 0, _grid_h - 1)


func _fraction_from_cell(gx: int, gy: int) -> Vector2:
  var sz := _bounds_max - _bounds_min
  if sz.x < 1e-6 or sz.y < 1e-6:
    return Vector2(0.5, 0.5)
  var fx := (float(gx) + 0.5) / float(_grid_w)
  var fy := (float(gy) + 0.5) / float(_grid_h)
  return Vector2(fx, fy)


func _world_xz_from_fraction(frac: Vector2) -> Vector2:
  var sz := _bounds_max - _bounds_min
  return _bounds_min + Vector2(frac.x * sz.x, frac.y * sz.y)
