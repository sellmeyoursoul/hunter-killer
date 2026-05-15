# Hunter Killer — Creature model (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Creature model (abstract data + vitals)

**One-line objective:** Define the **authoritative list** of creature-facing stats, motivation sliders, hunger, and reproduction fields so POC classes and future `Creature`-style nodes can **reserve** members without implementing every system at once.

**Out of scope (explicit non-goals):**  
- Full utility-AI or behavior-tree product in this phase.  
- Networking / persistence schema for MMO scale.  
- Using LLM output as the real-time movement controller ([VISION_WORLD_BUILDER_PLAN.md](VISION_WORLD_BUILDER_PLAN.md)).

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** Future `Creature`-like scenes or `Player` refactors; current game may only **subset** these fields (e.g. calories only in [PLANTS_PLAN.md](PLANTS_PLAN.md)).

**Key scripts (paths):**  
- TBD: e.g. `res://creature/creature_stats.gd` or `CreatureStats` Resource—**do not create until a phase explicitly references this plan**.  
- Existing: `player.gd`, `mob.gd` may gain **optional** exports that mirror a subset of names below.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)  
- Prefer **Resource** or **composition** for stats so `Player` and `Mob` do not duplicate large blocks of logic prematurely.

**Stat point math:** Centralize in [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md).

---

## 3. Requirements

### Must have (design completeness)

- Single table (below) listing **POC-used** vs **reserved-for-later** fields.  
- Document `generatePoints()` / `initializeOutlook()` intent even if methods are stubs.

### Should have

- Naming convention: `statX` (int baseline) + `currPointX` / `maxPointX` (float pools) aligned with original spec intent.

### Nice to have

- Example JSON or `.tres` snippet for a “rabbit archetype” for tests.

---

## 4. Technical design

### Architecture / data flow

- **CreatureStats** (or equivalent) Resource holds scalars; nodes (`Player`, `Mob`, future `NPC`) **own** a stats instance and read/write through small APIs (`spend_fit`, `tick_hunger`, etc.) as phases land.  
- **Motivation traits** (-100..100 sliders or 0..100—<<Question: pick one scale at implementation>>) influence **weights** in a future utility layer, not movement tokens from an LLM. For **heredity**, **evolution**, and **phased trait–motor coupling** (survival-only vs multi-motivation), see [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md).

### Field catalog (from world vision; typos in source corrected)

**Stat-based pools** (each: `stat*` int baseline; `currPoint*` / `maxPoint*` floats refreshed from `statToPoint`—see shared plan):

| Group | Fields |
|-------|--------|
| Fitness | `stat_fit`, `curr_point_fit`, `max_point_fit` |
| Endurance | `stat_endurance`, `curr_point_end`, `max_point_end` |
| Will | `stat_will`, `curr_point_will`, `max_point_will` |
| Composure | `stat_composure`, `curr_point_comp`, `max_point_comp` |
| Observation | `stat_observation`, `curr_point_observ`, `max_point_observ` |
| Charm | `stat_charm`, `curr_point_charm`, `max_point_charm` |
| Wit | `stat_wit`, `curr_point_wit`, `max_point_wit` |
| Dexterity | `stat_dexterity`, `curr_point_dex`, `max_point_dex` |

**Motivation traits (NPC / creature behavior drivers)**

| Field | Meaning (high vs low) |
|-------|------------------------|
| `explorer_builder` | Explore world vs improve “home” |
| `change_stability` | Seek novelty vs keep routine |
| `compassion_self_interest` | Others’ needs vs self-max |
| `community_individual` | Collective support vs self-reliance |

**Cross-reference:** Field names and scales are authoritative here; [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) defines how they participate in the **dual genome** (`creature_motor` + outlook) and when each trait may affect motor or fitness.

**Basic info**

| Field | Notes |
|-------|--------|
| `age`, `max_age` | Game days |
| `size` | Longest dimension in **internal simulation units** (Godot 2D is typically **pixels**; there is **no** built-in feet/meters). Define a project constant **pixels ↔ real length** (e.g. inches or cm) when gameplay needs physical feel. **Future:** user setting for **display-only** units (ft/in vs m/cm); core sim stays in pixels unless a later phase changes that. |
| `weight` | Unencumbered mass |
| `speed` | Base locomotion (abstract or px/s) |

**Hunger**

| Field | Notes |
|-------|--------|
| `caloric_needs` | Full satiety threshold |
| `current_calories` | <<Source had unnamed field; use `current_calories`>> |
| `hunger` | Optional derived: `current_calories / caloric_needs` or 1 - that ratio—define at implementation |

**Reproduction**

| Field | Notes |
|-------|--------|
| `reproduction_min_age`, `reproduction_max_age` | Game days |
| `gestation_length` | Game days |
| `gender` | Enum or char: `M` / `F` / `O` / other—prefer Godot enum in code |

**Display length units (future UX):** Expose **`size`** (and related fields) to players in **ft/in** or **m/cm** via a settings toggle; convert at UI boundaries from internal pixels (or chosen abstract unit). Do **not** block POC on this — implement internal floats first, document the conversion constant when a creature phase wires `size` to motion or UI.

### Methods (intent)

