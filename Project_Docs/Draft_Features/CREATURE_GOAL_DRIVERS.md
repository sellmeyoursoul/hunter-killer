# Hunter Killer — Creature goal drivers (draft)

> **Purpose:** **Canonical hub** for **runtime goal semantics** shared by motor and memory: **motivation tree** (Tier-1 / Tier-2), **`GoalKind` registry** (**§4.1**), **`CreatureDefinition` motivation traits** (−100…+100), category rollup to Tier-2 leaves, and **trait × strategy-class** habitual replay modulation (`believed_goal_*`). This file does **not** specify cardinal scorer math, **`creature_motor`** pack merge keys, or belief TTL/schema — those stay in **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** and **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** respectively.
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

- **Today (ENGINE / pre–rich combat):** **`Avoid hostiles`** is **dominant** whenever **acute personal threat** applies (imminent predator, jeopardy): flee / evade **hard-wins** over food seek and other Tier-2 urges — **except** **`calorie_ratio < starvation_override_food_ceiling`** (default **0.10**), where **Find food** priority **0** overrides threat for dominance and motor urgency ([CREATURE_MOVEMENT_V2.md §A.2.3](CREATURE_MOVEMENT_V2.md)).

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
- **No separate mandatory normalization** to auxiliary \([−1,+1]\) storage — \(/100\) is an implementation detail inside the mapper.

#### 3.3.1 Trait → Tier-2 mapper (phase-1 resolved)

