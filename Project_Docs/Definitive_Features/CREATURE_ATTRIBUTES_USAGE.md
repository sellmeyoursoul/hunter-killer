# Creature stat pools — usage map (tier III)

> **Authoritative field names:** [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4 **Stat-based pools**.  
> **Conversion math:** [SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md) (`stat_to_point`).  
> **Curve conventions (2026-09-15):** one curve for every stat-driven gameplay scalar — [`StatMath.peg_curve`](../../creature/stat_math.gd), pegged at stat 1/10/25 directly in the consumer's own units, same shape as point-pool sizing (huge 1-10 growth, moderate 11-25, diminishing-never-plateauing 26+). Used by Composure (§3.4), Observation (§3.5), and Dexterity (§3.8). Retired the same day: `CreatureStatCurve.saturating`, a single-anchor predecessor (one pinned value + implicit 0/1 asymptotes) that turned out to be a strictly weaker special case once every consumer just pegs three real values instead — see [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) for the migration.  
> **Motivation traits** (`explorer_builder`, …) are **not** stat pools — see [CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) §3.
>
> **Implementation snapshot (repo):** Stat baselines and `curr_point_*` / `max_point_*` pools are **not wired** in GDScript yet for most stats (`CreatureStats` remains future per model plan) — **except Composure** (§3.4) and **Observation's point-pool baseline** (§3.5), both stubbed 2026-09-12 for concealment-rest and the predator prey-race giveaway respectively. `stat_to_point` **is** implemented at [`res://creature/stat_math.gd`](../../creature/stat_math.gd), superseding the "future" note in [SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md). Vitals that **are** live use `CreatureDefinition` + `creature_vitals_*` (`current_calories`, movement-cost multipliers, perception **scales**). This doc records **where Project_Docs say each stat pool should affect mechanics** once pools exist.

---

## 1. Pool refresh pipeline

| Step | Mechanism | Doc source |
|------|-----------|------------|
| Baseline | Integer `stat_*` per attribute (authoring / genetics) | [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) §4 |
| Max pool | `max_point_* = stat_to_point(stat_*)` (table 1…25 + extrapolation >25) | [SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md) |
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
| **Documented mechanics** | **`generate_points()`** initializes endurance pools from `stat_to_point(stat_endurance)` ([SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md)). **Future HUD** lists **fatigue** beside damage as a polled vital ([HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) §3). **Future** locomotion calorie costs ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §4 phasing, [PLANTS_PLAN.md](../Draft_Features/PLANTS_PLAN.md) §3). **Preserve calories** Tier-2 leaf: throttle sprint / costly detours when sated ([CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) §2, [CREATURE_MOVEMENT_V2.md](../Draft_Features/CREATURE_MOVEMENT_V2.md) §A.3.1) — **threshold bands on `calorie_ratio` today**, not endurance pool depletion. |
| **Status** | **Specified** (fatigue display + movement costs planned); pools **not wired**. |

### 3.3 Will — `stat_will`, `curr_point_will`, `max_point_will`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Push through exhaustion or injury via stubbornness ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_will)` on spawn ([SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md)). **No** Project_Docs file maps will spend to jeopardy, injury, or motor overrides yet. |
| **Status** | **Semantic only** / **Reserved**. |

### 3.4 Composure — `stat_composure`, `curr_point_comp`, `max_point_comp`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Keep clear judgment under stress ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_composure)` ([SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md)) — **implemented**, [`res://creature/stat_math.gd`](../../creature/stat_math.gd). **Live (2026-09-12; curve migrated 2026-09-15):** `Action.WAIT`'s calorie discount ([CREATURE_MOVEMENT_V3.md §6.4](../Draft_Features/CREATURE_MOVEMENT_V3.md) concealment-rest) reads `stat_composure` through `StatMath.peg_curve` (pegged at stat 1/10/25 → 0.9353/0.625/0.5156, same file as the point-pool table), lerped by `curr_point_comp/max_point_comp` between the stat-1 peg (full-cost, pool spent) and the pegged value (pool full) for `wait_calorie_multiplier`. **Stub caveat:** `curr_point_comp` is always full — nothing spends composure yet, so only the stat-baseline half of the formula is currently live. **No** link yet to **`jeopardy_forced_turn`**, flee panic, or **`scripted_intent_hold`** — those still use fixed `creature_motor` ticks ([CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md) §5). |
| **Status** | **Live** (WAIT calorie discount, stat-baseline only) / **Reserved** (point-pool spend — natural future hook: stress events under **Avoid hostiles**). |

