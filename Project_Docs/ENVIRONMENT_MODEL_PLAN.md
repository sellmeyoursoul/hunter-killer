# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

### Implementation tracking (quick glance)

| Topic | Status | Where |
|-------|--------|--------|
| **`passible`**, **`movement_impact`**, **`fit_size`**, mob detours, creature **`size`** (2D) | **Specified for implementation** | [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) |
| **Placement / boundaries / authoring** for env geometry | **Chosen:** palette PNGs in **`res://art/env/`** → bake → `EnvironmentGridBaked` (OBJECT §8.1) | [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §8.1 |
| **Player motor weights** (interior env + memory vs mobs; edges unchanged) | **Specified** — implement per OBJECT §8.2 | [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §8.2 |
| **`Experiential slowdown** + **`terrain_kind_id`** (learn per terrain kind; **includes squeeze exploration**) | **FUTURE** — not object-avoidance phase | [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §10; §4 `terrain_kind_id` |
| **`crush_weight`** destructible props | **NOT IMPLEMENTED** — future phase | §4 Property catalog; §5 step 3 |
| **`apply_movement_impact` / modifier merge** (shared helper) | Partially scoped — env side in object-avoidance plan; **plant + terrain merge** still **OUTSTANDING** | §5 step 1; §7 Risks |
| Physics **layer/mask mapping** table | **OUTSTANDING** | §6 Acceptance |
| **`crush_weight == 0`** semantics in code comments | **OUTSTANDING** (blocked until crush phase) | §6 Acceptance |
| **3D** height / volumetric crush | **OUTSTANDING / deferred** — keep **2D** until a future doc | §9 Open questions |
| Nice-to-have: **`Area2D` water** with non-linear drag | **OUTSTANDING** | §3 Nice to have |

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
- **Creature movement** queries tile under feet each physics tick (or on enter) to decide **`can_enter`** ([OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §3.5) and **`movement_speed_multiplier(creature_size, …)`** ([OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §3.6).

### Property catalog

| Property | Type | Meaning |
|----------|------|---------|
| `passible` | bool | **`true`:** **All** creatures may enter (**`fit_size`** does **not** gate entry). **`false`:** **Enterability** uses **`fit_size`** only (squeeze — Mode A in [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §3.3). |
| `movement_impact` | float (nullable) | Slowdown **strength**; effective penalty per creature uses **`movement_speed_multiplier(creature_size, env)`** (OBJECT §3.6). Applies on **`passible == true`** (everyone, or large-only when paired with Mode B **`fit_size`**) and inside **squeeze** cells when authored. |
| `fit_size` | float (nullable) | **Dual role** ([OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) §3.3): **Mode A** (`passible == false`) — **inclusive `<=`** squeeze entry; **`null`/`0`/invalid** ⇒ nobody enters. **Mode B** (`passible == true` + active **`movement_impact`** + valid **`fit_size > 0`**) — **strict `<`** exempts small creatures from slowdown; **`>=`** pays **`movement_impact`**. When **`passible == true`** and **`movement_impact`** inactive, ignore **`fit_size`** at runtime. |
| `terrain_kind_id` | StringName or int (nullable) | **FUTURE / not this phase** — Stable **category** ID so experiential memory distinguishes kinds (**mud**, **deep_snow**, **squeeze-rock-arch**, etc.); supports learned squeeze affordance vs slowdown (**OBJECT_AVOIDANCE_PLAN.md** §10). Nullable when unused. |
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

1. **OUTSTANDING (beyond object avoidance):** Extract shared `apply_movement_impact(creature, env_data)` when both plant underbrush and terrain use the same math — env-side helper is scoped in [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md); **plant merge** still TODO.  
2. **Specified for implementation:** Introduce tileset custom data or parallel grid for `passible` (+ `movement_impact`, `fit_size`) — see [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md).  
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
| Pathfinding without navmesh | **Partially addressed:** [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) scopes **2D** mob detour + rejoin; **full navmesh** still optional future work |

---

## 8. Testing / verification

**Manual steps:**  
- Walk creature through water / brush vs open ground.

**Automated (if any):**  
- Pure function tests for modifier merge.

---

## 9. Open questions

- **Deferred:** <<Question: 2D top-down only, or future 3D height for crush?>> — **3D out of scope** for [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md); revisit when a dedicated phase addresses height/crush.

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-12 | Tracking: §8.2 motor spec expanded (belief, memory, LOS future). |
| 2026-05-12 | Catalog + architecture: Mode B shrub semantics; `movement_speed_multiplier`; experiential squeezes in OBJECT §10. |
| 2026-05-12 | Tracking: §8 placement/motor outstanding; §10 future experiential learning; reserved `terrain_kind_id` in catalog. |
| 2026-05-12 | Property catalog aligned with OBJECT_AVOIDANCE_PLAN; `fit_size` row links §3.3–§3.3.1 (explicit implementer rules). |
| 2026-05-12 | Added implementation tracking table; linked `fit_size` / passibility work to OBJECT_AVOIDANCE_PLAN; flagged outstanding crush, layers, 3D. |
| 2026-05-11 | Extracted Environment abstract from EARLY_SPEC_DOC. |
