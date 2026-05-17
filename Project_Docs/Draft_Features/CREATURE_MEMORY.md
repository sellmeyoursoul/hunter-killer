# Hunter Killer — Creature memory (agent-friendly)

> **Purpose:** **Authoritative working spec** for **creature memory** — what an agent **stores** and **updates** so it can pursue [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) **goals** (survival, reproduction, trait-shaped priorities). Memory is **not** a telemetry dump of every seen object.

> **Motor / motivation alignment (read first):** [CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md) defines the **unified scripted motor**, **`SeekCandidate`** ingress (`feeding_mode` filters **membership/metadata**, **not** parallel code paths), the **motivation tree** (Tier-2 leaves), **`creature_motor` pack merges**, and **phasing** (ENGINE movement Foundations **before** full memory wiring). Treat that file as **primary context for agents** implementing behavior; **this** doc specifies **what** to remember **and** how beliefs merge into **`SeekCandidate[]` (+ threat/danger channels)** once the façade exists.

**Location:** `Draft_Features/` while design stabilizes; **promote** to `Definitive_Features/` when contract vs code (see [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md)). **Live code notes:** [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) (**`_goal_belief`** design block), [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd).

---

## 1. Phase summary

**Phase name:** Creature memory (**goal-generalized** beliefs + success patterns)

**One-line objective:** Specify **salient world beliefs** (§2) that reuse **one** memory schema for multiple **goals** (food, mates, **evasion & nesting**, etc.), with **precise** vs **coarse** tiers, **TTL-based coarse eviction**, **re-awareness promotion** to precise, optional **goal-type payloads** (§5–6), and hooks that **modulate Tier-2 behavior** consistently with [CREATURE_MOVEMENT_V2.md §A.3–A.4](CREATURE_MOVEMENT_V2.md) (motivation traits + relevance).

**Explicit non-authority:** **Which** entities count as **`SeekCandidate` / consumable_now / food_candidate** vs **friend/foe** is governed by **`CreatureDefinition`** + ingestion policy ([CREATURE_MOVEMENT_V2.md §A.2 — `feeding_mode` / DietRegistry posture](CREATURE_MOVEMENT_V2.md)). **Memory** stores **belief records** keyed by stable instance ids **where applicable** and **does not** restate predator/omnivore/herbivore branching.

**Out of scope (explicit non-goals):**

- Full utility-AI or MMO-scale persistence.  
- Replacing live sensory awareness with memory-only (**memory merges after / augments live sense**, same story as movement doc §C port).  
- Gender / full `CreatureStats` field catalog (**[CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)**).  
- Full **LoS/occlusion wiring** this round (**§7.4** deferral note; **movement Foundations** path may remain distance + cone until LoS lands — see CREATURE_MOVEMENT_V2 §D–E).

---

## 2. What memory is (conceptual contract)

Creature memory holds **three** cooperating layers, all keyed to **[CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) Goals and motivational priorities** and routed through the **motivation tree** in CREATURE_MOVEMENT_V2 §A.3:

| Layer | Role |
|-------|------|
| **Salient world facts** | Structured beliefs (positions, tiers, payloads, freshness) about **things that matter to active goals**. |
| **Goals and motivational priorities** | Runtime snapshot of Tier-2 **what matters now** — acute hunger/threat/find-mate/evasion urgencies that **prioritize which belief subsets** fuse into **`SeekCandidate` / threat samples**. Same tree as scripted motor (**Find food**, **Avoid hostiles**, **Find mate** stub, etc.). |
| **Successful outcome patterns** | Compact records of **action → outcome links** (“leading a predator toward a weaker prey source paid off”; “this squeeze pocket repeatedly broke LoS”; “this nook held for nesting”) so **later decisions can reuse**. |

**Linkage to motivation traits ([CREATURE_MOVEMENT_V2.md §A.4 — `CreatureDefinition` trait exports](CREATURE_MOVEMENT_V2.md)):**

