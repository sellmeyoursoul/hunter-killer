## Headless smoke driver: [code]godot --path . --headless -s res://tests/smoke_ai_player.gd[/code]
## Boots main_3d.tscn, presses the AI Player button programmatically (same call path as
## HUD._on_ai_player_button_pressed -> Main3D._on_hud_ai_player_game), lets the forced
## edge-chase repro (_DEBUG_FORCE_EDGE_CHASE_SPAWN) run for a fixed number of physics ticks,
## then quits. Reads motor_explore_tick.log / godot.log afterward for C9/C10 evidence.
extends SceneTree

const _RUN_TICKS := 3600

var _main: Node3D
var _ticks: int = 0
var _done: bool = false


func _init() -> void:
  _begin.call_deferred()


func _begin() -> void:
  var scene: PackedScene = load("res://main_3d.tscn") as PackedScene
  _main = scene.instantiate() as Node3D
  root.add_child(_main)
  await process_frame
  await process_frame
  ## Navmesh bakes on a background thread (main_3d.gd `_bake_playfield_navmesh`) — without this
  ## wait, nav-aware planner code (e.g. CLEANUP C9's geometry-scored flee targeting) silently gets
  ## empty path queries for the whole run instead of a real signal to test against.
  var bake_wait_frames := 0
  while (
    _main.has_method(&"is_navigation_ready")
    and not bool(_main.call("is_navigation_ready"))
    and bake_wait_frames < 600
  ):
    await process_frame
    bake_wait_frames += 1
  print("SMOKE: navmesh ready=", _main.call("is_navigation_ready") if _main.has_method(&"is_navigation_ready") else "n/a", " waited ", bake_wait_frames, " frames")
  var ad: Variant = _main.call("_ai_driver") if _main.has_method(&"_ai_driver") else null
  if ad == null:
    print("SMOKE: no AiDriver found")
    quit(1)
    return
  var ok: bool = ad.call("begin_engine_player_round")
  print("SMOKE: begin_engine_player_round -> ", ok)
  if not ok:
    quit(1)
    return
  _main.call("new_game")
  print("SMOKE: new_game() called, running ", _RUN_TICKS, " physics ticks")


func _physics_process(_delta: float) -> bool:
  if _done:
    return true
  _ticks += 1
  if _ticks >= _RUN_TICKS:
    _done = true
    print("SMOKE: run complete at tick ", _ticks)
    quit(0)
    return true
  return false
