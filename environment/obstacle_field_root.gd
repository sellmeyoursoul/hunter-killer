## Scene root for `res://obstacle_field.tscn`: aligns each obstacle [Sprite2D] to its [RectangleShape2D] footprint so art matches collisions.
## Bucket rules live in helper [code]res://environment/obstacle_visual_tiers.gd[/code] ([member _tier_helper]).
class_name ObstacleFieldRoot
extends Node2D


const _DEFAULT_OBSTACLE_TEX := preload("res://art/env/pile-of-rocks.png")
const _TIER_HELPER_SCRIPT := preload("res://environment/obstacle_visual_tiers.gd")


## Invokes [method Object.call] `"tier_for_rect_size"` from [member _TIER_HELPER_SCRIPT].
var _tier_helper: Object = _TIER_HELPER_SCRIPT.new()


## Multiplier **>1** grows sprites past physics bounds — useful when PNG alpha padding leaves piles visually smaller than the collision hull.
## Params / returns / usage:
## - Inspect in-editor after placing new art; most semi-transparent sprites need roughly **1.05–1.15**.
@export_range(1.0, 1.6, 0.005)
var visual_cover_scale: float = 1.09


## Optional distinct textures per obstacle size bucket (**0** small · **1** medium · **2** large vs max-axis threshold on [member _tier_helper]).
## Returns / side effects:
## - When an export stays empty, buckets fall back to [member _DEFAULT_OBSTACLE_TEX]; [method _ready] assigns [member Sprite2D.texture].
@export var texture_small_obstacle: Texture2D
@export var texture_medium_obstacle: Texture2D
@export var texture_large_obstacle: Texture2D


func _texture_for_tier(tier_i: int) -> Texture2D:
  match tier_i:
    0:
      if texture_small_obstacle != null:
        return texture_small_obstacle
    1:
      if texture_medium_obstacle != null:
        return texture_medium_obstacle
    2:
      if texture_large_obstacle != null:
        return texture_large_obstacle
  return _DEFAULT_OBSTACLE_TEX


func _ready() -> void:
  for node in get_children():
    if node is StaticBody2D:
      _fit_obstacle_sprite(node as StaticBody2D)


## Params:
## - sb: Static obstacle body with rectangle [CollisionShape2D] plus child [Sprite2D].
## Side effects:
## - Sets sprite texture per tier map, scales to collision size (with cover margin), aligns sprite pivot to collision center.
func _fit_obstacle_sprite(sb: StaticBody2D) -> void:
  var sprite := sb.get_node_or_null("Sprite2D") as Sprite2D
  if sprite == null:
    return
  var rect := Vector2.ZERO
  var collision_center_local := Vector2.ZERO
  for ch in sb.get_children():
    if ch is CollisionShape2D:
      var cs := ch as CollisionShape2D
      if cs.disabled:
        continue
      if cs.shape is RectangleShape2D:
        var r := cs.shape as RectangleShape2D
        rect = r.size
        collision_center_local = cs.position
        break
  if rect.x <= 1e-5 or rect.y <= 1e-5:
    push_warning(
      (
        "ObstacleFieldRoot: StaticBody '%s' has no enabled RectangleShape2D — skipping sprite stretch."
      )
      % sb.name
    )
    return
  var tier := int(_tier_helper.call("tier_for_rect_size", rect))
  var tex := _texture_for_tier(tier)
  sprite.texture = tex
  var ts := tex.get_size()
  if ts.x <= 1.0 or ts.y <= 1.0:
    return
  var cover := visual_cover_scale
  sprite.scale = Vector2(rect.x * cover / ts.x, rect.y * cover / ts.y)
  sprite.position = collision_center_local
