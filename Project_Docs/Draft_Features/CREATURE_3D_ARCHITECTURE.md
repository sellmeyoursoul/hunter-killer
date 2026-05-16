# Hunter Killer — 3D creature architecture (reuse vs leaf data)

> **Purpose:** Implementable map of the **3D creature** stack: **one copy** of each **capability** (vitals math, locomotion, perception scales, diet policies, predation clamp) and **leaf-heavy** [CreatureDefinition](../../creature/definition/creature_definition.gd) Resources for species. **Parallel** to today’s 2D `player.gd` / `mob.gd` — does not replace them. **Parent design:** internal plan “3D creatures: reuse vs leaf data”; goals alignment: [CREATURE_GOALS.md](../Completed_Features/CREATURE_GOALS.md). **Index:** [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).

---

## 1. Capability modules (single definition vs node-attached)

| Capability | Where logic lives | Attached as | Driven by |
|------------|-------------------|-------------|-----------|
| **Vitals / calorie burn & plant clamp** | [creature_vitals_math.gd](../../creature/capabilities/creature_vitals_math.gd) (pure) | [creature_vitals_component.gd](../../creature/capabilities/creature_vitals_component.gd) (`Node`) | [GameConfig](../../game_config.gd) globals × [CreatureDefinition](../../creature/definition/creature_definition.gd) multipliers |
| **Predator meal clamp** | [creature_predation_math.gd](../../creature/capabilities/creature_predation_math.gd) (pure) | (call from collision / AI) | [predator_prey_meal_calories](../../AI_int_lib/game_config_merge.gd), species caps |
| **Perception scale (3D)** | [creature_perception_3d.gd](../../creature/capabilities/creature_perception_3d.gd) (pure) | TBD query node (later phase) | Definition `perception_radius_scale`, cone scale |
| **Diet → default groups** | [diet_registry.gd](../../creature/capabilities/diet_registry.gd) (static) | Runs at setup / AI context build | [CreatureDefinition.FeedingMode](../../creature/definition/creature_definition.gd) |
| **Intake policy data** | [food_intake_policy.gd](../../creature/definition/food_intake_policy.gd) (Resource) | Referenced by AI / overlap handlers | `plant_groups`, `prey_groups` |
| **Locomotion (kinematic)** | [creature_kinematic_body_3d.gd](../../creature/capabilities/creature_kinematic_body_3d.gd) | `CharacterBody3D` **Body** child | [LocomotionProfile](../../creature/definition/locomotion_profile.gd) on definition |
| **Locomotion (rigid stub)** | [creature_rigid_body_3d.gd](../../creature/capabilities/creature_rigid_body_3d.gd) | `RigidBody3D` **Body** child | Same profile + `move_force_scale` export |
| **Orchestration** | [creature_root_3d.gd](../../creature/creature_root_3d.gd) | `Node3D` scene root | `@export var definition` |

**Pure helpers** stay free of `Node` for headless tests. **Components** hold runtime state (e.g. `current_calories`) and emit signals.

---

## 2. Leaf data: CreatureDefinition

Single Resource type (plus [LocomotionProfile](../../creature/definition/locomotion_profile.gd)): `species_id`, `feeding_mode`, vitals multipliers, perception scales, collision capsule hints, motivation trait **placeholders** ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)), optional `variant_scene`. **Example leaf asset:** [rabbit_archetype.tres](../../creature/species/rabbit_archetype.tres). Species **do not** need their own `.gd` unless behavior diverges (climb, burrow, etc.).

---

## 3. Scene templates (body-type fork)

| Scene | Physics | Use |
|-------|---------|-----|
| [creature_herbivore_kinematic_3d.tscn](../../creature/templates/creature_herbivore_kinematic_3d.tscn) | [code]CharacterBody3D[/code] + capsule | Herbivore / omnivore ground locomotion |
| [creature_carnivore_rigid_3d.tscn](../../creature/templates/creature_carnivore_rigid_3d.tscn) | [code]RigidBody3D[/code] + capsule + damping | Carnivore / chase stub; tune mass & forces in editor |

Both: [code]CreatureRoot3D[/code] + child [code]Body[/code] + child [code]Vitals[/code] ([CreatureVitalsComponent](res://creature/capabilities/creature_vitals_component.gd)). **Shared** scripts and definition; **only** the physics body differs.

---

## 4. AI / motor bridge (intent API)

- **Kinematic:** `CreatureKinematicBody3D.apply_horizontal_move_intent` — pass **Vector3**; **Y is ignored**; horizontal velocity integrated and **gravity** applied on this node. **XZ ownership:** all flattening from “2D motor direction” to “3D ground plane” happens **here** (or a thin adapter that sets `Vector3(intent_x, 0, intent_z)` from cardinal motor output).
- **Rigid:** `CreatureRigidBody3D.apply_horizontal_move_intent` / `set_horizontal_move_intent_for_tick` — same **horizontal** convention; forces applied in [code]_physics_process[/code].
- **AiDriver / scripting:** keep a **single** “direction in, motion out” contract; when wiring the 2D motor to 3D, map **screen X/Y** (or map forward) to **world X/Z** in one adapter — **not** scattered per species.

---

## 5. Testing strategy

- **Headless:** [tests/run_all.gd](../../tests/run_all.gd) covers **vitals burn**, **predation clamp**, **diet default policies**, **perception scale** — **no** per-species branches.
- **Play mode:** load templates under a `SubViewport` or dedicated 3D test scene when physics integration is required (deferred).

---

## 6. Changelog

| Date | Change |
|------|--------|
| 2026-05-15 | Initial architecture doc + `creature/definition/*`, `creature/capabilities/*`, templates. |
