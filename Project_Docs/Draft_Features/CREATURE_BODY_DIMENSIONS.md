# Hunter Killer — Creature body dimensions plan

> **Status:** `design` for Phases 1, 2, 4, 5 (draft; no code yet). **Phase 3 (facing) is `done`: shipped 2026-10-05 in bfcbd26 and user-confirmed in play** (§5, B26). All questions BQ1–BQ16 are answered (BQ1–BQ12 on 2026-10-01 as B6–B17; BQ13–BQ16 on 2026-10-02 as B18–B21). B24 and B25 (2026-10-02) refine the capsule height and the reach extent; B27 (2026-10-05) settles the eat-gate target side. No `<<Question>>` markers remain open.
>
> **Origin.** Split out of [NAVIGATION_PASSABILITY_PLAN.md](NAVIGATION_PASSABILITY_PLAN.md) Q10 (path radius: enclosing capsule or body width?) on 2026-10-01. That plan's Q10 and Q12 now wait on this doc. The user wants this doc settled before work returns to the navigation plan.
>
> **Decisions 2026-10-01 (user, in conversation; §6 B1–B5).** Authored length / width / height are canonical and the model conforms (B1). Models are scaled uniformly at mount, with a proportion check and a limited allowance for variety stretch (B2). Tooling exists on both ends: a measuring / proposal tool in the game, and dimension-driven generation in the art pipeline (B3). The facing convention was −Z forward, Y up, enforced when the model is created (B4, **superseded 2026-10-02 by B22: +Z forward**). The movement radius is width / 2 × 1.10, and creatures whose width ≤ length never strafe (B5).
>
> **Decisions 2026-10-01 (user, answers to BQ1–BQ12 in §10; §6 B6–B17).** Dimensions are in game units with one documented factor (~4 units per real metre, estimate), no world rescale; HK-models exports 1 Blender unit = 1 game unit (B6, with a post-landing cleanup item). Dimensions measure the whole-mesh AABB in the neutral rest pose (B7). Proportion check warns > 10% and fails > 20% per axis; variety stretch ±10% per axis via bone-chain scaling with a Visual-scale fallback; one shared tolerance spec (B8, pre-tuning baseline). The archetype `.tres` is the source of truth and the tool works in both directions (B9). Origin at ground contact, centred on the rest-pose AABB XZ footprint, with an existing-model review (B10). `creature_size = max(L, W, H)` on live dimensions (B11). A headless game tool plus a Blender checklist share one definition (B12). Dimensions come from design intent; all current models are placeholders, fitted non-uniformly and exempt from proportion failure; a fox archetype is added and the wolf 3× wrapper removed (B13). Low bodies clamp capsule height up to 2r (B14). Reach is a scalar with no oriented hit shape (B15). Nose / tail overhang is accepted for now (B16). Nav class membership declares both max radius and max `creature_size` (B17).
>
> **Decisions 2026-10-02 (user, answers to BQ13–BQ16 in §10; §6 B18–B21).** One shared tolerance JSON in this repo (`tools/`), read by the Blender checklist by relative path and by the game tool; `width_margin` lives in `game_config.json` (B18). The placeholder flag lives in a pack's `pack_resources.json`, only where a model deviates from the production default; placeholder mounts auto re-centre the origin (B19). Design-intent dimensions: rabbit 1.7 / 0.7 / 1.4, fox 2.0 / 0.4 / 0.9, wolf 6.0 / 1.3 / 3.0 (B20). The old hit `Area3D` stays untouched until the template cleanup (B21).
>
> **Decision 2026-10-02 (user, in conversation; §6 B22).** Forward axis: the model-forward convention switches to **+Z** (Godot's `MODEL_FRONT`; the Blender nose points along −Y, Blender's default character facing). This supersedes B4's −Z. The game's facing math needs a small code change (§4.8, Phase 3).
>
> **Decisions 2026-10-02 (user, in conversation; §6 B24, B25).** Capsule height uses Godot 4 total-height semantics: height = `body_height`, clamped to at least 2r (B24, refines B14). Reach extent becomes `live_length / 2 + reach_margin_fraction × live_length` (default fraction 0.25, i.e. 0.75 × length from the body centre), overridable per creature by `reach_override` (B25, supersedes the reach part of B15).
>
> **Finding and decision 2026-10-05 (user observation, verified in Godot; §2.1.1, §4.8.1, §6 B26).** In live play the awareness cone turns at a different rate / direction than the model and creatures appear to walk forward, backward and sideways. Root cause: `MotorPlane.yaw_from_horizontal_dir` (`atan2(d.x, -d.z)`) is **mirrored left / right** for the Visual; it is correct only for ±Z headings. B26 fixes it inside the Phase 3 change set, with a real-engine-rotation acceptance test. Phase 3 was the **highest-priority phase and shipped before Phases 1 / 2** (2026-10-05, bfcbd26; §5). B23's claim that the derivation "reproduces today's formula" is corrected (§4.8.1).
>
> **Decision 2026-10-05 (user, in conversation; §4.7, §6 B27).** Eat-gate target side: option (a). The target-side term is the target's **body radius** (same pairing as C1 contact: the predator's mouth / reach meets the prey's side); the eater's term is its reach extent (B25). Gate = `eat_action_max_distance` (5) + eater reach + target body radius; plants contribute 0.
>
> **Sourcing.** The code facts in §2 were verified by the caller on 2026-10-01 and are marked "caller-verified" with approximate line numbers. The B24 / B25 pass (2026-10-02) re-read `creature_mesh_footprint.gd`, `creature_kinematic_body_3d.gd` and every §4.7 consumer; line numbers in §4.7 / §4.8.1 are re-verified as of that date. Facts about the art pipeline come from the caller's reading of `../HK-models/3d_modeling_v1.md`, a sibling folder **outside this repo** that is not a git repo. This doc does not edit that file; §4.9 lists the edits it needs.

---

## 1. Phase summary

**Phase name:** Creature body dimensions (authored L / W / H as the single size truth).

**One-line objective:** Every creature's collision, pathing, reach and size-class numbers come from three authored body dimensions. The visual model is fitted to those dimensions, not the other way round.

**Problem in one paragraph.** Today the live capsule is **derived from the visual mesh**. Its radius is half the **longer** horizontal extent of the mesh AABB, which for a quadruped is half the nose-to-tail length. Its height is forced to at least 2r. So every creature is an upright cylinder about as wide as it is long, and the wolf's capsule is ~15.3 m tall. The authored `.tres` size fields are fallbacks only. Art workarounds (the wolf's 3× scale wrapper with pivot compensation) exist to make the derived capsule come out right. Runtime size change scales the `CharacterBody3D` itself, which Godot discourages. Pathing then erodes the navmesh by this oversized radius (NAVIGATION_PASSABILITY §3.1), and nothing tells the art pipeline what proportions a model should have.

**Out of scope (explicit non-goals):**
- Navigation class boundaries, map baking and the `NavRouter` (NAVIGATION_PASSABILITY). This doc only supplies the radius and size those depend on (§4.10).
- Combat, damage or hitbox **kill** semantics. Contact-hitbox kills stay removed ([CREATURE_MOVEMENT_V3_CLEANUP.md](CREATURE_MOVEMENT_V3_CLEANUP.md) D11). This doc only defines the hit **extent**.
- A rotating or swept collision shape. The movement capsule stays axis-aligned (B5, §4.5).
- Strafing locomotion for crab-like bodies (noted in §4.5; no decision).
- Animation, rigging and skinning, beyond what bone-chain variety stretch needs (B8).
- Editing `../HK-models/3d_modeling_v1.md`. The caller makes that edit (§4.9); All questions are now settled (B6–B21); the shared spec for item 5 is `tools/body_dimension_spec.json` (B18).
- A world rescale to real-metre units, and moving species sizes or hard-coded distances toward realistic proportions. Both are a **post-landing cleanup** (B6, §5.1), not part of this feature.

---

## 2. Context for agents

**Repo / project root:** `hunter-killer/`
**Engine & version:** Godot 4.7 (per NAVIGATION_PASSABILITY §2; the project overview memory says 4.6). GDScript.
**Main scenes / entry:** creature mount in [`creature/creature_root_3d.gd`](../../creature/creature_root_3d.gd); body in [`creature/capabilities/creature_kinematic_body_3d.gd`](../../creature/capabilities/creature_kinematic_body_3d.gd); headless tests `tests/run_all.gd`.

### 2.1 Current size pipeline (caller-verified 2026-10-01)

| Step | Where | What it does today |
|---|---|---|
| Footprint from mesh | `creature/capabilities/creature_mesh_footprint.gd` 57–61 | `radius = max(sx, sz) * 0.5`, which is half the **longer** horizontal AABB extent (nose to tail for quadrupeds). `height = sy - 2r` (Godot-3 cylinder-section style; if < 0.2, `max(0.2, 0.55 sy)`), then clamped to ≥ `2r + 0.05`. The kinematic body then assigns this value **directly** to `CapsuleShape3D.height` (Godot 4: total height), after a second `max(.., 2r + 0.05)` (`creature_kinematic_body_3d.gd` 193–195, 213–214, 227–229, 234–236). Net effect: for tall bodies the capsule is **shorter** than the model by 2r; for long, low bodies it is forced up to ~2r. B24 replaces this. |
| Apply to body | `creature_kinematic_body_3d.gd` `apply_capsule_footprint_from_visual` ~205, called from `creature/creature_root_3d.gd` ~149 | Applies a **0.92 inset** to the radius. |
| Hit capsule | `creature_kinematic_body_3d.gd` ~233 | Radius = **1.15 ×** body radius. |
| Runtime size change | `creature_kinematic_body_3d.gd` ~223 | `scale = Vector3.ONE * factor` on the **`CharacterBody3D` itself**. Godot discourages scaling physics bodies. |
| Facing offset | `creature_kinematic_body_3d.gd` ~28 | Extra Visual Y rotation for meshes whose forward is not the code's assumed model-forward axis (**+Z since 2026-10-05, B22 shipped**; `visual_yaw_offset_rad` per [CREATURE_3D_ARCHITECTURE §4](../Definitive_Features/CREATURE_3D_ARCHITECTURE.md)). Both herbivore and carnivore kinematic templates set the export (`creature_*_kinematic_3d.tscn`). The capsule stays axis-aligned (~719). |
| Authored fallbacks | `creature/definition/creature_definition.gd` ~31–32 | `creature_size`, `collision_capsule_radius` (and height). Used **only** when no visual is mounted. |

**Archetypes on disk:** only `creature/species/rabbit_archetype.tres` (size 1.7 / radius 0.6 / height 2.0) and `wolf_archetype.tres` (6.0 / 7.0 / 15.3). The fox has a pack (`assets/creatures/fox/`) but **no archetype**. Its live radius of 2.343 comes from the AABB of `fox.blend` through the same formula. This answers NAVIGATION_PASSABILITY §3.1's comment on where the fox radius comes from.

**All current rabbit / fox / wolf models are temporary placeholders** (user, 2026-10-01, B13). They will be replaced once the HK-models pipeline is resolved. Phase 0 measurements of these models (recorded here when taken) are **reports** on the placeholders, not the source of the species dimensions; those come from design intent (B13).

**Wolf wrapper:** `wolf_3d.tscn` wraps the shared placeholder `wolf.blend` mesh in a **3× scale plus a pivot-compensation translation** (tests in `tests/run_all.gd` ~962–1010). `creature_root_3d.gd` `_SPECIES_MESH_FILE` maps `&"wolf"` to `wolf_3d.tscn` ([PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md) wolf slice). This is an art workaround that makes the derived capsule come out right.

**Consequence.** Every creature is an upright cylinder with radius ≈ half its body length, and its height is forced to ≥ 2r. That is why the wolf capsule is ~15.3 m tall, and why NAVIGATION_PASSABILITY erodes its whole navmesh by 7.25 m.

#### 2.1.1 Phase 0 measurement reports (2026-10-02; placeholders, not the species spec, B13)

