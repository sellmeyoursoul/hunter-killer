# Hunter Killer — Creature movement V2 / unified motor (draft)

> **Purpose:** Working spec for a **movement + motivation refactor**. **Canonical goal drivers** (motivation tree Tier-1/2, `CreatureDefinition` traits, habitual **`believed_goal_*`** modulation): **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)**. This file **inherits** **goal-target / belief memory semantics** from [CREATURE_MEMORY.md](CREATURE_MEMORY.md), and adds **V2 architectural goals**: per-creature motor tuning in packs, **one** 8-way intent pipeline for all species, and **wiring** the motivation tree into `MotorContext` / motor scorer.
>
> **Tier:** Draft — supersede branching in [Definitive_Features/CREATURE_MOVEMENT.md](../Definitive_Features/CREATURE_MOVEMENT.md) when implemented; inventory doc stays authoritative for *current* code until then.
>
> **Refactor scope (ENGINE):** This phase **defines and implements scripted ENGINE motor only** (`creature_motor` weights, unified intent, motivation tree). **LLM / AI motor mode is out of scope** until ENGINE behavior is solid. When LLM motor is implemented later it must consume **motivation traits** at minimum; optionally share flattened motor params or read the species **`pack_resources.json`** so completions stay aligned with the same weighing story.
>
> **References:** [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) (`pack_resources.json`), [`creature_definition.gd`](../../creature/definition/creature_definition.gd), [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md), [game_config_merge.gd](../../AI_int_lib/game_config_merge.gd).
>
> **Co-development:** **Tier / trait semantics** — **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)**; **belief keys, hooks, tier belief tables** — **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** + code (**`goal_memory_*`**, **`_goal_belief`**). This file focuses on **routing** remembered targets into **`SeekCandidate[]`**, **`creature_motor`**, and scorer plumbing. **Archived** `[Completed_Features/](../Completed_Features/)** may still show older `food_memory_*` — ignore for implementation.

---

## A. Refactor stated goals

### A.1 creature_motor per pack + resilient defaults in `game_config_merge.gd`

**Target:** Per-species tuning lives in **`res://assets/creatures/<pack>/pack_resources.json`** — see **canonical shape** below. Root [`game_config.json`](../../game_config.json) and `user://game_config.json` may still hold **other** global knobs; they do **not** participate in the **`creature_motor`** merge stack (no global overlay layer).

**Canonical `pack_resources.json` shape (chosen):**

- **`"creature_motor": { … }`** at the pack root (**inline object**) holds **everything that defines movement weighing** for that species — weights, hold ticks, chaos, thresholds, Tier-2 multipliers once split, optional future keys. **Do not use** a `.tres` indirection unless we explicitly add `"creature_motor_path"` later.
- **`"strategy_class_tags": { … }`** (**optional sibling**, not nested under **`creature_motor`**) — species-specific **Slot B** modality extensions for locale priors / habitual replay (**[CREATURE_GOAL_DRIVERS.md §5.1 — Action 1](CREATURE_GOAL_DRIVERS.md)**):
  - **`extra_modalities`**: `string[]` of **`snake_case`** ids unioned at spawn with the engine **core modality resource** → per-instance **`effective_modality_allowlist`**.
  - Example: `{ "strategy_class_tags": { "extra_modalities": ["ambush_stalk"] } }`.
  - **Pole facet tags** are **not** pack-extensible (fixed eight ids in engine code).
- **`"goal_kinds": { … }`** (**optional sibling**, not nested under **`creature_motor`**) — species-specific **goal-category** extensions for locale priors / write gates (**[CREATURE_GOAL_DRIVERS.md §4.1](CREATURE_GOAL_DRIVERS.md)**):
  - **`extra_goal_kinds`**: array of objects — each adds a **`snake_case`** **`id`** unioned at spawn with engine **core `GoalKind`** ids → per-instance **`effective_goal_kinds`**.
  - Required per entry: **`id`**, **`parent_tier2`** (`find_food` | `avoid_hostiles` | `find_mate` | `preserve_calories`). Optional: **`salient_writes`** (default true), **`context_overlay`** (hint for **`context_hash`** compositor).
  - Example: `{ "goal_kinds": { "extra_goal_kinds": [{ "id": "nest_defense", "parent_tier2": "avoid_hostiles", "context_overlay": "nest_fingerprint" }] } }`.
  - **Core** ids (`find_food`, `avoid_hostiles`, `shelter`, `find_mate`) are **not** pack-overridable; packs only **add** kinds.

**Resolution rule (instantiation):** Every spawned creature gets `creature_motor` as **`default_creature_motor_params()` shallow-merged with the pack overlay** (see below). **`effective_goal_kinds`** and **`effective_modality_allowlist`** merge from the same **`pack_resources.json`** at spawn (**`CreatureDefinition.asset_pack_root`**). **`default_creature_motor_params()`** is the **only** authoritative place that composes (**merged into one dict**):

1. **Species-agnostic spine** — hard defaults so nothing runs with missing dicts.

2. **Exactly one profile** — **`creature_motor_profile_dev`** or **`creature_motor_profile_ship`** (locked identifiers — see selection below): **`default_creature_motor_params()` MUST reference these identifiers explicitly** (e.g. constants or map entries by id) and **select** between them using the build flag (**§Profile selection**). Implementations may extract `apply_creature_motor_profile_*` helpers for tests, but the **ship vs dev blend** observable at runtime originates from **`default_creature_motor_params()`**.

**Per-key precedence (strict):** For each **`creature_motor`** key **`k`**:

1. **Pack layer — first** (`pack_resources.json` → **`creature_motor`**, keyed by **`CreatureDefinition.asset_pack_root`**): if **`k`** is present **here**, that value wins.

2. **Else profile-backed defaults**: use **`default_creature_motor_params()[k]`** (spine ∪ selected profile).

If **all or part** of **`creature_motor`** is absent in the pack file, **missing keys** adopt **`default_creature_motor_params()`** only for those keys — the creature **still runs**; tuning may be **wrong for that species** until the pack is fixed (**acceptable per asset workflow**).

**Two merge profiles in `game_config_merge.gd` (required — locked identifiers):**

