# Hunter Killer — Object avoidance & terrain gates (agent-friendly)

**Parent design:** [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) — this document narrows scope to **2D** locomotion: squeeze (**Mode A**, **`passible == false`**), shrubs / brush (**Mode B**, **`passible == true`** + **`movement_impact`** + **`fit_size`**), mob detours, and **`movement_speed_multiplier(creature_size, env)`**. It does **not** supersede the parent catalog; it pins semantics left open there.

**Post-archive carry-forward:** When this plan moves to **Completed_Features**, keep **deferred** policy and `<<Comment>>` follow-ups alive in active docs: [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) §10 (consolidated list), [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md) (parking-lot items), [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) (motivation ↔ motor), [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §9 (AI parity).

**Explicitly out of scope here:**  
- `crush_weight` and destructible environment — remains in the parent doc for a later phase.  
- **3D** height, stacking, or volumetric crush — **2D top-down / screen-plane only** until a future doc says otherwise.

---

## 1. Phase summary

**Phase name:** Object avoidance — passibility grid, mob detours, difficult terrain, creature size

**One-line objective:** Represent environment cells with **`passible`**, **`movement_impact`**, and **`fit_size`** where **`fit_size`** gates **entry** on **`passible == false`** (squeeze) and gates **who pays `movement_impact`** on **`passible == true`** when **`movement_impact > 0`** (shrubs / brush — small bodies exempt); give **player** and **mob** a **`creature_size`**; drive **mob** around **`can_enter == false`** cells and **rejoin** baseline intent; apply **`movement_speed_multiplier(creature_size, env)`** (§3.6) in physics.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (Godot project root containing `project.godot`)

**Engine & version:** Godot 4.6.x (match `project.godot`)

**Relevant existing behavior:**  
- Mobs are spawned with a velocity along a spawn tangent ([`main.gd`](../main.gd)); there is **no** environment-aware pathing yet.  
- Player movement is intent × speed with viewport clamp ([`player.gd`](../player.gd)).  
- Scripted creature motor minimizes geometric cost vs mobs ([`creature/motor/cardinal_avoidance.gd`](../creature/motor/cardinal_avoidance.gd)); environment modifiers are additive future work.

**Align with:**  
- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — `size` / `weight` catalog (`weight` unused here).  
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)

---

## 3. Semantic contract (authoritative for this phase)

Enterability and slowdown are evaluated in this order: **can the creature occupy the cell?** (`can_enter`, §3.5) → **if yes, what is the movement multiplier?** (`movement_speed_multiplier`, §3.6).

### 3.1 `passible` (bool)

- **`passible == true`:** **Every** creature may enter and occupy the cell (`can_enter` is always **true**). **`fit_size`** never blocks entry; it may still affect **`movement_impact`** via the **shrub / brush** pattern (§3.3 Mode B).  
- **`passible == false`:** Closed terrain; **`fit_size`** gates **squeeze-through** entry (§3.3 Mode A). **Nobody** enters if **`fit_size`** is **`null`**, **`0`**, or invalid; otherwise **`creature_size <= fit_size`** (**inclusive**) may enter.

### 3.2 `movement_impact` (nullable float)

- **Meaning:** Authored **slowdown strength**. Whether it **actually reduces speed** for a given creature depends on **`passible`**, **`fit_size`**, and **`creature_size`** — see **`movement_speed_multiplier`** (§3.6), not raw comparison to **`movement_impact`** alone.  
- **`null` or `0`:** No slowdown from this field for anyone.  
- **Formula:** Implement one convention in code (e.g. multiplier **`1.0 - movement_impact`**) inside **`movement_speed_multiplier`** only.  
- **Ambiguous or extreme values:** If authoring or code leaves behavior unclear, apply the interpretation that **reduces speed most** (use the **lowest** lawful **`movement_speed_multiplier`** / strongest slowdown). Clamp so the result stays in **`(0, 1]`** (e.g. cap raw **`movement_impact`** or clamp **`1.0 - mi`** so speed never inverts or hits **0** unless explicitly desired).

### 3.3 `fit_size` (nullable float) — **two modes** (do not confuse)

Use one numeric **`fit_size`** field; meaning depends on **`passible`**:

| Mode | When | Role of `fit_size` | Comparison rule |
|------|------|-------------------|----------------|
| **A — Squeeze (solid / gap)** | **`passible == false`** | **Enterability only:** who may move **into** the cell | **`creature_size <= fit_size`** ⇒ **may enter** (**inclusive**). **`null` / `0` / invalid** ⇒ **nobody** enters. |
| **B — Shrubs / brush** | **`passible == true`** **and** **`movement_impact > 0`** **and** **`fit_size > 0`** (valid) | **Slowdown only:** everyone **enters**; small creatures **skip** **`movement_impact`** | **`creature_size < fit_size`** ⇒ **no** **`movement_impact`** penalty. **`creature_size >= fit_size`** ⇒ penalty **applies** (think mice through shrubs; large bodies tangled). |

**Mode B eligibility:** If **`passible == true`** but **`movement_impact`** is **`null`/`0`**, **ignore** **`fit_size`** for runtime (no penalty to modulate). Authoring may still store **`fit_size`** for tooling; **`movement_speed_multiplier`** returns **`1.0`**.

