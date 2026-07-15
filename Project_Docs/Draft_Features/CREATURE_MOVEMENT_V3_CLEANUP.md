# CREATURE_MOVEMENT_V3 — Cleanup & implementation gaps

> **Role:** Design workspace for **bug fixes**, **playtest regressions**, and **implementation gaps** discovered after V3 phasing (§12) ships or during manual smoke. **Not** a replacement for [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md) — that file remains the authoritative motor contract; this file tracks **follow-on slices** that close the gap between spec intent and runtime behavior.
>
> **Authority:** Items here are **tier II draft** until promoted into V3 §12 (new sub-phase), merged into V3 body text, or closed as *won't fix*. Code changes ship with doc updates per [project-docs.mdc](../../.cursor/rules/project-docs.mdc).
>
> **Related:** [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md) (main spec), [tests/motor_path_fixture.gd](../../tests/motor_path_fixture.gd) (headless geometry), duel manual smoke (§12.2 / 14.2.7).

---

## How to use this file

| Field | Meaning |
|-------|---------|
| **ID** | `C#` — stable reference in commits / PRs |
| **Status** | `open` → `design` → `ready` → `in_progress` → `done` / `wont_fix` |
| **Slice** | Proposed V3 §12 tag when implementation is scheduled |
| **Evidence** | Log excerpt, playtest steps, or failing test name |

When an item is **done**, move acceptance criteria into V3 (or archive note) and set status `done` here with link to test / commit.

---

## Inventory

