# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Plant ecology (world model — beyond edible POC)

**One-line objective:** Capture the **full** abstract plant model (calories, regrowth, seeding, movement impedance, crush rules) from the world vision so [PLANTS_PLAN.md](PLANTS_PLAN.md) can stay a **minimal** “stationary food + starvation” slice without losing long-term fields.

**Out of scope (explicit non-goals):**  
- Implementing every property in the first plant PR (follow PLANTS_PLAN for POC scope).  
- Full ecosystem simulation (competing species, soil moisture) until a dedicated ecology phase.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/dodge-the-creeps`

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** `plant.gd` / `Plant` scene when implemented per PLANTS_PLAN.

**Key scripts (paths):**  
- Near term: [PLANTS_PLAN.md](PLANTS_PLAN.md) paths (`plant.gd`, `main.gd`, `hud.gd`, `player.gd`).  
- Long term: optional `PlantSpecies` Resource holding the fields below.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)  
- Forward-compat: **declare unused exports or Resource defaults** on `Plant` when cheap, so saves/replicas carry future data.

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
| `edible` | bool | Creature can consume |
| `current_calories` | float | Available calories for consumers |
| `max_calories` | float | Cap for regrowth |
| `growth_rate` | float | Calories restored per **game day** toward `max_calories` |
| `size` | float | Footprint (e.g. square feet or tile area—align with ENVIRONMENT plan) |
| `seed_spread` | float | Max distance from center a new seed can root |
| `seed_rate` | float | Game days between seeding attempts |
| `seed_cal_req` | float | Minimum `current_calories` on spread day to release seeds |
| `seed_choke_rate` | float | Rate at which this species displaces existing plants in target cell |
| `movement_impact` | float | % speed reduction for creatures passing through |
| `fit_size` | float | Creatures smaller than this bypass slowdown |
| `crush_weight` | float | Creature weight above this destroys plant (0 = indestructible by crush—clarify vs ENVIRONMENT) |

### Methods

- **`spread_seed(spread: float, curr_cals: float, req_cals: float)`** (internal): If `curr_cals < req_cals`, return. Else pick random offset with distance `< spread`, attempt spawn at computed location (validity rules TBD).

### POC subset (cross-ref PLANTS_PLAN)

| Used in PLANTS_PLAN first? | Fields |
|-----------------------------|--------|
| Yes | `edible`, `current_calories` (per-instance static after spawn), collision with player |
| Likely soon | `max_calories` (for bar / balance) |
| Later | `growth_rate`, all seed*, `movement_impact`, `fit_size`, `crush_weight` |

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| see | [PLANTS_PLAN.md](PLANTS_PLAN.md) | POC file table |

### Collision / input / signals (if relevant)

- `body_entered` → transfer calories to `Player` / future `Creature`.  
- Future: layer for “walkable underbrush” vs blocking.

### Dependencies

- [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) for passability / crush interaction edges.

---

## 5. Implementation plan (ordered)

1. Ship PLANTS_PLAN POC with minimal fields.  
2. Add `PlantData` Resource with **full** defaults; scene uses subset.  
3. Implement regrowth tick.  
4. Implement `spread_seed` + competition (`seed_choke_rate`).

---

## 6. Acceptance criteria

- [ ] PLANTS_PLAN and this doc agree on which plant fields are **live** in code for each release.  
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
