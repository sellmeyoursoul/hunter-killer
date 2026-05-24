extends Node
## Autoload AI driver for remote TinyLlama control flow.
## Owns session state, request ordering, and virtual intent updates.

signal ai_session_state_changed(state: int)
signal ai_inference_started(request_id: int)
signal ai_inference_finished(action_token: String)

enum State {
  IDLE,
  ARMED,
  PLAYING,
  WAITING,
}

const CELL_SIZE: int = 24
const _TOKENS := preload("res://AI_int_lib/ai_action_tokens.gd")
const _WIRE := preload("res://AI_int_lib/perception_wire.gd")
const _RISK := preload("res://AI_int_lib/perception_risk_hints.gd")
const _SAMPLING := preload("res://AI_int_lib/perception_sampling.gd")
const _MOTOR := preload("res://creature/motor/cardinal_avoidance.gd")
const _ExploreScr := preload("res://creature/motor/expanding_cardinal_explore.gd")
const _PlayerScr := preload("res://player.gd")
const _IntentHoldScr := preload("res://creature/motor/scripted_intent_hold.gd")
const _NoGoalPatrolLockScr := preload("res://creature/motor/no_goal_patrol_lock.gd")
const _JeopardyTurnScr := preload("res://creature/motor/jeopardy_forced_turn.gd")
const _OLogSafe := preload("res://AI_int_lib/olog_safe.gd")
const _Merge := preload("res://AI_int_lib/game_config_merge.gd")
const _GeomScr := preload("res://creature/motor/motor_obstacle_geometry.gd")
const _CreatureDefinition := preload("res://creature/definition/creature_definition.gd")

const _SYSTEM_PROMPT_PATH := "res://AI_int_lib/system_prompt.txt"
const _ARMED_HANDSHAKE_USER := "ARMED"
## Separates system rules from handshake / observation in one [code]/v1/completions[/code] prompt (no chat roles).
const _COMPLETION_PROMPT_SEPARATOR := "\n\n---\n\n"
## Appended after the user blob so the last tokens prime a single-token reply (completions continue from context end).
const _COMPLETION_OUTPUT_TRAILER_ARMED := (
  "\n\n=== YOUR_TURN ===\n"
  + "The line above is the handshake payload only.\n"
  + "Reply with exactly one token: START in ALL CAPS. No other characters or words.\n"
)
const _COMPLETION_OUTPUT_TRAILER_PLAYING := (
  "\n\n=== YOUR_TURN ===\n"
  + "The block above is the observation snapshot for this tick.\n"
  + "Read PLAIN_HINT and RISK_HINTS before interpreting the ASCII grid.\n"
  + "Reply with exactly one movement token: UP, DOWN, LEFT, or RIGHT in ALL CAPS. No other characters or words.\n"
)


## GBNF passed to llama.cpp [code]/v1/completions[/code] as [code]grammar[/code] so tiny models cannot drift into newlines or prompt echo.
## Params:
## - state_enum: [enum State] encoded as int ([code]1[/code] ARMED, [code]2[/code] PLAYING).
## Returns:
## - Grammar string, or empty when grammar does not apply.
static func gbnf_for_completion_state_enum(state_enum: int) -> String:
  match state_enum:
    1:
      return "root ::= \"START\"\n"
    2:
      return "root ::= \"UP\" | \"DOWN\" | \"LEFT\" | \"RIGHT\"\n"
    _:
      return ""


## Maps merged [code]creature_motor.mode[/code] to [code]player.gd[/code] control int when **ARMED ΓåÆ PLAYING** ([method notify_main_new_game]); unknown modes map to ENGINE (same rule as [code]_creature_motor_mode[/code]).
## Params:
## - motor_mode: Raw [code]mode[/code] string from merged config (case-insensitive).
## Returns:
## - [code]ai_control_as_int()[/code] for [code]llm[/code], else [code]engine_control_as_int()[/code] on the preloaded player script.
static func playing_control_mode_int_for_motor_mode_string(motor_mode: String) -> int:
  var norm := str(motor_mode).to_lower().strip_edges()
  return _PlayerScr.ai_control_as_int() if norm == "llm" else _PlayerScr.engine_control_as_int()


const _LauncherScript := preload("res://AI_int_lib/bundled_inference_launcher.gd")
const _AgentNdjson := preload("res://AI_int_lib/agent_ndjson_sink.gd")
## Max characters of model [code]content[/code] included in [method OLog.debug] lines (avoid huge perception blobs in logs).
const _TL_DEBUG_CONTENT_MAX_CHARS: int = 200

#region agent log
const _DBG46_SESSION := "46c25f"
const _DBG46_REL := "res://debug-46c25f.log"


## Appends one NDJSON line for debug session 46c25f (no API keys, no full blobs).
static func _dbg46_emit(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
  var payload := {
    "sessionId": _DBG46_SESSION,
    "runId": run_id,
    "hypothesisId": hypothesis_id,
    "location": location,
    "message": message,
    "data": data,
    "timestamp": int(Time.get_unix_time_from_system() * 1000.0),
  }
  var line := JSON.stringify(payload)
  var abs_path := ProjectSettings.globalize_path(_DBG46_REL).replace("\\", "/")
  var f: FileAccess = null
  if FileAccess.file_exists(abs_path):
    f = FileAccess.open(abs_path, FileAccess.READ_WRITE)
    if f != null:
      f.seek_end()
  else:
    f = FileAccess.open(abs_path, FileAccess.WRITE)
  if f == null:
    return
  f.store_line(line)
  f.close()
#endregion

var _state: State = State.IDLE
var _main: Node = null
## Body used for snapshots and ENGINE motor context ([code]Player[/code] herbivore or duel [code]RigidBody2D[/code] carnivore when routed here).
var _creature: PhysicsBody2D = null
## CREATURE_GOALS duel bodies Main registers each round ([method register_creature]); scripted ENGINE motor iterates this list.
var _registered_creatures: Array = []
## Herbivore focal node for LLM snapshot sampling ([method _build_snapshot_blob]); when null, falls back to [member _creature].
var _primary_creature: PhysicsBody2D = null
## True during an active duel round ([method Main.new_game] ΓÇª [method Main.game_over]); used by awareness debug overlay gating.
var _duel_round_active: bool = false
## Per-round salt for motor tie-break / cost chaos (set in [_begin_playing_for_creature_goals_duel]).
var _duel_motor_round_salt: int = 0
var _inference_client: Dictionary = {}
var _system_prompt: String = ""

var _http_request: HTTPRequest
var _latest_snapshot: String = ""
var _has_snapshot: bool = false
var _physics_ticks: int = 0

## Last mob samples passed to the cardinal motor ([method _build_motor_context]); duplicated for the awareness debug overlay.
var _debug_last_motor_mobs: Array = []

var _request_id_counter: int = 0
var _latest_enqueued_request_id: int = -1
var _inflight_request_id: int = -1
var _next_inference_ms: int = 0
var _last_inference_url: String = ""

## Throttles editor-facing [code]noop[/code] diagnostics so tiny models at high cadence do not flood Output.
var _noop_diag_last_ms: int = 0

## Last completions request shape for Cursor NDJSON debug (session 46c25f).
var _last_request_used_completions: bool = false
var _last_prompt_tail: String = ""
var _last_user_head: String = ""
var _last_completion_grammar: String = ""

var _bundled_launcher: Node

## Per-body sticky intent state for scripted ENGINE motor ([method scripted_intent_hold.filtered_intent]).
var _scripted_intent_hold_state_by_body: Dictionary = {}
## Per-body no-goal patrol lock ([method no_goal_patrol_lock.pick_or_hold]).
var _no_goal_patrol_lock_state_by_body: Dictionary = {}
## Per-body jeopardy streak state ([method jeopardy_forced_turn.evaluate_jeopardy_tick]).
var _jeopardy_forced_turn_state_by_body: Dictionary = {}
## Herbivore flee latch + locked flee cardinal (prevents flee direction flip every tick).
var _herbivore_flee_latch_by_body: Dictionary = {}
var _herbivore_flee_lock_by_body: Dictionary = {}
## Latched cardinal for geometry / stuck escape (prevents per-tick LEFT/RIGHT flip).
var _geometry_escape_lock_by_body: Dictionary = {}
var _warned_missing_creature_pack_by_id: Dictionary = {}

## Ring buffer of mob snapshots for motor memory: each entry maps [code]RigidBody2D.get_instance_id()[/code] to [code]{ "position", "velocity" }[/code].
var _mob_hist: Array = []

## Instance ids of mobs that have been inside effective awareness at least once this round; gates extrapolated [code]gated[/code] samples and [code]ghost[/code] entries to observed mobs only.
var _mob_ids_ever_observed: Dictionary = {}

## GOAL-TARGET MEMORY (not implemented ΓÇö design anchor for ENGINE + future LLM beliefs).
## Spec: [i]Draft_Features/CREATURE_MEMORY.md[/i] + [i]Draft_Features/CREATURE_MOVEMENT_V2.md[/i]; config keys use [code]goal_memory_*[/code] (+ [code]weight_seek_remembered_goal[/code]). Do not introduce [code]food_memory_*[/code] aliases in code or config merges.
## Rough draft: per-round table keyed by target [code]instance_id[/code] ΓÇö e.g. [code]food_plants[/code] bushes, prey bodies, mates, squeeze/nest cues ΓÇö discriminator TBD alongside [code]SeekCandidate[/code] fa├ºade.
## - [b]Precise tier ΓÇö stationary[/b]: while remembered and distance to last world pos lies within [code]goal_memory_precise_radius_px[/code] (baseline **1000** in merge comments), merge exact [code]Vector2[/code] into seek/unready pathways (today [code]food_seek_targets[/code] / analogous lists until unified).
## - [b]Precise tier ΓÇö moving[/b]: small disk around last known position (radius [code]goal_memory_moving_last_known_radius_px[/code], clamp [code]Γëñ goal_memory_precise_radius_px[/code] unless waived) ΓÇö see CREATURE_MOVEMENT_V2 ┬ºF.
## - [b]Coarse tier[/b]: beyond precise envelope but not forgotten ΓÇö do **not** store a fixed world compass label; each tick recompute an **egocentric** 8-way bucket from [code]entry.world_pos - creature_pos[/code]: N, NE, E, SE, S, SW, W, NW (45┬░ sectors, +Y = N in world space). Use for weak motor bias, jeopardy routing, or perception text only. Discard coarse-only entries after [code]goal_memory_coarse_ttl_sec[/code] continuously in coarse (CREATURE_MEMORY ┬º5.3).
## Alternatives to weigh: (A) mirror [_mob_hist] ghosts + [code]awareness_memory_*[/code] decay at last position; (B) reuse [_explore_trail_record] grid cells per bush id (cheaper, blurs individual plants); (C) precise-only with no coarse tier (simplest, amnesia outside 1000px).
## Open design ΓÇö direction vs movement: the 8-way label **changes as the creature moves** because it is relative to current position, not a map-fixed bearing. That is intentional for "where is it from here?" navigation; map-fixed bearing needs stored world pos + separate landmark logic.
## Open design ΓÇö forget: candidates ΓÇö [code]distance > goal_memory_forget_radius_px[/code]; [code]Time.get_ticks_msec() - last_observed_ms > goal_memory_ttl_sec[/code]; coarse-only TTL [code]goal_memory_coarse_ttl_sec[/code]; session reset; LRU cap [code]goal_memory_max_entries[/code]. Readiness ([code]is_pickup_ready_for_motor[/code]) should freeze at last observation until the bush re-enters awareness (same rule as mob plant beliefs in HUNGER archive ┬º4.11).
## Open design ΓÇö predator / moving food: update [code]world_pos[/code] + [code]velocity[/code] every tick in awareness; out of cone extrapolate like [_motor_mobs_array] ghosts; coarse 8-way is a poor primary cue for movers ΓÇö prefer velocity bearing or precise tier only while chase is plausible.
## Planned hooks: [code]_goal_belief_reset()[/code], [code]_goal_belief_sync_from_scene()[/code] after live awareness ingest (today [_motor_food_plants_in_awareness_by_readiness]), merge remembered precise targets in [_build_motor_context]; optional [code]res://creature/motor/goal_source_memory.gd[/code].
# var _goal_belief: Dictionary = {}

## True while [method arm_ai_session] is in progress (awaiting bundled inference) or a synchronous CPU arm is finishing.
var _arm_session_in_progress: bool = false

## When true from [method begin_engine_player_round], [method _creature_motor_mode] behaves as scripted (local motor only) until round end.
var _cpu_player_round_active: bool = false

## Coverage trail cell centers keyed by creature instance id ([method _explore_trail_record]).
var _explore_trail_centers_by_body: Dictionary = {}
var _explore_trail_last_cell_by_body: Dictionary = {}
## Latest obstacle geometry from scene ([method _refresh_motor_obstacle_cache_if_needed]).
var _motor_obstacle_collect_tick: int = -1
var _motor_obstacle_aabbs: Array = []
var _motor_obstacle_samples: PackedVector2Array = PackedVector2Array()
## ENGINE: consecutive ticks with nonzero intent but barely moved (wall slide / clamp); keyed by instance id.
var _motor_stuck_ticks: Dictionary = {}
var _motor_stuck_last_pos: Dictionary = {}
## Prey: consecutive ticks idle/stuck while adjacent to a ready food target (releases seek for patrol lock).
var _forage_plateau_ticks_by_body: Dictionary = {}
## Last seen prey pose per carnivore instance id when rabbit/player leaves awareness cone (duel search).
var _predator_prey_memory_by_id: Dictionary = {}
## True after carnivore has had prey inside live awareness this round (gates memory chase).
var _predator_prey_ever_seen_by_id: Dictionary = {}

## Monotonic id for each [method arm_ai_session] entry; helps detect overlapping arms in NDJSON (debug).
static var _debug_arm_invoke_seq: int = 0


## Resolves viewport pixel size for motor bounds when [member Player.screen_size] / mob [member Mob.screen_size] is zero or the node cannot query [method CanvasItem.get_viewport_rect] yet.
## Params:
## - preferred: Creature node ([PhysicsBody2D] under Main); uses its viewport when it is inside the scene tree.
## Returns:
## - Visible viewport size; falls back to Main / scene root / window dimensions so callers avoid empty [Rect2] when off-tree.
## Example:
## - Use instead of raw [code]get_viewport_rect()[/code] during spawn ordering where [code]prepare_duel_spawn[/code] ran before [method Node.add_child].
func _viewport_playfield_size_px(preferred: Node) -> Vector2:
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


## Returns merged [code]creature_motor[/code] from autoload [code]GameConfig[/code], or merge defaults when absent (headless tool loads).
func _live_creature_motor_params() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_creature_motor_params"):
    return g.call("get_creature_motor_params") as Dictionary
  return (_Merge.default_root()["creature_motor"] as Dictionary).duplicate(true)


## Spine + profile motor params merged with [code]CreatureDefinition.asset_pack_root[/code] when set on [param body].
## Params:
## - body: Duel [code]Player[/code] or [code]Mob[/code] with optional [code]definition[/code] resource.
## Returns:
## - Merged [code]creature_motor[/code] dict for cardinal motor and awareness on that body.
func _creature_motor_params_for_body(body: PhysicsBody2D) -> Dictionary:
  var base := _live_creature_motor_params()
  if body == null:
    return base
  var def_v: Variant = body.get("definition")
  if def_v == null or not (def_v is Resource):
    return base
  var def_res := def_v as Resource
  if def_res.get_script() != _CreatureDefinition:
    return base
  var pack_v: Variant = def_res.get("asset_pack_root")
  var pack_root := str(pack_v).strip_edges() if pack_v != null else ""
  if pack_root.is_empty():
    var bid := body.get_instance_id()
    if not _warned_missing_creature_pack_by_id.has(bid):
      _warned_missing_creature_pack_by_id[bid] = true
      OLog.error(
        "Creature motor: asset_pack_root empty on '%s' — pack_resources.json overlay skipped; motion may oscillate (dev spine / high chaos)."
        % str(body.name),
        false,
        "AiDriver",
      )
    return base
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_creature_motor_params_for_pack"):
    return g.call("get_creature_motor_params_for_pack", pack_root) as Dictionary
  return _Merge.merge_creature_motor_pack_overlay(base.duplicate(true), pack_root)


## Applies [code]creature_motor.speed[/code] from pack overlay when the body exposes [code]speed[/code].
func _apply_creature_speed_from_pack(body: PhysicsBody2D) -> void:
  if body == null:
    return
  var motor_p := _creature_motor_params_for_body(body)
  if not motor_p.has("speed"):
    return
  var sp := float(motor_p["speed"])
  if sp <= 1.0:
    return
  body.set("speed", sp)


## Returns merged [code]perception[/code] dict (same fallback pattern as [_live_creature_motor_params]).
func _live_perception_params() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_perception_params"):
    return g.call("get_perception_params") as Dictionary
  return _Merge.default_perception_params().duplicate(true)


## Returns merged [code]inference_client[/code] dict (same fallback pattern as [_live_creature_motor_params]).
func _live_inference_client() -> Dictionary:
  var g := get_node_or_null("/root/GameConfig")
  if g != null and g.has_method("get_inference_client"):
    return g.call("get_inference_client") as Dictionary
  return (_Merge.default_root()["inference_client"] as Dictionary).duplicate(true)


## Clears ENGINE coverage trail (new round, attach, or session end).
func _explore_trail_reset() -> void:
  _explore_trail_centers_by_body.clear()
  _explore_trail_last_cell_by_body.clear()
  _motor_stuck_ticks.clear()
  _motor_stuck_last_pos.clear()
  _forage_plateau_ticks_by_body.clear()
  _motor_obstacle_collect_tick = -1


## Records a trail sample when [param world] enters a new coarse grid cell ([code]explore_coverage_cell_px[/code] from [param motor_p]).
## Params:
## - body: Playable creature whose path is tracked (keyed by instance id).
## - motor_p: Merged [code]creature_motor[/code].
func _explore_trail_record(body: PhysicsBody2D, motor_p: Dictionary) -> void:
  if body == null:
    return
  var bid := body.get_instance_id()
  var cell_px := maxf(16.0, float(motor_p.get("explore_coverage_cell_px", 52.0)))
  var ix := int(floorf(body.global_position.x / cell_px))
  var iy := int(floorf(body.global_position.y / cell_px))
  var c := Vector2i(ix, iy)
  if not _explore_trail_last_cell_by_body.has(bid):
    _explore_trail_last_cell_by_body[bid] = Vector2i(2147483647, 2147483647)
  var last_cell: Vector2i = _explore_trail_last_cell_by_body[bid]
  if c == last_cell:
    return
  _explore_trail_last_cell_by_body[bid] = c
  var center := Vector2((float(ix) + 0.5) * cell_px, (float(iy) + 0.5) * cell_px)
  if not _explore_trail_centers_by_body.has(bid):
    _explore_trail_centers_by_body[bid] = []
  var trail: Array = _explore_trail_centers_by_body[bid]
  trail.append(center)
  var cap := maxi(8, int(motor_p.get("explore_trail_max_cells", 96)))
  while trail.size() > cap:
    trail.pop_front()


func _scripted_intent_hold_state_for(body_id: int) -> Dictionary:
  if not _scripted_intent_hold_state_by_body.has(body_id):
    _scripted_intent_hold_state_by_body[body_id] = {}
  return _scripted_intent_hold_state_by_body[body_id]


## Per-body patrol lock while [code]motor_has_active_goal[/code] is false.
func _no_goal_patrol_lock_state_for(body_id: int) -> Dictionary:
  if not _no_goal_patrol_lock_state_by_body.has(body_id):
    _no_goal_patrol_lock_state_by_body[body_id] = {}
  return _no_goal_patrol_lock_state_by_body[body_id]


func _jeopardy_state_for(body_id: int) -> Dictionary:
  if not _jeopardy_forced_turn_state_by_body.has(body_id):
    _jeopardy_forced_turn_state_by_body[body_id] = {}
  return _jeopardy_forced_turn_state_by_body[body_id]


func _motor_reset_scripted_auxiliary_states() -> void:
  _scripted_intent_hold_state_by_body.clear()
  _no_goal_patrol_lock_state_by_body.clear()
  _jeopardy_forced_turn_state_by_body.clear()
  _predator_prey_memory_by_id.clear()
  _predator_prey_ever_seen_by_id.clear()
  _herbivore_flee_latch_by_body.clear()
  _herbivore_flee_lock_by_body.clear()
  _geometry_escape_lock_by_body.clear()
  _forage_plateau_ticks_by_body.clear()
  _warned_missing_creature_pack_by_id.clear()


func _refresh_motor_obstacle_cache_if_needed() -> void:
  if _main == null:
    _motor_obstacle_aabbs.clear()
    _motor_obstacle_samples = PackedVector2Array()
    return
  if _motor_obstacle_collect_tick == _physics_ticks:
    return
  _motor_obstacle_collect_tick = _physics_ticks
  var pack: Dictionary = _GeomScr.collect_from_scene_tree(_main)
  _motor_obstacle_aabbs = pack.get("aabbs", []) as Array
  var sp: Variant = pack.get("sample_points", PackedVector2Array())
  _motor_obstacle_samples = sp as PackedVector2Array if sp is PackedVector2Array else PackedVector2Array()


func _ready() -> void:
  _system_prompt = FileAccess.get_file_as_string(_SYSTEM_PROMPT_PATH).strip_edges()
  _http_request = HTTPRequest.new()
  add_child(_http_request)
  _http_request.request_completed.connect(_on_http_request_completed)
  _bundled_launcher = _LauncherScript.new()
  add_child(_bundled_launcher)
  _refresh_inference_client_config()
  set_physics_process(true)
  set_process(true)


## Registers scene references used for round lifecycle hooks and snapshot sampling.
## Params:
## - main_node: Main scene root node.
## Returns / side effects:
## - Stores references and emits current state to listeners.
## Usage:
## - Call once from Main._ready().
func attach_main(main_node: Node) -> void:
  _main = main_node
  _creature = _main.get_node_or_null("Player") as PhysicsBody2D
  _motor_reset_scripted_auxiliary_states()
  _mob_hist.clear()
  _mob_ids_ever_observed.clear()
  _explore_trail_reset()
  emit_signal("ai_session_state_changed", int(_state))


## Clears the duel creature registry before [method Main.new_game] re-registers spawn bodies.
func clear_creature_registry() -> void:
  _registered_creatures.clear()


## Registers a playable [PhysicsBody2D] for scripted ENGINE motor iteration ([method sync_duel_control_modes]). Ignores null and duplicate instance ids.
## Params:
## - node: Main [code]Player[/code] ([CharacterBody2D]) or duel carnivore ([RigidBody2D]).
func register_creature(node: Node) -> void:
  if node == null or not is_instance_valid(node):
    return
  if not (node is PhysicsBody2D):
    return
  var pb := node as PhysicsBody2D
  _apply_creature_speed_from_pack(pb)
  var id := pb.get_instance_id()
  for x in _registered_creatures:
    if x is Node and is_instance_valid(x) and (x as Node).get_instance_id() == id:
      return
  _registered_creatures.append(pb)


## Sets the herbivore body whose view the LLM snapshot represents ([method _build_snapshot_blob]).
## Params:
## - node: Main [code]Player[/code] expected for CREATURE_GOALS duel.
func set_primary_creature(node: Node) -> void:
  if node != null and node is PhysicsBody2D:
    _primary_creature = node as PhysicsBody2D


## Applies ENGINE control + zero intent on every registered creature (duel bootstrap after [method register_creature]).
func sync_duel_control_modes() -> void:
  var engine_int := _PlayerScr.engine_control_as_int()
  for n in _registered_creatures:
    if not (n is Node) or not is_instance_valid(n):
      continue
    var nn := n as Node
    if nn.has_method(&"set_control_mode"):
      nn.call(&"set_control_mode", engine_int)
    if nn.has_method(&"set_creature_move_intent"):
      nn.call(&"set_creature_move_intent", Vector2.ZERO)
    if nn is PhysicsBody2D:
      _apply_creature_speed_from_pack(nn as PhysicsBody2D)


func set_duel_round_active(active: bool) -> void:
  _duel_round_active = active


func is_duel_round_active() -> bool:
  return _duel_round_active


## Scripted ENGINE motor targets each physics tick ([member _registered_creatures]); empty registry falls back to [member _creature].
func _scripted_motor_subjects() -> Array:
  if _registered_creatures.is_empty():
    var fb: Array = []
    if _creature != null:
      fb.append(_creature)
    return fb
  var out: Array = []
  for n in _registered_creatures:
    if n is PhysicsBody2D and is_instance_valid(n):
      out.append(n as PhysicsBody2D)
  return out


## Zeros [method PhysicsBody2D.set_creature_move_intent] on registered duel bodies plus legacy [member _creature] (deduped by instance id).
func _clear_registered_creature_move_intents() -> void:
  var seen: Dictionary = {}
  var stack: Array = _registered_creatures.duplicate()
  if _creature != null:
    stack.append(_creature)
  for n in stack:
    if not (n is PhysicsBody2D) or not is_instance_valid(n):
      continue
    var pb := n as PhysicsBody2D
    var id := pb.get_instance_id()
    if seen.has(id):
      continue
    seen[id] = true
    if pb.has_method(&"set_creature_move_intent"):
      pb.call(&"set_creature_move_intent", Vector2.ZERO)


## True when human Start input must be ignored by HUD/Main.
## Params:
## - none
## Returns:
## - true while [enum State.ARMED] (round begins after **AI Player** without a separate Start) or [enum State.PLAYING].
func is_human_start_suppressed() -> bool:
  return _state == State.ARMED or _state == State.PLAYING


## Returns current AI session state enum encoded as int.
## Params:
## - none
## Returns:
## - One value from AiDriver.State.
## Usage:
## - HUD/Main use this for initial control sync.
func get_state() -> int:
  return int(_state)


## Debug-only copy of [member _debug_last_motor_mobs] (deep duplicate safe for overlay readers).
## Params:
## - none
## Returns:
## - Array of mob dicts with [code]position[/code], [code]velocity[/code], [code]cost_scale[/code], optional [code]_motor_debug_source[/code] ([code]live[/code] | [code]gated[/code] | [code]ghost[/code]).
func get_debug_motor_mobs_snapshot() -> Array:
  return _debug_last_motor_mobs.duplicate(true)


## Cone extension for **prey** pursuit gating. Uses [code]predator_prey_awareness_cone_extra[/code] when [code]> 0[/code]; otherwise falls back to hybrid [code]awareness_cone_extra[/code].
func _predator_prey_cone_extra(motor_p: Dictionary) -> float:
  if motor_p.has("predator_prey_awareness_cone_extra"):
    var prey_only := float(motor_p.get("predator_prey_awareness_cone_extra", 0.0))
    if prey_only > 0.0:
      return prey_only
  return maxf(0.0, float(motor_p.get("awareness_cone_extra", 0.0)))


## Prey world positions reachable under merged motor awareness gates ([code]weight_seek_prey[/code] pull uses these).
## Params:
## - predator: Carnivore body ([RigidBody2D] mob).
## Returns:
## - Array of [code]Vector2[/code]; empty when awareness disabled or scene missing.
func _prey_positions_for_predator_motor(predator: PhysicsBody2D) -> Array:
  if predator == null or _main == null:
    return []
  var motor_p := _creature_motor_params_for_body(predator)
  var awareness_r := float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return []
  var creature_pos := predator.global_position
  var he_xy := Vector2(
    maxf(0.0, float(motor_p.get("creature_half_extent_x", 13.5))),
    maxf(0.0, float(motor_p.get("creature_half_extent_y", 30.5))),
  )
  var cs_shape := predator.get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs_shape != null and cs_shape.shape is CapsuleShape2D:
    var cap := cs_shape.shape as CapsuleShape2D
    he_xy = Vector2(
      maxf(0.0, cap.radius),
      maxf(0.0, cap.radius + cap.height * 0.5),
    )
  var cone_extra := _predator_prey_cone_extra(motor_p)
  var half_deg := float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos := cos(deg_to_rad(half_deg))
  var facing := Vector2.RIGHT
  var fd: Variant = predator.get("last_move_direction")
  if typeof(fd) == TYPE_VECTOR2:
    var fv := fd as Vector2
    if fv.length() > 1e-4:
      facing = fv.normalized()
  var omni := bool(motor_p.get("predator_prey_awareness_omni", false))
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  var out: Array = []
  for n in _main.get_tree().get_nodes_in_group(&"prey"):
    if not (n is Node2D):
      continue
    var prey_node := n as Node
    if prey_node == predator:
      continue
    var prey_pos := (n as Node2D).global_position
    var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, prey_pos)
    if omni:
      if gd <= awareness_r:
        out.append(prey_pos)
    else:
      var eff := _effective_awareness_reach_for_driver(
        creature_pos, prey_pos, awareness_r, cone_extra, cone_cos, facing, forward_cone_only
      )
      if gd <= eff:
        out.append(prey_pos)
  return out


