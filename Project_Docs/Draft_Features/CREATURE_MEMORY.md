# Hunter Killer — Creature memory (agent-friendly)

> **Purpose:** **Authoritative working spec** for **creature memory** — what an agent **stores** about the world so it can pursue [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) **goals** (survival, reproduction, trait-shaped priorities). Memory entries should **map to goals**, not arbitrary fluff: **danger**, **food**, **mates**, **shelter / rest sites**, etc. Seemingly separate systems (e.g. **shelter**) still **roll up to goals**: a future **rest** mechanic should **reward** safe, comfortable places and **penalize** unsafe or unpleasant ones, tying rest location memory to **survival** and long-term fitness. **This doc phase** focuses on **food** first; other categories stay specified at outline level until their features land. **Location:** `Draft_Features/` while design stabilizes; **promote** to `Definitive_Features/` when contract vs code (see [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md)). **Live code notes:** [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) (`_food_belief` block), [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd). **Extraction:** Food-memory detail from [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) (former §9).

---

## 1. Phase summary

**Phase name:** Creature memory (goal-aligned beliefs; **food** tranche first)

**One-line objective:** Specify **what** creatures remember to serve **goals**, how **diet archetype** (**predator** / **omnivore** / **herbivore**) changes motivation and remembered targets, and how **food beliefs** extend live awareness (**precise** + **coarse** tiers, no omniscient seek). **Implement in order:** **predator (prey) calorie path** and **movement-based calorie costs** **before** expanding food-source memory and herbivore bush memory in code (see **§3**).

**Out of scope (explicit non-goals):**  
- Full utility-AI or MMO-scale persistence.  
- Replacing live `food_plants` awareness with memory-only (memory **merges after** live sense).  
- Gender / full `CreatureStats` field catalog (stay in [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)).  
- **Shelter / rest** implementation in this phase—only **design alignment** with goals (§2).

---

## 2. What memory is for (goal-aligned categories)

Creature memory is a **working set of salient world facts** keyed to [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) **Goals and motivational priorities** — not a dump of every seen object.

| Category | ties to goals | This phase |
|----------|----------------|------------|
| **Danger** | Primary: survival | Outline + awareness overlap (mobs, hazards); dedicated memory schema **later**. |
| **Food** | Primary: survival; compassion / hoarding ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §4) | **In scope** — §5 tables + config. |
| **Mates / reproduction** | Secondary: reproduce | Outline; locations / state **later**. |
| **Shelter / rest** | Primary: survival (recovery, safety); comfort modulates **reward** | **Not implemented** yet; **design rule:** rest sites must eventually integrate with “safe vs unsafe” and **goal weights**, so shelter memory is not a disconnected mini-game. |

**Diet archetype (`feeding_mode` or equivalent — name TBD in code)** modulates **what** is “food,” **seek vs avoid** weights, and which memory slots matter most:

| Archetype | Food seek / memory emphasis | Notes |
|-----------|----------------------------|--------|
| **Herbivore** | Plants / `food_plants`; weaker or no prey tracking | Aligns with current bush POC; prey **not** food. |
| **Omnivore** | Plants **and** prey / carrion when rules exist | Needs both plant and animal memory channels when implemented. |
| **Predator** | Prey (mobs, future fauna), not bushes as primary calories | **Requires** predator calorie intake from prey (or equivalent) **before** herbivore-style bush memory is the main nutritional story for that species. |

<<Question: Single enum on `CreatureStats` vs per-species config in `game_config.json`?>>

---

## 3. Implementation order (requirements)

**Do this first (prerequisite to treating memory + foraging as complete for mixed diets):**

1. **Predator / prey calorie path** — Creatures labeled **predator** (or species with prey-eligible diet) must gain **calories from prey** interaction (or documented stand-in) per a phase that references this plan; bush-only calories are **insufficient** for predator UX truth.  
2. **Movement-based calorie costs** — Locomotion consumes **`current_calories`** (or a dedicated exertion pool) beyond the current flat **time-based** drain ([HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md)); e.g. cost **per distance** or **per tick while moving**, tunable in `creature_motor` / vitals merge. Aligns with [PLANTS_PLAN.md](PLANTS_PLAN.md) **Action cost (future)** once formalized here.

