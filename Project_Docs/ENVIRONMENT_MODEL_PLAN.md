# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

### Implementation tracking (quick glance)

| Topic | Status | Where |
|-------|--------|--------|
| **`passible`**, **`movement_impact`**, **`fit_size`**, mob detours, creature **`size`** (2D) | **Specified for implementation** | [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) |
| **Placement / boundaries / authoring** for env geometry | **Chosen:** palette PNGs in **`res://art/env/`** → bake → `EnvironmentGridBaked` (OBJECT §8.1) | [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.1 |
| **Player motor weights** (interior env + memory vs mobs; edges unchanged) | **Specified** — implement per OBJECT §8.2 | [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2 |
| **Experiential slowdown** + **`terrain_kind_id`** (learn per terrain kind; **includes squeeze exploration**) | **FUTURE** — not object-avoidance phase | §10 (carry-forward); archived OBJECT §10; §4 `terrain_kind_id` |
| **`crush_weight`** destructible props | **NOT IMPLEMENTED** — future phase | §4 Property catalog; §5 step 3 |
| **`apply_movement_impact` / modifier merge** (shared helper) | Partially scoped — env side in object-avoidance plan; **plant + terrain merge** still **OUTSTANDING** | §5 step 1; §7 Risks |
| Physics **layer/mask mapping** table | **OUTSTANDING** | §6 Acceptance |
| **`crush_weight == 0`** semantics in code comments | **OUTSTANDING** (blocked until crush phase) | §6 Acceptance |
| **3D** height / volumetric crush | **OUTSTANDING / deferred** — keep **2D** until a future doc | §9 Open questions |
| Nice-to-have: **`Area2D` water** with non-linear drag | **OUTSTANDING** | §3 Nice to have |
| **Per-creature interior env belief — save-game persistence** | **FUTURE** | OBJECT §8.2.3 (memory on creature; persistence OOS) — §10 |
| **Multi-layer palette / image → grid merge order** | **Document at bake time** | OBJECT §8.1 limits — §10 |
| **Footprint: polygon–cell overlap vs center-only** | **FUTURE** (3D / mesh sampling) | OBJECT §9 — §10 |
| **`env_detour_patience_ticks`** vs shared **`awareness_memory_ticks`** | **FUTURE** if coupling hurts | OBJECT §8.2.5 — §10; [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) |
| **Silhouette vs unexplored** second motor bucket + LOS on snapshot | **FUTURE** (perception / FOV) | OBJECT §8.2.5 comments; OBJECT §10 — §10 |

---

## 1. Phase summary

**Phase name:** Environment model (terrain / props abstraction)

**One-line objective:** Define the shared **environment** abstraction (passibility, movement slowdown, size/weight gates, crush limits) for stone, dirt, water, dense brush, etc., so creatures and plants can share collision-response rules later.

**Out of scope (explicit non-goals):**  
- Full voxel or heightmap world in early phases.  
- Fluid simulation.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/dodge-the-creeps`

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** TBD—likely tilemap layers or `StaticBody2D` tiles under `Main`.

**Key scripts (paths):**  
- Future: `environment_tile.gd`, `EnvironmentData` Resource, or tile metadata.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)  
- Align numeric semantics with [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) for `movement_impact`, `fit_size`, `crush_weight` where possible (shared helper).

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

- Physics layers: environment vs creature vs projectile—table when implementing.

### Dependencies

- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) for `size` / `weight` on creatures.

---

## 5. Implementation plan (ordered)

1. **OUTSTANDING (beyond object avoidance):** Extract shared `apply_movement_impact(creature, env_data)` when both plant underbrush and terrain use the same math — env-side helper is scoped in [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md); **plant merge** still TODO.  
2. **Specified for implementation:** Introduce tileset custom data or parallel grid for `passible` (+ `movement_impact`, `fit_size`) — see [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md).  
3. **OUTSTANDING:** Wire crush detection for destructible props (`crush_weight`).

---

## 6. Acceptance criteria

- [ ] First implementation phase lists Godot layer/mask mapping.  
- [ ] `crush_weight == 0` semantics documented in code comments.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Double-penalty (plant + terrain) | Single “effective modifier” merge function |
| Pathfinding without navmesh | **Partially addressed:** [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) scopes **2D** mob detour + rejoin; **full navmesh** still optional future work |

---

## 8. Testing / verification

**Manual steps:**  
- Walk creature through water / brush vs open ground.

**Automated (if any):**  
- Pure function tests for modifier merge.

---

## 9. Open questions

- **Deferred:** <<Question: 2D top-down only, or future 3D height for crush?>> — **3D out of scope** for [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md); revisit when a dedicated phase addresses height/crush.

---

## 10. Future / deferred carryovers (OBJECT plan)

**Purpose:** [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) now lives under **Completed_Features**; this section keeps **deferred** policy and comment-thread intent in an **active** doc. Cross-check the archived OBJECT file for full prose; here is the **checklist** implementers should not lose.

### Perception & awareness (post–cardinal v1)

- **Line-of-sight / occlusion:** Environment props that **block vision** should eventually reduce confidence or range for mobs **behind** them (facing / sampling cone). **Not** part of OBJECT §8.2 v1; lands with a dedicated **FOV / perception** phase. If LOS later hides mobs from the motor snapshot, **nearby threat** implicitly follows **perceived** mobs only (same as motor today until changed).
- **Silhouette vs unexplored:** v1 uses **one** motor bucket for unknown interior; splitting **silhouette** (seen outline, passibility unknown) from **unexplored** waits on richer perception / LOS (OBJECT §8.2.5).

### Experiential learning (`terrain_kind_id`)

- **Squeezes:** Until a kind is learned, planners may treat **`passible == false`** façades as **fully costly / opaque** even when **Mode A** could allow a squeeze for this **`creature_size`**. Discovering a valid squeeze for kind **`K`** updates memory keyed **`(creature, terrain_kind_id == K)`**; physics **`can_enter`** stays authoritative at runtime.
- **Slowdown (`movement_impact`):** Under-weight **`movement_impact`** in **utility / planning** until the creature has **experienced** that **`terrain_kind_id`** (first entry, **N ticks — TBD**). Hard illegality (`can_enter == false` with no learned squeeze) stays absolute.
- **Sub-keys:** Separate memories for **squeeze affordance** vs **slowdown curves** may share one ID space or use **sub-keys** — **TBD** at implementation; invariant: **mud ≠ deep_snow ≠ squeeze-rock-wall-kind** so lessons do not cross-contaminate (see §4 **`terrain_kind_id`** row).

### Motor / grid sampling (deferred refinements)

- **Center vs overlap:** v1 uses **footprint center** → cell for `can_enter` / `movement_speed_multiplier`; **full polygon–cell overlap** deferred until **3D** or mesh-based terrain sampling (OBJECT §9).
- **Sustained slow heuristic:** **≥ 25%** footprint overlap with slow region counts as “inside” for lookahead; **retune** if playtests disagree.
- **Passible probe:** **≥ 1 logical pixel** overlap promotes **unknown → known** for passible (including slow) before **25%** dominates — tie **1px** to smallest **`cell_size_px`**.
- **Multi-cell slowdown:** **min** of per-cell multipliers (**worst impact wins**); not multiplicative combine.
- **Mode A squeeze + `movement_impact`:** Inside **`passible == false`** squeeze, active **`movement_impact`** applies to **all** legal occupants — **no** Mode B-style **`< fit_size`** small-body exemption **unless** a future spec adds it (OBJECT §3.5–§3.6).
- **Numeric compares:** Plain float compares unless the project adopts a shared **epsilon**; coerce TileMap **`int`** **`fit_size`** to **`float`** at boundaries (OBJECT §3.5).

### Memory, observation, and config knobs

- **Interior belief on creature; persistence:** Runtime store on the creature is specified for OBJECT phase; **save-game persistence** for that belief is **explicitly future**.
- **Ghost / stale mob positions:** Conservative updates if observation **contradicts** estimates; stable feature id **`terrain_kind_id` + `instance_id`** + grid fallbacks (OBJECT §8.2.3).
- **Optional headless `can_enter` probes:** Faster learning without physical “bump” — **parking lot**, not OBJECT v1 (see [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md)).
- **Low vs high mob-threat bands:** Single threshold or hysteresis pair in `GameConfig` / **`creature_motor`** — values **TBD** at tuning (OBJECT §8.2.5).
- **Slow vs unknown merge (no stronger stimuli):** After bounded **L / R / through** detours and **`awareness_memory_ticks`** patience, pick **one** convention in code: **additive** costs vs **weighted lexicographic** — **not** `max` alone; weights **TBD** (OBJECT §8.2.5).
- **`awareness_memory_ticks` vs `env_detour_patience_ticks`:** v1 **reuses** one knob for mob ghosts and env detour patience; **split** if coupled behavior causes problems ([ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md)).

### Authoring & metadata

- **Body-first:** Physics / collision **`can_enter`** is authoritative; grid is advisory. **Interior cells missing metadata** default **`passible == false`** (conservative) except **playfield edge** treatment per OBJECT §8.2.
- **Multi-layer bake:** When multiple images or channels feed one logical grid, **document merge order** at bake time (OBJECT §8.1 **Limits**).

### Optional future gates

- **`env_threat_radius`:** OBJECT §8.2 v1 uses **existing** snapshot proximity only — **no** extra radius gate unless a later phase adds one.

---

## 11. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-12 | §10: Mode A / float policy; silhouette vs unexplored. |
| 2026-05-12 | §10: consolidated **future / deferred** checklist from OBJECT (perception, experiential memory, sampling, config, authoring); §11 changelog renumber; tracking table rows. |
| 2026-05-12 | Tracking: §8.2 motor spec expanded (belief, memory, LOS future). |
| 2026-05-12 | Catalog + architecture: Mode B shrub semantics; `movement_speed_multiplier`; experiential squeezes in OBJECT §10. |
| 2026-05-12 | Tracking: §8 placement/motor outstanding; §10 future experiential learning; reserved `terrain_kind_id` in catalog. |
| 2026-05-12 | Property catalog aligned with OBJECT_AVOIDANCE_PLAN; `fit_size` row links §3.3–§3.3.1 (explicit implementer rules). |
| 2026-05-12 | Added implementation tracking table; linked `fit_size` / passibility work to OBJECT_AVOIDANCE_PLAN; flagged outstanding crush, layers, 3D. |
| 2026-05-11 | Extracted Environment abstract from EARLY_SPEC_DOC. |
