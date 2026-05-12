# Hunter Killer — Object avoidance & terrain gates (agent-friendly)

**Parent design:** [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) — this document narrows scope to **2D** locomotion: squeeze (**Mode A**, **`passible == false`**), shrubs / brush (**Mode B**, **`passible == true`** + **`movement_impact`** + **`fit_size`**), mob detours, and **`movement_speed_multiplier(creature_size, env)`**. It does **not** supersede the parent catalog; it pins semantics left open there.

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
| Player | **Clamp/slide** vs **`can_enter` false**; multiply speed by **`movement_speed_multiplier(creature_size, env)`** for occupied cells — **not** raw **`movement_impact`** alone. |
| Mob | **RigidBody2D** or **`CharacterBody2D`** migration is an implementation detail; avoidance must respect **same enterability rules** as the player. |
| Tests | **`can_enter`** (Modes A/B entry); **`movement_speed_multiplier`** (open mud, shrub **`< fit_size`**, shrub **`>= fit_size`**, squeeze + **`movement_impact`**); regression on **inclusive squeeze `<=`** vs **strict shrub `<`**. |

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
4. **Player:** block entry or slide when **`can_enter`** is false; apply **`movement_speed_multiplier(creature_size, env)`** while inside (§3.6).  
5. **Mob:** obstacle avoidance + **rejoin** baseline path/intent; verify mob cannot **`can_enter`** squeeze gaps the player uses (**`passible == false`** + **`fit_size`** between player and mob sizes).  
6. Unit tests for helpers + minimal integration checklist (manual: hide in narrow gap, mob routes around solid).

**Still outstanding for a complete feature** — detailed in **§8** (placement/boundaries and player motor weighting).

---

## 7. Acceptance criteria

- [ ] **`passible == true`:** **all** creatures **`can_enter`**; **`fit_size`** does **not** affect enterability (may affect **`movement_speed_multiplier`** via Mode B — §3.3).  
- [ ] **`passible == true`**, **`movement_impact`** active, **`fit_size`** **not** valid **`> 0`:** penalty applies to **all** sizes (open slow terrain).  
- [ ] **`passible == true`**, **`movement_impact`** active, **`fit_size > 0`:** **`creature_size < fit_size`** ⇒ **no** penalty; **`creature_size >= fit_size`** ⇒ penalty (**strict `<`** — §3.3 Mode B).  
- [ ] **`passible == false`** with **`fit_size`** **`null` or `0`:** **no** creature **`can_enter`**.  
- [ ] **`passible == false`** with **`fit_size > 0`:** **`creature_size <= fit_size`** (**inclusive**) **`can_enter`**; larger creatures cannot.  
- [ ] **Squeeze-through** (Mode A): **`movement_impact`** applies to **all** legal occupants when active (**no** shrub exemption).  
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

**Scope guard — playfield edges unchanged:** Keep existing **`weight_edge`**, **`penalty_oob`**, and **bounds AABB** behavior exactly as today. **No** retuning of edge repulsion for this phase. New terms apply only to **interior** environment (baked grid cells, and/or **`obstacles`** group geometry once unified with **`can_enter`** / **`movement_speed_multiplier`**).

**Problem:** [`creature/motor/cardinal_avoidance.gd`](../creature/motor/cardinal_avoidance.gd) and [`AiDriver` `_build_motor_context`](../AI_int_lib/ai_driver.gd) score cardinals vs mobs and static AABBs but do **not** yet encode **belief about** environment (unknown vs known solid vs known passable-for-self), **mob-proximity-modulated exploration**, or **slow-tile vs mob** tradeoffs.

#### 8.2.1 Belief buckets (motor; physics stays authoritative on `can_enter`)

Use a single **memory-backed classification** per distinct environmental feature (see §8.2.3). Until memory says otherwise, treat interior solids as **unknown / unexplored** (same bucket for v1 unless split later — §8.2.5).

| Bucket | Motor intent | **Low nearby mob threat** | **High nearby mob threat** |
|--------|--------------|---------------------------|----------------------------|
| **Unknown / unexplored** (no validated memory) | Learn vs survive | **Explore bias** — small **negative** cost (favor) toward directions that intersect the object / its near field so the creature **probes** safely | **Avoid bias** — add **positive** cost toward that object so the creature keeps **maneuver room**; this cost must stay **strictly weaker** than **mob avoidance** so that if one **must** choose between **risking mob contact** and **risking object contact**, the motor **prefers the object** (“better to hit the object than the mob”) |
| **Known — solid for self** (`can_enter == false` validated) | Corridor like a wall | Treat **like exterior edges** — strong clearance-style repulsion (new term mirroring **severity** of `weight_edge` **without** reusing or retuning the edge code path) | Same — hard obstacle; mobs can route around large solids |
| **Known — non-impeding for self** (creature can traverse; **mob cannot** use the same affordance) | Exploitable channel | **Favorable bias** — prefer cardinals that use the opening when it improves clearance from predicted mob positions | Still favorable **unless** slowdown or geometry makes that cardinal predict **tag** — then fall back to mob-avoidance dominance |

#### 8.2.2 Slow terrain (`movement_speed_multiplier` < 1)

