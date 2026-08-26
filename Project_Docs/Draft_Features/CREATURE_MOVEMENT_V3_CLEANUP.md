# CREATURE_MOVEMENT_V3 — Cleanup & implementation gaps

> **Role:** Design workspace for **bug fixes**, **playtest regressions**, and **implementation gaps** discovered after V3 phasing (§12) ships or during manual smoke. **Not** a replacement for [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md) — that file remains the authoritative motor contract; this file tracks **follow-on slices** that close the gap between spec intent and runtime behavior.
>
> **Authority:** Items here are **tier II draft** until promoted into V3 §12 (new sub-phase), merged into V3 body text, or closed as *won't fix*. Code changes ship with doc updates per [project-docs.mdc](../../.cursor/rules/project-docs.mdc).
>
> **Related:** [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md) (main spec), [tests/motor_path_fixture.gd](../../tests/motor_path_fixture.gd) (headless geometry), duel manual smoke (§12.2 / 14.2.7), [CREATURE_MOVEMENT_V3_RANDOMTESTS.md](CREATURE_MOVEMENT_V3_RANDOMTESTS.md) (sibling log — issues found specifically via randomized playfield spawn; move an item here if it turns out to be unrelated to spawn randomization).

---

## How to use this file

| Field | Meaning |
|-------|---------|
| **ID** | `C#` — stable reference in commits / PRs |
| **Status** | `open` → `design` → `ready` → `in_progress` → `done` / `wont_fix` / `pending_recurrence` |
| **Slice** | Proposed V3 §12 tag when implementation is scheduled |
| **Evidence** | Log excerpt, playtest steps, or failing test name |

When an item is **done**, move acceptance criteria into V3 (or archive note) and set status `done` here with link to test / commit.

