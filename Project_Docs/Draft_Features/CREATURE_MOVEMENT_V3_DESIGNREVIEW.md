# CREATURE_MOVEMENT_V3 — Design review (2026-08-26)

> **Role:** Standalone critical review of the V3 motor architecture, based on a full read of [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md) (spec), [CREATURE_MOVEMENT_V3_CLEANUP.md](CREATURE_MOVEMENT_V3_CLEANUP.md) (C# bug/gap log), and [CREATURE_MOVEMENT_V3_RANDOMTESTS.md](CREATURE_MOVEMENT_V3_RANDOMTESTS.md) (RT# log), cross-checked against `motor_planner.gd`, `creature_motor_stack.gd`, `motor_goal_hub.gd`, `memory_adapter.gd`. Not a bug tracker — those three files remain authoritative for status/fixes. This file exists to surface cross-cutting design questions the C#/RT# entries don't individually capture, and to force decisions on them.
>
> **How to use:** Each `<<Question: ...>>` block is an open decision. Resolve inline (append an `**Answer:**` line under the block with date) or promote to a CLEANUP.md item once a decision is made and there's an actionable fix.

---

## Confidence: 5/10

The goal-arbitration layer (hub scoring, feasibility tiers, belief/memory system) is coherent and the bugs found in it (C6, C11) were shallow and closed quickly. The risk is concentrated almost entirely in **geometry-aware target/waypoint selection** — flee-waypoint minting and pursuit-detour — which has needed repeated, deepening intervention rather than one-off fixes.

<<Question: Does a 5/10 match your own read of project risk, or do you weight the arbitration layer's stability more heavily than the waypoint-selection instability?>>
<<Answer: I had a sense that there was a fundamental flaw based on the repeted bug patters. V3 is stronger than V1 or V2, so this feels like we are getting closer. I probably would have guessed 7/10. The challenge is this will compound the more actions and goals we add to the game so I would like to get this as bullet-proof as we can before we move on to COMBAT and other features that add significant complexity>>

---

## 1. The flee-waypoint/pursuit-detour family is one structural weakness, not scattered edge cases

Evidence, in order:

- **C9** (flee-waypoint latch, rabbit stuck at playfield edge) took **7 fix iterations**, is still `in_progress`, not `done`. Fix 4's own writeup calls it out directly: it confirms "the R1 architecture risk's 'no obstacle awareness in the fixed-goal calculation' gap... survives a 4th iteration of local patching, not just a hypothesis." Fix 5 was the first iteration to change the underlying algorithm (geometry-scored candidates via navmesh reachability) rather than patch heuristics around it — and it only closed 2 of 4 repro runs. Fix 7 (a `Vector3.ZERO` sentinel bug) hit 6/6 on the specific C9 repro, but the doc says there's "not enough repro budget spent yet to call C9 formally done."
- **RT1** is explicitly the same mechanism resurfacing under randomized spawn: "confirmed same mechanism... a new manifestation of the same underlying reach-only, connectivity-blind scoring gap."
- **C16** and **C17** (boundary-clamp overshoot; reach-scoring vs. straight-line-projection mismatch near boundary corners) are two *more* flee-waypoint bugs found after C9's fixes and RT1 shipped.
- **R1** in CLEANUP.md is the team's own acknowledged architecture risk behind the earlier C1–C5 overshoot/orbit/turn-storm family (discrete one-action-per-tick, turn-then-move). Both shipped mitigations (arrival damping, turn+move blending) produced their own regressions requiring further live re-testing, and R1's acceptance checklist explicitly leaves open whether new overshoot/orbit instances will keep appearing as more goals are added.

<<Question: Is it time to pull R1's fallback option (a continuous local controller replacing discrete one-action-per-tick movement) forward from "watch, mitigate case by case" to an actual scoped slice — before Fight/Mate become a 3rd and 4th consumer of the same bearing-only pattern?>>
<<Answer: Yes. We will need to review the existing design for all of the things that fundamental change impacts. My worry is that it will replace the existing class of bugs with a whole new class.>>

<<Question: Should C9 stay open indefinitely pending "more repro budget," or should we set an explicit exit criterion (e.g. N clean randomized-spawn runs across M playfield seeds) so it can be formally closed or formally reclassified as `watch`?>>
<<Answer: Given that R1's fallback is going to change many fundamental things, I think we should close it out. Even if it reoccurs, it won't be clear if they are really the same bug or just the same symptom.>>

---

## 2. A documented invariant was silently unimplemented, not just buggy

The V3 spec's Definitions (§10) describe a clean `GOAL_SHELTER` step chain (approach candidate → STAY evaluate → belief write). RT4 found that the planner's shelter/rest sync (`_sync_shelter_or_rest_objective`) was a stub unconditionally returning `false` for the entire life of the design doc, until Slice 1 shipped 2026-08-14. Nothing in the spec flagged this gap — it surfaced only via a manually forced debug repro rig, not through normal test coverage or a doc audit.

<<Question: Should the spec (§12 phasing) get a lightweight "implemented vs. documented" audit pass per goal kind, so a gap like this can't sit undetected for the doc's whole lifetime again? Or is the RT#/C# discovery-by-repro process considered sufficient?>>
<<Answer: This seems larger than Movement V3. We should create a spike to find a larger solution to this problem. Perhaps we need to create a project manager agent who's role is to track outstanding implementation tasks. This feels like something fell out of the context window and was forgotten. Perhaps it can be solved with some bookkeeping.>>

---

## 3. Historical "done" statuses may be less trustworthy than their status field suggests

During the 5th C9 fix, the team discovered `smoke_ai_player.gd`'s headless harness had been running flee-geometry verification against an **unbaked (empty) navmesh** for several earlier passes. This means some already-`done` items that relied on that harness for verification — including parts of C1's pursuit-detour nav substep — may never have actually exercised the geometry-aware code path they claimed to validate.

<<Question: Worth a one-time audit of which `done` C#/RT# items relied on `smoke_ai_player.gd` before the navmesh-bake fix, to confirm they're still valid? Or treat this as sunk and only worry going forward?>>

<<Answer: Yes, but the audit should also include a review of if the tests are likely to be changed as  part of R1's fallback. If they are, there's no need to test against the current implementation.>>

---

## 4. No shared "stuck" abstraction

C9's own root-cause section names this directly: flee latch, pursuit-detour latch, and (implicitly) any future goal-specific latch each lack an exit condition for "I've tried every option this mechanism offers and I'm still stuck." Flee and pursuit-detour each grew independent, differently-tuned give-up mechanisms (`flee_give_up_reach_frac`, `pursuit_detour_escalation_count`, different latch-tick counts) rather than sharing one. Explore mode's `boundary_scan` is the only goal with this solved cleanly.

<<Question: Worth extracting a shared "stuck detector" primitive now (before Fight/Mate need their own), or is it cheap enough to keep bespoke-per-goal given how differently each latch's failure mode looks?>>

**Answer (2026-08-28):** Build it, as part of V3 before moving on to other features.

**Design direction, from reading the three existing latches (`_maintain_flee_latch`/`flee_waypoint_ticks_remaining`, `_try_maintain_pursuit_detour_latch`/`pursuit_detour_escalation_count`, `_maintain_explore_latch`/`boundary_scan_turns`):**

All three share the same *mechanical lifecycle* — hold a target + countdown, re-affirm it each tick while valid, count escalation attempts against a cap, clear and fall through to a fresh mint once the cap is hit. That lifecycle (hold/decrement/expire/clear-with-escalation-tier bookkeeping) is what the shared abstraction should own.

What must stay **outside** the abstraction, as goal-specific callables:
- `is_stuck(state, motor_v3) -> bool` — the actual stuck signal differs by physical meaning per goal (flee: reach-fraction vs `flee_dist`; pursuit: detour waypoint still LoS-blocked; explore: bearing/distance-improved progress or fixed turn budget). These aren't parameterizations of one formula.
- `escalate(state, motor_v3, tier) -> Variant` — the next candidate target is also goal-specific (flee's 16-way scan, pursuit's incremental rotation around the last waypoint, explore's tangent walk).

Forcing these two into the shared layer would just relocate the sentinel/resonance-style bugs (§5/§6) into one place that now breaks three goals at once instead of one — so the abstraction should be scoped narrowly to lifecycle bookkeeping, not decision logic.

**Action:** scope as a V3 slice (not deferred to `NEW_GOAL_TEMPLATE.md` guidance-only) — replace the duplicated `*_ticks_remaining`/`*_escalation_count` state fields and duplicated hold/decrement/clear control flow in `_maintain_flee_latch`, `_try_maintain_pursuit_detour_latch`, and `_maintain_explore_latch` with the shared primitive, wiring each goal's existing `is_stuck`/escalation logic in as-is. Land this before Fight/Mate add a 4th latch family.

---

## 5. Sentinel-value overloading is a recurring smell, not a one-off bug

C9's 7th fix root cause was `Vector3.ZERO` doing double duty as both a "no threat" sentinel and a legitimate world coordinate. GDScript's bare `Vector3`/`float` return types make this easy to reintroduce anywhere a "no value" case exists.

<<Question: Adopt an explicit convention (e.g. a `has_value` out-param, or a wrapper resource) for optional geometric returns project-wide, or fix these one at a time as they're found?>>

**Answer (2026-08-28):** Companion bool per ambiguous field, not a null-based convention.

`state` fields are read into strictly-typed `Vector3` locals everywhere (`var x: Vector3 = state.get("key", Vector3.ZERO)`), which gives compile-time safety on all downstream vector math. Switching the sentinel to `null` would force every one of those ~90 call sites to a `Variant` type plus a manual null-check before any math — a larger blast radius than the bug itself, and it trades a silent-wrong-answer failure mode for null-reference runtime errors wherever a check is missed. Not an improvement.

The companion-bool approach is also not a new convention for this file — `los_blocked_latched`, `boundary_scan_active`, and `flee_give_up_active` already use exactly this shape (a bool as the source of truth alongside a value). Extend it to the ambiguous `Vector3` fields: `flee_waypoint`, `pursuit_detour_waypoint`, `step_goal`, `explore_waypoint`, `shelter_candidate_anchor` — plus `step_ultimate_pos` and `locale_arrival_clear_anchor`, found by the gap-closure pass below (seven fields total; see "Implementation sequencing").

**Important correction to the initial framing:** the bool must be the *only* way validity is checked — not "checked only near `(0,0,0)`." A conditional check that only applies near origin reintroduces the same bug in a new shape (still requires remembering *when* to check). Every existing `== Vector3.ZERO` / `length_squared() < 1e-8` "is this set" idiom (seen at motor_planner.gd:1100, 1577, 1854, 2534, and others) gets replaced outright by reading the paired bool (e.g. `flee_waypoint_set`), unconditionally.

**Action:** scope as a V3 slice alongside §4's latch abstraction (same files, same latch-adjacent fields) — add a companion bool for each of the seven fields, replace every magnitude-based "is this set" check with a bool read, remove the `Vector3.ZERO`-as-sentinel convention from those fields entirely. Exact clear-sites and exit check are enumerated in the "Implementation sequencing" section's gap-closure below.

---

## 6. Magic-number resonance across the tunable surface

`blocked_approach_backtrack_dot` (0.55) sitting just above `cos(60°) = 0.5` for a fixed 60°-increment rotation sweep produced an exact, mathematically inevitable resonance that broke C9's 3rd fix attempt — a coincidence between two independently-chosen constants, not a logic error. `creature_motor_v3` already carries dozens of independently tuned floats (e.g. RT4's `flee_dist` stacking two multiplicative scale factors unexpectedly).

<<Question: Is this worth a lightweight non-resonance check/lint (e.g. flag config pairs where one is a trig-derived threshold near another's step size), or accepted as a one-off that happened to get caught?>>
<<Answer: Yes, let's build something to test/find these cases in code before finding them in real-life. Can't be 100%, especially since some of these constants are expected to be tunable.>>

---

## 7. Staleness/latency assumptions differ across subsystems reading world state in the same tick

Path-clearance LoS checks have `los_hysteresis_ticks`; threat-awareness LoS checks (feeding goal arbitration) don't — a difference that directly caused one confirmed bug (noted in C9's writeup). This inconsistency isn't called out anywhere as a design principle to audit — it was found incidentally.

<<Question: Worth an audit pass across all per-tick world-state reads (LoS, belief consult, threat sampling) to normalize hysteresis/staleness handling, or fix each inconsistency only as it produces a bug?>>

**Answer (2026-08-31):** Yes — build a single shared per-tick subsystem that all LoS/belief/threat consumers call, rather than fixing inconsistencies piecemeal.

Same rationale as §4's shared "stuck" abstraction: today, path-clearance and threat-awareness each independently decide when a stale LoS read is still trustworthy (one has `los_hysteresis_ticks`, the other doesn't), so bugs like C9's have to be found and fixed per-consumer, and nothing stops a third consumer from reinventing its own (possibly inconsistent) staleness rule. A shared subsystem that samples once per tick and hands back a cached result to every caller makes the hysteresis/staleness policy a single decision instead of N independently-tuned ones.

