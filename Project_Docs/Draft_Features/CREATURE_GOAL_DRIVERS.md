# Hunter Killer — Creature goal drivers (draft)

> **Purpose:** **Canonical hub** for **runtime goal semantics** shared by motor and memory: **motivation tree** (Tier-1 / Tier-2), **`CreatureDefinition` motivation traits** (−100…+100), **GoalKind / category rollup** to Tier-2 leaves, and **trait × strategy-class** habitual replay modulation (`believed_goal_*`). This file does **not** specify cardinal scorer math, **`creature_motor`** pack merge keys, or belief TTL/schema — those stay in **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** and **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** respectively.
>
> **Tier:** Draft (tier II) — promote when stable alongside sibling drafts.
>
> **Read order:** **[CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)** (field catalog, motivational priorities) → **this file** (drivers) → **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** (pipeline, `SeekCandidate`, phasing) → **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** (storage, `goal_*` / `believed_goal_*` identifiers, **§14** backends).
>
> **Naming:** Distinct from archived **[Completed_Features/CREATURE_GOALS.md](../Completed_Features/CREATURE_GOALS.md)** (tier A snapshot).

---

## 1. Goal drivers overview

A **goal driver** is the combination of:

1. **Tier-2 motivation leaves** — which survival/reproduction concerns are active (**Avoid hostiles**, **Find food**, …).
2. **`CreatureDefinition` trait axes** — how strongly each pole biases Tier-2 weights and habitual replay (**§3**).
3. **`GoalKind`-aligned memory aggregates** — locale priors and episodic traces keyed for habitual **`believed_goal_*`** projection (**[CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)**); **`context_hash`** overlays are defined **there**.

**Non-scope:** `SeekCandidate` build rules, `creature_motor` thresholds (**CREATURE_MOVEMENT_V2 §A.2–A.3.1**), precise/coarse belief tiers (**CREATURE_MEMORY §5–6**).

---

## 2. Motivation tree

Higher-level planner **constraints** expressed as tiers. **Costs / weights** in the cardinal scorer are ultimately **sums of motivation-weighted utilities** aligned to this tree — avoids ad-hoc `weight_seek_prey` vs `weight_seek_ready_food` sprawl unless they map here. **Integration:** **[CREATURE_MOVEMENT_V2.md §A.2–A.3.1](CREATURE_MOVEMENT_V2.md)**.

```
Tier 1 — Don’t die
├── Tier 2 — Avoid hostiles        (danger, jeopardy, mob repulsion, obstacle shield)
├── Tier 2 — Find food            (seek targets, memory merge, starvation urgency)
├── Tier 2 — Find mate           (OUT OF SCOPE impl — reserve hooks / slots only)
└── Tier 2 — Preserve calories   (movement cost awareness, throttle sprint, posture / idle when sated → future)
```

| Tier 2 leaf | Implemented today (approx.) | Extension / stub |
|-------------|----------------------------|------------------|
| **Avoid hostiles** | Mob costs, imminent gating food seek, jeopardy forced turn, `weight_obstacle_shield_prey` | Unified **threat samples**; acute threat **dominates** Tier-2 until **pack combat / nest defense** allows trait-driven **engage** (**§3** preamble) |
| **Find food** | Live `food_plants` + prey positions → seek; hunger scales explore | **Goal-target memory** (**CREATURE_MOVEMENT_V2 §C**; tier rules **[CREATURE_MEMORY.md §5](CREATURE_MEMORY.md)**); **Preserve cross-over** (**CREATURE_MOVEMENT_V2 §A.3.1**); habitual **`believed_goal_*`** bias (**§5** below); **`feeding_mode`** filters **`SeekCandidate`** ingress (**CREATURE_MOVEMENT_V2 §B.2**) |
| **Find mate** | — | **`MotivationWeights.mate_urgency` / slot in context** defaulted to zero; species or story enables later (**[CREATURE_MEMORY.md §3 — Mates row](CREATURE_MEMORY.md)**) |
| **Preserve calories** | Burn per distance (`game_config_merge`), hunger explore modifiers | Cross-threshold blend with **Find food** (**CREATURE_MOVEMENT_V2 §A.3.1**); thrift / posture / idle when **sated** |

---

