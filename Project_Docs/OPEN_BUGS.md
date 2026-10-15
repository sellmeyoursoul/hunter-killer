# Open bugs register

> **Purpose:** content-dense register of **unresolved bugs** (`open`, `in_progress`, `pending_recurrence`) across the active project docs. Enough detail that new data adds to the picture and nobody re-runs a dead end. **Not a debug diary:** the messy history stays in the source feature doc, which keeps a one-line pointer back here.
>
> **Status vocabulary:** [Project_Docs/CLAUDE.md](CLAUDE.md) (`open`, `in_progress`, `pending_recurrence`; `done` / `wont_fix` entries are **removed** from this file and their final status stays in the source doc). `watch` items stay in their source docs. **Unbuilt features are not bugs** — they belong to their feature plan or [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md).
>
> **Scope field (every entry):** `V3` = belongs to, or blocks closing, the current Creature Movement V3 project (see the Active development list in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)). `outside-V3` = not V3 scope, **must be addressed eventually** (it does not gate V3 close-out, but it is not dropped).
>
> **Tier:** root / tracking (see [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)); not a feature plan and not a contract. Rules for maintainers: [Project_Docs/CLAUDE.md](CLAUDE.md) "Bug register (OPEN_BUGS.md)".
>
> **Last full sweep:** 2026-10-15 (CBD-1 scripted audit results added; other entries last swept 2026-10-14).

---

## ID convention

`<DOC_ACRONYM>-<n>`: the acronym derives from the **source doc's filename** (registry below); `<n>` is the number the source doc already uses (`C9` -> `CMV3C-9`, `RT4` -> `CMV3R-4`). **Numbers are never reused.** A bug first logged with no source-doc number gets the prefix of the doc its pointer lives in and the next unused number for that prefix. **Register a new prefix here before using it.**

### Prefix registry

| Prefix | Source doc | Source-doc numbering | Next unused |
|--------|------------|----------------------|-------------|
| `CMV3C` | [CREATURE_MOVEMENT_V3_CLEANUP.md](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md) | `C#` (C1-C24 exist; 25-29 and 30-32 were assigned here without a C section) | 33 |
| `CMV3R` | [CREATURE_MOVEMENT_V3_RANDOMTESTS.md](Draft_Features/CREATURE_MOVEMENT_V3_RANDOMTESTS.md) | `RT#` (RT4 is a feature slice, not a bug; see its section) | 5 |
| `CMV3D` | [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) | none: findings are unnumbered prose, so IDs are sequential | 3 |
| `CMV3` | [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) (hub; reserved) | — | 1 |
| `CMV3MM` | [CM_V3_MULTI_MOBS.md](Draft_Features/CM_V3_MULTI_MOBS.md) (reserved) | — | 1 |
| `PSQ` | [PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) | decision numbers (PSQ-1 had none: sequential; source decisions 46 E / 33; PSQ-1 is `done` 2026-10-15, number not reused) | 2 |
| `NAV` | [NAVIGATION_PASSABILITY_PLAN.md](Draft_Features/NAVIGATION_PASSABILITY_PLAN.md) (reserved) | — | 1 |
| `CBD` | [CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md) (reserved) | — | 2 |
| `CGD` | [CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) (reserved) | — | 1 |
| `CMEM` | [CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) (reserved) | — | 1 |
| `EBP` | [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) (pointer lives in the backlog row) | none: backlog rows are unnumbered, IDs are sequential | 4 |
| `PDI` | [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) (doc-hygiene items only) | none, sequential | 2 |

---

## Summary

