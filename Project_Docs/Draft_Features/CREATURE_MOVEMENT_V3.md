Purpose: Working spec for ENGINE creature movement and goal refactor (V3). **Authority:** supersedes V2 + POST_LOS; greenfield `creature/motor/` design. Sibling docs ([CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md), [CREATURE_MEMORY.md](CREATURE_MEMORY.md)) refactored separately — V3 defines the **planner interface** they must satisfy. **Sibling rework:** resolved checklists **§12.3** (apply at Step 3 / before **6d** close; **§13 Tracking**).

**Step 1 (2026-06-20):** Promoted to [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md); [CREATURE_MOVEMENT_V2.md](../Completed_Features/CREATURE_MOVEMENT_V2.md) + [POST_LOS_MOVEMENT.md](../Completed_Features/POST_LOS_MOVEMENT.md) archived with supersession banners; registered in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).

# Definitions

1. **Safety** — **State** (not an action): `safety_time` consecutive **goal-consideration cycles** (not physics ticks — §10) with no danger in the **full** zone of awareness (cone + area — §8.1; default `safety_time` = 5; tune in playtest). **Danger** = **live** hostile in zone (LoS clear) **or** valid **threat ghost** (§8.1). Required before the **`REST` action** may begin (§6.1). Pending Safety may therefore require up to **`safety_time × n`** physics ticks minimum (§6.1). **`safety_time` continues to advance during Flight fast-path** (§6.3, §10). When Safety state ends, **`REST` requirements are no longer met** — hub stops emitting `REST` each tick (§6.1, §7.2). Distinct from **`STAY`** (Definitions §5).
2. **Clear path** — LoS ray **and** capsule/corridor sweep both pass (see §3 Movement Weighing tree).
3. **Step** — A discrete sub-task toward an active goal (e.g. Eat: move past boulder → move to shrub → EAT). **Completion:** all objectives for the step are satisfied.
4. **Objective** — Exit criteria for the active step (world position or non-movement action target). **Completion:** creature reaches the position (within **`arrival_tolerance`**, same as **`action_max_distance`** when set — §7.2) or completes the bound action.
5. **Action** — One atomic unit per physics tick (`MOVE_*`, `TURN_*`, `EAT`, `REST`, `STAY`, etc.). **ENGINE** creatures emit at most **one** action per tick (see §7). Non-movement actions may carry **`action_max_distance`** (world units) — max range to bind target; **`null` / unset** = cannot interact at distance (§7.2). **`STAY`** — no movement, full awareness, baseline metabolism (§7.5); empty goal table (§10) or Rest pending Safety (§6.1). **`REST`** — deliberate recovery under Rest goal + §6.1 only; half baseline; cone off while selected (§8.1). Human-player input mapping is **deferred** — working cadence assumptions in §7.
6. **Cone of awareness** — Forward-facing **3D** observation cone from the eye ray origin (§8.1), limited by line of sight — no seeing through solids.
7. **Area of awareness** — **Spherical** observation radius around the creature (§8.1), limited by line of sight — no seeing through solids.
8. **Zone of awareness** — **Union** of cone of awareness + area of awareness (§8.1); both geometric membership **and** clear LoS required for **live** ingest. **Threat ghosts** (§8.1) extend remembered hostile presence when LoS-blocked but still in zone.
9. **Unexplored** — A coarse- or precise-tier region with no observed objects within **50%** of the area-of-awareness radius (world units).
10. **Default step chains (per goal)** — Eat: approach → consume; **Find shelter:** approach candidate → **STAY** evaluate (Safety + fit) → belief write (§6.4); Flight: reach shelter or flee position → hold until safe; Rest: reach candidate safe location → **STAY** until Safety state (§1) → **REST**; Mate/Fight: stub until those systems land.

---

## 1. Goal hub (hub-and-spoke)

Start with defining an active goal based on the following. Structure this in a hub-and-spoke design so that a **single entry function** can be called — future goals added without massive refactor.

| Goal | GoalKind Wire ID | Summary |
|------|------------------|---------|
| **Rest** | - | Recover at a safe site: **STAY** until Safety (§1), then **`REST` action** (§6.1). Sustained until another goal wins or Safety ends. |
| **Eat** | find_food | Replenish calories. |
| **Find shelter** | shelter | Proactively map bolt-holes / squeeze refuges (§6.4). Feeds Rest safe sites and Flight retreat options. |
| **Flight** | avoid_hostiles | Avoid sources of danger. **Consumes** `shelter` beliefs during flee (§6.3); does not replace Find shelter mapping. |
| **Mate** | find_mate | Produce the next generation. **Deferred** (§6.5). |
| **Fight** | Not Defined yet | Stub until combat is implemented (§6.6). |

NOTE: The evaluation should factor in goal urgency and ease of accomplishment (i.e. a creature with plentiful calories and an available mate might weigh reproduction over food, even if Eat would win out if no mate were present. Likewise, the same creature would ignore the mate if the calorie count were low.) **Mate-vs-Eat numerics deferred** until §6.5.

**Resolved — hub entry contract:** Single entry function on each creature’s **motor stack** (§1 below). **No explicit parameters** — reads **that** creature’s body, vitals, and world context via stack-owned refs. **Output:** one **action** for the current physics tick. Goal consideration (§10) and step decomposition run inside this pipeline on the Observation cadence.

**Resolved — per-creature motor stack (closes §14.2.5):** **One motor stack per [`CreatureRoot3D`](../../creature/creature_root_3d.gd)** — not a global singleton hub and not `ai_driver` `_…_by_body` dictionaries. Scales to N creatures with isolated state and consistent per-tick behavior.

| Artifact | Path | Role |
|----------|------|------|
| **Motor stack** | [`creature/motor/creature_motor_stack.gd`](../../creature/motor/creature_motor_stack.gd) (new) | Owns hub + planner runtime state + per-creature memory adapter delegate; **`tick() -> Action`** |
| **Owner** | [`creature/creature_root_3d.gd`](../../creature/creature_root_3d.gd) | Creates / holds stack child; wires `Body` + `Vitals` + `creature_motor_v3` at spawn |
| **Orchestrator** | [`AI_int_lib/ai_driver.gd`](../../AI_int_lib/ai_driver.gd) | Iterates registered roots; **`motor_stack.tick()`** per ENGINE subject — **no** motor state on driver |

**Stack owns (per creature):** `ActiveGoal` table + consideration cadence counters; planner ephemeral state; **`memory_adapter`** façade with that creature’s belief / locale / kind stores (replaces V2 `_goal_belief_by_body` on driver); Flight fast-path / Safety counters; `blocked_approach_memory` instance.

**Stack reads (refs, not copies):** `CreatureKinematicBody3D` facing/pos; vitals (`calorie_ratio`, …); merged **`creature_motor_v3`**; shared world services (`main_3d` navmesh RID, playfield, scene tree for zone scan).

**Hard rules:** Hub/planner **`tick()`** must not read another creature’s body or memory. Zone scan lists **other** creatures as threat/food samples only — never as the active subject. **6b** headless: dual-root fixture asserts distinct actions per stack same tick.

**Resolved — V3 goal ↔ `GoalKind`:** Wire through [`goal_kind_registry.gd`](../../creature/memory/goal_kind_registry.gd) per the table above. Rest has no salient `GoalKind` (preserve-calories behavior only). **Find shelter** uses wire id **`shelter`** ([GOAL_DRIVERS §4.1](CREATURE_GOAL_DRIVERS.md)). Flight uses **`avoid_hostiles`**; Mate uses **`find_mate`** when enabled. Salient writes use the active wire id at outcome.

**Resolved — goal scoring (architecture):** At each consideration cycle, each candidate goal computes `weight = effective_base × urgency × (feasibility_floor + feasibility) × trait_goal_mul`. **`effective_base`** = `goal_base_<wire_id>` for most goals; **Find shelter** uses §1 shelter base formula. **`feasibility_floor`** = per-goal `goal_feasibility_floor_<wire_id>` from `creature_motor_v3` (§1). Urgency is continuous 0…1 from vitals/threat proximity. Feasibility is 0…1 from best available target/step (live > precise > coarse > seek-only). **`trait_goal_mul`** — v1 **1.0** (§1 trait stub). Hard overrides: `calorie_ratio < starvation_override_food_ceiling` forces Eat-only eligibility (§1 eligibility matrix); acute Flight fast-path (§10) suppresses normal consideration — **Find shelter excluded entirely** during acute threat. **`replay_weight`** applies at **planner / memory consult** (§6d, §9) — **not** on hub `weight` in v1. **Single control plane:** hub **`build_eligible_goals`** (§1) decides which rows enter the table; **winner = max `weight`** among eligible rows. Memory salient-write **`parent_tier2`** comes from **`parent_tier2_for_goal_kind(winner.goal_kind)`** — **not** from [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd).

**Resolved — `find_food` feasibility tiers (hub consult via memory adapter — ship v1):** Planner consult precedence matches feasibility ordering. Constants live on [`memory_adapter.gd`](../../creature/motor/memory_adapter.gd) (`FEASIBILITY_*`); tune in playtest if hub winners feel wrong.

| Signal | `find_food` feasibility | Planner `step_source` when incumbent |
|--------|-------------------------|--------------------------------------|
| Live ready food in awareness | **1.0** | `live` |
| Precise instance belief (§8.2) | **0.75** | `precise` |
| Coarse bearing only (§8.3) | **0.45** | `coarse` |
| Locale prior / hotspot (§9 tactic layer) | **0.25** | `locale` |
| None (generic explore) | **0.0** | `explore` |

**Resolved — per-goal `base` (`creature_motor_v3`):** Temperament multiplier (typical range **0…2**; ship profile uses **~0.5–1.0**). **Not** V2 `weight_seek_*` cardinal keys. Species packs may override.

| Hub goal | Config key | Ship default |
|----------|------------|--------------|
| Eat | `goal_base_find_food` | **1.0** |
| Flight | `goal_base_avoid_hostiles` | **1.0** |
| Rest | `goal_base_rest` | **0.85** |
| Find shelter | `goal_base_shelter` | **0.5** |
| Mate | `goal_base_find_mate` | **0.0** (disabled until §6.5) |

**Resolved — Find shelter effective base:**

```text
effective_base_shelter = goal_base_shelter × food_map_confidence
```

**Resolved — `food_map_confidence`:** `∈ [0, 1]` — how well the creature knows **nearby food**. Take the **best** of: live ready food in zone of awareness; precise/coarse **`find_food`** instance belief within `goal_memory_forget_radius`; strongest **`find_food`** locale-prior `stored_strength` within `believed_goal_hotspot_near_radius_px` ([CREATURE_MEMORY.md §10](CREATURE_MEMORY.md)). Low confidence ⇒ shelter mapping deprioritized (focus food first); high confidence ⇒ full `goal_base_shelter` applies. Tunable blend weights — **deferred** (v1: `max` of signals).

**Resolved — Find shelter eligibility (consideration):** Candidate enters the goal table only when **`calorie_ratio ≥ seek_priority_food_ceiling`** (default **0.80** — same key as Eat urgency bands; tune in playtest). **Not** eligible under starvation override band (Eat dominates). **Fully suppressed** during acute threat / Flight fast-path (§6.3, §10) — no parallel Find shelter row competes with flee.

**Resolved — Find shelter vs Flight:** Proactive **mapping** (Find shelter) vs reactive **flee** (Flight). When Flight runs, **nearby believed `shelter`** rows (instance + locale) **bias flee objectives** — prefer retreat toward known bolt-holes when fit estimates pass ([CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)). Find shelter does not run during fast-path; it **produces** beliefs Flight **consumes**.

**Resolved — `feasibility_floor`:** Use a **small epsilon** (not zero) so seek-only goals remain on the table when no target exists (`feasibility = 0` still yields non-zero weight). Per-goal keys under `creature_motor_v3`: **`goal_feasibility_floor_<wire_id>`** (same naming pattern as `goal_base_*`). Ship default **0.05** for all wired goals unless a pack overrides — tune in playtest.

| Hub goal | Config key | Ship default |
|----------|------------|--------------|
| Eat | `goal_feasibility_floor_find_food` | **0.05** |
| Flight | `goal_feasibility_floor_avoid_hostiles` | **0.05** |
| Rest | `goal_feasibility_floor_rest` | **0.05** |
| Find shelter | `goal_feasibility_floor_shelter` | **0.05** |
| Mate | `goal_feasibility_floor_find_mate` | **0.05** (inactive until §6.5) |

**Resolved — Eat urgency (calorie bands):** Adopt V2 numerics into **`creature_motor_v3`** (retune in playtest if needed):

| Key | Ship default | Role |
|-----|--------------|------|
| `preserve_bias_food_floor` | **0.90** | At/above: Eat urgency → **0** (preserve band) |
| `seek_priority_food_ceiling` | **0.80** | Below: Eat urgency → **1** (full seek) |
| `preserve_seek_blend_smoothness` | **0.5** | Mid-band **0.80–0.90** smoothstep aggressiveness |
| `starvation_override_food_ceiling` | **0.10** | Below: Eat hard-dominates acute threat |

**Eat urgency curve:** `urgency_eat = 1.0` when `calorie_ratio < seek_priority_food_ceiling` or under starvation override; `0.0` when `calorie_ratio ≥ preserve_bias_food_floor`; else smoothstep blend between ceilings using `preserve_seek_blend_smoothness` (same shape as V2 `preserve_find_food_seek_scale`, inverted for urgency — [CREATURE_MOVEMENT_V2.md §A.3.1](CREATURE_MOVEMENT_V2.md)). Implemented in the V3 hub module; **not** delegated to `tier2_dominance.gd`.

**Resolved — Flight urgency (`gate_dist` + disposition):**

```text
kind_threat(sample) = kind_profile.facet(threat_danger, sample.stimulus_kind_id)  // species_id for mobs; neutral 0.5 if unseen
urgency_flight = clamp(urgency_dist × kind_threat × threat_disposition_mod × relative_threat_mod, 0.0, 1.0)
```

**Resolved — kind threat (not familiarity):** Rank by **learned danger per stimulus type** — if experience says lions are scarier than wolves, **lion beats wolf** even when the wolf individual was seen more often. **Not** “known individual beats unknown.” Unseen kind uses **neutral prior** (**0.5**); **`unknown_kind_multiplier`** = **1.0** in v1. **`threat_disposition_mod`** always factors in (creature-global skittishness — §1 table).

**Geometry (`urgency_dist`) — per nearest in-zone threat sample** (footprint **`gate_dist`** from [`threat_sample.gd`](../../creature/motor/threat_sample.gd) / awareness ingest; **`max`** over samples):

```text
eff_reach   = effective awareness reach to that threat (sphere ∪ forward 3D cone — §8.1; LoS-clear only)
area_radius = area-of-awareness radius (inner sphere; `creature_motor_v3.awareness_radius` unless pack overrides)
t           = clamp((eff_reach - gate_dist) / max(flight_urgency_dist_floor, eff_reach - area_radius), 0, 1)
urgency_dist = lerp(flight_urgency_far_floor, 1.0, t)
```

| Anchor | `gate_dist` | `urgency_dist` |
|--------|-------------|----------------|
| Far edge of zone (`eff_reach`) | ≈ `eff_reach` | **`flight_urgency_far_floor`** (default **0.5**) — Flight competes but does not fully override other goals |
| Area-of-awareness boundary | ≈ `area_radius` | **1.0** — flee / fight (when combat lands) treated as unavoidable |
| Inside area sphere | `< area_radius` | **1.0** (clamped) |

Curve is **scale-invariant**: `eff_reach` and `area_radius` come from the same awareness geometry as threat ingest — widening cone/sphere moves eligibility and urgency ramp together.

**Creature-global disposition (`threat_disposition_mod`) — not locale-prior rows:** Per-creature **confidence / skittishness** scalar (not `LocalePriorMap` / grid-cell memory). General temperament toward threat — **not** spatial (“this boulder” / “this shrub”). Hub reads at consideration; **§12.2 6b** stubs **`1.0`** until **6d** wires read/write.

| Event (v1 contract) | Disposition nudge |
|---------------------|-------------------|
| **Benign exposure** — threat `in_awareness`, sub-panic (`urgency_dist < 1`), no fast-path / flee episode, threat departs cleanly | **Decrease** skittishness (less motivated to run next time) |
| **Hunt / evade** — `tactic_jeopardy_egress`, Flight fast-path, or successful escape episode | **Increase** skittishness |

Clamp **`threat_disposition_mod`** to **`[flight_disposition_mod_min, flight_disposition_mod_max]`** (ship defaults **0.4…1.2**). Step sizes — tune in playtest (`flight_disposition_benign_delta`, `flight_disposition_evade_delta` under `creature_motor_v3`).

**Relative threat (`relative_threat_mod`) — deferred combat (§6.6):** Opponent matchup (e.g. healthy lion vs hungry fox) may drive mod → **0** even when `urgency_dist = 1`. **V3 v1:** **`1.0`** stub. Health / wounds may feed this term when combat lands — may **zero out** Flight for non-threatening opponents regardless of geometry.

**Acute / fast-path (unchanged):** `gate_dist ≤ flight_acute_panic_radius` (§1 keys), `tactic_jeopardy_egress`, or §10 acute signal still triggers **Flight fast-path** — does not replace the consideration curve for sub-acute band competition.

**`creature_motor_v3` keys (geometry + disposition clamps):**

| Key | Ship default | Role |
|-----|--------------|------|
| `flight_urgency_far_floor` | **0.5** | `urgency_dist` at far awareness edge |
| `flight_urgency_area_radius` | alias **`awareness_radius`** (`creature_motor_v3`) | Inner sphere → `urgency_dist` **1.0** |
| `flight_urgency_dist_floor` | **1.0** | `eps` for normalization denominator (world units) |
| `flight_disposition_mod_min` | **0.4** | Floor on `threat_disposition_mod` |
| `flight_disposition_mod_max` | **1.2** | Ceiling on `threat_disposition_mod` |
| `flight_disposition_benign_delta` | TBD playtest | Per benign-exposure nudge (sign negative) |
| `flight_disposition_evade_delta` | TBD playtest | Per hunt/evade nudge (sign positive) |
| `flight_acute_panic_radius` | **220.0** | Acute Flight fast-path when threat `gate_dist ≤` this (world units; V2 parity: `herbivore_flee_panic_radius` from duel rabbit pack) |

**Implementation phasing:** **6b** — `urgency_dist` + `threat_disposition_mod = 1.0` + `relative_threat_mod = 1.0`. **6d** — persist / update per-creature disposition on benign vs evade events (motor meta or memory adapter field — not `LocalePriorMap`). **Combat** — `relative_threat_mod` + Fight hub reuse of `urgency_dist` geometry (§6.6).

**Resolved — Rest urgency and competition:** **`REST` action** still requires calories **≥ 95%** (§6.1). In the **80–95%** calorie band, **Rest loses** to competing goals (Eat when food is available, Find shelter when eligible, etc.) — no special Rest urgency curve in v1. **90–95% ecology:** Eat **`urgency_eat → 0`** at `calorie_ratio ≥ preserve_bias_food_floor` (**0.90**); Rest is **not on the table** until **≥ 95%**; Find shelter may still compete when **`calorie_ratio ≥ seek_priority_food_ceiling`** (**0.80**). If **no goal wins** consideration (no viable targets / all suppressed), hub emits **`STAY`** (§7.2) — not an error state. Future combat / wound vitals will feed Rest urgency when those systems land (§6.1 deferred healing).

**Resolved — Mate vs Eat tradeoff:** Goal **Deferred** until §6.5. **No Mate-vs-Eat numerics** in V3 v1 — `goal_base_find_mate` remains **0.0**; explicit tradeoff formula ships with the mating goal.

**Resolved — single control plane (hub eligibility; deprecate `tier2_dominance.gd`):** Closes §14.1.2 / §14.4.2. **Do not** call [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd) from the V3 hub. **Deprecate and delete** that module at **§12.2 6b** (with V2 `ai_driver` motor teardown) — its ~50-line if-ladder is **inlined** as explicit per-goal eligibility in the hub module. **Keep** [`goal_kind_registry.gd`](../../creature/memory/goal_kind_registry.gd) **`parent_tier2`** as memory **taxonomy** ([CREATURE_GOAL_DRIVERS.md §4.1](CREATURE_GOAL_DRIVERS.md)) — derive at outcome from the **winning hub goal**, not from `derive_dominant_tier2_leaf`. **Keep** the [CREATURE_GOAL_DRIVERS.md §2](CREATURE_GOAL_DRIVERS.md) motivation tree as **semantic** priority documentation only.

**Practical recommendation (adopted):**

1. **Hub owns eligibility + scoring** — one pipeline; no dual control with a parallel dominance module.
2. **Keep `parent_tier2` in `goal_kind_registry`** — salient writes and memory consult use `parent_tier2_for_goal_kind(active_winner.goal_kind, catalog)`.
3. **Ship in 6b** — do not build a hub + `tier2_dominance` wrapper and delete later.
4. **Port parity tests** — starvation-over-acute and preserve-band cases from `tests/run_all.gd` tier2 assertions to hub eligibility + `urgency_eat` tests at 6b.

**V3 role (narrower than V2):** Goal **winner** = **max `weight`** among **eligible** hub rows on the **consideration cadence** (§10) — **not** per-tick `derive_dominant_tier2_leaf` ([POST_LOS_MOVEMENT.md §4.5b](POST_LOS_MOVEMENT.md)). Sub-acute threat uses continuous **`urgency_flight`** (§1), not tier2’s boolean `acute_threat`. Acute response uses **Flight fast-path** (§10), which bypasses the goal table entirely.

**Consideration pipeline (6b):**

| Step | Owner | Action |
|------|-------|--------|
| 1 | §10 fast-path | If acute Flight (or future combat fast-path) → bypass table; emit flee actions |
| 2 | Hub | `build_eligible_goals(...)` → candidate hub rows (matrix below) |
| 3 | Hub | Score each eligible row: `weight = effective_base × urgency × (feasibility_floor + feasibility) × trait_goal_mul` |
| 4 | Hub | Winner = max weight (§10 tie-break) |
| 5 | Memory adapter (**6d**) | Salient write / consult parent: `parent_tier2_for_goal_kind(winner.goal_kind, catalog)` |

**Resolved — eligibility matrix (`build_eligible_goals`):** Applies on each **consideration** cycle when fast-path is **not** active. “Eligible” = row may enter the goal table and receive a `weight`. Mate row omitted until §6.5 (`goal_base_find_mate` **0.0**).

| Condition | Eat | Flight | Find shelter | Rest | Notes |
|-----------|:---:|:------:|:------------:|:----:|-------|
| **Starvation** — `calorie_ratio < starvation_override_food_ceiling` | ✓ | — | — | — | Eat only; scores even under threat samples (starvation priority **0**) |
| **Acute fast-path** (§10) | — | bypass | — | — | Table frozen / not scored; Flight every tick |
| **Normal** — default band | ✓ | ✓* | ✓† | ✓‡ | Compete on `weight` |
| **Find shelter gate** | — | — | † | — | † `calorie_ratio ≥ seek_priority_food_ceiling` |
| **Rest gate** | — | — | — | ‡ | ‡ calories **≥ 95%** + Safety path (§6.1); not eligible 80–95% band |

\* Flight row eligible when threat samples exist in zone (including sub-acute — `urgency_flight` may be **< 1.0** at far edge).  
† Find shelter **not** eligible during acute fast-path (§1, §6.4).  
‡ Rest competes only when Rest gates pass; Eat **`urgency_eat → 0`** at `calorie_ratio ≥ preserve_bias_food_floor` (**0.90**).

**Hard rules (hub-owned — same semantics as V2 [§A.2.3](CREATURE_MOVEMENT_V2.md), no `tier2_dominance` call):** starvation → Eat-only eligibility; acute fast-path → Flight bypass + Find shelter suppressed; sub-acute → continuous weight competition.

**Retired with V2 delete:** per-tick `dom_leaf` in `ai_driver` `_build_motor_context`, [`goal_seek.gd`](../../creature/motor/goal_seek.gd) dominant-leaf target filter, [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd) (entire module), `preserve_find_food_seek_scale` scaling cardinal `w_seek` / explore weights.

**Disposition:** [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd) → **`delete`** at **§12.2 6b**; hub eligibility lives in new V3 hub module under `creature/motor/`.

**Resolved — trait channels v1 (stub):** **Do not** wire non-zero trait coefficients in **`creature_motor_v3`** for V3 v1. Hub consideration: **`trait_goal_mul = 1.0`** always. Planner tactic style: **`trait_tactic_mul = 1.0`** always (reserved hook — no separate module in v1). **Do not** call [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) from the V3 hub — it maps **`dom_leaf` → Tier-2 urgency channels**, the same dual-control pattern retired with **`tier2_dominance.gd`** (§1).