## 3. Trait axes (`CreatureDefinition`)

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
- **Believed / remembered resources** — pooling and compassion dynamics — [CREATURE_MEMORY.md](CREATURE_MEMORY.md).

**UI & player-facing convention (resolved)**

- **Authoring / internal:** For every trait export, **slider left (−100)** = **first pole** in the pair (Explorer, Change, Compassion, Community); **slider right (+100)** = **second pole** (Builder, Stability, Self-interest, Individual). Consistent across all four fields.

- **Player-facing (future):** Dichotomies are **not exposed as raw sliders** — players infer personality from **observed actions**; design maps those actions back to the same −100/+100 semantics so species stay data-driven.

Traits are **knobs**, not branching scripts: runtime maps them to Tier-2 **weights** (`Find food`, `Find mate`, `Preserve calories`, spatial strategy, someday **world interaction** crush/nest/build).

**Trait application order (resolved):** When **multiple motivation traits** influence the same mapper pass (formula application, modulation passes, Tier-2 weight stacking — wherever traits are consulted in one tick), evaluate trait contributions **in descending strength**:

- **Strength** of a trait axis = **`abs(trait_value)`** (**distance from 0 midpoint** toward **−100** or **+100**). Apply **strongest first**, then **next strongest**, through **weakest last** (**abs** closest **0**).
- **Ties** (equal **`abs`**): **`explorer_builder`** → **`change_stability`** → **`compassion_self_interest`** → **`community_individual`**.

Same axis is evaluated **once per pass** at its slot in that sorted order (**no duplicate application** solely for reordering).

**Threat vs offensive / social combat (current vs future)**

- **Today (ENGINE / pre–rich combat):** **`Avoid hostiles`** is **dominant** whenever **acute personal threat** applies (imminent predator, jeopardy): flee / evade **hard-wins** over food seek and other Tier-2 urges so **escape is not overridden** by foraging or exploration in those states.

- **Future (pack / nest defense / coordinated hunt):** Trait blends such as **high Builder** (defend resource or nest), **Stability** (hold line, don’t scatter), **Compassion** / **Community** (risk for kin or shared asset) can authorize **coordinated engage** — e.g. wolves **pack-hunting** a large target, rabbits **collectively defending** a nest from a fox — so **avoidance is no longer unconditional** once **group combat verbs** and **objective pinning** (“defend nest id X”) exist; design must **tier** personal survival vs communal objective (**supersedes naive Avoid hard-win**).

---

### 3.1 Survival-plan vision (author intent — informs future systems)

Below is **design vocabulary** tying each dichotomy to **Don’t die / reproduce**. Systems marked **future** depend on ecology, crush, nests, richer combat—not ENGINE cardinal refactor alone.

**Explorer ⇄ Builder**

- **Explorer (−)** — **covers ground** to **discover and register** sources: food hotspots, mates, nesting/shelter options. Supports **belief maps** anchored by **`believed_goal_*`** knobs (**§5**) plus per-goal payload records in CREATURE_MEMORY, and wider **trail / explore** modulation in motor.
- **Builder (+)** — **thickens yield at known locations**: e.g. **crush competing non-food** so favoured food spreads; maintain **nest / safe substrate** so mates reproduce (**future** ecology + build verbs). Builder bias **de‑emphasizes blind roam** versus fortifying patches already known.

Motor **today-ish:** Explorer → weaker trail repulsion, stronger expanding sweep / coverage; Builder → tighter orbit around **`SeekCandidate`** + belief anchors (**future**: action layer for crush/nest—not Tier-2 cost only).

**Change ⇄ Stability**

- **Change (−)** — **alters environment or strategy** aggressively. High **Explorer** ⇒ maximise **new terrain + new hypotheses** (“always stir the pot”). High **Builder** ⇒ **actively reshape locality** (competitors removed, corridors opened, nests adjusted).
- **Stability (+)** — **preserve what works**. High **Explorer** ⇒ establish a **preferred range**: cycle known patches; only radiate outward when locals fail or external **pressure**. High **Builder** ⇒ **incremental tuning** at one focal resource—minor adjustments, reluctant to bulldoze; may **suppress** uprooting an established crop even if something “faster-growing” arrives (competition favors **steady state** unless forced).

Cross with **Explorer** explorer+change vs explorer+stability distinguishes **nomadic scan** vs **patrol within home range**.

