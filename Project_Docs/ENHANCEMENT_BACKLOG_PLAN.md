# Enhancement backlog

Informal parking lot for improvements **not** committed in phase design docs. Priority is rough (**Low** / **Medium** / **High**).

**Doc paths:** Register and resolve locations in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) (canonical). When an enhancement is driven by active design work, the table row links the **`Draft_Features/*.md`** plan explicitly (see **Draft plan** column below).

---

## oLog (logging library)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| Structured fields (`key=value` or JSON fragments in messages) | Medium | — | Easier grep and tooling than prose-only lines |
| Rate limiting per callsite / subsystem | Medium | — | Complements ring eviction; caps repetitive spam |
| Child loggers / fixed subsystem prefix | Medium | — | e.g. `OLog.child("AI")` prepends tag without passing each time |
| Deterministic `user://` root for automated tests (CI / headless) | Medium | — | Stable paths under Godot test harness |
| Editor-only or `logging_params.enabled` gate for shipped builds | Medium | — | Optional once shipping matters |
| Mirror selected levels to remote sink (HTTP, file rotation) | Medium | — | Out of scope for current file-only design |

---

## AI integration (Hunter Killer)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Perception: cap mob list in prompt** | Medium | [Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md](Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md) | When many mobs are **near** the player, serializing **all** `MOB` lines grows tokens and noise. Consider a **max count** (keep **distance-sorted** nearest *K*, drop or aggregate the rest) with a deterministic rule — tune *K* and “near” radius after POC. |

---

## Environment & scripted motor (OBJECT follow-ups)

**Source:** Deferred `<<Comment>>` threads from [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2.5 / §10. Environment semantics: [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) §10. **Shipped motor avoidance:** [Completed_Features/MOB_AVOIDANCE_PLAN.md](Completed_Features/MOB_AVOIDANCE_PLAN.md) (indexed in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)).

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`env_detour_patience_ticks`** separate from **`awareness_memory_ticks`** | Medium | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | v1 reuses one knob for mob ghost history and env detour patience; split if coupled tuning hurts either subsystem (§10). |
| **Skill-based human HUD / tutor nudge** (safer probing, corridor use) | Low | — | OBJECT §8.2.5: interior env motor nudges are **ENGINE**-only for that phase; optional **human** assist stays a **separate** UX feature. |
| **Optional headless `can_enter` probes** (learn passibility without bump) | Low | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | OBJECT §8.2.5 comment — faster belief updates in tests or sim; not required for cardinal v1. |
| **Optional `env_threat_radius`** gate for mob-threat scoring | Low | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | OBJECT §8.2 v1 uses existing snapshot only; add only if tuning asks for an extra spatial gate (§10). |
| **Motivation traits ↔ interior motor** (`explorer_builder`, etc.) | Low | [Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md), [Draft_Features/CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md) | OBJECT §8.2.5 / CREATURE_EVOLUTION deferred coupling. |

---

## Combat — Resisted Actions subsystem

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Opponent observation table: full-rate skill gate** | Medium | [Draft_Features/COMBAT_RESOLVED.md](Draft_Features/COMBAT_RESOLVED.md) §9 | Base impl uses 25% of `combat_exp_ema_alpha`. Full-rate learning requires an observation skill unlock. `stat_observation` is the natural gating stat; exact skill definition deferred until skill tree ships. |
| **Opponent observation table: scalability cap** | Low | [Draft_Features/COMBAT_RESOLVED.md](Draft_Features/COMBAT_RESOLVED.md) §9 | Per-creature-lifetime tables become a memory concern at large population counts. Add fixed-size cap (evict LRU pairs) or sparse representation before large-population milestones. |
| **Positional response overlay (Option B)** | Medium | [Draft_Features/COMBAT_RESOLVED.md](Draft_Features/COMBAT_RESOLVED.md) §9 | Separate spatial preference overlay per creature: named positional bias keys derived from action definition positional fields, updated via EMA when opponent positional actions resolve, read by `CombatPositionResolver` as additive weights. Update-trigger and bias-key design already resolved in §9. |
| **Action context-class flags** | Low | [Draft_Features/COMBAT_RESOLVED.md](Draft_Features/COMBAT_RESOLVED.md) §9 | As Resisted Actions expands beyond combat, tag actions with context-class flags (combat, social, mating) to scope observation tables and reaction sets. Not required while only one interaction type exists. |
| **Stat/skill-modulated `combat_rank_chaos`** | Low | [Draft_Features/COMBAT_RESOLVED.md](Draft_Features/COMBAT_RESOLVED.md) §10 | `combat_rank_chaos` (near-tie jitter epsilon on `combat_rank_score`) ships as a flat, independently-tuned config default this phase. Narrowing the epsilon band based on a stat/skill (observation, wit, composure) to reflect a creature's experience/discipline is a plausible follow-up, not designed. |

