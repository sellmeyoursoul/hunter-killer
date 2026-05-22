extends Node

const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")
const _Brand := preload("res://product_brand.gd")
const _PlayerScr := preload("res://player.gd")
const _MobScr := preload("res://mob.gd")
const _SOLID_SHRUB_SCENE_PATH := "res://assets/plants/solid_shrub/solid_shrub.tscn"
const _OPEN_SHRUB_SCENE_PATH := "res://assets/plants/open_shrub/open_shrub.tscn"

@export var mob_scene: PackedScene
## Optional baked terrain; when unset, [method _create_default_open_grid] fills the viewport with passible open cells.
@export var environment_grid: Resource = null

var score: int = 0
var _solid_shrub_scene: PackedScene
var _open_shrub_scene: PackedScene
var _round_ended: bool = false
var _duel_carnivore: RigidBody2D = null


func _ai_driver() -> Node:
  return get_node("/root/AiDriver")


## Ends the round once; logs winner/cause for manual playtest log, then generic game over UI.
## Params:
## - outcome_tag: e.g. [code]predation_carn_win[/code], [code]starvation_carn_herb_win[/code].
## - winner: [code]herbivore[/code] or [code]carnivore[/code] for manual log.
func end_round(outcome_tag: String, winner: String) -> void:
  if _round_ended:
    return
  _round_ended = true
  _log_round_outcome(outcome_tag, winner)
  game_over()


func game_over() -> void:
  _round_ended = true
  $ScoreTimer.stop()
  $HUD.show_game_over()
  $Music.stop()
  $DeathSound.play()
  _ai_driver().set_duel_round_active(false)
  _ai_driver().notify_main_game_over()


## Writes structured round outcome to OLog (copy into [CREATURE_GOALS_PLAYTEST_LOG.md](Project_Docs/Completed_Features/CREATURE_GOALS_PLAYTEST_LOG.md)).
func _log_round_outcome(outcome_tag: String, winner: String) -> void:
  var herb_cal := -1
  var carn_cal := -1
  var player := get_node_or_null("Player")
  if player != null:
    var c: Variant = player.get("current_calories")
    if typeof(c) == TYPE_FLOAT or typeof(c) == TYPE_INT:
      herb_cal = int(round(float(c)))
  if _duel_carnivore != null and is_instance_valid(_duel_carnivore):
    var mc: Variant = _duel_carnivore.get("current_calories")
    if typeof(mc) == TYPE_FLOAT or typeof(mc) == TYPE_INT:
      carn_cal = int(round(float(mc)))
  OLog.info(
    "CREATURE_GOALS round: winner=%s cause=%s herb_cal=%d carn_cal=%d"
    % [winner, outcome_tag, herb_cal, carn_cal],
    false,
    "Main",
  )


func new_game() -> void:
  _round_ended = false
  $ScoreTimer.stop()
  $StartTimer.stop()
  get_tree().call_group(&"mobs", &"queue_free")
  _duel_carnivore = null
  score = 0
  _ensure_spawn_markers()
  var herb_pos := _herbivore_spawn_position()
  var carn_pos := _carnivore_spawn_position()
  $Player.start(herb_pos)
  _spawn_duel_carnivore(carn_pos)
  _reset_food_plants()
  _ai_driver().clear_creature_registry()
  _ai_driver().register_creature($Player)
  if _duel_carnivore != null:
    _ai_driver().register_creature(_duel_carnivore)
  _ai_driver().sync_duel_control_modes()
  _ai_driver().set_duel_round_active(true)
  _ai_driver().set_primary_creature($Player)
  $StartTimer.start()
  $HUD.reset_vitals_display()
  $HUD.update_score(score)
  $HUD.show_message("Get Ready")
  $Music.play()
  _ai_driver().notify_main_new_game()


func _ready() -> void:
  _ensure_environment_grid()
  _ensure_spawn_markers()
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
  _ensure_food_plants()


## Creates spawn markers if the scene still uses legacy [code]StartPosition[/code] only.
func _ensure_spawn_markers() -> void:
  var vp := get_viewport().get_visible_rect().size
  var margin_y := vp.y * 0.5
  if get_node_or_null("HerbivoreSpawn") == null:
    var hs := Marker2D.new()
    hs.name = "HerbivoreSpawn"
    hs.position = Vector2(vp.x * 0.68, vp.y * 0.46)
    add_child(hs)
  if get_node_or_null("CarnivoreSpawn") == null:
    var cs := Marker2D.new()
    cs.name = "CarnivoreSpawn"
    cs.position = Vector2(vp.x * 0.18, margin_y)
    add_child(cs)


func _herbivore_spawn_position() -> Vector2:
  var n := get_node_or_null("HerbivoreSpawn")
  if n != null:
    return (n as Node2D).global_position
  var leg := get_node_or_null("StartPosition")
  if leg != null:
    return (leg as Node2D).global_position
  return Vector2(get_viewport().get_visible_rect().size.x * 0.68, get_viewport().get_visible_rect().size.y * 0.46)


