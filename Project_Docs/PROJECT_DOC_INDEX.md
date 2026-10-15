# Project documentation index

> **Canonical path registry — update only this file when any `Project_Docs/**/*.md` is added, moved, or removed.** Other docs, code comments, and [CLAUDE.md](../CLAUDE.md) describe *policy*; **paths live here.**
>
> **Tiers:** **II** = draft (work in progress), **III** = definitive contract (`Definitive_Features/` only — no tier III at root), **A** = archived (`Completed_Features/`), **root** = navigation / backlog / templates / tracking (e.g. [OPEN_BUGS.md](OPEN_BUGS.md); not a feature plan). **Tier I** (implementation notes) stays **outside** `Project_Docs/` and is not listed here unless policy changes.
>
> **Layout (option B):** `Draft_Features/` (active drafts only), `Definitive_Features/`, `Completed_Features/`. Historical migration notes: [Completed_Features/PD_INDEXING_AND_ORGANIZATION.md](Completed_Features/PD_INDEXING_AND_ORGANIZATION.md).

---

## Folder layout

```
Project_Docs/
  PROJECT_DOC_INDEX.md          ← this file (inventory + policy)
  FEATURE_PLAN_TEMPLATE.md
  ENHANCEMENT_BACKLOG_PLAN.md
  OPEN_BUGS.md                  ← root/tracking: dense open-bug register
  Draft_Features/               ← tier II
  Definitive_Features/          ← tier III
  Completed_Features/           ← tier A (archived)
```

Do **not** add new feature plans at `Project_Docs/` root (root holds navigation, process, backlog and tracking docs only). No `Meta/` subfolder.

---

## Promotion (draft → definitive or archived)

| Target | When | Action |
|--------|------|--------|
| **`Definitive_Features/`** (tier III) | **Ongoing contract** — must stay aligned with code, `project.godot`, or shared schemas (e.g. physics layer table). Drift is a bug. | Move file; register below; remove any `Draft_Features/` copy; fix cross-links. |
| **`Completed_Features/`** (tier A) | Feature **shipped**, plan **superseded**, or content **extracted** elsewhere. **Snapshot** — drift vs code is **expected**. | Move file; register below; **delete** `Draft_Features/` copy; **no** redirect stubs. |

**Do not** promote to tier III merely because code exists. **Code comments** linking to `Completed_Features/` do **not** make those files authoritative — see [CLAUDE.md](../CLAUDE.md) **Completed_Features scope**.

**Tier III default:** `Definitive_Features/` only. Rare root exception → **exception** note in the Definitive table below with rationale.

---

## Root `Project_Docs/` (navigation & process)

| File | Tier | Role |
|------|------|------|
| [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) | root | **This file** — sole inventory + active doc policy. |
| [FEATURE_PLAN_TEMPLATE.md](FEATURE_PLAN_TEMPLATE.md) | root | Template for new feature plans. |
| [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) | root | Cross-feature parking lot; links draft plans where applicable. |
| [OPEN_BUGS.md](OPEN_BUGS.md) | root (tracking) | **Open-bug register** (`open` / `in_progress` / `pending_recurrence`): dense summary per bug, ID prefix registry; history stays in the source feature doc with a one-line pointer. **Not a feature plan** and not a contract. Rules: [CLAUDE.md](CLAUDE.md) "Bug register". |

---

## Active development (current project: Creature Movement V3)

**Project:** Creature Movement V3 — hub [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md), first committed 2026-06-15. This is the ordered "call stack" of every `Draft_Features/` doc that is part of the current work: hub first, then companions, then docs the hub depends on, then docs spun out of it. The Draft table below remains the path registry; this section says **what must be reconciled before the project closes**.

**Inclusion rule:** a draft is listed if it was created after V3 began, or was created earlier **and** has been updated for V3 work (V3 cross-references, V3-dated notes). Pre-V3 drafts with no V3 content are excluded. When unsure, leave a doc out and ask the maintainer.