**Mode A vs B summary:** **Same field name, different jobs:** **Impossible wall vs squeeze** uses **Mode A** (`passible == false`). **Open tile with optional small-creature immunity to slowdown** uses **Mode B** (`passible == true` + active **`movement_impact`** + positive **`fit_size`**).

**Invalid `fit_size`:** **`null`**, **`≤ 0`**, **NaN**, non-numeric ⇒ **Mode A:** treat as **fully blocked**. **Mode B:** treat **`fit_size`** as **not valid for exemption** ⇒ **`movement_impact`** applies to **all** sizes (same as open mud).

**⚠️ Asymmetry (implementation trap):** Squeeze **entry** uses **`<= fit_size`** (**inclusive**). Shrub **exemption** uses **`< fit_size`** (**strict**). Document and unit-test both.

#### 3.3.1 Implementation rules (explicit — avoid branch bugs)

1. **`can_enter`:** If **`passible == true`** ⇒ **true** (do **not** use **`fit_size`** here). If **`passible == false`** ⇒ Mode A squeeze rules only (**§3.5**).  
2. **`movement_speed_multiplier`:** Always compute **after** **`can_enter`**; only called when the creature **occupies** the cell legally. Implement **§3.6** once; never scatter ad-hoc **`movement_impact`** checks.  
3. **Mode B:** Only exempt from penalty when **`passible == true`**, **`movement_impact`** active, **`fit_size`** valid **`> 0`**, and **`creature_size < fit_size`**.  
4. **Squeeze tile occupied:** If **`movement_impact`** is active, apply penalty to **all** creatures legally inside via Mode A (**no** shrub-style **`< fit_size`** exemption on **`passible == false`** unless a future spec adds it).  
5. **Floating-point:** plain comparisons unless the project adopts epsilon; coerce TileMap **`int`** **`fit_size`** to **`float`**.

**Anti-patterns (forbidden):**

- Using **`fit_size`** for **`can_enter`** when **`passible == true`**.  
- Using **inclusive `<=`** for shrub exemption (**must** be **strict `<`** per Mode B).  
- Treating **`fit_size == 0`** on **`passible == false`** as “everyone fits.”

**Hiding / asymmetry (authoring):** Mode A: **`passible == false`**, **`fit_size`** between player and mob sizes ⇒ **player-only squeeze**. Mode B: **`passible == true`**, **`movement_impact`**, **`fit_size`** above player but below mob ⇒ player avoids shrub slowdown, mob does not (example — tune to your **`creature_size`** scale).

### 3.4 Creature `creature_size` (float)

- Single scalar per creature for **this phase** (align naming with `CREATURE_MODEL_PLAN.md` **`size`** field when wiring exports / resources).  
- **Requirement:** **Player `creature_size` < Mob `creature_size`** enables **Mode A** squeeze-only gaps and **Mode B** shrub tiles where the player can be **under** **`fit_size`** while the mob is **not** (tune numeric **`fit_size`** to match §3.3).  
- Values are **author-tuned** (Godot units / abstract tiles — pick one scheme in implementation and document in code comments).

### 3.5 Reference: `can_enter(creature_size, env)` (spec pseudocode)

**Enterability only.** Does **not** implement shrub slowdown (§3.6).

Logical equivalent (must match §3.3.1):

```text
if env.passible:
  return true   # Mode B never blocks entry
# passible == false — Mode A squeeze only
if env.fit_size == null or env.fit_size <= 0 or is_nan(env.fit_size):
  return false
return creature_size <= env.fit_size   # inclusive squeeze
```

**Godot-shaped sketch** (illustrative — adapt types to your `EnvironmentData`):

```gdscript
## Returns whether a creature of the given size may enter this environment cell.
## Params:
## - creature_size: Same units as env.fit_size (see §3.3).
## - env: Tile/env metadata per OBJECT_AVOIDANCE_PLAN §3.
static func can_enter(creature_size: float, env: EnvironmentData) -> bool:
  if env.passible:
    return true
  var fs: Variant = env.fit_size
  if fs == null:
    return false
  var fit_f: float
  match typeof(fs):
    TYPE_FLOAT:
      fit_f = fs as float
    TYPE_INT:
      fit_f = float(fs as int)
    _:
      return false
  if is_nan(fit_f) or fit_f <= 0.0:
    return false
  return creature_size <= fit_f
```

### 3.6 Reference: `movement_speed_multiplier(creature_size, env)` (spec pseudocode)

Called only when the creature **occupies** the cell legally. Pick one penalty formula in code (example: **`1.0 - movement_impact`**).

```text
mi = env.movement_impact
if mi == null or mi == 0:
  return 1.0
# Mode B — shrub / brush: small creatures exempt (strict < fit_size)
if env.passible:
  fs = env.fit_size (coerced; invalid / null / <= 0 / nan => not Mode B)
  if fs > 0 and creature_size < fs:
    return 1.0
# Open mud (passible, no valid fs), large creatures in shrubs, squeeze occupants
return (1.0 - mi)
```

**Encoded behavior:**

