extends CanvasLayer

@export var vitals_poll_frames: int = 10

signal start_game
signal ai_player_game
signal end_ai_game

var _vitals_poll: int = 0
var _herbivore: Node = null
var _carnivore: Node = null
var _carnivore_score_override: int = -1


func _ai_driver() -> Node:
  return get_node("/root/AiDriver")


func show_message(text):
  $Message.text = text
  $Message.show()
  $MessageTimer.start()


func dismiss_message() -> void:
  $MessageTimer.stop()
  $Message.hide()


func show_game_over():
  show_message("Game Over")
  await $MessageTimer.timeout
  $Message.text = "Dodge the Creeps!"
  $Message.show()
  $StartButton.show()
  $AIPlayerButton.show()
  $EndAIButton.hide()


func update_score(score):
  $ScoreLabel.text = str(score)


## Clears end-of-round carnivore score display override.
func reset_vitals_display() -> void:
  _carnivore_score_override = -1
  _herbivore = null
  _carnivore = null


## Shows herbivore calories at catch on the carnivore HUD line (CREATURE_GOALS end score).
func set_carnivore_score_display(prey_calories: int) -> void:
  _carnivore_score_override = prey_calories
  _refresh_vitals_labels()


func _on_start_button_pressed():
  if _ai_driver().is_human_start_suppressed():
    return
  $StartButton.hide()
  start_game.emit()


func _on_ai_player_button_pressed() -> void:
  ai_player_game.emit()


func _on_end_ai_button_pressed() -> void:
  end_ai_game.emit()


func _on_message_timer_timeout():
  $Message.hide()


func set_ai_session_state(state: int) -> void:
  match state:
    0:
      $StartButton.show()
      $AIPlayerButton.show()
      $EndAIButton.hide()
      $EndAIButton.text = "End AI"
    1:
      $StartButton.show()
      $AIPlayerButton.hide()
      $EndAIButton.show()
      $EndAIButton.text = "Cancel"
    2:
      $StartButton.hide()
      $AIPlayerButton.hide()
      $EndAIButton.show()
      $EndAIButton.text = "End AI"
    3:
      $StartButton.show()
      $AIPlayerButton.show()
      $EndAIButton.hide()
      $EndAIButton.text = "End AI"


func _resolve_duel_creatures() -> void:
  var m := get_tree().current_scene
  if m == null:
    return
  if _herbivore == null or not is_instance_valid(_herbivore):
    _herbivore = m.get_node_or_null("Player")
  var mobs := get_tree().get_nodes_in_group(&"mobs")
  if mobs.size() >= 1:
    _carnivore = mobs[0]


func _format_vitals_line(role: String, cur_i: int, mx_i: int) -> String:
  return "%s %d / %d" % [role, cur_i, mx_i]


func _refresh_vitals_labels() -> void:
  _resolve_duel_creatures()
  if _herbivore != null:
    var mx_h: Variant = _herbivore.get("caloric_needs")
    var cur_h: Variant = _herbivore.get("current_calories")
    if (typeof(mx_h) == TYPE_INT or typeof(mx_h) == TYPE_FLOAT) and (
      typeof(cur_h) == TYPE_FLOAT or typeof(cur_h) == TYPE_INT
    ):
      var mx_i := int(mx_h)
      var cur_f := clampf(float(cur_h), 0.0, float(mx_i))
      $HerbivoreCaloriesLabel.text = _format_vitals_line("Herbivore", int(round(cur_f)), mx_i)
  if _carnivore != null:
    var mx_c: Variant = _carnivore.get("caloric_needs")
    var mx_ci := int(mx_c) if typeof(mx_c) == TYPE_INT or typeof(mx_c) == TYPE_FLOAT else 10
    var cur_ci := _carnivore_score_override
    if cur_ci < 0:
      var cur_c: Variant = _carnivore.get("current_calories")
      if typeof(cur_c) == TYPE_FLOAT or typeof(cur_c) == TYPE_INT:
        cur_ci = int(round(clampf(float(cur_c), 0.0, float(mx_ci))))
      else:
        cur_ci = 0
    $CarnivoreCaloriesLabel.text = _format_vitals_line("Carnivore", cur_ci, mx_ci)


func _process(_delta: float) -> void:
  _vitals_poll += 1
  if _vitals_poll < vitals_poll_frames:
    return
  _vitals_poll = 0
  _refresh_vitals_labels()
