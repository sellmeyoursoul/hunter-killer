# Hunter Killer — Creature body dimensions plan

> **Status:** `design` (draft, 2026-10-02). **No code.** All questions BQ1–BQ16 are answered (BQ1–BQ12 on 2026-10-01 as B6–B17; BQ13–BQ16 on 2026-10-02 as B18–B21). The only marker left is the capsule-height `<<Comment>>` in §4.2 (verify Godot 4 semantics).
>
> **Origin.** Split out of [NAVIGATION_PASSABILITY_PLAN.md](NAVIGATION_PASSABILITY_PLAN.md) Q10 (path radius: enclosing capsule or body width?) on 2026-10-01. That plan's Q10 and Q12 now wait on this doc. The user wants this doc settled before work returns to the navigation plan.
>
> **Decisions 2026-10-01 (user, in conversation; §6 B1–B5).** Authored length / width / height are canonical and the model conforms (B1). Models are scaled uniformly at mount, with a proportion check and a limited allowance for variety stretch (B2). Tooling exists on both ends: a measuring / proposal tool in the game, and dimension-driven generation in the art pipeline (B3). The facing convention is −Z forward, Y up, enforced when the model is created (B4). The movement radius is width / 2 × 1.10, and creatures whose width ≤ length never strafe (B5).
>
> **Decisions 2026-10-01 (user, answers to BQ1–BQ12 in §10; §6 B6–B17).** Dimensions are in game units with one documented factor (~4 units per real metre, estimate), no world rescale; HK-models exports 1 Blender unit = 1 game unit (B6, with a post-landing cleanup item). Dimensions measure the whole-mesh AABB in the neutral rest pose (B7). Proportion check warns > 10% and fails > 20% per axis; variety stretch ±10% per axis via bone-chain scaling with a Visual-scale fallback; one shared tolerance spec (B8, pre-tuning baseline). The archetype `.tres` is the source of truth and the tool works in both directions (B9). Origin at ground contact, centred on the rest-pose AABB XZ footprint, with an existing-model review (B10). `creature_size = max(L, W, H)` on live dimensions (B11). A headless game tool plus a Blender checklist share one definition (B12). Dimensions come from design intent; all current models are placeholders, fitted non-uniformly and exempt from proportion failure; a fox archetype is added and the wolf 3× wrapper removed (B13). Low bodies clamp capsule height up to 2r (B14). Reach is a scalar with no oriented hit shape (B15). Nose / tail overhang is accepted for now (B16). Nav class membership declares both max radius and max `creature_size` (B17).
>
> **Decisions 2026-10-02 (user, answers to BQ13–BQ16 in §10; §6 B18–B21).** One shared tolerance JSON in this repo (`tools/`), read by the Blender checklist by relative path and by the game tool; `width_margin` lives in `game_config.json` (B18). The placeholder flag lives in a pack's `pack_resources.json`, only where a model deviates from the production default; placeholder mounts auto re-centre the origin (B19). Design-intent dimensions: rabbit 1.7 / 0.7 / 1.4, fox 2.0 / 0.4 / 0.9, wolf 6.0 / 1.3 / 3.0 (B20). The old hit `Area3D` stays untouched until the template cleanup (B21).
>
> **Sourcing.** The code facts in §2 were verified by the caller on 2026-10-01 and are marked "caller-verified" with approximate line numbers. This design pass did not re-read code. Facts about the art pipeline come from the caller's reading of `../HK-models/3d_modeling_v1.md`, a sibling folder **outside this repo** that is not a git repo. This doc does not edit that file; §4.9 lists the edits it needs.

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
| Footprint from mesh | `creature/capabilities/creature_mesh_footprint.gd` ~57–61 | `radius = max(sx, sz) * 0.5`, which is half the **longer** horizontal AABB extent (nose to tail for quadrupeds). `height = sy - 2r`, clamped to ≥ `2r + 0.05`. |
| Apply to body | `creature_kinematic_body_3d.gd` `apply_capsule_footprint_from_visual` ~205, called from `creature/creature_root_3d.gd` ~149 | Applies a **0.92 inset** to the radius. |
| Hit capsule | `creature_kinematic_body_3d.gd` ~233 | Radius = **1.15 ×** body radius. |
| Runtime size change | `creature_kinematic_body_3d.gd` ~223 | `scale = Vector3.ONE * factor` on the **`CharacterBody3D` itself**. Godot discourages scaling physics bodies. |
| Facing offset | `creature_kinematic_body_3d.gd` ~28 | Extra Visual Y rotation for meshes whose forward is not −Z (`visual_yaw_offset_rad` per [CREATURE_3D_ARCHITECTURE §4](../Definitive_Features/CREATURE_3D_ARCHITECTURE.md)). The capsule stays axis-aligned (~719). |
| Authored fallbacks | `creature/definition/creature_definition.gd` ~31–32 | `creature_size`, `collision_capsule_radius` (and height). Used **only** when no visual is mounted. |