- **Today (ENGINE Foundations + staged memory):** definition-time traits (**−100…+100**) are **fixed per spawn**. Memory should still write **signals** that Tier-2 mappers consume: habitual patch bias (**`believed_goal_*`**, **`believed_goal_source_bias`** — CREATURE_MOVEMENT_V2 §A.3.1), **`weight_seek_remembered_goal`** (and goal-kind analogues), cardinal coarse bias, defensive retreat toward remembered **nest / squeeze** anchors, etc. Interpret as **belief-driven modulation of Tier-2 weights / relevance**, not silent trait mutation unless a dedicated **learning** system exists.  
- **Future:** [CREATURE_MOVEMENT_V2.md §A.4 “OUT OF V2 scope”](CREATURE_MOVEMENT_V2.md) excludes **experience-driven trait drift**. When an explicit learning pass exists, successful patterns (**third row above**) become the **authority** that may **bias or slowly adjust** interpreted trait-aligned behavior (still subject to CREATURE_MOVEMENT_V2 trait-scale semantics). **[This doc]** requirements: **patterns must be plumbed such that identical logic can elevate food, mate, shelter, evasion proofs** — no forked memory silos.

<<Question: Naming for success-pattern records — episodic buffers vs hashed “belief tags” keyed by biome/cell/cluster?>>

---

## 3. Goal-aligned categories

Memory categories **rollup to Tier-2** leaves (**CREATURE_MOVEMENT_V2 §A.3**) and generalized goals:

| Category | Tier-2 / goals | This phase vs later |
|----------|----------------|---------------------|
| **Nutrition (“find food”)** | **Find food** | **Implement first** alongside the movement-memory phase (**§§4–5**); payloads may include **anticipated calories**. |
| **Mates / reproduction** | **Find mate** | **Reuse same memory schema + config keys** (see **`goal_*`** list in §10); mating-specific payloads when systems land (e.g. estrous, lineage id). |
| **Danger / hostiles** | **Avoid hostiles** | Outline + unify with **ThreatSample**/jeopardy; coarse/precise can mirror goal rules where “last hostile position” cues exist. Dedicated schema refinement **later** if needed — **still no diet archetypes**. |
| **Evasion & nesting** (supersedes legacy “ambient hiding §” wording) | Survival, reproduction (safe birth sites) | **Design in §7** — **squeeze / perceived fit**, hostile size comparison, remembered **bolt-holes**, future nest sites. Separate from standalone “ambient hide minigame.” |

---

## 4. Implementation order (requirements)

**Approved phasing mirrors [CREATURE_MOVEMENT_V2.md §B.3 — Implementation order — maintainer-approved phasing](CREATURE_MOVEMENT_V2.md):**

1. **ENGINE scripted movement Foundations** — unified **`creature_motor`**, single **`MotorContext`** + **`SeekCandidate[]`** builder (**§G** checklist in CREATURE_MOVEMENT_V2); **avoid** coupling heavy persistence memory into **that same merge** unless glue is negligible.  

2. **Predator–prey calorie path + locomotion calorie cost** (nutritional motor truth called out cross-doc) remains a **credibility prerequisite** wherever **predator-style foraging parity** overlaps memory UX — cite implementing phase when deferring (**CREATURE_MOVEMENT_V2 §B.3 bullet 1** + historical CREATURE_MODEL notes).

3. **Phase — generalized goal-memory (this doc)** — implement **§5 rules** (+ optional payloads), merge **remembered ∪ live** inside **one façade** (CREATURE_MOVEMENT_V2 **§A.2** semantic). Tune after integration; **movement correctness wins** until memory stabilization (**CREATURE_MOVEMENT_V2 §B.3 bullets 3–4**).

4. **Danger / mates / full evasion** — extend tables as systems land (**same abstraction** wherever possible).

<<Comment: If §2 “success patterns” outruns code capacity, stub **belief counters** (“times patch X yielded calories”) feeding **`believed_goal_source_bias`** before full episode store.>>

---

## 5. Goal-target memory tiers (canonical — food is first concrete goal)

**Design goal:** remember **meaningful targets** after they leave immediate awareness — **without omniscient seek**. Schema is **goal-type agnostic**: `GoalKind` discriminator + shared tier rules + optional **`GoalPayload`**.

### 5.1 Precise tier

| Target class | Representation in **Precise** | Notes |
|--------------|------------------------------|-------|
| **Stationary** (e.g. bush, fixed nest landmark) | **Exact** last-known world position (**`Vector2` / Vector3 façade**) + frozen **consumability / affordance snapshots** consistent with **`consumable_now` freeze** (**CREATURE_MOVEMENT_V2 §C**) until live refresh | Belief keyed by **`instance_id`** where stable (**`bush_food.gd`** pattern). |
| **Moving** (e.g. herbivore, fleeing mate, relocating hostile) | **Small credibility disk** centered on **last known position**: radius **`goal_memory_moving_last_known_radius_px`** (**initial default aligns with experimentation** — CREATURE_MOVEMENT_V2 §F suggested **≈50 px** as starting scalar; clamp **≤ `goal_memory_precise_radius_px`** unless design promotes an exception) | Prey velocities / ghosts may layer on same pattern (**mob_hist** analogue). |

