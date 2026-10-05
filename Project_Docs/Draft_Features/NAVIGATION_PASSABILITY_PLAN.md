# Hunter Killer — Per-creature navigation passability plan

> **Status:** `design` (draft, 2026-09-30); **Phase 0 code landed in the working tree 2026-10-05** (items (a)–(e), (g); (f) pending test-harness; see §8 and the 2026-10-05 changelog row). Phases 1–4 are still design only. This doc owns the per-size / per-species navmesh question opened in [PHYSICS_SQUEEZE.md decision 46 B](PHYSICS_SQUEEZE.md), the backlog rows "Shared navmesh bake erodes by the largest creature's radius" and "Crushable shrubs vs the navmesh bake" in [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md), and the "Open" bullet of [ENVIRONMENT_MODEL_PLAN.md §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md). The user answers the `<<Question>>` markers in §9 **in this doc**.
>
> **Decisions 2026-09-30 (user, in conversation; §6.1 D1–D5).** The **backbone is decided**: tiled per-size-class navmeshes (Option A), with the smallest fitting class chosen by conservative round-up. **Phase 4 changed**: it is now an **optional, switchable, budgeted local exact-refinement layer** (§5.8), not the Option D grid backend. Tiling moves into Phase 1 so that crush can be added later without re-architecting (D4). Per-class obstacle inclusion follows `passible` / `fit_size` (D5). Still open: class count and boundaries, dynamics latency, the performance budget and the remaining §9 questions (including new Q10–Q12).
>
> **Decisions 2026-10-01 (user, in conversation; §6.1 D6–D7).** Q1 answered (D6): crush capability is a **class property** (tied to size for now), slope/climb use a physics-derived class baseline with the door left open for per-creature variability, and climb / swim / compressibility are deferred with capability bits reserved. D7: class membership and navigation-layer masks are **derived at runtime** from config; no authored per-creature or per-species class or layer.
>
> **Decision 2026-10-01 (user, in conversation; §6.1 D8).** Slope and climbing structure: each class's baseline slope / climb **matches physics** (the bake slope is never raised for climbers); steep-ground walkers get **slope-variant maps** (one bake per occupied (size class, slope variant) pair, **sparse**); climbing features (boulders, cliffs, ledges) become **off-mesh links** carrying a reserved CLIMB navigation-layer bit on the existing maps; the `NavRouter` reports link traversal; "slower above X" is motor cost, not passability. Obstacles are removed from the bake **explicitly**, decoupled from slope / climb thresholds.
>
> **Decision 2026-10-01 (user, in conversation; §6.1 D9).** Q2 partially answered: **K = 3 size classes for now** (small: rabbit, fox; medium: wolf; large: mastodon, reserved, no archetype yet). Species names are descriptive only; membership is derived at runtime (D7), and the large class is not baked while no large species is in the roster (D8 sparse baking). Class **boundaries** (`R_k`) and the acceptable erosion tolerance stay open (Q2 remainder; Q10 / Q12 are answered, so it is now gated only on the B20 dimensions landing).
>
> **Decision 2026-10-01 (user, in conversation; §6.1 D10).** Navigation code ownership is a **two-layer split**. **Layer 1**, a creature-agnostic navigation maps service in `environment/navigation/` (new folder, created in Phase 1; owner `environment-world`), owns bake, tiling, class / variant maps, obstacle carving, links, readiness, tile rebakes and the size → class lookup. **Layer 2**, the creature-facing `NavRouter` in `creature/motor/` (owner `creature-motor`), is the single M5 entry point and holds all creature-specific path logic. `creature-entity` builds the `PassabilityProfile`. `main_3d.gd` keeps only bake kick-off and the handle hand-off. §8 phase owners are updated to match.
>
> **Phase 0 landed 2026-10-05 (code verified; headless tests pending).** `PassabilityProfile` (`creature/capabilities/passability_profile.gd`) and `NavRouter` (`creature/motor/nav_router.gd`) exist; every §2.4 motor call site goes through the router (no `main_3d.gd` change); route scan start-overlap is fixed; `scan_truncated_static` telemetry exists; the terrain slope measurement ran (`tools/measure_terrain_slope.gd`, numbers in §2.1). Open decision for Phase 1: `max_climb` mismatch (§2.1).
>
> **Sourcing.** The evidence below is taken from active docs ([PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md) decisions 16–25 and 46, [ENVIRONMENT_MODEL_PLAN.md §6](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md), [CREATURE_MOVEMENT_V3.md §3](CREATURE_MOVEMENT_V3.md), [CREATURE_MOVEMENT_V3_CLEANUP.md C1](CREATURE_MOVEMENT_V3_CLEANUP.md#c1--pursuit-contact-geometry-stall-fox)). Those docs cite the code. The original design pass (2026-09-30) did not re-read the code. On 2026-10-01 the caller verified specific facts in code: the bake settings in `main_3d.gd` `_bake_playfield_navmesh` (~lines 605–644), `floor_max_angle` 50° in both kinematic templates, the `motor_planner.gd` order of operations (~3264 / ~3339), and the species archetype size fields in `creature/species/*.tres`. Facts verified that way are marked with their date in place. **Everything else still needs re-confirming** before implementation starts, including the code paths named in §2.
>
> Godot API statements in §5.0 come from knowledge of Godot 4.3–4.5. Each one carries a **verify** tag until someone checks it against the 4.7 docs.

---

## 1. Phase summary

**Phase name:** Navigation passability (per-creature pathing truth).

**One-line objective:** Pathing should answer "can **this** creature get there" for every creature size and capability. The single shared navmesh is baked for one size and cannot answer that.

**Problem in one paragraph.** Today one playfield navmesh is eroded by the **largest** creature's radius (wolf, ≈ 7.25 m after voxel snapping). Every creature pathfinds on it. Small creatures lose gaps, edge strips, and access to their own food. Large creatures are routed through gaps they cannot use, because the navmesh does not contain the open-shrub ghost obstacles at all. The per-creature shape-cast route scan catches some of these routes after the fact. It cannot produce a better route: it only truncates or disqualifies the one the navmesh gave. Neither layer has the full truth.

**Out of scope (explicit non-goals):**
- Creature-vs-creature avoidance and pushing (RVO, crowding). Creatures do not carve the navmesh, and this plan keeps it that way. They also do not physically collide with each other: creature bodies use `collision_mask = 1` (world static only; `creature/capabilities/creature_kinematic_body_3d.gd` ~lines 250-253, verified 2026-09-30). Creature interaction is motor behaviour plus hitbox `Area3D` overlaps.
- Line of sight / occlusion ([PHYSICS_SQUEEZE §8b](PHYSICS_SQUEEZE.md), backlog).
- Designing the crush mechanic itself (`crush_weight` semantics, damage, regrowth). This plan only states what pathing needs from it (§4.4, Q3). Crush **pathing structure** is planned now (D4), because it forces tiling into Phase 1. Crush **semantics** stay out of scope.
- Designing climbing, swimming, or jumping **movement**. This plan only reserves the extension points (Q1) and, for climbing, the pathing structure (D8: CLIMB links, router-reported link traversal).
- Flee / choke / shelter **scoring** (decisions 20, 39, 45). Those consume pathing output and are unchanged unless noted.

---

## 2. Context for agents

**Repo / project root:** `hunter-killer/`
**Engine & version:** Godot 4.7 (per caller; the project overview memory says 4.6). GDScript. C++ / GDExtension is in scope for the agent role; whether it is acceptable here is Q5.
**Main scenes / entry:** `main_3d.tscn` / [`main_3d.gd`](../../main_3d.gd) (bake owner today; per D10 the bake moves to `environment/navigation/` in Phase 1); headless tests `tests/run_all.gd` + [`tests/motor_path_fixture.gd`](../../tests/motor_path_fixture.gd).

### 2.1 Current navmesh bake (facts, per [PHYSICS_SQUEEZE decision 46 B](PHYSICS_SQUEEZE.md) and [ENVIRONMENT_MODEL_PLAN §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md))

| Item | Value today |
|---|---|
| Owner | `main_3d.gd` `_bake_playfield_navmesh`, deferred through `_ground_props_then_bake_navmesh` (props are grounded first) |
| Parse mode | `PARSED_GEOMETRY_STATIC_COLLIDERS`, `geometry_collision_mask = 1` |
| Source | `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN`, group `playfield_navmesh_source` on `_playfield_root` (terrain + `Obstacles3D`) and `FoodPlants` |
| Voxel | `cell_size` 0.25, `cell_height` 0.15 |
| `agent_radius` | largest body radius in the spawn plan (`main_3d.gd` `_duel_max_capsule_radius()`: authored `body_width / 2 × (1 + width_margin)`), rounded up to a voxel: wolf **0.715 → 0.75 m** since CREATURE_BODY_DIMENSIONS Phase 2 (2026-10-05). The 7.03 → 7.25 m figures in §3.1 and below are the pre-Phase-2 values (evidence, historical). |
| `agent_height` | 2.0 requested → **2.10 m** (the wolf capsule is now 3.0 m tall with its centre 1.5 m up, was ~15 m / ~7.7 m pre-Phase 2) |
| `agent_max_climb` | 0.25 requested → **0.15 m** (`floorf(0.25/0.15 + 0.001) × 0.15`, snapped **down** to `cell_height`), one value for every creature (`main_3d.gd` `_bake_playfield_navmesh` ~lines 605–644, caller-verified 2026-10-01) |
| `agent_max_slope` | **Not set** in `_bake_playfield_navmesh` (caller-verified 2026-10-01; grep 2026-10-05 finds no `agent_max_slope` in `main_3d.gd`), so the bake uses the `NavigationMesh` engine default. **Measured 2026-10-05: 45°** (read from the real baked mesh by `tools/measure_terrain_slope.gd`). |
| Physics slope (`floor_max_angle`) | **50°** (`0.8726646259972418` rad) in both `creature/templates/creature_herbivore_kinematic_3d.tscn` (line 22) and `creature_carnivore_kinematic_3d.tscn` (line 20); `floor_snap_length` 0.35 (caller-verified 2026-10-01). |
| Effective navmesh slope | **Step-limit cap confirmed by measurement (2026-10-05); soft cutoff ≈ 35°, above the nominal 31°.** Recast connects neighbouring spans only if their height difference is ≤ `agent_max_climb` (**verify**). On a smooth slope each 0.25 m cell rises `0.25·tanθ`, so the nominal cap is `atan(0.15/0.25)` = 30.96°, below both the 45° default and physics' 50°. **Measured against the real bake** (interior terrain samples, away from props and the edge so erosion does not mask the step limit): coverage 0–10° 100%, 10–30° 97–99%, 30–35° 91%, **35–40° 0%**. Cause of the soft cutoff above the nominal value is not isolated (not investigated). <<Comment: confirm no `.tscn` / `.tres` NavigationMesh resource overrides `agent_max_slope`; the measurement read the effective 45°, so none is evident, but resources were not grepped. Phase 1 fixes the mismatch per D8.>> |
| Measured bake values (2026-10-05, `tools/measure_terrain_slope.gd`, headless ~18 s, boots `main_3d.tscn`, reads the real baked mesh) | `agent_max_slope` 45°, `agent_max_climb` 0.15, `agent_radius` 0.75, `agent_height` 2.1, `cell_size` 0.25, `cell_height` 0.15. Body physics: `floor_max_angle` 50°, `floor_snap_length` 0.35. |
| Terrain slope histogram (1 m grid, terrain-only rays; 2026-10-05) | Max slope **37.4°**. 0–5° 51.8%, 5–10° 24.8%, 10–15° 7.8%, 15–20° 7.7%, 20–25° 4.3%, 25–30° 2.6%, 30–35° 0.7%, 35–40° 0.5%. The physics / navmesh mismatch band that matters for this terrain is **~35–37.4°**: ≈ 117 interior samples, ≈ **0.3%** of the playfield (larger slopes than 37.4° do not occur, so the nominal 31–50° band is mostly theoretical here). |
| Re-bake experiments (2026-10-05; replicated bakes, same source geometry and parameters, only the two limits changed) | `agent_max_climb` 0.30 with slope 50° lifts 35–40° coverage to **79%**; a larger climb adds nothing for terrain. Boulders' tops and sides are **already walkable in the shipped bake** (carving is footprint + erosion driven, not slope / climb driven), which supports D8's explicit obstacle removal. The playfield-edge band is already within 2 m. Shrub-top walkability was **not measured** (no hit). The obstacle-area metric is an **upper bound** (it reads deltas, not absolutes). |
| **Open decision (Phase 1): `max_climb` mismatch** | `PassabilityProfile.max_climb` is `floor_snap_length` (0.35) when > 0, else `DEFAULT_MAX_CLIMB` 0.15; the bake's `agent_max_climb` is 0.15. The two differ, so the profile does not match the bake today. Phase 1 must pick one source of truth (D6 / D8 say the class baseline matches physics, which points at deriving the bake value from the profile) and decide the voxel snap. Not decided. |
| Readiness | `is_navigation_ready()` turns true only after the map answers a closest-point query on a baked vertex. The mesh is re-pushed every 10 frames, with a 30-frame cap. A 0-polygon bake logs and still reports ready. |
| Maps | **One** map. Motor code reaches it only through `NavRouter` (Phase 0), which reads `main.get_navigation_map_rid()` (`main_3d.gd` ~552) per query; no motor code holds the raw RID. |
| Live body dimensions (2026-10-05, measured by the tool) | Radius / capsule height / reach: rabbit 0.385 / 1.4 / 1.275, wolf 0.715 / 3.0 / 4.5 (both from the live game spawn), fox 0.22 / 0.9 / 1.5 (**standalone mount**: the fox is not in the default roster). |

**Playfield scale:** ≈ 200 × 204 m (world x −100..100, z −100..103.7, per the decision-44 smoke mapping). At 0.25 m voxels that is ≈ 800 × 815 voxel columns per bake.

### 2.2 What carves the navmesh vs who can actually pass

| Obstacle kind | Physics layer (value) | In bake? | Who can pass (design intent) | Enforced by |
|---|---|---|---|---|
| Terrain trimesh | 1 | yes | everyone, slope/step-limited | engine (`move_and_slide`) + bake slope/climb |
| Perimeter boulders (3x) / interior boulders (6x), convex | 1 | yes | nobody | engine. Decisions 16/17 planned these on the ghost layer; the migration **never happened** (decision 46 B audit). |
| `solid_shrub_3d` body (rabbit food) | 1 | yes, since 2026-09-28 | nobody today. Expected to become **crushable** (`crush_weight`, [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md), [PHYSICS_SQUEEZE §4h](PHYSICS_SQUEEZE.md)). | engine |
| `open_shrub_3d` `MobBlocker`, convex hull | 16 (ghost, mask 0) | **no** | Hull solid for everyone. Gaps **between** hulls are size-dependent squeezes. | motor shape-cast only: `GhostObstacleQuery`, `_clamp_velocity_to_ghost_fit`, `RoutePlausibilityScan` (decisions 16, 22, 25) |
| Calorie `Area3D`s | 1 (overlap only) | no (not static colliders) | n/a | n/a |
| Creatures | 2 / 4 | no | n/a | engine body-vs-body is off (masks = 1) |

**Key observation.** Every obstacle above is solid for every creature: the shrub hull, the boulder, the solid shrub. The only thing that varies with size is **which gaps between obstacles a body fits through**. For a disc-shaped footprint, navmesh erosion by `agent_radius` models exactly that. The ghost layer exists so the **physics engine** doesn't enforce those hulls. It does not exist because the hulls are passable for anyone. This matters for Option A (§5.1) and for Q6.

### 2.3 Live enforcement layer (per-creature, continuous radius)

- **Per-step gate:** `CreatureKinematicBody3D._clamp_velocity_to_ghost_fit` shape-casts the body's own capsule against the ghost layer before each move. It has an escape hatch for starting inside an overlap (§8e) and reports `ActionOutcome.blocked` (decision 25 Tier 1).
- **Route plausibility scan:** `RoutePlausibilityScan.scan_path` walks the navmesh path segment by segment with `GhostObstacleQuery.sweep_capsule_along_segment` (`cast_motion`) and truncates at the first non-fit (decision 22). It is wired into flee (`_flee_candidate_probe`, three sites) and every other mint site via `_route_scanned_endpoint` (decision 25 Tier 2 / slice 6).
- **Dead-end marks and detours:** `MemoryAdapter.is_waypoint_dead_end` at every mint site (decision 21, C23). `_route_scan_collapsed_onto_self` counts as a dead end (decision 46 E). The pursuit-detour latch (±60° rotated plus the straight-line reach compare, CLEANUP C1) and `apply_blocked_objective_resolution` act as fallback.
- **Start-overlap (fixed 2026-10-05, Phase 0 (d); headless test pending):** `cast_motion` reports "clear" when the capsule already overlaps a ghost object at the start of the sweep (decision 46 E). `RoutePlausibilityScan.scan_path` now has a start-overlap pre-check like `ShelterEnclosureProbe` (decision 33). Result key `start_overlap` is `none` / `escaping` / `blocked`: `blocked` returns reach 0 and path `[p0, p0]`; `escaping` (first segment leads out of the overlap, per `GhostObstacleQuery.escaping_overlap`) samples the exit point along the first segment and sweeps from there, and the distance walked inside the overlap counts toward reach.
- **Capsule centre (2026-10-05):** the scan, ghost-fit clamp and shelter probe test the true capsule centre (body origin + `get_capsule_center_offset_y()`), see [CREATURE_BODY_DIMENSIONS.md §4.8](CREATURE_BODY_DIMENSIONS.md) "Capsule-centre fix".

### 2.4 Single-map call sites (seam inventory; **migrated onto `NavRouter` in Phase 0, 2026-10-05**)

**Status.** Every row below now calls `NavRouter` (`creature/motor/nav_router.gd`). Grep 2026-10-05: no raw map RID use, `NavigationServer3D.map_get_path` or `map_get_closest_point*` call remains in `creature/motor/` outside `nav_router.gd` (the stack's `get_navigation_map_rid` mentions only resolve the `main_3d` node for the router). The planner ctx key `map_rid` is replaced by `nav_router` (`NavRouter.from_ctx(ctx)`); a legacy `map_rid` is still coerced into a router. The stack holds one router per body (`get_nav_router()`). The first column is kept as the original inventory.

| Consumer | Uses the map for |
|---|---|
| `MotorPathClear.resolve_step_objective` + `nav_query_origin` | substep / hop (`MIN_HOP_DISTANCE` 2 m, horizontal) ([CREATURE_MOVEMENT_V3 §3.1](CREATURE_MOVEMENT_V3.md)) |
| `motor_planner.gd` `_flee_candidate_probe`, `_route_scanned_endpoint`, `_apply_route_plausibility_scan` | reach per candidate bearing / target |
| `_apply_live_food_objective` (per-tick `map_get_path` first waypoint) | live pursuit |
| `_remint_alternate_pursuit_detour` straight-vs-rotated reach compare | C1 |
| Locale search / lost-prey search candidates (decision 46 F/G) | navmesh-snapped search points |
| `CreatureMotorStack._resolve_main` → `map_rid` | map handle for the stack |
| `tests/motor_path_fixture.gd` | builds its own map (`agent_radius` 0.25); `await_nav_ready` / `await_region_nav_ready` (decision 46 J) |

**Migration target (D10).** Every motor call site above migrates onto the **Layer-2 `NavRouter`** (`creature/motor/`, M5); none keeps a raw map RID. The map handle that reaches the motor today through `main.get_navigation_map_rid()` (`main_3d.gd` ~551, caller-verified 2026-10-01) and `CreatureMotorStack._resolve_main` is replaced by **Layer-1 handles** (`environment/navigation/`) held behind the router. In Phase 0 the router wraps the current single map, reached through the **existing** `main.get_navigation_map_rid()` accessor (no `main_3d.gd` change was needed; done). From Phase 1 it resolves per-(class, variant) handles from Layer 1. The fixture row moves onto Layer 1's fixture-buildable maps in Phase 1.

**Existing patterns to follow:** [root CLAUDE.md](../../CLAUDE.md) and [Project_Docs/CLAUDE.md](../CLAUDE.md). Query-enforced passability for object-scale obstacles (decision 16). Ground-truth sizes with noise only at tactical decisions (decisions 8/18). Worst-alone impact merge (`EnvironmentMovementImpact.merge_greatest_impact`). Staged slices, tested as they land (§8h).

---

## 3. Evidence: observed failures

### 3.1 Erosion (the shared mesh is eroded for the wolf, so small creatures pay)

> Figures in this section (7.03 / 7.25 m, ~15 m wolf capsule) are the **pre-Phase-2 observations**; the wolf radius is now 0.715 m (erosion 0.75 m). See [CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) §4.8 "Phase 2 landed state". Evidence pointer: the live radii and the slope / coverage measurement are recorded in §2.1 (2026-10-05).

- `agent_radius` 7.25 m applies to **every** creature's queries.
- The rabbit loses gaps and edge strips it physically fits through.
- Each `solid_shrub_3d` (rabbit food) sits inside a ~7 m hole. The closest navmesh point to the food is ≥ 7.25 m from the hull.
- **Decision-44 smoke pocket.** The interior is ~21.9 m wide between boulder faces, which leaves only ~7–8 m navigable (21.9 − 2 × 7.25). The pocket was re-fitted for 6x boulders so the wolf could enter. The rabbit's navigable interior shrank by the same 14.5 m.
- **Live capsule radii for small creatures are not in any active doc.** Declared `.tres` values are only fallbacks. Only two species archetypes exist (verified 2026-10-01, `creature/species/*.tres`): `rabbit_archetype.tres` (`creature_size` 1.7, `collision_capsule_radius` 0.6, height 2.0) and `wolf_archetype.tres` (6.0 / 7.0 / 15.3). **There is no fox archetype**, so the fox fallback 0.7 cited in earlier drafts has no `.tres` source. The fox's live value was 2.343 ([PHYSICS_SQUEEZE slice 4 changelog](PHYSICS_SQUEEZE.md)). **Update 2026-10-05 (evidence pointer; this bullet is historical).** Since CREATURE_BODY_DIMENSIONS Phase 2 a `fox_archetype.tres` exists, and the live radii were **measured** by `tools/measure_terrain_slope.gd`: rabbit 0.385 (height 1.4), wolf 0.715 (3.0), fox 0.22 (0.9, standalone mount; the fox is not in the default roster). So the fox 2.343 and the unmeasured rabbit radius are superseded; D9's provisional `R_small` ≥ 2.5 m illustration (fox 2.343) is stale and Q2's boundaries must be re-derived from these radii (still open). The former `<<Comment>>` markers on the fox radius source and the rabbit radius are resolved.

### 3.2 Gap trap (the navmesh cannot see the open shrub)

- The wolf (r ≈ 7.03) was routed through the gap between the solid shrub at (75,30) and the open shrub at (65,20). The centres are ~14.1 m apart; the caller estimates the wolf needs ~18.5 m. The wolf wedged in **9 of 17** headless runs (caller-reported, [decision 46 B](PHYSICS_SQUEEZE.md)).
- Mechanism: the solid shrub carves the wolf-eroded mesh, but the open shrub does not. So the navmesh shows a corridor on the open-shrub side. The route scan can only truncate that one path, so reach collapses, the creature records a dead end or retries a detour, and the navmesh keeps offering the same corridor.
- **C1 straight-vs-rotated compare ties.** Both candidates run through the same navmesh, which can't see the open shrub, so they get the same reach. Ties keep the rotated pick, so the compare never actually decides anything around open shrubs. It only discriminates on layer-1 geometry.

### 3.3 History: tuning validated against an empty navmesh

- The live bake produced **zero polygons** until the decision 46 B fix: region default `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` with no children. Before the fix `map_get_path` was always empty and `map_get_closest_point` returned (0,0,0).
- **Fix date.** Active docs date the source-mode fix 2026-09-25 (PHYSICS_SQUEEZE changelog, ENVIRONMENT_MODEL_PLAN §6.3.1). Solid shrubs joined the bake on 2026-09-28. The batch landed as commit `a6852a9`. The caller's brief says "until 2026-09-28". <<Comment: reconcile the date. It matters only for deciding which live captures count as "real navmesh" evidence.>>
- **Onset.** When the bake first broke is not established. [RANDOMTESTS RT1](CREATURE_MOVEMENT_V3_RANDOMTESTS.md)'s 2026-08-10 capture (`nav_closest=(0,0,0)`, `nav_owner_valid=false`) shows the same signature.
- **Consequence for this plan.** Much navmesh-dependent tuning was validated live on an empty mesh: flee reach (`fk=boxed`), C1 live captures, and the decision-44 smoke. The acceptance criteria in §7 therefore require **live** measurements on the new pathing and do not trust earlier live evidence.

---

## 4. Requirements and scalability drivers

### 4.1 Must have
- **M1.** A creature's path query returns routes that its own radius fits through (static obstacles), within a stated tolerance (§7). It must not return routes that are only valid for a larger or smaller body.
- **M2.** Small creatures do not lose gaps or food access to a larger creature's erosion.
- **M3.** Open-shrub-style obstacles are visible to pathing for the creatures they block (fixes the gap trap).
- **M4.** Runtime size change (decision 5) moves a creature onto the correct passability without a stall.
- **M5.** A single seam. Every motor call site obtains paths / closest points through one per-creature API, not a raw shared map RID. This keeps later migrations local.
- **M6.** Headless determinism. Fixtures can build the new structure synchronously and await readiness (continuing decision 46 J).

### 4.2 Should have
- **S1.** Dynamic obstacle updates (crush, regrowth, depleted-hull swap) reach pathing within the latency Q3 sets.
- **S2.** The live shape-cast gate stays as the exact, continuous-radius final authority for ghost-layer contact (decision 16). Pathing reduces how often it fires; it doesn't replace it.
- **S3.** An extension point for capability-based passability (climb, swim, crush weight, squeeze) that does not multiply maps combinatorially.

### 4.3 Nice to have
- **N1.** Terrain cost (mud, water) from the environment grid folded into path cost. Today it feeds only `movement_impact`, and the grid is an all-passable stub.
- **N2.** Debug overlay: draw each class map / clearance field per creature (F9-style).

### 4.4 Scalability drivers

| Driver | Source | Pressure on the design |
|---|---|---|
| Runtime size change (growth, magic) | PHYSICS_SQUEEZE decision 5 | Sizes may be continuous and change mid-route. |
| Traits: climbing, crush weight, squeeze / compressibility, swim | backlog "Climbing as a skill/trait"; PLANT_ECOLOGY `crush_weight`; ENVIRONMENT_MODEL Mode A/B `fit_size`; PHYSICS_SQUEEZE §5 `can_swim` note | Passability stops being a function of radius only. These are capability dimensions orthogonal to size. |
| More species | stated scale range "mouse to mastodon" (PHYSICS_SQUEEZE §1) | More distinct sizes. Radius range spans ≥ 10x. |
| Dynamic world | crush (removes an obstacle), regrowth (restores one), depletion hull swap in `assets/plants/bush_food_3d.gd` (changes shape; **not rebaked today**, decision 46 I) | Needs local updates at a latency the gameplay tolerates. |
| Environment grid | `EnvironmentGridBaked`, 4 m cells, origin = playfield min (decision 45 I); `EnvironmentCellData` squeeze/slowdown fields exist but have **zero callers** (PHYSICS_SQUEEZE §2b bucket 3) | Possible home for field-scale cost and a clearance field. 4 m is far too coarse for creature radii of ~1–2 m. |

---

## 5. Design space

### 5.0 Godot capability notes (verify each against 4.7 docs)

| # | Claim | Relevance | Confidence |
|---|---|---|---|
| G1 | `NavigationServer3D` supports **multiple independent maps** (`map_create`, `map_set_active`, `map_set_cell_size` / `map_set_cell_height`). A `NavigationRegion3D` joins one map (`set_navigation_map`). Each active map syncs on the physics frame. | Option A | high — **verify** |
| G2 | Agent radius / height / climb / slope are **baked into the mesh**. No path query takes a per-query radius. | Why one map can't serve many sizes | high — **verify** |
| G3 | Regions have a `navigation_layers` bitmask. `map_get_path(map, from, to, optimize, navigation_layers)` and `NavigationPathQueryParameters3D.navigation_layers` filter which regions a query may use. | Option B; capability overlays | high — **verify** |
| G4 | Regions have `enter_cost` / `travel_cost`. | Soft costs (crushable, squeeze, mud) | high — **verify** |
| G5 | `NavigationPathQueryParameters3D` has `map`, `start_position`, `target_position`, `navigation_layers`, `pathfinding_algorithm` (A* only), `path_postprocessing`, `metadata_flags`; `simplify_path` (4.3+); `excluded_regions` / `included_regions` (believed 4.4+); max-length / max-polygon search limits (believed 4.5+). | Per-query region exclusion (Option E repair) | medium — **verify versions** |
| G6 | `NavigationObstacle3D.affect_navigation_mesh` (+ `carve_navigation_mesh`) affects the navmesh **at bake time only**. At runtime obstacles affect RVO avoidance velocities, **not** pathfinding. | Crush / dynamic obstacles still need a rebake | medium-high — **verify** |
| G7 | No incremental rebake of part of one region. Rebake granularity is a **region**. Chunked tiles use `NavigationMesh.filter_baking_aabb` plus `border_size` (believed 4.3+) so adjacent tiles line up. | Local updates in Option A | medium — **verify** |
| G8 | `NavigationServer3D.parse_source_geometry_data` + `bake_from_source_geometry_data(_async)`. `NavigationMeshSourceGeometryData3D` can be parsed **once** and baked with several `NavigationMesh` settings; `add_projected_obstruction` exists (believed 4.3+). | Bake N classes from one parse | medium — **verify** |
| G9 | `AStarGrid2D` (engine C++, scriptable): `region`, `cell_size`, `set_point_solid`, `set_point_weight_scale`, `fill_solid_region` (believed 4.3+), jump-point option. Solidity is **global per grid**, with no per-query predicate. `AStar3D` covers arbitrary graphs. | Option D without GDExtension (one grid per class) | high for core API — **verify** `fill_solid_region` |
| G10 | Bake and query cost for an 800 × 815-voxel terrain at 0.25 m: **unknown**. | Option A bake budget | **measure** |
| G11 | Slope is baked: one `agent_max_slope` per bake. Steeper triangles are excluded from the mesh, and the unwalkable patches erode by `agent_radius`. Neighbouring spans connect only if their height difference ≤ `agent_max_climb`, so the step limit also caps the effective slope (`atan(agent_max_climb / cell_size)`). Slope / climb / height filters are also part of how layer-1 obstacles get removed; the bake has no "obstacle" tag. | D8: slope variants are separate bakes; obstacle removal must be explicit | medium-high — **verify** |
| G12 | `NavigationLink3D` (server: `link_create`) joins two points on a map, with `navigation_layers`, `enter_cost`, `travel_cost` and a bidirectional flag. `NavigationPathQueryResult3D` reports `path_types` / `path_owner_ids` per path point, so a caller can tell which segments cross a link. | D8: climb links; router reports link traversal | medium — **verify against 4.7** |

### 5.1 Option A — Per-size-class navigation maps (**chosen backbone, D1**)

**Shape.** K size classes, each with a class radius `R_k` (the upper bound of the class, snapped **up** to a voxel), plus class height / climb / slope. Each class gets its own map, **tiled** into regions (D4), baked from one shared parsed source (G8). A creature queries the map for the smallest class with `R_k ≥ its live radius` (conservative round-up, D1). Obstacles, including ghost-layer hulls, are included per class by the `passible` / `fit_size` rules in D5 (Q6 formally open). Because hulls are solid for everyone (§2.2), erosion by `R_k` removes exactly the gaps that class can't fit through.

- **Pros:** Godot-native (G1, G2); zero custom pathfinding. Fixes erosion within a bounded tolerance: the loss for a creature of radius r is `R_k − r`. Fixes the gap trap: the open shrub now carves the wolf map. The C1 compare becomes meaningful. Class height and climb fix overhang and step mismatches for free. This is how Unity (NavMesh agent types) and Unreal (supported agents) handle multiple sizes: one navmesh per agent type. The existing `RoutePlausibilityScan` and per-step gate stay as they are, as the exact final check.
- **Cons:** Continuous size is quantized; tolerance depends on class spacing. Bake time and memory scale by K (G10 unknown). Dynamic changes need a rebake per class, or per tile per class (G7). Capabilities (climb, swim, crush) multiply maps if modelled as maps. Readiness logic becomes per-map.
- **Crush:** A crushed shrub is removed from the source, and the affected tile is rebaked on the class maps that carved it (D4). Crush capability is a **class property** (D6): each size class either crushes a given crush band or not, so crush-capable classes treat those crushables as cost areas instead of carving them, and lighter classes carve them. No weight bands × size classes. Reason: Godot navmeshes have no per-polygon area types (cost and layer bits are per **region**, G3/G4), so "carve for light, cost for heavy" inside one class map would need hole-cut plus separate CRUSH-bit fill regions stitched by edge margin, with Option B's fragility. **Revisit trigger:** a heavy-small or light-large creature whose crush ability differs from its size class. See Q3/Q8.
- **Squeeze / compressibility:** Not native. Approximate by baking a class at `R_k × squeeze_factor` and tagging those regions with cost. This gets complicated fast. Per D6, compressibility stays **out of class maps** (deferred); `fit_size` obstacle entry is already per class via D5. See Q1.
- **Slope / climbing (D8):** Bake `agent_max_slope` / `agent_max_climb` per class at a baseline that **matches physics** (walkable range of `floor_max_angle`, with a step limit consistent with `cell_size` so baseline slopes really connect; G11). The bake slope is never raised for climbers. **Steep-ground walkers** (e.g. mountain goats: much steeper slopes, no vertical climbing) use a **slope-variant map**, a separate bake per (size class, slope variant), because slope is bake-time and Godot has no per-polygon area tags. **Climbing features** (boulders, cliffs, ledges) are **off-mesh links** (G12) carrying a reserved CLIMB navigation-layer bit, added to the existing maps with no new bakes. Links are generated per tile at bake time by a ledge detector (height above the walking step limit, within climbable height); boulder tops become islands joined by links. A climbing goat uses the steep variant plus CLIMB links. Only (class, variant) pairs that the world's roster occupies are baked (sparse). Terminology: a **map** is a separate bake; a **navigation layer** is one of 32 filter bits on regions / links within a map.
- **Runtime size change:** Switch maps at class thresholds, with hysteresis (same idea as §8d). Replan on switch.
- **Dynamic obstacles:** Tiles: the playfield is split into T regions per class, and a change rebakes the covering tile(s) × K. The depletion hull swap needs the same path, or a decision that depleted hull changes don't matter for pathing (Q3). Staleness is asymmetric (D4): a stale map after a crush is conservative, but a stale map after a regrowth or hull swap is optimistic.
- **Industry precedent (D1 rationale):** Unreal "Supported Agents" and Unity "Agent Types" both ship tiled per-agent-size Recast navmeshes at large world scale, typically with 2–4 classes.
- **Migration cost:** Medium. Bake code moves out of `main_3d.gd` into the Layer-1 maps service in `environment/navigation/` (D10), readiness per map, the seam (M5) across ~7 motor call sites, and fixture support for building K classes. There is no scoring change.

### 5.2 Option B — One fine navmesh (smallest radius) + navigation layers for "small-only" regions

**Shape.** Bake once with the smallest radius, and bake again at the larger class radii. Compute the polygon **difference** (small-only strips) and turn each band into separate regions tagged with navigation-layer bits. A large creature's query excludes the small-only bits.

- **Pros:** One map, one query path. The layer mask per creature is cheap. The same mechanism serves capability overlays (climb-only, swim-only) well, because those are **region** properties, not clearance.
- **Cons:** Godot has no navmesh boolean ops. The difference must be computed in script (`Geometry2D.clip_polygons` on XZ projections, or similar), then rebuilt into regions whose edges must connect within `edge_connection_margin`. This is fragile, especially on sloped terrain. It is still quantized to classes and still needs N bakes to compute the bands, so it costs more than A with more failure modes. Dynamic updates need the same rebake plus a re-diff.
- **Verdict:** Poor for **size**. Good for **capabilities** as an overlay on A.

### 5.3 Option C — Clearance-annotated navmesh + custom clearance-aware A*

**Shape.** Bake one mesh at the smallest radius and compute clearance per polygon edge / portal. Run a custom A* over the `NavigationMesh` polygons (vertices / polygons are readable) that rejects portals narrower than `2r`, then do a custom funnel.

- **Pros:** Continuous radius on one mesh. Exact size semantics if clearance is computed correctly.
- **Cons:** Correct corridor clearance on arbitrary triangulations is hard. Portal width is not corridor clearance. The standard fix is a local-clearance triangulation (Kallmann's LCT), which Godot doesn't produce. It replaces Godot's pathfinder entirely, so it needs a custom A*, funnel and closest-point, probably in C++ for performance. Dynamic updates still rebake Godot's mesh, then re-annotate. It inherits the navmesh's single slope / climb / height, so capabilities still need layers.
- **Concrete scalable form:** a clearance-annotated **constrained Delaunay triangulation**. Examples are Demyen & Buro's TRA* (2006) and Kallmann's Local Clearance Triangulations (LCT, 2010 / 2014). These answer "does radius r fit" exactly per query, with cost that scales with world size better than a grid. They would be custom C++ / GDExtension, and they are 2.5D (one walkable surface per XZ point).
- **Verdict (revised 2026-09-30):** Not chosen. It is the **fallback** if quantised classes (D1), even with the local layer (D2), prove inadequate **and** the world stays 2.5D (Q9). Q5 (C++) also gates it.

### 5.4 Option D — Clearance / distance field on a fine grid + custom grid pathfinder

**Shape.** A 2.5D grid over the playfield at 0.5–1 m cells. Each cell stores its height, slope, an obstacle id, and flags (crushable weight, squeeze factor, terrain kind). A distance transform ("brushfire") gives the **clearance** to the nearest blocking cell. A creature's query treats a cell as passable iff `clearance ≥ r` (or `≥ r × squeeze` at a cost), the slope / step to the neighbour is within that creature's limits, and any obstacle there is not crushable by that creature's weight. Paths come from A* / JPS with clearance (in the spirit of Harabor & Botea's Hierarchical Annotated A*, which targets multiple agent sizes plus terrain capabilities). String-pulling / Theta* smooths the result.

- **Pros:** Continuous radius **and** every capability dimension in one structure, evaluated per query. No combinatorial maps. Local dynamic updates: re-run brushfire within `max_radius` of the change, which is cheap, so crush latency is ~one frame. Aligns with the existing `EnvironmentGridBaked` / `EnvironmentCellData` Mode A/B concepts (§2b) and could finally give them callers. Runtime size change is free: the next query uses the new r.
- **Cons:** Custom pathfinder, smoothing and closest-point. At 200 × 204 m with 0.5 m cells that is ~163k cells. A GDScript A* per query is likely too slow at more than a few creatures, so this probably needs C++ / GDExtension (Q5). `AStarGrid2D` (G9) is engine-native but has global solidity, so it only helps as one grid per size class (a Grid-A hybrid). 2.5D assumes single-level terrain: no bridges, caves or overhangs; see Q9. Grid resolution trades memory against the thin-obstacle error. The existing 4 m grid is unusable for this; it needs a new fine layer. Loses Godot navmesh tooling (debug draw, `NavigationAgent3D`) unless mirrored.
- **Migration cost:** High: new subsystem, rasterizer from colliders, pathfinder, and tests. The seam (M5) keeps motor call sites unchanged.
- **Status (2026-09-30):** Kept as an alternative. It is **no longer the recommended escape hatch**; D2 replaced it in Phase 4 with the local refinement layer (§5.8). A whole-world fine grid scales with world area, and the world is expected to grow significantly (D1).

### 5.5 Option E — Status quo + smarter live repair (baseline)

**Shape.** Keep one map. Improve repair. Possible repairs: bake at the **smallest** radius so small creatures stop losing gaps; extend the route scan to sweep layer 1 too; fix the start-overlap bug; on a scan truncation, requery with the blocking spot excluded (needs `excluded_regions`, G5, which only works at region granularity, so it's ineffective on one big region); add more detour candidates.

- **Stuck watchdog with a per-agent region blacklist** (considered 2026-09-30): when a creature makes no progress, add the offending region (tile) to that creature's `excluded_regions` for later path queries (G5), with expiry. Tiling (D4) makes regions small enough for this to be useful. This folds into the §8e escape hatch as a last-resort repair. It does not replace class maps.
- **Pros:** No new infrastructure. The start-overlap fix and telemetry are worth doing anyway.
- **Cons:** It doesn't fix the root cause. Whichever radius is baked, one side of the size range gets wrong routes. Repair is reactive, one path at a time, with no alternative-route search, so gap traps become retry loops whose cost grows with clutter. Every new trait adds more repair heuristics. The C1 compare stays blind to ghost obstacles. **Not scalable.**

### 5.6 Hybrids

- **H1 (superseded 2026-09-30 by H4): A now, with a seam that allows D later.** Phase 0 builds the per-creature `PassabilityProfile` plus a `NavRouter` seam (M5) over the current single map. Phase 1 swaps in per-class maps behind it. In this version, Phase 4 replaced the router backend with D if Q2 / Q3 / Q5 pushed toward continuous sizes, fast dynamics or many creatures. The seam is kept in H4. Only the Phase 4 backend changed.
- **H4 (chosen, D1 + D2): tiled class maps (A) + optional local exact-refinement layer.** Phases 0–1 as in H1, with tiling in Phase 1 (D4). Phase 4 adds the local layer (§5.8) behind the same `NavRouter` seam, which is Layer 2 in `creature/motor/` (D10), so call sites don't know it exists. It is switchable and budgeted, and it **only adds, never fixes** (D3).
- **H2: A for size, B-style layers for capabilities.** Size classes are maps. Binary capabilities (swim, crush-heavy) are region navigation-layer bits within each class map. This avoids size × capability map multiplication for binary traits. It needs capability regions baked as separate regions, and that is fiddly (see B's cons). **Amended by D8:** slope bands can **not** be region overlays, because separately baked regions erode at their own boundaries and leave gaps up to 2× `agent_radius` that `edge_connection_margin` cannot stitch; steep ground is a slope-variant map instead. Climbing uses **links** (G12) with a CLIMB layer bit, not regions.
- **H3: Grid-A.** Option D's clearance field, but pathfinding through one `AStarGrid2D` per size class (solidity = `clearance < R_k`). Engine-native A*, local updates via `set_point_solid`, no GDExtension. Still quantized to classes; capabilities via `weight_scale` or extra grids.

### 5.7 Keep or change the navmesh-coarse / shape-cast-enforcement split?

With A / H4 the split **stays, but the roles sharpen**:
- The navmesh (per class) becomes the **route** truth for static geometry, including ghost hulls. It's no longer "coarse" in the sense of being wrong about size.
- The per-creature route scan becomes a **residual** check for continuous-radius error inside a class (`R_k − r`), dynamic changes since the last bake, and future Mode-B `movement_impact` accumulation (decision 22).
- The per-step gate stays the exact final authority (decision 16).
- Dead-end marks and detours stay as fallback for dynamic cases, as decision 22 intended.

With D, the grid becomes the single route and passability truth. The shape-cast stays only as the physical contact gate.

**Open option, not decided: navmesh-constrained movement.** Detour's `moveAlongSurface` and Unreal's NavWalking movement mode clamp each tick's motion to the navmesh surface. Physics is then used only for contact and hits. The Godot approximation is to clamp the post-move position with `map_get_closest_point` on the creature's class map (G1). This removes the planner-vs-physics mismatch **by construction**, because a creature cannot stand anywhere its own map says is closed.
- **Why it fits here:** creatures don't collide with each other (§1), so there is no crowd push-off to preserve, and nothing needs physics to shove a creature off the mesh.
- **What it requires:** **everything** that blocks must be in the bake (ghost hulls, solids, per-class inclusion per D5). Anything left out becomes walk-through. Dynamic changes are only as fresh as the last tile rebake, so D4's asymmetric staleness applies directly to movement, not just to routes. It interacts with the local layer (§5.8): a squeeze taken off the class map would need the clamp to use the local layer's corridor or a smaller class's map there.
- **Relation to decision 16:** it would replace the per-step ghost shape-cast gate as the primary enforcement for static obstacles. That is a larger change to decision 16 than this plan otherwise makes.

### 5.8 Local exact-refinement layer (chosen Phase 4 hybrid, D2 / D3)

**Home (D10).** The layer lives in the Layer-2 `NavRouter` (`creature/motor/`, owner creature-motor), because it needs the creature's live radius and state. It reads Layer-1 maps (`environment/navigation/`) only through plain-value queries, e.g. the smallest-class walkability check in step 4.

**Shape.** Near the creature, inside a window of radius `W` (≈ 30–50 m, configurable), build a per-creature **inflated-obstacle (configuration-space) visibility graph**:
1. Collect the convex hulls physics already uses inside the window: boulders, solid shrubs, and ghost-layer open-shrub `MobBlocker` hulls. Apply the D5 inclusion rules at the creature's own size.
2. Project each hull to XZ and grow it by the creature's **live** radius r (Minkowski sum with a disc, approximated by a polygon offset). Merge overlapping grown hulls.
3. Nodes are the grown-hull vertices plus start and exit. Edges are mutually visible node pairs. A* over this graph gives the shortest path at exactly radius r.
4. **Splice:** replace the class path's section inside the window with the local path, from the creature to the point where the class path leaves the window (or to the target if it is inside). Accept only if all of these hold: it is shorter by a margin, every local segment lies over walkable ground (checked against the **smallest** class map, which covers slope and step limits the 2D graph can't see), and `RoutePlausibilityScan` passes it.

**Cost** scales with (queries per frame) × (obstacle corners in the window)², **not** with world size. That is why it survives as a local layer when the naive global version doesn't (§5.9).

**Hard requirement: it only adds, it never fixes (D3).** The class navmesh plus the existing shape-cast enforcement must always yield a correct, non-stuck path **on their own**. The local layer only upgrades routes that are already valid. With the layer OFF, routes are class-quantised but never broken. No correctness path may depend on it: no fix for a class-map bug, no gap-trap escape and no dead-end recovery may be routed through it.

**Controls** (config section `navigation` in `game_config.json`, owned by app-shell; key names are proposals):

| Proposed key | Purpose |
|---|---|
| `navigation.local_refinement.enabled` | Master switch. `false` means class-quantised routes only. |
| `navigation.local_refinement.trigger_radius_ratio` | Trigger gate, part 1: run only when `r ≤ ratio × R_k`, meaning the creature is well below its class radius. |
| (bake-time flag, no key) | Trigger gate, part 2: run only when the class route passes within the window of a gap flagged **"closed for this class, open for smaller"**. Flags come from each class bake: obstacle pairs whose hull-to-hull gap `g` satisfies `g < 2·R_k`, with `g` recorded. A creature qualifies only if `2r ≤ g`. |
| `navigation.local_refinement.max_queries_per_physics_frame` | Per-physics-frame query budget. Requests over budget wait in a **time-sliced queue**. The creature follows its class route meanwhile. |
| `navigation.local_refinement.max_ms_per_physics_frame` | Hard time cap that sits alongside the query budget. |
| `navigation.local_refinement.window_radius_m` | Window radius `W` (proposal 40). |
| `navigation.local_refinement.cache_radius_bucket_m` | Result cache keyed by (obstacle cluster, radius bucket). The radius rounds **up** to its bucket, so the cache stays conservative. Entries are invalidated on crush, regrowth or hull swap within the cluster. |
| `navigation.local_refinement.priority` | Priority / LOD ordering of the queue: creatures in flight, then in pursuit, then near the camera or player. Idle, distant creatures come last or never. |
| `navigation.local_refinement.species_opt_out` | Per-species opt-out, as a list of species ids. The alternative is a species archetype export; the implementing slice picks one. |

**Telemetry:** queries per frame, ms spent per frame, queue depth, and upgrades accepted vs rejected (with the rejection reason: not shorter, off walkable ground, scan failed).

**Tests** run the gap-trap and erosion scenarios **both ways**. OFF: the creature is slower (it detours) but not stuck. ON: it takes the squeeze.

**Limits:** it is 2D inside the window (Q9). Cost areas (Mode B, crush cost) aren't modelled; the local graph sees only hard hulls. Its freshness is live within the window, because it reads current hulls rather than the bake.

### 5.9 Other alternatives considered (2026-09-30)

| Alternative | What it is | Verdict |
|---|---|---|
| Naive per-query obstacle inflation + visibility graph | Configuration-space VG over **all** obstacles for every query | Exact for any radius, and dynamic. But global per-query cost grows ~n² in obstacle corners, and it is 2D only, so it doesn't scale to a large, dense world. **Survives only as the local layer (§5.8).** |
| Clearance-annotated CDT (TRA*, LCT) | See §5.3 | The concrete scalable form of exact per-radius pathing. The fallback if quantised classes prove inadequate **and** the world stays 2.5D (Q9). |
| Navmesh-constrained movement | See §5.7 | Open option, not decided. Fits well because creatures don't collide with each other. |
| Width-based path radius | Path radius ≈ half the shoulder width (industry practice) instead of a capsule that encloses the model. The wolf's `collision_capsule_radius` is 7.0, capsule height 15.3 and `creature_size` 6.0 (`creature/species/wolf_archetype.tres` lines 19-21, verified 2026-09-30). | Would shrink erosion and the number of classes needed. Open: **Q10**. |
| Soft vegetation | Foliage is costly but passable for large animals, not a hard blocker. Common in games. | Removes the gap trap for those obstacles outright. Interacts with Mode B `fit_size` (D5). Open: **Q11**. |
| Stuck watchdog + per-agent region blacklist | `excluded_regions` on path queries (G5) | Folded into Option E and the §8e escape hatch (§5.5). |
| RVO / ORCA, context steering, flow fields | Local avoidance and crowd steering | Not applicable: they address creature-vs-creature and crowd movement, not static size passability. |
| HPA* | Hierarchical abstraction for speed | Speed only. It doesn't change passability semantics. |
| Dijkstra flee maps (Brogue-style) | A distance-from-threat field, descended to flee | A possible future alternative to flee-candidate probing (`_flee_candidate_probe`). Not in scope here. |

---

## 6. Recommendation (backbone decided 2026-09-30; details pending)

**H4: tiled Option A with K = 3 size classes for now (D9; industry practice is 2–4), with the maps in a creature-agnostic Layer-1 service (`environment/navigation/`) behind a new Layer-2 `NavRouter` seam (`creature/motor/`, D10), obstacles included per class by the D5 rules, and an optional, switchable, budgeted local exact-refinement layer in Phase 4 (§5.8).** Option D is kept as an alternative (§5.4), not the planned escape hatch. LCT (§5.3) is the fallback if quantisation proves inadequate and the world stays 2.5D. Rationale:

1. The two concrete failures are erosion and the gap trap. Both come from *one radius for everyone* and *ghost hulls missing from pathing*. A fixes both with native Godot features and no custom pathfinder.
2. The seam (Phase 0) has value under every option and is the only part that touches all motor call sites. The local layer and any later backend change sit behind it.
3. The playfield is a small, controlled dev environment today. The world and its object count will grow significantly. Tiled per-agent-size Recast navmeshes are what Unreal and Unity ship at that scale. Global continuous exactness isn't required (D1). Where it pays off, the local layer supplies it at a cost that doesn't grow with the world (D2).
4. Tiling now (D4) keeps crush and regrowth a local rebake instead of a later re-architecture.

**Would still change the recommendation:**
- Class-quantisation error proves unacceptable even with the local layer, and Q9 = single-level → **LCT (§5.3)**, gated on Q5.
- Q3 = sub-second path reaction to crush and regrowth at many sites → measure tile rebakes × K (G10) first. If that misses, lean harder on the shape-cast plus the local layer for the stale window before reconsidering D.
- Q6 = "never bake ghost hulls" → A still fixes erosion but **not** the gap trap. D5 implies baking them; see Q6.
- Q10 / Q11 answers may shrink K, or remove the gap trap for vegetation entirely.

### 6.1 Decision log

| # | Date | Decision (user, in conversation) | Consequence in this doc |
|---|---|---|---|
| D1 | 2026-09-30 | **Size classes, each with its own navmesh (Option A), are the global backbone.** Fixed classes; a creature uses the smallest class that fits (round up, conservative). Continuous exactness is **not** required globally. Rationale: the playfield is a small, controlled dev environment, the world and object count will grow significantly, and tiled per-agent-size Recast navmeshes are what Unreal ("Supported Agents") and Unity ("Agent Types") ship at scale, typically with 2–4 classes. | Q2 partially answered. §5.1, §6, §8 Phase 1. |
| D2 | 2026-09-30 | **Phase 4 replaces "Option D grid backend" with an OPTIONAL local exact-refinement layer**: a per-creature inflated-obstacle visibility graph near the creature (window ~30–50 m), built from the same convex hulls physics uses and grown by the live radius. It takes exact squeezes the class map closed. Cost scales with (queries/frame × local obstacle density), not world size. D stays in §5 as an alternative. | §5.4 status, §5.6 H4, §5.8, §8 Phase 4, §8.1 H4 column. |
| D3 | 2026-09-30 | **The local layer is switchable and budgeted, and it only adds, never fixes (hard requirement).** Class navmesh + shape-cast enforcement must always yield a correct, non-stuck path on their own. Controls: master switch, trigger gating, per-frame query budget with a time-sliced queue, window radius, result cache, priority/LOD, per-species opt-out. Config section `navigation` (app-shell, `game_config.json`). Telemetry and both-ways tests. It sits behind the `NavRouter` seam. | §5.8, §7, §10, §11. |
| D4 | 2026-09-30 | **Crush is planned now (not implemented), so tiling moves into Phase 1.** Retrofitting tiles onto monolithic per-class bakes is expensive. (a) A baked obstacle can't be removed individually; the rebake unit is a region or tile (G7). (b) **Asymmetric staleness:** after a crush the stale map says "blocked" (conservative, harmless). After a regrowth or hull swap the stale map says "open" while physics blocks (dangerous). The shape-cast and local layer cover that window, and regrowth rebakes get priority. (c) **Crush-capable classes don't carve crushables:** crushables are cost areas (`travel_cost`) for crush-capable classes, and carve only for the classes that can't crush them. A crush then rebakes only where the shrub was carved. *(Amended 2026-10-01 by D6: crush capability is a class property, not separate weight bands × classes.)* Crush **semantics** stay out of scope. | §1, §5.1, §8 Phases 1–2, §10, Q3/Q8 notes. |
| D5 | 2026-09-30 | **Per-class obstacle inclusion via `passible` / `fit_size`** (semantics: `environment/environment_cell_data.gd`, [ENVIRONMENT_MODEL_PLAN property catalog](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)). **Mode A** (`passible == false`): carve as solid in a class's map **unless** the class's max `creature_size` ≤ `fit_size`. In that case the interior is enterable and is not carved. `fit_size` null / 0 / invalid means nobody enters, so the obstacle carves for every class; that is today's case for boulders and open-shrub hulls. **Mode B** (`passible == true` + active `movement_impact`): never carved. It is a cost area for classes whose sizes reach `fit_size` (Mode B's strict `<` exempts smaller bodies) and free for smaller classes. Gaps **between** obstacles stay governed by each class's `agent_radius` erosion; `fit_size` governs **entering** the obstacle itself. | §5.1, §5.8 step 1, §8 Phase 1, Q6 note, new Q12. |
| D6 | 2026-10-01 | **Q1 answered: which passability dimensions vary per creature in pathing.** Radius: per class (D1). Height: per-class `agent_height` (class max height). Slope / climb: class baseline derived from physics, with the **door left open** for per-creature variability (a stat, skill or trait may climb steeper slopes, or past slope X there may be a speed penalty or fall risk), not designed now. `PassabilityProfile.max_slope` / `max_climb` are **derived** fields, never hard-coded at call sites; the router computes its `navigation_layers` mask from the profile at query time. **Crush is tied to size for now: crush capability is a class property** (each class crushes a given crush band or not); no weight bands × size classes, because Godot cost / layer bits are per region, not per polygon (§5.1). Revisit trigger: a heavy-small or light-large creature. Climbing trait, swim and compressibility: **deferred**; Phase 0 reserves capability bits for climb and swim. "Squeeze" split: `fit_size` entry is per class via D5 (no new work); compressibility stays out of class maps. *(Amended 2026-10-01 by D8: the slope / climb "door" is now structured as slope-variant maps + CLIMB off-mesh links. The earlier "slope-band overlay regions with layer bits" option is rejected, because separately baked regions erode at their own boundaries and leave gaps up to 2× `agent_radius` that `edge_connection_margin` cannot stitch. `travel_cost` slope bands are replaced by motor-side cost, D8.6.)* | §5.1 crush / squeeze / climbing bullets, D4 amended, Q1 answer, Q8 direction, §8 Phases 0, 1, 3. |
| D7 | 2026-10-01 | **No authored per-creature or per-species navmesh class or layer assignment.** Class membership and any `navigation_layers` mask are **derived at runtime** from the creature's size / traits against the class table in config. Inserting a new class between two existing sizes needs only a config change (class table); no edits to creature instances, species `.tres` or templates. Runtime hysteresis state is fine (derived, not authored). Whatever Q12 decides as the canonical size measure, membership is computed, never stored as authored data. | §8 Phases 0–1, Q12 note. |
| D8 | 2026-10-01 | **Slope and climbing structure.** (1) **Baseline slope / climb per class matches physics**: the walkable range of `floor_max_angle` (50° today, §2.1), with a step limit consistent with `cell_size` so baseline slopes really are connected (today's 0.15 m climb at 0.25 m cells caps the effective slope at a suspected ~31°, G11). The bake slope is **not** raised to accommodate climbers. (2) **Steep-ground walkers** (e.g. mountain goats: no vertical climbing, much steeper slopes) → **slope-variant maps**: a separate bake per (size class, slope variant), because slope is bake-time. There is no cheaper Godot form: no per-polygon area tags, and "bake permissive, filter per creature" violates D3. (3) **Climbing features** (boulders, cliffs, ledges) → **off-mesh links** (`NavigationLink3D`, G12) carrying a reserved **CLIMB navigation-layer bit**, added to the existing maps (no new bakes). Links are generated per tile at bake time by a **ledge detector** (height above the walking step limit, within climbable height); boulder tops become islands joined by links. A climbing goat uses the steep variant + CLIMB links. (4) **Sparse baking:** only (size class, slope variant) pairs that some species in the world's roster occupies are baked (extends today's spawn-plan-derived radius in `_duel_max_capsule_radius()`; enabled by D7). *(Amended 2026-10-01 by D10: `main_3d.gd` hands the roster's sizes / traits to Layer 1 as plain values at bake kick-off, Layer 1 maps them to occupied pairs, and `_duel_max_capsule_radius()` is retired.)* Worst case K classes × V variants maps (illustrative: 8 × 2 = 16; today K = 3, D9); typically far fewer. Terminology: **maps** are separate bakes; **navigation layers** are the 32 filter bits on regions / links within a map. (5) **The router reports link traversal:** `NavRouter` exposes which path segments cross links (via `path_types` / `path_owner_ids`, G12) so the motor can later switch movement mode. Climb movement itself is out of scope. (6) **"Slower above X" / fall risk:** inside the walkable range this is cost, not passability. Motor-side speed reduction from the floor normal is possible now (`creature_motor_stack.gd` ~544 reads `floor_below_slope_deg`). Pathing slope cost would need a custom polygon search (deferred, behind `NavRouter`). Fall risk is motor / physics. (7) **Rejected:** "bake each class at its most permissive member's slope" (superseded by (2)); "bake at 90° and filter slope in our code", because filtering only truncates the one returned path and cannot reroute (the gap-trap failure class; the motor picks candidates, queries `map_get_path`, then `RoutePlausibilityScan` truncates, `motor_planner.gd` ~3264 / ~3339, caller-verified 2026-10-01), because slope / climb / height filters are part of how layer-1 obstacles (boulders, solid shrubs, cliffs, playfield edge) are carved today (G11), so loosening them makes obstacle tops and sides walkable, and because the default path would depend on extra code (inverts D3). **Consequence:** obstacles are removed from the bake **explicitly** (projected obstructions, G8, under the D5 hull rules), decoupled from slope / climb thresholds. | Header, §2.1, §5.0 G11–G12, §5.1 slope / climbing bullet, §5.6 H2, D6 amended, §7, §8 Phases 0, 1, 3, §8.1, Q1 answer, §10, §11. |
| D9 | 2026-10-01 | **Q2 partially answered: K = 3 size classes for now.** **small**: rabbit, fox. **medium**: wolf. **large**: mastodon (no archetype exists yet; reserved class). Species names here are **descriptive, for design discussion only**: per D7, actual membership is derived at runtime from each creature's size against the config class table, never authored per species. Per D8 sparse baking, the large class is **not baked** while no large species is in the roster. "For now": adding a class later is config-only (D7). Facts (verified 2026-10-01, `creature/species/*.tres`): only `rabbit_archetype.tres` (`creature_size` 1.7, `collision_capsule_radius` 0.6, height 2.0) and `wolf_archetype.tres` (6.0 / 7.0 / 15.3) exist; there is no fox or mastodon archetype. The fox's live radius 2.343 comes from the PHYSICS_SQUEEZE slice 4 changelog (source unverified, §3.1). The rabbit's live radius is unmeasured (§3.1). **Class boundaries (`R_k`) stay open**, gated on Q10 (path radius vs enclosing capsule) and Q12 (size↔radius canonical). *Provisional illustration only, not decided:* small must cover the fox's live 2.343 → `R_small` ≥ 2.5 m after voxel snap-up; medium covers the wolf's live 7.03 → `R_medium` = 7.25 m. | Header, §3.1 (fox source note), §6, D8 example, §8 Phase 1, Q2 answer + narrowed question, §10 map-count risk. |
| D10 | 2026-10-01 | **Navigation code ownership: two-layer split.** **Layer 1, navigation maps service** (`environment/navigation/`, new folder created in Phase 1, owner **environment-world**): bake (moved out of `main_3d.gd` `_bake_playfield_navmesh` ~605, readiness ~684 and `get_navigation_map_rid` ~551, caller-verified 2026-10-01), tiling, size classes × slope variants (D8 / D9), explicit obstacle carving, link generation (ledge detector), sparse pair baking, per-map / per-tile readiness, tile rebakes (crush / regrowth / hull swap), and the **size → class lookup** against the config class table (the single source of class boundaries, D7). Its query API is **creature-agnostic**: plain values only (e.g. `query_path(class_id, variant_id, layer_mask, from, to)`, `closest_point(...)`, link-crossing info in results), with no creature bodies or state, so non-motor consumers (spawn placement, AI) can reuse it and fixtures can test it. `main_3d.gd` (app-shell) keeps only the bake kick-off and the handle hand-off. At kick-off it gathers the spawn roster and hands Layer 1 the required sizes / traits as plain values (e.g. a list of radii / sizes plus slope-variant needs); Layer 1 maps them to occupied (class, variant) pairs via its size → class lookup, replacing and retiring today's precursor `_duel_max_capsule_radius()` (amends D8 (4)). **Layer 2, creature-facing path service** (the `NavRouter` / M5 seam, `creature/motor/`, owner **creature-motor**): the single entry point for all motor call sites. It translates a creature's `PassabilityProfile` into a Layer-1 query and then applies creature-specific logic: `RoutePlausibilityScan` (existing), the Phase 4 local exact-refinement layer (live radius, window hulls, priority/LOD, per-frame budget queue), future per-creature slope cost / limits, and the stuck watchdog / per-creature region blacklist. New functionality lands here. **Split rule:** anything that needs a creature body or creature state goes in the motor layer; anything that needs only plain values plus maps goes in the environment layer. **`PassabilityProfile`** is built by **creature-entity** from traits (live radius, size, slope variant, CLIMB / SWIM bits), using Layer 1's size → class lookup. Names (`NavRouter`, `NavigationMaps`) are proposals. | Header, §2 entry, §2.4 migration note, §5.1 migration cost, §5.6 H4, §5.8 home, §6, §6.2, §8 Phases 0–4 (content + owners), §8 docs to sync. Resolves the open Phase 3 ownership left by D8. |

### 6.2 Code ownership layers (D10)

| | Layer 1: navigation maps service | Layer 2: creature-facing path service |
|---|---|---|
| Path | `environment/navigation/` (new; created in Phase 1) | `creature/motor/` |
| Owner (routing) | environment-world | creature-motor |
| Provisional name | `NavigationMaps` (proposal) | `NavRouter` (proposal) |
| Owns | Bake (from `main_3d.gd`), tiling, class × slope-variant maps, explicit obstacle carving, ledge detector + links, sparse pair baking, per-map / per-tile readiness, tile rebakes, size → class lookup against the config class table | Single M5 entry point for motor call sites; profile → Layer-1 query translation; `RoutePlausibilityScan`; Phase 4 local layer; future per-creature slope cost / limits; stuck watchdog / region blacklist; link-traversal reaction hand-off to the motor |
| Inputs | Plain values: class id, variant id, layer mask, points | A creature's `PassabilityProfile`, body and state |
| Consumers | Layer 2; non-motor consumers (spawn placement, AI); headless fixtures | Motor call sites (§2.4) |

**Split rule:** needs a creature body or creature state → Layer 2; needs only plain values plus maps → Layer 1. `PassabilityProfile` is built by creature-entity from traits, using Layer 1's size → class lookup. `main_3d.gd` (app-shell) keeps only the bake kick-off and the handle hand-off.

---

## 7. Acceptance criteria and success metrics

**Metrics apply to live runs as well as headless ones.** Pre-2026-09-25 live evidence does not count (§3.3). Numeric targets marked *(tune)* are proposals for the user to accept or change.

- [ ] **Gap trap:** the (75,30) / (65,20) headless scenario wedges the wolf in **0 of ≥ 30** seeded runs *(tune)*. It was 9/17 before.
- [ ] **Static-route agreement:** for static obstacles, the fraction of a creature's path queries that its own route scan truncates is ≤ 2% *(tune)*. New telemetry counter `scan_truncated_static` per creature. A high value means the pathing truth and the enforcement truth disagree. *(Phase 0 code landed 2026-10-05: `NavRouter.scan_truncated_static` / `path_queries` / `scan_truncated_static_ratio()` / `telemetry_snapshot()`, stack `get_nav_telemetry()`, debug snapshot keys `nav_path_queries` / `nav_scan_truncated_static`, explore tick log suffix ` nst=<truncs>/<queries>` printed only when truncs > 0. The counter increments once per blocked route scan. Headless test pending; the ≤ 2% threshold is not yet measured live.)*
- [ ] **Erosion tolerance:** for each creature, the extra erosion versus its own radius is ≤ the class tolerance `R_k − r` *(Q2 sets the bound)*. Measure by sampling points that are capsule-clear at radius r and checking whether that creature's map covers them.
- [ ] **Food access:** each `solid_shrub_3d` has a navigable point for the rabbit's class within the rabbit's effective eat reach (size-scaled eat range, CREATURE_BODY_DIMENSIONS B29: eater reach + target radius, XZ distance; rabbit→plant ≈ 1.275; was B28 reach + `eat_range_bonus_fraction` × length + radius ≈ 1.7, and before that `eat_action_max_distance` + radius bonus, decision 26).
- [ ] **Decision-44 pocket:** the rabbit's navigable interior width is within one voxel of `21.9 − 2 × R_rabbit_class`.
- [ ] **C1 compare:** in the c1 smoke and a new open-shrub variant, the straight-vs-rotated reach compare produces non-tied reach at least once in live play (telemetry).
- [ ] **Dynamic latency:** from a crush / regrowth / hull swap event to every affected class map answering with the new geometry ≤ **T_dyn** (Q3 sets it).
- [ ] **Size change:** a creature whose radius crosses a class boundary queries the new class within one consideration tick. No `MOTOR_INVARIANT` silent stall is attributable to the switch (headless test).
- [ ] **Budget:** total navigation time per physics frame ≤ **B_nav** ms at **N** creatures on the target hardware (Q5 sets N, hardware and B_nav). Bake time per class and memory per class are recorded.
- [ ] **Readiness:** `is_navigation_ready()` is true only when **every** class map passes the closest-point check. A 0-polygon class map fails loudly and does not report ready.
- [ ] **Fixtures:** `tests/motor_path_fixture.gd` builds single-class (default, unchanged behaviour) **and** multi-class layouts synchronously. The full suite stays green.
- [ ] **Route scan start-overlap:** `RoutePlausibilityScan` reports a start-overlap as blocked (or escaping, per §8e), matching `ShelterEnclosureProbe` (decision 33). *(Code landed 2026-10-05, §2.3; headless test pending, so unticked.)*
- [ ] **Tile-ready bake (D4):** Phase 1 class maps are baked per tile. A synthetic change rebakes only the covering tile(s) on the affected class maps, and paths cross tile seams without gaps.
- [ ] **Stale-open window (D4):** after a synthetic regrowth or hull swap, and before the rebake lands, no creature wedges. The shape-cast (and the local layer when ON) covers the window. Regrowth rebakes are queued ahead of crush rebakes.
- [ ] **Local layer OFF (D3):** with `navigation.local_refinement.enabled = false`, the gap-trap and erosion scenarios complete **without** getting stuck, taking the class-quantised detour.
- [ ] **Local layer ON (D3):** with the layer enabled, the same scenarios take the squeeze. Per-frame query count and ms stay within the configured budget. Telemetry reports upgrades accepted.
- [ ] **Baseline slope agreement (D8):** every terrain sample whose slope is ≤ `floor_max_angle` (and that is not inside an obstacle footprint) is covered by its class map, measured headless. No disconnected slope fragments from a step-limit / cell-size mismatch. *(Baseline measured 2026-10-05 for the current single bake, §2.1: interior coverage 0–30° 97–100%, 30–35° 91%, 35–40° 0%, so the box stays unticked until Phase 1 fixes the mismatch.)*
- [ ] **Obstacle carving decoupled from slope (D8):** after explicit obstacle removal replaces slope / climb-based carving, no class map has polygons on obstacle tops or sides (boulders, solid shrubs, cliffs, playfield edge), measured headless.
- [ ] **Sparse baking (D8):** the bake builds exactly the (size class, slope variant) pairs occupied by the world's roster, and no others (log + headless check).

---

## 8. Phased plan sketch (ordered; slices not yet approved)

| Phase | Content | Gated on | Owner (routing) |
|---|---|---|---|
| **0 — Seam + hygiene** | **Status 2026-10-05 (code verified): (a), (b), (c), (d), (e), (g) done in the working tree; (f) pending test-harness (headless tests not yet written; do not treat the §7 boxes as met).** (a) done: `creature/capabilities/passability_profile.gd` (`radius`, `height`, `creature_size`, `max_climb` = `floor_snap_length` when > 0 else `DEFAULT_MAX_CLIMB` 0.15, `max_slope` = `floor_max_angle` (50° = 0.873 rad), `weight` default 1.0 with no definition field today, `capabilities` bits `CAP_CLIMB` / `CAP_SWIM` reserved and unused, `size_class_key()` = `&"default"` until Phase 1), cached by `CreatureKinematicBody3D.get_passability_profile()`. (b) done: `NavRouter` (`class_name`, per-creature instance): `for_body` / `for_map` / `coerce` / `from_ctx`, `path(profile, from, to)` -> `{points, reachable, link_segments}` (`link_segments` always empty until climb links exist), `closest_point`, `map_for`, `is_ready`, `has_map`, `query_origin`, `navigation_layers_for(profile)` as the single mask place (`DEFAULT_QUERY_LAYERS` = `NAV_LAYER_WALK` 1; CLIMB bit 2 added only when the profile has `CAP_CLIMB`; SWIM bit 4 reserved), backed by the existing `main.get_navigation_map_rid()` (no `main_3d.gd` change). (c) done: §2.4 migrated. (d) done: route-scan start-overlap (§2.3). (e) done: `scan_truncated_static` telemetry (§7). (g) done: `tools/measure_terrain_slope.gd` ran (§2.1, §11); live rabbit radius recorded. **Open decision for Phase 1:** `PassabilityProfile.max_climb` (0.35 from `floor_snap_length`) vs the bake's `agent_max_climb` 0.15 (§2.1). Original scope text follows. (a) `PassabilityProfile` per creature: live radius, height, max_climb, max_slope, weight, capability bits. All fields are **derived** (class defaults + future stat / skill / trait modifiers), never hard-coded at call sites (D6). Capability bits for **climb** and **swim** are reserved now, unused (D6), and a **CLIMB navigation-layer bit** is reserved for links (D8). (b) **`NavRouter` (Layer 2, `creature/motor/`, D10; name is a proposal)**: `path(profile, from, to)`, `closest_point(profile, p)`, `map_for(profile)`, `is_ready()`, backed by the **current single map** through a thin `main_3d.gd` accessor (no behaviour change). The Layer-1 maps service (provisionally `NavigationMaps`, `environment/navigation/`, also a proposal) doesn't exist yet in Phase 0. The router computes the query's `navigation_layers` mask from the profile at query time, so overlays can be added later without changing call sites (D6 / D7). Path results expose which segments cross off-mesh links (D8.5), unused until climb links exist. (c) Migrate every §2.4 call site onto it. (d) Route-scan start-overlap fix. (e) `scan_truncated_static` telemetry. (f) Promote the gap-trap scenario to a headless regression test (expected red until Phase 1). (g) Record the effective `agent_max_slope` (engine default) and run the terrain slope measurement (§11; confirms or denies the suspected ~31° step-limit cap vs `floor_max_angle` 50°), plus the live rabbit radius. | user approval only | creature-motor (router skeleton over the current single map + call-site migration); creature-entity (`PassabilityProfile`); app-shell (thin `main_3d.gd` accessor only); test-harness |
| **1 — Tiled class maps (A, D1 / D4)** | **Extract the bake** out of `main_3d.gd` (`_bake_playfield_navmesh`, readiness, `get_navigation_map_rid`) into the new Layer-1 maps service in `environment/navigation/` (D10); `main_3d.gd` keeps only the bake kick-off and the handle hand-off. Layer 1 owns the size → class lookup against the config class table. The router moves onto Layer-1 handles. K classes from config: K = 3 for now (small / medium / large, D9), large unbaked until a large species is in the roster (D8.4); boundaries per Q2 remainder, Q10, Q12. **Tiled from the start** (D4): per-class regions per tile via `filter_baking_aabb` + `border_size` (G7), with tile size set by G10 measurements. Parse once and bake per class and tile async (G8). Obstacle inclusion per class by the D5 rules (ghost hulls included per Q6). Per-class height; per-class baseline climb / slope **matched to physics** (capsule geometry + `floor_max_angle`) so navmesh and physics agree (D6 / D8), including fixing the step-limit / cell-size mismatch so baseline slopes stay connected (G11). **Explicit obstacle removal** (projected obstructions, G8, under the D5 hull rules), decoupled from slope / climb thresholds (D8). **Sparse baking:** only occupied (size class, slope variant) pairs (D8.4). At bake kick-off `main_3d.gd` gathers the spawn roster and hands Layer 1 the required sizes / traits as plain values (e.g. a list of radii / sizes plus slope-variant needs); Layer 1 maps them to occupied (class, variant) pairs via its size → class lookup. This replaces today's precursor `_duel_max_capsule_radius()`, which is retired (D10); in Phase 1 the variant is always the baseline. Crush capability as a class property (D6). Bake-time "closed for class, open for smaller" gap flags (feeds §5.8 trigger gating). Readiness across all maps and tiles. Fixture multi-class builder. Class selection with hysteresis, **derived at runtime** from the config class table (D7); no authored class or layer on creatures, species or templates. | Q2 remainder, Q6, Q12 | environment-world (extract bake to `environment/navigation/`, tiles, classes); app-shell (config class table, `main_3d.gd` hand-off); creature-motor (router onto Layer 1); test-harness |
| **2 — Dynamics** | Local tile rebake on crush / regrowth / hull swap on the class maps that carve the object (D4). Regrowth and hull swap get priority. Latency telemetry against T_dyn. Crushable representation per Q8 (D4 / D6 direction: cost area for crush-capable classes, carve for the rest). | Q3, Q8 | environment-world (Layer-1 tile rebakes); assets-pack (shrub change events); test-harness |
| **3 — Capabilities** | **Steep slope (D8):** slope-variant maps, one bake per occupied (size class, steep variant) pair; the router picks the variant from the profile. `floor_max_angle` is per body, so physics enforces the matching slope, set from the profile. **Climbing (D8):** off-mesh links (G12) with the CLIMB layer bit, generated per tile at bake time by a ledge detector (height above the walking step limit, within climbable height), added to existing maps; boulder tops become link-joined islands. The router reports link segments; climb **movement** is out of scope. Swim as a navigation-layer overlay (H2) or per-query rule, using the bit reserved in Phase 0 (deferred, D6). Compressibility (deferred, D6): out of class maps; possibly local layer `r × factor` in the window, or live enforcement only. **"Slower above X"** is motor-side speed from the floor normal (D8.6); pathing slope cost needs a custom polygon search (deferred, behind `NavRouter`, Layer 2). Fall risk is motor / physics, not pathing. Ledge detector, links, steep variants and link-crossing info in query results are Layer 1; the link reaction (climb mode) and "slower above X" are Layer 2 (D10). | trait design docs | environment-world (ledge detector, links, steep variants, link-crossing in query results); creature-motor (link reaction / climb mode, slower-above-X); creature-entity (profile bits); app-shell (config); test-harness |
| **4 — Local exact-refinement layer (optional, D2 / D3)** | §5.8: windowed inflated-obstacle visibility graph inside the Layer-2 `NavRouter` (`creature/motor/`, D10). Master switch, trigger gating, per-frame budget + time-sliced queue, window, cache, priority/LOD, species opt-out. Config section `navigation` in `game_config.json`. Telemetry. Gap-trap and erosion tests both OFF and ON. **Only adds, never fixes.** | Phase 0–1 metrics (quantisation cost observed); Q9 for window 2D validity | creature-motor (local layer in the router); app-shell (config keys); test-harness |

Option D (grid backend) and LCT (§5.3) are no longer scheduled phases. They stay as alternatives if Phase 0–4 metrics show class quantisation plus the local layer is inadequate.

**Docs to sync when phases ship (flag for `project-docs`):** [ENVIRONMENT_MODEL_PLAN §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) (bake sources / erosion / tiling), `game_config.json` `navigation` section (Phase 4 keys; wherever config keys are documented), [PHYSICS_SQUEEZE decision 22](PHYSICS_SQUEEZE.md) (if Q6 reverses "never bake the ghost layer"), [CREATURE_MOVEMENT_V3 §3.1](CREATURE_MOVEMENT_V3.md) (substep via router), [PLANT_ECOLOGY_PLAN `crush_weight` row](PLANT_ECOLOGY_PLAN.md). **When `environment/navigation/` is created (Phase 1, D10):** register it in the [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) topic tables and update [ENVIRONMENT_MODEL_PLAN §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md), because bake ownership moves from `main_3d.gd` to the Layer-1 maps service.

### 8.1 Evaluation matrix

Scores: ✔ handles well · ~ partial / with work · ✘ does not handle. Costs are relative.

| Concern | A class maps | B fine + layers | C annotated navmesh | D grid clearance | E status quo+ | H1 (A → D seam; superseded) | **H4 (tiled A + local layer; chosen)** |
|---|---|---|---|---|---|---|---|
| Erosion (M2) | ✔ within class tolerance | ~ class bands, fragile | ✔ | ✔ exact to cell | ✘ one side always loses | ✔ | ✔ class tolerance; exact in window when ON |
| Gap trap (M3) | ✔ if Q6 = bake hulls | ~ | ✔ if hulls in mesh | ✔ | ✘ retry loops | ✔ | ✔ (D5 inclusion) |
| Continuous size | ~ quantized | ~ quantized | ✔ | ✔ | ✘ | ~ → ✔ | ~ globally; ✔ in window |
| Runtime size change (M4) | ✔ map switch + hysteresis | ✔ mask switch | ✔ | ✔ free | ~ | ✔ | ✔ map switch; local layer uses live r |
| Crush | ~ tile rebake × K; pre-crush per-creature weight awkward | ~ | ~ rebake + re-annotate | ✔ local brushfire, per-creature weight | ~ reactive | ~ → ✔ | ~ tile rebake on carving classes only (D4); crush as class property (D6) |
| Squeeze / compressibility | ✘ / ~ extra classes | ~ | ~ | ✔ `r × factor` at a cost | ~ route scan only | ~ → ✔ | ~ possible in window (`r × factor`) |
| Climbing / slope trait | ~ per class, overlays | ~ climb as overlay; slope bands leave seam gaps (D8) | ~ | ✔ per-query rule | ✘ | ~ → ✔ | ~ steep slope: sparse slope-variant maps; climbing: CLIMB links on existing maps (D8) |
| Height / overhang | ✔ per class | ~ | ✘ single height | ~ 2.5D, no overhangs | ✘ | ✔ | ✔ per class (window is 2D) |
| Dynamic obstacles latency | ~ tile rebake (G10) | ✘ re-diff | ✘ | ✔ ~frame | ~ | ~ → ✔ | ~ tile rebake; live hulls in window |
| C1 compare meaningful | ✔ | ~ | ✔ | ✔ | ✘ | ✔ | ✔ |
| Scales with world size | ✔ tiled | ~ | ✔ | ✘ grid area | ✔ | ~ | ✔ local cost independent of world |
| Test fixtures | ~ multi-class builder | ✘ complex | ✘ | ~ new fixture type | ✔ unchanged | ~ | ~ multi-class + OFF/ON runs |
| Engine-native | ✔ | ✔ + script geometry | ✘ custom A* | ✘ (✔ if H3) | ✔ | ✔ now | ✔ (local layer in script; perf to verify) |
| C++ likely needed | no | no | yes | likely (not for H3) | no | only in Phase 4 | no (unless budget demands) |
| Implementation cost | M | H | VH | H | L | M now, H later | M now, M later |
| Migration cost vs current code | M (bake + seam) | H | VH | H (seam absorbs call sites) | L | M, then local | M, then local |
| Main risk | bake time × K; map count growth with traits | seam connectivity | clearance correctness | perf, 2.5D limit | root cause untouched | two backends to maintain until D lands | local-layer budget blowout; OFF path rotting untested |

---

## 9. Open questions (answer in place)

Each question gives the context, options and consequences, then one `<<Question>>` marker to answer. The backbone is decided (§6.1). Q1 is answered (D6, 2026-10-01). Q2's class count is answered (D9, 2026-10-01); its boundaries remain open. Q2–Q5 now tune it rather than choose it. Q6–Q9 are narrower. Q10–Q12 were added 2026-09-30; Q10 and Q12 are answered (2026-10-01, in CREATURE_BODY_DIMENSIONS B17 / §4.10); Q11 is open.

### Q1 — Which passability dimensions vary per creature?

| Dimension | Status today | If "varies per creature" | If "fixed / not now" |
|---|---|---|---|
| Radius | varies (rabbit … wolf 7.03) | required; drives the whole plan | n/a |
| Height / overhang clearance | bake uses 2.1 m for all; no overhang props exist today | per-class `agent_height` (free in A); D needs per-cell ceiling height | keep one height; overhang props must not be authored |
| Slope / step limit (incl. climbing trait) | 0.15 m climb for all; slope unrecorded | per class (A) or per query (D); a climbing **trait** needs overlays (H2) or D | one limit; climbing waits for its own design |
| Crush weight | not implemented | pathing must know "I can crush this": region cost + layer bit (A) or per-query rule (D) | crushables carve; crushing is discovered on contact |
| Squeeze / compressibility (Mode A `fit_size`) | `EnvironmentCellData` supports it, zero callers | extra reduced-radius classes (A, costly) or `r × factor` (D, cheap) | exact radius only |
| Swim / terrain kind | not implemented | capability overlay (layer bit) or grid flag | n/a |

**Answer (user, 2026-10-01; D6–D7):**

| Dimension | Outcome |
|---|---|
| Radius | Varies; drives the class maps (D1). |
| Height / overhang | Per-class `agent_height` = class max height (free under A). Caveat: the wolf's enclosing capsule is 15.3 m tall (Q10). |
| Slope / step | Class baseline **matches physics** (capsule geometry + `floor_max_angle`, step limit consistent with `cell_size`), so navmesh and physics agree (D6 / D8). `PassabilityProfile.max_slope` / `max_climb` are derived fields; `floor_max_angle` is per body, so physics can enforce per creature. Steeper-slope walkers use **slope-variant maps**, sparse per occupied (class, variant) pair (D8). "Slower above X" is motor-side cost from the floor normal, not passability (D8). Fall risk is motor / physics, not pathing. |
| Climbing trait | Structure decided (D8): **off-mesh links** with a reserved CLIMB navigation-layer bit, generated by a bake-time ledge detector on existing maps; the router reports link traversal. Climb movement deferred. Capability bit reserved in `PassabilityProfile` (Phase 0). |
| Crush | Tied to size for now: a **class property** (each class crushes a given crush band or not). No weight bands × classes, because cost and layer bits are per region (§5.1). Revisit trigger: a heavy-small or light-large creature. |
| Squeeze | The row conflated two things. `fit_size` obstacle entry is already per class via D5 (no new work). Compressibility is deferred and stays out of class maps (later: local layer `r × factor` in the window, or live enforcement only). |
| Swim | Deferred. Capability bit reserved in `PassabilityProfile` (Phase 0). |

Class membership and any layer mask are derived at runtime from config, never authored per creature or species (D7).

### Q2 — Size model: few fixed classes or continuous sizes?

- **Few fixed classes (2–3):** A is cheap. Erosion error per creature is `R_k − r`. Example with small ≤ 2.5 m and large ≤ 7.25 m: a 3 m creature would lose ~4.25 m per side, so class boundaries must follow the roster. Growth / magic crosses boundaries in steps, with hysteresis.
- **More classes (4–8):** bounded error, but K× bake time and memory, and K maps to keep ready and in sync.
- **Continuous (any radius, growth mid-life):** only C or D give exact results. A can only approximate with many classes.
- **Rounding policy:** conservative round-up (never routes a creature through a gap it can't fit; may deny gaps near the class edge) vs nearest (smaller loss; relies on the route scan to catch misfits). This plan assumes round-up.

**Answer (user, 2026-09-30, partial; D1):** fixed classes, each with its own navmesh. A creature uses the **smallest class that fits**, with **conservative round-up**. Continuous exactness is **not** required globally; the optional local layer (§5.8) supplies exactness near the creature where it pays off. Industry practice is 2–4 classes.

**Answer (user, 2026-10-01, partial; D9):** **K = 3 size classes for now.**

| Class | Descriptive members (design discussion only) | Notes |
|---|---|---|
| small | rabbit, fox | Rabbit archetype 0.6 declared radius (live unmeasured); fox has no archetype, live 2.343 (source unverified, §3.1). |
| medium | wolf | Wolf archetype 7.0 declared, live ≈ 7.03. |
| large | mastodon | Reserved. No archetype exists; not baked while no large species is in the roster (D8.4). |

Membership is **derived at runtime** from size against the config class table (D7); the species names above are not authored data. Adding a class later is config-only.

*Provisional illustration only (not decided):* `R_small` ≥ 2.5 m (fox live 2.343 snapped up to a 0.25 m voxel), `R_medium` = 7.25 m (wolf live 7.03 snapped up). Under conservative round-up, a rabbit at its declared 0.6 m would then lose up to ~1.9 m per side to small-class erosion. That is the kind of tolerance the remaining question must bound.

<<Question: Q2 (remainder) — Where are the class boundaries (`R_k` for small / medium / large) relative to the current roster, and what erosion tolerance per creature (`R_k − r`) is acceptable before the local layer is expected to cover the difference? Q10 (body radius, B1 / B5) and Q12 (B17) are answered in CREATURE_BODY_DIMENSIONS; set the boundaries after the B20 dimensions land. Live radii are now measured (rabbit 0.385, fox 0.22, wolf 0.715; §2.1, 2026-10-05), so the boundaries can be derived from them.>>

### Q3 — World dynamism: what changes at runtime, how often, and how fast must paths react?

Candidates: crush (an obstacle removed, possibly permanent), regrowth (an obstacle restored), depletion hull swap (`bush_food_3d.gd`, shape change on ready ↔ depleted; not rebaked today), future terrain changes (digging, flooding), and creatures as obstacles (out of scope).

| Answer | Consequence |
|---|---|
| Rare (a few per minute), seconds of latency OK | A with tiled regions and async rebakes is enough |
| Frequent (many per minute), ≤ 1 s latency | A needs small tiles × K classes, and G10 must be measured first; D becomes attractive |
| Near-instant (same or next frame) | D (local brushfire), or keep the shape-cast as the only enforcement for dynamic things and accept stale routes |
| Hull swap "doesn't matter for pathing" | no rebake on depletion; the per-step gate + escape hatch (§8e) covers it |

**Note (2026-09-30, D4):** tiling is in Phase 1 regardless of this answer, so the answer only sets tile size, rebake priority and T_dyn. Staleness is asymmetric: crush is conservative while stale, but regrowth and hull swaps are optimistic while stale, so they are the latency that matters.

<<Question: Q3 — Which obstacles change at runtime (crush, regrowth, depletion hull swap, terrain edits, other), roughly how often per minute in a busy scene, and what is the maximum acceptable time (T_dyn) from the change to paths reflecting it? Can the depletion hull swap be ignored by pathing?>>

### Q4 — Where does per-creature passability truth live?

- **(a) Status quo:** navmesh coarse and species-blind; per-creature shape-cast is the truth (decision 22). Consequence: the failures in §3 persist, and every new trait adds repair heuristics (Option E).
- **(b) Pathing holds static truth per class; shape-cast is the residual and final gate (A / H4).** Decision 22's route scan stays but should rarely truncate (metric in §7). This amends decision 22's premise that the navmesh is species-blind.
- **(c) Pathing holds full per-creature truth, static and dynamic (D).** The shape-cast is only the physical contact gate.

**Note (2026-09-30):** D1 and D3 imply (b). The class navmesh plus shape-cast enforcement is the correctness baseline, and the local layer only upgrades routes. Navmesh-constrained movement (§5.7) would be a variant of (b) that moves static enforcement onto the navmesh. Left open for explicit confirmation.

<<Question: Q4 — Keep the navmesh as species-blind coarse routing with per-creature truth enforced live by shape-casts (status quo), move static per-creature truth into pathing with shape-casts as the residual/final gate (Option A/H4), or move all per-creature truth into pathing (Option D)?>>

### Q5 — Performance budget and language

The facts that decide A vs D: bake cost × K (G10), per-query A* cost on ~163k grid cells, and map sync cost. **Note (2026-09-30):** A is chosen (D1), so Q5 now sets the Phase 1 tile / bake budget and the local layer's per-frame budget (§5.8). It also decides whether the LCT fallback (§5.3) or a C++ local layer is available if needed. The agent role includes C++. A GDExtension adds a build toolchain, CI and a platform matrix, and needs a new specialist routing row.

<<Question: Q5 — Target creature count on screen (now, and the design ceiling), target hardware (min-spec CPU), frame budget for navigation in ms, and whether C++/GDExtension is acceptable for a pathfinding backend (yes now / yes later if metrics demand it / never)?>>

### Q6 — Bake ghost-layer hulls into the per-class maps?

[Decision 22](PHYSICS_SQUEEZE.md) / §8a rejected baking the ghost layer "because a single shared bake can't express a per-species fact". With per-class maps that reason no longer applies. Hulls are solid for everyone (§2.2), and erosion by `R_k` yields exactly the class's passable gaps. Physics would still not enforce them (they stay out of movement masks), so decision 16's query enforcement is untouched.
- **Yes:** fixes the gap trap and the C1 blindness. Amends decision 22's wording (not its intent).
- **No:** A fixes erosion only. The gap trap needs a separate mechanism: an open-shrub region with high cost, or D.

**Implication recorded (2026-09-30, D5):** the class-map direction implies baking hulls **per class according to the `passible` / `fit_size` rules**: Mode A carves unless the class fits, and Mode B is a cost area, never carved. Hulls with no valid `fit_size` (today's open shrubs and boulders) carve every class. The formal answer is left to the user. Q11 (soft vegetation) could turn open shrubs into Mode B cost areas instead.

<<Question: Q6 — With per-class maps, may ghost-layer hulls (open shrubs, later boulders) be baked into every class map's source geometry while staying off every movement mask? This amends decision 22's "never bake the ghost layer" wording.>>

### Q7 — Boulders: migrate to the ghost layer (decisions 16/17) or keep them on layer 1?

- **Keep layer 1:** the engine enforces boulders (robust against motor bugs) and they carve every class map. There is no pathing difference under A.
- **Migrate:** consistent with decision 16 (only terrain engine-enforced). Under A they carve anyway (if Q6 = yes). The risk: boulder blocking then depends on the motor gate (the escape hatch, the start-overlap bug) instead of physics.

<<Question: Q7 — Do boulders stay on layer 1 (engine-enforced) or migrate to the ghost layer as decisions 16/17 planned? Under Option A with Q6 = yes, pathing is the same either way. The difference is only which layer enforces contact.>>

### Q8 — Crushable shrubs in pathing

- **(a) Keep carving until crushed**, then rebake the tile. Pathing is pessimistic, so heavy creatures detour around things they could flatten.
- **(b) Separate cost region + CRUSH layer bit:** creatures above `crush_weight` include the bit and pay `travel_cost`. Per-shrub weight thresholds need per-threshold bits, so use a few weight bands.
- **(c) Don't carve at all:** the per-step gate stops light creatures, and the route scan must learn about layer 1. This reintroduces gap-trap risk for light creatures.

**Direction (2026-09-30, D4; amended 2026-10-01, D6):** a per-class mix of (a) and (b). Crush capability is a **class property** (D6): crushables carve for classes that can't crush them and are cost areas for crush-capable classes, so a crush rebakes only the maps that carved it. No separate weight bands × classes and no per-creature CRUSH layer bit inside a class map. Revisit if a heavy-small or light-large creature appears.

<<Question: Q8 — With crush as a class property (D6), how many distinct crush bands (shrub `crush_weight` tiers) are expected, and which classes crush which band? For a crush-capable class, is a crushable a `travel_cost` area (cost region) or simply not carved?>>

### Q9 — Terrain topology: is the playfield single-level (2.5D)?

Option D and H3 assume one walkable surface per XZ cell. Bridges, caves, overhangs or multi-level terrain break that and favour navmesh-based options.

**Note (2026-09-30):** Q9 now also decides whether **LCT (§5.3) stays viable** as the fallback for exact per-radius pathing. The local layer's visibility graph (§5.8) is 2D as well. On multi-level terrain its window would need per-level filtering, or it would have to switch off where levels overlap.

<<Question: Q9 — Will any playfield have multi-level walkable geometry (bridges, caves, ledges above walkable ground, overhangs creatures walk under)? If yes, grid backends (D/H3) and the LCT fallback need a layered structure or are ruled out, and the local layer needs per-level filtering.>>

### Q10 — Path radius: enclosing capsule or body width? (answered 2026-10-01)

> **Answered 2026-10-01** in [CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) §4.10 and decision B17 (with B1, B5, B16). Yes, the 7.0 radius came from half the model's length. Pathing uses the width-based **body radius** (width / 2 × 1.10); there is one radius, the resized movement capsule, and no separate `path_radius`. With the B20 design-intent dimensions the wolf radius becomes about 0.72. The question text below is kept for context.

The wolf's `collision_capsule_radius` is 7.0 (live ≈ 7.03), its capsule height is 15.3 and its `creature_size` is 6.0 (`creature/species/wolf_archetype.tres` lines 19-21, verified 2026-09-30). A 7 m radius is wider than the whole body's longest dimension, which suggests the capsule was sized to **enclose** the model. Industry practice is to set the path radius to about **half the shoulder width**. A width-based path radius would shrink erosion for large creatures, might reduce the number of classes (Q2), and could remove some gap traps outright. It could be a separate `path_radius` used only by pathing, with the collision capsule left alone. The alternative is to resize the capsule itself.

Question (answered, see the note above): was the wolf's collision_capsule_radius of 7.0 chosen to enclose the model, and should pathing use a width-based radius (about half shoulder width), either as a separate path_radius or by resizing the capsule?

### Q11 — Soft vegetation for large creatures?

Many games make foliage costly but passable for large animals instead of a hard blocker. For open shrubs this would remove the gap trap entirely for large classes: they walk through at a cost, and only small classes route around the hull, or through it if it fits (Mode A). This maps onto **Mode B** (`passible == true` + `movement_impact` + `fit_size`, D5): a cost area for classes ≥ `fit_size`, free for smaller ones. It changes decision 16's premise that open-shrub hulls are solid for everyone (§2.2).

<<Question: Q11 — What is the design intent for open shrubs vs large creatures: a hard blocker for everyone (today), or costly-but-passable for large creatures (Mode B style)? If passable, which obstacle kinds qualify (open shrubs only, or other vegetation too)?>>

### Q12 — `fit_size` vs class radius: which is canonical? (answered 2026-10-01)

> **Answered 2026-10-01** in [CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) decision B17 (BQ12, §4.10): option 3. Each class declares both a max body radius and a max `creature_size`, and a creature's class is the smallest class satisfying both. `creature_size` is `max(L, W, H)` on live dimensions (B11). The numeric class boundaries stay open (Q2 remainder), to be set only after the B20 dimensions land. The question text below is kept for context.

`fit_size` compares against `creature_size`, the **longest body dimension** ([CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)). Class maps are keyed by **capsule radius** (`R_k`). The D5 rules need each class to define both a max radius (for erosion) and a max `creature_size` (for `fit_size` compares), with an explicit mapping. For the wolf the two diverge sharply: radius 7.0 against `creature_size` 6.0 (Q10). If they are defined independently, a creature could fall into different classes by radius and by size.

**Constraint (2026-10-01, D7):** whichever measure Q12 makes canonical, class membership is **computed at runtime** from the creature's live size / traits against the config class table, never stored as authored data on creatures, species `.tres` or templates.

Question (answered, see the note above): class definitions need an explicit size↔radius mapping. Options were capsule (or path) radius canonical; `creature_size` canonical; or both declared per class, with a creature's class the smallest class that satisfies both. Chosen: the last (B17).

---

## 10. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Bake time × K classes stalls startup or rebakes | Measure G10 in Phase 0. Async bakes. Parse once (G8). Tile regions from Phase 1 (G7, D4). |
| Tiles retrofitted late onto monolithic bakes (expensive rework when crush lands) | Phase 1 is tiled from the start (D4). Crush semantics stay out of scope; only the structure is ready. |
| Stale-open window after regrowth / hull swap routes creatures into physics blocks | Regrowth and hull-swap rebakes get priority over crush (D4). The shape-cast route scan and per-step gate cover the window. The local layer reads live hulls when ON. |
| Local-layer budget blowout (many creatures × dense obstacle windows) | Master switch, per-frame query + ms budget with a time-sliced queue, trigger gating, cache, priority/LOD, species opt-out (§5.8). Telemetry on queries/frame and ms. |
| Fallback path rots untested because the local layer usually covers it | "Only adds, never fixes" (D3). Gap-trap and erosion tests run **both OFF and ON** (§7, §11). The OFF run must never get stuck. |
| Map count explodes with size × capability | Capabilities as layer overlays (H2) or links (climbing, D8), not maps. Revisit D if the overlay count grows. |
| Map count grows K classes × V slope variants (D8; illustrative 8 × 2 = 16; today K = 3, D9) | Sparse baking of occupied pairs only (D8.4). Keep K small (Q2). Measure bake time per map (G10). |
| Climb-link generation quality (missed ledges, links onto unreachable tops, link spam on rough terrain) | Ledge detector thresholds tied to the walking step limit and climbable height. Headless fixture with a boulder and a cliff. Link traversal is reported by the router, so bad links show up in telemetry. |
| Class switching flickers for a creature near a boundary | Hysteresis band. Switch only on consideration ticks (mirrors §8d). |
| One class map empty or not synced; silent fallback like decision 46 B | Per-map readiness. A 0-polygon class map fails loudly. A headless test per class. |
| The route scan masks a class-map bug | `scan_truncated_static` telemetry with an alarm threshold (§7). |
| Earlier tuning rested on an empty navmesh (§3.3) | Re-run the decision-44, c1 and c44 smokes after Phase 1. Treat earlier live evidence as void. |
| Seam migration regresses motor behaviour | Phase 0 is behaviour-neutral by construction (same single map). Full suite A/B before and after. |
| GDExtension toolchain burden (LCT fallback or C++ local layer) | Only if Q5 allows and metrics demand it. Phase 4 is designed to be script-feasible first. |

---

## 11. Testing / verification

**Automated (proposed):**
- Gap-trap scenario as a seeded multi-run headless test (§7 target).
- Per-class bake produces polygons; ghost hulls carve only where the class radius can't fit (two-class fixture: a gap between two hulls wider than 2·R_small and narrower than 2·R_large).
- Class selection with hysteresis on a runtime radius change.
- Route-scan start-overlap regression (sibling of the decision 33 shelter probe test). Code landed 2026-10-05; headless test pending (test-harness).
- Tile rebake latency after a synthetic crush (Phase 2), and the stale-open window after a synthetic regrowth / hull swap (no wedge before the rebake lands).
- Tile-seam continuity: a path across a tile boundary on every class map (Phase 1).
- Per-class inclusion (D5): a Mode A obstacle with `fit_size` between two class sizes carves the larger class only. A Mode B obstacle carves no class and is a cost area for classes ≥ `fit_size`.
- Local layer (Phase 4): the gap-trap and erosion scenarios run **OFF** (slower detour, never stuck) and **ON** (takes the squeeze, within budget). Cache invalidation on a synthetic crush / regrowth / hull swap.
- **Terrain slope measurement (D8; RUN 2026-10-05 as `tools/measure_terrain_slope.gd`, results in §2.1; not wired into `tests/run_all.gd`):** a read-only headless script (`godot --path . --headless -s res://tools/measure_terrain_slope.gd`, ~18 s) over the current playfield: a slope histogram of the terrain; per slope bin, whether the current bake covers it (confirms or denies the suspected ~31° step-limit cap, G11); and what happens to boulders, solid shrubs and the playfield edge when `agent_max_slope` / `agent_max_climb` are raised (do obstacle tops / sides become walkable). Feeds §2.1 and Phase 0 (g).
- Baseline slope agreement, obstacle-free tops / sides, and sparse pair baking (§7 D8 items), Phase 1.

**Manual:** re-run the [decision 44 smoke](PHYSICS_SQUEEZE.md#decision-44-live-smoke-test), `spawn_layout_c1_smoke.json` and `spawn_layout_c44_smoke.json` on the new pathing. Add an open-shrub gap-trap layout.

---

## 12. Related docs

- [PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md): decisions 5, 16/17, 22/23, 25, 33, 46 B/E (source of the question this doc answers).
- [ENVIRONMENT_MODEL_PLAN.md §6](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md): layer table and navmesh bake sources (contract to sync).
- [CREATURE_MOVEMENT_V3.md §3 / §3.1](CREATURE_MOVEMENT_V3.md): substep rule and headless fixture.
- [CREATURE_MOVEMENT_V3_CLEANUP.md C1](CREATURE_MOVEMENT_V3_CLEANUP.md#c1--pursuit-contact-geometry-stall-fox): straight-vs-rotated compare.
- [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md): `crush_weight`, `fit_size`, `movement_impact`.
- [ENVIRONMENT_MODEL_PLAN.md property catalog](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) and `environment/environment_cell_data.gd`: `passible` / `fit_size` Mode A / B semantics (D5).
- [CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md): `creature_size` = longest body dimension (Q12).
- [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md): "Shared navmesh bake erodes by the largest creature's radius", "Crushable shrubs vs the navmesh bake", "Climbing as a skill/trait".

---

## 13. Changelog

| Date | Change |
|------|--------|
| 2026-09-30 | Created (design only, status `design`). Captures the evidence (erosion, gap trap 9/17, empty-navmesh history), current bake facts, obstacle/passability inventory, single-map call-site seam, Godot capability notes (unverified against 4.7), options A–E plus hybrids H1–H3, evaluation matrix, acceptance metrics, phased plan, and questions Q1–Q9 for the user. Provisional recommendation: H1 (per-class maps behind a `NavRouter` seam, ghost hulls baked per class, grid backend as the planned escape hatch), pending Q1–Q5. Takes over the per-size navmesh `<<Question>>` from PHYSICS_SQUEEZE decision 46 B. |
| 2026-09-30 | Recorded user decisions D1–D5 (§6.1). D1: tiled per-size-class navmeshes (Option A) are the backbone, with round-up class selection; Q2 partially answered. D2: Phase 4 is now an optional local exact-refinement layer (§5.8), replacing the Option D grid backend, which stays as an alternative. D3: the local layer is switchable and budgeted, and only adds, never fixes (config section `navigation`, telemetry, OFF/ON tests). D4: crush planned structurally, so tiling moves into Phase 1; asymmetric staleness; crush-capable classes treat crushables as cost areas. D5: per-class obstacle inclusion via `passible` / `fit_size`. Added the alternatives analysis (§5.9; TRA* / LCT under §5.3; navmesh-constrained movement as an open option in §5.7; stuck watchdog under §5.5). Recommendation §6 → H4. §7, §8, §8.1 (H4 column, world-size row), §10 and §11 updated. Notes added on Q3–Q6, Q8 and Q9 (Q9 now also gates LCT). New questions Q10 (width-based path radius), Q11 (soft vegetation) and Q12 (size↔radius canonical mapping). |
| 2026-10-01 | Recorded user decisions D6–D7 (§6.1). D6 answers Q1: radius and height per class; slope / climb at a physics-derived class baseline with the door left open for per-creature variability (derived `PassabilityProfile` fields, router-computed layer mask, future slope-band overlays / cost); crush is a class property (no weight bands × classes; revisit trigger noted); climbing trait, swim and compressibility deferred with climb / swim capability bits reserved; "squeeze" split into `fit_size` entry (D5) vs compressibility. D7: class membership and layer masks derived at runtime from the config class table, never authored per creature / species. Updated header, §2.1 slope / climb rows (grep facts; slope still to verify), §5.1 crush / squeeze / climbing bullets, D4 (amended), §8 Phases 0–3, §8.1 crush cell, Q1 (answered), Q8 (direction and question narrowed), Q12 (D7 constraint). |
| 2026-10-01 | Recorded user decision D8 (§6.1): slope / climb baseline matches physics; steep-ground walkers via sparse slope-variant maps per occupied (class, variant) pair; climbing via off-mesh links with a reserved CLIMB navigation-layer bit from a bake-time ledge detector; router reports link traversal; "slower above X" is motor-side cost; obstacle removal made explicit, decoupled from slope / climb. Rejected: "bake at 90° and filter in code", "most permissive member's slope", and slope-band overlay regions (D6 amended). §2.1 now records caller-verified facts (`floor_max_angle` 50° in both kinematic templates, `agent_max_slope` unset → default believed 45°, climb snapped to 0.15 m) and the suspected ~31° effective cap. Added G11–G12, updated §5.1, §5.6 H2, §7 (three items), §8 Phases 0 / 1 / 3, §8.1 slope row, Q1 answer, §10 (two risks), §11 (terrain slope measurement). |
| 2026-10-01 | Recorded user decision D9 (§6.1): Q2 partially answered, K = 3 size classes for now (small: rabbit, fox; medium: wolf; large: mastodon, reserved and unbaked until rostered). Membership stays runtime-derived (D7); species names are descriptive. Boundaries and erosion tolerance remain open (Q2 remainder narrowed; gated on Q10 / Q12); provisional `R_k` illustration recorded. Recorded verified archetype facts (only rabbit and wolf archetypes exist; no fox or mastodon) and corrected §3.1's "fox 0.7" fallback, which has no `.tres` source; added a comment to confirm the source of the fox live radius 2.343. Sourcing note qualified: the 2026-09-30 pass did not re-read code, but specific facts were caller-verified 2026-10-01 and dated in place (also marked the D8 `motor_planner.gd` ~3264 / ~3339 reference). Updated header, §6 (K = 3), D8 and §10 map-count examples, §8 Phase 1, §9 intro. |
| 2026-10-01 | Recorded user decision D10 (§6.1, new §6.2): navigation code ownership is a two-layer split. Layer 1 is a creature-agnostic navigation maps service in `environment/navigation/` (new, Phase 1; environment-world; provisional name `NavigationMaps`). It owns the bake (moved from `main_3d.gd` ~551 / ~605 / ~684, caller-verified), tiles, class × variant maps, obstacle carving, links, readiness, rebakes and the size → class lookup. Layer 2 is the creature-facing `NavRouter` in `creature/motor/` (creature-motor), the M5 entry point holding the route scan, the local layer, per-creature slope logic and the stuck watchdog. creature-entity builds `PassabilityProfile`. Updated header, §2 entry note, §2.4 (migration target; map handle replaced by Layer-1 handles behind the router), §5.1 migration cost, §5.6 H4 and §5.8 (local layer lives in Layer 2), §6, §8 Phase 0 (b) naming and Phase 1 / 3 / 4 content, the §8 owner column for all phases (this resolves the Phase 3 ownership left open by D8), and §8 docs to sync (index + ENVIRONMENT_MODEL_PLAN §6.3.1 when the folder is created). Roster hand-off clarified: `main_3d.gd` passes the roster's sizes / traits to Layer 1 as plain values at bake kick-off, Layer 1 derives the occupied (class, variant) pairs, and `_duel_max_capsule_radius()` is retired. This is folded into the D10 row and §8 Phase 1, with an amendment note on D8 (4). |
| 2026-10-01 | Q10 and Q12: added cross-links. Their design moved to the new draft [CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) (authored L / W / H, width-based body radius, decisions B1–B5); the answers are pending there. No other changes. |
| 2026-10-02 | Q10 and Q12 marked answered (cross-link only). The 2026-10-01 "pending there" notes were stale: the answers were recorded 2026-10-01 in [CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) §4.10 and decision B17 (BQ12; Q10 via B1 / B5 / B16). Removed the two `<<Question>>` markers (Q10, Q12) and updated the Q2-remainder gating wording. Class boundaries (`R_k`, class max `creature_size`) stay open until the B20 dimensions land. |
| 2026-10-05 | **Phase 0 code landed (doc sync; headless tests pending).** `PassabilityProfile` and `NavRouter` added; every §2.4 motor call site migrated (grep-proven: no raw map RID / `map_get_path` / `map_get_closest_point*` in `creature/motor/` outside `nav_router.gd`); route scan start-overlap fixed (`start_overlap` none / escaping / blocked); `scan_truncated_static` + `path_queries` telemetry (router, stack `get_nav_telemetry()`, debug keys, ` nst=` explore log suffix). Capsule-centre fix (CREATURE_BODY_DIMENSIONS §4.8) shipped alongside. Terrain slope measurement run (`tools/measure_terrain_slope.gd`): `agent_max_slope` 45°, step-limit cap confirmed with a soft cutoff ≈ 35° (nominal 30.96°), terrain max 37.4°, mismatch band ≈ 0.3% of the playfield; boulder tops / sides already walkable in the shipped bake; live radii rabbit 0.385 / wolf 0.715 / fox 0.22. Synced §2.1 (measured rows, open `max_climb` decision), §2.3, §2.4, §3.1 (resolved two `<<Comment>>`s), §7 (three boxes annotated, none ticked), §8 Phase 0 status ((f) pending), §11. New open decision for Phase 1: profile `max_climb` 0.35 (`floor_snap_length`) vs bake `agent_max_climb` 0.15. |