---

## Death / game-over differentiation

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Distinct player defeat causes** | Medium | — | **Today:** mob contact and (per [HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md)) **starvation** may both call **`Main.game_over()`** with the same player-facing outcome. **Future:** separate messaging, sounds, analytics, and **`AiDriver`** hooks for **violence** (mob hit), **starvation**, **environment** (e.g. freezing, falling, drowning), etc. |
| **Per-cause tutorial / meta** | Low | — | Optional HUD copy or post-death screen keyed by defeat enum |

---

## Creature goal drivers & habitual replay

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`ExperienceRing` + map/ring disagree predicate** | Medium | [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §5.1 Action 3 | **Phase 1:** predicate **dormant** (map-only). When ring ships: implement disagree rule (draft: `success_rate` vs ring failure / `replay_delta` sign flip); `change_stability` tie-break + `tie_key` parity already specified. |
| **Trait → Tier-2 urgency channels (non-stub)** | Medium | [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §3.3.1 | Phase 1: **`trait_tier2_mapper.gd`** stub (zero deltas). Future: per-trait coefficients into `urgency_find_food`, `urgency_avoid_hostiles`, etc. |
| **Slot B `current_fit` — full qualitative matchers** | Medium | [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §5.1.4 | Phase 1: classifier flags only. Long-term: squeeze fingerprint, LoS hide, durable local state per §5.1 table. |
| **Remembered seek weighting (`weight_seek_remembered_goal`)** | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §10 | Phase 1: interim bump on **`weight_seek_ready_food`** in [`goal_belief_memory.gd`](../creature/motor/goal_belief_memory.gd) / [`ai_driver.gd`](../AI_int_lib/ai_driver.gd). **Target:** per-target scaling via **`weight_seek_remembered_goal`** on precise remembered seeks into **`goal_seek_targets`** / **`weight_seek_goal`** (not global seek bump). **Blocked until** goal-seek ingress stable ([CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) §A.2.2). |
| **`kind_profile` motor use (`nutrition_yield`)** | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §5.7, [CREATURE_MOVEMENT_V3](Draft_Features/CREATURE_MOVEMENT_V3) §6.2 | **V3 resolved:** yield on `_kind_profile` facets; instance `anticipated_calories` legacy stub. **6d:** EWMA on EAT; live ranking + §8.3 replace. Trait confidence modulation deferred. |
| **Combat: `fight` vs `flee_retreat` dominance** | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §5.5 Phase E | Phase E: **`avoid_hostiles` always blocks** remembered prey chase. When combat ships, predators may **fight** through remembered threat under policy. |

---

## Creature / foraging (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Predator / prey calorie intake** (predators gain calories from prey, not bushes-only) | High | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §3 | **Prerequisite** before treating predator memory/foraging as correct; ties to diet archetype table (§2). |
| **Movement-based calorie costs** (locomotion burns `current_calories` beyond time drain) | High | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §3, [Draft_Features/PLANTS_PLAN.md](Draft_Features/PLANTS_PLAN.md) | **Prerequisite** per CREATURE_MEMORY — tune via `creature_motor` / vitals; pairs with foraging tradeoffs. |
| **Food-source memory** (precise coords + egocentric 8-way) | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) | After §3 prerequisites unless phase note defers; `ai_driver.gd` / `game_config_merge.gd`. |

---

## Creature motor profiles & CI (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`creature_motor_profile_ship` numerics** | Medium | [Draft_Features/CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) §A.1 | **Stub only** until gameplay baseline exists; finalize before release exports. |
| **Ship executable automated regression** (`creature_motor_ship` feature tag) | Medium | [Draft_Features/CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) §A.1, §G.1 | **Deferred (B-10):** CI strategy for ship profile — export preset vs harness vs both — subsumes headless/executable tests, not merge-unit tests alone. Blocked on real ship profile values. |
| **Dev profile aberrant tuning table** | Low | [Draft_Features/CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) §A.1 | Per-key extreme overrides for wiring regression (small circles / obviously wrong locomotion). Lands with first §G.1 dev regression test. |

---

## Perception & awareness (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|-------|
| **Line of sight / occlusion** — solids reduce or block effective **awareness** (cone/radius) | Medium | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md), [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §7.4 | **Shipped (M4 v1):** physics rays, combined gate, >60% blocked; ghosts persist. **Backlog:** semantic fallback on plant/env bodies; stealth vs observation skill checks. |
| **Semantic LoS fallback** — plant/env body metadata when rays/grid inconclusive | Low | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §7.4 | Deferred post–M4 v1 (physics-only LoS shipped). |
| **Stealth / observation skill checks** — replace hard 60% occlusion threshold | Medium | [Draft_Features/CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) §D–E | Competing skill checks for partial occlusion. |
| **Ghost movement prediction** — escape routes vs known trapped | Low | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §7.3 | Object permanence shipped; prediction heuristics deferred. |
| **Cumulative movement_impact** — combined terrains harder than either alone | Low | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | v1 uses greatest-impact-first merge only; revisit after playtest. |
| **3D volumetric crush** — height, stacking, multi-layer semantics | Medium | [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) §10 | Full spec TBD; `crush_weight` + creature `weight` wiring deferred. |

---

## Plants & ecology (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Long-term ecology** (seeding, species, non-POC regrowth) | Low | [Draft_Features/PLANT_ECOLOGY_PLAN.md](Draft_Features/PLANT_ECOLOGY_PLAN.md), [Draft_Features/PLANTS_PLAN.md](Draft_Features/PLANTS_PLAN.md) | Shipped hunger POC: [Completed_Features/HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md). |

---

## Rendering & platform (draft design)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **3D tile terrain authoring (D5)** | Medium | [Completed_Features/CONVERT_TO_3D.md](Completed_Features/CONVERT_TO_3D.md) §D5, [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | Replace dev grasslands mesh + procedural open env grid with Godot 4.x 3D tile tools. Migration umbrella **shipped** — [CONVERT_TO_3D.md](Completed_Features/CONVERT_TO_3D.md) archived. |

---

## Other

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`res://` repo layout migration** | Medium | [Draft_Features/REPO_LAYOUT_PLAN.md](Draft_Features/REPO_LAYOUT_PLAN.md) | Systems vs **`assets/`**, optional **`systems/`** rename, **`scenes/app/`**, **`config/`**; aligns with [ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) §4 / §9; **do not apply** until draft questions resolved |
| **Stat → point pool math** | Low | [Draft_Features/SHARED_STATTOPOINT_PLAN.md](Draft_Features/SHARED_STATTOPOINT_PLAN.md) | Feeds [Draft_Features/CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md). |
| **World-model feature umbrella** | Low | [Draft_Features/VISION_WORLD_BUILDER_PLAN.md](Draft_Features/VISION_WORLD_BUILDER_PLAN.md) | Index of domain plans; archive table: [Completed_Features/EARLY_SPEC_DOC](Completed_Features/EARLY_SPEC_DOC) |