### 3.5 Observation — `stat_observation`, `curr_point_observ`, `max_point_observ`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Observe the world and react effectively ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | **Direct (specified):** High-level movement replan interval **`n`** (physics ticks between awareness re-evaluation and goal reconsideration) **derived from the creature’s Observation attribute** — higher observation ⇒ **more frequent** replans ([POST_LOS_MOVEMENT.md](../Draft_Features/POST_LOS_MOVEMENT.md)). **Parallel (live stub, not pools):** Perception disk/cone via merged `awareness_radius`, `awareness_cone_extra`, `awareness_cone_half_angle_deg` ([CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md), [HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md](../Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md)); species **`perception_radius_scale`** / **`awareness_cone_half_angle_scale`** on [CreatureDefinition](../../creature/definition/creature_definition.gd) ([CREATURE_3D_ARCHITECTURE.md](./CREATURE_3D_ARCHITECTURE.md)). **Evolution surface:** awareness motor genes ([CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](../Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md)) — genome tuning, not `curr_point_observ` spend. **Memory:** “observation” in TTL / forget policy = **live in-awareness contact**, not stat pool ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §5). **Future LoS:** occlusion reduces **effective awareness** ([ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md), [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §7.4) — docs do not yet tie to `stat_observation`. **Live (2026-09-12; curve migrated 2026-09-15):** predator prey-race giveaway ([CREATURE_MOVEMENT_V3.md §3 "prey-race giveaway"](../Draft_Features/CREATURE_MOVEMENT_V3.md)) — `stat_observation` scales `prey_race_giveup_ticks` via `StatMath.peg_curve` (pegged at stat 1/10/25 → 80.94/37.5/22.19 ticks), same mechanism as Composure's WAIT discount; higher observation recognizes an unwinnable live chase sooner. Same stub caveat as Composure: point pool always full, only the stat baseline is live. |
| **Status** | **Specified** for replan cadence ([POST_LOS_MOVEMENT.md](../Draft_Features/POST_LOS_MOVEMENT.md)); perception **Live** via motor keys + definition scales; **Live (partial)** for prey-race giveaway (stat baseline only); point pool not wired. |

### 3.6 Charm — `stat_charm`, `curr_point_charm`, `max_point_charm`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Convince others to assist ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_charm)` ([SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md)). **Social / multi-agent** systems deferred ([CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](../Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) — `compassion_self_interest`, `community_individual` reserved). **LLM conversation** scope does not reference charm stats ([AI_INT_CONVERSATION_SCOPE_PLAN.md](../Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md)). |
| **Status** | **Semantic only** / **Reserved**. |

### 3.7 Wit — `stat_wit`, `curr_point_wit`, `max_point_wit`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Fast thinking; unpredictability in conversation and combat ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_wit)` ([SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md)). **No** motor or memory doc ties wit to **`motor_intent_cost_chaos`**, jeopardy reaction, or dialogue — those remain **`creature_motor`** / AI-scope concerns without stat pools. |
| **Status** | **Semantic only** / **Reserved**. |

### 3.8 Dexterity — `stat_dexterity`, `curr_point_dex`, `max_point_dex`

| Aspect | Detail |
|--------|--------|
| **Semantic** | Quick reflexes for action/reaction ([EARLY_SPEC_DOC](../Completed_Features/EARLY_SPEC_DOC)). |
| **Documented mechanics** | Pool sizing via `stat_to_point(stat_dexterity)` ([SHARED_STATTOPOINT_PLAN.md](../Completed_Features/SHARED_STATTOPOINT_PLAN.md)). **Shelter / squeeze beliefs** use **`estimated_squeeze_capability`** (skill lane, not stat pool) ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §7). **Live (2026-09-15):** `stat_dexterity` drives per-creature turn rate via `creature_motor_stack.gd::_refresh_move_turn_rate` (`StatMath.peg_curve`, pegged at stat 1/10/25 → 183.7/691.6/1350.0 deg/sec) — unifies the continuous goal-directed turn law and boundary-scan/EAT-orbit's turn stepping onto one rate (`locomotion_executor.gd::_rotate_facing`/`_blend_turn_toward` both read `move_turn_rate_deg_per_sec`), replacing the two independently-fixed constants that existed before. 1350 preserved as the dex-25 ceiling (today's pre-existing live-tested default), not pushed faster. Same stub caveat as Composure/Observation: point pool always full, only the stat baseline is live. See [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) for the full derivation and implementation writeup. **No** doc maps dexterity to **`seek_direction_turn`** segment length or physics reaction latency beyond this; the dexterity↔`speed` trade-off (cornering vs. straight-line speed) is explicitly deferred, not yet wired. |
| **Status** | **Live** (turn-rate curve, stat-baseline only) / **Semantic only** / **Reserved** (remaining future hooks: squeeze skill progression, dexterity↔speed trade-off). |

