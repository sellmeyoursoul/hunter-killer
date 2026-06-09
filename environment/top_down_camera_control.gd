extends RefCounted
class_name TopDownCameraControl
## Top-down spectator camera pan/zoom math for [code]main_3d.gd[/code] (world XZ, W = −Z).


## Params:
## - right, left, back, forward: action strengths in [0, 1].
## Returns:
## - Normalized motor-plane strengths as [code]Vector2(x, z)[/code] (right−left, back−forward).
static func strengths_from_actions(
  right: float,
  left: float,
  back: float,
  forward: float,
) -> Vector2:
  return Vector2(right - left, back - forward)


## Params:
## - strengths: [code]Vector2(x, z)[/code] from [method strengths_from_actions].
## - delta: frame delta seconds.
## - speed: world units per second on XZ.
## Returns:
## - Pan offset delta to accumulate on the playfield center.
static func pan_offset_delta(strengths: Vector2, delta: float, speed: float) -> Vector2:
  if strengths.length_squared() < 1e-8:
    return Vector2.ZERO
  return strengths.normalized() * speed * delta


## Params:
## - scale: current zoom multiplier on auto-computed camera height.
## - wheel_up: [code]true[/code] when scroll wheel moves up (zoom in = lower height).
## - step, min_scale, max_scale: per-notch change and clamp bounds.
## Returns:
## - Updated zoom scale, clamped to [param min_scale]..[param max_scale].
static func apply_zoom_step(
  scale: float,
  wheel_up: bool,
  step: float,
  min_scale: float,
  max_scale: float,
) -> float:
  var next := scale + (-step if wheel_up else step)
  return clampf(next, min_scale, max_scale)


## Clamps [param scale] to the allowed zoom range.
static func clamped_zoom_scale(scale: float, min_scale: float, max_scale: float) -> float:
  return clampf(scale, min_scale, max_scale)
