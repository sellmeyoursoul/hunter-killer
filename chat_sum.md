# Handoff Context

**System State:** `Goal_Movement_RefactorV3` branch. **post-6d P2–P4 shipped** (flee waypoint latch, flight entry telemetry reset, headless A/B/C green). Duel playtest **2026-07-10:** rabbit close-range Flight egress OK; **fox pursuit stalls** on rock-blocked path to live prey (`MOVE_F` + `blk=1` loop, no `TURN_*`, §9 `seek` → explore `tgt=(0,0)` tick). Not a Flight regression — carnivore contact-geometry gap. New cleanup hub: [CREATURE_MOVEMENT_V3_CLEANUP.md](Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md) (linked from V3 §intro + §3 fixture table + [PROJECT_DOC_INDEX.md](Project_Docs/PROJECT_DOC_INDEX.md)). **C1** documented (`design`); L1 `pursuit_pinch` fixture + headless smoke spec written but **not implemented**. `motor_path_fixture.gd` still only `open` / `blocked`.

**Progress Made:**
- **P2–P4:** Flee waypoint latch (`flee_waypoint`, `flee_waypoint_latch_ticks`=16), stack `flight_just_entered` / exit clear, P3 telemetry reset, flight tests A/B/C in [`tests/run_all.gd`](tests/run_all.gd); config in [`game_config_merge.gd`](AI_int_lib/game_config_merge.gd).
- **Playtest diagnosis:** Fox stall signature in `motor_explore_tick.log` (~t=3292+); prey engagement + `find_food` live correct; blocked reeval misaligns `step_goal` without turn-first recovery.
- **C1 design:** Gate §9 seek during live prey latch; pursuit detour substep latch (flee/explore pattern); align-after-reeval. Slice tag: `post-6d-pursuit-contact`.
- **Docs:** Created [`CREATURE_MOVEMENT_V3_CLEANUP.md`](Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md) with C1 + layered smoke plan (L0 fixture / L1 pursuit_pinch CI / L2 duel manual).

**Last Known Trajectory:** Cleanup doc and pursuit smoke **design** complete. **Next:** (1) scaffold red L1 test — `build_pursuit_pinch()` + `_test_motor_pursuit_pinch_detour_smoke`; (2) implement C1 fix; (3) duel manual smoke sign-off (rabbit + fox hunt).
