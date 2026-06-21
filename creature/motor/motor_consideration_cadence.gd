extends RefCounted
class_name MotorConsiderationCadence
## Observation → replan interval [code]n[/code] ([CREATURE_MOVEMENT_V3.md §10](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).


## Returns physics ticks between goal-consideration cycles (POST_LOS piecewise curve; stat clamped ≥ 10).
static func observation_replan_interval_ticks(stat_observation: int, motor_v3: Dictionary) -> int:
  var stat := maxi(10, int(stat_observation))
  var base_ticks := maxi(1, int(motor_v3.get("goal_replan_base_ticks", 8)))
  var scale := 1.0
  if stat <= 10:
    scale = lerpf(2.0, 1.0, float(stat) / 10.0)
  else:
    scale = lerpf(1.0, 0.5, clampf(float(stat - 10) / 90.0, 0.0, 1.0))
  return maxi(1, int(round(float(base_ticks) * scale)))