| Locked id | Audience | Behavioral intent |
|-----------|----------|-------------------|
| **`creature_motor_profile_dev`** | Editor, CI, builds **without** the ship feature tag below | **Aberrant probe profile:** tune weights/speed/explore/hold toward **extreme ends of each knob's spectrum** so effective behavior **clearly deviates** from acceptable ship norms — e.g. **tight looping / small circles**, excessive idle spin, or other obviously wrong locomotion. Purpose: **detect wiring regressions** (missing pack overlay, broken merge, absent seek/threat builder) — **not** approximate real creature behavior. Per-key guidance: when unsure, pick the **opposite extreme** from the intended ship midpoint for that scalar. |
| **`creature_motor_profile_ship`** | **Ship / release exports** when export feature **`creature_motor_ship`** is enabled | **Stub only until gameplay baseline exists:** ship numerics are **guesswork** today. Implement as **empty overlay** (spine-only) or placeholder dict with **`<<Comment: FINALIZE BEFORE SHIP>>`** on every intended override key. **Do not** treat stub values as release tuning. Finalize after playtest baseline establishes neutral species curve. |

**Profile selection (build flag — defaults to dev):**

- **Chosen mechanism:** Godot **export custom feature tag** **`creature_motor_ship`** (set on **production / ship presets only** in the Export dialog → *Features*, or equivalent export metadata).
- **Runtime rule:** **`default_creature_motor_params()`** calls `OS.has_feature(&"creature_motor_ship")` and merges **`creature_motor_profile_ship`** when true; otherwise merges **`creature_motor_profile_dev`** (default for editor runs, unstamped exports, missing tag). Merge helpers keyed by those two identifiers may exist for tests (**e.g.** `apply_creature_motor_profile_ship(base)`) — names must preserve the **_dev** / **_ship** suffixes; **`default_creature_motor_params()`** remains the **single entry** that performs profile selection + spine merge for production codepaths.

**CI / ship executable testing (deferred — B-10):** Strategy for validating **`creature_motor_ship`** builds — export preset vs harness vs both — **deferred until `creature_motor_profile_ship` has real numerics**. Requires broader **automated regression against a ship-tagged executable**, not profile-merge unit tests alone. Track in **[ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md)**.

**LLM note:** **`mode` / inference** tying into `creature_motor` is **out of scope** for this refactor. Packs may still record `mode: "scripted"` for clarity; ENGINE implements scripted path only until LLM motor phase.

### A.2 Single intent path (herbivore + carnivore logic merged)

**Principle:** There is **one** scripted motor pipeline: **`AiDriver`** builds **one** `MotorContext`; **`CardinalAvoidance.pick_best_move_intent`** scores one cost stack. Species differences are **data** (`CreatureDefinition.feeding_mode`, diet policy, trait multipliers), not parallel `if prey / if mobs` code paths scattered through `ai_driver.gd`.

**Unified target builder (resolved — B-7):** Collapse predator/prey seek/threat forks into **one method on `AiDriver`** in [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) (name TBD, e.g. `_build_motor_target_lists`). **Inputs:** body, motor params, awareness scan, `CreatureDefinition`, `feeding_mode`. **Outputs:** **`SeekCandidate[]`** + **`ThreatSample[]`**. **`_build_motor_context`** consumes this output — **no** standalone `MotorTargetPolicy.gd` class.

**Unified “targets” ontology (design target):**

| Concept today (V1) | V2 framing |
|--------------------|------------|
| `food_seek_targets`, `prey` positions separately | **`SeekCandidate`** (**one** routed list — see below): entries are **objects of relevance** to “what to pursue / avoid-soft”; **moving vs stationary** is a **subtype** on each object, **not** a separate motor ingress list. |
| `unready_food_avoid_targets` only on plants | **Same list:** edible-but-not-ready → **eligible as “food” shape but `consumable_now = false`** (repulse / low priority seek). |
| Carnivore: prey appended to food list + `pursuit_targets` | **Same list**: pursuit vs idle food is **`SeekCandidate`** metadata + combined **relevance**, not **`pursuit_targets` vs food** forked entry points (internal scorer may peel sub-terms). |
| Herbivore-only forage geom strip | Applies when **the seek list includes stationary plant-class candidates** near same cell — express as **`forage_geom_relief_radius`** keyed to **`SeekCandidate`**, not `is_in_group(&"prey")`. |

**SeekCandidate — single relevance list (resolved):**

- The motor consumes **one routed `SeekCandidate[]`** (possibly empty). Each entry carries **spatial / affordance facts** (`consumable_now`, mover vs stationary; **LoS flags deferred** — **§D**) plus **relevance**.
- **Relevance combines** (**at minimum** interpretation): (**a**) **affinity with the derived dominant Tier-2 leaf** (**§A.2.3** — not a separate authored field on each **`SeekCandidate`**), and (**b**) **proximity to addressing that concern** (distance, reachability placeholders, directional alignment).
- **Do not maintain** parallel first-class seek vs pursuit ingest paths — **ingress normalizes into this one list**; diet / `feeding_mode` only filters **membership or metadata**, not duplicated arrays.

#### A.2.3 Derived dominant Tier-2 leaf (phase-1 resolved)

**`dominant_tier2_leaf`** is **derived each tick** in [`_build_motor_context`](../../AI_int_lib/ai_driver.gd) (or **`trait_tier2_mapper`** output path) — **not** stored on individual **`SeekCandidate`** entries and **not** a persistent config field.

**Derivation order (phase 1):**

| Priority | Condition | `dominant_tier2_leaf` |
|----------|-----------|------------------------|
| **0** | `calorie_ratio < starvation_override_food_ceiling` (default **0.10**) | **Find food** — **overrides** acute threat / jeopardy for dominance + motor urgency |
| 1 | Acute personal threat (imminent mob / **`tactic_jeopardy_egress`** / jeopardy path) | **Avoid hostiles** — skipped when priority **0** active |
| 2 | `calorie_ratio < seek_priority_food_ceiling` (default **~0.80**) | **Find food** |
| 3 | `calorie_ratio ≥ preserve_bias_food_floor` (default **~0.90**) | **Preserve calories** |
| 4 | `find_mate` urgency enabled (stub **0** today) | **Find mate** |
| else | — | **Preserve calories** (idle / low urgency) |

