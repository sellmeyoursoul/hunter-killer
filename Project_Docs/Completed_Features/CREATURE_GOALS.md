# Hunter Killer — Creature goals & asymmetric matchups (agent-friendly)

> **Archived (tier A):** Snapshot of **v1 Herbivore vs Carnivore duel** shipped with [`main.gd`](../../main.gd), [`player.gd`](../../player.gd), [`mob.gd`](../../mob.gd), [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd). Drift vs later code is expected unless a maintainer cites this file. **Companion:** [CREATURE_GOALS_PLAYTEST_LOG.md](CREATURE_GOALS_PLAYTEST_LOG.md).
>
> **Purpose:** Define how **two (or more) creature kinds** differ in **roles, food, and threats** while sharing the same **top-level survival goal** — stay alive (see [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) **Goals and motivational priorities**). **Today:** one **ENGINE**-driven “player” creature whose implicit goal is **don’t die** (starvation + mob contact), with motor + hunger aligned to **shrubs** as food. **Target:** a **zero-sum-style** arena where one **Herbivore** and one **Carnivore** start on **opposite sides** of the play area, each **must not die**, but **food sources are asymmetric**: the herbivore **eats shrubs** (existing ENGINE / motor path); the carnivore **eats the herbivore** (predator path — see [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §2–3). **Success criterion for the phase:** iterated tuning until **win rate is roughly even** (~50% herbivore survival vs carnivore “meal” / herbivore elimination) over many runs — not a perfect 50/50, but **not** a dominant strategy for either side. **Index:** [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).

---

## 1. Phase summary

**Phase name:** Asymmetric creatures — Herbivore vs Carnivore (shared survival, opposed calories)

**One-line objective:** Introduce two **generic** creature lineages — **Herbivore** (from today’s `Player` pattern) and **Carnivore** (from today’s `Mob` pattern) — with **opposite spawn anchors**, **asymmetric lose rules** (herbivore: starvation **and** predation; carnivore: starvation **only** — see §2), and **complementary food** so that **outcomes are competitive** and **balance targets ~even win share**.

**Out of scope (explicit non-goals):**

- Full **reproduction** / mate goals (stay in [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md); this phase is **survival-only**).
- **Omnivore** as a third combatant in the same match (may be a **later** archetype; [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) table still applies to future work).
- **LLM**-only creatures without sharing the same **ENGINE** intent / vitals contracts as human/scripted modes.
- Renaming or removing legacy **`player.gd` / `mob.gd`** paths in a way that **breaks** existing scenes without migration — prefer **duplicate** scenes/scripts first, then optionally unify behind a shared base class in a follow-up. <<Comment: Repo rule forbids arbitrary file renames once stable; new files use new names.>>

---

## 2. Shared vs different structure

| Aspect | Shared by both kinds | Herbivore-specific | Carnivore-specific |
|--------|----------------------|--------------------|--------------------|
| **Primary goal** | **Survive** — do not hit lose conditions for this session / round | — | — |
| **Vitals** | Same **field intent:** `current_calories`, `caloric_needs`, baseline + movement burn ([`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd) `creature_motor` keys; [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §3) | — | Predator **gain** on prey contact / meal ([`predator_prey_meal_calories`](../../AI_int_lib/game_config_merge.gd)); herbs **gain** from shrubs only |
| **ENGINE control** | Both can run under **`ControlMode.ENGINE`** with the **same** `AiDriver` / scripted motor **pipeline**, differing only by **weights**, **food targets**, and **threat model** | Food = **`food_plants`**; threat = **carnivore** + environment (per §3, human vs AI session modes) | Food = **herbivore** node(s); **no** meaningful calories from shrubs; navigation may **bounce** off obstacles but **contact is not a defeat condition** |
| **Spawn** | Both enter visible play at round start | **One side** of playfield (author anchor) | **Opposite side** (paired anchor) |
| **Lose (baseline)** | Starvation at `current_calories` ≤ 0 **or** role-specific lethal contact where defined below — herbivore is **not** starvation-only (predation still applies) | **Starvation** **or** **caught by carnivore** (same class of event as historical mob–player overlap unless doc tightens). Environment / squeeze rules **mirror** today’s herbivore collision semantics where they already apply. | **Starvation** at `current_calories` ≤ 0 **only** in v1. **Carnivore may contact any obstacle without penalty** (no round loss, no extra calorie hit from obstacle touch — tuning lives in physics / avoidance quality, not a separate “hazard KO”). |

### 2.1 Taxonomy: abstract Creature → diet → species

This aligns the **role split** in this doc with the historical **abstract `Creature`** idea from [EARLY_SPEC_DOC](EARLY_SPEC_DOC) §4.2 and the diet table in [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §2.

| Layer | Meaning | Examples / notes |
|-------|---------|------------------|
| **`Creature` (abstract)** | Shared **survival goal**, vitals, motivation field names, reproduction hooks — see [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md). **Not** necessarily one Godot node type; see below. | Stat pools, `caloric_needs`, goals hierarchy |
| **Diet specialization** | **Herbivore**, **Carnivore**, **Omnivore** — **what counts as food**, default threat/seek **weights**, and which **memory** channels matter ([CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md)). | In **design / docs**, treat these as **subkinds** of Creature. |
| **Concrete species** | **Parameterized** implementations: art pack, `speed`, `creature_size`, optional species caps — rabbit, mouse, fox, … | Tune balance **per species** without a new taxonomy tier |

**Implementation (Godot — recommendation, not mandatory):**

- **Prefer** a **single shared vitals + intent API** (one base script or small set of scripts) plus a **`feeding_diet`** (`HERBIVORE` | `CARNIVORE` | `OMNIVORE`) or equivalent Resource on the instance — motor and `AiDriver` branch on diet instead of deep `extends` chains **when** body types differ (`CharacterBody2D` vs `RigidBody2D`).
- **Subclasses per diet** are reasonable **if** two species share the same physics model and only differ by exports + config — e.g. `HerbivoreCreature.gd` extends a common `CreatureBody.gd`.
- **Subclasses per species** (dozens of `fox.gd`, `rabbit.gd`) are usually **not** worth it unless a species needs **unique code paths**; otherwise use **scene variants** + data (pack JSON, exports) per [asset_management.md](../../.cursor/rules/focus/asset_management.md).

**Resolved (v1):** **Diet as data** on the creature instance (e.g. [`CreatureDefinition`](../../creature/definition/creature_definition.gd) `feeding_mode` / equivalent) is **sufficient**. No mandatory `class_name` / `extends` mirror types for Herbivore, Carnivore, or Omnivore.

**Conceptual framing:** “For one to live, the other **may** need to die” describes **pressure** in a **finite-food / predator-prey** loop, not a strict theorem. In implementation, **both** can theoretically survive for a time if the herbivore **keeps calories** and **avoids capture**; **success** is still measured at **round outcome** (who hit lose first, or time-boxed judge if added later).

### 2.2 Round outcomes (v1 — implemented)

| Event | Winner (manual log) | Main hook | Log tag |
|-------|---------------------|-----------|---------|
| Herbivore caught | Carnivore | [`Main.end_round`](../../main.gd) → `game_over()` | `predation_carn_win` |
| Herbivore starvation | Carnivore | same | `starvation_herb` |
| Carnivore starvation | Herbivore | same | `starvation_carn_herb_win` |
| Round timer (~10 s) | Log only (`none`) | same | `timeout` |

**Winner authority:** [CREATURE_GOALS_PLAYTEST_LOG.md](CREATURE_GOALS_PLAYTEST_LOG.md) + `OLog` line tagged `CREATURE_GOALS` from Main. HUD stays generic “Game Over”.

**Playfield:** All creatures **clamp** to the viewport AABB ([`playfield_clamp.gd`](../../creature/capabilities/playfield_clamp.gd)); **OOB is not** a lose condition.

**Spawns (v1):** **Carnivore — left** (`CarnivoreSpawn`); **Herbivore — right** (`HerbivoreSpawn`). **One** carnivore per round; **`MobTimer` wave spawn retired**.

---

## 3. Implementation sketch (code-facing)

**Shipped v1:** Implemented on [`player.gd`](../../player.gd) / [`mob.gd`](../../mob.gd) + [`main.gd`](../../main.gd) (not separate duplicate scenes).

1. **Herbivore** — [`player.gd`](../../player.gd): `CharacterBody2D`, `MobHitbox`, shrub overlap via [`bush_food.gd`](../../assets/plants/bush_food.gd); groups `herbivores`, `prey`.
2. **Carnivore** — [`mob.gd`](../../mob.gd): `RigidBody2D`, **`add_calories_from_prey`**, ENGINE pursuit via [`carnivore_pursuit.gd`](../../creature/motor/carnivore_pursuit.gd).
3. **`Main` session modes:** **`Start`** — human herbivore + ENGINE carnivore. **`AI Player`** — both ENGINE ([`sync_duel_control_modes`](../../AI_int_lib/ai_driver.gd)).
4. **Motor / AI** — Herbivore ENGINE: **`cardinal_avoidance`** + food seek + threat cost. Carnivore ENGINE: pursuit toward prey groups (**optional belief / memory** remains future — [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md)).
5. **Level / Main** — **HerbivoreSpawn**, **CarnivoreSpawn**; bushes per [PLANTS_PLAN.md](../Draft_Features/PLANTS_PLAN.md) / [`main.gd`](../../main.gd).

### 3.4.1 Carnivore ENGINE motor contract (v1)

| Input | Source |
|-------|--------|
| `creature_position` | Carnivore `global_position` |
| `prey_targets` | Nodes in [`DietRegistry`](../../creature/capabilities/diet_registry.gd) `prey_groups` (`herbivores`, `prey`, `player`) |
| Playfield AABB | `bounds_min` / `bounds_max` = viewport (same as herbivore motor) |

| Output | Sink |
|--------|------|
| Unit direction | [`mob.gd`](../../mob.gd) [`set_creature_move_intent`](../../mob.gd) → `linear_velocity` while `control_mode == ENGINE` |

Implementation: [`carnivore_pursuit.gd`](../../creature/motor/carnivore_pursuit.gd) + [`AiDriver._run_carnivore_engine_motor`](../../AI_int_lib/ai_driver.gd).

### 3.5 AiDriver N-creature registry (v1)

[`ai_driver.gd`](../../AI_int_lib/ai_driver.gd): `register_creature`, `clear_creature_registry`, `set_duel_round_active`, `sync_duel_control_modes`. Motors run for **every** registered creature in `ENGINE` control — not a hardcoded Player+Mob pair (forward-compatible with reproduction).

---

## 4. Success criteria & balance loop

| Criterion | Intent |
|-----------|--------|
| **Win-rate parity** | Across **N** automated or semi-auto runs (N large enough for noise to settle), **neither** archetype **dominates**; target band e.g. **40–60%** “wins” for each side until further split by skill / map. **Not automated in v1** — ongoing manual tuning (§6). |
| **Observable failure modes** | Herbivore loses: starvation vs **caught** — log tags in §2.2. Carnivore loses: **starvation** only in v1; obstacle contact is **not** a KO. **OOB** is prevented by playfield clamp (§2.2), not logged as defeat. |
| **Tuning hooks** | Shared: `calorie_baseline_drain_per_sec`, `calorie_cost_per_px_moved`, `caloric_needs`, shrub yields. Asymmetric: `predator_prey_meal_calories`, **relative speed** (herbivore `speed` vs carnivore cruise), **awareness** radii, avoidance weights in [`game_config.json`](../../game_config.json) `creature_motor`. |

**Balance / regression (v1):** Prefer **manual playtesting** and **iterative tuning**, and use the **existing** headless suite ([`tests/run_all.gd`](../../tests/run_all.gd) — vitals, diet defaults, 3D template smoke, etc.) so automated checks do **not** bake in a biased win-rate harness before the duel loop is fun and stable. **Defer** a batched arena / automated win-count runner until after a **playable duel prototype** and enough manual calibration to avoid unintended statistical bias.

---

## 5. Dependencies & cross-links

| Doc or code | Relationship |
|-------------|--------------|
| [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) | Field names, goal hierarchy |
| [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) | Diet archetypes, predator/herbivore memory emphasis, §3 calorie prereqs |
| [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) | Parking-lot items (LoS, memory) that affect **fair** pursuit / hiding |
| [HUNGER_AND_EATING.md](HUNGER_AND_EATING.md) | **Archive** — historical bush + HUD patterns; not authoritative for new duel rules unless maintainer cites |
| [CREATURE_3D_ARCHITECTURE.md](../Draft_Features/CREATURE_3D_ARCHITECTURE.md) | 3D reuse vs leaf data: capabilities + templates + [CreatureDefinition](../../creature/definition/creature_definition.gd). |

---

## 6. Acceptance checklist (v1 shipped)

- [x] Herbivore / carnivore via [`player.gd`](../../player.gd) + [`mob.gd`](../../mob.gd) (diet-as-data); no forbidden renames.
- [x] Opposing spawns (carnivore left, herbivore right); single carnivore; `MobTimer` retired.
- [x] Carnivore prey meal + herbivore shrub intake; dual HUD calorie labels.
- [x] **`Start`:** human herbivore + ENGINE carnivore; **`AI Player`:** both ENGINE.
- [ ] **Ongoing:** §4 win-rate parity via manual rows in [CREATURE_GOALS_PLAYTEST_LOG.md](CREATURE_GOALS_PLAYTEST_LOG.md) (template shipped; not a code gate).

---

## 7. Changelog

| Date | Change |
|------|--------|
| 2026-05-15 | §2.1 **Taxonomy:** abstract Creature → Herbivore / Carnivore / Omnivore → concrete species; Godot composition vs subclass note; link EARLY_SPEC_DOC. |
| 2026-05-15 | Initial draft: shared survival goal, herbivore vs carnivore duplication strategy, opposite spawns, ~even win rate success criterion. |
| 2026-05-15 | Resolved: asymmetric loses (herbivore starvation + predation; carnivore starvation only; no obstacle KO for carnivore). Diet-as-data v1. `Main`: Start = human herbivore + ENGINE carnivore; AI Player = both ENGINE. §4 manual tuning + existing tests; defer batched arena harness. |
| 2026-05-15 | **Implemented v1 duel:** §2.2 outcomes, spawns, 10s round cap, playfield clamp, dual HUD, AiDriver N-registry, carnivore pursuit motor, manual playtest log template. |
| 2026-05-15 | **Archived** to `Completed_Features/` (tier A snapshot); cross-links repaired for folder move; §3 aligned with shipped `player.gd`/`mob.gd`. |