- Fold **anticipated slowdown** from §3.6 into per-cardinal cost using the same lookahead footprint as mob scoring.
- **Contextual blend:** Prefer **slow passage** when it **increases separation / decreases closing** vs alternatives; **penalize** slow passage when it **predictably leads to tag** (mob cuts off or closes faster than the slowdown buys time). Tunables live in `GameConfig` / `creature_motor` alongside existing weights.

#### 8.2.3 Mapping / memory (required)

- Features must remain **recognizable** when they leave **awareness** for a long time: store **stable id** (e.g. **`terrain_kind_id` + authored instance id**, **cell-span hash**, or **world AABB key** from static body) → **classification** + optional **squeeze-validated** flag. **TTL / invalidation** on level reload — **TBD** (§8.2.5).
- Memory feeds **§8.2.1** bucket selection; **physics** still uses live grid / `can_enter` at runtime.

#### 8.2.4 Out of scope (this phase) — document for later

- **Line-of-sight / occlusion:** Solid props **hiding** mobs from awareness / snapshot — affects perception, not cardinal cost v1. Tracked in §10.

#### 8.2.5 Open questions & ambiguities (resolve before coding weights)

- <<Question: Are **unknown** and **unexplored** distinct states (e.g. “seen silhouette” vs “never sampled”), or one bucket for v1?>>  
- <<Question: What exactly **validates** “solid for self” — collision stop, one failed `can_enter` probe, explicit `terrain_kind_id` learn flag, or designer-authored only?>>  
- <<Question: Define **nearby mob threat** — reuse **`awareness_radius` / cone / memory ghosts`**, or a separate **`env_threat_radius`**?>>  
- <<Question: “Known non-impeding + mobs cannot pass” — confirm this means **Mode A squeeze** or **Mode B shrub** or **open passible** tile inside a larger static footprint; how does motor get **mob passability** (mob `creature_size`) without duplicating world query logic?>>  
- <<Question: When **both** slow terrain **and** unknown object compete on the same cardinal, what is the **merge order** (additive vs max vs lexicographic)?>>  
- <<Question: **ENGINE** vs **HUMAN** control — apply exploration biases only under **ENGINE**, or also nudge **HUMAN** via optional HUD (probably ENGINE only)?>>

**Deliverable (implementation):**

- Extend **`CardinalAvoidance`** context + cost pipeline with **interior env** terms and **memory lookup** hooks; keep **mob weights > interior-unknown-avoid** when both fire; add tests for ordering and edge-vs-interior independence.  
- Wire **`EnvironmentGridBaked`** sampling into **`_build_motor_context`** (or parallel helper) once the grid exists in **Main**.

---

## 9. Open questions

- <<Question: Footprint rule — single **center point** vs **collision shape overlap fraction** for “inside difficult terrain”?>>  
- <<Question: When player overlaps multiple cells, **max** vs **multiplicative** combine for `movement_impact`?>>  
- <<Question: (Motor §8.2.5) See §8.2.5 — unknown vs unexplored, validation rule, threat radius, mob passability source, merge order, ENGINE-only.>>

---

## 10. Future enhancements (not this phase)

**Line-of-sight / occlusion (awareness):** Environment props that **block vision** should reduce confidence or range for mobs **behind** them relative to the creature’s facing / sampling cone — ties to perception / snapshot, not cardinal §8.2 v1. Implement in a dedicated perception phase when field-of-view is defined.

**Experiential exploration — squeezes:** Until learned (per **`terrain_kind_id`**), planners may treat **`passible == false`** façade as **fully costly / opaque**, even though **Mode A** might allow a squeeze for this **`creature_size`**. Discovering a valid squeeze for kind **`K`** updates memory keyed **`(creature, terrain_kind_id == K)`**, rewarding **probing “solid” props** to find **predator-avoidance shortcuts**. Physics **`can_enter`** remains authoritative at runtime.

**Experiential slowdown — open mud, shrubs, squeeze interiors:** **`movement_impact`** effects (including **Mode B** asymmetry and post-squeeze slowdown) should be **under-weighted in utility / planning** until the creature has **experienced** that **`terrain_kind_id`** (first entry, N ticks — **TBD**). Hard illegality (`can_enter == false` with **no** learned squeeze) remains absolute.

**Per-kind memory (`terrain_kind_id`):** Separate memories for **squeeze affordance** vs **slowdown curves** may share the same ID space or sub-keys — **TBD** when implementing; the invariant is **mud ≠ deep_snow ≠ squeeze-rock-wall-kind** so lessons do not cross-contaminate ([ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) property catalog).

---

## 11. Changelog

| Date | Change |
|------|--------|
| 2026-05-12 | §8.2 motor vs environment: belief buckets, mob>object ordering, slow terrain context, memory, §8.2.5 questions; §10 LOS note. |
| 2026-05-12 | Baked grid resources + palette authoring under **res://art/env/** (OBJECT §8.1). |
| 2026-05-12 | Expanded §3.3 / §3.5: explicit `fit_size` truth table, implementation rules, anti-patterns, invalid numeric handling, reference `can_enter` sketch. |
| 2026-05-12 | Mode B shrubs + §3.6 `movement_speed_multiplier`; superseded single-role `fit_size` wording — see §3.3 Mode A+B. |
| 2026-05-12 | Initial plan: object avoidance, difficult terrain, inclusive `fit_size`, creature sizes; parent doc tagged for remaining items. |