Enter **Precise** when the creature holds a fresh belief **and** distance-from-believed-target rules place the entry inside the **precision envelope** (**§5.4** thresholds).

### 5.2 Coarse tier

**Condition:** remembered, **outside** precise envelope, **still within** **`goal_memory_forget_radius_px`** (or LRU / global policies **not superseding** TTL below).

**Representation:** unchanged egocentric model — **8-way sector recomputed each tick** from **`last_world_pos − creature_pos`**: **N, NE, E, SE, S, SW, W, NW** (**45°** sectors; **`+Y = N`** matching `ai_driver` notes). Weak cardinal bias / LLM cues — **not** a bogus map-fixed compass.

### 5.3 Coarse → forgotten (TTL in coarse state)

| Rule | Specification |
|------|---------------|
| **Coarse TTL** | While an entry stays **continuously** in **Coarse** (never promoted to Precise nor purged by distance LRU), enforce **`goal_memory_coarse_ttl_sec`** since **entered coarse** (**default ~15** s to start — tune in-play). Counter **resets** when promoted or dropped from coarse. |

### 5.4 Re-awareness: Coarse → Precise

When a remembered entity **re-enters the creature’s active zone of sensory awareness** (**same definition** as scripted motor fusion — CREATURE_MOVEMENT_V2 Foundations), **drop it from coarse-only treatment** — **snap to Precise**: refresh position/affordance from live scanner, freeze snapshots per refresh rules (**§5.1 stationaries** unchanged).

<<Comment: LRU cap (`goal_memory_max_entries`) interacts with TTL — evict weakest/oldest globally when bursting; document tie-break vs coarse TTL ordering in implementing PR?>>

---

## 6. Optional goal payloads (`GoalPayload`)

Type-specific blobs **orthogonal** to tier geometry:

| Goal kind | Example payload fields |
|-----------|-------------------------|
| **Nutrition / food** | `anticipated_calories` (estimate from memory or last sensory read), ripeness-ish flags mirrored from **`consumable_now`**. |
| **Mate** | Compatibility / courtship cues when designed (size bracket, hormonal flag, lineage avoid list). |
| **Evasion & nesting / shelter-like** | `estimated_squeeze_body_size`, `estimated_hostile_size`, `confidence` (**§7**) — qualitative “fit” not raw editor truth unless skill maxed (**future progression**). |

Payloads attach to belief entries; **routing** ignores unknown fields gracefully.

---

## 7. Evasion & nesting (refactor from “ambient hiding” prose)

**Authoritative squeeze / passage semantics:** [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) — **`passible`**, **`fit_size`**, **Mode A** squeeze.

### 7.1 Goal framing

Treat **bolt-holes**, **squeeze pockets**, future **birthing nests** as **`GoalKind.evade_or_nest` (name TBD)** records — same **tier / TTL / coarse** rules (**§5**). **Shelter/rest comfort** modulation (*reward safe recovery*) aligns with CREATURE_MOVEMENT motivation tree commentary once rest vitals tie in.

### 7.2 Size comparison (skills — not authoritative editor reads)

Creature decisions **never** consume **oracle** **`fit_size` / hostile collider extents** blindly at skill floor. Instead compare:

- **`estimated_squeeze_capability`** (**creature-relative** squeeze/clearance skill — parameterized elsewhere; improves with progression).  
- **`estimated_hostile_body_size`** (threat profiling skill / last sighting).

**Decision sketch:** propose retreat toward candidate cell only if **`estimated squeeze passage ≥ hostile estimate − margin`** (margin & transforms **implementation detail** anchored to ENVIRONMENT MODEL fields without exposing truths for free).

### 7.3 Last-known fleeing targets (**moving prey / hiding creature** symmetry)

Until predicted pathing for occupants inside squeeze cavities exists, **moving goal targets** fleeing into cover use the **moving** precise-disk rule (**§5.1** row “Moving”) — i.e., **same `goal_memory_moving_last_known_radius_px`** policy applied to last seen **bolt-hole egress** hosts.

