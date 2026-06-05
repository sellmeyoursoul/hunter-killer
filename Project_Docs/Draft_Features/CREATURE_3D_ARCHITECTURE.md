# Hunter Killer — 3D creature architecture (reuse vs leaf data)

> **Purpose:** Implementable map of the **3D creature** stack: **one copy** of each **capability** (vitals math, locomotion, perception scales, diet policies, predation clamp) and **leaf-heavy** [CreatureDefinition](../../creature/definition/creature_definition.gd) Resources for species. **Parallel** to today’s 2D `player.gd` / `mob.gd` — does not replace them until [CONVERT_TO_3D.md](CONVERT_TO_3D.md) retires the 2D path. **Parent design:** internal plan “3D creatures: reuse vs leaf data”; goals alignment: [CREATURE_GOALS.md](../Completed_Features/CREATURE_GOALS.md). **Index:** [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).

---

## 1. Capability modules (single definition vs node-attached)

| Capability | Where logic lives | Attached as | Driven by |
|------------|-------------------|-------------|-----------|
| **Vitals / calorie burn & plant clamp** | [creature_vitals_math.gd](../../creature/capabilities/creature_vitals_math.gd) (pure) | [creature_vitals_component.gd](../../creature/capabilities/creature_vitals_component.gd) (`Node`) | [GameConfig](../../game_config.gd) globals × [CreatureDefinition](../../creature/definition/creature_definition.gd) multipliers |
| **Predator meal clamp** | [creature_predation_math.gd](../../creature/capabilities/creature_predation_math.gd) (pure) | (call from collision / AI) | [predator_prey_meal_calories](../../AI_int_lib/game_config_merge.gd), species caps |
| **Perception scale (3D)** | [creature_perception_3d.gd](../../creature/capabilities/creature_perception_3d.gd) (pure) | TBD query node (later phase) | Definition `perception_radius_scale`, cone scale |
| **Diet → default groups** | [diet_registry.gd](../../creature/capabilities/diet_registry.gd) (static) | Runs at setup / AI context build | [CreatureDefinition.FeedingMode](../../creature/definition/creature_definition.gd) |
| **Intake policy data** | [food_intake_policy.gd](../../creature/definition/food_intake_policy.gd) (Resource) | Referenced by AI / overlap handlers | `plant_groups`, `prey_groups` |
| **Locomotion (production)** | [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) | `CharacterBody3D` **Body** child | [LocomotionProfile](../../creature/definition/locomotion_profile.gd) on definition; **`move_and_slide()`** on this node |
| **Locomotion (rigid stub — non-production)** | [creature_rigid_body_3d.gd](../../creature/capabilities/creature_rigid_body_3d.gd) | `RigidBody3D` **Body** child | **Deprecated** for duel per [CONVERT_TO_3D.md §D4](CONVERT_TO_3D.md); retained only for experiments / tests until removed |
| **Orchestration** | [creature_root_3d.gd](../../creature/creature_root_3d.gd) | `Node3D` scene root | `@export var definition` |

**Normative (duel / migration):** **All** 3D duel creatures — herbivore and carnivore — use **`CharacterBody3D` + `move_and_slide()`** via [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd). Do **not** use `RigidBody3D` chase for production.

**Pure helpers** stay free of `Node` for headless tests. **Components** hold runtime state (e.g. `current_calories`) and emit signals.

---

## 2. Leaf data: CreatureDefinition

Single Resource type (plus [LocomotionProfile](../../creature/definition/locomotion_profile.gd)): `species_id`, `feeding_mode`, vitals multipliers, perception scales, collision capsule hints, motivation trait **placeholders** ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)), optional `variant_scene`. **Example leaf asset:** [rabbit_archetype.tres](../../creature/species/rabbit_archetype.tres). Species **do not** need their own `.gd` unless behavior diverges (climb, burrow, etc.).

---

## 3. Scene templates (production)

| Scene | Physics | Use |
|-------|---------|-----|
| [creature_herbivore_kinematic_3d.tscn](../../creature/templates/creature_herbivore_kinematic_3d.tscn) | **`CharacterBody3D` + `move_and_slide`** + capsule | Herbivore / omnivore ground locomotion |
| [creature_carnivore_kinematic_3d.tscn](../../creature/templates/creature_carnivore_kinematic_3d.tscn) | **`CharacterBody3D` + `move_and_slide`** + capsule | Carnivore duel locomotion (M0+) |
| [creature_carnivore_rigid_3d.tscn](../../creature/templates/creature_carnivore_rigid_3d.tscn) | `RigidBody3D` (stub) | **Non-production** — experiments only |

Both production templates: [code]CreatureRoot3D[/code] + child [code]Body[/code] ([code]CharacterBody3D[/code] + [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd)) + child [code]Vitals[/code] ([CreatureVitalsComponent](res://creature/capabilities/creature_vitals_component.gd)). **Shared** scripts and definition; species differ via [code]CreatureDefinition[/code] only.

---

## 4. AI / motor bridge (intent API)

- **Production path:** `CreatureKinematicBody3D` — horizontal intent via `apply_horizontal_move_intent(Vector3, delta)`; **Y is ignored** for steering; **`move_and_slide()`** integrates motion and floor contact; **gravity** applied on this node when airborne.
- **Adapter (M0–M1):** Expose `set_creature_move_intent(Vector2)` on the **Body** (or thin wrapper) that maps `Vector2(x, y)` → `Vector3(x, 0, z)` so [ai_driver.gd](../../AI_int_lib/ai_driver.gd) keeps its 2D motor contract until full `Vector3` motor ships ([CONVERT_TO_3D.md §D3](CONVERT_TO_3D.md)).
- **XZ ownership:** All flattening from “2D motor direction” to “3D ground plane” happens **at the body boundary** — **not** scattered per species.

---

## 5. Testing strategy

- **Headless:** [tests/run_all.gd](../../tests/run_all.gd) covers **vitals burn**, **predation clamp**, **diet default policies**, **perception scale** — **no** per-species branches.
- **Play mode:** load **kinematic** templates under a `SubViewport` or dedicated 3D test scene when physics integration is required.
- **Template smoke:** Assert **kinematic** herbivore + carnivore scenes load; do **not** treat rigid carnivore as production contract.

---

## 6. Changelog

| Date | Change |
|------|--------|
| 2026-05-15 | Initial architecture doc + `creature/definition/*`, `creature/capabilities/*`, templates. |
| 2026-06-05 | **D4 alignment:** production duel = **`CharacterBody3D` + `move_and_slide`** only; carnivore kinematic template; rigid stub marked non-production; adapter note for `set_creature_move_intent`. |
| 2026-06-05 | **M0:** [`creature_carnivore_kinematic_3d.tscn`](../../creature/templates/creature_carnivore_kinematic_3d.tscn) + [`motor_plane.gd`](../../creature/motor/motor_plane.gd); kinematic body implements `set_creature_move_intent`. |
