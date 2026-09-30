# Hunter Killer — Per-creature navigation passability plan

> **Status:** `design` (draft, 2026-09-30). **No code.** This doc owns the per-size / per-species navmesh question opened in [PHYSICS_SQUEEZE.md decision 46 B](PHYSICS_SQUEEZE.md), the backlog rows "Shared navmesh bake erodes by the largest creature's radius" and "Crushable shrubs vs the navmesh bake" in [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md), and the "Open" bullet of [ENVIRONMENT_MODEL_PLAN.md §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md). The user answers the `<<Question>>` markers in §9 **in this doc**. The recommendation in §6 is **provisional, pending answers to Q1–Q5**.
>
> **Sourcing.** The evidence below is taken from active docs ([PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md) decisions 16–25 and 46, [ENVIRONMENT_MODEL_PLAN.md §6](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md), [CREATURE_MOVEMENT_V3.md §3](CREATURE_MOVEMENT_V3.md), [CREATURE_MOVEMENT_V3_CLEANUP.md C1](CREATURE_MOVEMENT_V3_CLEANUP.md#c1--pursuit-contact-geometry-stall-fox)). Those docs cite the code. This design pass did not re-read the code. Before implementation starts, re-confirm the code paths named in §2.
>
> Godot API statements in §5.0 come from knowledge of Godot 4.3–4.5. Each one carries a **verify** tag until someone checks it against the 4.7 docs.

---

## 1. Phase summary

**Phase name:** Navigation passability (per-creature pathing truth).

**One-line objective:** Pathing should answer "can **this** creature get there" for every creature size and capability. The single shared navmesh is baked for one size and cannot answer that.

**Problem in one paragraph.** Today one playfield navmesh is eroded by the **largest** creature's radius (wolf, ≈ 7.25 m after voxel snapping). Every creature pathfinds on it. Small creatures lose gaps, edge strips, and access to their own food. Large creatures are routed through gaps they cannot use, because the navmesh does not contain the open-shrub ghost obstacles at all. The per-creature shape-cast route scan catches some of these routes after the fact. It cannot produce a better route: it only truncates or disqualifies the one the navmesh gave. Neither layer has the full truth.

**Out of scope (explicit non-goals):**
- Creature-vs-creature avoidance and pushing (RVO, crowding). Creatures do not carve the navmesh, and this plan keeps it that way.
- Line of sight / occlusion ([PHYSICS_SQUEEZE §8b](PHYSICS_SQUEEZE.md), backlog).
- Designing the crush mechanic itself (`crush_weight` semantics, damage, regrowth). This plan only states what pathing needs from it (§4.4, Q3).
- Designing climbing, swimming, or jumping. This plan only reserves the extension points (Q1).
- Flee / choke / shelter **scoring** (decisions 20, 39, 45). Those consume pathing output and are unchanged unless noted.

---

## 2. Context for agents

**Repo / project root:** `hunter-killer/`
**Engine & version:** Godot 4.7 (per caller; the project overview memory says 4.6). GDScript. C++ / GDExtension is in scope for the agent role; whether it is acceptable here is Q5.
**Main scenes / entry:** `main_3d.tscn` / [`main_3d.gd`](../../main_3d.gd) (bake owner); headless tests `tests/run_all.gd` + [`tests/motor_path_fixture.gd`](../../tests/motor_path_fixture.gd).

### 2.1 Current navmesh bake (facts, per [PHYSICS_SQUEEZE decision 46 B](PHYSICS_SQUEEZE.md) and [ENVIRONMENT_MODEL_PLAN §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md))

| Item | Value today |
|---|---|
| Owner | `main_3d.gd` `_bake_playfield_navmesh`, deferred through `_ground_props_then_bake_navmesh` (props are grounded first) |
| Parse mode | `PARSED_GEOMETRY_STATIC_COLLIDERS`, `geometry_collision_mask = 1` |
| Source | `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN`, group `playfield_navmesh_source` on `_playfield_root` (terrain + `Obstacles3D`) and `FoodPlants` |
| Voxel | `cell_size` 0.25, `cell_height` 0.15 |
| `agent_radius` | largest `collision_capsule_radius` in the spawn plan, rounded up to a voxel: wolf 7.03 → **7.25 m** |
| `agent_height` | 2.0 requested → **2.10 m** (the wolf capsule is ~15 m tall; its centre is ~7.7 m up) |
| `agent_max_climb` | 0.25 requested → **0.15 m** |
| `agent_max_slope` | **Not recorded in any active doc.** <<Comment: record the value `_bake_playfield_navmesh` uses and compare it with `CharacterBody3D.floor_max_angle` (50° per [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) boulder-climb notes). If they differ, the navmesh and physics disagree about which slopes are walkable.>> |
| Readiness | `is_navigation_ready()` turns true only after the map answers a closest-point query on a baked vertex. The mesh is re-pushed every 10 frames, with a 30-frame cap. A 0-polygon bake logs and still reports ready. |
| Maps | **One** map. Motor code reaches it through `main.get_navigation_map_rid()`. |

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
- **Known limitation (not fixed):** `cast_motion` reports "clear" when the capsule already overlaps a ghost object at the start of the sweep. `ShelterEnclosureProbe` has an overlap pre-check (decision 33); the route scan does not (decision 46 E).

### 2.4 Single-map call sites (seam inventory, from docs; re-grep before implementing)

| Consumer | Uses the map for |
|---|---|
| `MotorPathClear.resolve_step_objective` + `nav_query_origin` | substep / hop (`MIN_HOP_DISTANCE` 2 m, horizontal) ([CREATURE_MOVEMENT_V3 §3.1](CREATURE_MOVEMENT_V3.md)) |
| `motor_planner.gd` `_flee_candidate_probe`, `_route_scanned_endpoint`, `_apply_route_plausibility_scan` | reach per candidate bearing / target |
| `_apply_live_food_objective` (per-tick `map_get_path` first waypoint) | live pursuit |
| `_remint_alternate_pursuit_detour` straight-vs-rotated reach compare | C1 |
| Locale search / lost-prey search candidates (decision 46 F/G) | navmesh-snapped search points |
| `CreatureMotorStack._resolve_main` → `map_rid` | map handle for the stack |
| `tests/motor_path_fixture.gd` | builds its own map (`agent_radius` 0.25); `await_nav_ready` / `await_region_nav_ready` (decision 46 J) |

**Existing patterns to follow:** [root CLAUDE.md](../../CLAUDE.md) and [Project_Docs/CLAUDE.md](../CLAUDE.md). Query-enforced passability for object-scale obstacles (decision 16). Ground-truth sizes with noise only at tactical decisions (decisions 8/18). Worst-alone impact merge (`EnvironmentMovementImpact.merge_greatest_impact`). Staged slices, tested as they land (§8h).

---

## 3. Evidence: observed failures

### 3.1 Erosion (the shared mesh is eroded for the wolf, so small creatures pay)

- `agent_radius` 7.25 m applies to **every** creature's queries.
- The rabbit loses gaps and edge strips it physically fits through.
- Each `solid_shrub_3d` (rabbit food) sits inside a ~7 m hole. The closest navmesh point to the food is ≥ 7.25 m from the hull.
- **Decision-44 smoke pocket.** The interior is ~21.9 m wide between boulder faces, which leaves only ~7–8 m navigable (21.9 − 2 × 7.25). The pocket was re-fitted for 6x boulders so the wolf could enter. The rabbit's navigable interior shrank by the same 14.5 m.
- **Live capsule radii for small creatures are not in any active doc.** Declared `.tres` values (rabbit 0.6, fox 0.7) are only fallbacks. The fox's live value was 2.343 ([PHYSICS_SQUEEZE slice 4 changelog](PHYSICS_SQUEEZE.md)). <<Comment: measure and record the live rabbit capsule radius. Every erosion number for the small class depends on it, and Q2's class boundaries need it.>>

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

### 5.1 Option A — Per-size-class navigation maps

**Shape.** K size classes, each with a class radius `R_k` (the upper bound of the class, snapped **up** to a voxel), plus class height / climb / slope. Each class gets its own map and region, baked from one shared parsed source (G8). A creature queries the map for the smallest class with `R_k ≥ its live radius` (conservative). Ghost-layer hulls are baked into **every** class map (mask `1 | 16`), pending Q6. Because hulls are solid for everyone (§2.2), erosion by `R_k` removes exactly the gaps that class can't fit through.

- **Pros:** Godot-native (G1, G2); zero custom pathfinding. Fixes erosion within a bounded tolerance: the loss for a creature of radius r is `R_k − r`. Fixes the gap trap: the open shrub now carves the wolf map. The C1 compare becomes meaningful. Class height and climb fix overhang and step mismatches for free. This is how Unity (NavMesh agent types) and Unreal (supported agents) handle multiple sizes: one navmesh per agent type. The existing `RoutePlausibilityScan` and per-step gate stay as they are, as the exact final check.
- **Cons:** Continuous size is quantized; tolerance depends on class spacing. Bake time and memory scale by K (G10 unknown). Dynamic changes need a rebake per class, or per tile per class (G7). Capabilities (climb, swim, crush) multiply maps if modelled as maps. Readiness logic becomes per-map.
- **Crush:** A crushed shrub is removed from the source, and the affected tile is rebaked on every class map. "Crushable **by me**" before crushing is not expressible per creature, because weight isn't a class property. Two options: keep crushables as carving and let the motor crush on contact (pathing is pessimistic), or bake the crushable footprint as a separate high-`travel_cost` region with a CRUSH navigation-layer bit (G3/G4) and let heavy creatures include that bit. See Q3/Q8.
- **Squeeze / compressibility:** Not native. Approximate by baking a class at `R_k × squeeze_factor` and tagging those regions with cost. This gets complicated fast; see Q1.
- **Climbing:** Bake `agent_max_slope` / `agent_max_climb` per class. A climbing **trait** becomes a capability overlay (region layer bit, as in Option B) or an extra map per (class, climber), which multiplies maps.
- **Runtime size change:** Switch maps at class thresholds, with hysteresis (same idea as §8d). Replan on switch.
- **Dynamic obstacles:** Tiles: the playfield is split into T regions per class, and a change rebakes the covering tile(s) × K. The depletion hull swap needs the same path, or a decision that depleted hull changes don't matter for pathing (Q3).
- **Migration cost:** Medium. Bake code in `main_3d.gd` (app-shell), readiness per map, the seam (M5) across ~7 motor call sites, and fixture support for building K classes. There is no scoring change.

### 5.2 Option B — One fine navmesh (smallest radius) + navigation layers for "small-only" regions

**Shape.** Bake once with the smallest radius, and bake again at the larger class radii. Compute the polygon **difference** (small-only strips) and turn each band into separate regions tagged with navigation-layer bits. A large creature's query excludes the small-only bits.

- **Pros:** One map, one query path. The layer mask per creature is cheap. The same mechanism serves capability overlays (climb-only, swim-only) well, because those are **region** properties, not clearance.
- **Cons:** Godot has no navmesh boolean ops. The difference must be computed in script (`Geometry2D.clip_polygons` on XZ projections, or similar), then rebuilt into regions whose edges must connect within `edge_connection_margin`. This is fragile, especially on sloped terrain. It is still quantized to classes and still needs N bakes to compute the bands, so it costs more than A with more failure modes. Dynamic updates need the same rebake plus a re-diff.
- **Verdict:** Poor for **size**. Good for **capabilities** as an overlay on A.

### 5.3 Option C — Clearance-annotated navmesh + custom clearance-aware A*

**Shape.** Bake one mesh at the smallest radius and compute clearance per polygon edge / portal. Run a custom A* over the `NavigationMesh` polygons (vertices / polygons are readable) that rejects portals narrower than `2r`, then do a custom funnel.

- **Pros:** Continuous radius on one mesh. Exact size semantics if clearance is computed correctly.
- **Cons:** Correct corridor clearance on arbitrary triangulations is hard. Portal width is not corridor clearance. The standard fix is a local-clearance triangulation (Kallmann's LCT), which Godot doesn't produce. It replaces Godot's pathfinder entirely, so it needs a custom A*, funnel and closest-point, probably in C++ for performance. Dynamic updates still rebake Godot's mesh, then re-annotate. It inherits the navmesh's single slope / climb / height, so capabilities still need layers.
- **Verdict:** Highest effort for a result that Option D gets more simply.

### 5.4 Option D — Clearance / distance field on a fine grid + custom grid pathfinder

**Shape.** A 2.5D grid over the playfield at 0.5–1 m cells. Each cell stores its height, slope, an obstacle id, and flags (crushable weight, squeeze factor, terrain kind). A distance transform ("brushfire") gives the **clearance** to the nearest blocking cell. A creature's query treats a cell as passable iff `clearance ≥ r` (or `≥ r × squeeze` at a cost), the slope / step to the neighbour is within that creature's limits, and any obstacle there is not crushable by that creature's weight. Paths come from A* / JPS with clearance (in the spirit of Harabor & Botea's Hierarchical Annotated A*, which targets multiple agent sizes plus terrain capabilities). String-pulling / Theta* smooths the result.

- **Pros:** Continuous radius **and** every capability dimension in one structure, evaluated per query. No combinatorial maps. Local dynamic updates: re-run brushfire within `max_radius` of the change, which is cheap, so crush latency is ~one frame. Aligns with the existing `EnvironmentGridBaked` / `EnvironmentCellData` Mode A/B concepts (§2b) and could finally give them callers. Runtime size change is free: the next query uses the new r.
- **Cons:** Custom pathfinder, smoothing and closest-point. At 200 × 204 m with 0.5 m cells that is ~163k cells. A GDScript A* per query is likely too slow at more than a few creatures, so this probably needs C++ / GDExtension (Q5). `AStarGrid2D` (G9) is engine-native but has global solidity, so it only helps as one grid per size class (a Grid-A hybrid). 2.5D assumes single-level terrain: no bridges, caves or overhangs; see Q9. Grid resolution trades memory against the thin-obstacle error. The existing 4 m grid is unusable for this; it needs a new fine layer. Loses Godot navmesh tooling (debug draw, `NavigationAgent3D`) unless mirrored.
- **Migration cost:** High: new subsystem, rasterizer from colliders, pathfinder, and tests. The seam (M5) keeps motor call sites unchanged.

### 5.5 Option E — Status quo + smarter live repair (baseline)

**Shape.** Keep one map. Improve repair. Possible repairs: bake at the **smallest** radius so small creatures stop losing gaps; extend the route scan to sweep layer 1 too; fix the start-overlap bug; on a scan truncation, requery with the blocking spot excluded (needs `excluded_regions`, G5, which only works at region granularity, so it's ineffective on one big region); add more detour candidates.

- **Pros:** No new infrastructure. The start-overlap fix and telemetry are worth doing anyway.
- **Cons:** It doesn't fix the root cause. Whichever radius is baked, one side of the size range gets wrong routes. Repair is reactive, one path at a time, with no alternative-route search, so gap traps become retry loops whose cost grows with clutter. Every new trait adds more repair heuristics. The C1 compare stays blind to ghost obstacles. **Not scalable.**

### 5.6 Hybrids

- **H1 (recommended shape, provisional): A now, with a seam that allows D later.** Phase 0 builds the per-creature `PassabilityProfile` plus a `NavRouter` seam (M5) over the current single map. Phase 1 swaps in per-class maps behind it. If Q2 / Q3 / Q5 answers push toward continuous sizes, fast dynamics or many creatures, Phase 4 replaces the router backend with D. No motor call site changes a second time.
- **H2: A for size, B-style layers for capabilities.** Size classes are maps. Binary capabilities (climb-steep, swim, crush-heavy) are region navigation-layer bits within each class map. This avoids size × capability map multiplication for binary traits. It needs capability regions baked as separate regions (for example, steep-slope patches), and that is fiddly (see B's cons).
- **H3: Grid-A.** Option D's clearance field, but pathfinding through one `AStarGrid2D` per size class (solidity = `clearance < R_k`). Engine-native A*, local updates via `set_point_solid`, no GDExtension. Still quantized to classes; capabilities via `weight_scale` or extra grids.

### 5.7 Keep or change the navmesh-coarse / shape-cast-enforcement split?

With A / H1 the split **stays, but the roles sharpen**:
- The navmesh (per class) becomes the **route** truth for static geometry, including ghost hulls. It's no longer "coarse" in the sense of being wrong about size.
- The per-creature route scan becomes a **residual** check for continuous-radius error inside a class (`R_k − r`), dynamic changes since the last bake, and future Mode-B `movement_impact` accumulation (decision 22).
- The per-step gate stays the exact final authority (decision 16).
- Dead-end marks and detours stay as fallback for dynamic cases, as decision 22 intended.

With D, the grid becomes the single route and passability truth. The shape-cast stays only as the physical contact gate.

---

## 6. Provisional recommendation (pending Q1–Q5)

**H1: Option A with 2–3 size classes behind a new `NavRouter` seam, ghost hulls baked into every class map, and Option D kept as the planned escape hatch.** Rationale:

1. The two concrete failures are erosion and the gap trap. Both come from *one radius for everyone* and *ghost hulls missing from pathing*. A fixes both with native Godot features and no custom pathfinder.
2. The seam (Phase 0) has value under every option and is the only part that touches all motor call sites. After it lands, switching the backend from A to D (or H3) is a local change.
3. A's weak points (continuous size, fast dynamics, capability combinatorics) are exactly what Q2, Q3 and Q1 decide. If the answers are "few classes, slow or rare changes, few binary traits", A is enough. If they are "continuous growth, frequent crush, many traits", commit to D early and treat A as the interim.

**Would change the recommendation:**
- Q2 = truly continuous sizes with small erosion tolerance → **D** (or H3 for a native-only path).
- Q3 = sub-second path reaction to crush and regrowth at many sites → **D**. Tile rebakes × K classes are unlikely to meet it (G10 to measure).
- Q5 = no C++ ever **and** Q2 continuous → **H3**. Accept some quantization.
- Q6 = "never bake ghost hulls" → A still fixes erosion but **not** the gap trap. Fixing the trap would then need open shrubs moved to a separate high-cost region layer, or D.

---

## 7. Acceptance criteria and success metrics

**Metrics apply to live runs as well as headless ones.** Pre-2026-09-25 live evidence does not count (§3.3). Numeric targets marked *(tune)* are proposals for the user to accept or change.

- [ ] **Gap trap:** the (75,30) / (65,20) headless scenario wedges the wolf in **0 of ≥ 30** seeded runs *(tune)*. It was 9/17 before.
- [ ] **Static-route agreement:** for static obstacles, the fraction of a creature's path queries that its own route scan truncates is ≤ 2% *(tune)*. New telemetry counter `scan_truncated_static` per creature. A high value means the pathing truth and the enforcement truth disagree.
- [ ] **Erosion tolerance:** for each creature, the extra erosion versus its own radius is ≤ the class tolerance `R_k − r` *(Q2 sets the bound)*. Measure by sampling points that are capsule-clear at radius r and checking whether that creature's map covers them.
- [ ] **Food access:** each `solid_shrub_3d` has a navigable point for the rabbit's class within the rabbit's effective eat reach (`eat_action_max_distance` + radius bonus, decision 26).
- [ ] **Decision-44 pocket:** the rabbit's navigable interior width is within one voxel of `21.9 − 2 × R_rabbit_class`.
- [ ] **C1 compare:** in the c1 smoke and a new open-shrub variant, the straight-vs-rotated reach compare produces non-tied reach at least once in live play (telemetry).
- [ ] **Dynamic latency:** from a crush / regrowth / hull swap event to every affected class map answering with the new geometry ≤ **T_dyn** (Q3 sets it).
- [ ] **Size change:** a creature whose radius crosses a class boundary queries the new class within one consideration tick. No `MOTOR_INVARIANT` silent stall is attributable to the switch (headless test).
- [ ] **Budget:** total navigation time per physics frame ≤ **B_nav** ms at **N** creatures on the target hardware (Q5 sets N, hardware and B_nav). Bake time per class and memory per class are recorded.
- [ ] **Readiness:** `is_navigation_ready()` is true only when **every** class map passes the closest-point check. A 0-polygon class map fails loudly and does not report ready.
- [ ] **Fixtures:** `tests/motor_path_fixture.gd` builds single-class (default, unchanged behaviour) **and** multi-class layouts synchronously. The full suite stays green.
- [ ] **Route scan start-overlap:** `RoutePlausibilityScan` reports a start-overlap as blocked (or escaping, per §8e), matching `ShelterEnclosureProbe` (decision 33).

---

## 8. Phased plan sketch (ordered; slices not yet approved)

| Phase | Content | Gated on | Owner (routing) |
|---|---|---|---|
| **0 — Seam + hygiene** | (a) `PassabilityProfile` per creature: live radius, height, max_climb, max_slope, weight, capability bits. (b) `NavRouter` / `PassabilityService`: `path(profile, from, to)`, `closest_point(profile, p)`, `map_for(profile)`, `is_ready()`, backed by the **current single map** (no behaviour change). (c) Migrate every §2.4 call site onto it. (d) Route-scan start-overlap fix. (e) `scan_truncated_static` telemetry. (f) Promote the gap-trap scenario to a headless regression test (expected red until Phase 1). (g) Record `agent_max_slope` vs `floor_max_angle` and the live rabbit radius. | user approval only | creature-motor; app-shell (main_3d accessor); test-harness |
| **1 — Class maps (A)** | K classes from config (Q2). Parse once and bake K times async (G8). Ghost hulls in the source (Q6). Per-class height / climb / slope. Readiness across all maps. Fixture multi-class builder. Class selection with hysteresis. | Q1, Q2, Q6 | app-shell (bake), creature-motor (router), test-harness |
| **2 — Dynamics** | Tile the playfield into regions per class (G7). Local rebake on crush / regrowth / hull swap. Latency telemetry against T_dyn. Crushable representation per Q8. | Q3, Q8 | app-shell, environment-world, assets-pack (shrub events) |
| **3 — Capabilities** | Climb / swim / crush-heavy as navigation-layer overlays (H2) or per-query rules. Squeeze per Q1. | Q1 (+ trait design docs) | creature-entity (profile), app-shell (bake) |
| **4 — Grid backend (D / H3), conditional** | Fine 2.5D grid + brushfire clearance + pathfinder behind `NavRouter`; C++ per Q5. Retire class maps if D supersedes them. | Q2, Q3, Q5, Q9; Phase 0–1 metrics | new GDExtension domain (needs a specialist row), environment-world |

**Docs to sync when phases ship (flag for `project-docs`):** [ENVIRONMENT_MODEL_PLAN §6.3.1](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) (bake sources / erosion), [PHYSICS_SQUEEZE decision 22](PHYSICS_SQUEEZE.md) (if Q6 reverses "never bake the ghost layer"), [CREATURE_MOVEMENT_V3 §3.1](CREATURE_MOVEMENT_V3.md) (substep via router), [PLANT_ECOLOGY_PLAN `crush_weight` row](PLANT_ECOLOGY_PLAN.md).

### 8.1 Evaluation matrix

Scores: ✔ handles well · ~ partial / with work · ✘ does not handle. Costs are relative.

| Concern | A class maps | B fine + layers | C annotated navmesh | D grid clearance | E status quo+ | H1 (A → D seam) |
|---|---|---|---|---|---|---|
| Erosion (M2) | ✔ within class tolerance | ~ class bands, fragile | ✔ | ✔ exact to cell | ✘ one side always loses | ✔ |
| Gap trap (M3) | ✔ if Q6 = bake hulls | ~ | ✔ if hulls in mesh | ✔ | ✘ retry loops | ✔ |
| Continuous size | ~ quantized | ~ quantized | ✔ | ✔ | ✘ | ~ → ✔ |
| Runtime size change (M4) | ✔ map switch + hysteresis | ✔ mask switch | ✔ | ✔ free | ~ | ✔ |
| Crush | ~ tile rebake × K; pre-crush per-creature weight awkward | ~ | ~ rebake + re-annotate | ✔ local brushfire, per-creature weight | ~ reactive | ~ → ✔ |
| Squeeze / compressibility | ✘ / ~ extra classes | ~ | ~ | ✔ `r × factor` at a cost | ~ route scan only | ~ → ✔ |
| Climbing / slope trait | ~ per class, overlays | ✔ as overlay | ~ | ✔ per-query rule | ✘ | ~ → ✔ |
| Height / overhang | ✔ per class | ~ | ✘ single height | ~ 2.5D, no overhangs | ✘ | ✔ |
| Dynamic obstacles latency | ~ tile rebake (G10) | ✘ re-diff | ✘ | ✔ ~frame | ~ | ~ → ✔ |
| C1 compare meaningful | ✔ | ~ | ✔ | ✔ | ✘ | ✔ |
| Test fixtures | ~ multi-class builder | ✘ complex | ✘ | ~ new fixture type | ✔ unchanged | ~ |
| Engine-native | ✔ | ✔ + script geometry | ✘ custom A* | ✘ (✔ if H3) | ✔ | ✔ now |
| C++ likely needed | no | no | yes | likely (not for H3) | no | only in Phase 4 |
| Implementation cost | M | H | VH | H | L | M now, H later |
| Migration cost vs current code | M (bake + seam) | H | VH | H (seam absorbs call sites) | L | M, then local |
| Main risk | bake time × K; map count growth with traits | seam connectivity | clearance correctness | perf, 2.5D limit | root cause untouched | two backends to maintain until D lands |

---

## 9. Open questions (answer in place)

Each question gives the context, options and consequences, then one `<<Question>>` marker to answer. Q1–Q5 gate the recommendation. Q6–Q9 are narrower and follow from them.

### Q1 — Which passability dimensions vary per creature?

| Dimension | Status today | If "varies per creature" | If "fixed / not now" |
|---|---|---|---|
| Radius | varies (rabbit … wolf 7.03) | required; drives the whole plan | n/a |
| Height / overhang clearance | bake uses 2.1 m for all; no overhang props exist today | per-class `agent_height` (free in A); D needs per-cell ceiling height | keep one height; overhang props must not be authored |
| Slope / step limit (incl. climbing trait) | 0.15 m climb for all; slope unrecorded | per class (A) or per query (D); a climbing **trait** needs overlays (H2) or D | one limit; climbing waits for its own design |
| Crush weight | not implemented | pathing must know "I can crush this": region cost + layer bit (A) or per-query rule (D) | crushables carve; crushing is discovered on contact |
| Squeeze / compressibility (Mode A `fit_size`) | `EnvironmentCellData` supports it, zero callers | extra reduced-radius classes (A, costly) or `r × factor` (D, cheap) | exact radius only |
| Swim / terrain kind | not implemented | capability overlay (layer bit) or grid flag | n/a |

<<Question: Q1 — Which of radius, height/overhang, slope/climb (including a climbing trait), crush weight, squeeze/compressibility and swim must vary per creature in pathing, and which only in live enforcement or not at all? Each dimension that must vary in pathing adds either maps/overlays (Option A) or pushes toward the grid backend (Option D).>>

### Q2 — Size model: few fixed classes or continuous sizes?

- **Few fixed classes (2–3):** A is cheap. Erosion error per creature is `R_k − r`. Example with small ≤ 2.5 m and large ≤ 7.25 m: a 3 m creature would lose ~4.25 m per side, so class boundaries must follow the roster. Growth / magic crosses boundaries in steps, with hysteresis.
- **More classes (4–8):** bounded error, but K× bake time and memory, and K maps to keep ready and in sync.
- **Continuous (any radius, growth mid-life):** only C or D give exact results. A can only approximate with many classes.
- **Rounding policy:** conservative round-up (never routes a creature through a gap it can't fit; may deny gaps near the class edge) vs nearest (smaller loss; relies on the route scan to catch misfits). This plan assumes round-up.

<<Question: Q2 — Should sizes be treated as a few fixed classes (how many, and where are the boundaries relative to the current roster), or as continuous (growth, magic, many species)? What erosion tolerance per creature is acceptable, in metres or as a fraction of radius? Is conservative round-up the right rounding policy?>>

### Q3 — World dynamism: what changes at runtime, how often, and how fast must paths react?

Candidates: crush (an obstacle removed, possibly permanent), regrowth (an obstacle restored), depletion hull swap (`bush_food_3d.gd`, shape change on ready ↔ depleted; not rebaked today), future terrain changes (digging, flooding), and creatures as obstacles (out of scope).

| Answer | Consequence |
|---|---|
| Rare (a few per minute), seconds of latency OK | A with tiled regions and async rebakes is enough |
| Frequent (many per minute), ≤ 1 s latency | A needs small tiles × K classes, and G10 must be measured first; D becomes attractive |
| Near-instant (same or next frame) | D (local brushfire), or keep the shape-cast as the only enforcement for dynamic things and accept stale routes |
| Hull swap "doesn't matter for pathing" | no rebake on depletion; the per-step gate + escape hatch (§8e) covers it |

<<Question: Q3 — Which obstacles change at runtime (crush, regrowth, depletion hull swap, terrain edits, other), roughly how often per minute in a busy scene, and what is the maximum acceptable time (T_dyn) from the change to paths reflecting it? Can the depletion hull swap be ignored by pathing?>>

### Q4 — Where does per-creature passability truth live?

- **(a) Status quo:** navmesh coarse and species-blind; per-creature shape-cast is the truth (decision 22). Consequence: the failures in §3 persist, and every new trait adds repair heuristics (Option E).
- **(b) Pathing holds static truth per class; shape-cast is the residual and final gate (A / H1).** Decision 22's route scan stays but should rarely truncate (metric in §7). This amends decision 22's premise that the navmesh is species-blind.
- **(c) Pathing holds full per-creature truth, static and dynamic (D).** The shape-cast is only the physical contact gate.

<<Question: Q4 — Keep the navmesh as species-blind coarse routing with per-creature truth enforced live by shape-casts (status quo), move static per-creature truth into pathing with shape-casts as the residual/final gate (Option A/H1), or move all per-creature truth into pathing (Option D)?>>

### Q5 — Performance budget and language

The facts that decide A vs D: bake cost × K (G10), per-query A* cost on ~163k grid cells, and map sync cost. The agent role includes C++. A GDExtension adds a build toolchain, CI and a platform matrix, and needs a new specialist routing row.

<<Question: Q5 — Target creature count on screen (now, and the design ceiling), target hardware (min-spec CPU), frame budget for navigation in ms, and whether C++/GDExtension is acceptable for a pathfinding backend (yes now / yes later if metrics demand it / never)?>>

### Q6 — Bake ghost-layer hulls into the per-class maps?

[Decision 22](PHYSICS_SQUEEZE.md) / §8a rejected baking the ghost layer "because a single shared bake can't express a per-species fact". With per-class maps that reason no longer applies. Hulls are solid for everyone (§2.2), and erosion by `R_k` yields exactly the class's passable gaps. Physics would still not enforce them (they stay out of movement masks), so decision 16's query enforcement is untouched.
- **Yes:** fixes the gap trap and the C1 blindness. Amends decision 22's wording (not its intent).
- **No:** A fixes erosion only. The gap trap needs a separate mechanism: an open-shrub region with high cost, or D.

<<Question: Q6 — With per-class maps, may ghost-layer hulls (open shrubs, later boulders) be baked into every class map's source geometry while staying off every movement mask? This amends decision 22's "never bake the ghost layer" wording.>>

### Q7 — Boulders: migrate to the ghost layer (decisions 16/17) or keep them on layer 1?

- **Keep layer 1:** the engine enforces boulders (robust against motor bugs) and they carve every class map. There is no pathing difference under A.
- **Migrate:** consistent with decision 16 (only terrain engine-enforced). Under A they carve anyway (if Q6 = yes). The risk: boulder blocking then depends on the motor gate (the escape hatch, the start-overlap bug) instead of physics.

<<Question: Q7 — Do boulders stay on layer 1 (engine-enforced) or migrate to the ghost layer as decisions 16/17 planned? Under Option A with Q6 = yes, pathing is the same either way. The difference is only which layer enforces contact.>>

### Q8 — Crushable shrubs in pathing

- **(a) Keep carving until crushed**, then rebake the tile. Pathing is pessimistic, so heavy creatures detour around things they could flatten.
- **(b) Separate cost region + CRUSH layer bit:** creatures above `crush_weight` include the bit and pay `travel_cost`. Per-shrub weight thresholds need per-threshold bits, so use a few weight bands.
- **(c) Don't carve at all:** the per-step gate stops light creatures, and the route scan must learn about layer 1. This reintroduces gap-trap risk for light creatures.

<<Question: Q8 — How should an uncrushed but crushable shrub appear in pathing: carve until crushed, a cost region usable only by heavy-enough creatures, or not carved at all? How many distinct crush-weight bands are expected?>>

### Q9 — Terrain topology: is the playfield single-level (2.5D)?

Option D and H3 assume one walkable surface per XZ cell. Bridges, caves, overhangs or multi-level terrain break that and favour navmesh-based options.

<<Question: Q9 — Will any playfield have multi-level walkable geometry (bridges, caves, ledges above walkable ground, overhangs creatures walk under)? If yes, grid backends (D/H3) need a layered grid or are ruled out.>>

---

## 10. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Bake time × K classes stalls startup or rebakes | Measure G10 in Phase 0. Async bakes. Parse once (G8). Tile regions (G7). |
| Map count explodes with size × capability | Capabilities as layer overlays (H2), not maps. Revisit D if the overlay count grows. |
| Class switching flickers for a creature near a boundary | Hysteresis band. Switch only on consideration ticks (mirrors §8d). |
| One class map empty or not synced; silent fallback like decision 46 B | Per-map readiness. A 0-polygon class map fails loudly. A headless test per class. |
| The route scan masks a class-map bug | `scan_truncated_static` telemetry with an alarm threshold (§7). |
| Earlier tuning rested on an empty navmesh (§3.3) | Re-run the decision-44, c1 and c44 smokes after Phase 1. Treat earlier live evidence as void. |
| Seam migration regresses motor behaviour | Phase 0 is behaviour-neutral by construction (same single map). Full suite A/B before and after. |
| GDExtension toolchain burden (Phase 4) | Only if Q5 allows. H3 as the native-only fallback. |

---

## 11. Testing / verification

**Automated (proposed):**
- Gap-trap scenario as a seeded multi-run headless test (§7 target).
- Per-class bake produces polygons; ghost hulls carve only where the class radius can't fit (two-class fixture: a gap between two hulls wider than 2·R_small and narrower than 2·R_large).
- Class selection with hysteresis on a runtime radius change.
- Route-scan start-overlap regression (sibling of the decision 33 shelter probe test).
- Tile rebake latency after a synthetic crush (Phase 2).

**Manual:** re-run the [decision 44 smoke](PHYSICS_SQUEEZE.md#decision-44-live-smoke-test), `spawn_layout_c1_smoke.json` and `spawn_layout_c44_smoke.json` on the new pathing. Add an open-shrub gap-trap layout.

---

## 12. Related docs

- [PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md): decisions 5, 16/17, 22/23, 25, 33, 46 B/E (source of the question this doc answers).
- [ENVIRONMENT_MODEL_PLAN.md §6](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md): layer table and navmesh bake sources (contract to sync).
- [CREATURE_MOVEMENT_V3.md §3 / §3.1](CREATURE_MOVEMENT_V3.md): substep rule and headless fixture.
- [CREATURE_MOVEMENT_V3_CLEANUP.md C1](CREATURE_MOVEMENT_V3_CLEANUP.md#c1--pursuit-contact-geometry-stall-fox): straight-vs-rotated compare.
- [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md): `crush_weight`, `fit_size`, `movement_impact`.
- [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md): "Shared navmesh bake erodes by the largest creature's radius", "Crushable shrubs vs the navmesh bake", "Climbing as a skill/trait".

---

## 13. Changelog

| Date | Change |
|------|--------|
| 2026-09-30 | Created (design only, status `design`). Captures the evidence (erosion, gap trap 9/17, empty-navmesh history), current bake facts, obstacle/passability inventory, single-map call-site seam, Godot capability notes (unverified against 4.7), options A–E plus hybrids H1–H3, evaluation matrix, acceptance metrics, phased plan, and questions Q1–Q9 for the user. Provisional recommendation: H1 (per-class maps behind a `NavRouter` seam, ghost hulls baked per class, grid backend as the planned escape hatch), pending Q1–Q5. Takes over the per-size navmesh `<<Question>>` from PHYSICS_SQUEEZE decision 46 B. |
