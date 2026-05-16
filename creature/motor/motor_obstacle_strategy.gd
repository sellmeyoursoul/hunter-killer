## Lightweight obstacle-aware tactics layered on cardinal motor costs ([shield] prey vs predator / [pin] predator).
extends Object


## Computes additive motor cost from obstacle flank cues ([negative] lowers total cost when advantageous).
## Params:
## - predicted: Candidate creature footprint center after lookahead.
## - threat_pos: Predator center when [param shield_weight] active ([code]Vector2.ZERO[/code] disables shield term).
## - prey_pin_pos: Prey center when [param pin_weight] active ([code]Vector2.ZERO[/code] disables pin term).
## - obstacle_points: World-space obstacle outline samples inside awareness (corners / capsule rim).
## - eps: Distance floor for inverse weighting.
## Returns:
## - Scalar added to cardinal cost (negative values reward that move).
static func strategic_obstacle_cost(
  predicted: Vector2,
  threat_pos: Vector2,
  prey_pin_pos: Vector2,
  obstacle_points: PackedVector2Array,
  shield_weight: float,
  pin_weight: float,
  eps: float,
) -> float:
  var total := 0.0
  if obstacle_points.is_empty():
    return total
  var inv_eps := 1.0 / maxf(eps, 1.0)

  if shield_weight > 1e-8 and threat_pos.length_squared() > 1e-6:
    var u_threat := (threat_pos - predicted)
    var dt := u_threat.length()
    if dt > 1e-4:
      u_threat /= dt
      for i in range(obstacle_points.size()):
        var sp := obstacle_points[i]
        var v := sp - predicted
        var d := v.length()
        if d < 1e-4:
          continue
        var u_obs := v / d
        var align := maxf(0.0, u_obs.dot(u_threat))
        total -= shield_weight * align * inv_eps / maxf(eps, d)

  if pin_weight > 1e-8 and prey_pin_pos.length_squared() > 1e-6:
    var u_prey := (prey_pin_pos - predicted)
    var dp := u_prey.length()
    if dp > 1e-4:
      u_prey /= dp
      for i in range(obstacle_points.size()):
        var sp := obstacle_points[i]
        var v := sp - predicted
        var d := v.length()
        if d < 1e-4:
          continue
        var u_obs := v / d
        var pin_align := maxf(0.0, u_obs.dot(u_prey))
        total -= pin_weight * pin_align * inv_eps / maxf(eps, d)

  return total