**Long-term intent (deferred — no full spec in this doc):** Traits should bias **how** an active goal is **implemented** (target choice, seek vs local commit, persist / switch / seek — [CREATURE_GOAL_DRIVERS.md §3.1–3.2](CREATURE_GOAL_DRIVERS.md)), **not** which hub goal wins consideration. Example: Eat + Explorer + sated calories → seek novel food sources; Eat + Builder → persist on known local patch; Change → favor seek/switch; Stability → favor persist/wait. Numerics and module ownership ship post–V3 v1 ([ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — **Post–V3 trait tactic modulator**). **V3 v1 intentional:** **`trait_goal_mul = 1.0`** at hub; personality via **`replay_weight`** / locale priors at memory consult (**6d**) only.

**Deferred — post–V3 v1 trait modulator:** Does **not** block V3 ship or **6b**. Scoped in [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — **Post–V3 trait tactic modulator (non-stub)**. Open decisions when picked up: greenfield module (`trait_tactic_modulator.gd` or similar) vs **`creature_motor_v3`** scalar keys for planner tactic style; **do not** revive [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) or V2 **`urgency_*`** Tier-2 channel API. **`trait_goal_mul` / `trait_tactic_mul`** remain V3 spec hooks (literal **1.0** in v1); not wired in legacy code.

**Disposition:** [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) → **`delete`** at **§12.2 6b** (with `tier2_dominance.gd`). **§12.1** inventory; **§15**.

---

## 2. Steps and objectives

For the active goal, break it down into **steps** with **objectives**. These should be actions a human player could potentially take.

- Review applicable skills (stub until skill feature lands).
- Identify step with the highest weight.

**Resolved — step / objective / action:** See Definitions §3–5 and §10 default step chains.

**Resolved — `ActiveGoal` schema:** Adopt [POST_LOS_MOVEMENT.md §3.1](POST_LOS_MOVEMENT.md) fields: `goal_kind`, `weight`, `ultimate_pos`, `step_chain`, `step_index`, `source` (`live` | `belief` | `locale_prior` | `explore` | `backtrack`). **Legacy incompatibility:** shipped motor scatters goal state across `MotorContext` keys (`motor_has_active_goal`, `motor_seek_goal_pos`, per-goal weights) rather than a typed goal table — V3 greenfield replaces this with an explicit active goal table (§10).

**Resolved — “Set finding location as goal”:** Not a separate goal type. If the target is already known — live in zone of awareness (§8.1), precise tier (§8.2), or coarse tier (§8.3) — decompose into steps and objectives. If not known at any tier, enter **Seek** (§3).

---

## 3. Movement (when objective requires movement)

If the current step objective requires movement, follow the movement trees below.

### Top-level movement tree

```
      -------------------
      | Is objective    |
      | location known? |
      -------------------
          no |      | Yes
          ___        ___
          |             |
          V             V
      --------      ----------------
      | Seek |      | Is there  a  |
      --------      | clear path   |
                    | to the goal? |
                    ----------------
                     yes |   | no
                    ______   ______
                    |              |
                    V              V
              ------------    -----------------
              | MOVE to  |    | Calculate     |
              | the goal |    | optimal steps |
              ------------    -----------------
                                      |
                                      V
                                ------------------
                                | Make the first |
                                | step the new   |
                                | objective.     |
                                ------------------
```

**Resolved — “Objective location known?”:** Any of live sighting, precise instance belief, locale-prior centroid, or coarse direction — **tier determines planner behavior** (§8.1 live trees vs §8.2 pathmapping vs §8.3 direction seek).

### Seek cycle tree

```
          --------
          | Seek |
          --------
              |
              V
      -----------------
      | Is this seek  |
      | part of an    |
      | objective?    |
      -----------------
        yes|    | no
        ----    -------------------------
        |                               |
        V                               |
    -------------                       |
    | Is the    |                       |
    | objective |                       |
    | in sight? |                       |
    -------------                       |
    yes|      | No                      |
    ---       -------------------       |
    |                            |      |
    V                            V      V
  -----------               -----------------------
  | Is the  |               | Is there a visible  |
  | path    | <----------   | pattern that        |
  | clear?  |           |   | matches believed    |
  -----------           |   | objective?          |
  yes|     | No         |   -----------------------
  ----     ----------   |     yes |       | no
  |                 |   -----------       ---------
  V                 V                             |
--------------  -------------------               V
| MOVE there |  | Is there enough |         -------------------------
--------------  | information to  |         | Are there unexplored  |
                | calculate a     |         | locations in the      |
                | multistep clear |         | zone of awareness     |
                | path?           |         | with a clear path?    |
                -------------------         -------------------------
                  yes |         | no                yes |         | no
                  -----         --------                V         -------------
                  |                     |             ---------------         |
                  V                     V             | MOVE there  |         V
        ---------------------   -------------------   | and restart |   ---------------------
        | Generate the      |   | Pick path with  |   | Seek cycle  |   | Is there an area  |
        | path. Make first  |   | highest weight  |   ---------------   | behind that opens |
        | step the          |   | for getting     |                     | clear paths to    |
        | active objective. |   | around blocker. |                     | unexplored areas? |
        ---------------------   -------------------                     --------------------
                  |                      |                                 yes |      | no
                  V                      V                                ------      -------
            --------------          ---------------                         |                 |
            | MOVE there |          | MOVE there  |                         V                 V
            --------------          | and restart |                   ---------------   ---------------
                                    | Seek cycle  |                   | MOVE there  |   | MOVE there  |
                                    ---------------                   | and restart |   | and restart |
                                                                      | Seek cycle  |   | Seek cycle  |
                                                                      ---------------   ---------------
```

**Resolved — “Pattern that matches believed objective”:** **Combined precedence** — any source that yields an objective-producing match counts: instance `_goal_belief`, `LocalePriorMap` / `replay_rank_score`, coarse belief bearing (§8.3).

**Resolved — “Unexplored locations”:** See Definitions §9 (coarse/precise tier, 50% area-of-awareness object-density rule). Does not reuse `explore_coverage_cell_px` as the primary contract.

**Resolved — detour / multistep (POST_LOS intent, greenfield implementation):** **Navmesh-first** (`NavigationServer3D` first waypoint); **static-obstacle detour fallback** when navmesh path is empty or map RID invalid. Detour scoring inputs: distance, threat, `replay_weight`, terrain. Optional **`creature_motor_v3.detour_score_competition`** (default **false**): when true, score navmesh vs detour and pick highest. **Headless:** run static AABB corridor sweep when `space_state` is absent; LoS ray skipped where raycast unavailable; navmesh still requires valid map RID — see **headless path fixture** below.

**Resolved — headless path fixture (minimal — closes §14.2.3 / §14.4.5):** V3 **6c+** headless slices use a **programmatic minimal fixture** — **not** full [`main_3d.gd`](../../main_3d.gd) / duel scene boot. Duel manual smoke continues to use playfield navmesh bake (`get_navigation_map_rid()` on main).

| Artifact | Path | Role |
|----------|------|------|
| **Fixture builder** | [`tests/motor_path_fixture.gd`](../../tests/motor_path_fixture.gd) (new) | Headless-only: spawn flat walkable floor + `NavigationRegion3D`, **sync bake**, return valid `map_rid` |
| **Layout variants** | same module | **`open`** — clear floor nav path; **`blocked`** — floor + static AABB wall for backtrack / detour slices |
| **Main stub hook** | extend [`tests/terrain_test_main_stub.gd`](../../tests/terrain_test_main_stub.gd) | Add **`get_navigation_map_rid()`** delegating to active fixture (same contract as `main_3d`) |

**Fixture contract (6c CI gates):**

1. **Setup** — `MotorPathFixture.build_open()` / `.build_blocked()` returns `{ map_rid, space_state?, bounds, teardown }`. Assert `map_rid.is_valid()` before planner tests run.
2. **Navmesh ready** — after bake, assert `NavigationServer3D.map_get_path(map_rid, from, to, true).size() ≥ 2` for fixture start → goal used in the test (guards async-bake flakes without booting duel).
3. **LoS** — when fixture includes collision world, pass `space_state` into planner LoS ctx; when absent, tests follow §3 headless rule (corridor sweep only; LoS skipped).
4. **Teardown** — free fixture nodes after each test (or per `run_all` group) so CI stays deterministic.
5. **Fallback slice** — one separate headless test uses **invalid** `RID()` to assert detour / `STEP_MODE_NONE` fallback — **not** a substitute for navmesh-first slices.

**Out of scope for fixture:** grasslands art pack, interior boulders, LLM/HUD, creature pack merge — keep tests fast. Full duel scene remains **manual smoke** only (§12.2 **6c**).

**Resolved — backtrack v1:** **Approach-heading TTL memory** only ([`blocked_approach_memory.gd`](../../creature/motor/blocked_approach_memory.gd) pattern) — no position stack in v1.

**Resolved — path following (facing-relative executor):** Navmesh/detour trees yield a **world-space step objective** (waypoint or ultimate target). Each tick the planner: (1) sets the active step objective to that point; (2) **turns** until facing is within alignment tolerance (§7.3); (3) emits **`MOVE_FORWARD`** or **`MOVE_BACKWARD`** toward the objective along current facing; (4) on subsequent ticks, applies **small course-correction turns** as the objective moves, then continues move ticks. Does **not** teleport facing or slide without turn actions. Acute Flight fast-path may **abort** an in-progress turn sequence (§10).

**Resolved — LoS blocked threshold (V3 unified):** **`los_blocked_occlusion_fraction`** under **`creature_motor_v3`** — ship default **0.80** (`> 80%` occluded ⇒ blocked). Applies to **live ingest** (§8.1), **clear-path** movement weighing (§3), and zone builder consumers — **one policy**, not separate 60% / 80% values.

### Movement Weighing Tree

```
						-----------------------
						| Is there a clear 	  |
						| LoS ray and Capsule |
						| / corridor sweep    |
            | to the objective?   |
						-----------------------
						  Yes |      | No
						  -----		   ------------	
						  |					            |
						  V				      	      V
					---------------       ---------------
					| MOVE along  |       | Identify all |
					| that Path.	|       | unobstructed |
					---------------       | paths to the |
                                | Objective.   |
                                | Is the count |
                                | > 0?         |
                                ---------------
                                 yes |   | no
                          ------------   ------------
                          |                         |
                          V                         V
                    ---------------             -----------------------
                    | Is one path |             | Are there secondary |
                    | shorter     |             | Objectives in the   |
                    | than the    |             | zone of awareness?  |
                    | others?     |             ----------------------- 
                    ---------------                   yes |     | no
                    yes |   | no                      -----     -----------
                  -------   -------                   |                   |
                  |               |                   V                   V
                  V               V               ----------------    -----------------------
            ---------------   ------------------  | recalculate  |    | Do any unobstructed |
            | MOVE along  |   | Weigh the      |  | active goals |    | points at the edge  |
            | that path.  |   | shortest paths |  ----------------    | of the zone of      |
            ---------------   | and MOVE down  |                      | awareness lead to   |
                              |the winner.     |                      | known dead-ends?    |
                              ------------------                      -----------------------
                                                                           yes |          | no
                                                                          ------          |
                                                                          |               |
                                                                          V               |
                                                                ----------------------    |
                                                                | Remove them        |    |
                                                                | from consideration |    V
                                                                ----------------------  ----------------------  
                                                                          |             | Are there any      |
                                                                          ------------->| remaining paths    |
                                                                                        | that don't involve |
                                                                                        | backtracking?      |
                                                                                        ----------------------
                                                                                          yes |         | no
                                                                                        -------         -------
                                                                                        |                     |
                                                                                        V                     V
                                                                                  --------------------    --------
                                                                                  | Select the most  |    | Seek |
                                                                                  | direct path and  |    --------
                                                                                  | make it the      |
                                                                                  | active objective |
                                                                                  --------------------
```

**Resolved — clear-path test:** LoS ray **>80%** occluded = blocked; plus capsule/corridor AABB sweep; headless: corridor sweep still runs when raycast unavailable (POST_LOS §4.1 intent).

**Deferred — squeeze skill-check on clear-path:** varies by attributes/skills once skill feature lands (§8.1).

**Resolved — “Secondary objectives in zone of awareness”:** Consider **all live goal targets**. A candidate **B** that does **not** replace the incumbent (§8.3 cross-instance table) routes here: less-desirable but suitable same-goal alternates, different-goal opportunistic detours (e.g. food while seeking a mate), or blocked-primary alternates — when the detour does not materially reduce primary success likelihood.

**Resolved — dead-end memory (three concepts):** Do **not** conflate backtrack pinch memory, geographic cul-de-sac marks, and instance passibility — each has a distinct store and phase.

| Concept | Store | Phase | Role |
|---------|-------|-------|------|
| **A. Backtrack / pinch** | [`blocked_approach_memory.gd`](../../creature/motor/blocked_approach_memory.gd) per body — heading TTL only (§3 Seek cycle) | **6c** | Block 180° re-entry into the corridor just failed; uses existing `blocked_approach_*` keys |
| **B. Geographic dead-end** | **`_dead_end_marks_by_body`** — per-creature list ([CREATURE_MEMORY.md §5.6](CREATURE_MEMORY.md)) | **6d** | Movement Weighing “known dead-ends?” — filter edge-of-awareness waypoints that lead into remembered cul-de-sacs; Flight “remove known dead ends” for spatial options |
| **C. Instance passibility** | **`_goal_belief`** row fields ([CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md)) | **6d** | §9 persist/switch/seek — “this objective is unreachable / doesn’t fit”; shelter STAY probe failure |

**Resolved — geographic row schema (B):** Per-creature list (not keyed by `instance_id`). Row fields:

| Field | Type | Required | Role |
|-------|------|----------|------|
| `world_pos` | `Vector3` | yes | Cul-de-sac anchor (failed waypoint or stuck sample) |
| `approach_heading` | `Vector3` (unit) | yes | Same position may be valid from another direction |
| `goal_kind` | wire id | yes | Read filter — flee may exclude different marks than `find_food` / `shelter` |
| `instance_id` | int / `StringName` | optional | Links mark to incumbent objective for §9 correlation; **not** primary key |
| `recorded_ms` | int | yes | TTL expiry + LRU tie-break |

**Resolved — geographic consult (B):** On read, drop candidate waypoint **W** when ∃ mark with `distance(W, world_pos) ≤ dead_end_match_radius`, `goal_kind` matches (or mark is goal-agnostic — v1: **match active step `goal_kind`**), and `normalize(W − creature_pos)` dots `approach_heading` ≥ `dead_end_heading_dot`. Successful traverse through a previously marked cul-de-sac **removes** matching rows.

**Resolved — geographic writes (B):** Planner records on: clear-path fail (§3 LoS + sweep) toward objective; `ActionOutcome.blocked` on `MOVE_FORWARD` after **`dead_end_record_min_blocked_ticks`** consecutive blocked ticks (debounce). Optional geographic row at shelter probe position on failed fit (§6.4) in addition to instance mark (C).

**Resolved — geographic retention (B):** TTL expiry first (`dead_end_memory_ttl_sec`); at cap (`dead_end_memory_max_entries`), evict **oldest `recorded_ms`** (LRU). No `merge_use_count` — consult frequency does not affect eviction.

**Resolved — instance passibility (C):** On `_goal_belief` row — `passibility_fail_count` (int, default 0), `last_passibility_fail_ms` (int). Increment on failed approach / shelter probe / passibility contradiction; **clear** on live re-awareness ([CREATURE_MEMORY.md §5.4](CREATURE_MEMORY.md)). §9 favors **switch** when `passibility_fail_count ≥ passibility_fail_switch_threshold` (ship default **2**). Row fields expire with belief TTL (`goal_memory_ttl_sec`) or clear on re-awareness — whichever comes first.

**Resolved — phasing:** **6c** ships **A only** — Movement Weighing “known dead-ends?” branch treats as **no** (no geographic consult). **6d** wires **B + C** via memory adapter (§8.4). Geographic marks are **memory tier**, not planner-only ephemeral state.

**Resolved — config defaults ([CREATURE_MEMORY.md §10](CREATURE_MEMORY.md)):** `dead_end_memory_ttl_sec` **15**, `dead_end_memory_max_entries` **12**, `dead_end_match_radius` **52** (alias `explore_coverage_cell`), `dead_end_heading_dot` **0.55** (alias `blocked_approach_backtrack_dot`), `dead_end_record_min_blocked_ticks` **3**, `passibility_fail_switch_threshold` **2**. Tune in playtest; species packs may override.

**Resolved — Movement Weighing tree scope:** Applies when the objective is **live in zone of awareness**. Precise-tier pathmapping (§8.2) skips LoS/capsule for remembered coords outside awareness. After movement, when the objective enters the zone, recalculation may use pathmapping for the remainder.

---

## 4. Non-movement actions

If the objective does not require movement, take an action toward the objective.

**Resolved — outcome / salient writes:** Each **action type** carries its own outcome hook in the action definition (which `GoalKind` salient write fires on completion). See per-goal flows in §6 (e.g. EAT → `find_food`; Flight clear → `avoid_hostiles` / `shelter`).

---

## 5. Goal completion loop

Once the objective is accomplished, review the goal for further steps.

- If so, make the next step the new current objective and return to §3.
- If the goal is met, calculate a new goal (§1 hub).

**Resolved — Rest goal completion:** Rest is **sustained** — it does not “complete” like Eat consume. The creature remains on Rest until another goal wins on consideration, Safety state ends, or `REST` is interrupted (§6.1).

---

## 6. Goal logic flows

NOTE: Overlap with the top-level movement flow is intentional — shows how goal-specific flows connect to the movement trees.

### 6.1 Rest

**Resolved — Rest goal phase machine:**

| Phase | Condition | Action emitted |
|-------|-----------|----------------|
| **Approach** | Not at a candidate safe site | `MOVE_*` / `TURN_*` per §3 |
| **Pending Safety** | At a site that **might be safe**; Safety state (§1) not yet achieved | **`STAY`** (full zone, baseline cal — §7.5) |
| **Recover** | Safety state met + §6.1 criteria below | **`REST`** (area-only perception, half baseline — §7.5, §8.1) |

If Safety is already true on arrival and other criteria pass, skip Pending Safety and enter Recover immediately.

```
        ------------------
        | At a candidate |
        | safe location? |
        ------------------
         no |         | yes
        ----           ----
        |                  |
        V                  V
  ----------------    ------------------
  | Believed safe|    | Safety state   |
  | site known?  |    | achieved (§1)? |
  ----------------    ------------------
   yes |    | no        yes |       | no
   ----    ----          -----       -------
   |          |           |                 |
   V          V           V                 V
  --------  -------   ------------    ------------
  | MOVE   | | Seek | | action:    |  | action:    |
  | toward | | /    | | REST       |  | STAY       |
  | site   | | find | ------------    | (until     |
  --------  -------                   | Safety)    |
                                      ------------
```

- **`REST`** aids calorie preservation and healing. Stub until combat — no movement. Calorie: §7.5 (half baseline).
- **`STAY` (Rest pending):** Expected while waiting for Safety at a candidate site — **not** a broken-goal fallback (§7.2).
- **Criteria to emit `REST`:** Rest goal incumbent; calories ≥ 95%; **Safety state** (§1); safe location (full zone check — §8.1); pre-engage uses **full** zone of awareness.
- **Consideration (80–95% calories):** Rest **loses** to competing goals in this band (§1) — creature typically keeps foraging or mapping until calories reach the `REST` threshold or another driver applies. If **no goal wins**, **`STAY`** (§7.2).
- **Pending Safety timing:** Safety state advances on **goal-consideration cycles** only — expect up to **`safety_time × n`** physics ticks in Pending Safety (`STAY`) before **`REST`** is eligible, where **`n`** is the Observation cadence (§10).
- **Outcome Hook:** `REST` action (sustained; no single-tick completion).

**Resolved — Safety state vs `REST` action:** **Safety** is a **state** (Definitions §1). **`REST`** is an **action**. Entering `REST` requires Safety state. While `REST` is active, danger is checked **per tick** against **area of awareness only** (§8.1). When Safety state ends or `REST` criteria fail, the hub **stops selecting `REST`** on each physics tick and emits another action instead (e.g. Flight fast-path if danger entered area — §6.3, §10).

**Resolved — `REST` interrupt:** Per-tick area danger check while `REST` is selected. Hostile in **area** ⇒ end `REST` same tick ⇒ **Flight fast-path** (§6.3). Cone of awareness **re-engages** on the first tick where `REST` is not the selected action (§8.1). Goal supersession on consideration (e.g. Eat as calories drift) ends `REST` without restoring cone mid-tick beyond that rule. Replanning does **not** temporarily restore the cone.

**Resolved — “Safe location” (signals):** Rank and qualify candidate rest sites using **`shelter` beliefs** (dominant), **live threat clearance** (ephemeral tie-breaker), and **squeeze-fit** (conditional — only when shelter belief is weak or absent). **Safety state (§1) is a hard gate** for entering `REST`; it is **not** a weighted term in `safe_site_score`. Experience refines what counts as safe over time ([CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)).

**Resolved — safe location scoring:** Weighted **`creature_motor_v3`** keys — **not** equal thirds. Shelter belief carries the most weight (creature treats a proven bolt-hole as ~100% safe). Live threat clearance carries the least (can flip any tick). Squeeze-fit is **anti-double-counted** against probed shelter beliefs (§6.4 STAY probe already embeds fit in `confidence`).

**Formula (`safe_site_score` per candidate site):**

```
safe_site_score =
    w_shelter * shelter_signal
  + w_threat  * live_threat_clearance
  + w_squeeze * squeeze_fit * unprobed_factor
```

| Signal | Range | Source |
|--------|-------|--------|
| **`shelter_signal`** | 0…1 | `_goal_belief` for `goal_kind == shelter`: **`confidence`** after successful §6.4 STAY probe; optional boost from locale prior **`stored_strength`**. Successful probe floors **`shelter_signal` ≥ `safe_site_probe_confidence_floor`** — creature believes the site is as safe as it gets. |
| **`live_threat_clearance`** | 0…1 | **Instantaneous** — no hostile threatening this site in awareness **right now**. **Not** Safety state (§1). Low weight because it changes tick-to-tick. |
| **`squeeze_fit`** | 0…1 | Live estimate vs hostile size ([CREATURE_MEMORY.md §7.2](CREATURE_MEMORY.md)). |
| **`unprobed_factor`** | 0…1 | **`1.0 − shelter_signal`** — when shelter belief is strong, squeeze term **drops out** (fit already in `confidence`). |

**Uses:**

| Use | Rule |
|-----|------|
| **Rank sites** (MOVE toward best rest site) | Highest `safe_site_score` among eligible candidates |
| **Qualify “safe location”** for `REST` | At incumbent site: `safe_site_score ≥ safe_site_rest_threshold` **and** Safety state met |
| **Exclude bad sites** | `passibility_fail_count ≥ passibility_fail_switch_threshold` (§3 **C**) — failed §6.4 probe |

**Optional hard gate (unprobed only):** When `shelter_signal < safe_site_probe_confidence_floor`, require `squeeze_fit ≥ safe_site_squeeze_fit_floor` before the site is eligible. Probed shelter beliefs **bypass** live squeeze in the score.

**Ship defaults (`creature_motor_v3`):**

| Key | Default | Role |
|-----|---------|------|
| `safe_site_weight_shelter_belief` | **0.70** | Dominant — remembered / probed shelter |
| `safe_site_weight_squeeze_fit` | **0.20** | Conditional via `unprobed_factor` |
| `safe_site_weight_threat_free` | **0.10** | Live threat clearance tie-breaker |
| `safe_site_rest_threshold` | **0.6** | Minimum score at site to count as safe location for `REST` |
| `safe_site_probe_confidence_floor` | **0.6** | Below this, squeeze gate + full `unprobed_factor` apply |
| `safe_site_squeeze_fit_floor` | **0.5** | Min squeeze when unprobed (hard gate) |

Tune in playtest. Species packs may override. **Note:** shelter-heavy scoring prefers remembered bolt-holes over opportunistic open-ground rest; creatures in a squeeze may need more ticks before beliefs match reality (LoS limits) — adjust thresholds if rest feels too picky.

**Resolved — believed safe location unknown:** Set finding location as objective (§2); do not emit `STAY` or `REST` until at a candidate site.

### 6.2 Eat

```
                --------------
                | Is food    |
                | available? |
                --------------
                yes |   | no
                -----   -------
                |             |
                V             V
          ------------    ------------------
          | Take the |    | Is location of |
          | action:  |    | food known?    |
          | EAT      |    ------------------
          ------------     yes |       | no
                          -----       ------
                          |                |
                          V                V
                  ----------------    ---------------
                  | Set location |    | Set finding |
                  | as next      |    | location as |
                  | objective    |    | goal.       |
                  ----------------    ---------------
```

- EAT consumes from a food resource: `available_calories` (max gain) and `consumption_time` (physics ticks, stationary).
- **Criteria:** calories < 95%.
- **Urgency:** §1 Eat calorie bands (`preserve_bias_food_floor`, `seek_priority_food_ceiling`, `preserve_seek_blend_smoothness`, `starvation_override_food_ceiling`).
- **Per-tick cost:** §7.5 — same as **`STAY`**; net positive on completion.
- Outcome Hook: EAT action

**Resolved — three memory layers (Eat):** **Instance** (`_goal_belief` §5.5) = **where** — “I know an apple tree is *there*.” **Kind** (`_kind_profile` §5.7) = **what type is worth how much** — “apple trees beat strawberry plants on yield.” **Locale** (`LocalePriorMap` §14) = **patch / tactic habit** — “foraging *here* worked.” Layers compose; none replaces another.

**Resolved — awareness ingest contract (live food entry):** V3 **greenfield zone builder** (§8.1) — **not** legacy [`motor_target_builder._in_awareness_zone`](../../creature/motor/motor_target_builder.gd) (diet forks retired). Output shape matches prior **`scan_food_plants_in_awareness`** lists; V3 adds **`stimulus_kind_id`** (pack-stable plant type — omniscient at ingest in v1). Per entry:

| Field | Required | Source | Role |
|-------|----------|--------|------|
| `pos` | yes | plant `global_position` | Seek / EAT alignment |
| `instance_id` | yes | Godot `Node.get_instance_id()` | **Runtime target handle** for this tick’s EAT + instance belief key — **not** the learning key for yield |
| `stimulus_kind_id` | yes (V3) | `@export` / pack id on plant scene ([`bush_food_3d.gd`](../../assets/plants/bush_food_3d.gd) until `plant_kind_id` lands) | **Kind profile** key (`nutrition_yield` facet) |
| `consumable_now` | yes | `ready` vs `unready` list | Instance `consumable_now` freeze |
| `line_of_sight_clear`, `occluded`, `occlusion_fraction` | yes | §8.1 zone builder + [`line_of_sight.gd`](../../creature/motor/line_of_sight.gd) | Live ingest only when LoS clear; occluded targets excluded (ghost path §8.1) |

`food_split` = `{ "ready": […], "unready": […] }`. Entries with `instance_id == 0` skip instance sync (phase-1 rule). **Do not** use per-instance **`anticipated_calories`** as the V3 learning field — yield lives on **kind** facets ([CREATURE_MEMORY.md §5.7](CREATURE_MEMORY.md)).

**Resolved — `stimulus_kind_id` authoring (required):** Every food source scene **must** define **`stimulus_kind_id`** before spawn. **Spawn / placement:** do **not** instantiate food into the world without a valid id — fix the bush/shrub (or pack) definition instead of ingesting with a missing key. **`OLog.error`** when spawn is attempted without **`stimulus_kind_id`**. Required for all new food assets; kind ranking and EWMA depend on it (§6.2, §8.4 **6d**).

**Resolved — module ownership:** **Motor stack** ([§1](CREATURE_MOVEMENT_V3)) — orchestrates tick; owns hub scoring runtime, planner state, per-creature **memory adapter** instance. **Hub** — goal scoring only; **no** ingest or memory calls. **Planner** (within stack) — runs awareness pass (or calls shared util), ranks live food targets using **kind** `nutrition_yield` consult + geometry; binds active step `instance_id` for EAT. **Memory adapter** (§8.4, **6d**) — one façade **per stack**; all writes: instance sync, `record_observation`, locale salient write fan-out. **Body / executor** — emits EAT completion outcome to **this stack’s** adapter (calories gained); does not mutate belief stores directly.

**Resolved — kind read (foraging / replace):** Rank live candidates and §8.3 cross-instance replace by **`kind_profile.facet(nutrition_yield, stimulus_kind_id)`** — never-seen kind → **neutral prior** (ship default **0.5** on 0…1 scale). V3 **`unknown_kind_multiplier`** = **1.0** (no familiarity bonus/penalty until traits / plants land). §8.3 “superior same-goal option” = higher **kind** yield belief, not higher instance `anticipated_calories`.

**Resolved — EAT outcome writes:** On completion, adapter receives `{ stimulus_kind_id, instance_id, calories_gained, food_anchor, insufficient_yield }` and:

1. **`record_observation`** — topic `&"nutrition_yield"` → EWMA update on kind facet ([CREATURE_MEMORY.md §5.7](CREATURE_MEMORY.md)).
2. **`goal_source_memory.try_salient_write`** — `find_food` locale prior (unchanged §14.4).
3. **Instance sync** — refresh `consumable_now` / position on matching `instance_id` when still tracked.

**Deferred — variable bite / pool / sharing:** Today plants are static one-bite-full-depletion; schema allows **`believed_calories_per_action`** separate from pool size when [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) lands. V3 wires **`calories_gained`** observation only.

**Deferred — trait modulation on kind confidence:** Traits will bias how fast confidence grows and how strongly kind beliefs affect scoring — v1 omniscient `stimulus_kind_id`, neutral unseen, trait channels stub **1.0** (§1).

**Phasing:** **6c** — ingest includes `stimulus_kind_id`; live target ranking uses kind consult with neutral priors; **no** kind EWMA writes. **6d** — full adapter: instance sync, `record_observation` on EAT, kind read in §8.3 / §9.

### 6.3 Flight

```
                --------------
                | Is danger  |
                | present?   |
                --------------
                yes |     | no
                -----     -----
                |             |
                V             V
          ------------    -------------
          | Is there |    | Calculate |
          | a known  |    | new goal. |
          | shelter  |    -------------
          | nearby?  |
          ------------
          Yes |    | no
          -----    -----------------
          |                       |
          V                       V
    --------------    --------------------------
    | Set going  |    | Remove known dead ends |
    | as active  |    | as options. Are there  |
    | objective  |    | any remaining spaces   |
    --------------    | away from the danger?  |
          |            --------------------------
          |              yes |         | no
          |              -----         ------
          |              |                  |
          |              V                  V
          |    --------------------    -----------------------
          |    | Set farthest one |    | Is there a possible | 
          |    | from danger as   |    | path that requires  |
          |    | active objective |    | moving towards the  |
          |    --------------------    | danger?             |
          |             |               -----------------------
          |             |               yes |         | no
          |             |               -----         -------
          |             |               |                   |
          |             |               V                   V
          |             |       ----------------    -----------------------
          |             |       | Set location |    | Set nearby location |
          |             |       | on that path |    | that would result   |
          |             |       | as active    |    | in erratic movement |
          |             |       | objective    |    | with frequent       |
          |             |       ----------------    | reevaluation for    |
          |             |              |            | potential openings  |
          |             |              |            -----------------------
          |             |              |                 |
          |             V              v                 v
          |         ---------------------------------------
          --------->| Are any viable actions available that|
                    | might aide in the escape (slow the   |
                    | dangerdown, push it away, etc)?      |
                    ----------------------------------------
                        yes |             | no
                        -----             |
                        |                 |
                        V                 |
                  -------------------     |
                  | take the action |     |
                  -------------------     |
                              |           |
                              V           V
                            -----------------
                            | take the MOVE |
                            | action        |
                            -----------------
```

- MOVE: physically relocate over physics ticks.
- **Criteria:** danger in zone of awareness; creature not in squeeze believed inaccessible to danger source.
- **Squeeze tradeoff:** weigh danger distance vs calorie count when boxed in — separate from starvation override in GOAL_DRIVERS (anticipatory, not dominance flip).
- **Urgency:** §1 — `urgency_flight` from `gate_dist` geometry × creature-global **`threat_disposition_mod`** × combat **`relative_threat_mod`** (v1 stubs **1.0** on disposition/combat terms).
- Outcome Hook: danger no longer in the zone of awareness for X ticks of the Goal consideration cadence, where X is the value safety_time (default 5, number to be tuned in playtesting.)

**Resolved — Flight fast-path exit:** Release when danger is absent from the zone of awareness for **`safety_time`** goal-consideration cycles (same as Outcome Hook above). Then run full goal consideration per §10.

**Resolved — `safety_time` during Flight fast-path:** **`safety_time` counter continues during acute Flight** — each consideration cycle with no danger in the full zone increments toward exit; danger present resets the counter. Goal-table weights stay frozen (§10); awareness / danger evaluation still runs on the consideration cadence.

**Resolved — goal-table freeze during Flight:** Matches §10 combat fast-path contract — freeze `weight`, `step_chain`, `step_index` during acute response; full consideration round on release.

**Resolved — Flight + believed shelter:** On fast-path flee, rank retreat objectives using **`avoid_hostiles`** urgency plus **nearby `shelter` beliefs** (instance precise/coarse rows + locale priors within consult radius). Prefer known bolt-holes that pass squeeze-fit vs estimated threat ([CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)) over generic flee headings when available. **Find shelter** hub goal is **not** active during fast-path — only this **consume** path runs.

### 6.4 Find shelter

**Purpose:** Proactively discover and validate refuges (bolt-holes, squeeze pockets) so **Rest** (§6.1), **Flight** (§6.3), and future **Mate** nesting have shelter beliefs to use.

```
        ----------------------
        | Shelter candidate  |
        | known or visible?  |
        ----------------------
         no |           | yes
        ----             ----
        |                    |
        V                    V
  ----------------    ------------------
  | Seek / explore |  | MOVE toward    |
  | (§3)           |  | candidate      |
  ----------------    ------------------
                              |
                              V
                      ------------------
                      | At entrance:   |
                      | STAY — evaluate|
                      | Safety (§1) +  |
                      | squeeze fit    |
                      | (MEMORY §7)    |
                      ------------------
                         pass |    | fail
                         ----      -----
                         |            |
                         V            V
                   ------------   ----------------
                   | Write /    | | Mark low conf|
                   | update     | | or dead-end  |
                   | shelter    | | (§3)         |
                   | belief     | ----------------
                   ------------
```

- **Wire id:** **`shelter`** ([`goal_kind_registry.gd`](../../creature/memory/goal_kind_registry.gd)).
- **Actions:** **`MOVE_*` / `TURN_*`** to approach; **`STAY`** at candidate to evaluate — **not** `REST` (no cone-off / half-calorie recovery during probe).
- **Eligibility (consideration):** §1 — `calorie_ratio ≥ seek_priority_food_ceiling`; **not** during acute threat / Flight fast-path.
- **Weight:** `effective_base_shelter = goal_base_shelter × food_map_confidence` (§1).
- **Outcome hook:** Successful STAY probe → instance **`shelter`** belief (+ locale salient write when MEMORY enables `shelter` writes). Failed fit → instance passibility mark on `_goal_belief` + optional geographic dead-end row (§3 **B + C**).
- **v1 scope:** Live squeeze/passage candidates in awareness + belief tiers per §8; full squeeze fingerprint `context_hash` deferred ([CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)).

### 6.5 Mate

**Deferred** until mating systems land. <<Comment: Stub — define steps, criteria, urgency, and `find_mate` memory hooks when mating systems land.>>

### 6.6 Fight

**Deferred** until combat ships. <<Comment: Stub — define engagement criteria and interaction with Flight fast-path until combat ships.>>

---

## 7. Execution layer (MOVE)

MOVE is the physics/locomotion contract below the planner.

**Resolved — execution model (greenfield):** Facing-relative locomotion — turn on one tick, move forward or backward on another (mirrors planned human-player controls). Do **not** presuppose retired `cardinal_avoidance.gd` eight-way selection unless explicitly re-adopted.

**Resolved — MOVE tick semantics:** One physics tick carries **one** action. A tick is either **turn-only** (facing adjusts; **no** displacement) **or** **move-only** (forward/back along current facing; **no** facing change that tick) — never both in the same tick. Turn-only ticks impose a deliberate cost for large facing changes (180° = **8** turn ticks at 22.5° — §7.3). The same one-action-per-tick rule extends to future non-locomotion actions (shove, attack) when those systems land.

**Resolved — human vs engine ordering:** **Execution layer first; human input adapter deferred.** V3 implements facing-relative `MOVE` through the shared locomotion module (below). Human and LLM adapters are **out of V3 scope** but **must** emit the same `Action` types when they land. Key-to-action mapping is not a V3 concern. **Implementation build order:** §12.2 **6a** (execution before hub/planner) — same principle, different axis than human deferral.

**Resolved — locomotion owner:** Single module under `creature/motor/` applies `Action` values to [`CreatureKinematicBody3D`](../../creature/capabilities/creature_kinematic_body_3d.gd). The ENGINE planner calls it directly; human/LLM adapters call it later via the same contract.

### 7.1 Layer split (planner → executor → body)

Three layers; **world targets and urgency stop at the planner**. <<Comment: Table lists **runtime** data flow (planner → executor). **Step 6 build order** is execution (6a) before planner (6c) — see §12.2.>>

| Layer | Location | Inputs | Output |
|-------|----------|--------|--------|
| **Planner + hub** | [`creature_motor_stack.gd`](../../creature/motor/creature_motor_stack.gd) on each [`CreatureRoot3D`](../../creature/creature_root_3d.gd) | **This** creature’s body/vitals, zone scan, memory adapter, `step_goal`, urgency | One `Action` per physics tick |
| **Executor** | `creature/motor/` locomotion module (stateless) | `Action` only (+ `delta`) | `ActionOutcome` (displacement, blocked) |
| **Body** | [`CreatureKinematicBody3D`](../../creature/capabilities/creature_kinematic_body_3d.gd) | Called by executor | Physics, facing state, vitals |

The executor **never** receives `step_goal`, `ultimate_pos`, or urgency. The planner uses those internally (e.g. emit `TURN_LEFT` until facing aligns with `step_goal`, then `MOVE_FORWARD`). Human input (deferred) maps keys to the same `Action` values and calls the same executor entry point.

**Resolved — urgency vs speed:** Urgency affects **which action** the planner chooses (goal scoring, §1). Per-tick locomotion speed is unchanged by urgency ([`LocomotionProfile`](../../creature/definition/locomotion_profile.gd) `max_speed` / accel). Future **`SPRINT`** action may move faster at a higher calorie cost — out of V3 scope.

**Resolved — terrain / squeeze at execution:** The executor **only applies** the chosen action. No terrain scoring, wall-slide steering, or squeeze affordance logic in the executor. If `MOVE_FORWARD` into a squeeze (or any block) fails in physics, displacement is negligible and `ActionOutcome` reports blocked; **memory / planner** update beliefs to match observed reality on the next observation or consideration cycle — not inside the executor.

### 7.2 Executor contract

**Entry point (greenfield):** `apply_action(body, action, delta) -> ActionOutcome`

| `Action` | Executor behavior |
|----------|-------------------|
| `TURN_LEFT` / `TURN_RIGHT` | Rotate facing by turn increment (§7.3); **no** displacement |
| `MOVE_FORWARD` / `MOVE_BACKWARD` | Displace along ±facing for one move tick via `move_and_slide` |
| `STAY` | No turn, no displacement; full awareness (§8.1) |
| `REST` | No turn, no displacement; cone off while selected (§8.1) |
| `EAT` / others | No locomotion; interaction hooks per §4; range gate via **`action_max_distance`** (§7.2) |

**Resolved — `action_max_distance` (interaction range):** Per-action max distance in **world units** to bind / complete the action. **`null` / unset** = cannot interact at distance. Objective **completion** uses the same threshold as **`arrival_tolerance`** (Definitions §4). Ship defaults on action types:

| Action | `action_max_distance` (ship default) | Notes |
|--------|--------------------------------------|-------|
| **`EAT`** | **5** | Close enough to shrub / food resource to bite |
| **`MATE`**, combat | TBD | Deferred §6.5–6.6 |

**Resolved — `STAY` vs broken goals:** **`STAY` is an action**, not evidence of planner failure. Valid planner contexts emit `STAY`: (1) **idle** — **empty goal table** (§10); (2) **Rest pending Safety** — Rest goal active at a candidate safe site (§6.1); (3) **no winning goal** — consideration ran but no incumbent with actionable steps (e.g. 90–95% calories, Eat urgency 0, Rest not eligible — §1). Do **not** conflate with “goals are broken.” Optional dev log for excessive consecutive `STAY` ticks if playtest warrants — no CI alarm in v1.

**Resolved — empty table vs ineligible goals:** **Empty table** = hub has **no active goal rows** ⇒ **`STAY`** each tick. Goals **on table** with **`feasibility = 0`** still compete at **`goal_feasibility_floor_*`** (§1) — table is **not** empty. Tier-2-ineligible goals are **not added** / are **removed** from the table rather than sitting at zero weight only.

Deduct `action.calorie_cost` (§7.5) when the action is applied. Deprecate engine `set_creature_move_intent(Vector3)` and distance-based [`_apply_calorie_drain_and_starvation`](../../creature/capabilities/creature_kinematic_body_3d.gd) — calorie burn lives on the action definition.

### 7.3 Facing and turn increment

**Resolved — authoritative facing:** Horizontal facing is **body state** (`last_move_direction` or renamed `facing`), not derived from post-move velocity. Turn actions mutate facing; move actions consume it. [`Visual`](../../creature/capabilities/creature_kinematic_body_3d.gd) yaw syncs from facing (awareness cone, §8.1).

**Resolved — turn increment:** **22.5°** per `TURN_LEFT` / `TURN_RIGHT` tick. A 180° reversal requires **8** consecutive turn ticks (deliberate reorientation cost). Planner picks left vs right by shorter arc to `step_goal`, **committed with hysteresis** (`turn_commit_sign`) until **MOVE alignment** (`dot(facing, to_target) ≥ cos(turn_increment_deg)`) is reached — not re-picked every tick (§7.3 facing alignment). Commit does **not** use signed-bearing zero-crossing (avoids ±180° atan2 wrap flip-flop).

**Resolved — explore latch (no live/memory food):** First **`explore_dir`** copies horizontal **`last_move_direction`** (duel spawn facing), not a random bearing. **`explore_waypoint`** is a **world-fixed** point minted once at **`creature_pos + explore_dir × (awareness_radius × 0.5)`** and held until arrival tolerance, blocked explore move (clears latch), dead-end filter rotation, or §9 switch/seek. While **`step_source == explore`**, skip per-tick LoS/nav rewrite and backtrack **`step_goal`** rotation (same contract as **`precise`** GPS latch).

**Resolved — latched stuck detection (explore / precise):** After each tick, [`CreatureMotorStack.tick()`](../../creature/motor/creature_motor_stack.gd) calls [`MotorPlanner.note_tick_completion()`](../../creature/motor/motor_planner.gd) with playfield clamp result. **Stuck** when: executor **`ActionOutcome.blocked`**; **`MOVE_FORWARD`** + playfield clamp adjusted position; or **`explore`** + latched + tick displacement **< `motor_stuck_move_epsilon`** (turn-in-place explore arcs). **`precise`** uses MOVE/clamp stuck **or** **`precise_no_progress_ticks`** (distance to GPS **`step_goal`** not improving over **`dead_end_record_min_blocked_ticks`**) — not turn-idle alone. **`consecutive_blocked`** increments on stuck ticks; latched sources reset only on **`MOVE_FORWARD`** with meaningful progress toward **`step_goal`**. After **`dead_end_record_min_blocked_ticks`**: **`explore`** at playfield edge (**`playfield_hug_band`**) → **boundary scan** (lock **`turn_commit_sign`**, sweep up to 360° along rim via [`MotorPlane.playfield_boundary_hug`](../../creature/motor/motor_plane.gd), `blocked_objective_action = boundary_scan`); **`explore`** interior → rotate **`explore_dir` 60°**, clear latch (`explore_replan`); **`precise`** / other → §9 [`apply_blocked_objective_resolution`](../../creature/motor/motor_planner.gd). F10 HUD **`cmt`**: **`sL`/`sR`** during boundary scan vs **`L`/`R`** align commit.

**Resolved — facing alignment before `MOVE_FORWARD`:** Two tolerances (`_is_facing_aligned_for_move` / `_is_facing_aligned_for_eat`). **MOVE alignment:** angular error between horizontal **facing** and direction to **`step_goal`** ≤ **`turn_increment_deg × 1.0`** (one full turn increment — scales with §7.3 tuning). Equivalently: **`dot(facing, normalize(step_goal − pos)) ≥ cos(turn_increment_deg × π/180)`**. Ship **`turn_increment_deg`** = **22.5** ⇒ **22.5°** MOVE cone. A single atomic turn rotates a full increment; a **0.5×** cone is narrower than one turn step, so the creature could overshoot every tick and spin indefinitely — MOVE accepts within one increment and **course-corrects while moving** (this section). **EAT / precise interaction facing** keeps the tighter **`turn_increment_deg × 0.5`** gate (**11.25°** default). **Turn-direction hysteresis:** planner commits shorter-arc turn direction (`turn_commit_sign`: 0=none, +1=`TURN_LEFT`, −1=`TURN_RIGHT`) and holds it until **`dot(facing, normalize(step_goal − pos)) ≥ cos(turn_increment_deg)`** (MOVE cone) — not re-derived from cross product every tick. While committed, **ignore signed bearing sign flips** near the ±180° rear hemisphere (atan2 discontinuity). Initial pick still uses signed bearing for shorter arc. Commit cleared on `MOVE_FORWARD`, **`goal_kind`** change, and (Flight / non-precise retargets) when target bearing jumps **> one increment** between ticks — **`step_source == precise`** skips bearing-delta commit clear (fixed GPS). **`step_source == precise`** also skips backtrack **60°** `step_goal` rewrite (§8.2 GPS seek). Prevents **TURN_LEFT** / **TURN_RIGHT** flip-flop. Until aligned for MOVE, emit turn actions only.

**Resolved — acute threat preempts turn sequence:** When Flight fast-path becomes eligible mid-turn (multi-tick reorientation in progress), **abort** the turn chain immediately — recalculate flee geometry; if continuing the turn is no longer correct, emit Flight actions instead (§6.3, §10).

### 7.4 Body integration

**Stays on `CreatureKinematicBody3D`:** `CharacterBody3D` capsule, `move_and_slide`, gravity, [`LocomotionProfile`](../../creature/definition/locomotion_profile.gd), playfield clamp (safety net), vitals sync, defeat / hitbox.

**Moves to executor / deprecates on body:** world-space intent vector, `_engine_heading_with_wall_slide` for engine mode, facing-from-velocity after move, per-frame distance calorie integration.

**Tick order (engine):** For each ENGINE [`CreatureRoot3D`](../../creature/creature_root_3d.gd): **`motor_stack.tick()`** selects `Action` → executor **`apply_action(body, …)`** → body completes physics step. One action, one application, one calorie debit **per creature**. [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) loops registered roots only — does not hold per-body goal or belief state (§1 motor stack).

**Resolved — facing authority when `_motor_stack_drives_physics`:** Body **`_physics_process`** returns immediately — legacy intent, **`_apply_facing_after_horizontal_move`** (velocity-derived facing), and distance calorie drain do **not** run. **`last_move_direction`** is owned by **`LocomotionExecutor`** turn actions only; turn ticks **zero horizontal velocity** so stale slide cannot fight the next planner read. Do **not** gate this skip on **`set_use_v3_action_calories`** alone.

### 7.5 Action calorie costs

**Resolved — per-action burn:** Each `Action` carries `calorie_cost` computed at apply time from `delta` (physics step seconds). Refactor replaces legacy `calorie_cost_per_unit_moved` × distance with this model; other action types get values **relative to MOVE** (author fills in).

| Action | Cost formula (per tick) | Notes |
|--------|-------------------------|-------|
| `MOVE_FORWARD`, `MOVE_BACKWARD` | `move_calorie_per_sec × delta` | Anchor |
| `TURN_LEFT`, `TURN_RIGHT` | Same as `MOVE_FORWARD` | Exertion without displacement |
| `STAY` | `calorie_baseline_drain_per_sec × delta` | Full baseline; idle or Rest-pending Safety |
| `REST` | `calorie_baseline_drain_per_sec × rest_baseline_multiplier × delta` | Half baseline; Rest goal + §6.1 only |
| `EAT` | `calorie_baseline_drain_per_sec × delta` | Same per-tick burn as **`STAY`**; net **positive** after food gain on action completion |
| future `SPRINT`, etc. | TBD relative to MOVE | Out of V3 v1 scope |

**Deferred — `SPRINT`:** calorie cost relative to MOVE when sprint action lands (out of V3 v1 scope).

**Resolved — MOVE anchor:** Continuous `MOVE_FORWARD` for **one second** costs **1 calorie** total:

```text
move_calorie_per_sec = 1.0
move_cost(action, delta) = move_calorie_per_sec × delta
```

**Resolved — `REST`:** **Half** baseline metabolism (not half of MOVE):

```text
rest_baseline_multiplier = 0.5
rest_cost(action, delta) = calorie_baseline_drain_per_sec × rest_baseline_multiplier × delta
```

**Resolved — `STAY`:** Full baseline metabolism:

```text
stay_cost(action, delta) = calorie_baseline_drain_per_sec × delta
```

**Resolved — `EAT`:** Per-tick cost matches **`STAY`** (baseline drain). Food resource gain on completion must exceed cumulative eat-tick cost — net calorie **positive** when the action finishes.

```text
eat_cost(action, delta) = calorie_baseline_drain_per_sec × delta
```

Default `calorie_baseline_drain_per_sec` from **`creature_motor_v3`** is **1.0** ⇒ `STAY` / `EAT` ≈ **1.0 cal/s**, `REST` ≈ **0.5 cal/s** at default config. No separate passive drain path in the body — every tick debits exactly one action’s cost.

**Config keys (`creature_motor_v3` — see §12):** `calorie_baseline_drain_per_sec` (default **1.0**), `move_calorie_per_sec` (default **1.0**), `rest_baseline_multiplier` (default **0.5**), Eat urgency band keys (§1: `preserve_bias_food_floor`, `seek_priority_food_ceiling`, `preserve_seek_blend_smoothness`, `starvation_override_food_ceiling`). V3 does not read legacy `creature_motor` or `calorie_cost_per_unit_moved`.

### 7.6 Failure and beliefs

Executor returns `ActionOutcome` with observed displacement and blocked flag. Belief updates (squeeze misjudgement, dead-ends, passibility) are **planner / memory** responsibilities (§3, §8.4, [CREATURE_MEMORY.md](CREATURE_MEMORY.md)) — triggered when outcome contradicts planner expectation, not inside `apply_action`.

**Deferred — human control cadence:** Until human controls ship, ENGINE remains one-action-per-tick (Definitions §5). <<Comment: Players may hold multiple keys and emit more than one action per physics tick when human control lands — reconcile with ENGINE contract then; may require Definitions §5 amendment.>>

---

## 8. Pathmapping and memory interface

V3 planner **reads** memory; authoritative storage tiers remain in refactored [CREATURE_MEMORY.md](CREATURE_MEMORY.md).

### 8.1 Zone of awareness

- Complete set of locations and objects within the zone **with clear line of sight** — geometrically inside the sphere and/or forward cone is **necessary but not sufficient**; occluded targets are **not** live ingest (no x-ray vision through `world_static` solids).
- **Occluded-in-zone ghosts** — read-time projection from **`_goal_belief`** (§8.1 below; storage [CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md)). **6c:** none (live + LoS only). **6d:** full adapter contract.
- Stub: capsule/corridor sweep reliability varies by attributes/skills once skill feature lands.
- Level of absolute clarity stays in sync with the zone; everything else is a different tier.

**Resolved — perception by context (Safety state vs `REST` action):**

| Context | Zone used | Cone of awareness |
|---------|-----------|-------------------|
| Safety state counting (§1); `STAY` pending Safety; pre-`REST` eligibility | **Full** zone (area + cone) | **On** |
| Default (`MOVE`, `TURN`, `STAY` idle, `EAT`, …) | **Full** zone | **On** |
| While **`REST` is the selected action** | **Area of awareness only** | **Off** |

**Resolved — cone disengagement:** Cone disengages on the **first tick `REST` is selected**; re-engages on the **first tick `REST` is not** the selected action (danger interrupt, Safety ends, goal supersession, etc.). Only **`REST`** disables the cone in v1. Implemented in **perception / zone build** (not the executor — §7.1).

**Resolved — danger during `REST`:** Per-tick hostile check uses **area sphere only** (cone off). **Live** hostiles require clear LoS (no x-ray). **Threat ghosts** (§8.1 — hostile `_goal_belief` rows projected while occluded-in-zone) count as present in area **without** live LoS until ghost expiry. Hostile in area (live LoS **or** threat ghost) ⇒ end `REST` ⇒ Flight fast-path (§6.1, §6.3). Area radius tuning deferred until combat and skills land (may modify effective area).

**Resolved — default zone geometry (non-`REST`):** **Zone of awareness** = **union** of **area sphere** + **forward 3D cone**, both gated by **line of sight**. No diet-specific awareness forks; no “cone-only” or “sphere-only” posture toggles.

| Volume | Geometry | Membership |
|--------|----------|------------|
| **Area of awareness** | **Sphere** radius **`awareness_radius`** (world units) about creature body; gate distance to target footprint when half-extents apply | Target within sphere reach |
| **Cone of awareness** | **3D cone** apex at **eye ray origin** (`los_eye_height` or default **0.9 × collision capsule height** — [`get_los_eye_height()`](../../creature/capabilities/creature_kinematic_body_3d.gd)); half-angle **`awareness_cone_half_angle_deg`** about horizontal **facing**; forward reach **`awareness_radius + awareness_cone_extra`** along cone axis | Target within forward cone reach |
| **Zone (default)** | **Union** — in area **or** in forward cone | Either row above |

While **`REST` is selected:** **area sphere only**; cone **off** (table above). All other contexts use the **full union**.

**Resolved — line of sight (mandatory for live ingest):** After geometric zone test, require **clear LoS** via [`line_of_sight.gd`](../../creature/motor/line_of_sight.gd) (`LineOfSight3D`): physics-ray segments eye → target against **`world_static`** mask; **`> los_blocked_occlusion_fraction` occluded** ⇒ blocked — ship default **`los_blocked_occlusion_fraction` = 0.80** (§3 unified policy). Targets inside the sphere or cone but **behind solids do not count as live** — no x-ray vision. Reuse **`line_of_sight.gd`**; **do not** reuse legacy [`CardinalAvoidance.effective_awareness_reach`](../../creature/motor/cardinal_avoidance.gd) (horizontal 2D wedge + body-center distance). V3 ships a **greenfield zone builder** module that composes 3D sphere + eye-anchored cone + LoS.

**Resolved — config (`creature_motor_v3`):** Neutral keys under pack **`creature_motor_v3`** (copy ship values from duel packs on migration — V3 runtime does **not** read legacy **`creature_motor`**):

| Key | Role |
|-----|------|
| `awareness_radius` | Area-of-awareness **sphere** radius |
| `awareness_cone_extra` | Extra forward reach along cone axis (forward zone reach = radius + extra) |
| `awareness_cone_half_angle_deg` | Forward cone half-angle (degrees); facing = body **`last_move_direction`** (§7) |
| `los_eye_height` | Optional eye ray origin Y offset; default **0.9 × capsule height** on body |
| `los_blocked_occlusion_fraction` | Fraction occluded along ray ⇒ blocked — ship default **0.80** (§3) |
| `awareness_requires_los` | When **true** (ship default), LoS gate applies to all live ingest (food, threats, mobs). When **false**, distance+geometry only — **debug / test only**; not ship profile |

**Retired — not in V3 packs or zone builder:** `awareness_forward_cone_only`, `herbivore_threat_awareness_omni`, `predator_prey_awareness_omni`, `predator_prey_awareness_cone_extra` (legacy diet / posture forks).

**Resolved — single consumer contract:** [`awareness_zone.gd`](../../creature/motor/awareness_zone.gd) + [`awareness_zone_scan.gd`](../../creature/motor/awareness_zone_scan.gd) feed **live** ingest for **threat** ([CREATURE_GOAL_DRIVERS.md §2](CREATURE_GOAL_DRIVERS.md)), **food** (§6.2), **memory re-awareness** ([CREATURE_MEMORY.md §5.4](CREATURE_MEMORY.md)), **Flight `urgency_dist` / `eff_reach`** (§1), **Safety** checks (§1, §6.1), and debug overlay. Same geometry + LoS rule every tick. **6d:** occluded-in-zone **ghost layer** (below) merges threat ghosts into the same threat / danger consumers.

**Resolved — occluded-in-zone ghost mapping (Option A — `_goal_belief` / MEMORY §5.5):**

| Principle | Rule |
|-----------|------|
| **Storage** | **`_goal_belief`** rows via memory adapter — **not** planner-only ephemeral state, **not** legacy **`_mob_hist`** / **`awareness_memory_*`** (retire in V3 — §12.1) |
| **Tier** | Existing **`PRECISE`** row unchanged; ghost = **read-time ingest overlay** when LoS fails but row + zone rules pass — **no third tier** |
| **Eligibility** | Row exists from prior **live** in-zone sighting with clear LoS; target is **geometrically in zone** this tick but **LoS blocked**; **dedupe:** when live LoS clears for the same instance, **live sample wins** — drop ghost projection for that instance this tick |
| **Phasing** | **6c:** **no ghosts** — live + LoS only. **6d:** adapter read API emits ghost samples |

**Movers** (`is_moving = true` — **all tracked creatures**: hostiles, prey, mates, neutrals, relocating mobs):

- **Believed position** for zone membership: **`last_world_pos`**; optional intercept hint **`last_world_pos + last_velocity × goal_memory_ghost_horizon_sec`** (default **0.4 s** — MEMORY §5.5) for pursuit / Flight geometry only.
- **Persist while:** **`last_world_pos`** (and intercept when used for reach-cap test) remains inside **geometric zone** (full union; **area sphere only** while `REST` selected — same posture table as live ingest).
- **Also drop when (reach cap — formula A):** **`gate_dist(creature, believed_pos) > awareness_radius + awareness_cone_extra`**, where **`believed_pos`** is **`last_world_pos`** or extrapolated intercept — prevents stale chase of targets that have **believed** to have moved beyond max zone reach even if last observed point still sits behind cover in the rear sphere.
- **Fields:** reuse MEMORY §5.5 — **`last_velocity`**, **`ghost_strength`** (age decay within mover TTL optional; zone exit + reach cap are primary evictors).

**Statics** (bushes, props — `is_moving = false`):

- **Non-threat / not noteworthy:** **No occluded-in-zone ghost** unless the instance already has a **`_goal_belief`** row from another memory path (precise/coarse outside zone — §8.2–8.3). If only held as a transient occluded-in-zone ghost with **no** persistent row, **forget when `last_world_pos` leaves geometric zone** — do not clog memory.
- **Threat statics** (if any): same zone-based ghost as movers **without** velocity extrapolation.

**Ghost projection vs danger consumers (resolved — consult filters in §8.4):**

- **Projection** (who may emit an occluded-in-zone ghost sample) follows eligibility above — **same rules** for tracked creatures, persistent static food, and **remembered shelter sites** (`goal_kind == shelter` from §6.4 probe).
- **Consumption** is **not** uniform: only samples passing **`danger_filter`** (§8.4) reach Safety / Flight / **`REST` area interrupt**. Food, **shelter**, mate (deferred), and neutral creature ghosts **project** when eligible but **never** count as danger unless **`goal_kind == avoid_hostiles`**.
- Transient occluded statics with **no** persistent row: **forget when out of zone** (§972–974).

**Ingest shape (6d):** ghost entries mirror live samples with **`source: ghost`**, **`line_of_sight_clear: false`**, position from **`last_world_pos`** (movers: optional intercept in pursuit hints only). Samples passing **`danger_filter`** feed **`ThreatSample`** / **`gate_dist`** like live threat samples.

**Sibling doc — [CREATURE_MEMORY.md](CREATURE_MEMORY.md):** Step 3 + **6d** sibling sync checklists — **§12.3**. Adapter implementation remains **§12.2 6d**; doc sync is **not** optional drift.

### 8.2 Precise tier

Instance-anchored beliefs for past observed objects of interest within `goal_memory_precise_radius` (pack or creature default, world units). Holds real-world location; may omit obstacles — pathing decisions apply once the creature re-enters awareness.

- Moving toward objectives on **precise** remembered targets **does not** use LoS ray + capsule/corridor sweep (straight seek / shortest path).
- Prefer shortest path unless known obstacles in awareness — then closest unobstructed point becomes primary objective.

<<Comment: Precise tier = **instance beliefs** (`instance_id` rows), not `LocalePriorMap` aggregates — wording synced; storage authority remains [CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md).>>

### 8.3 Coarse tier

For objects outside precise envelope but within `goal_memory_forget_radius`, preserve general direction only.

Prioritize shortest unobstructed path in that direction until:

1. Objective enters zone of awareness.
2. Another belief **B** enters zone of awareness — route per **cross-instance table** below (replace vs secondary).
3. Another goal takes precedence.
4. Creature travels `goal_memory_forget_radius + 10%` — then Seek takes priority.

**Resolved — coarse expiry (two policies):**

| Policy | Scope |
|--------|--------|
| `goal_memory_coarse_ttl_sec` + LRU | How long a belief **remains in coarse-tier memory** |
| V3 travel-distance rule (`forget_radius + 10%`) | Locomotion: creature reached the general area but objective never entered zone of awareness → generic **Seek** takes over |

**Resolved — coarse locomotion (replaces eight-way `sector_weights`):** V3 **path-in-direction** is the sole coarse locomotion contract. **[CREATURE_MEMORY.md §5](CREATURE_MEMORY.md)** belief rows are **unchanged** (`last_world_pos`, `tier`, TTL/LRU) — imprecision is enforced at **read time**, not by changing stored geometry.

- **Planner read:** For `tier == COARSE`, derive **bearing** = `normalize(last_world_pos − creature_pos)`. Emit shortest unobstructed path **in that direction** (§3 Movement Weighing / detour trees). **Do not** set `ultimate_pos = last_world_pos` or precise GPS seek while coarse.
- **Retired for V3 locomotion:** [`believed_goal_source_bias.sector_weights`](CREATURE_MEMORY.md) eight-way merge and **`weight_coarse_sector_goal_bias`** cardinal costs ([MEMORY §14.1](CREATURE_MEMORY.md)). MEMORY merge may simplify on promotion; non-motor consumers (LLM, debug) are out of V3 scope.
- **Re-find not guaranteed:** tier downgrade, pathing/detours, coarse TTL, forget radius, and travel-distance Seek handoff (above) — not compass-sector storage.

**Resolved — competing coarse beliefs (incumbent selection):** When multiple `COARSE` rows match the active `goal_kind`, pick the locomotion bearing in order:

1. Belief tied to the **active step’s `instance_id`** (if any).
2. Else highest **goal weight × feasibility** among coarse candidates.
3. Tie-break: newest **`last_observed_ms`** (recency — not distance; proximity feeds feasibility in §1, not this tie-break).

**Resolved — cross-instance awareness (B while seeking coarse A):** When belief **B** enters awareness (live or re-awareness → `PRECISE`) while the incumbent step targets coarse **A** (`instance_id` ≠ B):

| Condition | Routing |
|-----------|---------|
| **B like-for-like with A** (same `GoalKind`, same step intent — e.g. bush for bush) | **Replace** incumbent objective with B |
| **B superior same-goal option** (e.g. higher **kind** `nutrition_yield` for B’s `stimulus_kind_id`) | **Replace** incumbent objective with B |
| **B less desirable but potentially suitable** (same goal, lower yield) | **Secondary objective** (§3) — opportunistic detour only if primary success likelihood not materially reduced |
| **B different goal** than A (e.g. shrub sought, mate available) | **Secondary objective** (§3) |

Same-instance re-awareness (B = A) remains **[CREATURE_MEMORY.md §5.4](CREATURE_MEMORY.md)** — snap A to `PRECISE`; no separate cross-instance rule.

**Deferred — neighbor search refinement (skills stub):** While seeking coarse A, a precise/live **B** *may* narrow ephemeral planner search geometry (bearing cone toward A, not GPS lock). **Out of V3 v1 scope** until skills land. <<Comment: Skill band gates cone width and refinement strength — stub until skill feature lands; no implementation in V3 phase 1.>> **Excluded:** stored spatial relations between instances (no pairwise layout memory, no triangulation graph).

### 8.4 Planner consumption (sibling MEMORY section)

**Resolved — MEMORY sibling split:** [CREATURE_MEMORY.md](CREATURE_MEMORY.md) owns **row schema, TTL keys, eviction, salient-write gates** (§§5.5, 5.6, 5.7, 10). This doc owns **when** the V3 planner reads/writes via the memory adapter — no V2 `MotorContext` merge. On promotion, add matching **§8.4 planner-consumption** section to MEMORY with cross-anchors to this §8.4.

**Resolved — memory modules (adapter facade — not greenfield rewrite):** Keep [`goal_belief_memory.gd`](../../creature/motor/goal_belief_memory.gd) and [`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd) as **storage + consult implementations**, but V3 **must not** call V2 **`MotorContext` merge** entry points (`project_believed_goal_bias`, per-tick cardinal projection, `sector_weights` locomotion). Introduce a **thin memory adapter** under `creature/motor/` (§12.2 **6d**) that exposes §8.4 read/write tables only. Legacy V2 consult methods become **dead code** behind the adapter boundary until **deleted** in **§12 step 11** (**§15**). **Do not** duplicate storage schemas or salient-write math in a parallel memory stack — adapter wraps existing classes.

**Resolved — memory adapter module path (Option A — dedicated façade):** Closes §15.3 adapter-path row.

| Artifact | Path / name | Role |
|----------|-------------|------|
| **Memory adapter** | [`creature/motor/memory_adapter.gd`](../../creature/motor/memory_adapter.gd) | **Sole public entry** for hub/planner memory I/O — §8.4 read/write tables |
| **Salient write payload** | **`SalientWriteContext`** (`class_name`) | Replaces V2 `motor_ctx: Dictionary` on salient writes (§12.3.4); may live in [`salient_write_context.gd`](../../creature/motor/salient_write_context.gd) or the same file as the adapter |
| **Storage (internal)** | `goal_belief_memory.gd`, `goal_source_memory.gd`, `kind_profile_memory.gd` | Delegate only — **not** imported by hub/planner for consult |

**Hard rules:** Hub, planner, and executor outcome hooks on a stack **preload/import only** `memory_adapter.gd` (and `SalientWriteContext` when building write payloads) for **that creature’s adapter instance**. **Do not** nest the façade API under `goal_*_memory.gd` or call V2 projection/merge entry points from V3 code paths. **Do not** store per-creature belief / goal state on [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) — stacks own it (§1).

**Resolved — V2 projection method cleanup:** **Delete** unused V2 projection/merge methods from [`goal_belief_memory.gd`](../../creature/motor/goal_belief_memory.gd) / [`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd) in **one pass at §12 step 11** once grep confirms zero callers (V3 adapter path + any remaining V2 tests migrated or removed). **Do not** leave `@deprecated` stubs for a release — storage modules stay; dead V2 **API surface** is removed cleanly.

**Resolved — instance belief cap eviction (`_goal_belief`):** When **`goal_memory_max_entries`** is exceeded (after TTL / forget-radius / coarse-TTL evictions), evict the row with **lowest `last_observed_ms`** (oldest live sighting). Tie-break: deterministic low **`instance_id`**. **`merge_use_count`** / **`last_merged_ms`** — **deprecated** in V3 (V2 motor-merge fields; not read or written). No consult-frequency retention in v1 — adapter reads do **not** bump eviction stats. Future use-based retention may land via backlog if playtest warrants.

**Resolved — memory adapter read API (6d):**

| Consult | Source | Planner use |
|---------|--------|-------------|
| **Precise belief** | `_goal_belief` where `tier == PRECISE` | §8.2 GPS seek to `last_world_pos` when outside awareness |
| **Coarse belief** | `_goal_belief` where `tier == COARSE` | §8.3 bearing-only path-in-direction |
| **Locale prior** | `LocalePriorMap` / `replay_rank_score` | §3 seek cycle, §9 tactic layer |
| **Dead-end filter** | `_dead_end_marks_by_body` | §3 Movement Weighing edge-waypoint filter; §6.3 Flight spatial option removal |
| **Instance passibility** | `_goal_belief.passibility_fail_count` | §9 switch bias; shelter / Flight consume blocked instances |
| **Kind yield / threat** | `_kind_profile` facets ([CREATURE_MEMORY.md §5.7](CREATURE_MEMORY.md)) | §6.2 live ranking; §8.3 replace; §9 switch; §1 `kind_threat` |
| **Occluded-in-zone ghost** | `_goal_belief` read projection (§8.1) | Filtered per **§8.4 consult filters** — **6d** |

**Resolved — occluded-in-zone ghost projection + consult filters (closes §14.4.6):** Single **`_goal_belief`** store; **one** internal ghost projector; **multiple** public adapter consults apply **consumer-specific filters**. Ghosts are classified at **consult** time, not by separate storage tiers.

**Pipeline:**

| Step | Rule |
|------|------|
| **A — Project** | Internal only: **`_project_occluded_in_zone_ghosts(zone_ctx)`** — for each eligible row (§8.1), if **`last_world_pos`** is in geometric zone this tick **and** LoS blocked **and** no live sample for same **`instance_id`**, emit ghost sample (`source: ghost`, `line_of_sight_clear: false`). |
| **B — Filter** | Each public consult below applies its predicate — **never** pass unfiltered ghosts to Safety / Flight / REST danger. |

**Ghost eligibility by row class:**

| Row class | `is_moving` | Occluded-in-zone ghost? | Persistent row required? |
|-----------|-------------|-------------------------|---------------------------|
| **Tracked creatures** (hostile, prey, mate, neutral) | `true` | **Yes** | Prior live in-zone sighting (clear LoS) |
| **Static food** | `false` | **Only if** row exists | Yes — live sight or §8.2–8.3 promotion |
| **Shelter site** (`goal_kind == shelter`) | `false` | **Yes** | Yes — §6.4 successful probe write |
| Transient occluded static, no row | `false` | **No** | — |

**`danger_filter(sample) -> bool` (v1):** True when sample is **nearby threat** for Safety / Flight / REST area interrupt:

- **`goal_kind == &"avoid_hostiles"`**, **and**
- Sample shape matches threat ingest (**`ThreatSample`** / live threat scan) with **`stimulus_kind_id`** for **`kind_threat`** (§1).

**Exclude from danger:** `find_food`, **`shelter`**, `find_mate` (deferred), neutral creatures tracked under non-hostile kinds, any row failing **`danger_filter`**. Creature ghosts that fail **`danger_filter`** still **project** when occluded-in-zone but reach **goal consults only**.

**Deferred — combat / neutral fauna:** **`relative_threat_mod`** and low **`kind_profile.threat_danger`** may refine **`danger_filter`**; neutral kinds never pass **`danger_filter`** even when occluded.

**Public adapter consults (filtered reads):**

| Adapter consult | Row / sample filter | Ghost? | Primary consumers |
|-----------------|---------------------|--------|-------------------|
| **`consult_danger_samples()`** | **`danger_filter`** | Live + threat ghost | Safety state (§1), Flight urgency / fast-path (§1, §6.3), **`REST` area interrupt** (§6.1), hub threat eligibility |
| **`consult_food_targets()`** | **`goal_kind == &"find_food"`** | Live + ghost when persistent row | Eat ranking (§6.2), remembered food seek (§8.2), §8.3 replace |
| **`consult_shelter_beliefs()`** | **`goal_kind == &"shelter"`** | Precise / coarse outside zone; **live + ghost inside** zone (remembered bolt-hole behind cover still counts at **`last_world_pos`**) | **`safe_site_score`** (§6.1), Find shelter probe (§6.4), REST site rank / qualify |
| **`consult_goal_beliefs(goal_kind)`** | **`goal_kind` param match** (+ optional `tier`) | Live + ghost per §8.1 | Generic remembered seek (§8.2–8.3); future **`find_mate`** |
| **`consult_kind_facet(...)`** | **`_kind_profile`** by **`stimulus_kind_id`** | N/A (not instance rows) | §6.2 yield rank; §1 **`kind_threat`** on threat samples |

**First sight → `goal_kind` stamp (write-side; before any ghost):**

| Live ingest / write event | `goal_kind` on new row |
|---------------------------|------------------------|
| Hostile threat scan | **`avoid_hostiles`** |
| Food plant in awareness | **`find_food`** |
| Successful Find shelter probe (§6.4) | **`shelter`** |
| Future mate recognition | **`find_mate`** (deferred — §6.5) |

Re-sync updates **`last_world_pos`**, **`consumable_now`**, **`last_velocity`**, **`is_moving`** only — **`goal_kind`** unchanged unless a salient episode retags (combat deferred).

**Resolved — memory adapter write API (6d):**

| Event | Write target |
|-------|--------------|
| Live sighting / re-awareness | `_goal_belief` sync (position / `consumable_now` only); clear `passibility_fail_count` on matching `instance_id` |
| Kind observation | `record_observation(topic_id, stimulus_kind_id, value)` per [CREATURE_MEMORY.md §5.7](CREATURE_MEMORY.md) learn-topic registry |
| Consumption / salient outcome | `goal_source_memory.try_salient_write` (unchanged) + EAT → `nutrition_yield` observation |
| Clear-path fail / blocked MOVE | `_dead_end_marks_by_body` append (§3 **B**) |
| Failed approach / shelter probe | `_goal_belief` increment `passibility_fail_count` (+ optional geographic row §3 **B**) |
| Successful traverse of marked cul-de-sac | Remove matching `_dead_end_marks_by_body` rows |

**6c:** adapter stubs return empty / no-op for instance belief, locale, kind EWMA writes, dead-end consults, and **ghost projection** — live awareness + LoS only + kind read with **neutral** priors + `blocked_approach_memory.gd` only.

---

## 9. Goal seek exceptions

If the objective is inaccessible (shrub out of reach, creature in squeeze), evaluate past experience (three memory layers below), alternate goal locations, and an element of chaos to decide: persist, switch target, or enter Seek.

**Resolved — past experience (three layers):**

| Layer | Source | Role in §9 |
|-------|--------|------------|
| **Tactic / area** | **`LocalePriorMap`** / **`replay_rank_score`** for active `(GoalKind, context_hash, modality)` | High score → favor **persist** on current approach; low score → favor **switch** or **Seek** |
| **Target / instance** | **`_goal_belief`** row for incumbent **`instance_id`** — `consumable_now`, `passibility_fail_count` ([CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md)) | Not consumable, or `passibility_fail_count ≥ passibility_fail_switch_threshold` → favor **switch**; other instance beliefs supply **alternate locations** |
| **Stimulus / kind** | **`_kind_profile`** facet for incumbent `stimulus_kind_id` — `nutrition_yield` ([CREATURE_MEMORY.md §5.7](CREATURE_MEMORY.md)) | Low **kind** yield vs alternates → favor **switch**; kind ranking for live targets per §6.2 |

**Combine:** **Persist** only when **all three** layers support staying on the incumbent (locale + instance passibility/consumability + kind yield vs alternates). Any layer failing pushes toward **switch** (ranked alternates: higher kind-yield live/instance targets, locale hotspots via **`replay_rank_score`**, §8.3 cross-instance table) then **Seek** if no viable alternate.

**Resolved — `change_stability` (single path):** Factored **once** — inside **`replay_rank_score`** trait rank bias ([CREATURE_GOAL_DRIVERS.md §5.1](CREATURE_GOAL_DRIVERS.md)). **Not** a separate §9 multiplier or second “past experience” input.

**Resolved — chaos on close calls:** When persist / switch / seek scores tie after the above, break symmetry with RNG. Key **`blocked_objective_chaos`** under pack **`creature_motor_v3`** — **not** legacy `motor_intent_cost_chaos` or other V2 `creature_motor` keys.

**Resolved — `blocked_objective_chaos` ship default:** **`0.15`** (light jitter on persist / switch / seek score ties). **`0.0`** disables chaos. Species packs may override; retune in playtest if ties feel too random or too sticky.

---

## 10. Goal consideration cadence

Every **n** physics ticks, re-evaluate zone of awareness and run **goal consideration** on new observations.

- **n** from **Observation** attribute — higher Observation ⇒ more frequent replans ([CREATURE_ATTRIBUTES_USAGE.md §3.5](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)).
- Maintain an **active goal table** (goals + weights). **Empty table** (no rows) ⇒ **`STAY`** each tick (§7.2). Goals on table at **`feasibility_floor`** only are **not** empty.
- Goal consideration weighs all candidates. When a goal decomposes into steps, earliest unaccomplished step is **primary**. If another goal’s weight exceeds incumbent, discard incumbent step chain.

**Resolved — goal consideration tie-break:** When hub goal **weights tie** (or are within a small epsilon after rounding), break symmetry with RNG. Key **`goal_consideration_chaos`** under pack **`creature_motor_v3`** — ship default **`0.15`** (same magnitude as **`blocked_objective_chaos`** §9). **`0.0`** disables chaos.

**Fast-path bypass (every tick):** Flight. **Find shelter** is **fully suppressed** — not scored on the goal table during acute threat (§1, §6.4). Flight **consumes** nearby **`shelter`** beliefs for retreat bias (§6.3). **Combat (future):** attack action triggers fight/flight immediately — planner and frozen goal table do not compete with acute response. **Acute Flight preempts** in-progress multi-tick turn sequences (§7.3).

**Combat fast-path signal:** dedicated flag — do **not** infer from damage intake, ambient threat, or generic hostile-in-awareness alone.

- **Set:** creature **takes an attack action** (combat state machine). Not implemented until combat lands.
- **Clear:** defined with combat; release triggers same post-response goal-consideration contract as Flight exit.

**Goal-table contract (Flight / combat fast-path):** freeze active goal table during acute response (`weight`, `step_chain`, `step_index` preserved — not cleared). On release, run a **full goal-consideration round** before resuming step execution; frozen incumbent may no longer be valid.

**Resolved — Observation → n ticks:** Adopt [POST_LOS_MOVEMENT.md §3.3](POST_LOS_MOVEMENT.md) piecewise curve — **10 = neutral** (scale 1.0). `stat_observation ≤ 10`: scale `lerp(2.0, 1.0, stat/10)`; `> 10`: scale `lerp(1.0, 0.5, (stat−10)/90)`; `n = max(1, round(base_ticks × scale))`. Pilot clamp: minimum **10** for curve input until observation pools land.

**Resolved — `goal_replan_base_ticks` ship default:** Adopt POST_LOS **`post_los_replan_base_ticks` = 8** under **`creature_motor_v3.goal_replan_base_ticks`**. At `stat_observation = 10`, `n = 8`. Retune in playtest if consideration feels too sluggish or twitchy.

**Resolved — `goal_consideration_chaos` ship default:** **`0.15`** — light jitter on hub goal-weight ties (§10 above). **`0.0`** disables.

**Resolved — between replan ticks:** Execution follows the **incumbent goal** from the last consideration round (weights frozen; step chain advances on objective completion). Fast-path Flight/combat may override every tick (§10). No per-tick full re-score between consideration cycles.

---

## 11. Adopted decisions (from POST_LOS — intent only)

**Resolved — POST_LOS ledger vs V2 (kickoff audit):** Every row in the table below is **V3 intent-only**. **None** retains `cardinal_avoidance.gd` eight-way selection or V2 **`MotorContext`** merge at runtime. POST_LOS described goals and seek state atop those modules; V3 replaces them with an explicit **`ActiveGoal` table** (§2, §10), facing-relative **`Action`** execution (§7), and **memory adapter** consult (§8.4) — not a `MotorContext` projection path. Rows whose wording echoes POST_LOS/V2 are clarified in the **Notes** column (e.g. Eat urgency = **`creature_motor_v3` keys only**; eligibility = **hub `build_eligible_goals`** §1 — **delete** `tier2_dominance.gd`, per-tick `dom_leaf`, `goal_seek` filter).

**Resolved — Step 3 teardown (V2 behavior out; not “delete every motor file”):** §12 Step 3 removes V2 **motor behavior** per §12.1 dispositions. After Step 3 the game launches with **no intelligent creature movement** (Step 5); compile survives via **stub**, **keep**, and **adapter** rows until §12.2 Step 6 rebuilds in order **6a → 6b → 6c → 6d.1 → 6d.2 → 6d.3**.

| Disposition | Step 3 action | Examples (§12.1 seed — complete inventory on branch) | V3 phase |
|-------------|---------------|------------------------------------------------------|----------|
| **delete** | Remove file or motor pipeline block | `cardinal_avoidance.gd`, `goal_seek.gd`, `seek_planner.gd`, `ai_driver` `_mob_hist` / `awareness_memory_*`, cardinal / explore / eight-way helpers | — |
| **stub** | Minimal placeholder until Step 6 | `ai_driver.gd` motor pipeline | **6b** hub entry |
| **keep** | Utility V3 calls directly | `line_of_sight.gd`, `blocked_approach_memory.gd`, `threat_sample.gd`; `game_config_merge.gd` + `creature_motor_v3` | **6a**–**6c** |
| **adapter** | Retain storage; drop V2 `MotorContext` API | `goal_belief_memory.gd`, `goal_source_memory.gd`, `kind_profile_memory.gd` (new) | **6d** |

**6c adapter stubs:** Until **6d**, memory adapter returns empty / no-op for instance belief, locale prior, kind EWMA writes, dead-end consults, and ghost projection — live awareness + LoS only (§8.4).

| Decision | V3 section | Notes |
|----------|------------|-------|
| Three layers: goals → planner → execution | §1–3, §7 | **V3 intent.** Runtime **call** order; **build** order §12.2 (execution first) |
| Hub: no explicit inputs; one action per tick | §1 | **V3 intent.** **`creature_motor_stack.gd`** per [`CreatureRoot3D`](../../creature/creature_root_3d.gd) |
| V3 ↔ `GoalKind` routing | §1 table | **V3 intent.** Via `goal_kind_registry.gd` |
| `ActiveGoal` schema | §2 | **V3 intent.** POST_LOS §3.1 fields; **replaces** scattered `MotorContext` goal keys |
| Slow replan vs fast-path Flight/combat | §10 | **V3 intent.** Every tick bypass for acute response; `goal_replan_base_ticks` **8** (§10) |
| Clear path = LoS (>80% blocked) + corridor sweep | §3 | **V3 intent.** Reuse **keep** `line_of_sight.gd`; squeeze skill-check **Deferred** (skills) |
| Navmesh-first, detour fallback when blocked | §3 Seek cycle | **V3 intent.** Greenfield planner; **`tests/motor_path_fixture.gd`** for headless CI; duel manual smoke |
| Unexplored = coarse/precise low object density | Definitions §9 | **V3 intent.** 50% area-of-awareness rule |
| Approach-heading backtrack TTL (v1) | §3 Seek cycle | **V3 intent.** Reuse **keep** `blocked_approach_memory.gd`; no position stack v1 |
| Dead-end memory — geographic + instance | §3, §8.4 | **V3 intent.** §5.6 + `_goal_belief` passibility; **6d** |
| Freeze goal table during Flight/combat | §10 | **V3 intent.** Full consideration after release |
| Flight exit = `safety_time` cycles safe | §6.3 | **V3 intent.** Matches Outcome Hook |
| Coarse TTL vs travel-distance Seek handoff | §8.3 | **V3 intent.** Separate policies |
| Coarse path-in-direction; `sector_weights` retired for locomotion | §8.3 | **V3 intent.** MEMORY schema unchanged; not `MotorContext.believed_goal_source_bias` |
| Coarse incumbent: recency tie-break (`last_observed_ms`) | §8.3 | **V3 intent.** Not distance |
| Cross-instance B-vs-A: replace vs secondary-objective | §8.3 | **V3 intent.** Circumstantial table |
| Neighbor search refinement | §8.3 | **Deferred** — skills stub; no stored spatial relations |
| Facing-relative forward/back MOVE | §7 | **V3 intent.** Greenfield; **not** `cardinal_avoidance` |
| Turn-only vs move-only (one action per tick) | §7 | **V3 intent.** 180° and future shove/attack cost |
| Execution-first; human adapter deferred | §7 | **V3 intent.** Shared `Action` contract |
| Locomotion owner under `creature/motor/` | §7 | **V3 intent.** ENGINE + future adapters |
| Executor sees `Action` only (not `step_goal`) | §7.1–7.2 | **V3 intent.** Planner owns world targets |
| Urgency → planner only; fixed speed until `SPRINT` | §7.1 | **V3 intent.** `LocomotionProfile` |
| Turn increment 22.5° / 8 ticks per 180° | §7.3 | **V3 intent.** Facing-relative |
| Per-action calorie; MOVE = 1 cal/s; STAY = baseline; REST = half baseline | §7.5 | **V3 intent.** Retire distance burn |
| `STAY` vs `REST`; Rest phase machine; cone off during `REST` only | §6.1, §7.2, §8.1 | **V3 intent.** Safety state gates `REST` |
| Safe location scoring — shelter-heavy weights | §6.1 | **V3 intent.** `safe_site_weight_*`; squeeze anti-double-count |
| Physics failure → beliefs (not executor) | §7.6 | **V3 intent.** Memory sibling |
| Past experience: locale + instance + kind layers; `change_stability` once | §9 | **V3 intent.** **6d** via memory adapter + `replay_rank_score`; not `MotorContext` merge |
| Eat — kind vs instance memory + ingest | §6.2, §8.4 | **V3 intent.** `stimulus_kind_id`; `record_observation`; instance = where only |
| Flight — kind threat × disposition | §1, §6.3 | **V3 intent.** `kind_threat`; neutral unseen; not familiarity |
| Config namespace `creature_motor_v3` | §7.5, §9, §12 | **V3 intent.** No legacy `creature_motor` merge or V2 `MotorContext` key reads |
| Blocked-objective chaos | §9 | **V3 intent.** `blocked_objective_chaos` **0.15** ship default (§9) |
| Step 2 inventory template (§12.1) | §12 | **V3 intent.** Disposition + consumers + tests columns |
| Step 6 sub-phases 6a→6d.3 (§12.2) | §12 | **V3 intent.** Execution → hub → live planner → memory (6d.1→6d.2→6d.3) |
| Per-goal `base` + Find shelter scoring | §1, §6.4 | **V3 intent.** `goal_base_*`, `food_map_confidence` |
| Find shelter hub goal | §6.4 | **V3 intent.** Wire `shelter`; MOVE + STAY probe |
| `goal_feasibility_floor_*` epsilon | §1 | **V3 intent.** Per-goal keys; ship default **0.05** |
| Eat urgency calorie bands (V2 numerics) | §1 | **V3 intent.** Keys in `creature_motor_v3` only — same curve shape, **not** V2 motor merge |
| Rest loses in 80–95% band | §1, §6.1 | **V3 intent.** Wound-driven urgency deferred |
| Mate vs Eat numerics | §1, §6.5 | **Deferred** with Mate goal |
| `EAT` per-tick calorie = `STAY` | §7.5 | **V3 intent.** Net positive on completion |
| Flight urgency (`gate_dist` + disposition) | §1, §6.3 | **V3 intent.** Far floor **0.5**; disposition **6d**; `relative_threat_mod` combat |
| Hub eligibility — `build_eligible_goals` (deprecate `tier2_dominance.gd`) | §1 | **V3 intent.** Hub-owned matrix; **delete** module at **6b** |
| Trait stub — delete `trait_tier2_mapper.gd` | §1 | **V3 intent.** Hub `trait_*_mul` constants only; **delete** at **6b** |
| V2 cleanup backlog | §15 | **Tracking** — close at **§12 step 11** |
| Trait channels v1 stub (`trait_goal_mul` / `trait_tactic_mul` = 1.0) | §1 | **V3 intent.** Tactic style deferred; replay in **6d** |

---

## 12. Implementation phases

1. **Kick off refactor** — **Step 1 closed 2026-06-20**
   - [x] Create `Goal_Movement_RefactorV3` branch.
   - [x] Convert this file to `.md` and reformat.
   - [x] Retirement banners on superseded docs → `Completed_Features/`.
   - [x] `PROJECT_DOC_INDEX` row.
2. **Inventory (§12.1)** — **Step 2 closed 2026-06-20** — fill one row per module on the refactor branch; grep consumers and `tests/run_all.gd` before Step 3.
3. Remove code per §12.1 dispositions; empty stubs where noted. **Sibling doc pass (same step):** execute **§12.3.1** + **§12.3.3** checklists; set matching **§13 Tracking** rows to **Done** when sibling files land. Adapter code remains **§12.2 6d**.
   - [x] **Step 3 closed 2026-06-20** — V2 motor modules deleted; `ai_driver.gd` motor stub; `run_all.gd` pruned; sibling sync **§12.3.1** + **§12.3.3**.
4. Address linter errors.
   - [x] **Step 4 closed 2026-06-20** — `check_gdscript_no_tabs.py` clean; Step 3 scripts parse; fixed `world_to_cell` Vector2 type in `run_all.gd`.
5. Run game — **§12 Step 3–5 QA contract** below; no intelligent creature movement expected; fix **non-motor** launch/crash errors only.
   - [x] **Step 5 closed 2026-06-20** — duel launches; no errors; idle creatures + calorie drain (manual smoke).
6. Implement code changes per **§12.2** sub-phases (**6a → 6b → 6c → 6d.1 → 6d.2 → 6d.3**); repeat 6–10 after each sub-phase closes.
7. Address linter errors.
8. Review code against design for gaps, inconsistencies, sibling-doc conflicts.
9. Address issues found.
10. Begin test/bug-fix cycle.

Repeat 6–10 after **each** §12.2 sub-phase closes its acceptance checklist (not only at the end of Step 6).

**Sibling docs:** **§12.3** — four resolved checklists for [CREATURE_MEMORY.md](CREATURE_MEMORY.md) and [CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md) (**§13 Tracking** at Step 3 / before **6d.3** closes).

**Resolved — Step 3–5 QA contract (closes §14.4.4):** Intentional **motor teardown window** after Step 3 until **§12.2** sub-phases restore behavior. Maintainer/tester accepts anticipated limitations; **motor intelligence bugs deferred** to sub-phase checklists where movement is in scope — not triaged as regressions during Steps 3–5.

| Phase | In scope (fix / assert) | Out of scope (expected broken — do not file) |
|-------|-------------------------|---------------------------------------------|
| **Step 3–5** | Project **compiles**; **linter clean**; duel / main scene **launches without crash**; non-motor systems sane (HUD, round flow, vitals drain if still wired); delete or disable V2 motor tests per §12.1 inventory — **`tests/run_all.gd` green for tests still in scope** | Creatures **not** seeking food, fleeing, remembering bushes; idle / `STAY` / stub motor; empty or stale motor debug overlays; “AI feels dumb” |
| **6a** | §12.2 **6a** headless — facing-relative turn/move, `ActionOutcome.blocked`, calorie debit | Hub goals, pathing, live food |
| **6b** | §12.2 **6b** headless — hub `STAY`, eligibility matrix, dual-stack isolation | Live locomotion toward objectives |
| **6c+** | §12.2 **6c** manual smoke — **duel** LoS-visible seek; headless planner slices | Remembered food, memory tiers (**6d**) |

**Step 5 pass criteria:** Launch duel (or main 3D entry), no crash, no error spam — **motor behavior assertions not required**. Creatures may stand still or emit stub actions indefinitely.

**CI / tests:** Remove or skip V2 motor tests at Step 3 with inventory row — **do not** restore V2 seek/cardinal tests to green the branch. New headless gates attach **only** as each **6a→6d** sub-phase closes its checklist.

**Manual duel smoke:** **Deferred until §12.2 6c** (14.2.7). Steps 3–5: optional “loads and runs” sanity only.

**Bug policy:** Infrastructure failures (crash, failed load, broken round start, linter/CI red on in-scope tests) → fix in Steps 3–5. Missed motor logic → acceptable slip-through here; **caught when later sub-phases expect movement** (6a executor, 6c planner, 6d memory).

11. Clean up: Map all deferred features to [Enhancement_Backlog_Plan](../ENHANCEMENT_BACKLOG_PLAN.md), update [Creature_Movement](../Definitive_Features/CREATURE_MOVEMENT.md) to reflect all V3 changes, move this md file to `Project_Docs/Completed_Features/`, and execute **§15 V2 cleanup backlog** — every row **done** or explicitly deferred to backlog with owner. Grep `creature/motor/` and `ai_driver.gd` for remaining V2 preloads (`cardinal_avoidance`, `MotorContext`, `creature_motor` reads in V3 paths) before promotion.

### 12.1 Step 2 inventory template

**Resolved — artifact:** Before Step 3 deletion, maintain a table on the **`Goal_Movement_RefactorV3`** branch (appendix below or sibling `V3_MOTOR_INVENTORY.md` on that branch — register in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) only if promoted to a standalone doc). **One row per `.gd` file** under review, or per **logical subsystem** when a single file spans unrelated concerns (e.g. `ai_driver.gd` motor pipeline — one row, bullet consumers/tests).

**Scope (Step 2 grep):**

| Area | Paths |
|------|--------|
| Motor scripts | `creature/motor/**/*.gd` |
| Orchestrator | `AI_int_lib/ai_driver.gd` (motor pipeline sections) |
| Config merge | `AI_int_lib/game_config_merge.gd` (`creature_motor`, future `creature_motor_v3`) |
| Pack authoring | `assets/creatures/**/pack_resources.json` (`creature_motor` blocks) |
| Body integration | `creature/creature_root_3d.gd`, `creature/capabilities/*.gd` (motor hooks) |
| Tests | `tests/run_all.gd`, `tests/debug_motor_pick.gd`, `tests/motor_path_fixture.gd`, `tests/terrain_test_main_stub.gd` |
| Debug / HUD | `creature/awareness_debug_overlay_3d.gd`, `hud.gd` (motor readouts only) |

**Disposition values:**

| Value | Step 3 action |
|-------|----------------|
| **delete** | Remove file or motor block; no V3 replacement at same path |
| **stub** | Empty/minimal placeholder so compile survives until Step 6 |
| **keep** | Retain as utility; V3 calls directly (e.g. geometry helpers) |
| **adapter** | Retain storage/consult logic; replace V2 **`MotorContext`** merge API with V3 memory adapter (§8.4) |

**Required columns (fill every row):**

| Column | Content |
|--------|---------|
| **Module path** | `res://…` script or named `ai_driver` subsection |
| **Disposition** | `delete` \| `stub` \| `keep` \| `adapter` |
| **Consumers** | Preloaders, callers, scenes, config keys — blast radius for Step 3 |
| **Tests** | Per test: **delete** (V2-only), **port** (reuse under V3), or **replace** (new name TBD in Step 6) |
| **V3 owner / notes** | Target module or § anchor; Step 6 sub-phase if blocked on adapter |

**Alignment:** Inventory **adapter** rows must map to **§12.2 sub-phase 6d**. **delete** rows must have no remaining consumers after Step 3 (or after the §15 **Target phase** column closes). **keep** rows typically land in **6a** (execution) or **6c** (planner). Grep completed **2026-06-20** on branch **`Goal_Movement_RefactorV3`** — **30** scripts under `creature/motor/`, plus orchestrator, config, body, packs, tests (see table + §12.1.1).

**Step 2 inventory (complete — `Goal_Movement_RefactorV3`, 2026-06-20):**

| Module path | Disposition | Consumers | Tests | V3 owner / notes |
|-------------|-------------|-----------|-------|------------------|
| `creature/motor/cardinal_avoidance.gd` | delete | `ai_driver.gd`, `motor_target_builder.gd`, `jeopardy_forced_turn.gd`, `motor_tactic_classifier.gd`, `tests/run_all.gd`, `tests/debug_motor_pick.gd` | delete: `_test_cardinal_avoidance`, `_test_cardinal_interior_env_grid`, `_test_playfield_*` escape, `_test_predator_*` pinch/escape, `_test_herbivore_flee_*`, `_test_food_seek_motor`, `_test_explore_trail_repulsion_motor`, `_test_ne_corner_food_seek_egress`, … | Step 3 — §12.2 **6a** facing-relative MOVE |
| `creature/motor/eight_way_directions.gd` | delete | `cardinal_avoidance.gd`, `expanding_cardinal_explore.gd`, `no_goal_patrol_lock.gd`, `seek_direction_turn.gd`, `jeopardy_forced_turn.gd`, `ai_driver.gd`, `tests/run_all.gd` | delete with cardinal | Step 3 / **§15** #6 |
| `creature/motor/motor_oct_directions.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_seek_oct_directions` | Step 3 — V3 facing-relative (no oct pick) |
| `creature/motor/expanding_cardinal_explore.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_expanding_cardinal_explore`, `_test_predator_patrol_expanding_coverage`, `_test_no_goal_plateau_random` | Step 3 / **§15** #12 |
| `creature/motor/no_goal_patrol_lock.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_no_goal_patrol_lock`, `_test_no_goal_patrol_lock_guided` | Step 3 / **§15** #12 |
| `creature/motor/seek_direction_commit.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_seek_direction_commit` | Step 3 / **§15** #12 |
| `creature/motor/seek_direction_turn.gd` | delete | `seek_direction_commit.gd`, `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_seek_direction_turn`, `_test_seek_diagonal_intent` | Step 3 / **§15** #12 |
| `creature/motor/seek_stationary_look.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_seek_stationary_look` | Step 3 / **§15** #12 |
| `creature/motor/scripted_intent_hold.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_scripted_intent_hold` | Step 3 / **§15** #12 |
| `creature/motor/jeopardy_forced_turn.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_jeopardy_forced_turn` | Step 3 |
| `creature/motor/wall_slide_pick.gd` | delete | `creature_kinematic_body_3d.gd`, `tests/run_all.gd` | delete: `_test_wall_slide_pick` | Step 3 / **§15** #12; body uses `apply_action` **6a** |
| `creature/motor/motor_obstacle_strategy.gd` | delete | `cardinal_avoidance.gd`, `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_obstacle_strategy_shield_pin`, `_test_pinch_obstacle_*` | Step 3 / **§15** #12 |
| `creature/motor/motor_obstacle_geometry.gd` | delete | `cardinal_avoidance.gd`, `ai_driver.gd`, `tests/run_all.gd` | delete: env-grid obstacle tests tied to cardinal; port pure geometry only if navmesh/detour needs | Step 3 / **§15** #12 |
| `creature/motor/terrain_motor.gd` | delete | `cardinal_avoidance.gd`, `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_terrain_physics_cardinal_blocked`, `_test_terrain_stuck_escape_prefers_uphill` | Step 3 / **§15** #12 |
| `creature/motor/goal_visibility_latch.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_goal_visibility_latch_streak_and_engagement` | Step 3 / **§15** #12 |
| `creature/motor/tier2_dominance.gd` | delete | `ai_driver.gd`, `goal_seek.gd`, `trait_tier2_mapper.gd`, `tests/run_all.gd` | delete: `_test_creature_motor_v2_profiles`, `_test_motor_motivation_wiring` (tier2 paths); replace hub eligibility **6b** | §12.2 **6b** — inlined in hub |
| `creature/motor/trait_tier2_mapper.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: stub paths in `_test_motor_motivation_wiring` | §12.2 **6b** — **§15** #2 |
| `creature/motor/motor_tactic_classifier.gd` | delete | `ai_driver.gd`, `goal_source_memory.gd`, `tests/run_all.gd` | delete: tactic build in `_test_motor_motivation_wiring` | §12.2 **6d.2** — **§15** #3 |
| `creature/motor/goal_seek.gd` | delete | `ai_driver.gd`, `motor_target_builder.gd`, `tests/run_all.gd` | delete: `_test_goal_seek_resolve_and_cost`, `_test_food_seek_motor`, `_test_seek_occlusion_step_cost_no_los_ctx` | §12.2 **6c** planner |
| `creature/motor/seek_planner.gd` | delete | `ai_driver.gd`, `tests/run_all.gd` | delete: `_test_seek_planner_replan_interval`, `_test_seek_planner_resolve_disabled_and_no_los` | §12.2 **6b**/**6c** cadence |
| `creature/motor/motor_target_builder.gd` | delete | `ai_driver.gd`, `goal_seek.gd`, `tests/run_all.gd` | delete: `_test_motor_target_builder_feeding_mode`, `_test_plant_occluded_live_food_entries`, `_test_eaten_bush_moves_to_unready_not_seek` | §12.2 **6c** — `awareness_zone` + scan |
| `creature/motor/seek_candidate.gd` | delete | `motor_target_builder.gd`, `goal_belief_memory.gd`, `goal_seek.gd`, `tests/run_all.gd` | delete: V2 seek-candidate merge tests; replace live-sample types **6c** | §12.2 **6c** |
| `creature/motor/carnivore_pursuit.gd` | delete | tests only (`run_all.gd`) | delete: `_test_carnivore_pursuit_intent` | **Deferred** combat — **§15** #15; unused by `ai_driver` |
| `creature/motor/believed_goal_sector.gd` | delete | `goal_source_memory.gd`, `goal_belief_memory.gd`, `blocked_approach_memory.gd`, `seek_direction_turn.gd`, `tests/run_all.gd` | delete: sector align in `_test_creature_motor_v2_profiles`; delete sector locomotion tests | §12.2 **6d** — path-in-direction |
| `creature/motor/goal_belief_memory.gd` | adapter | `ai_driver.gd`, [CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md) | port: `_test_goal_belief_coarse_ttl`; delete: `_test_goal_belief_merge_skips_live_awareness`, `_test_goal_belief_moving_prey_ghost`, `_test_goal_belief_anticipated_calories_stub` (V2 merge) | §12.2 **6d** — storage; drop V2 merge API step 11 |
| `creature/motor/goal_source_memory.gd` | adapter | `ai_driver.gd`, [CREATURE_MEMORY.md §14](CREATURE_MEMORY.md) | port: `_test_goal_source_memory`, `_test_goal_kind_phase_c_replay`, `_test_locale_prior_escalate_seek`; delete V2 `MotorContext` projection tests | §12.2 **6d** |
| `creature/motor/line_of_sight.gd` | keep | `cardinal_avoidance.gd`, `motor_target_builder.gd`, `seek_planner.gd`, `tests/run_all.gd` | port: `_test_line_of_sight_wall_occlusion` | §12.2 **6c** — §3, §8.1 |
| `creature/motor/threat_sample.gd` | keep | `motor_target_builder.gd`, `tests/run_all.gd` (preload) | port where ingest shape unchanged | §1 Flight, §6.3, **6c** scan |
| `creature/motor/blocked_approach_memory.gd` | keep | `cardinal_avoidance.gd`, `ai_driver.gd`, `tests/run_all.gd` | **ported:** `_test_blocked_approach_memory`, `_test_seek_wall_filter_and_backtrack`; `_test_herbivore_food_seek_pinch_escape_backtrack` deferred **6d** | §12.2 **6c** — §3 backtrack TTL |
| `creature/motor/motor_plane.gd` | keep | `ai_driver.gd`, `creature_kinematic_body_3d.gd`, `awareness_debug_overlay_3d.gd`, `environment/nav_path_hint.gd`, `environment/playfield_bounds_3d.gd`, many motor modules | port: `_test_motor_plane_yaw_from_facing`; drop after full Vector3-native V3 paths if redundant | Utility — XZ projection / playfield scale until **6c** zone builder owns geometry |
| `creature/motor/creature_motor_stack.gd` (new) | keep | `creature_root_3d.gd`, `ai_driver` tick loop | replace: per-root tick + dual-stack isolation **6b** | §1 — hub/planner/adapter runtime |
| `creature/motor/awareness_zone.gd` (new) | keep | planner, `awareness_zone_scan` | replace: zone geometry + LoS tests **6c** | §12.2 **6c** — §8.1 |
| `creature/motor/awareness_zone_scan.gd` (new) | keep | planner | replace: live food/threat ingest tests **6c** | §12.2 **6c** |
| `creature/motor/memory_adapter.gd` (new) | keep | hub, planner | replace: adapter consult + write tests **6d.1–6d.2** | §12.2 **6d** — §8.4 façade (reads + writes + §9) |
| `creature/motor/dead_end_memory.gd` (new) | keep | memory adapter | replace: dead-end filter tests **6d.2** | §12.2 **6d.2** — geographic cul-de-sac |
| `creature/motor/blocked_objective_resolver.gd` (new) | keep | motor planner | replace: §9 persist/switch/seek tests **6d.2** | §12.2 **6d.2** — §9 |
| `creature/motor/salient_write_context.gd` (new, optional) | keep | memory adapter, outcome hooks | replace: salient-write gate tests **6d.2** | §12.2 **6d.2** |
| `creature/motor/kind_profile_memory.gd` (new) | adapter | memory adapter | replace: EWMA + neutral prior tests **6d** | §12.2 **6d** — `_kind_profile` |
| `creature/memory/stimulus_learn_registry.gd` (new) | keep | memory adapter, packs | replace: learn-topic registry tests **6d** | §12.2 **6d** |
| `creature/memory/goal_kind_registry.gd` | keep | `ai_driver.gd`, `goal_source_memory.gd`, tests | port: `_test_goal_kind_phase_c_replay` | Taxonomy — **not** tick dominance |
| `AI_int_lib/ai_driver.gd` (motor pipeline) | stub → replace | `main_3d.gd`, creature bodies, HUD, overlay | delete: cardinal/escape/V2 intent tests (§12.1.1); keep `_test_ai_driver_creature_registry` | §12.2 **6b** — thin root tick loop; **§15** #10 |
| `AI_int_lib/ai_driver.gd` — `_mob_hist`, `awareness_memory_*` | delete | `_motor_mobs_array`, overlay ghost path | delete: `_test_goal_belief_moving_prey_ghost`, `_test_predator_prey_memory_chase` (ring-buffer path) | Retired — §8.1 `_goal_belief` ghosts **6d.3** |
| `AI_int_lib/game_config_merge.gd` | keep + extend | packs, `tests/run_all.gd` | port: `_test_creature_motor_v2_profiles`, `_test_creature_pack_motor_overlays` → `creature_motor_v3` **6a** | §12.2 **6a**+; drop unused `awareness_memory_*` defaults Step 3 |
| `assets/creatures/*/pack_resources.json` — `creature_motor` | keep → migrate | fox, rabbit, resolver_smoke | port overlays test **6a** | One-shot copy → `creature_motor_v3` **6a**; remove legacy step 11 |
| `creature/creature_root_3d.gd` | keep | duel spawn, `ai_driver` registry | port: motor stack child wiring **6b** | Owns stack; Body + Vitals refs |
| `creature/capabilities/creature_kinematic_body_3d.gd` | keep | `ai_driver`, duel bodies | port: `_test_creature_kinematic_playfield_clamp_after_move`, human intent tests | §7.4 — deprecate ENGINE `set_creature_move_intent` **6a** |
| `creature/awareness_debug_overlay_3d.gd` | keep | `main_3d`, debug HUD | port when zone builder lands **6c** | Uses `MotorPlane` for draw helpers |
| `hud.gd` (motor readouts) | keep | `main_3d` | port: `_test_hud_resolves_3d_herbivore_motor_body` | Telemetry only — **6b** |
| `tests/run_all.gd` | keep | CI | prune motor tests Step 3 per §12.1.1; add V3 gates per **6a→6d** | Master harness |
| `tests/debug_motor_pick.gd` | delete | manual cardinal debug | n/a | Step 3 |
| `tests/run_motor_motivation_only.gd` | delete | dev wrapper for `_test_motor_motivation_wiring` | n/a | Step 3 — replace **6b** hub tests |
| `tests/terrain_test_main_stub.gd` | keep | `tests/run_all.gd` | extend: `get_navigation_map_rid()` delegate | §3 fixture hook **6c** |
| `tests/motor_path_fixture.gd` (new) | keep | `tests/run_all.gd`, `terrain_test_main_stub.gd` | **ported:** `_test_motor_path_fixture_open_nav`, `_test_motor_path_fixture_blocked_nav` (`agent_radius` 0.25) | §3 — not duel boot |

#### 12.1.1 Motor test disposition (Step 2 grep — `tests/run_all.gd`)

**Step 3 action:** Remove or skip rows marked **delete**; keep **port** until V3 replacement lands in the matching sub-phase.

| Test | Action | V3 sub-phase / notes |
|------|--------|----------------------|
| `_test_cardinal_avoidance` | delete | Step 3 |
| `_test_cardinal_interior_env_grid` | delete | Step 3 |
| `_test_playfield_corner_escape`, `_test_world_corner_static_wedge_escape`, `_test_playfield_open_corner_escape`, `_test_playfield_boundary_edge_rocks` | delete | Step 3 |
| `_test_predator_cover_pin_flank`, `_test_predator_*` pinch/escape/pacing/outward/rim (cardinal) | delete | Step 3 |
| `_test_herbivore_flee_*`, `_test_herbivore_food_seek_pinch_escape_backtrack` | delete | Step 3 |
| `_test_food_seek_motor`, `_test_ne_corner_food_seek_egress`, `_test_explore_trail_repulsion_motor`, `_test_explore_idle_when_no_pickup` | delete | Step 3 |
| `_test_expanding_cardinal_explore`, `_test_no_goal_plateau_random`, `_test_predator_patrol_expanding_coverage` | delete | Step 3 |
| `_test_predator_chase_motor_ctx`, `_test_predator_prey_memory_chase` | delete | Step 3 — mob_hist retired |
| `_test_goal_belief_moving_prey_ghost` | delete | Step 3 — **6d.3** ghost replacement |
| `_test_goal_belief_merge_skips_live_awareness` | delete | Step 3 — V2 merge |
| `_test_goal_seek_resolve_and_cost`, `_test_seek_occlusion_step_cost_no_los_ctx` | delete | Step 3 |
| `_test_motor_target_builder_feeding_mode`, `_test_plant_occluded_live_food_entries`, `_test_eaten_bush_moves_to_unready_not_seek` | delete | Step 3 |
| `_test_creature_motor_v2_profiles`, `_test_motor_motivation_wiring` | delete | Step 3 — **6b** hub eligibility tests |
| `_test_seek_planner_*`, `_test_seek_direction_*`, `_test_seek_oct_directions`, `_test_seek_diagonal_intent`, `_test_seek_stationary_look` | delete | Step 3 |
| `_test_scripted_intent_hold`, `_test_jeopardy_forced_turn`, `_test_no_goal_patrol_lock*` | delete | Step 3 |
| `_test_wall_slide_pick`, `_test_obstacle_strategy_shield_pin`, `_test_pinch_obstacle_*`, `_test_terrain_physics_cardinal_blocked`, `_test_terrain_stuck_escape_prefers_uphill` | delete | Step 3 |
| `_test_goal_visibility_latch_streak_and_engagement`, `_test_carnivore_pursuit_intent` | delete | Step 3 |
| `_test_motor_cardinal_probe_scaled_for_small_playfield` | delete | Step 3 |
| `_test_line_of_sight_wall_occlusion` | **ported** | **6c** — closed 2026-07-02 |
| `_test_blocked_approach_memory`, `_test_seek_wall_filter_and_backtrack` | **ported** | **6c** — closed 2026-07-02 |
| `_test_motor_path_fixture_blocked_nav`, `_test_creature_motor_stack_explore_no_live_food` | **added** | **6c** — `build_blocked` + no-live-food seek |
| `_test_creature_motor_stack_seek_precise_memory`, `_test_creature_motor_stack_seek_coarse_memory`, `_test_creature_motor_stack_seek_locale_prior` | **added** | **6d.1** — memory read consult slices |
| `_test_creature_motor_stack_memory_live_beats_precise`, `_test_creature_motor_stack_memory_tier_precedence`, `_test_creature_motor_stack_memory_dual_isolation`, `_test_creature_motor_stack_memory_feasibility_tiers`, `_test_creature_motor_stack_memory_stale_instance_id` | **added** | **6d.1** — read-contract hardening |
| `_test_creature_motor_stack_memory_live_sync`, `_test_creature_motor_stack_memory_maintain_coarse_ttl`, `_test_creature_motor_stack_memory_eat_locale_write`, `_test_creature_motor_stack_memory_write_dual_isolation` | **added** | **6d.2 slice 0** — live sync, maintain, EAT locale write, write isolation |
| `_test_creature_motor_stack_sated_stay`, `_test_creature_motor_stack_memory_kind_ewma`, `_test_creature_motor_stack_memory_dead_end_filter`, `_test_creature_motor_stack_memory_passibility_switch`, `_test_creature_motor_stack_memory_blocked_objective`, `_test_food_plant_missing_stimulus_kind_id` | **added** | **6d.2** — sated STAY, kind EWMA, dead-end, passibility, §9, spawn gate |
| `_test_goal_belief_coarse_ttl`, `_test_goal_belief_anticipated_calories_stub` | port | **6d** — legacy `ai_driver` path; coarse TTL also covered on adapter |
| `_test_goal_source_memory`, `_test_goal_kind_phase_c_replay`, `_test_locale_prior_escalate_seek`, `_test_escape_reversal_suppression` | port | **6d** |
| `_test_creature_pack_motor_overlays`, `_test_creature_motor_v2_profiles` | port | **6a** → `creature_motor_v3` |
| `_test_ai_driver_creature_registry`, `_test_hud_resolves_3d_herbivore_motor_body` | port | **6b** |
| `_test_motor_plane_yaw_from_facing` | port | keep until `motor_plane` retired |

### 12.2 Step 6 implementation sub-phases

**Resolved — build order:** **6a Execution → 6b Hub shell → 6c Planner (live tier) → 6d.1 Memory reads → 6d.2 slice 0 (adapter writes + migration) → 6d.2 Writes + exceptions → 6d.3 Ghosts + disposition.** Unblocks post–Step 3 playability (§7.4 tick loop), defers highest-coupling memory work until live pathing is baseline. **6d** splits into reviewable sub-phases — each closes its checklist and runs §12 steps **6–10** before the next **6d** sub-phase starts.

<<Comment: **Alternative order (not adopted):** top-down **hub → planner → execution → memory adapter** matches §1→§3→§7 **document section** flow and the three-layer narrative in §11 (“goals → planner → execution”). **Downside:** hub/planner emit `Action`s long before `apply_action` exists — Step 5 “run game” stays broken; facing-relative turn-then-move and `ActionOutcome` → belief loops (§7.6) integrate in one late risky pass. **Memory adapter last** is the same in both orderings.>>

**Per sub-phase:** ship **vertical slices** (smallest end-to-end path first), then expand scope. Close the **acceptance checklist** before starting the next sub-phase.

**Cross-cutting gates (every sub-phase):** linter clean; `tests/run_all.gd` green for tests in scope; §12.1 inventory rows for touched modules updated.

---

#### 6a — Execution

**Closed 2026-06-20** — headless `run_all.gd` green (turn/move/blocked/calorie gates); manual duel smoke (idle + calorie drain).

**Entry:** Step 3 stubs compile; `creature_motor_v3` merge block exists (calorie keys minimum).

**In scope:** §7 — `Action` types, `apply_action`, facing (§7.3), calorie debit (§7.5), `ActionOutcome`, body integration (§7.4). Deprecate ENGINE `set_creature_move_intent` / distance calorie on body (§15 #14). Add **`creature_motor_v3`** merge in `game_config_merge.gd` + **one-shot copy** duel `creature_motor` → `creature_motor_v3` (§12.2 pack migration <<Comment>>); **`OLog`** guard if V3 path reads legacy `creature_motor` (§15 #9).

**Out of scope:** Goal table, pathing, memory, Flight/Rest flows.

**Vertical slices:**

1. `TURN_LEFT` / `TURN_RIGHT` only — facing mutates, zero displacement.
2. `MOVE_FORWARD` / `MOVE_BACKWARD` along facing.
3. `STAY` — no motion; baseline calorie debit.
4. `ActionOutcome.blocked` when `MOVE_FORWARD` hits geometry (squeeze/block).

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | Step 5 complete (game launches; movement may be absent) |
| Headless **required** | Sequenced actions → expected facing, displacement, `blocked` flag; calorie debit per §7.5 |
| Headless **required** | Body no longer applies distance-based calorie burn |
| Manual | Optional — debug harness drives `apply_action` on duel scene |
| Inventory | `cardinal_avoidance` etc. **delete**d; locomotion module **keep**/new under `creature/motor/` |
| Out of scope | Hub, planner, memory adapter |

---

#### 6b pre-flight checklist

<<Comment: Generated from 6a implementation review (2026-06-20). Run **before** starting 6b code; re-run after each 6b vertical slice before closing acceptance.>>

**Purpose:** 6a delivered a **testable execution module** that is **not wired** to the live duel loop. 6b introduces `creature_motor_stack.tick()` and replaces the `ai_driver` motor stub — the highest-risk seam is **one action → one apply → one debit per tick** (§7.4). Fail any **Blocker** row before writing hub code; fail any **Blocker** in **Integration contract** before manual smoke.

##### A — 6a closure (entry gates)

| # | Check | Blocker? |
|---|-------|----------|
| A1 | §12.2 **6a** headless gates green on maintainer machine (`run_all.gd` — turn, move, STAY calorie, blocked, no distance burn, v3 merge/overlays) | **Yes** |
| A2 | `python tools/check_gdscript_no_tabs.py` clean | **Yes** |
| A3 | `LocomotionExecutor`, `MotorAction`, `ActionOutcome` registered / preload paths resolve (no missing-class launch errors) | **Yes** |
| A4 | Duel `pack_resources.json` blocks define **`creature_motor_v3`** (rabbit + fox); legacy `creature_motor` still present only for archived tests until step 11 | No |
| A5 | §12.2 **6a** acceptance row checked in this doc after A1–A3 pass | No — **closed 2026-06-20** |

##### B — Integration contract (§7.4 tick order)

| # | Check | Blocker? |
|---|-------|----------|
| B1 | **Single owner per tick:** `motor_stack.tick()` selects exactly one `Action` → `LocomotionExecutor.apply_action(body, …)` → **no second** horizontal move in the same physics step | **Yes** |
| B2 | **`_physics_process` gating:** When stack owns ENGINE/AI motion, body **does not** re-apply `creature_move_intent` / `apply_horizontal_move_intent` from the deprecated vector path (§7.4 — retire intent vector for ENGINE) | **Yes** |
| B3 | **`set_use_v3_action_calories(true)`** enabled for every ENGINE/AI body before first stack tick (duel spawn or root init) — distance burn in `_apply_calorie_drain_and_starvation` skipped for ENGINE/AI | **Yes** |
| B4 | **One debit per tick:** `debit_action_calories` runs once per applied action; `_physics_process` does **not** also distance-burn when B3 is set | **Yes** |
| B5 | **Playfield clamp:** After executor move, playfield safety net runs (either inside executor post-move hook or once per tick after `apply_action` — must not rely solely on `_physics_process` intent path) | **Yes** |
| B6 | **Gravity / floor:** Non-move actions (`STAY`, `TURN_*`) still allow gravity / floor contact in the same tick if body remains a `CharacterBody3D` step (document chosen approach in stack or body) | No |
| B7 | **`ai_driver`:** Drops per-body `set_creature_move_intent(Vector3.ZERO)` loop for ENGINE subjects; iterates registered **`CreatureRoot3D`** instances and calls **`motor_stack.tick()`** only (§1, §7.4) | **Yes** |
| B8 | Headless **integration test** added: one tick through stack (hub → `STAY`) → single calorie debit, zero duplicate displacement vs baseline-only friction drift | **Yes** |

##### C — Config namespace (`creature_motor_v3` only)

| # | Check | Blocker? |
|---|-------|----------|
| C1 | Stack, hub, and executor read **`GameConfig.get_creature_motor_v3_params_for_pack(pack_root)`** (or equivalent per-spawn merge) — **not** `get_creature_motor_params()` | **Yes** |
| C2 | Body `_refresh_calorie_burn_params()` / food-outcome thresholds migrated to **`creature_motor_v3`** keys where V3 path is active (or stack passes merged dict into body at spawn) | **Yes** |
| C3 | **`OLog` warn-once** if any V3 stack/hub/executor code path reads legacy **`creature_motor`** (§12.2 6a <<Comment>>, §15 #9) | No |
| C4 | `merge_creature_motor_v3_from_legacy` covered by headless test (pack **without** explicit v3 block still merges calorie/awareness keys) | No |

##### D — 6a test debt (close during 6b or before 6c)

| # | Check | Blocker for 6b close? |
|---|-------|------------------------|
| D1 | `MOVE_BACKWARD` displacement + not-blocked on open floor | No |
| D2 | `TURN_LEFT` facing + turn calorie = `move_calorie_per_sec × delta` | No |
| D3 | `REST` calorie = baseline × `rest_baseline_multiplier` × delta | No |
| D4 | `apply_action` without `set_use_v3_action_calories(true)` does **not** double-burn (negative test) | No |
| D5 | Realistic `delta` (e.g. `1/60`) for move/blocked tests — not only `delta=1.0` | No |
| D6 | `ActionOutcome.blocked` false when playfield clamp stops motion without wall contact (document expected behavior) | No |

##### E — Hub / stack scaffolding (6b slice 1)

| # | Check | Blocker? |
|---|-------|----------|
| E1 | `creature_motor_stack.gd` exists; holds hub + cadence shell; **no** cross-creature static state | **Yes** |
| E2 | `CreatureRoot3D` owns one stack instance; duel registers two roots → **dual-stack isolation** headless test passes | **Yes** |
| E3 | Hub slice 1: empty / stub table → **`STAY`** every tick; calories drain at baseline only (manual smoke) | **Yes** |
| E4 | **`tier2_dominance.gd`** + **`trait_tier2_mapper.gd`** deleted; eligibility matrix lives in hub module | **Yes** (before 6b close) |
| E5 | Flight fast-path **stub** (flag only) — no full flee geometry until 6c/6d | No |

##### F — Manual smoke (6b; not Step 5)

| # | Expected | Failure signal |
|---|----------|----------------|
| F1 | Duel launches; no crash | Error spam, failed load |
| F2 | Creatures **idle** (`STAY`); no pursuit / seek | Movement toward food or prey |
| F3 | Calories drain at **baseline** rate (~1 cal/s per §7.5 defaults), not distance-based | Burn tracks sliding / jitter without stack actions |
| F4 | No duplicate motion (visual slide or speed 2×) | Body moves on `STAY` ticks |

**Sign-off:** Maintainer checks all **Blocker = Yes** rows in **A**, **B**, **E1–E3**, and **C1–C2** before marking §12.2 **6b** acceptance closed.

---


#### 6b — Hub shell

**Closed 2026-07-01** — hub module, consideration cadence, per-root [code]creature_motor_stack[/code], [code]AiDriver[/code] root iteration; eligibility + scoring; vertical slice wired through stack (planner deferred to **6c** until close).

**Implementation started 2026-06-20** — hub module, consideration cadence, per-root [code]creature_motor_stack[/code], [code]AiDriver[/code] root iteration; 6b vertical slice emits [code]STAY[/code] only (planner deferred to **6c**).

**Entry:** 6a acceptance closed. Complete **§12.2 6b pre-flight checklist** (all Blocker rows) before first hub/stack commit.

**In scope:** §1 hub entry (including **`trait_goal_mul = 1.0`** / **`trait_tactic_mul = 1.0`** — no `trait_tier2_mapper`), §10 cadence shell, `ActiveGoal` table, empty-table → `STAY` (§7.2), wire **`CreatureRoot3D` → `creature_motor_stack.tick()`** (§1, §7.4); `ai_driver` iterates roots only. Flight fast-path **stub** (flag only). Hub **`build_eligible_goals`** + eligibility matrix (§1); **delete** [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd) and [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd). **Flight urgency geometry** ships in 6b; **`threat_disposition_mod`** stubbed **1.0** until **6d**. **`creature_motor_v3`** merge wired — V3 paths **must not** read legacy **`creature_motor`** (§15). **§1 goal scoring closed** (§13).

**Out of scope:** Movement toward objectives, memory tiers, full Rest/Flight/Mate (§6), **`replay_weight`** / trait tactic style (§6d / deferred).

**Vertical slices:**

1. Hub always returns `STAY`; tick loop wired end-to-end.
2. Empty goal table → `STAY` each tick (§7.2).
3. Observation cadence fires consideration; table can hold one stub `find_food` goal (no locomotion yet).
4. Flight fast-path flag preempts table (no-op or `STAY` until 6c/6d).

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | 6a closed |
| Headless **required** | Hub entry returns exactly one `Action`/call; empty table → `STAY` |
| Headless **required** | Consideration cadence advances on tick count (§10 formula or stub `n`) |
| Headless **required** | Hub eligibility matrix (§1): starvation → Eat-only; sub-acute Flight competes on `weight`; port tier2 parity cases from `tests/run_all.gd` |
| Headless **required** | Dual-root fixture — two `creature_motor_stack` instances return distinct actions; no cross-creature state bleed (§1) |
| Manual **smoke** | Duel creatures idle (`STAY`); no crash; calories drain at baseline |
| Inventory | `ai_driver` motor pipeline **stub → replace** with root **`motor_stack.tick()`** loop; **`tier2_dominance.gd`** + **`trait_tier2_mapper.gd` deleted**; **`creature_motor_stack.gd`** + **`creature_root_3d.gd`** wiring |
| Blocker note | §13 spec-complete — all rows **Closed**, **Deferred**, or **Tracking** (see §13) |

---

#### 6c — Planner (live tier)

**Closed 2026-07-01** — [code]awareness_zone.gd[/code], [code]awareness_zone_scan.gd[/code], [code]motor_planner.gd[/code], [code]motor_path_clear.gd[/code]; stack binds hub winner → turn/move/EAT; headless gates in [code]tests/run_all.gd[/code] + [code]tests/motor_path_fixture.gd[/code]. **6c headless checklist gaps closed 2026-07-02** — backtrack port, `build_blocked` nav assert, explore-without-food stack slice; harness leak cleanup (`ai_driver` fixture `free()`, goal-belief orphan `free()`).

**Entry:** 6b acceptance closed.

**In scope:** §3 movement + seek trees, §8.1 **live** zone / movement weighing (objective **in awareness** with LoS). **Greenfield** §8.1 zone builder (sphere + cone + LoS) — **not** [`motor_target_builder.gd`](../../creature/motor/motor_target_builder.gd) diet forks. Reuse **keep** [`line_of_sight.gd`](../../creature/motor/line_of_sight.gd), [`threat_sample.gd`](../../creature/motor/threat_sample.gd), `blocked_approach_memory.gd`, navmesh detour (§3). **Delete** `motor_target_builder.gd`, `seek_candidate.gd` when zone builder lands. **Live targets only** — **no occluded-in-zone ghosts**, no `_goal_belief` / `LocalePriorMap` / kind EWMA writes. **§6.2:** awareness ingest includes **`stimulus_kind_id`**; live food ranking uses kind consult with **neutral** priors. **Headless:** ship [`tests/motor_path_fixture.gd`](../../tests/motor_path_fixture.gd) at **6c slice 1** (§3 fixture contract).

**Resolved — adopt `awareness_zone.gd`** for sphere + cone + LoS geometry (§8.1). **Split live ingest:** food/threat scene scan in a separate module — [`awareness_zone_scan.gd`](../../creature/motor/awareness_zone_scan.gd) — so geometry stays stable as scan logic grows. Planner imports both; zone builder owns geometry only. Inventory at **6c** slice 1.

**Out of scope:** Precise/coarse remembered targets (§8.2–8.3), locale prior hotspots, §9 blocked-objective memory layers, Rest phase machine, full Flight exit, **Find shelter** belief tiers (§6.4 → **6d**).

**Vertical slices:**

1. **Eat + live bush only** — turn toward visible food, `MOVE_FORWARD` when aligned.
2. Clear-path LoS + corridor sweep (§3); blocked → detour or backtrack TTL.
3. No live food → generic **Seek** (unexplored heuristic §3 / Definitions §9).
4. `ActionOutcome.blocked` → planner notes failure (§7.6); backtrack via `blocked_approach_memory.gd` only — **no** geographic dead-end persist (§3 **B** deferred to **6d**).
5. Movement Weighing “known dead-ends?” branch → treat as **no** until **6d**.

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | 6b closed |
| Headless **required** | Live target fixture → planner emits turn/move sequence toward objective — `_test_creature_motor_stack_seek_live_food` |
| Headless **required** | Blocked approach / backtrack behavior (port or replace §12.1 tests) — `_test_blocked_approach_memory`, `_test_seek_wall_filter_and_backtrack` |
| Headless **required** | Seek when no live objective (no memory consult) — `_test_creature_motor_stack_explore_no_live_food` |
| Headless **required** | §3 **motor_path_fixture** — valid `map_rid` + nav path assert before navmesh-first slices; **`build_blocked`** for backtrack slice — `_test_motor_path_fixture_open_nav`, `_test_motor_path_fixture_blocked_nav` |
| Manual **smoke** | Duel creature seeks **LoS-visible** shrub; pursuit movement plausible with live prey in zone only |
| Inventory | `goal_seek`, `seek_planner`, cardinal modules **delete**d; **`motor_target_builder.gd`** **delete**d; **`awareness_zone.gd`** + **`awareness_zone_scan.gd`** + planner added per §3; **`tests/motor_path_fixture.gd`** added |
| Out of scope | Remembered food, coarse bearing, §9 exceptions, **occluded-in-zone ghosts** |

---

#### 6d — Memory adapter (6d.1 → 6d.2 → 6d.3)

**Entry:** 6c acceptance closed; live planner is baseline.

**Why three sub-phases:** **6d.1** validates **read-only** consult (remembered seek) without write-side or ghost coupling. **6d.2** adds **learning writes**, §9 exceptions, and kind EWMA — depends on stable reads from **6d.1**. **6d.3** adds **occluded-in-zone ghosts**, disposition, and shelter beliefs — highest coupling to Safety / Flight / `REST`; needs kind threat plumbing from **6d.2**. After **each** sub-phase closes, run §12 steps **6–10** before starting the next.

**Shared scope (lands across 6d.1–6d.3):** §8.4 **memory adapter** façade — [`memory_adapter.gd`](../../creature/motor/memory_adapter.gd) only public entry (§8.4 Option A); no V2 `MotorContext` merge. **Retire** legacy **`_mob_hist`** / **`awareness_memory_*`** mob ghost path by **6d.3**. **`sector_weights` locomotion** retired (§8.3); stop calling `believed_goal_sector` from adapter. **Delete** [`motor_tactic_classifier.gd`](../../creature/motor/motor_tactic_classifier.gd); salient writes use **`SalientWriteContext`** at outcome time (§12.3.4). Trait tactic style deferred; **`replay_weight`** consult only. V2 projection methods on `goal_*_memory` — **no V3 callers** after adapter lands; **delete** dead methods at **§12 step 11** (**§15** #7).

---

##### 6d.1 — Memory reads (precise + coarse + locale)

**Headless closed 2026-07-02** — [code]memory_adapter.gd[/code] read façade on [code]CreatureMotorStack[/code]; planner consults precise → coarse → locale when no live food. Headless gates: [code]_test_creature_motor_stack_seek_*_memory[/code], [code]_test_creature_motor_stack_seek_locale_prior[/code], and read-contract tests [code]_test_creature_motor_stack_memory_*[/code] (live precedence, tier order, dual-stack isolation, feasibility tiers, stale [code]instance_id[/code]).

**Sign-off note:** Duel **manual smoke** (remembered-food seek without test seeding) is **unblocked** after **6d.2 slice 0** — run before closing slice 0 sign-off.

**In scope:** §8.2 precise instance belief consult; §8.3 coarse path-in-direction; `LocalePriorMap` / `replay_rank_score` consult in seek cycle (§3, §9). **Read-only** — no EWMA writes, no geographic dead-end persist, no ghosts.

**Out of scope:** §9 blocked-objective persist/switch/seek writes; kind `record_observation`; occluded-in-zone ghosts; `threat_disposition_mod`; shelter belief writes; live sighting sync; `goal_belief_memory.maintain()`; migrating [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) `_goal_belief_by_body` / `_goal_source_memory_by_body` (→ **6d.2 slice 0**).

**Vertical slices:**

1. **Precise** instance belief — seek remembered bush outside awareness (§8.2).
2. **Coarse** bearing — path-in-direction when precise envelope lost (§8.3).
3. **Locale prior** — pattern / hotspot consult in seek cycle (§3, §9).

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | 6c closed |
| Headless **required** | Precise belief fixture → movement without live LoS to remembered coords |
| Headless **required** | Coarse tier → bearing-only locomotion (not GPS `ultimate_pos`) |
| Headless **required** | Locale prior row → seek bias / alternate target ranking |
| Headless **required** | Live ready food beats precise memory consult |
| Headless **required** | Consult tier precedence: precise → coarse → locale |
| Headless **required** | Dual-stack memory isolation (distinct beliefs / step goals) |
| Headless **required** | Hub `find_food` feasibility matches §1 tier table |
| Headless **required** | Stale `instance_id` on precise row — no crash; locomotion stays valid |
| Manual **smoke** | Duel remembered-food seek — **ready for sign-off** after **6d.2 slice 0** headless gates |
| Inventory | [`memory_adapter.gd`](../../creature/motor/memory_adapter.gd) read paths wired; hub/planner import adapter only — storage via internal delegates |
| Out of scope | Writes, §9 exception layers, ghosts, disposition, slice 0 migration |

**After close:** §12 steps **6–10**; then **6d.2 slice 0** (not full 6d.2 until slice 0 closes).

---

##### 6d.2 — Writes + kind + dead-ends + §9

**Entry:** 6d.1 headless acceptance closed.

**Do not start** §9 / kind EWMA / dead-end slices until **6d.2 slice 0** headless checklist is green — **slice 0 headless closed 2026-07-02**; full slice 0 sign-off awaits duel manual smoke.

#### 6d.2 slice 0 — Adapter writes + store migration (do first) {#6d2-slice-0--adapter-writes--store-migration-do-first}

**Headless closed 2026-07-02** — [`memory_adapter.gd`](../../creature/motor/memory_adapter.gd) `sync_after_scan`, `maintain_beliefs`, `notify_food_consumption_outcome`, `reset`; wired from [`creature_motor_stack.gd`](../../creature/motor/creature_motor_stack.gd) each tick. V3 ENGINE EAT routes via [`creature_root_3d.gd`](../../creature/creature_root_3d.gd) → stack (not `ai_driver` when `_motor_stack_drives_physics`). Session reset clears stack adapters from [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) `_goal_belief_reset_all`. **Slice 0 closed 2026-07-02** — sated idle `STAY` when hub weights ≈ 0 (§7.2); precise arrival tolerance stops in-place jitter.

**Purpose:** Make memory **observable in duel** before layering §9 exception logic, kind profiles, and dead-end marks. Closes the dual-store gap: V3 ENGINE paths must not read or write [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) `_goal_belief_by_body` / `_goal_source_memory_by_body` (§1, §8.4 hard rules).

**In scope:**

| # | Deliverable | Spec anchor |
|---|-------------|-------------|
| S0.1 | **Live sighting sync** — after awareness scan, adapter writes `_goal_belief` from `food_split` (and threat samples when applicable) via `goal_belief_memory.sync_from_scene` / `sync_from_threat_samples` | §8.4 write table |
| S0.2 | **`maintain()` each tick** — TTL, forget radius, PRECISE→COARSE promotion on stack-owned beliefs | [CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md), §8.3 |
| S0.3 | **EAT / salient write routing** — `notify_food_consumption_outcome` (or stack outcome hook) writes to **this creature’s** adapter `goal_source_memory`, not `ai_driver` dict | §6.2, §8.4 |
| S0.4 | **Retire V3 ENGINE reads of driver memory dicts** — grep-clean: stack adapter is sole belief/locale store for [`CreatureRoot3D`](../../creature/creature_root_3d.gd) motor tick | §1, §15 #10 |
| S0.5 | **Duel manual smoke** — creature sees bush, loses LoS, seeks remembered coords (no test seed) | 6d.1 deferred gate |

**Out of scope for slice 0:** §9 persist/switch/seek branches; `record_observation` / kind EWMA; dead-end geographic marks; `SalientWriteContext`; §12.3.2 locale consult rewrite (may start in parallel but not a slice-0 blocker).

**Vertical slice:**

0. **See → remember → seek** — live food in awareness populates adapter; after leaving awareness, planner uses precise/coarse consult without headless seeding.

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | 6d.1 headless closed |
| Headless **required** | Live scan tick → `_goal_belief` row exists on stack adapter (no manual seed) — `_test_creature_motor_stack_memory_live_sync` |
| Headless **required** | `maintain()` evicts / downgrades row when outside precise envelope + TTL exceeded — `_test_creature_motor_stack_memory_maintain_coarse_ttl` |
| Headless **required** | EAT outcome → locale row on **stack** store (not `ai_driver` `_goal_source_memory_by_body`) — `_test_creature_motor_stack_memory_eat_locale_write` |
| Headless **required** | Dual-root: belief rows isolated per stack — `_test_creature_motor_stack_memory_write_dual_isolation` |
| Manual **smoke** | Duel remembered-food seek after brief LoS contact — **code-ready**; maintainer duel sign-off optional |
| Inventory | V3 ENGINE tick path: stack adapter sole store; `notify_food_consumption_outcome` on body uses root stack when `_motor_stack_drives_physics` |

**After close:** §12 steps **6–10**; then **6d.2** slices 4–6 (§9, dead-ends, kind). **Slice 0 closed 2026-07-02.**

---

**Full 6d.2 scope (after slice 0):**

**Headless closed 2026-07-02** — [`kind_profile_memory.gd`](../../creature/motor/kind_profile_memory.gd), [`dead_end_memory.gd`](../../creature/motor/dead_end_memory.gd), [`blocked_objective_resolver.gd`](../../creature/motor/blocked_objective_resolver.gd), [`stimulus_learn_registry.gd`](../../creature/memory/stimulus_learn_registry.gd). Adapter writes: `record_observation`, dead-end marks, `passibility_fail_count`; live food ranked by kind `nutrition_yield`; §9 persist/switch/seek on blocked locomotion; `stimulus_kind_id` spawn gate on [`main_3d.gd`](../../main_3d.gd) + [`bush_food_3d.gd`](../../assets/plants/bush_food_3d.gd).

**In scope:** §9 blocked-objective persist/switch/seek (locale + instance + **kind** layers + `blocked_objective_chaos`). **Dead-end** geographic marks (`_dead_end_marks_by_body`) + **instance passibility** on `_goal_belief` (§3). **`_kind_profile`** + **`record_observation`** + learn-topic registry — `nutrition_yield` on EAT ([CREATURE_MEMORY.md §5.7](CREATURE_MEMORY.md)). **`stimulus_kind_id`** spawn gate enforced at food placement (§6.2). **Rename `*_px` config keys** to world-unit names during MEMORY / pack pass (e.g. `believed_goal_hotspot_near_radius_px` → `believed_goal_hotspot_near_radius`) — §12.3.2.

**Out of scope:** Occluded-in-zone ghosts; `threat_disposition_mod`; shelter instance beliefs; Flight kind `threat_danger` episodes.

**Vertical slices:**

4. **§9** — inaccessible objective uses locale + instance + **kind** memory layers + `blocked_objective_chaos`.
5. **Dead-end consult** — geographic filter on edge waypoints (§3); instance `passibility_fail_count` on switch (§9).
6. **Kind profile** — EAT updates `nutrition_yield`; live ranking + §8.3 replace consult (§6.2).

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | 6d.1 closed; **6d.2 slice 0** closed |
| Headless **required** | §9 branch: persist vs switch vs seek with stub memory fixtures (locale + instance + kind) — `_test_creature_motor_stack_memory_blocked_objective` |
| Headless **required** | Kind profile EWMA: EAT observation updates `nutrition_yield`; consult changes live ranking — `_test_creature_motor_stack_memory_kind_ewma` |
| Headless **required** | Dead-end mark → edge waypoint filtered; `passibility_fail_count` → switch bias — `_test_creature_motor_stack_memory_dead_end_filter`, `_test_creature_motor_stack_memory_passibility_switch` |
| Headless **required** | Missing `stimulus_kind_id` at food spawn → no spawn + `OLog.error` (§6.2) — `_test_food_plant_missing_stimulus_kind_id` |
| Inventory | Adapter **write** paths for instance sync, `record_observation`, dead-end marks; slice 0 migrates ENGINE memory off `ai_driver` |
| Sibling | Begin **§12.3.2** MEMORY pass (locale consult rewrite; `*_px` rename) — deferred; world-unit keys already in `game_config_merge` defaults |
| Out of scope | Ghosts, disposition, shelter beliefs |

**After close:** §12 steps **6–10**; then **6d.3**. **6d.2 headless closed 2026-07-02.**

---

##### 6d.3 — Ghosts + disposition + shelter

**Entry:** 6d.2 acceptance closed.

**In scope:** §8.1 **occluded-in-zone ghost** read projection (§8.4). **`threat_disposition_mod`** read/write on benign vs evade events (§1 — per-creature, not locale rows). **`shelter`** instance beliefs + Find shelter probe outcomes (§6.4). Flight disposition + **`kind_threat`** on samples (§1, §6.3). Salient writes unchanged — planner reads via adapter. **Retire** `_mob_hist` / `awareness_memory_*` mob ghost path.

**Out of scope:** `sector_weights` locomotion; neighbor-search refinement (skills); Mate/Fight (§6.5–6.6).

**Vertical slices:**

7. **Flight disposition + kind threat** — benign-exposure vs evade nudges to `threat_disposition_mod`; `kind_threat` on samples (§1).
8. **Occluded-in-zone ghosts** — **`danger_filter`** + shelter / food consults (§8.1, §8.4); threat ghosts affect Safety / Flight / REST; live-wins dedupe; mover reach cap; static non-threat zone-only expiry.

**Acceptance checklist:**

| Gate | Criterion |
|------|-----------|
| Entry | 6d.2 closed |
| Headless **required** | Occluded-in-zone **threat ghost** fixture → Safety / Flight / REST danger without live LoS; mover reach-cap eviction; live LoS clears ghost |
| Headless **required** | `threat_disposition_mod` nudges after benign vs evade fixtures |
| Headless **required** | Shelter belief write on successful Find shelter probe (§6.4) |
| Manual **smoke** | Duel remembered-food seek; occluded threat behind cover blocks Safety / REST when ghost active |
| Inventory | V2 merge tests **delete**d; `_mob_hist` path **delete**d |
| Sibling | Complete **§12.3.2** + **§12.3.4** before closing **6d.3** |
| **6d complete** | All **6d.1–6d.3** checklists green |

<<Comment: Headless test matrix — sub-phase checklists above are v1 gates; expand species rows after §1 scoring closes. Do not inherit V2 Phase 3 advance-gate checklist unless re-adopted explicitly.>>

**Resolved — config namespace (`creature_motor_v3`):** All V3 movement, planner, locomotion, and exception tuning keys live in a **new** pack-root inline object **`creature_motor_v3`** (same authoring pattern as V2 `creature_motor`, **separate merge block**). V3 runtime **does not** merge or alias legacy **`creature_motor`**, V2 **`MotorContext`** key names, or POST_LOS-prefixed motor keys — greenfield modules read **`creature_motor_v3` only** so old cardinal / tier-2 paths are not implied dependencies.

**Resolved — one-shot copy at 6a.** Copy duel `creature_motor` → `creature_motor_v3` in the same commit that wires V3 merge; **do not** dual-author both blocks during transition. V3 runtime reads **`creature_motor_v3` only**. Legacy `creature_motor` may remain in packs for archived V2 tests until **§12 step 11**, then **remove** legacy blocks entirely. At **6a**, add an **`OLog`** guard (e.g. warn once if any V3 code path reads legacy `creature_motor` keys) to catch stray reads while debugging mid-transition behavior.

- **V3-owned examples:** §7.5 calorie keys, §1 **`goal_feasibility_floor_*`** + Eat urgency band keys + **Flight urgency / disposition / `kind_threat` clamp keys** + **`flight_acute_panic_radius`**, §8.1 **`awareness_radius` / `awareness_cone_extra` / `awareness_cone_half_angle_deg` / `los_eye_height` / `los_blocked_occlusion_fraction` / `awareness_requires_los`**, §6.1 **`safe_site_*`** rest-site scoring keys, §9 **`blocked_objective_chaos`** (ship default **0.15**), §10 **`goal_replan_base_ticks`** (ship default **8**) + **`goal_consideration_chaos`** (ship default **0.15**), §7 **`turn_increment_deg`** (ship **22.5**) + per-action **`action_max_distance`** (EAT ship **5**), §6.2 **`unknown_kind_multiplier`**, detour toggles (e.g. **`detour_score_competition`**, replacing `post_los_detour_score_competition` intent).
- **Memory storage keys** (`goal_*`, `believed_goal_*`, **`kind_profile_*`** — [CREATURE_MEMORY.md §10](CREATURE_MEMORY.md)) remain the **MEMORY sibling** contract for belief / locale-prior / **kind-profile** **storage and TTL**; V3 consumes them through the **memory adapter** (§8.4) in **§12.2 6d**, not by reusing V2 motor merge codepaths or V2 pack motor weights.

### 12.3 Sibling doc rework (single-pass checklists)

V3 owns the **planner interface**; **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** owns **storage / TTL / salient-write gates**; **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)** owns **motivation tree, `GoalKind` registry, strategy-class replay math**. Neither sibling gets a ground-up schema rewrite for V3 v1 — retire **V2 `MotorContext` → cardinal** consumption paths and align cross-links. **§12.3.1–§12.3.4** are **resolved implementation checklists** — apply to sibling files during the gated step; flip **§13 Tracking** rows to **Done** when each pass lands in git.

| Pass | When | Target doc | §13 tracking |
|------|------|------------|--------------|
| **12.3.1** | §12 **step 3** (with code teardown) | `CREATURE_MEMORY.md` | Step 3 |
| **12.3.2** | Before **6d.3** acceptance closes | `CREATURE_MEMORY.md` | 6d |
| **12.3.3** | §12 **step 3** | `CREATURE_GOAL_DRIVERS.md` | Step 3 |
| **12.3.4** | Before **6d.3** acceptance closes | `CREATURE_GOAL_DRIVERS.md` | 6d |

**Do not edit** sibling docs for V3-only motor keys (`creature_motor_v3`, `Action`, hub scoring) beyond cross-links — those stay in this file.

#### 12.3.1 CREATURE_MEMORY.md — Step 3 pass

**Resolved — sibling sync checklist (apply §12 step 3):** One edit session on `CREATURE_MEMORY.md` alongside code teardown. Defer §14.1 full rewrite to **§12.3.2**.

**Resolved — `_goal_belief` LRU (`merge_use_count` / `last_merged_ms`):** **Deprecated** for V3 — do not increment on adapter consult. Cap eviction uses **lowest `last_observed_ms`** per **§8.4** above. MEMORY §5.4 / §5.5 schema table: mark both fields **V2 compat, unused**; update `_goal_belief_maintain` narrative accordingly. Code: stop writes in `goal_belief_memory.gd` at Step 3 or **6d** when maintain path is ported.

**Header / authority (replace V2-primary framing):**

- Top **Motor / motivation alignment** blurb: primary motor authority = **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** (ENGINE scripted creatures); cite **CREATURE_MOVEMENT_V2** only as archived / superseded context. **This doc** = storage + TTL + salient-write gates; consult = **V3 memory adapter** ([§8.4](CREATURE_MOVEMENT_V3) here), **not** per-tick **`MotorContext`** merge.
- **§1 One-line objective** + **Explicit non-authority:** drop “projecting into **`MotorContext` `believed_goal_*`**” as the primary consume story; point to **§8.4 adapter** + **§14** storage.
- **§1 Phase-1 scope table:** update **Ships** row — moving beliefs / ghost projection ship under V3 **6d** (not “stub moving beliefs”); **LoS** = mandatory for live ingest per V3 §8.1 (retire “LoS deferred this round” in §1 non-goals / §7.4 deferral note where it contradicts V3).
- **§1 Out of scope:** keep MMO persistence etc.; remove implication that ENGINE motor is still V2 Foundations.

**§2 / §4 narrative (retire cardinal consume diagram):**

- **§2 layer table** row “Goals and motivational priorities”: replace **`SeekCandidate` / threat samples fuse into motor merge** with **hub consideration + planner ingest** (V3 §1, §10); Tier-2 leaves still per **GOAL_DRIVERS §2**.
- **§2.1 mermaid:** replace `facade → Tier2_cardinal_scorer` with `LocalePriorMap → V3_memory_adapter → planner` (ExperienceRing optional branch unchanged).
- **§2.1 “Framework contract”** bullets citing **CREATURE_MOVEMENT_V2 §A.3.1** as live motor: cross-link **V3 §8.4** + **§9** for consult; note **`believed_goal_source_bias`** façade is **retired for locomotion** (locale consult via **`replay_rank_score`** — detail **→ 12.3.2**).
- **§4 Approved phasing:** replace “ENGINE movement Foundations = `MotorContext` + `SeekCandidate[]`” with **V3 §12** (6a→6d); memory adapter **6d** after live planner **6c**.

**§5 Belief tiers (storage unchanged; consume path updated):**

- **§5.2 Coarse tier:** keep egocentric **bearing** definition for **stored** rows; **remove** “8-way step bias / motor cost” and **`believed_goal_source_bias.sector_weights`** increment narrative (**GB-MG1**). State: V3 planner derives **path-in-direction** at **read time** ([CREATURE_MOVEMENT_V3 §8.3](CREATURE_MOVEMENT_V3)); **do not** write sectors into storage.
- **§5.4 Re-awareness:** zone definition = **V3 §8.1** (sphere ∪ eye-anchored 3D cone + **mandatory LoS**); cross-link **CREATURE_MOVEMENT_V3 §8.1**, not **CREATURE_MOVEMENT_V2 §E.1** alone.
- **§5.5 `_goal_belief`:**
  - **`last_world_pos` / `last_velocity`:** document **`Vector3`** façade (world units); note 2D projection at ingest boundary if code still uses plane helpers.
  - **Occluded-in-zone ghosts (Option A):** add subsection mirroring V3 §8.1 + **§8.4 consult filters** — one projector, **`danger_filter`**, **`consult_shelter_beliefs`**; mover **reach cap**; **`ghost_strength`**; intercept hint `last_world_pos + last_velocity × goal_memory_ghost_horizon_sec` for pursuit geometry only.
  - **Retire narrative:** `_mob_hist`, `awareness_memory_*`, ring-buffer mob ghosts — superseded by **`_goal_belief`** ghost projection (**6d** code).
  - **Phase E “Motor merge shape (Q4)”:** mark **superseded** — no `SeekCandidate` / `pursuit_targets` merge from memory; V3 adapter returns consult records for planner. Keep **storage fields** (`is_moving`, `last_velocity`, etc.).
- **§5.5 functions** (`_goal_belief_sync_from_scene`, `_goal_belief_maintain`): remove steps that call **`project_believed_goal_bias`** or increment **sector_weights**; point to **adapter** ownership (V3 §8.4 write table). **LRU at cap:** **lowest `last_observed_ms`** (§8.4); do not reference **`merge_use_count`**.

**§8 Context for agents:**

- **§8.1–8.2** read order: insert **CREATURE_MOVEMENT_V3** before or replacing V2 as motor authority.
- **§8.3** (already partial): ensure it states V3 supersedes V2 **merge**; list **§§5.5, 5.6, 5.7, 10, 14** as stable storage.

**§8.4 Planner consumption:**

- Confirm read/write tables match **V3 §8.4** (including **occluded-in-zone ghost consult filters** — **`danger_filter`**, **`consult_shelter_beliefs`**, **`consult_danger_samples`**).
- **6c / 6d phasing** rows: match V3 §8.4 “6c stubs” bullet.

**§10 Config (Step 3 slice only):**

- Add note: **`goal_*` / `believed_goal_*` / `kind_profile_*`** remain MEMORY-owned; **motor tuning** for V3 lives in **`creature_motor_v3`** ([CREATURE_MOVEMENT_V3 §12](CREATURE_MOVEMENT_V3)).
- Mark **`weight_coarse_sector_goal_bias`** and **`believed_goal_source_bias` sector channel** as **retired for V3 locomotion** (may remain documented for LLM/debug until removed — **→ 12.3.2** for §14.1 full rewrite).

**Changelog:** one **§15** row dated implementation pass — “V3 Step 3 sibling sync (§12.3.1).”

#### 12.3.2 CREATURE_MEMORY.md — 6d pass (before 6d.3 closes)

**Resolved — sibling sync checklist (apply before 6d.3 closes):** One edit session when wiring memory adapter (**§12.2 6d.2–6d.3**). Blocks **6d.3** acceptance until sibling file matches this list.

**Resolved — `*_px` key rename (implementation step):** During **6d.2** code + MEMORY doc pass, rename config keys that use misleading **`_px`** suffix to **world-unit** names (values unchanged unless a literal px→world conversion is required). Example: **`believed_goal_hotspot_near_radius_px` → `believed_goal_hotspot_near_radius`**. Update pack merge, consult code, and §10 MEMORY tables in the same change set. Grid **`cell_x` / `cell_y`** remain logical grid indices — not renamed.

**§14 Locale priors — consult path (replace cardinal projection):**

- **§14.1 `believed_goal_source_bias` projection:** rewrite for **adapter consult**, not **`MotorContext`** + **`cardinal_avoidance.gd`**:
  - **Keep:** row storage (`cell_x`, `cell_y`), **`replay_rank_score`**, top-N (**3**), hotspot radius **`believed_goal_hotspot_near_radius`** (renamed from `*_px`), **`locale_prior_pull_w_norm`**, **`weight_believed_goal_pull`** as **planner consult** scalars (not per-tick 8-way cost terms).
  - **Retire:** **`sector_weights[8]`** build from coarse beliefs; **`weight_coarse_sector_goal_bias`** cardinal loop; “append to **`food_seek_targets`**” merge language.
  - **Add:** **Coarse instance beliefs** — planner reads **bearing** = `normalize(last_world_pos − creature_pos)` per **V3 §8.3** (storage unchanged).
  - **Add:** **`replay_weight`** applies at **planner / memory consult** (V3 §9, §1) — **multiplicative on locale ranking / seek bias**, **not** hub `weight`; cross-link **GOAL_DRIVERS §5.1** (updated in **§12.3.4**).
  - **Threat / escalate:** §14.3 threat-response ordering — rebind “first threat pass” to **V3 Flight fast-path / hub** (not cardinal flee term).
- **§14.1 Implementation hooks:** `goal_source_memory` exposes **adapter consult APIs**; delete references to **`cardinal_avoidance.gd`** reading façade.

**§14.4 Salient writes:**

- Emitter still **`goal_source_memory.try_salient_write`**; caller becomes **V3 hub/planner outcome hook** (not `_build_motor_context`). **`context_hash`** compositors unchanged for phase-1 `find_food` / `avoid_hostiles`.
- **`MotorContext` tactic classifier** input **→ 12.3.4** (GOAL_DRIVERS owns replacement contract).

**§5.6 / §5.7:** confirm consult + write tables match implemented adapter (dead-end filter, `record_observation`, `threat_danger` on Flight episodes).

**§10:** remove or strike **`weight_coarse_sector_goal_bias`** from active motor table if §14.1 retired; move Preserve/Find calorie band **reads** to **`creature_motor_v3`** cross-link (keys may remain in merge for non-V3 tools until pack cleanup).

**Acceptance:** grep `CREATURE_MEMORY.md` for `MotorContext`, `cardinal_avoidance`, `SeekCandidate` merge, `sector_weights` — each hit is **archived**, **retired**, or **adapter** wording.

#### 12.3.3 CREATURE_GOAL_DRIVERS.md — Step 3 pass

**Resolved — sibling sync checklist (apply §12 step 3):** One edit session on `CREATURE_GOAL_DRIVERS.md` alongside code teardown.

**Header / read order:**

- **Purpose** footer: motor / scorer / phasing authority = **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** for ENGINE creatures; **CREATURE_MOVEMENT_V2** = superseded draft (archive banner when promoted).
- **Read order** line: `… → CREATURE_MOVEMENT_V3 (motor) → CREATURE_MEMORY …` (drop V2 as required read for implementers).

**§1 Non-scope:** replace “`creature_motor` thresholds (**CREATURE_MOVEMENT_V2 §A.2–A.3.1**)” with **`creature_motor_v3`** + V3 §1 hub scoring.

**§2 Motivation tree:**

- Intro: remove “costs in the **cardinal scorer**” as the **implementation** anchor; keep tree as **semantic** priority model; integration = **V3 hub consideration** + hub **`build_eligible_goals`** (§1) — **not** `tier2_dominance.gd` ([CREATURE_MOVEMENT_V3 §1](CREATURE_MOVEMENT_V3)).
- **§2 table “Implemented today”:** replace V2 bullets (`SeekCandidate`, patrol lock, cardinal explore, **§E.1** without LoS) with **V3 v1 snapshot** — hub goals (Eat, Flight, Rest, Find shelter), consideration cadence (§10), Flight fast-path, **`goal_kind_registry`**, live ingest = V3 §8.1 zone + LoS. Mark prey chase / carnivore pursuit **deferred** unless already shipped elsewhere.
- **Jeopardy / starvation:** keep numeric cross-refs but cite **`creature_motor_v3`** keys (`starvation_override_food_ceiling`, etc.) aligned with V3 §1.

**§6 Cross-links authority table:**

| Topic | Authority |
|-------|-----------|
| ENGINE motor, planner, execution, phasing | **CREATURE_MOVEMENT_V3** |
| `creature_motor` / cardinal / `MotorContext` merge (historical) | **CREATURE_MOVEMENT_V2** (archived) |
| Storage, `goal_*`, locale priors §14 | **CREATURE_MEMORY.md** |
| Motivation tree, `GoalKind`, strategy-class §5 | **This file** |

- **Identifiers** footnote: motor wires memory via **V3 adapter** (not “per CREATURE_MOVEMENT_V2”).

**§3.3.1 / §3.4:** confirm trait Tier-2 stub + “post-stub” coefficients still accurate; note **`trait_goal_mul = 1.0`** at hub (V3 §1) — no GOAL_DRIVERS formula change required.

**Changelog:** one row — “V3 Step 3 sibling sync (§12.3.3).”

#### 12.3.4 CREATURE_GOAL_DRIVERS.md — 6d pass (before 6d.3 closes)

**Resolved — sibling sync checklist (apply before 6d.3 closes):** One edit session when wiring salient-write + memory consult paths. Blocks **6d.3** acceptance until sibling file matches this list.

**§5.1 Replay consume path (align with V3 §1 / §9):**

- **`replay_weight` motor integration:** replace “multiplicative on **`weight_believed_goal_pull`** / cardinal **`weight_seek_*`**” with **planner-only consult** — locale prior ranking (§9 persist/switch/seek), detour/seek cycle (V3 §3), **not** hub consideration `weight`. **`change_stability`** remains **only** inside **`replay_rank_score`** (V3 §9 resolved).
- **Hotspot / escalate:** rebind **CREATURE_MOVEMENT_V2 §A.3.1** bullets to **V3 §3 seek cycle** + MEMORY §14.1 adapter consult (post-§12.3.2).

**§5.1.1 Salient episode emitter:**

- **Caller:** V3 outcome hooks (Eat complete, Flight exit, Find shelter probe, etc.) — not `ai_driver._build_motor_context`.
- **Replace `MotorContext` parameter** with **`SalientWriteContext`** ([§8.4](CREATURE_MOVEMENT_V3)) carrying:
  - active **`GoalKind`** wire id,
  - dominant Tier-2 at outcome (for write gates),
  - **tactic classifier flags** (below) — optional stub `{}` until tactic style lands,
  - food-anchor **`Vector3`** (or plane projection),
  - merged **`creature_motor_v3`** (or global config slice) for gate thresholds,
  - per-instance allowlists unchanged.
- **Tactic classifier flags (phase 1):** preserve **GOAL_DRIVERS §5.1.1 flag ids** (`tactic_jeopardy_egress`, `hide_hold_still`, …) but document **producer** = V3 planner/hub **`SalientWriteContext`** snapshot at outcome time, **not** [`motor_tactic_classifier.gd`](../../creature/motor/motor_tactic_classifier.gd) on `MotorContext`. Until detectors ship: **`tactic_classifier_active = false`** → default modality inference per `GoalKind` (existing table). **Delete** `motor_tactic_classifier.gd` at **6d.2** (**§15**).

**Resolved — defer through V3 v1.** Ship **`tactic_classifier_active = false`** and empty tactic-flag map on **`SalientWriteContext`** at **6d.2**; salient writes use default modality inference per `GoalKind` (GOAL_DRIVERS §5.1.1 table). **Do not** reimplement squeeze/hide corridor detectors in planner or hub for v1. Post–V3: revisit navmesh-corridor squeeze + hide-viable detectors when tactic style lands ([ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — post–V3 trait tactic modulator).
- **`emitter_knows_modality`:** redefine as **`SalientWriteContext.tactic_classifier_active`** (same semantics).
- Delete “Cardinal / motor code may set **`MotorContext`** tactic flags” — **planner / hub** sets context at outcome time only.

**§5.1.2–5.1.5 / §5.1 combine:** scan for **`MotorContext`** / cardinal / `weight_seek_*` — reword to **adapter consult** or cite V3 §9.

**§2 live awareness:** cross-link **CREATURE_MOVEMENT_V3 §8.1** (sphere ∪ cone + LoS) instead of **V2 §E.1** alone.

**Acceptance:** grep `CREATURE_GOAL_DRIVERS.md` for `MotorContext`, `cardinal`, `CREATURE_MOVEMENT_V2 §A.3` as **live** authority — each hit archived or redirected to V3 / MEMORY adapter.

---

## 13. Outstanding decisions index

**Spec-complete rule:** Every row below is **Closed**, **Deferred**, or **Tracking**. **Closed** / **Deferred** = design decided. **Tracking** = checklist in **§12.3** — apply during implementation; set **Done** when the sibling file pass lands. Nothing in **§13** blocks Step 1 kickoff.

| Topic | Marker location | Blocker? | Status |
|-------|-----------------|----------|--------|
| Goal scoring — per-goal `base` | §1 | — | **Closed** |
| Find shelter goal + scoring | §1, §6.4 | — | **Closed** |
| Goal scoring — `feasibility_floor` | §1 | — | **Closed** |
| Goal scoring — Eat urgency bands | §1 | — | **Closed** |
| Goal scoring — Flight urgency | §1, §6.3 | — | **Closed** |
| Goal scoring — Rest weights | §1 | — | **Closed** |
| Goal scoring — Mate vs Eat | §1, §6.5 | No | **Deferred** |
| Goal scoring — hub eligibility (single control plane) | §1 | — | **Closed** |
| Goal scoring — trait channels v1 | §1, §15 #2 | — | **Closed** — delete `trait_tier2_mapper` at **6b** |
| Post–V3 trait tactic modulator | §1, [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) | No | **Deferred** — post–V3 v1; module vs config keys |
| Dead-end geographic memory schema | §3 | — | **Closed** |
| Safe location signal weights | §6.1 | — | **Closed** |
| Eat — kind vs instance ingest + adapter | §6.2, §8.4 | — | **Closed** |
| Kind memory — trait confidence modulation | §6.2, §1 | No | **Deferred** |
| EAT variable bite / pool / sharing | §6.2 | No | **Deferred** (plants) |
| `EAT` calorie cost | §7.5 | — | **Closed** |
| Awareness sphere + 3D cone + LoS | §8.1 | — | **Closed** |
| Ghost mapping contract | §8.1 | — | **Closed** |
| MEMORY adapter vs storage split | §8.4 | — | **Closed** |
| Memory adapter façade — `memory_adapter.gd` + `SalientWriteContext` | §8.4 | — | **Closed** — Option A; hub/planner import adapter only |
| V2 projection method delete policy | §8.4 | — | **Closed** — delete at §12 step 11 when grep clean; no `@deprecated` stubs |
| Zone builder — `awareness_zone.gd` + scan split | §12.2 **6c** <<Comment>> | — | **Closed** |
| Pack `creature_motor` → `creature_motor_v3` migration | §12.2 <<Comment>> | — | **Closed** — one-shot copy at **6a**; `OLog` guard; remove legacy at step 11 |
| Squeeze/hide tactic flags (v1) | §12.3.4 <<Comment>> | — | **Closed** — `tactic_classifier_active = false` through v1 |
| `ai_driver` extraction boundary | §15.3 <<Comment>> | — | **Closed** — thin façade; **`creature_motor_stack`** per root |
| Per-creature motor stack ownership | §1 | — | **Closed** — `creature_motor_stack.gd` on `CreatureRoot3D`; closes §14.2.5 |
| Step 3–5 QA contract (expected broken motor) | §12 | — | **Closed** — launch/no-crash only; motor bugs deferred to **6a→6d** |
| Flight acute panic radius key | §1 | — | **Closed** — `flight_acute_panic_radius` default **220.0** |
| Headless path fixture (navmesh + LoS scope) | §3 | — | **Closed** — `tests/motor_path_fixture.gd`; duel = manual only |
| `blocked_objective_chaos` default | §9 | — | **Closed** |
| `goal_replan_base_ticks` default | §10 | — | **Closed** |
| §11 POST_LOS row re-validation | §11 | — | **Closed** |
| `_goal_belief` LRU — deprecate `merge_use_count` | §8.4, §12.3.1 | — | **Closed** — cap eviction = lowest `last_observed_ms`; no consult-frequency retention v1 |
| MEMORY sibling sync (Step 3) | §12.3.1 | Step 3 | **Done** — 2026-06-20 Step 3 pass |
| MEMORY sibling sync (6d) | §12.3.2 | 6d.3 | **Tracking** — apply before 6d.3 acceptance closes |
| GOAL_DRIVERS sibling sync (Step 3) | §12.3.3 | Step 3 | **Done** — 2026-06-20 Step 3 pass |
| GOAL_DRIVERS sibling sync (6d) | §12.3.4 | 6d.3 | **Tracking** — apply before 6d.3 acceptance closes |
| §15 V2 cleanup backlog | §15 | §12 step 11 | **Tracking** — all rows **done** or backlog-deferred before promotion |
| Shared `_goal_belief` consult filters | §8.4 | — | **Closed** |
| Config namespace `creature_motor_v3` | §12 | — | **Closed** |
| Headless / playtest gates | §12.2 | — | **Closed** (per sub-phase) |
| Doc promotion (`.md`, index, archive V2) | §12 step 1 | No | **Closed** — Step 1 **2026-06-20** |
| §12.1 module inventory | §12.1 | — | **Closed** — Step 2 **2026-06-20** |
| Human control cadence | §7.6 | No | **Deferred** |
| Mate goal flow | §6.5 | No | **Deferred** |
| Fight goal flow | §6.6 | No | **Deferred** |
| Neighbor search refinement (skills) | §8.3 | No | **Deferred** |
| Clear-path squeeze skill-check | §3 | No | **Deferred** |
| `SPRINT` calorie cost | §7.5 | No | **Deferred** |
| Combat fast-path / attack action | §10 | No | **Deferred** |
| REST healing (combat) | §6.1 | No | **Deferred** |
| Flight `relative_threat_mod` (opponent matchup) | §1, §6.6 | No | **Deferred** |
| Trait tactic style (implementation) | §1 | No | **Deferred** |

---

## 15. V2 cleanup backlog (reduce cruft)

**Purpose:** Single register of V1/V2 motor dependencies to retire so V3 stays on one control plane (same pattern as §1 **`tier2_dominance.gd` delete**). **Close every row** at **§12 step 11** before promoting this doc to `Completed_Features/`. Update **§12.1** inventory when disposition changes.

**Status legend:** `pending` = not started | `in_progress` = sub-phase active | `done` = deleted or V3 replacement shipped | `deferred` = explicit backlog entry required

**Difficulty:** **Low** = small module / few callers | **Medium** = critical-path or cross-module | **High** = architectural boundary

### 15.1 Cleanup candidates

| # | Module / concern | Action | Target phase | Difficulty | Why |
|---|------------------|--------|--------------|------------|-----|
| 1 | [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd) | **delete** — logic in hub `build_eligible_goals` | **6b** | Low | ~50-line if-ladder; dual control with hub weights (§1) |
| 2 | [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) | **delete** — hub `trait_*_mul = 1.0` | **6b** | Low | Stub; maps `dom_leaf` → channels; no v1 behavior |
| 3 | [`motor_tactic_classifier.gd`](../../creature/motor/motor_tactic_classifier.gd) | **delete** — `SalientWriteContext` at outcomes | **6d.2** | Medium | `MotorContext` coupling; preload of cardinal for squeeze |
| 4 | [`motor_target_builder.gd`](../../creature/motor/motor_target_builder.gd) | **delete** — greenfield §8.1 zone builder | **6c** | Medium | Cardinal + diet forks; on live-ingest critical path |
| 5 | [`seek_candidate.gd`](../../creature/motor/seek_candidate.gd) | **delete** — V3 live-sample types in zone builder | **6c** | Low | Data shape tied to deleted builder |
| 6 | [`believed_goal_sector.gd`](../../creature/motor/believed_goal_sector.gd) + [`eight_way_directions.gd`](../../creature/motor/eight_way_directions.gd) | **delete** locomotion use | **6d** | Low–Med | §8.3 path-in-direction replaces `sector_weights` |
| 7 | `goal_belief_memory` / `goal_source_memory` V2 **projection API** | **delete** dead projection/merge methods — storage kept | **6d** → **step 11** | Med–High | Façade = `memory_adapter.gd` (§8.4); **delete** V2 API at step 11 when grep clean — no `@deprecated` stubs |
| 8 | [`cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd) + eight-way stack | **delete** | Step 3 | Low | Already §12.1; largest V2 surface |
| 9 | **`creature_motor`** config namespace | **ban** V3 reads; packs add **`creature_motor_v3`**; **remove** legacy block at **§12 step 11** | **6a**+ | Medium | One-shot copy at **6a**; `OLog` guard on stray V3 reads; no dual-author |
| 10 | [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) motor pipeline | **thin loop** — iterate roots, call `motor_stack.tick()` | **6b** | High | No `_…_by_body` motor state on driver; stacks on root (§1) |
| 11 | `_mob_hist` / **`awareness_memory_*`** | **delete** | Step 3 → **6d.3** | Low | Replaced by `_goal_belief` ghosts (§8.1) |
| 12 | Cardinal satellites (`expanding_cardinal_explore`, `no_goal_patrol_lock`, `seek_direction_*`, `scripted_intent_hold`, `wall_slide_pick`, `motor_obstacle_*`, `terrain_motor`, `goal_visibility_latch`) | **delete** with Step 3 / cardinal | Step 3 | Low | No V3 consumer after `ai_driver` stub |
| 13 | [`goal_seek.gd`](../../creature/motor/goal_seek.gd), [`seek_planner.gd`](../../creature/motor/seek_planner.gd) | **delete** | Step 3 / **6c** | Low | V2 seek; replaced by hub + planner |
| 14 | Body [`set_creature_move_intent`](../../creature/capabilities/creature_kinematic_body_3d.gd) ENGINE path | **deprecate** for ENGINE — `apply_action` only | **6a** | Medium | Human adapter may keep intent path |
| 15 | [`carnivore_pursuit.gd`](../../creature/motor/carnivore_pursuit.gd) | **delete** or backlog-isolate | **Deferred** | Low | Combat deferred (14.2.9) |

### 15.2 Keep (not cleanup targets)

| Module | Role |
|--------|------|
| [`line_of_sight.gd`](../../creature/motor/line_of_sight.gd) | Pure LoS utility (§3, §8.1) |
| [`threat_sample.gd`](../../creature/motor/threat_sample.gd) | Shared threat shape (§1 Flight, ingest) |
| [`blocked_approach_memory.gd`](../../creature/motor/blocked_approach_memory.gd) | Backtrack TTL (§3) |
| [`motor_plane.gd`](../../creature/motor/motor_plane.gd) | XZ projection / playfield scale helpers — retain until V3 paths fully native 3D |
| [`goal_kind_registry.gd`](../../creature/memory/goal_kind_registry.gd) **`parent_tier2`** | Memory taxonomy — not tick dominance |
| [`memory_adapter.gd`](../../creature/motor/memory_adapter.gd) (new) | §8.4 façade — **only** public entry for hub/planner memory I/O |
| [`salient_write_context.gd`](../../creature/motor/salient_write_context.gd) (new, optional split) | **`SalientWriteContext`** write-side payload — §12.3.4 |
| [`awareness_zone.gd`](../../creature/motor/awareness_zone.gd) (new) | §8.1 zone geometry + LoS — not live scan |
| [`awareness_zone_scan.gd`](../../creature/motor/awareness_zone_scan.gd) (new) | Live food/threat scene scan — split from geometry |
| [`creature_motor_stack.gd`](../../creature/motor/creature_motor_stack.gd) (new) | Per-creature hub + planner + adapter runtime — **`tick()`** entry |

### 15.3 Open decisions (<<Question>> index)

| Topic | Where decided | Blocks |
|-------|---------------|--------|
| Post–V3 trait modulator (module vs config keys) | [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) | Post–V3 v1 — **deferred** |
| Squeeze/hide tactic detectors (post–v1) | §12.3.4 <<Comment>> | Post–V3 v1 — **deferred** |

**Resolved — `ai_driver` extraction (§15.3):** **Keep in `AI_int_lib/ai_driver.gd`:** LLM round loop, pack/creature registry, perception snippets for AI, HUD/debug telemetry hooks, **root registration + tick loop**. **Live on each [`CreatureRoot3D`](../../creature/creature_root_3d.gd):** [`creature_motor_stack.gd`](../../creature/motor/creature_motor_stack.gd) — hub, planner state, memory adapter delegate, orchestrates shared utils (`awareness_zone.gd`, executor). **`ai_driver`** calls **`root.motor_stack.tick()`** per ENGINE subject — **no** motor state dictionaries on the driver. Confirm wiring at **6b**.

### 15.4 Acceptance (§12 step 11)

- [ ] Every **§15.1** row **`done`** or **`deferred`** with [ENHANCEMENT_BACKLOG_PLAN](../ENHANCEMENT_BACKLOG_PLAN.md) entry
- [ ] `grep` / inventory: no V3 code preloads **`cardinal_avoidance`**, **`tier2_dominance`**, **`trait_tier2_mapper`**, **`motor_tactic_classifier`**, **`motor_target_builder`**
- [ ] No V3 runtime read of **`creature_motor`** keys; legacy pack blocks **removed** (V2 tests migrated or removed)
- [ ] **`goal_*_memory`** V2 projection/merge methods **deleted** — grep confirms zero callers (V3 adapter + V2 tests migrated/removed); no `@deprecated` stubs
- [x] **§12.1** inventory complete — every `creature/motor/**/*.gd` row filled (**Step 2 — 2026-06-20**)

---

## 14. Spec review backlog (critical review)

**Purpose:** Capture gaps, tensions, and open assumptions before / during implementation. Promoted items live in the authoritative body (§1–§12) and **§13 Closed**. Items here do **not** block Step 1 kickoff unless promoted to §13.

**Status legend:** `open` = needs decision or spec edit | `accepted` = intentional as-is | `deferred` = backlog / process | `done` = promoted into spec

### 14.1 Challenge the requirements

| # | Item | Status | Notes |
|---|------|--------|-------|
| 14.1.1 | **Facing-relative + one action/tick** — up to **8** turn ticks for 180° before `MOVE_FORWARD` (§7.3); threats close every tick. | `accepted` | Product bet vs V2 single-tick cardinal pick |
| 14.1.2 | **Dual control on goals** — hub `weight` scoring (§1) **and** `tier2_dominance.gd` eligibility + acute overrides. | `done` | §1 — hub **`build_eligible_goals`**; **delete** `tier2_dominance.gd` at **6b** |
| 14.1.3 | **`safety_time` in consideration cycles**, not physics time. | `accepted` | §1, §6.1, §10 — intentional |
| 14.1.4 | **6d scope** — split into reviewable sub-phases. | `done` | §12.2 **6d.1 → 6d.2 → 6d.3** |
| 14.1.5 | **Traits stubbed** but **replay** ships at **6d** — habitual via locale priors first. | `accepted` | §1 — intentional v1 |
| 14.1.6 | **File promotion to `.md` + index** | `done` | §12 step 1 — **2026-06-20** |

### 14.2 Unconfirmed assumptions

| # | Assumption | Risk if wrong | Status |
|---|------------|---------------|--------|
| 14.2.1 | Every species pack gets **`creature_motor_v3`** merge block at **6a** | Wrong / missing keys at runtime | `done` — §12.2 pack migration <<Comment>>; one-shot copy + `OLog` guard |
| 14.2.2 | **`stimulus_kind_id`** required on food spawn (§6.2) | Kind ranking / EWMA noop | `done` |
| 14.2.3 | **Navmesh RID valid** in duel + headless (§3) | 6c CI slices fail without fixtures | `done` — §3 minimal **`motor_path_fixture`**; duel navmesh unchanged |
| 14.2.4 | **`stat_observation` clamp min 10** until pools land (§10) | Same replan cadence early | `accepted` |
| 14.2.5 | Hub **“no explicit parameters”** reads correct per-body state | Wrong creature / stale awareness | `done` — §1 **`creature_motor_stack`** per [`CreatureRoot3D`](../../creature/creature_root_3d.gd) |
| 14.2.6 | **2D `*_px` keys** in **3D** motor | Wrong consult radii | `done` | §12.3.2 — rename at **6d.2** |
| 14.2.7 | **Duel scene** sufficient manual smoke | Complex flows need harness | `accepted` | §12 Step 3–5 QA — duel motor smoke **from 6c**; load-only before |
| 14.2.8 | **§12.3 Tracking** sibling passes on schedule | Sibling drift during **6d** | `accepted` | |
| 14.2.9 | **Carnivore prey chase deferred**; moving beliefs + ghosts ship **6d.3** | Half predator–prey | `accepted` | |
| 14.2.10 | **Acute fast-path** — `gate_dist ≤ flight_acute_panic_radius` | Implementers guess threshold | `done` — §1 keys table; default **220.0** |
| 14.2.11 | **`arrival_tolerance` / interaction range** undefined | Step completion ambiguous | `done` | §7.2 **`action_max_distance`** — EAT **5** |
| 14.2.12 | **Facing alignment** before `MOVE_FORWARD` | Turn/move flip-flop | `done` | §7.3 — MOVE within 1× turn increment + turn-direction hysteresis; EAT keeps 0.5× |

### 14.3 Edge cases (under-specified)

| # | Edge case | Status | Promoted to |
|---|-----------|--------|-------------|
| 14.3.1 | **LoS threshold split** (60% vs 80%) | `done` | §3, §8.1 — **80%** unified (`los_blocked_occlusion_fraction`) |
| 14.3.2 | **Flight fast-path vs `safety_time`** | `done` | §6.3, §10 — counter continues during Flight |
| 14.3.3 | **Pending Safety timing** (`safety_time × n` physics ticks) | `done` | §1, §6.1 |
| 14.3.4 | **Goal consideration ties** | `done` | §10 — **`goal_consideration_chaos` 0.15** |
| 14.3.5 | **Threat ghost + live same hostile** dedupe | `done` | §8.1 — live wins |
| 14.3.6 | **Empty table vs `feasibility_floor` rows** | `done` | §7.2, §10 |
| 14.3.7 | **Turn-only under acute threat** | `done` | §7.3, §10 — Flight preempts turn chain |
| 14.3.8 | **Path following algorithm** (navmesh → turn/move) | `done` | §3 — facing-relative path follow |
| 14.3.9 | **§161 typo** in old 6d slice 3 | `done` | §12.2 — fixed to §3 |
| 14.3.10 | **90–95% calorie ecology** | `done` | §1, §6.1, §7.2 — Eat urgency 0; Rest ≥95%; else **`STAY`** if no winner |

### 14.4 Constraints that make implementation harder than it looks

| # | Constraint | Status | Notes |
|---|------------|--------|-------|
| 14.4.1 | **Sibling split + fat 6d adapter** | `done` | §12.2 **6d.1–6d.3** split |
| 14.4.2 | **`tier2_dominance.gd` reuse** vs V3 acute threat | `done` | §1 — sub-acute = `urgency_flight`; acute = fast-path; module **delete** at **6b** |
| 14.4.3 | **`ai_driver.gd` choke point** | `done` | §15 #10 + §1 — root tick loop; motor state on **`creature_motor_stack`** |
| 14.4.4 | **Step 3–5 “expected broken”** QA | `done` | §12 Step 3–5 QA contract — motor out of scope until **6a→6d** |
| 14.4.5 | **Headless + navmesh + LoS** harness scope | `done` | §3 fixture — navmesh required; LoS optional via fixture collision; detour fallback separate test |
| 14.4.6 | **Shared `_goal_belief`** consult filters (shelter vs threat ghosts) | `done` | §8.4 — one projector, **`danger_filter`**, shelter / food / goal consults |
| 14.4.7 | **Config sprawl** across pack namespaces | `done` | §15 #9 — `creature_motor_v3` only in V3 paths |

### 14.5 In good shape (no action unless review disagrees)

- Phasing **6a → 6b → 6c → 6d.1 → 6d.2 → 6d.3** with vertical slices per sub-phase.
- Layer split: hub / planner / executor / memory adapter — **one stack per [`CreatureRoot3D`](../../creature/creature_root_3d.gd)** (§1).
- §13 **Closed** for motor numerics; sibling sync **Tracking** only.
- Dead-end three-way split; kind vs instance memory; coarse path-in-direction.
- §11 ledger + Step 3 dispositions + **§15** cleanup register.

### 14.6 Highest-value fixes — status

| Priority | Item | Status |
|----------|------|--------|
| 1 | Unify **LoS 80%** | `done` — §3, §8.1 |
| 2 | **`action_max_distance`** + **facing alignment** | `done` — §7.2–7.3 |
| 3 | **`safety_time` during Flight** | `done` — §6.3, §10 |
| 4 | **`panic` / acute fast-path threshold** | `done` — §1 `flight_acute_panic_radius` **220.0** |
| 5 | **Goal consideration tie-break** | `done` — §10 |
| 6 | **`*_px` rename** | `done` — §12.3.2 |
| 7 | **Split 6d** | `done` — §12.2 |
| 8 | **Single control plane** — hub eligibility; deprecate `tier2_dominance.gd` | `done` — §1, §12.1, **6b** |
| 9 | **V2 cleanup backlog** | `tracking` — §15; close at **§12 step 11** |












