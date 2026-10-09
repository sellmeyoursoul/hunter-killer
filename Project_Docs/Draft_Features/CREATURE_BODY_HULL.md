# Hunter Killer — Creature body hull plan

> **Status:** `design` (draft, nothing implemented; **later phase, not navigation Phase 1**). Created 2026-10-08 from [NAVIGATION_PASSABILITY_PLAN.md](NAVIGATION_PASSABILITY_PLAN.md) §6.1 **D22, D23, D24, D25** (answers to Q14 / Q16 / Q17) and the Q17 follow-up question "own plan or a section of CREATURE_BODY_DIMENSIONS.md?" (answered here by creating this plan; the caller should resolve the marker in the navigation plan). Cross-links, does not duplicate: [CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) (B1–B29; **B14 / B24 are refined by D25**).
>
> **Authority note.** D22–D25 are the source of truth for the decisions in §3; this plan only sequences and specifies them. Where this doc and the navigation plan disagree, the navigation plan's decision rows win until a maintainer reconciles.
>
> **Status vocabulary** for §7 items: `open`, `design`, `ready`, `in_progress`, `done`, `wont_fix`, `watch`, `pending_recurrence` ([Project_Docs/CLAUDE.md](../CLAUDE.md)).

---

## 1. Phase summary

**Phase name:** Creature body hull (one body shape shared by collision, fit gate and footprint).

**One-line objective:** Introduce a body-hull abstraction so the collision body, the navigation gate / shape-cast hull (oriented per D24, true height per D22 / D23) and the environment / awareness footprint all read the same description of a creature's shape, instead of each assuming an upright `CapsuleShape3D`.

**Why (D22 / D24 / D25 in one paragraph).** The user wants shapes "as close to the model as possible": a giraffe tall, long and thin; a spider short, long and wide (D22). Fit must therefore use height and an oriented footprint (D23, D24). Today every species is an upright capsule, and a capsule cannot be shorter than its diameter, so a short-wide body would be taller than its model and fail low lintels it should pass (Q17). The rejected shortcut, "gate uses true height, body stays a clamped capsule", lets the gate admit a route the physical body cannot take (the wedge class), so the **same hull** must feed body and gate (D25).

**Out of scope (explicit non-goals):**
- Navmesh class boundaries, baking, the exact-fit re-plan mechanism ([NAVIGATION_PASSABILITY_PLAN.md](NAVIGATION_PASSABILITY_PLAN.md) §5.10, D23). This plan only supplies the hull those consume.
- Baked class maps stay **circular and permissive** (D24). No per-orientation bakes.
- Authoring dimensions (`body_length / width / height`), the fit / mount flow and variety stretch ([CREATURE_BODY_DIMENSIONS.md](CREATURE_BODY_DIMENSIONS.md) §4.1–4.4). Unchanged.
- Authoring or art for the first flat species (spider-like). This plan defines when it triggers the non-capsule hull, not the species.
- Hit / kill semantics (contact hitboxes stay removed; B15 / B21).
- Changing any current species' collision behaviour in the first phases: rabbit, fox, wolf stay capsules with identical numbers.

---

## 2. Context for agents

**Repo / project root:** `hunter-killer/`
**Engine & version:** Godot 4.6 per project memory (CREATURE_BODY_DIMENSIONS §2 and the navigation plan say 4.7; verify at implementation). GDScript.
**Main scenes / entry:** creature mount [`creature/creature_root_3d.gd`](../../creature/creature_root_3d.gd); body [`creature/capabilities/creature_kinematic_body_3d.gd`](../../creature/capabilities/creature_kinematic_body_3d.gd); headless tests `tests/run_all.gd`.

### 2.1 Current state (verified by read-only grep 2026-10-08)

