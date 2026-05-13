## Footprint sizing helper used by [ObstacleFieldRoot] and headless tests.
extends RefCounted


## Stable visual bucket index from authored collision axes (pixels).
## Params:
## - rect_size: [RectangleShape2D.size] in local obstacle space.
## Returns:
## - **0** small (max axis ≤130.5 px), **1** medium (≤200.5), **2** large.
## Usage example:
## - Attach distinct PNGs per bucket via [member ObstacleFieldRoot.texture_small_obstacle] … [member ObstacleFieldRoot.texture_large_obstacle].
func tier_for_rect_size(rect_size: Vector2) -> int:
  var mx := maxf(rect_size.x, rect_size.y)
  if mx <= 130.5:
    return 0
  if mx <= 200.5:
    return 1
  return 2