**Action:** scope as a V3 slice — audit every current per-tick LoS/belief/threat read site (starting with path-clearance's `los_hysteresis_ticks` and the unhysteresed threat-awareness check named in C9's writeup), consolidate them behind one per-tick-cached subsystem, and retire the per-caller staleness logic they currently duplicate.

---

## 8. Scalability to new goal kinds is unproven

Mate and Fight are still stubs (`goal_base_find_mate = 0.0`, "not defined yet"). The one new goal added post-ship (Find Shelter) immediately produced both a silently-unimplemented stub (see §2 above) and a hardcoded feasibility-floor bypass. That's a two-for-two hit rate on "new goal exposes an undocumented gap."

<<Question: Before starting Fight or Mate, should there be an explicit pre-implementation checklist derived from what Find Shelter's rollout missed (step-chain completeness, feasibility floor wiring, latch/give-up coverage), or continue discovering gaps per-goal via repro as they've been found so far?>>
<<Answer: Yes. Create NEW_GOAL_TEMPLATE.md for this purpose and update the appropriate files to point to it>>

---

## Bottom line

The arbitration layer is not where further investment is urgently needed. The waypoint/target-selection layer (flee, pursuit-detour, and the discrete-movement model underlying both) is the concentrated risk, and the pattern across C9/RT1/C16/C17/R1 suggests continued patching has diminishing returns. The highest-leverage open decision is §1's: whether to schedule R1's continuous-controller fallback now, before a third and fourth goal kind (Fight, Mate) inherit the same bearing-only pattern.