**Then** (same plan or follow-on PRs tied to this doc):

3. **Food-source memory** (§5) — `_food_belief_*`, merge after live awareness, precise/coarse tiers.  
4. Extend memory slots for **danger**, **mates**, **shelter** as their systems land.

<<Comment: Until (1) and (2) land, ENGINE motor may remain **herbivore-oriented** with global hunger drain; document exceptions in the implementing PR.>>

---

## 4. Context for agents

**Key scripts (paths):**  
- [`AI_int_lib/ai_driver.gd`](../../AI_int_lib/ai_driver.gd) — `_motor_food_plants_in_awareness_by_readiness`, `_build_motor_context`; future `_food_belief_*`.  
- [`AI_int_lib/game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd) — planned `food_memory_*` keys (commented today).  
- [`creature/motor/cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd) — food seek weights vs mobs.  
- [`assets/plants/bush_food.gd`](../../assets/plants/bush_food.gd) — stationary bush `global_position`; belief key = instance id.

**Existing specs:**  
- [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) — `passible`, `fit_size`, squeeze **Mode A** (see **§6**).  
- [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) — grid / `can_enter` vs motor memory.  
- [Completed_Features/HUNGER_AND_EATING.md](../Completed_Features/HUNGER_AND_EATING.md) — POC eating / mob plant beliefs (archive; cite if task requires).

---

## 5. Food-source memory (design — not fully implemented)

**Goal:** Remember discovered food after it leaves the awareness cone — without omniscient seek.