| ID | Title | Status | Slice |
|----|-------|--------|-------|
| [C1](#c1-pursuit-contact-geometry-stall-fox) | Pursuit contact geometry stall (fox) | `in_progress` — headless smoke green, duel manual (Pass 5) pending | `post-6d-approach-geometry` (shared) |
| [C2](#c2-locale-food-approach-oscillation-rabbit) | Locale food approach oscillation (rabbit) | `in_progress` — same-tick clamp fix shipped, headless smoke green, duel manual pending | `post-6d-approach-geometry` (shared) |
| [C3](#c3-prey-contact-without-eat--body-pin-stall-fox) | Prey contact without EAT / body-pin stall (fox) | `done` | `post-6d-prey-eat-contact` |
| [C4](#c4-stale-instance_id-lookups-crash-memory-adapter-diet-filter-headless-regression) | Stale `instance_id` lookups crash memory adapter diet filter (headless regression) | `done` | unassigned |
| [C5](#c5-stale-test-vs-6e-executor-refactor-contract-seek_wall_filter_and_backtrack) | Stale test vs 6e executor refactor contract (`_test_seek_wall_filter_and_backtrack`) | `done` | unassigned |
| [C6](#c6-newly-exposed-locale-consult-precedence-gap-memory_tier_precedence) | Newly exposed locale-consult precedence gap (`_test_creature_motor_stack_memory_tier_precedence`) | `done` | unassigned |

**Shared slice:** C1 and C2 are the same failure family — a **fixed `step_goal` with poor approach geometry** and **no progress escalation**. They ship in **one slice** (`post-6d-approach-geometry`) via a shared executor foundation, with goal-specific tails. See [Shared implementation plan (C1 + C2)](#shared-implementation-plan-c1--c2).

**C3** is a **separate** eat/contact failure (bodies jam without `EAT`) — do **not** schedule as Pass 4; see [C3](#c3-prey-contact-without-eat--body-pin-stall-fox).

---

## C1 — Pursuit contact geometry stall (fox)

**Status:** `in_progress`  
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
- [ ] Duel manual: fox clears an **interior pinch** and resumes chase (same session as rabbit flee / locale patch).
- [ ] No regression: post-6d Flight tests (A/B/C) and flee latch still pass.

### Open questions

_Resolved 2026-07-10:_ `pursuit_detour_latch_ticks` = **16** (mirror flee) for Pass 3 ship. _Resolved 2026-07-14 (C1 residual):_ sticky detour vs live remint plan locked; initial retune **32** (may move to **48**). §9 seek **stays available** for ghost-only prey. No open questions.

---

## C2 — Locale food approach oscillation (rabbit)

**Status:** `in_progress`  
**Slice:** `post-6d-approach-geometry` (shared with C1; herbivore memory-seek tail)  
**Evidence:** Duel playtest **2026-07-10** (session ~16:00) — after live bush seek at `(32.2, 65.0)`, rabbit hub retargets to **locale prior** `(26.0, 78.0)` at **t≈2201** (`src=locale`, `w≈0.294`). From **t≈2366** through session end (**t≈2617**): repeating **TURN_*** sweep → **`MOVE_F` with `err≈±137°`–`180°`** (`dot` negative) while `blk=0`, `cblk=0`, `ff=0`, `thr=0`. Log: `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` (rolling tail t=2218+) and `hunter_killer.log` (`MotorExplore` DEBUG lines).

**C2 residual (2026-07-14 ~10:34–10:35 UTC):** Pass 1–4 shipped, but duel still showed rabbit live bush `(32.2, 65)` → locale `(26, 78)` → **overshoot spin for hundreds of ticks** (`food=0`, 0 `EAT`, rear-hemisphere `MOVE_F`). Root cause: Layer 1 overshoot remint **reset** `locale_no_progress_ticks`, starving Layer 2 so §9 never fired while the orbit continued. **Design lock:** retain progress counters on overshoot remint — see [Response #3](#resolved--overshoot-guard-layer-1) (supersedes 2026-07-13 reset rule). Pass 4 empty-locale clear remains correct; progress retention is the Layer 2 escape hatch if orbit keeps the creature outside `eat_action_max_distance` or locale remints after clear. Verify sticky clear separately if remint-after-clear still observed.

**C2 residual #2 shipped (2026-07-14, same-tick clamp):** `_test_motor_locale_approach_no_oscillation_smoke` was still red after the progress-retention fix above — headless replay of the fixture and a fresh `motor_explore_tick.log` capture both showed the same rear-hemisphere flip (`err` jumping from ~`-19°` to `+154°` in one tick) at ranges the reactive Layer 1 remint (2-move-step close band, sub-meter at typical speeds) never reaches. Root cause: `LocomotionExecutor._displace_along_facing` moves the body via acceleration/friction (`apply_horizontal_move_intent`) and never checks remaining distance to `step_goal` — a single aligned `MOVE_FORWARD` can travel straight through a near anchor, flipping the bearing to the rear hemisphere before any next-tick remint has a chance to react. **Fix:** [`LocomotionExecutor.apply_action`](../../creature/motor/locomotion_executor.gd) now accepts an optional `step_goal` and, after a `MOVE_FORWARD`, `_clamp_overshoot_to_goal` snaps the body back onto the goal (and zeroes horizontal velocity) if displacement carried it past the goal along the pre-move approach line — same tick, before any bearing flip can occur. [`creature_motor_stack.tick`](../../creature/motor/creature_motor_stack.gd) threads `_planner_state.step_goal` through when the selected action is `MOVE_FORWARD`. This supersedes relying solely on the reactive Layer 1 remint (which still runs for the next-tick case where nav-substep resolution is needed after a real overshoot). Headless: `_test_motor_locale_approach_no_oscillation_smoke` green; full-suite diff against pre-change baseline shows **zero new failures** (only the two C6 asserts flipped green, same 13 pre-existing/unrelated failures remain).

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
- [ ] Headless: assert **no** `MOVE_F` **selected** when misaligned at `select_action` time (`|err| > turn_increment_deg` at decision time — not post-tick snapshot; see cone gate note).
- [ ] Duel manual: rabbit eats or leaves locale patch — no in-place spin at `(26, 78)`-class anchor after live food session.
- [x] No regression (headless): full-suite diff against pre-change baseline shows zero new failures. **Not yet re-verified in duel.**

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
| 2026-07-14 | **C2 residual #2 (same-tick overshoot clamp) shipped:** `_test_motor_locale_approach_no_oscillation_smoke` was still red after Response #3 (progress-counter retention) — a fresh `motor_explore_tick.log` capture showed the same rear-hemisphere flip (`err` jumping from ~`-19°` to `+154°` in one tick) inside `LocomotionExecutor._displace_along_facing`, at ranges beyond the reactive Layer 1 remint's sub-meter close band. `apply_action` now takes an optional `step_goal`; `_clamp_overshoot_to_goal` snaps the body back onto the goal (zeroing horizontal velocity) if the tick's displacement carried it past the goal along the pre-move approach line, same tick. `creature_motor_stack.tick` threads `_planner_state.step_goal` through on `MOVE_FORWARD`. Headless: `_test_motor_locale_approach_no_oscillation_smoke` green; full-suite diff vs. pre-change baseline shows zero new failures (`_test_motor_pursuit_pinch_detour_smoke` / C1 unaffected). Duel manual (Pass 5) still pending for both C1 and C2. |
