extends Node

@export var mob_scene: PackedScene
var score: int = 0

func game_over():
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.show_game_over()
	$Music.stop()
	$DeathSound.play()
	
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

# Called when the node enters the scene tree for the first time.
# Emits an info-level startup line for `OLog` validation (`user://logs/…`). Requires
# `LOG_LEVEL` of Info or Debug in `user://game_config.json` → `logging_params` (see Project_Docs/Completed_Features/LOGGING_PLAN.md).
func _ready() -> void:
	var project_title: String = str(ProjectSettings.get_setting("application/config/name", "Game"))
	OLog.info("%s is starting" % project_title, false, "Main")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