<<Comment: Later “estimated actions inside cavity” consumes partial observability + occlusion model — defer to post-LoS backlog.>>

### 7.4 Line of sight (scope boundary)

**Explicitly out-of-scope — this authoring round.**

**Near-term posture:** Leverage whatever **Godot 3D** offers for **persistent bodies/occluders** (physics rays, occlusion queries — details TBD in implementation spike). Supplement with **semantic factors owned by Environment / Plant / prop bodies** when grid-only truth fails (**ENVIRONMENT MODEL** extensions).

**Skills cross-link:** Future **skill-based actions** SHOULD include **hide / stealth** verbs that mutate **effective LoS footprint** (**CREATURE_MOVEMENT_V2 Tier-2 / future action layer**) — coordinated with occlusion backlog (**[ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md)** *Line of sight / occlusion*).

---

## 8. Context for agents (**CREATURE_MOVEMENT_V2 forwards** implementation)

### 8.1 Read order

1. **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** — motivations, **`SeekCandidate`**, motor merge, phased acceptance (**§G**).  
2. **This file** — belief lifecycle + payload tiers.  
3. **[ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)** — geometry truths.

### 8.2 Key scripts / hooks (today’s breadcrumbs)

| Area | Paths / notes |
|------|----------------|
| Awareness split / motor food | [`AI_int_lib/ai_driver.gd`](../../AI_int_lib/ai_driver.gd) — `_motor_food_plants_in_awareness_by_readiness`, `_build_motor_context`; future generalized `_goal_belief_*` façade. |
| Config merge spine | [`AI_int_lib/game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd) — commented **`goal_*`** placeholders (**§10**); pack overlay via **`creature_motor`** (**CREATURE_MOVEMENT_V2 §A.1**). |
| Cardinal costs | [`creature/motor/cardinal_avoidance.gd`](../../creature/motor/cardinal_avoidance.gd). |
| Stationary flora anchor | [`assets/plants/bush_food.gd`](../../assets/plants/bush_food.gd) — **`global_position`**, **`instance_id`**. |

---

## 9. Resolved carry-forwards (**CREATURE_MOVEMENT_V2 §F** echoed + generalized)

| Topic | Resolution |
|-------|-------------|
| **Coarse landmarks** | **Egocentric** coarse sectors (**now**); map-fixed anchors **defer** unless revisit. |
| **Forget policy combo** | **Union** — **`goal_memory_forget_radius_px`**, TTL since last **in-awareness observation** (**global freshness**, still useful), **`goal_memory_coarse_ttl_sec` while coarse-only** (**§5.3**), session reset, LRU **`goal_memory_max_entries`** — tune together in play (**CREATURE_MOVEMENT_V2 §F** spirit). |

---

## 10. Planned config keys (`goal_*` + `believed_goal_*`)

Prefer **dual home**: authoritative defaults in **`default_creature_motor_params()`** / **`creature_motor` pack JSON** overlays when keys are tuning-adjacent; global merge MAY retain fallbacks mirrored in **`game_config_merge.gd`** comments.

**Policy:** **`food_memory_*` / `_food_belief` / `believed_food_*` identifiers are deprecated** throughout **code** and active **Draft/Definitive** docs. Implement only **`goal_*`** / **`_goal_belief`** (**no parser aliases**, **no transitional save-key bridges** unless a maintainer mandates a dedicated migration spike). *[Completed_Features/](../Completed_Features/)* snapshots may lag.

| Planned key | Role |
|-------------|------|
| `goal_memory_precise_radius_px` | Tier boundary — precise vs coarse (**~1000 px** starter in commented merge defaults). Stationary beliefs use exact coords inside envelope. |
| `goal_memory_moving_last_known_radius_px` | **Moving** credible disk (**clamp ≤ `goal_memory_precise_radius_px`** unless waived). Starter **≈50 px** per CREATURE_MOVEMENT_V2 §F. |
| `goal_memory_forget_radius_px` | Beyond → hard drop / LRU candidate. |
| `goal_memory_coarse_ttl_sec` | Forget after **N seconds continuously coarse** (**starter ~15**). |
| `goal_memory_ttl_sec` | Time since last live observation TTL (orthogonal to coarse-only timer). |
| `goal_memory_max_entries` | LRU cap. |
| `weight_seek_remembered_goal` | Motor weight bridging precise merge into **`SeekCandidate`**. |
| `weight_coarse_sector_goal_bias` | Egocentric 8-way weak bias (coarse tier). |

**Belief / habitual locale stubs** (**CREATURE_MOVEMENT_V2 §A.3.1**): **`believed_goal_hotspot_near_radius_px`**, **`believed_goal_seek_escalate_radius_px`**, motor field **`believed_goal_source_bias`**. Nutritional hotspots may ship first — keys stay **goal-generic** so mates / nests / evasion stacks reuse wiring.

---

## 11. Cross-ported questions (prior CREATURE_MODEL §9 food themes)

- <<Question: Should **`hunger`** stay stored vs purely derived (`current_calories` / needs)? (**[CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)** §9)>>  
- <<Question: **Food bushes deep inside squeeze cavities** — distance-only until LoS, or heuristic occlusion stub?>> *(Superseded loosely by CREATURE_MOVEMENT_V2 §D interim — reaffirm during memory implementation PR.)*

---

## 12. Dependencies

- **[CREATURE_MOVEMENT_V2.md](CREATURE_MOVEMENT_V2.md)** — motor/motivation **primary**.  
- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — vitals naming; motivations.  
- [Draft_Features/PLANTS_PLAN.md](PLANTS_PLAN.md), [Draft_Features/PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) — plant fields.  
- [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) — **`passible`**, **`fit_size`**, occlusion hooks.  

---

## 13. Acceptance criteria (when implementing)

- [ ] **Phasing respected:** ENGINE movement Foundations (**CREATURE_MOVEMENT_V2 §G.2**) green before heavy belief merge regressions (**§G.4** there).  
- [ ] Precise merges respect **consumable_now** freeze / payload freeze until live refresh (**CREATURE_MOVEMENT_V2 §C**).  
- [ ] Stationary beliefs = **exact** coords in precise envelope; movers = disk radius policy (**§5.1**) — **no coarse phantom vectors** surfaced as micromanaged GPS.  
- [ ] Coarse TTL (**§5.3**) + re-awareness promotion (**§5.4**) covered by deterministic tests **if feasible**.  
- [ ] **`goal_*`** / **`believed_goal_*`** keys documented in **`game_config_merge.gd`** and pack authoring when wired (**§10 — no deprecated `food_memory_*` in active codepaths**).  
- [ ] **`SeekCandidate` unify** regression check post-memory — predator/prey ingestion **already** routed through single list (**§A.2**).  
- [ ] Predator locomotion prerequisites before claiming predator memory parity (**§4 bullet 2**).  
- [ ] Future LoS / stealth alignment notes trace to ENVIRONMENT backlog + **`GoalKind.evade_or_nest`**.

---

## 14. Changelog

| Date | Change |
|------|--------|
| 2026-05-16 | **Code/doc rename:** authoritative identifiers **`goal_memory_*`**, **`weight_seek_remembered_goal`**, **`weight_coarse_sector_goal_bias`**, **`believed_goal_*`**, stubs **`_goal_belief`** / **`goal_source_memory.gd`** (`ai_driver.gd`, `game_config_merge.gd`, `cardinal_avoidance.gd`). **§10:** no **`food_memory_*`** aliases policy. **`CREATURE_MOVEMENT_V2.md`** synced (dual-author note, §§A–G). **`CREATURE_MOVEMENT.md` (Definitive)** table row updated. |
| 2026-05-16 | **Align with CREATURE_MOVEMENT_V2:** motor doc as **primary agent context**; remove **diet archetype / predator-herb.memory emphasis** duplicate — defer classification to **`feeding_mode`/`SeekCandidate`**. Memory = **facts + motivations + successful patterns**; modulation of Tier-2 + future learning hook. |
| 2026-05-16 | **Goal-generalized tiers:** stationary exact vs mover disk ≤ `goal_memory_precise_radius_px` / `goal_memory_moving_last_known_radius_px`; **coarse TTL** (**`goal_memory_coarse_ttl_sec`** ~15); **coarse eviction on re-awareness** → precise; **`goal_*` config keys**. Optional **GoalPayload** (calories, mate cues, squeeze estimates). |
| 2026-05-16 | **Evasion & nesting** refactor (skills-based size estimation vs hostiles); LoS deferral explicit; phased implementation order synced **§B.3**. |
| 2026-05-15 | *(historical)* Goal-aligned framing with diet archetypes / food-first prerequisites — superseded May 2026 alignment pass. |
