#!/usr/bin/env python3
"""Round 2: ai_driver.gd Vector3 migration — defaults, flee/stuck signatures, cardinals."""
from pathlib import Path

TARGET = Path(__file__).resolve().parents[1] / "AI_int_lib" / "ai_driver.gd"


def main() -> int:
  t = TARGET.read_text(encoding="utf-8")

  t = t.replace("Vector3 = Vector2.ZERO", "Vector3 = Vector3.ZERO")

  # Flee / escape return types
  for sig in [
    ") -> Vector2:\n  var lock_ticks := maxi(4, int(motor_p.get(\"herbivore_flee_lock_ticks\"",
    ") -> Vector2:\n  var away := creature_pos - threat_pos",
    ") -> Vector2:\n  if flee_dir.length_squared()",
    ") -> Vector2:\n  var prefer := Vector2.ZERO",
    ") -> Vector2:\n  var lock_ticks := maxi(6, int(motor_p.get(\"geometry_escape_lock_ticks\"",
  ]:
    t = t.replace(sig, sig.replace(") -> Vector2:", ") -> Vector3:"))

  t = t.replace("food_pull: Vector2 = Vector2.ZERO", "food_pull: Vector3 = Vector3.ZERO")
  t = t.replace("incumbent_intent: Vector2", "incumbent_intent: Vector3")
  t = t.replace("hunt_prey_pos != Vector2.ZERO", "hunt_prey_pos != Vector3.ZERO")
  t = t.replace("prev_sample_pos: Vector2", "prev_sample_pos: Vector3")
  t = t.replace("incumbent: Vector2", "incumbent: Vector3")

  t = t.replace("flee_dir: Vector2", "flee_dir: Vector3")
  t = t.replace("cardinal: Vector2", "cardinal: Vector3")
  t = t.replace("away_u: Vector2", "away_u: Vector3")
  t = t.replace("threat_u: Vector2", "threat_u: Vector3")
  t = t.replace("probe: Vector2", "probe: Vector3")
  t = t.replace("var c: Vector2 = cardinals", "var c: Vector3 = cardinals")
  t = t.replace("var c2: Vector2 = cardinals", "var c2: Vector3 = cardinals")
  t = t.replace("var old_t: Vector2 = rec.get(\"threat_pos\"", "var old_t: Vector3 = _as_motor_vec3(rec.get(\"threat_pos\"")
  t = t.replace(
    "aware_obstacle_samples: PackedVector2Array = PackedVector2Array()",
    "aware_obstacle_samples: PackedVector3Array = PackedVector3Array()",
  )

  t = t.replace(
    "else Vector2.RIGHT",
    "else Vector3(1.0, 0.0, 0.0)",
  )
  t = t.replace("Vector2(-away_ob.y, away_ob.x)", "Vector3(-away_ob.z, 0.0, away_ob.x)")
  t = t.replace("Vector2(-slip_dir.y, slip_dir.x)", "Vector3(-slip_dir.z, 0.0, slip_dir.x)")
  t = t.replace("Vector2.RIGHT if bool(body_id & 1) else Vector2.UP", "Vector3(1.0, 0.0, 0.0) if bool(body_id & 1) else Vector3(0.0, 0.0, -1.0)")

  t = t.replace("var nearest_ob: Vector2 = slip_info.get", "var nearest_ob: Vector3 = _as_motor_vec3(slip_info.get")
  t = t.replace("nearest_ob == Vector2.ZERO", "nearest_ob == Vector3.ZERO")
  t = t.replace('slip_info.get("ob_center", Vector2.ZERO)', 'slip_info.get("ob_center", Vector3.ZERO)')
  t = t.replace('slip_info.get("away_dir", Vector2.ZERO)', 'slip_info.get("away_dir", Vector3.ZERO)')
  t = t.replace("typeof(away_pre) == TYPE_VECTOR2 and (away_pre as Vector2)", "typeof(away_pre) == TYPE_VECTOR3 and (away_pre as Vector3)")
  t = t.replace("toward_world = away_pre as Vector2", "toward_world = away_pre as Vector3")
  t = t.replace("away_raw as Vector2 if typeof(away_raw) == TYPE_VECTOR2 else Vector3.ZERO", "away_raw as Vector3 if typeof(away_raw) == TYPE_VECTOR3 else Vector3.ZERO")
  t = t.replace("var picked := Vector2.ZERO", "var picked := Vector3.ZERO")
  t = t.replace("ctx[\"expanding_explore_hint\"] = _snap_seek_direction(slip_dir)", "ctx[\"expanding_explore_hint\"] = _snap_seek_direction_v3(slip_dir)")

  t = t.replace("var apply_shield_bonus := func(cardinal: Vector2, probe: Vector2, score: float)", "var apply_shield_bonus := func(cardinal: Vector3, probe: Vector3, score: float)")
  t = t.replace("      Vector2.ZERO,\n      aware_obstacle_samples,", "      Vector3.ZERO,\n      aware_obstacle_samples,")

  # Edge clearance uses z for playfield Y axis
  t = t.replace(
    "      minf(probe.y - margin, bounds_max.y - margin - probe.y),",
    "      minf(probe.z - margin, bounds_max.y - margin - probe.z),",
  )

  t = t.replace("return _snap_seek_direction(away_u)", "return _snap_seek_direction_v3(away_u)")
  t = t.replace("var away_snap := _snap_seek_direction(away_u)", "var away_snap := _snap_seek_direction_v3(away_u)")

  t = t.replace("typeof(c) != TYPE_VECTOR2", "typeof(c) != TYPE_VECTOR3")
  t = t.replace("var card := c as Vector2", "var card := c as Vector3")
  t = t.replace("typeof(away_v) == TYPE_VECTOR2 and (away_v as Vector2)", "typeof(away_v) == TYPE_VECTOR3 and (away_v as Vector3)")
  t = t.replace("prefer = away_v as Vector2", "prefer = away_v as Vector3")
  t = t.replace('slip.get("away_dir", Vector2.ZERO)', 'slip.get("away_dir", Vector3.ZERO)')

  # Blocked approach
  t = t.replace("body: PhysicsBody2D,\n  ctx: Dictionary,\n  stuck_n: int,\n  incumbent: Vector3", "body: Node,\n  ctx: Dictionary,\n  stuck_n: int,\n  incumbent: Vector3")
  t = t.replace("var pos: Vector2 = ctx.get(\"creature_position\"", "var pos: Vector3 = _as_motor_vec3(ctx.get(\"creature_position\"")
  t = t.replace("var last_move := Vector2.ZERO", "var last_move := Vector3.ZERO")
  t = t.replace("if typeof(lm) == TYPE_VECTOR2 and (lm as Vector2)", "if typeof(lm) == TYPE_VECTOR3 and (lm as Vector3)")
  t = t.replace("last_move = lm as Vector2", "last_move = lm as Vector3")
  t = t.replace(") as Vector2\n  if approach.length_squared()", ") as Vector3\n  if approach.length_squared()")
  t = t.replace("var approach: Vector2 = Callable(_BlockedApproachScr", "var approach: Vector3 = Callable(_BlockedApproachScr")

  # Motor stuck track — accept Node + Vector3 positions
  t = t.replace(
    "func _motor_stuck_track_mob(\n  body: PhysicsBody2D,\n  incumbent_intent: Vector3,",
    "func _motor_stuck_track_mob(\n  body: Node,\n  incumbent_intent: Vector3,",
  )
  t = t.replace(
    "  var sid := body.get_instance_id()\n  var pos := body.global_position",
    "  var sid := body.get_instance_id()\n  var pos := _MotorPlane.body_motor_position(body)",
  )

  # Cardinal best aligned v3
  t = t.replace(
    """static func _cardinal_best_aligned_to(world_dir: Vector2) -> Vector2:
  if world_dir.length_squared() < 1e-12:
    return Vector3.ZERO
  var u := world_dir.normalized()
  var best := Vector2.RIGHT
  var best_dot := -INF
  for c in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
    var d := u.dot(c)
    if d > best_dot:
      best_dot = d
      best = c
  return best""",
    """static func _cardinal_best_aligned_to_v3(world_dir: Vector3) -> Vector3:
  if world_dir.length_squared() < 1e-12:
    return Vector3.ZERO
  var u := world_dir.normalized()
  var best := Vector3(1.0, 0.0, 0.0)
  var best_dot := -INF
  for c in _MotorOctScr.SEEK_DIRECTIONS:
    var d := u.dot(c as Vector3)
    if d > best_dot:
      best_dot = d
      best = c as Vector3
  return best


static func _cardinal_best_aligned_to(world_dir: Vector2) -> Vector2:
  var v3 := _cardinal_best_aligned_to_v3(Vector3(world_dir.x, 0.0, world_dir.y))
  return Vector2(v3.x, v3.z)""",
  )

  t = t.replace("var toward := _cardinal_best_aligned_to_v3(prey_pos - pos)", "var toward := _cardinal_best_aligned_to_v3(prey_pos - pos)")

  TARGET.write_text(t, encoding="utf-8")
  print(f"Updated {TARGET}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