## Test/helper: prey positions under explicit motor params and facing (mirrors [_prey_positions_for_predator_motor] gating).
func _collect_prey_positions(
  predator: PhysicsBody2D,
  motor_p: Dictionary,
  creature_pos: Vector2,
  he_xy: Vector2,
) -> Array:
  if predator == null or _main == null:
    return []
  var awareness_r := float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return []
  var cone_extra := _predator_prey_cone_extra(motor_p)
  var half_deg := float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos := cos(deg_to_rad(half_deg))
  var facing := Vector2.RIGHT
  var fd: Variant = predator.get("last_move_direction")
  if typeof(fd) == TYPE_VECTOR2:
    var fv := fd as Vector2
    if fv.length() > 1e-4:
      facing = fv.normalized()
  var omni := bool(motor_p.get("predator_prey_awareness_omni", false))
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  var out: Array = []
  for n in _main.get_tree().get_nodes_in_group(&"prey"):
    if not (n is Node2D):
      continue
    if (n as Node) == predator:
      continue
    var prey_pos := (n as Node2D).global_position
    var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, prey_pos)
    if omni:
      if gd <= awareness_r:
        out.append(prey_pos)
    else:
      var eff := _effective_awareness_reach_for_driver(
        creature_pos, prey_pos, awareness_r, cone_extra, cone_cos, facing, forward_cone_only
      )
      if gd <= eff:
        out.append(prey_pos)
  return out


## Records last prey position/velocity when [param prey_pts] is non-empty (predator instance id key).
func _predator_prey_memory_touch(
  predator: PhysicsBody2D, prey_pts: Array, pursuit_targets: Array
) -> void:
  if predator == null or prey_pts.is_empty():
    return
  _predator_prey_ever_seen_by_id[predator.get_instance_id()] = true
  var pred_pos := predator.global_position
  var best_pos := pred_pos
  var best_d_sq := INF
  for pq in prey_pts:
    if typeof(pq) != TYPE_VECTOR2:
      continue
    var p := pq as Vector2
    var d_sq := pred_pos.distance_squared_to(p)
    if d_sq < best_d_sq:
      best_d_sq = d_sq
      best_pos = p
  var best_vel := Vector2.ZERO
  for item in pursuit_targets:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var ppos: Vector2 = item.get("position", Vector2.ZERO)
    if ppos.distance_squared_to(best_pos) < 64.0:
      var pvel: Variant = item.get("velocity", Vector2.ZERO)
      if typeof(pvel) == TYPE_VECTOR2:
        best_vel = pvel as Vector2
      break
  _predator_prey_memory_by_id[predator.get_instance_id()] = {
    "position": best_pos,
    "velocity": best_vel,
    "last_seen_ms": Time.get_ticks_msec(),
  }


## Returns stale prey snapshot for search when live [param prey_pts] is empty but memory TTL/radius still valid.
func _predator_prey_memory_sample(
  predator: PhysicsBody2D, motor_p: Dictionary, creature_pos: Vector2
) -> Dictionary:
  var inactive := {
    "active": false,
    "position": Vector2.ZERO,
    "velocity": Vector2.ZERO,
    "strength": 0.0,
  }
  if predator == null:
    return inactive
  var bid := predator.get_instance_id()
  if not _predator_prey_memory_by_id.has(bid):
    return inactive
  var rec: Dictionary = _predator_prey_memory_by_id[bid]
  var ttl_ms := int(float(motor_p.get("predator_prey_memory_sec", 10.0)) * 1000.0)
  var forget_r := float(motor_p.get("predator_prey_memory_forget_radius_px", 2800.0))
  var age_ms := Time.get_ticks_msec() - int(rec.get("last_seen_ms", 0))
  if age_ms > ttl_ms:
    _predator_prey_memory_by_id.erase(bid)
    return inactive
  var mem_pos: Vector2 = rec.get("position", Vector2.ZERO)
  if creature_pos.distance_to(mem_pos) > forget_r:
    _predator_prey_memory_by_id.erase(bid)
    return inactive
  var strength := clampf(1.0 - float(age_ms) / float(maxi(1, ttl_ms)), 0.4, 1.0)
  return {
    "active": true,
    "position": mem_pos,
    "velocity": rec.get("velocity", Vector2.ZERO),
    "strength": strength,
  }


## Footprint clearance to the nearest static AABB (surface separation, not center distance).
static func _static_obstacle_slip_info(
  creature_pos: Vector2, he_xy: Vector2, static_obs: Array
) -> Dictionary:
  var best_clear := INF
  var best_center := Vector2.ZERO
  var best_ohe := Vector2.ZERO
  for ob in static_obs:
    if typeof(ob) != TYPE_DICTIONARY:
      continue
    var op: Vector2 = ob.get("position", Vector2.ZERO)
    var ohe_raw: Variant = ob.get("half_extents", Vector2.ZERO)
    var ohe := Vector2.ZERO
    if typeof(ohe_raw) == TYPE_VECTOR2:
      ohe = ohe_raw as Vector2
    var sep := INF
    if ohe.x > 0.0 and ohe.y > 0.0:
      var sep_closest_c: Vector2 = Callable(_MOTOR, &"closest_point_on_aabb").call(creature_pos, he_xy, op)
      var sep_closest_o: Vector2 = Callable(_MOTOR, &"closest_point_on_aabb").call(op, ohe, creature_pos)
      sep = sep_closest_c.distance_to(sep_closest_o)
    else:
      sep = creature_pos.distance_to(op) - maxf(he_xy.x, he_xy.y)
    if sep < best_clear:
      best_clear = sep
      best_center = op
      best_ohe = ohe
  if best_clear >= INF:
    return {"clearance": INF, "ob_center": Vector2.ZERO, "away_dir": Vector2.ZERO}
  var closest_c: Vector2 = Callable(_MOTOR, &"closest_point_on_aabb").call(creature_pos, he_xy, best_center)
  var closest_o: Vector2 = (
    Callable(_MOTOR, &"closest_point_on_aabb").call(best_center, best_ohe, creature_pos)
    if best_ohe.length_squared() > 1e-12
    else best_center
  )
  var away_dir := closest_c - closest_o
  if away_dir.length_squared() < 1e-12:
    away_dir = creature_pos - best_center
  return {"clearance": best_clear, "ob_center": best_center, "away_dir": away_dir}