**Write gates vs derived leaf:** Successful **eat** still writes **`find_food`** even in mid Preserve band (**[CREATURE_MEMORY.md §14.4](CREATURE_MEMORY.md)**). Motor **weights** may smoothstep Preserve↔Find in 0.80–0.90; **salient writes** follow **outcome resolution**.

**Consumers (same derived value per tick):**

- **`SeekCandidate` relevance** — filter/boost entries compatible with dominant leaf (**§A.2**).
- **Salient write gates** → **`GoalKind`** routing (**[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)**, **GOAL_DRIVERS §4.1**).
- **`LocalePriorMap` consult** — projection, **`context_hash`**, threat pass **§14.3**.
- Future: **`goal_seek_targets`** filtered by dominant leaf (**§A.2.2**).

**Phase-1 code note:** Today hunger/jeopardy paths in **`ai_driver.gd`** approximate this stack; formalize as one **`derive_dominant_tier2_leaf(...)`** when refactoring.

**Examples:**

- **Plant, not pickup-ready** → **`food_candidate = true`**, **`consumable_now = false`** (maps to today’s **unready** inverse-distance avoidance or weak seek).
- **Herbivore body to a carnivore** → **`food_candidate = true`** for that species**, **`consumable_now`** subject to gameplay rules (alive, in range, etc.).
- **Rival predator** → **`hostile = true`** (Tier 2 *Avoid hostiles*) — never “food,” separate channel from seek.

<<Comment: `DietRegistry` / `FoodIntakePolicy` should classify **interaction** (“can bite bush”); motor should classify **salience** (“target appears in seekers or hostiles”). Split keeps eating code from routing code.>>

#### A.2.1 `MotorContext` tactic classifier flags (phase-1 — salient write)

**Authority:** Full emitter contract — **[CREATURE_GOAL_DRIVERS.md §5.1.1](CREATURE_GOAL_DRIVERS.md)**; write gates — **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)**.

When building **`MotorContext`** ([`_build_motor_context`](../../AI_int_lib/ai_driver.gd)), motor / perception **may set** boolean tactic flags for the tick. **`goal_source_memory.gd`** reads them to build **`modality_tags[]`** when **`tactic_classifier_active`** is true. **Do not** write **`LocalePriorMap`** from cardinal code directly.

| Key | Role |
|-----|------|
| `tactic_classifier_active` | **`true`** if any tactic flag below is set |
| `tactic_in_squeeze` | → `squeeze_commit` |
| `tactic_jeopardy_egress` | → `flee_retreat` |
| `tactic_hide_viable` | → `hide_stealth` |
| `tactic_return_home_payoff` | → `return_home` |
| `tactic_lasting_local_change` | → `lasting_local_change` |
| `tactic_fight_active` | → `fight` (stub) |
| `conspecific_aid_count` | Pole inference: `squeeze_commit` → `community` vs `individual` |
| `hide_hold_still` | Pole inference: `hide_stealth` → `stability` vs `change` |

Phase 1: flags may be **stubbed false** until squeeze/threat detectors land; **`find_food`** salient writes still use §5.1.1 **default modality / `explorer` pole** path.

#### A.2.2 Goal seek vs food seek (phase-1 posture)

