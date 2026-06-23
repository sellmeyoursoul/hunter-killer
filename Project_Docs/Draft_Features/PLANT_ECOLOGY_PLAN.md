# Hunter Killer — Plant ecology (world model, agent-friendly)

> **Authoritative asset layout for plant packs:** **`res://assets/plants/`** per [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) and [Completed_Features/ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md). **Shipped hunger + shrub POC** (field usage / rates): archived [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md); this doc defines **long-term** semantics and names—implementations should **reuse the same property names** where they overlap.

---

## 1. Phase summary

**Phase name:** Plant ecology (world model — beyond edible POC)

**One-line objective:** Capture the **full** abstract plant model (calories, regrowth, seeding, movement impedance, crush rules) from the world vision so [PLANTS_PLAN.md](PLANTS_PLAN.md) can stay a **high-level** plants/food index without losing long-term fields.

**Out of scope (explicit non-goals):**  
- Implementing every property in the first plant PR (follow [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) for the current shipped slice).  
- Full ecosystem simulation (competing species, soil moisture) until a dedicated ecology phase.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot **4.6.x** (match `project.godot`).

**Main scenes / entry:** Bush / plant scenes under **`res://assets/plants/`** per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md); instantiated from `main.gd` (or level loader).

**Key scripts (paths):**  
- Near term: [PLANTS_PLAN.md](PLANTS_PLAN.md), [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) (`main.gd`, `player.gd`, `hud.gd`, `mob.gd`, `assets/plants/…`).  
- Long term: optional `PlantSpecies` Resource holding the fields below.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)  
- [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md)  
- Forward-compat: **declare unused exports or Resource defaults** on plant scenes when cheap, so future saves/replicas carry data.

---

## 3. Requirements

### Must have (documentation)

- Property list below with types and one-line semantics.  
- `spread_seed` contract documented.

### Should have

- Explicit mapping: **POC (PLANTS_PLAN)** uses which subset.

### Nice to have

- Visual debug overlay for seed radius in editor.

---

## 4. Technical design

### Architecture / data flow

- **POC:** `Area2D` (or `StaticBody2D`) plant instance holds `current_calories` (pickup depletes or deletes); optional `max_calories` for HUD/debug.  
- **Future:** World tick calls `spread_seed` on mature plants; new instances spawn via `Main` or a `WorldSpawner` autoload.

### Property catalog (world vision; units TBD)

| Property | Type | Meaning |
|----------|------|---------|
| `edible` | bool | Creature **may** consume when rules allow; **Hunger POC** ties edibility to **`current_calories == max_calories`** ([HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md)). |
| `current_calories` | float | Available calories stored in the plant **right now**; consumers use this value. **Edible “ready” gate (Hunger phase):** no transfer until `current_calories == max_calories` (then burst depletes to 0 for that interaction—see [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md)). |
| `max_calories` | float | Cap for regrowth and **ready** threshold |
| `growth_rate` | float | **Long term:** calories restored **per unit time** toward `max_calories`, scaled by **plant type**, **biome / environment** (e.g. faster in rainforest than desert), and other world factors—**not** a single global constant in the vision. **POC / testing:** a fixed numeric rate (e.g. **+1 per second** in [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md)) is acceptable to unblock other features until species + env hooks exist. *(Legacy table text “per game day” referred to an older tick abstraction; replace with sim-time units when world days are defined.)* |
| `size` | float | Footprint (e.g. square feet or tile area—align with ENVIRONMENT plan) |
| `seed_spread` | float | Max distance from center a new seed can root |
| `seed_rate` | float | Game days between seeding attempts |
| `seed_cal_req` | float | Minimum `current_calories` on spread day to release seeds |
| `seed_choke_rate` | float | Rate at which this species displaces existing plants in target cell |
| `movement_impact` | float | % speed reduction for creatures passing through |
| `fit_size` | float | Creatures smaller than this bypass slowdown | 
<<Comment: Need to think about this. It should always be smaller than `size`, but is it a % or a defined number?>>
| `crush_weight` | float | Creature weight above this destroys plant (0 = indestructible by crush—clarify vs ENVIRONMENT) |
<<Comment: Need to define how plants absorb damage once combat lands. Do they have physical stats or some other method?>>

### Methods

- **`spread_seed(spread: float, curr_cals: float, req_cals: float)`** (internal): If `curr_cals < req_cals`, return. Else pick random offset with distance `< spread`, attempt spawn at computed location (validity rules TBD).

### POC subset (cross-ref [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md))

| In current hunger slice? | Fields |
|---------------------------|--------|
| Yes | `current_calories`, `max_calories`, regrowth via **`growth_rate`** (fixed +1/s for POC), burst grant when full, collision / overlap per Food A / B |
| Optional / soon | `edible` (implicit when full), HUD via creature vitals |
| Later | Per-species **`growth_rate`** modulation by environment; all `seed_*`, `movement_impact`, `fit_size`, `crush_weight` |

**Note:** There is **no** separate **`yield_calories`** in this catalog—**`current_calories`** is the live pool; **`max_calories`** is the cap and ready test. Do not introduce a second “yield” field unless a future mechanic needs it and this table is extended explicitly.

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| see | [PLANTS_PLAN.md](PLANTS_PLAN.md), [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) | POC under **`res://assets/plants/solid_shrub/`** and **`open_shrub/`**; physics [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6** |

### Collision / input / signals (if relevant)

- `body_entered` → transfer calories to `Player` / future `Creature`.  
- **Food B asymmetry:** [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6** (layer/mask split), not ad-hoc per-scene exceptions unless a future phase revisits.  
- Future: layer for “walkable underbrush” vs blocking beyond hunger POC.

### Dependencies

- [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) for passability / crush interaction edges.

---

## 5. Implementation plan (ordered)

1. **Done:** hunger + plant POC per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) with **PLANT_ECOLOGY** field names (`current_calories`, `max_calories`, `growth_rate`).  
2. Add `PlantData` Resource with **full** defaults; scene uses subset.  
3. Generalize regrowth tick (per-species / per-environment **`growth_rate`**).  
4. Implement `spread_seed` + competition (`seed_choke_rate`).

---

## 6. Acceptance criteria

- [ ] [PLANTS_PLAN.md](PLANTS_PLAN.md), [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md), and this doc agree on which plant fields are **live** in code for each release.  
- [ ] `spread_seed` pseudocode above reflected in real GDScript when phase starts.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Performance with many plants | Spatial hashing / chunk tick; cap seeds per frame |
| Unit confusion (feet vs px) | Document in ENVIRONMENT or global constants |

---

## 8. Testing / verification

**Manual steps:**  
- Grow/spread in a dev scene with fast-forward days.

**Automated (if any):**  
- Unit test `spread_seed` RNG bounds (deterministic seed).

---

## 9. Open questions

- <<Question: Per-plant RNG seed for reproducible worlds?>>  
- <<Question: Same `movement_impact` schema as Environment for shared code?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Split full plant ecology from EARLY_SPEC_DOC; linked PLANTS_PLAN POC. |
| 2026-05-14 | Hunter Killer paths; **`growth_rate`** long-term vs POC; **`assets/plants/solid_shrub/`** + **`open_shrub/`**; Food B collision → ENV **§6**; aligned eat rule with HUNGER; removed implied `yield_calories`. |
| 2026-05-14 | Hunger POC **shipped** in repo; cross-refs point at archived **HUNGER_AND_EATING**. |
