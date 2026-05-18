# Hunter Killer — Creature movement V2 / unified motor (draft)

> **Purpose:** Working spec for a **movement + motivation refactor**. **Canonical goal drivers** (motivation tree Tier-1/2, `CreatureDefinition` traits, habitual **`believed_goal_*`** modulation): **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)**. This file **inherits** **goal-target / belief memory semantics** from [CREATURE_MEMORY.md](CREATURE_MEMORY.md), and adds **V2 architectural goals**: per-creature motor tuning in packs, **one** cardinal intent pipeline for all species, and **wiring** the motivation tree into `MotorContext` / cardinal scorer.
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

**Resolution rule (instantiation):** Every spawned creature gets `creature_motor` as **`default_creature_motor_params()` shallow-merged with the pack overlay** (see below). **`default_creature_motor_params()`** is the **only** authoritative place that composes (**merged into one dict**):

1. **Species-agnostic spine** — hard defaults so nothing runs with missing dicts.

2. **Exactly one profile** — **`creature_motor_profile_dev`** or **`creature_motor_profile_ship`** (locked identifiers — see selection below): **`default_creature_motor_params()` MUST reference these identifiers explicitly** (e.g. constants or map entries by id) and **select** between them using the build flag (**§Profile selection**). Implementations may extract `apply_creature_motor_profile_*` helpers for tests, but the **ship vs dev blend** observable at runtime originates from **`default_creature_motor_params()`**.

**Per-key precedence (strict):** For each **`creature_motor`** key **`k`**:

1. **Pack layer — first** (`pack_resources.json` → **`creature_motor`**, keyed by **`CreatureDefinition.asset_pack_root`**): if **`k`** is present **here**, that value wins.

2. **Else profile-backed defaults**: use **`default_creature_motor_params()[k]`** (spine ∪ selected profile).

If **all or part** of **`creature_motor`** is absent in the pack file, **missing keys** adopt **`default_creature_motor_params()`** only for those keys — the creature **still runs**; tuning may be **wrong for that species** until the pack is fixed (**acceptable per asset workflow**).

**Two merge profiles in `game_config_merge.gd` (required — locked identifiers):**

| Locked id | Audience | Behavioral intent |
|-----------|----------|-------------------|
| **`creature_motor_profile_dev`** | Editor, CI, builds **without** the ship feature tag below | **Stay put:** prefer **idle** (**`Vector2.ZERO`**) translation; tune weights / speed / lookahead so effective **displacement is negligible**. **Facing** tracks a deterministic **ordinal probe** over cardinals (~*one directional emphasis tick at a time* in test harness vernacular)—enough motion signal to validate wiring **without wandering the map**. Use for automated detection of absent/malformed pack `creature_motor`. |
| **`creature_motor_profile_ship`** | **Ship / release exports** when the export feature **`creature_motor_ship`** is enabled | **Midpoint curve:** neutral-ish behavior across motivation-trait extremes (moderate exploration, moderate hold jitter, compassionate balance not pegged)—until pack keys overlay species-specific shaping. |

**Profile selection (build flag — defaults to dev):**

- **Chosen mechanism:** Godot **export custom feature tag** **`creature_motor_ship`** (set on **production / ship presets only** in the Export dialog → *Features*, or equivalent export metadata).
- **Runtime rule:** **`default_creature_motor_params()`** calls `OS.has_feature(&"creature_motor_ship")` and merges **`creature_motor_profile_ship`** when true; otherwise merges **`creature_motor_profile_dev`** (default for editor runs, unstamped exports, missing tag). Merge helpers keyed by those two identifiers may exist for tests (**e.g.** `apply_creature_motor_profile_ship(base)`) — names must preserve the **_dev** / **_ship** suffixes; **`default_creature_motor_params()`** remains the **single entry** that performs profile selection + spine merge for production codepaths.

<<Comment: If CI needs **ship** without a packaged export, add a preset that includes **`creature_motor_ship`**, or a tiny harness that calls merge with **`creature_motor_profile_ship`** directly—avoid env knobs unless unavoidable.>>

<<Comment: Exact numeric tuning for **`creature_motor_profile_dev`** (near-zero displacement, cardinal probe sequencing) lands with the first regression test named in §G — keep both profiles authoritative only inside `game_config_merge.gd`, referenced explicitly from **`default_creature_motor_params()`**.>>

**LLM note:** **`mode` / inference** tying into `creature_motor` is **out of scope** for this refactor. Packs may still record `mode: "scripted"` for clarity; ENGINE implements scripted path only until LLM motor phase.

### A.2 Single intent path (herbivore + carnivore logic merged)

**Principle:** There is **one** scripted motor pipeline: **`AiDriver`** builds **one** `MotorContext`; **`CardinalAvoidance.pick_best_move_intent`** scores one cost stack. Species differences are **data** (`CreatureDefinition.feeding_mode`, diet policy, trait multipliers), not parallel `if prey / if mobs` code paths scattered through `ai_driver.gd`.

