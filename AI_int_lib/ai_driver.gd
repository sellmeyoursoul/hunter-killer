extends Node
## Autoload AI driver — V3 Step 3 stub: session/LLM + goal-memory storage; zero ENGINE move intent until §12.2 rebuild.

signal ai_session_state_changed(state: int)

enum State {
  IDLE,
  ARMED,
  PLAYING,
  WAITING,
}

const CELL_SIZE: int = 24
const _ControlMode := preload("res://creature/capabilities/creature_control_mode.gd")
const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")
const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")

const _SQRT2_INV: float = 0.7071067811865475
const _EIGHT_WAY_DIRS: Array[Vector3] = [
  Vector3(0.0, 0.0, -1.0),
  Vector3(_SQRT2_INV, 0.0, -_SQRT2_INV),
  Vector3(1.0, 0.0, 0.0),
  Vector3(_SQRT2_INV, 0.0, _SQRT2_INV),
  Vector3(0.0, 0.0, 1.0),
  Vector3(-_SQRT2_INV, 0.0, _SQRT2_INV),
  Vector3(-1.0, 0.0, 0.0),
  Vector3(-_SQRT2_INV, 0.0, -_SQRT2_INV),
]

var _state: State = State.IDLE
var _main: Node = null
var _creature: Node = null
var _registered_creatures: Array = []
var _registered_creature_roots: Array = []
var _primary_creature: Node = null
var _duel_round_active: bool = false
var _duel_motor_round_salt: int = 0

var _arm_session_in_progress: bool = false
var _cpu_player_round_active: bool = false


func _ready() -> void:
  set_physics_process(true)
  set_process(true)


func attach_main(main_node: Node) -> void:
  _main = main_node
  _sync_creature_from_main()
  _goal_belief_reset_all()
  emit_signal("ai_session_state_changed", int(_state))


func _sync_creature_from_main() -> void:
  _creature = null
  if _main != null and _main.has_method(&"get_herbivore_motor_body"):
    _creature = _main.call(&"get_herbivore_motor_body") as Node


func clear_creature_registry() -> void:
  _registered_creatures.clear()
  _registered_creature_roots.clear()
  _creature = null
  _primary_creature = null


func register_creature_root(root: Node) -> void:
  if root == null or not is_instance_valid(root):
    return
  if not root.has_method(&"motor_stack_tick"):
    return
  var id := root.get_instance_id()
  for x in _registered_creature_roots:
    if x is Node and is_instance_valid(x) and (x as Node).get_instance_id() == id:
      return
  _registered_creature_roots.append(root)


func register_creature(node: Node) -> void:
  if node == null or not is_instance_valid(node):
    return
  if _MotorPlane.is_motor_physics_body(node):
    var pb := node as Node
    var id := pb.get_instance_id()
    var already_registered := false
    for x in _registered_creatures:
      if x is Node and is_instance_valid(x) and (x as Node).get_instance_id() == id:
        already_registered = true
        break
    if not already_registered:
      _registered_creatures.append(pb)
    var parent := pb.get_parent()
    if parent != null:
      register_creature_root(parent)
    return
  register_creature_root(node)


func set_primary_creature(node: Node) -> void:
  if node != null and _MotorPlane.is_motor_physics_body(node):
    _primary_creature = node as Node
    _creature = _primary_creature


func sync_duel_control_modes() -> void:
  var engine_int := _ControlMode.engine_as_int()
  for n in _registered_creatures:
    if not (n is Node) or not is_instance_valid(n):
      continue
    var nn := n as Node
    if nn.has_method(&"set_control_mode"):
      nn.call(&"set_control_mode", engine_int)
    _call_set_creature_move_intent(nn, Vector3.ZERO)


func set_duel_round_active(active: bool) -> void:
  _duel_round_active = active


func is_duel_round_active() -> bool:
  return _duel_round_active


func _scripted_motor_roots() -> Array:
  if not _registered_creature_roots.is_empty():
    var out: Array = []
    for n in _registered_creature_roots:
      if n is Node and is_instance_valid(n):
        out.append(n as Node)
    return out
  var fb: Array = []
  for n in _registered_creatures:
    if not _MotorPlane.is_motor_physics_body(n) or not is_instance_valid(n):
      continue
    var parent := (n as Node).get_parent()
    if parent != null and parent.has_method(&"motor_stack_tick"):
      var pid := parent.get_instance_id()
      var seen := false
      for existing in fb:
        if existing is Node and (existing as Node).get_instance_id() == pid:
          seen = true
          break
      if not seen:
        fb.append(parent)
  if fb.is_empty() and _creature != null:
    var cp := _creature.get_parent()
    if cp != null and cp.has_method(&"motor_stack_tick"):
      fb.append(cp)
  return fb