**Target (§A.2):** one **`SeekCandidate[]`** ingress and **`goal_seek_cost`** — not parallel **`food_seek_targets`** / **`pursuit_targets`** forks. **Code today** still uses **`food_seek_*`** keys in [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) / [`cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd).

**Phase A target builder (shipped):** [`motor_target_builder.gd`](../../creature/motor/motor_target_builder.gd) — **`build_motor_target_lists()`** emits **`seek_candidates`**, **`threat_samples`**, **`food_split`**, **`prey_positions`**, **`pursuit_targets`** from **`feeding_mode`** + [`FoodIntakePolicy`](../../creature/definition/food_intake_policy.gd) (`DietRegistry`), not **`prey` / `mobs` group forks**. Typed hostile ingress: [`threat_sample.gd`](../../creature/motor/threat_sample.gd). **`_goal_belief_*`** runs when **`supports_plant_belief`** (plant groups on policy).

**Phase-B goal seek (shipped):** **`goal_seek_targets`** + **`weight_seek_goal`** on **`MotorContext`**, filtered by **derived** dominant Tier-2 via [`goal_seek.gd`](../../creature/motor/goal_seek.gd) + [`seek_candidate.gd`](../../creature/motor/seek_candidate.gd). Cardinal linear pull uses **`goal_seek_cost_at_prediction`** (alias of legacy food seek cost). Legacy **`food_seek_targets`** / **`weight_seek_ready_food`** remain for belief merge and pack compat.

| Layer | Phase A/B (current) | Later |
|-------|---------------------|-------|
| Instance targets | **`goal_seek_targets`** + **`weight_seek_goal`**; legacy food keys mirrored | Drop parallel **`prey_seek_targets`** linear pull when pursuit-only path suffices |
| Habitual patches | **`believed_goal_source_bias`** vector + sector costs | Same — **never** merged into seek target list |
| `replay_weight` | Multiplicative on **`weight_believed_goal_pull`** + **`weight_seek_goal`** | — |

### A.3 Motivation tree (framework)

**Canonical tree diagram, Tier-2 leaf semantics, category rollup:** **[CREATURE_GOAL_DRIVERS.md §2 — Motivation tree](CREATURE_GOAL_DRIVERS.md)**. **This section** retains **motor-specific** Preserve-vs-Find thresholds (**§A.3.1**) and **`believed_goal_*`** integration stubs (**§A.3.1** bullets).

#### A.3.1 Preserve calories vs Find food (resolved)

| Rule | Specification |
|------|----------------|
| **Not exploration-only down-weight** | **Preserve calories** may **suppress or strongly reduce** Tier-2 **Find food** weights when **`calorie_ratio`** is above a **per-creature preserve floor** — more than tweaking generic exploration noise alone. |
| **Per creature** | Floors / ceilings ship as **defaults in `default_creature_motor_params()`** (spine ∪ selected **`creature_motor_profile_*`**) and **overrides** in **`pack_resources.json` → `creature_motor`** / future **`CreatureDefinition`** exports so each archetype tunes the band. |
| **Starter thresholds** | **`calorie_ratio ≥ preserve_bias_food_floor`** (**default ~0.90**): bias **Preserve** (less seek, fewer costly detours). **`calorie_ratio < seek_priority_food_ceiling`** (**default ~0.80**): bias **Find food** (seek regains traction). **Mid band (0.80–0.90):** **smoothstep** blend; **`preserve_seek_blend_smoothness`** (**default 0.5**, range **0…1**) = blend **aggressiveness** (higher → sharper Preserve↔Seek transition). **`calorie_ratio < starvation_override_food_ceiling`** (**default 0.10**): **Find food** overrides acute threat (**§A.2.3** priority **0**). **`Avoid hostiles`** / jeopardy **override** hunger band when acute threat applies — **except** starvation priority **0**. |
| **Motor keys** | **`preserve_bias_food_floor`**, **`seek_priority_food_ceiling`**, **`preserve_seek_blend_smoothness`**, **`starvation_override_food_ceiling`** — defaults in **`default_creature_motor_params()`** only; omit from pack **`creature_motor`** unless overriding. |
| **No-goal patrol lock (phase-1 — resolved)** | When **`motor_has_active_goal`** is false, skip per-tick tie roulette; **[`no_goal_patrol_lock.gd`](../../creature/motor/no_goal_patrol_lock.gd)** picks a random **8-way** unit direction or **`Vector2.ZERO`**, holds for **`motor_no_goal_patrol_lock_sec`** (duel packs default **1.0** s), re-rolls when expired if still no goal. Goal surfacing clears lock and restores normal motor. Key: **`motor_no_goal_patrol_lock_sec`** (**0** = legacy explore/patrol motor). |

##### Believed goal source / habitual locales (future — overlays goal memory)

Once memory tracks **regions or outcomes that reliably satisfied a Tier-2 goal** (nutrition first — mates, nests, bolt-holes reuse the same façade):

- **Nearby habitual locale** (within **`believed_goal_hotspot_near_radius_px`** — default **250 px**, same as **`locale_prior_projection_radius_px`** — **[CREATURE_MEMORY.md §10 / §14.1](CREATURE_MEMORY.md)**): **vector pull** toward top locale-prior patches (**not** fake seek targets).
- **No nearby habitual source** (no locale prior within **hotspot** **250 px**, but creature still within **`believed_goal_seek_escalate_radius_px`** — default **1000 px**): **elevate urgency** via **`weight_seek_ready_food`** (or future **`weight_seek_goal`**) and Preserve/Find band — **not** via **`pull_dir`** formula.
- **Threat vs escalate ordering:** **[CREATURE_MEMORY.md §14.3](CREATURE_MEMORY.md)** — acute threat does **not** instantly abandon escalate/hotspot evaluation; locale priors inform **replay / modality choice** before **Avoid hostiles** hard-win (**no** separate flee cardinal from priors phase 1).
- **Trait-scaled habitual replay:** **[CREATURE_GOAL_DRIVERS.md §5 — Habitual replay modulation](CREATURE_GOAL_DRIVERS.md)** (trait × strategy-class × **`believed_goal_*`**). Backends and **`context_hash`** overlays: **[CREATURE_MEMORY.md §§2.1–2.2](CREATURE_MEMORY.md)**; tag vocabulary + validation — **GOAL_DRIVERS §5.1** (**Actions 1–3 Resolved**). Same façade, **no forked ingress**.

**Resolved (motor consumption — phase 1):** [`cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd) adds **additive** cost terms from **`MotorContext.believed_goal_source_bias`** (**[CREATURE_MEMORY.md §14.1](CREATURE_MEMORY.md)**). Per candidate step **`d`** (unit 8-way direction — see definitive [CREATURE_MOVEMENT.md §4.1](../Definitive_Features/CREATURE_MOVEMENT.md)):

```text
effective_pull_weight = weight_believed_goal_pull * replay_weight   // when consult context_hash matches; GOAL_DRIVERS §5.1
cost += -dot(d, pull_dir) * effective_pull_weight * pull_mag
for s in 0..7:
  cost += -sector_weights[s] * align(d, sector_s) * weight_coarse_sector_goal_bias
```

- **`replay_weight`** ([GOAL_DRIVERS §5.1](CREATURE_GOAL_DRIVERS.md)): **`prior_base * (1 + replay_delta/100)`**, **`prior_base = stored_strength`** — **multiplicative** on **`weight_believed_goal_pull`** and optionally **`weight_seek_ready_food`**; **not** a second direction; **not** additive on costs.
- **Hotspot / escalate:** adjust **`weight_seek_ready_food`** and Preserve/Find thresholds above — **not** the vector lines.
- **Precise remembered bushes** stay in **`food_seek_targets`** only — **do not** append centroid to seek lists.

Implementation slots: **`believed_goal_source_bias`** populated by **`goal_source_memory.project_believed_goal_bias(...)`**; keys **`weight_believed_goal_pull`**, **`believed_goal_hotspot_near_radius_px`** in **`creature_motor`** (**MEMORY §10**). Trait replay obeys **[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)**. **Stub zero bias** acceptable until memory PR lands.

<<Comment: First implementation may omit `believed_goal_*`; document keys in **`creature_motor`** packs when wired. Nutritional hotspots may be the first consumer — still keyed generically so mates/shelter/evasion stacks without renames later.>>

### A.4 Motivation traits (`CreatureDefinition`)

**Canonical:** polarity table, UI convention, trait application order, survival-plan narrative, Tier subtree scaling — **[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)**. **Code map (tier III):** **[CREATURE_TRAIT_USAGE.md](../Definitive_Features/CREATURE_TRAIT_USAGE.md)** — spawn read path, Slot A/B live vs stub urgency.

**Code:** read `@export_range(-100, 100)` scalars from [`creature_definition.gd`](../../creature/definition/creature_definition.gd); apply per **GOAL_DRIVERS §3** when blending Tier-2 weights and **`believed_goal_*`** replay (**§A.3.1**).

---

## B. Port from CREATURE_MEMORY (goal-aligned beliefs — still applicable)

