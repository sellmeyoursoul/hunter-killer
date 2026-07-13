# Handoff Context

**System State:** `Goal_Movement_RefactorV3` branch. Slice `post-6d-approach-geometry` **Passes 1–4 shipped** in `motor_planner.gd` / `creature_motor_stack.gd` / `game_config_merge.gd` / `tests/run_all.gd` + `MotorPathFixture.build_pursuit_pinch`. Hub: [CREATURE_MOVEMENT_V3_CLEANUP.md](Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md). **C3** (prey contact without EAT) documented as `design`/`open`, slice `post-6d-prey-eat-contact` — **not** implemented. Headless suite may still show unrelated `memory_adapter` `slot >= slot_max` failures on Steam Godot 4.7; Pass 1–4 asserts themselves were green in targeted runs.

**Progress Made:**
- **Pass 1:** overshoot guard (`step_ultimate_pos`, `approach_overshoot_guard_move_steps`=2), material turn-first; fox continuous-live remint exempt; `_test_motor_live_pursuit_no_turn_storm_smoke`.
- **Pass 2:** `locale_no_progress_ticks` → §9 (locale not in `_is_latched_step_source`).
- **Pass 3:** C1 `pursuit_detour_waypoint` latch (16 ticks) + stack §9 short-circuit while live prey visible; `_test_motor_pursuit_pinch_detour_smoke`.
- **Pass 4:** C2 live↔locale handoff (same kind→live; else calories-per-EAT on re-derive) + locale arrival bind/clear; tests `_test_motor_planner_live_locale_handoff_*`, `_test_motor_planner_locale_arrival_binds_live_or_clears`.
- **C3 logged:** duel ~t=3188 — zero `act=EAT`, fox `MOVE_F blk=1` pin loop; kill is V3 EAT only (`MobHitbox` inert); `_can_eat_now` dist vs `step_goal` suspect.

**Last Known Trajectory:** Passes 1–4 complete. **Next:** Pass 5 duel manual sign-off (rabbit locale patch + fox obstacle chase). After that (or in parallel): design/implement **C3** `post-6d-prey-eat-contact` — likely measure `_can_eat_now` to ultimate/prey pos and/or force EAT bind on blocked contact in eat range.
