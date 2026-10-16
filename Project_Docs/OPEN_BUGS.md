# Open bugs register

> **Purpose:** content-dense register of **unresolved bugs** (`open`, `in_progress`, `pending_recurrence`) across the active project docs. Enough detail that new data adds to the picture and nobody re-runs a dead end. **Not a debug diary:** the messy history stays in the source feature doc, which keeps a one-line pointer back here.
>
> **Status vocabulary:** [Project_Docs/CLAUDE.md](CLAUDE.md) (`open`, `in_progress`, `pending_recurrence`; `done` / `wont_fix` entries are **removed** from this file and their final status stays in the source doc). `watch` items stay in their source docs. **Unbuilt features are not bugs** — they belong to their feature plan or [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md).
>
> **Scope field (every entry):** `V3` = belongs to, or blocks closing, the current Creature Movement V3 project (see the Active development list in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)). `outside-V3` = not V3 scope, **must be addressed eventually** (it does not gate V3 close-out, but it is not dropped).
>
> **Tier:** root / tracking (see [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)); not a feature plan and not a contract. Rules for maintainers: [Project_Docs/CLAUDE.md](CLAUDE.md) "Bug register (OPEN_BUGS.md)".
>
> **Last full sweep:** 2026-10-16 (CBD-1 step 6 legacy `creature_motor` retirement recorded; other entries last swept 2026-10-14 / 2026-10-15).

---

## ID convention

`<DOC_ACRONYM>-<n>`: the acronym derives from the **source doc's filename** (registry below); `<n>` is the number the source doc already uses (`C9` -> `CMV3C-9`, `RT4` -> `CMV3R-4`). **Numbers are never reused.** A bug first logged with no source-doc number gets the prefix of the doc its pointer lives in and the next unused number for that prefix. **Register a new prefix here before using it.**

### Prefix registry