---

## Status (2026-08-28)

Decisions made:

- **§1 — R1 fallback**: Approved in principle — move from "watch" to a scoped slice, gated on a design review of everything a continuous local controller touches. **Open blocker, discuss next**: how to scope that review without it becoming an open-ended rewrite.
- **§1 — C9 exit criterion**: Close C9 now rather than chase a repro-count threshold — once R1's fallback lands, a recurrence can't be cleanly attributed to "same bug" vs. "same symptom, new mechanism" anyway.
- **§2 — spec/implementation drift**: Bigger than V3. Spawn a spike — candidate direction is a lightweight project-manager-style tracking process/agent for outstanding implementation tasks, so a silently-stubbed function doesn't sit undetected for a doc's whole lifetime again. **Action:** open a spike doc outside this file's scope.
- **§3 — historical `done` audit**: Do it, but scope it jointly with §1 — skip re-verifying anything the R1 fallback is going to replace anyway.
- **§6 — magic-number resonance**: Build tooling to catch resonant constant pairs before they hit a live repro, accepting it can't be exhaustive since some constants are intentionally tunable. **Action:** becomes a CLEANUP.md item once §1's scope is known (resonance risk may change shape under a continuous controller).
- **§8 — new-goal template**: Approved. **Action:** create `NEW_GOAL_TEMPLATE.md` capturing what Find Shelter's rollout missed (step-chain completeness, feasibility floor wiring, latch/give-up coverage), and update the spec/cleanup docs to point new-goal work at it.
- **§4 — shared "stuck" abstraction**: Approved. Build as a V3 slice — shared lifecycle bookkeeping (hold/decrement/expire/clear-with-escalation-tier), goal-specific `is_stuck`/`escalate` stay outside it. See §4 for full design direction.
- **§5 — sentinel-value convention**: Approved. Companion bool per ambiguous `Vector3` field, checked unconditionally as the sole source of truth — not a null-based convention. Gap-closure (2026-08-31) expanded the field list from 5 to 7: `flee_waypoint`, `pursuit_detour_waypoint`, `step_goal`, `explore_waypoint`, `shelter_candidate_anchor`, `step_ultimate_pos`, `locale_arrival_clear_anchor`. See §5 and "Implementation sequencing" for full reasoning and enumerated clear-sites.
- **§7 — staleness/hysteresis consistency**: Approved. Build a single per-tick LoS/world-state subsystem that all consumers (path-clearance, threat-awareness, belief) call once per tick, returning cached results — rather than each consumer independently sampling with its own hysteresis rules. **Action:** scope as a V3 slice; audit all current per-tick LoS/belief/threat read sites (path-clearance's `los_hysteresis_ticks`, threat-awareness's unhysteresed check flagged in C9) and migrate them onto the shared subsystem so hysteresis behavior is defined once, not per-caller.