**Compassion ⇄ Self-interest**

- **Compassion (−)** — tolerate **sharing** food / mate access; weaker conspecific aggression (**future melee / chase-off** mechanics).
- **Self-interest (+)** — **hoard**, contest, chase rivals from resources or mating opportunities (when combat depth exists).

Tier-2 effect **before combat:** weak modulation of **crowding toward the same `SeekCandidate`**, **pseudo-priority bumps** toward contested patches (stub). Fully realized only with **faction / conspecific threat** tuning. Canonical **sharing vs hoarding** prose for **`compassion_self_interest`** is pinned in **[CREATURE_MODEL_PLAN.md — Goals and motivational priorities](CREATURE_MODEL_PLAN.md#goals-and-motivational-priorities-design)** (see **Cross-links** above).

**Community ⇄ Individual**

- **Community (−)** — **wants kin nearby** — shared growth if **paired with compassion**; paired with **self-interest** ⇒ **prefer other bodies as decoys/distraction for predators**, not necessarily benign sharing.

- **Individual (+)** — **solo bias**. Paired **compassion**: tolerate transient **overlap** (another eats / mates then leaves); lingering conspecific **can flip to hostility** if space feels violated (**future script**). Paired **self-interest**: proactively **fight or steal**. With **high Change**, if too weak to evict rivals by force ⇒ **destructive sabotage** of contested resources (**future**—“scorched earth” escalation path).

Tier-2 + motor: herd **centering potential fields** (**future**) vs lone **tangential roam** vectors; overlaps **Avoid hostiles** when conspecific rivalry becomes a ThreatSample.

---

### 3.2 Summary table — traits → Tier-2 emphasis (engineering shorthand)

| Trait axis | Rough Tier-2 / systems touch | Motor / scaffold today | Deferred |
|------------|------------------------------|------------------------|----------|
| **Explorer–Builder** | **Find food** coverage vs patch fortification | Explore weights, hotspot bias (**CREATURE_MOVEMENT_V2 §A.3.1**) | Crush / nest ecology |
| **Change–Stability** | Roam novelty vs patrol / incremental optimise | Escape vs hold (`scripted_intent_hold`), expanding hint | Landscaping / selective crush |
| **Compassion–Self-interest** | Conspecific contest vs share | Minimal | Detailed combat chase-off |
| **Community–Individual** | Aggregate vs solo roam; decoy herd | Minimal | Mate proximity, riot logic |

### 3.3 Trait scale into Tier subtrees (resolved)

- **`CreatureDefinition` authoring scale** stays **−100 … +100** on each slider, with **0 = midpoint** between the two poles (**neutral** blending — ship profile targets this region per **CREATURE_MOVEMENT_V2 §A.1**).
- Tier-2 weight deltas read **directly from this scalar** (e.g. `weight_x += trait_scale * explorer_builder / 100.0` patterns) unless a subsystem documents a different lawful transform; **no separate mandatory normalization** to auxiliary \([−1,+1]\) storage — \(/100\) is an implementation detail inside the mapper.
- **First trait wired into motor:** add the concrete formula (per trait → which Tier-2 terms) beside `game_config_merge` or the motor façade so tuning stays auditable.

### 3.4 OUT OF V2 scope (explicit)

| Topic | Boundary |
|-------|----------|
| **Heredity** | No genetic transfer of traits or motor params in this refactor. |
| **Experience-driven trait drift** | Motivation traits are **fixed at spawn / definition** until a future system explicitly adds learning. |

---

## 4. Goal kinds and Tier-2 rollup

Memory **categories** align to Tier-2 leaves (**§2**). Implementation phasing lives in **[CREATURE_MEMORY.md §3](CREATURE_MEMORY.md)**.

| Category | Tier-2 / goals | Notes |
|----------|----------------|-------|
| **Nutrition (“find food”)** | **Find food** | First consumer for generalized schema; payloads optional (**CREATURE_MEMORY §5–6**). |
| **Mates / reproduction** | **Find mate** | Stub urgency until mating systems land; same **`goal_*`** façade (**CREATURE_MEMORY §10**). |
| **Danger / hostiles** | **Avoid hostiles** | Threat samples / jeopardy; coarse beliefs where applicable. |
| **Finding shelter** (evasion / nesting) | **Avoid hostiles** + survival reproduce posture | Squeeze, bolt-holes — **[CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)**; intersects **Preserve** / rest comfort later. |

**Movement mirror:** **[CREATURE_MOVEMENT_V2.md §B.1](CREATURE_MOVEMENT_V2.md)** (belief categories ↔ Tier 2).

---

## 5. Habitual replay modulation (trait × strategy-class tags × `believed_goal_*`)

**Reads first:** **[CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)** (`LocalePriorMap` / `ExperienceRing` → façade); **[CREATURE_MOVEMENT_V2.md §A.3.1](CREATURE_MOVEMENT_V2.md)** (`MotorContext` **`believed_goal_source_bias`**, radii).

After locale priors project into **`believed_goal_*`** / habitual bias, **`CreatureDefinition` traits** (**§3**) scale **how strongly** to **reapply** remembered outcomes — same façade, **no forked ingress**. **`context_hash`** composition and backend knobs (**write gates**, decay, overlays per `GoalKind`) are authoritative in **[CREATURE_MEMORY.md §§2.1, 14](CREATURE_MEMORY.md)**.

**Principle**

- **`context_hash`** encodes situation class — spatial cell, passage fit, or (later) **effect class** (“changed local environment” vs “discovered new route”).
- **Traits modulate how much to favor reusing that class** when merging into Tier-2 (**§3** application order when multiple axes touch the same weights).

**Illustrative tension** (authoring example until **Actions 1–2** land — **multi-tag combine rule** is **Resolved** below):

| **If `context_hash` / strategy-class tags imply…** | **Builder pole** (positive `explorer_builder`) | **Explorer pole** (negative `explorer_builder`) |
|----------------------------------------------------|-----------------------------------------------|--------------------------------------------------|
| Strategy involved **lasting local change** (terraformed pocket, nest prep, blocked lane) | **Higher** weight to **reapply** that remembered pattern | **Lower** weight — prefers fresh scan over repeating “settled” plays |
| Strategy was **pure reconnaissance / roaming payoff** | **Lower** relative emphasis vs stable patch bias | **Higher** weight to repeat similar wander / probe plays |

**Today (ENGINE + staged memory):** traits **read-only at spawn** (**§3.4**). Apply trait mediation as **read-only multipliers or blends** on **`believed_goal_*`** — **not** silent trait mutation.

**Future:** explicit **learning / heredity** may **nudge** trait scalars; **orthogonal** to tick replay formula (**CREATURE_MEMORY §2.2** narrative).

### 5.1 Strategy-class tags (authoritative)

**Resolved (`context_hash` strategy class):** Attach optional strategy metadata as a **tag set** (multi-label), not a single mutually exclusive enum. Real episodes often blend cues (e.g. **`squeeze_commit`** + **`individual`** + **`stability`**). **Rationale:** combined tags increase **replay variability** at macro scale; aligns with overall design intent even if emit/store/merge/weight paths refactor later.

**Resolved (two tag families — trait bridge vs tactical means):** Strategy-class tags split into **two families** on every salient episode. **Traits connect only to pole facet tags**; **modality tags** use a **separate formula slot** so personality weighting and tactic choice stay aligned without double-counting.

| Family | Count (initial) | Role | Traits enter? |
|--------|-----------------|------|---------------|
| **Pole facet tags** | **8** — one negative / one positive pole per **§3** continuum | Motivational **“color”** of the episode — habitual replay affinity + **future trait drift** | **Yes** |
| **Modality tags** | **6** initial — grow when scenarios arise | Tactical **means** / situation — “is this tactic applicable **here and now**?” | **No** (situational match only) |

**Resolved (episode write — hybrid pole emission):** On every **salient** write (per **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)** write gates):

