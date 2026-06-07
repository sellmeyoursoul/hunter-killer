extends SceneTree

const _Motor := preload("res://creature/motor/cardinal_avoidance.gd")

func _init() -> void:
  var ctx := {
    "creature_position": Vector3(20.0, 0.0, 360.0),
    "creature_speed": 400.0,
    "lookahead_sec": 0.15,
    "bounds_min": Vector2.ZERO,
    "bounds_max": Vector2(480.0, 720.0),
    "mobs": [],
    "weight_dist": 1.0,
    "weight_closing": 0.5,
    "penalty_oob": 1e7,
    "distance_eps": 8.0,
    "shuffle_tie_break": false,
    "weight_interior": 3.0,
    "weight_dist_sq": 0.0,
    "weight_edge": 0.0,
  }
  var creature_pos: Vector3 = ctx["creature_position"]
  var step_len := float(ctx["creature_speed"]) * float(ctx["lookahead_sec"])
  var order := _Motor.evaluation_order_from_ctx(ctx)
  for d in order:
    if d.length_squared() < 1e-14:
      continue
    var predicted := creature_pos + d.normalized() * step_len
    var cost := _Motor.cost_at_prediction(
      predicted,
      [],
      Vector2.ZERO,
      Vector2(480.0, 720.0),
      1.0,
      0.5,
      1e7,
      8.0,
      Vector2.ZERO,
      3.0,
      0.0,
      0.0,
      creature_pos,
    )
    print("d=", d, " cost=", cost)
  quit(0)