**Archetypes on disk:** only `creature/species/rabbit_archetype.tres` (size 1.7 / radius 0.6 / height 2.0) and `wolf_archetype.tres` (6.0 / 7.0 / 15.3). The fox has a pack (`assets/creatures/fox/`) but **no archetype**. Its live radius of 2.343 comes from the AABB of `fox.blend` through the same formula. This answers NAVIGATION_PASSABILITY §3.1's comment on where the fox radius comes from.

**All current rabbit / fox / wolf models are temporary placeholders** (user, 2026-10-01, B13). They will be replaced once the HK-models pipeline is resolved. Phase 0 measurements of these models (recorded here when taken) are **reports** on the placeholders, not the source of the species dimensions; those come from design intent (B13).

**Wolf wrapper:** `wolf_3d.tscn` wraps the shared placeholder `wolf.blend` mesh in a **3× scale plus a pivot-compensation translation** (tests in `tests/run_all.gd` ~962–1010). `creature_root_3d.gd` `_SPECIES_MESH_FILE` maps `&"wolf"` to `wolf_3d.tscn` ([PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md) wolf slice). This is an art workaround that makes the derived capsule come out right.

**Consequence.** Every creature is an upright cylinder with radius ≈ half its body length, and its height is forced to ≥ 2r. That is why the wolf capsule is ~15.3 m tall, and why NAVIGATION_PASSABILITY erodes its whole navmesh by 7.25 m.

### 2.2 Facing and locomotion (caller-verified 2026-10-01)

- V3 `creature/motor/locomotion_executor.gd` already moves the body **only along ±facing**: `_displace_along_facing` (~52 / 54) and blended turn + move (~117–131). The default `move_turn_rate_deg_per_sec` is 1350. **V3 has no strafing today.**
- The capsule does not rotate, so it does not model the sweep of a long body turning (§4.5).

### 2.3 Consumers that add capsule radius to distances (caller-verified 2026-10-01; full audit in §4.7)