- **`generate_points()`** (internal): For each stat baseline, set `max_point_*` and usually `curr_point_*` via [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md). Original spec chained formulas; implementation doc should restate in GDScript-friendly steps when coding.  
- **`initialize_outlook()`** (internal): Seeds motivation sliders; **may live only on concrete species** if abstract `Creature` stays data-only.

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create (future) | `res://creature/...` | Only when a phase references this plan |

### Collision / input / signals (if relevant)

- Locomotion against terrain: **`CharacterBody2D`** / **`CharacterBody3D`** with **`move_and_slide()`** per [OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §5.1 — **do not** reimplement slide on **`Area2D`**.

### Dependencies

- [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md)  
- [OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) (§5.1 — `CharacterBody*D` + `move_and_slide` for creature locomotion)  
- [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) (motivation traits in evolution / motor stack)

---

## 5. Implementation plan (ordered)

1. Land hunger on **player** per [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) (and index [PLANTS_PLAN.md](PLANTS_PLAN.md)) using **`current_calories`**, **`caloric_needs`**.
2. Introduce `CreatureStats` Resource with **all fields @export default** for forward compatibility; wire only used fields.  
3. Migrate mob/player to shared Resource when second species needs the same vitals.

---

## 6. Acceptance criteria

- [ ] This doc’s field list matches intentional naming for code generation (snake_case for GDScript).  
- [ ] First implementing phase lists which rows are **active** vs **reserved**.  
- [ ] `generate_points` / `initialize_outlook` have a decided home (Resource vs subclass).

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Godot scene bloat from huge exports | Use nested Resource or Dictionary for rare fields. |
| Unit mismatch (feet vs pixels) | Sim uses **pixels** (typical Godot 2D); document a **pixels ↔ real length** constant when needed. **Future:** user-facing unit preference (ft/in vs m/cm) at UI only — see **Display length units** under §4. |

---

## 8. Testing / verification

**Manual steps:**  
- Inspect default Resource in editor when implemented.

**Automated (if any):**  
- Unit tests for `stat_to_point` in shared plan; creature tests when APIs exist.

---

## 9. Open questions

- <<Question: Single `gender` enum vs bitmask for future genetics?>>  
- <<Question: Should `hunger` be stored or always derived?>>
- **Control parity (deferred):** [OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2.5 applies interior env / exploration motor biases to **ENGINE**-controlled creatures only for that phase; **HUMAN** input does not get those nudges. Resolve whether **`ControlMode.AI`** (or any non-scripted motor) should match **ENGINE** weights when the **AI control** phase lands — document in the AI feature plan so scripted vs learned control stays consistent.

### Food-source memory (creature enhancement — draft)

**Goal:** Remember discovered food after it leaves the awareness cone — without omniscient seek.

| Tier | Condition (baseline) | Representation | Motor use |
|------|----------------------|----------------|-----------|
| **Precise** | Remembered bush/player-food and `distance(creature, last_world_pos) ≤ food_memory_precise_radius_px` (**1000** px default) | Exact `Vector2` + last-known ready/unready | Merge into `food_seek_targets` / unready lists ([`ai_driver.gd`](../../AI_int_lib/ai_driver.gd), [`cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd)) |
| **Coarse** | Still remembered but farther than precise radius | **Egocentric** 8-way sector recomputed each tick from `last_world_pos - creature_pos`: N, NE, E, SE, S, SW, W, NW | Weak cardinal bias or LLM/perception text — **not** a stored world compass bearing |

**Alternatives to weigh**

1. **Mob-style ghost buffer** — ring buffer + `awareness_memory_*` decay at last position (proven pattern in `ai_driver` `_mob_hist`).  
2. **Explore-trail-style grid** — cheap, but merges distinct bushes in one cell.  
3. **Precise-only** — no coarse tier; forget hard outside radius (simplest).

**Open design**

- <<Question: Coarse direction **changes as the creature moves** because sectors are relative to current position. Is that acceptable for ENGINE routing, or do we need map-fixed landmarks for “return to NW corner of map”?>>  
- <<Question: **Forget** — combine `food_memory_forget_radius_px`, `food_memory_ttl_sec` since last in-awareness observation, session reset, and LRU `food_memory_max_entries`?>>  
- <<Question: **Predator / moving food** — track prey `instance_id` + `velocity`; refresh every tick in awareness; extrapolate out of cone like mob ghosts; readiness ≠ bush regrow. Coarse 8-way is a weak cue for movers — prefer velocity bearing or precise tier only.>>  
- <<Comment: Stationary bushes — [`bush_food.gd`](../../assets/plants/bush_food.gd) `global_position` is stable; belief keys on instance id.>>

**Planned config keys** (commented in [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd)): `food_memory_precise_radius_px`, `food_memory_forget_radius_px`, `food_memory_ttl_sec`, `food_memory_max_entries`, `weight_seek_remembered_food`.

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-12 | §9: deferred **ENGINE vs AI** interior motor parity (OBJECT §8.2.5). |
| 2026-05-12 | §4 Collision: **`CharacterBody*D`** + **`move_and_slide`** per [OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §5.1; dependency link. |
| 2026-05-12 | `size`: internal **pixels**; no Godot ft/m; future **display** units (ft/in vs m/cm); **Display length units** note; §7 risk. |
| 2026-05-12 | Cross-link motivation traits ↔ [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) (§4, Dependencies). |
| 2026-05-11 | Extracted creature + vitals from EARLY_SPEC_DOC. |