*(Sections below summarize [CREATURE_MEMORY.md](CREATURE_MEMORY.md); V2 refactor **does not replace** belief design — it **routes** beliefs through the **[CREATURE_GOAL_DRIVERS.md §2](CREATURE_GOAL_DRIVERS.md)** motivation tree and pack-scoped motor data.)*

### B.1 What memory is for (goal-aligned categories)

Creature memory remains a **working set of salient world facts** keyed to goals — not a telemetry dump.

| Category | Goals | Relation to Tier 2 |
|----------|-------|---------------------|
| **Nutrition (“find food” targets)** | Don’t die | **Find food** |
| **Mates / reproduction** | Reproduce | **Find mate** (stub) |
| **Danger** | Don’t die | **Avoid hostiles** |
| **Evasion / nesting / shelter-like** | Don’t die; reproduce (safe birth); recovery | Matches [CREATURE_MEMORY.md §7](CREATURE_MEMORY.md); intersects **Avoid hostiles** + future **Preserve** / rest comfort |

### B.2 Ingress policy — `feeding_mode` (single motor path)

**V1 shorthand:** predator vs omnivore vs herbivore often implied **Forked routing**.

**V2 wording:** **`feeding_mode`** filters **`SeekCandidate`** **membership / metadata** (**§A.2**) and **consumption / bite rules**. The **motor does not fork** — it consumes one **`SeekCandidate[]`** plus **`ThreatSample[]`** from a builder step (perception façade). **No** separate “archetype memory stack” — all goal kinds share **`goal_*`** configs ([CREATURE_MEMORY.md](CREATURE_MEMORY.md)).

**Phasing stance:** Accepted as written; delivery order (**movement foundations → memory → retune**) is nailed in **§B.3**.

### B.3 Implementation order — maintainer-approved phasing

1. **`feeding_mode`** as **ingress-only** (**§B.2**) remains correct; predator/prey calorie path + **movement calorie cost** (per [CREATURE_MEMORY.md §4](CREATURE_MEMORY.md)) still gate claiming **predator memory-complete UX** wherever that overlaps schedule.

2. **Phase — ENGINE movement first (this document’s refactor slice):** Land **correct unified scripted movement**: **`creature_motor`** = **`default_creature_motor_params()`** ∪ pack overlay (**§A.1**), single intent plumbing, avoidance/seek correctness from live sense + existing geometry gates. **Do not ship** persisted **`_goal_belief`** layering in this same slice unless it is negligible glue.

3. **Phase — generalized goal-memory second:** Full memory implementation (**§C**, [CREATURE_MEMORY.md §4–§5](CREATURE_MEMORY.md)): merge **`SeekCandidate ∪ remembered`** through one façade. **Tune after integration** — if memory degrades movement versus the movement-phase baseline, adjust weights/rules in a focused follow-up (movement truth wins until memory proven stable).

4. Technical enabler retained from prior draft: unify motor **routing** early so **`SeekCandidate` ownership** stays one codepath **before** memory writes into it.

---

## C. Goal-target memory (design — not fully implemented)

**Objective:** Remember **goal-relevant** targets after they leave awareness — **without omniscient seek**. **Nutritional foliage + prey land first** — mates, nests, bolt-holes follow the **same** schema ([CREATURE_MEMORY.md §5](CREATURE_MEMORY.md)).

**Movement refactor scope:** **Authoritative** numerical defaults **and** TTL rules live in [CREATURE_MEMORY.md](CREATURE_MEMORY.md) (**`goal_memory_*`**). Here: how beliefs **fuse** into **`SeekCandidate[]`** (and threats) beside live sense, with **`consumable_now` / payloads** frozen until refreshed.

| Tier | Condition (baseline — sync with CREATURE_MEMORY §5) | Representation | Motor use |
|------|-----------------------------------------------------|----------------|-----------|
| **Precise — stationary** | Distance to `last_world_pos` inside **`goal_memory_precise_radius_px`** (~**1000** px cue in commented merge defaults) | Exact **`Vector2`** + frozen affordability (`consumable_now`, optional payloads) | Merge into **`SeekCandidate`** (**§A.2**) |
| **Precise — moving** | Last-known **`Vector2`** with disk **`goal_memory_moving_last_known_radius_px`** (starter ~**50** px; clamp **`≤ goal_memory_precise_radius_px`** unless waived — **§F**) | Blob + velocity ghost when extrapolating | Same list (**§A.2**) |
| **Coarse** | Beyond precise envelope; still remembered under forget/LRU rules | Egocentric 8-way sector each tick (**+Y = N**) | Weak sector bias (**`weight_coarse_sector_goal_bias`**) on matching **8-way seek steps**; **never** spoof full-precision seek |

**Alternative storage:** Mob ghosts, explore-grid keyed by **`instance_id`**, precise-only — **memory-phase** choices only (**§B.3**); **does not block** Foundations.

**Canonical keys** (pack `creature_motor` ∪ merge defaults comments): **`goal_memory_precise_radius_px`**, **`goal_memory_moving_last_known_radius_px`**, **`goal_memory_forget_radius_px`**, **`goal_memory_ttl_sec`**, **`goal_memory_coarse_ttl_sec`**, **`goal_memory_max_entries`**, **`weight_seek_remembered_goal`**, **`weight_coarse_sector_goal_bias`**, plus **`believed_goal_*`** habitual locale knobs (**§A.3.1**).

**Code hooks:** **`_goal_belief_reset()`**, **`_goal_belief_sync_from_scene()`**, **`_goal_belief_maintain()`**, **`_goal_belief_merge_into_motor_context()`** — see [`AI_int_lib/ai_driver.gd`](../../AI_int_lib/ai_driver.gd) and **[CREATURE_MEMORY.md §5.5](CREATURE_MEMORY.md)**. **`goal_source_memory.gd`** for locale priors.

**Examples — stationary bushes:** beliefs key on **`instance_id`** (**`bush_food.gd`** stable **`global_position`**).

---

## D. World geometry & hiding (squeeze / passibility)

**Cross-link (evasion / nesting memory):** [CREATURE_MEMORY.md §7](CREATURE_MEMORY.md).

**Authoritative semantics:** [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md).

| Topic | Notes |
|-------|-------|
| **Squeeze / fit_size** | Small creatures behind `passible == false` façade — seekers and threats ultimately respect **LOS** alongside distance once pipeline ships (**resolved** below). |
| **Planner opacity** | Conservative motor until squeeze “learned” — unchanged. |

