# Hunter Killer — Hunger, calories, and bush food sources (agent-friendly)

> **Archive:** This feature is **implemented** in-tree (`player.gd`, `main.gd`, `hud.gd`, `mob.gd`, `assets/plants/…`). Per [AGENTS.md](../../.cursor/rules/AGENTS.md), treat this file as **historical** unless a maintainer explicitly cites it for new work; active plants index remains [PLANTS_PLAN.md](../Draft_Features/PLANTS_PLAN.md).

> **Purpose:** Specify **hunger** / **calorie** gameplay for the Hunter Killer Godot project: bush-style food assets, two interaction archetypes (impact vs pass-through), creature HUD feedback, plant **calorie regrowth**, and **two-state shrub sprites** (PNG) per archetype.
>
> **Terminology:** Use **calorie** / **calories** in code and docs (not “callory”). Align creature-facing fields with [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) (**`caloric_needs`**, **`current_calories`**).
>
> **Relationship to other docs:** Environment passibility and brush semantics intersect [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) and [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md). Plant **field names** and long-term **`growth_rate`** semantics align with [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md) (no separate `yield_calories`—use **`current_calories`** / **`max_calories`**). High-level plants index: [PLANTS_PLAN.md](../Draft_Features/PLANTS_PLAN.md). **Authoritative asset root for plant packs:** **`res://assets/plants/`** per [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) and [ASSET_MANAGEMENT_PLAN.md](ASSET_MANAGEMENT_PLAN.md).

---

## 1. Phase summary

**Phase name:** Hunger & eating (bushes + HUD + regrowth)

**One-line objective:** Add **bush** food sources that restore the playable creature’s **`current_calories`**, drain hunger **over real time at 1 calorie per second**, show **hunger/calorie status** top-right, **regrow** depleted plant calories at **1 calorie per second**, and distinguish **not ready** vs **ready** bush states with **authored PNG sprites** (two textures per archetype; §5.4). **Level intent:** about **4–5** such plants in a scene so the player **routes between** them **while dodging mobs**. **AI intent:** begin the **mob decision tree** so agents weigh **avoidance** and **food viability** (not avoidance alone), using **plant beliefs** updated under a **zone of awareness**.

**Out of scope (explicit non-goals):**

- Full ecosystem simulation (seeding, species competition) beyond calorie pool regrowth on placed bushes — defer to [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md).
- Per-plant **differing** regrowth rates — **not** required this phase (all bushes use **1/s**); the **awareness** rules below are written so that difference can land later without redoing beliefs.
- Cross-session persistence of hunger or plant depletion (see **Session reset** in §3).

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot **4.6.x** (match `project.godot`).

**Main scenes / entry (today):**

- `res://main.tscn` + `res://main.gd`
- HUD: `res://hud.gd` (CanvasLayer UI under Main)

**Key scripts / scenes likely touched:**

- `res://player.gd` — creature vitals, collision callbacks, overlap entry
- `res://main.gd` — game over / round flow if starvation ends the run
- `res://hud.gd` — top-right hunger readout
- Obstacle / props (general environment): `res://obstacle_field.tscn`, `res://environment/obstacle_field_root.gd` — **food bushes are separate** from this pipeline (standalone **`res://assets/plants/…`** scenes; §5.1).
- `res://mob.gd` — mob decision inputs: plant **discovery** + **status under awareness**; hook into emerging **decision tree** (avoidance + food).
- Optional: `res://creature/` helpers if pulling stats into a small Resource

**Session reset (this phase):** On **each new session** (a new run from `main` / round start as defined by `main.gd`), set **all** calorie pools that this feature owns to **full**: the **player**’s **`current_calories`** → **`caloric_needs`**, and **each** food bush’s **`current_calories`** → **`max_calories`**. **Do not** persist hunger, plant depletion, or regrowth progress across application restarts or between separate sessions. **Save/load** of vitals or bush state is **out of scope** this phase.

**Existing patterns to follow:**