| Prefix | Source doc | Source-doc numbering | Next unused |
|--------|------------|----------------------|-------------|
| `CMV3C` | [CREATURE_MOVEMENT_V3_CLEANUP.md](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md) | `C#` (C1-C24 exist; 25-29, 30-32 and 33 were assigned here without a C section) | 34 |
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
| [CMV3C-27](#cmv3c-27) | `pending_recurrence` | V3 | environment-world | Corner scenario of `test_c9_flee_edge_pingpong.gd` fell at tick 35 near (-95,-93); does not reproduce at HEAD, original coordinates look mislabelled |
| [CMV3C-28](#cmv3c-28) | `open` | V3 | creature-entity | Instances of CMV3C-10: airborne-invariant trips for rabbit/fox/wolf in the C9 edge test; falling bodies, not flee |
| [CMV3C-29](#cmv3c-29) | `open` | V3 | creature-motor | Silent-stall `MOTOR_INVARIANT` for a rabbit near (90.5, 81.9), seen once in a nav-cost run; uninvestigated |
| [CMV3D-1](#cmv3d-1) | `open` | V3 | creature-motor (tentative) | `is_on_floor=false` at spawn warning for both creatures on the C9 rig; recurrence not confirmed |
| [CMV3D-2](#cmv3d-2) | `open` | V3 | creature-motor (tentative) | Explore walks the whole way to a wall: explore waypoints minted well past the playfield boundary; recurrence not confirmed |
| [CMV3C-33](#cmv3c-33) | `open` | outside-V3 | environment-world | `PlayfieldGroundSampler._bake` elevation includes props (~16-17 m at the (-96,-96) corner vs terrain 0); low priority, fix decision pending consumer audit |
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
- **Leading hypothesis:** none for the current instances; the old fixes were verified on favourable samples (10/10 twice) and the family has recurred each time. [CMV3C-27](#cmv3c-27) (corner fall) was investigated 2026-10-16 and does not overlap (not reproducible; its y -3.64 matched the west basin, not a falling body in the corner).
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

- **Status:** `pending_recurrence` (was `open`) | **Scope:** V3 | **Owner:** environment-world (placement / terrain) | **Updated:** 2026-10-16 | **Source:** pointer in [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) checklist (residual item, "Corner scenario")
- **Symptom (as originally logged 2026-10-13/14):** in the corner scenario the body fell (C10-like) at tick 35, "deterministically", near (-94..-96.6, y -3.64, z -93.2..-93.8), at all standoffs.
- **Repro:** `godot --path . --headless -s res://tests/test_c9_flee_edge_pingpong.gd`. 2026-10-16 investigation: **does not reproduce** at HEAD (4 full runs + 3 corner-only runs) or at 7c1751e (2 runs). Terrain at the corner is solid flat y=0 (ray scans; no seam, no void).
- **Ruled out:** "placement over a drop / unsupported terrain" (terrain at the corner is flat y=0). A shared cause with [CMV3C-10](#cmv3c-10) / [CMV3C-26](#cmv3c-26) / [CMV3C-28](#cmv3c-28): none found (no overlap).
- **Leading hypothesis:** the original coordinates were mislabelled. The recorded y -3.64 matches the west basin (z -14..16, the [CMV3C-26](#cmv3c-26) location), not z ~ -93, so the 2026-10-13 observation probably belonged to a different location or run. Not proven. Related but separate finding from this investigation: [CMV3C-33](#cmv3c-33) (sampler elevation includes props; the test's `_place` spawned the body ~18.5 m up at this corner and it free-fell 25 ticks).
- **Next step:** none until a fresh corner-scenario fall appears (record the full position, scenario label and `sample_elevation` when it does).

### CMV3C-28

- **Status:** `open` | **Scope:** V3 | **Owner:** creature-entity | **Updated:** 2026-10-14 | **Source:** [CLEANUP C10](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c10-fox-ends-up-under-the-geography-after-close-contact-with-prey-new-2026-08-05) (family, tracked as [CMV3C-10](#cmv3c-10)) and the C9 residual checklist item
- **Symptom:** the instances of CMV3C-10: rabbit / fox / wolf trip the airborne / off-floor invariant in `test_c9_flee_edge_pingpong.gd` runs (falling bodies, pos y 8.9, 12, -13.7). Not flee-related.
- **Repro:** among the ~6 failures in 50 earlier untightened `test_c9_flee_edge_pingpong.gd` runs (mixed with the west-edge notch leak); also 1/6 `smoke_ai_player.gd` runs on 2026-08-07 (fox at tick 731). Current rate in the tightened test not recorded.
- **Ruled out:** nothing tested for these trips. The original C10 causes (boulder-seam tunnelling, thin `safe_margin`) were fixed 2026-08-06/07; whether they apply to these bodies is not established.
- **Leading hypothesis:** none for these bodies; [CMV3C-27](#cmv3c-27) (corner fall) was investigated 2026-10-16 and does not overlap with these trips (no shared cause with CMV3C-10/26/28).

### CMV3C-29

- **Status:** `open` (uninvestigated) | **Scope:** V3 | **Owner:** creature-motor | **Updated:** 2026-10-14 | **Source:** pointer in [CLEANUP](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#open-bug-register-pointers-2026-10-14) (no C section)
- **Symptom:** silent-stall `MOTOR_INVARIANT` for a rabbit near (90.5, 81.9).
- **Repro:** seen once in a nav-cost run (`tools/measure_nav_cost.gd`); not retried.
- **Ruled out:** nothing.
- **Leading hypothesis:** none. Related earlier silent-stall classes (tall-capsule arrival, hop-vs-ultimate) are documented fixed in [PHYSICS_SQUEEZE.md decision 46 E/F](Draft_Features/PHYSICS_SQUEEZE.md); check whether those paths apply.

### CMV3C-33

- **Status:** `open` (low priority) | **Scope:** outside-V3 (does not gate V3; the C9 test-side workaround is being done separately in `tests/`) | **Owner:** environment-world | **Updated:** 2026-10-16 | **Source:** pointer in [CLEANUP C9](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) checklist (found while investigating [CMV3C-27](#cmv3c-27); no C section)
- **Symptom:** `PlayfieldGroundSampler._bake` (`environment/playfield_ground_sampler.gd`) takes `surface_y` / `sample_elevation` from rays that do not exclude props. At the (-96.13, -96.13) corner `sample_elevation` reads ~16-17 m while true terrain is 0. The C9 test's `_place` (`sample_elevation + 1.2`) therefore spawned the body at ~18.5 m and it free-fell 25 ticks (11 short of the 36-tick airborne bailout). Sampler values also varied **between processes** (105 m at the rim vs 9-17 m); cause unknown.
- **Repro:** `tests/test_c9_flee_edge_pingpong.gd` corner scenario, observed during the 2026-10-16 CMV3C-27 investigation; no isolated sampler repro command or rate recorded.
- **Ruled out:** nothing tested beyond the ray observation (terrain itself is flat y=0 at the corner).
- **Leading hypothesis:** the elevation rays hit props (e.g. plants / boulders / rim geometry), and prop placement differs per process, which would also explain the between-process variation. Not verified.
- **Fix decision:** pending consumer audit. Options: a terrain-only elevation channel, or exclude props from the elevation rays. Needs an audit of `MotorPlane` and other consumers of `sample_elevation` / `surface_y` first (some may want prop-inclusive height).
- **Test-side workaround:** test-harness is changing `_place` in the C9 test to raycast terrain (tracked separately in `tests/`; does not close this item).

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

- **Status / scope / owner:** `open` | outside-V3 | cross-domain (suggest test-harness for the scripted audit; fixes route to the domain owners: creature-motor, creature-entity, app-shell). Logged 2026-10-15. **Partly done 2026-10-15 / 2026-10-16:** plan steps 1, 3, 4 and 6 shipped (the 5 CONFLICTs, the JSON restated-default cleanup, NO_DEFAULT review plus dead-pack-knob removal, wholesale retirement of the legacy `creature_motor` surface 2026-10-16); steps 2 and 5 open. Maintainer 2026-10-15: not gating V3; stays here as outside-V3 tech debt (the 5 conflicts were the drift that had actually occurred).
- **Source:** [CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md) §7 (reach config-driven box) and §4.8 Phase 1 landed state.
- **Item (maintainer-requested review of ALL defaults for duplicated definitions).** Design rule (maintainer, 2026-10-15): global defaults live in code (e.g. `AI_int_lib/game_config_merge.gd`); `game_config.json` only overrides them (tuning / testing; proven values should eventually be folded back into the code default); then species packs (e.g. wolf), then possibly sub-species (e.g. timber wolf). A default that is a calculation should expose a place for per-creature customization. A default must be defined in **ONE** place.
- **Already fixed (2026-10-15; full suite green, exit 0, 0 ASSERT / SCRIPT ERROR / Parse Error):**
  - `game_config.gd` `get_width_margin()` / `get_reach_margin_fraction()` hold no literal fallbacks (`_merge_default_v3_float` -> `default_creature_motor_v3_params()`); tests `_test_body_dims_reach_margin_config_drives_reach_extent`, `_test_body_dims_margin_getters_fall_back_to_merge_default`.
  - **Plan step 1, the 5 CONFLICT fallbacks:** new `static func v3_default(key)` in `AI_int_lib/game_config_merge.gd` (lazily cached copy of `default_creature_motor_v3_params()`), used by `motor_explore_seek.gd` (`explore_w_spawn`, `explore_w_open`) and `motor_planner.gd` (3x `awareness_radius`). Behaviour note: if a `motor_v3` dict lacks those keys the fallback is now the code default (`awareness_radius` 1500 not 150; explore weights 0.20 / 0.45 not 0.35 / 0.30); no test depended on the old values and the shipped merged dict always carries the keys.
  - **Plan step 4, JSON restated-default cleanup (maintainer rule: once a value is in code, remove it from JSON so a later code tweak is not silently masked):** `game_config.json` lost 26 keys (`perception.SNAPSHOT_PHYSICS_STRIDE`, `playfield_spawn.seed`, `creature_motor_v3.width_margin` / `reach_margin_fraction`, 22 `creature_motor.*`; `perception` and `creature_motor_v3` are now `{}`); pack overlays lost keys equal to the code default (fox 23, wolf 23, rabbit 33 net lines). Verified by a before/after dump of the merged root and each pack's merged `creature_motor` / `creature_motor_v3` in BOTH ship and dev profile modes (identical).
  - **Rule learned (still the right layering rule):** a pack key is redundant only against the CODE default (per profile), never against a `game_config.json` tuning pin. Compare pack overlays against code defaults, not the json-merged config.
  - **Correction (2026-10-15, see KEY FINDING below):** the earlier "kept pins" / "profile-dependent pins" notes (`game_config.json` 4 keys; fox/wolf `weight_seek_*`; rabbit ship-profile values; `weight_explore_trail_repulsion` "restored because a test caught it") concern INERT `creature_motor` data. The before/after merged-config equality check was true but trivial for `creature_motor`, and the test that failed asserted inert overlay data (`_test_creature_pack_motor_overlays`). Do not read those pins as live V3 tuning.
  - **DONE 2026-10-15 (steps 3 + dead-knob removal; full suite green, exit 0, 0 ASSERT / SCRIPT ERROR / Parse Error):**
    - **60 dead diet-prefixed pack `creature_motor` keys removed** (rabbit 36, fox 29, wolf 29 `pack_resources.json`): `herbivore_*` (rabbit), `predator_*` (fox / wolf), `jeopardy_forced_turn_ticks_prey`, `motor_forage_plateau_*`, `motor_goal_sight_chaos_mul`, `motor_no_goal_chaos_mul`, `motor_tie_cost_epsilon`, `obstacle_lookahead`, `plant_awareness_requires_los`, `post_los_*`, `pursuit_engaged_urgency_floor`, `geometry_escape_lock_ticks`, `awareness_forward_cone_only`, `predator_prey_memory_sec`, `herbivore_flee_panic_radius`, `speed`. Cause: artifacts of the pre-V3 separate predator / prey code paths; the V3 refactor (fd721a9, 2026-06-20) deleted their last readers. Also removed: the dead `awareness_forward_cone_only` read in `creature/awareness_debug_overlay_3d.gd`, the `herbivore_flee_panic_radius` branch of `merge_creature_motor_v3_from_legacy` in `pack_resource_resolver.gd`, the unreachable fallbacks in `goal_belief_memory.gd` `_moving_ttl_ms` (now only `goal_memory_mover_ttl_sec`, default via `_Merge.v3_default`), and 6 test assertions on the removed keys in `_test_creature_pack_motor_overlays`. `speed` was never a config knob (body speed = `locomotion_profile.max_speed`).
    - **Bucket-B relocation (behaviour-preserving)** into `default_creature_motor_v3_params()` (`AI_int_lib/game_config_merge.gd`), read via `_Merge.v3_default(key)`: `prey_engagement_detour_decay_step_ticks` 4; `prey_race_giveup_ticks` 90.0 (baseline until `_refresh_prey_race_giveup_ticks` overwrites it); and 14 spine-only keys V3 read with inline fallbacks, now defaulting to that effective inline literal: `believed_goal_escalate_seek_mul` 1.35, `explore_coverage_cell` 52.0, `food_seek_imminent_mob_radius` 100.0, `locale_prior_max_buckets` 100, `locale_prior_pull_w_norm` 3.0, `locale_prior_write_blend` 0.35, `replay_bell_k` 1.4, `replay_n_min` 3.0, `replay_n_sat` 10.0, `replay_urgency_slot_b_min` 90.0, `replay_w_fit` 0.4, `replay_w_store` 0.6, `salient_write_max_per_sec` 100, `urgency_boost_linear_slope` 25.0. The spine / ship values for these were never seen by V3 (e.g. ship `locale_prior_write_blend` 0.32 and `believed_goal_escalate_seek_mul` 1.4 are ignored). `explore_coverage_cell` and `food_seek_imminent_mob_radius` were added to `MotorPlane._UNSCALED_MOTOR_DISTANCE_KEYS` (still NOT playfield-scaled; behaviour unchanged).
    - **Structural constants** (one named const, not tunables): `MotorPlane.DEFAULT_EYE_HEIGHT` 1.0 (7 sites); `CreatureDefinition.DEFAULT_STAT` 10 (`stat_observation` fallbacks + `@export` default); `FallPhysics.DEFAULT_GRAVITY` 9.8 (reused as the ProjectSettings gravity fallback in the kinematic body, `motor_plane`, `playfield_bounds_3d`); `GoalKindRegistry.SALIENT_WRITES_DEFAULT` true.
    - **Tool spec fix:** `tools/measure_body_dimensions.gd` now reads `tools/body_dimension_spec.json` directly (the 0.02 / 0.10 / 0.20 literals were unreachable duplicates) and exits 2 with `push_error` if a required key is missing.
    - **Investigated, not bugs / left:** `choke_observation_weight` fallbacks 0.0 (`goal_belief_memory.gd`, "no prior choke estimate") vs 1.0 (`memory_adapter.gd`, neutral multiplier on rows already `GK_CHOKE_POINT`) differ intentionally; `olog.gd` `source_tag` 'Main' duplicates its param defaults (skipped); `motor_v3.los_eye_height` optional override intentionally has no default.
  - **Standard-location rule (new, 2026-10-15):** tunables -> `default_*_params()` in `AI_int_lib/game_config_merge.gd` (consume via `_Merge.v3_default` or the merged dict); structural / cross-file constants -> ONE named const in the owning script. No documented rule existed before; now recorded in [assets/CLAUDE.md](../assets/CLAUDE.md) Config layering.
- **KEY FINDING (verified 2026-10-15): NO pack's `creature_motor` block is applied at V3 runtime.** `GameConfig.get_creature_motor_params_for_pack` has zero callers; `_Merge.merge_creature_motor_pack_overlay` is called only from `tests/run_all.gd` (~899, ~923); the legacy shim `merge_creature_motor_v3_from_legacy` fires only when a pack's `creature_motor_v3` block is empty, and all three packs have a non-empty one. V3 reads exactly one dict, `motor_v3`, built by `GameConfig.get_creature_motor_v3_params_for_pack` from `default_creature_motor_v3_params()` + the pack's `creature_motor_v3` block. The remaining pack `creature_motor` keys, the `game_config.json` `creature_motor` block, and the legacy spine `default_creature_motor_params()` (143 keys; ~100 have no non-test reader) are therefore largely INERT. Only `predator_prey_meal_calories`, `creature_half_extent_x/y`, `calorie_baseline_drain_per_sec`, `calorie_cost_per_unit_moved` and `seek_priority_food_ceiling` (unreachable) are read through the legacy getter `get_creature_motor_params` (`creature_kinematic_body_3d.gd`, `creature_motor_stack.gd`). The live pack knobs are the `creature_motor_v3` block. **RESOLVED 2026-10-16 (step 6):** the whole legacy surface was deleted (see the DONE entry below); the four keys that still had a reader (`predator_prey_meal_calories`, `creature_half_extent_x/y`, `calorie_cost_per_unit_moved`) moved into `default_creature_motor_v3_params()`, and `calorie_baseline_drain_per_sec` / `seek_priority_food_ceiling` readers were switched to the V3 getter. The "kept pins" correction above stands (they described inert data that no longer exists).
- **Known suspects, verified 2026-10-15** (inline literal `motor_v3.get("key", 0.25)` where `default_creature_motor_v3_params()` already defines the same key and value; each literal is a duplicate definition, i.e. DUPLICATE_SAME, plan step 2, not yet changed):
  - `flight_release_margin_frac`: `creature/motor/creature_motor_stack.gd` ~1139 (merge line 473).
  - `flee_incumbent_bearing_bonus`: `creature/motor/motor_planner.gd` ~3821 (merge line 410).
  - `flee_separation_gain`: `creature/motor/flee_candidate_scoring.gd` ~262 (merge line 428).
  - `explore_w_unexp`: `creature/motor/motor_explore_seek.gd` ~101 (merge line 314).
  - `goal_shelter_explore_floor`: `creature/motor/motor_goal_hub.gd` ~282 (merge line 633).
  - Also in `tests/run_all.gd` (~9649 `goal_shelter_explore_floor`, ~11614 `flight_release_margin_frac`; ~1170 restates `explore_w_unexp` 0.25 in a fixture), not yet judged: tests may justify an exception.
- **Known suspects, NOT verified against a default (needs a look):**
  - Hard-coded body fallbacks 0.35 (radius) and 1.2 (height) in `creature/motor/creature_motor_stack.gd` ~1656-1657 (used when `_body` lacks `get_body_radius` / `get_collision_capsule_height`); no matching default checked.
  - `.get(...)` fallback chains for GameConfig-less bodies in `creature/capabilities/creature_kinematic_body_3d.gd` (lines ~214-234; the margin fallback reads the merge default but its `.get(key, 0.0)` literals are a second fallback layer); further chains not enumerated.
  - Related, tracked in the source doc: body margins ignore the species pack overlay (open `<<Question>>` in CREATURE_BODY_DIMENSIONS.md; grep 2026-10-15: no shipped `pack_resources.json` sets either key).
- **Tooling (2026-10-15; updated 2026-10-16):** `python tools/audit_default_duplicates.py [--json out.json]` (stdlib only, read-only, always exit 0) compares inline `get("key", literal)` fallbacks, `game_config.json` and the `creature_motor_v3` pack overlays in `pack_resources.json` against the `default_*_params()` dictionaries in `AI_int_lib/game_config_merge.gd`. Limits: regex / line based; scalar defaults only; single-line `get("key", literal)` fallbacks only; key-name matching, so generic keys (`count`, `dist`) are noise; 0 / empty / false fallbacks are counted, not classified; only the `creature_motor_v3` pack overlay section is checked; no sub-species structure exists yet. Guard test: `_test_margin_defaults_have_no_duplicate_literals` in `tests/run_all.gd` (`width_margin` / `reach_margin_fraction` may have no non-zero numeric fallback under `creature/` or in `game_config.gd`; a literal 0 is allowed).
- **Audit results (re-run 2026-10-16 after the step 6 retirement: 5 default functions, 207 merge default keys; before the retirement 8 functions / 370 keys, CONFLICT 0 / DUPLICATE_SAME 269 / NO_DEFAULT 52 sites (32 keys) / game_config.json restates 4 / pack restates 13 / PACK_UNKNOWN_KEY 0. First run 2026-10-15 found CONFLICT 5, game_config.json 30 and pack 90 restated keys). Current (2026-10-16): CONFLICT 0, DUPLICATE_SAME 266, NO_DEFAULT 52 sites / 32 keys, game_config.json RESTATES 0 / UNKNOWN_KEY 1, PACK_RESTATES 0, PACK_UNKNOWN_KEY 0, repeated-key 9. The bullets below keep the 2026-10-15 numbers as history.**
  - **CONFLICT = 0** (was 5: `explore_w_spawn` / `explore_w_open` stale since the C8 rebalance; 3x `awareness_radius` 150 vs 1500, dormant because the merged dict always has the key).
  - **DUPLICATE_SAME = 269** (was 285; deferred) inline fallbacks equal to the code default (approx: `motor_planner` ~100, `memory_adapter` ~45, `creature_motor_stack` ~35, `goal_source_memory` ~30, `motor_goal_hub` ~20, `goal_belief_memory` ~15, others, `oLog_lib/olog.gd` 3). Includes the five 0.25 suspects verified above. Some keys match only one of several differing defaults (`locale_prior_write_blend` 0.35 spine vs 0.32 ship; `believed_goal_escalate_seek_mul` 1.35 vs 1.4), so a literal can be "same" as one default and still differ from the other.
  - **NO_DEFAULT = 52 sites / 32 keys** (was 69 / 41; literal is the only definition). The remaining items are runtime snapshot / telemetry fields (`count`, `dist`, `calorie_ratio`, `hostile`, ...) that need no default; the former candidates (`prey_*`, `stat_observation`, `eye_height`, measure-tool tolerances) were resolved by the 2026-10-15 relocation / constants.
  - **RESTATES_DEFAULT (`game_config.json`) = 4** (was 30), **PACK_RESTATES_DEFAULT = 13** (was 90): both concern INERT `creature_motor` data (see KEY FINDING); 1 UNKNOWN_KEY (`playfield_spawn.debug_start_calories`, a test-only override). **PACK_UNKNOWN_KEY = 0** (was 94: the dead pack-only knobs were removed).
  - **Repeated key with differing literals: 9** (`awareness_radius` x12 sites with 0.0 / 150.0 / 1500.0; the rest are mostly runtime fields).
- **Ordered plan (maintainer decides):**
  1. ~~Fix the 5 CONFLICTs~~ **DONE 2026-10-15** (`GameConfigMerge.v3_default`, see Already fixed).
  2. **Open:** policy decision for the 269 DUPLICATE_SAME: remove inline fallbacks vs a documented safe-default helper (`v3_default` / `_merge_default_v3_float` now exist). Large mechanical change; owner per domain (creature-motor / creature-entity / app-shell). Not gating V3.
  3. ~~Review NO_DEFAULT candidates~~ **DONE 2026-10-15** (relocated / constants, see DONE block; remainder is runtime / telemetry fields).
  4. ~~JSON / pack restated-default cleanup~~ **DONE 2026-10-15** (plus removal of the 60 dead pack knobs that had made up PACK_UNKNOWN_KEY).
  5. **Open:** extend the audit tool (multi-line calls, expressions, sub-species); make the pack check compare against code defaults per profile (never the json-merged config); re-run after each batch; consider a guard test once a batch is clean.
  6. ~~Retire the inert legacy `creature_motor` surface~~ **DONE 2026-10-16** (maintainer-approved; full suite green, exit 0, 0 ASSERT / SCRIPT ERROR / Parse Error; `check_gdscript_no_tabs.py` exit 0). Behaviour-preserving:
     - **Deleted:** `creature_motor_spine()`, `creature_motor_profile_dev/ship()`, `use_ship_motor_profile()`, `default_creature_motor_params()`, `apply_creature_motor_profile_ship/dev()`, `merge_creature_motor_pack_overlay()` (all `AI_int_lib/game_config_merge.gd`); the `"creature_motor"` entry in `default_root()` / `merge_root()`; `PackResourceResolver.load_creature_motor_overlay`, `_V3_LEGACY_COPY_KEYS`, `merge_creature_motor_v3_from_legacy` (`merge_creature_motor_v3_pack_overlay` now just loads the pack's `creature_motor_v3` block); `GameConfig.get_creature_motor_params` / `get_creature_motor_params_for_pack`; the `game_config.json` `creature_motor` block; the `creature_motor` block of the rabbit, fox, wolf and `resolver_smoke` packs (`resolver_smoke` needs no `creature_motor_v3` block: no test asserts a non-default for it).
     - **Moved into `default_creature_motor_v3_params()`:** `predator_prey_meal_calories` 5, `creature_half_extent_x` 13.5, `creature_half_extent_y` 30.5, `calorie_cost_per_unit_moved` 0.002. Readers switched to `get_creature_motor_v3_params()` with `_Merge.v3_default(key)` fallbacks: `creature_kinematic_body_3d.gd` (`_seek_priority_food_ceiling`, `_refresh_calorie_burn_params`, `try_grant_as_prey_to`, `_footprint_half_for_clamp`, the two calorie member initialisers), `creature_motor_stack.gd` `_resolve_predator_prey_meal_calories`, `motor_plane.gd` `footprint_half_extents` (inline 13.5 / 30.5 fallbacks removed), `goal_source_memory.gd` `_hunger_subscore` (receives the V3 dict). `calorie_cost_per_unit_moved` is read only on the body's non-V3 fallback drain (`_use_v3_action_calories == false`, i.e. bodies without a `CreatureRoot3D`); it is left untouched when V3 action calories are on, as before. `calorie_cost_per_unit_moved` is also in `MotorPlane._is_distance_motor_param_key`, so the playfield-scaled V3 copy now carries a scaled value no reader consumes.
     - **Tests (`tests/run_all.gd`):** the ~10 `default_creature_motor_params()` / `creature_motor_spine()` fixtures now use `default_creature_motor_v3_params()`; `_test_creature_pack_motor_overlays` lost its inert overlay assertions and survives as `_test_creature_pack_goal_kinds_and_archetypes` (the goal-kind / modality / archetype assertions it also held are live); the `merged["creature_motor"]` / `base["creature_motor"]` default assertions were dropped or converted to V3 (`awareness_radius`, `explore_coverage_cell`, `food_seek_imminent_mob_radius`); new `_test_legacy_creature_motor_surface_retired` asserts the 4 moved keys, the absence of the deleted `GameConfig` / `_Merge` / `PackRes` symbols and of any `creature_motor` key in `game_config.json` and the four pack jsons; the two `use_ship_motor_profile` project-setting assertions were removed.
- **Proposal (NOT adopted):** make "`python tools/audit_default_duplicates.py` reports CONFLICT = 0" a verify-before-close-out item in the PROJECT_DOC_INDEX Active development list.
