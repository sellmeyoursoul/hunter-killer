# Hunter Killer — Creature movement V2 / unified motor (draft)

> **Purpose:** Working spec for a **movement + motivation refactor**. This file **inherits** goal-aligned framing and food-memory substance from [CREATURE_MEMORY.md](CREATURE_MEMORY.md) (ported below where still relevant), and adds **V2 architectural goals**: per-creature motor tuning in packs, **one** cardinal intent pipeline for all species, and a **motivation tree** that future memory and traits plug into.
>
> **Tier:** Draft — supersede branching in [Definitive_Features/CREATURE_MOVEMENT.md](../Definitive_Features/CREATURE_MOVEMENT.md) when implemented; inventory doc stays authoritative for *current* code until then.
>
> **Refactor scope (ENGINE):** This phase **defines and implements scripted ENGINE motor only** (`creature_motor` weights, unified intent, motivation tree). **LLM / AI motor mode is out of scope** until ENGINE behavior is solid. When LLM motor is implemented later it must consume **motivation traits** at minimum; optionally share flattened motor params or read the species **`pack_resources.json`** so completions stay aligned with the same weighing story.
>
> **References:** [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) (`pack_resources.json`), [`creature_definition.gd`](../../creature/definition/creature_definition.gd), [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md), [game_config_merge.gd](../../AI_int_lib/game_config_merge.gd).

---

## A. Refactor stated goals

### A.1 creature_motor per pack + resilient defaults in `game_config_merge.gd`

**Target:** Per-species tuning lives in **`res://assets/creatures/<pack>/pack_resources.json`** — see **canonical shape** below. Root [`game_config.json`](../../game_config.json) and `user://game_config.json` remain **optional global overrides** where we still want a single dial for debugging.

**Canonical `pack_resources.json` shape (chosen):**

- **`"creature_motor": { … }`** at the pack root (**inline object**) holds **everything that defines movement weighing** for that species — weights, hold ticks, chaos, thresholds, Tier-2 multipliers once split, optional future keys. **Do not use** a `.tres` indirection unless we explicitly add `"creature_motor_path"` later.

**Resolution rule (instantiation):** Every spawned creature resolves **`creature_motor` by merging** (later keys override):

1. **Base fallback** — always **`default_creature_motor_params()`** in [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd) (species-agnostic spine so nothing runs with missing dicts).

2. **Profile layer** — exactly one of **`creature_motor_profile_dev`** or **`creature_motor_profile_ship`** (locked identifiers — see selection below) applies **behavior when pack/species JSON is incomplete or absent**.

3. **Pack layer** — for this instance’s **`CreatureDefinition.asset_pack_root`** (same folder as its `pack_resources.json`), **`creature_motor` object** overlays any provided keys onto (1)+(2).

4. Optional: **global** `creature_motor` from `game_config.json` / `user://` as today (document order vs pack — typically global after defaults, **pack wins last** for anything authored per species).

If **all or part** of `creature_motor` is missing in the pack file, **missing keys** **fall back** to (1)+(2). The creature **still runs** with defined behavior; it may be **wrong for that species** until the pack is fixed — that is acceptable per asset workflow.

**Two merge profiles in `game_config_merge.gd` (required — locked identifiers):**

| Locked id | Audience | Behavioral intent |
|-----------|----------|-------------------|
| **`creature_motor_profile_dev`** | Editor, CI, builds **without** the ship feature tag below | **Stay put:** prefer **idle** (**`Vector2.ZERO`**) translation; tune weights / speed / lookahead so effective **displacement is negligible**. **Facing** tracks a deterministic **ordinal probe** over cardinals (~*one directional emphasis tick at a time* in test harness vernacular)—enough motion signal to validate wiring **without wandering the map**. Use for automated detection of absent/malformed pack `creature_motor`. |
| **`creature_motor_profile_ship`** | **Ship / release exports** when the export feature **`creature_motor_ship`** is enabled | **Midpoint curve:** neutral-ish behavior across motivation-trait extremes (moderate exploration, moderate hold jitter, compassionate balance not pegged)—until pack keys overlay species-specific shaping. |