Still open (need more discussion before actionable): none — all eight sections have a decision recorded above.

**§1's open blocker — resolved (2026-08-28):** Scope the fallback as **executor-level only**. The goal hub keeps selecting one discrete winning goal/target per tick (arbitration contract, `select_action`'s role, and the C#/RT# latch mechanisms are untouched); only `locomotion_executor.gd`'s movement (turn+move blending, arrival damping) becomes continuous. This keeps the blast radius contained — R1's regressions so far (C1–C5 overshoot/orbit family) live at exactly this layer. Arbitration-level blending (goal hub itself continuously weighting multiple goals) was explicitly rejected as the near-term scope — too large a rewrite, touches `motor_goal_hub.gd` and `motor_planner.gd`'s contract simultaneously, and isn't what R1 was scoped to fix.

**Action:** the §3 historical-`done` audit and the pre-implementation review this unblocks should scope to `locomotion_executor.gd` and its direct callers/consumers (arrival damping, turn+move blending, anything reading a discrete `action` value produced this tick) — not the full motor stack.

All eight sections now have a recorded decision.

---

## Implementation sequencing (2026-08-31)

Four slices are approved and unstarted: §1 (R1 executor-level continuous controller), §4 (shared "stuck" abstraction), §5 (sentinel-bool convention), §7 (shared per-tick LoS/staleness subsystem). Order:

1. **§5 — sentinel-bool convention**
2. **§7 — shared per-tick LoS/staleness subsystem**
3. **§4 — shared "stuck" abstraction**
4. **§1 — R1 executor-level continuous controller**

**Why this order:** §4's goal-specific `is_stuck`/`escalate` callables will read exactly the fields §5 is fixing (`flee_waypoint`, `pursuit_detour_waypoint`, `explore_waypoint`) and exactly the LoS signal §7 is consolidating (pursuit-detour's `is_stuck` is "still LoS-blocked"). Landing §5 and §7 first means §4 is written once, against the final interfaces, instead of being built against the old sentinel/per-caller-hysteresis idiom and then retrofitted. §5 goes before §7 only because it's the smaller, more contained change (one file, `motor_planner.gd`) — order between §5 and §7 is otherwise not load-bearing and they could be done in parallel if useful. §1 goes last: it's the largest, riskiest rewrite, and it's the direct downstream consumer of whatever `step_goal`/waypoint contract §4 and §5 settle on — building it against a state representation that's about to change (sentinel semantics, latch field names) would mean re-touching `locomotion_executor.gd` a second time.

### Gap review per slice

**§5 — sentinel-bool convention — gaps closed (2026-08-31)**

*Field list was not exhaustive.* Re-running the `Vector3.ZERO` grep against `motor_planner.gd` and checking every field that's read back with a `length_squared() < 1e-8` / `> 1e-8` validity check (not just a `.get()` default) surfaces **two fields missed by the original five**:
- `step_ultimate_pos` — checked at lines 310, 329, 1260, 1268, 1313–1314, 1696, 2358; same "is this set" idiom as `step_goal`.
- `locale_arrival_clear_anchor` — checked at line 1942–1943 (`distance_squared_to` against a live anchor, only meaningful if the stored anchor is real).

