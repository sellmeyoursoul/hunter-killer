# Hunter Killer — Hunger, calories, and bush food sources (agent-friendly)

> **Purpose:** Specify **hunger** / **calorie** gameplay for the Hunter Killer Godot project: bush-style food assets, two interaction archetypes (impact vs pass-through), creature HUD feedback, plant **calorie regrowth**, and simple **empty vs ready** visuals.
>
> **Terminology:** Use **calorie** / **calories** in code and docs (not “callory”). Align creature-facing fields with [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) (**`caloric_needs`**, **`current_calories`**).
>
> **Relationship to other docs:** Environment passibility and brush semantics intersect [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) and [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md). Long-term plant fields (regrowth rates, spread) extend [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md). New authored meshes/sprites belong under **`res://assets/`** per [Completed_Features/ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) (e.g. **`assets/plants/…`**).

---

## 1. Phase summary

**Phase name:** Hunger & eating (bushes + HUD + regrowth)

**One-line objective:** Add **bush** food sources that restore the playable creature’s **`current_calories`**, drain hunger over time or motion, show **hunger/calorie status** top-right, **regrow** depleted plant calories, and expose **empty** vs **ready** eat states with **red** vs **blue** borders.

**Out of scope (explicit non-goals):**

- Full ecosystem simulation (seeding, species competition) beyond calorie pool regrowth on placed bushes — defer to [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md).
- Mob hunger or mob eating <<Comment: confirm if mobs should ignore calories entirely for this phase>>.
- Networking / save-game persistence for hunger <<Question: persist hunger across sessions in this phase, or session-only?>>

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
- Obstacle / props: `res://obstacle_field.tscn`, `res://environment/obstacle_field_root.gd` <<Comment: bushes may be separate scenes instead of folding into obstacle tiers — pick one approach in §4>>
- Optional: `res://creature/` helpers if pulling stats into a small Resource

**Existing patterns to follow:**

- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md) and focus rules under [`.cursor/rules/focus/`](../.cursor/rules/focus/).
- Document new physics **layers/masks** or extend the project’s collision table <<Question: where is the authoritative layer map documented today — ENVIRONMENT_MODEL §6 vs code-only?>>

---

## 3. Requirements

### Must have

1. **Creature calorie pool** — Track **`current_calories`** with an upper bound **`caloric_needs`** (or equivalent) per [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md); derive optional **`hunger`** display if useful (e.g. ratio or inverted bar).
2. **Hunger drain** — Calories decrease over time or on movement <<Question: drain **per physics frame**, **per second**, or **only when creature moves** (per PLANTS_PLAN-style tick)? Pick one rule and starting rates>>.
3. **Starvation failure** — When **`current_calories` ≤ 0** (or crosses a starvation threshold), trigger **game over** or an agreed lose condition <<Question: immediate death at 0, or grace buffer?>> wired through existing **`main.gd` / `hud.gd`** patterns.
4. **Food source A — Impassible impact bush** — Stationary **solid** prop (creature **cannot** walk through). Grants calories on **collision impact** (first contact or sustained touch — pick one in §4).
5. **Food source B — Creature-pass / mob-block bush** — Creature **passes through** (no blocking collision for the player creature); **mobs do not** pass through (they experience it as a blocker or detour). Grants calories when the creature **passes through / overlaps** <<Question: single pulse per entry vs per-frame while inside — affects balance>>.
6. **HUD** — Upper **right** corner: readable **hunger/calorie status** (numeric and/or bar). Must update whenever **`current_calories`** changes.
7. **Calorie regrowth on plants** — Depleted plants regain **`current_calories`** up to **`max_calories`** over time using **`growth_rate`**-style semantics compatible with [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) <<Question: regrowth in **real seconds**, **physics ticks**, or abstract **game days** for this POC?>>.
8. **Visual states** — Clear distinction:
   - **Empty / no calories available:** **Red** border (no usable calories — still may show dead-looking sprite if desired).
   - **Ready / has calories:** **Blue** border.
   - <<Question: transitional state (partially regrown) — intermediate color, thin blue, or snap from red→blue only when `current_calories >= min_pickup`?>>

### Should have

- Bush scenes authored under **`res://assets/plants/…`** with optional **`pack_resources.json`** for shared SFX/sprites.
- Single configurable export or Resource for **`yield_calories`**, **`max_calories`**, **`growth_rate`** per instance.

### Nice to have

- Brief eat **SFX**; subtle sprite swap between empty vs full.
- Unit tests for calorie math / regrowth if logic is non-trivial pure functions.

---

## 4. Technical design

### 4.1 Architecture / data flow (words)

- **`Player`** (or a small **`CreatureVitals`** helper it owns) holds **`current_calories`** / **`caloric_needs`** and emits **`vitals_changed`** (or similar) when updated.
- Each **bush** instance owns **`current_calories`**, **`max_calories`**, **`growth_rate`**, and optionally **`yield_per_contact`** for impact-type sources.
- **Regrowth:** On **`_physics_process`**, **`Timer`**, or **world tick**, increase plant **`current_calories`** toward **`max_calories`**; clamp; refresh border color when crossing thresholds.
- **Food A (solid):** **`StaticBody2D`** (or grid-backed obstacle if aligned with baked env) + **`Area2D`** or **`CharacterBody2D` collision** handling on **`Player`** to apply impulse calorie grant <<Comment: avoid double-counting on every physics frame unless explicitly designed>>.
- **Food B (creature-pass / mob-block):** Requires **asymmetric collision**:
  - **Recommended:** separate **collision layers** — e.g. bush **blocker** shape on a layer in **mob masks** only; **`Area2D` calorie zone** on a layer **monitored** by **player** only. Document the exact bitmask table in code comments + this doc when implemented.
  - **Alternative:** bake **different kind ids** into **`EnvironmentGridBaked`** for mob vs player <<Comment: heavier lift — only if we want one subsystem for both>>.