**LOS vs distance-only gates (resolved — phase 1 deferral)**

- **Target behavior (future):** **`SeekCandidate` (and symmetrical threat sampling)** exposes **`occluded` / `line_of_sight_clear`** so candidates blocked by squeeze/occluders/props are not scored as blindly reachable from **distance + cone** alone.
- **Phase 1 (this round — out of scope):** Continue **§E.1 hybrid radius + forward cone** (+ environmental placeholders) in scripted motor. **No** `occluded` field work, **no** LoS API changes in Foundations PR.
- **Follow-up:** Wire LoS via **Godot 3D ray** queries per [CREATURE_MEMORY.md §7.4](CREATURE_MEMORY.md) + backlog **§E** — after gameplay baseline and **ship profile** stabilization.

---

## E. Line of sight & awareness

### E.1 Zone of awareness — radius + forward cone (resolved — phase 1)

**Normative geometry** for live sensory ingest (food plants, mobs, prey, threats, re-awareness promotion — **[CREATURE_MEMORY.md §5.4](CREATURE_MEMORY.md)**). Matches [`CardinalAvoidance.effective_awareness_reach`](../../creature/motor/cardinal_avoidance.gd) and [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) `_effective_awareness_reach_for_driver`.

| Key | Role |
|-----|------|
| `awareness_radius` | Base omnidirectional reach (px) from creature center to target (footprint gate distance when half-extents apply). When **`≤ 0`**, live **food** ingest returns empty lists; mob cost may treat distance as unbounded (HK legacy). |
| `awareness_cone_extra` | Extra reach (px) when target lies in the **forward sector**. When **`≤ 0`**, half-angle alone does not extend reach beyond `awareness_radius`. |
| `awareness_cone_half_angle_deg` | Forward sector half-angle (degrees); facing = `last_move_direction` (or `Vector2.RIGHT`). |

Let **`u`** = unit vector creature → target, **`f`** = facing. Target is **in forward sector** when **`u·f ≥ cos(θ)`** (`θ` = half-angle).

**Effective reach (default — hybrid zone):**

| Target bearing | Effective reach |
|----------------|-----------------|
| In forward sector | **`awareness_radius + awareness_cone_extra`** |
| Outside forward sector | **`awareness_radius`** |

**Default posture (resolved):** **`awareness_forward_cone_only = false`** — zone = **rear/peripheral disk** plus **forward extended wedge**. Duel packs (rabbit, fox) ship this hybrid unless a species explicitly opts into cone-only legacy.

**Legacy opt-in:** **`awareness_forward_cone_only = true`** restricts live awareness to the forward sector only (reach **`0`** behind the creature). Reserve for strict frontal-sensing species; not the default for ENGINE movement or memory re-awareness.

**Same math, same tick — consumers:**

- `_motor_food_plants_in_awareness_by_readiness` → live food seek + `_goal_belief_sync_from_scene`
- `_motor_mobs_array` → mob repulsion + gated live / ghost memory
- `_herbivore_predator_threat_sample`, `_collect_prey_positions`, `_pursuit_targets_for_predator` (unless `herbivore_threat_awareness_omni` / `predator_prey_awareness_omni`)
- Debug overlay — [`awareness_debug_overlay.gd`](../../creature/awareness_debug_overlay.gd) (base disk + forward extra band)

**Species overrides:** Prey pursuit may use separate **`predator_prey_awareness_cone_extra`** (defaults **0** — does not reuse plant `awareness_cone_extra`).

### E.2 Line of sight (deferred backlog)

**Phase 1:** Zone of awareness remains **distance + cone** only — no occlusion ray tests.

**LOS track (future):** **Godot 3D ray** checks aligning **Tier-2 hostile detection** and **Find-food `SeekCandidate` credibility with §D** — see [CREATURE_MEMORY.md §7.4](CREATURE_MEMORY.md).

Tracking: [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md).

---

## F. Resolved from CREATURE_MEMORY (coarse tiers / movers — `goal_*` naming)

Carry-forward for ENGINE routing (**implement in memory phase**, **§B.3**). Authoritative policy: [CREATURE_MEMORY.md §5.3–§9](CREATURE_MEMORY.md).

| Topic | Resolution |
|-------|------------|
| **Coarse sectors vs landmarks** | **Egocentric** coarse sectors **for now** (creature-relative). Map-fixed landmarks **deferred** unless revisit. |
| **Forget policy** | **Combine** **`goal_memory_forget_radius_px`**, TTL since live observation (**`goal_memory_ttl_sec`**), TTL while continuously **coarse** (**`goal_memory_coarse_ttl_sec`**), LRU (**`goal_memory_max_entries`**) — ship together; tune interplay in-play. |
| **Moving prey / movers** | **Last-known disk** **`goal_memory_moving_last_known_radius_px`** (starter ~**50** px — same knob as generalized movers). Pair with ghosts / velocity when implemented. |

**Note:** Tune in **`creature_motor`** packs; **never** resurrect **`food_memory_*`** identifiers.

---

## G. Acceptance criteria — V2 movement refactor slice

**Order:** Satisfy §G prior to treating **persistent goal-memory** (`_goal_belief` / **`goal_*` keys**) as MVP-complete (**§B.3**, **§C** deferred storage strategies). Regression memory checklist (**§G.4**) runs after movement slice unless parallelized.

Motor unification separate from memory wiring — split PRs acceptable if each updates this checklist.

### G.1 Config / packs

- [x] **`creature_motor` object** under **`assets/creatures/<pack>/pack_resources.json`** overlays merged defaults (movement-weighing keys in one nested object).

- [x] **`game_config_merge.gd`** defines **`creature_motor_profile_ship`** (Phase 3 retune) and **`creature_motor_profile_dev`** (extreme aberrant overrides); **`default_creature_motor_params()`** merges spine + profile via **`use_ship_motor_profile()`** (`OS.has_feature(&"creature_motor_ship")` or editor **`hunter_killer_debug/use_ship_motor_profile`**).

- [x] Missing or partial pack `creature_motor` shallow-merges without crash; regression test asserts **dev profile** produces **aberrant** locomotion (wiring detector). **Ship executable CI** deferred until **`creature_motor_profile_ship`** finalized (**§A.1**).