func _scripted_motor_subjects() -> Array:
  if _registered_creatures.is_empty():
    var fb: Array = []
    if _creature != null:
      fb.append(_creature)
    return fb
  var out: Array = []
  for n in _registered_creatures:
    if _MotorPlane.is_motor_physics_body(n) and is_instance_valid(n):
      out.append(n as Node)
  return out


func _clear_registered_creature_move_intents() -> void:
  var seen: Dictionary = {}
  var stack: Array = _registered_creatures.duplicate()
  if _creature != null:
    stack.append(_creature)
  for n in stack:
    if not _MotorPlane.is_motor_physics_body(n) or not is_instance_valid(n):
      continue
    var pb := n as Node
    var id := pb.get_instance_id()
    if seen.has(id):
      continue
    seen[id] = true
    _call_set_creature_move_intent(pb, Vector3.ZERO)
    _clear_creature_wall_slide_away_hint(pb)


func is_human_start_suppressed() -> bool:
  return _state == State.ARMED or _state == State.PLAYING


func get_state() -> int:
  return int(_state)


func get_debug_motor_mobs_snapshot() -> Array:
  return []


func get_debug_carnivore_prey_snapshot(_predator: Node = null) -> Array:
  return []


## Scaled [code]creature_motor_v3[/code] for debug overlay — matches V3 stack perception ([CREATURE_MOVEMENT_V3.md §8.1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func get_debug_motor_v3_params_for_body(body: Node) -> Dictionary:
  if body == null:
    return {}
  return _creature_motor_v3_params_for_body(body)


func _call_set_creature_move_intent(body: Node, intent3: Vector3) -> void:
  if body == null or not body.has_method(&"set_creature_move_intent"):
    return
  body.call(&"set_creature_move_intent", intent3)


func _clear_creature_wall_slide_away_hint(body: Node) -> void:
  if body.has_method(&"clear_wall_slide_away_hint"):
    body.call(&"clear_wall_slide_away_hint")


func _clear_creature_wall_slide_toward_hint(body: Node) -> void:
  if body.has_method(&"clear_wall_slide_toward_hint"):
    body.call(&"clear_wall_slide_toward_hint")


func _viewport_playfield_size(preferred: Node) -> Vector2:
  if _main != null and _main.has_method(&"get_motor_playfield_size"):
    var mps: Variant = _main.call(&"get_motor_playfield_size")
    if typeof(mps) == TYPE_VECTOR2:
      var mv := mps as Vector2
      if mv.x > 0.0 and mv.y > 0.0:
        return mv
  if preferred is CanvasItem:
    var ci := preferred as CanvasItem
    if ci.is_inside_tree():
      return ci.get_viewport_rect().size
  if _main != null:
    var vp_main := _main.get_viewport()
    if vp_main != null:
      return vp_main.get_visible_rect().size
  var st := get_tree()
  if st != null:
    var vp_root := st.root.get_viewport()
    if vp_root != null:
      return vp_root.get_visible_rect().size
  var wh := DisplayServer.window_get_size()
  return Vector2(wh)


func _creature_motor_v3_params_for_body(body: Node) -> Dictionary:
  var motor_v3: Dictionary = _Merge.default_creature_motor_v3_params()
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method(&"get_creature_motor_v3_params"):
    motor_v3 = g.call(&"get_creature_motor_v3_params") as Dictionary
  var def_v: Variant = _MotorPlane.definition_for_body(body)
  if def_v != null and def_v is Resource:
    var def_res := def_v as Resource
    if def_res.get_script() == _CreatureDefinition:
      var pack_v: Variant = def_res.get("asset_pack_root")
      var pack_root := str(pack_v).strip_edges() if pack_v != null else ""
      if not pack_root.is_empty():
        if g != null and g.has_method(&"get_creature_motor_v3_params_for_pack"):
          motor_v3 = g.call(&"get_creature_motor_v3_params_for_pack", pack_root) as Dictionary
        else:
          motor_v3 = _Merge.merge_creature_motor_v3_pack_overlay(
            motor_v3.duplicate(true),
            pack_root,
          )
  var ss: Variant = body.get("screen_size")
  var playfield := ss as Vector2 if typeof(ss) == TYPE_VECTOR2 else Vector2.ZERO
  if playfield == Vector2.ZERO:
    playfield = _viewport_playfield_size(body)
  var dist_scale := _MotorPlane.motor_distance_scale_for_main(_main, playfield)
  return _MotorPlane.scale_motor_distance_params(motor_v3, dist_scale)


func _goal_belief_reset_all() -> void:
  for root in _scripted_motor_roots():
    if root != null and is_instance_valid(root) and root.has_method(&"reset_motor_memory"):
      root.call(&"reset_motor_memory")