### 4.2 Scene & file changes (starter table)

| Action | Path | Notes |
|--------|------|-------|
| create | `res://assets/plants/bush_impact/…` | Impassible impact bush scene + sprite |
| create | `res://assets/plants/bush_pass_mob_block/…` | Pass-through for creature, blocks mobs |
| create | `res://plants/bush_food.gd` (or per-archetype scripts) | Shared calorie / regrowth / border logic <<Comment: single script with export enum vs two scenes — avoid duplication>> |
| modify | `res://player.gd` | Apply overlaps/collisions; drain hunger |
| modify | `res://hud.gd` | Top-right anchor; bind to vitals |
| modify | `res://main.gd` | Instantiate sample bushes; starvation → game over |

### 4.3 HUD layout

- **Anchor:** `Control` subtree — **top-right** (`anchors_preset` top-right or `anchor_right/top = 1` with negative margins).
- **Content:** At minimum a **`Label`** showing **`current_calories`** / **`caloric_needs`**; optional **`ProgressBar`** or **`TextureProgress`**.
- **Style:** Readable on busy background; consider **outline** or **panel** behind text.

### 4.4 Border visuals (empty vs ready)

- Implement as **`Panel`**/`**NinePatchRect`** `border_color` / **`StyleBoxFlat`** border **width + color**, or a **`ColorRect`** frame parent.
- **Mapping:**

| Plant calories | Border color | Notes |
|----------------|--------------|-------|
| `current_calories <= 0` (or `< min_pickup`) | **Red** | “Empty” |
| `current_calories >= min_pickup` | **Blue** | “Ready to eat” |

<<Question: confirm hex or Godot named colors — e.g. red `#cc3333`, blue `#3366cc` for WCAG-ish contrast?>>

### 4.5 Dependencies

- **Assets:** Bush sprites (placeholder acceptable); optional audio.
- **Plans:** [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md), [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md), [Completed_Features/ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md).

---

## 5. Implementation plan (ordered)

1. Add **`current_calories`** / **`caloric_needs`** (exports or constants) on **`Player`** + drain + starvation hook.
2. Extend **`HUD`** with top-right vitals control; subscribe to player signals or poll from Main <<Question: signal-first vs Main pushes each frame?>>.
3. Implement shared **`BushFood`** (name TBD) logic: plant calorie pool, regrowth, border colors.
4. Author **Food A** scene (solid + impact calories) and place in **`main.tscn`** (or level loader).
5. Author **Food B** scene (layered collision for creature overlap + mob block) and verify mob pathing still avoids / slides per OBJECT plan.
6. Playtest: starvation timing, double-grant bugs, regrowth feels fair.

---

## 6. Acceptance criteria

- [ ] Creature **`current_calories`** decreases per agreed drain rule and increases when interacting with both bush types.
- [ ] **Food A** is **impassible** and grants calories on **impact** without duplicates bugs under normal movement.
- [ ] **Food B** lets the **creature pass through** and grants calories on pass-through; **mobs cannot** treat the bush as free space (blocked or routed).
- [ ] Top-right HUD shows live calorie/hunger status during play.
- [ ] After depletion, plant **`current_calories`** **regrow** toward **`max_calories`** per agreed time base.
- [ ] **Red** border when empty; **blue** border when ready <<Question: define exact threshold constants in code + mirror here>>.
- [ ] Starvation ends the round via existing game-over flow (or documented alternate).

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| **Double calorie grants** every physics frame | Use **one-shot** collision flags, **`Area2D` body_entered** debounce, or minimum cooldown timer. |
| **Layer/mask mistakes** — creature blocked by Food B | Integration test scene; visualize collision shapes in editor. |
| **Mob AI ignores new blocker** | Ensure obstacle query / static footprint feeds **mob motor** the same way other solids do (see OBJECT avoidance). |
| **HUD clutter** | Keep single compact panel; scale with `canvas_items` stretch mode. |

---

## 8. Testing / verification

**Manual:**

- Stand still vs move — verify drain matches §3.
- Repeated bash vs Food A — calories stable after intended rule.
- Walk through Food B — calories increment; mob paths around or stalls consistently.

**Automated (optional):**

- Pure functions for regrowth clamp + border state given calorie snapshot.

---

## 9. Open questions (embedded)

<<Question: Hunger drain — per frame, per second, or only when moving? Starting numeric values?>>

<<Question: Calorie grant — burst on first touch vs steady drip while overlapping?>>

<<Question: Regrowth clock — real time, physics ticks, or abstract days?>>

<<Question: Should mobs ever consume bushes later, or permanently ignore?>>

<<Question: Persist hunger in save data for this phase?>>

---

## 10. References

- [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) — hunger fields.
- [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md) — `current_calories`, `max_calories`, `growth_rate`.
- [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) — terrain / brush alignment.
- [Completed_Features/OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) — locomotion, obstacles, mob detours.
- [Completed_Features/ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) — `assets/plants/` packaging.