| ID | Status | Scope | Owner | One line |
|----|--------|-------|-------|----------|
| [CMV3C-7](#cmv3c-7) | `pending_recurrence` | V3 | test-harness | Flaky `_test_creature_motor_stack_memory_tier_precedence` asserts; not reproduced in 39 runs |
| [CMV3C-9](#cmv3c-9) | `in_progress` | V3 | creature-motor | Flee remint-repeat at playfield edge: planner re-mints the same waypoint pair; trips the C9 invariant ~1-4 in 60 test runs (reopened after DESIGNREVIEW closed it) |
| [CMV3C-10](#cmv3c-10) | `in_progress` | V3 | creature-entity | C10 airborne / under-the-geography invariant: reopened; recurring in the C9 edge test (instances: CMV3C-28) |
| [CMV3C-25](#cmv3c-25) | `pending_recurrence` | V3 | creature-entity | West-edge pinned body: x frozen at -98.02 while velocity.x ramps to +2.93 (ticks 117-141) |
| [CMV3C-26](#cmv3c-26) | `open` | V3 | creature-entity | Rabbit ends up on unwalkable ground in a west-edge notch (x ~ -95, z 0..2.5), ~2 in 70 test runs |
| [CMV3C-27](#cmv3c-27) | `open` | V3 | environment-world | Corner scenario of `test_c9_flee_edge_pingpong.gd` falls deterministically at tick 35 near (-95,-93) |
| [CMV3C-28](#cmv3c-28) | `open` | V3 | creature-entity | Instances of CMV3C-10: airborne-invariant trips for rabbit/fox/wolf in the C9 edge test; falling bodies, not flee |
| [CMV3C-29](#cmv3c-29) | `open` | V3 | creature-motor | Silent-stall `MOTOR_INVARIANT` for a rabbit near (90.5, 81.9), seen once in a nav-cost run; uninvestigated |
| [CMV3D-1](#cmv3d-1) | `open` | V3 | creature-motor (tentative) | `is_on_floor=false` at spawn warning for both creatures on the C9 rig; recurrence not confirmed |
| [CMV3D-2](#cmv3d-2) | `open` | V3 | creature-motor (tentative) | Explore walks the whole way to a wall: explore waypoints minted well past the playfield boundary; recurrence not confirmed |
| [EBP-1](#ebp-1) | `open` | outside-V3 | assets-pack | `open_shrub_3d` depleted visual appears to jump position after being eaten |
| [EBP-2](#ebp-2) | `open` | outside-V3 | environment-world | `mesh_local_bottom_y` / `snap_prop_root_to_ground` measure in root-local units; a scaled prop sinks |

Tech debt / doc hygiene items (not bugs) are in [their own section](#tech-debt--doc-hygiene) below: CMV3C-30, CMV3C-31, CMV3C-32, CBD-1.

---

## Entries

### CMV3C-7

- **Status:** `pending_recurrence` | **Scope:** V3 | **Owner:** test-harness | **Updated:** 2026-08-07 (no change since) | **Source:** [CLEANUP C7](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c7-flaky-headless-assertions-nondeterministic-across-identical-runs)
- **Symptom:** `_test_creature_motor_stack_memory_tier_precedence` asserts "coarse beats locale when precise absent" and "locale consult when no instance beliefs" intermittently fail on identical code (about 1 in 6 separate-process runs, 2026-07-15).
- **Repro:** `godot --path . --headless -s res://tests/run_all.gd`, separate process per run. 39 consecutive runs after C8: 0 failures (historical rate ~1/6; `(5/6)^39` ~ 0.1%).
- **Ruled out:** Jolt substep timing and C4 ObjectDB noise (for the sibling replay-fixture flake, which was root-caused and fixed: collider-registration race, fixed by awaiting two `physics_frame` cycles); leftover geometry from the adjacent predecessor test (30-iteration in-process loop, 0 divergence).
- **Leading hypothesis:** incidentally resolved by C8 frame-yield/timing fixes. No mechanism identified.
- **Next step:** none until a fresh divergence appears. Not investable time. Single-run headless diffs remain untrustworthy for other tests until a scripted multi-run check exists.

### CMV3C-9

- **Status:** `in_progress` (was `pending_recurrence` 2026-10-13) | **Scope:** V3 | **Owner:** creature-motor | **Updated:** 2026-10-14 | **Source:** [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge)
- **Symptom:** a fleeing rabbit at the playfield edge re-mints `flee_waypoint` at (nearly) the same points while the body barely moves; trips the fail-fast invariant "flee_waypoint remint repeated a recent remint (boundary ping-pong, C9)" (`creature/motor/creature_motor_stack.gd` ~line 521).
- **Repro:** `godot --path . --headless -s res://tests/test_c9_flee_edge_pingpong.gd` (standalone; not in `run_all.gd`). Passes ~93% (56/60 on 2026-10-14). Remint-repeat trip rate: 2/60 pre-fix (walkable-clamp fix, 2026-10-13), ~1-4/60 post-fix.
  - 2026-10-13 trip (batch run 27): printed scenario label was `minus_x_edge`'s successor; body position indicates a `plus_z_edge` start ~(0,95). Tick 98, `flee_waypoint` (-3.96, 11.36, 90.17), body (1.74, 12.56, 95.43), 2 history entries. Body y 12.56 still unexplained (tracked as [CMV3C-32](#cmv3c-32)).
  - 2026-10-14 loop of 60: 4 failures: two C9 trips in `minus_x_minus_z_corner` (runs 27 and 34), one silent-stall invariant at the minus-x edge (z ~ 44.7, tick 148), one "rabbit left walkable terrain" at the minus-x edge.
  - Instrumented run: body blocked ticks 99-147 at x = -98.02; planner alternated between a south waypoint set (-93.46, -95.6) and a north set near (-84, -71). The south point was minted at tick 115 and again at 150 with the body 1.3 m from its earlier position. Re-mint gaps (ticks): 6, 17, 17, 17, 6, 6, 17, 12 = 5-tick give-up latch + 1 and 16-tick flee latch + 1.
- **Ruled out:** (H1) stale invariant/belief state across per-attempt re-placement: `new_game()` (`main_3d.gd:228-247`) rebuilds creatures and motor stacks each attempt; "tick 98" is the fresh stack's tick count. (H2) waypoint/position history desync: `creature_motor_stack.gd` clears together (528-529), appends together (556-557), pops together (559-560). The 3.0 m position comparison is therefore behaving as designed.
- **Leading hypothesis (supported):** genuine oscillation at an edge. In `motor_planner.gd`, hysteresis already exists in the scored flee sweep (incumbent candidate x1.25 via `flee_incumbent_bearing_bonus`, ~3820-3821; recent-mint backtrack-filter exemption 3833-3839; `flee_recent_dirs` 3 entries / 45 ticks; `flee_bearing_smoothing` 4310-4318). The **give-up escalation** (`final_reach < 0.35 * flee_dist`, 16-direction sweep, ~3870-3920) ranks purely by raw reach (strict `>`), ignoring the incumbent bonus, race/separation terms and backtrack history, so near-tied reaches flip on small position changes. There is no re-mint cooldown and no position memory of recent mints (history holds directions only). `apply_immediate_blocked_path_reevaluation` (~4645-4660) can also overwrite `flee_waypoint` with a +60 deg rotated point after 3 backtrack-deflect ticks.
- **Unexplained observation:** the trace showed `blocked: true` every pinned tick although `is_on_wall()` was false in all instrumented samples. Verified semantics: `locomotion_executor.gd:184-190, 203-217` needs net progress <= 0.001, `is_on_wall()`, and wall normal opposing intent by > 0.15; `boundary_stuck` (`motor_planner.gd:1001-1002`) fires on any tick `clamp_playfield_position` adjusted XZ, with no speed threshold; `consecutive_blocked` counter at 1100-1101. Possibly the clamp-adjust path (see [CMV3C-25](#cmv3c-25)).
- **Next step (diagnostic):** log `flee_pick_kind` per mint. The instrumented trace lacked it. Verified 2026-10-14: it is a planner state key (`motor_planner.gd` `flee_pick_kind`, set at ~3989; values `open` / `incumbent` / `shelter` / `choke` / `locale` / `giveup` / `boxed`) emitted as the ` fk=<kind>` suffix **on `gk=avoid_hostiles` explore-log lines only** (documented in the telemetry table of [CREATURE_MOVEMENT_V3.md §12.2](Draft_Features/CREATURE_MOVEMENT_V3.md), not §7). So a trace taken without the explore log enabled, or outside `avoid_hostiles` lines, will not show it; the `giveup` value is the one that discriminates the leading hypothesis.
- **Candidate fix (NOT applied, undecided):** margin hysteresis inside the give-up sweep: keep the prior bearing unless a challenger's reach exceeds it by ~15% of `flee_dist`; skip endpoints near recently minted positions; gate on the fox actually threatening along the held bearing. Weaker alternative: penalize the far side of the blocked body (does not touch the give-up path).
- **Regression-test sketch:** scenario in `tests/test_c9_flee_edge_pingpong.gd` with the rabbit at the pinned position and the fox opposite, 200 ticks; assert no two mints more than 10 ticks apart within 2 m of one point while the body moved < 3 m.
- **Closure history / policy:** [DESIGNREVIEW §1](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) (2026-08-28) recorded a user decision to close C9 rather than chase repro counts. **That closure was reopened** (user, 2026-10-14: it was reopened after the team thought it was fixed); C9 is `in_progress` and tracked here as CMV3C-9, because run 27 is a new real trip with a next step. The original DESIGNREVIEW history is kept in place with a pointer.

### CMV3C-10

- **Status:** `in_progress` (reopened 2026-10-14 by maintainer; the source doc previously logged the non-vocabulary `fixed`) | **Scope:** V3 | **Owner:** creature-entity (the original fixes touched creature templates and obstacle collision) | **Updated:** 2026-10-14 | **Source:** [CLEANUP C10](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c10-fox-ends-up-under-the-geography-after-close-contact-with-prey-new-2026-08-05)
- **Symptom:** a creature ends up under / inside the geography or airborne, tripping the fail-fast airborne / off-floor invariant ("airborne/off-floor for 45+ ticks (stuck-under-geometry, C10)", `creature_motor_stack.gd` `_trip_invariant`; the threshold is terrain-scaled via `FallPhysics`, PHYSICS_SQUEEZE decision 30). The original report was a fox under the terrain after close contact with prey (contact disproven as the cause).
- **Repro:** recurring in `tests/test_c9_flee_edge_pingpong.gd` (instances and rates: [CMV3C-28](#cmv3c-28)); historically 1/6 `smoke_ai_player.gd` runs (2026-08-07, fox, tick 731).
- **Ruled out (history):** terrain-mesh seam / hole and `floor_max_angle` rejection (raycast-grid probes, 25.6-30.2 deg continuous slope); boulder proximity for the terrain-only trips. Fixed causes: boulder-seam tunnelling (convex hulls for obstacle props, 2026-08-06); thin `safe_margin` (0.001 -> 0.06 -> 0.15, 2026-08-06/07); boulder climb-then-fall (additive climb-guard cylinder, 2026-09-05); flat 45-tick threshold on a real cliff fall (terrain-scaled, 2026-09-21).
- **Leading hypothesis:** none for the current instances; the old fixes were verified on favourable samples (10/10 twice) and the family has recurred each time. Check overlap with [CMV3C-27](#cmv3c-27) (deterministic corner fall) first.
- **Next step:** work the instances under CMV3C-28; the full 2026-08 history stays in the source doc. Merge decision: kept separate from CMV3C-28 (this is the family and its fix history; CMV3C-28 is the current instance set with its own repro command); cross-linked both ways.

### CMV3C-25

- **Status:** `pending_recurrence` | **Scope:** V3 | **Owner:** creature-entity (kinematic body / walkable clamp); hand to creature-motor if the pre-clamp x is already west of -98.05 | **Updated:** 2026-10-14 | **Source:** pointer in [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) (no standalone C25 section)
- **Symptom:** at x = -98.019 / -98.02367, z ~ -87.4, ticks 117-141 of a corner-scenario run: `velocity.x` ramps +0.4/tick to +2.93 while position x does not change and z moves only 0.01-0.05/tick; y alternates ~0.000 / 0.13 (suggests depenetration or floor-snap each tick).
- **Repro:** not reproduced in 4 instrumented corner-test runs (those were at z ~ -79). Layout is locked (`game_config.json` `playfield_spawn.seed` 0, `locked_layout_path` `res://spawn_layout_cornered_wall_repro.json`), so the layout is not the variable.
- **Ruled out (code + probe):** walkable-mask notch / sliver / non-convexity (clean vertical edge at x >= -98.0, margins 0 and 0.385); clamp rejecting +x steps (`clamp_to_walkable` returns small +x steps unchanged); stale `_last_walkable_xz` (always the previous accepted point; `creature_kinematic_body_3d.gd:879-897`); physics walls (no ray hits, `test_move` not blocked for x in [-99.8, -95]); randomized layout.
- **Clamp facts:** `is_walkable` (`playfield_ground_sampler.gd:302-313`) tests centre + 8 ring points at margin + half-cell = 0.385 + 1.5625 = 1.9475 m, so the west limit is x >= -98.0525. Trim only removes velocity along the removed direction, so `vx` stays positive when x is pulled back.
- **Leading hypothesis:** none confirmed. Candidates: (a) `move_and_slide` / depenetration pushes the body west past the limit and the clamp pulls it back every tick; (b) another writer resets position.
- **Next step if it recurs:** temporary logging in `_clamp_playfield_position` (pre-clamp pos, `clamped_world`, velocity before/after trim, `is_on_wall`, slide collisions, `_last_walkable_xz`) and pre/post `move_and_slide` position in `apply_horizontal_move_intent` (~line 783). Pre-clamp x already west of -98.05 -> `move_and_slide`/depenetration (creature-motor / physics settings). Pre == post and still pinned -> another writer. Probe scripts from the 2026-10-14 session are gone.

### CMV3C-26

- **Status:** `open` | **Scope:** V3 | **Owner:** creature-entity | **Updated:** 2026-10-13 | **Source:** pointer in [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) checklist ("NEW open item (2026-10-13)")
- **Symptom:** the rabbit ends up on unwalkable ground in a notch of the west edge near x ~ -95, z 0..2.5 (`is_walkable` false at margin 0 for x up to ~ -94.5; terrain elevation ~ -3.9 there, a drop). No bad flee waypoint, so the body slid or was pushed past the `walkable_sampler` clamp.
- **Repro:** about 2 of 70 runs of `tests/test_c9_flee_edge_pingpong.gd`.
- **Ruled out:** bad flee waypoints (none in ~85+ runs after the walkable-clamp fix).
- **Leading hypothesis:** none; cause not yet read in body code. Possibly the same mechanism as [CMV3C-25](#cmv3c-25) (west edge, body beyond the clamp); location differs (z ~ 0..2.5 vs ~ -87), and CMV3C-25's probe ruled out a mask notch only at x >= -98. Kept separate from CMV3C-25 (maintainer decision 2026-10-14).
- **Next step:** read `creature_kinematic_body_3d.gd` clamp path against this location.

### CMV3C-27

- **Status:** `open` | **Scope:** V3 | **Owner:** environment-world (placement / terrain) | **Updated:** 2026-10-14 | **Source:** pointer in [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) checklist (residual item, "Corner scenario")
- **Symptom:** in the corner scenario the body falls (C10-like) at tick 35, deterministically, near (-94..-96.6, y -3.64, z -93.2..-93.8), at all standoffs.
- **Repro:** `tests/test_c9_flee_edge_pingpong.gd`, corner scenario, every run.
- **Ruled out:** nothing tested. Not yet investigated.
- **Leading hypothesis:** placement / terrain (spawn point over a drop or unsupported terrain).

### CMV3C-28

- **Status:** `open` | **Scope:** V3 | **Owner:** creature-entity | **Updated:** 2026-10-14 | **Source:** [CLEANUP C10](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c10-fox-ends-up-under-the-geography-after-close-contact-with-prey-new-2026-08-05) (family, tracked as [CMV3C-10](#cmv3c-10)) and the C9 residual checklist item
- **Symptom:** the instances of CMV3C-10: rabbit / fox / wolf trip the airborne / off-floor invariant in `test_c9_flee_edge_pingpong.gd` runs (falling bodies, pos y 8.9, 12, -13.7). Not flee-related.
- **Repro:** among the ~6 failures in 50 earlier untightened `test_c9_flee_edge_pingpong.gd` runs (mixed with the west-edge notch leak); also 1/6 `smoke_ai_player.gd` runs on 2026-08-07 (fox at tick 731). Current rate in the tightened test not recorded.
- **Ruled out:** nothing tested for these trips. The original C10 causes (boulder-seam tunnelling, thin `safe_margin`) were fixed 2026-08-06/07; whether they apply to these bodies is not established.
- **Leading hypothesis:** none for these bodies; check overlap with [CMV3C-27](#cmv3c-27) (deterministic corner fall) before treating as separate.

### CMV3C-29

- **Status:** `open` (uninvestigated) | **Scope:** V3 | **Owner:** creature-motor | **Updated:** 2026-10-14 | **Source:** pointer in [CLEANUP](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#open-bug-register-pointers-2026-10-14) (no C section)
- **Symptom:** silent-stall `MOTOR_INVARIANT` for a rabbit near (90.5, 81.9).
- **Repro:** seen once in a nav-cost run (`tools/measure_nav_cost.gd`); not retried.
- **Ruled out:** nothing.
- **Leading hypothesis:** none. Related earlier silent-stall classes (tall-capsule arrival, hop-vs-ultimate) are documented fixed in [PHYSICS_SQUEEZE.md decision 46 E/F](Draft_Features/PHYSICS_SQUEEZE.md); check whether those paths apply.

### CMV3D-1

- **Status:** `open` | **Scope:** V3 | **Owner:** creature-motor (tentative: spawn grounding may instead live in `main_3d.gd` / `PlayfieldBounds3D` settle code, i.e. app-shell / environment-world; confirm) | **Updated:** 2026-10-14 | **Source:** [DESIGNREVIEW, leg 2 live re-runs (2026-09-04)](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) ("off-floor-spawn warning")
- **Symptom:** a warning that `is_on_floor=false` at spawn, for both creatures, on the C9 rig run (`_DEBUG_FORCE_EDGE_CHASE_SPAWN`, `tests/smoke_ai_player.gd`). It did not stop either round from resolving normally.
- **Repro:** seen on 2026-09-04 only; no command or rate recorded. **Recurrence not yet confirmed; confirm during the tech-debt pass.**
- **Ruled out:** nothing; never investigated ("separate, unrelated finding").
- **Leading hypothesis:** possibly the spawn-height bug since fixed on 2026-10-05 (CREATURE_BODY_DIMENSIONS Phase 2: creatures spawned ~r too high and free-fell; see the "Spawn capsule height" history row in [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md)). If the warning no longer appears, close as `done`.

### CMV3D-2

- **Status:** `open` | **Scope:** V3 | **Owner:** creature-motor (tentative; `motor_explore_seek.gd` / `_nav_clearance`) | **Updated:** 2026-10-14 | **Source:** [DESIGNREVIEW, "Not addressed this pass" (2026-09-04)](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md)
- **Symptom:** a fox explores by walking the entire distance to a playfield wall before reacting, even when close enough that its forward cone should read as blocked.
- **Repro:** observed live 2026-09-04; no command or rate recorded. **Recurrence not yet confirmed; confirm during the tech-debt pass** (the finding predates later explore and boundary-clamp work, e.g. C16).
- **Ruled out:** nothing tested. Per the source text only (not re-verified against current code): `_nav_clearance` evaluates an open-space probe once at explore-mint time against a fixed point `awareness_radius * 0.5` (750 u by default) away, never re-checked while closing, and independent of actual playfield size.
- **Leading hypothesis:** the probe reach exceeds the playfield half-width, so most explore waypoints are minted past the boundary in any direction and "walk to a wall" is the structurally expected outcome. Fix directions (not applied): retune reach / probe distance to playfield scale, or re-check clearance on approach; needs its own sizing pass because it touches explore pacing.

### EBP-1

- **Status:** `open` | **Scope:** outside-V3 (not V3 scope, must be addressed eventually) | **Owner:** assets-pack (maintainer decision 2026-10-14; the fix is a Blender origin / pivot alignment pass; note the scene file itself lives under `assets/plants/`, which routes to environment-world, so a scene-side tweak would hand over) | **Updated:** 2026-10-14 | **Source:** pointer in [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) "Plants & ecology"
- **Symptom:** `open_shrub_3d`'s depleted visual appears to jump position after the shrub is eaten.
- **Repro:** found 2026-09-18 during an unrelated manual smoke test; no command or rate recorded.
- **Ruled out:** a physics-layer regression from the concurrent squeeze work (not caused by or related to it).
- **Leading hypothesis:** `assets/plants/open_shrub/open_shrub_3d.tscn` swaps visibility between two separately authored instances (`Visual/ReadyVisual` from `bush_ready.blend`, `Visual/DepletedVisual` from `bush.blend`) in `bush_food_3d.gd` `_refresh_visual()`; both share one local transform, so differing mesh origins / pivots in the two `.blend` files would read as a shift. Likely an asset co-registration fix, not code. Not investigated further.

### EBP-2

- **Status:** `open` | **Scope:** outside-V3 (not V3 scope, must be addressed eventually) | **Owner:** environment-world (`environment/playfield_bounds_3d.gd`) | **Updated:** 2026-10-14 | **Source:** pointer in [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) "Falling & vertical traversal"; origin [PHYSICS_SQUEEZE.md decision 46 D](Draft_Features/PHYSICS_SQUEEZE.md)
- **Symptom:** `PlayfieldBounds3D.mesh_local_bottom_y` measures the lowest mesh point in the prop root's local (unscaled) space (it converts through `prop_root.global_transform.affine_inverse()`), so `snap_prop_root_to_ground` sinks a scaled prop by (scale - 1) x its local bottom depth.
- **Repro:** by inspection (verified 2026-10-14: `playfield_bounds_3d.gd` lines 346-400). Only `tests/run_all.gd` (lines ~13521, 13532) calls `snap_prop_root_to_ground` today; `main_3d.gd` grounds props with `_prop_mesh_bottom_offset_y`, which works in world units.
- **Ruled out:** nothing needed; latent until a new caller uses it.
- **Leading hypothesis / fix:** convert to world units (or delete the pair and migrate the tests) before any new caller uses it.

---

## Tech debt / doc hygiene

Not bugs. Same ID convention, Scope `outside-V3` unless stated, status `open`. **None of these is fixed yet** (logged 2026-10-14 for a later pass).

### CMV3C-30

- **Source / owner:** `spawn_layout_c44_smoke.json` (repo root, **outside Project_Docs, not edited**) | test-harness / app-shell (owner TBD)
- **Item:** the file's `_note` says "CLEANUP C44", but the case it stages is C24 ([CLEANUP C24](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c24-gk_avoid_hostiles-ignored-its-own-explore-fallback-seed-and-sawtoothed-forever-east-wall-spinning), `GK_AVOID_HOSTILES` explore-fallback sawtooth). The filename also says `c44`, and docs that cite the file by name (the index PHYSICS_SQUEEZE row, the backlog row) would need updating if it were renamed; decide whether to fix the note only or rename the file (a rename needs the doc links updated in the same change).

### CMV3C-31

- **Source / owner:** [CLEANUP C9 section](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge), unchecked boxes (lines ~805-809) | project-docs with creature-motor / test-harness. **Scope: V3 prerequisite for closing CLEANUP** (the Active development list requires `open` / `in_progress` items cleared).
- **Item:** the C9 unchecked boxes mix real tasks (the west-edge notch item, which is now CMV3C-26; `_DEBUG_FORCE_EDGE_CHASE_SPAWN` removal) with stale tooling items (the `run_all.gd` vs live-invariant-harness incompatibility may already be covered by C12 / C14, both `done`; the "Decision needed" box predates the 2026-10 work; `_RUN_TICKS` tuning is polish). Needs one reconcile pass: tick, delete into a pointer, or promote to a real item.

### CMV3C-32

- **Source / owner:** [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) open question (line ~804) | creature-motor
- **Item:** the C9 open question about the 2026-10-13 trip's body y = 12.56 on a `minus_x_edge` run is only half answered: the xz position matches a `plus_z_edge` start ~(0,95) (the printed label was the previous scenario), but the y value remains unexplained (prop? terrain height there? a falling body, cf. [CMV3C-10](#cmv3c-10)). Check the terrain height at (1.74, 95.43) first.

### CBD-1

- **Status / scope / owner:** `open` | outside-V3 | cross-domain (suggest test-harness for the scripted audit; fixes route to the domain owners: creature-motor, creature-entity, app-shell). Logged 2026-10-15. **Not fixed yet** (except the two margin getters, below).
- **Source:** [CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md) §7 (reach config-driven box) and §4.8 Phase 1 landed state.
- **Item (maintainer-requested review of ALL defaults for duplicated definitions).** Design rule (maintainer, 2026-10-15): global defaults live in code (e.g. `AI_int_lib/game_config_merge.gd`); `game_config.json` only overrides them (tuning / testing; proven values should eventually be folded back into the code default); then species packs (e.g. wolf), then possibly sub-species (e.g. timber wolf). A default that is a calculation should expose a place for per-creature customization. A default must be defined in **ONE** place.
- **Already fixed (2026-10-15):** `game_config.gd` `get_width_margin()` / `get_reach_margin_fraction()` no longer hold literal 0.10 / 0.25 fallbacks (they use `_merge_default_v3_float` -> `default_creature_motor_v3_params()`); tests `_test_body_dims_reach_margin_config_drives_reach_extent` and `_test_body_dims_margin_getters_fall_back_to_merge_default`.
- **Known suspects, verified 2026-10-15** (inline literal `motor_v3.get("key", 0.25)` where `default_creature_motor_v3_params()` in `game_config_merge.gd` already defines the same key with the same value 0.25, so each literal is a duplicate definition):
  - `flight_release_margin_frac`: `creature/motor/creature_motor_stack.gd` ~1139 (merge line 473).
  - `flee_incumbent_bearing_bonus`: `creature/motor/motor_planner.gd` ~3821 (merge line 410).
  - `flee_separation_gain`: `creature/motor/flee_candidate_scoring.gd` ~262 (merge line 428).
  - `explore_w_unexp`: `creature/motor/motor_explore_seek.gd` ~101 (merge line 314).
  - `goal_shelter_explore_floor`: `creature/motor/motor_goal_hub.gd` ~282 (merge line 633).
  - Also in `tests/run_all.gd` (~9649 `goal_shelter_explore_floor`, ~11614 `flight_release_margin_frac`; ~1170 restates `explore_w_unexp` 0.25 in a fixture), not yet judged: tests may justify an exception.
- **Known suspects, NOT verified against a default (needs a look):**
  - `game_config.json` `creature_motor_v3` keys that merely restate the code default: `width_margin` 0.10 (line 19), `reach_margin_fraction` 0.25 (line 20). Verified to match the merge defaults today; whether to delete them or keep as the documented override example is undecided.
  - Hard-coded body fallbacks 0.35 (radius) and 1.2 (height) in `creature/motor/creature_motor_stack.gd` ~1656-1657 (used when `_body` lacks `get_body_radius` / `get_collision_capsule_height`); no matching default checked.
  - `.get(...)` fallback chains for GameConfig-less bodies in `creature/capabilities/creature_kinematic_body_3d.gd` (lines ~214-234; the margin fallback reads the merge default but its `.get(key, 0.0)` literals are a second fallback layer); further chains not enumerated.
  - Related, tracked in the source doc: body margins ignore the species pack overlay (open `<<Question>>` in CREATURE_BODY_DIMENSIONS.md; grep 2026-10-15: no shipped `pack_resources.json` sets either key).
- **Tooling (2026-10-15):** `python tools/audit_default_duplicates.py [--json out.json]` (stdlib only, read-only, always exit 0) compares inline `get("key", literal)` fallbacks, `game_config.json` and the `creature_motor` / `creature_motor_v3` pack overlays in `pack_resources.json` against the `default_*_params()` dictionaries in `AI_int_lib/game_config_merge.gd`. Limits: regex / line based; scalar defaults only; single-line `get("key", literal)` fallbacks only; key-name matching, so generic keys (`count`, `dist`) are noise; 0 / empty / false fallbacks are counted, not classified; only the two pack overlay sections are checked; no sub-species structure exists yet. Guard test: `_test_margin_defaults_have_no_duplicate_literals` in `tests/run_all.gd` (`width_margin` / `reach_margin_fraction` may have no non-zero numeric fallback under `creature/` or in `game_config.gd`; a literal 0 is allowed).
- **Audit results (2026-10-15; 8 default functions, 354 default keys).** Nothing below has been applied; maintainer decides.
  - **CONFLICT = 5 (priority; all verified by hand):** inline literal differs from the code default.
    - `motor_explore_seek.gd:99` `explore_w_spawn` 0.35 vs default 0.20; `:100` `explore_w_open` 0.30 vs 0.45 (literals stale since the CLEANUP C8 rebalance changed the defaults).
    - `motor_planner.gd:3190`, `:3625`, `:4329` `awareness_radius` 150.0 vs default 1500.0 (the other 8 `awareness_radius` fallbacks use 1500). Dormant today: the merged dict always has the key and `scale_creature_motor_v3_for_playfield` overwrites it; if the key were ever missing the fallback would behave ~10x differently.
  - **DUPLICATE_SAME = 285** inline fallbacks equal to the code default (approx: `motor_planner` ~100, `memory_adapter` ~45, `creature_motor_stack` ~35, `goal_source_memory` ~30, `motor_goal_hub` ~20, `goal_belief_memory` ~15, others, `oLog_lib/olog.gd` 3). Includes the five 0.25 suspects verified above. Some keys match only one of several differing defaults (`locale_prior_write_blend` 0.35 spine vs 0.32 ship; `believed_goal_escalate_seek_mul` 1.35 vs 1.4), so a literal can be "same" as one default and still differ from the other.
  - **NO_DEFAULT = 69 sites / 41 keys** (literal is the only definition). Mostly runtime snapshot / log fields (`count`, `dist`, `calorie_ratio`, `hostile`, ...). Possible missing defaults to review: `prey_race_giveup_ticks` 90.0 (`motor_planner.gd:2996`), `prey_engagement_detour_decay_step_ticks` 4 (`:3050`), `stat_observation` 10 (`:1555`), `choke_confirm_count` 1, `eye_height` 1.0 (5 sites), and `origin_position_tolerance_fraction` / `proportion_warn_fraction` / `proportion_fail_fraction` in `tools/measure_body_dimensions.gd`.
  - **`game_config.json`:** 30 keys restate the code default (`width_margin`, `reach_margin_fraction`, `perception.SNAPSHOT_PHYSICS_STRIDE`, `playfield_spawn.seed`, and 26 `creature_motor.*` keys); 1 UNKNOWN_KEY (`playfield_spawn.debug_start_calories`, a test-only override). Under the layering rule the json should hold only deliberate overrides.
  - **Pack overlays:** 90 keys restate the global default (wolf 26 and fox 26 `creature_motor` keys, rabbit 38; each pack restates `creature_motor_v3.awareness_cone_extra` 400.0; rabbit also restates 4 v3 keys); 1 unknown key `creature_motor.awareness_forward_cone_only` in all three packs.
  - **Repeated key with differing literals: 9** (`awareness_radius` x12 sites with 0.0 / 150.0 / 1500.0; the rest are mostly runtime fields).
- **Next step (ordered plan; maintainer decides):**
  1. Fix the 5 CONFLICTs first: remove the inline literal or make it the single code default. Decide per site which value is intended; for `explore_w_*` the default was deliberately rebalanced in C8, so likely remove the literal.
  2. Decide policy for the 285 DUPLICATE_SAME: remove inline fallbacks vs a documented "safe default helper" (cf. `_merge_default_v3_float`). Large mechanical change; owner per domain (creature-motor / creature-entity / app-shell).
  3. Review the NO_DEFAULT candidates above for missing defaults.
  4. Decide whether `game_config.json` and `pack_resources.json` should drop keys that merely restate defaults (30 + 90) and whether the unknown keys are dead.
  5. Extend the audit tool (multi-line calls, expressions, sub-species) and re-run after each batch; consider a guard test like the margin one once a batch is clean.
