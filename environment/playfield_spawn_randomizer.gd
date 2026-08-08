extends RefCounted
class_name PlayfieldSpawnRandomizer
## Randomized XZ fraction picks for interior boulders / food / duel-pair spawns
## ([ENVIRONMENT_MODEL_PLAN.md §6.4](../Project_Docs/Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)).
## Deliberate stress test, not gameplay balancing: [method pick_uniform_fraction] (boulders, food)
## has no mutual-separation check and may overlap other props — only [method pick_clear_fraction]
## (creature spawns) avoids existing points, so a creature never spawns stuck inside terrain/a prop.

const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")

## h-k-boulder1 mesh spans ~2.1 m; clears the perimeter ring (DEFAULT_INSET=0.5 + rock radius).
const DEFAULT_EDGE_MARGIN_M := 1.6
## Fox capsule diameter 0.8 m plus a little slack so a creature never spawns embedded in a prop.
const DEFAULT_MIN_SEPARATION_M := 1.2
const DEFAULT_MAX_ATTEMPTS := 24


## Pure uniform-random normalized XZ fraction, only constrained to stay clear of the playfield
## edge (and thus the perimeter boulder ring). No mutual-separation or terrain-safety check —
## used for interior boulders and food, which may overlap each other/other props on purpose.
static func pick_uniform_fraction(
  rng: RandomNumberGenerator,
  bounds: Dictionary,
  edge_margin_m: float = DEFAULT_EDGE_MARGIN_M,
) -> Vector2:
  var mx := _edge_margin_frac(bounds, edge_margin_m)
  return Vector2(
    rng.randf_range(mx.x, 1.0 - mx.x),
    rng.randf_range(mx.y, 1.0 - mx.y),
  )


## Rejection-samples a normalized XZ fraction that stays clear of the playfield edge, avoids
## terrain depressions (when [param ground_sampler] is valid), and keeps at least
## [param min_separation_m] from every point in [param existing_points] (world XZ). Falls back to
## the least-bad candidate seen after [param max_attempts] rather than looping forever — used only
## for creature spawns, so a creature never spawns stuck inside terrain or another prop.
static func pick_clear_fraction(
  rng: RandomNumberGenerator,
  bounds: Dictionary,
  ground_sampler: PlayfieldGroundSampler,
  existing_points: Array[Vector2],
  min_separation_m: float = DEFAULT_MIN_SEPARATION_M,
  edge_margin_m: float = DEFAULT_EDGE_MARGIN_M,
  max_attempts: int = DEFAULT_MAX_ATTEMPTS,
) -> Vector2:
  var best_frac := Vector2(0.5, 0.5)
  var best_score := -INF
  for _attempt in range(maxi(1, max_attempts)):
    var frac := pick_uniform_fraction(rng, bounds, edge_margin_m)
    var xz := _world_xz(bounds, frac)
    if ground_sampler != null and ground_sampler.is_valid():
      if ground_sampler.local_depression_score(xz) > PlayfieldGroundSampler.SPAWN_DEPRESSION_THRESHOLD_M:
        continue
    var nearest := _nearest_distance(xz, existing_points)
    if nearest >= min_separation_m:
      return frac
    if nearest > best_score:
      best_score = nearest
      best_frac = frac
  ## RefCounted (no scene tree) — can't reach the OLog autoload here, so this deliberately falls
  ## back to push_warning rather than the OLog.info convention used by Node-derived callers.
  if best_score == -INF:
    push_warning(
      "PlayfieldSpawnRandomizer: exhausted %d attempts with no valid candidate — using fallback center"
      % max_attempts,
    )
  else:
    push_warning(
      "PlayfieldSpawnRandomizer: no candidate cleared min_separation_m=%.2f after %d attempts — using closest (%.2f m clear)"
      % [min_separation_m, max_attempts, best_score],
    )
  return best_frac


static func _edge_margin_frac(bounds: Dictionary, edge_margin_m: float) -> Vector2:
  var sz: Vector2 = bounds.get("size", Vector2.ONE)
  var fx := 0.0 if sz.x < 1e-6 else clampf(edge_margin_m / sz.x, 0.0, 0.49)
  var fy := 0.0 if sz.y < 1e-6 else clampf(edge_margin_m / sz.y, 0.0, 0.49)
  return Vector2(fx, fy)


static func _world_xz(bounds: Dictionary, frac: Vector2) -> Vector2:
  var pos := _Bounds3D.world_position_from_fraction(bounds, frac, 0.0)
  return Vector2(pos.x, pos.z)


static func _nearest_distance(xz: Vector2, existing_points: Array[Vector2]) -> float:
  if existing_points.is_empty():
    return INF
  var nearest := INF
  for p in existing_points:
    nearest = minf(nearest, xz.distance_to(p))
  return nearest


## Serializes a resolved layout (fraction arrays/Vector2 values keyed by object type, plus
## [param seed]) to pretty-printed JSON — the "locations file" a developer can copy aside and
## point [code]playfield_spawn.locked_layout_path[/code] at to freeze a repro.
static func serialize_layout(layout: Dictionary, seed: int) -> String:
  var out := {"seed": seed}
  for key in layout:
    var value: Variant = layout[key]
    if typeof(value) == TYPE_VECTOR2:
      out[key] = _vec2_to_json(value)
    elif typeof(value) == TYPE_ARRAY:
      var arr: Array = []
      for entry in (value as Array):
        arr.append(_vec2_to_json(entry))
      out[key] = arr
  return JSON.stringify(out, "  ")


## Parses JSON written by [method serialize_layout]. Returns an empty dict on any parse failure
## (missing file content, malformed JSON, non-object root) — callers fall back to randomization.
static func parse_layout(json_text: String) -> Dictionary:
  var json := JSON.new()
  if json.parse(json_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
    return {}
  return json.data


## [param key]'s fraction list from a parsed layout, only when it has exactly [param expected_count]
## well-formed [code][fx, fy][/code] entries — otherwise empty (caller falls back to randomizing
## that object set rather than spawning a mismatched count).
static func locked_fraction_list(layout: Dictionary, key: String, expected_count: int) -> Array[Vector2]:
  var out: Array[Vector2] = []
  if not layout.has(key) or typeof(layout[key]) != TYPE_ARRAY:
    return out
  for entry in (layout[key] as Array):
    if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 2:
      out.append(Vector2(float(entry[0]), float(entry[1])))
  if out.size() != expected_count:
    return []
  return out


## [param key]'s single fraction from a parsed layout, or [code]null[/code] when absent/malformed.
static func locked_fraction(layout: Dictionary, key: String) -> Variant:
  if not layout.has(key) or typeof(layout[key]) != TYPE_ARRAY:
    return null
  var raw: Array = layout[key]
  if raw.size() < 2:
    return null
  return Vector2(float(raw[0]), float(raw[1]))


static func _vec2_to_json(value: Variant) -> Array:
  var v: Vector2 = value
  return [v.x, v.y]
