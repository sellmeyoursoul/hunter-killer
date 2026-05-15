extends RigidBody2D

const _SlidePickScr := preload("res://creature/motor/wall_slide_pick.gd")

@export var isHostile = true
## Must be **>** player [member Player.creature_size] for squeeze / shrub asymmetry (OBJECT §3.4).
@export var creature_size: float = 48.0

## World ray length from [member _ray_margin] used to foresee [StaticBody2D] rocks (pixels).
## Params / usage: increase if mob clips corners before reacting.
@export var obstacle_lookahead_px: float = 96.0

## Moves ray start slightly along motion so probes clear the capsule center (pixels).
@export var obstacle_ray_margin_px: float = 14.0

## Sample distance for baked grid blockage ahead of centroid (pixels).
@export var env_ahead_probe_px: float = 52.0

## Widens lookahead: rays at **−angle / 0 / +angle** (deg) vs motion; shortest hit selects the avoidance normal (POC).
@export_range(8.0, 45.0, 1.0)
var obstacle_cone_half_angle_deg: float = 22.0

## When [member _stuck_stationary_ticks_needed] lapses below this positional drift (pixels² / tick window), poke a breakout turn.
## Params / usage: keep small for “no visible motion” without noise from float drift.
@export var stuck_stationary_px_sq_max: float = 12.25

## If position barely moves while speed ≥ stall guard for this many physics ticks, snap heading hard-left (temporary POC).
## Params / returns: resets after breakout; skips intentional slow terrain.
@export_range(4, 30, 1)
var stuck_stationary_ticks_needed: int = 10

var _main: Node = null
var _spawn_cruise_speed: float = 200.0
var _last_heading: Vector2 = Vector2.RIGHT
var _wall_slide_pick: RefCounted
var _stuck_stationary_ticks: int = 0
var _stuck_anchor_pos: Vector2 = Vector2.ZERO

## Below this speed [RigidBody2D] collision restitution can park motion; refill using [member _last_heading] × [member _spawn_cruise_speed] when terrain allows.
const _STALL_SPEED_PX_PER_SEC := 4.0


func _ready() -> void:
  add_to_group(&"mobs")
  gravity_scale = 0.0
  lock_rotation = true
  set_can_sleep(false)
  _wall_slide_pick = _SlidePickScr.new()
  _spawn_cruise_speed = maxf(120.0, linear_velocity.length())
  var v0 := linear_velocity
  if v0.length_squared() > 1e-6:
    _last_heading = v0.normalized()
  _stuck_anchor_pos = global_position
  var mob_animations: Array[StringName] = [&"fly", &"swim", &"walk"]
  $AnimatedSprite2D.animation = mob_animations.pick_random()
  $AnimatedSprite2D.play()
  ## Food-source memory (predator / carnivore draft): prey = [code]player[/code] group (moving — track id + velocity like [code]ai_driver[/code] [_mob_hist]).
  ## Stationary [code]food_plants[/code] are routing intel only (where herbivore may go), not mob calories. Precise coords while in sense; coarse 8-way is egocentric and updates each tick — see [code]ai_driver.gd[/code] [_food_belief] design block.
  var plants := get_tree().get_nodes_in_group(&"food_plants")
  if not plants.is_empty():
    OLog.debug("Mob food_plants stub sees %d bush(es)." % plants.size(), false, "Mob")


func _on_visible_on_screen_notifier_2d_screen_exited():
  queue_free()


## Cached Main grid or null when unset / invalid.
func _environment_grid() -> EnvironmentGridBaked:
  if _main == null:
    _main = get_tree().current_scene
  if _main == null or not _main.has_method("get_environment_grid"):
    return null
  var gr: Variant = _main.call("get_environment_grid")
  if gr == null or not (gr is EnvironmentGridBaked):
    return null
  var grid := gr as EnvironmentGridBaked
  if not grid.is_valid_shape():
    return null
  return grid