### G.2 Code structure

- [x] **`GameConfig` / instantiation:** motor dict resolved **per creature instance** via **§A.1** (**`default_creature_motor_params()`** ∪ pack overlay — **no** global `creature_motor` layer): **`CreatureDefinition.asset_pack_root`** → **`pack_resources.json`** `creature_motor` keys overlay profile-backed defaults; duel `mob`, duel `player`, resolver smoke scenes, etc. behave the same mechanically; **only the pack pointer on the spawned definition** differs.

- [x] **`AiDriver`**: **`motor_target_builder.build_motor_target_lists()`** from **`feeding_mode`** + policy (**§A.2**); legacy **`_prey_positions_for_predator_motor`** / **`_motor_food_plants_*`** delegate to builder.

- [x] **`CardinalAvoidance`**: single scoring path — optional **subtract** chase pull as one term parameterized by targets, not separate `pursuit_targets` fork unless profiling demands it internally only.

### G.3 Motivation tree

- [x] Explicit **tier weights** structure in code **or** config (stub **mate** = 0).

- [x] **`preserve_bias_food_floor`**, **`seek_priority_food_ceiling`**, **`preserve_seek_blend_smoothness`**: defaults **~0.90 / ~0.80 / 0.5** in **`default_creature_motor_params()`**; **`preserve_seek_blend_smoothness`** = smoothstep aggressiveness **0…1**; jeopardy overrides via **§A.2.3**.

- [x] **`believed_goal_source_bias`** per **[CREATURE_MEMORY.md §14.1](CREATURE_MEMORY.md)** — **`goal_source_memory`**, top-3 centroid, **`cell_x/cell_y`** rows; cardinal additive pull + sector costs (**§A.3.1**); **`weight_believed_goal_pull`**, hotspot/projection **250 px**, escalate **1000 px** + **`escalate_seek_multiplier`** ([MEMORY §10](CREATURE_MEMORY.md)).

- [x] **Traits → Tier-2:** **[CREATURE_GOAL_DRIVERS.md §3.3.1](CREATURE_GOAL_DRIVERS.md)** — **`trait_tier2_mapper.gd`** urgency channels; **phase-1 stub** (zero deltas). Replay traits via **§5** unchanged.

### G.4 Memory prerequisites (subset of CREATURE_MEMORY §13 — after movement slice)

- [x] **Unified ENGINE movement baseline** (**§G.2** / duel smoke) green **before** shipping persistent memory merge that mutates **`SeekCandidate`**.

- [x] Prerequisites **predator calorie + locomotion calorie cost** before claiming pred memory parity ([CREATURE_MEMORY.md §13](CREATURE_MEMORY.md)).

- [x] When memory lands: precise merge respects **consumable_now** freeze; **`goal_memory_coarse_ttl_sec`** enforced; **no** coarse phantom **`Vector2` seek**; **re-tune** if motor quality regresses (**§B.3**).

- [x] **`strategy_class_tags.extra_modalities`** (optional pack sibling, **§A.1**) merged at spawn → **`effective_modality_allowlist`**; salient writes pass **`validate_episode_tags`** per **[CREATURE_GOAL_DRIVERS.md §5.1 — Action 1](CREATURE_GOAL_DRIVERS.md)**.

- [x] **`goal_kinds.extra_goal_kinds`** (optional pack sibling, **§A.1**) merged at spawn → **`effective_goal_kinds`**; salient writes pass **`validate_goal_kind`** per **[CREATURE_GOAL_DRIVERS.md §4.1](CREATURE_GOAL_DRIVERS.md)**.

- [x] **`find_food` `context_hash`** per **[CREATURE_MEMORY.md §2.1.1](CREATURE_MEMORY.md)** (`explore_coverage_cell_px`, world-zero origin, food **`SeekCandidate`** anchor, OOB reject write).

- [x] **`MotorContext` tactic classifier flags** (**§A.2.1**) — default modalities when classifiers stub false; **`goal_source_memory.gd`** salient path live via **`ai_driver`** outcome hooks.

- [x] **`replay_weight` multiplicative** on **`weight_believed_goal_pull`** / seek when consult hash matches — **[CREATURE_GOAL_DRIVERS.md §5.1](CREATURE_GOAL_DRIVERS.md)** (not additive cardinal fork).

---

## H. Dependencies

- [Definitive_Features/CREATURE_MOVEMENT.md](../Definitive_Features/CREATURE_MOVEMENT.md) — V1 fork inventory **to deprecate**.
- [CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md) — **canonical** motivation tree Tier-1/2, **`CreatureDefinition`** trait axes + application order, habitual **`believed_goal_*`** modulation (**§5.1** strategy-class tags — **Resolved**).
- [CREATURE_MEMORY.md](CREATURE_MEMORY.md) — canonical goal-memory tiers + TTLs; success-pattern façade (**§2.1**); trait-mediated habitual replay consumption (**§2.2**); routed into **Tier-2** (**Find food**, **Avoid hostiles**, future mate/nest/evasion payloads).
- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — field catalog; traits.
- [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) — must stay consistent (**heredity out of scope** here; genome doc may evolve separately).
- [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md).

---

## I. Changelog

