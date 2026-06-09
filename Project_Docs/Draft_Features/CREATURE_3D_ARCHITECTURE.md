# Hunter Killer — 3D creature architecture (reuse vs leaf data)

> **Purpose:** Implementable map of the **3D creature** stack: **one copy** of each **capability** (vitals math, locomotion, perception scales, diet policies, predation clamp) and **leaf-heavy** [CreatureDefinition](../../creature/definition/creature_definition.gd) Resources for species. **Production** duel bodies live in [`creature/templates/*_kinematic_3d.tscn`](../../creature/templates/); entry [`main_3d.tscn`](../../main_3d.tscn). **Parent design:** internal plan “3D creatures: reuse vs leaf data”; goals alignment: [CREATURE_GOALS.md](../Completed_Features/CREATURE_GOALS.md). **Index:** [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).

---

## 1. Capability modules (single definition vs node-attached)

| Capability | Where logic lives | Attached as | Driven by |
|------------|-------------------|-------------|-----------|
| **Vitals / calorie burn & plant clamp** | [creature_vitals_math.gd](../../creature/capabilities/creature_vitals_math.gd) (pure) | [creature_vitals_component.gd](../../creature/capabilities/creature_vitals_component.gd) (`Node`) | [GameConfig](../../game_config.gd) globals × [CreatureDefinition](../../creature/definition/creature_definition.gd) multipliers |
| **Predator meal clamp** | [creature_predation_math.gd](../../creature/capabilities/creature_predation_math.gd) (pure) | (call from collision / AI) | [predator_prey_meal_calories](../../AI_int_lib/game_config_merge.gd), species caps |
| **Perception scale (3D)** | [creature_perception_3d.gd](../../creature/capabilities/creature_perception_3d.gd) (pure) | Radius/cone scale at ingest | Definition `perception_radius_scale`, cone scale |
| **Line of sight (3D)** | [line_of_sight.gd](../../creature/motor/line_of_sight.gd) | Combined awareness gate in [motor_target_builder.gd](../../creature/motor/motor_target_builder.gd) | Optional `los_eye_height` in pack; default `0.9 ×` synced capsule height |
| **Diet → default groups** | [diet_registry.gd](../../creature/capabilities/diet_registry.gd) (static) | Runs at setup / AI context build | [CreatureDefinition.FeedingMode](../../creature/definition/creature_definition.gd) |
| **Intake policy data** | [food_intake_policy.gd](../../creature/definition/food_intake_policy.gd) (Resource) | Referenced by AI / overlap handlers | `plant_groups`, `prey_groups` |
| **Locomotion (kinematic)** | [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) | `CharacterBody3D` **Body** child | [LocomotionProfile](../../creature/definition/locomotion_profile.gd) on definition; **`_apply_physics_layers()`** sets player vs mob bits |
| **Orchestration** | [creature_root_3d.gd](../../creature/creature_root_3d.gd) | `Node3D` scene root | `@export var definition` |

**Pure helpers** stay free of `Node` for headless tests. **Components** hold runtime state (e.g. `current_calories`) and emit signals.

**D4 (normative):** All species use **`CharacterBody3D` + `move_and_slide`**. No rigid-body species fork.

---

## 2. Leaf data: CreatureDefinition

Single Resource type (plus [LocomotionProfile](../../creature/definition/locomotion_profile.gd)): `species_id`, `feeding_mode`, vitals multipliers, perception scales, collision capsule hints, motivation trait **placeholders** ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)), optional `variant_scene`. **Example leaf asset:** [rabbit_archetype.tres](../../creature/species/rabbit_archetype.tres). Species **do not** need their own `.gd` unless behavior diverges (climb, burrow, etc.).

---

## 3. Scene templates (unified kinematic)

| Scene | Physics | Use |
|-------|---------|-----|
| [creature_herbivore_kinematic_3d.tscn](../../creature/templates/creature_herbivore_kinematic_3d.tscn) | [code]CharacterBody3D[/code] + capsule + MobHitbox [code]Area3D[/code] | Herbivore / omnivore duel prey |
| [creature_carnivore_kinematic_3d.tscn](../../creature/templates/creature_carnivore_kinematic_3d.tscn) | [code]CharacterBody3D[/code] + capsule | Carnivore duel predator ([code]is_hostile[/code] on body script) |

Both: [code]CreatureRoot3D[/code] + child [code]Body[/code] + child [code]Vitals[/code] ([CreatureVitalsComponent](res://creature/capabilities/creature_vitals_component.gd)). **Shared** scripts and definition; **only** leaf data and body exports differ. Physics layers applied at runtime in [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) (`player` layer `2` / mask `1` for prey; `mob` layer `4` / mask `9` for predators).

---

## 4. AI / motor bridge (intent API)

- **Kinematic:** `CreatureKinematicBody3D.apply_horizontal_move_intent` — pass **Vector3**; **Y is ignored**; horizontal velocity integrated and **gravity** applied on this node. **XZ ownership:** all flattening from motor-plane direction to world XZ happens **here** (via [MotorPlane](../../creature/motor/motor_plane.gd) adapter).
- **Size sync (M4):** `apply_effective_creature_size(size)` scales mesh + capsule with `creature_size`; `get_collision_capsule_radius()` / `get_los_eye_height()` feed nav + LoS.
- **AiDriver / scripting:** single “direction in, motion out” contract on registered [code]CharacterBody3D[/code] duel bodies; cardinal motor output maps to [code]Vector3(x, 0, z)[/code] in one adapter — **not** scattered per species.

---

## 5. Testing strategy

- **Headless:** [tests/run_all.gd](../../tests/run_all.gd) covers **vitals burn**, **predation clamp**, **diet default policies**, **perception scale**, **3D template load**, **predation contact** — **no** per-species branches.
- **Play mode:** load templates under a `SubViewport` or dedicated 3D test scene when physics integration is required (deferred).

---

## 6. Changelog

| Date | Change |
|------|--------|
| 2026-06-08 | **D4:** Unified kinematic templates only; removed rigid-body fork and stale 2D parallel wording (M3). |
| 2026-05-15 | Initial architecture doc + `creature/definition/*`, `creature/capabilities/*`, templates. |
