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

## Death / game-over differentiation

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Distinct player defeat causes** | Medium | — | **Today:** mob contact and (per [HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md)) **starvation** may both call **`Main.game_over()`** with the same player-facing outcome. **Future:** separate messaging, sounds, analytics, and **`AiDriver`** hooks for **violence** (mob hit), **starvation**, **environment** (e.g. freezing, falling, drowning), etc. |
| **Per-cause tutorial / meta** | Low | — | Optional HUD copy or post-death screen keyed by defeat enum |

---

## Falling & vertical traversal (draft)

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Define what "falling" actually does** | Medium | — | Right now a `CharacterBody3D` off-floor just free-falls under gravity with no game-facing meaning — no fall damage, no terminal-velocity cap, no landing recovery/stagger, no distinct death cause (see **Distinct player defeat causes** above, which already names "falling" as a future environment-cause bucket without defining the mechanic itself). Needs a decision on: does falling ever hurt/kill, is there a max safe fall height, does landing interrupt the current goal/action, is there recovery time. Surfaced 2026-09-05 while investigating a boulder-climbing bug — user noted climbing *and* falling off edges are both fine/desired in principle, but the game has never actually specified fall behavior beyond raw physics. **2026-09-21 update:** some shared groundwork now exists — [Draft_Features/PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) §3 decision 30 added a standalone `FallPhysics.ticks_to_fall(height, gravity, fps)` module (currently only used to terrain-scale the C10 airborne-invariant threshold) plus a per-tick `floor_below_dist` geometry probe already computed for that same invariant — both deliberately kept as reusable primitives rather than wired into any damage/recovery decision, so fall damage itself can consume them without re-deriving the height↔time math. |
| **Cliff-edge avoidance** | Medium | [Draft_Features/PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) §3 decision 30 | 2026-09-21: found via a live crash — a wolf walked straight off a real ~13m terrain cliff (`MOVE_F`, no avoidance logic anywhere in the AI), and the genuine fall outlasted the C10 airborne-invariant's old flat 45-tick threshold (since raised/terrain-scaled, same decision, so this exact crash won't recur — but the AI still has zero concept of "don't step off a ledge"). Matters more once fall damage and push-based attacks (below) exist: a creature that can be shoved or chased toward an edge needs to actually recognize the danger. Natural building block: the existing per-tick `floor_below_dist` geometry probe (already computed for the invariant) is the distance signal a cliff-edge check would consume before committing to a forward step. |
| **Jump mechanic + jump-vs-flee distance/damage estimate** | Low | [Draft_Features/PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) §3 decision 30 | 2026-09-21, user's own framing while scoping the cliff-fall crash fix: once fall damage exists, a cornered creature facing something lethal (a predator) might rationally choose to jump off a ledge for guaranteed small damage instead. Needs (1) an actual jump action/ability — not modeled at all today — and (2) a decision layer weighing estimated fall damage (via **Define what "falling" actually does**, above) against the threat being fled. `FallPhysics` (decision 30) was deliberately built as a shared, reusable module rather than inlined into the invariant fix specifically so this can reuse it later. Blocked on fall damage existing first. |
| **Push-based attacks / knockback** | Low | — | 2026-09-21, raised alongside the cliff-avoidance/jump discussion: a predator (or environmental force) shoving a creature some distance, potentially off a ledge into a fall — ties cliff-edge danger to combat rather than only to careless pathing. No design yet: needs a knockback force/distance model, interaction with the existing capsule-vs-ghost-layer movement resolution (§Draft_Features/PHYSICS_SQUEEZE.md), and a decision on whether it's a distinct action or a side effect of an existing bite/contact mechanic. Depends on **Combat: `fight` vs `flee_retreat` dominance** (Creature goal drivers table, above) landing first. |
| **Climbing as a skill/trait, not a physics accident** | Low | [Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) | User's stated direction (2026-09-04/05): wants climbable terrain/obstacles as a deliberate feature — e.g. a spider-like creature able to scale steeper slopes than a fox — rather than the current all-or-nothing `floor_max_angle` shared by every `CharacterBody3D`. Would need per-species (or per-trait) effective slope tolerance. Also the reason a per-obstacle collision-shape "climb guard" (tried 2026-09-05, since reverted — see **Boulder scale vs. accidental-climb workaround** below) was rejected in favor of scaling the boulder itself: an invented invisible shape whose only job is "nothing can climb this" cuts against where physics is headed once climbing ships for real. Ties to **D6** ([CONVERT_TO_3D.md](Completed_Features/CONVERT_TO_3D.md)) — "vertical gameplay… later enhancement" — this is that enhancement. |
| **Boulder scale vs. accidental-climb workaround** | Low | — | Boulders (`h-k-boulder1.blend`) got a 3x visual/collision scale-up (`PlayfieldBounds3D.BOULDER_VISUAL_SCALE`, 2026-09-05) after live-verifying that a fixed-size creature capsule can incrementally "roll up" the boulder's convex-hull collision via capsule-edge-rounding (a Jolt/Godot quirk, not a hull-fidelity problem — tried a simplified hull, full convex decomposition, and an additive smooth-cylinder collision guard; none of the mesh-shape fixes worked as well as just making the object bigger relative to the capsule). This is a stopgap for ground-only dev, not a permanent size decision — once climbing is a real mechanic (see above), revisit whether boulders should be this large by default or whether smaller, genuinely-climbable rock props should exist alongside big landmark-scale ones. |