- **`passible == true`**, **`movement_impact`** active, **`fit_size`** valid **`> 0`**, **`creature_size < fit_size`** ⇒ multiplier **`1.0`** (**strict `<`**).  
- **`passible == true`**, **`movement_impact`** active, **`fit_size`** **not** valid **`> 0`** ⇒ penalty for **all** sizes.  
- **`passible == false`** (squeeze): **`movement_impact`** active ⇒ penalty for **all** who entered (**no** shrub exemption).  
- **Multiple overlapping cells:** For each cell the creature’s footprint counts as **inside** (§9), compute **`movement_speed_multiplier(creature_size, env)`** with this section, then use **min** of those values — **strongest slowdown wins** (e.g. **0.7** vs **0.5** ⇒ **0.5**). **Not** multiplicative stacking across cells.

---

## 4. Mob pathing behavior (2D)

**Goal:** When the mob’s **intended** trajectory would cross a cell **`can_enter` is false** for that mob’s **`creature_size`** (§3.5 — e.g. **`passible == false`** with **`fit_size`** null/**`0`**, or **`creature_size > fit_size`** on a squeeze tile), **steer around** using **local 2D** reasoning (tangential slide, short lookahead, or lightweight grid A* on a coarse **enterability mask** — implementation choice).

**Return to original path:** After clearance, **blend back** to the **prior global intent** (saved direction or path parameter) so behavior does not permanently drift — define a small **rejoin distance** or **timer** in implementation so oscillation is bounded.

**Scope note:** Full navmesh / multi-agent global planning is **not** required for v1 of this doc; **correct avoidance of solids for the mob’s size** + **rejoin** is sufficient.

---

## 5. Technical design sketch

| Concern | Direction |
|--------|-----------|
| Data source | TileMap **custom data**, parallel `Dictionary` grid keyed by cell, or **`EnvironmentData` Resource** referenced per cell — matches parent §4 architecture. |
| Queries | **`environment_query(cell)`** plus **`can_enter(creature_size, data)`** (§3.5) and **`movement_speed_multiplier(creature_size, data)`** (§3.6). |
| Player | **`CharacterBody2D`** (future **`CharacterBody3D`**) with **`move_and_slide()`** vs blocking geometry; apply **`movement_speed_multiplier`** from §3.6; multiply by the **minimum** multiplier across cells per §9 — **not** raw **`movement_impact`** alone. **Do not** reimplement slide/clamp on **`Area2D`** (see §5.1). |
| Mob | **RigidBody2D** or **`CharacterBody2D`** migration is an implementation detail; avoidance must respect **same enterability rules** as the player. |
| Tests | **`can_enter`** (Modes A/B entry); **`movement_speed_multiplier`** (open mud, shrub **`< fit_size`**, shrub **`>= fit_size`**, squeeze + **`movement_impact`**, **multi-cell min**); regression on **inclusive squeeze `<=`** vs **strict shrub `<`**. |

### 5.1 Player body & 3D-ready movement (Godot)

**Required:** Implement the player (and any creature that **walks through** **`passible == false`** / squeeze volumes) as **`CharacterBody2D`** with **`move_and_slide()`** for 2D, or **`CharacterBody3D`** with **`move_and_slide()`** when the project moves to 3D — **do not** reimplement penetration resolution, sliding along walls, or floor snapping with **`Area2D`** + manual position hacks; that duplicates Godot’s built-in kinematic behavior and drifts from engine upgrades.

**`Area2D`** remains appropriate for **pure overlap** roles (pickups, triggers, hit detection) on sibling nodes if needed, but **locomotion** against static env uses **`CharacterBody*D`**.

Modeling the creature as a **thin collision slab** (e.g. **1 world unit** “tall” in 3D, or a thin capsule extrusion) is still a valid **visual / physics shape** choice; it complements **`move_and_slide`**, it does not replace it.

Shared helper (mirrors parent §5 item 1):

```text
movement_speed_multiplier(creature_size, env_data) -> float
  §3.6 — depends on creature_size (Mode B) and squeeze occupancy (no exemption).
```

---

## 6. Implementation plan (ordered)

1. Add **`EnvironmentData`** (or equivalent) with **`passible`**, **`movement_impact`**, **`fit_size`** defaults; document defaults in JSON / Resource if used.  
2. **`creature_size`** on **Player** and **Mob** scenes (exports or stats hook); **mob > player**.  
3. **Environment grid** (or tile metadata) + **`can_enter`** + **`movement_speed_multiplier`**.  
4. **Player:** **`CharacterBody2D`** + **`move_and_slide()`**; respect **`can_enter`** via collision layers / slide response; apply **`movement_speed_multiplier(creature_size, env)`** while inside (§3.6).  
5. **Mob:** obstacle avoidance + **rejoin** baseline path/intent; verify mob cannot **`can_enter`** squeeze gaps the player uses (**`passible == false`** + **`fit_size`** between player and mob sizes).  
6. Unit tests for helpers + minimal integration checklist (manual: hide in narrow gap, mob routes around solid).

**Still outstanding for a complete feature** — detailed in **§8** (placement/boundaries and player motor weighting).

---

## 7. Acceptance criteria

- [ ] **Player** uses **`CharacterBody2D`** + **`move_and_slide()`** for locomotion vs terrain (§5.1), not manual **`Area2D`** slide.  
- [ ] **`passible == true`:** **all** creatures **`can_enter`**; **`fit_size`** does **not** affect enterability (may affect **`movement_speed_multiplier`** via Mode B — §3.3).  
- [ ] **`passible == true`**, **`movement_impact`** active, **`fit_size`** **not** valid **`> 0`:** penalty applies to **all** sizes (open slow terrain).  
- [ ] **`passible == true`**, **`movement_impact`** active, **`fit_size > 0`:** **`creature_size < fit_size`** ⇒ **no** penalty; **`creature_size >= fit_size`** ⇒ penalty (**strict `<`** — §3.3 Mode B).  
- [ ] **`passible == false`** with **`fit_size`** **`null` or `0`:** **no** creature **`can_enter`**.  
- [ ] **`passible == false`** with **`fit_size > 0`:** **`creature_size <= fit_size`** (**inclusive**) **`can_enter`**; larger creatures cannot.  
- [ ] **Squeeze-through** (Mode A): **`movement_impact`** applies to **all** legal occupants when active (**no** shrub exemption).  
- [ ] **Overlapping slow cells (§9 + §3.6):** effective multiplier = **min** of per-cell multipliers (**worst impact wins**); **not** multiplied together.  
- [ ] **Mob `creature_size` > Player `creature_size`** in authored defaults.  
- [ ] Mob **detours** cells where **`can_enter`** is false for the mob and **returns** toward its original intent within bounded parameters.  
- [ ] **`crush_weight`** behavior is **unchanged / unimplemented** (no accidental coupling).  
- [ ] No **3D** assumptions in code paths touched by this phase.
- [ ] **§8.1:** Placement/boundary scheme chosen, documented, and wired so **`EnvironmentData`** (or equivalent) is authoritative per navigable cell or region.  
- [ ] **§8.2:** Player scripted motor (and any AI-facing cost model) **weights** impassible / squeeze-denied cells vs **`movement_impact`** regions consistently with §3.

---

## 8. Outstanding tasks (this feature)

These items are **required** for the object-avoidance feature to feel complete in-game; they sit alongside §6 steps (grid + physics + mob detours).

### 8.1 Placement, boundaries, and authoring

**Problem:** Cells need **`EnvironmentCellData`** (kind presets) and a **baked grid** attached to **world geometry** with clear **boundaries** so movement queries agree with visuals.

**Deliverable:** Pick and document one primary approach (combinations allowed if rules are explicit):

- **Tile-aligned:** TileMap layers + **custom data** per tile/cell (boundaries = cell edges); props as multi-cell rectangles or merged meta-tiles.  
- **Region overlays:** `Area2D` / polygon volumes mapped onto the **same** logical grid used for **`can_enter`** queries (snap rules, integer cell coordinates).  
- **Physics-backed:** `StaticBody2D` / collision shapes driving an auxiliary grid or rasterization step that fills **`EnvironmentData`** per cell.

**Chosen direction — image import → kind grid → `EnvironmentCellData` / `EnvironmentGridBaked`:** Yes. Godot’s **`Image`** / imported textures (`CompressedTexture2D`, etc.) are a practical **authoring source**: each **pixel** (or block of pixels aggregated to one logical cell) maps to a **small integer kind id** or **palette color**, and a **`Dictionary`** or dense **`Array` of `EnvironmentCellData`** presets supplies **`passible`**, **`movement_impact`**, **`fit_size`**, and optional future **`terrain_kind_id`**. Typical pipeline:

1. **Asset:** PNG (or similar) under **`res://art/env/`** — one channel or discrete RGB colors per terrain **kind** (designers paint in Photoshop / Aseprite / GIMP).  
2. **Import settings:** **Filter = Nearest**, **mipmaps off** for index/palette maps so edges stay crisp.  
3. **Build step (editor and/or runtime):** Load `Image` from disk or `texture.get_image()`, iterate pixels (or use **`BitMap.create_from_image_alpha_threshold`** when the map is only solid vs empty), convert **(x, y) → cell (i, j)** with **`pixels_per_cell`** + **world origin** constants.  
4. **Mapping:** `kind_id = f(pixel_color)` — e.g. lookup **`Color` → int** or read **R** as 0–255 id; then **`kind_presets[kind_id]`** is an **`EnvironmentCellData`** preset. Same preset for every cell of that kind.  
5. **Baked runtime resource (implemented):** [EnvironmentCellData](../environment/environment_cell_data.gd) = one **kind** preset; [EnvironmentGridBaked](../environment/environment_grid_baked.gd) = `cell_width` / `cell_height`, `cell_size_px`, `origin_world`, `kind_presets` (`Array`), `cell_kind_ids` (`PackedInt32Array`); [EnvironmentGridBake.bake_from_image](../environment/environment_grid_bake.gd) fills the grid from an [Image] + `Color → kind id` map. Save baked grids as **`.tres`** in the editor (**Save As…** on the resource) or build at startup from a PNG in **`res://art/env/`** (e.g. `Image.load_from_file("res://art/env/playfield_index.png")`).

**Boundaries:** Cell boundaries align to the **raster grid** (pixel blocks); world AABB = `origin + cell_size * Vector2i(i, j)`. Visual overlay can be a **`Sprite2D`** / **`TextureRect`** using the same texture for debug.

**Limits:** One image layer = one **planar** field (good for §2 2D scope). Multiple layers (height-ish data) = multiple images or channels, still 2D if each layer maps to separate logical grids or merged rules (document merge order).

Include: editor workflow (how designers paint solids vs mud), how **multi-cell** obstacles stay consistent, and how **footprint** sampling (§9) aligns with those boundaries.

### 8.2 Player motor — environment, memory, and mob-relative tradeoffs

**Scope guard — playfield edges unchanged:** Keep existing **`weight_edge`**, **`penalty_oob`**, and **bounds AABB** behavior exactly as today. **No** retuning of edge repulsion for this phase. New terms apply only to **interior** environment. **Authority — body-first:** **`StaticBody2D` / `obstacles`** (and similar collision bodies) with attached env metadata are **authoritative** for **`can_enter`** and **`movement_speed_multiplier`** wherever their shapes overlap the playfield. **`EnvironmentGridBaked`** supplies painted / index-mapped fields and fills regions **not** overridden by bodies; **on conflict** in overlapping volume, **body rules win** — bake or query bodies first, then grid as fallback.

**Interior metadata contract:** Every **interior** collider / volume **except** the **playfield boundary** (the existing viewport / AABB edge treatment via **`weight_edge`** / **`penalty_oob`**) **must** carry **`EnvironmentCellData`** (or equivalent attached metadata) with valid **`passible`** / **`movement_impact`** / **`fit_size`** / **`terrain_kind_id`** as applicable. If metadata is **missing** on authored interior content, **default `passible == false`** (nobody enters — treat as solid) until authoring is fixed; this avoids “fall through” once **3D** or less explicit edges replace simple 2D clamps. Legacy **`obstacles`** AABBs without payloads use the same default until bound to env data.

**Problem:** [`creature/motor/cardinal_avoidance.gd`](../creature/motor/cardinal_avoidance.gd) and [`AiDriver` `_build_motor_context`](../AI_int_lib/ai_driver.gd) score cardinals vs mobs and static AABBs but do **not** yet encode **belief about** environment (unknown vs known solid vs known passable-for-self), **mob-proximity-modulated exploration**, or **slow-tile vs mob** tradeoffs.

#### 8.2.1 Belief buckets (motor; physics stays authoritative on `can_enter`)

Use a single **memory-backed classification** per distinct environmental feature (see §8.2.3). Until memory says otherwise, treat interior solids as **unknown / unexplored** (one motor bucket for **v1** — §8.2.5).

**Low / high nearby mob threat** (table columns): **Proximity pressure** from mobs already in the **same** motor snapshot as today — i.e. **`creature_motor`** terms that depend on **distance to each mob**, **closing**, **`awareness_radius`**, cone, and **memory ghosts** (see [`cardinal_avoidance.gd`](../creature/motor/cardinal_avoidance.gd) / [`ai_driver.gd`](../AI_int_lib/ai_driver.gd)). **Closer** mobs contribute **more** threat (e.g. a mob **100 px** away reads as **higher** threat than one **200 px** away when both are in awareness). **High** vs **low** is an **ordinal band** on that aggregate for the tick, not a second hard radius. **No** separate **`env_threat_radius`** for §8.2 v1 — detail §8.2.5.

| Bucket | Motor intent | **Low nearby mob threat** | **High nearby mob threat** |
|--------|--------------|---------------------------|----------------------------|
| **Unknown / unexplored** (no **validated** memory; see §8.2.5 for **assumed** vs **validated**) | Learn vs survive | **Explore bias** — small **negative** cost (favor) toward directions that intersect the object / its near field so the creature **probes** safely | **Avoid bias** — add **positive** cost toward that object so the creature keeps **maneuver room**; this cost must stay **strictly weaker** than **mob avoidance** so that if one **must** choose between **risking mob contact** and **risking object contact**, the motor **prefers the object** (“better to hit the object than the mob”) |
| **Known — solid for self** (`can_enter == false` **validated** by **collision stop** / failed entry — §8.2.5) | Corridor like a wall | Treat **like exterior edges** — strong clearance-style repulsion (new term mirroring **severity** of `weight_edge` **without** reusing or retuning the edge code path) | Same — hard obstacle; mobs can route around large solids |
| **Known — non-impeding for self** (self **validated** can traverse; mob **blocked** on same channel ⇒ **Mode A** squeeze asymmetry, **or** mob **impeded** while self skates ⇒ **Mode B** shrub / open mud asymmetry — §8.2.5) | Exploitable channel | **Favorable bias** — prefer cardinals that use the opening when it improves clearance from predicted mob positions | Still favorable **unless** slowdown or geometry makes that cardinal predict **tag** — then fall back to mob-avoidance dominance |

#### 8.2.2 Slow terrain (`movement_speed_multiplier` < 1)

- Fold **anticipated slowdown** from §3.6 into per-cardinal cost using the same lookahead footprint as mob scoring.
- **Contextual blend:** Prefer **slow passage** when it **increases separation / decreases closing** vs alternatives; **penalize** slow passage when it **predictably leads to tag** (mob cuts off or closes faster than the slowdown buys time). Tunables live in `GameConfig` / `creature_motor` alongside existing weights.
- **Vs unknown / interior explore (same cardinal):** When **slow terrain** and **unknown-object** explore / avoid terms both apply, use the **merge rule** in §8.2.5 (bounded detours, **cumulative ETA**, **`awareness_memory_ticks`** patience, then additive / weighted lexicographic; future **motivation traits** — [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) / [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md)).

#### 8.2.3 Mapping / memory (required)

- **Stable feature id (v1):** Primary key = **`terrain_kind_id` + `instance_id`** for discrete authored features (props, static bodies, placed plants, etc.). **`instance_id`** is assigned by tooling (e.g. `Meta` on a body, editor UUID, or stable scene path — pick one scheme per level pipeline). The same **kind + instance** pattern extends to **`creature_kind_id`**, **`plant_kind_id`**, and similar catalogs when those systems land, so **kind-level** priors can aggregate across instances while **instance-level** memory stays precise.
- **Fallback (no discrete instance):** For **pure baked grid** terrain (no per-cell “object”), use **`terrain_kind_id` + cell key** **`(kind_id, i, j)`** for a cell or a **connected-component / region id** for one contiguous painted patch. Use **cell-span hash** or **quantized world AABB** only if kind+cell is unavailable (legacy content).
- **Runtime ownership (this phase):** Store interior-env **belief / classification** on the **creature** (same node tree as the controlled mob/player, or a `RefCounted` / `Resource` **owned by** that creature). **`AiDriver` / motor** reads that store when building context. **Save-game persistence** and cross-session memory are **out of scope** for this phase; clearing memory on **level / scene reload** is acceptable.
- **TTL / invalidation:** Invalidate per-creature interior memory on **scene reload**; long-lived disk persistence — **when** a save-game phase lands (not required here).
- Memory feeds **§8.2.1** bucket selection; **physics** still uses live **`can_enter`** / grid + **body-first** rules (above).

#### 8.2.4 Out of scope (this phase) — document for later

- **Line-of-sight / occlusion:** Solid props **hiding** mobs from awareness / snapshot — affects perception, not cardinal cost v1. Tracked in §10.

#### 8.2.5 Interior env + motor decisions (v1)

- **Unknown vs unexplored (v1):** **One** motor bucket. Any feature with **no** validated memory for self (`can_enter` / squeeze not yet established for that stable id) uses the **Unknown / unexplored** row in §8.2.1 — including “never sampled” and any future “seen but unprobed” awareness cue until a phase adds distinct stored states. <<Comment: Splitting e.g. **silhouette / partial awareness** vs **unexplored** needs perception / snapshot / LOS (§8.2.4, §10); do **not** introduce a second bucket or enum value until that data is available in memory APIs.>>  
- **“Known — solid for self” (validation):** Motor memory promotes to this bucket when the creature **attempts to enter** that feature’s cells / occupancy and movement resolution shows **no legal occupancy** — **collision stop** / slide clamp consistent with live **`can_enter == false`** for that **`creature_size`** (§3.5). That empirical failure is the **authoritative** promotion from “not yet proven solid” to **known solid** for **self**. Designer-authored **`passible`** / grid data **seed one-time assumptions** only (next bullet); they **do not** alone hard-lock **Known — solid** motor behavior. <<Comment: Optional headless **`can_enter`** probes without moving the avatar are **not** required for v1 if collision-backed attempts already occur in normal play; add only if design needs faster learning without physical bump.>>  
- **Assumed vs validated (v1 lifecycle):** On first tracking of a stable feature id (§8.2.3), write **at most one** **assumption** from authored / baked grid: **assumed solid** or **assumed passible** (or leave neutral if data is ambiguous). **Do not** re-derive that assumption every frame from noisy heuristics. Keep it until an **entry attempt** resolves: **success** ⇒ **Known — non-impeding for self** (respect §3 **movement_impact** / squeeze semantics as applicable); **failure** (**collision stop** / illegal occupancy) ⇒ **Known — solid for self**. Motor **v1** still uses the single **Unknown / unexplored** table row for any state that is **not** yet **validated** known (assumption lives in memory for future tuning / UI, not a separate cardinal bucket here). <<Comment: Experiential **squeeze** / **`terrain_kind_id`** relearning (§10) refines passibility over time; it does **not** replace **collision-backed** solidity for true blocks.>>  
- **Nearby mob threat (§8.2.1 columns):** Reuse the **existing** motor mob snapshot and proximity scoring (**distance**, **closing**, **`awareness_radius`**, cone extras, **memory ghosts** — whatever already feeds `CardinalAvoidance` / `AiDriver` for this creature). **Threat rises as mobs get closer** (continuous / weighted by current tunables); there is **no** additional **`env_threat_radius`** gate for §8.2 v1. Map the aggregate to **low** vs **high** bands with a **single threshold or hysteresis pair** in `GameConfig` / `creature_motor` when implementing (values **TBD** at tuning time). <<Comment: If LOS later hides mobs from the snapshot (§10), “nearby” implicitly follows **perceived** mobs only — same as motor today.>>  
- **Known non-impeding vs mob (§3.3):** If the mob **cannot pass** the same opening (**`can_enter(mob_creature_size, env) == false`** — literal block for the mob’s size), treat as **Mode A squeeze** asymmetry (§3.3). If the mob **can** enter but is **impeded** relative to self (**`movement_speed_multiplier(mob_creature_size, env) < 1`** while self is faster or exempt — **Mode B** shrub / open mud), that is still **Known — non-impeding for self** for the player’s motor: self has a **mob exploit**, but the exploit is **“they’re slowed or tangled, I’m not”**, not **“they’re hard-blocked.”** Do **not** conflate **Mode B impediment** with **Mode A cannot-pass** wording in memory tags if you split them later.  
- **Mob passability without duplicated rules:** Build motor context with **`can_enter(mob_creature_size, env_data)`** and, when relevant, **`movement_speed_multiplier(mob_creature_size, env_data)`** using the **same §3.5 / §3.6 helpers** (or a thin wrapper) that physics and mob pathing already call; pass **booleans / multipliers** into `CardinalAvoidance` — **no** second implementation of grid rules inside the motor.  
- **“Known for mobs” in memory:** (1) **Observed** — mob **succeeds** or **fails** to use the channel in view. (2) **Estimated** — after self **validated** passage, infer mob outcome by evaluating **`can_enter(mob_size, …)`** / **`movement_speed_multiplier(mob_size, …)`** on the **same** cell / feature data (size-based prediction). (3) **Correction** — if observation later **contradicts** the estimate (mob passes when memory said block, or the reverse), **update** the stored mob-related classification so **known** matches **observed** behavior. <<Comment: Ghost / stale positions may briefly skew observation; use stable feature id (§8.2.3) + conservative updates if needed.>>  
- **Slow terrain vs unknown on the same cardinal:** With **no stronger** stimuli (mob, solid, etc.), **unknown** interior keeps a **net explore attraction** (§8.2.1 **low-threat** column). **Detour first:** prefer routes with **better cumulative ETA** (time integrated along the sampled path using §3.6 speeds) over **straight through** slow or ambiguous geometry when a **meaningfully faster** option exists among scored candidates. **Bounded detour set (v1):** evaluate **at most three** coarse alternatives around a single rough patch / unknown feature — **bear left**, **bear right**, and **straight through** (implementation maps these to cardinals or short tangents from current pose). **Patience / equalize:** reuse **`awareness_memory_ticks`** from [`game_config.json`](../game_config.json) under **`creature_motor`** for **both** (1) mob **ghost history** length in [`ai_driver.gd`](../AI_int_lib/ai_driver.gd) and (2) this **detour / rough-patch patience** window — same numeric knob for v1; **decompose** into separate config keys (e.g. **`env_detour_patience_ticks`**) if coupled behavior causes problems or unintended side effects. If, over that many **physics ticks**, **no** detour branch clears the rough footprint under the §9 rule, treat **through** vs **around** as **equal weight** for that scoring cycle so exploration is not permanently blocked by detour optimism. **When no good detour** after comparison (similar cumulative ETA across the bounded set), **combine** slow-terrain penalty with unknown explore/avoid terms using **additive** costs, or **weighted lexicographic** (e.g. mob-safe ordering first, then slow vs explore) — pick one convention in code and test; exact weights **TBD** in `GameConfig` / `creature_motor`. **Not** `max` of the two alone (that would erase explore or erase slowdown unpredictably). <<Comment: When **motivation traits** land ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) `explorer_builder` / outlook — see [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md)), **high explorer** should **scale up** unknown attraction and **scale down** slow-terrain aversion so exploration wins more often without changing the **mob > object** invariant from §8.2.1.>>  
- **ENGINE** vs **HUMAN / AI:** **This phase** — apply interior env / exploration motor biases **only** when the creature is **ENGINE**-controlled; **do not** apply those nudges to **HUMAN** input. **ControlMode.AI** (or any non-scripted motor) vs **ENGINE** parity for these weights — **resolve when the AI control phase** lands. <<Comment: A future **skill-based** mechanism (e.g. optional HUD / tutor hints) could nudge humans toward safer probing or corridor use; keep that as a **separate** feature, **out of scope** for cardinal §8.2 v1.>>

**Deliverable (implementation):**

- Extend **`CardinalAvoidance`** context + cost pipeline with **interior env** terms and **memory lookup** hooks; keep **mob weights > interior-unknown-avoid** when both fire; add tests for ordering and edge-vs-interior independence.  
- Wire **`EnvironmentGridBaked`** sampling into **`_build_motor_context`** (or parallel helper) once the grid exists in **Main**.

---

## 9. Footprint sampling (v1)

**Grid cell attribution (v1):** For **`can_enter`**, **`movement_speed_multiplier`**, and coarse motor/grid queries, resolve the primary cell(s) from the creature’s **footprint center** (e.g. **`global_position`** or collision AABB **center**) → map to **`(i, j)`**. **Not** full polygon–cell overlap for this path yet — revisit when adding **3D** or mesh-based terrain sampling.

**Footprint — sustained difficult terrain (motor lookahead):** Where finer sampling is needed for “how deep in mud,” use the creature’s **collision shape** area vs the slow region: **overlap fraction** = intersection area ÷ footprint area; treat as **inside** sustained slow-heuristic when **overlap fraction ≥ 0.25** (**25%**). <<Comment: Retune if playtests disagree with center-based occupancy above.>>

**Belief / unknown probe (memory — passible vs solid):** Distinct from center-only occupancy: promote **unknown → known** for **passible** (including **slow**) cells when the footprint shows **≥ 1 logical pixel** overlap into that cell (tie **1px** to smallest **`cell_size_px`** / palette step), so the creature can **brush** the cell, **confirm passible**, and **reroute** before **25%** overlap makes **`movement_impact`** dominate. **Solid** validation remains **collision stop** / failed entry (§8.2.5).

**Multi-cell slowdown (v1):** When the footprint overlaps **several** cells at once, take **`movement_speed_multiplier`** from §3.6 **per** inside cell, then apply **min** of those multipliers — **worst impact wins** (e.g. **70%** speed vs **50%** speed ⇒ **50%**). **Not** multiplicative combine.

---

## 10. Future enhancements (not this phase)

**Line-of-sight / occlusion (awareness):** Environment props that **block vision** should reduce confidence or range for mobs **behind** them relative to the creature’s facing / sampling cone — ties to perception / snapshot, not cardinal §8.2 v1. Implement in a dedicated perception phase when field-of-view is defined.

**Experiential exploration — squeezes:** Until learned (per **`terrain_kind_id`**), planners may treat **`passible == false`** façade as **fully costly / opaque**, even though **Mode A** might allow a squeeze for this **`creature_size`**. Discovering a valid squeeze for kind **`K`** updates memory keyed **`(creature, terrain_kind_id == K)`**, rewarding **probing “solid” props** to find **predator-avoidance shortcuts**. Physics **`can_enter`** remains authoritative at runtime.

**Experiential slowdown — open mud, shrubs, squeeze interiors:** **`movement_impact`** effects (including **Mode B** asymmetry and post-squeeze slowdown) should be **under-weighted in utility / planning** until the creature has **experienced** that **`terrain_kind_id`** (first entry, N ticks — **TBD**). Hard illegality (`can_enter == false` with **no** learned squeeze) remains absolute.

**Per-kind memory (`terrain_kind_id`):** Separate memories for **squeeze affordance** vs **slowdown curves** may share the same ID space or sub-keys — **TBD** when implementing; the invariant is **mud ≠ deep_snow ≠ squeeze-rock-wall-kind** so lessons do not cross-contaminate ([ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) property catalog).

**Canonical carry-forward:** Items above and other deferred `<<Comment>>` threads are duplicated in [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) §10 so they survive archiving this file.

---

## 11. Changelog

| Date | Change |
|------|--------|
| 2026-05-12 | §5 / §6 / §7: **CharacterBody2D/3D** + **`move_and_slide()`** required for player locomotion; §5 table; no **`Area2D`** slide reimplementation. |
| 2026-05-12 | §3.2/§3.6: ambiguous **`movement_impact`** → **max slowdown** + clamp. §5.1: **CharacterBody** + **`move_and_slide`** vs **Area2D**; thin 3D slab note. §8.2: metadata default **`passible==false`**; ENGINE/**AI** deferral. §8.2.5: **`awareness_memory_ticks`** dual use + decompose note. §9: **center** cell + **25%** sustained slow + **1px** passible probe. |
| 2026-05-12 | §8.2.3: stable id **`terrain_kind_id` + `instance_id`** + grid fallbacks; memory on **creature**; persistence OOS. §8.2 **body-first** vs grid. §8.2.5: detour = **L/R/through**, **cumulative ETA**, **`awareness_memory_ticks`** patience (`game_config.json`). |
| 2026-05-12 | §8.2.2/§8.2.5: **slow vs unknown** — detour / ETA first, else **additive** or **weighted lexicographic**; **not** `max`; future **`explorer_builder`** scales explore vs slow; §8.2.5 title; §9 title. |
| 2026-05-12 | §8.2.1/§8.2.5: **Known non-impeding** ↔ **Mode A** (mob cannot pass) vs **Mode B** (mob impeded); mob line uses **same §3** helpers; observation corrects estimates; §9 index. |
| 2026-05-12 | §8.2.1/§8.2.5: **nearby mob threat** = existing snapshot + proximity (**closer ⇒ higher**); no **`env_threat_radius`** v1; §9 index. |
| 2026-05-12 | §8.2.5: **solid for self** = **collision stop** / failed entry; **assumed** passible vs solid **once** until attempt; §8.2.1/§8.2.3/§9 index. |
| 2026-05-12 | §9 + §3.6 + §5: multi-cell slowdown = **min** of per-cell **`movement_speed_multiplier`** (worst impact wins); not multiplicative. |
| 2026-05-12 | §9: difficult-terrain **footprint** = collision-shape **overlap fraction**; **≥ 25%** counts as inside (v1 default). |
| 2026-05-12 | §8.2.5: **unknown / unexplored** = one v1 motor bucket (resolved); §8.2.1 pointer; §9 motor index. |
| 2026-05-12 | §8.2.5: **ENGINE**-only motor nudges this phase; human skill-based nudge deferred (comment). §9 index updated. |
| 2026-05-12 | §8.2 motor vs environment: belief buckets, mob>object ordering, slow terrain context, memory, §8.2.5 questions; §10 LOS note. |
| 2026-05-12 | Baked grid resources + palette authoring under **res://art/env/** (OBJECT §8.1). |
| 2026-05-12 | Expanded §3.3 / §3.5: explicit `fit_size` truth table, implementation rules, anti-patterns, invalid numeric handling, reference `can_enter` sketch. |
| 2026-05-12 | Mode B shrubs + §3.6 `movement_speed_multiplier`; superseded single-role `fit_size` wording — see §3.3 Mode A+B. |
| 2026-05-12 | Initial plan: object avoidance, difficult terrain, inclusive `fit_size`, creature sizes; parent doc tagged for remaining items. |