## Samples terrain multiplier under this mob ([EnvironmentCellData]) or **1** when unconstrained.
func _terrain_speed_multiplier_here(grid: EnvironmentGridBaked) -> float:
  if grid == null:
    return 1.0
  var cell_r := grid.sample_cell_data_at_world(global_position)
  if not (cell_r is EnvironmentCellData):
    return 1.0
  var env := cell_r as EnvironmentCellData
  if not env.can_enter(creature_size):
    return 1.0
  return env.movement_speed_multiplier(creature_size)


func _in_intentional_slow_terrain(grid: EnvironmentGridBaked) -> bool:
  if grid == null or not grid.is_valid_shape():
    return false
  var cell_r := grid.sample_cell_data_at_world(global_position)
  if not (cell_r is EnvironmentCellData):
    return false
  var env := cell_r as EnvironmentCellData
  if not env.can_enter(creature_size):
    return false
  if not env.is_movement_impact_active():
    return false
  return env.movement_speed_multiplier(creature_size) < 0.999


func _blocked_ahead(grid: EnvironmentGridBaked, from_pos: Vector2, heading_unit: Vector2) -> bool:
  if grid == null or not grid.is_valid_shape():
    return false
  var ahead := from_pos + heading_unit * env_ahead_probe_px
  var cell_r := grid.sample_cell_data_at_world(ahead)
  if cell_r == null or not (cell_r is EnvironmentCellData):
    return false
  var env := cell_r as EnvironmentCellData
  return not env.can_enter(creature_size)


func _blocked_here(grid: EnvironmentGridBaked, world_pos: Vector2) -> bool:
  if grid == null:
    return false
  var cell_r := grid.sample_cell_data_at_world(world_pos)
  if cell_r == null or not (cell_r is EnvironmentCellData):
    return false
  var env := cell_r as EnvironmentCellData
  return not env.can_enter(creature_size)


## Queries one ray segment; empty dict when missed.
func _ray_query_hit(ray_from: Vector2, ray_to: Vector2) -> Dictionary:
  var w2 := get_world_2d()
  if w2 == null:
    return {}
  var dq := PhysicsRayQueryParameters2D.create(ray_from, ray_to)
  dq.collision_mask = collision_mask
  dq.exclude = [get_rid()]
  dq.collide_with_areas = false
  dq.collide_with_bodies = true
  return w2.direct_space_state.intersect_ray(dq)


## Shortest-hit normal among **[forward_rotated]** + cone flanks (**±half_angle_deg**); empty when all miss.
func _cone_static_obstacle_normal(forward_unit: Vector2, ray_len: float, margin: float) -> Vector2:
  var u := forward_unit.normalized()
  if u.length_squared() < 1e-10:
    return Vector2.ZERO
  var rad := deg_to_rad(obstacle_cone_half_angle_deg)
  var dirs: Array[Vector2] = []
  dirs.append(u.rotated(+rad))
  dirs.append(u)
  dirs.append(u.rotated(-rad))
  var origin := global_position
  var best_hit: Dictionary = {}
  var best_d2 := INF
  for d in dirs:
    var du := (d as Vector2).normalized()
    var rf := origin + du * margin
    var rt := rf + du * ray_len
    var hit := _ray_query_hit(rf, rt)
    if hit.is_empty():
      continue
    var pos_hit: Variant = hit.get("position", null)
    if typeof(pos_hit) != TYPE_VECTOR2:
      continue
    var d2 := origin.distance_squared_to(pos_hit as Vector2)
    if d2 < best_d2:
      best_d2 = d2
      best_hit = hit
  if best_hit.is_empty():
    return Vector2.ZERO
  var norm: Variant = best_hit.get("normal", null)
  if typeof(norm) != TYPE_VECTOR2:
    return Vector2.ZERO
  return (norm as Vector2).normalized()


