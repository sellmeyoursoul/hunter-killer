#!/usr/bin/env python3
"""Migrate ai_driver.gd spatial helpers from Vector2 to horizontal Vector3 (M2)."""
from pathlib import Path

TARGET = Path(__file__).resolve().parents[1] / "AI_int_lib" / "ai_driver.gd"


def main() -> int:
  t = TARGET.read_text(encoding="utf-8")

  # Footprint helpers: motor plane uses .x/.z for world X/Z; bounds stay Vector2.
  t = t.replace(
    "func _footprint_edge_margin(\n  creature_pos: Vector2, he: Vector2, bounds_min: Vector2, bounds_max: Vector2\n) -> float:\n"
    "  var left := creature_pos.x - he.x - bounds_min.x\n"
    "  var right := bounds_max.x - (creature_pos.x + he.x)\n"
    "  var top := creature_pos.y - he.y - bounds_min.y\n"
    "  var bottom := bounds_max.y - (creature_pos.y + he.y)",
    "func _footprint_edge_margin(\n  creature_pos: Vector3, he: Vector2, bounds_min: Vector2, bounds_max: Vector2\n) -> float:\n"
    "  var left := creature_pos.x - he.x - bounds_min.x\n"
    "  var right := bounds_max.x - (creature_pos.x + he.x)\n"
    "  var top := creature_pos.z - he.y - bounds_min.y\n"
    "  var bottom := bounds_max.y - (creature_pos.z + he.y)",
  )
  t = t.replace(
    "func _footprint_in_bounds(\n  center: Vector2, he: Vector2, bounds_min: Vector2, bounds_max: Vector2\n) -> bool:\n"
    "  return (\n"
    "    center.x - he.x >= bounds_min.x\n"
    "    and center.x + he.x <= bounds_max.x\n"
    "    and center.y - he.y >= bounds_min.y\n"
    "    and center.y + he.y <= bounds_max.y\n"
    "  )",
    "func _footprint_in_bounds(\n  center: Vector3, he: Vector2, bounds_min: Vector2, bounds_max: Vector2\n) -> bool:\n"
    "  return (\n"
    "    center.x - he.x >= bounds_min.x\n"
    "    and center.x + he.x <= bounds_max.x\n"
    "    and center.z - he.y >= bounds_min.y\n"
    "    and center.z + he.y <= bounds_max.y\n"
    "  )",
  )

  # Cardinal wrappers accept legacy Vector2 at call sites.
  t = t.replace(
    "static func _cardinal_step_blocked(\n  creature_pos: Vector3,\n  he_xy: Vector2,\n  direction: Vector3,",
    "static func _cardinal_step_blocked(\n  creature_pos: Variant,\n  he_xy: Vector2,\n  direction: Variant,",
  )
  t = t.replace(
    "  return _MOTOR.cardinal_step_blocked(\n    creature_pos, he_xy, direction, static_obs, min_clearance_px\n  )",
    "  return _MOTOR.cardinal_step_blocked(\n    MotorPlane.read_pos(creature_pos), he_xy, MotorPlane.read_dir(direction), static_obs, min_clearance_px\n  )",
    1,
  )
  t = t.replace(
    "static func _cardinal_step_blocked_for_escape(\n  creature_pos: Vector3,\n  he_xy: Vector2,\n  direction: Vector3,",
    "static func _cardinal_step_blocked_for_escape(\n  creature_pos: Variant,\n  he_xy: Vector2,\n  direction: Variant,",
  )
  t = t.replace(
    "  return _MOTOR.cardinal_step_blocked_for_escape(\n    creature_pos, he_xy, direction, static_obs, min_clearance_px\n  )",
    "  return _MOTOR.cardinal_step_blocked_for_escape(\n    MotorPlane.read_pos(creature_pos), he_xy, MotorPlane.read_dir(direction), static_obs, min_clearance_px\n  )",
    1,
  )

  spatial_params = [
    "creature_pos: Vector2",
    "memory_pos: Vector2",
    "prey_pos: Vector2",
    "hunter_pos: Vector2",
    "threat_pos: Vector2",
    "predicted: Vector2",
    "center: Vector2",
    "probe_pos: Vector2",
    "prefer_world: Vector2",
    "prefer_dir: Vector2",
    "toward_world: Vector2",
    "raw_intent: Vector2",
    "nav_toward_dir: Vector2",
  ]
  for old in spatial_params:
    t = t.replace(old, old.replace("Vector2", "Vector3"))

  # Intent return types (heuristic: lines with escape/intent/chase in nearby context are handled separately).
  intent_returns = [
    ") -> Vector2:\n  if memory_pos == Vector2.ZERO:",
    ") -> Vector2:\n  if prey_pos == Vector2.ZERO:",
    ") -> Vector2:\n  if not _creature_playfield_corner_hugging",
    ") -> Vector2:\n  if not _playfield_bounds_valid",
    ") -> Vector2:\n  if raw_intent.length_squared()",
    ") -> Vector2:\n  if toward.length_squared()",
    ") -> Vector2:\n  if hunt_prey_pos",
  ]
  for frag in intent_returns:
    t = t.replace(frag, frag.replace("-> Vector2:", "-> Vector3:").replace("Vector2.ZERO", "Vector3.ZERO"))

  t = t.replace(") -> Vector2:\n  var escape_dirs", ") -> Vector3:\n  var escape_dirs")
  t = t.replace(") -> Vector2:\n  if prefer_dir.length_squared()", ") -> Vector3:\n  if prefer_dir.length_squared()")
  t = t.replace(") -> Vector2:\n  if memory_pos == Vector3.ZERO", ") -> Vector3:\n  if memory_pos == Vector3.ZERO")

  t = t.replace("var c: Vector2 = escape_dirs", "var c: Vector3 = escape_dirs")
  t = t.replace("var c_rel: Vector2 = escape_dirs", "var c_rel: Vector3 = escape_dirs")
  t = t.replace("var best_d := Vector2.ZERO", "var best_d := Vector3.ZERO")
  t = t.replace("var pick := Vector2.ZERO", "var pick := Vector3.ZERO")
  t = t.replace("var esc := Vector2.ZERO", "var esc := Vector3.ZERO")
  t = t.replace("var fallback := _snap_seek_direction", "var fallback := _snap_seek_direction_v3")
  t = t.replace("var desired := _snap_seek_direction", "var desired := _snap_seek_direction_v3")
  t = t.replace("else Vector2.ZERO", "else Vector3.ZERO")
  t = t.replace("return Vector2.ZERO", "return Vector3.ZERO")

  # Static obstacle slip info
  t = t.replace(
    "static func _static_obstacle_slip_info(\n  creature_pos: Vector2, he_xy: Vector2, static_obs: Array\n) -> Dictionary:",
    "static func _static_obstacle_slip_info(\n  creature_pos: Vector3, he_xy: Vector2, static_obs: Array\n) -> Dictionary:",
  )
  t = t.replace(
    '    var op: Vector2 = ob.get("position", Vector2.ZERO)',
    '    var op: Vector3 = MotorPlane.read_pos(ob.get("position", Vector3.ZERO))',
  )
  t = t.replace("  var best_center := Vector2.ZERO", "  var best_center := Vector3.ZERO")
  t = t.replace('return {"clearance": INF, "ob_center": Vector2.ZERO, "away_dir": Vector2.ZERO}',
                'return {"clearance": INF, "ob_center": Vector3.ZERO, "away_dir": Vector3.ZERO}')
  t = t.replace("      var sep_closest_c: Vector2 = Callable", "      var sep_closest_c: Vector3 = Callable")
  t = t.replace("      var sep_closest_o: Vector2 = Callable", "      var sep_closest_o: Vector3 = Callable")
  t = t.replace("  var closest_c: Vector2 = Callable", "  var closest_c: Vector3 = Callable")
  t = t.replace("  var closest_o: Vector2 = (\n    Callable", "  var closest_o: Vector3 = (\n    Callable")

  # Locked direction reads
  t = t.replace('rec.get("dir", Vector2.ZERO)', 'rec.get("dir", Vector3.ZERO)')
  t = t.replace("typeof(locked) == TYPE_VECTOR2", "typeof(locked) == TYPE_VECTOR3")
  t = t.replace("locked as Vector2", "locked as Vector3")
  t = t.replace("var locked_d := locked as Vector2", "var locked_d := locked as Vector3")

  # Playfield center on motor plane
  t = t.replace("  var center_u := Vector2.ZERO", "  var center_u := Vector3.ZERO")
  t = t.replace("  var prefer_u := Vector2.ZERO", "  var prefer_u := Vector3.ZERO")
  t = t.replace("  var to_center := center - creature_pos", "  var to_center := Vector3(center.x, 0.0, center.y) - creature_pos")

  # Predator hunt nudge etc.
  t = t.replace(
    "func _predator_hunt_nudge_if_idle(ctx: Dictionary, raw_intent: Vector2) -> Vector2:",
    "func _predator_hunt_nudge_if_idle(ctx: Dictionary, raw_intent: Vector3) -> Vector3:",
  )
  t = t.replace(
    '  var pos: Vector2 = ctx.get("creature_position", Vector2.ZERO)',
    '  var pos: Vector3 = _as_motor_vec3(ctx.get("creature_position", Vector3.ZERO))',
  )
  t = t.replace("  if prey_pos == Vector2.ZERO:", "  if prey_pos == Vector3.ZERO:")
  t = t.replace("  var toward := _cardinal_best_aligned_to", "  var toward := _cardinal_best_aligned_to_v3")

  TARGET.write_text(t, encoding="utf-8")
  print(f"Updated {TARGET}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