Measured with `tools/measure_body_dimensions.gd` against `tools/body_dimension_spec.json` (committed 62d372d). Raw values are the whole-mesh rest-pose AABB in model units: L = Z extent, W = X extent, H = Y extent (the tool's pre-B22 axis assignment). "Pivot" is the offset of the AABB bottom-centre from the model origin (B10 wants it at 0).

| Model | Raw L(z) / W(x) / H(y) | Pivot offset (x, y, z) | B10 pivot (tol) | Long horizontal axis (L/W) |
|---|---|---|---|---|
| `rabbit.blend` | 3.431 / 3.773 / 3.517 | (0.928, −0.498, −0.126) | FAIL (tol 0.069) | X (1.10) |
| `fox.blend` | 3.343 / 5.094 / 2.937 | (0.796, −0.517, 4.757) | FAIL (tol 0.067) | X (1.52) |
| `wolf.blend` (raw) | identical to `fox.blend` | identical to `fox.blend` | FAIL (tol 0.067) | X (1.52) |
| `wolf_3d.tscn` (3× wrapper) | 10.030 / 15.282 / 8.811 | (0, −4.405, 0) | FAIL | X |

**Fit against the B20 design intent.** Assuming a 90° yaw so that L := X extent and W := Z extent, with a uniform fit scale on L. Fitted W / H vs design:

| Model | Fit scale | Fitted W vs design | Fitted H vs design |
|---|---|---|---|
| rabbit | 0.451 | 1.546 vs 0.70 (+121%) | 1.585 vs 1.40 (+13%) |
| fox | 0.393 | 1.313 vs 0.40 (+228%) | 1.153 vs 0.90 (+28%) |
| wolf raw | 1.178 | 3.938 vs 1.30 (+203%) | 3.459 vs 3.00 (+15%) |
| wolf mounted (wrapper) | 0.393 | same as the raw row after re-fit | same as the raw row after re-fit |

**Findings**
1. **The fox placeholder is the wolf mesh.** `fox.blend` and `wolf.blend` have identical AABBs and pivots; the fox is the wolf model at a smaller scale.
2. **All three models are long along X, not Z.** Neither −Z nor +Z is their forward; the long axis says ±X, and the AABB cannot give the sign. Phase 3 needs a ±90° (not only 180°) pack / template override per model, with the sign set by a visual check in Blender / Godot. The existing template `visual_yaw_offset_rad` values (herbivore π/2, carnivore 3π/2) were tuned against the current (mirrored, see finding 7) −Z formula. The B22 / B26 override must be **reconciled with them, not stacked**: the net Visual yaw is what matters. **Superseded by finding 7:** the "each offset moves by π" reasoning is dropped; the facing-check results give the final value directly. See §4.8.1 and §5 Phase 3.
3. **No model meets the B10 pivot.** All four rows fail; the fox / wolf Z offset of 4.757 is the largest, the wrapper deliberately centres on the AABB centre (origin at mid-height, Y offset −4.405).
4. **The placeholder re-centre (B19, §4.3) must fix Y as well as XZ**: the AABB bottom goes to ground (body origin), not only the footprint centre. The wrapper's mid-height origin and the raw models' −0.5 Y offsets both need it.
5. **A per-axis placeholder fit is essential.** Fitted widths are 1.2 to 3.3 times the design widths (+121% to +228%), and heights are +13% to +28%; a uniform fit on length alone would give absurdly wide bodies.
6. **Diagnosis check.** The wrapped wolf half-X extent of 7.641, after the 0.92 inset, gives 7.03, matching the old 7.0 radius and confirming the §2.1 pipeline diagnosis.
7. **Facing-check results and the mirrored-yaw root cause (2026-10-05; `tools/facing_check_3d.tscn`, plus live-play observation verified in Godot).** In live play the awareness cone turns at a different rate / direction than the model, and creatures appear to walk forward, backward and sideways. Cause: `MotorPlane.yaw_from_horizontal_dir(d) = atan2(d.x, -d.z)` is **mirrored left / right** for the Visual. Godot's Y rotation is counter-clockwise seen from above, so `Basis(UP, yaw) * F` for F = −Z gives `(−sin yaw, 0, −cos yaw)`; with the old yaw a heading of +X puts the model nose toward −X. The formula is right only for ±Z headings. The awareness overlay draws from `last_move_direction` directly, so it is correct, and the mismatch with the model is what the user saw. The existing round-trip test (`tests/run_all.gd` ~13085) rebuilds a direction with `(sin(yaw), 0, −cos(yaw))`, the same wrong formula, so it could not catch the mirror. Facing-check scene results: at heading −Z with the old formula the **rabbit** nose lies along the arrow with the herbivore offset π/2, while the **fox / wolf** (carnivore offset 3π/2) are 180° off. The three model files share one nose direction. Hence under the **corrected +Z formula both templates need `visual_yaw_offset_rad` = 3π/2 (= −π/2)**. Final values are confirmed by the visual check at headings ±X, ±Z (§7). **Shipped 2026-10-05 (bfcbd26): both templates are now 3π/2 and the formula is corrected; user confirmed in play.**

### 2.2 Facing and locomotion (caller-verified 2026-10-01)

- V3 `creature/motor/locomotion_executor.gd` already moves the body **only along ±facing**: `_displace_along_facing` (~52 / 54) and blended turn + move (~117–131). The default `move_turn_rate_deg_per_sec` is 1350. **V3 has no strafing today.**
- The capsule does not rotate, so it does not model the sweep of a long body turning (§4.5).

### 2.3 Consumers that add capsule radius to distances (caller-verified 2026-10-01; full audit in §4.7)

`motor_planner.gd` eat reach bonus (4236–4240), own diameter (4029–4030), `_agent_radius` (4653–4655). `flee_candidate_scoring.gd` threat capsule (`threat_capsule_radius` 43–52, `threat_capsule_height` 58–67). `creature_motor_stack.gd` 350 and 1553–1554. `creature_kinematic_body_3d.gd` ghost-fit (601–602) and LoS eye height (183). All re-read 2026-10-02 (§4.7). From docs (not re-read): shelter fit and choke credit ([PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md)), C1 contact geometry ([CREATURE_MOVEMENT_V3_CLEANUP.md C1](CREATURE_MOVEMENT_V3_CLEANUP.md#c1--pursuit-contact-geometry-stall-fox)), the navmesh `agent_radius` (NAVIGATION_PASSABILITY §2.1), and the ghost-fit clamp / `RoutePlausibilityScan`, which sweep the body capsule.

### 2.4 External art pipeline (`../HK-models/3d_modeling_v1.md`, per caller)

- **Stage 2** generates the model with Hyper3D Rodin (image to model). The MCP tool `generate_hyper3d_model_via_images` accepts `bbox_condition` = [Length, Width, Height] **ratio** and outputs a normalized size. The Hunyuan3D fallback has **no** bbox parameter.
- **Stage 6** exports glTF `.glb`, Y-up, 1 Blender unit = 1 m = 1 Godot unit. **Superseded by B6:** 1 Blender unit = 1 **game** unit (~0.25 real m); the "= 1 m" part of that statement changes in the §4.9 edit.
- Its **Variation Strategy** plans per-instance bone-chain scaling (torso girth, leg length) and shape keys. B8 adopts bone-chain scaling as the primary variety mechanism.

### 2.5 Unit convention (B6)

- **Authored dimensions, speeds and distances are in game units.** One documented project factor: **~4 game units per real metre** (author's estimate from today's rabbit 1.7 / wolf 6.0 sizes, not measured). No world rescale now; gravity, physics feel and all tuned distances stay as they are.
- **Art export:** 1 Blender unit = 1 game unit. A model exported at its species' authored dimensions mounts at fit scale ≈ 1.
- With the B2 fit, a model's absolute exported size does not affect gameplay (only ratios do), but exporting in game units keeps the tool's reports and the fit scale readable.
- **Post-landing cleanup** (not a phase gate): §5.1.


**Existing patterns to follow:** [root CLAUDE.md](../../CLAUDE.md), [Project_Docs/CLAUDE.md](../CLAUDE.md), [assets/CLAUDE.md](../../assets/CLAUDE.md) (pack layout, `pack_resources.json`). Ground-truth sizes, with noise only at tactical decisions (PHYSICS_SQUEEZE decisions 8 / 18). Runtime size change per PHYSICS_SQUEEZE decision 5.

---

## 3. Requirements

### Must have
- **M1.** `CreatureDefinition` declares `body_length`, `body_width` and `body_height`. These are the only authored size inputs (B1).
- **M2.** Movement capsule, hit extent, `creature_size` and the pathing radius are all **derived** from the live dimensions. Nothing derives them from the mesh AABB (B1).
- **M3.** The `CharacterBody3D` is never scaled. Shapes are resized directly, and only the Visual node is scaled (B1).
- **M4.** A **production** model is scaled uniformly at mount. A proportion mismatch beyond the warn tolerance (> 10% per axis, B8) logs a warning and is never silently stretched to fit (B2). A **placeholder** model (B13) is instead scaled non-uniformly to hit all three authored dimensions, and its mismatch is reported as a warning, never a failure.
- **M5.** Creatures with `body_width ≤ body_length` move only along ±facing. This is an invariant with a test (B5).
- **M6.** Every consumer of "capsule radius" is classified as **body radius** or **reach extent** and uses the matching accessor (§4.7).
- **M7.** A headless measuring tool under `tools/` reports a model's L / W / H, pivot and forward axis, and checks its ratios against the archetype (B3a, B12). It reports pivot-convention violations (B10) on every model, placeholders included. It works in both directions (B9): spec-first (check a model against an archetype) and model-first (propose a dimension block from a model).
- **M8.** Runtime size change (decision 5) rescales the dimensions and re-derives every shape without scaling the body.
- **M9.** `creature_size` is derived as `max(live_length, live_width, live_height)` (B11).
- **M10.** Models are **production-standard by default**. A placeholder flag (name proposal `placeholder_model`) is stored in the pack's `pack_resources.json` and appears **only** for a model that deviates from the standard (B19); it marks temporary models for the B13 exemption. Today the rabbit, fox and wolf packs carry it.

### Should have
- **S1.** The art pipeline feeds the archetype's L : W : H ratio to Rodin `bbox_condition` (B3b, B9).
- **S2.** One shared tolerance / ratio definition is used by the game tool and the Blender checklist (B8, B12; one JSON, `tools/body_dimension_spec.json`, B18).
- **S3.** Per-instance variety stretch of ±10% per axis, via bone-chain scaling with a Visual-scale fallback, with collision following the instance's actual dimensions (B2, B8).
- **S4.** The facing (+Z forward, B4 superseded by B22) and pivot conventions are enforced at model export (B22, B10). The Visual yaw offset becomes a legacy override.

### Nice to have
- **N1.** *(Promoted to M7 by B9: model-first dimension proposals.)*
- **N2.** A debug overlay draws the movement capsule, the reach extent and the rest-pose AABB side by side.

---

## 4. Technical design

### 4.1 Data model (B1)

| Field | Authored? | Meaning |
|---|---|---|
| `body_length` | yes | Extent along the facing axis (+Z model-forward, B22) of the whole-mesh AABB in the neutral rest pose, tail included (B7). Game units (B6). |
| `body_width` | yes | Extent across the facing axis (X), same measure (ears included). |
| `body_height` | yes | Extent along Y, ground contact to top, same measure. |
| `creature_size` | **derived** | `max(live_length, live_width, live_height)` (B11), which matches the definition "longest body dimension" in [CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md). Tall creatures (large bipeds, a giraffe) are measured by height. |
| `collision_capsule_radius`, `collision_capsule_height` | **removed** as authored fields | Replaced by the derivations in §4.2. |

**Source of truth (B9).** The species archetype `.tres` (`CreatureDefinition` leaf data) holds the authored dimensions. This is consistent with Definitive [CREATURE_3D_ARCHITECTURE.md §2](../Definitive_Features/CREATURE_3D_ARCHITECTURE.md) (~31), which already defines the archetype `.tres` as leaf data carrying "collision capsule hints". The numbers are copied into the HK-models subject spec at Stage 1 (§4.6 b).

**Rest pose (B7).** "Neutral rest pose" is read here as the armature rest (bind) pose with no animation applied; an unrigged model is measured as exported.

**Live dimensions** = authored dimensions × the runtime size factor (decision 5, uniform) × the per-instance variety stretch (per axis, ±10%, B8). Every derived value in §4.2 reads the live dimensions, never the authored ones directly.

### 4.2 Derived shapes

| Derived value | Formula (proposal; B5 margin) | Used for |
|---|---|---|
| **Body radius** (movement capsule radius) | `live_width / 2 × (1 + width_margin)`, with `width_margin` starting at **0.10**, tunable, stored in `game_config.json` with the other motor tuning (B18) | `move_and_slide` contact, ghost-fit clamp, route scan, pathing radius / class (NAVIGATION_PASSABILITY D7) |
| **Capsule height** | `CapsuleShape3D.height = max(live_height, 2 × body_radius)` (B24, Godot 4 total-height semantics; B14: low / wide bodies clamp **up** to 2r and the clamp is logged; revisit after seeing it in practice). No `− 2r` subtraction and no `+ 0.05` floor. | Collision height, navmesh class `agent_height`, LoS eye height |
| **Reach extent** | `reach_override` if set (absolute distance from the body centre along facing, B25), else `live_length / 2 + reach_margin_fraction × live_length` = `live_length × (0.5 + reach_margin_fraction)`; default fraction **0.25**, so **0.75 × live_length**. A **scalar** (B15 scalar part stays). | Eat reach, contact geometry (§4.7). Consumers compare centre distance against it numerically. |
| **Hit extent** | **No separate oriented hit shape** (B15). Reach is the scalar above. The legacy axis-aligned `MobHitbox` `Area3D` is left to the template cleanup (B21); until then it is 1.15 × the new body radius, with no new logic. | Hitbox `Area3D` overlaps, if any remain |
| `creature_size` | `max(live_length, live_width, live_height)` (B11) | `fit_size` compares (NAVIGATION_PASSABILITY D5), `stat_fit`, env slowdown, nav class membership (B17) |

Proposed accessors (names are proposals): `get_body_radius()`, `get_reach_extent()`, `get_body_dimensions()`. `get_collision_capsule_radius()` is retired or kept only as an alias of `get_body_radius()`; its current ambiguity is the reason for the audit in §4.7.

**`get_reach_extent()` (B25).** Returns `reach_override` (scaled by the uniform runtime size factor, decision 5, like the authored dimensions; not by variety stretch) when the definition sets one, otherwise `live_length × (0.5 + reach_margin_fraction)`, with `reach_margin_fraction` read from `game_config.json` through the `game_config.gd` facade. The value is a distance **from the body centre** along facing, not from the nose. No minimum is enforced (an override may deliberately be shorter than the nose position). Worked values with the default fraction 0.25 and the B20 lengths: rabbit 1.7 → **1.275 (~1.28)**, fox 2.0 → **1.5**, wolf 6.0 → **4.5**.

**`reach_override` (B25).** An optional `@export var reach_override: float` on `CreatureDefinition` (archetype `.tres`), default `0.0` / unset meaning "use the computed value". When set (> 0) it **replaces** the computed value entirely. It is an **absolute distance from the body centre** in game units at size factor 1 (recommended, and adopted here: one meaning, no mixing with the fraction, directly comparable to the table above). It is not a fraction and not a delta on top of the computed value.

**Capsule height semantics (B24; resolves the former `<<Comment>>`).** Godot 4 contract: `CapsuleShape3D.height` is the **total** height including both hemispherical caps, and it must be ≥ 2 × `radius`. Code check (2026-10-02): the kinematic body already treats it as total height, assigning `cap.height = fit_height` directly with `fit_height = max(base_height, 2r + 0.05)` (`creature_kinematic_body_3d.gd` 193–195, 227–229, 234–236). But `creature_mesh_footprint.gd` 57–61 feeds it a Godot-3-style cylinder-section value, `sy − 2r` (then clamped `≥ 2r + 0.05`). So today's capsule is **2r shorter than the mesh** for tall bodies and is forced up to ~2r for long, low bodies. The B1 derivation replaces that chain: height = `body_height`, clamped to at least 2r (B14 clamp **kept** and reconciled: the clamp now binds exactly at `body_height < 2r`; the old `+ 0.05` floor and `0.55 sy` fallback go away). Also note `get_los_eye_height()` (183) is `0.9 × capsule height`, so it becomes `0.9 × max(live_height, 2r)`; for a clamped low body that sits above the model (see §8).>

### 4.3 Mount and fit flow (B1, B2)

1. `creature_root_3d.gd` mounts the Visual as today.
2. Measure the whole-mesh AABB of the mounted Visual in the neutral rest pose (B7) in the body's local frame, **before** any facing offset.
3. **Production model:** compute one **uniform** scale `s = live_length / model_length` (fit on length, the axis the reach extent uses) and apply it to the **Visual node only**. **Placeholder model** (B13, flagged in the pack's `pack_resources.json`, B19): compute per-axis scales `s_x = live_width / model_width`, `s_y = live_height / model_height`, `s_z = live_length / model_length` and apply them to the Visual node, so the visual hits the authored dimensions. The fit also **re-centres the origin** (B19): it translates the Visual so the scaled rest-pose AABB bottom-centre sits on the body origin; no re-export is needed. The user's stated preference: model distortion to match correct dimensions beats unrealistic dimensions to match models.
4. Check proportions against the uniform fit: compare `model_width × s` and `model_height × s` with `live_width` and `live_height`. Thresholds per axis (B8, pre-tuning baseline, in the shared spec): **warn > 10%**, **fail > 20%**.
   - **Production model:** warn logs a warning that names the species, the axis and the percentage. Fail is an **art bug**: the tool exits non-zero; the game still mounts the creature (with authored-dimension collision) and logs at a higher level (carried from the BQ3 recommendation, which the user accepted with changed numbers). The game never stretches a production model to hide the mismatch.
   - **Placeholder model:** the same deviation is reported as a **warning only**, never a failure, in both the game and the tool.
   - Pivot check (B10): the tool reports the pivot offset from the convention on every model. At mount, a placeholder's off-convention pivot is corrected automatically by the step 3 re-centre (B19); a **production** model must already meet B10 and gets no correction.
5. Apply variety stretch, if any (§4.4).
6. Size the shapes directly from the live dimensions (§4.2): movement capsule, the legacy `MobHitbox` (1.15 × the new body radius until the template cleanup, B21; no new logic), LoS eye height. **The body's `scale` stays `Vector3.ONE`.**
7. On a runtime size change, redo steps 3 and 6 with the new factor. Replace the body-scale path at `creature_kinematic_body_3d.gd` ~223.

`creature_mesh_footprint.gd` stays only as a **measuring** helper (steps 2 and 4, and the tool in §4.6). It no longer decides collision size.

### 4.4 Variety stretch (B2 "some allowed stretch")

- Each instance may carry a per-axis stretch of up to **±10% per axis** (B8, pre-tuning baseline; the range lives in the shared spec `tools/body_dimension_spec.json`, B18) for size variety and model variety.
- Collision **always** follows the instance's actual live dimensions. Stretch never makes the visual and the collision disagree.
- **Mechanism (B8):** **bone-chain scaling** per the HK-models Variation Strategy (torso girth, leg length) is primary. It needs rigged models and a mapping from bone scale to the resulting L / W / H (or a re-measure of the posed instance). **Non-uniform Visual-node scale** is the fallback (for unrigged models), accepting that it distorts the head and eyes.
- Distinguish this from the proportion check (§4.3 step 4). The proportion check flags a **model** that disagrees with its **species** spec. Variety stretch is an **intentional** per-instance deviation applied after a passing fit.

### 4.5 Facing invariant and radius validity (B5)

- **Invariant:** a creature with `body_width ≤ body_length` only ever moves along ±facing (forward or backward). It never strafes. V3 already behaves this way (§2.2). The invariant makes that a tested contract that blocks future strafing locomotion for such bodies.
- **Why it matters:** a width-based radius is valid only if the body's long axis lines up with the direction of travel. The body sweeps a corridor about `width` wide, not `length` wide.
- **Generalisation (note, not a decision):** the body radius is half the extent **perpendicular to the permitted travel axis**. A crab-like creature with width > length that moves sideways would use length. No such creature is planned, so the formula in §4.2 hard-codes width.
- **Residual cost (accepted):** the axis-aligned capsule does not model rotation sweep. A long body pivoting in place (turn rate ~1350°/s) swings its head and tail through nearby obstacles **visually**. The nose also overhangs the capsule by `L/2 − body_radius` when it meets an obstacle head-on (wolf example: roughly 2 units if `L = 6`, `W ≈ 1.5`). **Accepted for now (B16)**: no motor forward stop distance and no forward probe; revisit in live play (§8, §9 manual check).

### 4.6 Tooling (B3)

**(a) Game-side measuring / proposal tool** (B12): a headless Godot script under `tools/` (owner test-harness; name TBD). It also runs as a headless test over all shipped packs. Input is a model scene (`.glb`, `.blend` or `.tscn`) plus either a species archetype or a single given dimension (for example `length = 6`). Output:
- Raw whole-mesh rest-pose AABB (B7) and the pivot position relative to the AABB, with a pass / fail against the B10 convention (origin-position tolerance ≈ 2% of the matching length in the shared spec, B18). Reported for **every** model, placeholders included (B10 review work item).
- The forward axis it detects or assumes (+Z, B22), with a warning if the model looks rotated (for example a nose along −Z, the pre-B22 convention, reports as 180° off).
- Implied dimensions after uniform scaling to the given dimension.
- The ratio check against the archetype (per-axis percentage) with pass / warn (> 10%) / fail (> 20%) from the shared spec (B8). A model flagged placeholder in its pack's `pack_resources.json` (B13, B19) reports warn instead of fail.
- Model-first direction (B9): a proposed `body_length / width / height` block to paste into a new archetype.
- Exit code non-zero on any production-model fail.

**(b) Art-side dimension-driven generation** (external, HK-models):
- **Stage 1:** copy the species L / W / H from the game archetype `.tres` (source of truth, B9) into the HK-models subject spec.
- **Stage 2:** pass that ratio as Rodin `bbox_condition` so the generated model starts at the right proportions. Hunyuan3D has no bbox parameter, so a fallback model must be rescaled or fixed in Stage 3.
- **Stages 3 / 6:** run a Blender `execute_blender_code` checklist that checks the ratio, facing (+Z forward in Godot terms, i.e. nose along Blender −Y with the glTF exporter's +Y-up conversion, B22; Y up), pivot (B10) and units (1 Blender unit = 1 game unit, B6) before export, using the **same** ratio / tolerance definition as tool (a) (B12): the Blender script reads `tools/body_dimension_spec.json` by relative path (sibling folders `HK-models` / `hunter-killer`, e.g. `../hunter-killer/tools/body_dimension_spec.json`), so there is one copy (B18).

**(c) Existing-model review (B10 work item).** Run tool (a) over every current creature model and record pivot / facing / ratio results in §2.1. Non-conforming models are corrected, except where the model is a placeholder being replaced (moot to fix, but the tool must still report it).

### 4.7 Consumer audit: body radius vs reach extent (required work, owner creature-motor)

Moving the radius from about half the length to about half the width roughly **halves or thirds** every number that adds the capsule radius today (the wolf drops about 10×, B20). Each consumer needs the right one of the two values. Every row below marked "read" was confirmed against the code on 2026-10-02 (line numbers re-verified). All of today's consumers reach the value through `get_collision_capsule_radius()` / `get_collision_capsule_height()`; the only `.gd` files that call them are `creature_kinematic_body_3d.gd`, `motor_planner.gd`, `creature_motor_stack.gd`, `flee_candidate_scoring.gd` and `tests/run_all.gd`.

| Consumer (from §2.3) | Class | Reasoning (code read 2026-10-02) | Pre-change value |
|---|---|---|---|
| Eat reach bonus, `motor_planner.gd` `_eat_reach_radius_bonus` 4234–4241 (used by `_is_within_eat_range`, 4250+) | **reach extent** for the eating body + target **body radius** (B27, decided; see the answer block below) | Read: `bonus = body_radius + target_radius`, added to the fixed `eat_action_max_distance` (5.0, unscaled) so the gate means "reach beyond contact" (decision 14/25 follow-up). The mouth is at the front, so the eater's term is its reach extent (B25). With the body radius, wolf→rabbit eat reach would shrink from ~12.6 to ~6.1 and break decision 26 tuning. | Eat gate = 5 + r_eater + r_target. Wolf→rabbit ≈ 5 + 7.03 + 0.6 = 12.6; fox→rabbit ≈ 5 + 2.34 + 0.6 = 7.9 (rabbit radius is the archetype 0.6; its live mesh-derived value is not recorded). Rabbit eating a plant: 5 + 0.6 (plant contributes 0). |
| Flee threat capsule, `flee_candidate_scoring.gd` `threat_capsule_radius` 43–52, `threat_capsule_height` 58–67 | **body radius** (and capsule height), **reclassified** from "reach extent" | Read: the only callers are `motor_planner._flee_relevant_threat_capsule` (3447–3466; smallest in-awareness threat radius + height for the live detour bonus and the Stage B shelter fit-gate shape-cast) and the choke `threat_diameters` list (4034). Both are **gap-fit** questions ("can this threat squeeze through / into here?"), i.e. swept width, not how far the threat's front reaches. No flee-distance or danger-zone use exists in this function. | Wolf 7.03, fox 2.34, rabbit 0.6 (diameter 14.1 / 4.7 / 1.2). Post-change 0.72 / 0.22 / 0.39 (B20). |
| Own diameter, `motor_planner.gd` 4028–4030 | **body radius** × 2 | Read: inside `consult_choke_point_beliefs` handling; `own_diameter` feeds `_FleeScoring.choke_useful(opening_width, own_diameter, threat_diameters)` (flee_candidate_scoring.gd 115–122), which requires `opening_width ≥ own_diameter` (I fit) and `opening_width < threat diameter` (the threat does not). Pure gap-fit. | Wolf 14.1, fox 4.7, rabbit 1.2. Post-change 1.44 / 0.44 / 0.78. |
| `_agent_radius` / `_agent_height`, `motor_planner.gd` 4653–4662 | **body radius** / capsule height | Read: thin wrapper (`maxf(0.1, radius)`, `maxf(0.2, height)`) used by ~12 nav-path, clearance, ghost-fit and `RoutePlausibilityScan` calls (360, 556, 1244, 2016, 2311, 2376, 2696, 2815, 3315, 4505). Navmesh / path clearance. |  |
| `creature_motor_stack.gd` 350 (`_update_choke_point_producers`) | **body radius** | Read: `radius = get_collision_capsule_radius()`; `diameter = 2r` scales the choke detect half-width (`choke_detect_width_factor`), the merge radius and the minimum pass travel. These are "how wide a gap is relevant to this creature" thresholds (class comment: "scale off the creature's own capsule"), swept width. | Wolf 7.03 → 0.72, so every choke threshold shrinks ~10× (intended; recheck the factors in Phase 2). |
| `creature_motor_stack.gd` 1553–1554 (`_maybe_observe_shelter_opportunistically`) | **body radius** + capsule height | Read: `agent_r` / `agent_h` are passed to `ShelterEnclosureProbe.enclosure_fraction` as the self-sized shape-cast ("Stage A, self-radius shape-cast sweep"). Sweeping the movement capsule is the body-radius class (same row as the ghost-fit clamp). | Same radius change as above. |
| `creature_kinematic_body_3d.gd` 601–602 (ghost-fit clamp), 183 (`get_los_eye_height`) | **body radius** + capsule height | Read: the ghost-fit shape-casts the real capsule; the eye height is `0.9 ×` capsule height. Added to the audit (missing from §2.3). | Eye height was `0.9 × capsule height` (wolf 13.8); becomes `0.9 × max(live_height, 2r)` (wolf 2.7). |
| Shelter fit / choke credit (PHYSICS_SQUEEZE) | **body radius** for the width fit; the shelter **depth** check may need the length | Shelter enclosure should cover the whole body. Not re-read (doc only). |  |
| C1 contact geometry (CLEANUP C1) | predator **reach extent** + prey **body radius** | Contact means the predator's front meets the prey's side. Not re-read (doc only). | Not recorded here; take from CLEANUP C1 when implementing (it uses the capsule radii of both bodies). |
| `RoutePlausibilityScan`, `ShelterEnclosureProbe` | **body radius** (they sweep the movement capsule) | Automatic once the capsule is resized (they receive `agent_r` / `agent_h` from the callers above). |  |
| Navmesh `agent_radius` / class selection | **body radius** | NAVIGATION_PASSABILITY D1 / D7; answers its Q10 (§4.10). | Wolf navmesh erosion 7.25 → roughly 0.9 if the same ~0.22 margin implied by 7.25 − 7.03 applies (per NAVIGATION_PASSABILITY §3.1; not re-verified here). |

**Reach extent after B25 (eat / contact).** The eater's term changes from its pre-change body radius to `get_reach_extent()` = 0.75 × live_length from its centre (default fraction): rabbit 1.275, fox 1.5, wolf 4.5. Pre-change terms were 0.6 (rabbit archetype), 2.34 (fox, mesh-derived), 7.03 (wolf, mesh-derived). Reach therefore moves from "L / 2-ish via the mesh formula" to 0.75 L and the wolf/fox values are still much smaller than today's. Illustrative eat gates (5 + eater term + target term), target term = target **body radius** (0.39 rabbit; B27 decided): wolf→rabbit 5 + 4.5 + 0.39 = **9.9** (was ~12.6); fox→rabbit 5 + 1.5 + 0.39 = **6.9** (was ~7.9); rabbit→plant 5 + 1.275 = **6.3** (was 5.6). (The rejected target-reach-extent variant would have given 10.8 / 7.8 / 6.3.) Each of these (eat, flee, contact) must be re-compared headless against the pre-change values listed here and either accepted within an agreed delta or retuned with the change recorded (§7).

**Answer (B27, user, 2026-10-05): option (a), target body radius.** `_eat_reach_radius_bonus` becomes `eater get_reach_extent() + target get_body_radius()` (plants contribute 0), added to the fixed `eat_action_max_distance` (5.0). Rationale: the predator's mouth / reach meets the prey's side, the same pairing C1 contact uses; option (b) (target reach extent) was rejected because it over-credits a long prey approached from the side.

- **Illustrative gates under (a)** (gate = 5 + eater reach + target body radius; reach per B25 default, radii per B20): wolf→rabbit 5 + 4.5 + 0.39 = **9.9** (was ~12.6); fox→rabbit 5 + 1.5 + 0.39 = **6.9** (was ~7.9); rabbit→plant 5 + 1.275 + 0 = **6.3** (was 5.6).
- **Rabbit radius caveat.** The 0.39 rabbit body radius is the B20 design-intent value (`1.7 / 0.7 / 1.4` → `0.7 / 2 × 1.10`). The rabbit's **live** radius is mesh-derived today (archetype fallback 0.6; the live mesh-derived value was never recorded) and stays so until Phase 1 / 2 land; the gates above hold only after the Phase 1 capsule resize. Do not read them as current-code numbers.
- **Retune expectation.** Every gate moves (wolf→rabbit and fox→rabbit shrink, rabbit→plant grows), so the eat-range tuning behind decision 26 needs a re-check in the Phase 1 change set: compare headless before / after (§7) and either accept an agreed delta or retune `eat_action_max_distance` (or `reach_margin_fraction`, or a per-species `reach_override`), recording the change.

**Gating rule.** The capsule resize (Phase 1) and the reach-extent split for eat / contact must ship in the **same change set**, together with the `reach_margin_fraction` config key and the `reach_override` field. Otherwise eat reach and contact distances regress the moment the radius shrinks. (The flee threat capsule is a body-radius consumer after the 2026-10-02 audit, so it follows the capsule resize automatically and is not part of the reach split.)

### 4.8 Scene and file changes (proposed)

| Action | Path | Notes |
|---|---|---|
| modify | `creature/definition/creature_definition.gd` | Add `body_length / width / height` and optional `reach_override` (B25: absolute distance from body centre, `0.0` = unset = computed reach); remove the authored capsule fields; derive `creature_size = max(L, W, H)` on live dimensions (B11). Reads the placeholder flag from the pack's `pack_resources.json` (B19), not from the archetype. |
| modify | `creature/capabilities/creature_kinematic_body_3d.gd` | Size shapes from live dimensions (`CapsuleShape3D.height = max(live_height, 2r)`, B24 / B14; drop the `+ 0.05` floors at 193, 214, 227, 234); stop scaling the body (~223); `get_body_radius()` / scalar `get_reach_extent()` (B15 scalar, B25 formula and `reach_override`); hit `Area3D` kept at 1.15 × the new body radius until the template cleanup (B21); Visual yaw offset kept as a legacy override (~28). |
| modify | `creature/capabilities/creature_mesh_footprint.gd` | Measuring only (whole-mesh rest-pose AABB, pivot, ratio check). No longer sizes collision: the `radius` / `height` outputs (57–61, Godot-3-style `sy − 2r` height) are removed (B24). |
| modify | `creature/creature_root_3d.gd` | Uniform fit (production) or per-axis fit (placeholder, B13) + proportion report at mount (~149); drop `&"wolf": "wolf_3d.tscn"` from `_SPECIES_MESH_FILE` once the wrapper is gone. |
| modify | `creature/species/rabbit_archetype.tres`, `wolf_archetype.tres` | Dimensions from design intent (B13; values B20: rabbit 1.7 / 0.7 / 1.4, wolf 6.0 / 1.3 / 3.0). |
| create | `creature/species/fox_archetype.tres` | New, with design-intent dimensions (B13; B20: 2.0 / 0.4 / 0.9). |
| delete / modify | wolf pack `wolf_3d.tscn` (under `assets/creatures/`) | Remove the 3× wrapper and pivot compensation (B13). The placeholder `wolf.blend` pivot is handled by the placeholder mount re-centre (B19). |
| modify | `assets/creatures/*/pack_resources.json` | Per-pack forward override only where a legacy model can't be re-exported (B4, B22): the three placeholders are X-long (Phase 0, §2.1.1), so once the code convention flips to +Z each needs a net per-model ±90° yaw (sign pending a visual check), reconciled with the existing template Visual yaw offsets rather than stacked (§4.8.1). **Placeholder flag** (B19): present only on packs whose model deviates from the production default; added today to rabbit, fox and wolf. The default (key absent) means production-standard. Any other per-model override follows the same present-only-on-deviation rule. |
| modify | `creature/motor/motor_planner.gd`, `flee_candidate_scoring.gd`, `creature_motor_stack.gd`, `locomotion_executor.gd` | §4.7 audit; `_eat_reach_radius_bonus` = eater `get_reach_extent()` + target `get_body_radius()` (B27); facing invariant assertion. |
| modify | `creature/motor/motor_plane.gd` (`yaw_from_horizontal_dir` ~58–61, `HORIZONTAL_FORWARD` ~18) and `creature/capabilities/creature_kinematic_body_3d.gd` (Visual yaw ~724–725, `visual_yaw_offset_rad` ~28–29) | **B22 facing-math item. SHIPPED 2026-10-05 (bfcbd26; Phase 3 `done`):** `MotorPlane.MODEL_FORWARD = Vector3(0, 0, 1)` replaced `HORIZONTAL_FORWARD`; `yaw_from_horizontal_dir(d, default = MODEL_FORWARD) = wrapf(atan2(d.x, d.z) − atan2(F.x, F.z), −PI, PI)`. Original plan text follows. `yaw_from_horizontal_dir` returned `atan2(d.x, -d.z)`, which is **mirrored left / right** for the Visual (correct only for ±Z; B26, §2.1.1 finding 7), not merely a −Z convention. The corrected general form is the signed angle rotating `MODEL_FORWARD` onto `d` about +Y; for +Z forward it is `atan2(d.x, d.z)` (doc comment ~58 updated). **B23:** the yaw is derived from the new `MODEL_FORWARD` constant (declared here, replacing `HORIZONTAL_FORWARD`), not a literal; see §4.8.1. `visual_yaw_offset_rad` keeps its meaning (extra rotation when the mesh forward differs from the convention), now relative to +Z. Includes the audit of every semantic use of "forward" listed in §4.8.1. |
| modify | `creature/motor/motor_planner.gd`, `motor_explore_seek.gd`, `creature/.../awareness_zone.gd`, `creature/motor/creature_motor_stack.gd`, `occluded_in_zone_ghost.gd` | **SHIPPED (bfcbd26).** **B23:** replaced `MotorPlane.HORIZONTAL_FORWARD` (planner, explore seek, awareness zone) and `Vector3.FORWARD` (motor stack ~971, ghost ~33 / ~116) with `MotorPlane.MODEL_FORWARD`. No literal forward vector remains. Memory-file `atan2(x, -z)` bearings unchanged. |
| modify | `creature/templates/creature_herbivore_kinematic_3d.tscn`, `creature_carnivore_kinematic_3d.tscn` | **SHIPPED (bfcbd26).** They set `visual_yaw_offset_rad`; per the facing-check results (B26) **both** are now 3π/2 = `4.71238898038469` (= −π/2) under the corrected +Z formula, confirmed by `tools/facing_check_3d.tscn` at headings ±X, ±Z. |
| modify | `tests/run_all.gd` (~13085 `yaw_from_horizontal_dir` round-trip) | **SHIPPED (bfcbd26): `_test_motor_plane_yaw_from_facing` now uses `Basis(UP, yaw) * MODEL_FORWARD ≈ d` for 8 headings.** Replaced the round-trip test: it rebuilds directions with `(sin(yaw), 0, −cos(yaw))`, the same mirrored formula, so it cannot detect the bug (B26). The new test uses real engine rotation: `Basis(Vector3.UP, yaw) * MODEL_FORWARD` must equal `d` (within tolerance) for 8 headings. Add a +Z facing test (B22). Add the B23 tests: `yaw_from_horizontal_dir(MotorPlane.MODEL_FORWARD) == 0`, and a source grep check that no `HORIZONTAL_FORWARD` or creature-facing `Vector3.FORWARD` / literal `Vector3(0, 0, ±1)` forward remains. |

#### 4.8.1 B22 facing-math work item (SHIPPED 2026-10-05, bfcbd26; findings below are from the 2026-10-02 pre-implementation grep and are kept as history)

**Shipped state (2026-10-05).** `MotorPlane.MODEL_FORWARD = Vector3(0, 0, 1)` in `creature/motor/motor_plane.gd`; `HORIZONTAL_FORWARD` is retired (no alias). Fallback sites now use `MODEL_FORWARD`: `awareness_zone.gd`, `motor_explore_seek.gd`, `motor_planner.gd`, `creature_motor_stack.gd`, `occluded_in_zone_ghost.gd`. Both kinematic templates carry `visual_yaw_offset_rad = 3π/2` (`4.71238898038469`). The default facing with no movement is now +Z. `tools/facing_check_3d.tscn` (F6; keys 1–9; H cycles headings; `view=` / `heading=` user args) is the visual check. User confirmed in play (2026-10-05): facing corrected and the awareness cone turns with the body. The "−Z"/"today" wording in the bullets below describes the pre-ship code.

**Scope.** Switch the model-forward convention from −Z to +Z (B22). Pure visual mapping: the Visual's Y rotation must turn a +Z-forward mesh to face `last_move_direction`.

**Facing math locations**
- `creature/motor/motor_plane.gd` `yaw_from_horizontal_dir` (~58–61): `atan2(d.x, -d.z)`, doc comment says "mesh whose default forward is −Z". This is the one conversion to change. **It is also a live bug (B26):** the formula is mirrored left / right for the Visual (correct only for ±Z), so this item is a fix, not just a convention switch.
- `creature/capabilities/creature_kinematic_body_3d.gd` ~724–725: `visual.rotation.y = yaw_from_horizontal_dir(last_move_direction) + visual_yaw_offset_rad`; the export at ~28–29 (comment says "forward != -Z").
- `creature/templates/creature_herbivore_kinematic_3d.tscn` (line 26, π/2) and `creature_carnivore_kinematic_3d.tscn` (line 24, 3π/2) set `visual_yaw_offset_rad`; `Definitive_Features/CREATURE_3D_ARCHITECTURE.md` §4 describes the offset (sync when shipping).
- `tests/run_all.gd` ~13085–13087: round-trips `yaw_from_horizontal_dir` over 8-way directions. The test inverts the formula with the same mirrored assumption, so it could not catch the bug; it is replaced by a real-engine-rotation test (B26).

**Semantic "forward" in motor / movement code (must be checked, probably unaffected)**
- The motor works in world-space direction vectors. Facing is `last_move_direction` (a world `Vector3`), not a node basis. The grep found **no** `-basis.z` / `basis.z` / `global_basis` / `rotate_y` / `rotation.y` use in `creature/`, `environment/` or `tools/` other than the Visual yaw line above. `locomotion_executor.gd` turns with `atan2(-cross, dot)` on direction vectors (~124): convention-free.
- `MotorPlane.HORIZONTAL_FORWARD = Vector3(0, 0, -1)` (~18) is used as a **fallback direction** (empty input, default explore direction, flee fallback, awareness-zone default) in `motor_plane.gd` (declaration 18; the `default` parameter of `yaw_from_horizontal_dir` at 59), `motor_explore_seek.gd` (106, 147, 177, 179, 211), `motor_planner.gd` (420, 706, 2302, 3129, 3503, 4160, 4175, 4211; the comment at 3495 also names it) and `awareness_zone.gd` (34). Line numbers re-verified by grep 2026-10-02 (all matched the earlier list; only the `motor_plane.gd` 59 default was missing). These are world defaults, not model-forward. **Resolved (B23): retarget ALL of them to one named constant, `MotorPlane.MODEL_FORWARD`** (see "Single forward constant (B23)" below). They are the creature's default facing, so their value must equal the model-forward convention; the first-tick facing of a creature with no movement then stays consistent with the model.
- `Vector3.FORWARD` (−Z) fallbacks: `creature_motor_stack.gd` 971 (`facing` when no body) and `occluded_in_zone_ghost.gd` 33, 116 (zone `facing`) (re-verified 2026-10-02). Resolved (B23): retarget to `MotorPlane.MODEL_FORWARD`; no literal `Vector3.FORWARD` remains for creature facing.
- Compass-bearing conversions `atan2(x, -z)` in `blocked_approach_memory.gd` ~13, `goal_belief_memory.gd` ~37, `goal_source_memory.gd` ~74 and `memory_adapter.gd` ~1455: world bearing buckets, independent of model forward. Leave unless the owner decides to unify; changing them would reshuffle stored memory bearings.
- `main_3d.gd` ~361 `cam.look_at(..., Vector3.FORWARD)` is the camera up-vector argument, not creature facing.
- Existing tests that assert default facing or bearings against −Z must be listed during the check (`tests/run_all.gd`; not yet enumerated).

**Single forward constant (B23).**
- **Name and home.** `MotorPlane.MODEL_FORWARD: Vector3` in `creature/motor/motor_plane.gd` is the single source of truth for the game's model-forward convention. Final value **+Z** (`Vector3(0, 0, 1)`, B22).
- **`HORIZONTAL_FORWARD` is retired**, not kept as a second literal. Every use (`motor_plane.gd`, `motor_explore_seek.gd`, `motor_planner.gd`, `awareness_zone.gd`) is renamed to `MODEL_FORWARD`. If a horizontal-only name is wanted for readability, it may exist only as a derived alias (`HORIZONTAL_FORWARD := MODEL_FORWARD`), never an independent literal. Recommendation: retire it (one name).
- **Retargeted fallbacks.** `creature_motor_stack.gd` (~971) and `occluded_in_zone_ghost.gd` (~33, ~116) use `MotorPlane.MODEL_FORWARD` instead of `Vector3.FORWARD`.
- **Yaw derives from the constant.** `yaw_from_horizontal_dir(d)` is computed relative to `MODEL_FORWARD`, not from a literal axis: yaw = wrap(`atan2(d.x, d.z)` − `atan2(F.x, F.z)`) with F = `MODEL_FORWARD` (flattened to XZ), wrapped to (−π, π]. This is the signed angle rotating F onto d about +Y (Godot Y rotation is counter-clockwise from above, so `Basis(UP, yaw) * F ≈ d`). For F = +Z it is `atan2(d.x, d.z)`; for F = −Z it is `atan2(−d.x, −d.z)`. **Correction (2026-10-05, B26):** an earlier version of this doc said that for F = −Z the derivation "reproduces today's `atan2(d.x, -d.z)`". It does **not** for X components: today's formula is mirrored left / right (correct only for ±Z), and the derivation **fixes the mirror**. Because of that, step (1) of the phasing below is *not* behavior-preserving for X-heading visuals; see the revised phasing. Changing the constant flips the yaw formula and every fallback together. Invariant: `yaw_from_horizontal_dir(MODEL_FORWARD) == 0`.
- **Not touched.** The compass-bearing `atan2(x, -z)` calls (`blocked_approach_memory.gd`, `goal_belief_memory.gd`, `goal_source_memory.gd`, `memory_adapter.gd`) stay as **world bearings**, not model forward; they do not reference `MODEL_FORWARD`, and changing them would reshuffle stored memory bearings. `main_3d.gd` ~361 camera up-vector argument also stays.
- **Phasing (recommended).** Within Phase 3, land in two steps inside one branch: **(1) constant wiring plus the mirror fix**: introduce `MODEL_FORWARD` with value **−Z**, retarget all fallbacks, derive the yaw from it (B26). Fallbacks and ±Z-heading visuals are unchanged; X-heading visuals change on purpose (the mirror is fixed), so the template offsets may need adjusting in this step too. The real-engine-rotation test (B26) passes at −Z; the yaw-at-`MODEL_FORWARD` test passes at 0. **(2) the flip**: change only the constant's value to +Z together with the reconciled per-model ±90° net yaw (pack / template Visual offsets) and updated tests. Step 2 is a one-line code change plus overrides, which keeps the backward-facing risk (§8) isolated. Both steps may ship in the same change set if the maintainer prefers.

**Atomic with model forward.** Flipping the formula makes every mesh whose net Visual yaw was tuned for −Z face backward. Phase 0 (§2.1.1) measured all three placeholders as **X-long** (nose along ±X, sign unknown), so the override is a ±90° rotation per model, not just 180°. It must be **reconciled with the existing template `visual_yaw_offset_rad` values** (herbivore π/2, carnivore 3π/2): set the final net offset per model, do not stack a new override on top. **Resolved by the 2026-10-05 facing check (§2.1.1 finding 7, B26):** all three models share one nose direction, and under the corrected +Z formula **both templates need 3π/2 (= −π/2)**; the sign is confirmed by `tools/facing_check_3d.tscn` at headings ±X, ±Z. All of it lands in the same change set as the formula change.
| create | `tools/` measuring script (name TBD) | §4.6 (a), B12. |
| create | `tools/body_dimension_spec.json` (shared ratio / tolerance spec, B18) | Proportion thresholds (warn 10% / fail 20%), variety stretch range (±10%), origin-position tolerance (≈ 2% of length); read by tool (a) and, by relative path, the Blender checklist (B8, B12, B18). Lives under `tools/` (test-harness) because it is a check definition for tooling, not a game resource: `assets/_shared/` is the pooled game-resource area resolved via `PackResourceResolver` (assets/CLAUDE.md) and is the wrong home for it. |
| modify | `tests/run_all.gd` (~962–1010 wolf wrapper tests) | Replace wrapper tests with fit / proportion / no-body-scale / invariant / placeholder-fit tests. |
| modify | `game_config.json`, `game_config.gd` | Add `width_margin` (default 0.10) with the other motor tuning (B18); it is gameplay tuning, not an art check, so it stays out of the shared spec. |
| modify | `game_config.json`, `game_config.gd` (B25) | Add `reach_margin_fraction` (default **0.25**; key name proposal, same section as `width_margin`) with a `game_config.gd` facade getter; `get_reach_extent()` reads it, never a literal. `game_config.gd` is on the app-shell write path (CLAUDE.md routing), and the `eat_action_max_distance` family lives in `AI_int_lib/game_config_merge.gd` (546) / `motor_plane.gd` (284), so the implementing agent should place the new key next to `width_margin` and check the merge defaults. |
| modify | `creature/definition/creature_definition.gd` (B25) | `reach_override` field (see the first row of this table). |

### 4.9 Required cross-repo edit (external; caller performs — BQ1–BQ8 settled as B6–B13)

`../HK-models/3d_modeling_v1.md` needs:
1. A **facing rule** (B22, supersedes B4): +Z forward in Godot terms (nose along Blender −Y, Blender's default character facing, toward the Front-view camera; the glTF export maps Blender +Y to Godot −Z, so no extra axis flip is needed), Y up, enforced at model creation and checked before the Stage 6 export.
2. A **pivot rule** (B10): origin at ground contact, centred in XZ on the rest-pose AABB footprint. Enforced at Stage 6.
3. A **unit / scale statement** (B6): 1 Blender unit = 1 game unit (~4 game units per real metre, estimate). Replaces "1 Blender unit = 1 m".
4. **Stage 1:** copy the species L / W / H from the game archetype `.tres` into the subject spec (B9). **Stage 2:** pass the ratio as Rodin `bbox_condition`. **Stage 3:** Hunyuan fallback rescale / fix step.
5. A **Stage 3 / 6 checklist script** that shares the ratio / tolerance definition with the game tool (B12), reading `tools/body_dimension_spec.json` from this repo by relative path (B18).
6. **Variation Strategy:** bone-chain scaling limited to ±10% per axis (B8), and a note that collision follows the resulting dimensions.
7. A **measurement rule** (B7): dimensions are the whole-mesh AABB in the neutral rest pose, tail and ears included.

That repo is outside this one and has no git history, so drift between the two is a risk (§8). Mitigation (B12): PROJECT_DOC_INDEX gains "Related (outside Project_Docs)" rows pointing at the HK-models pipeline docs so a change on either side is visible (the caller routes that index edit).

### 4.10 Hand-back to NAVIGATION_PASSABILITY (its Q10 / Q12)

- **Its Q10 (answer from this doc; B1, B5, B16):** yes, the wolf's 7.0 radius came from enclosing the model, or more precisely from half its **length** via the footprint formula (§2.1). Pathing uses the **body radius** (width-based). There is **one** radius, the resized movement capsule; there is no separate `path_radius`. Resizing the capsule is B1. The nose / tail overhang this leaves is accepted for now (B16).
- **Its Q12 (answered by B17):** each nav class declares a **max body radius** and a **max `creature_size`**; a creature's class is the **smallest class satisfying both** (its option 3). No aspect-ratio assumption; class stays runtime-derived (its D7). Cross-link only: the navigation plan itself is updated separately.
- Effect on its D9 provisional bounds: every live radius shrinks (the fox's 2.343 and the wolf's 7.03 were half-length values). With B20 the radii become rabbit 0.39, fox 0.22, wolf 0.72 (wolf about 10× smaller), so navmesh erosion and the gap-trap are likely to mostly disappear and the wolf may fit the small nav class. Class boundaries (B17) are retuned only after these dimensions land. NAVIGATION_PASSABILITY's `R_k` and class max `creature_size` should be set only after the design-intent dimensions land (B13, Phase 2).

### 4.11 Collision / signals

- Layers / masks: unchanged.
- Signals: none new. The proportion mismatch is a log warning (OLog, [oLog_lib/CLAUDE.md](../../oLog_lib/CLAUDE.md) hygiene), once per species per session.
- Groups: none.

---

## 5. Implementation plan (ordered; slices not yet approved)

| Phase | Content | Gated on | Owner (routing) |
|---|---|---|---|
| **0 — Measure / review** | **Status: built** (`tools/measure_body_dimensions.gd` + `tools/body_dimension_spec.json`, 62d372d; the design-intent table and placeholder flag are hard-coded in the tool until Phase 1 / 2 supply the archetype fields and the `pack_resources.json` flag). Results recorded in §2.1.1. Original scope: Build tool (a) (B12), read-only, plus the shared spec file `tools/body_dimension_spec.json` (B18). Run the B10 existing-model review: measure the rabbit, fox (`fox.blend`) and wolf (`wolf.blend`, raw and wrapped) placeholders: whole-mesh rest-pose AABB, pivot offset vs convention, forward axis, ratio vs the B20 design-intent dimensions. Record the results in §2.1 as placeholder reports (not the species spec, B13). | B7, B10, B12, B18, B20 (decided) | test-harness |
| **1 — Data model + fit + shapes** | `body_length / width / height` on `CreatureDefinition`; derived `creature_size = max(L, W, H)` (B11); placeholder flag read from `pack_resources.json` (B19); `width_margin` in `game_config.json` (B18); optional `reach_override` on `CreatureDefinition` and `reach_margin_fraction` (default 0.25) in `game_config.json` / `game_config.gd` (B25); uniform Visual fit for production models and per-axis fit plus origin re-centre for placeholders, with proportion report at mount (B8, B13, B19); shapes sized from live dimensions with the B24 total-height capsule (`max(live_height, 2r)`, B14 clamp kept); scalar reach `live_length × (0.5 + fraction)` or `reach_override` (B15 scalar, B25); legacy `MobHitbox` left at 1.15 × the new radius (B21); stop scaling the body; runtime size change re-derives shapes. **Same change set** as the §4.7 reach-extent split (gating rule; eat and contact are the reach consumers, the flee threat capsule is body radius). Eat gate (B27): `_eat_reach_radius_bonus` = eater `get_reach_extent()` + target `get_body_radius()`; illustrative gates wolf→rabbit 9.9, fox→rabbit 6.9, rabbit→plant 6.3, with an eat-range retune check. | B6, B7, B8, B11, B13, B14, B15, B18, B19, B21, B24, B25, B27 (decided; eat-gate target side = body radius, §4.7) | creature-entity (definition, mount / fit, shapes); creature-motor (§4.7 audit, reach split); test-harness |
| **2 — Migration** | Design-intent dimensions on the rabbit and wolf archetypes; new fox archetype; flag all three current models as placeholders; remove the wolf 3× wrapper and its `_SPECIES_MESH_FILE` entry (placeholder pivot via the mount re-centre, B19); per-pack forward override where needed; retune radius-based distances. | B13, B19, B20 (decided) | creature-entity (archetypes, `_SPECIES_MESH_FILE`); assets-pack (wrapper removal, pack forward override, placeholder flag in the three `pack_resources.json` files); creature-motor (retune) |
| **3 — Facing invariant + forward-axis switch + mirrored-yaw fix (B26)** | **Status: `done` (shipped 2026-10-05, bfcbd26; user confirmed in play: facing corrected, awareness cone turns with the body).** Shipped: `MotorPlane.MODEL_FORWARD` (+Z), corrected `yaw_from_horizontal_dir`, all fallbacks retargeted, both templates 3π/2, engine-rotation test, `tools/facing_check_3d.tscn`. The facing-invariant assertion + headless test (width ≤ length → displacement parallel to facing) is tied to the Phase 1 capsule (§7) and is not yet done. Original scope: **Highest priority; ships independently, before Phases 1 / 2** (needs only the Phase 0 measurements; it touches no capsule, reach or archetype data). The mirrored `yaw_from_horizontal_dir` affects live play now, and every current model will be replaced by models following the HK-models rules (+Z forward), so the corrected formula and the 3π/2 template offsets (both templates) must be in place for them. **B26:** corrected signed-angle yaw from `MODEL_FORWARD`; acceptance test uses real engine rotation (`Basis(UP, yaw) * MODEL_FORWARD ≈ d`, 8 headings), not a hand-built inverse; visual check via `tools/facing_check_3d.tscn` at ±X, ±Z. Invariant assertion + headless test (width ≤ length → displacement parallel to facing). **B22 facing-math change (§4.8.1):** `yaw_from_horizontal_dir` → +Z forward, audit of every semantic "forward" use (`HORIZONTAL_FORWARD`, `Vector3.FORWARD` fallbacks, tests; **B23:** all retargeted to the single `MotorPlane.MODEL_FORWARD`, recommended as a behavior-preserving step at −Z first, then the flip to +Z), per-model **±90° net pack / template yaw override** (Phase 0 found all three placeholders X-long, not −Z; sign needs a visual check; reconcile with the existing template offsets herbivore π/2 / carnivore 3π/2 rather than stacking, §2.1.1, §4.8.1), round-trip test update. Same change set as the override so no model faces backward. The Visual yaw offset becomes a documented legacy override relative to +Z. | B4 (superseded), B22, B5 (decided) | creature-motor; test-harness |
| **4 — Art pipeline alignment** | HK-models edits (§4.9); Blender checklist sharing the ratio / tolerance definition; Rodin `bbox_condition` feed; PROJECT_DOC_INDEX "Related (outside Project_Docs)" rows (caller routes). | B6, B8, B9, B10, B12, B18 (decided) | external (caller); project-docs (index rows) |
| **5 — Variety stretch** | Per-instance stretch of ±10% per axis, bone-chain primary with Visual-scale fallback; collision follows the instance's actual dimensions. | B8 (decided) | creature-entity; assets-pack (bone-chain rigs); test-harness |
| (config) | `width_margin` (default 0.10) and `reach_margin_fraction` (default 0.25, B25) in `game_config.json` / `game_config.gd` (B18, B25). Fold into Phase 1 (the radius and reach derivations need them); tolerances and stretch range stay in the shared spec. | B18, B25 (decided) | app-shell |

**Ordering note (2026-10-05, B26).** Phase 3 was the first to ship (done, bfcbd26) and did not depend on Phases 1 / 2 (it needs only the Phase 0 measurements). Phases 1 and 2 keep their relative order and gating (§4.7 gating rule); Phase 3 need not wait for either, and they need not wait for it.

Navigation Phase 1 (NAVIGATION_PASSABILITY §8) should start **after** Phase 2 here, so class boundaries (B17: max radius and max `creature_size` per class) are set on the new dimensions.

### 5.1 Post-landing cleanup (B6; not a phase gate)

After this feature **and** the navigation work (NAVIGATION_PASSABILITY) have landed, not before:
- Revisit hard-coded distances that assume today's scale (for example the ~5-unit combat / contact distance).
- Move species sizes toward realistic proportions under the documented ~4 units / m factor (for example rabbit and wolf length relative to each other and to the playfield).

This item does not block any phase above and has no acceptance criterion in §7. It is tracked here until it gets its own plan or backlog row.

---

## 6. Decision log

| # | Date | Decision (user, in conversation) | Consequence in this doc |
|---|---|---|---|
| B1 | 2026-10-01 | **Authored dimensions are canonical; the model conforms.** `CreatureDefinition` gets `body_length`, `body_width` and `body_height`, replacing authored `creature_size` / `collision_capsule_radius` / `collision_capsule_height`. `creature_size` becomes derived (derivation settled by B11). Movement capsule radius = width / 2 × margin; height = `body_height`; hitbox from length (reach extent). Shapes are sized directly; the body is never scaled; only the Visual node is scaled. The pathing class derives from the dimensions (NAVIGATION_PASSABILITY D7). | §3 M1–M3, M8; §4.1–4.3; §4.8; §4.10. |
| B2 | 2026-10-01 | **Fit policy (c): uniform scale + proportion check.** The model is scaled uniformly at mount. The authored dimensions stay authoritative for gameplay. A warning fires when model proportions deviate beyond a tolerance. Mismatches are art bugs to fix in the model, not something to stretch silently. **But** some stretch is allowed for size change and model variety (ties to the HK-models Variation Strategy bone scaling). | §3 M4, S3; §4.3; §4.4; B8, B13. |
| B3 | 2026-10-01 | **Tooling on both ends, aligned so the model is right first time.** (a) A measuring / proposal tool: import a model, give one dimension (for example length = 6), report the implied width and height, and flag proportions that are off against the species spec. (b) Feed the desired dimensions into 3D generation (Rodin `bbox_condition`) so generated models start at the right ratios, aligned with the `../HK-models/3d_modeling_v1.md` stages. | §3 M7, S1, S2; §4.6; B9, B12. |
| B4 | 2026-10-01 | **SUPERSEDED by B22 (2026-10-02): forward is now +Z, not −Z.** Original text: **Facing by convention (Godot −Z forward, Y up), enforced at model creation time** by a rule in `../HK-models/3d_modeling_v1.md`. The caller edits that file once the open decisions settle; it is recorded here as a required cross-repo edit. The existing Visual forward offset (`creature_kinematic_body_3d.gd` ~28) becomes legacy / override only. | §3 S4; §4.6; §4.9 item 1; §5 Phase 3. |
| B5 | 2026-10-01 | **Width margin starts at 10%** (radius = width / 2 × 1.10), tunable. **Facing constraint:** creatures with width ≤ length move forward / backward only (no strafing), so the width-based radius is valid because the body lines up with its travel. V3 already behaves this way; the constraint makes it an invariant with a test. *Note (not a decision):* in general the radius is half the extent perpendicular to the permitted travel axis; a crab-like creature with width > length that moves sideways would use length. *Accepted residual cost:* a long body pivoting in place (~1350°/s) swings its head and tail through obstacles visually, because the axis-aligned capsule doesn't model rotation sweep. | §3 M5; §4.2; §4.5; §7; B16. |
| B6 | 2026-10-01 | **(BQ1) Game units with one documented factor**, ~4 game units per real metre (estimate). No world rescale now. HK-models exports directly in game units (1 Blender unit = 1 game unit). **Post-landing cleanup** (after this feature and the navigation work land, not a phase gate): revisit hard-coded distances (for example the ~5-unit combat / contact distance) and move species sizes toward realistic proportions (for example rabbit and wolf length). | §1 non-goals; §2.4; §2.5; §4.9 item 3; §5.1. |
| B7 | 2026-10-01 | **(BQ2) Whole-mesh AABB in the neutral rest pose**, tail and ears included. | §4.1; §4.3 step 2; §4.6; §4.9 item 7. |
| B8 | 2026-10-01 | **(BQ3) Pre-tuning baseline tolerances:** proportion check warns > 10% and fails > 20% per axis. Per-instance variety ±10% per axis via **bone-chain scaling**, with non-uniform Visual scale as the fallback. Collision follows the instance's actual dimensions. Tolerances live in **one shared spec**. Effect of fail (tool non-zero, game still mounts) carried from the BQ3 recommendation. | §3 M4, S2, S3; §4.3 step 4; §4.4; §4.6; §4.9 item 6; §7; B18. |
| B9 | 2026-10-01 | **(BQ4) The species archetype `.tres` (`CreatureDefinition` leaf data) is the source of truth.** Consistent with Definitive CREATURE_3D_ARCHITECTURE §2 (archetype as leaf data with "collision capsule hints"). Its §4 "Size sync (M4)" text (capsule from mesh AABB; `apply_effective_creature_size` "scales mesh + capsule") must be synced by `project-docs` when this ships; note the existing drift that code scales the `CharacterBody3D` itself (~223). Dimensions are copied into the HK-models subject spec at Stage 1 and fed to Rodin `bbox_condition`. The tool works in both directions. | §3 M7, N1; §4.1; §4.6; §4.9 item 4; §11. |
| B10 | 2026-10-01 | **(BQ5) Origin at ground contact, centred on the rest-pose AABB XZ footprint.** Enforced at HK-models Stage 6, checked by the game tool. **Work item:** review existing models for this convention and correct them where not met; moot for placeholders being replaced, but the tool must report it. Pivot tolerance: B18 (≈ 2% of length). | §3 M7, S4; §4.3 step 4; §4.6 (a), (c); §4.9 item 2; §5 Phase 0; §7. |
| B11 | 2026-10-01 | **(BQ6) `creature_size = max(length, width, height)`** on live dimensions. User rationale: tall creatures (large bipeds, a giraffe, taller than long) are measured correctly. | §3 M9; §4.1; §4.2; §7. |
| B12 | 2026-10-01 | **(BQ7) Both tools:** a headless Godot tool under `tools/` (test-harness) and a Blender checklist script for HK-models Stages 3 / 6, sharing one ratio / tolerance definition. PROJECT_DOC_INDEX gets "Related (outside Project_Docs)" rows pointing at the HK-models pipeline docs so changes on either side are visible (caller routes that edit). Shared definition location: B18. | §3 M7, S2; §4.6; §4.9; §5 Phases 0, 4; §8; §11. |
| B13 | 2026-10-01 | **(BQ8) Dimensions from design intent.** All current rabbit / fox / wolf models are **temporary** and will be replaced once the HK-models pipeline is resolved. User preference: model distortion to match correct dimensions beats unrealistic dimensions to match models. **Placeholder exemption:** a flagged placeholder model (name proposal `placeholder_model`; location B19) is fitted with non-uniform scale to hit the authored dimensions, and its proportion check reports warn, never fail. Production models from the pipeline follow the normal B8 warn / fail rule. Add a fox archetype; remove the wolf 3× wrapper. Values: B20. | §2.1; §3 M4, M10; §4.3 step 3–4; §4.8; §5 Phase 2; §7; B19, B20. |
| B14 | 2026-10-01 | **(BQ9) Default: clamp capsule height up to 2r** for low / wide bodies (logged). Revisit after seeing it in practice. **Refined by B24 (2026-10-02):** the clamp is kept, now as `max(live_height, 2r)` on a total-height capsule. | §4.2; §7; §8; B24. |
| B15 | 2026-10-01 | **(BQ10) Reach is a scalar (half length)**; no separate oriented hit shape. Fate of the existing hit `Area3D`: B21. **Reach part superseded by B25 (2026-10-02):** the scalar and no-oriented-shape parts stand; the "half length" value is replaced by `live_length × (0.5 + reach_margin_fraction)` with an optional `reach_override`. | §4.2; §4.8; §7; B21; B25. |
| B16 | 2026-10-01 | **(BQ11) Accept nose / tail overhang** into obstacles for now; revisit in live play. | §4.5; §4.10; §8; §9. |
| B17 | 2026-10-01 | **(BQ12) Each nav class declares a max body radius and a max `creature_size`; a creature's class is the smallest class satisfying both.** Answers NAVIGATION_PASSABILITY Q12 (cross-link only; that plan is not edited here). | §4.2; §4.10; §5. |
| B18 | 2026-10-02 | **(BQ13) One shared tolerance JSON in this repo**, `tools/body_dimension_spec.json` (path chosen by the designer pass), read by the Blender checklist by relative path (sibling folders `HK-models` / `hunter-killer`) and by the game tool. Contents: proportion thresholds (warn 10% / fail 20%), variety stretch range (±10%), origin-position tolerance (≈ 2% of length). **`width_margin`** (0.10; movement radius = W / 2 × 1.10) goes in `game_config.json` with the other motor tuning, because it is gameplay, not an art check. | §3 S2; §4.2; §4.4; §4.6; §4.8; §4.9 item 5; §5 Phases 0, 1, 4; §7; §8. |
| B19 | 2026-10-02 | **(BQ14, modified) The placeholder flag lives in the pack's `pack_resources.json`** (a property of the model, not the species), with a **default**: models are production-standard unless stated, and the flag (and any other per-model override) appears in a pack's `pack_resources.json` **only when the model deviates** from the standard. Today the three rabbit / fox / wolf models are flagged. **Placeholder mount fit auto re-centres the origin** (no re-export); production models must follow B10 with no correction. | §3 M10; §4.3 steps 3–4; §4.8; §5 Phases 1, 2; §7; §8. |
| B20 | 2026-10-02 | **(BQ15) Initial design-intent dimensions (L / W / H, game units):** rabbit 1.7 / 0.7 / 1.4 (ears up), movement radius 0.39 (was 0.6 archetype); fox 2.0 / 0.4 / 0.9, radius 0.22 (was 2.34 from the mesh); wolf 6.0 / 1.3 / 3.0, radius 0.72 (was 7.03 from the mesh). Radius = W / 2 × 1.10. Wolf radius drops about 10×, so navigation erosion and the gap-trap likely mostly disappear and the wolf may fit the small nav class. Nav class boundaries (B17) are retuned only after these land. The reach split ships in the same change set as the capsule change (§4.7 gating rule). The fox is narrower than the rabbit (realistic; noted). | §2.1; §4.8; §4.10; §5 Phases 0, 2; §7; §8. |
| B21 | 2026-10-02 | **(BQ16) The legacy hit `Area3D` (`MobHitbox`) is left to the already-planned template cleanup.** Until then it stays 1.15 × the body radius applied to the new radius, with no new logic. Code check 2026-10-02: nothing consumes it for predation (see §10 BQ16 answer). | §4.2; §4.3 step 6; §4.8; §5 Phase 1; §7. |
| B22 | 2026-10-02 | **Forward axis: +Z (Godot `MODEL_FRONT`), superseding B4's −Z.** User rule: "either is fine as long as it's documented; if −Z gives forward-facing in Blender by default, use −Z." Fact: Blender's glTF export maps Blender +Y to Godot −Z, so −Z forward would require the nose along Blender +Y, which is the opposite of Blender's default character facing (−Y, toward the Front-view camera). The condition fails, so the convention is **+Z forward** (Blender nose along −Y, the default; Y up). Needs a small code change to the facing math (§4.8.1, Phase 3); no code in this pass. The motor / movement semantic "forward" in existing code and tests must be checked as part of that item. | §3 S4; §4.2; §4.6; §4.8 / §4.8.1; §4.9 item 1; §5 Phase 3; §7; §8; supersedes B4. |
| B23 | 2026-10-02 | **One named forward constant.** User decision: retarget ALL hard-coded forward fallbacks (`MotorPlane.HORIZONTAL_FORWARD` in `motor_planner.gd`, `motor_explore_seek.gd`, `awareness_zone.gd`; `Vector3.FORWARD` in `creature_motor_stack.gd`, `occluded_in_zone_ghost.gd`) to `MotorPlane.MODEL_FORWARD`, the single source of truth for the model-forward convention, so the axis can later change in one place. `HORIZONTAL_FORWARD` is retired (or at most a derived alias). `yaw_from_horizontal_dir` derives from the constant, so one edit flips the yaw formula and the fallbacks. Value +Z (B22). Compass-bearing `atan2(x, -z)` in the memory files remain world bearings, not model forward. Recommended phasing: land the constant behavior-preserving (still −Z) first, then flip to +Z with the overrides. Resolves the "decision needed at implementation" in §4.8.1. **Correction 2026-10-05 (B26):** the claim that deriving yaw from the constant "reproduces today's `atan2(d.x, -d.z)`" at −Z was wrong for X components; the derivation fixes the mirror, so the −Z-first step is not purely behavior-preserving. | §4.8 / §4.8.1; §5 Phase 3; §7; §8. |
| B24 | 2026-10-02 | **Capsule height uses Godot 4 semantics.** `CapsuleShape3D.height` is the total height including both hemispheres and must be ≥ 2 × radius. Height = `body_height`, clamped to at least 2r (keeps and replaces B14's clamp wording; the clamp is logged). The Godot-3-style `sy − 2r` in `creature_mesh_footprint.gd` 57–61 (followed by a Godot-4 `≥ 2r + 0.05` clamp) is replaced; code check showed the kinematic body already uses total-height semantics, so only the footprint input was wrong. Resolves the §4.2 `<<Comment>>`. | §4.2; §2.1; §4.8; §5 Phase 1; §7; §8; refines B14. |
| B25 | 2026-10-02 | **Reach extent = body-centre-to-nose plus a margin.** `reach = live_length / 2 + reach_margin_fraction × live_length`, default fraction **0.25** (so 0.75 × length from the body centre: rabbit 1.275, fox 1.5, wolf 4.5). The fraction is a named key in `game_config.json` (+ `game_config.gd` facade), not a literal. Optional `reach_override` on `CreatureDefinition`: when set it replaces the computed value; specified as an **absolute distance from the body centre** (recommended and adopted). Eat / flee / contact consumers must be re-compared against pre-change values (reach moves from the old radius-based terms to 0.75 L; today's values listed in §4.7). **Supersedes the reach-value part of B15** (scalar and no-oriented-shape stay). | §4.2; §4.7; §4.8; §5 Phase 1; §7; §8; supersedes B15 (reach part). |
| B26 | 2026-10-05 | **Fix the mirrored Visual yaw as part of the Phase 3 change set.** Root cause of the awareness cone / model mismatch seen in live play: `yaw_from_horizontal_dir = atan2(d.x, -d.z)` is mirrored left / right (Godot Y rotation is counter-clockwise from above; heading +X gives a nose toward −X; correct only for ±Z). Correct general formula: the signed angle rotating `MODEL_FORWARD` onto d about +Y, `wrap(atan2(d.x, d.z) − atan2(F.x, F.z))`; F = +Z gives `atan2(d.x, d.z)`, F = −Z gives `atan2(−d.x, −d.z)`. Facing-check results (§2.1.1 finding 7): both templates need `visual_yaw_offset_rad` 3π/2 under +Z. Acceptance test uses real engine rotation (`Basis(UP, yaw) * MODEL_FORWARD ≈ d` for 8 headings), not a hand-built inverse; visual verification via `tools/facing_check_3d.tscn` at ±X, ±Z. Phase 3 is reprioritised: highest priority, may ship before Phases 1 / 2. Corrects B23's "reproduces today's formula" claim. **Shipped 2026-10-05 (bfcbd26), user-confirmed in play; status `done`.** | §2.1.1; §4.8 / §4.8.1; §5 Phase 3 + ordering note; §7; §8; §9. |
| B27 | 2026-10-05 | **Eat gate target side = target body radius (option a).** User decision. `_eat_reach_radius_bonus` = eater `get_reach_extent()` (B25) + target `get_body_radius()`; plants contribute 0; added to the fixed `eat_action_max_distance` (5.0). Same pairing as C1 contact (predator's mouth / reach meets prey's side). Rejected: (b) target reach extent (over-credits a long prey approached from the side). Illustrative gates: wolf→rabbit 9.9, fox→rabbit 6.9, rabbit→plant 6.3 (rabbit radius 0.39 is the B20 design-intent value; live mesh-derived radius, archetype 0.6, until Phase 1 / 2). Retune expectation: all gates shift, so the eat-range tuning (decision 26) is re-checked in Phase 1. Resolves the §4.7 `<<Question>>`. | §4.7; §4.8; §5 Phase 1; §7; §8. |

---

## 7. Acceptance criteria

(Agent treats unchecked items as incomplete.)

- [ ] `CreatureDefinition` exposes `body_length`, `body_width`, `body_height`. No authored capsule radius / height fields remain, and `creature_size` equals `max(live_length, live_width, live_height)`, including after a runtime size change (B11, headless; include a fixture taller than it is long).
- [ ] After mount, every creature's `CharacterBody3D.scale` is `Vector3.ONE`, including after a runtime size change (headless).
- [ ] The movement capsule radius equals `live_width / 2 × (1 + width_margin)` and its `CapsuleShape3D.height` equals `max(live_height, 2 × body_radius)` exactly (B24 total-height semantics; no `− 2r` and no `+ 0.05`), for rabbit, fox and wolf (heights 1.4 / 0.9 / 3.0; with the B20 radii 2r is 0.78 / 0.44 / 1.44, so none of the three clamps); a low / wide fixture clamps to 2r and logs it (headless).
- [ ] **Production** model: the Visual is scaled uniformly; its rest-pose length after scaling equals `live_length` within 1%.
- [ ] **Placeholder** model (B13): the Visual's rest-pose L / W / H after the per-axis fit each equal the live dimensions within 1%, and any proportion deviation is reported as a warning, never a failure (headless, game and tool).
- [ ] A production model whose W or H ratio deviates > 10% logs exactly one proportion warning per species per session; > 20% is reported as a fail by the tool; in both cases the creature still spawns with authored-dimension collision (headless, using deliberately mis-proportioned fixture models).
- [ ] Reach extent (B25), default: `get_reach_extent()` equals `live_length × (0.5 + reach_margin_fraction)` with the default 0.25 for rabbit 1.275, fox 1.5, wolf 4.5 (headless, including after a runtime size change).
- [ ] Reach extent, override: a definition with `reach_override` set returns exactly that absolute distance (scaled only by the runtime size factor), ignoring length and fraction; unset (`0.0`) uses the computed value (headless).
- [ ] Reach extent, config-driven: changing `reach_margin_fraction` in `game_config.json` (via the `game_config.gd` facade) changes `get_reach_extent()` for creatures without an override; no literal 0.25 remains in creature code (headless plus grep check).
- [ ] Reach extent is a scalar; no oriented hit shape exists (B15). The legacy `MobHitbox` `Area3D` radius equals 1.15 × the new body radius and no new logic reads it (B21).
- [ ] `width_margin` is read from `game_config.json` (default 0.10) (B18); the shared tolerances are read from `tools/body_dimension_spec.json` by both the game tool and the Blender checklist.
- [ ] Placeholder flag: read from the pack's `pack_resources.json`; a pack without the key is treated as production (B19). The rabbit, fox and wolf packs carry the flag. A placeholder mount ends with the scaled AABB bottom-centre on the body origin (headless).
- [ ] Facing invariant: for every creature with width ≤ length, each locomotion tick's horizontal displacement is parallel to ±facing within a small angular tolerance (headless, across turn, blended turn + move and backward moves).
- [x] Mirrored yaw fix (B26; shipped 2026-10-05, bfcbd26; user confirmed in play): `Basis(Vector3.UP, yaw_from_horizontal_dir(d)) * MotorPlane.MODEL_FORWARD` equals `d` within tolerance for 8 headings (±X, ±Z and the four diagonals), using real engine rotation, not a hand-built inverse of the formula (headless; the old `(sin(yaw), 0, −cos(yaw))` round-trip at `tests/run_all.gd` ~13085 is replaced). Visual check with `tools/facing_check_3d.tscn` at headings ±X, ±Z: the rabbit, fox and wolf noses lie along the heading arrow, and the awareness cone and the model turn together in live play. Both kinematic templates carry `visual_yaw_offset_rad` 3π/2 (confirmed by that check).
- [x] Forward axis (B22, B23; shipped 2026-10-05, bfcbd26; the §4.8.1 semantic-"forward" audit classification is recorded in the commit and §4.8.1 above): `yaw_from_horizontal_dir` aligns a +Z-forward mesh with `last_move_direction` for all 8-way directions (covered by the B26 test above); each X-long placeholder (Phase 0, §2.1.1) carries its reconciled net yaw (existing template offsets adjusted, not stacked) and faces its travel direction; `MotorPlane.MODEL_FORWARD` is the only forward literal: `yaw_from_horizontal_dir(MODEL_FORWARD) == 0` (headless), and a grep check finds no remaining `HORIZONTAL_FORWARD`, creature-facing `Vector3.FORWARD` or literal forward vector outside the constant (B23); the audit of semantic "forward" uses in §4.8.1 is recorded with each item classified (unaffected / changed), and the full suite stays green.
- [ ] Every consumer in §4.7 uses `get_body_radius()` or `get_reach_extent()`; no call site reads an ambiguous "capsule radius" (grep check).
- [ ] Eat reach and C1 contact distance (reach consumers) and the flee threat / choke / shelter-fit numbers (body-radius consumers) for rabbit / fox / wolf are compared headless against the pre-change values recorded in §4.7 (for example wolf→rabbit eat gate ~12.6, fox→rabbit ~7.9; reach term moves to 0.75 L; expected post-change gates under B27: wolf→rabbit ≈ 9.9, fox→rabbit ≈ 6.9, rabbit→plant ≈ 6.3), and either stay within an agreed delta or have been explicitly retuned with the change recorded.
- [x] The §4.7 eat-gate target-side Question is answered (B27, 2026-10-05: target body radius).
- [ ] `_eat_reach_radius_bonus` implements B27: eater `get_reach_extent()` + target `get_body_radius()` (plants 0), with a headless test of the three illustrative gates (wolf→rabbit ≈ 9.9, fox→rabbit ≈ 6.9, rabbit→plant ≈ 6.3 once the B20 dimensions are live).
- [ ] The wolf mounts its model without the 3× wrapper, and its mounted visual sits on the ground, centred on the body in XZ (B10; placeholder origin re-centre, B19).
- [ ] A fox archetype exists; rabbit, fox and wolf archetypes carry the B20 design-intent dimensions (rabbit 1.7 / 0.7 / 1.4, fox 2.0 / 0.4 / 0.9, wolf 6.0 / 1.3 / 3.0; radii 0.39 / 0.22 / 0.72); all three current models are flagged as placeholders; the placeholder measurement reports are recorded in §2.1.
- [ ] The measuring tool reports L / W / H, pivot vs the B10 convention, forward axis and ratio pass / warn / fail for each shipped creature model (placeholders included), reads its thresholds from the shared spec `tools/body_dimension_spec.json` (B18), proposes a dimension block in model-first mode (B9), and exits non-zero on a production-model fail (headless).
- [ ] The full suite stays green (`tests/run_all.gd`).
- [ ] Cross-repo: the HK-models doc carries the facing, pivot, unit (1 Blender unit = 1 game unit), measurement, ratio-spec and checklist rules (§4.9). The caller confirms this; it can't be checked from this repo.
- [ ] PROJECT_DOC_INDEX has "Related (outside Project_Docs)" rows for the HK-models pipeline docs (B12; caller routes).

---

## 8. Risks and mitigations

| Risk | Mitigation |
|---|---|
| **Retuning every radius-based distance.** Radii shrink to about a half or a third. Eat reach, flee distances, contact geometry, shelter fit, choke credit and navmesh erosion all shift. | §4.7 audit with a reach-extent / body-radius split; the gating rule (same change set); headless before / after comparisons (§7). Treat earlier live tuning as needing a re-check, as NAVIGATION_PASSABILITY §3.3 does. |
| **Visual clipping from the width radius.** The nose and tail overhang the capsule (`L/2 − r`), and a pivot in place sweeps head and tail through obstacles. | Accepted residual (B5, B16): no forward stop distance or probe for now; revisit in live play (forward stop distance is the first fallback). A debug overlay (N2) makes it visible. |
| **Cross-repo drift.** HK-models is outside this repo and not under git, so its rules and tolerances can drift from the game's. | One shared tolerance / ratio definition (B12, B18: `tools/body_dimension_spec.json`, read by relative path, so the cross-repo path layout is itself a dependency); the game-side tool re-checks every model at import regardless of what the art side did; PROJECT_DOC_INDEX "Related (outside Project_Docs)" rows (B12); this doc lists the required edits (§4.9). |
| **Low, wide bodies** (width × 1.1 > height) can't form a valid capsule. | B14 / B24: `CapsuleShape3D.height = max(live_height, 2r)` and log it. The capsule is then taller than the body (overhang clearance, navmesh `agent_height`, LoS eye height `0.9 ×` capsule height); revisit once seen in practice. |
| **Reach moves from radius-based terms to 0.75 L (B25).** Eat gates, contact distance and any tuning that assumed the old per-species terms shift (wolf eater term 7.03 → 4.5, fox 2.34 → 1.5, rabbit 0.6 → 1.275, so the rabbit as eater gets *more* reach). The margin fraction and `reach_override` make it tunable, but the first values are untuned. Under B27 (target term = body radius) the eat gates become wolf→rabbit ≈ 9.9, fox→rabbit ≈ 6.9, rabbit→plant ≈ 6.3, so decision-26 eat-range tuning needs a re-check. | §4.7 lists pre-change values and the gating rule keeps the reach split in the Phase 1 change set; headless before / after comparisons (§7); `reach_margin_fraction` is one config key to retune; per-species fixes via `reach_override`. |
| **Placeholder distortion.** Per-axis fitting of placeholder models (B13) visibly distorts them, and the exemption could let a real model ship flagged as a placeholder. | Accepted by the user (distortion beats wrong dimensions). The tool still reports every placeholder's deviation; the flag is removed when a pipeline model replaces the placeholder, which re-enables the B8 fail rule. |
| **Forward-axis flip (B22) turns models backward or shifts default facings.** The existing placeholders are X-long (Phase 0), with their facing currently compensated by template Visual yaw offsets; world-space fallbacks (`HORIZONTAL_FORWARD`, `Vector3.FORWARD`) feed first-tick facing (B23: all become `MotorPlane.MODEL_FORWARD`; land it at −Z first, then flip). | §4.8.1: measure forward in Phase 0, ship the formula change with the reconciled per-model ±90° net yaw (sign by visual check; not stacked on template offsets) in one change set, audit and classify every semantic "forward" use, update the round-trip test. |
| **Mirrored yaw is live now, and a self-consistent test hid it (B26).** The Visual turns mirrored for X headings today; the existing round-trip test uses the same wrong formula. Models replaced under the HK-models rules will inherit the bug until Phase 3 ships. Risk in the fix: X-heading visuals change on purpose, and wrong template offsets would leave models 180° or 90° off. | Prioritise Phase 3 and allow it to ship before Phases 1 / 2 (§5 ordering note); acceptance test via real `Basis(UP, yaw) * MODEL_FORWARD` (not an inverse of the formula); visual verification with `tools/facing_check_3d.tscn` at ±X, ±Z; both template offsets set to 3π/2 from the facing-check results. |
| **Baseline tolerances are untuned** (B8). | Treated as a pre-tuning baseline; they live in one shared spec so retuning is a single edit. |
| **Proportion warnings ignored.** Warnings become noise and bad models ship. | The tool exits non-zero on fail; a headless test runs the tool over all shipped packs. |
| **Variety stretch hides real art bugs.** | The proportion check runs on the **unstretched** fit (§4.4); stretch is applied after it passes. |
| **Hunyuan fallback models** arrive at arbitrary ratios. | A mandatory Stage 3 fix / rescale step; the tool check catches leftovers. |
| **Navigation plan builds on stale radii.** | Navigation Phase 1 starts after Phase 2 here (§5); `R_k` and class max `creature_size` (B17) are set from the design-intent dimensions (§4.10). |

---

## 9. Testing / verification

**Automated (proposed):**
- No-body-scale test: mount, runtime size change up and down, assert `scale == Vector3.ONE` and that the shapes match the live dimensions.
- Fit test: a fixture model at a known AABB is scaled uniformly to `live_length`; mis-proportioned fixtures at > 10% and > 20% trigger exactly one warning and a tool fail respectively.
- Placeholder fit test: the same mis-proportioned fixture flagged as a placeholder is fitted per-axis to all three live dimensions and reports warn, not fail.
- `creature_size` test: a tall fixture (H > L) gets `creature_size = H`.
- Low / wide test: a fixture with `H < 2r` gets capsule height 2r and one log line; a tall fixture gets exactly `H` (B24, no `− 2r`).
- Reach tests (B25): default (0.25 → 1.275 / 1.5 / 4.5), `reach_override` replaces the computed value, `reach_margin_fraction` changed in config changes the result.
- Consumer comparison tests: eat gate and flee / choke numbers before vs after (§4.7 pre-change values).
- Facing invariant test (§7).
- Yaw engine-rotation test (B26): for 8 headings, `Basis(Vector3.UP, MotorPlane.yaw_from_horizontal_dir(d)) * MotorPlane.MODEL_FORWARD` must equal `d`; plus `yaw_from_horizontal_dir(MODEL_FORWARD) == 0`. Never rebuild the direction from `sin` / `cos` of the formula's own convention (that is what hid the bug).
- Consumer split tests: eat reach and contact use the reach extent; path / gap checks use the body radius.
- The tool, run over every shipped creature pack, with ratio checks against its archetype.
- Replace the wolf wrapper tests (`tests/run_all.gd` ~962–1010).

**Manual (facing, B26):** open `tools/facing_check_3d.tscn` and check rabbit, fox and wolf noses against the heading arrow at ±X and ±Z; in live play confirm the awareness cone and the model turn together.

**Manual:** spawn rabbit, fox and wolf next to boulders and shrubs with the capsule debug draw on. Check the nose overhang and the pivot sweep (accepted for now, B16; this is the live-play revisit). Check how distorted the per-axis-fitted placeholders look (B13). Re-run the c1 and decision-44 smokes after Phase 2.

---

## 10. Questions and answers

Each question gives context, options with consequences, and the caller's recommendation, then the user's answer block. Numbered **BQ** to avoid clashing with NAVIGATION_PASSABILITY's Q numbers. **BQ1–BQ12 were answered on 2026-10-01** and **BQ13–BQ16 on 2026-10-02** (decisions B6–B21, one per question, BQn → B(n+5)). No question is open.

### BQ1 — World unit scale

HK-models says 1 unit = 1 m. Current game sizes aren't real-world: rabbit `creature_size` 1.7, wolf 6.0, playfield ~200 × 204. A real wolf body is roughly 1–1.6 m long and a rabbit roughly 0.4–0.5 m, so today's numbers imply about **4 game units per real metre**, and the rabbit and wolf are consistent with each other at that factor (author's estimate, not measured).
- **(a) Metres at real-animal scale:** rescale the world, playfield, speeds, reach / flee distances and navmesh voxel sizes. Gravity (9.8 units/s²) would then feel correct. This is the largest retune.
- **(b) Game units with one documented project scale factor** (for example 1 game unit = 0.25 m): the art pipeline exports in metres, and the uniform fit (§4.3) applies the factor. No world retune. Gravity and physics feel stay as tuned today.
- **(c) Undocumented status quo:** rejected, because it is exactly what produced the wolf wrapper.
- Note: with B2's uniform fit, a model's absolute exported size doesn't affect gameplay; only its ratios do. The scale choice matters for the export convention, physics feel and every tuned distance.
- **Rec:** pick one documented scale. (b) is cheaper now; (a) is cleaner long term.

**Answer (user, 2026-10-01; B6):** (b). Game units with one documented factor, ~4 game units per real metre (estimate); no world rescale now. HK-models exports directly in game units (1 Blender unit = 1 game unit), not metres with a fit-time factor. Follow-up cleanup **after** this feature and the navigation work land (not now, not a phase gate): revisit hard-coded distances (for example the ~5-unit combat / contact distance) and move species sizes toward realistic proportions (for example rabbit and wolf length). See §2.5, §5.1.

### BQ2 — What the dimensions measure

- **(a) Whole rest-pose mesh AABB**, including tail, ears and horns: tool-measurable and unambiguous. A long tail inflates length, so reach extent and `creature_size` grow.
- **(b) Body only (no tail):** closer to gameplay intent, but needs a cut rule per species (bone, marker or manual), so it can't be measured automatically.
- **Rec:** (a). The reach extent uses length. If a species' tail distorts reach badly, add a per-species override later.

**Answer (user, 2026-10-01; B7):** (a). Whole-mesh AABB in the neutral rest pose, tail and ears included. (Read as the armature rest / bind pose with no animation applied, §4.1.)

### BQ3 — Stretch tolerance numbers and mechanism

- **Proportion-check warn threshold:** proposal 10–15% per axis (W and H after uniform fit on L). Whether there is also a hard "fail" threshold, and what happens on fail (refuse to mount, or warn only).
- **Allowed variety stretch per instance:** proposal ±10% per axis.
- **Stretch mechanism:** (a) non-uniform Visual-node scale: simple and works on any model, but distorts heads and eyes; (b) bone-chain scaling (HK Variation Strategy: torso girth, leg length): plausible anatomy, but needs rigs plus a mapping from bones to resulting L / W / H; (c) both, with (a) for size and (b) for variety.
- Either way, collision follows the instance's resulting dimensions.
- **Where the numbers live:** `game_config.json` (app-shell) or a shared spec file (BQ7). The same applies to `width_margin` (B5).
- **Rec:** warn at 15%, fail at 30% (tool only, the game still mounts); ±10% stretch; (c).

**Answer (user, 2026-10-01; B8):** accepted as the **pre-tuning baseline**: warn > 10% per axis, fail > 20% per axis; per-instance variety ±10% per axis via bone-chain scaling, with Visual-node scale as the fallback; collision follows the instance's actual dimensions; the tolerances live in one shared spec. Fail effect follows the recommendation (tool fails; the game still mounts). Placeholder models are exempt from fail (B13). Where the shared spec lives, and whether `width_margin` joins it, was settled in BQ13 (B18).

### BQ4 — Source of truth and data flow between repos

- **Where the species dimension spec lives:** (a) the game archetype `.tres` is the truth, copied into the HK-models subject `status.md` (or a spec file) at Stage 1; (b) a shared spec file (JSON) that both the game and HK-models read; the archetype references it or is generated from it.
- **Bootstrapping direction:** model-first (the tool proposes dimensions from an existing model and the designer accepts them into the archetype) vs spec-first (dimensions set first, then fed to Rodin).
- **Consequences:** (a) is simple but copies the numbers by hand, and HK-models has no git to track the copy. (b) removes the copy but adds a cross-repo file path dependency.
- **Rec:** the archetype is the truth, and the tool supports both directions.

**Answer (user, 2026-10-01; B9):** (a). The species archetype `.tres` (`CreatureDefinition` leaf data) is the source of truth, consistent with Definitive CREATURE_3D_ARCHITECTURE §2. Its §4 "Size sync (M4)" text must be synced by `project-docs` when this ships (§11). Dimensions are copied into the HK-models subject spec at Stage 1 and fed to Rodin `bbox_condition`. The tool works in both directions.

### BQ5 — Pivot / origin convention

- **Proposal:** origin at ground contact (the lowest point of the rest-pose AABB), centred in XZ on the rest-pose AABB. This avoids the wolf pivot bug that the wrapper compensates for (§2.1).
- Enforce it at the HK-models Stage 6 export; the game-side tool checks it.
- **Alternative:** centre on the torso (centre of mass) instead of the AABB. This is better for turning about the hips, but harder to measure and it shifts the capsule off the AABB centre.
- **Rec:** AABB-centred, ground contact.

**Answer (user, 2026-10-01; B10):** origin at ground contact, centred on the rest-pose AABB XZ footprint; enforced at HK-models Stage 6 and checked by the game tool. **Work item:** review existing models for this convention and correct them where not met (moot for placeholder models being replaced, but the tool must report it; §4.6 c, Phase 0). The pivot tolerance was not given; it was settled in BQ13 (B18, ≈ 2% of length).

### BQ6 — `creature_size` derivation

[CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md) defines `creature_size` as the longest body dimension. The options are `max(L, W, H)` (follows the definition; a giraffe would use its height) or `L` (equal for quadrupeds). `fit_size` compares against it (NAVIGATION_PASSABILITY D5, Q12), so the choice moves Mode A / B entry results. Under BQ2 (a) a tail lengthens it.
- **Rec:** `max(L, W, H)`, live (after size factor and stretch).

**Answer (user, 2026-10-01; B11):** `creature_size = max(length, width, height)`, on live dimensions. Rationale: tall creatures (large bipeds, a giraffe, taller than long) are measured correctly.

### BQ7 — Tool home and form

- **Game side:** a headless Godot script under `tools/` (test-harness) that loads a `.glb` / `.blend` / `.tscn`, reports L / W / H, pivot and forward axis, and checks the ratio against the archetype. It also runs as a test over all shipped packs.
- **Art side:** a Blender `execute_blender_code` checklist script in HK-models Stages 3 / 6.
- **Shared definition:** one ratio / tolerance definition used by both: a JSON file in this repo that the HK-models script reads by path, or values duplicated with a version stamp.
- **Rec:** both tools, sharing one definition file.

**Answer (user, 2026-10-01; B12):** both. A headless Godot tool under `tools/` (test-harness) and a Blender checklist script for HK-models Stages 3 / 6, sharing one ratio / tolerance definition. PROJECT_DOC_INDEX gets "Related (outside Project_Docs)" rows pointing at the HK-models pipeline docs so changes on either side are visible (the caller routes that edit). The definition's location and the relative-path read were settled in BQ13 (B18).

### BQ8 — Migration of existing creatures

- Choose initial dimensions for rabbit, fox and wolf. This needs the Phase 0 measuring pass of the current models.
- Remove the wolf 3× wrapper (and fix the `wolf.blend` pivot, or replace the placeholder model).
- Add a fox archetype.
- The Hunyuan fallback can't take ratios, so its models need a post-generation rescale / fix in Stage 3.
- **Options for the numbers:** (a) measure the current models and accept them as the spec; (b) set the spec from design intent (relative sizes) and fix the models to match, producing warnings until the art is fixed.
- **Rec:** (a) for the first pass, so no warnings at launch. Revisit per species when new art lands.

**Answer (user, 2026-10-01; B13):** (b), set the dimensions from design intent. **All current rabbit / fox / wolf models are temporary** and will be replaced once the HK-models pipeline is resolved. Preference: model distortion to match correct dimensions beats unrealistic dimensions to match models. So placeholder models are fitted with non-uniform scale to hit the authored dimensions, and the proportion check reports (warn) rather than fails. This is an explicit **placeholder exemption** behind a flag (name proposal `placeholder_model`); production models from the pipeline follow the normal B8 warn / fail rule. Add a fox archetype; remove the wolf 3× wrapper. The flag's location and placeholder pivot handling were settled in BQ14 (B19); the numbers in BQ15 (B20).

### BQ9 — Low, wide bodies (new)

A capsule needs `height ≥ 2 × radius` (verify the semantics, §4.2 comment). A body with `H < W × 1.10` (for example a tortoise or a flat lizard) can't form one.
- **(a) Clamp the height up to 2r:** the capsule is taller than the body, which matters for overhang clearance and navmesh `agent_height`.
- **(b) Use a sphere or cylinder shape** for such bodies: different contact behaviour on slopes and steps.
- **(c) Shrink the radius to H/2:** the body is under-represented in width, so it clips sideways.
- **Rec:** (a) for now (no such species is planned), and log it.

**Answer (user, 2026-10-01; B14):** (a) as the default. Clamp the capsule height up to 2r for low / wide bodies; revisit after seeing it in practice.

### BQ10 — Hit extent shape and orientation (new)

B1 says the hitbox comes from length (reach extent). Today the hit capsule is axis-aligned with 1.15 × body radius. Hitbox kills are removed (CLEANUP D11); the hitbox now serves overlap consumers only.
- **(a) Axis-aligned cylinder / capsule of radius `L/2`:** simple, but as wide as it is long (the same over-coverage as today, sideways).
- **(b) A horizontal capsule along facing** (length L, radius W/2) that rotates with the Visual. This is exact, and an `Area3D` can rotate safely (no `move_and_slide`).
- **(c) No hit shape at all:** reach is computed numerically (centre distance vs reach extent) at the consumers.
- **Rec:** (b) if any overlap consumer remains; (c) if none does.

**Answer (user, 2026-10-01; B15):** reach is a scalar (half length); no separate oriented hit shape. Whether the existing axis-aligned hit `Area3D` stays for overlap consumers was settled in BQ16 (B21).

### BQ11 — Front overhang against obstacles (new)

With a width-based radius, the nose extends `L/2 − r` past the capsule (roughly 2 m for the wolf, §4.5), so head-on approaches to boulders and shrubs clip visually.
- **(a) Accept it** (B5 residual).
- **(b) Motor forward stop distance:** obstacle approach and arrival add the forward overhang. This touches arrival / substep code.
- **(c) A forward ray or shape probe** that limits forward speed near layer-1 / ghost obstacles.
- **Rec:** (a) now, and (b) if the live check shows it is bad.

**Answer (user, 2026-10-01; B16):** (a) for now. Accept nose / tail overhang; revisit in live play.

### BQ12 — Class membership key for navigation (hand-back of NAVIGATION_PASSABILITY Q12, new)

Under B1, width and length are independent. So there is **no fixed mapping** between the body radius (from width) and `creature_size` (from length or the max dimension). A class can't derive one from the other without assuming an aspect ratio.
- **(a) Key on body radius;** the class's max `creature_size` is declared separately for the D5 `fit_size` compare.
- **(b) Both are declared per class;** a creature's class is the smallest class that satisfies both (NAVIGATION_PASSABILITY Q12 option 3).
- **(c) Key on `creature_size`,** with the radius taken from an assumed aspect ratio: wrong for unusual body shapes.
- **Rec:** (b). It is the only option that needs no aspect-ratio assumption, and it stays runtime-derived (NAVIGATION_PASSABILITY D7).

**Answer (user, 2026-10-01; B17):** (b). Each nav class declares a max radius and a max `creature_size`; a creature's class is the smallest class satisfying both. This answers NAVIGATION_PASSABILITY Q12 (cross-link only; that plan is updated separately).

### BQ13 — Shared spec file: location, format and contents (new, from B8 / B10 / B12)

B8 and B12 require one ratio / tolerance definition shared by the game tool and the Blender checklist, but its location was not chosen.
- **(a) A JSON file in this repo** (for example under `tools/` or `creature/species/`), read by the HK-models Blender script via a relative path such as `../hunter-killer/...`. One copy; adds a cross-repo path dependency.
- **(b) A JSON file in this repo, duplicated into HK-models with a version stamp.** No path dependency; drift is caught only by the stamp.
- **Contents to decide:** warn / fail thresholds (B8), variety range (B8), pivot tolerance (B10, not yet given; proposal: a small fraction of the body dimension per axis, for example 2% of the matching L / W / H), and whether `width_margin` (B5) lives here or in `game_config.json`.
- **Rec:** (a), with `width_margin` in the same file so every size constant is in one place.

**Answer (user, 2026-10-02; B18):** (a), accepted as recommended with one change: `width_margin` does **not** join the file. The shared tolerances (10% / 20% proportion thresholds, ±10% stretch range, origin-position tolerance ≈ 2% of length) live in **one JSON file in this repo**, read by the Blender checklist script by relative path (sibling folders `HK-models` / `hunter-killer`) and by the game tool. `width_margin` (movement radius = W / 2 × 1.10) goes in `game_config.json` with the other motor tuning (gameplay, not an art check). **Path chosen (designer pass): `tools/body_dimension_spec.json`.** Reasoning: it is a definition for the measuring tool and the Blender checklist (test-harness territory), the Blender script reaches it as `../hunter-killer/tools/body_dimension_spec.json`, and `assets/_shared/` is for pooled game resources referenced through `shared_resources` / `PackResourceResolver` ([assets/CLAUDE.md](../../assets/CLAUDE.md)), which this is not. `creature/species/` was rejected because it holds game-runtime leaf data.

### BQ14 — Placeholder flag location and placeholder pivot handling (new, from B13 / B10)

- **Flag location:** (a) per pack in `assets/creatures/<species>/pack_resources.json` (the flag describes the **model**, and a pipeline model replaces the pack contents), or (b) on the archetype `.tres` (the species). **Rec:** (a), since the exemption should end automatically when the pack's model is replaced.
- **Pivot of placeholders:** removing the wolf 3× wrapper also removes its pivot compensation, and the placeholder `wolf.blend` (and possibly `fox.blend` / the rabbit) may not meet B10. Options: (a) the placeholder fit also translates the Visual so the measured AABB bottom-centre sits on the body origin (consistent with "distortion beats wrong dimensions"); (b) re-export the placeholders with a correct pivot. **Rec:** (a) for placeholders only; production models must pass the pivot check with no correction.

**Answer (user, 2026-10-02; B19):** modified (a). The placeholder flag lives in `pack_resources.json` (a property of the model, not the species), **with a default**: models are treated as production-standard, and the flag (and any other per-model override) appears in a pack's `pack_resources.json` **only when a model deviates from the standard**. Today the three rabbit / fox / wolf models are flagged placeholder. The placeholder mount fit **auto re-centres the origin** (no re-export needed); production models must follow B10 with no correction.

### BQ15 — Initial design-intent dimensions (new, from B13)

B13 sets the rabbit, fox and wolf dimensions from design intent, but no values were given. B6 defers realistic sizes to the post-landing cleanup, so the first values should avoid a gameplay retune.
- **Proposal:** keep today's gameplay lengths (rabbit ~1.7, wolf ~6.0 game units; fox between them, for example ~3.5) and take width and height from real-animal proportions for each species.
- **Alternative:** realistic sizes now at ~4 units / m (rabbit ~1.6–2.0, fox ~2.4–3.6, wolf ~4–6.4 length). This pulls part of the B6 cleanup forward.

**Answer (user, 2026-10-02; B20):** accepted as recommended (today's gameplay lengths, realistic W / H). Values (game units, L / W / H; radius = W / 2 × 1.10):

| Species | L | W | H | Movement radius | Previous radius |
|---|---|---|---|---|---|
| rabbit | 1.7 | 0.7 | 1.4 (ears up) | 0.39 | 0.6 (archetype) |
| fox | 2.0 | 0.4 | 0.9 | 0.22 | 2.34 (mesh-derived) |
| wolf | 6.0 | 1.3 | 3.0 | 0.72 | 7.03 (mesh-derived) |

Consequences noted by the user: the wolf radius drops about 10×, so navigation erosion and the gap-trap likely mostly disappear and the wolf may fit the small nav class; nav class boundaries (B17) are retuned only after these land; the reach split ships with the capsule change; the fox is narrower than the rabbit (realistic).

### BQ16 — Fate of the existing hit Area3D (new, from B15)

B15 makes reach a scalar and rules out an oriented hit shape, but it does not say whether the existing axis-aligned hit `Area3D` (today radius 1.15 × body radius, §2.1) stays. Hitbox kills are already removed (CLEANUP D11).
- **(a) Remove it** if no overlap consumer remains after D11; every consumer uses numeric reach checks.
- **(b) Keep it, axis-aligned,** sized from the body radius (for example 1.15 × as today) for whatever overlap consumers remain.
- **(c) Keep it, axis-aligned, radius = reach extent (L / 2):** sideways over-coverage, as today.
- **Rec:** audit the overlap consumers in Phase 1; (a) if there are none, otherwise (b).

**Answer (user, 2026-10-02; B21):** leave the old hit `Area3D` to the already-planned template cleanup, provided it has no impact. Until then it stays 1.15 × body radius applied to the new radius, with no new logic.

**Verification (designer pass, 2026-10-02, code read):** nothing consumes `MobHitbox` for predation after CLEANUP D11. `_on_mob_hitbox_body_entered` in `creature/capabilities/creature_kinematic_body_3d.gd` (~487) is an immediate `return`, and it is the only `body_entered` / `area_entered` / `get_overlapping_*` use in any `.gd`. The remaining references only toggle the shape's `disabled` flag on defeat / respawn (~464, ~777) and rescale it (~160, ~219, ~233 at 1.15 ×). The node is declared in `creature/templates/creature_herbivore_kinematic_3d.tscn`. **Impact on the cleanup:** `tests/run_all.gd` asserts it exists, monitors, uses mask 4, stays enabled after contact and is disabled after EAT defeat (~721–747, ~801–804), so the template cleanup must update those tests with the node removal.

---

## 11. Related docs

- [NAVIGATION_PASSABILITY_PLAN.md](NAVIGATION_PASSABILITY_PLAN.md): Q10 / Q12 (answered here: §4.10, B17), §3.1 (fox / rabbit radius sources), D5, D7, D9.
- [PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md): decision 5 (runtime size change), the wolf archetype slice (wrapper, `_SPECIES_MESH_FILE`), shelter fit, choke credit.
- [CREATURE_MOVEMENT_V3_CLEANUP.md](CREATURE_MOVEMENT_V3_CLEANUP.md): C1 contact geometry, D11 (no hitbox kills).
- [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md): locomotion executor, facing.
- [CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md): `creature_size` definition (contract to sync).
- [CREATURE_3D_ARCHITECTURE.md §2 / §4](../Definitive_Features/CREATURE_3D_ARCHITECTURE.md): §2 (~31) archetype `.tres` as leaf data with "collision capsule hints" (consistent with B9); §4 (~50) size sync, Visual facing, capsule from mesh AABB (contract to sync).
- `../HK-models/3d_modeling_v1.md` (external, outside this repo): Stages 1–3 and 6, Variation Strategy. To be listed in PROJECT_DOC_INDEX "Related (outside Project_Docs)" rows (B12; caller routes).

**Docs to sync when phases ship (flag for `project-docs`):**
- **CREATURE_3D_ARCHITECTURE §4 "Size sync (M4)"** (~50): today it says the capsule is sized from the mesh AABB and `apply_effective_creature_size` "scales mesh + capsule". Under B1 / B9 the authored archetype dimensions drive the shapes, only the Visual is scaled, and the body is never scaled. Note the **existing drift** to fix in the same sync: code already differs from that text, because it scales the `CharacterBody3D` itself (`creature_kinematic_body_3d.gd` ~223). §2's "collision capsule hints" wording should name the L / W / H fields.
- **CREATURE_ATTRIBUTES_USAGE** `creature_size` row: now derived as `max(L, W, H)` on live dimensions (B11); game units at ~4 units / m (B6).
- [CREATURE_TRAIT_USAGE.md](../Definitive_Features/CREATURE_TRAIT_USAGE.md), if body-radius / reach consumers are listed there.
- NAVIGATION_PASSABILITY §2.1 / §3.1 radius numbers, and its Q12 (answered by B17).
- PROJECT_DOC_INDEX: the row for this doc and the "Related (outside Project_Docs)" HK-models rows (B12; caller routes).

---

## 12. Changelog

| Date | Change |
|------|--------|
| 2026-10-01 | Created (design only, status `design`, no code). Split out of NAVIGATION_PASSABILITY Q10. Records user decisions B1–B5 (authored L / W / H canonical; uniform fit + proportion check with limited variety stretch; tooling on both ends; −Z forward / Y up enforced at model creation; 10% width margin and the no-strafe invariant for width ≤ length). Captures the caller-verified current size pipeline (mesh-derived half-length radius, forced 2r height, body scaling, wolf 3× wrapper, fox radius from `fox.blend`), the consumer audit (body radius vs reach extent) with a gating rule, the required HK-models cross-repo edits, phases with owners, acceptance criteria, risks, and open questions BQ1–BQ12 (BQ9–BQ12 added by the design pass: low-wide capsule, hit extent shape, front overhang, nav class key). |
| 2026-10-01 | User answered BQ1–BQ12; recorded as **B6–B17** (BQn → B(n+5)), with answer blocks replacing the `<<Question>>` markers. B6 game units (~4 / m), HK-models exports 1 Blender unit = 1 game unit, post-landing cleanup §5.1; B7 whole-mesh neutral rest-pose AABB; B8 warn > 10% / fail > 20%, ±10% bone-chain variety with Visual fallback, one shared spec; B9 archetype `.tres` is truth, tool both directions; B10 ground-contact / AABB-XZ-centred pivot plus existing-model review; B11 `creature_size = max(L, W, H)`; B12 both tools + PROJECT_DOC_INDEX outside-repo rows; B13 design-intent dimensions, all current models placeholders with a per-axis fit and warn-only exemption (`placeholder_model` proposal), fox archetype, wolf wrapper removed; B14 capsule height clamp to 2r; B15 scalar reach, no oriented hit shape; B16 overhang accepted; B17 nav class = smallest satisfying max radius and max `creature_size` (answers NAVIGATION_PASSABILITY Q12, cross-link only). Updated header, §1, §2.1, §2.4, new §2.5, §3 (M4, M7, new M9 / M10, S1–S4, N1), §4.1–4.6 (new §4.6 c), §4.8–4.10, §5 (+ §5.1), §6, §7, §8, §9, §11 (CREATURE_3D_ARCHITECTURE §4 sync + body-scale drift). Extended the capsule-height `<<Comment>>`. Added follow-up questions BQ13 (shared spec location, pivot tolerance, `width_margin` home), BQ14 (placeholder flag location, placeholder pivot), BQ15 (initial dimension values), BQ16 (fate of the hit `Area3D`). |
| 2026-10-02 | User answered BQ13–BQ16; recorded as **B18–B21**. B18 shared tolerance JSON at `tools/body_dimension_spec.json` (read by relative path from HK-models), `width_margin` in `game_config.json`; B19 placeholder flag in `pack_resources.json` only on deviation (default production), placeholder mount re-centres the origin; B20 rabbit 1.7 / 0.7 / 1.4, fox 2.0 / 0.4 / 0.9, wolf 6.0 / 1.3 / 3.0 with radii 0.39 / 0.22 / 0.72; B21 `MobHitbox` left to the template cleanup at 1.15 × the new radius (code check: no predation consumer after D11). All forward references to BQ13–BQ16 replaced; `<<Question>>` markers removed; status line updated (all BQ1–BQ16 answered). |
| 2026-10-02 | Wording tidy: removed stale "180°" override language (§4.8 pack row, §4.8.1 phasing, §8 forward-axis risk) to match the Phase 0 finding that all three placeholders are X-long; net override is a per-model ±90° yaw, sign pending a visual check, reconciled with template Visual yaw offsets (not stacked). |
| 2026-10-02 | Recorded **B22** (user, in conversation): forward axis switches from −Z to **+Z** (Godot `MODEL_FRONT`; Blender nose along −Y, Blender's default), because Blender's glTF export maps Blender +Y to Godot −Z so a −Z convention would oppose Blender's default facing. B4 marked superseded (text kept). Updated header, §2.1 facing-offset row, §3 S4 and M-table `body_length` row, §4.6 (tool forward-axis check, Blender checklist), §4.8 (pack override row; new rows for `motor_plane.gd` / `creature_kinematic_body_3d.gd` facing math, kinematic templates, test round-trip), new §4.8.1 (facing-math work item with locations and the semantic-forward audit list; no code changed), §4.9 item 1, §5 Phase 3, §7 (new checkbox), §8 (new risk). |
| 2026-10-02 | Recorded **B24** and **B25** (user, in conversation). B24: capsule height uses Godot 4 total-height semantics, `max(live_height, 2r)`; code read showed `creature_mesh_footprint.gd` 57–61 feeds a Godot-3-style `sy − 2r` into a body that already uses total height; the §4.2 `<<Comment>>` resolved and B14 reconciled. B25: reach = `live_length × (0.5 + reach_margin_fraction)` (default 0.25: rabbit 1.275, fox 1.5, wolf 4.5), optional absolute-distance `reach_override` on `CreatureDefinition`, config key + facade; B15's reach value superseded. Updated header, §2.1 / §2.3, §4.2 (table, accessor text), §4.7 (full audit: choke own-diameter, both `creature_motor_stack.gd` rows, kinematic ghost-fit / eye height classified; **flee threat capsule reclassified from reach extent to body radius**; pre-change values; new eat-gate target-side `<<Question>>`), §4.8 (rows incl. `reach_override`, config keys), §4.8.1 (line numbers re-verified, `motor_plane.gd` 59 default and template values added), §5 Phase 1 and config row, §6 (B14 / B15 notes, B24, B25), §7, §8, §9. |
| 2026-10-02 | **Phase 0 built and run** (tool + spec, 62d372d). Recorded the placeholder measurement reports in new §2.1.1 (not the species spec, B13): fox mesh == wolf mesh; all three models X-long so Phase 3 needs a per-model ±90° net override reconciled with the existing template offsets (herbivore π/2, carnivore 3π/2), sign pending a visual check; no model meets the B10 pivot; placeholder re-centre must also fix Y; per-axis fit essential (widths +121% to +228%); wrapper half-extent check confirms the §2.1 diagnosis. Updated §4.8.1 ("Atomic with model forward"), §5 Phase 0 (status built; design-intent table and placeholder flag hard-coded until Phase 1 / 2) and Phase 3, §7 forward-axis checkbox. |
| 2026-10-02 | Recorded **B23** (user): all hard-coded forward fallbacks retarget to one constant `MotorPlane.MODEL_FORWARD` (value +Z); `HORIZONTAL_FORWARD` retired; `yaw_from_horizontal_dir` derives from it; memory-file compass bearings stay world bearings. Resolved the §4.8.1 "decision needed at implementation"; added the "Single forward constant (B23)" block with the recommended two-step phasing (behavior-preserving at −Z, then flip). Updated §4.8 rows (new fallback-retarget row, motor_plane row, tests row), §5 Phase 3, §7 forward-axis checkbox, §8 risk. |
| 2026-10-05 | Recorded **B26** and the facing-check finding (user observation + Godot verification; **docs only, no code done**). `yaw_from_horizontal_dir = atan2(d.x, -d.z)` is mirrored left / right for the Visual (correct only for ±Z), which is why the awareness cone and the model disagree in live play; the existing round-trip test uses the same formula and could not catch it. Corrected B23 / §4.8.1: the derivation does **not** reproduce today's formula at −Z for X components, it fixes the mirror. Added the facing-check results to §2.1.1 (finding 7; both templates need 3π/2 under +Z; replaces the earlier "move by π" expectation in finding 2 and the "Atomic" paragraph). Reprioritised Phase 3 (highest priority, may ship before Phases 1 / 2; §5 row and ordering note). Updated §4.8 rows (motor_plane, templates, tests), §4.8.1 phasing, §6 (B26, B23 correction), §7 (new checkbox, forward-axis checkbox), §8 (new risk), §9 (engine-rotation test, manual facing check), header. |
| 2026-10-05 | **Phase 3 shipped** (bfcbd26; user confirmed in play: facing corrected, awareness cone turns with the body). Synced: `MotorPlane.MODEL_FORWARD = Vector3(0, 0, 1)` replaces `HORIZONTAL_FORWARD`; `yaw_from_horizontal_dir` = `wrapf(atan2(d.x, d.z) − atan2(F.x, F.z), −PI, PI)`; both kinematic templates `visual_yaw_offset_rad` 3π/2; fallbacks retargeted; `_test_motor_plane_yaw_from_facing` uses `Basis(UP, yaw) * MODEL_FORWARD`; `tools/facing_check_3d.tscn`. Status line, §4.8 rows, §4.8.1 shipped banner, §5 Phase 3 (`done`), §6 B26, §7 (mirrored-yaw and forward-axis boxes ticked). CREATURE_3D_ARCHITECTURE §4 synced separately. Also fixed this changelog's row order (B23 row now precedes the 2026-10-05 row). |
| 2026-10-05 | Recorded **B27** (user): eat-gate target side = target **body radius** (option a); eater term = reach extent (B25). Replaced the §4.7 `<<Question>>` with an answer block (illustrative gates wolf→rabbit 9.9, fox→rabbit 6.9, rabbit→plant 6.3; rabbit live mesh-derived radius vs archetype 0.6 caveat; retune expectation). Updated header, §4.7 eat row and reach paragraph, §4.8 motor_planner row, §5 Phase 1, §7 (Question box ticked, new implementation box, comparison box), §8 reach risk. |