## Sidestep static solids (fox patrol, rabbit forage/flee). Does not require visible prey.
## Params:
## - is_prey: When true, reads [code]herbivore_obstacle_*[/code] pack keys.
## Returns:
## - [code]true[/code] when ctx was shaped for obstacle slip this tick.
func _motor_obstacle_slip_shaping(
  ctx: Dictionary,
  motor_p: Dictionary,
  creature_pos: Vector2,
  he_xy: Vector2,
  body_id: int,
  stuck_n: int,
  toward_world: Vector2 = Vector2.ZERO,
  is_prey: bool = false,
) -> bool:
  var static_obs: Array = ctx.get("static_obstacles", []) as Array
  var slip_info := _static_obstacle_slip_info(creature_pos, he_xy, static_obs)
  var clearance: float = float(slip_info.get("clearance", INF))
  var nearest_ob: Vector2 = slip_info.get("ob_center", Vector2.ZERO)
  if nearest_ob == Vector2.ZERO or clearance >= INF:
    return false
  var probe_px := float(motor_p.get("predator_obstacle_probe_px", 200.0))
  var slip_w := float(motor_p.get("predator_obstacle_slip_expand_weight", 6.0))
  if is_prey:
    probe_px = float(motor_p.get("herbivore_obstacle_probe_px", probe_px))
    slip_w = float(motor_p.get("herbivore_obstacle_slip_expand_weight", slip_w))
  var tight_clr := clearance < maxf(36.0, maxf(he_xy.x, he_xy.y) * 1.35)
  if clearance > probe_px and stuck_n < 1 and not tight_clr:
    return false
  var away_raw: Variant = slip_info.get("away_dir", Vector2.ZERO)
  var away_ob := away_raw as Vector2 if typeof(away_raw) == TYPE_VECTOR2 else Vector2.ZERO
  if away_ob.length_squared() < 1e-12:
    away_ob = creature_pos - nearest_ob
  if away_ob.length_squared() < 1e-12:
    away_ob = Vector2.RIGHT if bool(body_id & 1) else Vector2.UP
  var slip_dir := away_ob.normalized()
  if stuck_n >= 1:
    var picked := _pick_stuck_escape_cardinal(creature_pos, he_xy, static_obs, body_id, stuck_n)
    if picked.length_squared() > 1e-12:
      slip_dir = picked
    else:
      var tangent := Vector2(-away_ob.y, away_ob.x)
      if tangent.length_squared() < 1e-12:
        tangent = Vector2.UP
      else:
        tangent = tangent.normalized()
      if bool((body_id ^ stuck_n) & 1):
        tangent = -tangent
      slip_dir = tangent
  elif toward_world.length_squared() > 64.0:
    var flank := Vector2(-slip_dir.y, slip_dir.x)
    if flank.dot(toward_world.normalized()) < 0.0:
      flank = -flank
    slip_dir = (slip_dir * 0.35 + flank.normalized() * 0.65).normalized()
  ctx["motor_stuck_allow_expand_hint"] = true
  ctx["creature_nav_slip_active"] = true
  ctx["predator_nav_slip_active"] = true
  ctx["expanding_explore_hint"] = _cardinal_best_aligned_to(slip_dir)
  ctx["weight_expanding_explore_hint"] = maxf(
    float(ctx.get("weight_expanding_explore_hint", 0.0)),
    slip_w,
  )
  ctx["weight_explore_idle_penalty"] = 0.0
  ctx["weight_explore_turn_bias"] = 0.0
  return true


## Carnivore wrapper for [_motor_obstacle_slip_shaping].
func _predator_obstacle_navigation_shaping(
  ctx: Dictionary,
  motor_p: Dictionary,
  creature_pos: Vector2,
  body_id: int,
  stuck_n: int,
  toward_world: Vector2 = Vector2.ZERO,
) -> bool:
  var he_xy: Vector2 = ctx.get("creature_half_extents", Vector2(13.5, 30.5))
  return _motor_obstacle_slip_shaping(
    ctx, motor_p, creature_pos, he_xy, body_id, stuck_n, toward_world, false
  )


## When a carnivore is stuck but still hunting, bias motor ctx to sidestep (flank) instead of pushing through solids toward prey.
## Params:
## - ctx: Motor context dict about to be passed to [code]pick_best_move_intent[/code] (mutated in place).
## - motor_p: Per-body merged motor params.
## - creature_pos: Predator center (world).
## - body_id: Instance id (flank sign alternation).
## - stuck_n: Consecutive stuck ticks from [method _motor_stuck_track_mob].
## - body: Predator body for calorie-driven escape urgency.
func _predator_hunt_stalemate_shaping(
  ctx: Dictionary,
  motor_p: Dictionary,
  creature_pos: Vector2,
  body_id: int,
  stuck_n: int,
  body: PhysicsBody2D,
) -> void:
  var prey_seek: Array = ctx.get("prey_seek_targets", []) as Array
  var pursuit: Array = ctx.get("pursuit_targets", []) as Array
  if prey_seek.is_empty() and pursuit.is_empty():
    return
  var min_stuck := maxi(1, int(motor_p.get("predator_stalemate_stuck_ticks", 1)))
  if stuck_n < min_stuck:
    return
  var prey_pos := _nearest_vector_from_positions(creature_pos, prey_seek)
  if prey_pos == Vector2.ZERO and not pursuit.is_empty():
    var item0: Variant = pursuit[0]
    if typeof(item0) == TYPE_DICTIONARY:
      prey_pos = (item0 as Dictionary).get("position", Vector2.ZERO)
  if prey_pos == Vector2.ZERO:
    return
  var to_prey := prey_pos - creature_pos
  if to_prey.length_squared() < 64.0:
    return
  var flank := Vector2(-to_prey.y, to_prey.x)
  if bool(((body_id >> 1) ^ _physics_ticks) & 1):
    flank = -flank
  var slip_dir := flank
  var static_obs: Array = ctx.get("static_obstacles", []) as Array
  var he_stale: Vector2 = ctx.get("creature_half_extents", Vector2(13.5, 30.5))
  var slip_info := _static_obstacle_slip_info(creature_pos, he_stale, static_obs)
  var nearest_ob: Vector2 = slip_info.get("ob_center", Vector2.ZERO)
  if nearest_ob != Vector2.ZERO:
    var away_ob := creature_pos - nearest_ob
    if away_ob.length_squared() > 1e-12:
      slip_dir = away_ob.normalized() * 0.55 + flank.normalized() * 0.45
  ctx["motor_stuck_allow_expand_hint"] = true
  ctx["predator_stalemate_active"] = true
  if ctx.get("expanding_explore_hint", Vector2.ZERO) is Vector2:
    var eh: Vector2 = ctx["expanding_explore_hint"]
    if eh.length_squared() < 1e-12:
      ctx["expanding_explore_hint"] = _cardinal_best_aligned_to(slip_dir)
  ctx["weight_obstacle"] = (
    float(ctx.get("weight_obstacle", 0.0))
    * float(motor_p.get("predator_stalemate_obstacle_mul", 0.2))
  )
  var cr := 1.0
  var ccal: Variant = body.get("current_calories")
  var cneed: Variant = body.get("caloric_needs")
  if (typeof(ccal) == TYPE_FLOAT or typeof(ccal) == TYPE_INT) and (
    typeof(cneed) == TYPE_FLOAT or typeof(cneed) == TYPE_INT
  ):
    cr = clampf(float(ccal) / maxf(1.0, float(cneed)), 0.0, 1.0)
  var urg := clampf(1.0 - cr, 0.0, 1.0)
  var urg_mul := lerpf(
    1.0,
    float(motor_p.get("predator_stalemate_starvation_mul", 2.0)),
    pow(urg, 0.85),
  )
  var esc_w := float(motor_p.get("weight_stuck_escape_explore", 2.2))
  esc_w *= float(motor_p.get("predator_stalemate_expand_mul", 2.5)) * urg_mul
  ctx["weight_expanding_explore_hint"] = maxf(float(ctx.get("weight_expanding_explore_hint", 0.0)), esc_w)
  ctx["weight_seek_prey"] = 0.0
  ctx["weight_pursuit_dist"] = 0.0
  ctx["weight_pursuit_closing"] = 0.0
  ctx["weight_pursuit_dist_sq"] = 0.0
  ctx["weight_obstacle_pin_predator"] = 0.0
  var static_obs_st: Array = ctx.get("static_obstacles", []) as Array
  var esc_st := _pick_stuck_escape_cardinal(creature_pos, he_stale, static_obs_st, body_id, stuck_n)
  if esc_st.length_squared() > 1e-12:
    ctx["expanding_explore_hint"] = esc_st
  ctx["weight_explore_idle_penalty"] = 0.0
  ctx["weight_explore_trail_repulsion"] = 0.0
  ctx["weight_explore_turn_bias"] = 0.0


## Threat band when carnivore is inside herbivore awareness: [code]none[/code], [code]alert[/code], [code]panic[/code].
func _herbivore_threat_band_aware(
  in_awareness: bool, gate_dist: float, motor_p: Dictionary
) -> StringName:
  if not in_awareness or gate_dist >= INF:
    return &"none"
  var panic_r := float(
    motor_p.get(
      "herbivore_flee_panic_radius_px",
      motor_p.get("herbivore_jeopardy_imminent_radius_px", 200.0),
    )
  )
  if gate_dist <= panic_r:
    return &"panic"
  return &"alert"


## Caution latch: true while predator remains inside awareness cone/disk.
func _herbivore_alert_latched(body_id: int, in_awareness: bool, _gate_dist: float, _motor_p: Dictionary) -> bool:
  if not in_awareness:
    _herbivore_flee_latch_by_body[body_id] = false
    return false
  _herbivore_flee_latch_by_body[body_id] = true
  return true


## Forced flee only when predator is visible in awareness and within panic footprint distance.
func _herbivore_flee_panic_active(
  _body_id: int, in_awareness: bool, gate_dist: float, motor_p: Dictionary
) -> bool:
  return _herbivore_threat_band_aware(in_awareness, gate_dist, motor_p) == &"panic"


## Rotating cardinal when hunt intent produces no displacement (predator).
func _predator_hunt_stuck_rotate_intent(body_id: int, stuck_n: int, motor_p: Dictionary) -> Vector2:
  var rot_ticks := maxi(4, int(motor_p.get("predator_hunt_stuck_rotate_ticks", 10)))
  var hint := _ExploreScr.Explore.pick_cardinal(
    rot_ticks, _physics_ticks, body_id ^ stuck_n ^ _duel_motor_round_salt
  )
  if hint.length_squared() > 1e-12:
    return hint
  return Vector2.LEFT if bool((body_id ^ stuck_n) & 1) else Vector2.RIGHT


## True when live prey or pursuit targets are present in motor ctx.
func _predator_hunt_active_in_ctx(ctx: Dictionary) -> bool:
  return (
    not (ctx.get("prey_seek_targets", []) as Array).is_empty()
    or not (ctx.get("pursuit_targets", []) as Array).is_empty()
  )


## Locked flee cardinal — stable for [code]herbivore_flee_lock_ticks[/code] unless threat moves far.
func _herbivore_locked_flee_intent(
  body_id: int,
  creature_pos: Vector2,
  threat_pos: Vector2,
  bounds_max: Vector2,
  he_xy: Vector2,
  motor_p: Dictionary,
) -> Vector2:
  var lock_ticks := maxi(4, int(motor_p.get("herbivore_flee_lock_ticks", 14)))
  var rec_v: Variant = _herbivore_flee_lock_by_body.get(body_id, null)
  if typeof(rec_v) == TYPE_DICTIONARY:
    var rec: Dictionary = rec_v
    if _physics_ticks < int(rec.get("until_tick", 0)):
      var old_t: Vector2 = rec.get("threat_pos", Vector2.ZERO)
      if old_t.distance_squared_to(threat_pos) < 70.0 * 70.0:
        var locked: Variant = rec.get("dir", Vector2.ZERO)
        if typeof(locked) == TYPE_VECTOR2 and (locked as Vector2).length_squared() > 1e-12:
          return locked as Vector2
  var dir := _herbivore_bounded_flee_intent(
    creature_pos, threat_pos, bounds_max, he_xy, body_id, motor_p
  )
  _herbivore_flee_lock_by_body[body_id] = {
    "dir": dir,
    "until_tick": _physics_ticks + lock_ticks,
    "threat_pos": threat_pos,
  }
  return dir


## Picks the unit cardinal that best aligns with [param world_dir] (for memory search hint).
static func _cardinal_best_aligned_to(world_dir: Vector2) -> Vector2:
  if world_dir.length_squared() < 1e-12:
    return Vector2.ZERO
  var u := world_dir.normalized()
  var best := Vector2.RIGHT
  var best_dot := -INF
  for c in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
    var d := u.dot(c)
    if d > best_dot:
      best_dot = d
      best = c
  return best


## Flee cardinal that moves away from [param threat_pos] without hugging the playfield edge.
func _herbivore_bounded_flee_intent(
  creature_pos: Vector2,
  threat_pos: Vector2,
  bounds_max: Vector2,
  he_xy: Vector2,
  body_id: int,
  motor_p: Dictionary,
) -> Vector2:
  var away := creature_pos - threat_pos
  var away_u := away.normalized() if away.length_squared() > 1e-12 else Vector2.RIGHT
  var edge_w := float(motor_p.get("herbivore_flee_edge_clearance_weight", 6.0))
  var interior_w := float(motor_p.get("herbivore_flee_interior_bias", 1.2))
  var center := bounds_max * 0.5
  var to_center := center - creature_pos
  var center_u := to_center.normalized() if to_center.length_squared() > 1e-12 else Vector2.ZERO
  var cardinals: Array[Vector2] = [
    Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
  ]
  var step := maxf(72.0, maxf(he_xy.x, he_xy.y) * 3.0)
  var best_d := Vector2.RIGHT
  var best_score := -INF
  for k in 4:
    var c: Vector2 = cardinals[(body_id + k + _physics_ticks) % 4]
    var score := c.dot(away_u)
    if center_u.length_squared() > 1e-12:
      score += interior_w * c.dot(center_u)
    var probe := creature_pos + c * step
    var margin := maxf(he_xy.x, he_xy.y) + 24.0
    var edge_clear := minf(
      minf(probe.x - margin, bounds_max.x - margin - probe.x),
      minf(probe.y - margin, bounds_max.y - margin - probe.y),
    )
    score += edge_w * clampf(edge_clear / 120.0, -1.5, 1.5)
    if score > best_score:
      best_score = score
      best_d = c
  return best_d


## Tracks ENGINE carnivore stalls (nonzero intent but almost no displacement); returns consecutive stuck ticks for escape shaping.
func _motor_stuck_track_mob(body: PhysicsBody2D, incumbent_intent: Vector2, motor_p: Dictionary) -> int:
  var sid := body.get_instance_id()
  var pos := body.global_position
  var eps := maxf(0.25, float(motor_p.get("motor_stuck_move_epsilon_px", 1.25)))
  var eps_sq := eps * eps
  var moved := false
  if _motor_stuck_last_pos.has(sid):
    var lp: Vector2 = _motor_stuck_last_pos[sid]
    moved = lp.distance_squared_to(pos) > eps_sq
  _motor_stuck_last_pos[sid] = pos
  var trying := incumbent_intent.length_squared() > 1e-8
  var vel_sq := 0.0
  if body is RigidBody2D:
    vel_sq = (body as RigidBody2D).linear_velocity.length_squared()
  else:
    var cv: Variant = body.get("current_velocity")
    if typeof(cv) == TYPE_VECTOR2:
      vel_sq = (cv as Vector2).length_squared()
    elif body is CharacterBody2D:
      vel_sq = (body as CharacterBody2D).velocity.length_squared()
  var stalled := trying and not moved and vel_sq < eps_sq
  if not stalled:
    _motor_stuck_ticks[sid] = 0
    _geometry_escape_lock_by_body.erase(sid)
    return 0
  var nxt := int(_motor_stuck_ticks.get(sid, 0)) + 1
  _motor_stuck_ticks[sid] = nxt
  return nxt


## Tracks prey ticks spent idle or motor-stuck while footprint-clearance to a food cue is within forage plateau radius.
## Counts ready seek targets while [code]weight_seek_ready_food > 0[/code]; after eating, counts unready avoid targets instead.
## Params:
## - body_id: Prey instance id.
## - ctx: Motor context from [_build_motor_context].
## - incumbent_intent: Held move intent from prior tick.
## - stuck_n: Consecutive stuck ticks from [_motor_stuck_track_mob].
## - motor_p: Merged creature motor pack.
func _track_herbivore_forage_plateau(
  body_id: int,
  ctx: Dictionary,
  incumbent_intent: Vector2,
  stuck_n: int,
  motor_p: Dictionary,
) -> void:
  var w_seek := float(ctx.get("weight_seek_ready_food", 0.0))
  var w_avoid_unready := float(ctx.get("weight_avoid_unready_food", 0.0))
  var food: Array = []
  if w_seek > 0.0:
    food = ctx.get("food_seek_targets", []) as Array
  elif w_avoid_unready > 0.0:
    food = ctx.get("unready_food_avoid_targets", []) as Array
  else:
    _forage_plateau_ticks_by_body[body_id] = 0
    return
  if food.is_empty():
    _forage_plateau_ticks_by_body[body_id] = 0
    return
  var pos: Vector2 = ctx.get("creature_position", Vector2.ZERO)
  var he: Vector2 = ctx.get("creature_half_extents", Vector2.ZERO)
  var nearest_clr := INF
  for t in food:
    if typeof(t) != TYPE_VECTOR2:
      continue
    nearest_clr = minf(
      nearest_clr,
      _MOTOR.minimum_footprint_point_clearance(pos, he, [t as Vector2]),
    )
  if not is_finite(nearest_clr):
    _forage_plateau_ticks_by_body[body_id] = 0
    return
  var plateau_r := float(motor_p.get("motor_forage_plateau_radius_px", 95.0))
  if nearest_clr > plateau_r:
    _forage_plateau_ticks_by_body[body_id] = 0
    return
  var stuck_thr := maxi(1, int(motor_p.get("motor_stuck_escape_ticks", 8)))
  var idle_or_stuck := incumbent_intent.length_squared() < 1e-8 or stuck_n >= stuck_thr
  if idle_or_stuck:
    _forage_plateau_ticks_by_body[body_id] = int(_forage_plateau_ticks_by_body.get(body_id, 0)) + 1
  else:
    _forage_plateau_ticks_by_body[body_id] = 0


## True when prey has lingered adjacent to food without eating or escaping long enough to drop the active seek goal.
func _herbivore_forage_plateau_release(body_id: int, motor_p: Dictionary) -> bool:
  var thr := maxi(1, int(motor_p.get("motor_forage_plateau_ticks", 10)))
  return int(_forage_plateau_ticks_by_body.get(body_id, 0)) >= thr