So **§5's field list is seven, not five**: `step_goal`, `explore_waypoint`, `flee_waypoint`, `pursuit_detour_waypoint`, `shelter_candidate_anchor`, `step_ultimate_pos`, `locale_arrival_clear_anchor`.

One field from the original grep was checked and **correctly excluded**: `explore_dir` is a direction, not a position — it's read/rotated/reset but never validity-checked via magnitude, and a real (normalized) direction is never zero-length, so `Vector3.ZERO` is unambiguous for it already. No companion bool needed there.

*Clear-sites enumerated.* Grepping `state\["<field>"\] = Vector3\.ZERO` for the seven fields gives the exact write-sites needing a paired `<field>_set = false`:
- `step_goal`: lines 199, 379, 504, 610, 948, 1262, 1859, 1879, 2778 (9 sites)
- `explore_waypoint`: lines 198, 378, 503, 609, 852, 951, 1563, 1858, 1878, 2777 (10 sites)
- `flee_waypoint`: line 1948 (1 site)
- `pursuit_detour_waypoint`: line 1582 (1 site)
- `locale_arrival_clear_anchor`: line 959 (1 site)
- `step_ultimate_pos`: lines 964, 1263 (2 sites)
- `shelter_candidate_anchor`: **never explicitly cleared** — only default-initialized in `new_state()` (line 91) and written once at line 1435. Simplest of the seven: the companion bool just needs to start `false` and flip `true` at line 1435; no clear-site work needed.

(Every field also needs its companion bool flipped `true` at its real-value write sites — those aren't enumerated here since they're the normal "mint a new value" call sites the slice is already touching one by one; the risk this gap review is guarding against is specifically the *clear* path being missed, since clearing is the less-visited code path.)

*Exit check defined.* After migration, grep `motor_planner.gd` for `Vector3\.ZERO` and `length_squared\(\) < 1e-8` / `> 1e-8`: every remaining hit must be either (a) one of the seven fields' new companion-bool read, with the magnitude check itself deleted, or (b) a genuinely non-ambiguous use (math identity, `explore_dir`, a local temp default that never round-trips through `state`). Any magnitude-based validity check still present against one of the seven fields after the slice is marked done means the migration missed a call site — the grep is the acceptance test, not just a sanity pass.

**Implemented (2026-08-31).** All seven fields got a companion `<field>_set` bool in `new_state()`; every write site (mint and clear) in `motor_planner.gd`, `motor_explore_seek.gd`, and `creature_motor_stack.gd` sets it; every magnitude-based "is this set" read was replaced with a bool read, per the exit check above — final audit grep for `length_squared()` against the seven fields turned up only two hits, both genuine function-parameter gates (not `state` reads), left as-is per the scope decision to migrate `state[...]` dict fields only, not caller-supplied `Vector3` parameters.

Two latent instances of the exact sentinel-collision bug class were caught and fixed as a direct consequence of the migration, not designed in advance:
- `_GkReg.GK_AVOID_HOSTILES`'s direct `_flee_objective()` call in `_sync_step_objective` stored the function's `Vector3.ZERO` "no threat" sentinel into `step_goal` unconditionally — unlike `_mint_flee_waypoint`'s already-fixed path, this call site had no `_flee_has_visible_threat` guard. Now gated the same way.
- The 22-way flee-candidate scan's "no usable reach signal" fallback read `flee_waypoint` via `.get(..., Vector3.ZERO)` and treated a never-set waypoint (defaulting to the origin) as a real prior heading to steer by. Now gated on `flee_waypoint_set`.

