#!/usr/bin/env python3
"""Round 4: remaining Vector3 type fixes in ai_driver.gd."""
from pathlib import Path

TARGET = Path(__file__).resolve().parents[1] / "AI_int_lib" / "ai_driver.gd"


def main() -> int:
  t = TARGET.read_text(encoding="utf-8")

  # Duel spawn facing: EightWay DIRECTIONS are Vector3
  t = t.replace(
    "    var facing: Vector2 = _EightWayDirScr.DIRECTIONS[slot]\n"
    "    if body.has_method(&\"apply_duel_spawn_facing\"):\n"
    "      body.call(&\"apply_duel_spawn_facing\", facing)\n"
    "    else:\n"
    "      body.set(\"last_move_direction\", facing)\n",
    "    var facing: Vector3 = _EightWayDirScr.DIRECTIONS[slot]\n"
    "    var facing_hint: Variant = facing\n"
    "    if body is PhysicsBody2D:\n"
    "      facing_hint = Vector2(facing.x, facing.z)\n"
    "    if body.has_method(&\"apply_duel_spawn_facing\"):\n"
    "      body.call(&\"apply_duel_spawn_facing\", facing_hint)\n"
    "    else:\n"
    "      body.set(\"last_move_direction\", facing_hint)\n",
  )

  # Awareness gate distance: Vector3 AABB math
  t = t.replace(
    "  var creature_center2 := Vector2(creature_center.x, creature_center.z)\n"
    "  var mob_pos2 := Vector2(mob_pos.x, mob_pos.z)\n"
    "  var half := creature_half\n"
    "  if half.x <= 0.0 or half.y <= 0.0:\n"
    "    return creature_center2.distance_to(mob_pos2)\n"
    "  var closest_c := _MOTOR.closest_point_on_aabb(creature_center2, half, mob_pos2)\n"
    "  return mob_pos2.distance_to(closest_c)\n",
    "  var half := creature_half\n"
    "  if half.x <= 0.0 or half.y <= 0.0:\n"
    "    return creature_center.distance_to(mob_pos)\n"
    "  var closest_c := _MOTOR.closest_point_on_aabb(creature_center, half, mob_pos)\n"
    "  return mob_pos.distance_to(closest_c)\n",
  )

  # Predator hunt: snap v3
  t = t.replace("_snap_seek_direction(to_prey)", "_snap_seek_direction_v3(to_prey)")

  # Remove pos2 shim in motor context build
  t = t.replace("  var pos2 := Vector2(pos.x, pos.z)\n", "")
  for old in [
    "_footprint_edge_margin(pos2, he_xy, Vector2.ZERO, ss)",
    "_herbivore_nearest_latched_food_pos(body.get_instance_id(), pos2)",
    "_snap_seek_direction(latch_pos - pos2)",
    "_static_obstacle_slip_info(pos2, he_xy, geom_aabbs)",
    "_pick_stuck_escape_cardinal(\n          pos2, he_xy, geom_aabbs, body.get_instance_id(), 1\n        )",
    "_static_obstacle_slip_info(pos2, he_xy, geom_aabbs)",
    "_creature_playfield_corner_wedge_active(\n    pos2, he_xy, geom_aabbs, Vector2.ZERO, ss, motor_p\n  )",
    "_creature_playfield_corner_hugging(\n    pos2, he_xy, Vector2.ZERO, ss, motor_p\n  )",
    "consult_threat_response(\n      pos2, motor_p, tactic_ctx, traits_for_motor\n    )",
  ]:
    t = t.replace(old, old.replace("pos2", "pos"))

  # Believed goal bias pos type
  t = t.replace(
    '  var pos: Vector2 = ctx["creature_position"]\n',
    '  var pos: Vector3 = _as_motor_vec3(ctx["creature_position"])\n',
  )

  # Salient write anchors Vector3
  t = t.replace(
    "  store.try_salient_write(\n"
    "    goal_kind,\n"
    "    dom,\n"
    "    food_anchor,\n",
    "  store.try_salient_write(\n"
    "    goal_kind,\n"
    "    dom,\n"
    "    Vector3(food_anchor.x, 0.0, food_anchor.y),\n",
  )
  t = t.replace(
    "  store.try_salient_write(\n"
    "    goal_kind,\n"
    "    dom,\n"
    "    body.global_position,\n",
    "  store.try_salient_write(\n"
    "    goal_kind,\n"
    "    dom,\n"
    "    _as_motor_vec3(_MotorPlane.body_motor_position(body)),\n",
  )

  # Latch food expand hint
  t = t.replace(
    "    if latch_pos != Vector2.ZERO:\n"
    "      var latch_snap := _snap_seek_direction(latch_pos - pos)\n"
    "      expand_hint = Vector3(latch_snap.x, 0.0, latch_snap.y)\n",
    "    if latch_pos != Vector3.ZERO:\n"
    "      var latch_snap := _snap_seek_direction_v3(latch_pos - pos)\n"
    "      expand_hint = latch_snap\n",
  )

  # Herbivore flee expand in context build
  t = t.replace(
    "          var away_snap := _snap_seek_direction(Vector2(away.x, away.z))\n"
    "          expand_hint = Vector3(away_snap.x, 0.0, away_snap.y)\n",
    "          var away_snap := _snap_seek_direction_v3(away)\n"
    "          expand_hint = away_snap\n",
  )

  # Predator memory lost visual
  t = t.replace(
    "    var toward_snap := _snap_seek_direction(Vector2(toward.x, toward.z))\n"
    "    expand_hint = Vector3(toward_snap.x, 0.0, toward_snap.y)\n",
    "    var toward_snap := _snap_seek_direction_v3(toward)\n"
    "    expand_hint = toward_snap\n",
  )

  # Patrol interior hint
  t = t.replace(
    "          var interior_hint := _snap_seek_direction(Vector2(toward_center.x, toward_center.z))\n"
    "          if interior_hint.length_squared() > 1e-12:\n"
    "            expand_hint = Vector3(interior_hint.x, 0.0, interior_hint.y)\n",
    "          var interior_hint := _snap_seek_direction_v3(toward_center)\n"
    "          if interior_hint.length_squared() > 1e-12:\n"
    "            expand_hint = interior_hint\n",
  )

  # Spawn / patrol slip expand hints
  t = t.replace(
    "          expand_hint = Vector3(esc_spawn.x, 0.0, esc_spawn.y)\n",
    "          expand_hint = esc_spawn\n",
  )
  t = t.replace(
    "      if typeof(away_p) == TYPE_VECTOR2 and (away_p as Vector2).length_squared() > 1e-12:\n"
    "        var away2 := away_p as Vector2\n"
    "        var away_snap := _snap_seek_direction(away2)\n"
    "        expand_hint = Vector3(away_snap.x, 0.0, away_snap.y)\n",
    "      if typeof(away_p) == TYPE_VECTOR3 and (away_p as Vector3).length_squared() > 1e-12:\n"
    "        var away3 := away_p as Vector3\n"
    "        var away_snap := _snap_seek_direction_v3(away3)\n"
    "        expand_hint = away_snap\n",
  )

  # Physics flee away_snap
  t = t.replace(
    "                var away_snap := _snap_seek_direction(flee_away)\n"
    "                if not _cardinal_step_blocked_for_escape(\n"
    "                  pred_pos, he_nav, away_snap, static_obs_nav, flee_block_clr\n"
    "                ):\n"
    "                  raw_intent = _motor_plane_v3(away_snap)\n",
    "                var away_snap := _snap_seek_direction_v3(flee_away)\n"
    "                if not _cardinal_step_blocked_for_escape(\n"
    "                  pred_pos, he_nav, away_snap, static_obs_nav, flee_block_clr\n"
    "                ):\n"
    "                  raw_intent = away_snap\n",
  )

  TARGET.write_text(t, encoding="utf-8")
  print(f"Updated {TARGET}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
