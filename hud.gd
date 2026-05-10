extends CanvasLayer

# Notifies 'Main' node that the button has been pressed
signal start_game
signal ai_player_game
signal end_ai_game


func _ai_driver() -> Node:
	return get_node("/root/AiDriver")

func show_message(text):
	$Message.text = text
	$Message.show()
	$MessageTimer.start()


## Hides the transient HUD message and stops its timer (e.g. after async AI bootstrap).
func dismiss_message() -> void:
	$MessageTimer.stop()
	$Message.hide()

## Shows game-over messaging then restores non-playing controls.
## Params:
## - none
## Returns / side effects:
## - Awaits message timer and toggles HUD buttons.
## Usage:
## - Called by Main.game_over().
func show_game_over():
	show_message("Game Over")
	# Wait until the MessageTImer has counted down.
	await $MessageTimer.timeout
	
	$Message.text = "Dodge the Creeps!"
	$Message.show()
	# Make a one-shot timer and wait for it to finish.
	$StartButton.show()
	$AIPlayerButton.show()
	$EndAIButton.hide()
	
func update_score(score):
	$ScoreLabel.text = str(score)
	
## Handles human Start button presses while respecting AiDriver suppression rules.
## Params:
## - none
## Returns / side effects:
## - Emits start_game only when human Start is allowed.
## Usage:
## - Connected from StartButton.pressed in hud.tscn.
func _on_start_button_pressed():
	if _ai_driver().is_human_start_suppressed():
		return
	$StartButton.hide()
	start_game.emit()


## Requests AI ownership of the next round (ARMED -> START -> PLAYING).
## Params:
## - none
## Returns / side effects:
## - Emits ai_player_game when AiDriver accepts arming.
## Usage:
## - Called from the "AI Player" button press signal.
func _on_ai_player_button_pressed() -> void:
	ai_player_game.emit()


## Ends an active AI round early via Main.game_over().
## Params:
## - none
## Returns / side effects:
## - Emits end_ai_game for Main to process.
## Usage:
## - Called from the "End AI" button press signal.
func _on_end_ai_button_pressed() -> void:
	end_ai_game.emit()
	
func _on_message_timer_timeout():
	$Message.hide()


## Updates HUD controls according to AiDriver session state.
## Params:
## - state: AiDriver.State enum value encoded as int.
## Returns / side effects:
## - Shows/hides Start, AI Player, and End AI buttons.
## Usage:
## - Main forwards AiDriver.ai_session_state_changed(state).
func set_ai_session_state(state: int) -> void:
	match state:
		0: # IDLE
			$StartButton.show()
			$AIPlayerButton.show()
			$EndAIButton.hide()
			$EndAIButton.text = "End AI"
		1: # ARMED
			$StartButton.show()
			$AIPlayerButton.hide()
			$EndAIButton.show()
			$EndAIButton.text = "Cancel"
		2: # PLAYING
			$StartButton.hide()
			$AIPlayerButton.hide()
			$EndAIButton.show()
			$EndAIButton.text = "End AI"
		3: # WAITING
			$StartButton.show()
			$AIPlayerButton.show()
			$EndAIButton.hide()
			$EndAIButton.text = "End AI"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
