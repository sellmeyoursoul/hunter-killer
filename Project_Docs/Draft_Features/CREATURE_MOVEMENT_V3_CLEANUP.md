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
| [C1](#c1-pursuit-contact-geometry-stall-fox) | Pursuit contact geometry stall (fox) | `in_progress` | `post-6d-approach-geometry` (shared) |
| [C2](#c2-locale-food-approach-oscillation-rabbit) | Locale food approach oscillation (rabbit) | `in_progress` | `post-6d-approach-geometry` (shared) |
| [C3](#c3-prey-contact-without-eat--body-pin-stall-fox) | Prey contact without EAT / body-pin stall (fox) | `done` | `post-6d-prey-eat-contact` |

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

- [ ] Headless: [C1 smoke fixture](#smoke-test-engineering-complex-geometry) — fox reaches within `action_max_distance` of prey without `cblk` runaway or explore fallback while prey live.
- [ ] Headless: while `pursuit_detour_waypoint` latch is valid, per-tick live prey refresh updates `step_ultimate_pos` / engagement latch **without** overwriting detour `step_goal`.
- [ ] Headless: repeated blocks against an **active** detour mint a **fresh** detour (or alternate-side nav/backtrack) — **not** live substep overwrite and **not** explore-at-origin fallback while prey live.
- [ ] Duel manual: fox clears an **interior pinch** and resumes chase (same session as rabbit flee / locale patch).
- [ ] No regression: post-6d Flight tests (A/B/C) and flee latch still pass.

### Open questions

_Resolved 2026-07-10:_ `pursuit_detour_latch_ticks` = **16** (mirror flee) for Pass 3 ship. _Resolved 2026-07-14 (C1 residual):_ sticky detour vs live remint plan locked; initial retune **32** (may move to **48**). §9 seek **stays available** for ghost-only prey. No open questions.

---

## C2 — Locale food approach oscillation (rabbit)

**Status:** `design`  
**Slice:** `post-6d-approach-geometry` (shared with C1; herbivore memory-seek tail)  
**Evidence:** Duel playtest **2026-07-10** (session ~16:00) — after live bush seek at `(32.2, 65.0)`, rabbit hub retargets to **locale prior** `(26.0, 78.0)` at **t≈2201** (`src=locale`, `w≈0.294`). From **t≈2366** through session end (**t≈2617**): repeating **TURN_*** sweep → **`MOVE_F` with `err≈±137°`–`180°`** (`dot` negative) while `blk=0`, `cblk=0`, `ff=0`, `thr=0`. Log: `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` (rolling tail t=2218+) and `hunter_killer.log` (`MotorExplore` DEBUG lines).

**C2 residual (2026-07-14 ~10:34–10:35 UTC):** Pass 1–4 shipped, but duel still showed rabbit live bush `(32.2, 65)` → locale `(26, 78)` → **overshoot spin for hundreds of ticks** (`food=0`, 0 `EAT`, rear-hemisphere `MOVE_F`). Root cause: Layer 1 overshoot remint **reset** `locale_no_progress_ticks`, starving Layer 2 so §9 never fired while the orbit continued. **Design lock:** retain progress counters on overshoot remint — see [Response #3](#resolved--overshoot-guard-layer-1) (supersedes 2026-07-13 reset rule). Pass 4 empty-locale clear remains correct; progress retention is the Layer 2 escape hatch if orbit keeps the creature outside `eat_action_max_distance` or locale remints after clear. Verify sticky clear separately if remint-after-clear still observed.

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

- [ ] Headless: [C2 smoke fixture](#l1-fixture-layout-locale_orbit) — herbivore reaches within `action_max_distance` of seeded locale anchor without err sign-flip loop or `locale_no_progress_ticks` runaway.
- [ ] Headless: assert **no** `MOVE_F` **selected** when misaligned at `select_action` time (`|err| > turn_increment_deg` at decision time — not post-tick snapshot; see cone gate note).
- [ ] Duel manual: rabbit eats or leaves locale patch — no in-place spin at `(26, 78)`-class anchor after live food session.
- [ ] No regression: `_test_creature_motor_stack_seek_locale_prior`, `_test_motor_planner_latched_stuck_replan`, post-6d Flight A/B/C.

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

- **C1:** `pursuit_detour_waypoint` latch (`pursuit_detour_latch_ticks` — **16** shipped Pass 3; **32** initial target for [C1 residual follow-up](#follow-up-plan-locked--c1-residual-2026-07-14)); gate §9 seek while live prey visible (ghost-only prey keeps §9).
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

**C1 pursuit detour (Option A):** On blocked `MOVE_F` with live prey latch, copy post-`apply_immediate_blocked_path_reevaluation` `step_goal` into `pursuit_detour_waypoint` + hold `pursuit_detour_latch_ticks` (**16** shipped Pass 3). `step_ultimate_pos` = live prey ultimate. **C1 residual (2026-07-14):** latch must stay authoritative as `step_goal` through live ultimate refresh; remint rules + initial **32**-tick tune — see [Follow-up plan](#follow-up-plan-locked--c1-residual-2026-07-14).

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