func _blocked_cone(grid: EnvironmentGridBaked, from_pos: Vector2, forward_unit: Vector2, degrees_half: float) -> bool:
  if grid == null or not grid.is_valid_shape():
    return false
  var u := forward_unit.normalized()
  if u.length_squared() < 1e-10:
    return false
  var rad := deg_to_rad(degrees_half)
  for d in [u.rotated(+rad), u, u.rotated(-rad)]:
    var du := (d as Vector2).normalized()
    if _blocked_ahead(grid, from_pos, du):
      return true
  return false


## POC “hard left”: +90° from screen axes using ** (−incoming.y, incoming.x)**.
func _breakout_heading_hard_left(forward_unit: Vector2) -> Vector2:
  var u := forward_unit.normalized()
  var fl := Vector2(-u.y, u.x).normalized()
  return fl if fl.length_squared() > 1e-8 else Vector2.UP


## Applies straight-line cruising with instantaneous tangential turns facing static obstacles ([RigidBody2D] mask) or squeezed grid cells ([EnvironmentCellData]).
## Params / side effects:
## - Writes [member linear_velocity]; preserves [member _spawn_cruise_speed] modulo terrain multiplier unless stalled in mud/shrub.
func _physics_process(_delta: float) -> void:
  var grid := _environment_grid()

  var spd := linear_velocity.length()
  var incoming := linear_velocity.normalized() if spd > 1e-4 else Vector2.ZERO
  if incoming.length_squared() < 1e-8:
    incoming = _last_heading

  if spd < _STALL_SPEED_PX_PER_SEC:
    if not _in_intentional_slow_terrain(grid):
      linear_velocity = _last_heading * _spawn_cruise_speed
      _stuck_stationary_ticks = 0
      _stuck_anchor_pos = global_position
    return

  _last_heading = incoming

  if not _in_intentional_slow_terrain(grid) and spd >= _STALL_SPEED_PX_PER_SEC:
    var drift := global_position.distance_squared_to(_stuck_anchor_pos)
    if drift <= stuck_stationary_px_sq_max:
      _stuck_stationary_ticks += 1
    else:
      _stuck_stationary_ticks = 0
      _stuck_anchor_pos = global_position
    if _stuck_stationary_ticks >= stuck_stationary_ticks_needed:
      var bump := _breakout_heading_hard_left(incoming)
      _last_heading = bump
      _stuck_stationary_ticks = 0
      _stuck_anchor_pos = global_position
      var mult_esc := _terrain_speed_multiplier_here(grid)
      linear_velocity = bump * (_spawn_cruise_speed * mult_esc)
      return

  ## Foot stuck inside authored solid cell (fallback when physics ray misses degenerate overlaps).
  if grid != null and _blocked_here(grid, global_position):
    var tangent := _wall_slide_pick.call("pick_tangent_closer", incoming, -incoming) as Vector2
    _last_heading = tangent
    incoming = tangent
    var mult_here := _terrain_speed_multiplier_here(grid)
    linear_velocity = tangent * (_spawn_cruise_speed * mult_here)
    return

  var ray_len := maxf(24.0, obstacle_lookahead_px)
  var mrg := obstacle_ray_margin_px
  var n_hit := _cone_static_obstacle_normal(incoming, ray_len, mrg)
  var heading_after := incoming
  var turned := false
  if n_hit.length_squared() > 1e-8:
    heading_after = _wall_slide_pick.call("pick_tangent_closer", incoming, n_hit) as Vector2
    turned = true
  elif grid != null and _blocked_cone(grid, global_position, incoming, obstacle_cone_half_angle_deg):
    ## Grid-only blockage (sparse vs physics hit): treat wall as perpendicular to velocity.
    heading_after = _wall_slide_pick.call("pick_tangent_closer", incoming, -incoming) as Vector2
    turned = true

  if turned:
    _last_heading = heading_after
    incoming = heading_after

  var mult_fin := _terrain_speed_multiplier_here(grid)
  linear_velocity = incoming * (_spawn_cruise_speed * mult_fin)