**Profile selection (build flag — defaults to dev):**

- **Chosen mechanism:** Godot **export custom feature tag** **`creature_motor_ship`** (set on **production / ship presets only** in the Export dialog → *Features*, or equivalent export metadata).
- **Runtime rule:** if `OS.has_feature(&"creature_motor_ship")` then apply **`creature_motor_profile_ship`**; else apply **`creature_motor_profile_dev`** (default for editor runs, unstamped exports, missing tag).
- Implement merge helpers keyed by those two identifiers (e.g. `apply_creature_motor_profile_ship(base)`, `apply_creature_motor_profile_dev(base)`) or a dictionary map — names must preserve the **_dev** / **_ship** suffixes.

<<Comment: If CI needs **ship** without a packaged export, add a preset that includes **`creature_motor_ship`**, or a tiny harness that calls merge with **`creature_motor_profile_ship`** directly—avoid env knobs unless unavoidable.>>

<<Comment: Exact numeric tuning for **`creature_motor_profile_dev`** (near-zero displacement, cardinal probe sequencing) lands with the first regression test named in §G — keep both profiles authoritative only inside `game_config_merge.gd`.>>

**LLM note:** **`mode` / inference** tying into `creature_motor` is **out of scope** for this refactor. Packs may still record `mode: "scripted"` for clarity; ENGINE implements scripted path only until LLM motor phase.

### A.2 Single intent path (herbivore + carnivore logic merged)

**Principle:** There is **one** scripted motor pipeline: **`AiDriver`** builds **one** `MotorContext`; **`CardinalAvoidance.pick_best_move_intent`** scores one cost stack. Species differences are **data** (`CreatureDefinition.feeding_mode`, diet policy, trait multipliers), not parallel `if prey / if mobs` code paths scattered through `ai_driver.gd`.

**Unified “targets” ontology (design target):**

| Concept today (V1) | V2 framing |
|--------------------|------------|
| `food_seek_targets`, `prey` positions separately | **`SeekTarget`** list: anything the species **would eat when “ready” / eligible**. |
| `unready_food_avoid_targets` only on plants | **Same channel:** edible-but-not-ready → **eligible as “food” shape but `consumable_now = false`** (repulse / low priority seek). |
| Carnivore: prey appended to food list + `pursuit_targets` | **One list** or **parallel samples** driven by schema: mover vs stationary stays a **subtype**, not two motor entry points. |
| Herbivore-only forage geom strip | Applies when **seek list includes stationary plant targets** near same cell — express as **`forage_geom_relief_radius`** keyed to seek targets, not `is_in_group(&"prey")`. |

**Examples:**

- **Plant, not pickup-ready** → **`food_candidate = true`**, **`consumable_now = false`** (maps to today’s **unready** inverse-distance avoidance or weak seek).
- **Herbivore body to a carnivore** → **`food_candidate = true`** for that species**, **`consumable_now`** subject to gameplay rules (alive, in range, etc.).
- **Rival predator** → **`hostile = true`** (Tier 2 *Avoid hostiles*) — never “food,” separate channel from seek.

<<Comment: `DietRegistry` / `FoodIntakePolicy` should classify **interaction** (“can bite bush”); motor should classify **salience** (“target appears in seekers or hostiles”). Split keeps eating code from routing code.>>

### A.3 Next tier: motivation tree (framework)

Higher-level planner **constraints** expressed as tiers. **Costs / weights** in the cardinal scorer are ultimately **sums of motivation-weighted utilities** aligned to this tree — after refactor, avoids ad-hoc `weight_seek_prey` vs `weight_seek_ready_food` sprawl unless they map here.

```
Tier 1 — Don’t die
├── Tier 2 — Avoid hostiles        (danger, jeopardy, mob repulsion, obstacle shield)
├── Tier 2 — Find food            (seek targets, memory merge, starvation urgency)
├── Tier 2 — Find mate           (OUT OF SCOPE impl — reserve hooks / slots only)
└── Tier 2 — Preserve calories   (movement cost awareness, throttle sprint, posture / idle when sated → future)
```