func _carnivore_spawn_position() -> Vector2:
  var n := get_node_or_null("CarnivoreSpawn")
  if n != null:
    return (n as Node2D).global_position
  return Vector2(get_viewport().get_visible_rect().size.x * 0.18, get_viewport().get_visible_rect().size.y * 0.5)


func _spawn_duel_carnivore(pos: Vector2) -> void:
  if mob_scene == null:
    OLog.error("Main: mob_scene unset — cannot spawn carnivore.", false, "Main")
    return
  var mob := mob_scene.instantiate() as RigidBody2D
  if mob == null:
    return
  mob.position = pos
  mob.linear_velocity = Vector2.ZERO
  var notifier := mob.get_node_or_null("VisibleOnScreenNotifier2D")
  if notifier != null:
    notifier.queue_free()
  add_child(mob)
  _duel_carnivore = mob
  if mob.has_method(&"prepare_duel_spawn"):
    mob.call(&"prepare_duel_spawn")
  if mob.has_method(&"set_control_mode"):
    mob.call(&"set_control_mode", _MobScr.engine_control_as_int())


func _ensure_food_plants() -> void:
  if get_node_or_null("FoodPlants") != null:
    return
  if _solid_shrub_scene == null:
    _solid_shrub_scene = load(_SOLID_SHRUB_SCENE_PATH) as PackedScene
  if _open_shrub_scene == null:
    _open_shrub_scene = load(_OPEN_SHRUB_SCENE_PATH) as PackedScene
  if _solid_shrub_scene == null or _open_shrub_scene == null:
    OLog.error(
      "Food plant scenes could not be loaded (%s, %s)."
      % [_SOLID_SHRUB_SCENE_PATH, _OPEN_SHRUB_SCENE_PATH],
      false,
      "Main",
    )
    return
  var root := Node2D.new()
  root.name = "FoodPlants"
  add_child(root)
  var solid_positions: Array[Vector2] = [
    Vector2(620.0, 520.0),
    Vector2(1280.0, 180.0),
    Vector2(700.0, 780.0),
  ]
  var open_positions: Array[Vector2] = [
    Vector2(450.0, 680.0),
    Vector2(1250.0, 850.0),
  ]
  for p in solid_positions:
    var s: Node2D = _solid_shrub_scene.instantiate() as Node2D
    s.position = p
    root.add_child(s)
  for p in open_positions:
    var o: Node2D = _open_shrub_scene.instantiate() as Node2D
    o.position = p
    root.add_child(o)


func _reset_food_plants() -> void:
  var fr := get_node_or_null("FoodPlants")
  if fr == null:
    return
  for c in fr.get_children():
    if c.has_method(&"reset_session"):
      c.call(&"reset_session")


func get_environment_grid() -> Resource:
  return environment_grid


func _ensure_environment_grid() -> void:
  if environment_grid != null and environment_grid is EnvironmentGridBaked:
    var g := environment_grid as EnvironmentGridBaked
    if g.is_valid_shape():
      return
  environment_grid = _create_default_open_grid()


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


func _process(_delta: float) -> void:
  pass


func _on_score_timer_timeout() -> void:
  score += 1
  $HUD.update_score(score)


func _on_start_timer_timeout() -> void:
  $ScoreTimer.start()


## Herbivore defeated (mob contact or starvation via [code]hit[/code]).
func _on_player_hit() -> void:
  var prey_cal := 0
  var player := get_node_or_null("Player")
  if player != null:
    var c: Variant = player.get("current_calories")
    if typeof(c) == TYPE_FLOAT or typeof(c) == TYPE_INT:
      prey_cal = int(round(float(c)))
  $HUD.set_carnivore_score_display(prey_cal)
  var tag := "predation_carn_win"
  if player != null and player.has_method(&"was_defeated_by_starvation") and player.call(&"was_defeated_by_starvation"):
    tag = "starvation_herb"
  end_round(tag, "carnivore")


func _on_hud_ai_player_game() -> void:
  $HUD/AIPlayerButton.disabled = true
  _AgentNdjson.write({
    "runId": "cpu-arm",
    "hypothesisId": "H4",
    "location": "main.gd:_on_hud_ai_player_game",
    "message": "cpu_player_pressed_handler_enter",
    "data": {},
  })
  $HUD.show_message("Starting CPU player…")
  var ok: bool = _ai_driver().begin_engine_player_round()
  $HUD/AIPlayerButton.disabled = false
  _AgentNdjson.write({
    "runId": "cpu-arm",
    "hypothesisId": "H4",
    "location": "main.gd:_on_hud_ai_player_game_after_begin",
    "data": {"cpu_begin_ok": ok, "driver_state": _ai_driver().get_state()},
  })
  $HUD.dismiss_message()
  if not ok:
    $HUD.show_message("Could not start CPU player. See logs.")
    $HUD.set_ai_session_state(0)
    return
  new_game()


func _on_hud_end_ai_game() -> void:
  if _ai_driver().get_state() == 1:
    _ai_driver().cancel_armed_session()
    return
  end_round("end_ai", "none")


func _on_ai_session_state_changed(state: int) -> void:
  $HUD.set_ai_session_state(state)
