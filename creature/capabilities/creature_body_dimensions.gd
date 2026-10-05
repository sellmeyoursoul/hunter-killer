extends RefCounted
## Pure math for creature body dimensions (CREATURE_BODY_DIMENSIONS.md §4.1-4.3). No node state.
##
## Dimension vectors are [code]Vector3(width, height, length)[/code] = body-local (X, Y, Z) with +Z
## model-forward (B22). All inputs are game units.

const SPEC_PATH := "res://tools/body_dimension_spec.json"
const _FALLBACK_WARN := 0.10
const _FALLBACK_FAIL := 0.20

## Proportion verdict levels returned by [method proportion_report].
const LEVEL_OK := 0
const LEVEL_WARN := 1
const LEVEL_FAIL := 2


## True when [param def] authors all three of body_length / body_width / body_height (> 0).
static func has_authored_dimensions(def: Variant) -> bool:
  if def == null:
    return false
  var l: Variant = def.get("body_length")
  var w: Variant = def.get("body_width")
  var h: Variant = def.get("body_height")
  if l == null or w == null or h == null:
    return false
  return float(l) > 0.0 and float(w) > 0.0 and float(h) > 0.0


## Movement-capsule radius: [code]live_width / 2 * (1 + width_margin)[/code] (B5, §4.2).
static func body_radius(live_width: float, width_margin: float) -> float:
  return live_width * 0.5 * (1.0 + maxf(0.0, width_margin))


## Capsule total height: [code]max(live_height, 2 * radius)[/code] (B24 / B14; no +0.05 floor).
static func capsule_height(live_height: float, radius: float) -> float:
  return maxf(live_height, 2.0 * radius)


## True when [method capsule_height] had to clamp up to 2r (B14).
static func capsule_height_clamped(live_height: float, radius: float) -> bool:
  return live_height < 2.0 * radius


## Reach extent from the body centre along facing (B25).
## Params:
## - live_length: Live body length.
## - margin_fraction: [code]reach_margin_fraction[/code] (config).
## - reach_override: Authored absolute distance at size factor 1; > 0 replaces the computed value.
## - size_factor: Uniform runtime size factor (scales the override, like the dimensions).
static func reach_extent(
  live_length: float, margin_fraction: float, reach_override: float, size_factor: float
) -> float:
  if reach_override > 0.0:
    return reach_override * size_factor
  return live_length * (0.5 + maxf(0.0, margin_fraction))


## [code]max(width, height, length)[/code] of a (W, H, L) vector (B11).
static func max_dimension(dims: Vector3) -> float:
  return maxf(dims.x, maxf(dims.y, dims.z))


## Fit scale from a measured model size to the live dimensions (both (W, H, L)).
## Params:
## - per_axis: false = production uniform fit on length; true = placeholder per-axis fit (B13).
## Returns [code]Vector3.ONE[/code] when the model size has a non-positive axis.
static func fit_scale(model_size: Vector3, live: Vector3, per_axis: bool) -> Vector3:
  if model_size.x <= 1e-6 or model_size.y <= 1e-6 or model_size.z <= 1e-6:
    return Vector3.ONE
  if per_axis:
    return Vector3(live.x / model_size.x, live.y / model_size.y, live.z / model_size.z)
  return Vector3.ONE * (live.z / model_size.z)


## Reads proportion tolerances from [constant SPEC_PATH]; defaults (10% / 20%) when unreadable.
## Returns [code]{warn: float, fail: float}[/code].
static func load_tolerances() -> Dictionary:
  var out := {"warn": _FALLBACK_WARN, "fail": _FALLBACK_FAIL}
  if not FileAccess.file_exists(SPEC_PATH):
    return out
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
  if typeof(parsed) != TYPE_DICTIONARY:
    return out
  var d: Dictionary = parsed
  out["warn"] = float(d.get("proportion_warn_fraction", _FALLBACK_WARN))
  out["fail"] = float(d.get("proportion_fail_fraction", _FALLBACK_FAIL))
  return out


## Proportion check on the uniform length fit (§4.3 step 4): compares model width / height scaled by
## [code]live_length / model_length[/code] with the live width / height.
## Params:
## - model_size: Measured rest-pose AABB size (W, H, L).
## - live: Live dimensions (W, H, L).
## - warn / fail: Per-axis relative deviation thresholds (see [method load_tolerances]).
## Returns [code]{level, width_dev, height_dev, worst_axis, worst_dev}[/code]; level is one of
## [constant LEVEL_OK] / [constant LEVEL_WARN] / [constant LEVEL_FAIL]; devs are fractions (0.12 = 12%).
static func proportion_report(model_size: Vector3, live: Vector3, warn: float, fail: float) -> Dictionary:
  var report := {"level": LEVEL_OK, "width_dev": 0.0, "height_dev": 0.0, "worst_axis": "", "worst_dev": 0.0}
  if model_size.z <= 1e-6 or live.x <= 1e-6 or live.y <= 1e-6:
    return report
  var s := live.z / model_size.z
  var wdev := absf(model_size.x * s - live.x) / live.x
  var hdev := absf(model_size.y * s - live.y) / live.y
  report["width_dev"] = wdev
  report["height_dev"] = hdev
  var worst := maxf(wdev, hdev)
  report["worst_dev"] = worst
  report["worst_axis"] = "width" if wdev >= hdev else "height"
  if worst > fail:
    report["level"] = LEVEL_FAIL
  elif worst > warn:
    report["level"] = LEVEL_WARN
  return report
