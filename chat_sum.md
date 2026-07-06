# Handoff Context

**System State:** Branch `Goal_Movement_RefactorV3`; **uncommitted** changes across motor stack, AI driver, pack JSONs, tests, and `Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md`. V3 motor architecture is spec-complete for refactor: three-phase tick pipeline `sync_step_objective` → `resolve_path_to_step_goal` (§3.1) → `align_and_move` (§7.3.0). Shipped code still uses legacy `motor_planner.gd` monolith with `turn_commit_sign` hysteresis; headless tests passed after V2 cruft cleanup but **not** re-run after latest doc-only edits. Key files: `motor_planner.gd` (~1056 LOC), `motor_plane.gd`, `creature_motor_stack.gd`, `CREATURE_MOVEMENT_V3.md` (~2340 lines).

**Progress Made:**
- V2 cruft cleanup landed (uncommitted): orphan pack keys removed (fox/rabbit), `ai_driver._goal_belief_by_body` retired, cardinal probe injection removed from `motor_plane.gd`, dead merge APIs deleted, `goal_belief_memory` cap eviction fixed; headless tests green at that point.
- `CREATURE_MOVEMENT_V3.md` design closed **2026-07-06**: per-objective consideration timer; clearance on consideration cadence + blocked-outcome immediate recheck; substep-complete reeval = **full hub re-score**; no max-interval cap; single-winner model; **retire `turn_commit_sign`** — pure cone + fewest-turn pick every tick; `boundary_scan_sign` only for rim scan.
- Telemetry/Flight answers promoted: HUD `cmt` = prior tick `Action` (L/R/0); delete `turn_commit_sign` from state/snapshot entirely; Flight turn flutter acceptable v1 (playtest revisit if paralysis).
- §15.3 refactor gate **closed** — `motor_planner` split unblocked. Two non-blocking open <<Question>> rows remain (§7.7): `last_action` vs end-of-tick `cmt` wiring; test migration PR sequencing.

**Last Known Trajectory:** Doc-only pass promoting user `<<Answer>>` blocks and closing §15.3 design gates. **Next:** implement `motor_planner.gd` refactor per §3/§7.3.0 (cone-only `align_and_move`, delete commit state, update `motor_planner_explore_log` + ~16 `turn_commit_sign` test refs). Optional: git commit branch work; fox NE-corner duel smoke not re-run this session.
