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
| [C1](#c1-pursuit-contact-geometry-stall-fox) | Pursuit contact geometry stall (fox) | `design` | `post-6d-pursuit-contact` (proposed) |

---

## C1 — Pursuit contact geometry stall (fox)

**Status:** `design`  
**Slice:** `post-6d-pursuit-contact` (proposed; separate from post-6d Flight P2–P4)  
**Evidence:** Duel playtest **2026-07-10** — rabbit flee OK (`ff=1`, flee waypoint latch); fox closes on prey then **stalls** with repeated `MOVE_F` + `blk=1`, never `TURN_*` / `STAY`. Log: `%APPDATA%\Godot\app_userdata\Hunter Killer\logs\motor_explore_tick.log` (~t=3292+). `src=live`, `find_food`, prey id latched, `ff=0` (D1 correct — prey ≠ Flight threat).

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

1. **Gate §9 `seek`** while `prey_engagement_latch_valid` **and** live prey still visible — do not drop to explore-at-origin for one tick.
2. **Pursuit detour substep latch** — mint waypoint from navmesh first segment or backtrack candidate; hold for N ticks (config sibling to `flee_waypoint_latch_ticks`).
3. **Align after blocked reeval** — when `step_goal` changes and heading error exceeds §7.3.0 cone, prefer `TURN_*` over `MOVE_F` into blocked corridor.

### Acceptance (draft)

- [ ] Headless: [C1 smoke fixture](#smoke-test-engineering-complex-geometry) — fox reaches within `action_max_distance` of prey without `cblk` runaway or explore fallback while prey live.
- [ ] Duel manual: fox paths around center obstacle and resumes chase (same session as rabbit flee).
- [ ] No regression: post-6d Flight tests (A/B/C) and flee latch still pass.

### Open questions

- <<Question>> Config key name / default latch ticks for `pursuit_detour_latch_ticks` — mirror `flee_waypoint_latch_ticks` (16) or shorter?
- <<Question>> Should §9 seek remain available when prey is **ghost-only** (belief, no live LoS)?

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

## Changelog

| Date | Change |
|------|--------|
| 2026-07-10 | Created; C1 fox pursuit stall + L1 smoke design |