| Tier 2 leaf | Implemented today (approx.) | Extension / stub |
|-------------|----------------------------|------------------|
| **Avoid hostiles** | Mob costs, imminent gating food seek, jeopardy forced turn, `weight_obstacle_shield_prey` | Unified **threat samples**; acute threat **dominates** Tier-2 until **pack combat / nest defense** allows trait-driven **engage** (§A.4 preamble) |
| **Find food** | Live `food_plants` + prey positions → seek; hunger scales explore | **Food memory** (§C); **Preserve cross-over** (§A.3.1); future **`believed_food_source`**; diet filters **`SeekCandidate`** ingress |
| **Find mate** | — | **`MotivationWeights.mate_urgency` / slot in context** defaulted to zero; species or story enables later ([CREATURE_MEMORY.md §2 mates row](CREATURE_MEMORY.md)) |
| **Preserve calories** | Burn per distance (`game_config_merge`), hunger explore modifiers | Cross-threshold blend with **Find food** (**§A.3.1**); thrift / posture / idle when **sated** |

#### A.3.1 Preserve calories vs Find food (resolved)

| Rule | Specification |
|------|----------------|
| **Not exploration-only down-weight** | **Preserve calories** may **suppress or strongly reduce** Tier-2 **Find food** weights when **`calorie_ratio`** is above a **per-creature preserve floor** — more than tweaking generic exploration noise alone. |
| **Per creature** | Floors / ceilings ship as **defaults in `game_config_merge`** (`creature_motor_profile_*`) and **overrides** in **`pack_resources.json` → `creature_motor`** / future **`CreatureDefinition`** exports so each archetype tunes the band. |
| **Starter thresholds** | **`calorie_ratio ≥ preserve_bias_food_floor`** (**default ~0.90**): bias **Preserve** (less seek, fewer costly detours). **`calorie_ratio < seek_priority_food_ceiling`** (**default ~0.80**): bias **Find food** (seek regains traction). **Mid band (0.80–0.90):** interpolate (smoothstep recommended) so behavior does not flip-tick between tiers. **`Avoid hostiles`** / jeopardy **override this hunger band** whenever **acute personal threat** applies (**today**); **future pack engage** may reorder that stack (§A.4 preamble, *Threat vs offensive*). |
| **Planned keys** (names TBD; document in merge when coded) | e.g. `preserve_bias_food_floor`, `seek_priority_food_ceiling`, optional `preserve_seek_blend_smoothness`. |

##### Believed food source (future — food memory)

Once memory tracks **regions or sources where food has regularly appeared**:

- **Nearby habitual locale** (within **`believed_food_hotspot_near_radius_px`** — distance TBD, config per creature): bias movement **toward** that belief (“this patch has paid off before”).
- **No nearby habitual source** (nothing within **`believed_food_seek_escalate_radius_px`** — TBD / configurable): **elevate Tier-2 Find food** globally (Seek becomes dominant within the Preserve/Seek calorie band logic), i.e. “must go find something” despite moderate fullness.

Implementation slots: motor context **`believed_food_source_bias`** (direction scalar or sector list + weight), fed from façade described in §C + [CREATURE_MEMORY.md](CREATURE_MEMORY.md). **Stub during ENGINE refactor until memory lands.**

<<Comment: First implementation may omit `believed_food_*`; document keys in **`creature_motor`** when the belief layer exists.>>

### A.4 Map motivation traits (`CreatureDefinition`) to the motivation tree

**Source fields:** [`creature_definition.gd`](../../creature/definition/creature_definition.gd) — each is one scalar `@export_range(-100, 100)` whose ends are **paired opposites**:

| Export | Negative end (conceptual −100 pole) | Positive end (conceptual +100 pole) |
|--------|--------------------------------------|-------------------------------------|
| `explorer_builder` | **Explorer** | **Builder** |
| `change_stability` | **Change** | **Stability** |
| `compassion_self_interest` | **Compassion** (share) | **Self-interest / hoard** (dominate resources) |
| `community_individual` | **Community** | **Individual** |

