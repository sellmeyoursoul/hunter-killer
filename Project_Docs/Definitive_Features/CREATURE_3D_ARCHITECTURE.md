# Hunter Killer — 3D creature architecture (reuse vs leaf data)

> **Purpose:** Implementable map of the **3D creature** stack: **one copy** of each **capability** (vitals math, locomotion, perception scales, diet policies, predation clamp) and **leaf-heavy** [CreatureDefinition](../../creature/definition/creature_definition.gd) Resources for species. **Production** duel bodies live in [`creature/templates/*_kinematic_3d.tscn`](../../creature/templates/); entry [`main_3d.tscn`](../../main_3d.tscn). **Parent design:** internal plan “3D creatures: reuse vs leaf data”; goals alignment: [CREATURE_GOALS.md](../Completed_Features/CREATURE_GOALS.md). **Index:** [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).
>
> **Tier:** Definitive (tier III) — align with code, `project.godot`, and creature templates; drift is a bug.

---

## 1. Capability modules (single definition vs node-attached)

| Capability | Where logic lives | Attached as | Driven by |
|------------|-------------------|-------------|-----------|
| **Vitals / calorie burn & plant clamp** | [creature_vitals_math.gd](../../creature/capabilities/creature_vitals_math.gd) (pure) | [creature_vitals_component.gd](../../creature/capabilities/creature_vitals_component.gd) (`Node`) | [GameConfig](../../game_config.gd) globals × [CreatureDefinition](../../creature/definition/creature_definition.gd) multipliers |
| **Predator meal clamp** | [creature_predation_math.gd](../../creature/capabilities/creature_predation_math.gd) (pure) | V3 **`EAT`** completion via motor stack (planned — [CREATURE_MOVEMENT_V3.md §12.2 D11](../Draft_Features/CREATURE_MOVEMENT_V3.md)); legacy `MobHitbox` contact **inert** until template cleanup | [predator_prey_meal_calories](../../AI_int_lib/game_config_merge.gd), species caps |
| **Perception scale (3D)** | [creature_perception_3d.gd](../../creature/capabilities/creature_perception_3d.gd) (pure) | Radius/cone scale at ingest | Definition `perception_radius_scale`, cone scale |
| **Line of sight (3D)** | [line_of_sight.gd](../../creature/motor/line_of_sight.gd) | Combined awareness gate in [motor_target_builder.gd](../../creature/motor/motor_target_builder.gd) | Optional `los_eye_height` in pack; default `0.9 ×` capsule height (`max(live_height, 2r)`) |
| **Diet → default groups** | [diet_registry.gd](../../creature/capabilities/diet_registry.gd) (static) | Runs at setup / AI context build | [CreatureDefinition.FeedingMode](../../creature/definition/creature_definition.gd) |
| **Intake policy data** | [food_intake_policy.gd](../../creature/definition/food_intake_policy.gd) (Resource) | Referenced by AI / overlap handlers | `plant_groups`, `prey_groups` |
| **Locomotion (kinematic)** | [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) | `CharacterBody3D` **Body** child | [LocomotionProfile](../../creature/definition/locomotion_profile.gd) on definition; **`_apply_physics_layers()`** sets player vs mob bits |
| **Visual facing (3D)** | [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) `_sync_visual_facing` + [motor_plane.gd](../../creature/motor/motor_plane.gd) `yaw_from_horizontal_dir` | `Body/Visual` child (mounted by [creature_root_3d.gd](../../creature/creature_root_3d.gd)) | [member last_move_direction](../../creature/capabilities/creature_kinematic_body_3d.gd) — same vector as awareness cone; capsule stays axis-aligned |
| **Orchestration** | [creature_root_3d.gd](../../creature/creature_root_3d.gd) | `Node3D` scene root | `@export var definition` |

**Pure helpers** stay free of `Node` for headless tests. **Components** hold runtime state (e.g. `current_calories`) and emit signals.

**D4 (normative):** All species use **`CharacterBody3D` + `move_and_slide`**. No rigid-body species fork.

---

## 2. Leaf data: CreatureDefinition

Single Resource type (plus [LocomotionProfile](../../creature/definition/locomotion_profile.gd)): `species_id`, `feeding_mode`, vitals multipliers, perception scales, body dimensions (`body_length` / `body_width` / `body_height`, optional `reach_override`; legacy capsule fields deprecated), motivation trait **placeholders** ([CREATURE_MODEL_PLAN.md](../Draft_Features/CREATURE_MODEL_PLAN.md)), optional `variant_scene`. **Example leaf asset:** [rabbit_archetype.tres](../../creature/species/rabbit_archetype.tres). Species **do not** need their own `.gd` unless behavior diverges (climb, burrow, etc.).