`motor_planner.gd` eat reach bonus (~4236–4240), own diameter (~4029), `_agent_radius` (~4654). `flee_candidate_scoring.gd` threat capsule (~43–58). `creature_motor_stack.gd` ~350 and ~1553. From docs (not re-read): shelter fit and choke credit ([PHYSICS_SQUEEZE.md](PHYSICS_SQUEEZE.md)), C1 contact geometry ([CREATURE_MOVEMENT_V3_CLEANUP.md C1](CREATURE_MOVEMENT_V3_CLEANUP.md#c1--pursuit-contact-geometry-stall-fox)), the navmesh `agent_radius` (NAVIGATION_PASSABILITY §2.1), and the ghost-fit clamp / `RoutePlausibilityScan`, which sweep the body capsule.

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
- **S4.** The facing and pivot conventions are enforced at model export (B4, B10). The Visual yaw offset becomes a legacy override.

### Nice to have
- **N1.** *(Promoted to M7 by B9: model-first dimension proposals.)*
- **N2.** A debug overlay draws the movement capsule, the reach extent and the rest-pose AABB side by side.

---

## 4. Technical design

### 4.1 Data model (B1)

| Field | Authored? | Meaning |
|---|---|---|
| `body_length` | yes | Extent along the facing axis (−Z) of the whole-mesh AABB in the neutral rest pose, tail included (B7). Game units (B6). |
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
| **Capsule height** | `max(live_height, 2 × body_radius)` (B14: low / wide bodies clamp **up** to 2r and the clamp is logged; revisit after seeing it in practice). Assumes total-height semantics (comment below). | Collision height, navmesh class `agent_height` |
| **Reach extent** | `live_length / 2` from the body centre along facing, a **scalar** (B15) | Eat reach, contact geometry, threat proximity (§4.7). Consumers compare centre distance against it numerically. |
| **Hit extent** | **No separate oriented hit shape** (B15). Reach is the scalar above. The legacy axis-aligned `MobHitbox` `Area3D` is left to the template cleanup (B21); until then it is 1.15 × the new body radius, with no new logic. | Hitbox `Area3D` overlaps, if any remain |
| `creature_size` | `max(live_length, live_width, live_height)` (B11) | `fit_size` compares (NAVIGATION_PASSABILITY D5), `stat_fit`, env slowdown, nav class membership (B17) |

Proposed accessors (names are proposals): `get_body_radius()`, `get_reach_extent()`, `get_body_dimensions()`. `get_collision_capsule_radius()` is retired or kept only as an alias of `get_body_radius()`; its current ambiguity is the reason for the audit in §4.7.

<<Comment: In Godot 4, `CapsuleShape3D.height` is the total height including both hemispheres and must be ≥ 2 × radius (verify against the 4.7 docs). The current `sy - 2r` formula in `creature_mesh_footprint.gd` looks like Godot 3 cylinder-section semantics. Confirm which semantics the code relies on before writing the derivation. Addendum (caller, 2026-10-01): Godot 4 `CapsuleShape3D.height` is believed to be the total height (caps included). If so, today's `height = sy − 2r` makes tall creatures' capsules **shorter** than the model (not taller), and long, low bodies are then clamped up to 2r by the `≥ 2r + 0.05` floor. Verify against the 4.7 docs. This is superseded by the B1 shapes anyway: the §4.2 height formula assumes total-height semantics.>>

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
- The forward axis it detects or assumes (B4), with a warning if the model looks rotated.
- Implied dimensions after uniform scaling to the given dimension.
- The ratio check against the archetype (per-axis percentage) with pass / warn (> 10%) / fail (> 20%) from the shared spec (B8). A model flagged placeholder in its pack's `pack_resources.json` (B13, B19) reports warn instead of fail.
- Model-first direction (B9): a proposed `body_length / width / height` block to paste into a new archetype.
- Exit code non-zero on any production-model fail.

**(b) Art-side dimension-driven generation** (external, HK-models):
- **Stage 1:** copy the species L / W / H from the game archetype `.tres` (source of truth, B9) into the HK-models subject spec.
- **Stage 2:** pass that ratio as Rodin `bbox_condition` so the generated model starts at the right proportions. Hunyuan3D has no bbox parameter, so a fallback model must be rescaled or fixed in Stage 3.
- **Stages 3 / 6:** run a Blender `execute_blender_code` checklist that checks the ratio, facing (−Z forward, Y up), pivot (B10) and units (1 Blender unit = 1 game unit, B6) before export, using the **same** ratio / tolerance definition as tool (a) (B12): the Blender script reads `tools/body_dimension_spec.json` by relative path (sibling folders `HK-models` / `hunter-killer`, e.g. `../hunter-killer/tools/body_dimension_spec.json`), so there is one copy (B18).

**(c) Existing-model review (B10 work item).** Run tool (a) over every current creature model and record pivot / facing / ratio results in §2.1. Non-conforming models are corrected, except where the model is a placeholder being replaced (moot to fix, but the tool must still report it).

### 4.7 Consumer audit: body radius vs reach extent (required work, owner creature-motor)

Moving the radius from about half the length to about half the width roughly **halves or thirds** every number that adds the capsule radius today. Each consumer needs the right one of the two values. The classifications below are proposals; each must be confirmed by reading the code.

| Consumer (from §2.3) | Proposed class | Reasoning |
|---|---|---|
| Eat reach bonus, `motor_planner.gd` ~4236–4240 | **reach extent** | The mouth is at the front of the body. With the body radius, eat reach would shrink sharply and break decision 26 tuning. |
| Flee threat capsule, `flee_candidate_scoring.gd` ~43–58 | **reach extent** of the threat | The danger zone is how far the threat's front reaches, not its side clearance. |
| Own diameter, `motor_planner.gd` ~4029 | **body radius** × 2 if it is a gap-fit check | Gap fit is about the swept width. <<Comment: confirm what ~4029 measures before classifying.>> |
| `_agent_radius`, `motor_planner.gd` ~4654 | **body radius** | Navmesh / path clearance. |
| `creature_motor_stack.gd` ~350, ~1553 | unknown | <<Comment: read and classify.>> |
| Shelter fit / choke credit (PHYSICS_SQUEEZE) | **body radius** for the width fit; the shelter **depth** check may need the length | Shelter enclosure should cover the whole body. |
| C1 contact geometry (CLEANUP C1) | predator **reach extent** + prey **body radius** | Contact means the predator's front meets the prey's side. |
| Ghost-fit clamp, `RoutePlausibilityScan`, `ShelterEnclosureProbe` | **body radius** (they sweep the movement capsule) | Automatic once the capsule is resized. |
| Navmesh `agent_radius` / class selection | **body radius** | NAVIGATION_PASSABILITY D1 / D7; answers its Q10 (§4.10). |

**Gating rule.** The capsule resize (Phase 1) and the reach-extent split for eat / threat / contact must ship in the **same change set**. Otherwise eat reach and contact distances regress the moment the radius shrinks.

### 4.8 Scene and file changes (proposed)

| Action | Path | Notes |
|---|---|---|
| modify | `creature/definition/creature_definition.gd` | Add `body_length / width / height`; remove the authored capsule fields; derive `creature_size = max(L, W, H)` on live dimensions (B11). Reads the placeholder flag from the pack's `pack_resources.json` (B19), not from the archetype. |
| modify | `creature/capabilities/creature_kinematic_body_3d.gd` | Size shapes from live dimensions (capsule height clamp B14); stop scaling the body (~223); `get_body_radius()` / scalar `get_reach_extent()` (B15); hit `Area3D` kept at 1.15 × the new body radius until the template cleanup (B21); Visual yaw offset kept as a legacy override (~28). |
| modify | `creature/capabilities/creature_mesh_footprint.gd` | Measuring only (whole-mesh rest-pose AABB, pivot, ratio check). No longer sizes collision. |
| modify | `creature/creature_root_3d.gd` | Uniform fit (production) or per-axis fit (placeholder, B13) + proportion report at mount (~149); drop `&"wolf": "wolf_3d.tscn"` from `_SPECIES_MESH_FILE` once the wrapper is gone. |
| modify | `creature/species/rabbit_archetype.tres`, `wolf_archetype.tres` | Dimensions from design intent (B13; values B20: rabbit 1.7 / 0.7 / 1.4, wolf 6.0 / 1.3 / 3.0). |
| create | `creature/species/fox_archetype.tres` | New, with design-intent dimensions (B13; B20: 2.0 / 0.4 / 0.9). |
| delete / modify | wolf pack `wolf_3d.tscn` (under `assets/creatures/`) | Remove the 3× wrapper and pivot compensation (B13). The placeholder `wolf.blend` pivot is handled by the placeholder mount re-centre (B19). |
| modify | `assets/creatures/*/pack_resources.json` | Per-pack forward override only where a legacy model can't be re-exported (B4). **Placeholder flag** (B19): present only on packs whose model deviates from the production default; added today to rabbit, fox and wolf. The default (key absent) means production-standard. Any other per-model override follows the same present-only-on-deviation rule. |
| modify | `creature/motor/motor_planner.gd`, `flee_candidate_scoring.gd`, `creature_motor_stack.gd`, `locomotion_executor.gd` | §4.7 audit; facing invariant assertion. |
| create | `tools/` measuring script (name TBD) | §4.6 (a), B12. |
| create | `tools/body_dimension_spec.json` (shared ratio / tolerance spec, B18) | Proportion thresholds (warn 10% / fail 20%), variety stretch range (±10%), origin-position tolerance (≈ 2% of length); read by tool (a) and, by relative path, the Blender checklist (B8, B12, B18). Lives under `tools/` (test-harness) because it is a check definition for tooling, not a game resource: `assets/_shared/` is the pooled game-resource area resolved via `PackResourceResolver` (assets/CLAUDE.md) and is the wrong home for it. |
| modify | `tests/run_all.gd` (~962–1010 wolf wrapper tests) | Replace wrapper tests with fit / proportion / no-body-scale / invariant / placeholder-fit tests. |
| modify | `game_config.json`, `game_config.gd` | Add `width_margin` (default 0.10) with the other motor tuning (B18); it is gameplay tuning, not an art check, so it stays out of the shared spec. |

### 4.9 Required cross-repo edit (external; caller performs — BQ1–BQ8 settled as B6–B13)

`../HK-models/3d_modeling_v1.md` needs:
1. A **facing rule** (B4): −Z forward, Y up, enforced at model creation and checked before the Stage 6 export.
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
| **0 — Measure / review** | Build tool (a) (B12), read-only, plus the shared spec file `tools/body_dimension_spec.json` (B18). Run the B10 existing-model review: measure the rabbit, fox (`fox.blend`) and wolf (`wolf.blend`, raw and wrapped) placeholders: whole-mesh rest-pose AABB, pivot offset vs convention, forward axis, ratio vs the B20 design-intent dimensions. Record the results in §2.1 as placeholder reports (not the species spec, B13). | B7, B10, B12, B18, B20 (decided) | test-harness |
| **1 — Data model + fit + shapes** | `body_length / width / height` on `CreatureDefinition`; derived `creature_size = max(L, W, H)` (B11); placeholder flag read from `pack_resources.json` (B19); `width_margin` in `game_config.json` (B18); uniform Visual fit for production models and per-axis fit plus origin re-centre for placeholders, with proportion report at mount (B8, B13, B19); shapes sized from live dimensions with the B14 height clamp; scalar reach (B15); legacy `MobHitbox` left at 1.15 × the new radius (B21); stop scaling the body; runtime size change re-derives shapes. **Same change set** as the §4.7 reach-extent split (gating rule). | B6, B7, B8, B11, B13, B14, B15, B18, B19, B21 (decided) | creature-entity (definition, mount / fit, shapes); creature-motor (§4.7 audit, reach split); test-harness |
| **2 — Migration** | Design-intent dimensions on the rabbit and wolf archetypes; new fox archetype; flag all three current models as placeholders; remove the wolf 3× wrapper and its `_SPECIES_MESH_FILE` entry (placeholder pivot via the mount re-centre, B19); per-pack forward override where needed; retune radius-based distances. | B13, B19, B20 (decided) | creature-entity (archetypes, `_SPECIES_MESH_FILE`); assets-pack (wrapper removal, pack forward override, placeholder flag in the three `pack_resources.json` files); creature-motor (retune) |
| **3 — Facing invariant** | Invariant assertion + headless test (width ≤ length → displacement parallel to facing). The Visual yaw offset becomes a documented legacy override. | B4, B5 (decided) | creature-motor; test-harness |
| **4 — Art pipeline alignment** | HK-models edits (§4.9); Blender checklist sharing the ratio / tolerance definition; Rodin `bbox_condition` feed; PROJECT_DOC_INDEX "Related (outside Project_Docs)" rows (caller routes). | B6, B8, B9, B10, B12, B18 (decided) | external (caller); project-docs (index rows) |
| **5 — Variety stretch** | Per-instance stretch of ±10% per axis, bone-chain primary with Visual-scale fallback; collision follows the instance's actual dimensions. | B8 (decided) | creature-entity; assets-pack (bone-chain rigs); test-harness |
| (config) | `width_margin` (default 0.10) in `game_config.json` / `game_config.gd` (B18). Folds into Phase 1 (the radius derivation needs it); tolerances and stretch range stay in the shared spec. | B18 (decided) | app-shell |

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
| B4 | 2026-10-01 | **Facing by convention (Godot −Z forward, Y up), enforced at model creation time** by a rule in `../HK-models/3d_modeling_v1.md`. The caller edits that file once the open decisions settle; it is recorded here as a required cross-repo edit. The existing Visual forward offset (`creature_kinematic_body_3d.gd` ~28) becomes legacy / override only. | §3 S4; §4.6; §4.9 item 1; §5 Phase 3. |
| B5 | 2026-10-01 | **Width margin starts at 10%** (radius = width / 2 × 1.10), tunable. **Facing constraint:** creatures with width ≤ length move forward / backward only (no strafing), so the width-based radius is valid because the body lines up with its travel. V3 already behaves this way; the constraint makes it an invariant with a test. *Note (not a decision):* in general the radius is half the extent perpendicular to the permitted travel axis; a crab-like creature with width > length that moves sideways would use length. *Accepted residual cost:* a long body pivoting in place (~1350°/s) swings its head and tail through obstacles visually, because the axis-aligned capsule doesn't model rotation sweep. | §3 M5; §4.2; §4.5; §7; B16. |
| B6 | 2026-10-01 | **(BQ1) Game units with one documented factor**, ~4 game units per real metre (estimate). No world rescale now. HK-models exports directly in game units (1 Blender unit = 1 game unit). **Post-landing cleanup** (after this feature and the navigation work land, not a phase gate): revisit hard-coded distances (for example the ~5-unit combat / contact distance) and move species sizes toward realistic proportions (for example rabbit and wolf length). | §1 non-goals; §2.4; §2.5; §4.9 item 3; §5.1. |
| B7 | 2026-10-01 | **(BQ2) Whole-mesh AABB in the neutral rest pose**, tail and ears included. | §4.1; §4.3 step 2; §4.6; §4.9 item 7. |
| B8 | 2026-10-01 | **(BQ3) Pre-tuning baseline tolerances:** proportion check warns > 10% and fails > 20% per axis. Per-instance variety ±10% per axis via **bone-chain scaling**, with non-uniform Visual scale as the fallback. Collision follows the instance's actual dimensions. Tolerances live in **one shared spec**. Effect of fail (tool non-zero, game still mounts) carried from the BQ3 recommendation. | §3 M4, S2, S3; §4.3 step 4; §4.4; §4.6; §4.9 item 6; §7; B18. |
| B9 | 2026-10-01 | **(BQ4) The species archetype `.tres` (`CreatureDefinition` leaf data) is the source of truth.** Consistent with Definitive CREATURE_3D_ARCHITECTURE §2 (archetype as leaf data with "collision capsule hints"). Its §4 "Size sync (M4)" text (capsule from mesh AABB; `apply_effective_creature_size` "scales mesh + capsule") must be synced by `project-docs` when this ships; note the existing drift that code scales the `CharacterBody3D` itself (~223). Dimensions are copied into the HK-models subject spec at Stage 1 and fed to Rodin `bbox_condition`. The tool works in both directions. | §3 M7, N1; §4.1; §4.6; §4.9 item 4; §11. |
| B10 | 2026-10-01 | **(BQ5) Origin at ground contact, centred on the rest-pose AABB XZ footprint.** Enforced at HK-models Stage 6, checked by the game tool. **Work item:** review existing models for this convention and correct them where not met; moot for placeholders being replaced, but the tool must report it. Pivot tolerance: B18 (≈ 2% of length). | §3 M7, S4; §4.3 step 4; §4.6 (a), (c); §4.9 item 2; §5 Phase 0; §7. |
| B11 | 2026-10-01 | **(BQ6) `creature_size = max(length, width, height)`** on live dimensions. User rationale: tall creatures (large bipeds, a giraffe, taller than long) are measured correctly. | §3 M9; §4.1; §4.2; §7. |
| B12 | 2026-10-01 | **(BQ7) Both tools:** a headless Godot tool under `tools/` (test-harness) and a Blender checklist script for HK-models Stages 3 / 6, sharing one ratio / tolerance definition. PROJECT_DOC_INDEX gets "Related (outside Project_Docs)" rows pointing at the HK-models pipeline docs so changes on either side are visible (caller routes that edit). Shared definition location: B18. | §3 M7, S2; §4.6; §4.9; §5 Phases 0, 4; §8; §11. |
| B13 | 2026-10-01 | **(BQ8) Dimensions from design intent.** All current rabbit / fox / wolf models are **temporary** and will be replaced once the HK-models pipeline is resolved. User preference: model distortion to match correct dimensions beats unrealistic dimensions to match models. **Placeholder exemption:** a flagged placeholder model (name proposal `placeholder_model`; location B19) is fitted with non-uniform scale to hit the authored dimensions, and its proportion check reports warn, never fail. Production models from the pipeline follow the normal B8 warn / fail rule. Add a fox archetype; remove the wolf 3× wrapper. Values: B20. | §2.1; §3 M4, M10; §4.3 step 3–4; §4.8; §5 Phase 2; §7; B19, B20. |
| B14 | 2026-10-01 | **(BQ9) Default: clamp capsule height up to 2r** for low / wide bodies (logged). Revisit after seeing it in practice. | §4.2; §7; §8. |
| B15 | 2026-10-01 | **(BQ10) Reach is a scalar (half length)**; no separate oriented hit shape. Fate of the existing hit `Area3D`: B21. | §4.2; §4.8; §7; B21. |
| B16 | 2026-10-01 | **(BQ11) Accept nose / tail overhang** into obstacles for now; revisit in live play. | §4.5; §4.10; §8; §9. |
| B17 | 2026-10-01 | **(BQ12) Each nav class declares a max body radius and a max `creature_size`; a creature's class is the smallest class satisfying both.** Answers NAVIGATION_PASSABILITY Q12 (cross-link only; that plan is not edited here). | §4.2; §4.10; §5. |
| B18 | 2026-10-02 | **(BQ13) One shared tolerance JSON in this repo**, `tools/body_dimension_spec.json` (path chosen by the designer pass), read by the Blender checklist by relative path (sibling folders `HK-models` / `hunter-killer`) and by the game tool. Contents: proportion thresholds (warn 10% / fail 20%), variety stretch range (±10%), origin-position tolerance (≈ 2% of length). **`width_margin`** (0.10; movement radius = W / 2 × 1.10) goes in `game_config.json` with the other motor tuning, because it is gameplay, not an art check. | §3 S2; §4.2; §4.4; §4.6; §4.8; §4.9 item 5; §5 Phases 0, 1, 4; §7; §8. |
| B19 | 2026-10-02 | **(BQ14, modified) The placeholder flag lives in the pack's `pack_resources.json`** (a property of the model, not the species), with a **default**: models are production-standard unless stated, and the flag (and any other per-model override) appears in a pack's `pack_resources.json` **only when the model deviates** from the standard. Today the three rabbit / fox / wolf models are flagged. **Placeholder mount fit auto re-centres the origin** (no re-export); production models must follow B10 with no correction. | §3 M10; §4.3 steps 3–4; §4.8; §5 Phases 1, 2; §7; §8. |
| B20 | 2026-10-02 | **(BQ15) Initial design-intent dimensions (L / W / H, game units):** rabbit 1.7 / 0.7 / 1.4 (ears up), movement radius 0.39 (was 0.6 archetype); fox 2.0 / 0.4 / 0.9, radius 0.22 (was 2.34 from the mesh); wolf 6.0 / 1.3 / 3.0, radius 0.72 (was 7.03 from the mesh). Radius = W / 2 × 1.10. Wolf radius drops about 10×, so navigation erosion and the gap-trap likely mostly disappear and the wolf may fit the small nav class. Nav class boundaries (B17) are retuned only after these land. The reach split ships in the same change set as the capsule change (§4.7 gating rule). The fox is narrower than the rabbit (realistic; noted). | §2.1; §4.8; §4.10; §5 Phases 0, 2; §7; §8. |
| B21 | 2026-10-02 | **(BQ16) The legacy hit `Area3D` (`MobHitbox`) is left to the already-planned template cleanup.** Until then it stays 1.15 × the body radius applied to the new radius, with no new logic. Code check 2026-10-02: nothing consumes it for predation (see §10 BQ16 answer). | §4.2; §4.3 step 6; §4.8; §5 Phase 1; §7. |

---

## 7. Acceptance criteria

(Agent treats unchecked items as incomplete.)

- [ ] `CreatureDefinition` exposes `body_length`, `body_width`, `body_height`. No authored capsule radius / height fields remain, and `creature_size` equals `max(live_length, live_width, live_height)`, including after a runtime size change (B11, headless; include a fixture taller than it is long).
- [ ] After mount, every creature's `CharacterBody3D.scale` is `Vector3.ONE`, including after a runtime size change (headless).
- [ ] The movement capsule radius equals `live_width / 2 × (1 + width_margin)` and its height equals `max(live_height, 2 × body_radius)` (B14), for rabbit, fox and wolf; a low / wide fixture clamps to 2r and logs it (headless).
- [ ] **Production** model: the Visual is scaled uniformly; its rest-pose length after scaling equals `live_length` within 1%.
- [ ] **Placeholder** model (B13): the Visual's rest-pose L / W / H after the per-axis fit each equal the live dimensions within 1%, and any proportion deviation is reported as a warning, never a failure (headless, game and tool).
- [ ] A production model whose W or H ratio deviates > 10% logs exactly one proportion warning per species per session; > 20% is reported as a fail by the tool; in both cases the creature still spawns with authored-dimension collision (headless, using deliberately mis-proportioned fixture models).
- [ ] Reach extent is the scalar `live_length / 2`; no oriented hit shape exists (B15). The legacy `MobHitbox` `Area3D` radius equals 1.15 × the new body radius and no new logic reads it (B21).
- [ ] `width_margin` is read from `game_config.json` (default 0.10) (B18); the shared tolerances are read from `tools/body_dimension_spec.json` by both the game tool and the Blender checklist.
- [ ] Placeholder flag: read from the pack's `pack_resources.json`; a pack without the key is treated as production (B19). The rabbit, fox and wolf packs carry the flag. A placeholder mount ends with the scaled AABB bottom-centre on the body origin (headless).
- [ ] Facing invariant: for every creature with width ≤ length, each locomotion tick's horizontal displacement is parallel to ±facing within a small angular tolerance (headless, across turn, blended turn + move and backward moves).
- [ ] Every consumer in §4.7 uses `get_body_radius()` or `get_reach_extent()`; no call site reads an ambiguous "capsule radius" (grep check).
- [ ] Eat reach, flee threat distance and C1 contact distance for rabbit / fox / wolf stay within an agreed delta of their pre-change values, or have been explicitly retuned with the change recorded (headless comparisons).
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
| **Low, wide bodies** (width × 1.1 > height) can't form a valid capsule. | B14: clamp the height up to 2r and log it. The capsule is then taller than the body (overhang clearance, navmesh `agent_height`); revisit once seen in practice. |
| **Placeholder distortion.** Per-axis fitting of placeholder models (B13) visibly distorts them, and the exemption could let a real model ship flagged as a placeholder. | Accepted by the user (distortion beats wrong dimensions). The tool still reports every placeholder's deviation; the flag is removed when a pipeline model replaces the placeholder, which re-enables the B8 fail rule. |
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
- Low / wide test: a fixture with `H < 2r` gets capsule height 2r and one log line.
- Facing invariant test (§7).
- Consumer split tests: eat reach and contact use the reach extent; path / gap checks use the body radius.
- The tool, run over every shipped creature pack, with ratio checks against its archetype.
- Replace the wolf wrapper tests (`tests/run_all.gd` ~962–1010).

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