## When prey is idle adjacent to a depleted bush, nudge away so patrol lock / motor do not hug inedible solids.
## Params:
## - ctx: Motor context from [_build_motor_context].
## - raw_intent: Intent chosen this tick (may be [code]Vector2.ZERO[/code] from patrol lock).
## - motor_p: Merged creature motor pack.
## Returns:
## - Cardinal away-from-unready intent when nudge applies; otherwise [param raw_intent].
func _herbivore_nudge_away_from_unready_if_idle(
  ctx: Dictionary, raw_intent: Vector2, motor_p: Dictionary
) -> Vector2:
  if raw_intent.length_squared() > 1e-8:
    return raw_intent
  var w_avoid := float(ctx.get("weight_avoid_unready_food", 0.0))
  var unready: Array = ctx.get("unready_food_avoid_targets", []) as Array
  if w_avoid <= 0.0 or unready.is_empty():
    return raw_intent
  var pos: Vector2 = ctx.get("creature_position", Vector2.ZERO)
  var he: Vector2 = ctx.get("creature_half_extents", Vector2.ZERO)
  var nearest := _nearest_vector_from_positions(pos, unready)
  if nearest == Vector2.ZERO:
    return raw_intent
  var plateau_r := float(motor_p.get("motor_forage_plateau_radius_px", 95.0))
  var clr := _MOTOR.minimum_footprint_point_clearance(pos, he, [nearest])
  if clr > plateau_r:
    return raw_intent
  var away := _cardinal_best_aligned_to(pos - nearest)
  if away.length_squared() > 1e-12:
    return away
  return raw_intent


## Prey world positions inside the duel carnivore awareness disk + forward cone (matches motor gating math).
## Params:
## - predator: Carnivore body (mob overlay parent); when null, uses the first registered [RigidBody2D] in group [code]mobs[/code].
## Returns:
## - Array of [code]Vector2[/code] suitable for [method awareness_debug_overlay._draw] circles.
func get_debug_carnivore_prey_snapshot(predator: PhysicsBody2D = null) -> Array:
  var pred := predator
  if pred == null:
    for n in _registered_creatures:
      if not (n is RigidBody2D) or not is_instance_valid(n):
        continue
      var rn := n as Node
      if rn.is_in_group(&"mobs"):
        pred = n as PhysicsBody2D
        break
  return _prey_positions_for_predator_motor(pred)


## Merged [code]creature_motor[/code] for debug overlay (pack overlay included).
func get_debug_motor_params_for_body(body: PhysicsBody2D) -> Dictionary:
  if body == null:
    return {}
  return _creature_motor_params_for_body(body)


## Pure helper for latest-enqueued request ordering checks.
## Params:
## - response_id: Request id attached to the completed response.
## - latest_enqueued_request_id: Most recent outbound request id.
## Returns:
## - true only when the response should be applied.
## Usage:
## - Used by runtime response handling and headless tests.
static func should_apply_response_id(response_id: int, latest_enqueued_request_id: int) -> bool:
  return response_id == latest_enqueued_request_id


## Maps [constant HTTPRequest.RESULT_*] to a short label for logs.
static func http_request_result_label(result: int) -> String:
  match result:
    HTTPRequest.RESULT_SUCCESS:
      return "SUCCESS"
    HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
      return "CHUNKED_BODY_SIZE_MISMATCH"
    HTTPRequest.RESULT_CANT_CONNECT:
      return "CANT_CONNECT"
    HTTPRequest.RESULT_CANT_RESOLVE:
      return "CANT_RESOLVE"
    HTTPRequest.RESULT_CONNECTION_ERROR:
      return "CONNECTION_ERROR"
    HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
      return "TLS_HANDSHAKE_ERROR"
    HTTPRequest.RESULT_NO_RESPONSE:
      return "NO_RESPONSE"
    HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
      return "BODY_SIZE_LIMIT_EXCEEDED"
    HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
      return "BODY_DECOMPRESS_FAILED"
    HTTPRequest.RESULT_REQUEST_FAILED:
      return "REQUEST_FAILED"
    HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
      return "DOWNLOAD_FILE_CANT_OPEN"
    HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
      return "DOWNLOAD_FILE_WRITE_ERROR"
    HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
      return "REDIRECT_LIMIT_REACHED"
    HTTPRequest.RESULT_TIMEOUT:
      return "TIMEOUT"
    _:
      return "UNKNOWN_%s" % result


## Flattens OpenAI-style [code]message.content[/code] (string, array of typed blocks, or null) to plain text.
## Params:
## - v: Raw JSON value from [code]choices[0].message.content[/code].
## Returns:
## - Concatenated assistant-visible text; empty string when absent.
static func coerce_openai_message_content_value(v: Variant) -> String:
  if v == null:
    return ""
  var t := typeof(v)
  if t == TYPE_STRING:
    return str(v)
  if t == TYPE_ARRAY:
    var out := ""
    for item in v as Array:
      if typeof(item) == TYPE_DICTIONARY:
        var d: Dictionary = item
        var typ := str(d.get("type", "text"))
        # llama.cpp OAI paths may emit output_text / input_text blocks, not only "text".
        if typ == "text" or typ == "output_text" or typ == "input_text":
          out += str(d.get("text", ""))
        elif typ == "refusal":
          out += str(d.get("refusal", ""))
      elif typeof(item) == TYPE_STRING:
        out += str(item)
    return out
  return str(v)


## Extracts generated text from an OpenAI-compatible [code]/v1/completions[/code] JSON object.
## Params:
## - resp: Parsed top-level response object.
## Returns:
## - [code]choices[0].text[/code] when present.
static func extract_openai_completion_choice_text(resp: Dictionary) -> String:
  var choices: Variant = resp.get("choices", [])
  if typeof(choices) != TYPE_ARRAY or choices.is_empty():
    return ""
  var first: Variant = choices[0]
  if typeof(first) != TYPE_DICTIONARY:
    return ""
  return str((first as Dictionary).get("text", ""))


## Extracts assistant text from an OpenAI-compatible [code]/v1/chat/completions[/code] JSON object.
## Params:
## - resp: Parsed top-level response object.
## Returns:
## - Non-empty string when [code]choices[0].message.content[/code] (or legacy [code]choices[0].text[/code]) carries text.
static func extract_openai_chat_choice_text(resp: Dictionary) -> String:
  var choices: Variant = resp.get("choices", [])
  if typeof(choices) != TYPE_ARRAY or choices.is_empty():
    return ""
  var first: Variant = choices[0]
  if typeof(first) != TYPE_DICTIONARY:
    return ""
  var choice: Dictionary = first
  var message: Variant = choice.get("message", {})
  if typeof(message) == TYPE_DICTIONARY:
    var msg: Dictionary = message
    var c := coerce_openai_message_content_value(msg.get("content", ""))
    if not c.strip_edges().is_empty():
      return c
  return str(choice.get("text", ""))


## Returns the exact ARMED handshake payload string.
## Params:
## - none
## Returns:
## - Literal ARMED user-message text.
## Usage:
## - Headless tests verify this does not drift.
func get_armed_handshake_user() -> String:
  return _ARMED_HANDSHAKE_USER


## Arms an AI session if inference config is valid.
## Params:
## - none
## Returns / side effects:
## - Returns false when required config is missing or the inference endpoint cannot be reached; true when state becomes ARMED.
## Usage:
## - Call when HUD "AI Player" is pressed (await from an async caller ΓÇö this function uses [code]await[/code] internally).
func arm_ai_session() -> bool:
  if _arm_session_in_progress:
    #region agent log
    _AgentNdjson.write({
      "runId": "ai-arm",
      "hypothesisId": "H4",
      "location": "ai_driver.gd:arm_rejected_reentrant",
      "message": "arm_ai_session_skipped_already_in_progress",
      "data": {},
    })
    #endregion
    return false
  _arm_session_in_progress = true
  _cpu_player_round_active = false
  _debug_arm_invoke_seq += 1
  var invoke_id := _debug_arm_invoke_seq
  _refresh_inference_client_config()
  var base_url := str(_inference_client.get("INFERENCE_BASE_URL", "")).strip_edges()
  var model_id := str(_inference_client.get("MODEL_ID", "")).strip_edges()
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H4",
    "location": "ai_driver.gd:arm_enter",
    "message": "arm_ai_session_entry",
    "data": {
      "invoke_id": invoke_id,
      "base_url_nonempty": not base_url.is_empty(),
      "model_id_nonempty": not model_id.is_empty(),
    },
  })
  #endregion
  if base_url.is_empty() or model_id.is_empty():
    _OLogSafe.error(
      "AiDriver: cannot arm ΓÇö set inference_client.INFERENCE_BASE_URL and MODEL_ID "
      + "(user://game_config.json overrides res://game_config.json template).",
      true,
      "AiDriver"
    )
    _arm_session_in_progress = false
    return false
  var inf_ok: bool = await _bundled_launcher.ensure_inference_endpoint_ready(_inference_client)
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H1,H3,H4",
    "location": "ai_driver.gd:after_ensure",
    "message": "ensure_inference_endpoint_ready_returned",
    "data": {"invoke_id": invoke_id, "ok": inf_ok},
  })
  #endregion
  if not inf_ok:
    #region agent log
    _AgentNdjson.write({
      "runId": "ai-arm",
      "hypothesisId": "H1,H3,H5",
      "location": "ai_driver.gd:arm_failed_inference",
      "message": "arm_ai_session_inference_not_ready",
      "data": {"invoke_id": invoke_id},
    })
    #endregion
    _arm_session_in_progress = false
    return false
  _set_state(State.ARMED)
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _PlayerScr.engine_control_as_int())
  if _creature != null and _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  _motor_reset_scripted_auxiliary_states()
  _has_snapshot = false
  _latest_snapshot = ""
  _next_inference_ms = Time.get_ticks_msec()
  #region agent log
  _AgentNdjson.write({
    "runId": "ai-arm",
    "hypothesisId": "H4",
    "location": "ai_driver.gd:arm_success",
    "message": "arm_ai_session_complete",
    "data": {"invoke_id": invoke_id, "emit_state_enum": get_state()},
  })
  #endregion
  _arm_session_in_progress = false
  return true


## Arms a CPU round: scripted motor + [member Player.ControlMode.ENGINE]; no inference or HTTP handshake.
## Params:
## - none
## Returns:
## - False when overlapping arm, already ARMED or PLAYING, or [member Main]/Player not ready.
## Usage:
## - Main HUD "AI Player" when local engine control replaces remote LLM.
func begin_engine_player_round() -> bool:
  if _arm_session_in_progress:
    return false
  if _main == null or _creature == null:
    _OLogSafe.info(
      "AiDriver: cannot start CPU player ΓÇö attach Main before pressing AI Player.",
      true,
      "AiDriver",
    )
    return false
  if _state == State.PLAYING or _state == State.ARMED:
    return false
  _arm_session_in_progress = true
  _debug_arm_invoke_seq += 1
  var invoke_id := _debug_arm_invoke_seq
  _cpu_player_round_active = true
  _set_state(State.ARMED)
  if _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _PlayerScr.engine_control_as_int())
  if _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  _motor_reset_scripted_auxiliary_states()
  _has_snapshot = false
  _latest_snapshot = ""
  _next_inference_ms = Time.get_ticks_msec()
  #region agent log
  _AgentNdjson.write({
    "runId": "cpu-arm",
    "hypothesisId": "HUD",
    "location": "ai_driver.gd:begin_engine_player_round_done",
    "message": "begin_engine_player_round_complete",
    "data": {"invoke_id": invoke_id},
  })
  #endregion
  _arm_session_in_progress = false
  return true


## Aborts an armed handshake without calling [method Main.new_game]; restores human control and IDLE UI.
## Params:
## - none
## Returns / side effects:
## - No-op unless current state is [enum State.ARMED].
## Usage:
## - HUD "Cancel" during setup, or automatic cleanup after a failed handshake HTTP response.
func cancel_armed_session() -> void:
  if _state != State.ARMED:
    return
  _cpu_player_round_active = false
  _http_request.cancel_request()
  _inflight_request_id = -1
  if _creature != null and _creature.has_method("set_control_mode"):
    _creature.call("set_control_mode", _PlayerScr.human_control_as_int())
  if _creature != null and _creature.has_method("set_creature_move_intent"):
    _creature.call("set_creature_move_intent", Vector2.ZERO)
  _motor_reset_scripted_auxiliary_states()
  _set_state(State.IDLE)


## Sets registered herbivore prey to human control (HUD **Start** duel; fox stays ENGINE from [method sync_duel_control_modes]).
func _apply_human_control_on_registered_prey() -> void:
  var human_int := _PlayerScr.human_control_as_int()
  for n in _registered_creatures:
    if not (n is Node) or not is_instance_valid(n):
      continue
    var nn := n as Node
    if nn.is_in_group(&"prey") and nn.has_method(&"set_control_mode"):
      nn.call(&"set_control_mode", human_int)


## Enters [enum State.PLAYING] for an active CREATURE_GOALS duel ([member _duel_round_active] or **AI Player** [enum State.ARMED]).
func _begin_playing_for_creature_goals_duel() -> void:
  var rng := RandomNumberGenerator.new()
  rng.randomize()
  _duel_motor_round_salt = rng.randi()
  _set_state(State.PLAYING)
  _randomize_duel_spawn_facing()
  if _cpu_player_round_active:
    if _creature != null and _creature.has_method("set_control_mode"):
      _creature.call(
        "set_control_mode",
        playing_control_mode_int_for_motor_mode_string(_creature_motor_mode())
      )
  else:
    _apply_human_control_on_registered_prey()


## Assigns a per-round random cardinal facing to each registered duel creature.
func _randomize_duel_spawn_facing() -> void:
  var cardinals: Array[Vector2] = [
    Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
  ]
  for n in _registered_creatures:
    if not (n is PhysicsBody2D) or not is_instance_valid(n):
      continue
    var body := n as PhysicsBody2D
    var slot := (body.get_instance_id() ^ _duel_motor_round_salt) & 3
    var facing: Vector2 = cardinals[slot]
    if body.has_method(&"apply_duel_spawn_facing"):
      body.call(&"apply_duel_spawn_facing", facing)
    else:
      body.set("last_move_direction", facing)


## Notifies the driver that Main.new_game() completed.
## Params:
## - none
## Returns / side effects:
## - Updates state and resets round-scoped transient fields.
## Usage:
## - Call at the end of Main.new_game().
func notify_main_new_game() -> void:
  _has_snapshot = false
  _latest_snapshot = ""
  _physics_ticks = 0
  _next_inference_ms = Time.get_ticks_msec()
  _mob_hist.clear()
  _mob_ids_ever_observed.clear()
  _explore_trail_reset()
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
          _creature.call("set_control_mode", _PlayerScr.human_control_as_int())
    _:
      if is_duel_round_active():
        _begin_playing_for_creature_goals_duel()
      else:
        _cpu_player_round_active = false
        if _creature != null and _creature.has_method("set_control_mode"):
          _creature.call("set_control_mode", _PlayerScr.human_control_as_int())


## Notifies the driver that Main.game_over() completed.
## Params:
## - none
## Returns / side effects:
## - Transitions to WAITING and clears movement intent/inference cadence.
## Usage:
## - Call from Main.game_over().
func notify_main_game_over() -> void:
  _cpu_player_round_active = false
  _clear_registered_creature_move_intents()
  _duel_motor_round_salt = 0
  _set_state(State.WAITING)
  _next_inference_ms = 0
  _has_snapshot = false
  _latest_snapshot = ""
  _mob_hist.clear()
  _mob_ids_ever_observed.clear()
  _explore_trail_reset()


func _exit_tree() -> void:
  _request_id_counter = 0
  _latest_enqueued_request_id = -1
  _inflight_request_id = -1
  _has_snapshot = false
  _latest_snapshot = ""
  if _http_request != null:
    _http_request.cancel_request()


func _process(_delta: float) -> void:
  if _state != State.ARMED and _state != State.PLAYING:
    return
  if _state == State.PLAYING and _creature_motor_mode() == "scripted":
    return
  if _inflight_request_id != -1:
    return
  var now_ms := Time.get_ticks_msec()
  if now_ms < _next_inference_ms:
    return
  _enqueue_inference_request()


## Returns effective motor lane for [method _physics_process] / inference gating:
## **`scripted`** while [member _cpu_player_round_active]; else **`llm`** or **`scripted`** from merged [code]creature_motor.mode[/code].
## Params:
## - none
## Returns:
## - **`scripted`** or **`llm`** (defaults to scripted when absent / unknown mode string).
func _creature_motor_mode() -> String:
  if _cpu_player_round_active or is_duel_round_active():
    return "scripted"
  var cm := _live_creature_motor_params()
  var m := str(cm.get("mode", "scripted")).to_lower().strip_edges()
  if m == "llm":
    return "llm"
  return "scripted"


## Parses [code]creature_motor[/code] boolean that defaults to [code]true[/code] when the key is absent (JSON may use bool or string).
## Params:
## - motor_p: Merged motor section.
## - key: Field name (e.g. [code]shuffle_tie_break[/code]).
## Returns:
## - [code]false[/code] only when the value is explicitly falsey ([code]false[/code], [code]"false"[/code], [code]0[/code], etc.).
func _motor_bool_default_true(motor_p: Dictionary, key: String) -> bool:
  if not motor_p.has(key):
    return true
  var v: Variant = motor_p[key]
  if typeof(v) == TYPE_BOOL:
    return bool(v)
  var s := str(v).to_lower().strip_edges()
  return s not in ["0", "false", "no", "off", ""]


## Distance from mob to creature footprint for awareness gating; mirrors [method CardinalAvoidance.awareness_gate_distance] using [member _MOTOR] for AABB math.
func _awareness_gate_distance_for_driver(
  creature_center: Vector2, creature_half: Vector2, mob_pos: Vector2
) -> float:
  var half := creature_half
  if half.x <= 0.0 or half.y <= 0.0:
    return creature_center.distance_to(mob_pos)
  var closest_c := _MOTOR.closest_point_on_aabb(creature_center, half, mob_pos)
  return mob_pos.distance_to(closest_c)