| Decision | Phase-1 choice |
|----------|----------------|
| **When to wire traits** | **Stub:** read trait scalars from **`CreatureDefinition`**; **urgency channel deltas = 0** (no personality shift on Tier-2 leaves this phase). Replay (§5) still uses traits via Slot A / **`change_stability`**. |
| **Mapper shape** | **Separate urgency channels** per Tier-2 leaf — not one shared additive blob. Each leaf exposes an **`urgency_*`** channel traits can nudge independently later. |
| **Where formula lives** | Dedicated module **[`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd)** (planned) — called from **`ai_driver`** / motor façade after base Tier-2 weights (hunger, jeopardy) are computed. **Not** inline in **`game_config_merge.gd`**. |

**Urgency channels (normative API — phase 1 stub returns base only):**

```text
apply_trait_urgency_channels(base: Tier2UrgencyChannels, traits: CreatureTraits, motor_p) -> Tier2UrgencyChannels
```

| Channel (field) | Tier-2 leaf | Phase-1 stub |
|-----------------|-------------|----------------|
| `urgency_avoid_hostiles` | **Avoid hostiles** | `base.urgency_avoid_hostiles` (unchanged) |
| `urgency_find_food` | **Find food** | `base.urgency_find_food` (unchanged) |
| `urgency_find_mate` | **Find mate** | `base.urgency_find_mate` (unchanged) |
| `urgency_preserve_calories` | **Preserve calories** | `base.urgency_preserve_calories` (unchanged) |

**Future (post-stub):** per-trait coefficients in **`creature_motor`** map **`explorer_builder`**, **`change_stability`**, etc. into channel deltas per **§3.2** shorthand — implemented only in **`trait_tier2_mapper.gd`** so formulas stay auditable.

**Jeopardy hard-win unchanged:** acute threat still forces **Avoid hostiles** dominance — **except** **`calorie_ratio < starvation_override_food_ceiling`** (priority **0**, [CREATURE_MOVEMENT_V2 §A.2.3](CREATURE_MOVEMENT_V2.md)). Trait channels **cannot** override jeopardy without explicit pack-combat / nest-defense verbs.

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
| **Finding shelter** (evasion / nesting) | **Avoid hostiles** (Tier-2 urgency) + storage id **`shelter`** (**§4.1**) | Squeeze, bolt-holes — **[CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)**; intersects **Preserve** / rest comfort later. |

**Movement mirror:** **[CREATURE_MOVEMENT_V2.md §B.1](CREATURE_MOVEMENT_V2.md)** (belief categories ↔ Tier 2).

**Wire ids and pack extension:** authoritative registry — **§4.1** below. **Not** per-species GDScript subclasses; optional species goals via **`pack_resources.json`**.

### 4.1 `GoalKind` registry (resolved)

**Purpose:** **`GoalKind`** is the **goal-category storage id** for locale priors, write gates, and replay keys — **orthogonal** to **modality tags** (Slot B — *how*) and **pole facets** (Slot A — *motivational color*). Row key: **`(GoalKind, context_hash, modality_tag)`** per **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)**.

**Design:** **Split registry** (same pattern as **§5.1** strategy-class tags) — engine **core** kinds + optional **pack extension**. **`CreatureDefinition`** stays a flat **`Resource`**; species variance lives in **`asset_pack_root` → `pack_resources.json`**, not goal subclasses.

#### Core `GoalKind` ids (engine — not pack-overridable)

Loaded from engine code + **`core_goal_kinds`** resource (path locks at implementation, e.g. `res://creature/memory/core_goal_kinds.json`).

| Wire id (`snake_case`) | Tier-2 leaf (urgency) | Phase-1 salient writes | `context_hash` overlay (phase-1) |
|------------------------|----------------------|------------------------|----------------------------------|
| `find_food` | **Find food** | **Yes** | **`grid_cell`** — **[CREATURE_MEMORY.md §2.1.1](CREATURE_MEMORY.md)** (food anchor) |
| `avoid_hostiles` | **Avoid hostiles** | **Yes** | **`grid_cell`** — **[CREATURE_MEMORY.md §2.1.2](CREATURE_MEMORY.md)** (creature anchor at outcome) |
| `shelter` | **Avoid hostiles** (tactical sub-goal) | **Stub** (no writes phase 1) | **Squeeze / nest fingerprint** (**[CREATURE_MEMORY.md §7](CREATURE_MEMORY.md)**) — deferred |
| `find_mate` | **Find mate** | **Stub** (hooks only; no writes until mating ships) | TBD |
| — | **Preserve calories** | **No** | — (modulates Tier-2 weights; not an “outcome accomplished” bucket) |

**`shelter` vs `avoid_hostiles`:** Both roll up to **Avoid hostiles** for Tier-2 dominance and jeopardy hard-win, but **`shelter`** is a **separate storage id** so squeeze/bolt-hole priors do not collide with generic flee buckets.

#### Pack extension (optional sibling — [CREATURE_MOVEMENT_V2.md §A.1](CREATURE_MOVEMENT_V2.md))

```json
{
  "creature_motor": { },
  "strategy_class_tags": { "extra_modalities": [] },
  "goal_kinds": {
    "extra_goal_kinds": [
      {
        "id": "nest_defense",
        "parent_tier2": "avoid_hostiles",
        "salient_writes": true,
        "context_overlay": "nest_fingerprint"
      }
    ]
  }
}
```

| Field | Required | Meaning |
|-------|----------|---------|
| `id` | Yes | **`snake_case`** wire id; must not collide with core ids |
| `parent_tier2` | Yes | Engine Tier-2 leaf that owns urgency when active: `find_food`, `avoid_hostiles`, `find_mate`, `preserve_calories` |
| `salient_writes` | No (default **true**) | Whether locale-prior write gates apply |
| `context_overlay` | No | Hint for **`context_hash`** compositor (`grid_cell`, `squeeze_fingerprint`, `nest_fingerprint`, …) |

**Not in `goal_kinds` schema:** **`pole_facet_tags`** (fixed engine eight) and per-episode **`modality_tags`** are **not** defined per goal in pack JSON. **`GoalKind`** + **`context_overlay`** only. Poles are **global**; episode tags are built at salient write by **[§5.1.1](CREATURE_GOAL_DRIVERS.md)** (modalities from motor classifier flags or per-`GoalKind` default inference → poles via §5.1 inference table). Pack **`strategy_class_tags.extra_modalities`** extends **tactics** only.

**At spawn** (with **`creature_motor`** merge):

```text
effective_goal_kinds = core_goal_kinds ∪ pack.goal_kinds.extra_goal_kinds
```

#### Outcome routing (phase-1)

After **Tier-2 dominance** passes ([CREATURE_MEMORY.md §14 — Write gates](CREATURE_MEMORY.md)):

| Dominant Tier-2 at outcome | Default `GoalKind` | Override |
|------------------------------|-------------------|----------|
| **Find food** | `find_food` | — |
| **Find mate** | `find_mate` | No write until mating ships |
| **Avoid hostiles** | `avoid_hostiles` | Phase 1: **`avoid_hostiles` only** — **`shelter`** routing deferred |
| **Preserve calories** | — | **No** salient write |

**Pack extras:** use declared **`id`**; Tier-2 weights follow **`parent_tier2`**.

#### Validation

- **`validate_goal_kind(id, effective_goal_kinds)`** before salient persist.
- Unknown **`GoalKind`** → **reject entire salient write** + **`OLog.error`** in dev (stricter than modality strip).
- Invalid pack entry at load → log + skip entry; do not crash spawn.

#### Implementation hooks (code PR — not in this doc)

- **`goal_kind.gd`** (or `creature/memory/goal_kind_registry.gd`): core table, pack merge, **`tier2_to_default_goal_kind`**, **`resolve_goal_kind_at_outcome`** (shelter disambiguation).
- Per-instance **`effective_goal_kinds`** on motor/memory façade at spawn.
- **`context_hash_for_find_food(...)`** — **[CREATURE_MEMORY.md §2.1.1](CREATURE_MEMORY.md)** (`explore_coverage_cell_px`, origin world zero, food **`SeekCandidate`** anchor, OOB → reject write, **`hash([goal_kind, cell_x, cell_y])`**).

---

## 5. Habitual replay modulation (trait × strategy-class tags × `believed_goal_*`)

**Reads first:** **[CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)** (`LocalePriorMap` / `ExperienceRing` → façade); **[CREATURE_MOVEMENT_V2.md §A.3.1](CREATURE_MOVEMENT_V2.md)** (`MotorContext` **`believed_goal_source_bias`**, radii).

After locale priors project into **`believed_goal_*`** / habitual bias, **`CreatureDefinition` traits** (**§3**) scale **how strongly** to **reapply** remembered outcomes — same façade, **no forked ingress**. **`context_hash`** composition and backend knobs (**write gates**, decay, overlays per `GoalKind`) are authoritative in **[CREATURE_MEMORY.md §§2.1, 14](CREATURE_MEMORY.md)**.

**Principle**

- **`context_hash`** encodes situation class — spatial cell, passage fit, or (later) **effect class** (“changed local environment” vs “discovered new route”).
- **Traits modulate how much to favor reusing that class** when merging into Tier-2 (**§3** application order when multiple axes touch the same weights).

**Illustrative tension** (authoring example — **multi-tag combine rule** **Resolved** below):

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

**Resolved (episode write — hybrid pole emission):** On every **salient** write (per **[CREATURE_MEMORY.md §14 — Write gates](CREATURE_MEMORY.md)** **Resolved**: dominant Tier-2 at outcome → **`GoalKind`** wire id per **§4.1** (`resolve_goal_kind_at_outcome`), one write per goal outcome). **Emitter contract — §5.1.1** (`goal_source_memory.gd`).

1. **`modality_tags[]`** — from **`MotorContext`** tactic classifier flags when active; **else** per-`GoalKind` **default modality inference** (§5.1.1).
2. **`pole_facet_tags[]`** — **explicit** only when emitter knows motivational color (rare phase 1); **else infer once at write** from modalities + context (§5.1 inference table). **Not** stored on **`goal_kinds`** definitions.
3. **`outcome_envelope`** — success tier, damage/jeopardy flag, **`insufficient_yield`**, goal delta stub (**[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)**).

Do **not** re-infer poles from later rules at **drift apply** time — the stored lesson stays stable (“that almost killed me”).

#### 5.1.1 Salient episode emitter (phase-1 resolved)

**Owner:** [`goal_source_memory.gd`](../../creature/memory/goal_source_memory.gd) (new) — **canonical** path for salient writes, **`LocalePriorMap`** updates, tag inference, and validation. **[`ai_driver.gd`](../../AI_int_lib/ai_driver.gd)** invokes it **only after** [MEMORY §14 write gates](CREATURE_MEMORY.md) pass; passes **`MotorContext`**, outcome, **`GoalKind`**, food-anchor **`Vector2`**, merged **`creature_motor`**, and per-instance allowlists. **Cardinal / motor code** may set **`MotorContext`** tactic flags — **must not** write locale priors directly.

**Pipeline:**

```text
ai_driver (outcome hook)
  → goal_source_memory.try_salient_write(...)
       → write gates + GoalKind + context_hash (MEMORY §2.1.1 / §2.1.2)
       → build modality_tags[] (classifier or default inference; up to 3 rows)
       → build pole_facet_tags[] (explicit or infer) → persist rank-1 as pole_facet_tag per row
       → validate_goal_kind + validate_episode_tags
       → LocalePriorMap persist (per modality_tag row)
```

**`emitter_knows_modality` (resolved):** **`true`** when **`MotorContext.tactic_classifier_active`** is **`true`** this tick — i.e. at least one **phase-1 tactic classifier flag** below is set by motor / perception. **Not** synonymous with “**Find food** is active” (that is Tier-2 / write gates).

**Phase-1 `MotorContext` tactic classifier flags** (authoritative keys for implementation — [CREATURE_MOVEMENT_V2.md §A.2.1](CREATURE_MOVEMENT_V2.md)):

| Key | When set (summary) | Maps to modality (when active) |
|-----|-------------------|-------------------------------|
| `tactic_classifier_active` | **Derived:** `true` if any other tactic flag in this table is `true` | — |
| `tactic_in_squeeze` | Creature in / committing through tight passage | `squeeze_commit` |
| `tactic_jeopardy_egress` | Acute threat; egress-dominant outcome | `flee_retreat` |
| `tactic_hide_viable` | Threat + viable hide / break-LoS opportunity | `hide_stealth` |
| `tactic_return_home_payoff` | Payoff from known locale anchor | `return_home` |
| `tactic_lasting_local_change` | Durable local state reused at outcome | `lasting_local_change` |
| `tactic_fight_active` | Combat engagement (stub until combat) | `fight` |

When **`tactic_classifier_active`:** build **`modality_tags[]`** from active flags (multi-label allowed); run **Action 1** validation (strip unknown modalities; reject if required path ends empty).

**Default modality when classifier inactive (resolved):** **Infer** per **`GoalKind`** — do **not** leave tags unset without a rule. **Do not** add pole lists to **`goal_kinds`** pack entries.

| `GoalKind` | Phase-1 default `modality_tags[]` when classifier inactive |
|------------|-----------------------------------------------------------|
| `find_food` | **`["open_forage"]`** when classifier inactive (single row) |
| `avoid_hostiles` | **`["flee_retreat"]`** when write gate passes (jeopardy had been acute) |
| `shelter` | **Stub — no writes phase 1** |
| `find_mate` | *(no salient writes phase 1)* | |
| Pack **`extra_goal_kinds`** | Use **`context_overlay`** hint + same inference discipline when writes enabled |

**Pole facet tags (resolved — not per-goal definitions):**

- **Eight pole ids** are **engine-global** (§5.1 Action 1). **Never** author `pole_facet_tags` on **`goal_kinds.extra_goal_kinds[]`**.
- After modalities are known: if **`pole_facet_tags[]`** not set explicitly, **`goal_source_memory.gd`** runs **write-time inference** (table below + deterministic OR rules).
- **`find_food` + classifier inactive:** modality **`open_forage`**; pole fallback **`explorer`**.

**Row persistence (resolved):** Rank-1 **`pole_facet_tag`** stored on each **`LocalePriorMap`** row (**[CREATURE_MEMORY.md §14.2](CREATURE_MEMORY.md)**). Slot A reads stored tag at replay — **no re-inference**.

**Explicit poles (optional):** Set **`pole_facet_tags[]`** only when **`emitter_knows_pole_color`** is **`true`** (rare; future). Phase 1: **always infer** from modalities unless tests supply explicit poles.

**Implementation hook (code PR):** `goal_source_memory.try_salient_write(...)` — see [CREATURE_MEMORY.md §14 — Salient emitter](CREATURE_MEMORY.md).

#### 5.1.2 Replay formula constants (`creature_motor` — phase-1 resolved)

**Policy:** Every replay tuning key is a **`creature_motor`** overlay key. **Authoritative defaults** live only in **`default_creature_motor_params()`** ([`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd)). Pack **`creature_motor` JSON** should **omit** these keys unless overriding — empty/missing pack fields **must not** silently invent values; merge falls back to the single default table so missing pack entries are obvious in authoring.

| Key | Default | Used in |
|-----|---------|---------|
| `replay_bell_k` | **1.4** | `bell(x) = 1 - exp(-k * x)` |
| `replay_w_fit` | **0.4** | Slot B `x_blend` |
| `replay_w_store` | **0.6** | Slot B `x_blend` |
| `replay_n_sat` | **10** | `evidence = 1 - exp(-attempt_count / n_sat)` |
| `replay_n_min` | **3** | `thin_cap = min(1, attempt_count / n_min)` |

**Impl:** `goal_source_memory.gd` reads merged **`motor_p`**; no hardcoded duplicates in replay path.

#### 5.1.3 `external_urgency` (phase-1 resolved)

**Purpose:** Scalar **0…1** pressure feeding Slot A cap lift (**near ±100** only with high **`slot_b_base`**).

**Sources — bitmask / enum** (phase-1 flags; extend when systems land):

| Bit / enum | Meaning | Phase-1 contributor |
|------------|---------|---------------------|
| `URGENCY_JEOPARDY` | Acute personal threat | `tactic_jeopardy_egress` **or** imminent mob within `food_seek_imminent_mob_radius_px` |
| `URGENCY_HUNGER` | Desperate forage band | `calorie_ratio < seek_priority_food_ceiling` — strength scales with hunger |
| `URGENCY_NEST_DEFENSE` | Communal / nest under attack | **Reserved 0** until pack combat / nest verbs |
| *(future bits)* | Pack engage, mate distress, … | Document in PR when added |

**Aggregate (continuous 0…1):** Each active bit contributes a **0…1 sub-score**; combine with **`max`** (dominant pressure wins) unless a future doc revision specifies weighted sum:

```text
external_urgency = clamp(max(jeopardy_01, hunger_01, nest_01, ...), 0.0, 1.0)
```

- **`jeopardy_01`:** **1.0** when jeopardy bit set, else **0.0**.
- **`hunger_01`:** `clamp((seek_priority_food_ceiling - calorie_ratio) / seek_priority_food_ceiling, 0, 1)` when hunger bit eligible (align **[CREATURE_MOVEMENT_V2 §A.3.1](CREATURE_MOVEMENT_V2.md)** ceilings).

**`urgency_boost` curve (linear — resolved):**

```text
urgency_boost = urgency_boost_linear_slope * external_urgency * gate(slot_b_base)
```

- **`gate(slot_b_base)`:** **1.0** when `slot_b_base >= replay_urgency_slot_b_min` (default **90**), else **0.0** (no cap lift on weak tactics).
- **`urgency_boost_linear_slope`:** default **25** in **`default_creature_motor_params()`** — tune in play.

**`creature_motor` keys:** `urgency_boost_linear_slope`, `replay_urgency_slot_b_min` (optional per-bit slopes deferred).

#### 5.1.4 `current_fit` per modality (phase-1 resolved)

**Long-term goal:** qualitative **§5.1 Slot B table** (squeeze fingerprint, LoS, durable local state, etc.) — full situational matchers per tag.

**Phase-1 rule (classifier-first):**

| Modality | `current_fit(tag)` phase-1 |
|----------|---------------------------|
| `squeeze_commit` | **1.0** if `tactic_in_squeeze`, else **0.0** |
| `flee_retreat` | **1.0** if `tactic_jeopardy_egress`, else **0.0** |
| `hide_stealth` | **1.0** if `tactic_hide_viable`, else **0.0** |
| `lasting_local_change` | **1.0** if `tactic_lasting_local_change`, else **0.0** |
| `return_home` | `clamp(1 - dist(creature, nearest_hotspot_centroid) / believed_goal_hotspot_near_radius_px, 0, 1)` when dominant goal matches; **0** if no hotspot |
| `fight` | **0.0** (stub until combat) |
| `open_forage` | Slot B from **`stored_strength`** / confidence only (no live tactic flag) |

Flags — **[CREATURE_MOVEMENT_V2 §A.2.1](CREATURE_MOVEMENT_V2.md)**. Until detectors ship, most fits are **0** — ranking leans on **`stored_strength`** + **`replay_rank_score`** (expected).

#### 5.1.5 `avoid_hostiles` escape reversal suppression (phase-1 resolved)

When **`try_salient_write`** would fire on **jeopardy clear** ([CREATURE_MEMORY.md §14.4](CREATURE_MEMORY.md)):

**Suppress** if starvation override **reversed the escape** and the creature returned to **any acute danger** (not only the first mob — supports **trailing hostile trains**):

1. During escape episode (`tactic_jeopardy_egress` was true), **`calorie_ratio < starvation_override_food_ceiling`** caused **Avoid → Find food** dominance flip, **and**
2. Before jeopardy-clear evaluation, creature re-entered **any** imminent threat (`food_seek_imminent_mob_radius_px` or equivalent acute-danger test) within **`escape_reversal_window_sec`** (default **1 s** — tune in play).

**If suppressed:** **no write** for that clear event; **retry on next clean escape** (jeopardy clears without reversal conditions).

**Projection:** **`avoid_hostiles`** rows **do not** feed **`believed_goal_source_bias.pull_dir`** — replay / threat-response ordering only (**§14.1**).

**Resolved (replay ranking — two slots):** When choosing among remembered lanes at an obstacle (or projecting **`believed_goal_*`**):

- **Slot A — trait × pole affinity:** `trait_affinity(creature_traits, record.pole_facet_tags)` — e.g. negative **`explorer_builder`** boosts records tagged **`explorer`**. Implements **§5** illustrative tension without traits reading modality ids directly.
- **Slot B — situational match:** `situational_match(current_context, record.modality_tags)` — e.g. squeeze geometry boosts **`squeeze_commit`**; acute threat boosts **`flee_retreat`** or **`hide_stealth`** as appropriate.
- **Combine** with **`context_hash`** prior strength, recency, salience — **Action 2 Resolved** below (`replay_delta` / `replay_weight`; recency / salience tie-breaks **Action 3**).

**Resolved (outcome learning — two channels):**

| Outcome | Pole channel (traits) | Modality channel (tactic memory) |
|---------|----------------------|----------------------------------|
| **Success** | Nudge **toward** stored **`pole_facet_tags`** on the record (**future**; **§3.4** today) | Strengthen prior for that **`context_hash`** + modality set |
| **Failure** | Nudge **away from** stored **`pole_facet_tags`** (strongest-weighted first) | Weaken / decay modality prior for similar situations |
| **Near-death / high jeopardy** | Strong **away-from** on poles; may interact with **Avoid hostiles** hard-win (**§3**) | Strong suppression of that modality (“don’t repeat that tactic”) even if trait move is small |

**Resolved (strategy-class tags — aggregation / double-counting):** **Bound double-counting within each family** via **strength-ranked top contributors** (**Action 3**): rank tags by family-specific strength, take **at most three** — weights **1.0, 0.2, 0.2** — ignore the rest. **Across families:** **multiply** Slot A and Slot B results (**Action 3**); do **not** pick one global winner among all tags.

**Strategy-class tags → trait replay — actions (complete in order):** Do **Action 1**, then **Action 2**, then **Action 3**. Each action **closes** when replaced by terse **`Resolved:`** prose (or explicitly **waived**) in-line here — same contract discipline as **[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)** for storage-backed rows.

**Action 1 — Canonical tag vocabulary:** **Resolved** — two-family ids below. **Wire ids:** **`snake_case`** (e.g. **`self_interest`**, not hyphenated).

**Orthogonality:** Episodes carry **multi-label** sets across **both** families. **Within a continuum**, prefer **at most one pole facet** per episode unless sub-phases are explicitly modeled. Modality tags may **stack** with any pole set (`explorer` + `squeeze_commit` is valid).

**Initial set scope:** **8 pole facets + 6 core modalities** (tables below); **poles stay capped at eight** — **no pack extension** for pole facets. **Additional modality ids** ship in the **engine core modality resource** and/or per-species **`pack_resources.json`** (**Resolved — validation**, below) for **species-specific Slot B** vocabulary.

**Resolved (Action 1 — split allowlist + pack extension):**

| Layer | Source | Species-specific? |
|-------|--------|-------------------|
| **Pole facet tags (8)** | Engine **GDScript** allowlist (`CORE_POLE_TAGS`) — §3 trait-axis table below | **No** — fixed engine contract |
| **Core modality tags (6)** | Engine **resource** (e.g. `res://creature/memory/core_modality_tags.json` — path locks at implementation) | **No** — shared shipped set |
| **Extra modalities** | **`pack_resources.json`** → **`strategy_class_tags.extra_modalities[]`** (sibling of **`creature_motor`**, not nested) | **Yes** — unioned at spawn |

**At spawn** (same resolution pass as **`creature_motor`** via **`CreatureDefinition.asset_pack_root`**):

```text
effective_modality_allowlist = core_modalities_from_resource ∪ pack.strategy_class_tags.extra_modalities
```

**Pack shape (Option A — sibling object):**

```json
{
  "creature_motor": { },
  "strategy_class_tags": {
    "extra_modalities": ["ambush_stalk"]
  }
}
```

| Field | Rule |
|-------|------|
| `strategy_class_tags` | Optional; omit = no extensions |
| `extra_modalities` | `string[]` of **`snake_case`** ids **not** already in the core resource; duplicates dedupe at merge |

**Resolved (Action 1 — validation at write / read):** Single gate **`validate_episode_tags(pole_tags, modality_tags, effective_modality_allowlist, emitter_knows_modality)`** before **`LocalePriorMap`** / episodic persist.

| Family | Policy |
|--------|--------|
| **Pole facet** | Unknown id → **reject entire salient write**. After normalization, **at most one pole per §3 continuum** (higher **`pole_strength`** wins per Action 2); invalid dual-pole writes → **reject**. |
| **Modality** | Unknown id → **strip** + **`OLog.error`** in dev. |
| **Required modality** | When emitter **knows tactical class** (§5.1 episode write) but **all** modalities stripped → **reject write**. |
| **New id without `current_fit` branch** | Allowed if on **`effective_modality_allowlist`**; **`current_fit(tag) = 0`** until motor implements branch (same as **`fight`** stub). |
| **LocalePriorMap read** | Rows whose **`modality_tag` ∉ effective_modality_allowlist** → **ignore** for replay (orphan / legacy). |

Packs **cannot** add or override pole facets. Legacy tactic names (`retreat`, `commit_cardinal`, `stalk`) map to **modality ids** or **`extra_modalities`** — **not** a second ontology (**[CREATURE_MEMORY.md §14](CREATURE_MEMORY.md)**).

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
| `flee_retreat` | Situation addressed by **acute egress / running away** — distinct from **`hide_stealth`** hold-still or sneak. | |
| `open_forage` | Mundane **find food** without a distinct tactic classifier — open patch foraging. | Phase-1 default modality when classifier inactive |
| `fight` | Goal accomplished through **combat**. | **Requires combat** implementation; stub until then. |

**Memory backends:** **`LocalePriorMap`** and future **`ExperienceRing`** traces use this **same** episode write shape (**`modality_tags[]`**, **`pole_facet_tags[]`**, **`outcome_envelope`**) — **[CREATURE_MEMORY.md §§2.1, 14](CREATURE_MEMORY.md)** (**`action_tag` excised**).

**Action 2 — Per-tag mapping to §3 axes:** **Resolved** — numeric contracts below. Must compose with **per-family top-3 strength ranking** (**Action 3**) and **§3 trait application order** when spawn traits and tag-derived modulation touch the same mapper pass.

**Resolved (Action 2 — per-tag mapping):** **Slot A** is **bipolar** (personality-colored replay); **Slot B** is **unipolar 0…100** (tactic familiarity + fit). **Slot B does not add a second signed term** — it **caps** how strongly **Slot A** can move habitual replay away from the baseline **`context_hash`** prior. Breakpoints and `k` are **first-pass** tunables in **`creature_motor`** / pack keys; the **0-neutral / B-gated / urgency-for-extremes** contract is normative.

#### Slot A — `trait_affinity(creature_traits, pole_facet_tags)` (−100…+100)

**Pole sign** on each **§3** axis: negative pole tags (`explorer`, `change`, `compassion`, `community`) → **−1**; positive pole tags (`builder`, `stability`, `self_interest`, `individual`) → **+1** (axis lookup in pole table above).

**Per-tag raw alignment** (then **Action 3** top-3 weights on the record):

```text
raw_axis(tag)   = (trait_scalar / 100.0) * pole_sign(tag)
pole_strength(tag) = abs(raw_axis(tag))
```

- **`trait_scalar = 0`** → **0** from that axis (**no personality pull**).
- **Linear** in `trait_scalar`; **misalignment** is automatic (e.g. `explorer` tag + positive **`explorer_builder`** → negative `raw_axis`).
- **Same continuum:** if two pole facets on one axis appear, keep only the **higher `pole_strength`** before ranking.

**Top-3 blend (pole family, this record):** Sort remaining tags by **`pole_strength`** descending; ties use **§3** axis order (**`explorer_builder` → `change_stability` → `compassion_self_interest` → `community_individual`**). Apply rank weights **`[1.0, 0.2, 0.2]`** (max **three** tags; additional tags ignored).

```text
pole_blend = sum over rank r in 1..3:  rank_weight[r] * raw_axis(tag_r)
slot_a_unsigned = clamp(abs(pole_blend) * 100.0, 0, 100)
slot_a_sign     = sign(pole_blend)    // 0 if exactly neutral
slot_a_raw      = slot_a_sign * slot_a_unsigned
```

**Multi-axis:** Top-3 poles may span up to three continuums; **`pole_blend`** is a **signed sum** of weighted alignments (strongest traits pull hardest without a single global “winner” tag in all cases).

**Cap references Slot B + `external_urgency`:** **`slot_b_base`** limits **\|effective Slot A\|** on replay; approaching **±100** needs **high `slot_b_base`** **and** elevated **`external_urgency`** (**§5.1.3**).

| Condition | Max **\|effective Slot A\|** on replay |
|-----------|----------------------------------------|
| **`slot_b_base` ~0–25** (weak / novel tactic) | **~25** — personality tint only |
| **`slot_b_base` ~25–75** | **Linear ramp ~25 → ~75** with `slot_b_base` |
| **`slot_b_base` > ~75** | **Asymptote ~75** from B alone — **hard** to exceed without sustained success (bell on B) |
| **`slot_b_base` ≥ ~90** **and** **`external_urgency` high** | **Toward ±100** |

```text
cap_from_b    = bell_cap(slot_b_base)         // maps Slot B 0…100 → cap ~0…~75 (see Slot B)
cap_final     = min(100, cap_from_b + urgency_boost(external_urgency, slot_b_base))
effective_a   = sign(slot_a_raw) * min(abs(slot_a_raw), cap_final)
```

**`external_urgency` numerics — §5.1.3** (bitmask → continuous **0…1**; **linear** `urgency_boost`).

#### Slot B — `situational_match(current_context, record.modality_tags)` (0…100)

**Not bipolar** — **0** = never tried / no applicable match in this **`context_hash`** class; **100** = frequent, **consistent** success for this modality set in that bucket (**[CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)** locale / episodic aggregates).

**Two factors:**

1. **`current_fit` ∈ [0, 1]`** — live **MotorContext**: is this tactic **applicable here and now**?
2. **`stored_strength` ∈ [0, 1]`** — blended success history for **`(GoalKind, context_hash, modality_tags)`**; backend also exposes **`attempt_count`**, **`success_count`**, **`success_delta`** for **confidence** below (**[CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)**).

**Per-tag modality strength** (then **Action 3** top-3 weights):

```text
modality_strength(tag) = current_fit(tag) * stored_strength(tag)
```

Sort tags by **`modality_strength`** descending (ties: higher **`current_fit`**, then §3-style modality id order as impl tie-break). Rank weights **`[1.0, 0.2, 0.2]`**, max **three** tags.

```text
fit_blend   = sum rank_weight[r] * current_fit(tag_r)
store_blend = sum rank_weight[r] * stored_strength(tag_r)
x_blend     = replay_w_fit * fit_blend + replay_w_store * store_blend    // §5.1.2 defaults 0.4 / 0.6
slot_b_base = round(100 * bell(x_blend))
slot_b      = slot_b_base    // alias: familiarity band; ranking uses replay_rank_score below
bell(x)     = 1 - exp(-k * x)    // k from creature_motor replay_bell_k — §5.1.2 defaults
bell_cap(b) = bell(b / 100.0) * 75    // Slot A cap_from_b(slot_b_base): ~75 max from B alone (phase-1 shape)
```

**Replay formula constants — §5.1.2** (`k`, `w_fit`, `w_store`, `n_sat`, `n_min`).

**Bell intent:** **~25** is **easy** (modest fit **or** a few tries); **>~75** is **uncommon** (strong **`current_fit`** **and** consistent locale success); **100** is **rare**. Two records with the same **`slot_b_base`** can still **rank differently** after **confidence** and **`change_stability`** bias (below).

**Per-modality `current_fit` inputs** (each tag scored separately; **top-3** weighted blend above replaces legacy **`max(current_fit)`**):

| Modality | `current_fit` inputs (long-term — qualitative targets) |
|----------|--------------------------------------------------------|
| `squeeze_commit` | Passage / squeeze fingerprint match; commit-in-progress or narrow opening ahead |
| `flee_retreat` | Acute threat / jeopardy; positive predator closure |
| `hide_stealth` | Threat present; egress not dominant; cover / LoS-break opportunity |
| `lasting_local_change` | Known durable local state at cell; builder-relevant patch flag |
| `return_home` | LoS or proximity to known locale anchor (strategy tag — not cell id alone) |
| `fight` | Combat engagement active (**stub 0** until combat ships) |

**Phase-1 `current_fit` rules — §5.1.4** (classifier-first; full qualitative table above remains **long-term** Slot B goal).

#### Slot B — confidence (attempts, success delta, Change/Stability)

**Purpose:** Same nominal **`slot_b_base`** (e.g. **~25**) can mean different **evidence quality**. **Confidence** reorders competing records and optionally **scales** personality pull; it does **not** replace the 0…100 bell or Slot A caps (**`cap_from_b(slot_b_base)`** unchanged).

**Locale prior row** per **`(GoalKind, context_hash, modality_tag)`**; **`confidence`** stats (**`attempt_count`**, **`success_count`**, **`success_delta`**) read from the **highest `modality_strength`** tag’s row on this record (phase-1):

| Field | Meaning |
|-------|---------|
| **`attempt_count`** | Salient tries in this bucket (write-gated per **CREATURE_MEMORY §14**) |
| **`success_count`** | Outcomes counted success per **`outcome_envelope`** |
| **`success_delta`** | Recent outcome trend — EWMA or rolling window (**§14** outcome-shaping locks formula) |

```text
success_rate = success_count / max(attempt_count, 1)    // or EWMA success rate in impl
```

**Confidence** (phase-1 shape, tunable):

```text
evidence      = 1 - exp(-attempt_count / replay_n_sat)   // §5.1.2 default 10
consistency   = success_rate
thin_cap      = min(1.0, attempt_count / replay_n_min)  // §5.1.2 default 3
delta_factor  = clamp(1 + 0.1 * sign(success_delta), 0.85, 1.15)
confidence    = clamp(evidence * (0.5 + 0.5 * consistency) * thin_cap * delta_factor, 0, 1)
```

- **Many attempts, mixed results** → **lower** `confidence` than **few attempts, never failed** at the same **`slot_b_base`**.
- **`success_delta` > 0** (improving) → slight **up**; **< 0** → slight **down** (bounded by **`delta_factor`**).

**`change_stability` rank bias** (traits enter **Slot B ranking only** — not Slot A):

| Pole | When **`slot_b_base`** is similar, prefer… |
|------|---------------------------------------------|
| **Change (−)** | **Novel / thin evidence** — low **`attempt_count`**, **no failures**, over high **`attempt_count`** with mixed **`success_rate`**. |
| **Stability (+)** | **Proven volume** — high **`attempt_count`** (even mixed) over untested / few-try streaks. |

```text
t               = (change_stability + 100) / 200.0       // 0 = Change … 1 = Stability
mixed_penalty   = 4 * success_rate * (1 - success_rate)  // peaks at 50% mixed
failures        = attempt_count - success_count
streak_bonus    = (failures == 0 && attempt_count > 0) ? (1 - evidence) : 0
novelty_score   = (1 - evidence) * (1 - mixed_penalty) + streak_bonus
proven_score    = evidence * (0.5 + 0.5 * success_rate)
trait_rank_bias = lerp(novelty_score, proven_score, t)
replay_rank_score = slot_b_base * confidence * trait_rank_bias
```

Use **`replay_rank_score`** when **choosing among remembered lanes / records** at replay time.

**Worked example** — same **`slot_b_base ≈ 25`**, same **`current_fit`**:

| Record | Attempts | Success rate | **Change** creature rank | **Stability** creature rank |
|--------|----------|--------------|--------------------------|-----------------------------|
| A | 20 | 50% mixed | Lower **`replay_rank_score`** | Higher **`replay_rank_score`** |
| B | 2 | 100% (never failed) | Higher **`replay_rank_score`** | Lower **`replay_rank_score`** |

#### Combine — Slot A + Slot B + `context_hash` prior

**Resolved (`locale_prior_strength` — phase 1):** **`stored_strength`** ∈ [0, 1] of the **best-matching** **`LocalePriorMap`** row for consult **`(GoalKind, context_hash, modality_tag)`** (highest **`replay_rank_score`** among matching rows; **0** if none).

```text
prior_base    = locale_prior_strength(context_hash, GoalKind)   // := stored_strength of best match
replay_delta  = effective_a * (slot_b_base / 100.0) * confidence    // confidence secondary to ranking
replay_weight = prior_base * (1 + replay_delta / 100.0)             // phase-1: multiplicative ONLY
```

**Resolved (`replay_weight` motor integration — phase 1):** **Multiplicative** — **not** additive on cardinal costs.

| Application | Formula | Notes |
|-------------|---------|--------|
| **Habitual vector pull** | `effective_pull_weight = weight_believed_goal_pull * replay_weight` when consult **`context_hash`** matches a row | Scales **magnitude** only — **[CREATURE_MEMORY.md §14.1](CREATURE_MEMORY.md)**. **`replay_weight` is not a second direction source.** |
| **Instance seek** | `weight_seek_ready_food *= replay_weight` (or future **`weight_seek_goal`**) when hash matches | Same **`replay_weight`**; separate from **`pull_dir`**. |
| **Hotspot / escalate** | Adjust **`weight_seek_*`** and Preserve/Find band per **[CREATURE_MOVEMENT_V2 §A.3.1](CREATURE_MOVEMENT_V2.md)** | **Does not** enter vector formula. |

**Additive `replay_weight` on cardinal costs:** **Rejected** for phase 1 (removed fork vs MOVEMENT §A.3.1).

- **`slot_b_base = 0`** → personality modulation **off** even if traits are extreme.
- **Moderate `slot_b_base`** → typical **±25…±75** effective personality swing (via cap table); **`confidence`** and **`trait_rank_bias`** reorder ties within that band.
- **Near ±100** → **high `slot_b_base`** **and** **`external_urgency`**.
- **Cross-family combine (resolved):** **multiply only** — `replay_delta = effective_a * (slot_b_base / 100.0) * confidence`; no separate **`w_pole` / `w_modality`**.
- **Ranking** among **records**: **`replay_rank_score`** first, then recency / salience.

#### Write-time inference (modality → default `pole_facet_tags[]`)

**Resolved (deterministic OR branches):** Used by **`goal_source_memory.gd`** when poles are not explicit. Runs **once at write** only. Inputs include **`MotorContext`** fields in §5.1.1 where noted.

| Modality | Pole tag(s) | Rule (phase-1) |
|----------|-------------|----------------|
| `lasting_local_change` | `builder` | fortify / reuse local state |
| `return_home` | `stability` | payoff from known locale |
| `squeeze_commit` | `community` if `conspecific_aid_count >= 1` in squeeze context; else `individual` | |
| `flee_retreat` | `individual` | solo egress default |
| `hide_stealth` | `stability` if `hide_hold_still` else `change` | `hide_hold_still` = low displacement / hold-still sub-phase on `MotorContext` |
| `fight` | `self_interest` | until combat + ally-assist rules ship |
| *(none — `find_food` open forage)* | `explorer` | §5.1.1 pole fallback when `goal_kind == find_food` and `modality_tags` empty after default inference |

**Action 3 — Per-family strength ranking + backend merge:** **Resolved** — top-3 tag aggregation, cross-family multiply, and **`LocalePriorMap` / `ExperienceRing`** façade fusion below.

**Resolved (Action 3 — per-family top-3):** Same paradigm as **§3 trait application order** — **strongest contributors matter most**; weaker tags still nudge at **20%**. Apply **separately** within **pole facet** family (Slot A) and **modality** family (Slot B); formulas in Slot A / Slot B above.

| Rule | Detail |
|------|--------|
| **Rank weights** | **1.0**, **0.2**, **0.2** on ranks 1–3 |
| **Cap** | **At most three** tags per family; additional tags **ignored** |
| **Pole strength** | `pole_strength(tag) = abs(raw_axis(tag))`; one tag per continuum (higher wins) |
| **Modality strength** | `modality_strength(tag) = current_fit(tag) * stored_strength(tag)` |
| **Cross-family** | **Multiply only:** `replay_delta = effective_a * (slot_b_base / 100.0) * confidence` |

**Example (one record):** `pole_facet_tags = [builder, individual]`, `modality_tags = [squeeze_commit, hide_stealth]`. Builder creature: `builder` rank-1 pole; `individual` rank-2 at 0.2. Squeeze fits now (`modality_strength` 0.7) vs hide partial (`0.3`): squeeze rank-1, hide rank-2 at 0.2 → blended **`slot_b_base`** and signed **`pole_blend`** feed **`effective_a`** / caps as in Action 2.

**Compare records (unchanged from Action 2 extension):** **`replay_rank_score`** → **`slot_b_base`** → recency / salience / Tier-2 leaf ownership.

**Resolved (Action 3 — backend merge):** **[CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)** — **`LocalePriorMap`** (aggregate) and optional **`ExperienceRing`** (episodic) both feed **one** motor façade. Apply Action 2/3 formulas **once** per tick after fusion.

| Situation | Rule |
|-----------|------|
| **Phase 1 default** (ring off or **ε = 0**) | **`LocalePriorMap` only** — no merge step |
| **Both active, agree** | **Single** replay input (same tags/stats; no extra blend) |
| **Both active, disagree** | **`change_stability`** sign breaks tie: **Change (−) → `ExperienceRing`**, **Stability (+) → `LocalePriorMap`** |
| **`change_stability == 0`** | **Parity tie-break** (deterministic, not RNG): **`tie_key = hash(creature_instance_id, context_hash, GoalKind)`** — **odd → map**, **even → ring** |

**Disagree predicate — deferred (phase 1):** **No code path** while **`ExperienceRing`** is off ([CREATURE_MEMORY.md §2.1](CREATURE_MEMORY.md)). Document as **dormant until ring ships**. Tracked in **[ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md)** (Creature goal drivers).

**Future predicate (draft — tune when ring lands):** both backends have salient entries for **`(GoalKind, context_hash)`**, **and** opposite replay pull — e.g. map **`success_rate ≥ replay_disagree_success_rate_threshold`** (default **0.5**) while best ring episode is **failure / near-death**, **or** `sign(replay_delta_map) != sign(replay_delta_ring)` after Action 2/3 on both sides. If false → **agree** path.

**Example (future):** Squeeze bucket — map **50%** success; ring latest **near-death** after **`squeeze_commit`**. **Stability (+)** → **map**; **Change (−)** → **ring**; **`change_stability == 0`** → **`tie_key`** odd/even.

---

## 6. Cross-links and dual-authoring

| Topic | Authority |
|-------|-----------|
| **Motivation tree framework; trait poles; trait application order; `GoalKind` registry (§4.1); trait Tier-2 stub §3.3.1; strategy-class §5.1.1–§5.1.4; salient emitter** | **This file** |
| **`creature_motor` merge, `SeekCandidate`, Preserve/Seek thresholds, `MotorContext` tactic flags, implementation phasing** | **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** |
| **`goal_*`, `believed_goal_*`, beliefs, locale priors, §14.2 row schema, §14.1 projection, §14.3 threat pass** | **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** (strategy-class **Actions 1–3 Resolved**; **`find_food` `context_hash` — §2.1.1**; emitter §5.1.1) |

**Identifiers** (`goal_memory_*`, `_goal_belief`, …): canonical lists **CREATURE_MEMORY §10**; motor wires them per **CREATURE_MOVEMENT_V2**.

---

## 7. Changelog

| Date | Change |
|------|--------|
| 2026-05-20 | **Tier A:** starvation exception **§3**; **§4.1** `avoid_hostiles` compositor + shelter stub writes; **§5.1.1** `open_forage`, **`pole_facet_tag`** on row; **§5.1.5** escape reversal (AH-7a–c). |
| 2026-05-19 | **§3.3.1 / §5.1.2–§5.1.4:** trait Tier-2 **stub** + **`trait_tier2_mapper.gd`** urgency channels; replay keys in **`default_creature_motor_params()`**; **`external_urgency`** bitmask + linear boost; phase-1 **`current_fit`** classifier rules; Action 3 disagree **dormant**. |
| 2026-05-19 | **§5.1 combine Resolved:** **`locale_prior_strength` := `stored_strength`**; **`replay_weight` multiplicative** on **`weight_believed_goal_pull`** / seek weights only — not additive; not a second direction (**MEMORY §14.1**). |
| 2026-05-19 | **§5.1.1 Resolved:** salient emitter **`goal_source_memory.gd`**; tactic classifier flags; default modality inference per **`GoalKind`** (not pole tags in **`goal_kinds`**); deterministic pole OR table + **`find_food`** → **`explorer`** fallback. |
| 2026-05-19 | **`find_food` `context_hash`:** cross-link **MEMORY §2.1.1** (grid_cell compositor Resolved). |
| 2026-05-19 | **§4.1 Resolved:** `GoalKind` split registry — core ids (`find_food`, `avoid_hostiles`, `shelter`, `find_mate` stub); pack **`goal_kinds.extra_goal_kinds[]`**; outcome routing; **`validate_goal_kind`**; no subclass extension. §4 shelter row + §5.1 episode write cross-ref. |
| 2026-05-19 | **§5.1 Action 1 Resolved:** split allowlist (poles = GDScript; core modalities = engine resource; species **`strategy_class_tags.extra_modalities`** sibling in pack); validation reject/strip policy + **`validate_episode_tags`**. |
| 2026-05-18 | **§5.1 / MEMORY:** **`action_tag` excised** — episodic traces reuse §5.1 tag sets; no parallel episodic enum. |
| 2026-05-18 | **§5.1 Action 3 backend merge Resolved:** agree → single façade; disagree → **`change_stability`** (Change→ring, Stability→map); **`change_stability == 0`** → **`tie_key` odd/even** (odd→map, even→ring). |
| 2026-05-18 | **§5.1 Action 3 Resolved:** per-family **top-3** strength ranking (**1.0 / 0.2 / 0.2**); **`pole_strength`** / **`modality_strength`**; cross-family **multiply only**. |
| 2026-05-18 | **§5.1 Action 2 extension:** Slot B **`confidence`** (`attempt_count`, `success_count`, `success_delta`); **`replay_rank_score`** + **`change_stability`** novelty vs proven bias; combine uses optional `* confidence`; Action 3 modality tie-break → **`replay_rank_score`**. |
| 2026-05-18 | **§5.1 Action 2 Resolved:** Slot A bipolar linear trait×pole, **B-gated** cap + **`external_urgency`** for ±100; Slot B unipolar **0…100** (`current_fit` + `stored_strength`, bell saturation); combine + write-time inference table. |
| 2026-05-18 | **§5.1:** **Two-family** strategy-class tags (**8 pole facets** + **6 modalities** incl. **`flee_retreat`**); hybrid write (modalities required, poles explicit or inferred); **two-slot** replay + dual-channel outcome learning; per-family dominance; Action 1 largely **Resolved**. |
| 2026-05-18 | **§5.1:** Seed **strategy-class tag vocabulary** table + orthogonality/scope/validation prose; narrow Action 1 `<<Question>>` to finalize ids + validation story. |
| 2026-05-17 | **New draft:** split from **CREATURE_MOVEMENT_V2** §A.3 framework + §A.4 + overlapping **CREATURE_MEMORY** trait/replay prose; **§5** hosts strategy-class **Resolved** + **Actions 1–3** (`<<Question>>`). |