The test suite (`tests/run_all.gd`) pokes these seven fields directly at ~60 call sites to build fixture states, bypassing production code entirely — every one of those needed the same companion-bool treatment (missing it silently made `align_and_move`/`select_action` etc. return `STAY` instead of acting, since the new guards read `false` by default). Full headless suite (`godot --headless -s res://tests/run_all.gd`) is green post-migration, matching the pre-migration baseline (0 assertion failures both runs).

**§7 — shared per-tick LoS/staleness subsystem — gaps closed (2026-08-31)**

*Classification pass complete.* There are **5-6 distinct per-tick "is X visible" samples** in the motor folder, all routing through the same raw primitive (`AwarenessZone.line_of_sight_clear` → `LineOfSight3D.occlusion_fraction`):

| # | Consumer | File | Checks LoS to | Hysteresis today? |
|---|---|---|---|---|
| 1 | Path clearance | `motor_path_clear.gd` | current `step_goal` | **Yes** — but lives in the *caller* (`motor_planner._latch_los_blocked`), not the LoS layer |
| 2 | Food-plant scan | `awareness_zone_scan.gd` | each candidate food plant | None |
| 3 | Prey/food-creature scan | `awareness_zone_scan.gd` | each candidate prey | None |
| 4 | Hostile-threat scan | `awareness_zone_scan.gd` | each candidate threat | None |
| 5 | Explore wedge probes | `motor_explore_seek.gd` (`_nav_clearance`) | synthetic bearing endpoints, not real objects | None (has unrelated spatial smoothing instead) |
| 6 | Ghost projection | `occluded_in_zone_ghost.gd` | remembered belief positions | A *different* mechanism — belief-ghost time-horizon fade, not tick-hysteresis |

The motivating bug (CLEANUP C11) is consumer #4: a threat near the awareness-cone edge "blinks in and out of `threat_samples` purely on facing," causing goal-hub flip-flop between `avoid_hostiles`/`find_food`. It's currently patched by consumer #6 (ghost projection) as a workaround — a parallel fix for the same disease this slice is meant to cure at the source. No C9/C16/RT1 references exist anywhere under `creature/motor/` — this bug class is specific to the awareness-scan/goal-hub interaction, not the flee-waypoint family.

*Subsystem location decided.* Extend `awareness_zone.gd` (it already owns the raw sampler `line_of_sight_clear`) rather than creating a new file — keeps the primitive and its cache together.

*Cache key decided.* `_latch_los_blocked`'s existing pattern (one bool + one streak counter per creature `state`) only works because path-clearance ever tracks *one* target at a time. Threat/food/prey scanning evaluates multiple candidates per tick, each needing its own independent hysteresis streak. The cache key must be **(creature, target instance_id)** — a dict of streaks keyed by instance_id — not a single latched bool. This is a real change from the existing pattern, not a drop-in reuse of `_latch_los_blocked`.

