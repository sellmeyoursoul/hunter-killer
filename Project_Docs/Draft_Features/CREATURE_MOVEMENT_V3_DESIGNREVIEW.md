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
- **Gap — resolved:** new file `creature/motor/latch_hold.gd` (`LatchHold`), not static helpers inside `motor_planner.gd` — keeps the shared primitive out of the already-large planner file.
- **Gap — resolved:** neither `Callable` objects nor a `match`-dispatched enum. The shared primitive owns only mechanical lifecycle (`is_active`/`start`/`decrement`/`escalate`/`clear`, keyed by a string `prefix` param) and does **not** itself call goal-specific `is_stuck`/`escalate` logic — each consumer (`_maintain_flee_latch`, `_try_maintain_pursuit_detour_latch`, etc.) keeps its own existing function and calls into `LatchHold`'s static methods directly for the bookkeeping slice only. This sidesteps the Callable-vs-match choice entirely: goal-specific policy never crosses into the shared file at all.
- **Gap — resolved:** naming convention is `"<prefix>_ticks_remaining"` / `"<prefix>_escalation_tier"`, where `prefix` is the existing per-goal field stem (`flee_waypoint`, `pursuit_detour`) — preserves each consumer's existing field names (`flee_waypoint_ticks_remaining`, `pursuit_detour_ticks_remaining`) rather than a new generic key, so `state` dict contents stay debuggable per-goal. One pure rename: `pursuit_detour_escalation_count` → `pursuit_detour_escalation_tier` to match the primitive's field convention.
- **Scope, confirmed during implementation:** explore and boundary-scan are excluded — both are continuous progress-based re-eval / phase-machine shapes, not a poor fit for the hold/decrement/escalate/clear lifecycle the other two latches share. Confirmed R1 (§1, future continuous-controller slice) is orthogonal to explore's arrival-distance re-eval, and that the shared primitive is goal-agnostic movement/pathing-layer infrastructure that won't need to change for future Combat/ranged-combat goals (those would use a different step-objective notion; goal-specific policy stays outside the shell as designed).
- New tunable `pursuit_detour_max_escalations` (default `2`, in `game_config_merge.gd`) replaces what was a hardcoded `> 2` literal in `_remint_alternate_pursuit_detour` — the cap is load-bearing: it's the only safety valve against retrying forever on a visible-but-physically-unreachable live pursuit target.