## Effective reach with forward cone; mirrors [method CardinalAvoidance.effective_awareness_reach].
## Default zone ([code]awareness_forward_cone_only = false[/code]): rear/peripheral disk at [param base_radius] plus forward wedge at [param base_radius] + [param cone_extra].
## Legacy [code]awareness_forward_cone_only = true[/code]: forward sector only (zero reach behind).
func _effective_awareness_reach_for_driver(
  creature_center: Vector2,
  mob_pos: Vector2,
  base_radius: float,
  cone_extra: float,
  cone_cos_threshold: float,
  facing: Vector2,
  forward_cone_only: bool = false,
) -> float:
  var delta := mob_pos - creature_center
  var dist := delta.length()
  var u := Vector2.RIGHT
  if dist > 1e-4:
    u = delta / dist
  var f := facing
  if f.length() < 1e-4:
    f = Vector2.RIGHT
  else:
    f = f.normalized()
  var in_forward_cone := true
  if cone_cos_threshold >= -1.0001:
    in_forward_cone = u.dot(f) >= cone_cos_threshold
  if forward_cone_only:
    if not in_forward_cone:
      return 0.0
    return base_radius + cone_extra
  var reach := base_radius
  if cone_extra > 0.0 and in_forward_cone:
    reach = base_radius + cone_extra
  return reach


## Nearest carnivore mob inside herbivore awareness (cone + radius unless [code]herbivore_threat_awareness_omni[/code]).
## Returns [code]in_awareness[/code], footprint [code]gate_dist[/code], and [code]world_pos[/code].
func _herbivore_predator_threat_sample(
  prey_body: PhysicsBody2D,
  motor_p: Dictionary,
  creature_pos: Vector2,
  he_xy: Vector2,
  facing: Vector2,
) -> Dictionary:
  var inactive := {
    "in_awareness": false,
    "gate_dist": INF,
    "world_pos": Vector2.ZERO,
  }
  if _main == null or prey_body == null:
    return inactive
  var awareness_r := float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return inactive
  var cone_extra := float(motor_p.get("awareness_cone_extra", 0.0))
  var half_deg := float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos := cos(deg_to_rad(half_deg))
  var omni := bool(motor_p.get("herbivore_threat_awareness_omni", false))
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  var best_dist := INF
  var best_pos := Vector2.ZERO
  for n in _main.get_tree().get_nodes_in_group(&"mobs"):
    if not (n is RigidBody2D):
      continue
    var rb := n as RigidBody2D
    if rb == prey_body:
      continue
    var mp := rb.global_position
    var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, mp)
    var in_zone := false
    if omni:
      in_zone = gd <= awareness_r
    else:
      var eff := _effective_awareness_reach_for_driver(
        creature_pos, mp, awareness_r, cone_extra, cone_cos, facing, forward_cone_only
      )
      in_zone = gd <= eff
    if not in_zone:
      continue
    if gd < best_dist:
      best_dist = gd
      best_pos = mp
  if best_dist >= INF:
    return inactive
  return {"in_awareness": true, "gate_dist": best_dist, "world_pos": best_pos}


## True when footprint clearance to nearest static AABB is at or below [param probe_px].
func _creature_geometry_pinched(
  creature_pos: Vector2, he_xy: Vector2, static_obs: Array, probe_px: float
) -> bool:
  if static_obs.is_empty() or probe_px <= 0.0:
    return false
  var slip_info := _static_obstacle_slip_info(creature_pos, he_xy, static_obs)
  return float(slip_info.get("clearance", INF)) <= probe_px


## Lookahead distance for cardinal static probes (patrol block test, stuck escape).
static func _motor_cardinal_probe_step(he_xy: Vector2) -> float:
  return _MOTOR.motor_cardinal_probe_step(he_xy)


## True when a unit cardinal step would leave the footprint pinched against static geometry.
static func _cardinal_step_blocked(
  creature_pos: Vector2,
  he_xy: Vector2,
  direction: Vector2,
  static_obs: Array,
  min_clearance_px: float,
) -> bool:
  return _MOTOR.cardinal_step_blocked(
    creature_pos, he_xy, direction, static_obs, min_clearance_px
  )


## Picks the cardinal step with best static clearance (corner / wall escape).
func _pick_stuck_escape_cardinal(
  creature_pos: Vector2,
  he_xy: Vector2,
  static_obs: Array,
  body_id: int,
  stuck_n: int,
) -> Vector2:
  var cardinals: Array[Vector2] = [
    Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
  ]
  var step := _motor_cardinal_probe_step(he_xy)
  var phase := maxi(0, stuck_n) >> 3
  var start_i := (body_id + phase) & 3
  var best_d := Vector2.RIGHT
  var best_clear := -INF
  for k in 4:
    var c: Vector2 = cardinals[(start_i + k) % 4]
    var probe_pos := creature_pos + c * step
    var info := _static_obstacle_slip_info(probe_pos, he_xy, static_obs)
    var cl := float(info.get("clearance", -INF))
    if cl > best_clear:
      best_clear = cl
      best_d = c
  return best_d


## Stable escape cardinal for [param stuck_n] >= 1; latched so intent does not flip every physics tick.
func _latched_stuck_escape_intent(
  body_id: int,
  creature_pos: Vector2,
  he_xy: Vector2,
  static_obs: Array,
  stuck_n: int,
  motor_p: Dictionary,
) -> Vector2:
  var lock_ticks := maxi(6, int(motor_p.get("geometry_escape_lock_ticks", 14)))
  var rec_v: Variant = _geometry_escape_lock_by_body.get(body_id, null)
  if typeof(rec_v) == TYPE_DICTIONARY:
    var rec: Dictionary = rec_v
    if _physics_ticks < int(rec.get("until_tick", 0)):
      var locked: Variant = rec.get("dir", Vector2.ZERO)
      if typeof(locked) == TYPE_VECTOR2 and (locked as Vector2).length_squared() > 1e-12:
        return locked as Vector2
  var esc := _pick_stuck_escape_cardinal(creature_pos, he_xy, static_obs, body_id, stuck_n)
  _geometry_escape_lock_by_body[body_id] = {
    "dir": esc,
    "until_tick": _physics_ticks + lock_ticks,
  }
  return esc


## Appends a mob field snapshot for memory ghosts ([member _mob_hist]). Drops oldest entries past [code]awareness_memory_ticks[/code].
func _record_mob_history_if_playing() -> void:
  if _main == null:
    return
  var motor_p_hist := _live_creature_motor_params()
  var max_t := int(motor_p_hist.get("awareness_memory_ticks", 3))
  if max_t <= 0:
    _mob_hist.clear()
    _mob_ids_ever_observed.clear()
    return
  var snap: Dictionary = {}
  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var rb := n as RigidBody2D
      snap[rb.get_instance_id()] = {
        "position": rb.global_position,
        "velocity": rb.linear_velocity,
      }
  _mob_hist.append(snap)
  while _mob_hist.size() > max_t:
    _mob_hist.pop_front()


## Cached static obstacle AABBs ([method _refresh_motor_obstacle_cache_if_needed]); populated each physics tick before motor subjects run.
func _static_obstacles_for_motor() -> Array:
  return _motor_obstacle_aabbs.duplicate()


func _nearest_position_from_dict_mobs(creature_pos: Vector2, mobs_arr: Array) -> Vector2:
  var best := INF
  var out := Vector2.ZERO
  for item in mobs_arr:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var mp: Vector2 = item.get("position", Vector2.ZERO)
    var d := creature_pos.distance_squared_to(mp)
    if d < best:
      best = d
      out = mp
  return out if best < INF else Vector2.ZERO


func _nearest_vector_from_positions(creature_pos: Vector2, pts: Array) -> Vector2:
  var best := INF
  var out := Vector2.ZERO
  for p in pts:
    if typeof(p) != TYPE_VECTOR2:
      continue
    var pv := p as Vector2
    var d := creature_pos.distance_squared_to(pv)
    if d < best:
      best = d
      out = pv
  return out if best < INF else Vector2.ZERO


## Removes static AABBs / samples that sit on **ready** bush centers so herbivore seek can approach forage while still blocking non-target vegetation.
## Params:
## - forage_world_positions: [code]food_seek_targets[/code] ready positions (typically shrub roots).
## - clearance_px: Euclidean distance within which geometry is dropped.
func _filter_obstacle_geom_for_forage(
  aabbs: Array, samples: PackedVector2Array, forage_world_points: Array, clearance_px: float
) -> Dictionary:
  var out_aabbs: Array = []
  var out_samples := PackedVector2Array()
  if clearance_px <= 1e-4 or forage_world_points.is_empty():
    return {"aabbs": aabbs.duplicate(true), "samples": samples.duplicate()}
  var clr2 := clearance_px * clearance_px
  var near_forage_point := func(center: Vector2) -> bool:
    for f in forage_world_points:
      if typeof(f) != TYPE_VECTOR2:
        continue
      var fp := f as Vector2
      if fp.distance_squared_to(center) <= clr2:
        return true
    return false

  for item in aabbs:
    if typeof(item) != TYPE_DICTIONARY:
      continue
    var c: Vector2 = item.get("position", Vector2.ZERO)
    if near_forage_point.call(c):
      continue
    out_aabbs.append(item)

  for i in range(samples.size()):
    var p := samples[i]
    if near_forage_point.call(p):
      continue
    out_samples.append(p)

  return {"aabbs": out_aabbs, "samples": out_samples}


func _pursuit_targets_for_predator(
  predator: PhysicsBody2D, motor_p: Dictionary, creature_pos: Vector2, he_xy: Vector2, facing: Vector2
) -> Array:
  var arr: Array = []
  if predator == null or _main == null:
    return arr
  var awareness_r := float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return arr
  var cone_extra := _predator_prey_cone_extra(motor_p)
  var half_deg := float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos := cos(deg_to_rad(half_deg))
  var omni := bool(motor_p.get("predator_prey_awareness_omni", false))
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  for n in _main.get_tree().get_nodes_in_group(&"prey"):
    if not (n is Node2D):
      continue
    if (n as Node) == predator:
      continue
    var prey_pos := (n as Node2D).global_position
    var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, prey_pos)
    if omni:
      if gd > awareness_r:
        continue
    else:
      var eff := _effective_awareness_reach_for_driver(
        creature_pos, prey_pos, awareness_r, cone_extra, cone_cos, facing, forward_cone_only
      )
      if gd > eff:
        continue
    var vel := Vector2.ZERO
    if n is CharacterBody2D:
      vel = (n as CharacterBody2D).velocity
    elif n is RigidBody2D:
      vel = (n as RigidBody2D).linear_velocity
    arr.append({"position": prey_pos, "velocity": vel, "cost_scale": 1.0})
  return arr


## Builds [param mobs] array for [code]CardinalAvoidance[/code]: live entries, unreachable live with memory scale (only if that mob was previously inside effective awareness this round), despawned ghosts (same observed rule).
## Params:
## - motor_p: Merged [code]creature_motor[/code].
## - creature_pos: Creature center (world).
## - he_xy: Footprint half-extents for gating.
## - motor_subject: Body whose cone facing comes from [code]last_move_direction[/code]; omitted uses [member _creature]. Skips the rigidbody equal to [code]motor_subject[/code] so a carnivore mob does not score itself as prey.
## Returns:
## - Array of [code]{ "position", "velocity", "cost_scale", "_motor_debug_source?" }[/code] dicts. [code]_motor_debug_source[/code] is overlay-only; motor ignores it.
func _motor_mobs_array(
  motor_p: Dictionary, creature_pos: Vector2, he_xy: Vector2, motor_subject: PhysicsBody2D = null
) -> Array:
  var out: Array = []
  if _main == null:
    return out
  var awareness_r: float = float(motor_p.get("awareness_radius", 0.0))
  var cone_extra: float = float(motor_p.get("awareness_cone_extra", 0.0))
  var half_deg: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos: float = cos(deg_to_rad(half_deg))
  var facing_v := Vector2.RIGHT
  var facing_src := motor_subject if motor_subject != null else _creature
  if facing_src != null:
    var fd: Variant = facing_src.get("last_move_direction")
    if typeof(fd) == TYPE_VECTOR2:
      var fv := fd as Vector2
      if fv.length() > 1e-4:
        facing_v = fv.normalized()
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  var prey_omni_threat := (
    motor_subject != null
    and motor_subject.is_in_group(&"prey")
    and bool(motor_p.get("herbivore_threat_awareness_omni", false))
  )

  var mem_ticks := maxi(0, int(motor_p.get("awareness_memory_ticks", 3)))
  var mem_w: float = float(motor_p.get("awareness_memory_weight", 0.35))
  var horizon: float = float(motor_p.get("awareness_memory_horizon_sec", 0.0))
  if horizon <= 0.0 and mem_ticks > 0:
    horizon = float(mem_ticks) / maxf(1.0, float(Engine.physics_ticks_per_second))

  var live_ids: Dictionary = {}

  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var rb := n as RigidBody2D
      if motor_subject != null and rb == motor_subject:
        continue
      var id := rb.get_instance_id()
      live_ids[id] = true
      var p := rb.global_position
      var v := rb.linear_velocity
      var gated := false
      if awareness_r > 0.0:
        var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, p)
        if prey_omni_threat:
          gated = gd > awareness_r
        else:
          var eff := _effective_awareness_reach_for_driver(
            creature_pos, p, awareness_r, cone_extra, cone_cos, facing_v, forward_cone_only
          )
          gated = gd > eff
      if not gated:
        _mob_ids_ever_observed[id] = true
      if gated:
        if mem_ticks > 0 and mem_w > 0.0 and _mob_ids_ever_observed.has(id):
          var pred := p + v * horizon
          out.append({
            "position": pred,
            "velocity": v,
            "cost_scale": mem_w,
            "_motor_debug_source": "gated",
          })
      else:
        out.append({
          "position": p,
          "velocity": v,
          "cost_scale": 1.0,
          "_motor_debug_source": "live",
        })

  if mem_ticks > 0 and mem_w > 0.0 and _mob_hist.size() > 0:
    var ghost_added: Dictionary = {}
    var i := _mob_hist.size() - 1
    while i >= 0:
      var snap: Dictionary = _mob_hist[i]
      for id in snap:
        if live_ids.has(id):
          continue
        if ghost_added.has(id):
          continue
        if not _mob_ids_ever_observed.has(id):
          continue
        var e: Dictionary = snap[id]
        var gp: Vector2 = e.get("position", Vector2.ZERO)
        var gv: Vector2 = e.get("velocity", Vector2.ZERO)
        var pred := gp + gv * horizon
        if awareness_r > 0.0:
          var gd2 := _awareness_gate_distance_for_driver(creature_pos, he_xy, pred)
          var eff2 := _effective_awareness_reach_for_driver(
            creature_pos, pred, awareness_r, cone_extra, cone_cos, facing_v, forward_cone_only
          )
          if gd2 > eff2:
            continue
        out.append({
          "position": pred,
          "velocity": gv,
          "cost_scale": mem_w,
          "_motor_debug_source": "ghost",
        })
        ghost_added[id] = true
      i -= 1

  return out


## In-awareness [code]food_plants[/code] split by each node's [code]is_pickup_ready_for_motor[/code] (same cone/radius as mob motor gating).
## **Live sense only today.** Goal-target memory (precise coords / mover disk per [code]goal_memory_*[/code], else egocentric 8-way) merges **after** this call inside [_build_motor_context] ΓÇö see [_goal_belief] design block above.
## When [code]awareness_radius <= 0[/code], returns empty lists (no omniscient food seek/avoid); unlike live mob cost, food targets require explicit sensory range.
## Params:
## - motor_p: Merged [code]creature_motor[/code].
## - creature_pos: Creature center (world).
## - he_xy: Footprint half-extents for gating.
## - facing_v: Forward axis for cone reach.
## Returns:
## - Dict with [code]ready[/code] / [code]unready[/code] arrays of [code]Vector2[/code] bush roots.
func _motor_food_plants_in_awareness_by_readiness(
  motor_p: Dictionary, creature_pos: Vector2, he_xy: Vector2, facing_v: Vector2
) -> Dictionary:
  var ready_positions: Array = []
  var unready_positions: Array = []
  if _main == null:
    return {"ready": ready_positions, "unready": unready_positions}
  var awareness_r: float = float(motor_p.get("awareness_radius", 0.0))
  if awareness_r <= 0.0:
    return {"ready": ready_positions, "unready": unready_positions}
  var cone_extra: float = float(motor_p.get("awareness_cone_extra", 0.0))
  var half_deg: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var cone_cos: float = cos(deg_to_rad(half_deg))
  var forward_cone_only := bool(motor_p.get("awareness_forward_cone_only", false))
  for n in _main.get_tree().get_nodes_in_group(&"food_plants"):
    if not n.has_method(&"is_pickup_ready_for_motor"):
      continue
    var fp: Vector2 = n.global_position
    var gd := _awareness_gate_distance_for_driver(creature_pos, he_xy, fp)
    var eff := _effective_awareness_reach_for_driver(
      creature_pos, fp, awareness_r, cone_extra, cone_cos, facing_v, forward_cone_only
    )
    if gd > eff:
      continue
    var ready_v: Variant = n.call(&"is_pickup_ready_for_motor")
    if typeof(ready_v) == TYPE_BOOL and bool(ready_v):
      ready_positions.append(fp)
    else:
      unready_positions.append(fp)
  return {"ready": ready_positions, "unready": unready_positions}


## Live mob centers for food-seek survival gating (ungated; all [code]mobs[/code] group [code]RigidBody2D[/code] except optional self-exclusion).
## Params:
## - exclude_body: When set (typically the duel carnivore), that rigidbody's center is omitted from the imminent list.
## Returns:
## - Array of [code]Vector2[/code].
func _motor_imminent_mob_positions(exclude_body: PhysicsBody2D = null) -> Array:
  var out: Array = []
  if _main == null:
    return out
  for n in _main.get_tree().get_nodes_in_group(&"mobs"):
    if n is RigidBody2D:
      var rb := n as RigidBody2D
      if exclude_body != null and rb == exclude_body:
        continue
      out.append(rb.global_position)
  return out