**Unified “targets” ontology (design target):**

| Concept today (V1) | V2 framing |
|--------------------|------------|
| `food_seek_targets`, `prey` positions separately | **`SeekCandidate`** (**one** routed list — see below): entries are **objects of relevance** to “what to pursue / avoid-soft”; **moving vs stationary** is a **subtype** on each object, **not** a separate motor ingress list. |
| `unready_food_avoid_targets` only on plants | **Same list:** edible-but-not-ready → **eligible as “food” shape but `consumable_now = false`** (repulse / low priority seek). |
| Carnivore: prey appended to food list + `pursuit_targets` | **Same list**: pursuit vs idle food is **`SeekCandidate`** metadata + combined **relevance**, not **`pursuit_targets` vs food** forked entry points (internal scorer may peel sub-terms). |
| Herbivore-only forage geom strip | Applies when **the seek list includes stationary plant-class candidates** near same cell — express as **`forage_geom_relief_radius`** keyed to **`SeekCandidate`**, not `is_in_group(&"prey")`. |

**SeekCandidate — single relevance list (resolved):**

- The motor consumes **one routed `SeekCandidate[]`** (possibly empty). Each entry carries **spatial / affordance facts** (`consumable_now`, mover vs stationary, LOS flags when wired — **§D**) plus **relevance**.
- **Relevance combines** (**at minimum** interpretation): (**a**) **affinity with the creature’s top active concern / Tier-2 focus** (“top concern”: e.g. acute hunger biases food-like entries even if secondary goals exist — align with **`MotorContext`** + motivation tree tier weights), and (**b**) **proximity to addressing that concern** (distance, reachability placeholders, directional alignment — whichever the façade exposes for that candidate class).
- **Do not maintain** parallel first-class seek vs pursuit ingest paths — **ingress normalizes into this one list**; diet / `feeding_mode` only filters **membership or metadata**, not duplicated arrays.

**Examples:**

- **Plant, not pickup-ready** → **`food_candidate = true`**, **`consumable_now = false`** (maps to today’s **unready** inverse-distance avoidance or weak seek).
- **Herbivore body to a carnivore** → **`food_candidate = true`** for that species**, **`consumable_now`** subject to gameplay rules (alive, in range, etc.).
- **Rival predator** → **`hostile = true`** (Tier 2 *Avoid hostiles*) — never “food,” separate channel from seek.

<<Comment: `DietRegistry` / `FoodIntakePolicy` should classify **interaction** (“can bite bush”); motor should classify **salience** (“target appears in seekers or hostiles”). Split keeps eating code from routing code.>>

### A.3 Motivation tree (framework)

**Canonical tree diagram, Tier-2 leaf semantics, category rollup:** **[CREATURE_GOAL_DRIVERS.md §2 — Motivation tree](CREATURE_GOAL_DRIVERS.md)**. **This section** retains **motor-specific** Preserve-vs-Find thresholds (**§A.3.1**) and **`believed_goal_*`** integration stubs (**§A.3.1** bullets).

#### A.3.1 Preserve calories vs Find food (resolved)

| Rule | Specification |
|------|----------------|
| **Not exploration-only down-weight** | **Preserve calories** may **suppress or strongly reduce** Tier-2 **Find food** weights when **`calorie_ratio`** is above a **per-creature preserve floor** — more than tweaking generic exploration noise alone. |
| **Per creature** | Floors / ceilings ship as **defaults in `default_creature_motor_params()`** (spine ∪ selected **`creature_motor_profile_*`**) and **overrides** in **`pack_resources.json` → `creature_motor`** / future **`CreatureDefinition`** exports so each archetype tunes the band. |
| **Starter thresholds** | **`calorie_ratio ≥ preserve_bias_food_floor`** (**default ~0.90**): bias **Preserve** (less seek, fewer costly detours). **`calorie_ratio < seek_priority_food_ceiling`** (**default ~0.80**): bias **Find food** (seek regains traction). **Mid band (0.80–0.90):** interpolate (smoothstep recommended) so behavior does not flip-tick between tiers — smoothness parameterized by **`preserve_seek_blend_smoothness`** (authoring semantics TBD, e.g. blend aggressiveness **`0`**–**`1`**). **`Avoid hostiles`** / jeopardy **override this hunger band** whenever **acute personal threat** applies (**today**); **future pack engage** may reorder that stack (**[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)** preamble, *Threat vs offensive*). |
| **Motor keys** (author in **`creature_motor`** when wiring) | **`preserve_bias_food_floor`**, **`seek_priority_food_ceiling`**, **`preserve_seek_blend_smoothness`**. |

##### Believed goal source / habitual locales (future — overlays goal memory)

