# Hunter Killer — Shared stat-to-point (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Shared stat → point pool conversion (`stat_to_point`)

**One-line objective:** Specify the **lookup table and extrapolation rule** that maps integer stat baselines (1–25 table, >25 asymptotic growth) to **max point pools** used by [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md).

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
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)  
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
| `stat_num < 1` | <<Question: clamp to 1, return 0, or assert in debug?> |
| `stat_num > 25` | Extrapolation loop above |

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create | `res://creature/stat_math.gd` (example) | Static `stat_to_point` |

### Dependencies

- None external.

---

## 5. Implementation plan (ordered)

1. Implement `stat_to_point` with table + loop; **no gameplay wiring** required for first merge if tests pass.  
2. Call from `CreatureStats.generate_points()` when that Resource exists.

---

## 6. Acceptance criteria

- [ ] Golden-value tests for stat 1, 25, 26, 30 match hand-calculated or reference spreadsheet.  
- [ ] Documented clamp policy for `stat_num < 1`.

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

- <<Question: Should stats cap at a max int (e.g. 99) for UI?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Formalized statToPoint from EARLY_SPEC_DOC into implementable spec. |