**Implemented (2026-09-02), via 5 validated substeps:**
1. Contract + scaffolding (`latch_hold.gd`, no wiring).
2. Wire pursuit-detour (`_try_maintain_pursuit_detour_latch`/`_clear_pursuit_detour_latch`/`_maybe_mint_pursuit_detour_latch`/`_remint_alternate_pursuit_detour`), behavior-preserving.
3. Wire flee (`_maintain_flee_latch`/`_mint_flee_waypoint`/`clear_flee_waypoint_latch`), behavior-preserving.
4. Test-validity pass: audited all 7 flee-latch/pursuit-detour-latch tests in `tests/run_all.gd` — all read/write the exact `LatchHold`-owned keys, no references to the old `pursuit_detour_escalation_count` name survive, none were stale. No test edits needed. Noted but out of scope for this substep: no test drives `_remint_alternate_pursuit_detour` past `pursuit_detour_max_escalations` to hit the `gave_up` hard-clear branch — candidate for follow-up coverage, not required here.
5. Revisit "should quiet pursuit-detour expiry (ticks run out with no block) also escalate toward the cap, instead of resetting to tier 0?" — **investigated and closed as a no-op.** `_maybe_mint_pursuit_detour_latch` is called unconditionally at the end of every path-clearance tick while `step_source == "live"` and ready food is present (motor_planner.gd, end of `apply_immediate_blocked_path_reevaluation`'s caller chain), with no check for an already-active latch — so during a *sustained* live-food chase the pursuit-detour latch is continuously re-stamped (full ticks, tier reset) every tick rather than counting down. Quiet expiry (ticks actually reaching 0) can therefore only happen at a chase-episode boundary — prey eaten, lost from scan, engagement latch invalidated — where resetting the escalation tier for what is genuinely a new pursuit context is correct, not a bug. No repro or test evidence shows a loop via quiet expiry. Left unchanged.

Full headless `tests/run_all.gd` re-run after all 5 substeps: 0 assertion failures (same pre-existing `slot >= slot_max` noise as baseline).

### Slice candidates surfaced during §4 (not scoped, not started)

**Candidate A — herding / dead-end-driven pursuit targeting.** Dead-end recording is actively suppressed during live pursuit (`should_suppress_live_pursuit_blocked_resolution`), and no herding/dead-end-driven pursuit-targeting mechanism exists anywhere in the codebase. Flagged during §4's substep discussion, not written up further.

<<Question: Is herding/dead-end-driven pursuit targeting worth its own design pass now, or does it wait until a concrete gameplay need (e.g. pack-hunting AI) makes the shape of the mechanism clearer?>>

**Candidate B — learned pursuit-persistence (bandit over `pursuit_detour_max_escalations`).** Raised while closing out §4 substep 5: instead of a fixed `pursuit_detour_max_escalations` default, let each creature learn — per prey `stimulus_kind_id` — how much detour persistence pays off, so the population naturally converges toward "chase this kind of prey harder" or "give up sooner" based on actual outcomes, rather than one hand-tuned global constant.

The hard part is credit assignment: there's no way to observe the counterfactual of "would giving up early instead have been correct" for an attempt that was never made. The proposed shape sidesteps this by not trying to score the *decision*, only the *parameter value actually used*:

- **Existing infrastructure fits directly.** `KindProfileMemory` (`creature/motor/kind_profile_memory.gd`) already stores per-creature, per-`stimulus_kind_id` EWMA-learned facets from direct observation (e.g. `nutrition_yield` from EAT outcomes) — the same shape this needs, via `stimulus_learn_registry.gd`'s topic/facet registration.
- **Arms:** a small discrete set of `max_escalations` candidate values (e.g. 1/2/3/4), scored independently per `stimulus_kind_id`.
- **Selection:** epsilon-greedy — mostly pick the current best-scoring arm for that prey kind (exploit), occasionally sample another (explore) — this is the "try more, try less" variability.
- **Reward:** on episode resolution (EAT success, or the engagement/detour latch fully gives up), record one EWMA observation against the arm actually used for that episode — no inference about paths not taken.

<<Question: Is this worth scoping as a real slice, or is it premature relative to other open work (§1's continuous controller, Combat) — i.e. should it wait until there's a second or third learned-behavior use case to justify the shared bandit-over-`KindProfileMemory` machinery, rather than building it for one parameter first?>>

<<Question: What should the reward signal actually be — flat eat/no-eat, or discounted by ticks/energy spent per episode (so a long successful chase scores lower than a short one)? Getting this wrong risks the population converging toward "give up immediately" if giving up is cheap and eating is rare regardless of persistence.>>

<<Question: Does this want to be a per-creature learned trait (each individual's own EWMA, reset at birth) or a per-species/population trait (shared across all creatures of a kind, converging faster but losing individual variation)? Per-creature is more consistent with how `KindProfileMemory` already works; per-species would need new aggregation infrastructure.>>

<<Question: Scope boundary — does this replace `pursuit_detour_max_escalations` as a config default entirely, or does the config value stay as the *initial* prior each creature's learned bias starts from (config sets the seed, learning adjusts per-individual from there)? The latter avoids a flag day where existing tuning knowledge is discarded.>>

---

**§1 — R1 executor-level continuous controller**
- Still has the open item from §3's audit: the pre-implementation review needs a concrete checklist of everything in `locomotion_executor.gd` and its direct callers/consumers the change touches (arrival damping, turn+move blending, anything reading a discrete per-tick `action` value) — that checklist doesn't exist yet, only the scope boundary (executor-level only) does.
- **Gap:** no regression/acceptance test plan stated yet for distinguishing "R1's fallback introduced a new bug class" from "R1's fallback fixed the old one" — given the user's explicitly stated worry ("my worry is that it will replace the existing class of bugs with a whole new class"), this slice should not start implementation until that test plan exists, not just the scope boundary.
- **Gap:** interaction with §4/§5 isn't fully specified — §4/§5 change what `flee_waypoint`/`pursuit_detour_waypoint`/`step_goal` look like (bool-gated validity) and how latches escalate, but §1 only consumes whatever discrete waypoint the planner hands it each tick. Worth an explicit one-line confirmation, once §4/§5 ship, that the executor's continuous-movement contract (turn+move blending toward a target) doesn't care *how* that target was chosen upstream — if it does care, §1's scope boundary needs revisiting.

**Tunable-surface impact assessment (2026-09-02), pre-design.** Before designing the continuous controller itself, categorized every `locomotion_executor.gd`/`motor_planner.gd` tunable touching turn/move mechanics by how much a move away from one-discrete-action-per-tick actually affects it:

- **Bucket 1 — meaning changes, not just value (needs redesign):**
  - `turn_increment_deg` (22.5°) — today "rotation applied this tick"; under continuous blending this becomes an angular-rate limit (deg/sec), a unit change, not a retune.
  - `move_blend_max_error_deg` (60.0°) — today gates whether a `MOVE_FORWARD` may blend-turn before facing is close enough, with a presumed pure-`TURN_LEFT`/`TURN_RIGHT` tick as the fallback when it fails. If turn+move are always blended, both the gate and that fallback branch may be eliminated outright, not retuned.
  - `TURN_LEFT`/`TURN_RIGHT` as standalone [MotorAction]s — likely become vestigial for goal-directed movement (only meaningful for pure-orient behaviors like STAY-and-face) once movement is continuous.
  - `motor_stuck_move_epsilon` (1.25) — already cross-tuned against arrival damping's min-speed fraction per its own doc comment. Today a turn tick contributes ~0 displacement and a move tick contributes full-speed displacement (bimodal); once every tick blends some movement, "N consecutive ticks below epsilon" has a different statistical shape even at the same numeric value.
- **Bucket 2 — durations/counts, independent of action mechanics (expected to survive unchanged):** `predator_prey_visible_latch_ticks`, `predator_prey_engagement_latch_ticks(_min/_max)`, `flee_waypoint_latch_ticks`, `pursuit_detour_latch_ticks`, `flee_give_up_latch_ticks`, `los_hysteresis_ticks`, `threat_awareness_hysteresis_ticks` — all "hold this belief/target for N physics ticks," independent of how movement executes within that window; physics tick rate itself doesn't change.
- **Bucket 3 — ambiguous, magnitude may need retuning even though the mechanism survives:** `dead_end_record_min_blocked_ticks` (3) and the `consecutive_blocked` counter — `_is_move_blocked`'s collision-based detection is physics-outcome-based, not action-model-based, so it survives, but the count threshold was calibrated against the old cadence's bimodal progress-per-tick shape.
- **Expected no-op:** `approach_arrival_damping_radius` (2.5) — already a continuous linear taper (`_arrival_damping_frac`), the one tunable in the current file already shaped for a continuous controller.

**Sequencing:** pin down the continuous-controller model itself first (this is genuinely the largest open design question — see discussion), then stress-test that design back against this bucket list before finalizing the pre-implementation checklist and regression/acceptance test plan above.

**Continuous-controller model — pinned (2026-09-02).** Two independent continuous control laws evaluated every tick, replacing the discrete `TURN_LEFT`/`TURN_RIGHT`/`MOVE_FORWARD` alternation and the `move_blend_max_error_deg` hard gate:

- **Turn:** proportional toward heading error, capped at a max angular rate (deg/sec) — `turn_increment_deg`'s role changes from "rotation applied this tick" to a rate constant. Small errors settle in one tick instead of overshoot-correcting in fixed steps; large errors turn at the cap.
- **Forward speed:** `max_speed * max(0.0, cos(heading_error)) * arrival_damping(dist_to_goal)` — `cos(heading_error)` falls straight out of `dot(facing, direction_to_target)` (already computed for the turn law), so it needs no separate hand-tuned curve or threshold. Zero when the target is at/behind 90° off facing, full when directly ahead, tapering near arrival exactly as `_arrival_damping_frac` does today. `move_blend_max_error_deg` is eliminated as a gate, not retuned.

**Explicit design constraint:** forward speed floors at **zero**, it never goes negative. A target behind the creature means the executor turns in place (zero linear speed) until heading error drops enough for forward speed to become nonzero — it never backs into a target just because backward would technically reduce distance faster. Forward and backward must not become interchangeable/distance-minimizing-optimal choices of one symmetric law; backward stays a **separate, discretely-triggered decision** with its own weight (today's sole case: orbit-break after N facing revolutions in `_select_flight_action`/EAT-orbit logic), not a lane the continuous distance-minimization law can ever route through.

**Flagged as future work, not in §1's scope:** `MOVE_BACKWARD` currently uses the same `max_speed` and same calorie cost as `MOVE_FORWARD` (`locomotion_executor._displace_along_facing`, `motor_action.calorie_cost_for`) — no reverse-speed asymmetry exists in the code today, unlike what discussion assumed going in. Now that forward/backward are staying strictly separate decisions rather than symmetric options, there will be more cases where backing up is the right discrete choice (not just orbit-break) — those triggers, and whether backward should move at a different (likely slower) speed/cost than forward, are explicitly deferred to a future slice, alongside the already-deferred combat strafe/independent-facing work (`CREATURE_MOVEMENT_V3.md:2016`).

**Bucket re-audit against the pinned model (2026-09-02).** Re-checking every call site of the bucket-1 tunables against the pinned model (not just the tunable's default value) surfaces that `turn_increment_deg` is dual-purpose today, and the two purposes diverge under the new model:

- **Pure-orientation stepping** (`_boundary_scan_turn_budget`, `_pick_boundary_scan_sign`, `_pick_shorter_arc_turn_sign` — motor_planner.gd:492,557,577) — discrete turn-only behaviors (boundary scan's 360° look-around, turn-direction sign-picking heuristics) that never blend with movement and stay entirely out of §1's scope, same as boundary_scan was excluded from §4's latch abstraction. `turn_increment_deg` keeps its current literal per-tick-degree-step meaning here, unchanged.
- **Movement-blend gating** (`_is_within_move_blend_arc`, motor_planner.gd:2729-2732) — the actual `select_action` branch choosing `TURN_LEFT`/`TURN_RIGHT` vs. `MOVE_FORWARD` for goal-directed movement. Under the pinned model (forward speed floors at zero via `cos(heading_error)`, turning always blends into every move tick) **this branch collapses** — goal-directed movement no longer needs to choose between turn-only and move actions; a code-path elimination in the planner, not just a retuned gate constant in the executor.
- **Cascading from the gate's removal:** `force_align_turn_before_move` (motor_planner.gd:93, and set at 4 call sites to force one pure-turn tick after re-minting a detour/flee waypoint) becomes unnecessary — there's no more "forced pure-turn tick" once every move tick already blends in the needed turn.
- **Survives unchanged:** `_is_facing_aligned_for_move`/`_is_facing_aligned_with_tolerance`/`_move_alignment_min_dot` — per the code's own comment (motor_planner.gd:2739), LOS/path-clearance (`_run_path_clearance_los_nav`) uses this tight cone independently of action selection, so it's a separate consumer untouched by the movement-blend change.
- `motor_stuck_move_epsilon` — confirmed needs re-derivation (not removal): the bimodal zero-vs-full displacement shape it was tuned against goes away once every tick blends some movement.

Bucket 2 (duration/latch tunables) and bucket 3 (`dead_end_record_min_blocked_ticks`/`consecutive_blocked`) are confirmed as originally assessed — no new findings. `approach_arrival_damping_radius` confirmed as a no-op.

**Next:** `select_action`'s new shape, now that the goal-directed TURN-vs-MOVE branch is gone.

**`select_action`/`align_and_move` new shape (2026-09-02).** The collapse is localized — `select_action` (motor_planner.gd:126) itself barely changes: goal-hub arbitration, EAT/REST/STAY gating, `boundary_scan_action` dispatch, and `_select_eat_orbit_or_align` all stay exactly as-is (discrete decisions unrelated to travel movement, consistent with the "executor-level only" scope boundary already agreed for §1). Only the tail — `_locomote_toward_step_goal` → `align_and_move` (motor_planner.gd:2717-2732) — changes:

```
static func align_and_move(body, motor_v3, state) -> int:
  var step_goal: Vector3 = state.get("step_goal", Vector3.ZERO)
  if not bool(state.get("step_goal_set", false)):
    return _MotorAction.STAY
  state["dist_to_goal"] = _horizontal_distance(body, step_goal)   # unchanged, still needed for arrival damping
  return _MotorAction.MOVE_FORWARD                                 # no branch — executor blends turn+move every tick
```

Removed from this path:
- `force_align_turn_before_move` (motor_planner.gd:93, and set at 319, 389, 1792) — existed only to force a pure-turn tick after a re-mint; unnecessary once every move tick already blends in the needed turn.
- `_is_within_move_blend_arc` (the `move_blend_max_error_deg` gate) — folded into the executor's continuous `cos(heading_error)` speed law.
- The `_pick_align_turn_sign` calls at lines 2727/2731 — superseded by the executor's own signed cross/dot turn computation in `_blend_turn_toward`.

**Survives unchanged:** `_pick_align_turn_sign` itself — still called from `_select_eat_orbit_or_align` (motor_planner.gd:2540, EAT-range orbit-to-face-food) and boundary-scan sign-picking, both discrete pure-turn behaviors out of §1's scope for the same reason boundary_scan is.

**Second, independent reason bucket-3 thresholds need retuning:** `_tick_had_meaningful_progress` (motor_planner.gd:196) gates on `act != _MotorAction.MOVE_FORWARD → return false`. Today that's a real filter (a turn-only tick can never register progress). Once travel movement is always `MOVE_FORWARD`, the gate almost never trips for the travel path, so progress gets evaluated on every travel tick instead of only the minority of ticks that happened to land on `MOVE_FORWARD` in the old turn-then-move sequence — `dead_end_record_min_blocked_ticks`/`consecutive_blocked` will accumulate at a different rate than before, independent of the bimodal-displacement point already noted.

**Open thread:** the `force_align_turn_before_move` set-sites removed above (flee/pursuit-detour re-mint, motor_planner.gd:319, 389, 1792) currently exist to force a deliberate re-orientation after a waypoint changes materially — that intent doesn't disappear just because the flag's consumer does. Needs a replacement behavior under the continuous model (see next discussion).

**`force_align_turn_before_move` set-sites — resolved, no replacement needed (2026-09-02).** All three set-sites (motor_planner.gd:319 `_maybe_flag_material_step_goal_change`, :389 overshoot-remint, :1792 `_remint_alternate_pursuit_detour`) are the same pattern: "step_goal just jumped materially — don't lurch forward along the stale old heading, turn first." This dissolves for free under the continuous model rather than needing new logic:

`creature_motor_stack.gd:182-184` reads `step_goal` fresh from `_planner_state` and passes it as `move_turn_target` into `apply_action` the *same tick* it changed — there's no cached/stale heading state in the loop. Since forward speed is `max_speed * max(0, cos(heading_error)) * arrival_damping`, recomputed against whatever `step_goal` is *this* tick, the instant a waypoint re-mints somewhere very different, heading error is large that same tick and forward speed collapses toward zero with it — a near-pure-turn tick happens automatically, without a flag. The old flag existed only because the discrete model could compute a stale heading-aligned `MOVE_FORWARD` before the next tick's re-evaluation; the continuous model has no such staleness window since turn and move solve from the same fresh target every tick.

**Action:** delete all three set-sites outright (dead protection against a failure mode that no longer exists), not translate them to new logic.

**Caveat, needs one-line confirmation per site during implementation, not assumed:** this reasoning holds only because `move_turn_target` is threaded from the planner's fresh `step_goal` into the executor every tick already (existing wiring for R1 mitigation #2). If any of the three remint call sites set `step_goal` through a path that doesn't flow into that same-tick `move_turn_target` read, the "no staleness window" claim breaks for that specific site.

**Test plan (2026-09-02) — fills the standing "no regression/acceptance test plan" gap noted above.** Grepping `tests/run_all.gd` for the discrete-mechanics surface (`TURN_LEFT`/`TURN_RIGHT`, `align_and_move`, `force_align_turn_before_move`, `move_blend_max_error_deg`, `turn_increment_deg`) surfaces 60+ hits — this is a test-mechanism migration, not a values-only retune, so it needs planning up front rather than test-by-test discovery. Four categories, by what needs to happen to each:

1. **Executor unit tests asserting old discrete mechanics** (e.g. `_test_locomotion_executor_turn_facing`, `align_and_move`'s TURN-return assertions around motor_planner-test lines 3071-3103) — test behavior that no longer exists once `align_and_move` always returns `MOVE_FORWARD`. **Replace outright**, not retune.
2. **`force_align_turn_before_move` assertions** (lines 3103, 3136, 3793) — test a flag being deleted. **Delete these assertions** along with the flag.
3. **Simulation-loop scaffolding** — a recurring pattern (`if act == TURN_LEFT or act == TURN_RIGHT: apply_action(...) else: break`, driving the body through a simulated "spin via discrete TURN ticks until MOVE_FORWARD appears" loop) appears at ~10 distinct sites (lines 4069-4090, 4144-4155, 4217-4227, 4283-4318, 5055-5085, 5959-5980, 6043-6081, and others). The *outcome* most of these check (creature reaches the flee waypoint, pursuit-detour resolves, explore doesn't flip-flop) is usually still valid to want true — only the "spin N discrete ticks to align" mechanism driving it is obsolete. **Rewrite the scaffolding, keep the behavioral assertion** underneath where one exists.
4. **Config default/merge tests** (lines 760, 814-817, `turn_increment_deg`) — since `turn_increment_deg` survives unchanged for pure-orientation uses (boundary_scan, eat-orbit) and only gains a sibling rate tunable for the blended-move law, these likely need **no change**, pending confirmation once the new tunable's name is picked.

**New coverage needed** (nothing today exercises the continuous law itself): turn-rate cap correctness (deg/sec, not deg/tick); the `cos(heading_error)` forward-speed curve at sample angles (0°/45°/90°/135°); the zero-floor invariant (forward speed never goes negative, never substitutes for backward — directly enforces the "forward/backward must not become interchangeable" constraint from the pinned model above); composition with arrival damping; and a direct test of the `force_align_turn_before_move`-deletion claim — that a same-tick large waypoint re-mint produces near-zero forward speed rather than a stale-heading lurch.

**Implementation scoping (2026-09-02) — 7 validated substeps**, same pattern as §4's substep-validated approach:

1. **Add the new turn-rate tunable, scaffolding only, no wiring** — e.g. `move_turn_rate_deg_per_sec` in `game_config_merge.gd`, alongside `turn_increment_deg` (stays untouched for pure-orientation uses). No behavior change. **Implemented (2026-09-02):** added `move_turn_rate_deg_per_sec: 1350.0` to `default_creature_motor_v3_params()`, derived to match `turn_increment_deg`'s existing worst-case per-tick cap at the default 60Hz physics rate (22.5° / (1/60s) = 1350°/s) — not a new cap, so the continuous law's ceiling isn't a step change from today's. Matching default-value assertion added to `_test_creature_motor_v3_merge_defaults` in `tests/run_all.gd`. Full headless suite green (0 assertion failures, same baseline `slot >= slot_max` noise).
2. **Implement the continuous law inside `locomotion_executor.gd`, not wired in yet** — replace `_blend_turn_toward`'s fixed-increment clamp with the rate-based turn, and `_displace_along_facing`'s speed with the `cos(heading_error)` scaling, still called only from the existing `MOVE_FORWARD` path. Isolates "does the new law work" from "does removing the TURN/MOVE branch work" — existing executor unit tests should still mostly pass here since `align_and_move` hasn't changed what it emits yet. **Implemented (2026-09-02):** new `_move_turn_rate_rad(motor_v3)` reads `move_turn_rate_deg_per_sec`; `_blend_turn_toward` now takes `delta`, clamps the turn to `_move_turn_rate_rad * delta` (rate, not fixed step) instead of `_turn_increment_rad`, and returns the post-turn heading-alignment fraction `max(0, cos(heading_error))` (`1.0` when `target` is unset or already reached, preserving existing 4-arg/no-target call sites at full speed). `_displace_along_facing` gained an `align_frac: float = 1.0` param, multiplied into `damp_frac` alongside the existing arrival-damping fraction — so forward speed is now `arrival_damping * heading_alignment`, composing both continuous laws as designed. `apply_action`'s `MOVE_FORWARD` branch wires the two together (`align_frac := _blend_turn_toward(...)` fed into `_displace_along_facing`). `MOVE_BACKWARD`/`TURN_LEFT`/`TURN_RIGHT` untouched, per the backward-stays-separate constraint. Full headless suite green (0 assertion failures; the two `SCRIPT ERROR` lines present in the output were confirmed pre-existing on unmodified `main` via `git stash`, unrelated to this change).
3. **Collapse `align_and_move`** — remove `_is_within_move_blend_arc`, always return `MOVE_FORWARD` once `step_goal_set`. The actual behavior-changing cutover; everything before this step is prep, everything after depends on it. **Implemented (2026-09-02):** `align_and_move` (motor_planner.gd:2717) now returns `MOVE_FORWARD` unconditionally once `step_goal_set` (still returns `STAY` when unset, and still honors `force_align_turn_before_move` — deletion of that flag is substep 4). `_is_within_move_blend_arc` deleted; no remaining code references (confirmed via grep — only doc/cleanup-log mentions remain).

   **Result: 14 headless assertion failures, confirmed all attributable to this cutover** (`git stash` verified baseline is 0 failures both before this change and before substep 2's). Classified:
   - **11 directly assert the retired discrete-turn mechanics** — e.g. `"stack turns before moving toward precise goal"`, `"cone contract: misaligned goal selects TURN"`, `"flight close range: aligned MOVE_F within 12 ticks"` — tests asserting align-then-move as two phases, or driving a "spin via TURN ticks until MOVE_FORWARD" scaffolding loop (the category-1/3 breakage the test plan predicted). Deferred to substep 5 as scoped.
   - **3 failures don't assert anything about turning/movement on their face** — `"carnivore awareness scan ignores plants"`, `"prey entry carries prey instance_id"`, `"carnivore stack food_split ready empty near shrub"` (plain awareness-scan tests). **Investigated and confirmed (2026-09-02) via bisection** (temporarily disabling ranges of preceding tests and re-running, narrowed to a single call): the sole culprit is `_test_motor_planner_turn_alignment_no_flip_flop` (already one of the 11 category-1 failures above, tests/run_all.gd:4035), not a second/independent bug. That test's own loop (`for _i in 8: ... if act == MOVE_FORWARD: break`) previously needed ~8 iterations to converge from a 180° misalignment; under the new model it converges on iteration 1. That collapses how much engine time elapses before the test's `main.queue_free()` runs, shifting the timing window for later tests' own frame-await-then-scan pattern enough that a still-pending deferred free leaks a stray entry into a subsequent scan and swaps which body lands at `ready[0]` — exactly what `"prey entry carries prey instance_id"` catches. **Confirmed as a knock-on of the same root cause (tests built around "loop until MOVE_FORWARD" as an implicit timing budget, not a second failure mode)** — rewriting this test's scaffolding in substep 5 is expected to resolve all 3 as a side effect; re-verify after substep 5's rewrite rather than treating as separately fixed.
4. **Delete `force_align_turn_before_move`** — the field, its 3 set-sites, and its now-dead read in `align_and_move`. Its own substep (not bundled into 3) since it's an independently-verifiable removal per the "no staleness window" reasoning already documented above. **Implemented (2026-09-02):** removed the `new_state()` default, all 3 set-sites (overshoot-remint, `_maybe_flag_material_step_goal_change`'s call site, `_remint_alternate_pursuit_detour`), the reset-to-false site, and the `align_and_move` read/branch. Cascaded to remove the now-fully-dead machinery that existed solely to compute this flag: `_maybe_flag_material_step_goal_change` and `_is_continuous_objective_retarget` (deleted outright — confirmed via grep neither had any caller elsewhere in the codebase, both private to `motor_planner.gd`), and the `flag_material_change`/`body`/`motor_v3`/`delta` parameters threaded through `_assign_resolved_step_goal`, `_apply_live_food_objective`, and `_apply_locale_food_objective` purely to support it — all three simplified down to their actually-used parameters, and their now-redundant `if body != null: ... else: <duplicate state-set logic>` branches collapsed to a single unconditional call, across their combined 8 call sites. Confirmed via `--check-only` (clean parse) and full headless run.

   **Result: 17 headless assertion failures** (14 carried over + 3 new). The 3 new ones (`"overshoot remint arms turn-first flag"`, `"overshoot retain: remint still arms turn-first"`, `"alternate remint arms turn-first after detour jump"`) directly assert the now-deleted flag — expected category-2 breakage per the test plan. Also surfaced 3 `SCRIPT ERROR: Out of bounds get index '0'` lines — a downstream consequence of the same root cause, not a new failure mode: `_assert()` doesn't halt execution, so a test whose `turn_actions` array is now empty (no more TURN actions minted before MOVE_FORWARD) still runs an unguarded `turn_actions[0]` on the next line. All still trace to the same category-1/2/3 test breakage already catalogued; the 2 pre-existing baseline `SCRIPT ERROR`s remain separately confirmed unrelated (§1 substep 3 entry above).
5. **Test migration pass** — the 4-category rewrite from the test plan above (replace discrete-mechanics unit tests, delete `force_align_turn_before_move` assertions, rewrite the ~10 simulation-loop scaffolding sites, confirm config tests need no change) plus the new continuous-law coverage (turn-rate cap, cos-curve samples, zero-floor invariant, arrival-damping composition, same-tick re-mint lurch test).

   **Implemented (2026-09-02).** 12 tests rewritten across the 4 categories, plus 2 new tests added:
   - **Category 1/2 (discrete-mechanics assertions, retired flag):** `_test_motor_align_cone_contract` rewritten to assert the zero-floor invariant directly (180° target → `align_and_move` still returns `MOVE_FORWARD`, but that tick's displacement is near-zero and facing still rotates) instead of asserting a `TURN_LEFT`/`TURN_RIGHT` selection. `_test_motor_planner_fixed_objective_overshoot_remints`, `_test_motor_planner_overshoot_retains_locale_no_progress`, and `_test_motor_planner_pursuit_detour_alternate_on_persistent_block` had their `force_align_turn_before_move` assertions removed; the first two needed their fixture's `step_ultimate_pos` changed to a small offset from `step_goal` (previously identical, since `resolve_step_objective` returns `ultimate` unchanged with no navmesh) so the remint is still independently observable via `step_goal` actually re-targeting, rather than losing all coverage of "did the remint fire."
   - **Category 3 (simulation-loop scaffolding — ~6 tests):** `_test_motor_planner_turn_alignment_no_flip_flop`, `_test_creature_motor_stack_precise_turn_no_flip_flop`, `_test_motor_planner_explore_rear_hemisphere_no_flip_flop`, `_test_motor_planner_explore_post_scan_inward_align_no_flip_flop`, `_test_motor_planner_flight_close_range_forward_egress`, and `_test_motor_planner_flight_flee_waypoint_orbit_stable` all replaced the "spin via discrete TURN ticks until MOVE_FORWARD, then check no L/R flip-flop" loop with: assert `select_action` always returns `MOVE_FORWARD` once `step_goal_set`; feed the tick's `step_goal` as `move_turn_target` into `apply_action` (required for the executor to actually turn — the old TURN_LEFT/TURN_RIGHT actions turned unconditionally, MOVE_FORWARD only turns when given a target, a detail the first rewrite pass initially missed and had to fix per-test); assert facing-to-target alignment is non-decreasing tick over tick (flip-flop is structurally impossible now — `_blend_turn_toward` clamps to the exact signed correction needed, never overshoots) and converges within the tick budget. Kept each test's still-valid non-mechanics assertions (flee-latch stability, no-premature-replan, net displacement) unchanged.
   - **Category 4 (config tests):** confirmed no change needed, as predicted — `turn_increment_deg`'s default assertion is untouched.
   - **New coverage (2 tests added):** `_test_locomotion_executor_continuous_turn_rate_cap` (a single tick's turn is capped at `move_turn_rate_deg_per_sec * delta`, not a fixed step) and `_test_locomotion_executor_continuous_forward_speed_scales_with_alignment` (post-turn heading alignment strictly decreases at 0°/90°/180° samples, with 180° landing negative — the speed law's floor point). The latter measures **facing alignment directly, not raw displacement** — an initial attempt to assert on physical displacement magnitude was confounded by `apply_horizontal_move_intent`'s per-axis `move_toward` acceleration ramp, which (from a standing start) can transiently make a two-axis intent cover more ground than a single-axis one before velocity converges, unrelated to the actual turn/speed law being tested; measuring the alignment value the speed law is actually a function of avoids that confound entirely.

   Full headless suite green (0 assertion failures) after the full rewrite; the 2 pre-existing baseline `SCRIPT ERROR` lines (confirmed unrelated via `git stash` in substep 3) remain, unchanged in count.
6. **Bucket-3 retuning** — `dead_end_record_min_blocked_ticks`/`consecutive_blocked` and `motor_stuck_move_epsilon`, retuned against the new continuous progress-per-tick shape, headless suite as the feedback loop.

   **Implemented (2026-09-02).** Scoped the risk precisely before changing anything: `consecutive_blocked`'s general increment path (`move_stuck = executor_blocked or boundary_stuck`, motor_planner.gd) is purely collision/boundary-based — unaffected by the speed law change, since real wall contact doesn't care how movement is computed. The actual risk is isolated to **explore's `explore_idle_stuck` check**, the one place `no_progress` (raw per-tick displacement below `motor_stuck_move_epsilon`) feeds escalation directly — `precise`/`locale`/`memory_moving` don't have an equivalent displacement-based idle check.

   **Confirmed empirically, not just reasoned about:** instrumented `_test_motor_planner_explore_rear_hemisphere_no_flip_flop`'s 180°-misalignment scenario and found `consecutive_blocked` climbing to 2 out of the 3 needed to trigger a false stuck-replan — purely from slow-turning ticks (post-turn heading error still >~79°, where `cos(heading_error)` falls below the `motor_stuck_move_epsilon`-derived threshold) legitimately converging, not any real block. A near-miss, not just theoretical.

   **Fix:** added a `still_aligning` exemption to `explore_idle_stuck` (motor_planner.gd, `note_tick_completion`), mirroring the existing `still_ramping` exemption's "improving disqualifies" idiom — if facing-to-goal alignment improved since last tick, treat it as turning-in-place progress, not stuck. Peeks the already-existing `explore_last_facing_dot` field (written by `_note_explore_align_progress`, called later the same tick) rather than writing it — an earlier draft of this fix wrote the field itself and would have corrupted that function's own improving-vs-last-tick comparison (caught before landing, not after).

   **Result:** re-instrumented the same scenario post-fix — `consecutive_blocked` now caps at 1, never approaching the 3-tick threshold. Full headless suite green (0 assertion failures) with no config value changes — the mechanism needed a code-level exemption, not a retuned number. `dead_end_record_min_blocked_ticks` and `motor_stuck_move_epsilon` stay at their existing defaults.
7. **Acceptance** — the three-legged bar below.

**Live smoke-testing finding, found and fixed (2026-09-02) — not a §1 regression.** During live acceptance testing (leg 3, open-ended smoke testing), a rabbit froze motionless for **321 consecutive physics ticks (~5.3s)** in a playfield corner: `act=EAT` selected every tick, facing/position/target all identical the entire time, calories draining with no bite ever completing (`motor_explore_tick.log`, session 2026-09-02 19:03-19:04 UTC, t=2065→2385).

**Root cause, isolated precisely:** `_sync_food_memory_objective`'s coarse-belief-tier branch (motor_planner.gd, formerly lines 1935-1941) set `step_goal`/`step_goal_set`/`step_instance_id`/`step_source` but never touched `step_ultimate_pos`/`step_ultimate_pos_set` — unlike the precise/locale branches, which route through `_assign_resolved_step_goal` and set it explicitly. A stale `step_ultimate_pos` left over from a prior objective (e.g. an earlier precise/live target) persisted into the coarse tier. `_can_eat_now` resolves its actual target via `_resolve_eat_target_pos`, which prefers `step_ultimate_pos` over `step_goal` whenever set — so EAT's facing/range gates were evaluated against stale garbage instead of the current coarse bearing probe, passed incorrectly, and since EAT doesn't move or turn the body, the creature's position never changed, so the next tick's coarse consult produced the identical bearing again — a self-sustaining freeze.

**Confirmed unrelated to §1's continuous-controller work:** `EAT` bypasses `align_and_move`/the locomotion executor entirely (motion only happens via `MOVE_FORWARD`), so none of substeps 1-6's changes execute on this path at all. The coarse-tier branch's missing sync predates this session's work.

**Fix:** coarse branch now explicitly clears `step_ultimate_pos`/`step_ultimate_pos_set` (coarse has no real "ultimate" position, only a rough bearing probe, so clearing is correct — not a value to preserve). **Regression test added** (`_test_motor_planner_coarse_clears_stale_ultimate_pos`, tests/run_all.gd) — poisons `step_ultimate_pos_set` with a stale value before a coarse-only tick and asserts it's cleared; verified to genuinely fail without the fix and pass with it (not a tautology — an initial version of the test passed even with the bug reproduced, because `state["goal_kind"]` didn't match the incoming goal and `_sync_step_objective`'s own goal-switch reset silently cleared the poisoned field before the coarse branch was ever reached, masking the bug; fixed by seeding `state["goal_kind"]` to match, matching how a creature that's been on `find_food` for a while would actually arrive at this code path). Full headless suite green (0 assertion failures) with the fix in place.

**This is exactly what leg 3 of the acceptance bar (open-ended smoke testing) is for** — a genuinely new-to-this-testing-pass bug, not on the historical-repro checklist, caught by ordinary live play rather than a targeted test.

Steps 1-2 are additive/low-risk (no existing behavior changes). Step 3 is the one real cutover point.

**Acceptance bar — three legs, not headless alone.** The C9/RT1/C16/C17 bug family was found via live/duel repro, not the unit suite — headless-green does not by itself distinguish "introduced a new bug class" from "fixed the old one." Required before this slice is considered done:
1. **Headless suite green** post-migration (mechanical correctness — the 4 categories above pass, new coverage passes).
2. **Live re-runs of the specific historical repros** — C9's rabbit-stuck-at-playfield-boundary, the overshoot/orbit (C1-C5) family — re-executed live against the continuous controller, not assumed fixed by design reasoning alone.
3. **Smoke tests beyond the known repro list**, specifically aimed at surfacing bug classes this design pass hasn't anticipated — general live/duel play across a range of goal kinds (find_food live pursuit, flee, explore, shelter, rest) and playfield positions (open floor, corners, boundary hugging), not just the targeted historical-repro set, since a genuinely new failure mode by definition won't show up in a checklist built from the old model's known failures.