## Derives multipliers so low hunger relaxes center/edge posture costs and shortens scripted intent hold (more map coverage).
## Params:
## - motor_p: Merged [code]creature_motor[/code]; optional [code]hunger_explore_*[/code] keys tune low-calorie exploration (see [code]game_config_merge.default_creature_motor_params[/code]).
## - calorie_body: Body whose [code]current_calories[/code] / [code]caloric_needs[/code] drive urgency; defaults to [member _creature].
## Returns:
## - Dict with [code]interior_mul[/code], [code]edge_mul[/code], [code]hold_mul[/code] in [code](0, 1][/code]; all [code]1.0[/code] when calories full or creature lacks hunger fields.
func _hunger_exploration_modifiers(motor_p: Dictionary, calorie_body: PhysicsBody2D = null) -> Dictionary:
  var calorie_ratio := 1.0
  var wb := calorie_body if calorie_body != null else _creature
  if wb != null:
    var c0: Variant = wb.get("current_calories")
    var n0: Variant = wb.get("caloric_needs")
    if (typeof(c0) == TYPE_FLOAT or typeof(c0) == TYPE_INT) and (typeof(n0) == TYPE_FLOAT or typeof(n0) == TYPE_INT):
      calorie_ratio = clampf(float(c0) / maxf(1.0, float(n0)), 0.0, 1.0)
  var urgency := 1.0 - calorie_ratio
  var power := float(motor_p.get("hunger_explore_urgency_power", 1.25))
  urgency = clampf(pow(urgency, power), 0.0, 1.0)
  var min_i := float(motor_p.get("hunger_explore_interior_scale_min", 0.16))
  var min_e := float(motor_p.get("hunger_explore_edge_scale_min", 0.16))
  var min_h := float(motor_p.get("hunger_explore_hold_scale_min", 0.2))
  return {
    "interior_mul": lerpf(1.0, min_i, urgency),
    "edge_mul": lerpf(1.0, min_e, urgency),
    "hold_mul": lerpf(1.0, min_h, urgency),
  }


## Builds the dictionary consumed by [code]cardinal_avoidance.pick_best_move_intent[/code].
## Half-extents: JSON [code]creature_half_extent_*[/code] are clamped with [code]maxf(0, ΓÇª)[/code]; capsule-derived values use the same clamp. Use **positive** JSON values for real footprint scoring ([code]Vector2.ZERO[/code] in context falls back to center-point motor math).
## Params:
## - motor_p: Merged [code]creature_motor[/code] params from [code]GameConfig[/code].
## - hunger_explore: Output of [method _hunger_exploration_modifiers] (optional; empty uses no scaling).
## - motor_subject: Body whose pose, viewport, and mob-relative samples populate the context; defaults to [member _creature].
## Returns:
## - Context dict with creature position (playable entity body), bounds, mob samples, and tunables.
func _build_motor_context(
  motor_p: Dictionary, hunger_explore: Dictionary = {}, motor_subject: PhysicsBody2D = null
) -> Dictionary:
  var body := motor_subject if motor_subject != null else _creature
  if body == null:
    return {}
  var pos := body.global_position
  var spd := 400.0
  var spv: Variant = body.get("speed")
  if typeof(spv) == TYPE_FLOAT or typeof(spv) == TYPE_INT:
    spd = float(spv)
  var ss := body.get("screen_size") as Vector2
  if ss == Vector2.ZERO:
    ss = _viewport_playfield_size_px(body)
  var he_xy := Vector2(
    maxf(0.0, float(motor_p.get("creature_half_extent_x", 13.5))),
    maxf(0.0, float(motor_p.get("creature_half_extent_y", 30.5))),
  )
  var cs_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
  if cs_shape != null and cs_shape.shape is CapsuleShape2D:
    var cap := cs_shape.shape as CapsuleShape2D
    he_xy = Vector2(
      maxf(0.0, cap.radius),
      maxf(0.0, cap.radius + cap.height * 0.5),
    )
  var half_deg: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
  var facing_display := Vector2.RIGHT
  var fd0: Variant = body.get("last_move_direction")
  if typeof(fd0) == TYPE_VECTOR2:
    var fv0 := fd0 as Vector2
    if fv0.length() > 1e-4:
      facing_display = fv0.normalized()
  var mobs_arr: Array = _motor_mobs_array(motor_p, pos, he_xy, body)

  var csz := 0.0
  var szv: Variant = body.get("creature_size")
  if typeof(szv) == TYPE_FLOAT or typeof(szv) == TYPE_INT:
    csz = float(szv)
  var interior_active := int(body.get("control_mode")) == _PlayerScr.engine_control_as_int()
  var env_grid: Variant = null
  if _main != null and _main.has_method("get_environment_grid"):
    env_grid = _main.call("get_environment_grid")

  ## Live awareness lists; future: union with [_goal_belief] precise-tier positions (ready/unready frozen at last observation).
  var food_split: Dictionary = _motor_food_plants_in_awareness_by_readiness(
    motor_p, pos, he_xy, facing_display
  )
  var plant_ready_targets: Array = (food_split["ready"] as Array).duplicate()
  var food_targets: Array = plant_ready_targets.duplicate()
  var is_predator_body := body.is_in_group(&"mobs") and not body.is_in_group(&"prey")
  var prey_pts: Array = []
  if is_predator_body:
    prey_pts = _prey_positions_for_predator_motor(body)
  var pursuit_targets: Array = []
  if is_predator_body:
    pursuit_targets = _pursuit_targets_for_predator(body, motor_p, pos, he_xy, facing_display)
  var prey_pts_live: Array = prey_pts.duplicate()
  var predator_memory := (
    _predator_prey_memory_sample(body, motor_p, pos) if is_predator_body
    else {"active": false, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "strength": 0.0}
  )
  if is_predator_body:
    _predator_prey_memory_touch(body, prey_pts_live, pursuit_targets)
  var prey_ever_seen := (
    is_predator_body
    and bool(_predator_prey_ever_seen_by_id.get(body.get_instance_id(), false))
  )
  var unready_food_targets: Array = food_split["unready"]
  ## Future food memory: for each belief outside awareness but inside precise radius, append world pos to ready/unready;
  ## for coarse-only beliefs, expose [code]goal_memory_coarse_sectors[/code] (8-way strings) or a weak cardinal cost ΓÇö do not append stale Vector2 beyond precise envelope.
  var w_seek_base := float(motor_p.get("weight_seek_ready_food", 16.0))
  var w_avoid_unready_base := float(motor_p.get("weight_avoid_unready_food", 5.5))
  var imminent_r_cfg := float(motor_p.get("food_seek_imminent_mob_radius_px", 100.0))
  var cr := 1.0
  var ccal: Variant = body.get("current_calories")
  var cneed: Variant = body.get("caloric_needs")
  if (typeof(ccal) == TYPE_FLOAT or typeof(ccal) == TYPE_INT) and (
    typeof(cneed) == TYPE_FLOAT or typeof(cneed) == TYPE_INT
  ):
    cr = clampf(float(ccal) / maxf(1.0, float(cneed)), 0.0, 1.0)
  var predator_hunt_motivated := is_predator_body and cr < 0.998
  var w_seek := 0.0
  if not food_targets.is_empty() and w_seek_base > 0.0 and cr < 0.998:
    var urg := clampf(1.0 - cr, 0.0, 1.0)
    w_seek = w_seek_base * lerpf(0.28, 1.0, pow(urg, 0.85))
  var w_seek_prey_base := float(motor_p.get("weight_seek_prey", 22.0))
  var w_seek_prey := 0.0
  if predator_hunt_motivated and not prey_pts_live.is_empty() and w_seek_prey_base > 0.0:
    var urg_p := clampf(1.0 - cr, 0.0, 1.0)
    w_seek_prey = w_seek_prey_base * lerpf(0.28, 1.0, pow(urg_p, 0.85))
  var predator_lost_visual := (
    predator_hunt_motivated
    and prey_ever_seen
    and bool(predator_memory.get("active", false))
    and prey_pts_live.is_empty()
  )
  var w_avoid_unready := 0.0
  if not unready_food_targets.is_empty() and w_avoid_unready_base > 0.0 and cr < 0.998:
    var urg2 := clampf(1.0 - cr, 0.0, 1.0)
    w_avoid_unready = w_avoid_unready_base * lerpf(0.22, 1.0, pow(urg2, 0.85))
    if not food_targets.is_empty():
      w_avoid_unready *= float(motor_p.get("food_avoid_unready_scale_when_ready_target", 0.35))
  var motor_explore_always := bool(motor_p.get("motor_exploration_always_enabled", true))
  var urg3 := clampf(1.0 - cr, 0.0, 1.0)
  var urg_curve3 := lerpf(0.18, 1.0, pow(urg3, 0.9))
  var nearest_adv_dist := INF
  var herbivore_threat: Dictionary = {}
  if body.is_in_group(&"prey"):
    herbivore_threat = _herbivore_predator_threat_sample(
      body, motor_p, pos, he_xy, facing_display
    )
    if bool(herbivore_threat.get("in_awareness", false)):
      nearest_adv_dist = float(herbivore_threat.get("gate_dist", INF))
  elif body.is_in_group(&"mobs") and not body.is_in_group(&"prey") and predator_hunt_motivated:
    for pq in prey_pts_live:
      if typeof(pq) == TYPE_VECTOR2:
        nearest_adv_dist = minf(nearest_adv_dist, pos.distance_to(pq as Vector2))
  var ar := float(motor_p.get("awareness_radius", 0.0))
  var herbivore_needs_explore := (
    body.is_in_group(&"prey") and plant_ready_targets.is_empty()
  )
  var herbivore_forage_active := (
    body.is_in_group(&"prey") and w_seek > 0.0
  )
  var predator_has_prey := is_predator_body and w_seek_prey > 0.0
  var prey_engaged := predator_has_prey
  var pursuit_urgency := 0.0
  if nearest_adv_dist < INF and ar > 1e-4:
    pursuit_urgency = clampf(1.0 - nearest_adv_dist / ar, 0.0, 1.0)
  if prey_engaged:
    var urg_floor := float(motor_p.get("pursuit_engaged_urgency_floor", 0.65))
    pursuit_urgency = maxf(pursuit_urgency, urg_floor)
  var min_blend := float(motor_p.get("exploration_blend_min_when_engaged", 0.28))
  var exploration_blend_multiplier := lerpf(1.0, min_blend, pursuit_urgency)
  if prey_engaged or herbivore_forage_active:
    exploration_blend_multiplier = 0.0
  elif not motor_explore_always:
    exploration_blend_multiplier = 1.0 if food_targets.is_empty() else 0.0
  var w_idle_exp_base := float(motor_p.get("weight_explore_idle_penalty", 10.5))
  var w_turn_exp_base := float(motor_p.get("weight_explore_turn_bias", 0.14))
  var w_idle_exp := 0.0
  var w_turn_exp := 0.0
  var w_trail_rep := 0.0
  var trail_for_motor: Array = []
  var expand_hint := Vector2.ZERO
  var w_expand_hint_out := float(motor_p.get("weight_expanding_explore_hint", 0.12))
  var use_explore_curve := (
    (motor_explore_always or food_targets.is_empty() or herbivore_needs_explore)
    and not prey_engaged
    and not herbivore_forage_active
  )
  if use_explore_curve:
    if w_idle_exp_base > 0.0:
      w_idle_exp = w_idle_exp_base * urg_curve3
    if w_turn_exp_base > 0.0:
      w_turn_exp = w_turn_exp_base * urg_curve3
    var w_trail_base := float(motor_p.get("weight_explore_trail_repulsion", 2.35))
    if w_trail_base > 0.0:
      w_trail_rep = w_trail_base * urg_curve3
    var bid_tr := body.get_instance_id()
    var tr_raw: Variant = _explore_trail_centers_by_body.get(bid_tr, [])
    trail_for_motor = (tr_raw as Array).duplicate() if tr_raw is Array else []
    if trail_for_motor.size() > 1:
      trail_for_motor.pop_back()
    if body.is_in_group(&"mobs") and not body.is_in_group(&"prey"):
      var patrol_ex := int(motor_p.get("carnivore_explore_rotate_physics_ticks", 36))
      var patrol_seed := body.get_instance_id() ^ _duel_motor_round_salt
      if expand_hint == Vector2.ZERO:
        expand_hint = _ExploreScr.Explore.pick_cardinal(patrol_ex, _physics_ticks, patrol_seed)
      if expand_hint.length_squared() > 1e-12:
        w_expand_hint_out = maxf(
          w_expand_hint_out,
          float(motor_p.get("weight_stuck_escape_explore", 2.2))
            * float(motor_p.get("predator_patrol_explore_mul", 2.8)),
        )
        w_idle_exp = 0.0
        w_trail_rep = 0.0
        w_turn_exp *= float(motor_p.get("predator_chase_turn_bias_mul", 0.15))
  w_idle_exp *= exploration_blend_multiplier
  w_turn_exp *= exploration_blend_multiplier
  w_trail_rep *= exploration_blend_multiplier

  var herbivore_flee_active := false
  var herbivore_alert := false
  if body.is_in_group(&"prey"):
    var bid_prey := body.get_instance_id()
    var threat_in := bool(herbivore_threat.get("in_awareness", false))
    var threat_gate := float(herbivore_threat.get("gate_dist", INF))
    herbivore_flee_active = _herbivore_flee_panic_active(bid_prey, threat_in, threat_gate, motor_p)
    herbivore_alert = _herbivore_alert_latched(bid_prey, threat_in, threat_gate, motor_p)
    if herbivore_flee_active:
      var threat_pos: Vector2 = herbivore_threat.get("world_pos", Vector2.ZERO)
      if threat_pos == Vector2.ZERO:
        threat_pos = _nearest_position_from_dict_mobs(pos, mobs_arr)
      if threat_pos != Vector2.ZERO:
        var away := pos - threat_pos
        if away.length_squared() > 1e-12:
          expand_hint = _cardinal_best_aligned_to(away)
          w_expand_hint_out = maxf(
            w_expand_hint_out,
            float(motor_p.get("herbivore_flee_expand_weight", 4.5)),
          )
          w_idle_exp = 0.0
          w_trail_rep = 0.0
          exploration_blend_multiplier = 0.0
          w_seek = 0.0
          w_avoid_unready = 0.0
    elif herbivore_alert:
      w_seek *= float(motor_p.get("herbivore_alert_seek_scale", 0.45))
      w_avoid_unready *= 1.15
  if herbivore_needs_explore and not herbivore_flee_active:
    var base_ex := int(motor_p.get("expanding_explore_base_physics_ticks", 36))
    var phase_seed := body.get_instance_id() ^ _duel_motor_round_salt
    expand_hint = _ExploreScr.Explore.pick_cardinal(
      base_ex, _physics_ticks, phase_seed
    )
    if expand_hint.length_squared() > 1e-12:
      w_expand_hint_out *= float(motor_p.get("herbivore_expanding_explore_mul", 3.0))
      w_turn_exp *= float(motor_p.get("herbivore_explore_turn_bias_mul", 0.15))
      w_idle_exp = 0.0
      w_trail_rep = 0.0
  elif predator_lost_visual:
    var mem_pos_lost: Vector2 = predator_memory["position"]
    var toward := mem_pos_lost - pos
    expand_hint = _cardinal_best_aligned_to(toward)
    if expand_hint.length_squared() > 1e-12:
      w_expand_hint_out = maxf(
        w_expand_hint_out,
        float(motor_p.get("weight_stuck_escape_explore", 2.2))
        * float(motor_p.get("predator_memory_expand_mul", 1.2)),
      )
      w_idle_exp = 0.0
      w_trail_rep = 0.0
      w_turn_exp *= float(motor_p.get("predator_chase_turn_bias_mul", 0.15))

  var geom_aabbs: Array = _motor_obstacle_aabbs.duplicate()
  var geom_samples := _motor_obstacle_samples
  if geom_aabbs.is_empty() and _main != null:
    var pack_fallback: Dictionary = _GeomScr.collect_from_scene_tree(_main)
    geom_aabbs = pack_fallback.get("aabbs", []) as Array
    var sp_fb: Variant = pack_fallback.get("sample_points", PackedVector2Array())
    geom_samples = sp_fb as PackedVector2Array if sp_fb is PackedVector2Array else PackedVector2Array()
  if body.is_in_group(&"prey"):
    var forage_clr := float(motor_p.get("vegetation_blocking_forage_clearance_px", 92.0))
    var forage_geom_pts: Array = food_targets.duplicate()
    forage_geom_pts.append_array(unready_food_targets)
    var fd_geom: Dictionary = _filter_obstacle_geom_for_forage(
      geom_aabbs, geom_samples, forage_geom_pts, forage_clr
    )
    geom_aabbs = fd_geom["aabbs"] as Array
    geom_samples = fd_geom["samples"] as PackedVector2Array
    if not herbivore_flee_active:
      var spawn_slip := _static_obstacle_slip_info(pos, he_xy, geom_aabbs)
      var spawn_clear := float(spawn_slip.get("clearance", INF))
      var spawn_probe := float(motor_p.get("herbivore_obstacle_probe_px", 300.0))
      if spawn_clear <= spawn_probe:
        var esc_spawn := _pick_stuck_escape_cardinal(
          pos, he_xy, geom_aabbs, body.get_instance_id(), 1
        )
        if esc_spawn.length_squared() > 1e-12:
          expand_hint = esc_spawn
          w_expand_hint_out = maxf(
            w_expand_hint_out,
            float(motor_p.get("herbivore_obstacle_slip_expand_weight", 8.0)),
          )
          w_idle_exp = 0.0
          w_trail_rep = 0.0
  if (
    body.is_in_group(&"mobs")
    and not body.is_in_group(&"prey")
    and prey_pts_live.is_empty()
    and expand_hint == Vector2.ZERO
  ):
    var patrol_probe := float(motor_p.get("predator_obstacle_probe_px", 280.0))
    var patrol_slip := _static_obstacle_slip_info(pos, he_xy, geom_aabbs)
    var patrol_clear := float(patrol_slip.get("clearance", INF))
    if patrol_clear <= patrol_probe:
      var away_p: Variant = patrol_slip.get("away_dir", Vector2.ZERO)
      if typeof(away_p) == TYPE_VECTOR2 and (away_p as Vector2).length_squared() > 1e-12:
        expand_hint = _cardinal_best_aligned_to(away_p as Vector2)
        w_expand_hint_out = maxf(
          w_expand_hint_out,
          float(motor_p.get("predator_obstacle_slip_expand_weight", 7.0)),
        )
        w_idle_exp = 0.0
        w_turn_exp = 0.0
  var aware_samples := _GeomScr.filter_samples_by_radius(pos, ar, geom_samples)

  var strategic_threat := Vector2.ZERO
  var strategic_prey_pin := Vector2.ZERO
  if body.is_in_group(&"prey"):
    strategic_threat = _nearest_position_from_dict_mobs(pos, mobs_arr)
  elif body.is_in_group(&"mobs") and not body.is_in_group(&"prey") and predator_hunt_motivated:
    strategic_prey_pin = _nearest_vector_from_positions(pos, prey_pts_live)

  var w_shield := (
    float(motor_p.get("weight_obstacle_shield_prey", 0.0)) if body.is_in_group(&"prey") else 0.0
  )
  var w_pin := (
    float(motor_p.get("weight_obstacle_pin_predator", 0.0))
    if body.is_in_group(&"mobs") and not body.is_in_group(&"prey") and predator_hunt_motivated
    else 0.0
  )

  var w_p_dist := 0.0
  var w_p_close := 0.0
  var w_p_sq := 0.0
  if body.is_in_group(&"mobs") and not body.is_in_group(&"prey") and predator_hunt_motivated:
    w_p_dist = float(motor_p.get("weight_pursuit_dist", 0.42))
    w_p_close = float(motor_p.get("weight_pursuit_closing", 0.95))
    w_p_sq = float(motor_p.get("weight_pursuit_dist_sq", 38.0))

  var imminent_pts: Array = []
  var imminent_r_applied := 0.0
  if imminent_r_cfg > 0.0 and (
    w_seek > 0.0 or w_seek_prey > 0.0 or not food_targets.is_empty()
  ):
    imminent_pts = _motor_imminent_mob_positions(body)
    imminent_r_applied = imminent_r_cfg
    if w_seek > 0.0 and not imminent_pts.is_empty():
      var clear_now := float(
        Callable(_MOTOR, &"minimum_footprint_point_clearance").call(pos, he_xy, imminent_pts)
      )
      if clear_now < imminent_r_cfg:
        w_seek = 0.0

  var weight_obstacle_ctx := float(motor_p.get("weight_obstacle", 0.0))
  if body.is_in_group(&"mobs") and not body.is_in_group(&"prey"):
    weight_obstacle_ctx *= float(motor_p.get("weight_obstacle_predator_boost", 1.55))

  var motor_entropy: int = _physics_ticks ^ body.get_instance_id() ^ _duel_motor_round_salt
  motor_entropy ^= int(pos.x * 0.0731 + pos.y * 0.0583)
  var motor_goal_in_sight := false
  if is_predator_body:
    motor_goal_in_sight = w_seek_prey > 0.0 or predator_lost_visual
  elif body.is_in_group(&"prey"):
    motor_goal_in_sight = not plant_ready_targets.is_empty()
  var chaos_amp := float(motor_p.get("motor_intent_cost_chaos", 0.0))
  if herbivore_flee_active:
    chaos_amp = 0.0
  elif motor_goal_in_sight:
    chaos_amp *= float(motor_p.get("motor_goal_sight_chaos_mul", 0.25))
  else:
    chaos_amp *= float(motor_p.get("motor_no_goal_chaos_mul", 2.5))

  var w_dist_out := float(motor_p.get("weight_dist", 0.45))
  var w_dist_sq_out := float(motor_p.get("weight_dist_sq", 55.0))
  var w_close_out := float(motor_p.get("weight_closing", 1.05))
  var w_edge_out := float(motor_p.get("weight_edge", 0.48)) * float(hunger_explore.get("edge_mul", 1.0))
  if herbivore_flee_active:
    w_edge_out *= float(motor_p.get("herbivore_flee_edge_mul", 4.0))
    w_dist_out *= float(motor_p.get("herbivore_flee_dist_mul", 2.8))
    w_dist_sq_out *= float(motor_p.get("herbivore_flee_dist_sq_mul", 2.2))
    w_close_out *= float(motor_p.get("herbivore_flee_close_mul", 1.85))

  var motor_has_active_goal := false
  if body.is_in_group(&"prey"):
    motor_has_active_goal = (
      herbivore_flee_active
      or herbivore_alert
      or w_seek > 0.0
    )
  elif is_predator_body:
    motor_has_active_goal = w_seek_prey > 0.0 or predator_lost_visual

  var prey_seek_motor: Array = prey_pts_live if predator_hunt_motivated else []
  var pursuit_motor: Array = pursuit_targets if predator_hunt_motivated else []

  return {
    "creature_position": pos,
    "creature_speed": spd,
    "lookahead_sec": float(motor_p.get("lookahead_sec", 0.15)),
    "bounds_min": Vector2.ZERO,
    "bounds_max": ss,
    "mobs": mobs_arr,
    "weight_dist": w_dist_out,
    "weight_dist_sq": w_dist_sq_out,
    "weight_closing": w_close_out,
    "penalty_oob": float(motor_p.get("penalty_oob", 1e7)),
    "distance_eps": float(motor_p.get("distance_eps", 6.0)),
    "creature_half_extents": he_xy,
    "weight_interior": float(motor_p.get("weight_interior", 0.65)) * float(hunger_explore.get("interior_mul", 1.0)),
    "weight_edge": w_edge_out,
    "shuffle_tie_break": _motor_bool_default_true(motor_p, "shuffle_tie_break"),
    "tie_shuffle_seed": motor_entropy,
    "motor_intent_cost_chaos": chaos_amp,
    "motor_chaos_seed": motor_entropy,
    "motor_pick_tick": _physics_ticks,
    "motor_tie_cost_epsilon": float(motor_p.get("motor_tie_cost_epsilon", 0.55)),
    "motor_cardinal_block_min_clearance_px": float(
      motor_p.get("motor_patrol_min_step_clearance_px", 4.0)
    ),
    "motor_no_goal_plateau_random": _motor_bool_default_true(motor_p, "motor_no_goal_plateau_random"),
    "awareness_radius": float(motor_p.get("awareness_radius", 0.0)),
    "awareness_cone_extra": float(motor_p.get("awareness_cone_extra", 0.0)),
    "awareness_cone_cos_threshold": cos(deg_to_rad(half_deg)),
    "awareness_forward_cone_only": bool(motor_p.get("awareness_forward_cone_only", false)),
    "creature_facing": facing_display,
    "static_obstacles": geom_aabbs,
    "weight_obstacle": weight_obstacle_ctx,
    "creature_size": csz,
    "environment_grid": env_grid,
    "interior_env_motor_active": interior_active,
    "interior_env_near_mob_px": float(motor_p.get("interior_env_near_mob_px", 70.0)),
    "weight_interior_env_solid": float(motor_p.get("weight_interior_env_solid", 8000.0)),
    "weight_interior_env_slow": float(motor_p.get("weight_interior_env_slow", 4.0)),
    "food_seek_targets": food_targets,
    "weight_seek_ready_food": w_seek,
    "imminent_mob_points": imminent_pts,
    "food_seek_imminent_mob_radius_px": imminent_r_applied,
    "unready_food_avoid_targets": unready_food_targets,
    "weight_avoid_unready_food": w_avoid_unready,
    "weight_explore_idle_penalty": w_idle_exp,
    "weight_explore_turn_bias": w_turn_exp,
    "explore_trail_centers": trail_for_motor,
    "weight_explore_trail_repulsion": w_trail_rep,
    "weight_expanding_explore_hint": w_expand_hint_out,
    "expanding_explore_hint": expand_hint,
    "exploration_blend_multiplier": exploration_blend_multiplier,
    "prey_seek_targets": prey_seek_motor,
    "weight_seek_prey": w_seek_prey,
    "pursuit_targets": pursuit_motor,
    "weight_pursuit_dist": w_p_dist,
    "weight_pursuit_closing": w_p_close,
    "weight_pursuit_dist_sq": w_p_sq,
    "aware_obstacle_samples": aware_samples,
    "strategic_threat_pos": strategic_threat,
    "strategic_prey_pin_pos": strategic_prey_pin,
    "weight_obstacle_shield_prey": w_shield,
    "weight_obstacle_pin_predator": w_pin,
    "herbivore_flee_active": herbivore_flee_active,
    "herbivore_flee_panic": herbivore_flee_active,
    "herbivore_alert": herbivore_alert,
    "motor_has_active_goal": motor_has_active_goal,
  }


