extends RefCounted
class_name PlayfieldGroundSampler
## Baked ground-elevation grid over playfield XZ for rim spawn placement and terrain-aware motor.


const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")

const DEFAULT_GRID_CELLS := 32
const DEPRESSION_RADIUS_CELLS := 2
## Walkable-mask resolution per axis (finer than the elevation grid so the terrain edge is located
## to ~3 m on a 200 m playfield).
const WALKABLE_GRID_CELLS := 64
## Ring sample count around a body centre in [method is_walkable].
const WALKABLE_RING_SAMPLES := 8
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
## Walkable mask: 1 where a ground ray hit at the cell centre ([method _bake_walkable_mask]).
var _walk := PackedByteArray()
var _walk_w := 0
var _walk_h := 0
var _walk_exclude: Array = []


## Builds a sampler from playfield bounds and downward ground raycasts.
## Params:
## - bounds: [PlayfieldBounds3D.xz_bounds_from_playfield_root] dictionary.
## - space: Active [PhysicsDirectSpaceState3D] (scene must be in tree).
## - grid_cells: Square grid resolution per axis.
## - walkable_exclude_rids: Collider RIDs (props: boulders, plants) ignored by the walkable mask only,
##   so a prop over the void never marks its cell as terrain. Elevation sampling is unchanged.
## Returns:
## - Configured sampler (may be invalid when bounds or space are missing).
static func bake_from_playfield(
  bounds: Dictionary,
  space: PhysicsDirectSpaceState3D,
  grid_cells: int = DEFAULT_GRID_CELLS,
  walkable_exclude_rids: Array = [],
) -> PlayfieldGroundSampler:
  var sampler := PlayfieldGroundSampler.new()
  sampler._walk_exclude = walkable_exclude_rids
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


## Worst-case vertical drop (meters) anywhere in the baked grid — the highest sampled cell minus
## the lowest. A conservative upper bound on any single fall a creature could take while staying
## in bounds (real accessible falls are almost always shorter, since it assumes a body could reach
## both extremes), used to size the C10 airborne-invariant threshold per playfield so a genuine
## deep-terrain fall (PHYSICS_SQUEEZE.md §3 decision 30) doesn't get flagged as a stuck-under-
## geometry bug. Returns 0.0 when unbaked/invalid or the grid is empty.
func max_elevation_range() -> float:
  if not is_valid() or _elevations.is_empty():
    return 0.0
  var lo := _elevations[0]
  var hi := _elevations[0]
  for e in _elevations:
    lo = minf(lo, e)
    hi = maxf(hi, e)
  return hi - lo


## Normalized playfield fractions for herbivore and carnivore duel spawns on elevated rim.
## Params:
## - separation_min_frac: Minimum normalized-fraction separation between the two picks.
## - rng: When non-null, randomly selects among the top-elevation qualifying candidates instead of
##   deterministically taking the single highest cell (Randomized Playfield Spawn,
##   [ENVIRONMENT_MODEL_PLAN.md §6.4](../Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)).
##   [code]null[/code] preserves the original deterministic (max-elevation-first) behavior.
## - existing_points: World XZ points (already-placed boulders/food) a candidate must clear by
##   [param prop_clearance_m] — so a creature never spawns inside a prop.
## Returns:
## - [code][herb_frac, carn_frac][/code] as [code]Vector2[/code] entries.
func pick_duel_spawn_fractions(
  separation_min_frac: float = SPAWN_MIN_SEPARATION_FRAC,
  rng: RandomNumberGenerator = null,
  existing_points: Array[Vector2] = [],
  prop_clearance_m: float = 1.2,
) -> Array:
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
      if _too_close_to_existing(xz, existing_points, prop_clearance_m):
        continue
      candidates.append({"frac": frac, "elev": elev, "xz": xz})
  if candidates.is_empty():
    return [FALLBACK_HERB_FRAC, FALLBACK_CARN_FRAC]
  candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
    return float(a.get("elev", 0.0)) > float(b.get("elev", 0.0))
  )
  var first: Dictionary
  if rng != null:
    var top_k := mini(candidates.size(), maxi(1, int(ceil(float(candidates.size()) * 0.3))))
    first = candidates[rng.randi_range(0, top_k - 1)]
  else:
    first = candidates[0]
  var qualifying: Array = []
  var best_second: Dictionary = {}
  var best_sep := -1.0
  for i in range(candidates.size()):
    var c: Dictionary = candidates[i]
    var sep := (c.get("frac", Vector2.ZERO) as Vector2).distance_to(
      first.get("frac", Vector2.ZERO) as Vector2
    )
    if sep >= separation_min_frac:
      qualifying.append(c)
      if sep > best_sep:
        best_sep = sep
        best_second = c
  if rng != null and not qualifying.is_empty():
    best_second = qualifying[rng.randi_range(0, qualifying.size() - 1)]
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


static func _too_close_to_existing(xz: Vector2, existing_points: Array[Vector2], clearance_m: float) -> bool:
  for p in existing_points:
    if xz.distance_to(p) < clearance_m:
      return true
  return false


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
  _bake_walkable_mask(space)
  _valid = true