---

## 4. Summary matrix

| Stat pool | Primary doc intent | Affects mechanics today? | Next documented hook |
|-----------|-------------------|--------------------------|----------------------|
| **Fitness** | Strength / exertion budget | No | `spend_fit`; movement calorie costs |
| **Endurance** | Fatigue before exhaustion | No (HUD fatigue **planned**) | Locomotion burn; Preserve-calories coupling |
| **Will** | Override exhaustion/injury | No | *(none named)* |
| **Composure** | Performance under stress | **Partial** (`Action.WAIT` calorie discount via stat baseline only — point pool always full) | Point-pool spend; stress events under Avoid hostiles |
| **Observation** | Perceive + react | **Partial** (motor awareness keys + definition scales; prey-race giveaway via stat baseline; **not** pools) | Replan interval **n** ([POST_LOS_MOVEMENT.md](../Draft_Features/POST_LOS_MOVEMENT.md)); future LoS |
| **Charm** | Persuasion / aid | No | Multi-agent / social phases |
| **Wit** | Unpredictability | No | Combat / conversation phases |
| **Dexterity** | Reflexes | **Partial** (turn rate via stat baseline; point pool always full) | Squeeze capability progression; dexterity↔speed trade-off ([CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md)) |

---

## 5. Related vitals (not stat pools)

These appear in the same [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) catalog but are **not** `stat_*` → `curr_point_*` pools:

| Field | Live / specified usage | Docs |
|-------|------------------------|------|
| `current_calories`, `caloric_needs`, derived hunger ratio | **Live** — drain, eating, motor Tier-2 bands, HUD | [HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md), [CREATURE_MOVEMENT_V2.md](../Draft_Features/CREATURE_MOVEMENT_V2.md) §A.2.3 / §A.3.1, [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §10 |
| `speed` | **Live** — `creature_speed` in motor lookahead | [CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md) §4 |
| `size` / `creature_size` | **Live** — squeeze, shrub slowdown, motor `creature_size` | [OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md), [ENVIRONMENT_MODEL_PLAN.md](./ENVIRONMENT_MODEL_PLAN.md) |
| `weight` | **Reserved** — env `crush_weight` future | [ENVIRONMENT_MODEL_PLAN.md](./ENVIRONMENT_MODEL_PLAN.md) §4 |
| Motivation traits (−100…+100) | **Partial** — Slot A/B replay; Tier-2 urgency stub | [CREATURE_TRAIT_USAGE.md](./CREATURE_TRAIT_USAGE.md), [CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) |

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
| 2026-09-12 | Composure §3.4 promoted to **Live** (partial): `stat_to_point` implemented (`stat_math.gd`); `Action.WAIT` concealment-rest calorie discount reads `stat_composure` via the new `CreatureStatCurve.saturating` curve. Point pool (`curr_point_comp`/`max_point_comp`) stubbed always-full — no spend mechanic yet. See [CREATURE_MOVEMENT_V3.md §6.4](../Draft_Features/CREATURE_MOVEMENT_V3.md). |
| 2026-09-12 | Observation §3.5 gains a **Live (partial)** consumer: predator prey-race giveaway — `stat_observation` (same stub shape as Composure, point pool always full) scales how many non-closing re-arm ticks a predator tolerates before excluding a live-but-unwinnable chase. See [CREATURE_MOVEMENT_V3.md §3](../Draft_Features/CREATURE_MOVEMENT_V3.md) "prey-race giveaway". |
| 2026-09-15 | Added top-level **Curve conventions** pointer (`CreatureStatCurve.saturating` default vs. `StatMath`'s multi-peg table technique). Dexterity §3.8 promoted to **Specified**: turn-rate curve pegged at dexterity 1/10/25 (183.7/691.6/1350.0 deg/sec), unifying goal-directed movement's continuous turn law with boundary-scan/eat-orbit's discrete stepping — implementation not started. See [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md). |
| 2026-09-15 | Curve conventions revised: single curve (`StatMath.peg_curve`) for all stat-driven scalars — `CreatureStatCurve.saturating` retired, Composure/Observation migrated. Dexterity §3.8 promoted to **Live**: turn-rate curve wired via `creature_motor_stack.gd::_refresh_move_turn_rate`, unifying goal-directed movement and boundary-scan/EAT-orbit onto one dexterity-derived rate. See [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](../Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) "Implemented" for the full writeup. |