| Date | Change |
|------|--------|
| 2026-05-25 | **Phase 2:** `derive_dominant_tier2_leaf` + `believed_goal_source_bias` projection wired in `ai_driver`; Phase 1 ENGINE movement foundations marked complete. |
| 2026-05-23 | **§A.3.1:** no-goal **patrol lock** — random cardinal + idle, **`motor_no_goal_patrol_lock_sec`** (1s duel default), goal interrupt. |
| 2026-05-23 | **§E.1 Resolved:** zone of awareness = **radius disk + forward cone extension** (default `awareness_forward_cone_only = false`); duel packs + memory re-awareness cross-link. |
| 2026-05-20 | **Tier B closure:** §A.1 dev=aberrant extremes / ship=stub; B-10 ship executable CI deferred; §A.2 **`AiDriver`** unified builder; §D/E LoS phase-1 out of scope; §G.1/G.2 checklist aligned. |
| 2026-05-20 | **§A.2.3 / §A.3.1:** priority **0** starvation override; **`starvation_override_food_ceiling`**; write-gate note; **§C** `_goal_belief_*` hooks → MEMORY §5.5. |
| 2026-05-19 | **§A.2.3 / §A.3.1:** derived **`dominant_tier2_leaf`**; **`preserve_seek_blend_smoothness`** default **0.5** (smoothstep aggressiveness). |
| 2026-05-19 | **§G.3:** trait → Tier-2 stub + **`trait_tier2_mapper.gd`** per **GOAL_DRIVERS §3.3.1**. |
| 2026-05-19 | **§A.3.1:** **`believed_goal_seek_escalate_radius_px`** default **1000 px** (hotspot **250 px**). |
| 2026-05-19 | **§A.3.1 / §A.2.2:** **`believed_goal_source_bias`** cardinal additive costs; **`replay_weight` multiplicative**; hotspot **250 px**; goal-seek vs food-seek phase-1 posture. |
| 2026-05-19 | **§A.2.1:** **`MotorContext`** tactic classifier flags for salient emitter (**GOAL_DRIVERS §5.1.1**). |
| 2026-05-19 | **§G.4:** checklist **`find_food` `context_hash`** (**MEMORY §2.1.1**). |
| 2026-05-19 | **§A.1:** optional pack sibling **`goal_kinds.extra_goal_kinds`** (species GoalKind extensions); spawn merge note for **`effective_goal_kinds`**. §G.4 checklist. |
| 2026-05-19 | **§A.1:** optional pack sibling **`strategy_class_tags.extra_modalities`** (species Slot B extensions); cross-link **GOAL_DRIVERS §5.1 Action 1 Resolved**. §A.3.1 stale **`<<Question>>` Actions 1–3** ref removed. |
| 2026-05-17 | **Three-way split:** motivation tree framework + **§A.4** trait content moved to **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)**; **§A.3** stub + **§A.3.1** motor keys/integration retained; **§A.4** = pointer to **GOAL_DRIVERS §3**; **§G**, **§H**, habitual replay bullets updated. |
| 2026-05-16 | **§A.3.1:** **Trait-scaled habitual replay** — **`believed_goal_*`** from **`context_hash` / LocalePriorMap**, then **§A.4 traits** modulate **reapplication** ([CREATURE_MEMORY §2.2](CREATURE_MEMORY.md)); **`explorer_builder` vs environment-alter vs explore** illustrative; drift **still out-of-scope**. Implementation slots → **MEMORY §§2–2.2**. |
| 2026-05-16 | **Naming alignment (`goal_*`):** generalized belief keys (**`goal_memory_*`**, **`weight_seek_remembered_goal`**, **`believed_goal_*`**, **`_goal_belief`** hooks); **§B**, **§C**, **§F**, **§G** synced with [CREATURE_MEMORY.md](CREATURE_MEMORY.md); **§B.2** retitled (**`feeding_mode` ingress** vs diet-archetype memory). |
| 2026-05-17 | Initial **CREATURE_MOVEMENT_V2**: goals (pack motor, unified intent ontology, motivation tree + mate stub, trait map), ported CREATURE_MEMORY food/env/LOS sections, acceptance criteria — **trait learning & heredity explicitly excluded.** |
| 2026-05-18 | **A.1** merge spine + dual **ship** / **dev** defaults in `game_config_merge`; canonical **`creature_motor` inline JSON**; per-instance pack resolution clarified; **LLM motor** marked out-of-scope — future uses **traits at minimum** + optional JSON read-through; §G checklist updated. |
| 2026-05-18 | Locked profile ids **`creature_motor_profile_dev`** / **`creature_motor_profile_ship`**; selection = export feature **`creature_motor_ship`** + **`OS.has_feature`** — **default dev** when tag absent. |
| 2026-05-18 | **§A.3.1**: Preserve∩Find resolved — **≥~90% Preserve bias**, **&lt;~80% Seek bias**, mid-band blend, per-creature keys; **`believed_goal_*`** / hotspot radii staged for memory; §G.3 checklist updated. |
| 2026-05-18 | **§A.4**: Author **survival-plan vision** — Explorer⇄Builder, Change⇄Stability, Compassion⇄self-interest⇄hoard, Community⇄Individual (incl. decoy herds, sabotage escalation); polarity table + engineering shorthand vs deferred ecology/combat. |
| 2026-05-18 | **§A.4**: Cross-links to [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) (field catalog motivation table + goals / compassion-vs-hoard) and duplicate pointer under **Compassion** bullet; **CREATURE_MEMORY** for beliefs. |
| 2026-05-18 | Resolved **slider poles** (left = first word / right = second); **player-facing implicit** traits via actions; **Avoid** acute-threat dominance **today** vs **future pack hunt / nest defense** (Builder/Stability/Compassion/Community engage); §A.3.1 + motivation table cross-refs. |
| 2026-05-18 | **Trait→Tier:** canonical **−100…+100**, **0 = midpoint**; Tier weighting uses this scale directly (divide-by-100 optional impl detail); §A.4 **Trait scale into Tier subtrees** replaces old normalize-to-±1 comment. |
| 2026-05-18 | **§B.2/B.3** phasing locked: **movement Foundations → memory full implementation → retune**. **§C** alternatives flagged **memory phase only**. **§D** LOS **resolved** (interim distance+cone; LOS property ASAP after foundations). §E + §G.4 ordering updated. |
| 2026-05-16 | **§F** closed: **egocentric** coarse sectors; **forget** = radius + TTL + LRU together (evaluate in play); **moving prey** last-known **50 px** radius baseline + tune; duplicate §F question removed. |
| 2026-05-16 | **§A.1:** Merge **base + profile inside `default_creature_motor_params()`** (explicit profile refs); **per-key precedence** = pack first, then profile-backed defaults; **removed global `creature_motor` overlay**. **§A.2/`SeekCandidate`:** **one relevance-weighted list** (top concern + proximity). **§A.3.1/`§A.4`:** Locked motor keys **`preserve_bias_food_floor`**, **`seek_priority_food_ceiling`**, **`preserve_seek_blend_smoothness`**; trait application order by **`abs`** with tie **`explorer_builder` → …**. **§G** checklist aligned. |