| # | Doc | Role | Verify before close-out |
|---|-----|------|-------------------------|
| 1 | [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) | **Hub / spec.** ENGINE motor contract, §12 phasing, §7 telemetry. | §12 and §15 inventory rows all `done` or `deferred` with a backlog entry; no unresolved `<<Question>>` / `<<Comment>>`; §7 telemetry and config tables match code; "known limitation" notes reconciled; decide the Definitive_Features/ promotion (link from [CREATURE_MOVEMENT.md](Definitive_Features/CREATURE_MOVEMENT.md)). |
| 2 | [CREATURE_MOVEMENT_V3_CLEANUP.md](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md) | **Companion:** C# bug / gap log, R1 architecture risk. | No `open` / `in_progress` items; `pending_recurrence` items consciously accepted ([OPEN_BUGS.md](OPEN_BUGS.md) entries cleared or carried); C9 disposition reconciled with DESIGNREVIEW §1; C10 reopened as `in_progress` ([CMV3C-10](OPEN_BUGS.md#cmv3c-10); non-vocabulary `fixed` normalized); R1 `watch` decision made; debug scaffolding removed (`_DEBUG_FORCE_EDGE_CHASE_SPAWN`, temp traces). |
| 3 | [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) | **Companion:** cross-cutting design review and approved slices. | Each approved slice (§1 R1 executor controller, §4 stuck abstraction, §5 sentinel bools, §7 per-tick LoS subsystem) shipped or explicitly deferred; every `<<Question>>` answered; the "not addressed" findings (explore walk-to-wall, off-floor spawn warning) dispositioned; §9 turn-rate / evasive-bias slice decided. |
| 4 | [CREATURE_MOVEMENT_V3_RANDOMTESTS.md](Draft_Features/CREATURE_MOVEMENT_V3_RANDOMTESTS.md) | **Companion:** randomized-spawn stress-test log (RT#). | **RT4 feature slice must be addressed before this doc can be resolved / closed** (maintainer, 2026-10-14; it is a feature slice, not a bug, and is not in OPEN_BUGS.md): RT4 (`in_progress`) REST / `safety_met` half built; RT1 `<<Comment>>` (re-check the valley escape against the real navmesh with `spawn_layout_locked_rt1.json`) answered; locked layouts still referenced exist. |
| 5 | [CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) | **Dependency (semantics):** motivation tree, traits, `GoalKind` registry; V3 Step 3 sibling sync dated 2026-06-20. | Strategy-class `<<Question>>` Actions 1-3 resolved; semantics match the shipped hub; [CREATURE_TRAIT_USAGE.md](Definitive_Features/CREATURE_TRAIT_USAGE.md) still matches. |
| 6 | [CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) | **Dependency (storage):** beliefs, locale priors, §14 tuning; consumed by V3. | §14 tuning and key tables match code; memory-lifetime assumptions (wall-clock vs game time) noted; "working -> definitive" promotion decided. |
| 7 | [PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) | **Spun out:** size / passability, shelter and flee scoring (decisions 1-46). | Decision 44 live smoke re-run recorded (and `flee_memory_debug_log` switched off); staged `spawn_layout_c1_smoke.json` / `spawn_layout_c44_smoke.json` run; flee-scoring K case (ii) decided; slice 11 still parked or built; §4 open questions answered. |
| 8 | [NAVIGATION_PASSABILITY_PLAN.md](Draft_Features/NAVIGATION_PASSABILITY_PLAN.md) | **Spun out:** per-creature navigation passability (size-class navmeshes, NavRouter). | Q2-Q9, Q11, Q13 answered; acceptance checklists ticked or deferred; gap-trap and budget (B_nav, N_active) boxes settled; decision on the per-size navmesh backbone shipped or explicitly deferred. |
| 9 | [CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md) | **Spun out:** authored body dimensions, movement radius, facing invariant. | Phases 1 / 2 status current (Phase 3 shipped); headless grounding test landed; `open` fox-archetype item decided; HK-models art pipeline still aligned. |
| 10 | [CREATURE_BODY_HULL.md](Draft_Features/CREATURE_BODY_HULL.md) | **Spun out:** body-hull abstraction (collision body, nav gate hull, mesh footprint); status `design, not started`. | Nothing is implemented yet and open questions HQ1-HQ8 are unanswered: before close-out, build it, or decide and record an explicit deferral (it is not complete, so it stays active); refinements to B14 / B24 in CREATURE_BODY_DIMENSIONS reconciled. |
| 11 | [CM_V3_MULTI_MOBS.md](Draft_Features/CM_V3_MULTI_MOBS.md) | **Spun out:** multi-predator support. | Live F10 HUD verification (§8) done; link to the DESIGNREVIEW §9 evasive-bias slice still accurate; scope (still draft vs shipped) decided. |

**Closing step (required):** before calling the project complete, do **one full read-through of every doc listed above** (not skimming): check statuses, markers, links, and cross-doc contradictions; confirm every [OPEN_BUGS.md](OPEN_BUGS.md) entry sourced from these docs is resolved or consciously carried; then promote or archive per the **Promotion** table, update this section and the Draft table, and clear the project's entries from this section.

**Maintenance:** keep this list current — when V3 work adds or retires a doc, update this section in the same change as the Draft table row.

---

## `Project_Docs/Draft_Features/` (tier II — work in progress only)

**Do not** add redirect stubs or duplicate entries for shipped features — list the real path under `Completed_Features/` or `Definitive_Features/` below and remove the draft file when the work ships or is superseded.

| File | Notes |
|------|-------|
| [Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md](Draft_Features/AI_INT_CONVERSATION_SCOPE_PLAN.md) | AI / conversation scope (in progress). |
| [Draft_Features/CM_V3_MULTI_MOBS.md](Draft_Features/CM_V3_MULTI_MOBS.md) | **Multi-predator support** (investigation, not started) — scene/spawn structure, HUD observability, flee direction blending needed before more than one live predator per encounter is possible; companion to [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md)'s learned evasive-turn-bias sketch. |
| [Draft_Features/CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md) | **Creature body dimensions** (design; Phase 3 facing shipped 2026-10-05, Phases 1 / 2 not started): authored `body_length`/`width`/`height` are canonical and the model conforms (uniform scale + proportion check); width-based movement radius (+10% margin) vs length-based reach extent; facing invariant (no strafing when width ≤ length); art-pipeline alignment with the external HK-models pipeline (Rodin `bbox_condition`, +Z forward convention, B22); decisions B1–B27 (BQ1–BQ16 all answered). Spun out of [NAVIGATION_PASSABILITY_PLAN.md](Draft_Features/NAVIGATION_PASSABILITY_PLAN.md) Q10/Q12. |
| [Draft_Features/CREATURE_BODY_HULL.md](Draft_Features/CREATURE_BODY_HULL.md) | **Creature body hull** (design, not started): body-hull abstraction unifying the collision body, the navigation gate hull (oriented, D24) and the mesh footprint, so capsule-assuming consumers read one hull (capsule default for tall bodies; box / low cylinder for `height < 2r`); spun out of [NAVIGATION_PASSABILITY_PLAN.md](Draft_Features/NAVIGATION_PASSABILITY_PLAN.md) D25 / Q17 follow-up; refines B14 / B24 in [CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md). Status: `design`. |
| [Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](Draft_Features/CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) | Evolution + motor genome. |
| [Draft_Features/CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) | **Canonical:** motivation tree Tier-1/2, **`CreatureDefinition`** traits (−100…+100), goal-kind rollup, habitual **`believed_goal_*`** modulation + strategy-class **`<<Question>>`** Actions **1–3**. Consumed by [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) + [CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md). |
| [Draft_Features/CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md) | **Creature memory** (working → definitive): goal-aligned beliefs (food, danger, mates, shelter); success-pattern backends + **§14** tuning; read **[CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md)** first for Tier-2 / traits / replay semantics. |
| [Draft_Features/CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md) | Creature fields / schema; memory → [CREATURE_MEMORY.md](Draft_Features/CREATURE_MEMORY.md); Tier-2 trait narrative → [CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §3. |
| [Draft_Features/CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) | **ENGINE motor refactor (active source of truth):** `creature_motor_v3`, per-root **`creature_motor_stack`**, hub / planner / facing-relative execution, memory adapter; phasing **6a→6d**. Supersedes V2 + POST_LOS (archived). |
| [Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md) | **V3 follow-on:** bug fixes, playtest gaps, headless smoke extensions — companion to [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md); not §12 phasing. |
| [Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md](Draft_Features/CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) | **Cross-cutting design review:** flee-waypoint/R1 architecture risk, shared abstractions (stuck detector, sentinel-bool convention, per-tick LoS subsystem), stat-curve conventions, dexterity turn-rate unification (§9) — companion to [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md), not §12 phasing. |
| [Draft_Features/CREATURE_MOVEMENT_V3_RANDOMTESTS.md](Draft_Features/CREATURE_MOVEMENT_V3_RANDOMTESTS.md) | **Randomized spawn stress-test log:** issues surfaced by [ENVIRONMENT_MODEL_PLAN.md §6.4](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)'s randomized interior boulder / food / duel-pair spawn; sibling to [CREATURE_MOVEMENT_V3_CLEANUP.md](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md), not a duplicate. |
| [Draft_Features/NAVIGATION_PASSABILITY_PLAN.md](Draft_Features/NAVIGATION_PASSABILITY_PLAN.md) | **Per-creature navigation passability** (design, not started): backbone decided — tiled per-size-class navmeshes (Option A) plus an optional, switchable local exact-refinement layer (H4); decision log D1–D10 (2026-09-30 / 2026-10-01: K=3 size classes; slope/climb via physics-matched baseline + steep-variant maps + CLIMB links; derived class membership; two-layer ownership — `environment/navigation/` maps + `creature/motor/` NavRouter); Q1, Q10 and Q12 answered, Q2 partial (boundaries gated on the body-dimension values landing), Q3–Q9 and Q11 open; owns the per-size navmesh question from [PHYSICS_SQUEEZE.md decision 46 B](Draft_Features/PHYSICS_SQUEEZE.md). |
| [Draft_Features/PHYSICS_SQUEEZE.md](Draft_Features/PHYSICS_SQUEEZE.md) | **Size/passability & shelter-squeeze model:** query-only ghost collision layer, per-creature shape-cast passability (not physics-layer tricks), route-plausibility scan, squeeze/choke-point belief type, flee-bias race-margin scoring, shelter Stage A/B fit-gate. Implementation slices 1-10 done; slice 11 (held-belief hysteresis) parked pending a real noised size estimate. Stuck-target detection/exclusion review moved to [CREATURE_MOVEMENT_V3_CLEANUP.md C23](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c23). |
| [Draft_Features/PLANT_ECOLOGY_PLAN.md](Draft_Features/PLANT_ECOLOGY_PLAN.md) | Long-term plant ecology. |
| [Draft_Features/PLANTS_PLAN.md](Draft_Features/PLANTS_PLAN.md) | Plants / food index (active design; shipped slice archived). |
| [Draft_Features/REPO_LAYOUT_PLAN.md](Draft_Features/REPO_LAYOUT_PLAN.md) | `res://` layout draft (not authoritative). |
| [Draft_Features/VISION_WORLD_BUILDER_PLAN.md](Draft_Features/VISION_WORLD_BUILDER_PLAN.md) | World-builder umbrella. |

---

## `Project_Docs/Definitive_Features/` (tier III — current contract)

**Default location for tier III.** Exceptions (a spec at `Project_Docs/` root) require an explicit **exception** note in this table.

| File | Notes |
|------|-------|
| [Definitive_Features/CREATURE_3D_ARCHITECTURE.md](Definitive_Features/CREATURE_3D_ARCHITECTURE.md) | **3D creature stack:** [CreatureDefinition](res://creature/definition/creature_definition.gd), capabilities, templates, AI intent bridge. |
| [Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md](Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md) | **Stat pool → mechanics map:** `stat_*` / `curr_point_*` / `max_point_*` from [CREATURE_MODEL_PLAN.md](Draft_Features/CREATURE_MODEL_PLAN.md); disambiguation vs `current_fit`, `creature_size`, awareness keys. |
| [Definitive_Features/CREATURE_TRAIT_USAGE.md](Definitive_Features/CREATURE_TRAIT_USAGE.md) | **Motivation trait → code map:** four `CreatureDefinition` axes (−100…+100), Slot A/B replay live paths, Tier-2 urgency stub; semantics in [CREATURE_GOAL_DRIVERS.md](Draft_Features/CREATURE_GOAL_DRIVERS.md) §3–§5. |
| [Definitive_Features/CREATURE_MOVEMENT.md](Definitive_Features/CREATURE_MOVEMENT.md) | **Legacy 2D movement inventory** (cardinal pipeline, config keys, carnivore vs herbivore forks). **Not** V3 motor authority — implement ENGINE motor from [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md). |
| [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) | Env catalog; **§6** = **2D layer/mask** (`project.godot`); **§7** acceptance checklist. |

---

## `Project_Docs/Completed_Features/` (archived — tier A)

**Per [CLAUDE.md](../CLAUDE.md):** snapshots in time; not default authority unless explicitly cited. Code comment links are reference only.

| File | Notes |
|------|-------|
| [Completed_Features/AI_INSTRUCTIONS_PLAN.md](Completed_Features/AI_INSTRUCTIONS_PLAN.md) | Archived rules refactor. |
| [Completed_Features/CONVERT_TO_3D.md](Completed_Features/CONVERT_TO_3D.md) | **Archived:** 2D→3D migration umbrella (M0–M4 migration scope complete); creature stack → [CREATURE_3D_ARCHITECTURE.md](Definitive_Features/CREATURE_3D_ARCHITECTURE.md). Snapshot — drift expected. |
| [Completed_Features/ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) | Asset pipeline; see [assets/CLAUDE.md](../assets/CLAUDE.md). |
| [Completed_Features/CREATURE_GOALS.md](Completed_Features/CREATURE_GOALS.md) | **Archived:** v1 Herbivore vs Carnivore duel (opposite spawns, dual HUD, N-creature AiDriver, manual playtest log). Snapshot — drift expected. |
| [Completed_Features/CREATURE_GOALS_PLAYTEST_LOG.md](Completed_Features/CREATURE_GOALS_PLAYTEST_LOG.md) | Manual win/cause rows for CREATURE_GOALS balance tuning (companion to archived spec). |
| [Completed_Features/CREATURE_MOVEMENT_V2.md](Completed_Features/CREATURE_MOVEMENT_V2.md) | **Archived:** V2 unified motor (`creature_motor`, **`SeekCandidate`**, **`MotorContext`**, cardinal). Superseded by [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md). Snapshot — V2 code until Step 3 teardown. |
| [Completed_Features/POST_LOS_MOVEMENT.md](Completed_Features/POST_LOS_MOVEMENT.md) | **Archived:** POST_LOS planner (Phase 4.5). Superseded by [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) §§2–3, §7, §10. Snapshot — drift expected. |
| [Completed_Features/DtC_AI_INT_PLAN.md](Completed_Features/DtC_AI_INT_PLAN.md) | Dodge-the-Creeps AI integration archive. |
| [Completed_Features/EARLY_SPEC_DOC](Completed_Features/EARLY_SPEC_DOC) | Pre-split World Builder scratch; extracted into child plans — **reference only**. |
| [Completed_Features/FORK_HUNTER_KILLER.md](Completed_Features/FORK_HUNTER_KILLER.md) | Fork / mirror workflow (historical policy). |
| [Completed_Features/HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md) | Hunger + bushes POC — **implemented**. |
| [Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md](Completed_Features/HUNTER_KILLER_FIELD_AND_PERCEPTION_PLAN.md) | Field / perception archive. |
| [Completed_Features/LOGGING_PLAN.md](Completed_Features/LOGGING_PLAN.md) | Supplanted by [oLog_lib/CLAUDE.md](../oLog_lib/CLAUDE.md). |
| [Completed_Features/MOB_AVOIDANCE_PLAN.md](Completed_Features/MOB_AVOIDANCE_PLAN.md) | Shipped motor avoidance (code may link here — **reference only** unless task cites this file). |
| [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) | Object / grid avoidance archive. |
| [Completed_Features/PD_INDEXING_AND_ORGANIZATION.md](Completed_Features/PD_INDEXING_AND_ORGANIZATION.md) | **Completed** Project_Docs reorg (option B) — historical; active policy is **this index** + `AGENTS.md`. |
| [Completed_Features/SHARED_STATTOPOINT_PLAN.md](Completed_Features/SHARED_STATTOPOINT_PLAN.md) | Stat → point pool conversion (`StatMath.stat_to_point`) and the general three-peg stat curve (`StatMath.peg_curve`) — **implemented and wired**, `res://creature/stat_math.gd`. |

---

## Related (outside `Project_Docs/`)

| Location | Role |
|----------|------|
| [CLAUDE.md](../CLAUDE.md) | Always-on agent policy: doc sync, formatting, subagent routing. |
| Nested `CLAUDE.md` files | Scoped rules: [Project_Docs/CLAUDE.md](CLAUDE.md), [assets/CLAUDE.md](../assets/CLAUDE.md), [AI_int_lib/CLAUDE.md](../AI_int_lib/CLAUDE.md), [oLog_lib/CLAUDE.md](../oLog_lib/CLAUDE.md). |
| [../../HK-models/3d_modeling_v1.md](../../HK-models/3d_modeling_v1.md) | **External art pipeline (HK-models):** 2D concept → 3D model stages (Rodin/Hunyuan generation, cleanup, texturing, rigging, glTF export). Must stay aligned with [CREATURE_BODY_DIMENSIONS.md](Draft_Features/CREATURE_BODY_DIMENSIONS.md) (game units, rest-pose AABB dims, +Z forward (B22), ground-centre origin, proportion tolerances). Changes on either side → review the other. |
| [../../HK-models/shared_parts.md](../../HK-models/shared_parts.md) | External shared parts library (eyes, teeth, claws) for the art pipeline. |

The external `HK-models` paths are outside this repo; keep them in sync manually when either side moves.

---

## Maintenance

1. **Path changes:** Edit **only this file** for inventory moves; then fix broken relative links (grep the old basename).
2. **New draft:** Add a row under `Draft_Features/` when work starts; remove the row and delete the file when shipped (move to `Completed_Features/` or `Definitive_Features/` per **Promotion** above).
3. **No draft stubs** for completed features — register `Completed_Features/` (or `Definitive_Features/`) here instead.
4. **Enhancement backlog:** Link `Draft_Features/…` paths in [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) when tracking active work.
5. **Coordinated migrations:** Folder or glob changes → update [CLAUDE.md](../CLAUDE.md) and the affected nested `CLAUDE.md` files in the **same** change set.
6. **Link hygiene:** Use **relative** links from each file’s directory (`../` when crossing folders).
7. **Duplication:** One canonical path per topic — e.g. mob avoidance: `Completed_Features/MOB_AVOIDANCE_PLAN.md` only, not a duplicate in `Draft_Features/`.
8. **Active development list:** keep the **Active development** section current — when the current project's work adds, retires, or moves a doc, update that list (and its "verify before close-out" line) in the same change as the Draft table row.
9. **Open-bug register:** [OPEN_BUGS.md](OPEN_BUGS.md) is root/tracking, not a feature plan; its ID prefixes are registered at its top. Update it (and the source doc's one-line pointer) when a bug's status or facts change. Rules: [CLAUDE.md](CLAUDE.md) "Bug register".