**`pending_recurrence`:** investigated in good faith (repro attempted, hypotheses tested) but not reproduced and not root-caused — neither provably fixed nor actionable right now. Distinct from `open` (there's a known next step to take) and from `watch` (an accepted design trade-off being monitored for a *specific* future trigger condition, R1-style). A `pending_recurrence` item has no next step until it recurs — when asked "what's left to work on," treat it as **not** investable time; revisit only if new evidence (a fresh repro, a new failure mode) shows up.

---

## Inventory

| ID | Title | Status | Slice |
|----|-------|--------|-------|
| [C1](#c1-pursuit-contact-geometry-stall-fox) | Pursuit contact geometry stall (fox) | `done` — headless green; duel-validated via accumulated live pursuit evidence 2026-08-06 | `post-6d-approach-geometry` (shared) |
| [C2](#c2-locale-food-approach-oscillation-rabbit) | Locale food approach oscillation (rabbit) | `done` — same-tick clamp fix shipped, headless green; duel-validated via accumulated live-play evidence 2026-08-06 | `post-6d-approach-geometry` (shared) |
| [C3](#c3-prey-contact-without-eat--body-pin-stall-fox) | Prey contact without EAT / body-pin stall (fox) | `done` | `post-6d-prey-eat-contact` |
| [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression) | Stale `instance_id` lookups crash memory adapter diet filter (headless regression) | `done` | unassigned |
| [C5](#c5-stale-test-vs-6e-executor-refactor-contract-seek_wall_filter_and_backtrack) | Stale test vs 6e executor refactor contract (`_test_seek_wall_filter_and_backtrack`) | `done` | unassigned |
| [C6](#c6-newly-exposed-locale-consult-precedence-gap-memory_tier_precedence) | Newly exposed locale-consult precedence gap (`_test_creature_motor_stack_memory_tier_precedence`) | `done` | unassigned |
| [C7](#c7-flaky-headless-assertions-nondeterministic-across-identical-runs) | Flaky headless assertions (nondeterministic across identical runs) | `pending_recurrence` — replay-fixture flake + a second flaky test both fixed 2026-08-06/07; memory-tier-precedence flake not reproduced in 39 runs, no next step until it recurs | unassigned |
| [C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) | Stable pre-existing test failures found during R1 mitigation #2 audit | `done` — 13/13 fixed | unassigned |
| [C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) | Flee-waypoint latch corrupted by reactive backtrack deflection (rabbit stuck at playfield edge) | `in_progress` — 7th fix (flee-to-origin sentinel bug) shipped 2026-08-07, 6/6 clean headless runs on the C9 check specifically; not formally closed pending more repro budget | unassigned |
| [C10](#c10-fox-ends-up-under-the-geography-after-close-contact-with-prey-new-2026-08-05) | Fox ends up under the geography after close contact with prey | `fixed` — boulder-seam cause fixed 2026-08-06 (convex obstacle collision); terrain-only tunneling cause fixed 2026-08-06 (`safe_margin` on creature bodies); recurred 2026-08-07 (same family, margin insufficient at speed), re-fixed by bumping `safe_margin` 0.06→0.15, 10/10 clean post-re-fix runs | unassigned |
| [C11](#c11-goal-hub-incumbent-flip-flops-find_foodresetavoid_hostiles-on-single-tick-threat-sampling) | Goal hub incumbent flip-flops (`find_food`/`rest`/`avoid_hostiles`) on single-tick threat sampling | `done` — recurred 2026-08-12 under randomized spawn via a distinct facing-cone mechanism, re-fixed (vigilance ghost) | unassigned |
| [C12](#c12-run_allgd-full-suite-run-aborts-test_motor_locale_approach_no_oscillation_smoke-trips-the-c10-airborne-invariant) | `tests/run_all.gd` full-suite run aborts: `_test_motor_locale_approach_no_oscillation_smoke` deterministically trips the C10 airborne/off-floor invariant (rabbit, tick 91) | `done` | unassigned |
| [C13](#c13-rabbit-freezes-permanently-after-first-bite-of-a-shrub-find_food-live-target-never-goes-stale--legacy-player-pickup-latch-never-releases) | Rabbit freezes permanently after eating a shrub once — `find_food` never retargets a depleted live target, and a legacy proximity-pickup latch keeps it permanently unready | `done` | unassigned |
| [C14](#c14-test_motor_pursuit_pinch_detour_smoke-fox-trips-the-c10-airborne-invariant---not-the-c12-family) | `tests/run_all.gd`: `_test_motor_pursuit_pinch_detour_smoke` (fox) trips the same C10 airborne invariant as C12 | `done` | unassigned |
| [C15](#c15-rabbit-slowly-starves-in-an-eatwander-to-a-phantom-locale-anchorreturn-loop-rabbit) | Rabbit slowly starves cycling eat → wander to a phantom locale-memory anchor → return, forever | `done` | unassigned |
| [C16](#c16-flee-waypoint-overshoots-the-playfield-boundary-instead-of-clamping-to-the-reachable-distance) | Flee waypoint overshoots the playfield boundary instead of clamping to the reachable distance | `done` | unassigned |
| [C17](#c17-flee-waypoint-reach-scoring-mismatched-its-own-straight-line-projection-near-a-boundary-corner-rabbit-spins-then-fails-to-strafe-past) | Flee-waypoint reach scoring mismatched its own straight-line projection near a boundary corner | `done` | unassigned |
| [C18](#c18-eat-completes-through-a-solid-the-eater-physically-cant-pass-straight-line-range-only-no-reachabilityocclusion-check) | EAT completes through a solid the eater physically can't pass (straight-line range only, no reachability/occlusion check) | `done` | unassigned |
| [C19](#c19-motoractionrest-unreachable-from-select_action-a-winning-rest-cycle-reads-as-stay) | `MotorAction.REST` unreachable from `select_action` — a winning REST cycle read as `STAY` | `done` | unassigned |

**Shared slice:** C1 and C2 are the same failure family — a **fixed `step_goal` with poor approach geometry** and **no progress escalation**. They ship in **one slice** (`post-6d-approach-geometry`) via a shared executor foundation, with goal-specific tails. See [Shared implementation plan (C1 + C2)](#shared-implementation-plan-c1--c2).

**C3** is a **separate** eat/contact failure (bodies jam without `EAT`) — do **not** schedule as Pass 4; see [C3](#c3-prey-contact-without-eat--body-pin-stall-fox).

**Standing architecture risk:** C1–C5 (and most of C2's residuals) are all symptoms of one underlying shape — see [R1 — one action per tick + turn-first alignment](#r1--architecture-risk-one-action-per-tick--turn-first-alignment) — tracked separately since it's a design-level trade-off, not a single fixable bug.

---

## R1 — Architecture risk: one action per tick + turn-first alignment

**Status:** `watch` — mitigation #1 shipped 2026-07-15, mitigation #2 shipped 2026-07-16; not scheduled to escalate to the fallback  
**Spec anchor:** [CREATURE_MOVEMENT_V3.md §14.1.1](CREATURE_MOVEMENT_V3.md) — "Facing-relative + one action/tick... `accepted`, Product bet vs V2 single-tick cardinal pick."

### The trade-off

Every tick, the planner selects exactly one of `{TURN_LEFT, TURN_RIGHT, MOVE_FORWARD, EAT, STAY}`, and `align_and_move` gates `MOVE_FORWARD` behind a facing cone — turn-then-move, never both in the same tick. This is a deliberate, accepted product bet (§14.1.1): it keeps the action vocabulary discrete and cheap to cost/log/balance (calories per action, action-economy comparisons like C3's "predator turn+EAT vs prey turn+MOVE").

The cost: it's the direct root of the overshoot / orbit / turn-storm bug family that has consumed the bulk of the `post-6d-approach-geometry` (C1/C2) and `post-6d-prey-eat-contact` (C3) cleanup effort, plus the reactive-only backtrack contract underlying C5. A creature can't make a small heading correction *while* closing distance — it either commits to a full move burst against a fixed `step_goal` (risking overshoot) or stalls turning in place (risking orbit). Each fix shipped this month (overshoot guard, step-goal-jump turn-first, pursuit-detour latch, EAT facing-arc widening, `pursuit_detour_latch_ticks` retunes 16→32) has been a band-aid for a new instance of this same shape, not a fix to the shape itself. As more goals ship, this class of bug is expected to keep recurring.

### Near-term mitigations (try first, additive to current architecture)

1. **Arrival damping** — taper `MOVE_FORWARD`'s executed distance as the creature nears `step_goal` (steering's "arrival" behavior, applied only to the last portion of a move) instead of always covering a full `max_speed × delta` burst. Targets overshoot directly; keeps the discrete action vocabulary and action-economy balance untouched.
2. **Blend turn+move in one tick** — let a single action carry both a bounded turn delta and a move delta (tank/car-style) instead of requiring full cone alignment before `MOVE_FORWARD` is legal. Targets turn-storm/orbit directly; still discrete-tick and still logs one action per tick, but changes the turn/move cost split and needs re-balancing against the C3 action-economy assumptions.

### Fallback: continuous local controller (if 1 & 2 don't break the loop)

If arrival damping and turn+move blending both ship and the same bug family (overshoot / orbit / turn-storm) keeps recurring as new goals are added, that recurrence is itself the signal that the fixed-`step_goal` + discrete-action model has hit a structural ceiling rather than needing another parameter retune. At that point, escalate to:

**Hybrid discrete-goal / continuous-controller split** — keep the hub/planner's discrete goal selection (`step_goal`, objective, action costs, calorie accounting, per-tick logging) exactly as-is, but replace `align_and_move`'s discrete action selection with a continuous local controller (seek + arrival + simple avoidance, Reynolds-style steering) that outputs velocity/angular velocity every physics tick toward the current `step_goal`. This is the option that actually resolves "fixed-step/latch model fighting a continuous approach problem" rather than adding another discrete band-aid (detour latch, no-progress counter, orbit-break-after-N-revolutions, ...).

**Not chosen as a first move because:** the "one action per tick" abstraction is load-bearing well beyond the executor — calorie costs, the replay-capture/explore-log instrumentation, and most of `tests/run_all.gd` assert a specific discrete action per tick. This is a V4-scale rewrite of the executor layer and its test surface, not a cleanup-slice change. Full replacement of the discrete action vocabulary itself (not just the executor) was considered and rejected for the same reason, plus it would force a redesign of action-economy balance (calories/action → calories/second or similar) that touches decisions already signed off in C3.

### Mitigation #1 shipped (2026-07-15): arrival damping

Replaced the position-based overshoot clamp with pre-emptive speed tapering:

- **Removed** `LocomotionExecutor._clamp_overshoot_to_goal` (post-hoc: let the body travel at full speed, then snap it back onto the approach line if it crossed the goal). It was fighting `motor_planner.gd`'s own fixed-objective overshoot remint (`_maybe_apply_fixed_objective_overshoot`) — that remint only reminds `step_goal` when it detects the body *passed* the goal, which the hard clamp made almost impossible to ever observe (position was already snapped back before the remint check ran).
- **Added** `LocomotionExecutor._arrival_damping_frac(dist_to_goal, motor_v3)` — linearly tapers `MOVE_FORWARD` speed from full down to `_ARRIVAL_DAMPING_MIN_SPEED_FRAC` (**0.35**) as `dist_to_goal` closes inside `approach_arrival_damping_radius` (new `motor_v3` default, **2.5** world meters — independent of `eat_action_max_distance`/`arrival_tolerance`, not EAT-specific). Implemented by scaling the movement intent vector's magnitude rather than adding a new parameter to `apply_horizontal_move_intent` — a sub-unit-length intent already reads as partial thrust there (`creature_kinematic_body_3d.gd`), so this reuses an existing seam instead of touching the real-body movement contract.
- **Goal-agnostic by construction**: damping is keyed off `dist_to_goal`, computed once in `align_and_move` (the sole source of `MOVE_FORWARD`, confirmed via `grep`) regardless of which goal kind produced the step — not gated to EAT/find_food. `MOVE_BACKWARD` (orbit-break, retreat) is explicitly excluded (no meaningful "goal" to damp toward).
- **`dist_to_goal` threaded up the chain**: now planner-owned state (`state["dist_to_goal"]`, set in `align_and_move`, read by `creature_motor_stack.gd` to hand to the executor) rather than recomputed inside the executor from a raw `step_goal` position. Intentionally **not** wired into `_can_eat_now` / `_at_arrival` / other existing distance checks this pass — those already have their own tolerance semantics (EAT range vs. general arrival) and didn't need to change to fix overshoot. Left as a natural follow-up for when a range-gated goal (e.g. ranged combat) actually lands and needs a shared "how far to the current objective" read.

**Tuning decisions called out (not derived, chosen and verified safe against existing thresholds):**

- `approach_arrival_damping_radius = 2.5` — no strong constraint from the code; picked as a modest fraction of the existing `arrival_tolerance`/`eat_action_max_distance` default (5.0) so the final approach visibly decelerates before arrival is even declared, without damping for most of that band. Not tuned from duel evidence — a starting point.
- `_ARRIVAL_DAMPING_MIN_SPEED_FRAC = 0.35` — **checked against** `motor_stuck_move_epsilon`'s implied per-tick progress fraction (~0.19 of a full-speed tick at defaults, `motor_planner.gd` `_latched_stuck_move_epsilon`). At 0.35 the minimum damped displacement stays ~1.87× that threshold regardless of `max_speed` (both terms scale linearly with speed), so a damped final approach still registers as progress for `precise`/`locale` no-progress tracking (`_note_fixed_objective_position_progress`) and won't falsely trigger §9 escalation near the goal. **If `motor_stuck_move_epsilon` is ever retuned larger, re-check this margin.**

**Verified (headless):** confirmed the suite has **run-to-run flakiness** independent of this change — 3 specific assertions (`_test_motor_replay_fixture_drives_stack_from_capture`'s "closes on the captured prey trajectory", `_test_creature_motor_stack_memory_tier_precedence`'s "coarse beats locale when precise absent" and "locale consult when no instance beliefs") intermittently pass/fail across identical back-to-back runs of the *same* code — not yet root-caused, not caused by this change (reproduced on pre-R1 code via `git stash` isolation). Controlling for that: 4 consecutive runs each of pre-change and post-change code (matched via `git stash`) produced **byte-identical failure sets** (13 assertions, same names) in every run. No regression.

### Regression found and fixed (2026-07-15): live-pursuit damping asymmetry

Duel smoke run immediately after shipping mitigation #1: `winner=herbivore cause=starvation_carn_herb_win` — fox starved (0% calories) chasing the rabbit, despite a **600-tick window** (`t≈2600–3200`) of near-perfect bearing alignment (avg bearing error 0.0–0.2°) — i.e. driving straight at the rabbit the whole time and never reaching `EAT`. Confirmed via `hunter_killer.log` this was **not** the classic overshoot signature (searched all of today's real duel pursuit ticks for the `dot < 0` "target flipped behind" tell that motivated mitigation #1 in the first place — zero occurrences, vs. it appearing repeatedly in duels from 07-11/07-13/07-14 and in headless test runs pre-fix).

**Root cause:** damping is keyed off each creature's own `dist_to_goal`, but that means something different for predator vs. prey:
- **Fox** (`find_food`, `step_source == "live"`): `step_goal` is the rabbit's live position — `dist_to_goal` genuinely shrinks as the fox closes, so damping engages exactly during the final approach.
- **Rabbit** (`avoid_hostiles`, Flight): also routes through `align_and_move` (`_select_flight_action` → `_locomote_toward_step_goal`, [motor_planner.gd:1740](../../creature/motor/motor_planner.gd)), but its `step_goal` is a flee waypoint `awareness_radius × 0.5` (75m) out (`_flee_objective`) — never within the 2.5m damping radius of *its own* goal, so it never damps.

Fox `max_speed` 7.0 vs. rabbit `max_speed` 6.0 — only a 17% edge. The 0.35 damping floor drops the fox's effective speed below the rabbit's once within ~1.95m (`lerp(0.35, 1.0, dist/2.5) × 7.0 = 6.0` → `dist ≈ 1.95`). Predator throttles down right where it needs speed most; prey keeps full speed; gap stabilizes just outside catch range instead of closing.

**Fix:** exclude `step_source == "live"` from arrival damping in `creature_motor_stack.gd` (the executor only receives `dist_to_goal` — and therefore only damps — when the current step source is a fixed/latched objective: `precise` / `locale` / `memory_moving`). `state["dist_to_goal"]` itself is still computed and stored every tick regardless of step source (still available for future range-gated consumers per the original design intent) — only what gets **handed to the executor for damping** is gated. Mirrors the identical `live`-exclusion already applied to the overshoot remint (`_is_fixed_objective_overshoot_source` in `motor_planner.gd`) and for the same stated reason: a continuously-retargeting moving-prey goal isn't a point you decelerate into.

**Verified (headless):** 3 consecutive runs post-fix produced byte-identical failure sets to the established 13-assertion baseline — no regression. **Duel re-verification pending** (manual smoke, per §14.2.7 — no headless duel harness exists yet).

### Reproduction (2026-07-16 duel log): mitigation #1 alone didn't close the loop

Manual duel smoke after mitigation #1 + the live-pursuit fix still ended `starvation`: fox never reached `EAT` (0 `act=EAT` lines, `motor_explore_tick.log`), calorie ratio decayed monotonically 11%→0% over the captured window, and `dist_to_goal` bottomed out at **0.00** (contact) at `t=3374` while `dist < 0.5` on 210 of 400 logged fox ticks — the fox was repeatedly on top of the rabbit but never ate. Root cause caught in the log: at `t=3374` the fox overshoots straight through the rabbit's position with a frozen heading (`dot` flips from `0.993` to `-0.872` in one tick — the target is now behind it, not the facing being wrong), then the planner keeps issuing `MOVE_FORWARD` for ~10 more ticks while `dot` stays pinned near `-1.000` (facing dead away from the target) before finally turning to recover — the textbook R1 shape: a fixed heading committed for a full move burst against a continuously-retargeting live point.

### Mitigation #2 shipped (2026-07-16): blend turn+move in one tick

- **Widened the `MOVE_FORWARD` gate** (`motor_planner.gd` `align_and_move` / new `_is_within_move_blend_arc`): legal whenever heading error is within new `move_blend_max_error_deg` (default **60°**) instead of the tight `turn_increment_deg` (22.5°) cone. `_is_facing_aligned_for_move`'s tight cone is untouched and still gates `_run_path_clearance_los_nav`'s LOS/nav substep — only action *selection* widened.
- **Executor blends a bounded turn into the move** (`locomotion_executor.gd` new `_blend_turn_toward`, called from `apply_action` before `_displace_along_facing` on `MOVE_FORWARD`): rotates `last_move_direction` toward the tick's target by up to one `turn_increment_deg`, clamped to whatever fraction of a full increment closes the remaining error, then moves along the corrected heading — tank/car-style, still one discrete action per tick. Signed rotation solved directly (`atan2(-cross, dot)`, clamped) rather than reusing `motor_planner.gd`'s left/right-pick helper, verified against `_rotate_facing`'s `TURN_LEFT` sign convention by hand.
- **Threaded from `creature_motor_stack.gd`**: `step_goal` passed as the new `move_turn_target` param on every `MOVE_FORWARD` tick, **including `step_source == "live"`** — the opposite gating from arrival damping's live-exclusion. Blending a bounded heading correction into the move is exactly what stops a continuously-retargeting live pursuit from committing to a stale heading and overshooting through the target; damping's live-exclusion (which throttles speed) and this one (which corrects heading) address different halves of the same asymmetry.
- **No action-economy rebalancing needed**: `motor_action.gd::calorie_cost_for` already charges `TURN_LEFT`/`TURN_RIGHT`/`MOVE_FORWARD` the identical `move_calorie_per_sec` rate — blending doesn't create a cheaper combo relative to the old turn-then-move sequence, so the C3 action-economy comparisons the doc flagged as a risk are unaffected.
- `move_blend_max_error_deg = 60°` chosen (not derived from duel evidence) to guarantee positive forward progress at the arc's edge (`cos 60° = 0.5`) and to stay clear of `eat_facing_arc_deg`'s 90°-off `_test_motor_align_cone_contract` fixture without needing to touch that test.

**Test surface impact:** 3 pre-existing tests hard-coded the old tight-cone contract by name/threshold (`_test_motor_planner_explore_rear_hemisphere_no_flip_flop`'s "rear explore MOVE when within turn increment cone", `_test_motor_planner_flight_close_range_converges_and_displaces_away`'s "flight close range: aligned MOVE_F within 12 ticks", `_test_motor_planner_flight_flee_waypoint_orbit_stable`'s "orbit flight: at least one aligned MOVE_F") — updated their `move_min_dot` reference from `turn_increment_deg` to `move_blend_max_error_deg` to match the intended new contract; behavior asserted (facing must be within the legal-move arc when `MOVE_FORWARD` fires) is unchanged, just the arc width.

**Verified (headless):** isolated mitigation #2's specific impact by temporarily reverting just its 4-file diff (not a full `git stash`, which would have also reverted mitigation #1's still-uncommitted work) — confirmed a **pre-existing 13-assertion failure set** exists in the working tree with mitigation #2 fully reverted, byte-identical across repeated runs. This set is **different from** the 13-assertion flaky baseline documented above (that one names `_test_motor_replay_fixture_drives_stack_from_capture` / `_test_creature_motor_stack_memory_tier_precedence`; this one names `explore_dir seeds from body facing`, `MOVE_FORWARD against wall sets blocked`, `belief north of origin...`, etc. — no overlap) and appears **stable, not flaky** (identical across 3 consecutive runs) — likely drift from the machine moves this session (`moving to laptop` / `moving downstairs` commits) or leftover WIP, not caused by any R1 mitigation. **Not investigated further** (out of scope for this slice) — flagging here since it affects future before/after headless comparisons the same way C7 does. With mitigation #2 applied, 3 consecutive runs reproduced this exact same 13-assertion set with zero net-new failures — confirmed via a real regression first (16 failures before the 3 pinned tests above were updated), so this isn't a case of the diff silently matching a pre-broken suite.

**Duel re-verification pending** (manual smoke, per §14.2.7 — no headless duel harness exists yet). Next duel should re-check the `motor_explore_tick.log` `dist_to_goal`/`dot` pattern from the reproduction above (overshoot-through-target with a frozen heading) for recurrence.

### Acceptance (for revisiting this decision, not for shipping now)

- [x] Ship near-term mitigation #1 (arrival damping) as its own slice — **2026-07-15**.
- [x] Ship near-term mitigation #2 (turn+move blend) — **2026-07-16**.
- [ ] After both ship, track whether new overshoot/orbit/turn-storm instances still appear as new goals are added (next candidate: any post-6d goal beyond find_food/Flight).
- [ ] If yes — treat as confirmed signal, scope the continuous-local-controller hybrid as a deliberate slice (not a reactive patch) with its own design pass, not folded into an existing C-item.
- [ ] If no — close this item `wont_fix` with a note citing which mitigation(s) actually closed the loop.

---

## C1 — Pursuit contact geometry stall (fox)

**Status:** `done` — marked done 2026-08-06 on accumulated live-duel evidence rather than a dedicated rock-pinch repro (see "Duel validation" below).  
**Slice:** `post-6d-approach-geometry` (shared with C2; separate from post-6d Flight P2–P4)  
**Evidence:** Duel playtest **2026-07-10** — rabbit flee OK (`ff=1`, flee waypoint latch); fox closes on prey then **stalls** with repeated `MOVE_F` + `blk=1`, never `TURN_*` / `STAY`. Log: `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` (~t=3292+). `src=live`, `find_food`, prey id latched, `ff=0` (D1 correct — prey ≠ Flight threat).

**C1 residual (2026-07-14):** Duel ended `winner=none` / `end_ai`. Rolling motor window **t=2804–3203**: fox 400/400 `src=live`, `find_food`, `food=1`; **259** `MOVE_F`, **141** turns, **26** `blk=1`; recurring blocked `MOVE_F` with heading error roughly **−50° to −80°**; prey GPS clustered around **(28–31, 97–100)**; **0** `EAT`, **0** `MOVE_BACKWARD`; fox calories **22%→11%**. This is a **C1 obstacle/pinch residual after Pass 3** — sticky detour vs live remint — **not** the earlier open-field no-turn trail case (C3 family; C3 closed).

### Symptom

1. Carnivore wins `find_food` with **live prey** in zone; `prey_engagement_latch` holds identity.
2. Direct LoS / corridor to prey **blocked** by static obstacle (rock).
3. After first block: `step_goal` jumps sideways; snapshot shows large heading error (`err≈-62°`, `dot≈0.47`).
4. Loop: `cblk` increments → §9 `blk_act=seek` → one tick `src=explore` / `tgt=(0,0)` → back to live with bad geometry.
5. Fox never emits turn actions; only forward into wall.

**Not in scope:** Flight / flee waypoint latch (post-6d P2–P4) — rabbit egress path verified.

### V3 model (no hub sub-goals)

Per §3 single-winner: “go around rock” is **not** a new hub goal. It is a **substep** under winning `find_food`:

- §3.1 `MotorPathClear.resolve_step_objective` (nav substep)
- §3.2 backtrack / `apply_immediate_blocked_path_reevaluation`
- Latch **pattern** from `explore_waypoint` / `flee_waypoint` (hold detour waypoint; do **not** reuse explore bearing picker)
- `prey_engagement_latch` for prey identity continuity (already shipped post-6d-explore-prey)

### Proposed fix (design)

C1-specific tails on top of the [shared foundation](#shared-implementation-plan-c1--c2) (Layers 1–2):

1. **Gate §9 `seek`** while `prey_engagement_latch_valid` **and** live prey still visible — do not drop to explore-at-origin for one tick. **Resolved:** §9 seek **remains available** when prey is **ghost-only** (belief, no live LoS) — the gate applies **only** while live prey is in the zone.
2. **Pursuit detour substep latch** — mint waypoint from navmesh first segment or backtrack candidate; hold for **`pursuit_detour_latch_ticks`**. **Resolved:** mirror **`flee_waypoint_latch_ticks`** — default **16**.
3. **Align after blocked reeval** — folded into **shared Layer 1** (step-goal-jump turn-first + overshoot guard). When `step_goal` changes materially or the creature passes the goal, force `TURN_*` before `MOVE_F` regardless of stale facing.

### Follow-up plan (locked) — C1 residual 2026-07-14

Pass 3 shipped detour latch + §9 gate; duel pinch residual shows **live prey refresh overwriting the active detour substep** and/or **reminting the same detour every blocked tick**. Primary fix is **sticky pursuit detour vs live remint**, with light latch-duration tuning:

1. **Sticky detour `step_goal`** — while `pursuit_detour_waypoint` latch is valid, it remains **authoritative** as `step_goal`. Per-tick live prey refresh updates **only** `step_ultimate_pos`, prey instance/kind, and engagement latch. Live refresh **must not** overwrite the detour substep.
2. **No per-block remint** — do **not** remint the same detour on every blocked tick. Remint only on a **materially new** blocked reevaluation, **latch expiry**, or **detected failure/no-progress** of the active detour.
3. **Alternate detour on persistent block** — if blocked/no-progress persists while latch is active, mint a **fresh** nav/backtrack detour (prefer an **alternate side** where existing APIs permit) while retaining the live prey ultimate; do **not** fall back to explore-at-origin while prey remains live.
4. **Latch duration tuning** — raise `pursuit_detour_latch_ticks` from **16** to an initial **32** for the next implementation/playtest. This is **tunable** and may move to **48** if 32 is insufficient. Tuning **supports** the structural fix; it does **not** substitute for it.
5. **Preserve §9 gate** — live visible + engagement latch still suppresses seek/explore fallback ([C1 §9 gate](#resolved--layer-3-tails-locked-for-pass-34)); ghost-only prey behavior unchanged.
6. **Deferred (out of slice)** — optional live pass/reopen recovery (distance-to-prey starts increasing after closing) only if open-field walk-past recurs **after** detour fix lands. Do **not** include in this slice.
7. **Explicitly avoid** — hitbox kills (D11); new hub goal for detour; widening `EAT` beyond **5 m**; solving solely by reducing rocks.

### Acceptance (draft)

- [x] Headless: [C1 smoke fixture](#smoke-test-engineering-complex-geometry) — fox reaches within `action_max_distance` of prey without `cblk` runaway or explore fallback while prey live (`_test_motor_pursuit_pinch_detour_smoke` green; unaffected by the C2 same-tick clamp fix — full-suite diff shows no new failures).
- [x] Headless: while `pursuit_detour_waypoint` latch is valid, per-tick live prey refresh updates `step_ultimate_pos` / engagement latch **without** overwriting detour `step_goal` (`_test_motor_planner_pursuit_detour_sticky_live_refresh`).
- [x] Headless: repeated blocks against an **active** detour mint a **fresh** detour (or alternate-side nav/backtrack) — **not** live substep overwrite and **not** explore-at-origin fallback while prey live (`_test_motor_planner_pursuit_detour_skips_reeval_while_latched`, `_test_motor_planner_pursuit_detour_alternate_on_persistent_block`).
- [x] Duel manual: fox clears an **interior pinch** and resumes chase (same session as rabbit flee / locale patch). **Closed 2026-08-06 via accumulated evidence, not a dedicated repro** — see "Duel validation" below.
- [x] No regression: post-6d Flight tests (A/B/C) and flee latch still pass — full-suite headless re-run during the C10/EAT-range work this session showed only the same 6 pre-existing unrelated failures.

### Duel validation (2026-08-06)

No dedicated "walk the fox into a rock on purpose" repro was run. Marked `done` instead on the strength of several recent live duel sessions (the C10 terrain-tunneling investigation and the fox-can't-close/EAT-range investigation, both same day) that exercised the real pursuit path end-to-end — live prey, real obstacle geometry, real navmesh — with **no** instance of the C1 symptom (`MOVE_F blk=1` stall into an obstacle with no turn recovery). The EAT-range fix in particular required the fox to successfully close through real duel geometry to reach the prey at all, which wouldn't have been observable if C1's pinch-stall were still live. If the pinch-stall resurfaces in a future duel, reopen this item rather than filing a new one.

### Open questions

_Resolved 2026-07-10:_ `pursuit_detour_latch_ticks` = **16** (mirror flee) for Pass 3 ship. _Resolved 2026-07-14 (C1 residual):_ sticky detour vs live remint plan locked; initial retune **32** (may move to **48**). §9 seek **stays available** for ghost-only prey. No open questions.

---

## C2 — Locale food approach oscillation (rabbit)

**Status:** `done` — marked done 2026-08-06 on accumulated live-duel evidence (rabbit food approach unremarkable across multiple recent sessions); residual #3 (2026-08-05) never reproduced again and its temporary debug tracing was removed. See "Duel validation" below.  
**Slice:** `post-6d-approach-geometry` (shared with C1; herbivore memory-seek tail)  
**Evidence:** Duel playtest **2026-07-10** (session ~16:00) — after live bush seek at `(32.2, 65.0)`, rabbit hub retargets to **locale prior** `(26.0, 78.0)` at **t≈2201** (`src=locale`, `w≈0.294`). From **t≈2366** through session end (**t≈2617**): repeating **TURN_*** sweep → **`MOVE_F` with `err≈±137°`–`180°`** (`dot` negative) while `blk=0`, `cblk=0`, `ff=0`, `thr=0`. Log: `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` (rolling tail t=2218+) and `hunter_killer.log` (`MotorExplore` DEBUG lines).

**C2 residual (2026-07-14 ~10:34–10:35 UTC):** Pass 1–4 shipped, but duel still showed rabbit live bush `(32.2, 65)` → locale `(26, 78)` → **overshoot spin for hundreds of ticks** (`food=0`, 0 `EAT`, rear-hemisphere `MOVE_F`). Root cause: Layer 1 overshoot remint **reset** `locale_no_progress_ticks`, starving Layer 2 so §9 never fired while the orbit continued. **Design lock:** retain progress counters on overshoot remint — see [Response #3](#resolved--overshoot-guard-layer-1) (supersedes 2026-07-13 reset rule). Pass 4 empty-locale clear remains correct; progress retention is the Layer 2 escape hatch if orbit keeps the creature outside `eat_action_max_distance` or locale remints after clear. Verify sticky clear separately if remint-after-clear still observed.

**C2 residual #2 shipped (2026-07-14, same-tick clamp):** `_test_motor_locale_approach_no_oscillation_smoke` was still red after the progress-retention fix above — headless replay of the fixture and a fresh `motor_explore_tick.log` capture both showed the same rear-hemisphere flip (`err` jumping from ~`-19°` to `+154°` in one tick) at ranges the reactive Layer 1 remint (2-move-step close band, sub-meter at typical speeds) never reaches. Root cause: `LocomotionExecutor._displace_along_facing` moves the body via acceleration/friction (`apply_horizontal_move_intent`) and never checks remaining distance to `step_goal` — a single aligned `MOVE_FORWARD` can travel straight through a near anchor, flipping the bearing to the rear hemisphere before any next-tick remint has a chance to react. **Fix:** [`LocomotionExecutor.apply_action`](../../creature/motor/locomotion_executor.gd) now accepts an optional `step_goal` and, after a `MOVE_FORWARD`, `_clamp_overshoot_to_goal` snaps the body back onto the goal (and zeroes horizontal velocity) if displacement carried it past the goal along the pre-move approach line — same tick, before any bearing flip can occur. [`creature_motor_stack.tick`](../../creature/motor/creature_motor_stack.gd) threads `_planner_state.step_goal` through when the selected action is `MOVE_FORWARD`. This supersedes relying solely on the reactive Layer 1 remint (which still runs for the next-tick case where nav-substep resolution is needed after a real overshoot). Headless: `_test_motor_locale_approach_no_oscillation_smoke` green; full-suite diff against pre-change baseline shows **zero new failures** (only the two C6 asserts flipped green, same 13 pre-existing/unrelated failures remain).

**C2 residual #3 (2026-08-05, live re-repro, still open):** User's manual smoke testing hit this again — same anchor class, `motor_explore_tick.log` tail showed rabbit `src=locale tgt=(26.0,78.0) dist≈0.00–0.01 food=0 cblk=0` oscillating `TURN_*`/`MOVE_F` continuously (`err` cycling through a repeating 4-tick pattern, never settling). Two hypotheses investigated and **ruled out** via direct headless instrumentation (not guessed):
- Built an isolated repro (`CreatureMotorStack.tick()` with a herbivore body spawned already-arrived on a seeded empty locale anchor) with debug prints wired into `_maybe_locale_arrival_bind_or_clear` and `_sync_food_memory_objective`'s locale branch. **Result: the arrival-clear + 90-tick revisit-cooldown mechanism (`_locale_anchor_on_arrival_cooldown`) worked correctly** — cleared the empty anchor on tick 0 and held `explore` for the full cooldown window. So the mechanism is not broken in isolation.
- Suspected the locale anchor itself (a rank-weighted centroid over nearby memory rows, not a fixed point, per `project_believed_goal_bias`) might drift tick-to-tick by more than the cooldown's 1-unit match tolerance and dodge the "don't re-pick what we just cleared" guard. Tested directly with two competing memory rows and a fixed creature position: **the returned anchor was bit-identical across 8 repeated calls.** Not the cause either.
- Conclusion: the arrival-clear mechanism works given the exact inputs tried so far, but something about the *live* scenario differs from both synthetic repros in a way not yet identified (richer memory history? a different code path into `step_source == locale` that skips `_apply_locale_food_objective`'s `step_ultimate_pos` assignment? consideration-cadence interaction?).
- **Debug tooling added, currently live in the codebase:** `print()`-based `ARR_DBG`/`SYNCFOOD_DBG` traces in `motor_planner.gd` (`_maybe_locale_arrival_bind_or_clear`, `_sync_food_memory_objective`), now tagged with a per-instance label (`_dbg_label`, e.g. `ARR_DBG [rabbit#116937200019 t=3540] ...`) after a first capture attempt turned out ambiguous (fox and rabbit both write `find_food`-tier locale telemetry and were indistinguishable without a label — see `creature_instance_id` below). **These prints are intentionally temporary** (raw `print()`, no config gate — unlike the permanent `MotorPlannerExploreLog` pattern) and should be removed once this is root-caused, not left in.
- A live capture taken *after* adding the instance label did not reproduce C2 (see [C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) instead) — still open, next live repro should carry the labeled traces.
- **Side effect (permanent, kept):** added `creature_instance_id` (`creature_kinematic_body_3d.gd`, set from `get_instance_id()` in `_ready()`) and wired it into `_creature_log_label()` (`creature_motor_stack.gd`) — the existing, shipped label function that feeds `motor_explore_tick.log` / replay capture. Motivated by needing to disambiguate creatures of the same species once there's more than one alive at a time (currently the game only spawns one herbivore + one carnivore, so this hasn't mattered until now).

**Not in scope:** Flight / flee waypoint latch (post-6d P2–P4); carnivore live-prey pursuit (C1). This run showed `avoid_hostiles` early but **no `ff=1`** — stall is **not** threat egress.

### Symptom

1. Herbivore wins `find_food`; live bush exhausted or deprioritized → planner consults **locale prior** (`adapter.consult_locale_seek`).
2. `step_source = locale`, `step_goal` = nav-resolved anchor (playtest `tgt=(26.0, 78.0)`).
3. Creature **approaches** (initial `err` ~+15°–+22°, then brief aligned `MOVE_F` at `dot≈1`).
4. Near anchor: **one `MOVE_F` while nearly 180° off** (`err≈-177.7`, `dot≈-0.999` at t=2366) — §7.3.0 cone violated.
5. Loop for hundreds of ticks: 5–7 `TURN_*` to re-align → `MOVE_F` with `err` flipped to rear hemisphere (`≈-137°` or `≈+145°`) → repeat. **No position progress**; calories drain (80% → 69% in tail window).

**Distinct from C1:** no collision block (`blk=0`), no §9 `blk_act=seek` explore fallback, no carnivore `prey_engagement_latch`. Failure is **`align_and_move` + locale step lifecycle**, not rock-blocked live pursuit.

### Root cause (design hypothesis)

| Gap | Detail |
|-----|--------|
| **`locale` not latched** | [`_is_latched_step_source`](../../creature/motor/motor_planner.gd) includes `precise` / `explore` / `memory_moving` only — **`locale` omitted**. No `precise_no_progress_ticks` / explore idle stuck replan / §9 escalation while spinning on a fixed anchor. This is the **primary** gap. |
| **Overshoot, not a live cone violation** | `align_and_move` (`_is_facing_aligned_for_move`) **already** gates `MOVE_F` on `dot ≥ cos(turn_increment_deg)` **at decision time**. The logged `err≈-177°` `MOVE_F` at t=2366 is a **post-tick** snapshot ([`get_debug_snapshot`](../../creature/motor/creature_motor_stack.gd) reads body + `_last_outcome` **after** locomotion): the creature was aligned pre-move, then **passed / overshot** the anchor, flipping bearing to the rear hemisphere. Root fix is an **overshoot guard**, not re-adding a cone check that already exists. |
| **Hub retarget without arrival** | Live → locale switch at t=2201 drops `w` from `1.050` → `0.294` but **same goal kind** — creature may already be near one food site while locale anchor is a **different** grid cell center; no arrival / eat-bind handoff clears locale objective. |

### V3 model (no hub sub-goals)

Per §3 single-winner: fixing “spin at remembered bush patch” is **not** a new hub goal. It is **substep / executor** behavior under winning `find_food`:

- §3.2 latched stuck pattern — add a locale-specific no-progress counter (mirror `precise_no_progress_ticks`) — see [shared Layer 2](#shared-implementation-plan-c1--c2).
- §9 blocked-objective **seek** — when locale approach makes no progress for N ticks, allow switch to explore / another memory tier (same resolver as precise stall).
- Overshoot guard on the executor path — see [shared Layer 1](#shared-implementation-plan-c1--c2).
- Arrival / eat-bind at locale anchor — within `action_max_distance`, bind eat or clear `step_source` (§8.1 live EAT path when bush respawns in zone).

### Proposed fix (design)

C2-specific tails on top of the [shared foundation](#shared-implementation-plan-c1--c2) (Layers 1–2):

1. **Locale stuck detection (Layer 2 wiring)** — treat `step_source == locale` like `precise` for position progress:
   - Increment `locale_no_progress_ticks` when displacement `< motor_stuck_move_epsilon` over a window that includes turn-only ticks **or** rear-hemisphere `MOVE_F`.
   - Escalate to §9 persist/switch/seek when `locale_no_progress_ticks >= dead_end_record_min_blocked_ticks` (default **3**; same as `precise` — no separate locale min-ticks key in v1).
2. **Live → locale handoff scoring** — **Resolved:** when both a **live** bush and a **locale** anchor are candidates, **weight the current (in-range/live) bush** if the two are the **same kind**. If they differ, **score both** and pick the higher **calories-per-`EAT`** target as the next objective (do not blindly latch the memory anchor over a richer live source). Anchors the retarget decision at t≈2201 in a value comparison, not step-source precedence alone.

> **Cone gate note:** the earlier draft proposed “add a cone gate to `align_and_move`.” Code review shows the cone is **already** enforced pre-move; the real defect is **overshoot** (post-move telemetry) + **missing stuck escalation**. The behavioral “no `MOVE_F` with `|err| > turn_increment_deg`” assertion is retained as a **regression contract** in the smoke test, not as new gating logic.

### Acceptance (draft)

- [x] Headless: [C2 smoke fixture](#l1-fixture-layout-locale_orbit) — herbivore reaches within `action_max_distance` of seeded locale anchor without err sign-flip loop or `locale_no_progress_ticks` runaway (`_test_motor_locale_approach_no_oscillation_smoke` green after the same-tick clamp fix).
- [ ] Headless: assert **no** `MOVE_F` **selected** when misaligned at `select_action` time (`|err| > turn_increment_deg` at decision time — not post-tick snapshot; see cone gate note). **Deferred, not blocking:** test-hardening only — the actual overshoot bug this would guard against is fixed and duel-validated; left as a nice-to-have regression contract for whoever next touches `align_and_move`.
- [x] Duel manual: rabbit eats or leaves locale patch — no in-place spin at `(26, 78)`-class anchor after live food session. **Closed 2026-08-06 via accumulated evidence, not a dedicated repro** — see "Duel validation" below.
- [x] No regression (headless): full-suite diff against pre-change baseline shows zero new failures, re-confirmed 2026-08-06 after removing the C2 residual #3 debug tracing.

### Duel validation (2026-08-06)

No dedicated locale-spin repro was run. Marked `done` instead because rabbit food-seeking has been unremarkable across multiple recent live duel sessions (same sessions cited for [C1](#c1-pursuit-contact-geometry-stall-fox)'s duel validation) — no oscillation, no in-place spin, no stalled locale approach observed. Residual #3 (2026-08-05, below) was never reproduced again despite labeled debug tracing left in place specifically to catch it; that tracing (`ARR_DBG`/`SYNCFOOD_DBG` in `motor_planner.gd`) has now been removed. If locale-anchor spin resurfaces, reopen this item rather than filing a new one — residual #3's root cause was never actually identified, only observed to stop recurring.

### Open questions

- **Resolved (latched vs counter):** Use a **separate `locale_no_progress_ticks` counter** (shared Layer 2) — **do not** add `locale` to `_is_latched_step_source`. Rationale: `_is_latched_step_source` today only feeds `note_outcome`'s `consecutive_blocked` semantics; folding `locale` in would change turn-tick reset behavior with no upside, and risks coupling to a future sync path where locale **should** still refresh its nav substep as the creature moves (locale anchors are fuzzier than a `precise` instance GPS). See [shared Layer 2](#shared-implementation-plan-c1--c2).
- **Resolved (one PR):** C1 + C2 ship in **one slice / one PR** (`post-6d-approach-geometry`) with **two** L1 smoke tests. See [Shared implementation plan](#shared-implementation-plan-c1--c2).
- **Resolved (locale stuck threshold):** Reuse **`dead_end_record_min_blocked_ticks`** (default **3**) — same threshold as `precise` for `locale_no_progress_ticks` → §9 escalation. Do **not** add a separate `locale_no_progress_min_ticks` config key in v1; only introduce that sibling if duel smoke shows 3 is too twitchy on fuzzy grid-centroid anchors.
- **Resolved (Layer 2 `live` call site):** **Defer** `live_no_progress` wiring in v1 — C1 is collision-driven (`consecutive_blocked` → §9); Layer 3 (detour latch + §9 gate) is the C1 fix. Revisit only if C1 smoke stays red or logs show `blk=0` live pursuit orbit.
- **Resolved (overshoot guard — Layer 1):** See [Overshoot guard contract](#resolved--overshoot-guard-layer-1) below. **2026-07-14 follow-on:** on overshoot remint for `locale` / `precise`, **retain** `<source>_no_progress_ticks` (do **not** reset) so Layer 2 can escalate §9 under continuous overshoot — see Response #3.
- **Resolved (step-goal-jump materiality):** `dist(old_step_goal, new_step_goal) > motor_stuck_move_epsilon(body, delta)` → set `force_align_turn_before_move`. Same epsilon family as latched stuck detection.
- **Resolved (pursuit detour mint — C1):** **Option A** — after blocked `MOVE_F`, latch detour from `apply_immediate_blocked_path_reevaluation` / `_run_path_clearance_los_nav` output (not a separate nav-first-segment picker).
- **Resolved (C1 §9 seek gate):** **Pre-call short-circuit** in [`creature_motor_stack.gd`](../../creature/motor/creature_motor_stack.gd) when `prey_engagement_latch_valid` **and** live prey visible — skip `apply_blocked_objective_resolution` seek path (ghost-only prey unchanged).
- **Resolved (C2 live↔locale handoff):** Hook in [`_derive_find_food_step_objective`](../../creature/motor/motor_planner.gd); **same kind** = matching `stimulus_kind_id`; **calories-per-EAT** from **live sample fields** until kind-facet objects land; runs **only on re-derive ticks** (`refresh_step_objective`, no `has_step_goal`, inventory flip).
- **Resolved (locale arrival v1):** Within `action_max_distance` at locale anchor → **`EAT`** if bush respawns in zone / bind live food; else **clear** `step_source` / step fields.
- **Resolved (turn-first flag):** `force_align_turn_before_move` checked in **`align_and_move`** before `MOVE_F` — one-shot forced `TURN_*` toward `step_goal`.

---

## C3 — Prey contact without EAT / body-pin stall (fox)

**Status:** `done` (slice `post-6d-prey-eat-contact`)  
**Slice:** `post-6d-prey-eat-contact` (separate from `post-6d-approach-geometry` C1/C2 — **not** Pass 4; schedule after / parallel to Pass 5 duel — see [Shared implementation plan](#shared-implementation-plan-c1--c2))  
**Evidence:** Duel playtest **2026-07-13** — log review of `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` session ending ~**t=3188** (~15:55). Rolling window showed **zero `act=EAT`**, zero fox `STAY`. Fox `find_food` / `src=live` / `food=1` with prey id latched; rabbit continuous `ff=1` flee. Recurring `MOVE_F blk=1` with large `err` (~60–77°) then turn/remint loop. Bodies visually stacked / jammed; no kill. Same-day follow-up duel: open-field orbit flavor (`food=1`, 0 EAT, `blk=0`, mirrored turns, fox starve) — same C3 family as body-pin `blk=1`.

**Sign-off addendum (2026-07-13 ~21:06–21:07 UTC):** Round `winner=carnivore` `cause=predation_carn_win` (herb_cal=30 carn_cal=6). Motor: fox `act=EAT` at **t=3549**, `src=live`, `food=1`, cal jumped 1%→10%. Confirms open-field / chase contact produced V3 EAT kill (not starve orbit).

### Symptom

1. Carnivore closes on live prey (`src=live`, prey engagement latched).
2. Capsules overlap / pin against prey body; fox keeps selecting `MOVE_F` into the block (`blk=1`) with large heading error, then turn/remint — **or** open-field spin/orbit with `blk=0` and no `EAT`.
3. No `EAT` and no fox `STAY` in the window — kill never fires despite contact / proximity.

### V3 contract reminder (bug vs resolved)

Contact / `MobHitbox` predation remains intentionally **inert** (D11). Kill is V3 **`EAT` only** via `_can_eat_now` → `_try_complete_eat` → `try_grant_as_prey_to`.

| | Distance | Facing |
|--|----------|--------|
| **Bug today** | `_can_eat_now` measures to **`step_goal`** (nav substep) and uses a tight facing gate (`0.5 × turn_increment_deg` ≈ ±11.25°) | Misses when capsules overlap prey ultimate but substep/facing fail |
| **Resolved contract** | Distance to **`step_ultimate_pos` / live food ultimate** (prey body or plant pos), in **world meters**: `dist ≤ eat_action_max_distance` (**5**) | Front arc **`eat_facing_arc_deg` = 90** (half-angle 45°; `dot ≥ cos(45°)`) |

Blocked `MOVE_F` into prey is **not** itself the eat trigger; eat still requires range + facing (or post-backup re-check).

### Root cause hypothesis (design)

| Gap | Detail |
|-----|--------|
| **Collision pin ≠ EAT** | Body overlap / `blk=1` does not arm the eat path; chase keeps reminting approach geometry. |
| **`_can_eat_now` distance gate** | Distance is against `step_goal` (nav substep), so facing/range can fail while capsules already overlap the prey ultimate. |
| **Chase into blocked body / open orbit** | `MOVE_F` into immobile/pinned prey continues the blocked remint loop; open-field spin never widens enough under the tight cone. |
| **Tight EAT facing** | ~±11.25° cone makes turn+EAT rare while rabbit flees / orbit continues. |

### Proposed fix (locked)

1. **Ultimate distance (world meters)** — `_can_eat_now` measures to `step_ultimate_pos` / live food ultimate, **not** nav `step_goal`. Range: `dist ≤ eat_action_max_distance` default **5** world units. ~~move-steps `eat_range_move_steps × expected_forward_step_world`~~ — **deferred** (speed-scaled EAT range later phase; duel 2026-07-14 fox trailed with 0 EAT under ~0.4 m step band).
2. **Facing arc** — replace `_is_facing_aligned_for_eat` = `0.5 × turn_increment_deg` with **`eat_facing_arc_deg`** default **90** (implementer converts to half-angle 45° for the dot test: `dot ≥ cos(45°)`).
3. **Consistency v1** — same meter-range + facing gate for **plants and prey** (shared `_can_eat_now`). Revisit plant-vs-prey split only if playtest shows shrub nibble feels wrong.
4. **Spin / break (A primary + B backup):**
   - **(A)** Spinning while closing is OK — action economy favors predator (`turn+EAT` vs rabbit `turn+MOVE`); widened cone should usually self-correct.
   - **(B)** If still in eat range of ultimate, latched live food, but **3 full facing revolutions** elapse without emitting `EAT` (≈ `3 * 360 / turn_increment_deg` turn actions, or equivalent counter), then **back up one step** (one rearward locomotion tick / break the orbit) and resume turn/EAT approach. Rationale: rabbit exactly 2× fox speed edge case / infinite orbit. Do **not** reintroduce hitbox kills (D11).

### Out of scope (this item)

- Do **not** mark C1/C2 done from this evidence alone.
- Do **not** implement C3 code in Pass 4 (`post-6d-approach-geometry` Layer 3 C2 handoff / locale arrival).
- Do **not** reintroduce contact-hitbox kills (D11).

### Acceptance

- [x] Headless: fox within `eat_action_max_distance` (5 m) of live prey **ultimate**, facing within `eat_facing_arc_deg` (90°), selects `EAT` without requiring a perfect nav substep at the capsule center.
- [x] Headless: after 3 full revolutions in eat range without `EAT`, one rearward locomotion tick fires, then turn/EAT approach resumes (no hitbox kill).
- [x] Duel manual: body-pin (`blk=1`) **or** open-field orbit (`blk=0`) produces `EAT` / kill rather than infinite spin / starve; blocked `MOVE_F` alone does not trigger eat.
- [x] No regression: Pass 1–4 approach-geometry tests; Flight A/B/C; prey latch / §9 gate; plant EAT still works under the shared `_can_eat_now` v1 gates.

### Resolved (2026-07-13; range superseded 2026-07-14)

- **Distance:** `step_ultimate_pos` / live food ultimate — **not** nav `step_goal`.
- **Range:** world meters — `eat_action_max_distance` = **5**. Speed-scaled move-steps range **deferred** (later phase).
- **Facing:** `eat_facing_arc_deg` = **90** (half-angle 45° for `dot ≥ cos(45°)`); replaces `0.5 × turn_increment_deg`.
- **Plant + prey:** same gates in shared `_can_eat_now` (v1); plant-vs-prey split only if shrub nibble feels wrong.
- **Spin:** primary = widened cone + predator action-economy self-correct; backup = 3 revolutions without `EAT` → one step back, then resume.
- **Blocked MOVE_F:** not an eat trigger; range + facing (or post-backup re-check) required.
- **Status:** `done` — shipped slice `post-6d-prey-eat-contact` (headless C3 gates green; duel manual signed off — `predation_carn_win` / `act=EAT` t=3549). Range gate restored to 5 m after step-band starve trail.

---

## C4 — Stale `instance_id` lookups crash memory adapter diet filter (headless regression)

**Status:** `done` — fix shipped 2026-07-14; 2 of 5 originally-listed acceptance tests confirmed unrelated (see below), remainder green  
**Slice:** unassigned — cross-cutting [`memory_adapter.gd`](../../creature/motor/memory_adapter.gd) bug, distinct from `post-6d-approach-geometry` (C1/C2) and `post-6d-prey-eat-contact` (C3)  
**Evidence:** Headless `godot --path . --headless -s res://tests/run_all.gd` — **2026-07-14** — **37 assertion(s) failed**. Confirmed via `git stash` isolation (parking only the in-flight `post-6d-approach-geometry` replay-capture instrumentation change — `creature_motor_stack.gd`, `project.godot`, `tests/run_all.gd` — while leaving other same-session WIP in place) that failure count and signatures are **identical with and without** that change — **not** caused by replay-capture instrumentation. **Not yet checked** against a stash of *all* current WIP (`motor_planner.gd`, `AI_int_lib/game_config_merge.gd` also modified uncommitted this session) or against last commit `de00439` — unconfirmed whether this predates this session or was introduced by the other in-flight work.

### Symptom

Recurring engine-level error, not an ordinary assertion mismatch:

```
ERROR: Condition "slot >= slot_max" is true. Returning: nullptr
   at: get_instance (./core/object/object.h:912)
   GDScript backtrace (most recent call first):
       [0] _belief_instance_passes_diet (res://creature/motor/memory_adapter.gd:978)
```

Fires from multiple call chains into `_belief_instance_passes_diet` — `consult_precise_food`, `consult_coarse_bearing`, `_count_live_known_objectives` → `count_known_objectives`, and `_switch_score` ([`blocked_objective_resolver.gd`](../../creature/motor/blocked_objective_resolver.gd)) → `apply_blocked_objective_resolution`. Cascades into failures in `_test_creature_motor_stack_memory_feasibility_tiers` (precise + coarse), `_test_creature_motor_stack_memory_stale_instance_id`, `_test_memory_adapter_ghost_danger_without_live_los` (plus a follow-on out-of-bounds array read in the test itself), `_test_creature_motor_stack_safety_blocked_by_ghost`, and `_test_creature_motor_stack_blocked_memory_writes`. Separately, `_test_seek_wall_filter_and_backtrack` fails (`deflected step goal does not continue blocked approach heading`) — **not yet confirmed** as the same root cause or a second, unrelated regression. Suite exits with **2 leaked `P10JoltBody3D` RIDs**, **4 leaked ObjectDB instances**, **1 resource still in use** — plausible fallout from the same stale-lookup path skipping fixture teardown, **not yet confirmed**.

### Root cause (confirmed 2026-07-14)

`_belief_instance_passes_diet` ([memory_adapter.gd:975-979](../../creature/motor/memory_adapter.gd)) called `instance_from_id(instance_id)` with no validity check beyond `!= 0`. When the id doesn't decode to a live ObjectDB slot, Godot prints the `"slot >= slot_max"` engine error and returns `null`; that `null` then flows into `_DietRegistry.node_is_valid_food_for_policy(null, policy)` ([diet_registry.gd:55](../../creature/capabilities/diet_registry.gd)), which explicitly returns `false` for a null node — so the belief was silently **rejected as "fails diet"** instead of counted. Not just log noise: this under-counted every feasibility/inventory tally that filtered through it. **Smoking gun:** [`_test_creature_motor_stack_memory_stale_instance_id`](../../tests/run_all.gd) seeds a belief with `instance_id = 1` and asserts `"stale instance_id still drives precise seek"` — the test's own name shows the original author anticipated exactly this scenario (a belief with no resolvable live Node) and expected graceful handling; the assertion was red. Production code seeds real ids correctly (`awareness_zone_scan.gd:92` uses `plant.get_instance_id()`); the crash path is reachable both by legitimately-stale ids (a remembered object since freed) and by synthetic test fixture ids (small hand-picked ints like `88031`, `99001`, `1` used throughout `run_all.gd`, including the new replay-capture fixture from Phase 1).

**Addendum (2026-07-14, Phase 1 replay-harness verification):** Confirmed **process-wide** blast radius, not scoped to the originally-failing tests. Adding two new, unrelated headless tests (`_test_motor_replay_fixture_load_and_rehydrate`, `_test_motor_replay_fixture_drives_stack_from_capture` — replay harness Phase 1, appended at the end of the `run_all.gd` list) produced **540** `"slot >= slot_max"` error lines across the run (vs isolated occurrences in the original 2026-07-14 evidence), including inside the new tests' own `stack.tick()` calls via `_derive_find_food_step_objective` → `consult_precise_food`. Total **assertion** failures stayed at **37** (the new tests' own `_assert` checks all passed — the corruption is caught/swallowed before it reaches their assertions) but the error-log noise confirmed this is a **cross-test, cumulative** corruption (an ObjectDB slot-error path that fires per bad lookup, not five-to-eight isolated test bugs).

### Fix shipped (2026-07-14)

`_belief_instance_passes_diet` now guards with `is_instance_id_valid(instance_id)` before calling `instance_from_id`, returning `true` (belief passes — no live node to check against, don't gate on diet) when the id doesn't resolve, instead of falling into the raw ObjectDB lookup:

```gdscript
func _belief_instance_passes_diet(instance_id: int) -> bool:
  if _food_intake_policy == null or instance_id == 0:
    return true
  if not is_instance_id_valid(instance_id):
    return true
  var node := instance_from_id(instance_id)
  return _DietRegistry.node_is_valid_food_for_policy(node, _food_intake_policy)
```

**Verified (headless, before/after diff of `run_all.gd` failures):** total assertion failures **37 → 15**. **19 assertion sites fixed**, including the smoking-gun `_test_creature_motor_stack_memory_stale_instance_id`, both `_test_creature_motor_stack_memory_feasibility_tiers` asserts, and `_test_creature_motor_stack_blocked_memory_writes` (now fully green). `"slot >= slot_max"` print volume dropped only slightly (540 → 502) — `is_instance_id_valid` itself still routes through the same low-level ObjectDB bounds check and prints on a garbage id, so the **noise** persists for synthetic test ids even though the **behavior** is now correct (no more silent diet mis-rejection). Silencing the print entirely would need either an engine-level change or a heuristic pre-filter on implausible id magnitudes — not done; out of scope (see [C6](#c6-newly-exposed-locale-consult-precedence-gap-memory_tier_precedence) note below on cost/benefit).

**Not touched (unrelated, still red both before and after):** `_test_memory_adapter_ghost_danger_without_live_los` and `_test_creature_motor_stack_safety_blocked_by_ghost` fail in `consult_danger_samples` / occluded-ghost threat consult — a different code path (threat beliefs, not food diet filtering) that never calls `_belief_instance_passes_diet`. Confirmed present in both the pre-fix and post-fix runs; not a C4 symptom. Left as a known, separate, still-open gap — not logged as its own item yet since it wasn't investigated this session.

**Newly exposed by this fix:** removing the crash let `_test_creature_motor_stack_memory_tier_precedence` run one statement further than it ever had before, surfacing a previously-masked real bug — see [C6](#c6-newly-exposed-locale-consult-precedence-gap-memory_tier_precedence).

### Acceptance

- [x] `_belief_instance_passes_diet` guards against invalid/uninitialized `instance_id` before the ObjectDB lookup (returns diet-pass cleanly instead of erroring).
- [x] Headless green: `_test_creature_motor_stack_memory_feasibility_tiers`, `_test_creature_motor_stack_memory_stale_instance_id`, `_test_creature_motor_stack_blocked_memory_writes`.
- [ ] `_test_memory_adapter_ghost_danger_without_live_los`, `_test_creature_motor_stack_safety_blocked_by_ghost` — confirmed **unrelated** to C4 (separate threat-ghost consult path); left open, not scheduled this session.
- [x] Confirmed `_test_seek_wall_filter_and_backtrack` does **not** share this root cause — see [C5](#c5-stale-test-vs-6e-executor-refactor-contract-seek_wall_filter_and_backtrack).
- [ ] No leaked RID / ObjectDB / Resource warnings at headless suite exit — not re-verified after the fix; likely improved (fewer aborted test functions means fewer skipped `queue_free()` calls) but not measured.

### Open questions

- None blocking — root cause confirmed and fixed. Remaining open item is the unrelated ghost-danger consult failures (not logged as their own item yet).

---

## C5 — Stale test vs 6e executor refactor contract (`_test_seek_wall_filter_and_backtrack`)

**Status:** `done` — confirmed stale test, not a production bug; test corrected 2026-07-14  
**Slice:** unassigned — [`motor_planner.gd`](../../creature/motor/motor_planner.gd) blocked-approach backtrack, distinct from C4 (confirmed: this test uses a real `bush.get_instance_id()`, not a synthetic id — never touches `_belief_instance_passes_diet`)  
**Evidence:** Headless `run_all.gd`, present in both the pre- and post-C4-fix runs — `ERROR: ASSERT: deflected step goal does not continue blocked approach heading` at [`_test_seek_wall_filter_and_backtrack`](../../tests/run_all.gd).

### Symptom

The test pre-seeds `state["blocked_approach"]` (simulating "this creature already tried approaching due south and got blocked") via `_BlockedApproachScr.record(...)`, places a food bush on that **same** bearing, then calls `MotorPlanner.select_action(ctx, state)` **once** on a fresh state and asserts the resulting `step_goal` direction is deflected ≥ ~25° off the blocked heading (`dot < 0.9`). It fails — `step_goal` points straight at the bush, `dot ≈ 1.0`, no deflection applied.

### Root cause hypothesis (leaning: stale test, not production bug)

Traced the only call site that applies the 60° backtrack deflection: [`apply_immediate_blocked_path_reevaluation`](../../creature/motor/motor_planner.gd) (around line 1866-1876) reads `state["blocked_approach"]` and rotates `move_dir` by 60° when the current approach direction matches a recorded blocked heading. This function is **not** part of `select_action`'s normal `sync_step_objective` → path clearance → `align_and_move` pipeline — per [creature_motor_stack.gd `tick()`](../../creature/motor/creature_motor_stack.gd), it's called **only** reactively, after an actual `ActionOutcome.blocked` on a `MOVE_FORWARD` this tick. [CREATURE_MOVEMENT_V3.md §3.2](CREATURE_MOVEMENT_V3.md) resolves this explicitly: *"the 60° backtrack detour runs in §3.2 reevaluate only — not inside §3.1 before the solid branch. It is a within-goal escape for a dead-ended substep, not a competing branch."*

The test calls `select_action` directly, one time, on a freshly-constructed state — it never drives a real blocked `MOVE_FORWARD` and never calls `apply_immediate_blocked_path_reevaluation`. There is no live obstacle in the test scene either (just body + bush, empty floor), so §3.1 path clearance finds a clear corridor and the planner correctly goes straight for the bush per the *documented* contract. This looks like a test that predates the **6e.1/6e.2** "simplified tick executor" refactor (§12.2, closed 2026-07-06) — which split the old combined pipeline into the current three-phase `sync_step_objective` / path clearance / `align_and_move` model — and was never updated to exercise deflection through the new reactive-only call path (e.g. driving a couple of `stack.tick()`s that produce a genuine blocked `MOVE_FORWARD`, or calling `apply_immediate_blocked_path_reevaluation` directly instead of `select_action`).

**Confirmed 2026-07-14:** traced every call site that consults `state["blocked_approach"]` in `motor_planner.gd` — `apply_immediate_blocked_path_reevaluation` (line ~1866, the 60° deflection) and `apply_blocked_objective_resolution` (§9, line ~2025, dead-end marking). Both are reactive-only, called from `creature_motor_stack.gd` only after a genuine blocked `MOVE_FORWARD` outcome this tick (the former unconditionally on any blocked move, the latter once `consecutive_blocked` crosses `dead_end_record_min_blocked_ticks`). Neither is reachable from `select_action`'s fresh §3.1 derivation. This is design, not a gap — matches `CREATURE_MOVEMENT_V3.md` §3.2 exactly.

### Fix shipped (2026-07-14)

Corrected [`_test_seek_wall_filter_and_backtrack`](../../tests/run_all.gd) to exercise the intended two-stage contract instead of calling `select_action` once and expecting deflection on a fresh pick:

1. Call `select_action` as before, but assert the **opposite** of the original (wrong) expectation: a fresh pick with no live obstacle goes straight at the bush (`dot(approach) > 0.9`) even with `blocked_approach` memory recorded on the same heading — locking in the reactive-only contract as a regression guard in its own right.
2. Then call `_MotorPlanner.apply_immediate_blocked_path_reevaluation(ctx, state, body, motor_v3)` directly — simulating what `creature_motor_stack.gd` does after a real blocked `MOVE_FORWARD` — and assert the now-deflected `step_goal` (`dot(approach) < 0.9`), which is the original test's intent.

**Verified (headless, exact before/after line diff):** only the one line `ERROR: ASSERT: deflected step goal does not continue blocked approach heading` dropped out of the failure list; no other assertion changed. Total: 15 (unchanged count, since the runner's printed summary was already undercounting real `ERROR: ASSERT` lines by one before this fix — see note below). Confirms the 60° deflection logic itself was never broken; only the test's call path was stale.

**Resolved side note:** this also explains the earlier "37 → 15" vs. a stray "16 assertion(s) failed" readout seen right after the C4 fix — not run-to-run nondeterminism. The runner's printed `N assertion(s) failed` summary can undercount the actual number of `ERROR: ASSERT` lines by one in some runs (cause not further diagnosed — cosmetic, doesn't affect which assertions pass/fail). Cross-checking with `grep -c "ERROR: ASSERT"` against the full log, rather than trusting the summary line alone, is the reliable count going forward.

### Acceptance

- [x] Confirm blocked-approach 60° deflection still fires correctly when driven through the intended reactive path (direct `apply_immediate_blocked_path_reevaluation` call, matching `creature_motor_stack.gd`'s own call site).
- [x] Fixed the test to exercise the correct call path (kept as a regression guard for both the reactive-only contract and the deflection itself).
- [x] No regression to `_test_motor_pursuit_pinch_detour_smoke` / other backtrack-adjacent tests (confirmed via exact before/after failure-line diff).

### Open questions

- Should blocked-approach memory ever proactively bias a *fresh* `step_goal` pick (avoid a known-bad heading before re-attempting it), or is reactive-only (current documented contract) intentional and sufficient? Not changed this session — current behavior matches the documented §3.2 contract; worth a deliberate design call only if playtesting shows the reactive-only delay causes visible thrash.

---

## C6 — Newly exposed locale-consult precedence gap (`_test_creature_motor_stack_memory_tier_precedence`)

**Status:** `done`  
**Slice:** unassigned — surfaced as a side effect of the [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression) fix, not caused by it  
**Evidence:** Headless `run_all.gd`, **2026-07-14**, post-C4-fix only — `ERROR: ASSERT: locale consult when no instance beliefs` at [`_test_creature_motor_stack_memory_tier_precedence`](../../tests/run_all.gd) (the `stack.get_planner_step_source() == &"locale"` check after clearing all instance beliefs). **Confirmed not present** in the pre-fix baseline — but not because it was passing: backtrace evidence shows the pre-fix run **never reached that line** in this test (last frame recorded stops two statements earlier, at the "coarse beats locale" assert). The C4 crash was aborting this test function partway through every run; fixing C4 let it run to completion for the first time and exposed a real, previously-invisible failure underneath.

### Symptom

Test sequence: seed a precise belief + coarse belief + locale prior → tick → assert `step_source == precise` (passes). Erase the precise belief → tick → assert `step_source == coarse` (was also failing, same root cause as below). Clear **all** instance beliefs (empty dict) → tick → assert `step_source == locale` (new failure) — with no instance beliefs left, the planner does not fall through to the locale prior as the next tier.

### Root cause (found and fixed 2026-07-14)

One underlying bug explained both the "coarse beats locale" and "locale consult" failures — not two. [`_sync_step_objective`](../../creature/motor/motor_planner.gd)'s `GK_FIND_FOOD` branch only calls `_derive_find_food_step_objective` (the function that walks precise → coarse → locale) when: live food appears/moves, `refresh_targets` is set, `step_goal` is unset, or the food-inventory mode changed. None of those conditions fire when an **incumbent belief is simply erased out from under an already-latched `precise`/`coarse` step_source** — `has_step_goal` stays true (the stale goal from the prior tick), so the elif chain falls through to nothing and the stale `step_source` (and stale `step_goal`) latches forever instead of re-consulting the tier hierarchy.

**Fix:** added `_find_food_memory_tier_stale(...)` — when `live_food` is empty and the current `step_source` is `precise`/`coarse`/`locale`, re-run that tier's own consult (`consult_precise_food` / `consult_coarse_bearing` / `consult_locale_seek`) and report stale if it no longer reports `active` (or, for `precise`, if the active belief's `instance_id` no longer matches the incumbent). Wired as a new elif branch in `_sync_step_objective` before the live-remint branch, so a stale tier now falls through to `_derive_find_food_step_objective` and re-derives (precise → coarse → locale) instead of holding a dead `step_goal`.

### Acceptance

- [x] Root-caused why locale consult doesn't win when all instance beliefs are absent (stale latched `step_source` with no re-derivation trigger).
- [x] Confirmed same root cause as the "coarse beats locale when precise absent" failure — one fix for both.
- [x] Headless green: `_test_creature_motor_stack_memory_tier_precedence` (all three asserts).

### Open questions

- None blocking. Remaining headless noise in the same run (`slot_max` ObjectDB errors, ghost-danger asserts) is pre-existing/unrelated — see [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression) open items.

---

## C7 — Flaky headless assertions (nondeterministic across identical runs)

**Status:** `pending_recurrence` — replay-fixture flake root-caused and fixed 2026-08-06; a second, previously-uncaught flaky test found and fixed 2026-08-07; memory-tier-precedence flake not reproduced in 39 runs 2026-08-07 and not formally root-caused — no next step until it recurs, not investable time in the meantime  
**Slice:** unassigned — test-infrastructure gap, not a motor-code bug  
**Evidence:** Headless `run_all.gd`, **2026-07-15** — 3 assertions intermittently pass/fail across back-to-back runs of **identical, unchanged code**: `_test_motor_replay_fixture_drives_stack_from_capture`'s "closes on the captured prey trajectory", and `_test_creature_motor_stack_memory_tier_precedence`'s "coarse beats locale when precise absent" / "locale consult when no instance beliefs". Confirmed via `git stash` A/B isolation while investigating [R1](#r1--architecture-risk-one-action-per-tick--turn-first-alignment) mitigation #1: same commit, run 6 times back-to-back (3 pre-change, 3 post-change via stash), failure set was identical in 5 of 6 runs (13 assertions) but one run showed 12 (with the replay-fixture assertion swapped in for the two tier-precedence ones) — same code, different result.

### Symptom

Not order-dependent in an obvious way (test list is static, run sequentially) — more likely genuine nondeterminism in the simulated scenario itself: physics substep timing (Jolt), or the residual `"slot >= slot_max"` ObjectDB corruption noise already tracked under [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression) (500+ print lines per run, confirmed still present, cause not fully diagnosed) nondeterministically perturbing an unrelated lookup on some runs but not others.

### Why this matters

Any future "before/after" headless comparison (regression hunting, tuning verification) needs **multiple runs**, not one, to trust a diff — a single run's assertion count/set is not reliable ground truth for these specific tests. This cost real investigation time during R1 verification (an initial single run showed what looked like a new regression from arrival damping; it took 4 additional runs each of before/after code to establish it was pre-existing flakiness, not a regression).

### Root cause — replay-fixture flake (found and fixed 2026-08-06)

Not Jolt substep nondeterminism, and not the C4 ObjectDB noise — both original hypotheses ruled out by direct isolation rather than guessed. Root-caused via a repeated-run harness (`_test_motor_replay_fixture_drives_stack_from_capture`'s exact scenario, rerun 12× in one process with per-tick `is_on_floor()`/margin tracing): the very first run showed `floor_true_ticks=0/60` and a thin closing-distance margin (1.30, just over the assertion's 0 threshold); all 11 subsequent runs showed `floor_true_ticks=60/60` and a comfortable margin (~7.7).

Mechanism: this codebase only applies gravity and calls `move_and_slide()` inside `apply_horizontal_move_intent`, itself only invoked from a `MOVE_FORWARD`/`MOVE_BACKWARD` action ([`locomotion_executor.gd`](../../creature/motor/locomotion_executor.gd)) — never automatically every physics frame. The test spawns a floor + body and does a single `await process_frame` before driving the capture. A freshly-added collider isn't visible to physics broadphase queries until the physics server has actually processed a step, and whether that happened yet by the time `process_frame` resolves is a genuine race in headless/uncapped-FPS execution (the physics accumulator can run zero, one, or several steps per rendered frame depending on wall-clock scheduling). When it loses the race, the body falls through the never-registered floor for the entire 60-tick capture instead of landing, drifting further from the (grounded) prey in 3D and degrading the margin — occasionally enough to flip the assertion. Confirmed this isn't order-dependent test pollution: the *same* isolated scenario, rerun identically, produces the divergent outcome purely from this timing race.

**Fix:** [`MotorReplayFixture.drive_stack`](../../tests/motor_replay_fixture.gd) now awaits two full `physics_frame` cycles before starting its capture-drive loop (`_settle_on_floor`, one cycle was empirically not reliably enough headroom; a synchronous manual-call-only loop with no yield to the engine at all did not force the sync either — both tried and rejected before landing on this). This does not guarantee full floor-contact resolution every run, but makes the *outcome* deterministic — verified via 5 separate `--headless` process invocations (not just loop iterations sharing a process, which introduces its own confound via deferred `queue_free()` timing), byte-identical assertion result every time. Deterministic pass/fail is what the fixture's assertions actually need; chasing full physical grounding further was out of scope for this fix.

### Triage (2026-08-07)

Tried to force a repro of `_test_creature_motor_stack_memory_tier_precedence`'s two flaky asserts before guessing at a fix. A tight 30-iteration in-process loop (pairing it with its actual predecessor test, `_test_creature_motor_stack_memory_live_beats_precise`, to match the real adjacency and test the leftover-un-freed-geometry hypothesis C8's trio turned out to hinge on) produced **zero** divergent results. Separate-process invocations — closer to how the original flake was actually observed in 2026-07-15 — were run **39 times** back-to-back post-fix (see below) with zero recurrence of this specific test's failure, against a historical rate of roughly 1-in-6. Not a formal root-cause (no specific mechanism identified, unlike the item found below), but `(5/6)^39 ≈ 0.1%` makes "still flaky at the original rate" an unlikely explanation for 39 straight clean runs. Most likely explanation: incidentally resolved by other work this session (C8's frame-yield/timing fixes, or upstream changes since 2026-07-15) rather than independently fixed. Marked `pending_recurrence` rather than `done` since it wasn't pinned down — no next step until a fresh repro shows up.

**Found a different, previously-uncaught flaky test in the process** — confirms the "other flaky assertions not yet caught" open question below was real. `_test_motor_planner_explore_seek_seeds_waypoint` ("seek fallback seeds explore_dir from body facing") failed 2 of the first 18 separate-process runs this pass. Root cause: unlike sibling explore-direction tests (e.g. `wall_bias_opens_away`), this test never zeroes `goal_consideration_chaos` (default 0.15) — the per-wedge random jitter `_pick_explore_dir` adds when scoring bearings. In an empty synthetic scene every wedge ties on `open_term`, so the pick is decided by `spawn_term`'s margin between the facing-aligned wedge and its neighbors — a margin this session's [C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) `explore_w_spawn` rebalance (0.35→0.20) narrowed enough that chaos could occasionally flip the winner. Pre-existing flake, made measurably easier to hit by that rebalance. Fixed by setting `goal_consideration_chaos = 0.0` in the test, matching the established pattern ([`tests/run_all.gd`](../../tests/run_all.gd) `_test_motor_planner_explore_seek_seeds_waypoint`). Verified: 25 separate-process runs post-fix, zero recurrence.

### Acceptance

- [x] Root-cause why `_test_motor_replay_fixture_drives_stack_from_capture` varies run-to-run on unchanged code — physics-frame/collider-registration race, not Jolt jitter or C4 noise (see above).
- [x] Fix: `drive_stack` settles on two `physics_frame` cycles before driving the capture. Verified deterministic across 5 separate process invocations.
- [~] `_test_creature_motor_stack_memory_tier_precedence` — **`pending_recurrence`, not reproduced in 39 separate-process runs post-C8** (see Triage above); no specific mechanism found, so not marked fixed, but no longer observed at its historical rate either. Not investable time unless a fresh repro shows up.
- [x] **Found and fixed a second, previously-uncaught flaky test while checking:** `_test_motor_planner_explore_seek_seeds_waypoint` — missing `goal_consideration_chaos = 0.0`, exposed by this session's `explore_w_spawn` rebalance. See Triage above.
- [ ] Decide whether other flaky assertions exist in the suite that haven't been caught yet — worth a scripted multi-run (both in-process-loop *and* separate-process) check before trusting any future single-run headless diff as authoritative, given how easily the replay-fixture flake hid behind "looks like it usually passes."

### Open questions

- Are there other flaky assertions in the suite not yet caught because no one has run it 6× back-to-back? Worth a scripted multi-run check before trusting any future single-run headless diff as authoritative. (Partially answered 2026-08-07 — found one; more may exist.)

---

## C8 — Stable pre-existing test failures found during R1 mitigation #2 audit

**Status:** `done` — 13 of 13 fixed  
**Slice:** unassigned — test-hygiene / stale-fixture gaps, not motor-code bugs (except where noted)  
**Evidence:** discovered isolating [R1](#r1--architecture-risk-one-action-per-tick--turn-first-alignment) mitigation #2's own diff (reverting just its 4-file change, not a full `git stash`) surfaced a **13-assertion failure set already present in the working tree before mitigation #2** — byte-identical across 3 consecutive runs (**stable**, unlike [C7](#c7-flaky-headless-assertions-nondeterministic-across-identical-runs)'s nondeterministic set; no name overlap with C7's 3). User asked whether these were stale pre-V3 test artifacts — audited all 13 individually.

**Re-verified 2026-07-17** (separate session, stuck-rabbit LOS-hysteresis fix): headless suite run 3× back-to-back against clean `main` (via `git stash` A/B against that session's unrelated `motor_planner.gd`/`game_config_merge.gd` diff) — byte-identical **8** `ERROR: ASSERT` failures every run, all 8 confirmed by a further 3 direct re-runs this session. All 8 match this section's tracked items **except** one: `_test_motor_planner_explore_move_not_falsely_blocked` ("explore forward move clears consecutive_blocked on meaningful progress") is failing again despite being listed as fixed below on 2026-07-16 — see the "Regressed 2026-07-17" entry in [Open](#open-not-fixed--needs-dedicated-follow-up) below. Net: only **4** of the original 5 "fixed" items are still confirmed green; the open list below is missing this 8th failure and needs the new entry added.

**Fixed 2026-08-05** (separate session): user asked whether the 8 open items were worth acting on given that live fox/rabbit smoke testing can't force-reproduce them — answer was yes for the two with an already-isolated deterministic repro (the unit test itself), no live reproduction needed. Root-caused and fixed both the regressed `explore_move_not_falsely_blocked` (real production bug, see below) and `post_scan_inward_align_no_flip_flop` (test-fixture bug, see below). Headless suite run 2× back-to-back post-fix: stable **6** `ERROR: ASSERT` failures both runs, matching exactly the 6 remaining open items below — no new regressions introduced.

### Fixed (2026-07-16)

None of the 5 fixed were "testing removed functionality" — all were live systems with test fixtures that had drifted from current behavior:

- **`_test_motor_planner_explore_latch`** ("explore_dir seeds from body facing... not random"): the 8-wedge bearing pick (`motor_explore_seek.gd::_pick_explore_dir`) centers wedges at 22.5°/67.5°/... — offset from cardinals — so no wedge can ever score `dot > 0.99` against an exact cardinal facing (`cos(22.5°) ≈ 0.924` is the ceiling). Test threshold loosened to `> 0.9`. (A dead `_initial_explore_dir()` helper in `motor_planner.gd` — exact-facing seeding, never called from anywhere — suggests this test predates the wedge-scored picker; left the dead code alone, out of scope here.)
- **`_test_motor_planner_explore_move_not_falsely_blocked`** ("...clears consecutive_blocked on meaningful progress"): single MOVE_FORWARD tick from a cold stop (velocity 0) — `apply_horizontal_move_intent`'s acceleration ramp means one tick's displacement is far below the no-progress epsilon regardless of correctness. Changed to 30 ticks so velocity ramps to a realistic speed before asserting. **Regressed 2026-07-17 — see the "Regressed 2026-07-17" entry in [Open](#open-not-fixed--needs-dedicated-follow-up) below; no longer green.**
- **`_test_motor_planner_explore_overshoot_replans`** + **`_test_motor_planner_explore_rim_overshoot_replans_inward`** (both "...sets blocked_objective_action=explore_replan", plus "overshoot mints a new explore waypoint"): two compounding fixture bugs. (1) Neither test set `state["goal_kind"]` before calling `select_action` — `_sync_step_objective`'s goal-kind-change reset (fresh state's `goal_kind` defaults to `""`, always `!=` the tick's goal_kind) wiped the pre-seeded `explore_dir`/`explore_waypoint` overshoot fixture before the overshoot-detection logic ever ran. Fixed by pre-setting `state["goal_kind"] = GK_FIND_FOOD`. (2) With that fixed, the non-refresh path (`_maintain_explore_latch`) detects the overshoot and clears the waypoint but — unlike `mint_explore_step`, which self-heals same-tick — doesn't re-mint until the next consideration tick (a real asymmetry between the two paths, not fixed here, just routed around). Fixed by adding `ctx["refresh_step_objective"] = true` so the test exercises the self-healing `_derive_find_food_step_objective` path it actually intends to test. Also moved the interior-overshoot fixture's body from exactly `arrival_tolerance` (5.0) away to 10.0 away — the exact-boundary distance was silently taking the "arrived normally" branch instead of the overshoot branch.
- **`_test_motor_planner_avoid_hostiles_refresh_on_consideration_only`** ("flee step_goal refreshes on consideration tick"): flee waypoints are a pure bearing calculation (direction away from threat × `awareness_radius`), and the fixture moved the threat from `(10,0,0)` to `(30,0,0)` — same bearing from the creature's origin, different distance. A correct recompute legitimately produces the *identical* waypoint in both cases; the test's premise that this should differ was wrong. Changed the second threat position to a different bearing (`(10,0,30)`) so a real refresh is observable.

### Fixed (2026-08-05)

- **`_test_motor_planner_explore_move_not_falsely_blocked`** ("explore forward move clears consecutive_blocked on meaningful progress") — **real production bug**, not a test artifact, confirming the 2026-07-17 "Regressed" entry's suspicion. Traced with per-tick instrumentation (`consecutive_blocked`, `no_progress`, `_tick_had_meaningful_progress`'s inputs) rather than guessed: the cold-start acceleration ramp (`apply_horizontal_move_intent` building velocity from 0 via `move_toward`) held displacement below `stuck_eps` for the first ~6 ticks — long enough for `explore_no_progress_ticks` (via `_note_explore_align_progress`, driven off `explore_idle_stuck`) to reach `dead_end_record_min_blocked_ticks` (default 3) **before the creature ever reached cruising speed**. That escalated into `_apply_explore_stuck_or_rim_replan`, which zeroed `state["step_goal"]` and picked a new bearing — a false "dead end" conclusion. Once `step_goal` was zeroed, `_tick_had_meaningful_progress`'s `to_goal` pointed back at the origin (the zeroed goal), so every subsequent tick's forward displacement dotted *negative* against it and `consecutive_blocked` could never clear via the normal progress-reset path either — the assertion failure was a downstream symptom of the goal having already been discarded several ticks earlier, not a threshold-tuning issue. **Any real creature starting a MOVE_FORWARD explore step from a stop (e.g. right after a turn-alignment) risks this same false replan before reaching cruising speed** — plausibly a contributor to erratic/repeated explore-direction changes in live play, not just a test-only concern. Fixed in `motor_planner.gd::note_outcome`: added a `still_ramping` check (new `explore_last_move_disp_len` state field, reset alongside the other explore-align-progress fields in `_reset_explore_align_progress_state`) — if this tick's forward displacement is still climbing versus the previous tick's, the tick is exempted from the no-progress count, mirroring the "improving disqualifies" idiom `_note_explore_align_progress` already uses for the facing-dot check just above it. Once displacement plateaus (real dead end, or reaching cruising speed) the exemption naturally stops applying. Verified: `consecutive_blocked` now stays at 1 through the ramp and cleanly resets to 0 once real progress is confirmed, instead of escalating to a spurious replan.
- **`_test_motor_planner_explore_post_scan_inward_align_no_flip_flop`** ("post-scan inward align converges to MOVE within 16 ticks") — **test-fixture bug**, not the boundary-scan re-arm regression suspected on 2026-07-17. Same root cause as the already-fixed overshoot tests: the test never set `state["goal_kind"]` before its first `select_action` call, so `_sync_step_objective`'s goal-kind-change reset fired on tick 0 (default `""` → `GK_FIND_FOOD`) and silently zeroed the `boundary_scan_egress_ticks` grace period that `_end_boundary_scan` had just set up moments earlier — the exact protection the "Fix 2 (Fox rim)" work already built to stop this re-arm case. With the egress grace zeroed from the start, `consecutive_blocked` (incremented by ordinary turn-in-place ticks, which read as `no_progress`) reached `dead_end_record_min_blocked_ticks` at tick 3 and re-armed `boundary_scan_active` — matching the observed "spins a full circle" symptom exactly, but the re-entry guard itself was working correctly once the test seeded `goal_kind` like its sibling tests already do. Fixed by adding `state["goal_kind"] = _GkReg.GK_FIND_FOOD` before the loop. A second, separate assertion in the same test (`post-scan MOVE faces inward`) then surfaced once the loop could actually reach `MOVE_FORWARD`: it read `body.last_move_direction` immediately after `select_action` returned `MOVE_FORWARD`, without ever applying that action — but `align_and_move` deliberately commits to `MOVE_FORWARD` within a wide `move_blend_max_error_deg` (60°) cone and relies on the executor's same-tick `_blend_turn_toward` (driven by `move_turn_target`, CLEANUP R1 mitigation #2) to correct the rest of the way, exactly as `creature_motor_stack.gd`'s real `tick()` caller does. Fixed by calling `_LocomotionExecutor.apply_action(body, act, delta, motor_v3, null, step_goal)` before checking `last_move_direction`, mirroring the real caller.

### Fixed (2026-08-07)

The "LOS/wall-raycast trio" tracked below since 2026-07-16 turned out to be **two unrelated bugs**, not one shared root cause — found by live-instrumenting each test rather than trusting the earlier "likely the same root cause" guess:

- **`_test_locomotion_executor_move_blocked`** ("MOVE_FORWARD against wall sets blocked") — **test-isolation bug, not physics/Jolt.** The test immediately prior (`_test_locomotion_executor_stay_calorie_debit`) is fully synchronous — it calls `main.queue_free()` but never yields a frame, so by the time this test spawned its own wall/floor/body, the *previous* test's wall/floor/body were still fully live in the physics world at the same coordinate conventions. The new body's `move_and_slide()` was colliding/depenetrating against that leftover geometry, not this test's own wall — producing exactly the "body already 2+ units past the wall, continuous freefall" symptom previously guessed to be Jolt tunneling. Fixed with two `await process_frame` calls at the top of the test to flush the pending free before spawning ([`tests/run_all.gd`](../../tests/run_all.gd) `_test_locomotion_executor_move_blocked`) — same headroom [C7](#c7-flaky-headless-assertions-nondeterministic-across-identical-runs)'s replay-fixture fix already established empirically for this exact class of problem.
- **`_test_motor_explore_seek_wall_bias_opens_away`** + **`_test_memory_adapter_ghost_danger_without_live_los`** + **`_test_creature_motor_stack_safety_blocked_by_ghost`** ("wall north of spawn-facing picks open bearing away from obstruction" / "occluded threat ghost emits danger sample" / "ghost danger blocks Safety state") — **real production bug**, confirmed by instrumenting `LineOfSight3D.occlusion_fraction` directly ([`creature/motor/line_of_sight.gd`](../../creature/motor/line_of_sight.gd)): it chopped the full eye→target distance into exactly **10 fixed-length buckets** and voted per bucket (any hit within a bucket = 1 vote), then required **80%** of buckets blocked to count as occluded. A wall sitting close to the creature but far from the (often distant) probe target could only ever fill **one** bucket — max measured `occlusion_fraction` was **0.1**, an order of magnitude below threshold, *regardless of how solid the wall actually was*. At the live default `awareness_radius` (1500, ⇒ ~750-unit probes) against a ~200-unit playfield, this made the occlusion check a near-total no-op for wall-avoidance and ghost-threat-memory alike, not just a test artifact.
  - **Fix:** replaced the length-bucket sampling with a real shadow-fan test — cast rays from the eye to a ring of points fanned across the *target's* silhouette (radius `los_target_radius`, new default **0.5**, pack-overridable per species for better/worse peripheral vision) instead of chopping the path length. A near occluder now correctly shadows the whole fan (all sample rays converge back through nearly the same point close to the eye, regardless of how far the nominal target sits) while a genuinely clear line stays fully open. `AwarenessZone.line_of_sight_clear` and `default_creature_motor_v3_params()` updated to thread the new radius through ([`creature/motor/awareness_zone.gd`](../../creature/motor/awareness_zone.gd), [`AI_int_lib/game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd)).
  - Fixing the shadow test alone was enough for the ghost-danger tests but not the full-stack safety test — that one drives the real `CreatureMotorStack.tick()` path, whose `get_los_eye_height()` (mesh-fitted capsule height × 0.9) computed a real eye height of **3.44** world units for the test rabbit, well above the test's 4-unit-tall wall (top at world Y 3) — the ray simply flew over it. The other 3 ghost tests dodge this by hardcoding `eye_height: 1.0` directly. Fixed by raising `_ghost_test_wall`'s height to comfortably exceed realistic eye heights ([`tests/run_all.gd`](../../tests/run_all.gd)).
  - The shadow-fan fix alone still left `wall bias opens away` red: it correctly zeroed `open_term` for the two wedges directly facing the wall, but every *other* wedge — 45° away or 180° away — tied at a flat `open_term = 1.0`, so `explore_w_spawn` (favoring the creature's current heading) always broke that tie in the wall's own general direction rather than a genuinely far bearing. **User-directed rebalance:** open space should outweigh spawn-heading inertia by default, with other factors (unexplored/forward) only adjusting the calculus among *comparably* open choices. Implemented `_apply_open_safety_margin` in [`motor_explore_seek.gd`](../../creature/motor/motor_explore_seek.gd) — wedges within `explore_open_safety_margin_wedges` (new default **3**) of a blocked bearing get a discounted `open_term`, fading linearly to no discount at the margin's edge, giving `open_term` real graduation instead of a flat tie. Combined with a default weight rebalance (`explore_w_spawn` 0.35→**0.20**, `explore_w_open` 0.30→**0.45**), spec table in [CREATURE_MOVEMENT_V3.md §7.3.2](CREATURE_MOVEMENT_V3.md) and the pinned-defaults regression test updated to match.
- **`_test_memory_adapter_count_known_objectives_fractional`** ("belief north of origin scores higher in north wedge than east wedge") — **test-fixture bug, not a wedge-scoring gap.** `explore_bearing_coverage`'s documented contract ([CREATURE_MOVEMENT_V3.md §7.3.2/§8.4](CREATURE_MOVEMENT_V3.md)) is instance beliefs per wedge + near-live overlay only — it does **not** consult the locale-prior store, so the fixture's `seed_locale_prior_for_test(0, 0, 1.0)` call (needed for this same test's *other* assertion, `count_known_objectives == 2.75`) contributes nothing to the wedge comparison. The two beliefs used for the wedge assertion (8001 north, 8002 east) are both `PRECISE` tier at the same distance, so they score identically by design — the fixture had no actual source of asymmetry between wedge 0 and wedge 2 under the correct implementation. Fixed by seeding a second `PRECISE` belief sharing the north wedge, giving it a genuine 2-belief-vs-1-belief edge via the real per-wedge accumulation path ([`tests/run_all.gd`](../../tests/run_all.gd) `_test_memory_adapter_count_known_objectives_fractional`).
- **`_test_creature_motor_stack_food_map_confidence_inventory_ratio`** ("two known bushes yield partial inventory_ratio") — **test-fixture bug, not ObjectDB noise as previously suspected.** `MemoryAdapter.get_beliefs()` returns a defensive `_beliefs.duplicate(true)`, not a live reference. The fixture's `adapter.get_beliefs().erase(89003)` mutated a throwaway copy with no effect, and the immediately-following `adapter.set_beliefs_for_test(adapter.get_beliefs())` fetched a *fresh*, still-unerased duplicate — silently undoing the erase, so all 3 beliefs (not 2) were still present on the second `tick()`, keeping confidence pinned at the saturated `1.0` instead of dropping to `2/3`. Fixed by capturing the duplicate in a local variable, erasing from that, then passing it to `set_beliefs_for_test` ([`tests/run_all.gd`](../../tests/run_all.gd) `_test_creature_motor_stack_food_map_confidence_inventory_ratio`). The `Condition "slot >= slot_max"` ObjectDB noise previously blamed for this failure is real but unrelated — it litters many other tests throughout the suite (already tracked under [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression)) and was never this test's actual cause.
- Neither of these two shared a root cause with the LOS/wall-raycast trio above, despite being grouped in the same "6 open items" batch for several sessions.

Verified: full headless suite **6 → 0** failures. Two consecutive `--headless` runs completed with zero `ERROR: ASSERT` lines (invariant harness temporarily disabled per the existing `run_all.gd`/synthetic-fixture workaround, reverted after each run) — first fully-green run of this 13-item batch since it was first logged 2026-07-16.

### Acceptance

- [x] Determine whether the 13 pre-existing failures are stale pre-V3 test artifacts — **no**, all are live current systems.
- [x] Fix the 5 that were test-fixture/threshold drift, not production bugs.
- [x] **Re-fixed 2026-08-05:** `_test_motor_planner_explore_move_not_falsely_blocked` — real production bug (cold-start ramp falsely escalated to an explore-stuck replan), see [Fixed (2026-08-05)](#fixed-2026-08-05) above.
- [x] **Fixed 2026-08-05:** `post-scan inward align` — test-fixture bug (missing `goal_kind` seed + premature facing check), not a boundary-scan re-arm regression; see [Fixed (2026-08-05)](#fixed-2026-08-05) above.
- [x] **Fixed 2026-08-07:** `MOVE_FORWARD against wall sets blocked` — test-isolation bug (leftover un-freed geometry from the prior synchronous test), not Jolt tunneling; see [Fixed (2026-08-07)](#fixed-2026-08-07) above.
- [x] **Fixed 2026-08-07:** the LOS/wall-raycast trio (wall-bias, ghost-danger ×2) — real algorithmic bug in `LineOfSight3D.occlusion_fraction` (length-bucket sampling could never register a normal wall as occluding a long sight line), plus a test-wall-height gap and an explore wedge-scoring tie; see [Fixed (2026-08-07)](#fixed-2026-08-07) above.
- [x] **Fixed 2026-08-07:** `two known bushes` — test-fixture bug (`get_beliefs()` deep-copy erase discarded), not ObjectDB noise; see above.
- [x] **Fixed 2026-08-07:** `belief north of origin` — test-fixture bug (fixture had no real source of wedge asymmetry under the documented, correct `explore_bearing_coverage` contract), not a wedge-scoring logic gap; see above.

---

## C9 — Flee-waypoint latch corrupted by reactive backtrack deflection (rabbit stuck at playfield edge)

**Status:** `in_progress` — original bug fixed and verified 2026-07-16; **reopened 2026-08-05** after live re-verification found the fix's own documented open gap (fox's wall-oscillation) live, then found the initial follow-up hypothesis wrong and root-caused + fixed two real mechanisms (3 iterations); live loop-closure still unconfirmed — see "Root-cause correction" and "Fix shipped" below. **2026-08-06:** confirmed via automated headless repro that the 3rd fix does NOT close the loop; root-caused exactly why (single-slot blocked-direction memory + a 60° rotation that resonates with the 0.55 backtrack threshold); shipped a 4th fix (rolling multi-direction history) that broke the exact 2-point resonance but still didn't achieve real escape near a corner; shipped a 5th fix (geometry-scored candidate selection via navmesh reachability) that found and fixed a genuine headless-tooling bug (smoke test was querying an unbaked navmesh) and is a large, verified improvement (2/4 repeated runs now complete with zero trips; the other 2 trip far later than before) — but still not fully closed. **2026-08-07:** shipped a 6th fix — a give-up escalation, analogous to explore mode's `boundary_scan`, for when even the 5th fix's best geometry-scored candidate is still bad. 4 repeated headless runs: 3/4 clean (up from 2/4), 1/4 still tripped. Real further improvement, still not fully closed. **Same day, follow-up:** traced the one remaining trip's degenerate `(0,y,0)` waypoint to a distinct, previously-unidentified bug — `_flee_objective`'s "no threat currently in awareness" case returns `Vector3.ZERO` as a sentinel, which the candidate-scoring machinery was treating as a literal flee-toward-world-origin destination instead of "no answer." Root cause: the `in_awareness` LoS check has no hysteresis and can flicker false for a tick near corner geometry even while the Flight episode's own latch stays active. Fixed by holding the last latched waypoint on any no-visible-threat tick instead of reminting from the sentinel. 6 repeated headless runs post-fix: **zero C9 trips of any kind** (1/6 tripped on an unrelated, already-"fixed" C10 airborne check — flagged separately, not chased down here). See "7th fix" below.  
**Slice:** unassigned — [`motor_planner.gd`](../../creature/motor/motor_planner.gd), `apply_immediate_blocked_path_reevaluation`, `_maintain_flee_latch`, `_mint_flee_waypoint`, `_remint_alternate_pursuit_detour`  
**Evidence:** Live duel log (`motor_explore_tick.log`, t=3144–3418+) — user report: "rabbit got stuck at the playfield edge trying to escape, then once the fox arrived, they both got stuck."

### Symptom

Rabbit in acute Flight (`ff=1`, `gk=avoid_host`) near the playfield boundary stopped making net progress. `dist_to_goal` held flat around 7.8–7.94 for hundreds of ticks while `tgt` (the logged `step_goal`) cycled through a stable, repeating rotation of ~4 fixed points (`(-105,32)` → `(-105,40)` → `(-99,44)` → `(-92,41)` → repeat, period ≈34 ticks) instead of holding steady for the configured `flee_waypoint_latch_ticks` (16). Net displacement over the whole captured window was effectively zero — the rabbit was in a stable limit cycle, not fleeing.

Distant-phase behavior (same log, t≈3019–3143, rabbit far from any wall) was correct: the flee waypoint held for a clean ~16-tick window each remint with smooth incremental drift as the fox closed distance — confirming the latch mechanism itself works when the direct path to the flee objective has clear line-of-sight.

The fox arriving triggered a second, related symptom (see Root cause) but the rabbit's lockup was already present before contact.

### Root cause (confirmed 2026-07-16)

[`apply_immediate_blocked_path_reevaluation`](../../creature/motor/motor_planner.gd) (§3.2 reactive backtrack + LOS/nav deflection, runs only after a genuine blocked `MOVE_FORWARD`) computes a **per-tick** deflected `step_goal` — either a 60° backtrack rotation or a navmesh first-waypoint substitute when line-of-sight to the real objective is blocked. This is correct and intentional as an ephemeral, this-tick-only correction; `_maintain_flee_latch` re-derives `step_goal` fresh from the stable `flee_waypoint` every tick the 16-tick countdown hasn't expired, and `_locomote_toward_step_goal`'s own `resolve_path_to_step_goal` call (on the normal consideration cadence) already re-deflects fresh from that stable target every time, non-destructively.

The bug: the function also contained
```gdscript
if bool(ctx.get("flight_fast_path_active", false)):
  state["flee_waypoint"] = state.get("step_goal", Vector3.ZERO)
```
which stamped that tick's ephemeral deflection permanently into the persistent `flee_waypoint` latch. Once stamped, the *next* blocked tick's deflection used the *previous* deflection as its "ultimate" input instead of the real flee objective — a self-referential drift with no path back to the true target short of the whole Flight episode exiting (only `flight_just_exited` calls `clear_flee_waypoint_latch`). Near a wall/boundary, where blocked ticks recur constantly, this produced exactly the observed small-N-point limit cycle: each deflection just bounces off nearby valid waypoints around the corruption point instead of ever recovering the original "away from threat" direction.

The fox's own oscillation (ping-ponging between exactly 2 waypoints near its food target once wall-blocked, `cblk` cycling 0→1→2→0) is the **same underlying `_run_path_clearance_los_nav`/navmesh-first-waypoint instability**, just without a persistent latch to compound the drift — it re-derives from the true food position each remint, so it stays a bounded 2-point oscillation rather than a drifting one. This is the same family as the already-open [C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) LOS/wall-raycast items and is **not** fixed by this change — left open as a C8 follow-up. Neither live pursuit nor flee has an escalation mechanism analogous to explore mode's boundary-scan for "genuinely wall-blocked, try something structurally different" — both just keep re-deflecting forever.

### Fix shipped (2026-07-16)

Removed the `flee_waypoint` stamp from `apply_immediate_blocked_path_reevaluation`. The reactive deflection now only ever touches `step_goal` for the current tick's movement; `flee_waypoint` stays pinned to its original mint until the latch countdown legitimately expires or the Flight episode exits.

New regression test `_test_motor_planner_blocked_move_reeval_preserves_flee_latch` (avoids the currently-broken LOS-raycast detection tracked in C8 by driving the deflection through the raycast-independent backtrack-memory branch instead): asserts `step_goal` still deflects away from a recorded backtrack heading, but `flee_waypoint` is unchanged afterward.

**Duel re-verification (2026-08-05, live):** Fresh `motor_explore_tick.log` capture — fox chased rabbit to the playfield edge and both got stuck. Confirms two things:
1. **The original drift fix holds** — rabbit's `tgt` no longer cycles through a growing/drifting set of waypoints; it's a clean bounded 2-point ping-pong (`(-106.2,19.0)` ⇄ `(-102.4,12.0)`, `dist` flat ~7.9, `err`/`dot` alternating between exactly two values). No self-referential drift observed.
2. **The predicted C8 follow-up is confirmed live, not just theoretical** — the fox chasing that same rabbit instance (`id=181210714463`) shows the identical signature this section already called out: bounded 2-point `tgt` ping-pong (`(-100.6,20.2)` ⇄ `(-99.6,17.4)`), `blk=1` on `MOVE_F`, `cblk` cycling 0→1→2→0, never escalating. Both creatures hit the boundary at roughly the same time and neither has an escalation path out — they just keep re-deflecting at each other indefinitely. See [C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) for the shared root-cause family this now feeds evidence into.

### Acceptance

- [x] `apply_immediate_blocked_path_reevaluation` no longer writes into `flee_waypoint`.
- [x] New test `_test_motor_planner_blocked_move_reeval_preserves_flee_latch` green.
- [x] Full headless suite: stable 8 pre-existing (C8) failures, byte-identical across 3 consecutive runs — no new regressions.
- [x] Duel manual re-verification (rabbit no longer locks into a limit cycle at the playfield edge) — re-run live 2026-08-05, confirmed: bounded 2-point oscillation only, no drift.
- [x] Fox's own wall-oscillation — **root-caused 2026-08-05** (see below); the "same `_run_path_clearance_los_nav` family" hypothesis above was disproven, not confirmed. Real cause identified — tracked as a new C8 fix item, not a C9 change.

### Root-cause correction (2026-08-05, on-demand repro + `NAV_DBG` capture)

The 2026-08-05 duel re-verification's hypothesis above ("same `_run_path_clearance_los_nav`/navmesh-first-waypoint instability") turned out to be **wrong** — caught by adding instrumentation and forcing an on-demand repro rather than trusting the plausible-looking guess.

**Repro method:** manual live reproduction requires both creatures' paths to overlap by chance; to force it on demand, temporarily pinned the duel spawn (`main_3d.gd`, `_DEBUG_FORCE_EDGE_CHASE_SPAWN`) so the rabbit spawns at the playfield edge and the fox spawns on its interior side — guaranteeing the flee direction drives the rabbit into the corner instead of away from it. Also added a `NAV_DBG` print inside `_run_path_clearance_los_nav` logging every time its LOS-blocked latch actually fires and what `_PathClear.resolve_step_objective` resolves to.

**Result:** the forced spawn reproduced the boundary ping-pong for both creatures within ~1800 ticks of the session starting. But `NAV_DBG` **never printed once** across the whole session (`grep -c NAV_DBG godot.log` → `0`) — meaning `_run_path_clearance_los_nav`'s LOS raycast was never latched as blocked, and the navmesh resolution path was never invoked at all. The oscillation is coming from somewhere else entirely. Tracing the actual `motor_explore_tick.log` tick-by-tick during the stuck window found two **separate, previously-undocumented** mechanisms — one per creature:

**Rabbit (flee/`avoid_hostiles`):** confirms the interaction this section's original fix already flagged as an open gap, now pinned down precisely. `_maintain_flee_latch` (`motor_planner.gd`) unconditionally restores the latched `flee_waypoint` at the top of every `select_action` call, for the full `flee_waypoint_latch_ticks` (16) window. When a `MOVE_FORWARD` toward that latched target is blocked, `apply_immediate_blocked_path_reevaluation` computes a one-tick-only 60°-rotated escape point and moves on it *that tick only* (by design, per the 2026-07-16 fix above — this part is correct). But the next tick, `_maintain_flee_latch` runs first and blindly re-institutes the original (still-blocked, wall-facing) `flee_waypoint`, discarding the escape point with no memory that it was just needed. Log evidence (`rabbit#2`, t=1774–1793): `TURN_L` ticks show `tgt=(-9.8,104.3)` (the base, wall-facing latch); `MOVE_F` ticks — the ones immediately following a blocked reevaluation — show `tgt=(-2.8,107.9)` (the rotated escape point), alternating every tick with `dist` pinned flat at ~7.9–7.94 the whole time. Neither point is ever committed to, so the rabbit never actually moves away from the corner.

**Fox (`find_food` live pursuit):** a different, previously-unidentified mechanism: `_remint_alternate_pursuit_detour` (`motor_planner.gd`) alternates its detour angle by `pursuit_detour_alt_flip`, ±60° each remint, every time `consecutive_blocked` reaches `dead_end_record_min_blocked_ticks` (3) — an intentional "try the other side" strategy for a single blocked-by-a-movable-obstacle case. Near a corner, though, *both* ±60°-rotated candidates can be equally blocked by the boundary, so the fox just flips between the same two dead-end waypoints forever, re-triggering every ~3 ticks (matching the observed `cblk` cycling 0→1→2→0). The function's `maxf(dist, 3.0)` distance floor also exactly explains the log's constant `dist=3.00` reading. Log evidence (`fox#2199`, t=1774–1793): `tgt` alternates cleanly between `(-0.8,101.7)` and `(-3.5,100.5)` (a ~3.0-unit apart pair, matching the floor), `blk=1` most ticks, `cblk` cycling 0→1→2→0 without ever escalating past the alt-flip.

**Why this matters beyond "now we know":** both mechanisms share the same shape — a latch/hysteresis system built to prevent single-tick thrash (16-tick flee latch, 32-tick pursuit-detour latch with a 3-tick escalation trigger) has no exit condition for "I've now tried every option this mechanism offers and I'm still stuck" — unlike explore mode, which has `boundary_scan` for exactly this case. Both flee and live-pursuit will oscillate indefinitely once genuinely cornered, with no fallback to a structurally different strategy. This is the same gap the 2026-07-16 fix above already called out in the abstract ("neither live pursuit nor flee has an escalation mechanism analogous to explore mode's boundary-scan") — this session found the concrete mechanism for both, superseding the navmesh-instability guess.

### Fix shipped (2026-08-05)

Gave both mechanisms an escape hatch — same session as the root-cause finding above, verified against the headless suite immediately after (still the same 6-failure C8 baseline, byte-identical, no new regressions):

- **Rabbit (`motor_planner.gd`):** `apply_immediate_blocked_path_reevaluation`'s backtrack branch now tracks a new `flee_backtrack_streak` counter, incremented only when the waypoint it's deflecting off of is literally the currently-latched `flee_waypoint` (`old_goal.is_equal_approx(state.flee_waypoint)` — narrow guard so this can't fire for explore/locale/precise, which hit this same generic backtrack code for their own unrelated reasons). Once the streak reaches `dead_end_record_min_blocked_ticks` (3), instead of waiting out the rest of the 16-tick latch countdown against a target that keeps failing, it forces an early `_mint_flee_waypoint` — a fresh `_flee_objective` recompute from the *current* threat bearing, which has usually shifted enough after a few ticks of the fox closing in to pick a genuinely different direction. `_mint_flee_waypoint` now resets the streak counter itself (single choke point for every fresh mint, natural-expiry or escalated), and `clear_flee_waypoint_latch` resets it too. This does **not** reintroduce the original C9 bug (stamping the ephemeral per-tick deflection into the latch on *every* blocked tick) — it only forces a fresh, independently-recomputed mint after a sustained streak, not the deflection itself.
- **Fox (`motor_planner.gd`):** `_remint_alternate_pursuit_detour` now tracks `pursuit_detour_escalation_count`. The first two escalations still alternate ±60° as before (try one side, then the other); on the third consecutive escalation (both sides tried and blocked again), it gives up on detouring around this waypoint entirely — clears the pursuit-detour latch via `_clear_pursuit_detour_latch` (which also resets the escalation count) instead of reminting a third alternate — so the next tick's `_derive_find_food_step_objective` falls through to a full fresh `_apply_live_food_objective` recompute using the prey's actual current position, rather than another blind ±60° bearing rotation from a stale anchor. `_maybe_mint_pursuit_detour_latch` (the first-mint path, reached after natural latch expiry or this give-up) resets the escalation count too, so each new detour episode starts clean.

**First attempt didn't work — live re-test, 2026-08-05:** re-ran with the forced edge-chase spawn; still stuck in the identical 2-point ping-pong. Traced the fresh `motor_explore_tick.log`: the rabbit's `flee_backtrack_streak` almost certainly did reach the escalation threshold (blocked on every other tick, consistent with the ~3-invocation streak), but the resulting `_mint_flee_waypoint()` re-derive produced essentially the *same* wall-facing point every time — `tgt` barely moved between escalations (`(-9.8,104.3)` → `(-7.6,102.9)` → `(-7.7,102.9)`, converging, not escaping). Root cause of the fix's failure: `_flee_objective` is a pure bearing-away-from-current-threat calculation with zero boundary/geometry awareness — when both creatures are stalemated near a corner, the threat's bearing relative to the rabbit barely changes tick to tick, so "recompute from scratch" just reproduces the same doomed direction. Separately, `_remint_alternate_pursuit_detour`'s escalation (the fox-side fix) turned out to never even fire in this scenario — `consecutive_blocked` capped at 2 in the fresh log, never reaching the 3-tick threshold that gates the first branch of `apply_immediate_blocked_path_reevaluation` — so the fox's observed oscillation isn't its own pursuit-detour bug at all, it's just tracking the rabbit's own oscillating live position (moving prey re-derives the fox's target fresh every tick, unconditionally). Fixing the rabbit should resolve the fox's symptom as a side effect.

**Revised fix:** instead of re-deriving `flee_waypoint` from scratch (`_flee_objective`), promote the already-computed 60°-rotated `deflected` point — the one already known to point somewhere directionally different from the blocked bearing — into the persistent latch once the streak threshold is hit, resetting the countdown. Each escalation still only fires after a sustained streak (not every blocked tick, avoiding the original C9 drift bug), and re-reads the *then-current* `flee_waypoint` as its rotation base each time, so repeated escalations walk incrementally around the corner rather than compounding into unbounded drift. The fox-side `_remint_alternate_pursuit_detour` escalation is left in place as a correct defensive fix for when that path *is* exercised (e.g. a stationary/cached food target rather than live-tracked moving prey), even though it wasn't the active cause here.

**Second live re-test, 2026-08-05 — meaningful improvement, but not fully closed:** the promote-the-deflection fix visibly changed behavior — the rabbit now runs 10-15 clean unblocked `MOVE_F` ticks at a time (real `dist` reduction, e.g. 7.33 → 6.34) between escalation episodes, instead of the frozen tight 2-point ping-pong. But tracing the full `motor_explore_tick.log` window (t=1949 through t=2348, ~400 ticks) showed it's still a **closed loop, just bigger and slower** (period ≈30-40 ticks instead of 2): escalate through a short sequence of rotated waypoints (`(-62,102)→(-58,107)→(-51,105)→(-49,98)`-ish) → clean run down to `dist≈6.3-6.5` → the *natural* `flee_waypoint_latch_ticks` (16-tick) countdown expires independent of any blocked/escalation state → `_maintain_flee_latch` calls `_mint_flee_waypoint`, which re-derives fresh from `_flee_objective` (pure bearing away from current threat) → that recompute happens to point almost exactly back the way it came (`err` flips to ≈-156°, near 180°) → repeat from the top. The escalation fix only guarded the *reactive* blocked-tick path; the natural relatch has the identical blind spot and undoes the escalation's progress every cycle.

**Third fix (same session):** extended the same backtrack check into `_mint_flee_waypoint` itself, so it applies to *every* fresh mint — natural expiry or escalated — not just the reactive per-tick deflection. If the freshly-computed `_flee_objective` bearing is itself a backtrack relative to a recently recorded blocked direction (`_BlockedApproach.active_dir`, same 45-tick-TTL memory the reactive path already uses), rotate it 60° before latching it in. This reuses existing infrastructure rather than adding a new mechanism, and should stop the natural relatch from re-deriving the same wall-facing direction it just escaped from moments earlier.

**Third live re-test, 2026-08-05 — inconclusive on the loop, but the fox actually caught the rabbit for the first time:** re-ran with the forced edge-chase spawn. The rabbit's `dist` trended down cleanly and the fox's pursuit `dist` closed all the way to `0.00` (t=2245, `motor_explore_tick.log`, `fox#6796`) — a genuine contact/catch, which never happened in either prior attempt (both previous fixes kept the pair perpetually not-quite-converging). Whether the underlying flee-loop is *fully* closed is unconfirmed either way, because a **new, separate bug** interrupted the session right at that contact moment — see [C10](#c10-fox-ends-up-under-the-geography-after-close-contact-with-prey-new-2026-08-05) below. Both `godot.log` and `motor_explore_tick.log` stop dead for the fox at the exact same tick the distance hit `0.00`, with the fox's final logged `err` flipped to `+180.0` (facing fully reversed) — consistent with a physics collision-resolution event on deep body overlap, not a script crash (no error printed). Paused the C9 live-verification here per user direction; will need another live pass once C10 is investigated separately, since a fox that falls through the floor on contact can't be distinguished from "the fox just isn't chasing effectively" in this log format alone.

### Automated headless confirmation (2026-08-06): 3rd fix does not close the loop

The 3rd C9 live re-test above ended inconclusive because C10 interrupted the session before contact could be re-checked cleanly. Rather than repeat manual live duels (slow, and each run is destroyed by whatever bug fires first), built automated tooling to answer the flee-loop question directly and repeatably, offline:

- **`tests/smoke_ai_player.gd`** — a headless `SceneTree` driver (`godot --path . --headless -s res://tests/smoke_ai_player.gd`) that instantiates `main_3d.tscn`, calls the exact code path the "AI Player" HUD button triggers (`AiDriver.begin_engine_player_round()` then `Main3D.new_game()`), runs a configurable number of physics ticks (`_RUN_TICKS`), then quits — reproduces `_DEBUG_FORCE_EDGE_CHASE_SPAWN` sessions without a human driving the HUD.
- **Live invariant-assertion harness** — added directly to [`CreatureMotorStack.tick()`](../../creature/motor/creature_motor_stack.gd), gated `const _DEBUG_ASSERT_MOTOR_INVARIANTS := true`, permanent until C9/C10 both close. Runs at the end of every tick and trips (`push_error` with creature label + reason + full state dict, then `get_tree().quit(1)`) on: NaN/Inf position; prolonged airborne (`not is_on_floor()` for >45 ticks after a 45-tick post-spawn settle grace period — catches C10); `flee_waypoint` repeating a value from recent history on a genuine remint (catches C9); unblocked `MOVE_FORWARD` with <0.02 net displacement over a 30-tick window (generic stall catch-all, not yet triggered). Halts the run dead on the exact offending tick instead of requiring log archaeology after the fact.
- Two iterations were needed to stop the harness false-positiving before it produced a trustworthy result: the airborne check originally compared spawn-Y vs current-Y (false-positived on legitimate slope settling), replaced with `is_on_floor()`-based detection; the flee-waypoint-repeat check originally compared every tick's value against history (false-positived on the latch's *intended* multi-tick persistence), fixed to only record/compare on genuine remint events and to clear history when `flee_waypoint` resets to `Vector3.ZERO` at Flight-episode end.

**Result:** on a 3600-tick headless run with the corrected harness, the invariant tripped at **tick 1792** — `flee_waypoint` caught cycling between exactly two fixed points, `(-88.6/88.7, 83.7/83.8)` and `(-77.5, 73.4)`, alternating every ~17 ticks with a `TURN_L`/`TURN_R` in between each flip. Manually re-read the full `motor_explore_tick.log` trace for ticks 1700–1792 to confirm this wasn't a harness artifact: it's a real remint-to-remint repeat, `dist` to the threat holding steady at 6–8 units the whole window and never closing. This is the same *shape* of bug the 3rd fix (backtrack-rotation check in `_mint_flee_waypoint`) was meant to close — the fix produced a **tighter, cleaner 2-point cycle**, not an escape. Reasonable read: `_mint_flee_waypoint`'s backtrack-rotation check only rotates the newly-computed bearing away from *one* recently-recorded blocked direction (`_BlockedApproach.active_dir`); with two fixed obstacles/threat geometry pinning the rabbit at this spot, the rotated candidate lands close enough to the *other* blocked direction to itself get flagged and rotated back next remint, giving exactly two stable candidates and no third option or give-up condition — matching the "no third option" framing carried over from last session's trajectory note, now confirmed rather than hypothesized. **Not yet traced line-by-line inside `_mint_flee_waypoint` / the rotation math itself** — this pass confirms *that* the loop persists and *what* the two trapped points are, not yet *which line* produces the second point from the first.

Separately (not yet dug into): the 900-tick and early-3600-tick windows of these runs showed the fox spending long stretches in `gk=find_food` and the rabbit in `gk=avoid_host` well before any flee/pursuit interaction started — real dead time before the forced-edge-chase repro engages, which is why `_RUN_TICKS` needed to go from 900 to 3600 to catch anything in this harness.

C10 was **not** reproduced in this session's runs — the flee loop caught here happened at `dist` 6–8, before the pair ever reached contact (`dist=0.00`) where C10 previously triggered. The airborne-based invariant check is in place and ready to catch it live or headless whenever a run does reach contact.

### Root cause, traced (2026-08-06): why the 3rd fix's rotation only ever finds two candidates

Traced `_mint_flee_waypoint` and `BlockedApproachMemory` (`blocked_approach_memory.gd`) line by line against the tick-1792 repro. Two facts compound into an exact 2-cycle:

1. **`blocked_approach` is a single-slot memory** ([`BlockedApproachMemory.record`](../../creature/motor/blocked_approach_memory.gd)) — one direction, one 45-tick TTL, overwritten every blocked tick. It can never hold more than "the one direction most recently walked into."
2. **The rotation is a fixed +60°, and the backtrack-dot threshold (`blocked_approach_backtrack_dot`, default 0.55) sits just above `cos(60°) = 0.5`.** So: mint *N* is flagged as a backtrack against the direction the rabbit was just blocked walking (dot ≈ 1.0 ≥ 0.55) and rotates +60° to a new point. The rabbit then gets blocked trying to walk *that* new point, so the single-slot memory is overwritten to point at it. Mint *N+1* recomputes the raw bearing fresh — `_flee_objective` has no obstacle awareness, so while cornered this raw bearing is essentially unchanged from mint *N*'s raw bearing — and checks it against the memory, now holding the +60° point: `dot(raw, raw+60°) = cos(60°) = 0.5`, which is **just under** 0.55, so it reads as "clear" and un-rotates straight back to the original (still-blocked) bearing. Repeat forever. The single-slot memory has no way to remember "the +60° point was *also* already tried and failed" once it's overwritten — there is no third option because nothing survives long enough to be a third option.

### Fix attempted (2026-08-06): rolling multi-direction history

Replaced the single-slot backtrack check with a short rolling history (`state["flee_recent_dirs"]`, up to 3 entries, same 45-tick TTL as `blocked_approach`) of this Flight episode's last few *minted* directions — not just the single most-recently-blocked one. On each mint, rotate the candidate by +60° increments (capped at 5 attempts) past *every* direction currently in that history, not just the latest. Both `_mint_flee_waypoint` and `clear_flee_waypoint_latch` updated; new `flee_recent_dirs` state field added and reset on Flight-episode exit. [`motor_planner.gd`](../../creature/motor/motor_planner.gd).

**Headless regression check:** full `run_all.gd` suite aborted before finishing — traced to the live invariant harness (added last session) false-tripping C10's airborne check inside `_test_motor_locale_approach_no_oscillation_smoke`, a synthetic fixture with no floor under it. Confirmed this is **pre-existing and unrelated** to this fix (reproduced identically on the pre-fix code via `git stash` isolation — byte-identical abort point on both). Worked around by temporarily setting `_DEBUG_ASSERT_MOTOR_INVARIANTS := false` for one verification run (reverted immediately after): suite completed with the same **6 pre-existing assertion failures**, byte-identical names, on both pre-fix and post-fix code. No regression. *(The `run_all.gd` / synthetic-fixture incompatibility with the invariant harness is a separate, still-open gap — the harness assumes real playfield geometry under every spawn, which unit-test fixtures don't provide. Not fixed here; flagging for whoever next touches the harness.)*

**Automated headless re-verification (harness back on, `smoke_ai_player.gd`, 3600 ticks): partial success, loop not fully closed.** The tight, exact 2-point resonance from the 3rd fix is gone — confirmed no repeat of the old signature. But the invariant still tripped, at **tick 1478** this run, on `flee_waypoint = (-58.3, 32.1)` repeating a value from the harness's 20-entry history. Traced the full `hunter_killer.log` window (t=1200–1478, ~280 ticks): the rabbit visited **17 distinct `tgt` waypoints** in that window (vs. exactly 2 before) — the rotation-past-history fix is demonstrably working, it's no longer a simple resonance. But every one of those 17 points sits in the same bounded ~15×15 unit patch, and `dist` to the threat held flat in a 6.8–7.9 band the entire window — **zero net progress**. This is the same shape the doc's 2nd-fix attempt hit ("bigger and slower" loop, not an escape) recurring one level up: `_mint_flee_waypoint`'s rotate-past-recent-history logic can steer the candidate around *within* whatever local space is reachable, but `_flee_objective` itself has no notion of "is there actually open room over there" — near a genuine corner, every direction within reach is some flavor of blocked, so rotating just cycles through a larger set of equally-bad local points instead of finding real escape space. This is the R1 architecture risk's "no obstacle awareness in the fixed-goal calculation" gap, now confirmed to survive a 4th iteration of local patching, not just a hypothesis.

**Assessment:** closing this fully likely requires giving the flee-target *selection* itself some geometry/reachability awareness — e.g. sampling a few candidate bearings and checking each against navmesh/LOS clearance (the way `pursuit_detour`'s nav substep already does for C1) rather than pure bearing-away-from-threat math with post-hoc rotation. That's a larger change than another rotation-heuristic patch.

### 5th fix (2026-08-06): geometry-scored candidate selection, plus a real headless-tooling bug found and fixed along the way

User chose to scope the geometry-aware approach rather than attempt another rotation-only patch. Implementation: `_mint_flee_waypoint` now scores 6 candidate bearings (60° apart, starting from the raw threat-away bearing) by **actual navmesh-reachable distance** — new [`_flee_candidate_reach`](../../creature/motor/motor_planner.gd), which calls `NavigationServer3D.map_get_path(map_rid, creature_pos, candidate, true)` and measures how far along that path the creature can really get, clamped short of the requested distance whenever geometry blocks the way. This reuses the exact primitive `_remint_alternate_pursuit_detour` already uses for C1 (`_PathClear`/`_NavHint` → `NavigationServer3D.map_get_path`), just applied at *candidate-scoring* time instead of only reactively after a step-goal is already blocked. Picks the best-reaching candidate that also isn't a recent-history backtrack (falls back to best-reaching-overall if every candidate collides with history, so it never regresses below the 4th fix's floor).

**Headless verification caught a real, separate bug in the test tooling itself, not in the fix:** first pass of `smoke_ai_player.gd` runs showed zero navmesh differentiation — instrumented `_flee_candidate_reach` directly and confirmed `NavigationServer3D.map_get_path` was returning **empty paths for every single query** (1116/1116 samples in one run). Root cause: `NavigationRegion3D.bake_navigation_mesh()` (`main_3d.gd` `_bake_playfield_navmesh`) bakes on a background thread — `get_navigation_map_rid()` returns a valid RID the instant baking *starts*, not when it *finishes*, and `smoke_ai_player.gd` was only waiting 2 process frames before running the full 3600-tick loop. Every path query for the entire headless run was silently querying an unbaked (empty) navmesh. **This means the geometry-aware fix was never actually being tested at all in its first few verification runs** — the harness itself was blind to it. Fixed properly: added `Main3D._nav_baked` + `bake_finished` signal wiring + `is_navigation_ready()` (`main_3d.gd`), and `smoke_ai_player.gd` now polls (capped at 600 frames) until the bake genuinely completes before starting ticks. *(This same blind spot likely means `_remint_alternate_pursuit_detour`'s C1 nav-substep behavior has also never been exercised by headless smoke testing — only by live duels, which always have time for the bake to finish before a human clicks anything. Worth knowing if C1 ever needs headless re-verification.)*

**Headless regression check (suite):** same 6 pre-existing failures, byte-identical, both before and after this fix (invariant harness temporarily disabled for the check, same pre-existing `run_all.gd`/synthetic-fixture incompatibility as before, same workaround). No regression, including from the `main_3d.gd` navmesh-ready wiring.

**Result, with the navmesh genuinely engaged, 4 repeated 3600-tick headless runs (`_DEBUG_FORCE_EDGE_CHASE_SPAWN`):** 2 of 4 ran the full 3600 ticks with **zero invariant trips of any kind**. The other 2 still tripped the C9 boundary-ping-pong check, but markedly later than every prior fix generation — tick 2405 and tick 872 (vs. ~500–1800 across the 3rd/4th fix's runs). Real, measurable improvement — not a full close. Run-to-run variance (2/4 clean vs. 2/4 still trapped, despite the forced spawn point being deterministic) means some downstream timing/cadence non-determinism affects which side of the corner the rabbit and fox end up favoring; not chased down further this session. Some corner configurations still leave every one of the 6 candidate bearings genuinely low-reach (the corner really doesn't have 6 good directions), so scoring-by-reach alone doesn't guarantee escape — it just makes bad candidates far less likely to keep winning.

**Assessment:** this is real, verified progress and the correct next step was taken (geometry awareness, not another rotation heuristic) — but C9 is not fully closed. Leaving open rather than claiming done.

### 6th fix (2026-08-07): give-up escalation, modeled on explore's `boundary_scan`

The 5th fix's own assessment named the remaining gap precisely: "some corner configurations still leave every one of the 6 candidate bearings genuinely low-reach — scoring-by-reach alone doesn't guarantee escape." Neither flee nor live-pursuit had ever had an equivalent of explore mode's `boundary_scan` — the "genuinely stuck, try something structurally different" escape hatch this doc's root-cause section (2026-08-05) already named as the missing piece. User-directed design discussion before implementation, explicitly framed around passing a "sniff test for something a cornered animal would really do."

**Why not a literal port of `boundary_scan`:** `boundary_scan` works by stopping forward progress and rotating in place for several ticks (a turn budget) before committing to whatever heading looked clearest. That's a reasonable behavior for unhurried exploration, but it fails the sniff test for panic flight — a real cornered prey animal doesn't pause to slowly survey its surroundings while a predator is closing the last few meters; multi-tick deliberation at that range gets it caught. The two things worth keeping from `boundary_scan` are its *shape* (finer-grained search than the normal path, and committing to whatever real opening turns up) and its *behavioral trigger* (a structural "give up on the careful approach" moment) — not its literal turn-and-look mechanic.

**Design:** `_mint_flee_waypoint` (`motor_planner.gd`) already scores 6 candidate bearings (60° apart) by real navmesh-reachable distance (5th fix). After picking the best of those 6, check whether even that best candidate's reach is below `flee_give_up_reach_frac` (new default **0.35**) of the requested flee distance — i.e., genuinely cornered, not just locally obstructed. If so, escalate same-tick (no extra ticks spent, unlike `boundary_scan`'s turn budget) to a much finer full-circle sweep (`flee_give_up_scan_directions`, new default **16**) and — unlike the normal 6-candidate sweep — don't filter candidates by recent-backtrack history at all: a direction the creature was blocked from a few ticks ago and is now the *only* real opening is still the only real opening. This matches documented real anti-predator behavior more closely than continuing to optimize a threat-bearing calculation that has no notion of "open" at all — cornered prey break for the nearest real gap, including laterally past the predator's flank, rather than continuing to insist on "directly away." Escalated waypoints also latch for a much shorter window (`flee_give_up_latch_ticks`, new default **5**, vs. the normal **16**) — a cornered animal re-assesses far more often, because the situation changes fast at that range. New `state["flee_give_up_active"]` flag drives the shortened latch and resets in `clear_flee_waypoint_latch` on Flight-episode exit, same as the other flee-scoped fields.

**Headless verification:** full `run_all.gd` suite (invariant harness off per the still-open synthetic-fixture gap) — zero assertion failures, matching C8's fully-closed state; no regression. 4 repeated 3600-tick `smoke_ai_player.gd` runs (`_DEBUG_FORCE_EDGE_CHASE_SPAWN`, invariant harness on): **3/4 completed with zero invariant trips** (up from the 5th fix's 2/4), the remaining 1/4 tripped at tick 927. Real further improvement, not a full close — run-to-run variance (first flagged after the 5th fix, still unexplained) persists. The one trip's logged `flee_waypoint` was `(0.0, -4.62, 0.0)` — exactly on the world origin in the horizontal plane, which reads as a genuinely degenerate case (possibly the momentary no-threat-in-awareness fallback in `_flee_objective`, which still has no geometry awareness of its own and feeds a nonsense bearing into the same candidate-scoring machinery) rather than the give-up escalation itself misbehaving. Not dug into further this session — flagging as a candidate root cause for whoever continues C9.

### 7th fix (2026-08-07): flee-to-world-origin sentinel bug

Followed up on the 6th fix's flagged candidate root cause. Traced two facts that compound:

1. **`AwarenessZone.line_of_sight_clear`** (`awareness_zone.gd`) is a **raw per-tick** occlusion check — unlike the path-clearance LoS check (`_run_path_clearance_los_nav`), which has `los_hysteresis_ticks` specifically as a thrash-guard "for tight obstacle pockets," threat-awareness LoS has no equivalent. Near corner geometry — exactly where flee is most likely to be re-minting — `occlusion_fraction` can flicker a threat sample's `in_awareness` false for a single tick even though the threat is still genuinely nearby and dangerous.
2. **`_flight_fast_path_active`'s own latch** (`creature_motor_stack.gd`, `_update_flight_fast_path`) doesn't require a fresh acute threat every tick once armed — it stays active as long as `not _safety_met`. So the Flight episode (and the flee-waypoint remint machinery) keeps running through that flicker tick.

When the flicker landed on the exact tick the flee-waypoint latch happened to expire, `_mint_flee_waypoint` called `_flee_objective`, which returns `Vector3.ZERO` as its documented "no in-awareness threat" sentinel — but `Vector3.ZERO` is *also* a valid world position (the origin), and `_mint_flee_waypoint`'s only zero-check was on `to_wp` (the vector *relative to the creature*, generally nonzero unless the creature happens to be standing on the origin), not on `wp` itself. So the candidate-scoring machinery ran treating "the world origin" as a genuine flee destination — bearing `to_wp.normalized()` pointed at `(0,0,0)`, and distance `to_wp.length()` was however far the creature happened to be from the origin that tick. The 6th fix's finer give-up scan searched hard enough to actually land a waypoint there, which is what tripped the tick-927 invariant — the give-up escalation didn't cause this bug, it just had enough search resolution to expose it.

**Fix:** new `_flee_has_visible_threat(ctx)` helper checks `threat_samples` for a live `in_awareness` entry directly, instead of relying on `_flee_objective`'s ambiguous `Vector3.ZERO` return to signal "no answer." When `_mint_flee_waypoint` finds no visible threat this tick, it now holds the existing latched `flee_waypoint` (resetting its countdown) instead of reminting from the sentinel — matching real behavior: an animal that loses sight of a predator for one tick keeps running the way it was already going, it doesn't reroute toward a fixed point. Falls back to a spawn-facing waypoint only if there's no prior latched waypoint to hold (a Flight episode somehow entering with no live threat that exact tick — shouldn't normally happen, but defensive), mirroring `_flee_objective`'s own existing co-located-threat fallback.

**Headless verification:** full suite — zero assertion failures, no regression. 6 repeated 3600-tick `smoke_ai_player.gd` runs: **zero C9 (flee-waypoint boundary-ping-pong) trips across all 6** — the origin-waypoint failure mode did not recur once. 1/6 runs did trip, but on the unrelated C10 airborne/off-floor check (`fox` stuck under geometry at tick 731) — C10 was previously marked `fixed` with "10/10 clean post-fix runs"; this is a new data point suggesting it isn't fully 100%, flagged as a separate follow-up, not investigated this session.

### Acceptance (fix)

- [x] `flee_backtrack_streak` escalation added, scoped to only the flee-latch backtrack case.
- [x] `pursuit_detour_escalation_count` escalation added, gives up after both alternate sides fail once.
- [x] Full headless suite: still the same 6 pre-existing (C8) failures, no new regressions.
- [x] **First fix attempt live-tested and found insufficient** — re-derive-from-scratch doesn't escape a bearing-only calculation's blind spot; see above.
- [x] **Second fix (promote deflection into latch) live-tested — improved but not sufficient** — real movement bursts now happen, but the natural 16-tick relatch reopens the same loop at a larger scale; see above.
- [x] Third fix: apply the same backtrack-rotation check to every `_mint_flee_waypoint` call (natural expiry included, not just escalation); headless suite re-verified clean.
- [x] **Automated headless re-verification (3rd fix), 2026-08-06: confirmed NOT sufficient** — new live invariant harness + `smoke_ai_player.gd` caught a stable 2-point `flee_waypoint` cycle at tick 1792 of a 3600-tick run.
- [x] **Root-caused (2026-08-06)** why the 3rd fix only ever produces two candidates: single-slot `blocked_approach` memory + fixed 60° rotation + a 0.55 backtrack threshold just above `cos(60°)=0.5` — see above.
- [x] **4th fix (2026-08-06): rolling multi-direction history in `_mint_flee_waypoint`** — headless suite re-verified clean (same 6 pre-existing failures).
- [~] **4th fix live/headless re-verification: partial** — exact 2-point resonance confirmed gone (17 distinct waypoints visited vs. 2), but still zero net progress over a 280-tick window near the corner; invariant still trips. Not closed.
- [x] **5th fix (2026-08-06): geometry-scored candidate selection** (`_flee_candidate_reach`, navmesh-reachability-based) — user directed scoping this over another rotation-only patch; headless suite re-verified clean (same 6 pre-existing failures).
- [x] **Found and fixed a real headless-tooling bug along the way:** `smoke_ai_player.gd` was running the full 3600-tick repro against a navmesh that hadn't finished its background-thread bake yet, so every path query the 5th fix relies on was silently empty. Added `Main3D.is_navigation_ready()` (bake-finished signal) and made the smoke driver wait for it. Likely also means C1's nav-substep pursuit-detour behavior has never been genuinely exercised by headless testing before now.
- [~] **5th fix live/headless re-verification: real improvement, not fully closed** — 4 repeated 3600-tick runs: 2/4 completed with zero trips of any kind, 2/4 still tripped C9 but far later than any prior fix (tick 872, tick 2405 vs. ~500–1800 before). Some corner configurations still leave every candidate bearing genuinely low-reach.
- [x] **6th fix (2026-08-07): give-up escalation** (`flee_give_up_reach_frac` / `flee_give_up_scan_directions` / `flee_give_up_latch_ticks`) — user-directed design discussion first (explicit "sniff test" bar), then implementation; headless suite re-verified clean (0 assertion failures, matches C8-closed baseline).
- [~] **6th fix live/headless re-verification: further real improvement, not fully closed** — 4 repeated 3600-tick runs: 3/4 completed with zero trips (up from the 5th fix's 2/4), 1/4 still tripped, at tick 927. The one trip's logged waypoint looks like a separate, still-open degenerate case (`_flee_objective`'s no-threat-in-awareness fallback), not the escalation itself misbehaving — not confirmed.
- [x] **7th fix (2026-08-07): flee-to-world-origin sentinel bug** (`_flee_has_visible_threat`, hold-last-waypoint fallback) — confirmed the 6th fix's flagged hypothesis: raw (non-hysteresis) threat-awareness LoS flicker + `_flee_objective`'s ambiguous `Vector3.ZERO` sentinel. Headless suite re-verified clean (0 assertion failures).
- [~] **7th fix live/headless re-verification: zero C9 trips across 6 repeated runs** — the origin-waypoint failure mode did not recur once. 1/6 runs tripped on the unrelated, previously-"fixed" C10 airborne check instead — new, unexamined data point, not a C9 regression. Not enough repro budget spent yet to call C9 formally `done`.
- [ ] **Decision needed:** spend more repro budget on C9 to build confidence toward `done` (6/6 is promising but thin), investigate the new C10 airborne recurrence (1/6, unrelated to C9), dig into why run-to-run variance existed in earlier fixes despite a deterministic forced spawn, or accept current state and move on / revisit alongside the R1 architecture-risk work.
- [ ] Separately: fix or scope the `run_all.gd` / live-invariant-harness incompatibility found during this session's regression check (synthetic fixtures with no floor false-trip the C10 airborne check) — currently worked around by hand each time, not fixed.
- [ ] Remove `_DEBUG_FORCE_EDGE_CHASE_SPAWN` from `main_3d.gd` once live-verified (still needed for both C9 and C10 repro).
- [ ] Remove `tests/smoke_ai_player.gd`'s reliance on manual `_RUN_TICKS` tuning once the invariant harness is trusted enough to run to a fixed cap by default — not blocking, tooling polish only.

---

## C10 — Fox ends up under the geography after close contact with prey (new, 2026-08-05)

**Status:** `fixed` — **two independent causes found and fixed 2026-08-06; a third, same-family recurrence found and fixed 2026-08-07.** Cause 1: a boulder at `Obstacles3D/@Node3D@595`, world pos `(-52.0, -1.55, -6.31)`, sat un-tilted on a steep valley-slope with fragile concave-trimesh collision — fixed by baking convex hulls for obstacle props (9/10 headless runs clean, up from a lower pre-fix rate). Cause 2: the remaining ~1/10 terrain-only trips (no boulder within 12 units) were confirmed via a raycast-grid probe to **not** be a geometry hole — the slope surface there is solid and continuous (30.2°, well under the 50° `floor_max_angle`) — so the tunneling was traced to `CharacterBody3D`'s collision `safe_margin` sitting at Godot's default (0.001m), too thin relative to creature speed (fox `max_speed=7.0` → ~0.117m/tick at 60Hz) crossing a concave terrain trimesh; fixed by setting `safe_margin = 0.06` on both creature templates. **Verified then: 10/10 post-fix headless runs, zero C10 trips.** **2026-08-07:** the C9 give-up-escalation verification runs hit a fresh C10 trip (fox airborne 46+ ticks near `(-60.0, -2.52, -7.33)`) — confirmed via a fresh raycast-grid probe this was the **same cause-2 family, not a new mechanism**: no boulder anywhere nearby, real continuous single-collider terrain at the same ~30° slope grade, fox position measurably below the actual surface height. The `safe_margin = 0.06` fix reduces but doesn't fully eliminate this class of tunneling — the original "10/10" verification was evidently a favorable sample, not full closure. Bumped `safe_margin` **0.06 → 0.15** on both creature templates; re-verified **10/10 clean headless runs, zero trips of any kind** (C9 or C10). See "Recurrence and re-fix" below. Contact-with-prey was the original (now disproven) hypothesis.  
**Slice:** unassigned — physics/collision (obstacle placement + collision-shape generation in `main_3d.gd` / `playfield_bounds_3d.gd` — obstacle-prop half fixed); remaining terrain-only tunneling likely same family as [C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit)'s thin-wall tunneling finding; **not** related to C3/EAT-contact geometry (ruled out)  
**Evidence:** live duel session, forced edge-chase spawn (`main_3d.gd`, `_DEBUG_FORCE_EDGE_CHASE_SPAWN`) — user report: "the fox appeared to somehow end up under the geography so the rabbit was able to escape and the fox was essentially trapped."

### Symptom

User observed the fox visually stuck underneath the playfield geometry (out of the normal play area, unable to continue the chase), letting the rabbit escape freely. Not reproduced on purpose — found incidentally while live-verifying the [C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) flee-loop fix (3rd attempt) with the forced edge-chase spawn active.

### Log evidence

`motor_explore_tick.log` (`fox#6796`) shows the fox's pursuit `dist` to the rabbit closing cleanly tick over tick (`0.56 → 0.02 → 0.00` at t=2245) — genuine contact, the first time in any of this session's repro attempts the pair actually converged rather than perpetually not-quite-meeting. The very next line (t=2246) is the fox's **last** logged tick: `dist=0.02`, `err=+180.0`, `dot=-1.000` — facing flipped fully backward in a single tick. Both `motor_explore_tick.log` and `godot.log`'s `ARR_DBG` prints stop dead for the fox at that exact tick; the rabbit keeps logging normally afterward, still flagged `ff=1 thr=1` (still perceives the fox as an active threat, consistent with the fox's body/Node still existing somewhere, just no longer able to chase). No script error or warning was printed at or after the cutoff — this doesn't look like a crash, more like the fox's tick processing silently stopped producing normal output (consistent with a physics state the character controller doesn't know how to recover from, e.g. resting on nothing / falling with no floor to detect).

### Root cause hypothesis (not investigated)

Not confirmed — the tick log doesn't record body Y-position/`is_on_floor`, so there's no direct telemetry of the fall itself, only its immediate precondition (dist-to-prey hitting exactly 0) and its immediate aftermath (fox stops appearing in the log). Leading hypothesis, in order of plausibility:

1. **Deep body-overlap physics resolution near a corner.** The fox closing to `dist=0.00` means its `CharacterBody3D` capsule is now deeply interpenetrating the rabbit's, *and* this happened right at the forced-repro playfield corner (two nearby walls plus the other creature's collider all resolving overlap at once) — a maximally degenerate case for `move_and_slide`'s collision resolution, which could eject the fox along an unintended axis (e.g. straight down) if the overlap-resolution push vector ends up pointing through a thin floor collision plane instead of sideways.
2. **Possible link to C3.** [C3](#c3-prey-contact-without-eat--body-pin-stall-fox)'s fix made `_can_eat_now` gate on distance-to-`step_ultimate_pos` (5m) and a 90° facing arc — at `dist=0.00` the fox should be well within EAT range, but the log shows `act=MOVE_F` continuing, not `act=EAT`, right up to the cutoff. Worth checking whether the logged `dist` here is actually distance-to-`step_ultimate_pos` (what C3 gates on) or distance-to-`step_goal` (a nav substep, which can be `0.00` without the true ultimate being in EAT range) — if it's the latter, the fox was closing on a substep, not the rabbit's real body, and the deep overlap with the *substep* point rather than the rabbit could be a red herring for why EAT didn't fire, but wouldn't itself explain physically clipping through geometry.
3. **Possible link to C8's already-tracked physics family** — `_test_locomotion_executor_move_blocked`'s open item describes a body ending up in continuous freefall with `on_wall=false`/`on_floor=false` after clipping through a thin wall in a headless test; this could be the same underlying Jolt/collision-margin issue, now triggered live by creature-to-creature contact instead of creature-to-wall contact.

### Why this surfaced now, not earlier

This session's [C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) fixes (escalating flee-latch re-mint) are very likely *why* this was reachable at all — in every prior repro (before or during this session's C9 fixes), the fox and rabbit stayed perpetually a few units apart, oscillating without ever truly converging. The 3rd C9 fix let the fox close the distance all the way to contact for the first time. This is a case where fixing one bug made a previously-unreachable bug reachable, not a regression introduced by the C9 change itself.

### Open questions

- Does this reproduce reliably, or was it a one-off? Needs another live pass with the forced edge-chase spawn (still active) to see if repeated close-contact events near the corner reproduce it.
- Is the logged `dist` field distance-to-`step_goal` or distance-to-`step_ultimate_pos`? Matters for whether this is EAT-range-adjacent (C3) or purely a physics-resolution issue.
- Does this reproduce away from the boundary corner (i.e., is the corner geometry required, or does any close fox/rabbit contact risk it)? The forced-spawn repro always happens near a corner, so this hasn't been isolated from "cornered" as a variable.
- Add temporary Y-position / `is_on_floor` logging to the tick log (or a dedicated print) before the next repro attempt, so the actual fall is directly observable rather than inferred from the tick log going quiet.

**2026-08-06 update:** the requested Y-position/`is_on_floor` telemetry now exists, generalized rather than one-off — the live invariant-assertion harness in [`CreatureMotorStack.tick()`](../../creature/motor/creature_motor_stack.gd) (see [C9's automated headless confirmation](#c9--flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge)) checks `is_on_floor()` every tick and trips immediately (with position/tick/creature-label state dump) on >45 consecutive airborne ticks past spawn settle. This session's headless runs (`tests/smoke_ai_player.gd`, up to 3600 ticks) never reproduced C10 — the pair never reached `dist=0.00` contact, so the airborne condition was never exercised either way. Still open, still not reproduced on demand; the detection is just ready and waiting for the next run that does reach contact, headless or live.

### 2026-08-06 (later same day): reproduced via headless smoke, and the original "contact-triggered" hypothesis is wrong

User hit this live while running the C9-fix smoke test independently (`MOTOR_INVARIANT [fox#14608609841419] airborne/off-floor for 45+ ticks ... pos=(-58.28999, -2.644285, -7.159983), tick=462`). This session had *also* already caught the same signature twice earlier while headless-verifying the C9 5th fix, before the airborne threshold was temporarily raised to push past it: `fox#150407745847` at tick 506, `pos=(-56.85418, -2.611299, -4.598555)`. Both are the fox, both land within a few meters of each other (X ≈ −57 to −58, Z ≈ −5 to −7, Y ≈ −2.6), both happen **well under 600 ticks into the run** — long before any prey contact (`dist=0.00`) is realistically reached (the pair typically doesn't even start closing distance until several hundred to a thousand+ ticks in). **This directly contradicts the original "deep body-overlap at contact" hypothesis** — these falls have nothing to do with the rabbit at all.

Added temporary per-tick `is_on_floor()`/position/velocity tracing (`creature_motor_stack.gd`, removed after this investigation — not left in) and ran the headless repro repeatedly (10 runs total this session). C10's full 45+-tick trip is intermittent (~1–2 in 10 runs in this sample) but a **partial, self-recovering fall** was caught in flight in one run, and it's conclusive:

```
LEFT FLOOR tick=208 pos=(-49.94, -1.21, -8.89) vel=(-0.92, 0.00, 1.59)
still airborne tick=213 pos=(-50.08, -1.25, -8.66) streak=5  vel=(-2.06, -0.82, 2.84)
still airborne tick=218 pos=(-50.27, -1.35, -8.42) streak=10 vel=(-2.61, -1.63, 2.77)
still airborne tick=223 pos=(-50.52, -1.53, -8.19) streak=15 vel=(-3.37, -2.45, 2.68)
LANDED    tick=227 pos=(-50.78, -1.71, -8.01) after 19 airborne ticks
```

`vel.y` accelerates smoothly and monotonically downward (0 → −0.82 → −1.63 → −2.45, consistent with gravity, not a teleport/glitch), and the fox lands again ~0.5 units *lower* than where it left the floor — this is a genuine, gradual sink into geometry, self-arrested this time by hitting a lower collision surface, not always. The two full-trip locations (tick 462/506, ending Y ≈ −2.6) are the same event just not catching a lower floor in time. All observed events cluster around the same world-space neighborhood (roughly X: −50 to −58, Z: −5 to −9) and all happen early, independent of prey proximity — strongly pointing at a **specific terrain-collision defect near that location**, not a contact/overlap-resolution issue. The codebase already documents a "valley depression" in the procedurally-generated terrain and a related navmesh rasterization/`cell_height` alignment concern at elevation changes ([`main_3d.gd`](../../main_3d.gd) `_bake_playfield_navmesh`) — this is circumstantially consistent with the fall location being a slope/elevation transition in that same terrain, where the **physics collision** (not just the navmesh) may have an analogous gap or thin-wall tunneling issue. Also consistent with the already-tracked [C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) physics-tunneling family (`_test_locomotion_executor_move_blocked`'s freefall-after-clipping-through-a-thin-wall finding) — leading hypothesis #3 below, previously speculative, is now the best-supported one.

**Superseded:** hypothesis #1 (deep body-overlap at contact) and hypothesis #2 (C3 EAT-range interaction) — both assumed the fall required prey contact, which this session's evidence rules out. Renamed/reframed below; not deleting the original reasoning since it was a reasonable read of the evidence available at the time.

### Root cause hypothesis (not investigated)

~~Not confirmed — the tick log doesn't record body Y-position/`is_on_floor`~~ **Superseded 2026-08-06** — see above; Y-position/velocity telemetry now exists and points at terrain-collision tunneling near a specific world-space region, independent of prey contact. Original three hypotheses, for history:

1. ~~Deep body-overlap physics resolution near a corner (contact-triggered).~~ **Ruled out** — falls reproduce with no contact anywhere nearby, hundreds of ticks before the pair could plausibly be at `dist=0.00`.
2. ~~Possible link to C3's EAT-range gate.~~ **Ruled out for the same reason** — not contact-adjacent.
3. **Possible link to C8's already-tracked physics family** (`_test_locomotion_executor_move_blocked`'s freefall-after-clipping-through-a-thin-wall finding) — **now the leading, best-evidenced hypothesis**, not just a speculative third option. The gradual, gravity-accelerated sink profile matches "tunneled through a thin/steep collision surface" far better than a contact-overlap ejection (which would look like an instantaneous velocity spike, not a smooth multi-tick accel curve).

### Open questions

- ~~Does this reproduce reliably, or was it a one-off?~~ **Answered:** reproduces intermittently (~1–2 in 10 headless runs this session), not a one-off, not contact-dependent.
- ~~Is the logged `dist` field distance-to-`step_goal` or distance-to-`step_ultimate_pos`?~~ **Moot** — contact isn't the trigger.
- **New:** what specific terrain feature sits near world-space X: −50 to −58, Z: −5 to −9 in the forced-edge-chase-spawn playfield? Is it the "valley depression" already referenced in `main_3d.gd`'s navmesh-baking comments, or something else (a boulder, a slope, an obstacle placement)? Needs a direct look at `_bake_ground_sampler`/`playfield_ground_sampler.gd`'s elevation data and the actual collision shapes generated there, not just the navmesh.
- **New:** is this specific to the forced-edge-chase spawn's terrain seed, or does it reproduce at other locations too (i.e., is it a systemic slope-tunneling issue anywhere the terrain gets steep, or a one-off defect at this one spot)? The 2 full-trip locations and the 1 partial-fall location are all close together, but that could just mean the forced spawn always routes the fox through the same terrain feature, not that it's the *only* vulnerable spot on the map.

### Acceptance (draft)

- [x] Add direct Y-position/velocity telemetry and use it to root-cause the *shape* of the fall (gradual gravity-accelerated sink, not a teleport or overlap-ejection spike) — 2026-08-06, temporary instrumentation removed after use.
- [x] Determine reproduction rate and disprove the contact-triggered hypothesis — 2026-08-06, ~1–2 in 10 headless runs, no contact involved.
- [x] Identify the exact terrain feature/collision shape at the fall location and confirm the slope-tunneling hypothesis directly (not just circumstantially).
- [x] Fix the boulder-seam cause: `PlayfieldBounds3D.ensure_obstacle_physics` now bakes convex hulls (`StaticObstacleCollision.sync_convex_blocker_from_visual`) for obstacle props instead of raw trimesh; terrain itself intentionally left as trimesh. Headless suite: same 6 pre-existing baseline failures, no regression; new assertion added (`_test_boulder_obstacle_collision_bake`) confirming the baked shape is genuinely convex, not trimesh.
- [x] Reproduce reliably (or determine it's rare/one-off) before attempting a fix — confirmed intermittent (~1–2 in 10 headless runs), always in the same location.
- [x] **Verify the boulder-seam fix against the repro.** 9 of 10 post-fix headless runs had zero C10 trips (improved from pre-fix). 1 of 10 still tripped, ~12 units from the nearest boulder — confirmed a **second, independent cause** (terrain-vs-capsule tunneling, no obstacle involved).
- [x] Root-cause and fix the remaining terrain-only tunneling — **2026-08-06.** Raycast-grid probe at the exact repeat-offending coordinates (same spot to within ~1 tick/~1m across two separate sessions) confirmed the terrain surface is solid/continuous, ruling out a geometry hole. Traced to `CharacterBody3D` collision `safe_margin` at Godot's default (0.001m) — too thin relative to creature speed vs. concave terrain trimesh. Fixed via `safe_margin = 0.06` on both `creature_carnivore_kinematic_3d.tscn` and `creature_herbivore_kinematic_3d.tscn`.
- [x] **Verify the terrain-tunneling fix against the repro: 10/10 post-fix headless runs, zero C10 trips** (6 completed the full 3600 ticks cleanly; 4 hit the unrelated, already-tracked [C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) flee-loop bug first). Full `tests/run_all.gd` regression suite re-run with the fix in place: same 6 pre-existing baseline failures, byte-identical — no regression.
- [x] Re-verify C9's live loop-closure question can finally be answered cleanly (C10 no longer interrupts repro runs) — C9 remains independently open/tracked; see its own section for status.
- [x] **Recurrence found 2026-08-07** during unrelated C9 verification — confirmed same-family (no boulder nearby, real continuous terrain, same ~30° slope, fox position below actual surface height), not a new mechanism. `safe_margin = 0.06` measurably reduced but didn't eliminate the tunneling class.
- [x] **Re-fixed:** `safe_margin` bumped 0.06 → 0.15 on both creature templates. Full suite: 0 assertion failures, no regression. 10 repeated 3600-tick headless runs: 10/10 fully clean (zero C9 or C10 trips).

### Root cause, pinned down (2026-08-06)

Wrote a throwaway headless diagnostic (`tests/diag_terrain_probe.gd` — instantiated `main_3d.tscn`, ran downward raycasts on `WORLD_STATIC_COLLISION_MASK` across the fall region, deleted after use) to test the fall location directly instead of continuing to infer from creature telemetry.

1. **No hole exists.** A dense raycast grid across the whole fall neighborhood (X: −64..−44, Z: −14..2) hit solid collision at every single point — the terrain surface there is a real, continuous, steeply-sloped valley wall (elevation drops from +1.3 at X=−64 down to about −6.7 by Z≈−10..−11 across roughly 15–16m — genuinely steep in the lower section, well past a gentle grade).
2. **A boulder's collision box sits directly on that slope, at exactly the fall coordinates.** Zooming the raycast grid to 0.25m resolution around X: −51..−53, Z: −6..−7 showed a second, distinct collider named `AutoCollision_Cube` with its top surface at Y ≈ −0.5 to −0.6 — roughly 1.5–2m *higher* than the surrounding terrain trend at that X/Z, i.e., a boulder embedded in the hillside. Traced the actual scene node: `Obstacles3D/@Node3D@595` (a `Boulder` instance from `_spawn_interior_boulders`'s fixed fractional layout), positioned at world **(-52.0, -1.55, -6.31)** — dead center of every observed fall/land coordinate this session (tick 208 partial fall, tick 462 [user's report], tick 506 [this session's]).
3. **The collision setup is structurally seam-prone.** Both the boulder (`AutoCollision_Cube`) and the terrain (`AutoCollision_Grid`) get their collision shape from [`PlayfieldBounds3D.supplement_trimesh_collision_from_meshes`](../../environment/playfield_bounds_3d.gd) — a fallback that runs when an imported scene has **no authored `StaticBody3D`** and instead auto-bakes a `ConcavePolygonShape3D` (raw trimesh) per `MeshInstance3D` found (`AutoCollision_%s % mesh.name` — hence the generic Blender-default names `Cube`/`Grid`). Two independently-baked concave trimeshes meeting at a steep-slope boundary, with no primitive/convex shape involved anywhere, is a known-fragile setup for `move_and_slide` seam tunneling.
4. **Placement doesn't account for slope.** [`Main3D._snap_playfield_props_to_ground`](../../main_3d.gd) snaps every obstacle's Y to the ground height sampled at a **single raycast at the prop's center XZ**, with no rotation to match the local slope normal and no check on local slope steepness before accepting a spawn fraction. On flat ground this is fine; on a slope this steep, the boulder's un-tilted trimesh unavoidably interpenetrates the uphill side and floats/leaves a wedge-shaped gap on the downhill side, relative to the terrain's own trimesh — exactly where a fast-moving capsule sliding downhill near the boulder could catch the seam and tunnel through, which matches the observed telemetry precisely: smooth, gravity-accelerated `vel.y` (not an instant glitch/teleport) while the fox is near this exact spot.

**Fix options (not yet implemented, no code changed this pass — diagnosis only):**
- Give obstacle props (boulders) a primitive or convex collision shape (capsule/cylinder/convex hull) instead of the auto-baked concave trimesh — convex-vs-concave and convex-vs-capsule are both far more tunnel-resistant in most physics engines, including Jolt, than concave-vs-capsule. Likely the most direct fix, and probably desirable for boulders generally (concave trimesh on movable-adjacent obstacles is unusual).
- Make `_snap_playfield_props_to_ground` slope-aware: either reject/re-roll a fixed fraction whose local slope exceeds some threshold (mirrors `PlayfieldGroundSampler.local_depression_score`'s existing "reject steep/depressed spawn candidates" pattern, just applied to obstacle placement instead of creature spawn), or rotate the prop to align with the local slope normal so its collision seals against the terrain instead of sitting axis-aligned on an angle.
- Independently, enable continuous collision detection (CCD) on the creature `CharacterBody3D` bodies if Jolt exposes it in this Godot version — a blanket mitigation for this class of bug regardless of which specific obstacle causes it next.

None of these were implemented this pass — this was root-cause investigation only, at the user's explicit ask to "pin down the terrain feature." Fix implementation is a follow-up decision.

### Fix shipped (2026-08-06): convex collision for obstacle props

User chose the convex-collision route over slope-aware placement (main tradeoff discussed: slope-aware snapping only avoids the *known* bad case, it doesn't make the underlying concave-vs-concave collision any more robust elsewhere; convex hulls fix the actual defect and generalize to any future obstacle/slope combination).

**Discovery before writing new code:** food-plant shrubs (`assets/plants/bush_food_3d.gd`) already solve exactly this problem via [`StaticObstacleCollision.sync_convex_blocker_from_visual`](../../environment/static_obstacle_collision.gd) — walks a visual mesh subtree and bakes real `ConvexPolygonShape3D` shapes (`mesh.create_convex_shape()`) onto an existing `StaticBody3D`, same pattern used for the shrubs' calorie-pickup blocker. Boulders never used this helper — they fell through [`PlayfieldBounds3D.ensure_obstacle_physics`](../../environment/playfield_bounds_3d.gd) → `supplement_trimesh_collision_from_meshes`, the raw-trimesh fallback (also used, correctly, for the terrain itself). **Shrubs were never part of this bug class and needed no change.**

**Fix:** [`PlayfieldBounds3D.ensure_obstacle_physics`](../../environment/playfield_bounds_3d.gd) now creates a `StaticBody3D` (`AutoConvexCollision`) and routes it through `StaticObstacleCollision.sync_convex_blocker_from_visual` instead of the trimesh fallback. Scoped narrowly: `supplement_trimesh_collision_from_meshes`/`_supplement_trimesh_recursive` themselves are untouched and still used by `Main3D._mount_grasslands_floor` for the terrain — a convex hull of the whole playfield would flatten it into a dome, so terrain must stay concave/trimesh. Only the obstacle-prop path (boulders) changed.

**Test fixed to match the new contract:** `_test_boulder_obstacle_collision_bake` (`tests/run_all.gd`) hardcoded the old node name `AutoCollision_Cube` and never checked the shape type. Updated to expect `AutoConvexCollision` and added a new assertion that the baked shape is actually `ConvexPolygonShape3D`, not trimesh — this assertion caught a real bug during development (see below), so it's pulling its weight, not just cosmetic.

**Development wrinkle worth recording:** `StaticObstacleCollision`'s convex-shape `CollisionShape3D` children get Godot's auto-generated unique name (`@CollisionShape3D@2`, not the plain `CollisionShape3D`) since they're created without an explicit `.name`. First version of the new test assertion did `get_node_or_null("CollisionShape3D")` and always got `null` — looked like the fix wasn't producing a shape at all. A quick throwaway diagnostic (`tests/diag_boulder_shape.gd`, deleted after use) printed the real child list and confirmed the shape *was* being baked correctly (`ConvexPolygonShape3D`), just under a different name than expected; fixed by iterating children and type-checking instead of looking up a fixed name.

**Headless suite:** same 6 pre-existing baseline failures, byte-identical, before and after (the boulder-bake test flipped from a new 7th failure — caught mid-implementation — back to passing once fixed; not counted as a regression since it was this session's own change).

**Verification against the actual repro (`smoke_ai_player.gd`, `_DEBUG_FORCE_EDGE_CHASE_SPAWN`, invariant harness live):**
- Re-probed the exact spike location post-fix: collider is now `AutoConvexCollision` throughout, with smooth piecewise-constant normals (real convex facets) — the sharp ~1.5–2m discontinuity from the old trimesh bake is gone. Fix is structurally confirmed at the collision-shape level, not just inferred from behavior.
- 10 repeated 3600-tick headless runs: **9 of 10 had zero C10 trips** (down from roughly 2–3 full trips in a comparable ~12–14 run sample pre-fix, plus C9 trips on 5 of the 10 runs — a separate, already-tracked issue, unaffected either way).
- **1 of 10 still tripped C10** — `fox#150458077494`, tick 494, `pos=(-57.56469, -2.664979, -6.090335)`. Checked this against the full obstacle list: the nearest boulder is `@Node3D@593` at `(-64.0, 0.31, -14.45)`, **~12 units away** — far too far to be involved. This trip is on open terrain, no boulder anywhere nearby, on the same steep valley-slope feature.

**Conclusion: the boulder-seam cause is real, fixed, and verified — but it was not the only cause.** There's a second, independent tunneling mechanism: a fast-moving capsule can apparently tunnel through the terrain's own steep-slope trimesh directly, with no obstacle involved at all. This matches leading hypothesis #3 from the original investigation (the C8-tracked "freefall after clipping through a thin wall" family) even more precisely than the boulder finding did — the remaining cause is now more narrowly scoped (terrain-vs-capsule slope tunneling specifically, not obstacle placement).

### Second cause root-caused and fixed (2026-08-06, same day): collision `safe_margin`

Caught a fresh instance of the remaining trip via the same headless repro: `fox#150609072438`, tick 493, `pos=(-57.567, -2.633, -6.208)`, 46 airborne ticks. Compared against the earlier post-boulder-fix trip (`fox#150458077494`, tick 494, `pos=(-57.565, -2.665, -6.090)`) — the two are within ~1 tick and ~1 meter of each other **across separate sessions**, i.e. not random scattered tunneling but the same slope segment failing deterministically on the same forced-spawn repro path.

**Diagnostic:** wrote a throwaway raycast-grid probe (`tests/_tmp_c10_terrain_probe.gd`, deleted after use) — a 7×7 grid of vertical rays at 0.25m spacing centered on the fall coordinates, plus direct rays at both historical fall points. Every ray hit cleanly: smooth, continuous surface, normal `(0.01, 0.86, 0.50)` → **30.2° slope**, collider `AutoCollision_Grid`, well under the fox's `floor_max_angle` (50°). No hole, no gap, no degenerate triangle — this rules out a geometry defect at this location.

**Root cause:** with a provably solid surface being tunneled through at the same tick every run, the cause has to be collision-margin/CCD tunneling, not terrain geometry. Neither creature template (`creature_carnivore_kinematic_3d.tscn`, `creature_herbivore_kinematic_3d.tscn`) had a `safe_margin` override on their `Body` (`CharacterBody3D`) node, leaving Godot's default of 0.001m — razor-thin relative to creature speed (fox `max_speed = 7.0`, [fox_archetype.tres](../../creature/species/fox_archetype.tres), → ~0.117m of displacement per tick at the default 60Hz physics rate) crossing a concave trimesh (`AutoCollision_Grid`, baked via `supplement_trimesh_collision_from_meshes`) on a slope. Concave-trimesh-vs-capsule with a near-zero margin is exactly the collision configuration most prone to per-triangle-edge tunneling under `move_and_slide()`.

**Fix:** added `safe_margin = 0.06` to the `Body` node in both:
- [`creature/templates/creature_carnivore_kinematic_3d.tscn`](../../creature/templates/creature_carnivore_kinematic_3d.tscn)
- [`creature/templates/creature_herbivore_kinematic_3d.tscn`](../../creature/templates/creature_herbivore_kinematic_3d.tscn)

**Verification:**
- 10 repeated 3600-tick headless runs (`tests/smoke_ai_player.gd`, forced edge-chase spawn, invariant harness live): **zero C10 trips** (6 ran the full 3600 ticks with no invariant failures at all; 4 hit the unrelated, already-tracked C9 flee-loop bug first) — up from the prior ~1/10 (post-boulder-fix) rate.
- Full `tests/run_all.gd` regression suite, re-run with the invariant harness temporarily disabled per the standing workaround (synthetic no-floor fixtures false-trip the airborne check): same **6 pre-existing baseline failures**, byte-identical — no regression from the `safe_margin` change. Harness flag reverted to `true` immediately after.

**C10 was believed closed at this point** — both the boulder-seam cause and the terrain-only tunneling cause fixed and independently verified against the live repro. See "Recurrence and re-fix" below for why that verification (10/10) turned out to be a favorable sample rather than full closure.

### Recurrence and re-fix (2026-08-07): `safe_margin` reduces but doesn't eliminate slope tunneling

While verifying C9's give-up escalation (unrelated change), one of 4 repeated headless runs tripped C10 again: `fox#150458077494`, tick 731, airborne 46 ticks, `pos=(-60.00237, -2.517084, -7.332571)`.

**Confirmed same-family, not a new mechanism.** Wrote a fresh throwaway raycast-grid probe (deleted after use, same methodology as the original C10 root-cause pass): the obstacle list has nothing within the whole region (X: −75..−40, Z: −20..10) — no boulder anywhere near this trip, ruling out cause 1 (boulder seam) entirely. A 0.5m-resolution raycast grid around the fall coordinates found real, continuous, single-collider terrain (`PlayfieldRoot`, no chunk seams) with the local slope grade computing to ~30° — essentially identical steepness to the original cause-2 location — but the terrain surface height at the fox's exact fall XZ interpolates to Y≈−1.98, while the fox's logged position was Y≈−2.52: genuinely below the surface, not resting on or clipped past an obstacle.

**Conclusion:** `safe_margin = 0.06` was a real, correctly-diagnosed fix for the right mechanism (concave-trimesh-vs-capsule tunneling on a slope) — it measurably improved the trip rate (0/10 in the original verification batch) — but 0.06m is evidently not always enough margin at this creature speed/slope combination; the "10/10 clean" verification was a favorable sample, not a guarantee. This is a probabilistic reduction, not an elimination, of the same tunneling class.

**Fix:** bumped `safe_margin` **0.06 → 0.15** on both `creature_carnivore_kinematic_3d.tscn` and `creature_herbivore_kinematic_3d.tscn` — same mechanism as the original fix, larger buffer. Chose the direct, minimal escalation of the already-diagnosed fix over a new mechanism (a floor-recovery backstop) or slope-aware placement, both discussed but not needed unless this recurs again.

**Verification:** full `run_all.gd` suite — 0 assertion failures, no regression. 10 repeated 3600-tick `smoke_ai_player.gd` runs (forced edge-chase spawn, invariant harness live): **10/10 fully clean — zero trips of any kind** (neither C9 nor C10). No visible floating/penetration artifacts observed in the headless logs at the larger margin. Real improvement over the pre-bump rate (1 trip in the last 10 combined C9/C10 verification runs), though — consistent with the lesson just learned — a 10-run clean sample here should be read as *strong evidence*, not provable elimination; the same class of bug could still recur at a lower rate. Leaving C10 `fixed` rather than reopening formally, but flagging this pattern (margin tuning narrows probability, doesn't guarantee zero) for whoever next investigates a similar tunneling report.

---

## C11 — Goal hub incumbent flip-flops (`find_food`/`rest`/`avoid_hostiles`) on single-tick threat sampling

**Status:** `done`
**Slice:** unassigned — found during randomized-spawn playtesting ([CREATURE_MOVEMENT_V3_RANDOMTESTS.md](CREATURE_MOVEMENT_V3_RANDOMTESTS.md)), confirmed unrelated to spawn randomization itself (reproduces under the debug-forced fixed duel spawn, `_DEBUG_FORCE_EDGE_CHASE_SPAWN`), so logged here instead of there per that doc's own promotion rule.
**Evidence:** User report during manual playtest: "even without threat from the fox, the rabbit seems to go back and forth in the valley near its spawn point." Headless `tests/smoke_ai_player.gd` repro + `tests/motor_explore_tick.log` inspection confirmed the incumbent goal alternating every single 8-tick consideration cycle for dozens of cycles straight (`find_food` ↔ `rest`, later also `avoid_hostiles` ↔ `find_food`), not a one-off.

### Symptom

Rabbit's incumbent `goal_kind` (and thus its step target / facing) flips every reconsideration cycle (`_consideration_interval`, default 8 ticks) between two different goals, each time re-deriving a fresh step objective and re-orienting — reads as "wandering back and forth" even though within each 8-tick block the creature makes real, monotonic progress toward that block's target.

### Root cause (found and fixed 2026-08-10)

`motor_goal_hub.gd`'s eligibility/scoring and `_feasibility_for_goal`'s `GOAL_REST`/`GK_AVOID_HOSTILES` branches all read `ctx["threat_samples"]` — populated fresh every physics tick by `_refresh_danger_samples`, but only *consumed* by the goal hub once per `_consideration_interval` (8 ticks), inside `_run_consideration`. Two separate consumers of this same instantaneous, single-tick snapshot produced the same symptom:

1. `_update_safety_on_consideration` reset `_safety_cycles` to `0` whenever `_threat_samples` was nonempty **on the one physics tick consideration happened to fire** — a predator that drifted out of awareness range for exactly that one sampled tick (out of the 8 in the window) read as "fully safe," instantly making `GOAL_REST` eligible at weight ≈0.89 (vs. `find_food`'s ≈0.25, not a scoring near-tie) and winning outright; the very next single-tick threat blip reset it just as abruptly.
2. `MotorGoalHub.build_eligible_goals` only includes `GOAL_AVOID_HOSTILES` when `ctx["threat_samples"]` is nonempty **at that same single sampled instant** — same aliasing, same abrupt on/off eligibility flip, this time alternating `avoid_hostiles` against `find_food`/explore.

In both cases a genuinely-nearby predator (confirmed live: `_DEBUG_FORCE_EDGE_CHASE_SPAWN` pins the duel pair unusually close together) drifting in and out of the awareness radius between reconsiderations was enough to flip the incumbent every single cycle, because the hub was deciding based on one aliased instant rather than the window it was meant to represent.

**Fix (`creature/motor/creature_motor_stack.gd`):** widened both consumers from an instantaneous sample to a windowed one, without touching the acute Flight fast path (`_update_flight_fast_path`), which already re-evaluates every tick off its own fresh read and was never part of this bug:
- `_threat_seen_since_safety_check: bool` — OR'd true every physics tick a threat sample is nonempty, consumed and reset by `_update_safety_on_consideration` in place of the raw instantaneous check.
- `_threat_samples_window: Array` — holds the most recent nonempty `_threat_samples` seen since the last consideration; `_run_consideration` substitutes this into its local `ctx["threat_samples"]` (only for the hub eligibility/scoring/feasibility path) before calling `build_eligible_goals`, then resets it.

### Verification

- Full `tests/run_all.gd` suite: 0 assertion failures, no regression (same pattern as C9/C10: `_DEBUG_ASSERT_MOTOR_INVARIANTS` temporarily flipped `false` for the run, reverted immediately after — confirmed via `git diff` clean).
- Live repro (`tests/smoke_ai_player.gd`, forced-close duel spawn): pre-fix, incumbent `gk` alternated every exactly 8 ticks for dozens of consecutive cycles. Post-fix, blocks range 8–72 ticks with no persistent every-cycle metronome — remaining switches read as genuine reactions to the still-abnormally-close forced spawn, not sampling-artifact flicker.

### Open questions

- `_DEBUG_FORCE_EDGE_CHASE_SPAWN` (`main_3d.gd`) is still `true` and has silently overridden every duel-pair spawn all session, including this one — genuinely-random duel-pair distance hasn't been exercised by this test round at all yet. Revisit turning it off once C9 is fully closed. **Resolved as predicted below** — it was disabled in a later commit, and randomized spawns are exactly what surfaced the recurrence.

### Recurrence (2026-08-12) — facing-cone flicker, distinct mechanism from the original fix

**Status:** `done` — separate root cause, separate fix, same symptom family.

Live playtest report: rabbit oscillating between fleeing and foraging for an extended stretch before the fox closed enough to force a stable flee. `hunter_killer.log` for the reported session showed `rabbit#7`'s incumbent `gk` alternating `avoid_hostiles` ↔ `find_food` on an exact, persistent **16-tick period (8+8) for 24 consecutive cycles** (`t=1667`→`t=2167`, ~500 ticks) — the same *symptom* the original C11 fix addressed, but this time under genuinely randomized spawn (the original fix's own open question, above), not the forced-close debug spawn.

**Root cause:** a different aliasing mechanism than the original fix, not a regression of it. `AwarenessZone.effective_reach_toward` (`awareness_zone.gd:16`) grants two very different reach values depending on facing: an omnidirectional sphere of `awareness_radius` (playfield-scaled down to `≈15.9` world units on this session's arena — see the `RANDOMTESTS.md` RT1 trace for the same scaling mechanism), and — only inside the forward cone (`half_angle≈45–50°`) — an extended reach of `awareness_radius + awareness_cone_extra` (`≈58.2`). With the fox sitting in that gap band, whether it counts as a threat at all depends entirely on the rabbit's instantaneous facing: `avoid_hostiles`'s own flee turn rotates the cone off the fox (threat sample drops the very next tick), `find_food`'s return turn toward the fixed food target happens to sweep the cone back across the fox's bearing (threat reappears), and the hub flips again next reconsideration — a stable limit cycle, not random flicker, which is why it read as an exact metronome rather than "genuine reactions."

**Fix (`creature/motor/occluded_in_zone_ghost.gd`, `memory_adapter.gd`, `creature_motor_stack.gd`):** the existing occluded-in-zone ghost system (`project_ghosts`) already projects remembered hostiles into the danger-sample pipeline the goal hub reads, and `GK_AVOID_HOSTILES` was already wired as an eligible belief kind — but its gate requires the target still be *inside* the geometric zone with LoS *blocked* by real geometry (the wall/corner case), the opposite of "outside the cone, LoS otherwise clear." Added a sibling projector, `OccludedInZoneGhost.project_facing_lost_threat_ghosts`: for a recently-observed `avoid_hostiles` belief that has fallen outside the current geometric zone (but is still within `awareness_radius + awareness_cone_extra` — i.e., would be visible if facing were correct), keep emitting it as a danger sample from last-known-position (+ velocity extrapolation) for `goal_memory_ghost_horizon_sec` (**0.4s**, reused rather than a new constant, per direction) since the belief's last live observation. Wired into `MemoryAdapter.consult_danger_samples` alongside the existing wall-occlusion ghosts; `CreatureMotorStack._build_zone_ctx` now carries `now_ms` so the new projector can age the belief out.

**Verification:**
- Full `tests/run_all.gd` suite: 0 `ASSERT:` failures, no regression.
- `tests/smoke_ai_player.gd` (3600 ticks, randomized spawn, post-fix): incumbent-`gk` oscillation still occurs but in irregular blocks (32/56/32/8/32 ticks) rather than a persistent exact-period metronome — matches the qualitative bar the original C11 fix used to call itself resolved. Not a byte-for-byte replay of the reported session (no locked seed captured for it), so this is a strong structural indicator, not a guaranteed identical-scenario repro; a live playtest is the real confirmation.

---

## C12 — `run_all.gd` full-suite run aborts: `_test_motor_locale_approach_no_oscillation_smoke` trips the C10 airborne invariant

**Status:** `done`
**Slice:** unassigned — discovered 2026-08-10 while verifying [C11](#c11-goal-hub-incumbent-flip-flops-find_foodresetavoid_hostiles-on-single-tick-threat-sampling) and the duel-pair spawn-randomize change (`_DEBUG_FORCE_EDGE_CHASE_SPAWN` disabled); confirmed pre-existing and unrelated to either change (reproduces identically against committed HEAD with a clean working tree).
**Evidence:** `godot --headless -s res://tests/run_all.gd` aborted mid-run every time, `push_error("MOTOR_INVARIANT [rabbit#...] airborne/off-floor for 45+ ticks (stuck-under-geometry, C10)")` from `creature_motor_stack.gd:_trip_invariant`, deterministically at physics tick 91, same position each run.

### Symptom

The full headless suite never reached its end — `_trip_invariant` calls `get_tree().quit(1)` the instant the invariant trips, silently truncating every test declared after `_test_motor_locale_approach_no_oscillation_smoke` in `_run_all()`'s call order. No prior session verification since the C10 airborne check was added had actually run the suite to completion; "0 assertion failures" checks were only ever seeing however much of the list ran before this abort.

### Root cause (found and fixed 2026-08-10)

`_test_motor_locale_approach_no_oscillation_smoke` (`tests/run_all.gd:2994`) drives the body toward a locale-prior `hotspot` computed as `((7.5) * coverage_cell, 0, (7.5) * coverage_cell)` — with the default `explore_coverage_cell = 52.0`, that's `(390, 0, 390)`. The shared test fixture `_motor_v3_test_floor()` only builds a `40x40` collision floor centered at the origin (±20 extents in X/Z). The locale-goal steering correctly walks the body toward the far-off hotspot, off the tiny platform's edge at roughly tick 46, and the body free-falls with nothing underneath for the rest of the run — legitimately tripping the C10 "airborne 45+ ticks" invariant on a test-fixture gap, not a real motor/gameplay bug.

Confirmed no other consumer of `_motor_v3_test_floor()` is affected: no test asserts on off-floor/edge-fall behavior (`grep` for `airborne`/`is_on_floor` in `run_all.gd` only matches this fix's own comment), and the only other two tests computing the same coverage-cell-derived hotspot (`_test_creature_motor_stack_seek_locale_prior`, `_test_motor_planner_live_locale_handoff_same_kind_prefers_live`) never run a multi-tick physics loop, so the body never actually travels there.

**Fix (`tests/run_all.gd`):**
- `_motor_v3_test_floor(parent, footprint: float = 40.0)` — added an optional footprint override, default unchanged so every other caller is unaffected.
- `_test_motor_locale_approach_no_oscillation_smoke` now sizes its floor to `2.0 * (hotspot.x + coverage_cell)`, comfortably covering the anchor it actually steers toward.

### Verification

- Full `tests/run_all.gd` suite now runs to completion (previously aborted at tick 91): 0 `ASSERT:` failures, no `MOTOR_INVARIANT` trips.
- Confirmed pre-fix behavior reproduces identically on committed HEAD (`5cbd7bc`) with the working tree stashed clean — same tick (91), same rounded position, ruling out the C11/spawn-randomize changes as the cause.
- Noted but out of scope: the suite's shell exit code is `1` even with 0 assertion failures, and ~400 `Condition "slot >= slot_max"` engine errors fire from `_test_motor_planner_precise_backtrack_ignored`'s intentional stale-`instance_id` probing (see [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression), closed). Both reproduce identically before and after this fix and predate this session's work — confirmed via a minimal isolated probe script that `push_error`/leaked-RID/leaked-`Resource` alone do not force a nonzero exit with `quit(0)`, so the exit-code-1 cause is still unidentified; not investigated further since it doesn't correspond to any real assertion failure.

---

## C13 — Rabbit freezes permanently after first bite of a shrub (`find_food` live target never goes stale + legacy player-pickup latch never releases)

**Status:** `done`
**Slice:** unassigned — user playtest report 2026-08-10: "I ran a test and about a minute in, the rabbit froze between two shrubs."
**Evidence:** `hunter_killer.log` for the reported run (duel spawn `16:40:46`, `herb_frac=(0.39,0.33) carn_frac=(0.92,0.77)` — genuinely randomized, confirming the [C11](#c11-goal-hub-incumbent-flip-flops-find_foodresetavoid_hostiles-on-single-tick-threat-sampling)-adjacent `_DEBUG_FORCE_EDGE_CHASE_SPAWN` disable is working). Rabbit approaches a shrub cleanly (`t=4093`→`t=4112`, `dist` closing 6.83→4.97, `dot=1.000`), gets one calorie grant at `t=4113` (cal 52%→61%), then holds the exact same position/facing/`step_instance_id` for 800+ consecutive ticks (13.7+ real seconds, until the user stopped the game via "End AI") re-issuing `act=EAT` every tick with **no further calorie gain** (cal only drains: 61%→46%).

### Symptom

Once a creature takes one bite of a live (non-memory) food target, if that target isn't immediately ready again, the creature stands completely still forever — no turning, no exploring, no retargeting to another known food source — continuing to command a no-op `EAT` action indefinitely.

### Root cause (found and fixed 2026-08-10) — two independent, compounding bugs

**Bug A — a legacy human-player pickup latch never releases for an AI creature that stops moving:**
`assets/plants/bush_food_3d.gd` had two parallel calorie-grant paths: the intended AI path (`try_grant_engine_creature`, called from the motor's `EAT` action via `creature_motor_stack.gd:_try_complete_eat`) and a second, older proximity-`Area3D` path (`_try_grant_pickup`, gated on `body.is_in_group(&"player")`) left over from an earlier, human-walks-around-and-picks-up-food design. The herbivore body is added to the `"player"` group in `main_3d.gd` for unrelated reasons (`hud.gd` uses it purely as a fallback lookup to find "the herbivore" for the vitals HUD — there is no actual manual-control player mode in this build). So the rabbit also tripped the legacy path: on first proximity overlap it granted calories and set `_player_visit_locked = true`, which is only meant to clear on `body_exited` from the pickup `Area3D` (i.e., when a human player walks away). An AI creature that settles at its EAT range and stops moving never leaves that area, so the lock never clears — and `is_pickup_ready_for_motor()` (which gates `_player_visit_locked` first) is also exactly what feeds the motor's own live-food-readiness perception (`awareness_zone_scan.gd:88-89`). Net effect: the specific shrub the rabbit ate becomes **permanently** unready to it, regardless of `growth_rate` regrowth.

**Bug B — the planner never notices a live target went stale:**
`motor_planner.gd:_sync_step_objective`'s `GK_FIND_FOOD` arm only re-derives a step objective for `precise`/`coarse`/`locale` step sources going stale (`_find_food_memory_tier_stale`). A `live`-sourced target (exactly what a just-reached shrub is) had **no staleness check at all** — once locked on, `step_goal`/`step_instance_id` were held forever regardless of whether the target could still be eaten, so the creature never fell back to memory search or exploration even once Bug A is fixed and the shrub legitimately finishes its `growth_rate`-timed regrow.

Bug B alone would only cause a temporary freeze (until regrowth completes); Bug A made it permanent.

**Fix:**
- `assets/plants/bush_food_3d.gd`: removed the entire legacy proximity-pickup path (`_player_visit_locked`, `_try_grant_pickup`, `_on_calorie_body_entered`/`_exited`, `_try_proximity_pickup_for_players`, and their now-unused helpers `_pickup_radius_world`/`_creature_half_extents`/`_footprint_point_clearance`). `is_pickup_ready_for_motor()` now only checks the calorie pool. `try_grant_engine_creature` (the AI path) is untouched and is now the sole grant mechanism.
- `motor_planner.gd:_find_food_memory_tier_stale`: added a `step_source == &"live"` branch. To avoid over-triggering (see Verification), it only reports stale when the scan **positively confirms** the tracked `step_instance_id` is still visible but not consumable (present in `scan.food_split.unready`) — not merely whenever the live "ready" search comes up empty, which also happens for synthetic/unit-test scans and for a pinned-prey EAT target that never appears in the plant-only ready/unready lists.

### Verification

- First attempt at the Bug B fix (`step_source == &"live"` → unconditionally stale whenever the caller's `live_food.is_empty()` gate was already true) broke `_test_motor_planner_eat_uses_ultimate_not_step_goal` (C3) and its orbit-break sibling — those tests deliberately construct a `live` step target against an **empty** synthetic scan (`{"ready": [], "unready": []}`) to isolate `_can_eat_now`'s geometric gate from full scan-based re-derivation; the coarse "ready is empty" signal doesn't distinguish that from a genuinely-depleted target. Narrowed to the `food_split.unready`-membership check above, which fixes C13 without regressing C3.
- Full `tests/run_all.gd` suite: 0 `ASSERT:` failures (same pre-existing, unrelated `_test_motor_pursuit_pinch_detour_smoke` C10-airborne trip noted as C14 in the inventory above at the time — reproduces identically before and after this fix; **C14 fixed separately, see below**).
- Live repro (`tests/smoke_ai_player.gd`, 3600 ticks): the one `src=live` `EAT` tick in the run (`t=3257`, cal 60%→68%) is immediately followed by `t=3258` transitioning to `src=explore` and resuming movement — matching the intended behavior, vs. the reported 800+-tick freeze.

---

## C14 — `_test_motor_pursuit_pinch_detour_smoke` (fox) trips the C10 airborne invariant — not the C12 family

**Status:** `done`
**Slice:** unassigned — found 2026-08-10 alongside C13 verification (`tests/run_all.gd` full-suite abort at the same `MOTOR_INVARIANT` harness C12 had just fixed for a different test); the inventory's original one-line guess ("same family, test floor too small") turned out to be wrong once actually investigated.
**Evidence:** `godot --headless -s res://tests/run_all.gd` aborted mid-run: `push_error("MOTOR_INVARIANT [fox#...] airborne/off-floor for 45+ ticks (stuck-under-geometry, C10)")`, deterministically at physics tick 91, `pos≈(15.25, -9.93, 21.61)` — well **inside** the fixture's 40×40 floor footprint in X/Z, ruling out C12's "walked off a too-small platform" mechanism on inspection alone.

### Root cause (found 2026-08-10) — headless-only artifact, not a real motor bug

Root-caused with a throwaway diagnostic script (`tests/_tmp_c14_probe.gd`, deleted after use) that mirrored `_test_motor_pursuit_pinch_detour_smoke` exactly, with per-tick Y/velocity/`is_on_floor()` tracing and a series of controlled variants:

- **Not a tunneling-speed/margin issue**: reproduces identically at `safe_margin` 0.15 (current default) and 0.001 (Godot's default); reproduces with the floor collider bumped from 0.2 to 4.0 units thick. The body doesn't clip through in one fast step — `is_on_floor()` is simply **false from the very first tick** and never recovers; Y descends smoothly under plain gravity with zero collision response at all, straight through a floor a raycast at the same coordinates confirms is genuinely present and hit-testable.
- **Not species-, layer/mask-, or fixture-structure-specific**: reproduces identically for a rabbit body in the same fixture (ruling out the fox's hostile collision layer/mask); reproduces after reparenting the floor out from under the `NavigationRegion3D`, after replacing the `StaticBody3D`/`CollisionShape3D` with entirely fresh nodes post-bake, and after toggling `CollisionShape3D.disabled` to force a re-register — none of it helps.
- **The actual trigger, isolated by bisection**: `NavigationRegion3D.bake_navigation_mesh()` on this fixture. A build of the identical floor with **no bake at all** (either no `NavigationRegion3D`, or one present but never baked) lands the body correctly from tick 0, every time. Baking from `MeshInstance3D` visual geometry instead of `PARSED_GEOMETRY_STATIC_COLLIDERS` reproduces the failure identically — so it isn't specific to the collider-geometry parser either, just to calling `bake_navigation_mesh()` at all in this context.
- **The one config that recovers post-bake**: calling `apply_horizontal_move_intent()`/`move_and_slide()` from the creature body's **own native** `_physics_process()` (i.e., disabling `set_motor_stack_drives_physics()` so the body's built-in per-frame movement runs) lands correctly even after a bake, and *stays* landed across dozens of real physics frames. The **instant** anything else calls the identical function on the identical body — this test's manual `stack.tick()` loop, or a stand-in driver `Node` calling `stack.tick()` from its *own* `_physics_process()` (deliberately built to mirror how `AI_int_lib/ai_driver.gd`'s `AiDriver._physics_process` drives the real game, tree position and all) — `is_on_floor()` goes false and never recovers, even with zero horizontal intent and 200 real physics frames of prior settle time.
- Attempted to wait out the async bake properly via `NavigationRegion3D.bake_finished` (baking is threaded by default — confirmed via `main_3d.gd`'s own comment on the same API) instead of the fixture's `map_get_path`-polling proxy for "done": the `await nav_region.bake_finished` **hangs indefinitely in headless mode** rather than ever resolving, even though path queries against the map already succeed well before that. This suggests the bake's true "finished" state may never actually surface in `--headless` runs at all — consistent with (though not a complete explanation of) the collision-detection artifact above.

**Conclusion:** this is a genuine Godot/Jolt headless-mode quirk — baking a `NavigationRegion3D` navmesh desyncs `CharacterBody3D.is_on_floor()` for any body subsequently driven by anything other than its own `_physics_process()` callback — not a bug in the V3 motor/planner code, and not reproducible in real (non-headless) duels, which explains why extensive live C1/C9/C10 duel testing never surfaced it. Root cause not pinned down past this point (verges on engine internals); not investigated further since a full engine-level fix is out of scope for a test-fixture artifact.

### Fix (2026-08-10) — test-only workaround, no production code path changed

Since `_test_motor_pursuit_pinch_detour_smoke`'s actual assertions (turn/move counts, distance-to-prey closing, no §9 seek while live, no `cblk` runaway) are entirely XZ-plane and don't depend on real vertical physics:

- `tests/run_all.gd`: added `_motor_pursuit_pinch_ypin(body, resting_y)`, called after every `stack.tick()` in the test — pins `global_position.y` back to spawn height and zeroes `velocity.y` whenever `is_on_floor()` is false, so the fixture's gravity artifact can't corrupt `distance_to(prey_pos)` math or send the body off into freefall.
- `creature/motor/creature_motor_stack.gd`: the C9/C10 invariant harness flag (`_DEBUG_ASSERT_MOTOR_INVARIANTS`) was a hardcoded `const`, requiring a source-level edit/run/revert cycle to disable for a single run (the pattern already used ad hoc during C10's own verification passes). Converted to a per-instance `var _debug_assert_motor_invariants` (default `true`, unchanged behavior everywhere else) with a new `set_debug_assert_motor_invariants_enabled_for_test(enabled: bool)` setter, matching the existing `_for_test` setter convention. The pursuit-pinch test calls this with `false` — Y-pinning alone stops the *fall* but can't make the genuinely-broken `is_on_floor()` return `true`, so the C10 airborne check would otherwise still trip on this specific fixture's known artifact rather than a real stuck-under-geometry bug. Every other test/production path keeps the invariant harness on by default.

### Verification

- Full `tests/run_all.gd` suite: exit code 0, 0 `ASSERT:` failures, no `MOTOR_INVARIANT` trips — confirmed the suite now runs past `_test_motor_pursuit_pinch_detour_smoke` to completion (previously the C10 trip's `quit(1)` truncated everything after it, same failure shape as C12).
- Confirmed the fix doesn't just suppress the symptom: with Y-pinning alone (invariant harness still on), the suite still aborted at the same tick/signature, since `is_on_floor()` itself — not body Y — is what the invariant checks. Both halves of the fix (Y-pin + per-instance invariant disable) are required together; documented here so neither gets deleted independently by a future pass without re-deriving why.
- Confirmed the fixed fox in this test now genuinely chases and reaches the moving prey across the full 300-tick window (position trace shows real, monotonic XZ progress from the spawn point to near the prey, settling into repeated `EAT` actions), not just "stopped erroring."

---

## C15 — Rabbit slowly starves in an eat→wander-to-a-phantom-locale-anchor→return loop (rabbit)

**Status:** `done`
**Slice:** unassigned — user playtest report 2026-08-11: "the rabbit seemed to get stuck eating a shrub, walking away to the northeast, returning to the shrub, and repeating the pattern while slowly starving to death... at a certain point, a net loss of calories should result in another direction being tried."
**Evidence:** `hunter_killer.log` for the reported duel (`herb_frac=(0.83,0.48) carn_frac=(0.39,0.17)`, spawn `15:52:24`, round ended `winner=none cause=end_ai herb_cal=3`). Full rabbit tick trace extracted for the session (5507 ticks): calories `100%→5%`, 7 total `EAT` actions (6 at the same shrub `id=116702318938` at world `(69.6, 50.4)`), spaced 590–720 ticks apart.

### Symptom

Not a retargeting failure (C13's fix is working correctly — the just-eaten shrub is properly noticed as stale/unready and dropped). Instead, a specific repeating cycle:

1. `EAT` at the shrub → shrub immediately drops out of the scan as ready (its own ~300-tick regrow cooldown).
2. With no live food visible, planner falls back to `src=locale`, beelining for a **fixed memory anchor at `(78.0, 26.0)`** — the coverage-grid cell **centroid** for the 52×52-unit cell the shrub happens to live in, not the shrub's actual position (offset ~26 units from it).
3. Arrival finds nothing there (correctly — the anchor is a cell-average point, not a real food location); the objective clears and falls to `src=explore`, drifting progressively farther away (`(78.4,22.6)` → `(81.6,14.0)` → `(84.2,8.4)` across successive cycles).
4. Once the shrub re-enters the scan as ready again, the planner snaps straight back to it — but from wherever the explore drift left the rabbit, sometimes 30–40 units away.
5. Net calorie cost per cycle (travel to phantom anchor + explore drift + travel home + baseline drain over 600+ ticks) exceeds one bite's calorie yield. Repeats until starvation.

### Root cause (found 2026-08-11)

Two independent, compounding gaps in the existing (correctly-designed) locale-memory system:

1. **Cooldown far shorter than the cycle it needed to cover.** `_locale_anchor_on_arrival_cooldown` ([motor_planner.gd](../../creature/motor/motor_planner.gd)) exists specifically to stop an empty locale anchor from being immediately re-picked (CLEANUP C2, 2026-07-17) — but its default, `locale_revisit_cooldown_ticks = 90` (1.5s), was tuned for the in-place-orbit case C2 targeted, not for a full eat→detour→return cycle, which this session showed running 590–720 ticks. The cooldown always expired well before the rabbit came back around to reconsult locale memory, so the same anchor was eligible again every single time.
2. **No lasting penalty for a confirmed-empty visit.** The locale anchor's rank comes from `GoalSourceMemoryStore`'s learned `stored_strength`/`replay_rank_score` per coverage cell ([goal_source_memory.gd](../../creature/motor/goal_source_memory.gd)) — reinforced positively on every successful `EAT` via `notify_food_consumption_outcome` (`creature_motor_stack.gd` → `memory_adapter.gd`). But nothing on the *arrival-finds-nothing* path ever wrote the mirror-image negative signal, so a cell's rank only ever went up from real eats, never down from real misses at its own centroid — the cooldown timer was the *only* thing standing between this cell and being picked again, and per (1) that timer was too short to matter.

Not a "wrong location" bug at the data level — the memory is correctly identifying "food has been found in this general neighborhood," it's the coarse 52-unit cell-centroid granularity that doesn't coincide with where the shrub actually sits, and nothing was learning from that mismatch.

### Fix (2026-08-11)

Both angles requested together, since either alone only partially closes the loop (a longer cooldown delays the same anchor without ever discounting it; decay alone still lets it win on every single visit before evidence accumulates):

- **`AI_int_lib/game_config_merge.gd`**: `locale_revisit_cooldown_ticks` default bumped **90 → 300** (5s) — comfortably covers the shrub's own ~300-tick regrow window without being so long it stalls a genuinely-stuck creature indefinitely. Not derived from a formal model, a starting point sized to the observed cycle; retune if duel evidence shows it still too short (or now too conservative) once real regrowth timing is confirmed.
- **`creature/motor/memory_adapter.gd`**: new `notify_locale_food_arrival_empty(anchor, motor_v3, env_grid)` — the mirror of the existing `notify_food_consumption_outcome`, writing a `TIER_FAILURE` salient write via the same `GoalSourceMemoryStore.try_salient_write` learning path (same row key as the success writes for that cell, so `attempt_count` accrues from both real eats *and* empty locale visits — a cell's `stored_strength`/rank now reflects its true mixed track record).
- **`creature/motor/motor_planner.gd`**: `_maybe_locale_arrival_bind_or_clear` now calls the new adapter method right before `_clear_locale_step_fields`, using the same `ultimate` anchor position and `ctx["environment_grid"]` already available at that call site.

**Verified (isolated, `MemoryAdapter` direct)**: 3 simulated successful eats at the shrub position then repeated `notify_locale_food_arrival_empty` calls at the cell centroid — `replay_rank_score` for that cell dropped from `11.32` (post-eats, pre-failure) to `3.33` after the very first failure write, settling to a steady `~2.2–2.4` after 10 repeated failures (the EWMA/evidence model correctly converges to the cell's true long-run success rate rather than crashing to zero, which is the intended behavior — a cell that's genuinely produced 3 real eats shouldn't be discounted to nothing by one bad centroid, but should no longer dominate every cycle either).
**Verified (headless)**: full `tests/run_all.gd` suite — exit 0, 0 `ASSERT:` failures, no regressions.
**Not yet duel-validated** — this session's specific repro (which took an entire real duel to surface) hasn't been re-run live post-fix; next manual playtest should confirm the rabbit stops burning full round-trips on the same empty anchor.

---

## C16 — Flee waypoint overshoots the playfield boundary instead of clamping to the reachable distance

**Status:** `done`
**Slice:** unassigned — found 2026-08-12 during targeted `_DEBUG_FORCE_EDGE_CHASE_SPAWN` repro sessions for C9.
**Evidence:** User playtest report: "rabbit hit the edge and then turned 180 toward the fox and was eaten." `hunter_killer.log` for the reported session (spawn `herb_frac=(0.05,0.50) carn_frac=(0.20,0.50)` on a `200×203.7` playfield — rabbit spawns `X=-90`, only 10 units from the `min_x=-100` wall) showed the very first flee mint at `t=1` targeting `(-105.9, 2.4)` — 5.9 units past the map boundary.

### Root cause

`_mint_flee_waypoint` / `_flee_objective` (`motor_planner.gd`) already score candidate bearings by real navmesh-reachable distance (`_flee_candidate_reach`, the C9 5th/6th-fix machinery) — including preferring a roughly wall-parallel bearing over "straight away" once straight-away scores near-zero reach, since a wall-hugging direction travels much farther before hitting anything. But the *final waypoint* always projected the full requested `flee_dist` (`≈15.87` after the RT1 flee-distance fix) along whichever direction won, regardless of that direction's own measured reach. Near a boundary, the best-scoring direction is still correct but its reach can be much shorter than `flee_dist`, so the waypoint routinely landed past where the creature could actually go. The rabbit then spent several real seconds physically fighting the wall (repeated boundary-scan/backtrack-detour cycles) before finding a real opening, while the fox — never handicapped by any wall — closed distance uncontested. By the time the rabbit found real room to move, the fox was already close enough to force a losing chase. A second, separate overshoot source existed in `_mint_flee_waypoint`'s own "no visible threat this exact tick" bootstrap fallback (Flight entry before a live threat sample exists yet): it projects along a fixed `HORIZONTAL_FORWARD` compass direction with zero geometry awareness at all, which can point straight at a wall.

### Fix

`creature/motor/motor_planner.gd`:
- Main candidate-scored mint path: cap the final waypoint's travel distance to the chosen direction's own measured reach (`clampf(final_reach, 0.0, flee_dist)`) instead of always using the full `flee_dist`.
- **Caveat found during verification:** applying that same clamp to the pre-existing "zero signal in all 22 tested directions" fallback (a creature genuinely boxed in on every side) collapsed the waypoint to ~0 distance from the creature's own position — a "flee to here I already am" target whose bearing is dominated by floating-point noise tick to tick, which tripped the C9 boundary-ping-pong invariant via a *different* mechanism than the one C9 originally fixed (exact-repeat remints instead of directional thrashing). Fixed by only applying the reach clamp when a real (positive) reach was actually measured; the fully-boxed-in fallback keeps projecting a stable heading at full `flee_dist` (unclamped) rather than degenerating to a self-referential point — matches the user's own framing (moving parallel to a wall beats spinning; a fully-cornered creature holding one stable heading and pushing against it beats thrashing too).
- `HORIZONTAL_FORWARD` bootstrap fallback: same reach-based clamp, using `_flee_candidate_reach` against the fixed forward direction; a reach of `0` just holds position for that one tick until the next reconsideration has real threat data to steer by.

### Verification

- Full `tests/run_all.gd` suite: 0 `ASSERT:` failures, no regression (three iterations of this fix, each re-verified clean).
- `tests/smoke_ai_player.gd` with `_DEBUG_FORCE_EDGE_CHASE_SPAWN` on (the exact stress spawn from the report): 7 repeated runs post-fix, 0 `MOTOR_INVARIANT` trips (the first fix attempt — clamping the fully-boxed-in fallback too — reintroduced a C9 trip within the first 3 runs; the refined fix above has run clean across 7).
- Residual, accepted gap: the fully-boxed-in fallback (deliberately unclamped, per above) can still overshoot the boundary in the rare case where every tested direction scores zero reach — confirmed live at `≈4.7` units past the boundary in one of the 7 verification runs. Unlike the pre-fix behavior this doesn't cause thrashing or an invariant trip (the creature holds a stable heading, gets blocked, and the existing boundary-scan/backtrack-detour system — not flee-remint timing — finds the real opening on the next cycle), so left as-is rather than adding further complexity for a case that no longer produces pathological behavior.

---

## C17 — Flee-waypoint reach scoring mismatched its own straight-line projection near a boundary corner (rabbit spins then fails to strafe past)

**Status:** `done`
**Slice:** unassigned — found 2026-08-12, same `_DEBUG_FORCE_EDGE_CHASE_SPAWN` west-wall repro area as C9/C16.
**Evidence:** User playtest report: rabbit fleeing the fox hit the edge and spun for a couple of seconds before trying and failing to strafe past. `motor_explore_tick.log` for the session showed the flee mint cycling between three fixed waypoints — `(-113.9, -6.2)` (≈14 units past the `min_x=-100` wall), `(-108.1, 8.6)`, and `(-92.4, 10.9)` — for ~120 ticks (~2s): each mint reported a candidate "reach" of `≈15.87`, essentially the full `flee_dist` (so C16's clamp never engaged), then `MOVE_F` immediately reported `blk=1`, forcing a re-mint into one of the other two points, repeating.

### Root cause

`_flee_candidate_reach` (renamed `_flee_candidate_probe` by this fix) scored a candidate bearing by asking `NavigationServer3D.map_get_path()` for a path to `creature_pos + dir * dist`, then returned only the **straight-line distance** from the creature to that path's *last point* — discarding the endpoint itself. Near the boundary corner, an off-navmesh candidate point gets snapped by the nav query to the nearest reachable point, which the path may only reach by **bending around the corner**; the straight-line distance to that bent-path endpoint can read close to the full requested `dist` even though a straight cast in `dir` walks off the navmesh partway there. `_mint_flee_waypoint` then re-derived the waypoint as `creature_pos + final_dir * travel_dist` — a straight-line cast using only the scored *distance*, not the actual reachable *point* — so a direction that scored "clear" on paper still produced a waypoint the creature couldn't walk straight to. Several 60°-rotated candidates near the corner suffered the same mismatch, so the mint kept hopping between them.

### Fix

`creature/motor/motor_planner.gd`:
- `_flee_candidate_reach` → `_flee_candidate_probe`: now returns `{"reach": float, "endpoint": Vector3}` — the actual navmesh path endpoint alongside the distance to it, instead of distance alone.
- `_mint_flee_waypoint`'s main candidate loop, give-up escalation scan, and the "no live threat yet" `HORIZONTAL_FORWARD` bootstrap fallback all now track and use the winning candidate's own probed `endpoint` directly as the waypoint (when `reach_known`), instead of re-deriving a straight-line point from direction × clamped distance. The C16 "genuinely boxed in" fallback (all candidates score ~0 reach) is unchanged — still holds a stable heading at full `flee_dist`, since there's no reliable endpoint to target in that case.

### Verification

- Full `tests/run_all.gd` suite: 0 `ASSERT:` failures.
- `tests/smoke_ai_player.gd` with `_DEBUG_FORCE_EDGE_CHASE_SPAWN` on: 4 repeated runs post-fix, all completed 3600 ticks clean, 0 `MOTOR_INVARIANT` trips.
- Live re-check via `motor_explore_tick.log`: flee mints near the west wall now hold a single stable, actually-reachable target (e.g. repeatedly `(-95.3, 5.9)`) with `blk=0` throughout, instead of cycling between three unreachable points with `blk=1` re-mints.

---

## C18 — EAT completes through a solid the eater physically can't pass (straight-line range only, no reachability/occlusion check)

**Status:** `done`
**Slice:** unassigned — found 2026-08-14 while investigating [RANDOMTESTS.md RT4](CREATURE_MOVEMENT_V3_RANDOMTESTS.md#rt4-rabbit-never-shelters-inside-the-forced-shrub-refuge-cluster) (rabbit sheltering inside the forced shrub-refuge ring, fox parked outside).
**Evidence:** User playtest observation: rabbit sitting inside the shrub-refuge ring (`main_3d.gd:_spawn_open_shrub_refuge_cluster`, radius 3.0) with a fox stopped just outside it — asked whether anything invalidates `EAT` when the target is "essentially behind a solid." Code inspection (no repro run needed — the gap is structural): `_can_eat_now` / `_is_within_eat_range` (`motor_planner.gd:2179-2207`, pre-fix) gated `EAT` on straight-line Euclidean distance (`eat_action_max_distance`, default `5.0`) plus a facing arc — nothing else. The ring's shrubs use `MobBlocker` (`assets/plants/open_shrub/open_shrub_3d.tscn`, `collision_layer=8`) which only the carnivore's `collision_mask` (`9` = world_static + that layer, `creature_kinematic_body_3d.gd:_apply_physics_layers`) includes — herbivores walk straight through, carnivores are physically stopped. Ring diameter (6.0) is smaller than `2 × eat_action_max_distance`, so a fox stopped at the ring's edge can sit well within straight-line bite range of a rabbit on the near side of the ring interior with nothing checking whether a shrub wall stands between them.

### Root cause

`_is_within_eat_range` was a pure `distance_to() <= max_dist` check with no occlusion or reachability term. The existing LoS system (`LineOfSight3D.occlusion_fraction`, `line_of_sight.gd`) only ever queries `WORLD_STATIC_MASK` (layer 1) — it wouldn't have caught this either, since `MobBlocker` sits on layer 8, not layer 1, and LoS is a *visual* shadow-coverage heuristic (percentage of a sample fan blocked), not a *physical* pass/fail on the specific layers that stop the acting body's own movement. Separately, the existing per-tick LoS/nav deflection (`_run_path_clearance_los_nav`) only runs from inside `_locomote_toward_step_goal` — `select_action` (`motor_planner.gd:114-120`) checks `_can_eat_now` *before* ever reaching that code path, so it couldn't have gated `EAT` even if it had used the right mask.

### Fix

- `creature/motor/motor_path_clear.gd`: new `has_clear_contact_path(space_state, from, to, collision_mask, exclude_rids)` — a single-ray solid-intercept check parameterized on a caller-supplied `collision_mask`, deliberately generic (not EAT-specific) so it's ready to reuse for other contact-gated actions once combat lands, per the caller's ask.
- `creature/motor/motor_planner.gd`: `_can_eat_now` gained an optional `ctx: Dictionary = {}` parameter (defaults to permissive — no `space_state` means no check, so any call site that doesn't pass `ctx` is unaffected) and now calls `_has_clear_contact_path_for_action`, a thin adapter that rays from the eater's eye position to the eat target using **the eater's own `collision_mask`** (not a fixed vision mask) — so the gate matches whatever layers actually stop that specific body's movement, herbivore vs. carnivore included. `select_action`'s only call site now passes `ctx` through.

### Verification

- New test `_test_motor_planner_eat_blocked_by_solid_between` (`tests/run_all.gd`): spawns a carnivore body in range/facing-aligned with a live food target, asserts `_can_eat_now`/`select_action` succeed with no obstruction present (positive control), then adds a `collision_layer = 8` `StaticBody3D` directly on the path (mirroring the refuge ring's `MobBlocker`) and asserts both now correctly refuse `EAT`.
- Full `tests/run_all.gd` suite: 0 `ASSERT:` failures, 2/2 clean runs.
- **Diagnostic note (test-harness-only, not a game bug):** the first version of the new test's leftover `StaticBody3D` wasn't flushed from the shared physics world before later tests ran (`queue_free()` alone, no yielded frame afterward) — it lingered near world origin and physically interfered with `_test_motor_locale_approach_no_oscillation_smoke`'s rabbit a few tests later, tripping the C10 airborne invariant. Fixed by adding `await process_frame` after `main.queue_free()` at the end of the new test, matching frame-flush hygiene the C12/C14 fixes already established for this failure family. Confirmed via bisection (disabling the new test made the failure disappear; re-enabling it with the extra `await` made the full suite pass cleanly twice in a row) that this was purely a test-cleanup-timing artifact of the new test itself, not a behavior change from the `_can_eat_now` fix.

---

## C19 — `MotorAction.REST` unreachable from `select_action` — a winning REST cycle read as `STAY`

**Status:** `done`
**Slice:** unassigned — found and fixed 2026-08-14/2026-08-26 while investigating [RANDOMTESTS.md RT4](CREATURE_MOVEMENT_V3_RANDOMTESTS.md#rt4-rabbit-never-shelters-inside-the-forced-shrub-refuge-cluster) (flagged as a separate, pre-existing gap unrelated to shelter both at Slice 1 and Slice 2; closed out on its own here).
**Evidence:** No live repro needed — structural, found by code inspection while tracing why a fed, safe rabbit's REST behavior is never visually distinguishable from ordinary idling. `MotorAction.REST` has real, working scaffolding throughout the motor stack: the enum value and action-name string (`creature_motor_stack.gd:502-503`), a lower calorie-drain multiplier via `rest_baseline_multiplier` (`motor_action.gd:62-63`), a locomotion no-op handler (`locomotion_executor.gd:55`), and `_rest_area_only_perception()` (`creature_motor_stack.gd:697-702`), which specifically checks `_last_outcome.action == MotorAction.REST` to narrow perception while resting. None of it could ever fire: `select_action` (`motor_planner.gd`) had no branch for `goal_kind == GOAL_REST` at all — every non-`find_food` goal that reached its step goal fell through the single generic `_at_arrival` → `STAY` case, so a winning REST cycle (already correctly gated by `motor_goal_hub.gd`'s `calorie_ratio >= 0.95` + `safety_met` floor, confirmed sound in a prior session's synthetic probe) always produced the action `STAY`, never `REST`.

### Root cause

Two compounding gaps, both structural (no mistuned weight or threshold):

1. **`select_action` had no `GOAL_REST` branch.** The only special-cased terminal actions were `EAT` (for `GK_FIND_FOOD`) and the generic `_at_arrival` → `STAY` fallback that every other goal kind — including `GOAL_REST` — fell into.
2. **`_sync_shelter_or_rest_objective`'s `GOAL_REST` arm was a stub.** It unconditionally returned `false`, so `_sync_step_objective`'s `GOAL_REST` match arm (`motor_planner.gd`) always fell through to `_mint_explore_objective_for_goal` — an undirected explore step, not "arrived, hold position." Even if `select_action` had had a REST branch, there was never a step goal that counted as "reached" for REST specifically. (Shelter's sibling stub got a real implementation in RT4 Slice 1; REST's was explicitly left alone at the time as an unrelated gap.)

### Fix

- `creature/motor/motor_planner.gd`: `_sync_shelter_or_rest_objective` now holds the creature's own current position as the step goal and returns `true`. Unlike shelter, REST has no *site* to seek — its eligibility is calorie/safety gated, not location gated — so "hold here" is a complete implementation, not a placeholder; `_at_arrival` is true the same tick.
- `select_action`: added a `goal_kind == _MotorGoalHub.GOAL_REST and _at_arrival(...)` branch returning `_MotorAction.REST`, ahead of the generic `_at_arrival` → `STAY` fallback that was silently absorbing it.

### Verification

- New test `_test_motor_planner_select_action_returns_rest_for_goal_rest` (`tests/run_all.gd`): builds a `GOAL_REST` incumbent ctx and asserts `select_action` returns `REST` (not `STAY`) the same call the step goal is synced.
- Full `tests/run_all.gd` suite: 0 `ASSERT:` failures.
- **Not done:** no distinct REST animation yet — the action still routes through `locomotion_executor.gd`'s no-op handler shared with `STAY`/`EAT` (correct physical behavior and calorie drain, just no visual distinction). Deliberately deferred until animated actions land; `locomotion_executor.gd:55`'s shared `STAY, REST, EAT` no-op branch is the hook point to split out then. Also still open: the second half of RT4 item 2 (whether real playfield food density sustains `calorie_ratio >= 0.95` long enough to reach REST at all in practice) — this fix makes REST *observable* once reached, it doesn't re-verify how often it's reached.

---

## Shared implementation plan (C1 + C2)

**Thesis:** C1 (fox live-prey pursuit) and C2 (rabbit locale seek) are the **same failure family** — a **fixed `step_goal`** with **bad approach geometry** (blocked corridor / overshoot) and **no progress-stall escalation**. They differ only in **trigger** (`blk=1` collision vs `blk=0` orbit) and **step source** (`live` vs `locale`). Ship the common foundation **once**; keep the small goal-specific tails behind it.

### Three layers

| Layer | Scope | Serves | Nature |
|-------|-------|--------|--------|
| **Layer 1 — Executor hygiene** | `align_and_move` / `note_outcome` / `apply_immediate_blocked_path_reevaluation` | C1 + C2 | **Shared** |
| **Layer 2 — Stuck escalation** | Generalized fixed-objective no-progress → §9 | C2 (`locale` v1) | **Shared helper; `locale` call site v1** |
| **Layer 3 — Goal-specific latches** | Pursuit detour latch / §9 gate (C1); live↔locale handoff scoring (C2) | C1 or C2 | **Separate code, same PR** |

**Layer 1 — Executor hygiene (shared):**

1. **Verify the cone is honored at decision time** — `_is_facing_aligned_for_move` already enforces `dot ≥ cos(turn_increment_deg)`; add a **regression contract** test (no `MOVE_F` selected when misaligned at `select_action` time). This replaces the earlier “add a cone gate” proposal.
2. **Overshoot guard (general)** — locked contract in [Resolved — overshoot guard (Layer 1)](#resolved--overshoot-guard-layer-1). Fixes the C2 orbit; also helps C1 after a bad nav substep.
3. **Step-goal-jump turn-first (general)** — when `step_goal` changes materially (`dist(old, new) > motor_stuck_move_epsilon`), blocked reeval, live→locale switch, pursuit detour mint, or **overshoot remint**, set `force_align_turn_before_move`; **`align_and_move`** checks flag before `MOVE_F`. See [Resolved — step-goal-jump](#resolved--step-goal-jump--turn-first-layer-1-tail).

### Resolved — overshoot guard (Layer 1)

**Problem:** A legal pre-move-aligned `MOVE_F` can cross a fixed `step_goal` in **~1 move-step** of travel (`max_speed × delta` from [`LocomotionProfile`](../../creature/definition/locomotion_profile.gd) — not 1 world unit per tick). Post-move bearing flips to the rear hemisphere (C2 t≈2366). Recovery must be **geometry remint**, not §9 on the first crossing.

**Precedence (locked):**

| Stage | Trigger | Response |
|-------|---------|----------|
| **Layer 1 — overshoot** | Passed goal / confirmed overshoot after successful `MOVE_F` | Remint nav substep from ultimate + turn-first; **no §9** |
| **Layer 2 — no progress** | `locale_no_progress_ticks` (etc.) ≥ `dead_end_record_min_blocked_ticks` (3) | `note_outcome` → §9 persist/switch/seek |

**Detection (locked):**

- **Hook:** [`note_outcome`](../../creature/motor/motor_planner.gd) after a **successful, non-blocked** `MOVE_F` (post-locomotion ground truth). Optional pre-move guard in `select_action`: if already past goal along approach, do not pick another `MOVE_F`.
- **Primary signal:** **passed goal along pre-move approach** — mirror [`_passed_explore_waypoint`](../../creature/motor/motor_planner.gd) using pre-move `to_goal` / approach vector (creature crossed the goal plane along the approach line).
- **Secondary confirm (OR):** distance to `step_goal` **increased** vs pre-move **and** post-move rear hemisphere (`dot(facing, to_goal) < 0`). Do **not** use distance-increased alone — false positives on curving nav substeps.
- **Close band (move-steps, not meters):** evaluate only when `dist(step_ultimate_pos) < approach_overshoot_guard_move_steps × expected_forward_step_world(body, delta)`. `expected_forward_step_world` = `_LocomotionExecutor._expected_horizontal_speed(body) × delta` (same family as [`_latched_stuck_move_epsilon`](../../creature/motor/motor_planner.gd)). Ship default **`approach_overshoot_guard_move_steps` = 2** in `creature_motor_v3`. Ranged keys (`eat_action_max_distance`, `awareness_radius`) stay in **world units** — speed-agnostic.
- **Arrival edge:** when `dist(step_ultimate_pos) ≤ arrival_tolerance`, skip overshoot remint — use arrival / EAT-bind path (`STAY` / `EAT`), not geometry recovery.

**Response (locked):**

1. **Remint** `step_goal` = `_PathClear.resolve_step_objective(map_rid, creature_pos, step_ultimate_pos, agent_r)` — always remint from **ultimate**, not the stale nav substep.
2. **Turn-first flag** — same mechanism as step-goal-jump (item 3); next tick forces `TURN_*` before `MOVE_F`.
3. **Retain** `locale_no_progress_ticks` and `precise_no_progress_ticks` on overshoot remint (do **not** reset). Rationale: geometry recovery (Layer 1 remint + turn-first) and stuck escalation (Layer 2 → §9) must **compose**; resetting starved Layer 2 under continuous overshoot so §9 never fired while the orbit continued (duel **2026-07-14** — see [C2 residual](#c2-locale-food-approach-oscillation-rabbit)). Layer 1 still does **not** call §9 from the overshoot handler itself; Layer 2 may then reach threshold and escalate §9 on subsequent `note_outcome` ticks (orbit break via seek/switch). ~~**Superseded 2026-07-14:** Reset `locale_no_progress_ticks` (and precise progress fields when applicable) on overshoot remint~~ — that rule made remint ≠ stuck / no §9 from overshoot mutually exclusive under repeated remints.
4. **Do not** call `apply_blocked_objective_resolution` / §9 from overshoot — follow explore precedent (`_apply_explore_waypoint_passed` replans in place; [`_test_motor_planner_latched_stuck_replan`](../../tests/run_all.gd) expects explore stuck **without** §9). Remint still ≠ automatic §9; progress **retention** is what lets Layer 2 fire later.

**`step_ultimate_pos` (locked):** Planner state field set at mint for **`locale`** (locale anchor), **`precise`** (instance pos), and **pursuit detour latch** (Layer 3). Cleared on goal-kind change / §9 seek. Required so remint does not lose the ultimate after nav substep rewrite.

**Per `step_source` (locked):**

| Source | Overshoot path |
|--------|----------------|
| `locale`, `precise`, `live`, `memory_moving` | Shared `_apply_fixed_objective_overshoot` helper (ultimate remint + turn-first) |
| `explore` | **Unchanged** — existing `_passed_explore_waypoint` → rim inward / 60° replan; do not route through ultimate remint |

**Layer 2 — Stuck escalation (shared helper):**

- Generalize `_note_precise_position_progress` into a fixed-objective progress check keyed by `step_source` (bearing-improved **or** distance-improved, same as `precise`).
- Maintain `<source>_no_progress_ticks`; on threshold → `return true` from `note_outcome` so the stack runs §9 persist/switch/seek. **`locale`** uses **`dead_end_record_min_blocked_ticks`** (default 3) — same as `precise`; no `locale_no_progress_min_ticks` in v1 unless duel smoke proves 3 too twitchy.
- **Compose with Layer 1:** overshoot remint must **not** zero these counters (`locale` / `precise`) — see [Response #3](#resolved--overshoot-guard-layer-1) (2026-07-14). Still reset on meaningful MOVE progress, goal-kind change, and fresh locale mint.
- Wire call sites: **`locale` only** in v1 (C2 required). **`live` deferred** — see [C2 open questions](#open-questions). **Do not** add `locale` to `_is_latched_step_source` (see C2 resolved question) — call the helper directly for the `locale` branch.

**Layer 3 — Goal-specific tails (same PR, separate functions):**

- **C1:** `pursuit_detour_waypoint` latch (`pursuit_detour_latch_ticks` — **32** after C1 residual 2026-07-14; was **16** Pass 3); sticky vs live remint + alternate on persistent block; gate §9 seek while live prey visible (ghost-only prey keeps §9).
- **C2:** live↔locale handoff scoring (same-kind → prefer live/in-range; else compare calories-per-`EAT`).

### One PR, two smoke tests

```
Branch: post-6d-approach-geometry
├── creature/motor/motor_planner.gd
│   ├── Layer 1: overshoot guard (`step_ultimate_pos`, move-step close band) + step-goal-jump turn-first
│   ├── Layer 2: fixed-objective no-progress helper + §9 trigger (locale only v1)
│   ├── Layer 3 (C1): pursuit_detour latch + §9 gate on live prey
│   └── Layer 3 (C2): live↔locale handoff scoring
├── tests/run_all.gd
│   ├── _test_motor_align_cone_contract               (Layer 1 regression, cheap)
│   ├── _test_motor_pursuit_pinch_detour_smoke        (C1 L1)
│   └── _test_motor_locale_approach_no_oscillation_smoke (C2 L1)
└── CREATURE_MOVEMENT_V3_CLEANUP.md                   (close C1 + C2 when both L1 green)
```

**Both L1 fixtures stay** — they guard different geometries (`pursuit_pinch` wall vs `locale_orbit` open field) and different step sources. One duel manual session signs off both (rabbit locale patch + fox obstacle chase).

**Split fallback:** if review size demands, land **Layer 1 + Layer 2** first (foundation + both smokes red→green on the shared parts), then the Layer 3 tails as a fast follow within the same slice tag.

### Implementation order (locked)

| Pass | Scope | Exit |
|------|--------|------|
| **1** | Red smokes + **Layer 1** (cone contract, overshoot guard, turn-first + materiality) | `_test_motor_align_cone_contract` green; locale overshoot smoke shows remint / no orbit on fixed fixture |
| **2** | **Layer 2** (`locale_no_progress_ticks` → §9) | **Shipped 2026-07-13** — `_test_motor_locale_approach_no_oscillation_smoke` + locale branch in `_test_motor_planner_latched_stuck_replan` |
| **3** | **Layer 3 C1** (detour latch Option A + stack §9 short-circuit) | **Shipped 2026-07-13** — `_test_motor_pursuit_pinch_detour_smoke` + planner latch/§9 gate tests |
| **4** | **Layer 3 C2** (handoff scoring + locale arrival/EAT-bind) | **Shipped 2026-07-13** — handoff tests + locale arrival bind/clear |
| **5** | Duel manual (14.2.7) | Rabbit locale patch + fox obstacle chase one session. **Not done.** C3 (`post-6d-prey-eat-contact`) shipped in parallel — do not fold into Pass 5 exit. **Next:** [C1 residual follow-up](#follow-up-plan-locked--c1-residual-2026-07-14) (sticky detour vs live remint + latch **32**) before Pass 5 sign-off. |

Smoke distance/tick constants (X, K, N) tune during pass 1–2 red→green runs.

### Resolved — step-goal-jump + turn-first (Layer 1 tail)

- **Material change:** horizontal `dist(old_step_goal, new_step_goal) > _latched_stuck_move_epsilon(motor_v3, body, delta)` → `force_align_turn_before_move = true`.
- **Turn-first execution:** [`align_and_move`](../../creature/motor/motor_planner.gd) — when flag set, emit **`TURN_*`** (never `MOVE_F` that tick); clear flag after the forced turn pick. Shared with overshoot remint (sets flag on remint).

### Resolved — Layer 3 tails (locked for pass 3–4)

**C1 pursuit detour (Option A):** On blocked `MOVE_F` with live prey latch, copy post-`apply_immediate_blocked_path_reevaluation` `step_goal` into `pursuit_detour_waypoint` + hold `pursuit_detour_latch_ticks` (**32** after C1 residual; was **16** Pass 3). `step_ultimate_pos` = live prey ultimate. **C1 residual (2026-07-14 shipped):** latch stays authoritative as `step_goal` through live ultimate refresh; no per-block remint while latched; alternate-side remint when `consecutive_blocked >= dead_end_record_min_blocked_ticks` — see [Follow-up plan](#follow-up-plan-locked--c1-residual-2026-07-14).

**C1 §9 gate:** [`creature_motor_stack.tick`](../../creature/motor/creature_motor_stack.gd) — if `note_outcome` requests blocked resolution **and** `prey_engagement_latch_valid` **and** live ready food visible in scan, **do not** call `apply_blocked_objective_resolution` (or call with seek suppressed). Ghost-only / no live prey: §9 seek unchanged.

**C2 handoff:** In `_derive_find_food_step_objective` on re-derive only — if live ready food **and** locale consult would win memory tier, score: same `stimulus_kind_id` → keep live; else compare live sample calories-per-EAT vs locale tier estimate (live sample fields v1).

**C2 locale arrival:** On `src=locale` + `dist(ultimate) ≤ eat_action_max_distance` + live ready food at anchor → switch to live `EAT` path; if no consumable, clear locale step fields (stop orbit). Pass 4 empty-locale clear remains correct; if orbit keeps creature outside eat range or remints after clear, [progress retention on overshoot](#resolved--overshoot-guard-layer-1) is the Layer 2 escape hatch.

---

## Smoke test engineering — complex geometry

**Problem:** §3 `motor_path_fixture` today has **`open`** and **`blocked`** (single center wall). That proves nav bake + detour path existence but **does not** exercise carnivore **live-prey pursuit** with obstacle-between-predator-and-prey — the C1 failure mode.

**Goal:** A **fast headless smoke** that fails on the fox stall loop without booting full duel / grasslands art.

### Layered approach (recommended)

| Layer | What it proves | Cost |
|-------|----------------|------|
| **L0** | Fixture nav bakes; path detours | Existing `_test_motor_path_fixture_*` |
| **L1** | Planner + stack + blocked layout + **mock prey** | New — primary CI gate for C1 |
| **L2** | Full duel scene manual smoke | Human sign-off (14.2.7) |

Implement **L1** for C1; keep L2 as release checklist.

### L1 fixture layout: `pursuit_pinch`

Extend [`tests/motor_path_fixture.gd`](../../tests/motor_path_fixture.gd) with a third variant:

```
Predator (fox)          Prey (rabbit)
    P ●                      ● R
         \                  /
          \    [wall]      /
           \   ████       /
            \  ████      /
             \_________/
```

**Geometry (world units, 40×40 floor):**

| Node | Position (approx) | Size | Purpose |
|------|-------------------|------|---------|
| Floor | existing | 40×40 | Walkable |
| **Pinch wall** | `(20, 1, 14)` | `0.4 × 2 × 6` (along X) | Blocks direct P→R corridor; nav routes around north or south |
| Predator spawn | `(6, 0, 20)` | — | Fox body + carnivore stack |
| Prey spawn | `(34, 0, 20)` | — | Mock threat/food sample (see below) |

**Nav assertions (fixture self-test):**

1. `map_get_path(P, R).size() ≥ 2`
2. Path does **not** pass through wall AABB (same pinch check as `blocked` layout)
3. Direct LoS ray P→R **fails** (or corridor sweep blocked) — mirrors playtest

### L1 test harness: `_test_motor_pursuit_pinch_detour_smoke`

**Arrange**

1. `MotorPathFixture.build_pursuit_pinch(parent)` → `map_rid`, `space_state`, teardown.
2. Spawn carnivore `CreatureMotorStack` (or planner-only with `_flight_test_planner_ctx` pattern) at P; facing +Z or toward prey.
3. Inject **live prey sample** in planner ctx:
   - `goal_kind_id = find_food`, `is_moving = true`, `instance_id` stable
   - World position at R (no scene rabbit required — zone scan mock / `awareness_samples` dict used by existing flight tests)
4. Merge block: `creature_motor_v3` defaults + `prey_engagement_latch` enabled.
5. Low calorie on predator so `find_food` wins; no Flight threat.

**Act**

- Run **N physics ticks** (suggest **120–180** @ 60 Hz ≈ 2–3 s) calling `motor_stack.tick()` or `MotorPlanner.plan_tick()`.
- Pass real `map_rid` + `space_state` from fixture (not invalid RID).

**Assert (smoke — tune after first green run)**

| Assertion | Rationale |
|-----------|-----------|
| Predator–prey distance **decreases** vs tick 0 by ≥ X units | Not stalled at range |
| `cblk` (or blocked streak) **never** exceeds 2 for more than K consecutive ticks | No stall loop |
| `src` stays `live` (or `belief` if designed) — **no** `explore` with `tgt=(0,0)` while prey live | C1 signature |
| At least one `TURN_L` or `TURN_R` in window | Alignment / detour engaged |
| Final distance ≤ `action_max_distance` * 2 (or eat bind range) | Contact pursuit completes smoke goal |

**Optional stricter assert (after fix lands):**

- Minted `pursuit_detour_waypoint` (or nav substep) latched ≥ 4 ticks before prey range closes.

### Why not only duel smoke?

- Duel loads art, AI driver, HUD, bake timing — slow and flaky in CI.
- C1 needs **deterministic** obstacle between **two creature roles**; programmatic fixture is the §3 pattern (14.2.3).
- Manual duel remains the **integration** check (navmesh from playfield, mesh obstacles, both species packs).

### Reuse from existing tests

| Pattern | Source in `tests/run_all.gd` |
|---------|------------------------------|
| Planner ctx builder | `_flight_test_planner_ctx`, `_flight_test_threat_at` |
| Fixture mount | `_test_motor_path_fixture_blocked_nav` |
| Stack tick loop | `_test_creature_motor_stack_seek_live_food` |
| Blocked reeval | flight tests A/B/C post-6d |

### Implementation order

1. Add `build_pursuit_pinch()` + unit assert nav/LoS properties.
2. Add **red** smoke test with assertions above (expect fail on current main).
3. Implement C1 fix; green smoke + manual duel.

---

## Smoke test engineering — locale approach (C2)

**Problem:** Existing `_test_creature_motor_stack_seek_locale_prior` proves **one tick** of locale consult + step_goal direction. It does **not** exercise multi-tick `align_and_move` convergence, overshoot, or stuck replan — the C2 failure mode.

**Goal:** A **fast headless smoke** that fails on the locale spin loop without duel art.

### Layered approach (recommended)

| Layer | What it proves | Cost |
|-------|----------------|------|
| **L0** | Locale consult returns anchor + `src=locale` | Existing `_test_creature_motor_stack_seek_locale_prior` |
| **L1** | Multi-tick stack + planner + **seeded locale** + position assertions | New — primary CI gate for C2 |
| **L2** | Duel manual — live eat → locale retarget | Human sign-off (14.2.7) |

Implement **L1** for C2; keep L2 as release checklist.

### L1 fixture layout: `locale_orbit`

No new nav wall required — use existing `_motor_v3_test_floor` + open walkable space (same as locale prior tests).

**Geometry (world units):**

| Node | Position (approx) | Purpose |
|------|-------------------|---------|
| Herbivore spawn | `(0, 1, 0)` | Rabbit body + stack |
| Locale prior | grid cell `(7, 7)` → anchor ≈ hotspot center | `stack.seed_locale_prior_for_test(7, 7, strength)` — same pattern as existing memory tests |
| **Misaligned facing** | `last_move_direction` ≈ **+X** while anchor is **+X/+Z quadrant** | Forces turn sequence before forward moves |

**Optional reproducer (tighter):** second variant spawns body **past** anchor along approach vector (overshoot) to mirror playtest t=2366 rear-hemisphere `MOVE_F`.

### L1 test harness: `_test_motor_locale_approach_no_oscillation_smoke`

**Arrange**

1. `Node3D` floor + herbivore body at spawn; calories low enough that `find_food` wins.
2. `CreatureMotorStack` configured; **empty live scan** (no bush) — locale is only consult tier.
3. `seed_locale_prior_for_test(7, 7, 1.0)` (or explicit anchor at playtest-like `(26, 0, 78)` if grid mapping is wired in test).
4. Facing **away** from anchor (e.g. `-Z`) to require alignment ticks.

**Act**

- Run **N physics ticks** (suggest **90–120** @ 60 Hz) calling `stack.tick()`.
- Record per-tick planner snapshot: `step_source`, action, heading error to `step_goal` (test helper or debug hook).

**Assert (smoke — tune after first red run)**

| Assertion | Rationale |
|-----------|-----------|
| `step_source` stays `locale` until arrival or §9 switch — **no** unexplained drop to `explore` at origin | Stable locale seek |
| Distance to anchor **decreases** vs tick 0 by ≥ X units **or** final distance ≤ `action_max_distance` | Not orbiting in place |
| **No** `MOVE_F` **selected** when misaligned at decision time (`|err| > 22.5°` pre-move) | Cone contract at `select_action`; post-tick rear-hemisphere `err` is overshoot telemetry, not a cone bug |
| Count of consecutive ticks with `locale_no_progress` (or zero displacement) **< K** (e.g. 24) | No infinite spin |
| No alternating `err` sign flip across rear hemisphere for M consecutive forward moves | Orbit loop detector |

**Optional stricter assert (after fix lands):**

- §9 `seek` or explore remint fires once when progress stalls — mirrors precise stuck path.

### Reuse from existing tests

| Pattern | Source in `tests/run_all.gd` |
|---------|------------------------------|
| Locale seed + one-tick consult | `_test_creature_motor_stack_seek_locale_prior` |
| Multi-tick stack loop | `_test_creature_motor_stack_seek_live_food` |
| Latched stuck / precise no-progress | `_test_motor_planner_latched_stuck_replan` |
| Planner ctx without full stack | `_flight_test_planner_ctx` |

### Implementation order

1. Add `_test_motor_locale_approach_no_oscillation_smoke` — **red** on current main (expect orbit / overshoot / no stuck escalation).
2. Implement shared Layer 1 (overshoot + step-goal-jump) and Layer 2 (`locale_no_progress_ticks` → §9), plus C2 Layer 3 handoff scoring; green smoke. See [Shared implementation plan](#shared-implementation-plan-c1--c2).
3. Duel manual sign-off — rabbit locale patch after eating.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-07-10 | Created; C1 fox pursuit stall + L1 smoke design |
| 2026-07-10 | C2 locale food approach oscillation (rabbit) + L1 `locale_orbit` smoke design |
| 2026-07-10 | Merged C1 + C2 into shared slice `post-6d-approach-geometry`; added [Shared implementation plan](#shared-implementation-plan-c1--c2) (3 layers, one PR, two smokes). Corrected “cone gate” → cone is already enforced pre-move; real fixes are overshoot guard + step-goal-jump + stuck escalation. Resolved answers: `pursuit_detour_latch_ticks`=16; §9 seek stays for ghost-only prey; live↔locale handoff scoring (same-kind → live, else calories-per-`EAT`); `locale` uses a dedicated no-progress counter (not `_is_latched_step_source`); locale §9 threshold reuses `dead_end_record_min_blocked_ticks` (3) in v1. |
| 2026-07-13 | Locked [Overshoot guard contract](#resolved--overshoot-guard-layer-1): post-`MOVE_F` passed-goal detection in `note_outcome`; remint from `step_ultimate_pos` + turn-first; no §9 from overshoot; close band in move-steps (`approach_overshoot_guard_move_steps`=2); explore path unchanged. Deferred Layer 2 `live` wiring. Smoke cone assert → decision-time only. |
| 2026-07-13 | Pass 1 regression fix: exclude continuous `live` / `memory_moving` same-instance retarget from material turn-first; remove `live` from overshoot guard (doc-deferred). Added `_test_motor_live_pursuit_no_turn_storm_smoke`. |
| 2026-07-13 | **Pass 2 shipped:** Layer 2 — `_note_fixed_objective_position_progress` helper; `locale_no_progress_ticks` → §9 in `note_outcome` (mirror `precise`; `locale` not added to `_is_latched_step_source`); reset on overshoot remint, meaningful MOVE progress, goal-kind change, and fresh locale mint. Locale branch in `_test_motor_planner_latched_stuck_replan`. |
| 2026-07-13 | **Pass 3 shipped:** C1 Layer 3 — `pursuit_detour_waypoint` latch (Option A, mint after blocked reeval); `should_suppress_live_pursuit_blocked_resolution` §9 gate in stack; `pursuit_detour_latch_ticks`=16 in `game_config_merge.gd`; `MotorPathFixture.build_pursuit_pinch`; `_test_motor_pursuit_pinch_detour_smoke` + planner latch/§9 unit tests; stack `_resolve_main` walks parents for `map_rid`. |
| 2026-07-13 | **C3 logged:** Prey contact without EAT / body-pin stall (fox) — duel log ~t=3188; slice `post-6d-prey-eat-contact` (design/open; not Pass 4). |
| 2026-07-13 | **Pass 4 shipped:** C2 Layer 3 — live↔locale handoff scoring on re-derive (same kind → live; else calories-per-EAT); locale arrival bind live or clear orbit; helpers `_live_vs_locale_handoff_prefers_live`, `_maybe_locale_arrival_bind_or_clear`; tests `_test_motor_planner_live_locale_handoff_*` + `_test_motor_planner_locale_arrival_binds_live_or_clears`. |
| 2026-07-13 | **C3 EAT gates locked:** ultimate distance (not `step_goal`); `eat_range_move_steps`=5; `eat_facing_arc_deg`=90; plant+prey consistent v1; primary spin self-correct + 3-revolution backup then one step back; status `ready`; open-field orbit evidence addendum. |
| 2026-07-13 | **C3 shipped:** `_can_eat_now` → ultimate + move-steps + `eat_facing_arc_deg`; orbit break via `MOVE_BACKWARD` after `eat_orbit_break_revolutions`; config defaults in `game_config_merge.gd`; headless `_test_motor_planner_eat_uses_ultimate_not_step_goal` + `_test_motor_planner_eat_orbit_break_after_revolutions`; status `done` (duel manual open). |
| 2026-07-13 | **C3 duel manual signed off:** `predation_carn_win` (herb_cal=30 carn_cal=6); fox `act=EAT` t=3549 `src=live` cal 1%→10%; open-field/chase contact V3 EAT kill (not starve orbit). Headless + duel both closed for C3. |
| 2026-07-14 | **C2 residual / overshoot Response #3 locked:** duel ~10:34–10:35 UTC — Pass 1–4 shipped but locale overshoot orbit persisted (`food=0`, 0 EAT, rear-hemisphere MOVE_F). **Supersede** “reset `locale_no_progress` on overshoot remint”: **retain** `locale_no_progress_ticks` and `precise_no_progress_ticks` on overshoot remint so Layer 2 can escalate §9; Layer 1 still remints + turn-first without calling §9 from the overshoot handler. Pass 4 empty-locale clear remains correct; verify sticky clear separately if remint-after-clear still observed. Pass 5 not done; C3 unchanged. |
| 2026-07-14 | **Overshoot Response #3 shipped:** `_maybe_apply_fixed_objective_overshoot` no longer resets locale/precise progress; `_test_motor_planner_overshoot_retains_locale_no_progress` (+ remints fixture `arrival_tolerance` for close-band). |
| 2026-07-14 | **C3 EAT range restored to 5 m:** `_can_eat_now` / orbit use `eat_action_max_distance` (world meters to ultimate); removed `eat_range_move_steps` (speed-scaled range deferred). Duel evidence: fox trailed with 0 EAT under ~0.4 m step band. Facing arc 90° + orbit break unchanged. |
| 2026-07-14 | **C1 residual locked:** duel `winner=none` / `end_ai` t=2804–3203 — obstacle/pinch stall after Pass 3 (259 MOVE_F, 26 blk=1, err≈−50°–−80°, 0 EAT, cal 22%→11%); distinct from C3 open-field orbit. [Follow-up plan](#follow-up-plan-locked--c1-residual-2026-07-14): sticky `pursuit_detour_waypoint` vs live remint; no per-block remint; alternate detour on persistent block; `pursuit_detour_latch_ticks` **32** initial (tunable to 48); §9 gate preserved; pass/reopen recovery deferred; avoid hitbox/EAT-widen/rock-removal. C1 status → `in_progress`; Pass 5 not done. C2/C3 unchanged. |
| 2026-07-14 | **C1 residual shipped:** sticky detour vs live remint (`_refresh_live_prey_meta_only`); skip per-block remint while latch valid; `_remint_alternate_pursuit_detour` on `consecutive_blocked >= dead_end_record_min_blocked_ticks`; `pursuit_detour_latch_ticks`=32; tests sticky / skips-reeval / alternate-remint. Pass 5 duel still open. |
| 2026-07-14 | **C4 logged:** headless `run_all.gd` — 37 assertion(s) failed, `slot >= slot_max` ObjectDB errors in `_belief_instance_passes_diet` (`memory_adapter.gd:978`) cascading into 8+ test failures + leaked RID/ObjectDB/Resource at exit. Confirmed via `git stash` isolation **not** caused by in-flight replay-capture instrumentation change; root cause vs rest of session's WIP unconfirmed. Status `open`; slice unassigned. |
| 2026-07-14 | **C4 root-caused + fixed:** `_belief_instance_passes_diet` called `instance_from_id` on an unvalidated `instance_id`; unresolvable ids (stale or synthetic test ids) both spammed the ObjectDB error and silently returned diet-fail, under-counting feasibility/inventory. Guarded with `is_instance_id_valid(...)` before the lookup. Headless: 37 → 15 assertion failures (19 sites fixed). Status `done`. |
| 2026-07-14 | **C5 logged:** `_test_seek_wall_filter_and_backtrack` confirmed **not** a C4 symptom (uses a real `bush.get_instance_id()`). Traced to the 60° backtrack deflection living only in `apply_immediate_blocked_path_reevaluation` (reactive, post-blocked-MOVE per §3.2) while the test calls `select_action` once on a fresh state with no live obstacle — likely a stale test predating the 6e.1/6e.2 executor refactor rather than a production gap. Status `open`; not yet fixed. |
| 2026-07-14 | **C6 logged:** fixing C4 let `_test_creature_motor_stack_memory_tier_precedence` run past a point it had never reached before (previously aborted by the C4 crash), exposing a real, previously-invisible failure — locale consult doesn't win when all instance beliefs are absent. Not caused by the C4 fix; only newly visible because of it. Status `open`; not yet root-caused. |
| 2026-07-14 | **C6 root-caused + fixed:** stale latched `precise`/`coarse` `step_source` had no re-derivation trigger when its incumbent belief was erased (`_sync_step_objective`'s elif chain never re-entered `_derive_find_food_step_objective`). Added `_find_food_memory_tier_stale` — re-consults the incumbent tier and falls through to precise→coarse→locale re-derivation when it's no longer active. Same fix resolved both the "coarse beats locale" and "locale consult" asserts in `_test_creature_motor_stack_memory_tier_precedence` (one root cause, not two). Headless green for all three asserts. Status `done`. |
| 2026-07-14 | **Replay-harness Phase 2 shipped:** retrofit `_test_motor_locale_approach_no_oscillation_smoke` (90 → 150 ticks) and `_test_motor_pursuit_pinch_detour_smoke` (240 → 300 ticks) to sample a `MotorStallDetector.Tracker` each tick and assert `not stall.stalled(...)`, alongside their existing hand-rolled progress signals (rear-hemisphere count, `consecutive_blocked` streak) rather than replacing them. Pinch-test prey (`PREY_IID` 88050) now drifts (`sin`-wave ±2.5 world units on `z`) instead of sitting frozen at a fixed point, so the detour latch is exercised against a genuinely moving target. Headless: both smokes green, total assertion failures unchanged at 15 (matches post-C4-fix baseline) — no regression. |
| 2026-07-14 | **C5 fixed:** confirmed both `blocked_approach` consult sites in `motor_planner.gd` (`apply_immediate_blocked_path_reevaluation`, `apply_blocked_objective_resolution`) are reactive-only, called from `creature_motor_stack.gd` solely after a genuine blocked `MOVE_FORWARD` this tick — never from `select_action`'s fresh derivation. Not a production gap. Corrected `_test_seek_wall_filter_and_backtrack` to assert a fresh `select_action` pick ignores blocked-approach memory, then drive the reactive path directly via `apply_immediate_blocked_path_reevaluation` and assert the deflection there. Headless: exact before/after line diff shows only the one stale assertion cleared, nothing else changed. Status `done`. Also resolves the earlier "15 vs 16" mystery: the runner's summary count can undercount actual `ERROR: ASSERT` lines by one — cosmetic, not nondeterminism; `grep -c "ERROR: ASSERT"` is the reliable count. |
| 2026-07-15 | **R1 logged:** named "one action per tick + turn-first alignment" (§14.1.1 accepted product bet) as the standing architectural root of the C1/C2/C3/C5 bug family — not a new bug, a design-level trade-off. Documented two additive near-term mitigations (arrival damping; blend turn+move in one tick) and a fallback (hybrid discrete-goal / continuous-local-controller executor) to escalate to only if both mitigations ship and overshoot/orbit/turn-storm regressions keep recurring on new goals. Status `watch`; not scheduled. |
| 2026-07-15 | **R1 mitigation #1 shipped:** arrival damping. Removed `LocomotionExecutor._clamp_overshoot_to_goal` (post-hoc position snap that was fighting the planner's own overshoot remint); added `_arrival_damping_frac` tapering `MOVE_FORWARD` speed from full to 0.35× inside a new `approach_arrival_damping_radius` (2.5 m, independent of EAT range) as `dist_to_goal` closes — goal-agnostic, not EAT-specific. `dist_to_goal` is now planner-owned state (`align_and_move`), threaded to the executor instead of recomputed there, for future range-gated consumers (e.g. ranged combat). Damping floor checked against `motor_stuck_move_epsilon`'s no-progress threshold (~1.87× margin) so it can't falsely trigger §9 escalation. Headless: 4 runs each of pre/post code produced byte-identical failure sets (13 assertions) — no regression. Investigation also surfaced [C7](#c7-flaky-headless-assertions-nondeterministic-across-identical-runs) (test-suite flakiness, logged separately). |
| 2026-07-15 | **C7 logged:** 3 headless assertions found to intermittently pass/fail across identical back-to-back runs of unchanged code (replay-fixture prey-closing check; two `_test_creature_motor_stack_memory_tier_precedence` tier-precedence asserts). Discovered via `git stash` A/B verification of R1 mitigation #1 — cost real investigation time before being correctly identified as pre-existing flakiness, not a regression. Root cause not diagnosed (candidates: Jolt physics nondeterminism, residual C4 ObjectDB noise). Also noted: the replay-fixture carnivore body is airborne (`is_on_floor() == false`) for its entire 60-tick capture in both pre- and post-R1 code — separate, undiagnosed fixture gap. Status `open`. |
| 2026-07-15 | **R1 mitigation #1 damping-asymmetry regression fixed:** duel smoke immediately after shipping arrival damping ended `starvation_carn_herb_win` — fox tracked the rabbit with near-perfect bearing alignment for 600 straight ticks (avg error 0.0–0.2°) but never reached `EAT`. Confirmed via `hunter_killer.log` this was **not** the classic overshoot signature (zero `dot<0` occurrences in today's real duel pursuit, vs. it recurring in prior duels/headless runs pre-fix). Root cause: damping only ever engages for the *chasing* creature — fox's `step_goal` is the rabbit's live position (shrinks as it closes), rabbit's own `step_goal` is a 75m flee waypoint (never shrinks) — so a fox with only a 17% raw speed edge (7.0 vs 6.0) got throttled below the rabbit's speed inside ~1.95m while the rabbit stayed at full speed. Fixed by excluding `step_source == "live"` from arrival damping in `creature_motor_stack.gd`, mirroring the existing `live` exclusion on the overshoot remint for the same reason (continuously-retargeting moving-prey goal, not a point to decelerate into). `state["dist_to_goal"]` itself still computed/stored every tick for future consumers — only the executor hand-off is gated. Headless: 3 runs post-fix, byte-identical to the 13-assertion baseline. Duel re-verification pending (manual). |
| 2026-07-15 | **Debug distance instrumentation added:** follow-up duel review (rabbit juking near the end of a still-`starvation_carn_herb_win` run) needed to confirm the fox wasn't missing valid `EAT` opportunities, but `motor_explore_tick.log` had no raw distance field — only bearing (`err`/`dot`). Indirect signals (zero `MOVE_BACKWARD` orbit-breaks, zero `EAT` actions all duel) pointed to "never in range" rather than a facing/timing bug, but weren't conclusive. Added `dist_to_goal` to `CreatureMotorStack.get_debug_snapshot()` (recomputed fresh from current body position each call, not read from the possibly-stale planner-state value, so it's accurate even on ticks that skip `align_and_move` — EAT/orbit/STAY-at-arrival) and to both `motor_planner_explore_log.gd` formatters (`dist=%7.2f` column, HUD + rolling log). Headless: full-suite diff unchanged (13 assertions, same set) — additive, no regression. |
| 2026-07-16 | **R1 mitigation #2 shipped:** blend turn+move in one tick. New `motor_v3` key `move_blend_max_error_deg` (60°) widens `align_and_move`'s `MOVE_FORWARD` gate (`_is_within_move_blend_arc`) past the tight `turn_increment_deg` cone; `LocomotionExecutor._blend_turn_toward` rotates `last_move_direction` toward the tick's target by up to one turn increment before moving, so a single `MOVE_FORWARD` now carries a bounded heading correction (tank/car-style) instead of requiring full alignment first. `creature_motor_stack.gd` threads `step_goal` in as the blend target on every `MOVE_FORWARD` tick, `step_source == "live"` included (opposite of damping's live-exclusion — heading correction is exactly what a continuously-retargeting pursuit needs). Motivated by a fresh duel log (`motor_explore_tick.log`, `t=3374`): fox `dist_to_goal` hit 0.00 (contact) but `dot` flipped `0.993→-0.872` in one tick (overshoot with a frozen heading, target now behind), then `MOVE_FORWARD` kept firing for ~10 more ticks facing away before a turn recovered — 0 `EAT` actions all session, calories 11%→0%. Calorie cost model already charges TURN/MOVE identically, so no C3 action-economy rebalancing needed. 3 pre-existing tests hard-coded the old tight-cone threshold by name (`_test_motor_planner_explore_rear_hemisphere_no_flip_flop`, `_test_motor_planner_flight_close_range_converges_and_displaces_away`, `_test_motor_planner_flight_flee_waypoint_orbit_stable`) — updated to reference `move_blend_max_error_deg` instead. Headless: isolated mitigation #2's own diff (not full `git stash`, which would've also reverted mitigation #1's still-uncommitted work) — found a **pre-existing, stable 13-assertion failure set** unrelated to any R1 work (different names than the C7 flaky baseline, byte-identical across 3 runs with mitigation #2 reverted); with mitigation #2 applied and the 3 tests updated, 3 consecutive runs reproduced that exact same 13-assertion set — zero net-new failures. Duel re-verification pending (manual, §14.2.7). |
| 2026-07-16 | **[C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) logged and partially fixed:** user asked whether the 13-assertion stable failure set surfaced above was stale pre-V3 test artifacts. Audited all 13 individually — none were testing removed functionality; all are live current systems (explore bearing scoring, overshoot replan, flee waypoints, boundary scan, LOS occlusion, food-map confidence). Fixed 5: `explore_dir` threshold too strict for the 8-wedge picker's geometry (loosened `>0.99`→`>0.9`); a single cold-start tick can't clear the no-progress epsilon under acceleration-ramped movement (test now runs 30 ticks); two overshoot tests never set `state["goal_kind"]`, so `_sync_step_objective`'s goal-kind-change reset wiped their pre-seeded fixture before the code under test ever ran (also surfaced a real but out-of-scope asymmetry: `_maintain_explore_latch` doesn't self-heal an overshoot with a fresh mint same-tick the way `mint_explore_step` does); a flee-waypoint-refresh test moved a threat to a position with the *same bearing*, so an unchanged waypoint was the *correct* answer, not a bug. Left 8 open with root-cause hypotheses documented in C8, most promisingly a likely-real boundary-scan re-arm regression (`post-scan inward align` — body reaches perfect alignment mid-turn-sequence but keeps turning instead of moving, completing a full spin) and a shared LOS/wall-raycast non-detection issue affecting 3 tests. Full suite: 13 → 8 failures, stable across 3 runs. |
| 2026-07-16 | **[C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) shipped:** user reported the rabbit stuck at the playfield edge trying to escape the fox, then both stuck once the fox arrived. Traced via a fresh duel log to `apply_immediate_blocked_path_reevaluation` stamping its per-tick reactive backtrack/LOS deflection into the persistent `flee_waypoint` latch — each blocked tick's deflection became the "ultimate" input to the next tick's own deflection, a self-referential drift with no way back to the real flee objective short of the whole Flight episode exiting. Confirmed against the log: distant-phase flee waypoints held a clean ~16-tick latch window with smooth drift (correct); near the boundary, `tgt` instead cycled through a stable ~34-tick, 4-point limit cycle with zero net displacement. Fix: removed the `state["flee_waypoint"] = state["step_goal"]` stamp — the latch now stays pinned to its original mint; deflection remains a this-tick-only movement correction. New test `_test_motor_planner_blocked_move_reeval_preserves_flee_latch` (drives the deflection via the raycast-independent backtrack-memory branch to avoid the still-open C8 LOS-raycast flakiness). Headless: 8/8 pre-existing C8 failures unchanged across 3 runs, zero new regressions. Fox's own related-but-distinct wall-oscillation (same `_run_path_clearance_los_nav` family, no persistent latch to corrupt) left open under C8. Duel manual re-verification still pending. |
| 2026-07-14 | **C2 residual #2 (same-tick overshoot clamp) shipped:** `_test_motor_locale_approach_no_oscillation_smoke` was still red after Response #3 (progress-counter retention) — a fresh `motor_explore_tick.log` capture showed the same rear-hemisphere flip (`err` jumping from ~`-19°` to `+154°` in one tick) inside `LocomotionExecutor._displace_along_facing`, at ranges beyond the reactive Layer 1 remint's sub-meter close band. `apply_action` now takes an optional `step_goal`; `_clamp_overshoot_to_goal` snaps the body back onto the goal (zeroing horizontal velocity) if the tick's displacement carried it past the goal along the pre-move approach line, same tick. `creature_motor_stack.tick` threads `_planner_state.step_goal` through on `MOVE_FORWARD`. Headless: `_test_motor_locale_approach_no_oscillation_smoke` green; full-suite diff vs. pre-change baseline shows zero new failures (`_test_motor_pursuit_pinch_detour_smoke` / C1 unaffected). Duel manual (Pass 5) still pending for both C1 and C2. |
| 2026-08-07 | **[C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) LOS/wall-raycast trio root-caused + fixed — turned out to be two unrelated bugs, not one shared cause:** the wall-block test was test-isolation (a synchronous prior test's `main.queue_free()` never got a frame to flush, so its leftover wall/floor/body were still live physics geometry the new test's body collided against) — fixed with two `await process_frame` calls. The other three (wall-bias, ghost-danger ×2) were a genuine algorithmic bug in `LineOfSight3D.occlusion_fraction`: it chopped the eye→target distance into 10 fixed-length buckets and voted per bucket, so a normal wall near the creature but far from a distant probe target could only ever fill ~1 bucket (max ~10% occlusion), never crossing the 80% blocked threshold *regardless of solidity* — a live-gameplay bug for wall-avoidance and ghost-threat memory alike, not just a test artifact. Replaced with a shadow-fan test (rays across the target's silhouette, radius `los_target_radius`, new pack-overridable default 0.5) in `line_of_sight.gd`. Also fixed a test wall too short for a real creature's mesh-fitted eye height, and — user-directed — rebalanced `explore_w_open` above `explore_w_spawn` (0.30→0.45 vs 0.35→0.20) plus added `explore_open_safety_margin_wedges` (new default 3) so a wedge grazing an obstruction's edge scores below one genuinely clear across the ring, instead of tying at a flat "fully open" and losing to spawn-heading inertia every time. §7.3.2 spec table and pinned-defaults test updated to match. Headless: 6 → 2 failures, byte-identical across 2 runs. Remaining 2 (`two known bushes`, `belief north of origin`) are unrelated, untouched. |
| 2026-08-07 | **[C8](#c8-stable-pre-existing-test-failures-found-during-r1-mitigation-2-audit) closed — final 2 items were both test-fixture bugs, not the ObjectDB/wedge-scoring gaps previously suspected:** `two known bushes` — `MemoryAdapter.get_beliefs()` returns a defensive `_beliefs.duplicate(true)`, not a live reference, so the fixture's `adapter.get_beliefs().erase(89003)` mutated a throwaway copy and the following `set_beliefs_for_test(adapter.get_beliefs())` fetched a fresh, still-unerased duplicate — all 3 beliefs stayed present, confidence never dropped from the saturated 1.0. Fixed by capturing the duplicate in a variable before erasing. `belief north of origin` — `explore_bearing_coverage`'s documented contract (§7.3.2/§8.4) never consults the locale-prior store, so the fixture's `seed_locale_prior_for_test` call (needed only for this test's other, already-passing `count_known_objectives` assertion) contributed nothing to the wedge comparison; the two beliefs used for the wedge check were both `PRECISE` tier at equal distance, so they scored identically by design. Fixed by seeding a second `PRECISE` belief sharing the north wedge, giving it a genuine edge via the real per-wedge accumulation path. Headless: 13/13 of this batch's original failures now green — first fully clean run since the batch was first logged 2026-07-16. |
| 2026-08-07 | **[C7](#c7-flaky-headless-assertions-nondeterministic-across-identical-runs) triaged:** tried to force a repro of `_test_creature_motor_stack_memory_tier_precedence`'s flake before guessing — a 30x in-process loop (pairing it with its real predecessor test to probe the leftover-geometry hypothesis behind this session's C8 fixes) found nothing; 39 separate-process full-suite runs post-fix also found nothing, against a historical ~1-in-6 rate (`(5/6)^39 ≈ 0.1%`). Not formally root-caused, left `open` rather than `done`, but no longer reproducing at anything like its original rate — most likely resolved incidentally by other timing-related fixes this session. **Found a second, previously-uncaught flaky test in the process:** `_test_motor_planner_explore_seek_seeds_waypoint` ("seek fallback seeds explore_dir from body facing") failed 2 of 18 separate-process runs — it never zeroed `goal_consideration_chaos` (default 0.15) the way sibling explore-direction tests do, and this session's C8 `explore_w_spawn` rebalance (0.35→0.20) narrowed the score margin between the facing-aligned wedge and its neighbors enough for chaos to occasionally flip the winner. A pre-existing flake, made easier to hit by that rebalance. Fixed by explicitly zeroing chaos in the test, matching established sibling-test convention; 25 separate-process runs post-fix, zero recurrence. |
| 2026-08-07 | **[C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) 6th fix: give-up escalation, modeled on (but not a literal port of) explore's `boundary_scan`.** User asked to discuss the design before implementing, with an explicit bar: it had to "pass the sniff test for something a cornered animal would really do." Copying `boundary_scan`'s literal turn-in-place-for-several-ticks mechanic was rejected on that basis — a real cornered prey animal doesn't pause to survey while a predator closes the last few meters. Kept `boundary_scan`'s *shape* instead (finer-grained search, commit to the first real opening) without its multi-tick pause: when even the best of `_mint_flee_waypoint`'s 6 geometry-scored candidate bearings (5th fix) reaches less than `flee_give_up_reach_frac` (new default 0.35) of the requested flee distance, escalate same-tick to a finer full-circle sweep (`flee_give_up_scan_directions`, new default 16) that — unlike the normal sweep — ignores recent-backtrack history entirely, and latches the result for far fewer ticks (`flee_give_up_latch_ticks`, new default 5, vs. the normal 16) since a cornered animal's situation changes fast. Headless suite: 0 assertion failures (matches C8-closed baseline), no regression. 4 repeated 3600-tick forced-edge-chase headless runs: 3/4 clean (up from the 5th fix's 2/4), 1/4 still tripped (tick 927). The one trip's flee_waypoint sat exactly on the world origin in the horizontal plane, which reads as a separate, still-open degenerate case (likely `_flee_objective`'s momentary no-threat-in-awareness fallback feeding a nonsense bearing into the same candidate-scoring machinery) rather than the escalation itself misbehaving — flagged for whoever continues C9, not chased down this session. |
| 2026-08-07 | **[C9](#c9-flee-waypoint-latch-corrupted-by-reactive-backtrack-deflection-rabbit-stuck-at-playfield-edge) 7th fix: flee-to-world-origin sentinel bug, root-caused and fixed.** Followed up on the 6th fix's flagged tick-927 candidate root cause. Two compounding facts: `AwarenessZone.line_of_sight_clear` (threat-awareness LoS) is a raw per-tick check with no hysteresis, unlike the path-clearance LoS check's `los_hysteresis_ticks` thrash-guard — it can flicker a threat's `in_awareness` false for a single tick near corner geometry; and `_flight_fast_path_active`'s own latch doesn't require a fresh acute threat every tick once armed, so the Flight episode keeps running through that flicker. When the flicker landed on the exact tick the flee-waypoint latch expired, `_mint_flee_waypoint` re-minted from `_flee_objective`'s `Vector3.ZERO` "no threat" sentinel — a value that's also a valid world position, and the only zero-check in `_mint_flee_waypoint` was on the *relative* vector to that point, not the point itself — so the candidate-scoring machinery treated "the world origin" as a genuine flee destination. The 6th fix's finer give-up scan just had enough search resolution to actually land a waypoint there; it didn't cause the bug. Fixed with a new `_flee_has_visible_threat(ctx)` helper that checks `threat_samples` directly instead of trusting the ambiguous sentinel; on a no-visible-threat tick, `_mint_flee_waypoint` now holds the existing latched waypoint (resets its countdown) instead of reminting — a real animal that loses sight of a predator for a moment keeps running the way it was already going, not rerouting toward a fixed point. Falls back to a spawn-facing waypoint only if there's no prior latched waypoint to hold. Headless suite: 0 assertion failures, no regression. 6 repeated 3600-tick forced-edge-chase runs: **zero C9 trips across all 6** (the origin-waypoint failure mode didn't recur once); 1/6 tripped instead on the unrelated, previously-"fixed" C10 airborne check (fox stuck under geometry, tick 731) — a new, unexamined data point, flagged separately and not investigated this session. Promising, but not enough repro budget yet to call C9 formally `done`. |
| 2026-08-07 | **[C10](#c10-fox-ends-up-under-the-geography-after-close-contact-with-prey-new-2026-08-05) recurrence found and re-fixed:** the C9 7th-fix verification's unrelated C10 trip (fox airborne 46 ticks at `pos=(-60.0, -2.52, -7.33)`) got a proper follow-up rather than being left as a one-off data point. A fresh raycast-grid probe (same methodology as the original C10 root-cause pass, deleted after use) confirmed this is the **same cause-2 family** (terrain-vs-capsule slope tunneling), not a new mechanism: no boulder anywhere near the fall region, real continuous single-collider terrain at the same ~30° slope grade as the originally-fixed spot, and the fox's logged position measurably below (~0.5m) the actual interpolated surface height. Conclusion: `safe_margin = 0.06` (the 2026-08-06 fix) was the right mechanism and measurably helped, but the original "10/10 clean" verification was a favorable sample, not full elimination — margin tuning reduces tunneling probability, it doesn't guarantee zero. User chose to bump the same margin further (0.06 → 0.15) over a new floor-recovery-backstop mechanism or slope-aware placement, both discussed first. Headless suite: 0 assertion failures, no regression. 10 repeated 3600-tick forced-edge-chase runs: **10/10 fully clean, zero trips of any kind** (neither C9 nor C10) — best combined verification result of the whole session, though per the lesson just learned, read as strong evidence rather than provable elimination. |
