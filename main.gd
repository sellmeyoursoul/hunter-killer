extends Node

const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")
const _Brand := preload("res://product_brand.gd")

@export var mob_scene: PackedScene
## Optional baked terrain; when unset, [method _create_default_open_grid] fills the viewport with passible open cells.
@export var environment_grid: Resource = null

var score: int = 0


func _ai_driver() -> Node:
	return get_node("/root/AiDriver")

func game_over():
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.show_game_over()
	$Music.stop()
	$DeathSound.play()
	_ai_driver().notify_main_game_over()
	
# Starts a fresh round: same end state as the first run of this function—no leftover
# mobs or running mob/score timers from a prior round.
func new_game() -> void:
	$MobTimer.stop()
	$ScoreTimer.stop()
	$StartTimer.stop()
	get_tree().call_group(&"mobs", &"queue_free")
	score = 0
	$Player.start($StartPosition.position)
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("Get Ready")
	$Music.play()
	_ai_driver().notify_main_new_game()

# Called when the node enters the scene tree for the first time.
# Emits an info-level startup line for `OLog` validation (`user://logs/…`). Requires
# `LOG_LEVEL` of Info or Debug in `user://game_config.json` → `logging_params` (see Project_Docs/Completed_Features/LOGGING_PLAN.md).
func _ready() -> void:
	_ensure_environment_grid()
	OLog.info(
		"%s is starting — %s, %s" % [_Brand.GAME_TITLE, _Brand.AUTHOR, _Brand.COMPANY],
		false,
		"Main",
	)
	_ai_driver().attach_main(self)
	$HUD.ai_player_game.connect(_on_hud_ai_player_game)
	$HUD.end_ai_game.connect(_on_hud_end_ai_game)
	_ai_driver().ai_session_state_changed.connect(_on_ai_session_state_changed)
	$HUD.set_ai_session_state(_ai_driver().get_state())


## Returns the active [EnvironmentGridBaked] for movement queries (OBJECT §8.1).
func get_environment_grid() -> Resource:
	return environment_grid


## Ensures [member environment_grid] is a valid [EnvironmentGridBaked] covering the viewport.
func _ensure_environment_grid() -> void:
	if environment_grid != null and environment_grid is EnvironmentGridBaked:
		var g := environment_grid as EnvironmentGridBaked
		if g.is_valid_shape():
			return
	environment_grid = _create_default_open_grid()


## Builds a uniform open-field grid over the current viewport (one passible kind).
func _create_default_open_grid() -> Resource:
	var vp := get_viewport().get_visible_rect().size
	var cell_px := 64.0
	var cw := maxi(1, ceili(vp.x / cell_px))
	var ch := maxi(1, ceili(vp.y / cell_px))
	var open := EnvironmentCellData.new()
	open.passible = true
	open.movement_impact = 0.0
	open.fit_size = -1.0
	var grid := EnvironmentGridBaked.new()
	grid.cell_width = cw
	grid.cell_height = ch
	grid.cell_size_px = cell_px
	grid.origin_world = Vector2.ZERO
	grid.kind_presets = [open]
	var ids := PackedInt32Array()
	ids.resize(cw * ch)
	ids.fill(0)
	grid.cell_kind_ids = ids
	return grid


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_mob_timer_timeout() -> void:
	# Create a new instance of the Mob scene.
	var mob = mob_scene.instantiate()
	
	# Choose a random location on Path2D
	var mob_spawn_location = $MobPath/MobSpawnLocation
	mob_spawn_location.progress_ratio = randf()
	
	#Set the mob's position to the random location.
	mob.position = mob_spawn_location.position
	
	# Set the mob's direction perpendicular to the path direction.
	var direction = mob_spawn_location.rotation + PI / 2
	
	# Add some Randomness to the direction.
	direction += randf_range(-PI / 4 , PI / 4)
	mob.rotation = direction
	
	# Choose the velocity for the mob.
	var velocitity = Vector2(randf_range(150.0, 250.0), 0.0)
	mob.linear_velocity = velocitity.rotated(direction)
	
	# Spawn the mob by addig it to the Main scene.
	add_child(mob)


func _on_score_timer_timeout() -> void:
	score += 1
	$HUD.update_score(score)

func _on_start_timer_timeout() -> void:
	$MobTimer.start()
	$ScoreTimer.start()


## Handles HUD "AI Player" by starting scripted engine control ([member Player.ControlMode.ENGINE]); no inference.
## Params:
## - none
## Returns / side effects:
## - Transitions AiDriver ARMED→PLAYING through [method AiDriver.begin_engine_player_round] + [method new_game]; updates HUD messaging.
func _on_hud_ai_player_game() -> void:
	$HUD/AIPlayerButton.disabled = true
	#region agent log
	_AgentNdjson.write({
		"runId": "cpu-arm",
		"hypothesisId": "H4",
		"location": "main.gd:_on_hud_ai_player_game",
		"message": "cpu_player_pressed_handler_enter",
		"data": {},
	})
	#endregion
	$HUD.show_message("Starting CPU player…")
	var ok: bool = _ai_driver().begin_engine_player_round()
	$HUD/AIPlayerButton.disabled = false
	#region agent log
	_AgentNdjson.write({
		"runId": "cpu-arm",
		"hypothesisId": "H4",
		"location": "main.gd:_on_hud_ai_player_game_after_begin",
		"data": {"cpu_begin_ok": ok, "driver_state": _ai_driver().get_state()},
	})
	#endregion
	$HUD.dismiss_message()
	if not ok:
		$HUD.show_message("Could not start CPU player. See logs.")
		$HUD.set_ai_session_state(0)
		return
	new_game()


## Handles HUD End-AI button presses.
## Params:
## - none
## Returns / side effects:
## - Ends current round by calling game_over() once.
## Usage:
## - Connected in _ready().
func _on_hud_end_ai_game() -> void:
	if _ai_driver().get_state() == 1:
		_ai_driver().cancel_armed_session()
		return
	game_over()


## Mirrors AiDriver state changes onto HUD button visibility.
## Params:
## - state: AiDriver.State enum encoded as int.
## Returns / side effects:
## - Updates HUD controls.
## Usage:
## - Connected in _ready().
func _on_ai_session_state_changed(state: int) -> void:
	$HUD.set_ai_session_state(state)
