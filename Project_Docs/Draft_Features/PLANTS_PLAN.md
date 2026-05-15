# Hunter Killer — Plants / food (design doc, agent-friendly)

> **Authoritative implementation slice for hunger + bushes (shipped; archived spec):** [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md). This file tracks **plants/food** intent at a high level and stays aligned with [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) field names. **Asset layout:** all new plant-authored content lives under **`res://assets/plants/`** per [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) and [Completed_Features/ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md).

---

## 1. Phase summary

**Phase name:** Introduce plants / food

**One-line objective:** Stationary **food plants** (shrubs) that restore creature calories, with **hunger** driving risk and routing; see **HUNGER_AND_EATING** for numeric rules, two archetypes, mob intel stub, and HUD.

**Out of scope (explicit non-goals):** Mobs do **not** gain calories from plants (carnivore vs player per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md)). Full ecology (seeding, competition) stays in [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md).

**Related long-term design:** [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md). Creature vitals: [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md). Vision umbrella: [VISION_WORLD_BUILDER_PLAN.md](VISION_WORLD_BUILDER_PLAN.md).

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot **4.6.x** (match `project.godot`).

**Main scenes / entry:** `res://main.tscn` + `res://main.gd` (see [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §2).

**Key scripts (paths):**  
- `res://main.gd`, `res://player.gd`, `res://mob.gd`, `res://hud.gd`  
- Plant logic / scenes: **`res://assets/plants/`** — archetype folders **`solid_shrub/`** (Food A), **`open_shrub/`** (Food B); shared script **`res://assets/plants/bush_food.gd`** (see [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §5.2).

**Existing patterns to follow:** [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md), [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md).

---

## 3. Requirements

### Must have

- **Hunger / calories** — Creature **`current_calories`** bounded by **`caloric_needs`**; **time-based** passive loss (baseline rate **tunable** in play; see [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §3 for current numbers). **Not** “drain only while moving” as the long-term baseline.
- **Action cost (future)** — Additional calorie burn for **actions** (e.g. **running**, **fighting**) once those systems exist; rates TBD. This doc defers details to creature / combat plans when implemented.
- **Food plants** — Player can gain calories from authored plant instances under **`res://assets/plants/`**; starvation can end the round per HUNGER spec.
- **HUD** — Readable calorie / hunger feedback (polling / layout per HUNGER).

### Should have

- `pack_resources.json` under plant packs when audio/sprites are shared (per asset_management focus rule).

### Nice to have

- Eat SFX from pack manifests.

---

## 4. Technical design

### Architecture / data flow

- **Plants:** Standalone scenes under **`res://assets/plants/solid_shrub/`** and **`res://assets/plants/open_shrub/`** (see [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §5.2). Shared GDScript: **`res://assets/plants/bush_food.gd`** (keep all new plant paths under **`assets/plants/`**).
- **Who calls whom:** `Player` holds vitals; plants signal or are queried on overlap/collision; `Main` spawns plant instances and session-resets pools.

### Scene & file changes

| Action | Path | Notes |
|--------|------|--------|
| create | `res://assets/plants/…` | Bush scenes + textures per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §5.4 |
| create / modify | `res://assets/plants/bush_food.gd` | Shared calorie / regrowth / sprite swap |
| modify | `res://main.gd` | Instantiate plants; reset vitals |
| modify | `res://player.gd` | Vitals + drain + eat hooks |

### Collision / input / signals

- **Layer/mask (Food B):** Implement per [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6** (split); document any deviation in the same PR as `project.godot`.

### Dependencies

- [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md), [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md), [Completed_Features/ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md).

---

## 5. Implementation plan (ordered)

1. Shipped per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §6 (see `main.gd`, `player.gd`, `hud.gd`, `mob.gd`, `assets/plants/`).  
2. Reconcile any drift between this file and HUNGER after each milestone.

---

## 6. Acceptance criteria

- [ ] Plant art and scenes live under **`res://assets/plants/`** only (no new `res://plants/` root for authored plant content).  
- [ ] Calorie drain matches **time-based** baseline in HUNGER; movement-only drain is **not** the authoritative rule.  
- [ ] Cross-ref HUNGER for numeric constants and acceptance checklist.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Doc drift vs HUNGER | Single “implementation authority” sentence at top of §1 |

---

## 8. Testing / verification

**Manual:** Per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §9.

---

## 9. Open questions

- (none — defer to HUNGER `<<Question>>` markers)

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Linked PLANT_ECOLOGY, CREATURE_MODEL, VISION plans for forward-compatible fields. |
| 2026-05-14 | Retargeted to **Hunter Killer**; **time-based** hunger + future **action** costs; **`res://assets/plants/`** root; archetypes **`solid_shrub/`** / **`open_shrub/`**; **`bush_food.gd`**; Food B → ENV **§6** layer/mask split; HUNGER as implementation authority. |
| 2026-05-14 | **Implemented** hunger POC in code; spec moved to **`Completed_Features/HUNGER_AND_EATING.md`**. |