## Bakes the coarse "has ground" mask ([constant WALKABLE_GRID_CELLS] square) with one ground ray
## per cell centre. Runs once at bake time so per-tick walkability queries never touch physics.
## Params:
## - space: Active [PhysicsDirectSpaceState3D] (same one used for the elevation grid).
func _bake_walkable_mask(space: PhysicsDirectSpaceState3D) -> void:
  _walk_w = WALKABLE_GRID_CELLS
  _walk_h = WALKABLE_GRID_CELLS
  _walk = PackedByteArray()
  _walk.resize(_walk_w * _walk_h)
  var sz := _bounds_max - _bounds_min
  for gy in range(_walk_h):
    for gx in range(_walk_w):
      var xz := _bounds_min + Vector2(
        (float(gx) + 0.5) / float(_walk_w) * sz.x,
        (float(gy) + 0.5) / float(_walk_h) * sz.y,
      )
      var ground: Dictionary = _Bounds3D.raycast_ground_surface(
        space, xz, _floor_y_hint, _Bounds3D.WORLD_STATIC_COLLISION_MASK, _walk_exclude
      )
      _walk[gy * _walk_w + gx] = 1 if bool(ground.get("hit", false)) else 0


## True when the baked walkable mask exists (sampler baked from a real physics space).
func has_walkable_mask() -> bool:
  return _walk_w > 0 and _walk.size() == _walk_w * _walk_h


## Size of one walkable-mask cell in meters (x, z); [code]Vector2.ZERO[/code] when unbaked.
func walkable_cell_size() -> Vector2:
  if not has_walkable_mask():
    return Vector2.ZERO
  var sz := _bounds_max - _bounds_min
  return Vector2(sz.x / float(_walk_w), sz.y / float(_walk_h))


## True when the mask cell containing [param xz] had a ground hit at bake time; false outside the
## baked bounds. Cheap array lookup (no physics).
func _walk_cell_has_ground(xz: Vector2) -> bool:
  var sz := _bounds_max - _bounds_min
  if xz.x < _bounds_min.x or xz.y < _bounds_min.y or xz.x > _bounds_max.x or xz.y > _bounds_max.y:
    return false
  var gx := clampi(int(floor((xz.x - _bounds_min.x) / sz.x * float(_walk_w))), 0, _walk_w - 1)
  var gy := clampi(int(floor((xz.y - _bounds_min.y) / sz.y * float(_walk_h))), 0, _walk_h - 1)
  return _walk[gy * _walk_w + gx] != 0


## Whether a body of footprint radius [param margin] centred at [param xz] stays over real terrain.
## Samples the centre plus [constant WALKABLE_RING_SAMPLES] points on a ring at
## [code]margin + half a mask cell[/code] (the half cell conservatively covers the mask's
## quantization, since a cell only records ground at its centre). No per-tick physics.
## Params:
## - xz: World XZ of the body centre.
## - margin: Footprint radius in meters (0 = point query).
## Returns:
## - True when every sample has ground; also true when no mask is baked (nothing to enforce).
## Example: [code]sampler.is_walkable(Vector2(10, 20), 0.5)[/code]
func is_walkable(xz: Vector2, margin: float = 0.0) -> bool:
  if not has_walkable_mask():
    return true
  if not _walk_cell_has_ground(xz):
    return false
  var cs := walkable_cell_size()
  var r := maxf(margin, 0.0) + maxf(cs.x, cs.y) * 0.5
  for i in range(WALKABLE_RING_SAMPLES):
    var a := TAU * float(i) / float(WALKABLE_RING_SAMPLES)
    if not _walk_cell_has_ground(xz + Vector2(cos(a), sin(a)) * r):
      return false
  return true


## Nearest walkable point to [param xz] (searched on a 1 m-ish expanding square ring up to
## [param max_radius]). Returns [code]Vector2(INF, INF)[/code] when nothing walkable is in range.
## Params:
## - xz: Query point.
## - margin: Footprint radius required at the result.
## - max_radius: Search radius in meters.
func nearest_walkable(xz: Vector2, margin: float = 0.0, max_radius: float = 150.0) -> Vector2:
  if is_walkable(xz, margin):
    return xz
  var cs := walkable_cell_size()
  var step := maxf(1.0, minf(cs.x, cs.y) * 0.5)
  var best := Vector2(INF, INF)
  var best_d := INF
  var rings := int(ceil(max_radius / step))
  for ring in range(1, rings + 1):
    var rad := float(ring) * step
    if best_d < rad:
      break
    for ix in range(-ring, ring + 1):
      var iy_step := 1 if absi(ix) == ring else 2 * ring
      for iy in range(-ring, ring + 1, iy_step):
        var p := xz + Vector2(float(ix), float(iy)) * step
        var d := p.distance_to(xz)
        if d < best_d and is_walkable(p, margin):
          best_d = d
          best = p
  return best


## Constrains a one-tick move to real terrain: returns [param to] when walkable; otherwise the
## farthest walkable point reachable from [param from] by sliding along one axis (edge slide) or by
## shortening the move. When [param from] itself is not walkable (spawned/teleported off terrain),
## returns [method nearest_walkable] of [param to] so the body is pulled back on.
## Params:
## - from: Previous accepted XZ (should be walkable).
## - to: Desired XZ after the move.
## - margin: Footprint radius in meters.
## Returns:
## - Allowed XZ (equals [param to] when nothing blocks it).
func clamp_to_walkable(from: Vector2, to: Vector2, margin: float = 0.0) -> Vector2:
  if is_walkable(to, margin):
    return to
  if not is_walkable(from, margin):
    var back := nearest_walkable(to, margin)
    return to if back.x == INF else back
  var best := from
  var best_d := 0.0
  for cand in [Vector2(to.x, from.y), Vector2(from.x, to.y)]:
    var c: Vector2 = cand
    var d := c.distance_squared_to(from)
    if d > best_d and is_walkable(c, margin):
      best = c
      best_d = d
  var lo := 0.0
  var hi := 1.0
  for _i in range(8):
    var mid := (lo + hi) * 0.5
    if is_walkable(from.lerp(to, mid), margin):
      lo = mid
    else:
      hi = mid
  var shortened := from.lerp(to, lo)
  if shortened.distance_squared_to(from) > best_d:
    best = shortened
  return best


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