1. **`modality_tags[]`** — **required** when the emitter knows tactical class.
2. **`pole_facet_tags[]`** — **explicit** when the emitter knows motivational color; **else infer at write** from modalities + motor/social/outcome context before persist (**fallback** so traits never disconnect).
3. **`outcome_envelope`** — success tier, damage/jeopardy flag, goal delta (authoritative in **CREATURE_MEMORY** backends; referenced here for drift/aversion).

Do **not** re-infer poles from later rules at **drift apply** time — the stored lesson stays stable (“that almost killed me”).

**Resolved (replay ranking — two slots):** When choosing among remembered lanes at an obstacle (or projecting **`believed_goal_*`**):

- **Slot A — trait × pole affinity:** `trait_affinity(creature_traits, record.pole_facet_tags)` — e.g. negative **`explorer_builder`** boosts records tagged **`explorer`**. Implements **§5** illustrative tension without traits reading modality ids directly.
- **Slot B — situational match:** `situational_match(current_context, record.modality_tags)` — e.g. squeeze geometry boosts **`squeeze_commit`**; acute threat boosts **`flee_retreat`** or **`hide_stealth`** as appropriate.
- **Combine** with **`context_hash`** prior strength, recency, salience — weights **TBD** in **Action 2**.

**Resolved (outcome learning — two channels):**