---

## 3. Scene templates (unified kinematic)

| Scene | Physics | Use |
|-------|---------|-----|
| [creature_herbivore_kinematic_3d.tscn](../../creature/templates/creature_herbivore_kinematic_3d.tscn) | [code]CharacterBody3D[/code] + capsule + MobHitbox [code]Area3D[/code] (**inert** for predation post–D11 — remove in later phase) | Herbivore / omnivore duel prey |
| [creature_carnivore_kinematic_3d.tscn](../../creature/templates/creature_carnivore_kinematic_3d.tscn) | [code]CharacterBody3D[/code] + capsule | Carnivore duel predator ([code]is_hostile[/code] on body script) |

Both: [code]CreatureRoot3D[/code] + child [code]Body[/code] + child [code]Vitals[/code] ([CreatureVitalsComponent](res://creature/capabilities/creature_vitals_component.gd)). **Shared** scripts and definition; **only** leaf data and body exports differ. Physics layers applied at runtime in [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) (`player` layer `2` / mask `1` for prey; `mob` layer `4` / mask `9` for predators).

---

## 4. AI / motor bridge (intent API)

- **Kinematic:** `CreatureKinematicBody3D.apply_horizontal_move_intent` — pass **Vector3**; **Y is ignored**; horizontal velocity integrated and **gravity** applied on this node. **XZ ownership:** all flattening from motor-plane direction to world XZ happens **here** (via [MotorPlane](../../creature/motor/motor_plane.gd) adapter).
- **Visual facing:** `Body/Visual.rotation.y` tracks **`last_move_direction`** via `_sync_visual_facing()` (after each physics step and in `_process` so AiDriver stationary 8-way turns stay aligned). Yaw from [MotorPlane.yaw_from_horizontal_dir](../../creature/motor/motor_plane.gd) is the signed angle about +Y rotating **`MotorPlane.MODEL_FORWARD`** (**+Z**, `Vector3(0, 0, 1)`; the single model-forward constant, also the default facing when there is no movement) onto the direction: `wrapf(atan2(d.x, d.z) − atan2(F.x, F.z), −PI, PI)`, so `Basis(UP, yaw) * MODEL_FORWARD ≈ d`. Per-body **`visual_yaw_offset_rad`** export is an extra Visual yaw (relative to +Z) for meshes whose nose is not along +Z; both kinematic templates (`creature_herbivore_kinematic_3d.tscn`, `creature_carnivore_kinematic_3d.tscn`) set **3π/2** (`4.71238898038469`) for the current placeholder models (nose along ±X). `HORIZONTAL_FORWARD` is retired. Visual check: `tools/facing_check_3d.tscn`. Plan and history: [CREATURE_BODY_DIMENSIONS.md](../Draft_Features/CREATURE_BODY_DIMENSIONS.md) §4.8.1 (B22, B23, B26). **Collision capsule does not rotate.**
- **Size and body dimensions (CREATURE_BODY_DIMENSIONS Phase 1):** authored `body_length` / `body_width` / `body_height` on [CreatureDefinition](../../creature/definition/creature_definition.gd) (game units, +Z length, X width, Y height) are the size truth; the deprecated `creature_size` / `collision_capsule_radius` / `collision_capsule_height` are a **legacy fallback while any of the three is <= 0** (still on the class; removed from the rabbit / fox / wolf archetype `.tres` files, which carry authored dimensions since Phase 2: rabbit 1.7 / 0.7 / 1.4, fox 2.0 / 0.4 / 0.9, wolf 6.0 / 1.3 / 3.0 as L / W / H; the wolf 3× wrapper `wolf_3d.tscn` is gone and `_SPECIES_MESH_FILE[&"wolf"]` is `wolf.blend`; `placeholder_model: true` in the three `pack_resources.json` files). `apply_effective_creature_size(size)` sets a uniform size factor, re-derives the capsule and re-fits the Visual; the **`CharacterBody3D` is never scaled** (scale stays `Vector3.ONE`). `get_body_radius()` = `live_width / 2 × (1 + width_margin)` (nav / gap-fit / ghost-fit consumers); `get_reach_extent()` = `reach_override × size_factor` or `live_length × (0.5 + reach_margin_fraction)` (eat reach: the eater term of the size-scaled eat gate, below); `get_body_dimensions()` = `Vector3(width, height, length)`; `get_collision_capsule_height()` = `max(live_height, 2r)` (Godot 4 total height); `get_collision_capsule_radius()` is an alias of `get_body_radius()`; `get_los_eye_height()` = `0.9 ×` that height. `width_margin` / `reach_margin_fraction` / `eat_range_bonus_fraction` (default 0.25) live in `game_config.json` `creature_motor_v3` (defaults in `AI_int_lib/game_config_merge.gd` `default_creature_motor_v3_params()`; getters `GameConfig.get_width_margin()` / `get_reach_margin_fraction()` / `get_eat_range_bonus_fraction()`). **Eat gate** (`motor_planner.gd` `eat_range()` / `_eat_range_for`, CREATURE_BODY_DIMENSIONS B28): ground-plane (XZ, `MotorPlane.horizontal_distance`; Y ignored) distance <= eater `get_reach_extent()` + `eat_range_bonus_fraction` × eater live length + target `get_body_radius()` (plants 0); the fixed `eat_action_max_distance` is no longer read by the gate or approach. After [creature_root_3d.gd](../../creature/creature_root_3d.gd) mounts **Visual**, [apply_visual_fit](../../creature/capabilities/creature_kinematic_body_3d.gd) fits it: uniform on length for production models, per-axis plus bottom-centre re-centre when the pack's `pack_resources.json` has `placeholder_model: true`, with a once-per-species proportion log (tolerances from `tools/body_dimension_spec.json`); legacy mode skips the fit and centres the capsule on the mesh. [creature_mesh_footprint.gd](../../creature/capabilities/creature_mesh_footprint.gd) only **measures** the mesh AABB; pure math is in [creature_body_dimensions.gd](../../creature/capabilities/creature_body_dimensions.gd). **No** mesh colliders on **Body**. Detail and acceptance: [CREATURE_BODY_DIMENSIONS.md](../Draft_Features/CREATURE_BODY_DIMENSIONS.md) §4.7 / §4.8.
- **AiDriver / scripting:** single “direction in, motion out” contract on registered [code]CharacterBody3D[/code] duel bodies; cardinal motor output maps to [code]Vector3(x, 0, z)[/code] in one adapter — **not** scattered per species.

---

## 5. Testing strategy

- **Headless:** [tests/run_all.gd](../../tests/run_all.gd) covers **vitals burn**, **predation clamp**, **diet default policies**, **perception scale**, **3D template load**, **predation contact**, **motor-plane yaw ↔ 8-way facing** — **no** per-species branches.
- **Play mode:** load templates under a `SubViewport` or dedicated 3D test scene when physics integration is required (deferred).

---

## 6. Changelog

| Date | Change |
|------|--------|
| 2026-10-05 | **Body dimensions Phase 1:** capsule from authored L / W / H (`get_body_radius()`, `get_reach_extent()`, total-height capsule, body scale stays one, `apply_visual_fit` replaces `apply_capsule_footprint_from_visual`, `creature_mesh_footprint.gd` measuring-only); legacy capsule fields kept as fallback until archetypes migrate. §4 "Size sync (M4)" rewritten. |
| 2026-10-05 | **Facing corrected (bfcbd26):** `MotorPlane.MODEL_FORWARD = +Z` replaces `HORIZONTAL_FORWARD` (−Z); `yaw_from_horizontal_dir` fixed (was mirrored left / right for X headings); both kinematic templates `visual_yaw_offset_rad` 3π/2; headless yaw test uses real `Basis(UP, yaw) * MODEL_FORWARD`. |
| 2026-07-09 | **Mesh-aligned collision:** creature capsule from mounted visual AABB; food shrubs convex bake — [ENVIRONMENT_MODEL_PLAN.md §6.3](ENVIRONMENT_MODEL_PLAN.md). |
| 2026-06-09 | **Visual facing:** `Body/Visual` Y rotation synced to `last_move_direction` (awareness cone); `MotorPlane.yaw_from_horizontal_dir`; optional `visual_yaw_offset_rad`. |
| 2026-06-09 | Promoted from `Draft_Features/` to `Definitive_Features/` (tier III). |
| 2026-06-08 | **D4:** Unified kinematic templates only; removed rigid-body fork and stale 2D parallel wording (M3). |
| 2026-05-15 | Initial architecture doc + `creature/definition/*`, `creature/capabilities/*`, templates. |