**Cross-links**

- **`CreatureDefinition` trait fields** (-100/+100 sliders) — catalog table **Motivation traits (NPC / creature behavior drivers)** in [CREATURE_MODEL_PLAN.md §4 — Technical design — Field catalog](CREATURE_MODEL_PLAN.md#field-catalog-from-world-vision-typos-in-source-corrected).
- **Goal rank** (survival → reproduction → trait-driven tactics) plus **sharing vs hoarding** language for **`compassion_self_interest`** — [CREATURE_MODEL_PLAN.md — Goals and motivational priorities (design)](CREATURE_MODEL_PLAN.md#goals-and-motivational-priorities-design).
- **Believed / remembered resources** pooling with compassion dynamics — [CREATURE_MEMORY.md](CREATURE_MEMORY.md).

**UI & player-facing convention (resolved)**

- **Authoring / internal:** For every trait export, **slider left (−100)** = **first pole** in the pair (Explorer, Change, Compassion, Community); **slider right (+100)** = **second pole** (Builder, Stability, Self-interest, Individual). Consistent across all four fields.

- **Player-facing (future):** Dichotomies are **not exposed as raw sliders** — players infer personality from **observed actions**; design maps those actions back to the same −100/+100 semantics so species stay data-driven.

Traits are **knobs**, not branching scripts: runtime maps them to Tier-2 **weights** (`Find food`, `Find mate`, `Preserve calories`, spatial strategy, someday **world interaction** crush/nest/build).

**Threat vs offensive / social combat (current vs future)**

- **Today (ENGINE / pre–rich combat):** **`Avoid hostiles`** is **dominant** whenever **acute personal threat** applies (imminent predator, jeopardy): flee / evade **hard-wins** over food seek and other Tier-2 urges so **escape is not overridden** by foraging or exploration in those states.

- **Future (pack / nest defense / coordinated hunt):** Trait blends such as **high Builder** (defend resource or nest), **Stability** (hold line, don’t scatter), **Compassion** / **Community** (risk for kin or shared asset) can authorize **coordinated engage** — e.g. wolves **pack-hunting** a large target, rabbits **collectively defending** a nest from a fox — so **avoidance is no longer unconditional** once **group combat verbs** and **objective pinning** (“defend nest id X”) exist; design must **tier** personal survival vs communal objective (**supersedes naive Avoid hard-win**).

---

#### Survival-plan vision (author intent — informs future systems)

Below is **design vocabulary** tying each dichotomy to **Don’t die / reproduce**. Systems marked **future** depend on ecology, crush, nests, richer combat—not ENGINE cardinal refactor alone.

**Explorer ⇄ Builder**

- **Explorer (−)** — **covers ground** to **discover and register** sources: food hotspots, mates, shelter options. Supports **belief maps** (**`believed_food_source`**, mate sites) and wider **trail / explore** modulation in motor.
- **Builder (+)** — **thickens yield at known locations**: e.g. **crush competing non-food** so favoured food spreads; maintain **nest / safe substrate** so mates reproduce (**future** ecology + build verbs). Builder bias **de‑emphasizes blind roam** versus fortifying patches already known.

Motor **today-ish:** Explorer → weaker trail repulsion, stronger expanding sweep / coverage; Builder → tighter orbit around **`SeekCandidate`** + belief anchors (**future**: action layer for crush/nest—not Tier-2 cost only).

**Change ⇄ Stability**

- **Change (−)** — **alters environment or strategy** aggressively. High **Explorer** ⇒ maximise **new terrain + new hypotheses** (“always stir the pot”). High **Builder** ⇒ **actively reshape locality** (competitors removed, corridors opened, nests adjusted).
- **Stability (+)** — **preserve what works**. High **Explorer** ⇒ establish a **preferred range**: cycle known patches; only radiate outward when locals fail or external **pressure**. High **Builder** ⇒ **incremental tuning** at one focal resource—minor adjustments, reluctant to bulldoze; may **suppress** uprooting an established crop even if something “faster-growing” arrives (competition favors **steady state** unless forced).

Cross with **Explorer** explorer+change vs explorer+stability distinguishes **nomadic scan** vs **patrol within home range**.

**Compassion ⇄ Self-interest**

- **Compassion (−)** — tolerate **sharing** food / mate access; weaker conspecific aggression (**future melee / chase-off** mechanics).
- **Self-interest (+)** — **hoard**, contest, chase rivals from resources or mating opportunities (when combat depth exists).

Tier-2 effect **before combat:** weak modulation of **crowding toward same SeekTarget**, **pseudo-priority bumps** toward contested patches (stub). Fully realized only with **faction / conspecific threat** tuning. Canonical **sharing vs hoarding** prose for **`compassion_self_interest`** is pinned in **[CREATURE_MODEL_PLAN.md — Goals and motivational priorities](CREATURE_MODEL_PLAN.md#goals-and-motivational-priorities-design)** (see **Cross-links** above).

**Community ⇄ Individual**

- **Community (−)** — **wants kin nearby** — shared growth if **paired with compassion**; paired with **self-interest** ⇒ **prefer other bodies as decoys/distraction for predators**, not necessarily benign sharing.

- **Individual (+)** — **solo bias**. Paired **compassion**: tolerate transient **overlap** (another eats / mates then leaves); lingering conspecific **can flip to hostility** if space feels violated (**future script**). Paired **self-interest**: proactively **fight or steal**. With **high Change**, if too weak to evict rivals by force ⇒ **destructive sabotage** of contested resources (**future**—“scorched earth” escalation path).

Tier-2 + motor: herd **centering potential fields** (**future**) vs lone **tangential roam** vectors; overlaps **Avoid hostiles** when conspecific rivalry becomes a ThreatSample.

---

**Summary table — traits → Tier-2 emphasis (engineering shorthand)**

| Trait axis | Rough Tier-2 / systems touch | Motor / scaffold today | Deferred |
|------------|------------------------------|------------------------|----------|
| **Explorer–Builder** | **Find food** coverage vs patch fortification | Explore weights, hotspot bias (**§A.3.1**) | Crush / nest ecology |
| **Change–Stability** | Roam novelty vs patrol / incremental optimise | Escape vs hold (`scripted_intent_hold`), expanding hint | Landscaping / selective crush |
| **Compassion–Self-interest** | Conspecific contest vs share | Minimal | Detailed combat chase-off |
| **Community–Individual** | Aggregate vs solo roam; decoy herd | Minimal | Mate proximity, riot logic |

**Trait scale into Tier subtrees (resolved)**

- **`CreatureDefinition` authoring scale** stays **−100 … +100** on each slider, with **0 = midpoint** between the two poles (**neutral** blending — ship profile targets this region per §A.1).
- Tier-2 weight deltas read **directly from this scalar** (e.g. `weight_x += trait_scale * explorer_builder / 100.0` patterns) unless a subsystem documents a different lawful transform; **no separate mandatory normalization** to auxiliary \([−1,+1]\) storage — \(/100\) is an implementation detail inside the mapper.
- **First trait wired into motor:** add the concrete formula (per trait → which Tier-2 terms) beside `game_config_merge` or the motor façade so tuning stays auditable.

**OUT OF V2 scope (explicit):**

| Topic | Boundary |
|-------|----------|
| **Heredity** | No genetic transfer of traits or motor params in this refactor. |
| **Experience-driven trait drift** | Motivation traits are **fixed at spawn / definition** until a future system explicitly adds learning. |

---

## B. Port from CREATURE_MEMORY (goal-aligned beliefs — still applicable)

*(Sections below summarize [CREATURE_MEMORY.md](CREATURE_MEMORY.md); V2 refactor **does not replace** belief design — it **routes** beliefs through the unified motivation tree and pack-scoped motor data.)*

### B.1 What memory is for (goal-aligned categories)

Creature memory remains a **working set of salient world facts** keyed to goals — not a telemetry dump.

| Category | Goals | Relation to Tier 2 |
|----------|-------|---------------------|
| **Danger** | Don’t die | **Avoid hostiles** |
| **Food** | Don’t die | **Find food** |
| **Mates / reproduction** | Reproduce | **Find mate** (stub) |
| **Shelter / rest** | Don’t die; comfort | Mostly future; aligns with **Preserve calories** + safe posture when specified |

### B.2 Diet archetype (`feeding_mode`) in V2

**V1 wording:** predator vs omnivore vs herbivore changes emphasis.

**V2 wording:** **`feeding_mode` only decides which candidates enter `SeekTarget`** and **consumption rules**. The **motor does not fork** — it consumes a normalized **`SeekCandidate[]`** plus **`ThreatSample[]`** from a builder step (perception facade).

**Phasing stance:** Accepted as written; delivery order (**movement foundations → memory → retune**) is nailed in **§B.3**.

### B.3 Implementation order — maintainer-approved phasing

1. **`feeding_mode`** as **ingress-only** (**§B.2**) remains correct; predator/prey calorie path + **movement calorie cost** (per [CREATURE_MEMORY.md §3](CREATURE_MEMORY.md)) still gate claiming **predator memory-complete UX** wherever that overlaps schedule.

2. **Phase — ENGINE movement first (this document’s refactor slice):** Land **correct unified scripted movement**: pack merges, **`creature_motor_profile_*`**, single intent plumbing, avoidance/seek correctness from live sense + existing geometry gates. **Do not ship** persisted **food-source memory** persistence in this same slice unless it is negligible glue.

3. **Phase — food / belief memory second:** **Full** memory implementation (§C + [CREATURE_MEMORY.md](CREATURE_MEMORY.md)): merge **`SeekCandidate ∪ remembered`** through one façade. **Tune after integration** — if memory **degrades movement** versus the **movement-phase baseline**, adjust weights/rules in a focused follow‑up (movement truth wins until memory proven stable).

4. Technical enabler retained from prior draft: unify motor **routing** early so **`SeekCandidate` ownership** stays one codepath **before** memory writes into it.

---

## C. Food-source memory (design — not fully implemented)

**Goal:** Remember discovered food after it leaves awareness — without omniscient seek.

**Movement refactor scope:** The **tier table**, **planned keys**, and **hooks** below remain **canonical design reference** ([CREATURE_MEMORY.md](CREATURE_MEMORY.md)); **implementing or choosing among storage strategies** waits for the dedicated **memory phase** (**§B.3**).

*(Identical semantic tables to CREATURE_MEMORY; V2 applies them to **`SeekTarget` + freshness flags**, not “prey list” vs “bush list”.)*

| Tier | Condition (baseline) | Representation | Motor use |
|------|----------------------|----------------|-----------|
| **Precise** | `distance(creature, last_world_pos) ≤ food_memory_precise_radius_px` (**1000** px default in comments) | `Vector2` + frozen **consumable_now** snapshot | Merge into **`SeekCandidate` precise tier** → same channel as live plants/prey samples |
| **Coarse** | Beyond precise radius, still remembered | **Egocentric** 8-way sector each tick (+Y = N) | Weak cardinal bias / LLM text — **not** fake world bearing |

**Alternative implementations (defer to memory-design work — out of movement phase)**

Choices below are **comparisons only** until memory phase selects one (or hybrids). **Does not gate** ENGINE movement Foundations.

1. Mob-style ghost (`_mob_hist` pattern).  
2. Explore-grid keyed by bush **instance id** (cheap, risk of ambiguity).  
3. Precise-only forget.

**Planned config keys:** `food_memory_precise_radius_px`, `food_memory_forget_radius_px`, `food_memory_ttl_sec`, `food_memory_max_entries`, `weight_seek_remembered_food`, `weight_coarse_sector_food_bias` — **migrate to pack `creature_motor` / sibling manifest** alongside global fallback defaults.

**Hooks:** `_food_belief_reset()`, `_food_belief_sync_from_scene()` (see [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) comments).

Stationary bushes: beliefs key on **`instance_id`** (`bush_food.gd` stable `global_position`).

---

## D. World geometry & hiding (squeeze / passibility)

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

## F. Resolved from CREATURE_MEMORY (food / coarse / movers)

Carry-forward decisions for ENGINE routing and predator prey-memory shaping (**full implementation in memory phase**, **§B.3**). Source parallel: [CREATURE_MEMORY.md](CREATURE_MEMORY.md) §6 / open items — reconcile that doc when memory work lands.

| Topic | Resolution |
|-------|------------|
| **Coarse sectors vs landmarks** | **Egocentric** coarse sectors for ENGINE routing **for now** (creature-relative bearings/sectors). Map-fixed landmarks **deferred** unless a later spec revisits navigation. |
| **Forget policy** | **Combine** `food_memory_forget_radius_px` **+** time-since-observation TTL (`food_memory_ttl_sec`) **+** LRU cap (`food_memory_max_entries`) — implement together and **evaluate in play**; adjust weights/order if the interaction feels wrong. |
| **Moving food (prey)** | Treat a **last-seen credibility region:** **50 px** radius around the **last known position** as the initial default (**tune from playtest**). Prey beliefs follow **the same memory rules** as the rest of the food-memory design as they are implemented (instance id, velocity/ghost behavior, tier merge, etc.—see CREATURE_MEMORY). |

**Note:** The **50 px** default is a starting scalar for predator prey “where to look” after losing line-of-sight; promote to a **`creature_motor` / food-memory config key** when wiring (name TBD, e.g. `food_memory_prey_last_seen_radius_px`).

---

## G. Acceptance criteria — V2 movement refactor slice

**Order:** Satisfy §G prior to treating **persistent food-memory** implementation as MVP-complete (**§B.3**, **§C** deferred alternatives). Regression memory checklists (**§G.4**) run after movement slice unless explicitly parallelized.

Motor unification separate from memory wiring — split PRs acceptable if each updates this checklist.

### G.1 Config / packs

- [ ] **`creature_motor` object** under **`assets/creatures/<pack>/pack_resources.json`** overlays merged defaults (movement-weighing keys in one nested object).

- [ ] **`game_config_merge.gd`** defines **`creature_motor_profile_ship`** and **`creature_motor_profile_dev`** layers on top of the shared spine; selection uses **`OS.has_feature(&"creature_motor_ship")`** (default **dev** when tag absent).

- [ ] Missing or partial pack `creature_motor` shallow-merges without crash; regression test asserts **`creature_motor_profile_dev`** when pack missing/malformed; ship exports enable **`creature_motor_ship`** to exercise **`creature_motor_profile_ship`** fallbacks.

- [ ] Root [`game_config.json`](../../game_config.json) documents **globals-only** overrides (never the canonical home for per-species authoring).

### G.2 Code structure

- [ ] **`GameConfig` / instantiation:** motor dict resolved **per creature instance** from that instance’s **`CreatureDefinition.asset_pack_root`** → **`pack_resources.json`** `creature_motor` + merges (1)–(4) above — duel `mob`, duel `player`, resolver smoke scenes, etc. behave the same mechanically; **only the pack pointer on the spawned definition** differs.

- [ ] **`AiDriver`**: no predator/prey branching for **building seek vs threat arrays** beyond a **`MotorTargetPolicy`** / builder from `CreatureDefinition` + perception.

- [ ] **`CardinalAvoidance`**: single scoring path — optional **subtract** chase pull as one term parameterized by targets, not separate `pursuit_targets` fork unless profiling demands it internally only.

### G.3 Motivation tree

- [ ] Explicit **tier weights** structure in code **or** config (stub **mate** = 0).

- [ ] **`preserve_bias_food_floor` / `seek_priority_food_ceiling`** (or final names): **defaults ~0.90 / ~0.80**, overridable per creature via **`creature_motor`** / definition; Preserve may **suppress** Find food near full; jeopardy unaffected.

- [ ] **`believed_food_source`** (or contextual equivalent): stub fields in motor context document for food-memory façade; hotspots + escalate radii **`believed_food_hotspot_near_radius_px`**, **`believed_food_seek_escalate_radius_px`** when implemented.

- [ ] **Traits** plumbed **or** documented with `<<Comment>>` for first knob — **pole meaning** anchored in §A.4 (**Survival-plan vision** + shorthand table); **−100…+100** scale, **0 = midpoint** (**Trait scale into Tier subtrees**).

### G.4 Memory prerequisites (subset of CREATURE_MEMORY §10 — after movement slice)

- [ ] **Unified ENGINE movement baseline** (**§G.2** / duel smoke) green **before** shipping persistent memory merge that mutates **`SeekCandidate`**.

- [ ] Prerequisites **predator calorie + locomotion calorie cost** before claiming pred memory parity ([CREATURE_MEMORY.md §10](CREATURE_MEMORY.md)).

- [ ] When memory lands: precise merge respects **consumable_now** freeze; no coarse phantom `Vector2` seek; **re-tune** if motor quality regresses (**§B.3**).

---

## H. Dependencies

- [Definitive_Features/CREATURE_MOVEMENT.md](../Definitive_Features/CREATURE_MOVEMENT.md) — V1 fork inventory **to deprecate**.
- [CREATURE_MEMORY.md](CREATURE_MEMORY.md) — canonical until merge; beliefs feed **Find food** / **Danger**.
- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — field catalog; traits.
- [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) — must stay consistent (**heredity out of scope** here; genome doc may evolve separately).
- [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md).

---

## I. Changelog

| Date | Change |
|------|--------|
| 2026-05-17 | Initial **CREATURE_MOVEMENT_V2**: goals (pack motor, unified intent ontology, motivation tree + mate stub, trait map), ported CREATURE_MEMORY food/env/LOS sections, acceptance criteria — **trait learning & heredity explicitly excluded.** |
| 2026-05-18 | **A.1** merge spine + dual **ship** / **dev** defaults in `game_config_merge`; canonical **`creature_motor` inline JSON**; per-instance pack resolution clarified; **LLM motor** marked out-of-scope — future uses **traits at minimum** + optional JSON read-through; §G checklist updated. |
| 2026-05-18 | Locked profile ids **`creature_motor_profile_dev`** / **`creature_motor_profile_ship`**; selection = export feature **`creature_motor_ship`** + **`OS.has_feature`** — **default dev** when tag absent. |
| 2026-05-18 | **§A.3.1**: Preserve∩Find resolved — **≥~90% Preserve bias**, **&lt;~80% Seek bias**, mid-band blend, per-creature keys; **`believed_food_source`** / hotspot radii staged for memory; §G.3 checklist updated. |
| 2026-05-18 | **§A.4**: Author **survival-plan vision** — Explorer⇄Builder, Change⇄Stability, Compassion⇄self-interest⇄hoard, Community⇄Individual (incl. decoy herds, sabotage escalation); polarity table + engineering shorthand vs deferred ecology/combat. |
| 2026-05-18 | **§A.4**: Cross-links to [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) (field catalog motivation table + goals / compassion-vs-hoard) and duplicate pointer under **Compassion** bullet; **CREATURE_MEMORY** for beliefs. |
| 2026-05-18 | Resolved **slider poles** (left = first word / right = second); **player-facing implicit** traits via actions; **Avoid** acute-threat dominance **today** vs **future pack hunt / nest defense** (Builder/Stability/Compassion/Community engage); §A.3.1 + motivation table cross-refs. |
| 2026-05-18 | **Trait→Tier:** canonical **−100…+100**, **0 = midpoint**; Tier weighting uses this scale directly (divide-by-100 optional impl detail); §A.4 **Trait scale into Tier subtrees** replaces old normalize-to-±1 comment. |
| 2026-05-18 | **§B.2/B.3** phasing locked: **movement Foundations → memory full implementation → retune**. **§C** alternatives flagged **memory phase only**. **§D** LOS **resolved** (interim distance+cone; LOS property ASAP after foundations). §E + §G.4 ordering updated. |
| 2026-05-16 | **§F** closed: **egocentric** coarse sectors; **forget** = radius + TTL + LRU together (evaluate in play); **moving prey** last-known **50 px** radius baseline + tune; duplicate §F question removed. |
