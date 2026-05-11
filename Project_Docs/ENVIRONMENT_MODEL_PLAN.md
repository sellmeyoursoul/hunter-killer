# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

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
- **Creature movement** queries tile under feet each physics tick (or on enter) to apply speed multiplier and block transitions when `passible == false`.

### Property catalog

| Property | Type | Meaning |
|----------|------|---------|
| `passible` | bool | If false, creatures cannot enter (solid). |
| `movement_impact` | float | % speed reduction while inside (0 = no penalty). |
| `fit_size` | float | Creatures with **size** below this threshold ignore `movement_impact` (or reduced penalty—<<Question: clarify exclusive vs inclusive threshold>>). |
| `crush_weight` | float | Creature **weight** above this destroys this environment piece; `0` = unbreakable by crush rules. |

### Methods

- None required at abstract level for POC; concrete tiles may use Godot signals (`body_entered`).

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create (future) | `res://environment/...` | When phase references this doc |

### Collision / input / signals (if relevant)

- Physics layers: environment vs creature vs projectile—table when implementing.

### Dependencies

- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) for `size` / `weight` on creatures.

---

## 5. Implementation plan (ordered)

1. Extract shared `apply_movement_impact(creature, env_data)` when both plant underbrush and terrain use the same math.  
2. Introduce tileset custom data or parallel grid for `passible`.  
3. Wire crush detection for destructible props.

---

## 6. Acceptance criteria

- [ ] First implementation phase lists Godot layer/mask mapping.  
- [ ] `crush_weight == 0` semantics documented in code comments.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Double-penalty (plant + terrain) | Single “effective modifier” merge function |
| Pathfinding without navmesh | Defer pathfinding until passibility grid exists |

---

## 8. Testing / verification

**Manual steps:**  
- Walk creature through water / brush vs open ground.

**Automated (if any):**  
- Pure function tests for modifier merge.

---

## 9. Open questions

- <<Question: 2D top-down only, or future 3D height for crush?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Extracted Environment abstract from EARLY_SPEC_DOC. |
