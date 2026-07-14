# Handoff Context

**System State:** `Goal_Movement_RefactorV3` branch. Hub: [CREATURE_MOVEMENT_V3_CLEANUP.md](Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md). **Passes 1–4** shipped (`post-6d-approach-geometry`) in `motor_planner.gd`, `creature_motor_stack.gd`, `game_config_merge.gd`, `tests/run_all.gd`, `MotorPathFixture.build_pursuit_pinch`. **C3** shipped (`post-6d-prey-eat-contact`): `_can_eat_now` → ultimate + `eat_action_max_distance` **5 m** + `eat_facing_arc_deg` **90** + orbit break (`eat_orbit_break_revolutions`=3); headless + duel signed off (`predation_carn_win`, fox `act=EAT` t=3549). **C2 residual** shipped: overshoot remint **retains** `locale_no_progress_ticks` / `precise_no_progress_ticks` (supersedes 2026-07-13 reset). **EAT range:** move-steps reverted — `eat_range_move_steps` removed; meters only. **Playfield:** `main_3d.gd` interior boulders **18** (Pass 5 obstacle density). **C1** back to `in_progress` — Pass 3 detour latch (16 ticks) shipped but duel pinch residual persists; locked follow-up plan in CLEANUP. **Pass 5** duel manual **not done**. Headless full suite may still exit non-zero on unrelated asserts (`memory_adapter`, etc.).

**Progress Made:**
- **Pass 5 log review:** early runs failed (no locale/C1 scenarios); later runs showed C2 locale spin `(26,78)`, C3 orbit, C1 pinch — Pass 5 not signed off.
- **C3 shipped:** ultimate-distance EAT, facing arc, orbit `MOVE_BACKWARD`; tests `_test_motor_planner_eat_uses_ultimate_not_step_goal`, `_test_motor_planner_eat_orbit_break_after_revolutions`; duel `predation_carn_win` signed off.
- **C2 residual shipped:** `_maybe_apply_fixed_objective_overshoot` no longer resets locale/precise progress; `_test_motor_planner_overshoot_retains_locale_no_progress`.
- **EAT range restored to 5 m** (`eat_action_max_distance`); speed-scaled move-steps deferred.
- **Interior boulders:** +12 fracs in `_spawn_interior_boulders()` (18 total).
- **C1 residual plan locked (doc):** sticky `pursuit_detour_waypoint` vs live remint; no per-block remint; fresh detour on persistent block; latch **32** initial (tunable 48); §9 gate preserved; pass/reopen deferred.

**Last Known Trajectory:** Documented C1 residual follow-up in CLEANUP (sticky detour vs live remint + latch 32). **Next:** implement C1 residual in `motor_planner.gd` / config / tests, then re-run Pass 5 duel (rabbit locale + fox obstacle chase). C2 locale spin may need verify after overshoot-retain fix. Open-field fox trail-without-EAT (6–8 m gap) is separate from C1 pinch — do not widen EAT again without design lock.