func _physics_process(_delta: float) -> void:
  if _state != State.PLAYING or _main == null:
    return
  var subjects := _scripted_motor_subjects()
  if subjects.is_empty():
    return
  var focal := _primary_creature if _primary_creature != null else _creature
  if focal == null:
    focal = subjects[0] as PhysicsBody2D

  _physics_ticks += 1
  var p: Dictionary = _live_perception_params()
  var stride := maxi(1, int(p.get("SNAPSHOT_PHYSICS_STRIDE", 1)))
  if _physics_ticks % stride == 0:
    _latest_snapshot = _build_snapshot_blob(focal)
    _has_snapshot = not _latest_snapshot.is_empty()

  if _creature_motor_mode() == "scripted":
    _refresh_motor_obstacle_cache_if_needed()
    for subj in subjects:
      if not is_instance_valid(subj):
        continue
      var is_pred_subj: bool = subj.is_in_group(&"mobs") and not subj.is_in_group(&"prey")
      if not is_pred_subj and int(subj.get("control_mode")) != _PlayerScr.engine_control_as_int():
        continue
      var motor_p := _creature_motor_params_for_body(subj)
      _apply_creature_speed_from_pack(subj)
      _explore_trail_record(subj, motor_p)
      var h_ex := _hunger_exploration_modifiers(motor_p, subj)
      var ctx := _build_motor_context(motor_p, h_ex, subj)
      if ctx.is_empty():
        continue
      if subj == focal:
        _debug_last_motor_mobs = (ctx["mobs"] as Array).duplicate(true)
      var body_id: int = subj.get_instance_id()
      var j_state := _jeopardy_state_for(body_id)
      var hold_state := _scripted_intent_hold_state_for(body_id)
      var incumbent_v: Variant = subj.get("creature_move_intent")
      var incumbent: Vector2 = incumbent_v if typeof(incumbent_v) == TYPE_VECTOR2 else Vector2.ZERO
      var stuck_n := _motor_stuck_track_mob(subj, incumbent, motor_p)
      var is_pred: bool = subj.is_in_group(&"mobs") and not subj.is_in_group(&"prey")
      var hunt_active := is_pred and _predator_hunt_active_in_ctx(ctx)
      var stuck_thr := maxi(1, int(motor_p.get("motor_stuck_escape_ticks", 8)))
      if hunt_active:
        stuck_thr = 1
      var is_prey_body: bool = subj.is_in_group(&"prey")
      var pred_pos: Vector2 = ctx.get("creature_position", Vector2.ZERO)
      var he_nav: Vector2 = ctx.get("creature_half_extents", Vector2(13.5, 30.5))
      var toward_nav := Vector2.ZERO
      if is_pred:
        var prey_nav: Array = ctx.get("prey_seek_targets", []) as Array
        if not prey_nav.is_empty():
          toward_nav = _nearest_vector_from_positions(pred_pos, prey_nav)
        else:
          var purs_nav: Array = ctx.get("pursuit_targets", []) as Array
          if not purs_nav.is_empty() and typeof(purs_nav[0]) == TYPE_DICTIONARY:
            toward_nav = (purs_nav[0] as Dictionary).get("position", Vector2.ZERO)
      elif is_prey_body and bool(ctx.get("herbivore_flee_panic", false)):
        if _main != null:
          for mn in _main.get_tree().get_nodes_in_group(&"mobs"):
            if mn is Node2D:
              toward_nav = pred_pos - (mn as Node2D).global_position
              break
      var static_obs_nav: Array = ctx.get("static_obstacles", []) as Array
      _motor_obstacle_slip_shaping(
        ctx, motor_p, pred_pos, he_nav, body_id, stuck_n, toward_nav, is_prey_body
      )
      if hunt_active and stuck_n >= 1:
        _predator_hunt_stalemate_shaping(ctx, motor_p, pred_pos, body_id, stuck_n, subj)
      if stuck_n >= stuck_thr and not bool(ctx.get("creature_nav_slip_active", false)):
        var ws0 := float(ctx.get("weight_seek_ready_food", 0.0))
        if is_pred:
          ctx["weight_seek_ready_food"] = ws0 * float(motor_p.get("motor_stuck_prey_pull_scale", 1.5))
          var hunt_stalemate := not (ctx.get("prey_seek_targets", []) as Array).is_empty() or not (
            ctx.get("pursuit_targets", []) as Array
          ).is_empty()
          if hunt_stalemate:
            _predator_hunt_stalemate_shaping(ctx, motor_p, pred_pos, body_id, stuck_n, subj)
          elif not _motor_obstacle_slip_shaping(
            ctx, motor_p, pred_pos, he_nav, body_id, stuck_n, toward_nav, false
          ):
            var base_ex := int(motor_p.get("expanding_explore_base_physics_ticks", 36))
            var hint := _ExploreScr.Explore.pick_cardinal(
              base_ex, _physics_ticks, body_id ^ _duel_motor_round_salt
            )
            ctx["expanding_explore_hint"] = hint
            ctx["weight_expanding_explore_hint"] = maxf(
              float(ctx.get("weight_expanding_explore_hint", 0.0)),
              float(motor_p.get("weight_stuck_escape_explore", 2.2)),
            )
            ctx["weight_explore_turn_bias"] *= float(motor_p.get("motor_stuck_turn_bias_scale", 0.25))
            ctx["weight_explore_idle_penalty"] *= float(motor_p.get("motor_stuck_idle_penalty_scale", 2.5))
          else:
            ctx["motor_stuck_allow_expand_hint"] = true
            ctx["weight_expanding_explore_hint"] = maxf(
              float(ctx.get("weight_expanding_explore_hint", 0.0)),
              float(motor_p.get("weight_stuck_escape_explore_when_chasing", 2.2)),
            )
        else:
          if not _motor_obstacle_slip_shaping(
            ctx, motor_p, pred_pos, he_nav, body_id, stuck_n, toward_nav, true
          ):
            var base_ex_p := int(motor_p.get("expanding_explore_base_physics_ticks", 36))
            ctx["expanding_explore_hint"] = _ExploreScr.Explore.pick_cardinal(
              base_ex_p, _physics_ticks, body_id ^ _duel_motor_round_salt
            )
          ctx["motor_stuck_allow_expand_hint"] = true
          ctx["weight_expanding_explore_hint"] = maxf(
            float(ctx.get("weight_expanding_explore_hint", 0.0)),
            float(motor_p.get("weight_stuck_escape_explore", 2.2)),
          )
          ctx["weight_explore_turn_bias"] *= float(motor_p.get("motor_stuck_turn_bias_scale", 0.25))
          ctx["weight_explore_idle_penalty"] *= float(motor_p.get("motor_stuck_idle_penalty_scale", 2.5))
      elif stuck_n >= 1:
        ctx["motor_stuck_allow_expand_hint"] = true
        ctx["weight_expanding_explore_hint"] = maxf(
          float(ctx.get("weight_expanding_explore_hint", 0.0)),
          float(motor_p.get("weight_stuck_escape_explore", 2.2)),
        )
        if not is_pred:
          var static_obs_p: Array = ctx.get("static_obstacles", []) as Array
          var esc_p := _pick_stuck_escape_cardinal(pred_pos, he_nav, static_obs_p, body_id, stuck_n)
          if esc_p.length_squared() > 1e-12:
            ctx["expanding_explore_hint"] = esc_p
      if is_prey_body:
        _track_herbivore_forage_plateau(body_id, ctx, incumbent, stuck_n, motor_p)
        if _herbivore_forage_plateau_release(body_id, motor_p):
          ctx["motor_has_active_goal"] = false
          _forage_plateau_ticks_by_body[body_id] = 0
      var has_active_goal := bool(ctx.get("motor_has_active_goal", true))
      var patrol_lock_sec := float(motor_p.get("motor_no_goal_patrol_lock_sec", 0.0))
      var patrol_state := _no_goal_patrol_lock_state_for(body_id)
      var raw_intent: Vector2
      if has_active_goal:
        Callable(_NoGoalPatrolLockScr, &"reset_state").call(patrol_state)
        raw_intent = _MOTOR.pick_best_move_intent(ctx)
      elif patrol_lock_sec > 0.0:
        var patrol_min_clr := float(motor_p.get("motor_patrol_min_step_clearance_px", 4.0))
        var patrol_blocked := func(dir: Vector2) -> bool:
          return _cardinal_step_blocked(
            pred_pos, he_nav, dir, static_obs_nav, patrol_min_clr
          )
        raw_intent = Callable(_NoGoalPatrolLockScr, &"pick_or_hold").call(
          patrol_state,
          patrol_lock_sec,
          body_id ^ _duel_motor_round_salt,
          patrol_blocked,
        ) as Vector2
      else:
        raw_intent = _MOTOR.pick_best_move_intent(ctx)
      if is_prey_body:
        raw_intent = _herbivore_nudge_away_from_unready_if_idle(ctx, raw_intent, motor_p)
      if hunt_active and stuck_n >= 1:
        raw_intent = _latched_stuck_escape_intent(
          body_id, pred_pos, he_nav, static_obs_nav, stuck_n, motor_p
        )
        if raw_intent.length_squared() < 1e-12:
          raw_intent = _predator_hunt_stuck_rotate_intent(body_id, stuck_n, motor_p)
      elif is_prey_body and stuck_n >= 1:
        raw_intent = _latched_stuck_escape_intent(
          body_id, pred_pos, he_nav, static_obs_nav, stuck_n, motor_p
        )
      elif bool(ctx.get("herbivore_flee_panic", false)):
        var flee_threat := _nearest_position_from_dict_mobs(
          ctx["creature_position"] as Vector2, ctx.get("mobs", []) as Array
        )
        if flee_threat != Vector2.ZERO:
          raw_intent = _herbivore_locked_flee_intent(
            body_id,
            ctx["creature_position"] as Vector2,
            flee_threat,
            ctx.get("bounds_max", Vector2.ZERO) as Vector2,
            ctx.get("creature_half_extents", Vector2(13.5, 30.5)) as Vector2,
            motor_p,
          )
      var is_prey: bool = subj.is_in_group(&"prey")
      var jeopardy_ticks := maxi(0, int(motor_p.get("jeopardy_forced_turn_ticks", 5)))
      if is_prey:
        jeopardy_ticks = maxi(0, int(motor_p.get("jeopardy_forced_turn_ticks_prey", 3)))
      elif is_pred:
        var jpred := maxi(1, int(motor_p.get("jeopardy_forced_turn_ticks_predator", jeopardy_ticks)))
        jeopardy_ticks = maxi(
          0, int(round(float(jpred) * float(motor_p.get("jeopardy_weight_rival_predator", 1.0))))
        )
      var jeopardy_forced := false
      if jeopardy_ticks > 0:
        var half_deg_j: float = float(motor_p.get("awareness_cone_half_angle_deg", 45.0))
        var jeopardy_imminent := float(motor_p.get("food_seek_imminent_mob_radius_px", 100.0))
        if is_prey:
          jeopardy_imminent = float(
            motor_p.get("herbivore_jeopardy_imminent_radius_px", jeopardy_imminent)
          )
        var jeopardy_eval: Dictionary = Callable(_JeopardyTurnScr, &"evaluate_jeopardy_tick").call(
          {
            "incumbent": incumbent,
            "creature_position": ctx["creature_position"],
            "creature_half_extents": ctx.get("creature_half_extents", Vector2.ZERO),
            "creature_facing": ctx.get("creature_facing", Vector2.RIGHT),
            "mobs": ctx.get("mobs", []),
            "imminent_radius_px": jeopardy_imminent,
            "cone_cos_threshold": cos(deg_to_rad(half_deg_j)),
            "required_ticks": jeopardy_ticks,
          },
          j_state,
        )
        if bool(jeopardy_eval.get("should_force", false)):
          raw_intent = Callable(_JeopardyTurnScr, &"pick_forced_turn").call(
            ctx,
            incumbent,
            jeopardy_eval["threat_mob_pos"],
          ) as Vector2
          jeopardy_forced = true
          Callable(_IntentHoldScr, &"reset_state").call(hold_state)
      var hold_base := float(maxi(1, int(motor_p.get("scripted_intent_hold_physics_ticks", 8))))
      if not is_prey:
        hold_base = float(maxi(1, int(motor_p.get("intent_hold_ticks_predator", 6))))
      var extra_hold := 0.0
      if is_prey:
        var food_seek_list: Array = ctx.get("food_seek_targets", []) as Array
        if food_seek_list.is_empty():
          extra_hold = float(maxi(0, int(motor_p.get("explore_intent_hold_extra_ticks", 5))))
      var hold_ticks := maxi(
        1,
        int(round((hold_base + extra_hold) * float(h_ex.get("hold_mul", 1.0))))
      )
      var intent: Vector2 = raw_intent
      if not jeopardy_forced:
        var hold_apply := hold_ticks
        if (
          bool(ctx.get("predator_stalemate_active", false))
          or bool(ctx.get("creature_nav_slip_active", false))
        ):
          hold_apply = 1
        elif bool(ctx.get("herbivore_flee_panic", false)):
          hold_apply = maxi(6, int(motor_p.get("herbivore_flee_intent_hold_ticks", 12)))
        intent = Callable(_IntentHoldScr, &"filtered_intent").call(
          raw_intent, incumbent, hold_apply, hold_state
        ) as Vector2
      if subj.has_method(&"set_creature_move_intent"):
        subj.call(&"set_creature_move_intent", intent)

  _record_mob_history_if_playing()