| Outcome | Pole channel (traits) | Modality channel (tactic memory) |
|---------|----------------------|----------------------------------|
| **Success** | Nudge **toward** stored **`pole_facet_tags`** on the record (**future**; **§3.4** today) | Strengthen prior for that **`context_hash`** + modality set |
| **Failure** | Nudge **away from** dominant poles on the record | Weaken / decay modality prior for similar situations |
| **Near-death / high jeopardy** | Strong **away-from** on poles; may interact with **Avoid hostiles** hard-win (**§3**) | Strong suppression of that modality (“don’t repeat that tactic”) even if trait move is small |

**Resolved (strategy-class tags — aggregation / double-counting):** **Bound double-counting within each family.** When several tags in the **same family** influence the same **§3** axis or the same **`believed_goal_*`** replay path, apply **dominant tag at full strength**; **all other tags in that family** contribute at a **significantly lower weight**. **Across families:** combine **Slot A** (poles) and **Slot B** (modalities) with bounded weights — do **not** pick one global winner among all tags. **Escape hatch (if tuning demands):** cap tag count and/or max secondary impact **per family**.

**Strategy-class tags → trait replay — actions (complete in order):** Do **Action 1**, then **Action 2**, then **Action 3**. Each action **closes** when replaced by terse **`Resolved:`** prose (or explicitly **waived**) in-line here — same contract discipline as **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)** for storage-backed rows.

**Action 1 — Canonical tag vocabulary:** **Largely resolved** — two-family ids below. **Wire ids:** **`snake_case`** (e.g. **`self_interest`**, not hyphenated).

**Orthogonality:** Episodes carry **multi-label** sets across **both** families. **Within a continuum**, prefer **at most one pole facet** per episode unless sub-phases are explicitly modeled. Modality tags may **stack** with any pole set (`explorer` + `squeeze_commit` is valid).

**Initial set scope:** **8 pole facets + 6 modalities**; add modalities when motor verbs / GoalKinds need them — **poles stay capped at eight**.

**Validation story — `<<Question>>` still open:** **Hybrid** expected — engine **core allowlist** for shipped ids + optional **pack extension** table; lock when wiring storage.

#### Pole facet tags (8) — map to **§3** trait continuums

| Identifier | **`CreatureDefinition` axis** | Meaning | Notes |
|------------|------------------------------|---------|--------|
| `explorer` | **`explorer_builder`** (− pole) | Payoff came from **reconnaissance / roaming / probing** — coverage and discovery, not settling or reshaping a patch. | Absorbs earlier seed ids **`recon_roam`** / **`pure_explore`**. |
| `builder` | **`explorer_builder`** (+ pole) | Goal accomplished by **improving an existing situation** rather than moving to a new goal target. | Pairs with **`lasting_local_change`** modality at write when fortifying a patch. |
| `change` | **`change_stability`** (− pole) | Payoff came from **novel approaches** and interactions with the world. | |
| `stability` | **`change_stability`** (+ pole) | Goal accomplished using **well-known patterns**. | Pairs with **`return_home`** modality when inference applies. |
| `compassion` | **`compassion_self_interest`** (− pole) | Payoff came from **allowing another creature** to negatively impact **non-active** goals — sharing food, shelters, mates. | |
| `self_interest` | **`compassion_self_interest`** (+ pole) | Goal accomplished at the **direct expense** of a **non-hostile** creature — taking food, established mates, shelters. | |
| `community` | **`community_individual`** (− pole) | Problem solved by **multiple non-hostile creatures** working in unison. | |
| `individual` | **`community_individual`** (+ pole) | Creature accomplished the goal **on its own**, avoiding solutions from other non-hostile creatures. | |