- **All species are `CapsuleShape3D`.** Live bodies (B20 dimensions): rabbit r 0.385 / h 1.4, fox r 0.22 / h 0.9, wolf r 0.715 / h 3.0. All have `H >= 2r`, so the clamp has never changed a capsule.
- **The clamp is a shape-construction limit, not a bake-time one.** Godot clamps `CapsuleShape3D.height` to `>= 2r` at runtime. `creature/capabilities/creature_body_dimensions.gd` (`capsule_height`, `capsule_height_clamped`) implements `max(live_height, 2r)` (B24 / B14) and the kinematic body logs one line when it binds (`creature_kinematic_body_3d.gd` ~322–324).
- **Bake `agent_height` uses the unclamped / lower-bound height** (D25, D23 permissive proposer). Class numbers are blocked on spike T0c, not on this plan.
- **Clamp and its log line stay** until a flat body is authored (D25).
- **Seams already abstracted.** `get_body_radius()` and `get_collision_capsule_height()` on the kinematic body are the de facto hull interface, and `creature/capabilities/passability_profile.gd` packs `radius` / `height` for the router. Most motor consumers go through those two accessors, which makes the migration mostly an accessor-semantics change (see §4.2).

### 2.2 Capsule-assuming consumers (read-only grep, 2026-10-08; paths are the later-phase follow-up list)

Includes and extends the D25 / Q17 follow-up table (kinematic body, ghost-fit, LoS eye height, reach, `creature_mesh_footprint.gd`).

| Consumer | Path | Capsule assumption |
|---|---|---|
| Body shape construction | `creature/capabilities/creature_kinematic_body_3d.gd` (~342 body capsule, ~350 hit capsule, 243–312 accessors) | Builds `CapsuleShape3D` with `max(live_height, 2r)`; hit capsule 1.15 × radius (legacy, B21) |
| Dimension helpers | `creature/capabilities/creature_body_dimensions.gd` | `capsule_height`, `capsule_height_clamped` |
| Authored fields | `creature/definition/creature_definition.gd` (~33–48) | `collision_capsule_radius / height` retained as legacy fallbacks (CREATURE_BODY_DIMENSIONS §4.1 says removed from authored use) |
| Mesh measuring | `creature/capabilities/creature_mesh_footprint.gd` | Radius / height style output for a capsule |
| Passability profile | `creature/capabilities/passability_profile.gd` (~22, 46–47) | `radius` + `height` pair via `get_body_radius` / `get_collision_capsule_height` |
| Playfield clamp | `creature/capabilities/playfield_clamp.gd`, `environment/playfield_bounds_3d.gd` (~116, ~200–208) | Reads `CapsuleShape3D` radius / total height for edge clearance |
| Motor-plane footprint | `creature/motor/motor_plane.gd` (`footprint_half_extents`, ~138–190) | Reads `CapsuleShape3D.radius`; both axes equal (circle) |
| Ghost-fit / ghost query | `creature/motor/ghost_obstacle_query.gd` (~39, 76, 142) | `CapsuleShape3D.new()` casts / overlaps |
| Route scan | `creature/motor/route_plausibility_scan.gd` | `sweep_capsule_along_segment`, `capsule_overlaps_ghost_layer`, capsule-centre offset |
| Shelter fit | `creature/motor/shelter_enclosure_probe.gd` (~54) | `CapsuleShape3D` overlap shape |
| Choke points | `creature/motor/choke_point_probe.gd`, `choke_point_tracker.gd` | Capsule-centre ray origin offset; width from radius |
| Path / waypoint / router | `creature/motor/motor_path_clear.gd`, `motor_waypoint_chain.gd`, `nav_router.gd`, `creature_motor_stack.gd` (~355, ~1585–1586) | Capsule-centre vs ground-path offset ("tall capsule" fixes); radius + height passed to nav |
| Flee scoring | `creature/motor/flee_candidate_scoring.gd` (~38–67) | `threat_capsule_radius / height` of the threat |
| Motor planner | `creature/motor/motor_planner.gd` (~3472, ~4046, ~4244–4263, ~4721–4730) | Own / threat diameters, eat-gate target radius (B29), agent radius / height |
| Env / awareness footprint | `environment/environment_footprint_sampler.gd` (`overlapping_cell_layers`, `merged_env_at_footprint`) | Takes a single `footprint_radius` (circle) |
| Test fixtures | `tests/run_all.gd`, `tests/_tmp_creature_capsule_probe.gd` | Assert capsule numbers |

`AI_int_lib/perception_sampling.gd` and `main_3d.gd` also mention capsules; **not yet classified** (see HQ7, §9).

---

## 3. Requirements