func _refresh_inference_client_config() -> void:
  _inference_client = _live_inference_client()


func _set_state(next_state: State) -> void:
  if _state == next_state:
    return
  if _state == State.PLAYING and next_state != State.PLAYING:
    _motor_reset_scripted_auxiliary_states()
    _explore_trail_reset()
  _state = next_state
  emit_signal("ai_session_state_changed", int(_state))


func _enqueue_inference_request() -> void:
  _refresh_inference_client_config()
  var user_content := _ARMED_HANDSHAKE_USER if _state == State.ARMED else ""
  if _state == State.PLAYING:
    if not _has_snapshot:
      _next_inference_ms = Time.get_ticks_msec() + int(_inference_client.get("INFERENCE_PERIOD_MS", 250))
      return
    user_content = _latest_snapshot
  var rid := _request_id_counter
  _request_id_counter += 1
  _latest_enqueued_request_id = rid
  var base_url := str(_inference_client.get("INFERENCE_BASE_URL", "")).rstrip("/")
  var completions_path := str(_inference_client.get("COMPLETIONS_PATH", "/v1/completions")).strip_edges()
  var url: String
  var req: Dictionary
  if not completions_path.is_empty():
    url = "%s%s" % [base_url, completions_path]
    var trailer := ""
    match _state:
      State.ARMED:
        trailer = _COMPLETION_OUTPUT_TRAILER_ARMED
      State.PLAYING:
        trailer = _COMPLETION_OUTPUT_TRAILER_PLAYING
      _:
        trailer = ""
    var prompt := _system_prompt + _COMPLETION_PROMPT_SEPARATOR + user_content + trailer
    _last_request_used_completions = true
    _last_prompt_tail = prompt.substr(maxi(0, prompt.length() - 220), 220)
    _last_user_head = (
      user_content.get_slice("\n", 0).strip_edges().substr(0, 120)
      if not user_content.is_empty()
      else ""
    )
    #region agent log
    _last_completion_grammar = ""
    if bool(_inference_client.get("LLAMA_COMPLETION_GRAMMAR_ENABLED", true)):
      _last_completion_grammar = gbnf_for_completion_state_enum(int(_state))
    _dbg46_emit(
      "ai-inf",
      "H-A",
      "ai_driver.gd:_enqueue_inference_request",
      "enqueue_completions",
      {
        "state_enum": int(_state),
        "url_tail": url.substr(maxi(0, url.length() - 96), 96),
        "prompt_chars": prompt.length(),
        "trailer_chars": trailer.length(),
        "grammar_chars": _last_completion_grammar.length(),
        "prompt_tail": _last_prompt_tail,
        "user_head": _last_user_head,
      },
    )
    #endregion
    req = {
      "model": str(_inference_client.get("MODEL_ID", "")),
      "prompt": prompt,
      "max_tokens": int(_inference_client.get("MAX_OUTPUT_TOKENS", 48)),
      "temperature": float(_inference_client.get("TEMPERATURE", 0.0)),
      "stream": false,
      "echo": false,
    }
    if not _last_completion_grammar.is_empty():
      req["grammar"] = _last_completion_grammar
  else:
    var chat_path := str(_inference_client.get("CHAT_COMPLETIONS_PATH", "/v1/chat/completions")).strip_edges()
    if chat_path.is_empty():
      chat_path = "/v1/chat/completions"
    url = "%s%s" % [base_url, chat_path]
    _last_request_used_completions = false
    _last_prompt_tail = ""
    _last_user_head = (
      user_content.get_slice("\n", 0).strip_edges().substr(0, 120)
      if not user_content.is_empty()
      else ""
    )
    #region agent log
    _dbg46_emit(
      "ai-inf",
      "H-A",
      "ai_driver.gd:_enqueue_inference_request",
      "enqueue_chat",
      {"state_enum": int(_state), "url_tail": url.substr(maxi(0, url.length() - 96), 96), "user_head": _last_user_head},
    )
    #endregion
    req = {
      "model": str(_inference_client.get("MODEL_ID", "")),
      "messages": [
        {"role": "system", "content": _system_prompt},
        {"role": "user", "content": user_content},
      ],
      "max_tokens": int(_inference_client.get("MAX_OUTPUT_TOKENS", 48)),
      "temperature": float(_inference_client.get("TEMPERATURE", 0.0)),
      "stream": false,
    }
  _last_inference_url = url
  var headers := ["Content-Type: application/json"]
  var api_key := str(_inference_client.get("API_KEY", "")).strip_edges()
  if not api_key.is_empty():
    headers.append("Authorization: Bearer %s" % api_key)
  var err := _http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(req))
  if err != OK:
    _inflight_request_id = -1
    _next_inference_ms = Time.get_ticks_msec() + int(_inference_client.get("INFERENCE_PERIOD_MS", 250))
    return
  _inflight_request_id = rid
  _next_inference_ms = Time.get_ticks_msec() + int(_inference_client.get("INFERENCE_PERIOD_MS", 250))
  emit_signal("ai_inference_started", rid)


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  var rid := _inflight_request_id
  _inflight_request_id = -1
  if not should_apply_response_id(rid, _latest_enqueued_request_id):
    return
  if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
    _fail_inference_response(
      "inference HTTP failed (%s, http=%s) url=%s"
      % [http_request_result_label(result), response_code, _last_inference_url]
    )
    return
  var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
  if typeof(parsed) != TYPE_DICTIONARY:
    _fail_inference_response("inference response JSON was not an object")
    return
  var choice0_keys: Array = []
  var ch: Variant = (parsed as Dictionary).get("choices", [])
  if typeof(ch) == TYPE_ARRAY and not (ch as Array).is_empty():
    var z: Variant = (ch as Array)[0]
    if typeof(z) == TYPE_DICTIONARY:
      for k in (z as Dictionary).keys():
        choice0_keys.append(str(k))
  var cmpl_raw := extract_openai_completion_choice_text(parsed)
  var content := _extract_message_content(parsed)
  var token: String = (
    _TOKENS.normalize_completion_token_armed_handshake(content)
    if _state == State.ARMED
    else _TOKENS.normalize_completion_token(content)
  )
  var excerpt := content.strip_edges().replace("\n", " ").replace("\r", " ")
  var content_empty := content.strip_edges().is_empty()
  if excerpt.length() > _TL_DEBUG_CONTENT_MAX_CHARS:
    excerpt = excerpt.substr(0, _TL_DEBUG_CONTENT_MAX_CHARS) + " [truncated]"
  _OLogSafe.debug("TL completion raw=\"%s\" ΓåÆ token=%s" % [excerpt, token], true, "AiDriver")
  #region agent log
  _dbg46_emit(
    "ai-inf",
    "H-B",
    "ai_driver.gd:_on_http_request_completed",
    "completion_parsed",
    {
      "state_enum": int(_state),
      "used_completions": _last_request_used_completions,
      "prompt_tail": _last_prompt_tail,
      "user_head": _last_user_head,
      "choice0_keys": choice0_keys,
      "cmpl_len": cmpl_raw.length(),
      "cmpl_head": cmpl_raw.substr(0, mini(80, cmpl_raw.length())).replace("\n", "\\n"),
      "cmpl_nonempty_stripped": not cmpl_raw.strip_edges().is_empty(),
      "grammar_sent_chars": _last_completion_grammar.length(),
      "content_head": content.substr(0, mini(100, content.length())).replace("\n", "\\n"),
      "token": token,
    },
  )
  #endregion
  if token == "noop" and (_state == State.ARMED or _state == State.PLAYING):
    var now_ms := Time.get_ticks_msec()
    if now_ms - _noop_diag_last_ms >= 2000:
      _noop_diag_last_ms = now_ms
      _OLogSafe.info(
        (
          "AiDriver: TL noop (state_enum=%d, content_empty=%s). raw_excerpt=\"%s\". "
          + "If content_empty: raise inference_client.MAX_OUTPUT_TOKENS or fix server JSON. "
          + "Else: model/template issue; see OLog debug for each completion."
        )
        % [int(_state), content_empty, excerpt],
        true,
        "AiDriver"
      )
  _apply_action_token(token)
  emit_signal("ai_inference_finished", token)


func _fail_inference_response(reason: String) -> void:
  emit_signal("ai_inference_finished", "noop")
  if _state != State.ARMED:
    return
  _OLogSafe.error("AiDriver: %s ΓÇö cancel AI setup." % reason, true, "AiDriver")
  cancel_armed_session()


func _extract_message_content(resp: Dictionary) -> String:
  var from_cmpl := extract_openai_completion_choice_text(resp)
  if not from_cmpl.strip_edges().is_empty():
    return from_cmpl
  return extract_openai_chat_choice_text(resp)


func _apply_action_token(token: String) -> void:
  if token == "START":
    if _state == State.ARMED and _main != null and _main.has_method("new_game"):
      _main.call_deferred("new_game")
    return
  var intent_body := _primary_creature if _primary_creature != null else _creature
  if intent_body == null or not intent_body.has_method(&"set_creature_move_intent"):
    return
  var dir := Vector2.ZERO
  match token:
    "UP":
      dir = Vector2(0, -1)
    "DOWN":
      dir = Vector2(0, 1)
    "LEFT":
      dir = Vector2(-1, 0)
    "RIGHT":
      dir = Vector2(1, 0)
    _:
      return
  intent_body.call(&"set_creature_move_intent", dir)


func _build_snapshot_blob(snapshot_creature: PhysicsBody2D = null) -> String:
  var obs := snapshot_creature if snapshot_creature != null else _creature
  if _main == null or obs == null:
    return ""
  var viewport_size := (obs.get("screen_size") as Vector2)
  if viewport_size == Vector2.ZERO:
    viewport_size = _viewport_playfield_size_px(obs)
  var cols := int(ceil(viewport_size.x / float(CELL_SIZE)))
  var rows := int(ceil(viewport_size.y / float(CELL_SIZE)))
  if cols <= 0 or rows <= 0:
    return ""

  var grid: Array = []
  for _r in rows:
    var row := PackedInt32Array()
    row.resize(cols)
    grid.append(row)

  var creature_sample := _SAMPLING.sampling_from_collision_object(obs)
  var creature_point: Vector2 = creature_sample.get("point", obs.global_position)
  var creature_ext: Vector3 = creature_sample.get("half_extents", Vector3.ZERO)
  var creature_cell := _world_to_cell(creature_point, cols, rows)

  var mobs: Array[Dictionary] = []
  for n in _main.get_tree().get_nodes_in_group("mobs"):
    if n is RigidBody2D:
      var mob := n as RigidBody2D
      var mob_sample := _SAMPLING.sampling_from_collision_object(mob)
      var mob_point: Vector2 = mob_sample.get("point", mob.global_position)
      mobs.append({
        "node": mob,
        "sample": mob_sample,
        "dist": mob_point.distance_to(creature_point),
        "id": mob.get_instance_id(),
      })
  mobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
    var da: float = a["dist"]
    var db: float = b["dist"]
    if is_equal_approx(da, db):
      return int(a["id"]) < int(b["id"])
    return da < db
  )

  var mob_hint_entries: Array = []
  for info in mobs:
    var mob_rb: RigidBody2D = info["node"]
    var hint_point: Vector2 = info["sample"].get("point", mob_rb.global_position)
    mob_hint_entries.append({"point": hint_point, "velocity": mob_rb.linear_velocity})

  var creature_vel2 := Vector2.ZERO
  if obs.has_method(&"get"):
    creature_vel2 = obs.get("current_velocity") as Vector2

  var patch_band: Dictionary = (
    Callable(_RISK, &"classify_creature_patch_and_band").call(
      creature_cell.x,
      creature_cell.y,
      rows,
      cols,
      creature_vel2
    )
    as Dictionary
  )
  var prio: Dictionary = Callable(_RISK, &"pick_priority_closing_mob").call(mob_hint_entries, creature_point) as Dictionary

  for info in mobs:
    var mob_point: Vector2 = info["sample"].get("point", Vector2.ZERO)
    var mob_cell := _world_to_cell(mob_point, cols, rows)
    var cur := int(grid[mob_cell.x][mob_cell.y])
    if mob_cell == creature_cell:
      grid[mob_cell.x][mob_cell.y] = 3
    elif cur == 0:
      grid[mob_cell.x][mob_cell.y] = 2

  var pcur := int(grid[creature_cell.x][creature_cell.y])
  grid[creature_cell.x][creature_cell.y] = 3 if pcur == 2 else 1

  var lines: PackedStringArray = []
  lines.append(_WIRE.format_header_line(Time.get_ticks_msec(), int(_main.get("score")), cols, rows, CELL_SIZE))
  lines.append(
    (
      Callable(_WIRE, &"format_risk_hints_line").call(
        int(prio["idx_1"]),
        float(prio["t_approx_sec"]),
        str(patch_band["patch"]),
        str(patch_band["band"])
      )
      as String
    )
  )
  lines.append(
    (
      Callable(_WIRE, &"format_plain_hint_line").call(int(prio["idx_1"]), str(patch_band["patch"]), str(patch_band["band"]))
      as String
    )
  )
  for r in rows:
    var s := ""
    var row_arr: PackedInt32Array = grid[r]
    for c in cols:
      s += str(row_arr[c])
    lines.append(s)
  var creature_vel := Vector3(creature_vel2.x, creature_vel2.y, 0.0)
  lines.append(_WIRE.format_entity_velocity_line("PLAYER", creature_cell.x, creature_cell.y, creature_vel))
  lines.append(_WIRE.format_entity_extents_line("PLAYER_EXT", creature_ext))

  for info in mobs:
    var mob: RigidBody2D = info["node"]
    var mob_sample: Dictionary = info["sample"]
    var mob_point: Vector2 = mob_sample.get("point", mob.global_position)
    var mob_cell := _world_to_cell(mob_point, cols, rows)
    var mob_vel := Vector3(mob.linear_velocity.x, mob.linear_velocity.y, 0.0)
    var mob_ext: Vector3 = mob_sample.get("half_extents", Vector3.ZERO)
    lines.append(_WIRE.format_entity_velocity_line("MOB", mob_cell.x, mob_cell.y, mob_vel))
    lines.append(_WIRE.format_entity_extents_line("MOB_EXT", mob_ext))

  return "\n".join(lines)


func _world_to_cell(world_pos: Vector2, cols: int, rows: int) -> Vector2i:
  var c := clampi(int(floor(world_pos.x / float(CELL_SIZE))), 0, cols - 1)
  var r := clampi(int(floor(world_pos.y / float(CELL_SIZE))), 0, rows - 1)
  return Vector2i(r, c)