#### Modality tags (6 initial) — tactical / situational means

| Identifier | Meaning | Notes |
|------------|---------|--------|
| `lasting_local_change` | Episode involves **durable local state change** the creature **reuses** — nest prep, blocked lane, terraformed pocket. | **Outcome / state** modality; often co-emitted with **`builder`** pole at write. Distinct from **`alter_local_env`** (deferred until crush/ecology verbs land). |
| `squeeze_commit` | **Commit** through **tight geometry** — squeeze, bolt-hole, passage commitment. | |
| `return_home` | Returning to a **known area** yields goal payoff. | Tactical inverse of wide **explorer** roam; **requires LoS** to known locale when implemented. Spatial recurrence stays in **`context_hash`** — tag marks **return-for-payoff strategy**, not the cell id alone. |
| `hide_stealth` | Situation addressed by **hiding or sneaking** — defensive (evade) and offensive (ambush). | Split **`hide`** vs **`ambush_stalk`** later if dominance gets muddy. |
| `flee_retreat` | Situation addressed by **acute egress / running away** — distinct from **`hide_stealth`** hold-still or sneak. | Subsumes **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)** episodic **`retreat`** / **`action_tag`** shorthand for strategy-class namespace. |
| `fight` | Goal accomplished through **combat**. | **Requires combat** implementation; stub until then. |

**Related (memory backend):** **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)** **`action_tag`** examples (`commit_cardinal`, `stalk`, …) — map into **modality** ids here when emitters adopt strategy-class tags, or remain episodic-only until merged.

**Action 2 — Per-tag mapping to §3 axes:** **Slot A** affinity shapes for **pole facet** tags (direct axis lookup above); **Slot B** situational signals for **modality** tags; optional **write-time inference** table (modality → default pole hints). Must compose with **per-family dominant + attenuated secondary** (**Resolved** above) and **§3 trait application order** when spawn traits and tag-derived modulation touch the same mapper pass.

<<Question: **Action 2 — Per-tag mapping** — numeric affinity curves (pole ↔ trait scalar), situational_match inputs per modality, inference table rows, and combine weights for Slot A + Slot B?>>

**Action 3 — Dominant-tag selection:** **Partially resolved** — dominance runs **per family** (poles separately from modalities), then slots combine. Tie-break among poles: **trait affinity** first, then recency / salience. Tie-break among modalities: **situational_match** first, then recency / salience / Tier-2 leaf ownership.

<<Question: **Action 3 — Dominant-tag selection** — finalize secondary-tag attenuation factors, cross-family combine weights, and merge rules across **`LocalePriorMap` / episodic** buckets (**CREATURE_MEMORY §2.1**)?>>

---

## 6. Cross-links and dual-authoring

| Topic | Authority |
|-------|-----------|
| **Motivation tree framework; trait poles; trait application order; strategy-class tag semantics + Actions 1–3** | **This file** |
| **`creature_motor` merge, `SeekCandidate`, Preserve/Seek thresholds, implementation phasing** | **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** |
| **`goal_*`, `believed_goal_*`, beliefs, locale priors, `context_hash` overlays, §14 storage/tuning questions** | **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** |

**Identifiers** (`goal_memory_*`, `_goal_belief`, …): canonical lists **CREATURE_MEMORY §10**; motor wires them per **CREATURE_MOVEMENT_V2**.

---

## 7. Changelog

| Date | Change |
|------|--------|
| 2026-05-18 | **§5.1:** **Two-family** strategy-class tags (**8 pole facets** + **6 modalities** incl. **`flee_retreat`**); hybrid write (modalities required, poles explicit or inferred); **two-slot** replay + dual-channel outcome learning; per-family dominance; Action 1 largely **Resolved**. |
| 2026-05-18 | **§5.1:** Seed **strategy-class tag vocabulary** table + orthogonality/scope/validation prose; narrow Action 1 `<<Question>>` to finalize ids + validation story. |
| 2026-05-17 | **New draft:** split from **CREATURE_MOVEMENT_V2** §A.3 framework + §A.4 + overlapping **CREATURE_MEMORY** trait/replay prose; **§5** hosts strategy-class **Resolved** + **Actions 1–3** (`<<Question>>`). |