Once memory tracks **regions or outcomes that reliably satisfied a Tier-2 goal** (nutrition first — mates, nests, bolt-holes reuse the same façade):

- **Nearby habitual locale** (within **`believed_goal_hotspot_near_radius_px`** — distance TBD, configurable per creature / pack): bias movement toward that anchor (“this patch has paid off before” for whichever **active seek leaf** dominates).
- **No nearby habitual source** (nothing within **`believed_goal_seek_escalate_radius_px`** — TBD / configurable): **elevate urgency for the dominant Tier-2 seek concern** (**Find food** in early builds; analogous rise for mates when enabled) inside the Preserve/Seek calorie-band logic described above.
- **Trait-scaled habitual replay:** **[CREATURE_GOAL_DRIVERS.md §5 — Habitual replay modulation](CREATURE_GOAL_DRIVERS.md)** (trait × strategy-class × **`believed_goal_*`**). Backends and **`context_hash`** overlays: **[CREATURE_MEMORY.md §§2.1–2.2](CREATURE_MEMORY.md)**; strategy-class **`<<Question>>` Actions 1–3** live in **GOAL_DRIVERS §5**. Same façade, **no forked ingress**.

Implementation slots: motor context **`believed_goal_source_bias`** (direction scalar, sector list, or structured field per façade), fed from [CREATURE_MEMORY.md §§2–2.2 / §10](CREATURE_MEMORY.md). Trait blend hooks run in the **same** Tier-2 / mapper stack as habitual bias; obey **[CREATURE_GOAL_DRIVERS.md §3 — Trait application order](CREATURE_GOAL_DRIVERS.md)** where multiple axes touch the same weights. **Stub during ENGINE refactor until memory lands.**

<<Comment: First implementation may omit `believed_goal_*`; document keys in **`creature_motor`** packs when wired. Nutritional hotspots may be the first consumer — still keyed generically so mates/shelter/evasion stacks without renames later.>>

### A.4 Motivation traits (`CreatureDefinition`)

**Canonical:** polarity table, UI convention, trait application order, survival-plan narrative, Tier subtree scaling, OUT OF V2 scope — **[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)**.

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
| **Coarse** | Beyond precise envelope; still remembered under forget/LRU rules | Egocentric 8-way sector each tick (**+Y = N**) | Weak cardinal bias (**`weight_coarse_sector_goal_bias`**) — **never** spoof full-precision seek |

**Alternative storage:** Mob ghosts, explore-grid keyed by **`instance_id`**, precise-only — **memory-phase** choices only (**§B.3**); **does not block** Foundations.

**Canonical keys** (pack `creature_motor` ∪ merge defaults comments): **`goal_memory_precise_radius_px`**, **`goal_memory_moving_last_known_radius_px`**, **`goal_memory_forget_radius_px`**, **`goal_memory_ttl_sec`**, **`goal_memory_coarse_ttl_sec`**, **`goal_memory_max_entries`**, **`weight_seek_remembered_goal`**, **`weight_coarse_sector_goal_bias`**, plus **`believed_goal_*`** habitual locale knobs (**§A.3.1**).

**Code hooks:** **`_goal_belief_reset()`**, **`_goal_belief_sync_from_scene()`**, optional **`creature/motor/goal_source_memory.gd`** — see [`AI_int_lib/ai_driver.gd`](../../AI_int_lib/ai_driver.gd).

**Examples — stationary bushes:** beliefs key on **`instance_id`** (**`bush_food.gd`** stable **`global_position`**).

---

## D. World geometry & hiding (squeeze / passibility)

**Cross-link (evasion / nesting memory):** [CREATURE_MEMORY.md §7](CREATURE_MEMORY.md).

**Authoritative semantics:** [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md).

| Topic | Notes |
|-------|-------|
| **Squeeze / fit_size** | Small creatures behind `passible == false` façade — seekers and threats ultimately respect **LOS** alongside distance once pipeline ships (**resolved** below). |
| **Planner opacity** | Conservative motor until squeeze “learned” — unchanged. |

**LOS vs distance-only gates (resolved)**

- **Target behavior:** **`SeekCandidate` (and symmetrical threat sampling)** exposes an **`occluded` / `line_of_sight_clear`** truth (exact API TBD) so candidates **blocked by squeeze/occluders/props** are not scored as blindly reachable solely from **distance + cone**.
- **Interim (movement Foundations phase):** Until LOS infra lands, gated targets may continue using **distance + forward cone (+ environmental placeholders)** already in scripted motor — good enough for **foundations** integration; callers document “pre-LOS caveat” for bushes/mobs tucked behind occlusion.
- **Follow-up:** Wire LOS per [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) + backlog in **§E**, then tighten seek/threat façade so **`SeekCandidate`** list matches physical reachability — **movement phase need not stall** waiting for LOS, but LOS is **in scope soon after** Foundations pass.

