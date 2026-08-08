# Hunter Killer — Environment model (terrain / props abstraction)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

### Implementation tracking (quick glance)

| Topic | Status | Where |
|-------|--------|--------|
| **`passible`**, **`movement_impact`**, **`fit_size`**, mob detours, creature **`size`** (2D) | **Specified for implementation** | [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) |
| **Placement / boundaries / authoring** for env geometry | **Chosen:** palette PNGs in **`res://art/env/`** → bake → `EnvironmentGridBaked` (OBJECT §8.1) | [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.1 |
| **Player motor weights** (interior env + memory vs mobs; edges unchanged) | **Specified** — implement per OBJECT §8.2 | [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2 |
| **Experiential slowdown** + **`terrain_kind_id`** (learn per terrain kind; **includes squeeze exploration**) | **FUTURE** — not object-avoidance phase | §11 (carry-forward); archived OBJECT §10; §4 `terrain_kind_id` |
| **`crush_weight`** destructible props | **NOT IMPLEMENTED** — future phase | §4 Property catalog; §5 step 3 |
| **`apply_movement_impact` / modifier merge** (shared helper) | Partially scoped — env side in object-avoidance plan; **plant + terrain merge** still **OUTSTANDING** | §5 step 1; §8 Risks |
| Physics **layer/mask mapping** (hunger shrubs + actors) | **Done (3D)** — layer/mask **split** (Option A); see **§6** | §6; [HUNGER_AND_EATING.md](Completed_Features/HUNGER_AND_EATING.md) §5.1 |
| **Static obstacle mesh ↔ collision** (boulders bake at spawn; shrubs convex at `_ready`; creature capsules from visual) | **Done (3D)** | **§6.3**; [`static_obstacle_collision.gd`](../../environment/static_obstacle_collision.gd) |
| **`crush_weight == 0`** semantics in code comments | **OUTSTANDING** (blocked until crush phase) | §7 Acceptance |
| **3D** height / volumetric crush | **OUTSTANDING / deferred** — **3D layers shipped** ([CONVERT_TO_3D.md](../Completed_Features/CONVERT_TO_3D.md) M1); height/crush revisit in dedicated phase | §10 Open questions |
| Nice-to-have: **`Area2D` water** with non-linear drag | **OUTSTANDING** | §3 Nice to have |
| **Per-creature interior env belief — save-game persistence** | **FUTURE** | OBJECT §8.2.3 (memory on creature; persistence OOS) — §11 |
| **Multi-layer palette / image → grid merge order** | **Document at bake time** | OBJECT §8.1 limits — §11 |
| **Footprint: polygon–cell overlap vs center-only** | **Shipped (M4):** ≥25% overlap via [environment_footprint_sampler.gd](../../environment/environment_footprint_sampler.gd) | OBJECT §9 — §11 |
| **`env_detour_patience_ticks`** vs shared **`awareness_memory_ticks`** | **FUTURE** if coupling hurts | OBJECT §8.2.5 — §11; [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) |
| **Silhouette vs unexplored** second motor bucket + LOS on snapshot | **FUTURE** (perception / FOV) | OBJECT §8.2.5 comments; OBJECT §10 — §11 |
| **Randomized interior boulder / food / duel-pair spawn** (perimeter boulders stay fixed) + lockable repro layout file | **Done (3D)** | **§6.4**; [`playfield_spawn_randomizer.gd`](../../environment/playfield_spawn_randomizer.gd) |

---

## 1. Phase summary

**Phase name:** Environment model (terrain / props abstraction)

**One-line objective:** Define the shared **environment** abstraction (passibility, movement slowdown, size/weight gates, crush limits) for stone, dirt, water, dense brush, etc., so creatures and plants can share collision-response rules later.

**Out of scope (explicit non-goals):**  
- Full voxel or heightmap world in early phases.  
- Fluid simulation.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`)

**Engine & version:** Godot **4.6.x** (match `project.godot`)

**Main scenes / entry:** [`main_3d.tscn`](../../main_3d.tscn) + [`main_3d.gd`](../../main_3d.gd) — 3D playfield, perimeter boulders, 3D shrub scenes.

**Key scripts (paths):**  
- [`playfield_bounds_3d.gd`](../../environment/playfield_bounds_3d.gd), [`playfield_perimeter_boulders.gd`](../../environment/playfield_perimeter_boulders.gd)  
- Future: tileset custom data or parallel grid for `passible` (+ `movement_impact`, `fit_size`).

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)  
- [.cursor/rules/focus/asset_management.md](../.cursor/rules/focus/asset_management.md) — **authored food shrubs** use **`res://assets/plants/solid_shrub/`** and **`open_shrub/`** (3D scenes **`solid_shrub_3d.tscn`** / **`open_shrub_3d.tscn`**); **3D** physics **layer/mask** mapping for hunger + actors is **§6**.
- Align numeric semantics with [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md) for `movement_impact`, `fit_size`, `crush_weight` where possible (shared helper).

---

## 3. Requirements

### Must have (design)

- Properties and semantics below match EARLY_SPEC_DOC intent.

### Should have

- Explicit **POC** statement: current Dodge scene may use only implicit “viewport clamp as wall” until this phase is referenced.

### Nice to have

- `Area2D` water volume with different drag curve than linear `%` reduction.

---

## 4. Technical design

### Architecture / data flow

- **Tile / cell metadata** carries an `EnvironmentData` id or embedded struct.  
- **Creature movement** queries tile under feet each physics tick (or on enter) to decide **`can_enter`** ([OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §3.5) and **`movement_speed_multiplier(creature_size, …)`** ([OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §3.6).

### Property catalog

| Property | Type | Meaning |
|----------|------|---------|
| `passible` | bool | **`true`:** **All** creatures may enter (**`fit_size`** does **not** gate entry). **`false`:** **Enterability** uses **`fit_size`** only (squeeze — Mode A in [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §3.3). |
| `movement_impact` | float (nullable) | Slowdown **strength**; effective penalty per creature uses **`movement_speed_multiplier(creature_size, env)`** (OBJECT §3.6). Applies on **`passible == true`** (everyone, or large-only when paired with Mode B **`fit_size`**) and inside **squeeze** cells when authored. |
| `fit_size` | float (nullable) | **Dual role** ([OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §3.3): **Mode A** (`passible == false`) — **inclusive `<=`** squeeze entry; **`null`/`0`/invalid** ⇒ nobody enters. **Mode B** (`passible == true` + active **`movement_impact`** + valid **`fit_size > 0`**) — **strict `<`** exempts small creatures from slowdown; **`>=`** pays **`movement_impact`**. When **`passible == true`** and **`movement_impact`** inactive, ignore **`fit_size`** at runtime. |
| `terrain_kind_id` | StringName or int (nullable) | **FUTURE / not this phase** — Stable **category** ID so experiential memory distinguishes kinds (**mud**, **deep_snow**, **squeeze-rock-arch**, etc.); supports learned squeeze affordance vs slowdown ([OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §10). Nullable when unused. |
| `crush_weight` | float | **NOT IMPLEMENTED (this repo phase)** — Creature **weight** above this destroys this environment piece; `0` = unbreakable by crush rules. |

### Methods

- None required at abstract level for POC; concrete tiles may use Godot signals (`body_entered`).

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create (future) | `res://environment/...` | Runtime scripts; **author palette maps** in **`res://art/env/`** |

### Collision / input / signals (if relevant)

- Physics layers: **hunger + shrubs** use the **§6** table (layer/mask split). Extend this section when new props or actors need additional bits.

### Dependencies

- [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) for `size` / `weight` on creatures.

---

## 5. Implementation plan (ordered)

1. **OUTSTANDING (beyond object avoidance):** Extract shared `apply_movement_impact(creature, env_data)` when both plant underbrush and terrain use the same math — env-side helper is scoped in [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md); **plant merge** still TODO.  
2. **Specified for implementation:** Introduce tileset custom data or parallel grid for `passible` (+ `movement_impact`, `fit_size`) — see [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md).  
3. **OUTSTANDING:** Wire crush detection for destructible props (`crush_weight`).

---

## 6. Godot 3D physics — layer / mask (hunger shrubs + duel actors)

**Chosen approach:** **Layer / mask split (Option A)** for **Food B** (`open_shrub_3d`) — **no** `PhysicsBody3D.add_collision_exception_with(player)` as the primary mechanism for v1. **Food A** (`solid_shrub_3d`) uses the **same solidity class as perimeter boulders** (player and mob both collide).

**Authoritative numbers** below match [`project.godot`](../../project.godot) **`3d_physics/layer_*`**, [`creature_*_kinematic_3d.tscn`](../../creature/templates/), and [`*_shrub_3d.tscn`](../../assets/plants/) as of **2026-06-08**. If bits change in code, update **this table** and **`project.godot`** in the same PR.

### 6.1 Layer bits (3D physics)

| Bit | Value `2^(bit-1)` | `[layer_names]` name | Occupants |
|-----|-------------------|----------------------|-----------|
| 1 | `1` | `world_static` | Playfield floor / mesh collision; perimeter **StaticBody3D** boulders; **Food A** **`solid_shrub_3d`** blocker; **Food B** **`open_shrub_3d`** calorie **`Area3D`** **collision_layer** (overlap only — see §6.2) |
| 2 | `2` | `player` | Herbivore duel **`CharacterBody3D`** ([`creature_herbivore_kinematic_3d.tscn`](../../creature/templates/creature_herbivore_kinematic_3d.tscn) **Body**; layers set in [`creature_kinematic_body_3d.gd`](../../creature/capabilities/creature_kinematic_body_3d.gd) `_apply_physics_layers()`) |
| 3 | `4` | `mob` | Carnivore duel **`CharacterBody3D`** ([`creature_carnivore_kinematic_3d.tscn`](../../creature/templates/creature_carnivore_kinematic_3d.tscn) **Body**; `is_hostile` → mob layer) |
| 4 | `8` | `plant_mob_block` | **Food B only:** **`open_shrub_3d`** **MobBlocker** **StaticBody3D** shell that blocks **mobs** but **not** the player |

### 6.2 Masks (targets for hunger + duel)

| Body | `collision_layer` | `collision_mask` | Role |
|------|-------------------|------------------|------|
| **Herbivore (player)** | `2` | `1` | Walks **world_static** + Food B calorie areas; **`1` excludes bit `8`** → **no** physics collision with **`plant_mob_block`**. |
| **Carnivore (mob)** | `4` | `1 \| 8` (= **`9`**) | Collides with **rocks** and **`plant_mob_block`** — same treatment as other solid obstacles for movement / avoidance. |
| **Food A `solid_shrub_3d` static** | `1` | **`7`** (scene default) | Impassible for **player** and **mobs**. |
| **Food B `open_shrub_3d` MobBlocker** | `8` | **`4`** | Mutual mask↔layer with **mob** layer so **CharacterBody3D** contacts register. |
| **Food B / Food A calorie `Area3D`** | `1` | **`2`** | `monitoring = true`; **`collision_mask = 2`** → **player-only** overlap for burst calories. Mobs (**layer `4`**) do **not** match mask **`2`**. |

**Implementer note:** Calorie **`Area3D`** nodes are **not** a substitute for mob blocking; keep the **StaticBody3D** shell on **`plant_mob_block`** for **`open_shrub_3d`**.

### 6.3 Static obstacle collision authoring (mesh ↔ physics)

**Policy:** Visual meshes and gameplay collision should match. Implementation split by prop type:

| Prop class | Scene pattern | Collision bake |
|------------|---------------|----------------|
| **Mesh-only imports** (perimeter boulders, mesh props without physics) | No **`StaticBody3D`** in the imported scene | **Spawn-time trimesh** via [`playfield_bounds_3d.gd`](../../environment/playfield_bounds_3d.gd) [`ensure_obstacle_physics()`](../../environment/playfield_bounds_3d.gd) — [`PlayfieldPerimeterBoulders`](../../environment/playfield_perimeter_boulders.gd) calls this on spawn. **Do not** add placeholder static bodies on mesh-only imports or baking is skipped. |
| **Food shrubs** (`solid_shrub_3d`, `open_shrub_3d`) | Empty **`StaticBody3D`** / **`MobBlocker`** shell (layers per §6.2); no hand-authored placeholder spheres | **Convex hull from active visual** in [`bush_food_3d.gd`](../../assets/plants/bush_food_3d.gd) `_ready` / visual refresh via [`static_obstacle_collision.gd`](../../environment/static_obstacle_collision.gd). Calorie **`Area3D`** pickup sphere sized from the same visual AABB. |
| **Creatures** | **`CharacterBody3D`** capsule on **Body** (not mesh colliders) | Capsule radius/height + vertical center from mounted **Visual** mesh via [`creature_mesh_footprint.gd`](../../creature/capabilities/creature_mesh_footprint.gd) after [`creature_root_3d.gd`](../../creature/creature_root_3d.gd) mounts the species blend. |
| **Playfield floor** | Collision defines walkable bounds | Do **not** auto-match decorative grass mesh padding — bounds come from floor colliders ([`playfield_bounds_3d.gd`](../../environment/playfield_bounds_3d.gd)). |

**Helper module:** [`static_obstacle_collision.gd`](../../environment/static_obstacle_collision.gd) — convex blocker sync + pickup sphere fit. **Boulders** use **trimesh** (accurate static rock); **shrubs** use **convex hull** (cheaper, fewer snags).

### 6.4 Randomized playfield spawn layout (interior boulders / food / duel pair)

**Purpose:** a deliberate clutter stress test, **not** gameplay balancing — every run randomizes the 18 interior boulders, the 5 food shrubs (3 solid + 2 open), and the herbivore/carnivore duel pair, so the movement / memory / goals engines have to cope with realistic (sometimes overlapping) prop layouts instead of the hand-tuned fractions **`main_3d.gd`** shipped with previously. **Perimeter boulders are unaffected** — still procedurally placed along the edge by [`playfield_perimeter_boulders.gd`](../../environment/playfield_perimeter_boulders.gd) exactly as before.

**Overlap policy (intentional asymmetry):**
- **Interior boulders and food** (`_SpawnRandomizer.pick_uniform_fraction`) are pure uniform-random within the edge margin — **no** mutual-separation or terrain-depression check. They may overlap each other or land in awkward terrain on purpose.
- **Creature spawns only** (`_SpawnRandomizer.pick_clear_fraction`, and the `rng`/`existing_points` overload of [`PlayfieldGroundSampler.pick_duel_spawn_fractions()`](../../environment/playfield_ground_sampler.gd)) reject candidates too close to already-placed boulders/food or below the existing depression-safety threshold, so a creature never spawns embedded in a prop or on terrain that risks the C9/C10 tunneling class of bug.

**Config** (`game_config.json` → `playfield_spawn`, merged via [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd)):

| Key | Default | Meaning |
|-----|---------|---------|
| `seed` | `0` | `0` draws a fresh OS-random seed each run; nonzero is accepted but not the primary lock mechanism (see below). |
| `locked_layout_path` | `""` (empty) | Non-empty `res://`/`user://` path → skip randomization entirely and load fractions verbatim from that JSON file. |

**Locations file:** every resolved layout is written (debug builds only, `res://` is otherwise read-only) to **`res://spawn_layout_last_run.json`** — overwritten on every `_build_playfield()` (world objects) and every `new_game()` (duel pair re-roll). Format: `{"seed": int, "interior_boulders": [[fx,fy], ...], "solid_shrubs": [...], "open_shrubs": [...], "herbivore": [fx,fy], "carnivore": [fx,fy]}`.

**Lock workflow (freeze a buggy layout until it's root-caused):**
1. Reproduce the bug.
2. Copy `spawn_layout_last_run.json` to a descriptive name, e.g. `spawn_layout_locked_<bug>.json`.
3. Set `playfield_spawn.locked_layout_path` in `game_config.json` (or a `user://game_config.json` override, to avoid dirtying the committed default) to that path.
4. Commit the locked file if the repro should be shareable across machines.
5. Every run now loads that exact layout — boulders, food, and the duel pair — until the path is cleared.

**Key files:** [`playfield_spawn_randomizer.gd`](../../environment/playfield_spawn_randomizer.gd) (pick + serialize/parse helpers, no scene/physics dependency — independently unit-tested), [`playfield_ground_sampler.gd`](../../environment/playfield_ground_sampler.gd) `pick_duel_spawn_fractions()` (optional `rng`/`existing_points` params layered on the existing elevation-rim/no-depression filtering), `main_3d.gd` `_init_spawn_layout()` / `_spawn_interior_boulders()` / `_ensure_food_plants()` / `_spawn_duel_pair()` / `_write_spawn_layout_file()` / `_load_spawn_layout_file()`.

**Testing:** this is a deliberate clutter stress test of the movement/memory/goals engines (§6.4 above) — issues found while running with randomized spawn are tracked in [CREATURE_MOVEMENT_V3_RANDOMTESTS.md](../Draft_Features/CREATURE_MOVEMENT_V3_RANDOMTESTS.md), not in this file.

---

## 7. Acceptance criteria

- [x] **`project.godot`** lists **`3d_physics/layer_*`** names for bits used in §6.1 (at minimum **1, 2, 4, 8**).  
- [x] **Carnivore** `collision_mask` **ORs** in **`plant_mob_block`** (`8`) when Food B is present (target **`9`**).  
- [ ] **Food B** scene root (or shared plant README under **`res://assets/plants/open_shrub/`**) carries a **short comment** pointing to this **§6** table.  
- [ ] `crush_weight == 0` semantics documented in code comments (unchanged — future crush phase).

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Double-penalty (plant + terrain) | Single “effective modifier” merge function |
| Pathfinding without navmesh | **Partially addressed:** [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) scopes **2D** mob detour + rejoin; **full navmesh** still optional future work |

---

## 9. Testing / verification

**Manual steps:**  
- Walk creature through water / brush vs open ground.

**Automated (if any):**  
- Pure function tests for modifier merge.

---

## 10. Open questions

- **Deferred:** **3D physics layers shipped** (§6). **Height / volumetric crush** still out of scope for [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md); revisit in a dedicated phase ([CONVERT_TO_3D.md](../Completed_Features/CONVERT_TO_3D.md) M4).

---

## 11. Future / deferred carryovers (OBJECT plan)

**Purpose:** [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) now lives under **Completed_Features**; this section keeps **deferred** policy and comment-thread intent in an **active** doc. Cross-check the archived OBJECT file for full prose; here is the **checklist** implementers should not lose.

### Perception & awareness (post–cardinal v1)

- **Line-of-sight / occlusion:** Environment props that **block vision** should eventually reduce confidence or range for mobs **behind** them (facing / sampling cone). **Not** part of OBJECT §8.2 v1; lands with a dedicated **FOV / perception** phase. If LOS later hides mobs from the motor snapshot, **nearby threat** implicitly follows **perceived** mobs only (same as motor today until changed).
- **Silhouette vs unexplored:** v1 uses **one** motor bucket for unknown interior; splitting **silhouette** (seen outline, passibility unknown) from **unexplored** waits on richer perception / LOS (OBJECT §8.2.5).

### Experiential learning (`terrain_kind_id`)

- **Squeezes:** Until a kind is learned, planners may treat **`passible == false`** façades as **fully costly / opaque** even when **Mode A** could allow a squeeze for this **`creature_size`**. Discovering a valid squeeze for kind **`K`** updates memory keyed **`(creature, terrain_kind_id == K)`**; physics **`can_enter`** stays authoritative at runtime.
- **Slowdown (`movement_impact`):** Under-weight **`movement_impact`** in **utility / planning** until the creature has **experienced** that **`terrain_kind_id`** (first entry, **N ticks — TBD**). Hard illegality (`can_enter == false` with no learned squeeze) stays absolute.
- **Sub-keys:** Separate memories for **squeeze affordance** vs **slowdown curves** may share one ID space or use **sub-keys** — **TBD** at implementation; invariant: **mud ≠ deep_snow ≠ squeeze-rock-wall-kind** so lessons do not cross-contaminate (see §4 **`terrain_kind_id`** row).

### Motor / grid sampling (deferred refinements)

- **Center vs overlap:** **M4 shipped** — motor uses **≥ 25%** circle–cell overlap ([`environment_footprint_sampler.gd`](../../environment/environment_footprint_sampler.gd)), not center-cell only.
- **Sustained slow heuristic:** **≥ 25%** footprint overlap with slow region counts as “inside” for lookahead; **retune** if playtests disagree.
- **Merge precedence (M4):** greatest impact first — impassible beats slowdowns; highest `movement_impact` wins ([`environment_movement_impact.gd`](../../environment/environment_movement_impact.gd)).
- **Passible probe:** **≥ 1 logical pixel** overlap promotes **unknown → known** for passible (including slow) before **25%** dominates — tie **1px** to smallest **`cell_size_px`**.
- **Multi-cell slowdown:** **min** of per-cell multipliers (**worst impact wins**); not multiplicative combine.
- **Mode A squeeze + `movement_impact`:** Inside **`passible == false`** squeeze, active **`movement_impact`** applies to **all** legal occupants — **no** Mode B-style **`< fit_size`** small-body exemption **unless** a future spec adds it (OBJECT §3.5–§3.6).
- **Numeric compares:** Plain float compares unless the project adopts a shared **epsilon**; coerce TileMap **`int`** **`fit_size`** to **`float`** at boundaries (OBJECT §3.5).

### Memory, observation, and config knobs

- **Interior belief on creature; persistence:** Runtime store on the creature is specified for OBJECT phase; **save-game persistence** for that belief is **explicitly future**.
- **Ghost / stale mob positions:** Conservative updates if observation **contradicts** estimates; stable feature id **`terrain_kind_id` + `instance_id`** + grid fallbacks (OBJECT §8.2.3).
- **Optional headless `can_enter` probes:** Faster learning without physical “bump” — **parking lot**, not OBJECT v1 (see [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md)).
- **Low vs high mob-threat bands:** Single threshold or hysteresis pair in `GameConfig` / **`creature_motor`** — values **TBD** at tuning (OBJECT §8.2.5).
- **Slow vs unknown merge (no stronger stimuli):** After bounded **L / R / through** detours and **`awareness_memory_ticks`** patience, pick **one** convention in code: **additive** costs vs **weighted lexicographic** — **not** `max` alone; weights **TBD** (OBJECT §8.2.5).
- **`awareness_memory_ticks` vs `env_detour_patience_ticks`:** v1 **reuses** one knob for mob ghosts and env detour patience; **split** if coupled behavior causes problems ([ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md)).

### Authoring & metadata

- **Body-first:** Physics / collision **`can_enter`** is authoritative; grid is advisory. **Interior cells missing metadata** default **`passible == false`** (conservative) except **playfield edge** treatment per OBJECT §8.2.
- **Multi-layer bake:** When multiple images or channels feed one logical grid, **document merge order** at bake time (OBJECT §8.1 **Limits**).

### Optional future gates

- **`env_threat_radius`:** OBJECT §8.2 v1 uses **existing** snapshot proximity only — **no** extra radius gate unless a later phase adds one.

---

## 12. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-08-08 | **§6.4 (new):** Randomized interior boulder / food / duel-pair spawn (perimeter boulders unaffected) with a lockable `spawn_layout_last_run.json` repro file; `game_config.json` gained `playfield_spawn` (`seed`, `locked_layout_path`). Deliberate stress test — boulders/food may overlap, only creature spawns get overlap-avoidance. |
| 2026-06-08 | **§6:** Promoted to **3D** layer/mask table (`3d_physics`, kinematic duel templates, `*_shrub_3d.tscn`); §2 context + §7 acceptance updated (M3). |
| 2026-05-14 | **§6:** Godot **2D layer/mask split (Option A)** for **`solid_shrub`** / **`open_shrub`**; mob mask **`9`**; renumbered §6→§12. Tracking: physics table **Specified**. |
| 2026-05-12 | §10: Mode A / float policy; silhouette vs unexplored. |
| 2026-05-12 | §10: consolidated **future / deferred** checklist from OBJECT (perception, experiential memory, sampling, config, authoring); §11 changelog renumber; tracking table rows. |
| 2026-05-12 | Tracking: §8.2 motor spec expanded (belief, memory, LOS future). |
| 2026-05-12 | Catalog + architecture: Mode B shrub semantics; `movement_speed_multiplier`; experiential squeezes in OBJECT §10. |
| 2026-05-12 | Tracking: §8 placement/motor outstanding; §10 future experiential learning; reserved `terrain_kind_id` in catalog. |
| 2026-05-12 | Property catalog aligned with OBJECT_AVOIDANCE_PLAN; `fit_size` row links §3.3–§3.3.1 (explicit implementer rules). |
| 2026-05-12 | Added implementation tracking table; linked `fit_size` / passibility work to OBJECT_AVOIDANCE_PLAN; flagged outstanding crush, layers, 3D. |
| 2026-05-11 | Extracted Environment abstract from EARLY_SPEC_DOC. |