*Hysteresis tuning decided.* Reuse the existing default (`los_hysteresis_ticks` = 3) for threat-awareness rather than inventing a new default with no evidence behind it, but expose it under its own `motor_v3` key (not shared with path-clearance's) so it can diverge later without a second migration.

*Scope for this slice decided:* **narrow — threat scan only** (consumer #4). Build the shared per-target hysteresis cache in `awareness_zone.gd` and migrate only the hostile-threat scan, since it's the one with a confirmed bug and an existing workaround to eventually retire. Food/prey scanning (#2, #3) and explore-seek (#5) get the shared subsystem *available* but migrating their call sites is a follow-up slice, not blocking here. `occluded_in_zone_ghost.gd` (#6) stays in place, unmodified, until the new threat-hysteresis path is validated in headless and live testing — don't remove the workaround before its replacement is proven.

**Action:** implement the per-target hysteresis cache in `awareness_zone.gd` (dict keyed by target `instance_id`, same streak-counter shape as `_latch_los_blocked` but per-entry instead of singular), wire the hostile-threat scan in `awareness_zone_scan.gd` (`_scan_hostile_threats`) through it, add the new `motor_v3` tunable for threat-LoS hysteresis ticks, and headless/live-verify before considering `occluded_in_zone_ghost.gd` for removal or simplification.

**Implemented (2026-08-31).** `AwarenessZone.latch_awareness_verdict(cache, target_id, raw_aware, hysteresis_ticks) -> bool` added — same debounce shape as `_latch_los_blocked` (streak counter vs. `hysteresis_ticks`), keyed per target instead of singular. `AwarenessZoneScan.scan_live`/`_scan_hostile_threats` take a `threat_los_cache: Dictionary` parameter (default `{}`, so existing test call sites that don't pass one are unaffected — no hysteresis, same as before); the raw `in_awareness` verdict from `membership_with_los` is now latched through this cache before gating inclusion in `threat_samples`. Stale entries (targets not seen in a given scan) are pruned each call so the cache doesn't grow unbounded over a session. `creature_motor_stack._run_live_scan` threads the persistent cache through via the new `state["threat_los_hysteresis"]` field in `motor_planner.new_state()` (mirrors `los_blocked_latched`'s doc-comment cross-reference). New tunable `threat_awareness_hysteresis_ticks` (default 3, matching `los_hysteresis_ticks`) added to `game_config_merge.gd`'s V3 defaults, as its own key per the decision above (not shared with path-clearance's).

Scope held to the threat scan only, as decided — food/prey scanning and explore-seek were not touched, and `occluded_in_zone_ghost.gd` was left in place unmodified pending live validation of the new hysteresis path. Full headless suite (`run_all.gd`) is green post-migration (0 assertion failures), matching baseline.

**§4 — shared "stuck" abstraction**
- Depends on §5 (clean bool-based validity checks) and §7 (a stable LoS signal for pursuit-detour's `is_stuck`) landing first, per the sequencing above — if worked out of order, the callables get written twice.
- **Gap:** no decision on where the shared primitive lives (new file, e.g. `motor_stuck_latch.gd`, vs. a set of static helpers inside `motor_planner.gd`). Given §4/§5 already share files and fields, a new file may be cleaner to avoid further bloating `motor_planner.gd`.
- **Gap:** contract for the `is_stuck(state, motor_v3) -> bool` / `escalate(state, motor_v3, tier) -> Variant` callables isn't pinned down — Godot `Callable` objects bound per-goal, vs. a goal-kind enum dispatched via `match` inside the shared function. Callables are more flexible (goal code stays fully separate); a `match` is simpler to read/debug in this codebase's existing style. Worth picking one before writing the shared lifecycle function's signature.
- **Gap:** state-field naming after migration — replacing three different `*_ticks_remaining`/`*_escalation_count` pairs with one shared shape needs a naming convention (e.g. `<goal>_stuck_ticks_remaining`, `<goal>_stuck_tier`) so `state` dict contents stay debuggable per-goal at a glance, rather than colliding on a single generic key across goals.

**§1 — R1 executor-level continuous controller**
- Still has the open item from §3's audit: the pre-implementation review needs a concrete checklist of everything in `locomotion_executor.gd` and its direct callers/consumers the change touches (arrival damping, turn+move blending, anything reading a discrete per-tick `action` value) — that checklist doesn't exist yet, only the scope boundary (executor-level only) does.
- **Gap:** no regression/acceptance test plan stated yet for distinguishing "R1's fallback introduced a new bug class" from "R1's fallback fixed the old one" — given the user's explicitly stated worry ("my worry is that it will replace the existing class of bugs with a whole new class"), this slice should not start implementation until that test plan exists, not just the scope boundary.
- **Gap:** interaction with §4/§5 isn't fully specified — §4/§5 change what `flee_waypoint`/`pursuit_detour_waypoint`/`step_goal` look like (bool-gated validity) and how latches escalate, but §1 only consumes whatever discrete waypoint the planner hands it each tick. Worth an explicit one-line confirmation, once §4/§5 ship, that the executor's continuous-movement contract (turn+move blending toward a target) doesn't care *how* that target was chosen upstream — if it does care, §1's scope boundary needs revisiting.
