#!/usr/bin/env python3
"""Round 3: fix remaining ai_driver.gd parse/type errors for M2 Vector3 migration."""
from pathlib import Path

TARGET = Path(__file__).resolve().parents[1] / "AI_int_lib" / "ai_driver.gd"


def main() -> int:
  t = TARGET.read_text(encoding="utf-8")

  # --- Syntax: missing closing parens on _as_motor_vec3 ---
  t = t.replace(
    '_as_motor_vec3(slip_info.get("ob_center", Vector3.ZERO)\n',
    '_as_motor_vec3(slip_info.get("ob_center", Vector3.ZERO))\n',
  )
  t = t.replace(
    '_as_motor_vec3(ctx.get("creature_position", body.global_position)\n',
    '_as_motor_vec3(ctx.get("creature_position", body.global_position))\n',
  )
  t = t.replace(
    '_as_motor_vec3(rec.get("threat_pos", Vector2.ZERO)\n',
    '_as_motor_vec3(rec.get("threat_pos", Vector3.ZERO))\n',
  )

  # --- Predator hunt stalemate ---
  t = t.replace(
    "  var prey_pos := _nearest_vector_from_positions(creature_pos, prey_seek)\n"
    "  if prey_pos == Vector2.ZERO and not pursuit.is_empty():\n"
    "    var item0: Variant = pursuit[0]\n"
    "    if typeof(item0) == TYPE_DICTIONARY:\n"
    "      prey_pos = (item0 as Dictionary).get(\"position\", Vector2.ZERO)\n",
    "  var prey_pos := _nearest_prey_pos_from_ctx(creature_pos, ctx)\n",
  )
  t = t.replace("  var flank := Vector2(-to_prey.y, to_prey.x)\n", "  var flank := Vector3(-to_prey.z, 0.0, to_prey.x)\n")
  t = t.replace("  if nearest_ob != Vector2.ZERO:\n", "  if nearest_ob != Vector3.ZERO:\n")
  t = t.replace(
    '  if ctx.get("expanding_explore_hint", Vector2.ZERO) is Vector2:\n'
    '    var eh: Vector2 = ctx["expanding_explore_hint"]\n',
    '  if ctx.get("expanding_explore_hint", Vector3.ZERO) is Vector3:\n'
    '    var eh: Vector3 = ctx["expanding_explore_hint"]\n',
  )

  # --- Rescan goal ctx ---
  t = t.replace(
    "  var pos3 := Vector3(pos.x, 0.0, pos.y)\n",
    "  var pos3 := Vector3(pos.x, 0.0, pos.z)\n",
  )

  # --- Blocked approach backtrack ---
  t = t.replace(
    "  var blocked: Vector2 = Callable(_BlockedApproachScr, &\"active_dir\").call(rec, _physics_ticks) as Vector2\n",
    "  var blocked: Vector3 = Callable(_BlockedApproachScr, &\"active_dir\").call(rec, _physics_ticks) as Vector3\n",
  )

  # --- Flee obstacle nudge ---
  t = t.replace(
    "  var away_ob := away_ob_raw as Vector2 if typeof(away_ob_raw) == TYPE_VECTOR2 else Vector3.ZERO\n",
    "  var away_ob := away_ob_raw as Vector3 if typeof(away_ob_raw) == TYPE_VECTOR3 else Vector3.ZERO\n",
  )

  # --- Pinch escape prefer ---
  t = t.replace("  var prefer := Vector2.ZERO\n", "  var prefer := Vector3.ZERO\n")

  # --- Nearest helpers: Vector3 return ---
  t = t.replace(
    "func _nearest_position_from_dict_mobs(creature_pos: Vector3, mobs_arr: Array) -> Vector2:\n"
    "  var best := INF\n"
    "  var out := Vector2.ZERO\n"
    "  for item in mobs_arr:\n"
    "    if typeof(item) != TYPE_DICTIONARY:\n"
    "      continue\n"
    "    var mp: Vector2 = item.get(\"position\", Vector2.ZERO)\n"
    "    var d := creature_pos.distance_squared_to(mp)\n"
    "    if d < best:\n"
    "      best = d\n"
    "      out = mp\n"
    "  return out if best < INF else Vector3.ZERO\n",
    "func _nearest_position_from_dict_mobs(creature_pos: Vector3, mobs_arr: Array) -> Vector3:\n"
    "  return _nearest_position3_from_dict_mobs(creature_pos, mobs_arr)\n",
  )
  t = t.replace(
    "func _nearest_vector_from_positions(creature_pos: Vector3, pts: Array) -> Vector2:\n"
    "  var best := INF\n"
    "  var out := Vector2.ZERO\n"
    "  for p in pts:\n"
    "    if typeof(p) != TYPE_VECTOR2:\n"
    "      continue\n"
    "    var pv := p as Vector2\n"
    "    var d := creature_pos.distance_squared_to(pv)\n"
    "    if d < best:\n"
    "      best = d\n"
    "      out = pv\n"
    "  return out if best < INF else Vector3.ZERO\n",
    "func _nearest_vector_from_positions(creature_pos: Vector3, pts: Array) -> Vector3:\n"
    "  return _nearest_vector3_from_positions(creature_pos, pts)\n",
  )

  # --- Latched food pos ---
  t = t.replace(
    "func _herbivore_nearest_latched_food_pos(body_id: int, creature_pos: Vector3) -> Vector2:\n",
    "func _herbivore_nearest_latched_food_pos(body_id: int, creature_pos: Vector3) -> Vector3:\n",
  )

  # --- Pacing trap computed type ---
  t = t.replace(
    "  body_id: int, incumbent: Vector3, computed: Vector2, pinch_active: bool = false\n",
    "  body_id: int, incumbent: Vector3, computed: Vector3, pinch_active: bool = false\n",
  )
  t = t.replace(
    "  if typeof(prev_v) != TYPE_VECTOR2:\n"
    "    return false\n"
    "  var prev := prev_v as Vector2\n",
    "  if typeof(prev_v) != TYPE_VECTOR3:\n"
    "    return false\n"
    "  var prev := prev_v as Vector3\n",
  )

  # --- Predator hunt Vector3.ZERO comparisons ---
  for old in [
    "prey_pos == Vector2.ZERO",
    "prey_open != Vector2.ZERO",
    "prey_edge != Vector2.ZERO",
    "flee_threat != Vector2.ZERO",
    "break_pos == Vector2.ZERO",
    "break_pos != Vector2.ZERO",
    "latch_fp != Vector2.ZERO",
    "latch_fp_pinch != Vector2.ZERO",
    "latch_fc != Vector2.ZERO",
    "!= Vector2.ZERO",
  ]:
    new = old.replace("Vector2.ZERO", "Vector3.ZERO")
    if old != "!= Vector2.ZERO":
      t = t.replace(old, new)

  # Fix specific != Vector2.ZERO that should stay (bounds) - revert bounds lines if needed
  # (none of the above affect bounds)

  t = t.replace(
    "  return _nearest_prey_pos_from_ctx(creature_pos, ctx) != Vector2.ZERO\n",
    "  return _nearest_prey_pos_from_ctx(creature_pos, ctx) != Vector3.ZERO\n",
  )

  # --- Predator open hunt close ---
  t = t.replace(
    '  return Callable(_MotorOctScr, &"snap_to_seek_direction").call(to_prey) as Vector2\n',
    '  return Callable(_MotorOctScr, &"snap_to_seek_direction").call(to_prey) as Vector3\n',
  )

  # --- Geom chase segment: use .z for world Z ---
  t = t.replace(
    "Vector3(creature_pos.x, 0.0, creature_pos.y)",
    "Vector3(creature_pos.x, 0.0, creature_pos.z)",
  )
  t = t.replace(
    "Vector3(prey_pos.x, 0.0, prey_pos.y)",
    "Vector3(prey_pos.x, 0.0, prey_pos.z)",
  )

  # --- Predator immediate cardinal blocked: accept Vector3 direction ---
  t = t.replace(
    "  direction: Vector2,\n",
    "  direction: Vector3,\n",
    1,
  )

  # --- Predator obstructed hunt ---
  t = t.replace(
    "  var flank_u := Vector2(-prey_u.y, prey_u.x) if prey_u.length_squared() > 1e-12 else Vector3.ZERO\n",
    "  var flank_u := Vector3(-prey_u.z, 0.0, prey_u.x) if prey_u.length_squared() > 1e-12 else Vector3.ZERO\n",
  )
  t = t.replace(
    "    var c: Vector2 = hunt_dirs[(hunt_phase + k) % hunt_dirs.size()]\n",
    "    var c: Vector3 = hunt_dirs[(hunt_phase + k) % hunt_dirs.size()]\n",
  )
  t = t.replace(
    "      or probe.y - he.y < bounds_min.y\n"
    "      or probe.y + he.y > bounds_max.y\n",
    "      or probe.z - he.y < bounds_min.y\n"
    "      or probe.z + he.y > bounds_max.y\n",
  )
  t = t.replace(
    "  return _snap_seek_direction(Vector2(rot3.x, rot3.z))\n",
    "  return rot3\n",
  )
  t = t.replace(
    ") -> Vector2:\n"
    "  var lock_ticks := maxi(4, int(motor_p.get(\"predator_obstructed_hunt_lock_ticks\", 10)))\n",
    ") -> Vector3:\n"
    "  var lock_ticks := maxi(4, int(motor_p.get(\"predator_obstructed_hunt_lock_ticks\", 10)))\n",
  )

  # --- Predator edge chase cardinal type ---
  t = t.replace(
    "    var c: Vector2 = chase_dirs[(body_id + k + _physics_ticks) % chase_dirs.size()]\n",
    "    var c: Vector3 = chase_dirs[(body_id + k + _physics_ticks) % chase_dirs.size()]\n",
  )

  # --- Physics loop ---
  t = t.replace(
    "      var pred_pos2 := Vector2(pred_pos.x, pred_pos.z)\n",
    "",
  )
  t = t.replace(
    "      var prev_stuck_sample: Vector2 = _motor_stuck_last_pos.get(body_id, pred_pos2) as Vector2\n",
    "      var prev_stuck_sample: Vector3 = _as_motor_vec3(_motor_stuck_last_pos.get(body_id, pred_pos))\n",
  )
  t = t.replace(
    "          raw_intent = _motor_plane_v3(_predator_latched_memory_chase_intent(\n"
    "            body_id,\n"
    "            pred_pos2,\n"
    "            _motor_plane_v2(mem_tgt),\n",
    "          raw_intent = _predator_latched_memory_chase_intent(\n"
    "            body_id,\n"
    "            pred_pos,\n"
    "            mem_tgt,\n",
  )
  t = t.replace(
    "          raw_intent = _motor_plane_v3(_predator_latched_obstructed_hunt_intent(\n"
    "            body_id,\n"
    "            pred_pos2,\n"
    "            _motor_plane_v2(prey_blk),\n",
    "          raw_intent = _predator_latched_obstructed_hunt_intent(\n"
    "            body_id,\n"
    "            pred_pos,\n"
    "            prey_blk,\n",
  )
  t = t.replace(
    "            raw_intent = Vector2(hunt_rot3.x, hunt_rot3.z)\n",
    "            raw_intent = hunt_rot3\n",
  )

  # Flee panic block
  t = t.replace(
    "        var flee_threat := _nearest_position_from_dict_mobs(\n"
    "          ctx[\"creature_position\"] as Vector2, ctx.get(\"mobs\", []) as Array\n"
    "        )\n",
    "        var flee_threat := _nearest_position_from_dict_mobs(\n"
    "          pred_pos, ctx.get(\"mobs\", []) as Array\n"
    "        )\n",
  )
  t = t.replace(
    "          var flee_samples_raw: Variant = ctx.get(\"aware_obstacle_samples\", PackedVector2Array())\n"
    "          var flee_samples := (\n"
    "            flee_samples_raw as PackedVector2Array\n"
    "            if flee_samples_raw is PackedVector2Array\n"
    "            else PackedVector2Array()\n"
    "          )\n",
    "          var flee_samples_raw: Variant = ctx.get(\"aware_obstacle_samples\", PackedVector3Array())\n"
    "          var flee_samples := (\n"
    "            flee_samples_raw as PackedVector3Array\n"
    "            if flee_samples_raw is PackedVector3Array\n"
    "            else PackedVector3Array()\n"
    "          )\n",
  )
  t = t.replace(
    "          raw_intent = _herbivore_locked_flee_intent(\n"
    "            body_id,\n"
    "            ctx[\"creature_position\"] as Vector2,\n"
    "            flee_threat,\n",
    "          raw_intent = _herbivore_locked_flee_intent(\n"
    "            body_id,\n"
    "            pred_pos,\n"
    "            flee_threat,\n",
  )

  # food_pull Vector3
  t = t.replace("        var food_pull := Vector2.ZERO\n", "        var food_pull := Vector3.ZERO\n")
  t = t.replace("        var food_pull_pinch := Vector2.ZERO\n", "        var food_pull_pinch := Vector3.ZERO\n")
  t = t.replace("        var food_pull_corner := Vector2.ZERO\n", "        var food_pull_corner := Vector3.ZERO\n")

  # scan_intent / break_dir Vector3
  t = t.replace(
    "          elif scan_intent.length_squared() > 1e-12:\n"
    "            raw_intent = scan_intent\n",
    "          elif scan_intent.length_squared() > 1e-12:\n"
    "            raw_intent = _motor_plane_v3(scan_intent)\n",
  )
  t = t.replace(
    "          var break_dir := _snap_seek_direction(break_pos - pred_pos)\n",
    "          var break_dir := _snap_seek_direction_v3(break_pos - pred_pos)\n",
  )
  t = t.replace(
    "                raw_intent = away_snap\n",
    "                raw_intent = _motor_plane_v3(away_snap)\n",
    1,
  )

  # Jeopardy forced turn Vector3
  t = t.replace(
    "          ) as Vector2\n"
    "          jeopardy_forced = true\n",
    "          ) as Vector3\n"
    "          jeopardy_forced = true\n",
    1,
  )

  # Wall slide center: pred_pos.z
  t = t.replace(
    "              (bmin.y + bmax.y) * 0.5 - pred_pos.y\n",
    "              (bmin.y + bmax.y) * 0.5 - pred_pos.z\n",
  )

  # Facing shim for Vector3 turn_face in rescan
  t = t.replace(
    "          _apply_creature_facing_for_awareness(subj, turn_face)\n",
    "          _apply_creature_facing_for_awareness(subj, Vector2(turn_face.x, turn_face.z))\n",
  )
  t = t.replace(
    "          if _rescan_and_patch_goal_ctx(subj, motor_p, ctx, turn_face):\n",
    "          if _rescan_and_patch_goal_ctx(subj, motor_p, ctx, Vector2(turn_face.x, turn_face.z)):\n",
  )

  TARGET.write_text(t, encoding="utf-8")
  print(f"Updated {TARGET}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