| Tier | Condition (baseline) | Representation | Motor use |
|------|----------------------|----------------|-----------|
| **Precise** | Remembered bush (or player-food) and `distance(creature, last_world_pos) ≤ food_memory_precise_radius_px` (**1000** px default) | Exact `Vector2` + last-known ready/unready (`is_pickup_ready_for_motor` **frozen** until target re-enters awareness — same idea as mob plant beliefs in hunger archive §4.11) | Merge into `food_seek_targets` / unready lists ([`ai_driver.gd`](../../AI_int_lib/ai_driver.gd), [`cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd)) |
| **Coarse** | Still remembered but farther than precise radius | **Egocentric** 8-way sector recomputed **each tick** from `last_world_pos - creature_pos`: N, NE, E, SE, S, SW, W, NW (45° sectors; **+Y = N** in world space per `ai_driver` notes) | Weak cardinal bias or LLM/perception text — **not** a stored world-compass bearing |

**Alternatives to weigh**

1. **Mob-style ghost buffer** — ring buffer + `awareness_memory_*` decay at last position (pattern: `_mob_hist` in `ai_driver`).  
2. **Explore-trail-style grid** — cheap, but merges distinct bushes in one cell; if used, stay **keyed by bush instance id** so individuals are not lost.  
3. **Precise-only** — no coarse tier; hard forget outside radius (simplest).

**Planned config keys** (see commented dict in [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd)): `food_memory_precise_radius_px`, `food_memory_forget_radius_px`, `food_memory_ttl_sec`, `food_memory_max_entries`, `weight_seek_remembered_food`, `weight_coarse_sector_food_bias`.

**Planned hooks (from `ai_driver` comments):** `_food_belief_reset()`, `_food_belief_sync_from_scene()` after live food split; optional `res://creature/motor/food_source_memory.gd`.

<<Comment: Stationary bushes — [`bush_food.gd`](../../assets/plants/bush_food.gd) `global_position` is stable; belief keys on **instance id**.>>

---

## 6. World geometry & “hiding” (squeeze / passibility)

**Authoritative env semantics:** [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) property catalog — when **`passible == false`**, **Mode A** squeeze allows creatures with **`creature_size <= fit_size`** to enter cells that read as “solid” in the coarse grid.

**Design intent for awareness / memory**

| Topic | Notes |
|-------|--------|
| **Hiding / squeeze** | Small creatures may occupy volume inside or behind **`passible == false`** façades if **`fit_size`** permits. **Awareness** (cone, mobs, food) should eventually treat these cases: e.g. targets **in** shared squeeze/cavity may be **hidden** from line-based checks; **memory** may still hold last-known positions when line of sight breaks. |
| **Planner opacity** | ENVIRONMENT §192: until a squeeze **kind** is learned, planners may treat `passible == false` as **opaque** even when Mode A could allow entry for this **`creature_size`** — aligns with conservative motor; **memory** can still bias toward last-seen egress/hiding when implemented. |
| **Coordination** | Any “am I hidden?” or “can predator see me?” feature should share **`creature_size`**, grid **`passible`/`fit_size`**, and future **LoS** (§7) — avoid three divergent truths. |

<<Question: Should **food bushes inside squeeze cavities** use the same LoS rules as mobs, or always use distance-only until a later phase?>>

---

## 7. Line of sight & awareness radius (related backlog)

**Tracking:** [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — *Line of sight / occlusion (solids vs awareness)*. **Summary here:** Today, awareness is effectively **distance + forward cone** (and gating in `ai_driver`). **Future:** **solid** environment or props (per physics / grid) should **occlude** or **reduce** effective awareness — e.g. ray/sparse checks along cone, or grid-based shadowing — so memory and “hiding” (§6) interact correctly.

**Contracts:** Layer/mask and env props — [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6**; locomotion truth — [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md).

---

## 8. Cross-ported open questions (from [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §9 — food / memory)

Migrated here so **CREATURE_MODEL** stays field-catalog focused.

- <<Question: Coarse direction **changes as the creature moves** because sectors are relative to current position. Is that acceptable for ENGINE routing, or do we need **map-fixed landmarks** for “return to NW corner of map”?>>  
- <<Question: **Forget** — combine `food_memory_forget_radius_px`, `food_memory_ttl_sec` since last in-awareness observation, session reset, and LRU `food_memory_max_entries`?>>  
- <<Question: **Predator / moving food** — track prey `instance_id` + `velocity`; refresh every tick in awareness; extrapolate out of cone like mob ghosts; readiness ≠ bush regrow. Coarse 8-way is a weak cue for movers — prefer **velocity bearing** or precise tier only.>>

**Related creature vitals (hunger display — stays in CREATURE_MODEL for field naming, decision here for motor/perception):**

- <<Question: Should **`hunger`** be **stored** or **always derived** from `current_calories` / `caloric_needs`?>> (Still listed in [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §9 until resolved.)

---

## 9. Dependencies

- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — vitals naming; no duplicate food-memory table there after extraction.  
- [Draft_Features/PLANTS_PLAN.md](PLANTS_PLAN.md), [Draft_Features/PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) — plant fields / ecology.  
- [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) — layers, `passible`, `fit_size`.

---

## 10. Acceptance criteria (when implementing)

- [ ] **§3 prerequisites:** **Predator/prey calorie path** and **movement-based calorie costs** implemented (or explicitly deferred in a cited phase note).  
- [ ] Remembered **precise** targets merge into motor food lists only within configured radius; **no** stale `Vector2` appended in coarse-only tier.  
- [ ] Ready/unready **freezes** at last observation until live awareness refreshes (bush semantics).  
- [ ] Config keys documented in merge defaults when wired; headless or unit tests for gating if feasible.  
- [ ] LoS / occlusion (when scheduled) documented against ENVIRONMENT §6 and this plan §7.

---

## 11. Changelog

| Date | Change |
|------|--------|
| 2026-05-15 | **Goal-aligned memory** framing (danger, food, mates, shelter/rest); **diet archetypes**; **§3** prerequisite: predator calories + **movement-based** calorie costs **before** food-memory expansion; section renumber. |
| 2026-05-15 | Renamed from `MEMORY_FOOD_WORLD_AWARENESS.md` → **`CREATURE_MEMORY.md`**; scoped as start of definitive creature-memory spec (draft tier until promoted). |
| 2026-05-15 | Initial draft: food memory + env hiding + LoS pointer; questions moved from CREATURE_MODEL §9. |