---

## E. Line of sight & awareness (related backlog)

**Today:** scripted motor uses primarily **distance + forward cone**.

**LOS track:** Implements **explicit reachability/occlusion checks** aligning **Tier-2 hostile detection** and **Find-food `SeekCandidate` credibility with §D** squeeze/hiding truths (see backlog + ENVIRONMENT MODEL).

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

- [ ] **`creature_motor` object** under **`assets/creatures/<pack>/pack_resources.json`** overlays merged defaults (movement-weighing keys in one nested object).

- [ ] **`game_config_merge.gd`** defines **`creature_motor_profile_ship`** and **`creature_motor_profile_dev`**; **`default_creature_motor_params()`** explicitly references **both** profiles and merges **one** spine + chosen profile via **`OS.has_feature(&"creature_motor_ship")`** (default **dev** when tag absent).

- [ ] Missing or partial pack `creature_motor` shallow-merges without crash; regression test asserts **profile-backed `default_creature_motor_params()`** when pack missing/malformed (**dev vs ship** via **`creature_motor_ship`** export feature).

### G.2 Code structure

- [ ] **`GameConfig` / instantiation:** motor dict resolved **per creature instance** via **§A.1** (**`default_creature_motor_params()`** ∪ pack overlay — **no** global `creature_motor` layer): **`CreatureDefinition.asset_pack_root`** → **`pack_resources.json`** `creature_motor` keys overlay profile-backed defaults; duel `mob`, duel `player`, resolver smoke scenes, etc. behave the same mechanically; **only the pack pointer on the spawned definition** differs.

- [ ] **`AiDriver`**: no predator/prey branching for **building `SeekCandidate[]` vs `ThreatSample[]`** beyond a **`MotorTargetPolicy`** / builder from `CreatureDefinition` + perception (**one seek list ingress** — **§A.2**).

- [ ] **`CardinalAvoidance`**: single scoring path — optional **subtract** chase pull as one term parameterized by targets, not separate `pursuit_targets` fork unless profiling demands it internally only.

### G.3 Motivation tree

- [ ] Explicit **tier weights** structure in code **or** config (stub **mate** = 0).

- [ ] **`preserve_bias_food_floor`**, **`seek_priority_food_ceiling`**, **`preserve_seek_blend_smoothness`**: **defaults ~0.90 / ~0.80** (+ blend knob as implemented), overridable per creature via **`creature_motor`** / definition; Preserve may **suppress** Find food near full; jeopardy unaffected.

- [ ] **`believed_goal_source_bias`** (motor-context façade): habitual patch bias + escalate hooks; radii **`believed_goal_hotspot_near_radius_px`**, **`believed_goal_seek_escalate_radius_px`** ([CREATURE_MEMORY.md §10](CREATURE_MEMORY.md); **§A.3.1** here).

- [ ] **Traits** plumbed **or** documented with `<<Comment>>` for first knob — **pole meaning** anchored in **[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)** (**Survival-plan vision** + shorthand table); **−100…+100** scale, **0 = midpoint**; mapper applies **trait application order** (**strongest `abs` first**; tie **`explorer_builder` → `change_stability` → `compassion_self_interest` → `community_individual`**).

### G.4 Memory prerequisites (subset of CREATURE_MEMORY §13 — after movement slice)

- [ ] **Unified ENGINE movement baseline** (**§G.2** / duel smoke) green **before** shipping persistent memory merge that mutates **`SeekCandidate`**.

- [ ] Prerequisites **predator calorie + locomotion calorie cost** before claiming pred memory parity ([CREATURE_MEMORY.md §13](CREATURE_MEMORY.md)).

- [ ] When memory lands: precise merge respects **consumable_now** freeze; **`goal_memory_coarse_ttl_sec`** enforced; **no** coarse phantom **`Vector2` seek**; **re-tune** if motor quality regresses (**§B.3**).

---

## H. Dependencies

- [Definitive_Features/CREATURE_MOVEMENT.md](../Definitive_Features/CREATURE_MOVEMENT.md) — V1 fork inventory **to deprecate**.
- [CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md) — **canonical** motivation tree Tier-1/2, **`CreatureDefinition`** trait axes + application order, habitual **`believed_goal_*`** modulation (**strategy-class** Actions 1–3).
- [CREATURE_MEMORY.md](CREATURE_MEMORY.md) — canonical goal-memory tiers + TTLs; success-pattern façade (**§2.1**); trait-mediated habitual replay consumption (**§2.2**); routed into **Tier-2** (**Find food**, **Avoid hostiles**, future mate/nest/evasion payloads).
- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — field catalog; traits.
- [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) — must stay consistent (**heredity out of scope** here; genome doc may evolve separately).
- [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md).

---

## I. Changelog

| Date | Change |
|------|--------|
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
