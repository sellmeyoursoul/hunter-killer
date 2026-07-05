# Handoff Context

**System State:** Branch `Goal_Movement_RefactorV3`, **uncommitted** working tree. V3 ENGINE motor on per-root `creature_motor_stack` + `motor_planner.gd`. Duel explore debug log: `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` (400-line cap). **Headless:** `godot --path . --headless -s res://tests/run_all.gd` exits **0** (incl. new rim explore tests). **Doc authority:** implement from `Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md` §7.3 / §7.7; `Definitive_Features/CREATURE_MOVEMENT.md` = legacy 2D inventory + links only.

**Active files:**
- `creature/motor/motor_planner.gd` — explore latch, boundary scan, post-scan egress, turn commit, rim escape replan, `_apply_explore_stuck_or_rim_replan`, rim-aware waypoint mint
- `creature/motor/motor_planner_explore_log.gd`, `motor_planner_debug_hud.gd`, `creature_motor_stack.gd`
- `tests/run_all.gd` — `_test_motor_planner_explore_*` suite (latch, egress, rim waypoint/overshoot/replan, post-scan flip-flop, etc.)
- `assets/plants/bush_food_3d.gd` — `_OLogSafe` for headless parse
- `Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md` — §7.3 rim/explore contracts + §7.7 debug; §12.2 6c test row
- `Project_Docs/Definitive_Features/CREATURE_MOVEMENT.md` — banner → V3; §10 pointer only (no duplicated V3 prose)
- `Project_Docs/PROJECT_DOC_INDEX.md`, `.cursor/rules/project-docs.mdc`, `.cursor/agents/creature-motor.md` — V3 vs definitive routing

**Progress Made:**
- **Fix 3a–c (Fox NE-corner rim spin):** Rim waypoint mint uses `_rim_escape_explore_dir`; rim overshoot / dead-end / `_apply_explore_stuck_or_rim_replan` route to `_apply_explore_rim_escape_replan` (not 60° interior rotate); rim replan seeds `turn_commit_sign` via `_seed_inward_align_turn_commit`
- **Fix 1–2 (prior in branch):** Post-scan `boundary_scan_egress_ticks`; `_end_boundary_scan` seeds inward `explore_dir` + turn commit; post-scan L/R flip fix via shorter-arc commit
- **Partial rim egress:** `_rim_egress_move_cleared()` — egress clears on `MOVE_F` only when not `_is_at_playfield_rim`
- **Headless OLog:** `bush_food_3d.gd` → `olog_safe.gd`; `logging.mdc` headless convention
- **Tests added:** `_test_motor_planner_explore_rim_waypoint_mints_inward`, `_test_motor_planner_explore_rim_overshoot_replans_inward`, `_test_motor_planner_explore_rim_stuck_replan_seeds_commit` (+ prior egress / flip-flop / boundary-scan tests)
- **Doc realignment:** V3 is implementation source of truth; definitive movement doc deduped; index + project-docs + creature-motor agent updated

**Last Known Trajectory:** Doc authority fix completed (V3 vs definitive). **Next:** duel smoke — confirm Fox breaks rim turn-only / NE-corner `explore_replan` flip loop with Fix 3 in runtime logs. **Separate queue:** Rabbit seek `tgt=(0,0)` / `_seed_explore_after_seek` runtime path (Fix 3 Rabbit); optional explore log fields (`egress=`, `explore_dir` in `motor_planner_explore_log.gd`). Commit when ready. **6d.3** still blocked until duel explore locomotion validated in play.