- [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md) and focus rules under [`.cursor/rules/focus/`](../../.cursor/rules/focus/).
- Document physics **layers/masks** in [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6** (authoritative table) and **§7** acceptance checklist. Keep **`project.godot`** `[layer_names]` in sync; see [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) for doc tiers.

---

## 3. Phase numeric constants (this phase)

| Constant | Value | Notes |
|----------|-------|--------|
| **`caloric_needs`** (creature max) | **10** | Pool cap. At **session start**, player **`current_calories`** = **`caloric_needs`** (see **Session reset**, §2). |
| **Session reset** | **Full pools** | Every new session: creature and **all** food bushes start at **full** calories; no cross-session carryover. |
| Creature drain | **−1 calorie per second** | **Authoritative** rate for this phase. **Time base:** real seconds (`delta` integration). **Not** movement-gated; **not** “loss per physics frame” as the design rule. |
| **`max_calories`** (bush) | **5** | A **full** bush holds 5 transferable calories this phase. |
| Bush regrowth | **+1 calorie per second** | **Authoritative** rate for this phase. While depleted or partial, climb toward **`max_calories`**; clamp at **`max_calories`**. Same real-time base as creature drain. |
| **Scene layout (intent)** | **4–5 food bushes** | Enough spread that the creature must **move from plant to plant** and juggle **mob avoidance** (not a single stationary food source). Exact count is a target, not a hard engine constraint. |
| **Eat rule** | **Only when bush is full** | `current_calories == max_calories`; partial regrowth **cannot** be eaten. Grant transfers the full **5** in one interaction (subject to overlap/impact rules in §5). |
| **Starvation** | **`current_calories` ≤ 0 ⇒ immediate lose** | **No** grace buffer this phase: hitting **0** ends the round (game over / agreed lose) on that frame or tick boundary where vitals are applied. |
| **HUD vitals poll** | **Every 10 `_process` frames** (display tick) | **`hud.gd`** **polls** the creature (**`Player`**) for displayed vitals on this cadence — **display-only**; **no** extra physics layers or world queries from the HUD. **Default `10`**, tune for smoothness vs work. Same pattern for future **damage**, **fatigue**, etc. |

---

## 4. Requirements

### Must have

1. **Creature calorie pool** — Track **`current_calories`** with an upper bound **`caloric_needs`** (or equivalent) per [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md); derive optional **`hunger`** display if useful (e.g. ratio or inverted bar). **This phase:** **`caloric_needs` = 10** (see §3 constants table).
2. **Hunger drain** — Decrease **`current_calories`** at **exactly 1 calorie per second** in **real time** (see §3). Implementation may run in **`_process`** or accumulate `delta` in **`_physics_process`**, but the **authoritative rule** is **1/s** drain, not “only while moving” and not “each physics frame” as the unit of loss.
3. **Starvation failure** — When **`current_calories` ≤ 0**, trigger **game over** using the **same player-facing outcome as mob contact** this phase (`Main.game_over()` / existing HUD flow). **Future:** differentiated deaths (violence vs starvation vs environment) — see [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md).
4. **Food source A — Impassible impact bush** — Stationary **solid** prop (creature **cannot** walk through). **Calorie grant (this phase):** **single burst** on **first qualifying** collision / contact with the player (debounce so it does **not** repeat every physics frame while touching); only when bush is **full** (§3). **Burst transfer:** add up to **`max_calories`** (5) toward **`caloric_needs`**; **overflow is wasted** (clamp at **`caloric_needs`**, do not bank past cap). <<Comment: future phase may add sustained-touch rules>>
5. **Food source B — Creature-pass / mob-block bush** — Creature **passes through** (no blocking collision for the player creature); **mobs do not** pass through (they experience it as a blocker or detour). **Calorie grant (this phase):** **single burst** when the player **enters** the calorie overlap (same semantics as Food A: **not** a per-frame drip while standing inside). **Re-consume:** once the plant regrows so **`current_calories == max_calories`** again, it is **ready** (swap to **`*_full.png`**) and the player may earn another burst on a **new** qualifying entry after having left / reset debounce as designed. **Later phase:** **steady drip** while overlapping so player **decision-making** under sustained contact becomes richer.
6. **HUD** — Upper **right** corner: readable **hunger/calorie status** (numeric and/or bar). **Implementation:** **`hud.gd`** uses **`_process`** (or equivalent **idle** display tick), **not** gameplay physics, increments a counter and every **10** frames reads **`Player`** vitals and updates labels (§3). **No** world collision or interaction from the HUD—**read-only** display. May lag true vitals by up to that interval; tune **`10`** as needed.
7. **Calorie regrowth on plants** — When a creature consumes a bush, the bush’s **`current_calories`** go to **0**. Regrow toward **`max_calories` (5)** at **+1 calorie per second** in **real time** — **authoritative** for this phase, same time base as creature drain. **`growth_rate`** naming can align with [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md); this phase fixes the numeric rate at **1/s**.
8. **Visual states** — **Sprite / texture** (this phase: **no** colored border frame; **no** partial pickup): swap **`Sprite2D`** (or equivalent) texture when crossing the ready threshold (`current_calories == max_calories`). Filenames and placement: **§5.4**; art under **`res://assets/plants/…`**. **Z-order:** render the shrub **above** the creature so the player **visually tucks into** the bush when passing through (Food B). <<Comment: tune sibling order / z_index per scene>>
   - **Not ready** (`current_calories < max_calories`): **inedible** art — creature can **enter** Food B / cannot eat; Food A remains **solid** and inedible (§5.4 table).
   - **Ready** (`current_calories == max_calories`): **full (5) / consumable** art — **only** state where eating can occur; burst **5** then bush goes to **0** per §5.
9. **Play space** — Sample / shipping layouts should place **about 4–5** food bushes so survival depends on **moving between** sources **while dodging mobs**, not camping one bush.
10. **Session reset** — Matches §2 / §3: **each session** begins with **full** calories on the **player** and **every** food bush; no persisted hunger or bush depletion across sessions.
11. **Mob food awareness (decision-tree start)** — Mobs are modeled as **carnivores** relative to bushes: they **do not** gain **`current_calories`** from plants, **do not** run the player **eat** interaction on bushes, and **must not** change a bush’s **`current_calories`** or availability for the player. **Prey** is the **player** (ostensibly “eat the player”), not herbivory on bushes.  
    **Why track plants at all:** **Belief + planning** — mobs use **discovered** bushes and **awareness-limited** readiness to **predict player routing**, **contest** approach to food, and enrich avoidance-vs-pressure decisions (§4.11 bullets below remain for **intel**, not mob calorie pickup).  
    - **MVP (this phase — option C):** **Stub only** — e.g. register food bushes in a **`food_plants`** group and let **`mob.gd`** query nearest / list for **logging or placeholder scoring** without changing steering. If playtests show insufficient pressure, upgrade to full belief + motor hooks in a follow-up.  
    - **When beyond MVP C (target):** **Discovery:** If a mob has **never** perceived a plant, that plant is **unknown** to its food model (no guessed position).  
    - **Known plants:** Once **discovered**, a plant stays **known** for the session (at least identity + last known position — refinement in code).  
    - **Status belief:** **`current_calories` / readiness** vs **`max_calories`** is **only** updated while the plant is inside the mob’s **zone of awareness**. Use the **same numeric radius** as the creature motor’s **`awareness_radius`** from merged **`game_config`** / `creature_motor` (see `game_config_merge.gd` defaults and [cardinal_avoidance.gd](../../creature/motor/cardinal_avoidance.gd)) unless a future doc splits mob-specific sensing. **Outside** that zone, the mob **must not** treat plant state as automatically fresh omniscient truth; keep **last-known** snapshot with clear semantics **or** mark status **unknown** until the plant enters awareness again.
    - **Scope note:** **Mob vitals** may still exist for other systems (e.g. damage); **bush calories are player-only** this phase.

### Should have

- Bush scenes and textures under **`res://assets/plants/<archetype>/…`** with optional **`pack_resources.json`** per [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md).
- Single configurable export or Resource for **`max_calories`**, **`growth_rate`** per instance (align names with [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md); **`current_calories`** is the live pool—**no** separate `yield_calories`).

### Nice to have

- Brief eat **SFX**.
- Unit tests for calorie math / regrowth if logic is non-trivial pure functions.

---

## 5. Technical design

### 5.1 Architecture / data flow (words)

- **Bush placement:** Food shrubs are **their own authored scenes** under **`res://assets/plants/solid_shrub/`** (**Food A**) and **`res://assets/plants/open_shrub/`** (**Food B**). **Do not** fold them into **`obstacle_field`** tiers or **`obstacle_field_root`** as generic obstacle rows; place instances from **`main.gd`** (or a future level loader) alongside the obstacle system. Scripts may still mirror collision patterns from [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) where useful, but **assets and scenes** are **`assets/plants/`**-scoped.
- **`Player`** (or a small **`CreatureVitals`** helper it owns) holds **`current_calories`** / **`caloric_needs`**. Optional **`vitals_changed`** signal remains useful for **non-HUD** subscribers; **HUD** uses **polling** (§3, §5.3).
- Each **bush** instance owns **`current_calories`**, **`max_calories`**, and **`growth_rate`** (names per [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md)); burst grant reads **`current_calories`** when **`== max_calories`** only.
- **Regrowth:** On **`_process`** (or **`_physics_process`** with `delta` accumulation), increase plant **`current_calories`** by **1 × delta** per second toward **`max_calories` (5)**; clamp; **swap sprite** to **ready** vs **not-ready** texture when crossing **`max_calories`** (§5.4).
- **Calorie grant (player only, this phase):** **Burst** — one grant per **enter** or **first qualifying** contact while bush is **full**; debounce / one-shot per visit so **Food A** and **Food B** do **not** spam every frame. **Overflow** past **`caloric_needs`** on the player is **wasted** (§4). **Future:** **drip** while overlapping (especially Food B) for richer player tradeoffs.
- **Food A (solid):** **`solid_shrub`** **`StaticBody2D`** on **`world_static` (layer `1`)** with the **same layer/mask parity as `ObstacleField` rocks** so **player** and **mobs** both collide. Optional **`Area2D`** or **`CharacterBody2D`** contact handling on **`Player`** for burst calorie grant <<Comment: avoid double-counting on every physics frame unless explicitly designed>>.
- **Food B (creature-pass / mob-block):** **Chosen implementation — layer / mask split (Option A):** **`open_shrub`** uses (1) a **`StaticBody2D`** **mob shell** on dedicated layer **`plant_mob_block` (bit `8`)** with **`collision_mask`** including **mobs** so **`RigidBody2D`** contacts register, and (2) a separate **`Area2D`** **calorie zone** with **`collision_mask = 2`** (player layer only) for burst grants. **Player** keeps **`collision_mask`** on **`world_static` (bit `1`)** only — **excludes bit `8`**, so the creature **walks through** the shell. **`Mob`** **ORs** bit **`8`** into **`collision_mask`** (target **`9`** alongside **`world_static`**). **Mobs treat that shell like other solid obstacles** for blocking / avoidance. **Do not** put mobs on **two** physics layers in v1. **Authoritative bit table:** [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6**. **Future:** multi-sized creatures or richer pass rules may need more bits or math — extend **§6** in the same PR as code changes.
  - **Not chosen (v1):** `add_collision_exception_with(player)` as the primary Food B story (revisit only if layer budget or maintenance cost forces it).
- **Mob plant intel (post-stub):** When graduating from §4.11 **MVP C**, feed each mob (**`mob.gd`** or successor) **session-local** memory: **discovered** food plants; **refresh `current_calories` / readiness** only inside **awareness** (same **`awareness_radius`** as creature motor config). **Mobs never** invoke player-only eat logic or reduce bush pools.

### 5.2 Scene & file changes (starter table)

| Action | Path | Notes |
|--------|------|-------|
| create | `res://assets/plants/solid_shrub/…` | **Food A** — impassible impact bush; textures **`solid_shrub.png`**, **`solid_shrub_full.png`** (§5.4) |
| create | `res://assets/plants/open_shrub/…` | **Food B** — creature passes, mobs blocked per [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) §6; **`open_shrub.png`**, **`open_shrub_full.png`** |
| create | `res://assets/plants/bush_food.gd` (shared; or per-archetype scripts beside these folders) | Shared calorie / regrowth / **sprite** swap |
| modify | `res://player.gd` | Apply overlaps/collisions; drain hunger |
| modify | `res://hud.gd` | Top-right vitals; **poll `Player` every 10 `_process` frames** (§3); **display-only** |
| modify | `res://mob.gd` | **MVP:** `food_plants` group stub (§4.11); optional logging—**no** steering change required until follow-up |
| modify | `res://main.gd` | Instantiate **~4–5** sample bushes (see §3); **session reset** full calories on player + bushes; starvation → game over |

### 5.3 HUD layout

- **Anchor:** `Control` subtree — **top-right** (`anchors_preset` top-right or `anchor_right/top = 1` with negative margins).
- **Content:** At minimum a **`Label`** showing **`current_calories`** / **`caloric_needs`**; optional **`ProgressBar`** or **`TextureProgress`**.
- **Refresh model:** In **`_process`**, increment a counter; every **`10`** frames (see §3), read vitals from the **creature / `Player` node reference** (cached from **`main.gd`** or group lookup) and update labels. **Display-only**—**no** physics queries or collision changes from HUD. **Purpose:** shared pattern for **damage**, **fatigue**, and other polled vitals tunable via one interval constant. Signals (`vitals_changed`) are **optional** for other systems; **HUD path** is **poll-based** this phase.
- **Style:** Readable on busy background; consider **outline** or **panel** behind text.

### 5.4 Plant sprites (not ready vs ready)

**Approach:** Use **two authored PNGs per archetype** on the bush’s **`Sprite2D`** (or **`TextureRect`** if UI-layer); switch texture when `current_calories` crosses between **`< max_calories`** and **`== max_calories`**. **No** colored border overlay this phase.

**Asset paths:** Author PNGs under **`res://assets/plants/solid_shrub/`** and **`res://assets/plants/open_shrub/`** (per [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) and [ASSET_MANAGEMENT_PLAN.md](ASSET_MANAGEMENT_PLAN.md)); reference them from the matching **`.tscn`** in each folder when wiring scenes.

| Archetype | Not ready (`current_calories < max_calories`) | Ready (`current_calories == max_calories`) |
|-----------|-----------------------------------------------|--------------------------------------------|
| **Food B** — creature passes, mob blocked | **`open_shrub.png`** — empty / **no** calories available; **not** edible | **`open_shrub_full.png`** — **all 5** stored; **ready** to consume |
| **Food A** — solid, nothing passes through | **`solid_shrub.png`** — **inedible** (impassible, not consumable) | **`solid_shrub_full.png`** — **consumable** (still solid; burst eat when player qualifies) |

**Note:** PNGs live in **`solid_shrub/`** and **`open_shrub/`**; reference them from those **standalone plant** scenes (not from `obstacle_field`).

### 5.5 Dependencies

- **Assets:** Four PNGs per §5.4 (`open_shrub.png`, `open_shrub_full.png`, `solid_shrub.png`, `solid_shrub_full.png`) under **`res://assets/plants/solid_shrub/`** and **`res://assets/plants/open_shrub/`**; placeholders acceptable until art lands.
- **Plans:** [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md), [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md), [ASSET_MANAGEMENT_PLAN.md](ASSET_MANAGEMENT_PLAN.md).

---

## 6. Implementation plan (ordered)

1. Add **`current_calories`** / **`caloric_needs`** (exports or constants) on **`Player`** — **`caloric_needs` = 10**, drain **1/s**, starvation at **≤ 0** (immediate).
2. Extend **`HUD`** with top-right vitals: **`hud.gd`** polls **`Player`** every **10** `_process` frames (constant **tunable**); **read-only** UI; same poll hook reserved for future stats.
3. Implement shared plant logic in **`res://assets/plants/bush_food.gd`** (extend **`Node2D`** / **`Area2D`** / **`StaticBody2D`** as chosen): plant calorie pool, regrowth, **sprite / texture** swap (§5.4).
4. Author **Food A** scene under **`res://assets/plants/solid_shrub/`** (solid + impact calories) and place in **`main.tscn`** (or level loader).
5. Author **Food B** scene under **`res://assets/plants/open_shrub/`** (**§6** layer/mask split + z-order) and verify mob pathing still avoids / slides per OBJECT plan.
6. **`mob.gd` MVP (§4.11 C):** register bushes in **`food_plants`** group; optional list/query for logging—**no** required steering or full belief pipeline until follow-up.
7. Playtest: **~4–5** bushes, **session reset**, starvation at **1/s** drain vs **1/s** regrowth, duplicate-burst bugs, Food B **z-order**; mobs **never** strip bush calories.

---

## 7. Acceptance criteria

- [ ] Creature **`current_calories`** decreases **1 per second** (real-time integration) and increases when interacting with both bush types (bush grants only when **full**).
- [ ] **Food A** is **impassible** and grants a **single burst** on qualifying impact without duplicate grants under normal movement.
- [ ] **Food B** lets the **creature pass through** and grants a **single burst** on qualifying entry/overlap; **mobs cannot** treat the bush as free space (blocked or routed). **Later phase:** optional **drip** while overlapping.
- [ ] Top-right HUD shows calorie/hunger status, refreshed by **polling `Player` every 10** `_process` frames (tunable); **no** HUD-driven physics or world interaction.
- [ ] After depletion, plant **`current_calories`** **regrow** toward **`max_calories` (5)** at **1 per second**; when **`current_calories == max_calories`**, texture shows **`*_full.png`** again and the bush is **ready** for another burst.
- [ ] Bush **sprites** and **z-order** match §4.8 / §5.4 (player visually **under** pass-through shrub when overlapping Food B).
- [ ] **Calorie burst overflow** past **`caloric_needs`** is **wasted** (player does not exceed cap).
- [ ] Starvation at **`current_calories` ≤ 0** ends the round via the **same `game_over` path** as mob hit this phase (see backlog for future differentiation).
- [ ] **Session start** sets **player** and **all** food bushes to **full** calories; **no** cross-session persistence of hunger or bush pools.
- [ ] **Mobs — MVP C:** food bushes registered (e.g. **`food_plants`** group); **`mob.gd`** may query/list for **stub / logging**; **no** bush calorie mutation; **carnivore** vs player unchanged.
- [ ] **Layer/mask** matches [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6** (Food B split; mob **`collision_mask`** includes **`plant_mob_block`**; player does **not**).

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| **Double calorie grants** every physics frame | Use **one-shot** collision flags, **`Area2D` body_entered** debounce, or minimum cooldown timer. |
| **Layer/mask mistakes** — creature blocked by Food B | Integration test scene; visualize collision shapes in editor. |
| **Mob AI ignores new blocker** | Ensure obstacle query / static footprint feeds **mob motor** the same way other solids do (see OBJECT avoidance). |
| **Mob treats all plants as globally readable** | **Post-stub:** when full belief pipeline ships, add tests per §9; **MVP C** may skip omniscience tests. |
| **HUD lags vitals** | Display may trail true **`Player`** values by **up to the poll interval** (default **10** `_process` frames) — acceptable; document export. |
| **HUD clutter** | Keep single compact panel; scale with `canvas_items` stretch mode. |

---

## 9. Testing / verification

**Manual:**

- New session / **restart**: confirm **player** and **every** bush start **full**; no prior run bleeds through.
- **Mob belief (post-stub):** when full awareness-limited plant status is implemented, verify: bush **full** but **outside** mob awareness does not update mob “ready” belief until in range; deplete **outside** awareness — mob **must not** instantly know. **MVP C:** optional—stub may not expose beliefs yet.
- With **~4–5** bushes spaced for **rotation under mobs**, verify drain/regrowth still read as fair; stand still — drain continues (**not** movement-gated); **~10 s** to empty at **1/s** from full **10**.
- **Mob vs bush:** mobs **never** alter plant **`current_calories`**; collisions / AI **do not** trigger player eat logic.
- Walk through Food B — **one burst** per qualifying entry while bush is full; after regrow to **5**, **`*_full.png`** returns and another burst is allowed on a **new** entry cycle; mob paths around or stalls consistently.

**Automated (optional):**

- Pure functions for regrowth clamp + **which sprite / texture** to show given a calorie snapshot.

---

## 10. Open questions (embedded)

**Resolved this phase (do not reopen without a new phase note):** Creature drain **−1 calorie per second** and plant regrowth **+1 calorie per second** (real time, **not** movement-gated); **`caloric_needs` = 10** / **`max_calories` = 5** per bush; eat **only when `current_calories == max_calories`**; **burst overflow wasted**; regrow to full → **`*_full.png`** again; starvation **≤ 0** uses **same `game_over` path** as mob hit ([ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) for future death kinds); **saves out of scope**; level intent **~4–5** bushes (§4.9); **session reset** full pools (§2, §4.10); **mobs** **carnivore** / no bush calories (§4.11); **mob plant MVP C** = **`food_plants`** group **stub**; **post-stub** intel uses **`awareness_radius`** shared with creature motor; **HUD** polls **`Player` every 10** `_process` frames — **display-only** (§3, §5.3); **Food B** shrub **z-order above player** for tuck-in visual; **Food B collision = layer/mask split (Option A)** per [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6** — no dual-layer mobs in v1; **archetype folders** **`solid_shrub/`** and **`open_shrub/`** under **`res://assets/plants/`**; **burst** grant (**drip** later); **PNG pairs** per §5.4; shared logic **`res://assets/plants/bush_food.gd`** (name fixed for this phase); **no** `yield_calories`—align [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md) fields; **not** folded into **`obstacle_field`**.

---

## 11. References

- [CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md) — hunger fields.
- [PLANT_ECOLOGY_PLAN.md](../Draft_Features/PLANT_ECOLOGY_PLAN.md) — `current_calories`, `max_calories`, `growth_rate`.
- [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) — **§6** physics (**layer/mask split** for **`solid_shrub`** / **`open_shrub`**).
- [OBJECT_AVOIDANCE_PLAN.md](OBJECT_AVOIDANCE_PLAN.md) — locomotion, obstacles, mob detours.
- [ASSET_MANAGEMENT_PLAN.md](ASSET_MANAGEMENT_PLAN.md) — `assets/plants/` packaging.
- [.cursor/rules/focus/asset_management.md](../../.cursor/rules/focus/asset_management.md) — active **`res://assets/`** policy summary.
- [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — future differentiated death / `game_over` causes.

---

## 12. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-14 | **Food B:** **layer/mask split (Option A)** — authoritative table in [ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6**; **archetype paths** **`solid_shrub/`**, **`open_shrub/`**; fixed **`bush_food.gd`**; §5.1 / §5.2 / §6–§7 / §10 / references updated. |
| 2026-05-14 | **Implemented** in Godot: `player`/`main`/`hud`/`mob`, **`assets/plants/`** scenes; doc moved to **Completed_Features**. |