### Must have
- **M1 (D25).** A body-hull abstraction describes a creature's physical shape once, from the live dimensions, and is consumed by (a) the collision body, (b) the gate / shape-cast, (c) the environment / awareness footprint.
- **M2 (D25).** Capsule hull is the default for tall bodies (`H >= 2r`; all three current species). Rabbit / fox / wolf produce byte-identical shape numbers before and after the abstraction lands.
- **M3 (D25).** Flat / short-wide bodies (`H < 2r`) use a non-capsule hull (box or low cylinder), authored when the first such species arrives; for them the `max(live_height, 2r)` clamp does not apply. For capsule hulls the clamp and its existing log line stay.
- **M4 (D25).** The gate and the physical body use the **same** hull. "Gate true height, body clamped capsule" is rejected (wedge class: gate passes, body wedges).
- **M5 (D24).** The gate / shape-cast hull is **oriented** (it follows the creature's facing / candidate heading); baked class maps stay circular.
- **M6 (D22 / D23).** The gate uses the creature's true height. Bake `agent_height` stays an unclamped, permissive proposer value independent of the hull kind.
- **M7.** The `CharacterBody3D` is never scaled; the hull is rebuilt from live dimensions on body setup and on live-dimension change (B1 / M3 / M8 of CREATURE_BODY_DIMENSIONS).

### Should have
- **S1.** Eye height defined from the model / hull height, not the clamped capsule (D25 follow-up).
- **S2.** Reach (B25) re-checked against the oriented hull's extent (D25 follow-up).
- **S3.** `creature_mesh_footprint.gd` emits hull parameters (extents, orientation) rather than capsule-only values (D25 follow-up).

### Nice to have
- **N1.** Debug overlay draws the hull next to reach and the rest-pose AABB (extends CREATURE_BODY_DIMENSIONS N2).

---

## 4. Technical design

### 4.1 Hull kinds

| Kind | When | Shape | Parameters | Clamp |
|---|---|---|---|---|
| `capsule` | `live_height >= 2 × body_radius` (all current species) | `CapsuleShape3D` | radius, total height | `max(live_height, 2r)` at construction (unchanged); log line stays |
| `flat` (box or low cylinder) | `live_height < 2 × body_radius`, authored with the first flat species | `BoxShape3D` or `CylinderShape3D` | half-extents (W/2, H/2, L/2) or radius + height | None: true height honoured |

<<Question: HQ1 — Box or low cylinder for the first flat hull? A box models a long, wide spider footprint and works with the oriented hull (D24) naturally; a cylinder is rotation-symmetric (cheaper, no heading dependence) but is a circle again, which loses the "long" in "short, long, wide". Which is the default, or is it chosen per species?>>

<<Question: HQ2 — Does the kind get chosen automatically by the rule `H < 2r` (derived), or declared explicitly per species (authored `hull_kind`) so a tall-but-long creature could still pick a box? D25 words it as the first flat species "gets" a non-capsule hull, which reads as either.>>

### 4.2 Interface sketch (names are proposals)

One value-type description, built from live dimensions, read by three consumers. Illustrative signatures only:

- `BodyHull` (RefCounted or small Resource): `kind`, `radius`, `half_extents` (Vector3), `height`, `centre_offset_y` (the existing capsule-centre convention generalised), `build_physics_shape() -> Shape3D`, `build_cast_shape(heading: float) -> Shape3D`, `footprint_half_extents(heading: float) -> Vector2`, `footprint_radius_conservative() -> float`, `eye_height() -> float`.
- Owner: the kinematic body holds the hull and rebuilds it on live-dimension change; `get_body_hull()` is the new accessor. `get_body_radius()` and `get_collision_capsule_height()` stay as **compatibility accessors** derived from the hull (for a capsule they return today's numbers) so unmigrated consumers keep working through the rollout.

What each of the three consumers needs:

| Consumer | Needs from the hull | Notes |
|---|---|---|
| (a) Collision body | A `Shape3D` for the `CollisionShape3D`, rebuilt on live-dimension change; the Y offset of its centre relative to the feet | Must equal the gate's shape (M4). Capsule: unchanged. |
| (b) Gate / shape-cast (ghost-fit, route scan, shelter fit, choke width) | A `Shape3D` for cast / overlap, **oriented to a heading**, true height; the centre offset for ground-path points | Per-step ghost-fit uses the current facing; route scan uses the segment direction (D24: may fail a gap sideways, pass head-on). Capsule hull ignores heading. |
| (c) Environment / awareness footprint | A planar footprint: a conservative circle radius for cell sampling (`overlapping_cell_layers`), optionally half-extents + heading for an oriented footprint; plus playfield-clamp half-extents | Today a single `footprint_radius` circle (`environment_footprint_sampler.gd`, `motor_plane.gd`). |

<<Question: HQ3 — Orientation handling for the oriented gate hull (D24): (a) cast with the shape rotated to the segment direction per route-scan segment, (b) cast at the creature's current facing only and rely on re-plan when the turn changes fit, or (c) test both axis-aligned extents (head-on and sideways) as a cheaper conservative pair. D24 says the hull is oriented but not how the cast is oriented relative to path direction versus facing. The body's facing already follows the path (V3 moves only along ±facing, B5), so (a) and (b) coincide for creatures with `W <= L`; the choice matters for the planned-but-not-yet-turned case.>>

<<Question: HQ4 — For an oriented non-capsule **physics body**, does the `CollisionShape3D` rotate with facing, or stay axis-aligned (CREATURE_BODY_DIMENSIONS §4.5 says the capsule does not rotate, and only the Visual yaws)? Today the capsule is rotation-symmetric so the question never arose (CREATURE_BODY_DIMENSIONS §4.5: "capsule stays axis-aligned"). A box physics shape that does not rotate recreates the mismatch D24 is meant to remove; one that does rotate needs `move_and_slide` behaviour checked while turning at ~1350 deg/s.>>

### 4.3 Capsule radius-shrink verification (D25, open at implementation)

D25 says "Godot may shrink the radius" when height is below 2r. **Verify in Godot 4.6** before implementation: set `CapsuleShape3D.height < 2 × radius` and read back `radius` and `height` (and the same through `PhysicsServer3D`). Record the result here as verified with a date. Two outcomes: (1) height is clamped up (radius kept), which matches today's `capsule_height()`; (2) radius is shrunk instead, which would silently change the body radius used by every consumer and must be guarded against in `creature_body_dimensions.gd`. Either way the capsule-hull path keeps the explicit clamp so behaviour does not depend on engine order of operations.

### 4.4 Ownership across domains

| Domain | Owns | Notes |
|---|---|---|
| `creature-entity` | `BodyHull` type, accessors on the body (`get_body_hull`), `creature_body_dimensions.gd`, `creature_mesh_footprint.gd`, `CreatureDefinition` hull data (HQ5), `passability_profile.gd` | Per routing table, `creature/capabilities/` and `creature/definition/` are creature-entity |
| `creature-motor` | Migrating `creature/motor/*` consumers (ghost-fit, route scan, shelter, choke, planner, flee scoring) to read the hull | Behaviour must match for capsule hulls |
| `environment-world` | `environment/environment_footprint_sampler.gd` and `playfield_bounds_3d.gd` footprint inputs | Receives a radius / half-extents, never reads a hull type directly (keeps environment decoupled from creature internals) |
| nav (navigation plan T-tasks) | Consuming the oriented hull in the gate / re-plan | Defined in NAVIGATION_PASSABILITY §5.10 and §8.2.8 |
| `test-harness` | Equivalence, wedge and orientation tests (§8) | |
| `project-docs` | Contract sync after shipping (usage-map rows, B14 / B24 note) | Flag at ship time; this designer does not edit definitive docs |

<<Question: HQ5 — Where does hull-kind data live? Options: (a) on `CreatureDefinition` (archetype `.tres`) next to `body_length / width / body_height`, since it is species shape data; (b) on the locomotion profile (`LocomotionProfile`) because it is tied to movement / passability; (c) derived only, with no authored field (see HQ2). CREATURE_BODY_DIMENSIONS B9 already makes the archetype `.tres` the source of truth for body numbers, which favours (a); (b) avoids growing the definition if the hull is seen as a locomotion property.>>

### 4.5 Scene & file changes (planned; none made)

| Action | Path | Notes |
|---|---|---|
| create | `creature/capabilities/body_hull.gd` | Hull description + shape builders (name is a proposal) |
| modify | `creature/capabilities/creature_body_dimensions.gd` | Hull-kind selection; clamp applies to capsule only |
| modify | `creature/capabilities/creature_kinematic_body_3d.gd` | Build physics shape from hull; `get_body_hull()`; keep compat accessors |
| modify | `creature/capabilities/creature_mesh_footprint.gd` | Emit hull parameters (S3) |
| modify | `creature/capabilities/passability_profile.gd` | Carry the hull (or cast-shape factory) for the router / scan |
| modify | `creature/motor/ghost_obstacle_query.gd`, `route_plausibility_scan.gd`, `shelter_enclosure_probe.gd`, `choke_point_*.gd` | Cast / overlap with `build_cast_shape(heading)` |
| modify | `creature/motor/motor_plane.gd`, `environment/environment_footprint_sampler.gd`, `environment/playfield_bounds_3d.gd`, `creature/capabilities/playfield_clamp.gd` | Footprint from hull |
| modify | `creature/motor/flee_candidate_scoring.gd`, `motor_planner.gd`, `creature_motor_stack.gd` | Threat / own dimensions via hull-derived accessors |
| modify | `creature/definition/creature_definition.gd` | Hull data per HQ5 |
| modify | `tests/run_all.gd` (+ new fixtures) | See §8 |

### Collision / input / signals
- Layers / masks: unchanged. The hull changes shape type only, not layers.
- New signals: none planned. Hull rebuild is part of the existing live-dimension change path (B1 / M8).
- Groups: none.

### Dependencies
- Navigation plan T0c (re-plan spike) and the exact-fit gate (D23) for the oriented cast; Phase 1 of navigation does **not** depend on this plan (D25: later phase).
- Godot 4.6 (4.7?) capsule behaviour (§4.3).

---

## 5. Implementation plan (ordered, phased)

Each phase keeps rabbit / fox / wolf behaviour identical until Phase 4.

1. **Phase H0, verify and freeze (no behaviour change).** Verify capsule radius-shrink (§4.3). Add a golden test that records today's shape numbers for the three species. Answer HQ2 / HQ5.
2. **Phase H1, hull type behind existing accessors.** Add `BodyHull` (capsule kind only). Kinematic body builds its physics shape from it. `get_body_radius`, `get_collision_capsule_height`, eye height go through the hull. Zero numeric change.
3. **Phase H2, footprint consumers.** `motor_plane.gd`, playfield clamp / bounds and the environment footprint sampler take radius / half-extents from the hull (circle for capsule). Zero numeric change.
4. **Phase H3, gate and casts.** Ghost query, route scan, shelter fit and choke probes use `build_cast_shape(heading)`. Capsule ignores heading, so still zero numeric change; the orientation plumbing (HQ3) is exercised by a synthetic non-capsule fixture only.
5. **Phase H4, first flat hull (trigger: first flat species authored, HQ6).** Enable `flat` kind, resolve HQ1 / HQ4, drop the clamp for it, switch eye height to model-height-based (S1), re-check reach (S2), update `creature_mesh_footprint.gd` output (S3).
6. **Phase H5, doc sync.** Ship-time contract sync by `project-docs`: B14 / B24 note, usage-map rows for the hull accessors, fold the clamp description.

<<Question: HQ6 — When is the first flat species authored (spider-like), and is this plan expected to ship H0–H3 before it exists (pure refactor, enabling work), or should the whole plan wait for the species so the abstraction is shaped by a real case? D25 says the non-capsule hull arrives "when the first such species is authored" but also that the abstraction arrives "with the oriented footprint (D24)", which may come earlier.>>

---

## 6. Acceptance criteria

- [ ] Capsule-sized shape numbers for rabbit, fox and wolf are identical before and after Phases H1–H3 (golden test).
- [ ] The clamp `max(live_height, 2r)` and its single log line still bind and appear for a capsule-kind body with `H < 2r` (until a flat hull exists for that species).
- [ ] Collision body and gate shape come from the same `BodyHull` instance or equal parameters; a test asserts a fixture a route scan admits is traversable by the body (no wedge).
- [ ] A flat-hull fixture with `H < 2r` has physics shape height equal to true `H` (no clamp, no log line).
- [ ] An oriented fixture (long, narrow) fails a gap sideways and passes it head-on in the gate (D24).
- [ ] No consumer in §2.2 references `CapsuleShape3D` directly except the capsule branch of the hull builder (grep check).
- [ ] Environment footprint and playfield clamp receive radius / half-extents only; no hull type crosses into `environment/`.
- [ ] Bake `agent_height` is unaffected by hull kind (unclamped / lower-bound, D25).
- [ ] Godot radius-shrink behaviour is verified and recorded with a date in §4.3.
- [ ] `python tools/check_gdscript_no_tabs.py` exits `0` after any `.gd` change.

---

## 7. Risks & mitigations

| Risk | Status | Mitigation |
|---|---|---|
| Gate and body disagree on shape (wedge class) | `design` | M4: single hull instance; wedge test (§8) |
| Wide migration surface (about 15 files, many tests asserting capsule numbers) | `design` | Compat accessors; phases H1–H3 are zero-numeric-change with a golden test |
| Capsule-centre vs feet offset ("tall capsule" fixes in nav / path code) break when a flat hull has a different centre | `design` | Hull exposes `centre_offset_y`; flat hull kept feet-at-origin like authored capsules; test with a flat fixture |
| Box physics shape and fast turns (~1350 deg/s) cause wedging in `move_and_slide` | `open` | HQ4; test in H4 before authoring species |
| Oriented casts multiply per-step cost | `watch` | Trigger: gate cost above the T0c per-query budget (navigation plan §8.2.9); fall back to HQ3 option (c) |
| Radius-shrink behaviour differs from D25's assumption | `open` | §4.3 verification in H0 |
| Abstraction built before a real flat species shapes it (over-design) | `watch` | Trigger: a first flat species needing a hull feature not in §4.2; see HQ6 |

---

## 8. Testing / verification

**Manual steps:**
- After H1–H3: run the game; rabbit, fox, wolf move, flee, eat and route as before (no visible change).
- At H4: flat fixture creature passes under a low lintel a same-width capsule fails; verify no wedging when turning beside walls.

**Automated (headless, `tests/run_all.gd`; owned by test-harness):**
- **Golden equivalence:** hull-derived capsule radius, height, eye height, centre offset, footprint radius for the three species equal recorded values.
- **Clamp:** capsule kind with `H < 2r` gives height `2r` and one log line; tall fixture gives exactly `H`.
- **Flat hull:** `H < 2r` fixture yields the flat kind, true height, no clamp log.
- **No-wedge:** for a set of gaps (narrow, low, diagonal), `route scan admits => body traverses` using the same hull; and the converse for rejected gaps.
- **Orientation (D24):** long-narrow fixture fails sideways, passes head-on; capsule fixture is orientation-independent.
- **Footprint:** `overlapping_cell_layers` receives the hull's conservative radius; oriented footprint (if adopted) samples the expected cells.
- **Static grep check:** no direct `CapsuleShape3D` use outside the hull builder in the §2.2 files (allow-list for tests).
- Arrange-Act-Assert, intent-revealing names per root `CLAUDE.md`.

---

## 9. Open questions

All as inline `<<Question>>` markers above, collected:
- HQ1 box vs low cylinder (§4.1)
- HQ2 derived vs declared hull kind (§4.1)
- HQ3 orientation of the gate cast (§4.2)
- HQ4 does a non-capsule physics shape rotate with facing (§4.2)
- HQ5 hull-kind data location (§4.4)
- HQ6 when the first flat species is authored; ship H0–H3 early or wait (§5)

<<Question: HQ7 — Should `AI_int_lib/perception_sampling.gd` and `main_3d.gd` capsule mentions (found by grep, not classified) be in scope? Are they physical-body consumers or incidental (e.g. debug draw, spawn probing)?>>

<<Question: HQ8 — Eye height and awareness cone origin for a flat hull: model-height based (S1) leaves LoS looking from the top of a very low body; is `0.9 × true height` still right, or a species-authored eye height?>>

---

## 10. Changelog (this phase)

| Date | Change |
|---|---|
| 2026-10-08 | Draft created by feature-designer from NAVIGATION_PASSABILITY D22–D25 and CREATURE_BODY_DIMENSIONS B14 / B24. Consumer list from a read-only code grep. Not yet registered in `PROJECT_DOC_INDEX.md` (caller registers). |
