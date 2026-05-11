# Dodge the Creeps — Design doc (agent-friendly)

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

**Repo / project root:** `{projectHome}/dodge-the-creeps`

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** Future `Creature`-like scenes or `Player` refactors; current game may only **subset** these fields (e.g. calories only in [PLANTS_PLAN.md](PLANTS_PLAN.md)).

**Key scripts (paths):**  
- TBD: e.g. `res://creature/creature_stats.gd` or `CreatureStats` Resource—**do not create until a phase explicitly references this plan**.  
- Existing: `player.gd`, `mob.gd` may gain **optional** exports that mirror a subset of names below.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)  
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
- **Motivation traits** (-100..100 sliders or 0..100—<<Question: pick one scale at implementation>>) influence **weights** in a future utility layer, not movement tokens from an LLM.

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

**Basic info**

| Field | Notes |
|-------|--------|
| `age`, `max_age` | Game days |
| `size` | Longest dimension (design units TBD: feet vs meters—<<Question: align with Godot px or abstract “tiles”?>>) |
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

### Methods (intent)

- **`generate_points()`** (internal): For each stat baseline, set `max_point_*` and usually `curr_point_*` via [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md). Original spec chained formulas; implementation doc should restate in GDScript-friendly steps when coding.  
- **`initialize_outlook()`** (internal): Seeds motivation sliders; **may live only on concrete species** if abstract `Creature` stays data-only.

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create (future) | `res://creature/...` | Only when a phase references this plan |

### Collision / input / signals (if relevant)

- Deferred until creature controller phase.

### Dependencies

- [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md)

---

## 5. Implementation plan (ordered)

1. Land [PLANTS_PLAN.md](PLANTS_PLAN.md) hunger on **player** using minimal overlap (`current_calories`, `caloric_needs` names if practical).  
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
| Unit mismatch (feet vs pixels) | Pick one internal unit in first implementation phase; document conversion at boundaries. |

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

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Extracted creature + vitals from EARLY_SPEC_DOC. |
