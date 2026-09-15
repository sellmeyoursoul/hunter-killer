# Hunter Killer — Shared stat-to-point (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Shared stat → point pool conversion (`stat_to_point`)

**Status (2026-09-15, resolved):** Implemented at [`res://creature/stat_math.gd`](../../creature/stat_math.gd) (`StatMath.stat_to_point`), consumed so far only by `CreatureDefinition.max_point_comp()`/`max_point_observ()` (Composure and Observation stubs, [CREATURE_ATTRIBUTES_USAGE.md §3.4/§3.5](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)) — other stats' point pools remain unwired. The same file also gained `StatMath.peg_curve` (2026-09-15), a sibling function reusing this table's shape as a general three-peg curve (stat 1/10/25) for any stat-driven gameplay scalar, not just pool sizing — retired a single-anchor predecessor (`CreatureStatCurve.saturating`) that turned out to be a strictly weaker special case. See [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) for that migration (dexterity's turn-rate curve, and Composure/Observation's move off `saturating`).

**This doc's original scope (the lookup table + extrapolation rule) is fully implemented and tested — moved to `Completed_Features/`.** One item was out of this doc's scope and stays open: §9's UI stat-display cap question, tracked in [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) (no UI exists yet to answer it against).

**One-line objective:** Specify the **lookup table and extrapolation rule** that maps integer stat baselines (1–25 table, >25 asymptotic growth) to **max point pools** used by [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md).

**Out of scope (explicit non-goals):**  
- Balancing combat or economy numbers—this is a **mechanical** conversion spec.  
- Persisting derived pools across sessions (save format is a later phase).

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** N/A—pure utility.

**Key scripts (paths):**  
- Future: `res://creature/stat_math.gd` or static methods on `CreatureStats` companion.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)  
- Add **unit tests** when implementing (table boundaries, stat 26+, stat 1).

---

## 3. Requirements

### Must have

- Implementable restatement of original `statList` and `statNum > 25` loop in GDScript-friendly math.

### Should have

- Single public function: `stat_to_point(stat_num: int) -> float`.

### Nice to have

- Precomputed `PackedFloat32Array` constant for 1..25.

---

## 4. Technical design

### Architecture / data flow

- `generate_points()` in creature pipeline calls `stat_to_point` per stat to set `max_point_*` (and typically `curr_point_*` to full on spawn/rest rules).

### Lookup table (indices 1..25 → values; index `i` corresponds to `stat_num == i`)

Source list (preserve numeric values from EARLY_SPEC_DOC):

```text
[132.82, 158.62, 187.29, 219.15, 254.54, 293.87, 337.56, 386.11, 440.06, 500.00,
 559.94, 613.89, 662.44, 706.13, 745.46, 780.85, 812.71, 841.38, 867.18, 890.40,
 911.30, 930.11, 947.04, 962.28, 975.99]
```

**Convention:** In GDScript, use `stat_list[stat_num - 1]` when `1 <= stat_num <= 25`.

### Rule for `stat_num > 25`

Original pseudocode intent:

- Start `curr_points = 975.99`, `modifier = 13.71`, `diff = stat_num - 25`.  
- While `diff > 0`:  
  - `curr_points += modifier * 0.9`  
  - `modifier -= modifier * 0.1` (i.e. `modifier *= 0.9`)  
  - `diff -= 1`  
- Return `curr_points`.

<<Comment: Verify loop order matches design intent when coding; add test vectors for stat_num 26, 30, 40.>>

### Edge cases

| Input | Behavior |
|-------|----------|
| `stat_num < 1` | Resolved: clamps to 1 (`maxi(1, stat_num)`), no assert. |
| `stat_num > 25` | Extrapolation loop above |

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create | `res://creature/stat_math.gd` (example) | Static `stat_to_point` |

### Dependencies

- None external.

### Sibling function (2026-09-15, out of this doc's original scope but same file)

`StatMath.peg_curve(stat_num: int, v1: float, v10: float, v25: float) -> float` — reuses this table's own relative ratios (`T[10]/T[1]`, `T[25]/T[10]`) as a proportional remap onto three caller-pegged values, for any stat-driven gameplay scalar (not a point pool). Interpolates 2-9/11-24 using each stat's normalized position within the matching table segment; extrapolates 26+ with the same decaying-modifier technique as `stat_to_point`, scaled to the pegged range's own last increment. See [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) for the design discussion and worked examples (dexterity turn-rate; Composure/Observation migrated off `CreatureStatCurve.saturating`, now retired).

---

## 5. Implementation plan (ordered)

1. Implement `stat_to_point` with table + loop; **no gameplay wiring** required for first merge if tests pass.  
2. Call from `CreatureStats.generate_points()` when that Resource exists.

---

## 6. Acceptance criteria

- [x] Golden-value tests for stat 1, 25, 26, 30 match hand-calculated or reference spreadsheet — `_test_stat_math_stat_to_point_table_and_extrapolation`, `tests/run_all.gd`.  
- [x] Documented clamp policy for `stat_num < 1` — clamps to the stat-1 entry, see `stat_to_point`'s docstring.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Floating drift in loop | Use double accumulation or fixed iterations with documented tolerance in tests |

---

## 8. Testing / verification

**Automated (if any):**  
- Headless `tests/run_all.gd` or dedicated test script for stat table.

**Manual steps:**  
- None.

---

## 9. Open questions

- <<Question: Should stats cap at a max int (e.g. 99) for UI?>> **Deferred (2026-09-15), out of this doc's scope:** UI-only, no UI exists yet to answer it against — tracked in [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) "Other" table instead of blocking this doc's resolution.

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Formalized statToPoint from EARLY_SPEC_DOC into implementable spec. |
| 2026-09-12 | `stat_to_point` implemented at `res://creature/stat_math.gd`; wired to Composure's `max_point_comp()`. |
| 2026-09-15 | Wired to Observation's `max_point_observ()`. Added sibling `StatMath.peg_curve` (three-peg general stat curve, not point-pool specific) — migrated Composure's WAIT discount and Observation's prey-race giveaway off the now-retired `CreatureStatCurve.saturating`, and gave dexterity's turn-rate curve its implementation. §9's UI-cap question deferred to the backlog. **Doc resolved — moved to `Completed_Features/`.** See [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) for the full migration writeup. |
