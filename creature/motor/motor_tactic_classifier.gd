## MotorContext tactic classifier flags ([CREATURE_MOVEMENT_V2.md §A.2.1](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
extends Object

const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")
const _EnvGrid := preload("res://environment/environment_grid_baked.gd")
const _EnvCell := preload("res://environment/environment_cell_data.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")


static func _read_pos_v3(v: Variant) -> Vector3:
  var p: Variant = Callable(_MotorPlane, &"read_pos").call(v)
  if typeof(p) == TYPE_VECTOR3:
    return p as Vector3
  if typeof(p) == TYPE_VECTOR2:
    return _MotorPlane.to_horizontal_vec3(p as Vector2)
  return Vector3.ZERO


## Returns tactic-classifier subset for salient writes and [code]current_fit[/code] ([CREATURE_GOAL_DRIVERS.md §5.1.1](../../Project_Docs/Draft_Features/CREATURE_GOAL_DRIVERS.md)).
static func build_motor_ctx_tactics(
  creature_pos: Vector3,
  creature_half: Vector2,
  creature_size: float,
  _creature_facing: Vector3,
  motor_p: Dictionary,
  static_obstacles: Array,
  environment_grid: Variant,
  herbivore_threat: Dictionary,
  herbivore_flee_active: bool,
  mobs_arr: Array,
  nearest_hotspot_centroid: Vector3 = Vector3.ZERO,
) -> Dictionary:
  var tactic_jeopardy_egress := herbivore_flee_active
  var tactic_in_squeeze := _detect_in_squeeze(
    creature_pos, creature_half, creature_size, static_obstacles, environment_grid, motor_p
  )
  var tactic_hide_viable := _detect_hide_viable(
    herbivore_threat, herbivore_flee_active, motor_p
  )
  var tactic_return_home := _detect_return_home_payoff(
    creature_pos, nearest_hotspot_centroid, motor_p
  )
  var tactic_lasting_local_change := false
  var tactic_fight_active := false
  var hide_hold_still := tactic_hide_viable and not tactic_jeopardy_egress
  var conspecific_aid_count := _count_conspecifics_near(creature_pos, mobs_arr, motor_p)
  var tactic_classifier_active := (
    tactic_jeopardy_egress
    or tactic_in_squeeze
    or tactic_hide_viable
    or tactic_return_home
    or tactic_lasting_local_change
    or tactic_fight_active
  )
  return {
    "tactic_classifier_active": tactic_classifier_active,
    "tactic_jeopardy_egress": tactic_jeopardy_egress,
    "tactic_in_squeeze": tactic_in_squeeze,
    "tactic_hide_viable": tactic_hide_viable,
    "tactic_return_home_payoff": tactic_return_home,
    "tactic_lasting_local_change": tactic_lasting_local_change,
    "tactic_fight_active": tactic_fight_active,
    "hide_hold_still": hide_hold_still,
    "conspecific_aid_count": conspecific_aid_count,
    "nearest_hotspot_centroid": nearest_hotspot_centroid,
  }


static func _detect_in_squeeze(
  creature_pos: Vector3,
  creature_half: Vector2,
  creature_size: float,
  static_obstacles: Array,
  environment_grid: Variant,
  motor_p: Dictionary,
) -> bool:
  var clr_thr := float(motor_p.get("tactic_squeeze_clearance_px", 28.0))
  if not static_obstacles.is_empty() and clr_thr > 0.0:
    var clr := _Motor.footprint_static_clearance(
      creature_pos,
      creature_half,
      static_obstacles,
    )
    if clr < clr_thr:
      return true
  if creature_size > 0.0 and environment_grid != null and environment_grid is _EnvGrid:
    var grid := environment_grid as EnvironmentGridBaked
    if grid.is_valid_shape():
      var cell_r := grid.sample_cell_data_at_world(Vector2(creature_pos.x, creature_pos.z))
      if cell_r != null and cell_r is _EnvCell:
        var env := cell_r as EnvironmentCellData
        if env.can_enter(creature_size):
          var mult := env.movement_speed_multiplier(creature_size)
          if mult < 0.92:
            return true
  return false


static func _detect_hide_viable(
  herbivore_threat: Dictionary,
  herbivore_flee_active: bool,
  motor_p: Dictionary,
) -> bool:
  if herbivore_flee_active:
    return false
  if not bool(herbivore_threat.get("in_awareness", false)):
    return false
  var gate_dist := float(herbivore_threat.get("gate_dist", INF))
  if gate_dist >= INF:
    return false
  var panic_r := float(
    motor_p.get(
      "herbivore_flee_panic_radius_px",
      motor_p.get("herbivore_jeopardy_imminent_radius_px", 200.0),
    )
  )
  return gate_dist > panic_r


static func _detect_return_home_payoff(
  creature_pos: Vector3,
  hotspot_centroid: Vector3,
  motor_p: Dictionary,
) -> bool:
  if hotspot_centroid == Vector3.ZERO:
    return false
  var hotspot_r := float(motor_p.get("believed_goal_hotspot_near_radius_px", 250.0))
  if hotspot_r <= 1e-4:
    return false
  var dist := creature_pos.distance_to(hotspot_centroid)
  return dist <= hotspot_r * 1.25


static func _count_conspecifics_near(creature_pos: Vector3, mobs_arr: Array, motor_p: Dictionary) -> int:
  var radius := float(motor_p.get("tactic_conspecific_aid_radius_px", 120.0))
  if radius <= 1e-4:
    return 0
  var count := 0
  for entry in mobs_arr:
    if typeof(entry) != TYPE_DICTIONARY:
      continue
    var pos: Vector3 = _read_pos_v3((entry as Dictionary).get("position", Vector3.ZERO))
    if pos == Vector3.ZERO:
      continue
    if creature_pos.distance_to(pos) <= radius:
      count += 1
  return count
