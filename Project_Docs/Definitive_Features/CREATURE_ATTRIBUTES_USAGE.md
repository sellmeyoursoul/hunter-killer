# Creature stat pools — usage map (tier III)

> **Authoritative field names:** [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4 **Stat-based pools**.  
> **Conversion math:** [SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md) (`stat_to_point`).  
> **Motivation traits** (`explorer_builder`, …) are **not** stat pools — see [CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) §3.
>
> **Implementation snapshot (repo):** Stat baselines and `curr_point_*` / `max_point_*` pools are **not wired** in GDScript yet (`CreatureStats` / `stat_math.gd` remain future per model plan). Vitals that **are** live use `CreatureDefinition` + `creature_vitals_*` (`current_calories`, movement-cost multipliers, perception **scales**). This doc records **where Project_Docs say each stat pool should affect mechanics** once pools exist.

---

## 1. Pool refresh pipeline

| Step | Mechanism | Doc source |
|------|-----------|------------|
| Baseline | Integer `stat_*` per attribute (authoring / genetics) | [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4 |
| Max pool | `max_point_* = stat_to_point(stat_*)` (table 1…25 + extrapolation >25) | [SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md) |
| Current pool | `curr_point_*` usually set to `max_point_*` on spawn / rest; spent by actions | [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4 Methods; [EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC) §4.2 `generatePoints()` |
| Spend API (future) | e.g. `spend_fit(amount)` on `CreatureStats` | [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4 Architecture |

**EARLY_SPEC `generatePoints()` note:** Archived pseudocode chains `maxPointFit` to `statToPoint` inputs in a **typo-prone** way (`maxPointFit = statEndurance = statToPoint(currPointFit)`). Treat **each** `stat_*` as the input to `stat_to_point` for its own `max_point_*` unless a implementing phase explicitly revives a cross-stat formula and documents it in [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md).

---

## 2. Naming disambiguation (read before wiring)

| Term in docs/code | Meaning | Not the same as |
|-------------------|---------|-----------------|
| `curr_point_fit`, `stat_fit` | **Stat pool** — physical fitness / strength budget | `current_fit(tag)` in [CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) §5.1.4 — **modality applicability** for replay (0…1), unrelated to `stat_fit` |
| `creature_size` / `CreatureDefinition.creature_size` | Longest body dimension in **sim units** (px in 2D) | `stat_fit`; env `fit_size` (max body size that may **enter** a cell) |
| `fit_size` (environment) | Authoring gate for squeeze / shrub slowdown ([OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §3) | `stat_fit` pools |
| `estimated_squeeze_capability` | Skill-bounded **belief** about passing squeezes ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §7) | `stat_dexterity` or `stat_fit` — docs say “parameterized elsewhere; improves with progression” but **no stat pool link yet** |
| `awareness_radius`, `awareness_cone_*` (`creature_motor`) | Live **motor perception** disk + cone ([CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md) §4) | `stat_observation` pools — parallel concern; today scaled via `CreatureDefinition.perception_radius_scale` / `awareness_cone_half_angle_scale`, not observation points |
| “Observation” in memory TTL copy | Last **live sensory** contact with a remembered entity | Spending `curr_point_observ` |

---

## 3. Per-stat mechanical usage (from Project_Docs)

Status key: **Live** = affects shipped logic today via another field; **Specified** = another doc names a concrete behavior to hook; **Semantic only** = definition in model / EARLY_SPEC only; **Reserved** = no Project_Docs mechanic beyond catalog + conversion.

### 3.1 Fitness — `stat_fit`, `curr_point_fit`, `max_point_fit`

| Aspect | Detail |
|--------|--------|
| **Semantic** | General physical fitness / strength ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Future **`spend_fit`** API for exertion ([CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4). Indirect **future** coupling: **movement-based calorie burn** and **Preserve calories** locomotion thrift ([PLANTS_PLAN.md](../Draft_Features/PLANTS_PLAN.md) §3, [CREATURE_MOVEMENT_V2.md](../Draft_Features/CREATURE_MOVEMENT_V2.md) §A.3.1, [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md)) — docs cite vitals / `creature_motor`, **not** explicit `curr_point_fit` spend yet. |
| **Status** | **Semantic only** (+ reserved spend API). |
| **Related live fields** | `CreatureDefinition.calorie_movement_cost_multiplier`; base `speed` on bodies — **not** tied to `stat_fit` in docs. |

### 3.2 Endurance — `stat_endurance`, `curr_point_end`, `max_point_end`

| Aspect | Detail |
|--------|--------|
| **Semantic** | How much physical exertion before **fatigue** ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | **`generate_points()`** initializes endurance pools from `stat_to_point(stat_endurance)` ([SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md)). **Future HUD** lists **fatigue** beside damage as a polled vital ([HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §3). **Future** locomotion calorie costs ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §4 phasing, [PLANTS_PLAN.md](../Draft_Features/PLANTS_PLAN.md) §3). **Preserve calories** Tier-2 leaf: throttle sprint / costly detours when sated ([CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) §2, [CREATURE_MOVEMENT_V2.md](../Draft_Features/CREATURE_MOVEMENT_V2.md) §A.3.1) — **threshold bands on `calorie_ratio` today**, not endurance pool depletion. |
| **Status** | **Specified** (fatigue display + movement costs planned); pools **not wired**. |

### 3.3 Will — `stat_will`, `curr_point_will`, `max_point_will`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Push through exhaustion or injury via stubbornness ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_will)` on spawn ([SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md)). **No** Project_Docs file maps will spend to jeopardy, injury, or motor overrides yet. |
| **Status** | **Semantic only** / **Reserved**. |

### 3.4 Composure — `stat_composure`, `curr_point_comp`, `max_point_comp`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Keep clear judgment under stress ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_composure)` ([SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md)). **No** explicit link in active docs to **`jeopardy_forced_turn`**, flee panic, or **`scripted_intent_hold`** — those use fixed `creature_motor` ticks ([CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md) §5). |
| **Status** | **Semantic only** / **Reserved** (natural future hook: stress events under **Avoid hostiles**). |

### 3.5 Observation — `stat_observation`, `curr_point_observ`, `max_point_observ`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Observe the world and react effectively ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | **Direct (specified):** High-level movement replan interval **`n`** (physics ticks between awareness re-evaluation and goal reconsideration) **derived from the creature’s Observation attribute** — higher observation ⇒ **more frequent** replans ([post_los_movement.md](../Draft_Features/post_los_movement.md)). **Parallel (live stub, not pools):** Perception disk/cone via merged `awareness_radius`, `awareness_cone_extra`, `awareness_cone_half_angle_deg` ([CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md), [HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md](../Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md)); species **`perception_radius_scale`** / **`awareness_cone_half_angle_scale`** on [CreatureDefinition](../../creature/definition/creature_definition.gd) ([CREATURE_3D_ARCHITECTURE.md](../Draft_Features/CREATURE_3D_ARCHITECTURE.md)). **Evolution surface:** awareness motor genes ([CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](../Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md)) — genome tuning, not `curr_point_observ` spend. **Memory:** “observation” in TTL / forget policy = **live in-awareness contact**, not stat pool ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §5). **Future LoS:** occlusion reduces **effective awareness** ([ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md), [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §7.4) — docs do not yet tie to `stat_observation`. |
| **Status** | **Specified** for replan cadence ([post_los_movement.md](../Draft_Features/post_los_movement.md)); perception **Live** via motor keys + definition scales; **pools not wired**. |

### 3.6 Charm — `stat_charm`, `curr_point_charm`, `max_point_charm`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Convince others to assist ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_charm)` ([SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md)). **Social / multi-agent** systems deferred ([CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](../Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) — `compassion_self_interest`, `community_individual` reserved). **LLM conversation** scope does not reference charm stats ([AI_INT_CONVERSATION_SCOPE_PLAN.md](../Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md)). |
| **Status** | **Semantic only** / **Reserved**. |

### 3.7 Wit — `stat_wit`, `curr_point_wit`, `max_point_wit`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Fast thinking; unpredictability in conversation and combat ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_wit)` ([SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md)). **No** motor or memory doc ties wit to **`motor_intent_cost_chaos`**, jeopardy reaction, or dialogue — those remain **`creature_motor`** / AI-scope concerns without stat pools. |
| **Status** | **Semantic only** / **Reserved**. |

### 3.8 Dexterity — `stat_dexterity`, `curr_point_dex`, `max_point_dex`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Quick reflexes for action/reaction ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_dexterity)` ([SHARED_STATTOPOINT_PLAN.md](../Draft_Features/SHARED_STATTOPOINT_PLAN.md)). **Shelter / squeeze beliefs** use **`estimated_squeeze_capability`** (skill lane, not stat pool) ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §7). **No** doc maps dexterity to **`seek_direction_turn`** segment length, **`jeopardy_forced_turn_ticks`**, or physics reaction latency. |
| **Status** | **Semantic only** / **Reserved** (natural future hooks: squeeze skill progression, forced-turn responsiveness). |

---

## 4. Summary matrix

| Stat pool | Primary doc intent | Affects mechanics today? | Next documented hook |
|-----------|-------------------|--------------------------|----------------------|
| **Fitness** | Strength / exertion budget | No | `spend_fit`; movement calorie costs |
| **Endurance** | Fatigue before exhaustion | No (HUD fatigue **planned**) | Locomotion burn; Preserve-calories coupling |
| **Will** | Override exhaustion/injury | No | *(none named)* |
| **Composure** | Performance under stress | No | *(none named)* |
| **Observation** | Perceive + react | **Partial** (motor awareness keys + definition scales; **not** pools) | Replan interval **n** ([post_los_movement.md](../Draft_Features/post_los_movement.md)); future LoS |
| **Charm** | Persuasion / aid | No | Multi-agent / social phases |
| **Wit** | Unpredictability | No | Combat / conversation phases |
| **Dexterity** | Reflexes | No | Squeeze capability progression |

---

## 5. Related vitals (not stat pools)

These appear in the same [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) catalog but are **not** `stat_*` → `curr_point_*` pools:

| Field | Live / specified usage | Docs |
|-------|------------------------|------|
| `current_calories`, `caloric_needs`, derived hunger ratio | **Live** — drain, eating, motor Tier-2 bands, HUD | [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md), [CREATURE_MOVEMENT_V2.md](../Draft_Features/CREATURE_MOVEMENT_V2.md) §A.2.3 / §A.3.1, [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §10 |
| `speed` | **Live** — `creature_speed` in motor lookahead | [CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md) §4 |
| `size` / `creature_size` | **Live** — squeeze, shrub slowdown, motor `creature_size` | [OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md), [ENVIRONMENT_MODEL_PLAN.md](./ENVIRONMENT_MODEL_PLAN.md) |
| `weight` | **Reserved** — env `crush_weight` future | [ENVIRONMENT_MODEL_PLAN.md](./ENVIRONMENT_MODEL_PLAN.md) §4 |
| Motivation traits (−100…+100) | **Partial** — Tier-2 / replay modulation; not stat pools | [CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) |

---

## 6. Maintenance

- When a feature **wires** a stat pool into code, add a row to §3 with **file paths** and set **Status** to **Live**.
- Do **not** conflate **`current_fit(modality)`** with fitness stats in code or docs.
- Cross-stat formulas must be decided in [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) before implementation — do not inherit EARLY_SPEC typos silently.

---

## 7. Changelog

| Date | Change |
|------|--------|
| 2026-05-30 | Initial tier III map from Project_Docs review (model plan stat pools vs motor/memory/vitals). |