func begin_engine_player_round() -> bool:
  if _arm_session_in_progress:
    return false
  if _main == null:
    _OLogSafe.info(
      "AiDriver: cannot start CPU player — attach Main before pressing AI Player.",
      true,
      "AiDriver",
    )
    return false
  if _state == State.PLAYING or _state == State.ARMED:
    return false
  _arm_session_in_progress = true
  _cpu_player_round_active = true
  _set_state(State.ARMED)
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _ControlMode.engine_as_int())
  if _creature != null:
    _call_set_creature_move_intent(_creature, Vector3.ZERO)
  _goal_belief_reset_all()
  _arm_session_in_progress = false
  return true


func cancel_armed_session() -> void:
  if _state != State.ARMED:
    return
  _cpu_player_round_active = false
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _ControlMode.human_as_int())
  if _creature != null:
    _call_set_creature_move_intent(_creature, Vector3.ZERO)
  _goal_belief_reset_all()
  _set_state(State.IDLE)


func _apply_human_control_on_registered_prey() -> void:
  var human_int := _ControlMode.human_as_int()
  for n in _registered_creatures:
    if not (n is Node) or not is_instance_valid(n):
      continue
    var nn := n as Node
    if nn.is_in_group(&"prey") and nn.has_method(&"set_control_mode"):
      nn.call("set_control_mode", human_int)


func _begin_playing_for_creature_goals_duel() -> void:
  var rng := RandomNumberGenerator.new()
  rng.randomize()
  _duel_motor_round_salt = rng.randi()
  _set_state(State.PLAYING)
  _randomize_duel_spawn_facing()
  if _cpu_player_round_active:
    if _creature != null and _creature.has_method("set_control_mode"):
      _creature.call("set_control_mode", _ControlMode.engine_as_int())
  else:
    _apply_human_control_on_registered_prey()


func _randomize_duel_spawn_facing() -> void:
  for n in _registered_creatures:
    if not _MotorPlane.is_motor_physics_body(n) or not is_instance_valid(n):
      continue
    var body := n as Node
    var slot := (body.get_instance_id() ^ _duel_motor_round_salt) & 7
    var facing: Vector3 = _EIGHT_WAY_DIRS[slot]
    if body.has_method(&"apply_duel_spawn_facing"):
      body.call(&"apply_duel_spawn_facing", facing)
    else:
      body.set("last_move_direction", facing)


func notify_main_new_game() -> void:
  _sync_creature_from_main()
  _goal_belief_reset_all()
  match _state:
    State.ARMED:
      _begin_playing_for_creature_goals_duel()
    State.WAITING:
      _cpu_player_round_active = false
      if is_duel_round_active():
        _begin_playing_for_creature_goals_duel()
      else:
        _set_state(State.IDLE)
        if _creature != null and _creature.has_method("set_control_mode"):
          _creature.call("set_control_mode", _ControlMode.human_as_int())
    _:
      if is_duel_round_active():
        _begin_playing_for_creature_goals_duel()
      else:
        _cpu_player_round_active = false
        if _creature != null and _creature.has_method("set_control_mode"):
          _creature.call("set_control_mode", _ControlMode.human_as_int())


func notify_main_game_over() -> void:
  _cpu_player_round_active = false
  _clear_registered_creature_move_intents()
  _duel_motor_round_salt = 0
  _set_state(State.WAITING)
  _goal_belief_reset_all()


func _process(_delta: float) -> void:
  if _state != State.ARMED and _state != State.PLAYING:
    return
  if _state == State.PLAYING and _creature_motor_mode() == "scripted":
    return


func _creature_motor_mode() -> String:
  return "scripted"


func _physics_process(delta: float) -> void:
  if _state != State.PLAYING or _main == null:
    return
  var subjects := _scripted_motor_subjects()
  if subjects.is_empty() and _scripted_motor_roots().is_empty():
    return
  if _creature_motor_mode() != "scripted":
    return
  for root in _scripted_motor_roots():
    if not is_instance_valid(root):
      continue
    var body: Node = null
    if root.has_method(&"get_motor_body"):
      body = root.call("get_motor_body") as Node
    if body == null or not _MotorPlane.is_motor_physics_body(body):
      continue
    var is_pred_subj: bool = body.is_in_group(&"mobs") and not body.is_in_group(&"prey")
    if not is_pred_subj and int(body.get("control_mode")) != _ControlMode.engine_as_int():
      continue
    if root.has_method(&"motor_stack_tick"):
      root.call("motor_stack_tick", delta)


func _set_state(next_state: State) -> void:
  if _state == next_state:
    return
  if _state == State.PLAYING and next_state != State.PLAYING:
    _goal_belief_reset_all()
  _state = next_state
  emit_signal("ai_session_state_changed", int(_state))