---

## Creature goal drivers & habitual replay

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **`ExperienceRing` + map/ring disagree predicate** | Medium | [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §5.1 Action 3 | **Phase 1:** predicate **dormant** (map-only). When ring ships: implement disagree rule (draft: `success_rate` vs ring failure / `replay_delta` sign flip); `change_stability` tie-break + `tie_key` parity already specified. |
| **Post–V3 trait tactic modulator (non-stub)** | Medium | [Draft_Features/CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) §1, [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §3.1–3.2 | **Post–V3 v1 only** — does **not** block V3 ship. **V3 v1 (closed):** hub `trait_goal_mul` / planner `trait_tactic_mul` = **1.0** (spec formula hooks only — **not** in shipped `.gd` or pack config); **delete** `trait_tier2_mapper.gd` at **6b**; personality via **`replay_weight`** / locale priors at **6d**. **Open when this item is scoped:** (1) greenfield module name/API — e.g. `trait_tactic_modulator.gd` vs extending **`creature_motor_v3`** scalar keys — **not** `trait_tier2_mapper.gd`; (2) **do not** revive V2 **`urgency_find_food` / `urgency_avoid_hostiles` / …** Tier-2 channel model tied to `dom_leaf`. **Normative intent ([V3 §1](Draft_Features/CREATURE_MOVEMENT_V3.md)):** traits bias **how** an active goal is **implemented** (target choice, persist / switch / seek) — **not** which hub goal wins consideration. **Supersedes:** “Trait → Tier-2 urgency channels (non-stub)”. On pickup: revise GOAL_DRIVERS §3.3.1 + [CREATURE_TRAIT_USAGE.md](Definitive_Features/CREATURE_TRAIT_USAGE.md). |
| **Slot B `current_fit` — full qualitative matchers** | Medium | [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §5.1.4 | Phase 1: classifier flags only. Long-term: squeeze fingerprint, LoS hide, durable local state per §5.1 table. |
| **Remembered seek weighting (`weight_seek_remembered_goal`)** | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §10 | Phase 1: interim bump on **`weight_seek_ready_food`** in [`goal_belief_memory.gd`](../creature/motor/goal_belief_memory.gd) / [`ai_driver.gd`](../AI_int_lib/ai_driver.gd). **Target:** per-target scaling via **`weight_seek_remembered_goal`** on precise remembered seeks into **`goal_seek_targets`** / **`weight_seek_goal`** (not global seek bump). **Blocked until** goal-seek ingress stable ([CREATURE_MOVEMENT_V2.md](Draft_Features/CREATURE_MOVEMENT_V2.md) §A.2.2). |
| **`kind_profile` motor use (`nutrition_yield`)** | Medium | [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) §5.7, [CREATURE_MOVEMENT_V3](Draft_Features/CREATURE_MOVEMENT_V3.md) §6.2 | **V3 resolved:** yield on `_kind_profile` facets; instance `anticipated_calories` legacy stub. **6d:** EWMA on EAT; live ranking + §8.3 replace. Trait confidence modulation deferred. |
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
| **LoS reuses the §8a route plausibility scan; add `lineofsight_impact`** | Medium | [Draft_Features/PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) §8a, §8b | 2026-09-18: today's LoS ray (`line_of_sight.gd`'s `WORLD_STATIC_MASK`, layer 1 only) doesn't see the new object-scale query-only ghost layer, so a boulder/dense obstacle a creature can't fit through still won't occlude sight. Direction set, not designed: the §8a route-scan walk (creature→point, per-object shape-cast, worst-alone accumulate, stop at first hard blocker) is the right mechanism to reuse for vision too, rather than inventing a second traversal. Likely needs a second per-object property alongside `movement_impact` — a `lineofsight_impact` (how much a given object attenuates/blocks sight through it, independent of whether it's passable) — merged into the existing obscurement math (`_AwarenessZone`/`membership_with_los`'s >60% occlusion gate) the same way `movement_impact` merges via `merge_greatest_impact()`. Explicitly out of scope for the current physics/squeeze implementation pass — tracked here for when LoS/occlusion work is picked up. |
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
| **`open_shrub_3d`'s depleted visual appears to "jump" position after being eaten** | Low | — | Found 2026-09-18 during an unrelated manual smoke test (PHYSICS_SQUEEZE.md §9 slice 3's escape-hatch repro) — not caused by or related to that work. `open_shrub_3d.tscn` swaps visibility between two separately-authored mesh instances (`Visual/ReadyVisual` from `bush_ready.blend`, `Visual/DepletedVisual` from `bush.blend`) on EAT completion (`bush_food_3d.gd`'s `_refresh_visual()`); both sit at the same local transform under `Visual`, so if the two source `.blend` files don't share a consistent mesh origin/pivot, the depleted model reads as visibly shifted from where the ready one was standing. Likely fix is an asset-authoring alignment pass (co-register both meshes' origins in Blender) rather than a code change — not investigated further, just captured so it isn't lost or mistaken for a physics-layer regression from the concurrent squeeze work. |

---

## Navigation / pathfinding

| Item | Priority | Draft plan | Notes |
|------|----------|------------|--------|
| **Shared navmesh bake erodes by the largest creature's radius for every creature's queries** | Low | [Draft_Features/PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) §9 slice 1 | 2026-09-18: found while implementing PHYSICS_SQUEEZE's slice 1. `main_3d.gd`'s `_bake_playfield_navmesh()` sets `NavigationMesh.agent_radius = _duel_max_capsule_radius()` — the single shared bake is eroded by whichever creature currently in the spawn plan has the largest `collision_capsule_radius`, for every creature's path queries, not per-species. Same "one shared navmesh can't express per-species size" problem PHYSICS_SQUEEZE.md's §1 opened with, just recurring at the terrain layer (which that doc's decision 16 deliberately left engine-enforced/out-of-scope) instead of the object layer. Not a functional break — real per-instance collision against terrain is still correct regardless — but terrain-hugging navmesh-suggested routes are always as conservative as the biggest creature needs, and this gets more pronounced once the wolf's 3x scale-up (PHYSICS_SQUEEZE.md §3 decision 14) lands. Fix would mean per-size-class navmeshes/maps (Godot supports multiple `NavigationRegion3D`/maps) or accepting a smaller shared `agent_radius` with edge-case risk for large creatures — not designed, explicitly deferred rather than scope-creeping the squeeze-mechanic implementation. |

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
| **Stat display cap for UI** | Low | [Completed_Features/SHARED_STATTOPOINT_PLAN.md §9](Completed_Features/SHARED_STATTOPOINT_PLAN.md) | Should stats cap at a max int (e.g. 99) for UI display? Open since the original spec (2026-05-11); math itself is fully implemented/resolved (`stat_to_point`, `StatMath.peg_curve`) — this is UI-only and has no UI to answer it against yet. |
| **World-model feature umbrella** | Low | [Draft_Features/VISION_WORLD_BUILDER_PLAN.md](Draft_Features/VISION_WORLD_BUILDER_PLAN.md) | Index of domain plans; archive table: [Completed_Features/EARLY_SPEC_DOC](Completed_Features/EARLY_SPEC_DOC) |
