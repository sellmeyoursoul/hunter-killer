# Dodge the Creeps — Design doc (agent-friendly)

**Status:** Completed (2026-05-11). Archived under `Project_Docs/Completed_Features/`; active code references this document for motor contracts. Run `godot --path . --headless -s res://tests/run_all.gd` for regression coverage.

> Cardinal motor for dodging mobs — foundation for future weighted utility (hunger, etc.). LLM is **not** the movement engine while `creature_motor.mode` is `scripted` ([AI_INT_CONVERSATION_SCOPE_PLAN.md](../AI_INT_CONVERSATION_SCOPE_PLAN.md)).

---

## 1. Phase summary

**Phase name:** Mob avoidance — scripted cardinal motor (v1)

**One-line objective:** Each physics tick while engine-held control is active, choose a **4-way + idle** move intent by **minimizing a geometric cost** (inverse clearance to mobs against the creature’s predictive **collision footprint**, closing-speed term, out-of-bounds penalty) so the playable creature steers away from threats without HTTP latency.

**Round start / session start (resolved):** This phase keeps **starting a round gated on the AI Player UX** (HUD control that triggers the established arm / handshake → `START` → `PLAYING` flow when inference is configured).  
<<Comment: When multiple playable creatures gain independent cognition, revisit per-creature or joint “START” semantics; that is out of scope for this phase.>>

**Out of scope (explicit non-goals):**  
- Behavior-tree editor or third-party BT plugin.  
- Pathfinding / navmesh.  
- Changing mob spawn rules or RigidBody mob physics.  
- Removing or breaking the existing TinyLlama **ARMED** handshake / **PLAYING** `llm` path when `creature_motor.mode` is `llm`.

**Deferred enhancements (track for later specs, not this phase):**  
- **Offline / zero-server demo:** scripted `auto-START`, skipping llama-server, or issuing `START` without HTTP — deliberately **not** in v1; document in the next backlog pass when UX is chosen.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/dodge-the-creeps`

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** `main.tscn` → `AiDriver` autoload manages session state and, when AI session is **PLAYING**, applies either **scripted** motor intents or **`llm`** inference intents according to merged `creature_motor.mode`.

**Key scripts (paths):**  
- [creature/motor/cardinal_avoidance.gd](../../creature/motor/cardinal_avoidance.gd) — pure scoring / `pick_best_move_intent`; uses predictive **creature half-extents** for clearance geometry.  
- [AI_int_lib/ai_driver.gd](../../AI_int_lib/ai_driver.gd) — builds context from `Main` + playable creature (`player.gd` body) + group `mobs`, calls motor (scripted mode), drives `ControlMode`; skips play-phase HTTP when `creature_motor.mode` is scripted.  
- [player.gd](../../player.gd) — **`ControlMode`**: `HUMAN` | `ENGINE` | **`AI`**; `set_creature_move_intent`, `speed`, `screen_size`. ENGINE and AI both consume **sticky intent** (no literal keys).  
- [game_config.gd](../../game_config.gd) / [AI_int_lib/game_config_merge.gd](../../AI_int_lib/game_config_merge.gd) — `creature_motor` section (`creature_half_extent_x` / `creature_half_extent_y` must be **positive** numbers in JSON; see **Intentional asymmetries** for capsule override behavior).

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)  
- [VISION_WORLD_BUILDER_PLAN.md](../VISION_WORLD_BUILDER_PLAN.md), [CREATURE_MODEL_PLAN.md](../CREATURE_MODEL_PLAN.md) for future weight hooks.

---

## 3. Requirements

### Must have

- `creature_motor.mode` ∈ `scripted` | `llm` (default **`scripted`** in merged defaults).  
- Pure `pick_best_move_intent(ctx: Dictionary) -> Vector2` with deterministic tie-break order: **UP, RIGHT, DOWN, LEFT**, then **ZERO**.  
- Obstacle and closing terms use **shortest distance from each mob’s reference point to the axis-aligned predictive footprint** of the creature (center at predicted position, half-extents from merged config and/or resolved `CollisionShape2D`), not only center-to-center distance.  
- Out-of-bounds prediction: **entire** predictive footprint (AABB) must stay inside the same axis-aligned bounds as creature clamp (`bounds_min`, `bounds_max`); otherwise cost = `penalty_oob`.  
- **Control contract — three modes (normative):**  
  - **`HUMAN`:** movement comes from `Input` actions only.  
  - **`ENGINE`:** movement comes from **scripted** motor via `set_creature_move_intent` (this phase’s cardinal avoidance when `creature_motor.mode` is `scripted`).  
  - **`AI`:** movement comes from **LLM / TM** (or future remote policy) via the **same** `set_creature_move_intent` path when `creature_motor.mode` is `llm`.  
- Non-human modes must **not** introduce parallel ad-hoc motion APIs on the creature body: any controller (motor, inference, future TM) **only** changes motion through `set_creature_move_intent` + `ControlMode`, so capabilities stay aligned as actions grow.  
- When **scripted** + **PLAYING** + **`ControlMode.ENGINE`**: no `/v1/completions` traffic for movement ticks; intent updated on physics cadence.  
- When **`llm`** + **PLAYING** + **`ControlMode.AI`**: existing inference cadence unchanged.  
- When **`llm`** + **PLAYING**: creature is in **`AI`**, not `ENGINE`, so mode matches the active movement producer.

### Should have

- Tunable weights, `lookahead_sec`, **`scripted_intent_hold_physics_ticks`** (default **5** physics frames of commitment before scripted motor swaps cardinals), and optional **footprint** overrides via `creature_motor` JSON.

### Nice to have

- Second utility term (e.g. plant gradient) added to the same cost sum in a later phase.

---

## 4. Technical design

### Architecture / data flow

1. `AiDriver._physics_process` (when `PLAYING`, `creature_motor.mode` is `scripted`, creature is **`ControlMode.ENGINE`**): gather mob `{ position, velocity }`, creature center `global_position`, collision footprint / half-extents, `speed`, `screen_size`, merged motor params → raw intent from `CardinalAvoidance.pick_best_move_intent(ctx)` → **debounce through `scripted_intent_hold_physics_ticks`** (pure helper [creature/motor/scripted_intent_hold.gd](../../creature/motor/scripted_intent_hold.gd)) so a challenger cardinal must persist N consecutive physics ticks before replacing the incumbent → `set_creature_move_intent`. **Does not touch `ControlMode.HUMAN`** key handling (players still get instantaneous opposite keys).     
2. `AiDriver._process`: if `PLAYING` and scripted, **do not** `_enqueue_inference_request`; if `ARMED`, still enqueue handshake (START) so **AI Player** flow works when inference URL is configured.  
3. On transition to `PLAYING` from `ARMED`, set **`ControlMode.ENGINE`** when mode is `scripted`, else **`ControlMode.AI`** when mode is `llm`, so the mode always matches who writes intent.

### Who implements “controllers”?

- **This repo owns** the playable creature script (`player.gd`) and the **normative seams**: `ControlMode`, `set_creature_move_intent`, and (`future`) the same contract on additional creatures.  
- **We do not** author separate mystery controller types that bypass those seams. Any new actor (second creature, TM policy server) must **either** use the same methods on a body that implements the contract **or** go through a thin adapter that **only** calls those methods — so behavior stays inspectable and testable.  
- **Standard enforcement:** new features that move a controllable creature must be reviewed against section 3 (same action → same path: intent API plus `ControlMode`), not ad-hoc motion fields on the body.

### Context dictionary (`ctx`) — normative keys

| Key | Type | Meaning |
|-----|------|---------|
| `creature_position` | `Vector2` | World **center** of the creature’s collision footprint at scoring time (typically `global_position` of the `Player` node / `player.gd`). |
| `creature_half_extents` | `Vector2` | Axis-aligned **positive** half-width and half-height (world px) for the predictive AABB. **`Vector2.ZERO`** (or any non-positive half-extent on either axis after driver clamping) selects **center-point** clearance only (`CardinalAvoidance` treats that as legacy/tests). Config authors should keep JSON `creature_half_extent_x` / `creature_half_extent_y` **strictly positive**; the driver clamps with `max(0, …)` so mistakes do not produce negative geometry. |
| `creature_speed` | `float` | Max speed (px/s); matches `speed` on that body. |
| `lookahead_sec` | `float` | Horizons `speed * lookahead * dir` from `creature_position`. |
| `bounds_min` | `Vector2` | Usually `(0, 0)`. |
| `bounds_max` | `Vector2` | Viewport size / clamp max. |
| `mobs` | `Array` | Elements `{ "position": Vector2, "velocity": Vector2 }` in world space (mob reference point remains the body center unless a later phase adds extent keys). |
| `weight_dist` | `float` | Scale inverse-clearance sum (default `1.0`). |
| `weight_closing` | `float` | Scale mob velocity component along **mob → nearest point on creature footprint** (default `0.5`). |
| `penalty_oob` | `float` | Cost if predictive footprint leaves bounds (default `1e7`). |
| `distance_eps` | `float` | Floor for clearance divisor (default `8.0` px). |

**Merged `creature_motor` keys consumed only by AiDriver** (not passed through `pick_best_move_intent` context):

| Key | Type | Meaning |
|-----|------|---------|
| `scripted_intent_hold_physics_ticks` | `int` | Consecutive physics ticks the motor's **new** winning cardinal must repeat before replacing the creature's sticky intent (**default `5`**, clamped to at least `1`). Idle (`Vector2.ZERO` incumbent) still applies motor output immediately so round start stays responsive. |
| `creature_half_extent_x` | `float` | **Positive** half-width (px) when footprint is taken from JSON (see asymmetries below). |
| `creature_half_extent_y` | `float` | **Positive** half-height (px) when footprint is taken from JSON. |

### Cost model (v1, footprint-aware)

For candidate direction unit `d` (including `ZERO`):

- `predicted_center = creature_position + d * creature_speed * lookahead_sec`.  
- Let `H = creature_half_extents` (`Vector2.ZERO` ⇒ treat creature as a **point** at `predicted_center` for obstacle math — backward-compat only).  
- If the axis-aligned box **center `predicted_center`, half-extents `H`** is **not fully contained** in `[bounds_min, bounds_max]`, cost = `penalty_oob`.  
- Else: sum over mobs (`mob.position` / `mob.velocity`):  
  - `closest` = clamp of `mob.position` onto the predictive AABB `[predicted_center ± H]` (nearest point on or inside that rectangle to `mob.position`).  
  - `separation = mob.position - closest` (mob → creature proximity); `dist = separation.length()`, `inv = 1 / max(distance_eps, dist)`.  
  - `cost += weight_dist * inv`.  
  - If `dist > tiny`, let `u = separation / dist`; if `mob.velocity.dot(u) > 0`, add `weight_closing * (mob.velocity.dot(u)) * inv` (mob component **toward** the creature footprint).

Pick **minimum** cost; ties keep **earlier** direction in tie order.

### Scene & file changes (delivered)

| Action | Path | Notes |
|--------|------|-------|
| create | `res://creature/motor/cardinal_avoidance.gd` | Static API + footprint-aware clearance |
| create | `res://creature/motor/scripted_intent_hold.gd` | `scripted_intent_hold_physics_ticks` debounce for ENGINE path |
| modify | `res://AI_int_lib/game_config_merge.gd` | `creature_motor` defaults + merge |
| modify | `res://game_config.gd` | `get_creature_motor_params()` |
| modify | `res://AI_int_lib/ai_driver.gd` | Scripted branch, context build, `ControlMode`, positive half-extent clamp |
| modify | `res://game_config.json` | Document `creature_motor` keys |
| modify | `res://player.gd` | `ControlMode.AI`, intent path parity |

### Collision / input / signals (if relevant)

- Uses same collision outcome as today (Area2D player vs mob bodies); motor only changes **intent**, not layers.

### Dependencies

- Mobs in group `mobs` ([mob.gd](../../mob.gd)).

### Intentional asymmetries (motor vs other subsystems)

These differences are **deliberate** unless a future spec unifies them.

1. **Mob kinematics sample** — The scripted motor’s `ctx["mobs"]` entries use each mob **`RigidBody2D.global_position`** and **`linear_velocity`** (physics body origin). Perception snapshot / risk-hint code uses **collision-sampling** centers (and may rank by sampled distance). Unifying motor mobs to sampled points would be a separate change with perf and parity tradeoffs.

2. **Creature footprint source** — If the playable body’s `CollisionShape2D.shape` is a **`CapsuleShape2D`**, `AiDriver` **derives** `creature_half_extents` from that capsule (axis-aligned half-size) and **does not** use `creature_half_extent_x` / `creature_half_extent_y` from JSON for that build. If the shape is **missing or not a capsule**, those JSON keys supply the footprint; values are read as **non-negative** via `max(0, value)` so invalid config cannot invert an AABB. Authors should still store **positive** half-extents for meaningful footprint scoring.

---

## 5. Implementation plan (**completed**)

1. ~~Land `cardinal_avoidance.gd` + unit tests (footprint-aware path + ZERO-extents regressions).~~ **Done**  
2. ~~Merge `creature_motor` + `GameConfig.get_creature_motor_params()` (+ optional extent keys).~~ **Done**  
3. ~~Wire `AiDriver` scripted path, `AI` vs `ENGINE` modes, footprint in context build.~~ **Done**  
4. ~~Manual playtest~~ **Done** — AI Player / scripted dodge smoke per §8; regression covered by `tests/run_all.gd` (`_test_mob_avoidance_acceptance`, `_test_cardinal_avoidance`, `_test_scripted_intent_hold`).

---

## 6. Acceptance criteria

### Shared / configuration

- [x] Default merged config has `creature_motor.mode` = `scripted`.  
- [x] With `llm` mode, **PLAYING** keeps pre-change inference cadence; playable creature **`ControlMode.AI`** during `llm` **PLAYING** (wiring: `AiDriver.playing_control_mode_int_for_motor_mode_string` + `notify_main_new_game`).  
- [x] Headless tests cover cardinal cases, OOB penalty, tie order, `scripted_intent_hold` debounce (default streak), and (where practical) nonzero `creature_half_extents` clearance behavior.

### `ControlMode.HUMAN`

- [x] Mapped keys move the creature in **UP / DOWN / LEFT / RIGHT** as expected relative to viewport (`InputMap` actions verified in `_test_mob_avoidance_acceptance`).  
- [x] Whenever new discrete actions are added (`Input` maps or equivalents), acceptance rows are appended for those bindings (no additional move keys in this release; process applies when keys are added).

### `ControlMode.ENGINE` (scripted motor, this phase)

- [x] After the motor first commits to a cardinal, a **different** cardinal must persist for **`scripted_intent_hold_physics_ticks`** physics frames (default **5**) before the creature adopts it (`ControlMode.HUMAN` input unchanged).  
- [x] With nearby hostiles, motor picks directions that **affirmatively** reduce clearance risk versus standing still — observable as dodging behavior in playtests; automated tests approximate with inverse-clearance scoring on synthetic mobs (`_test_cardinal_avoidance` overlap cost).  
- [x] Scripted **PLAYING** emits **no** movement `/v1/completions` calls (`AiDriver._process` early-return when `creature_motor.mode` is `scripted`).

### `ControlMode.AI` (`creature_motor.mode` **`llm`**)

- [x] Refinement of LLM behavior, snapshot quality, and TM integration remains **out of scope** for this plan; only **mode wiring** and parity with the intent API are in scope here (`_apply_action_token` → `set_creature_move_intent`; `notify_main_new_game` sets **AI** mode for `llm`).

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| **Oscillation (flip-flop)** — The motor re-evaluates every physics tick. If two or more directions keep **nearly equal** cost (e.g. left vs right as a symmetric mob pair tightens), the chosen minimum can **swap** from tick to tick even with a fixed tie-break, so the creature **visibly jitters** or alternates cardinals. This is separate from “true ties” on one frame: it is **multi-frame instability** as costs cross when mobs or the creature move. **Human `ControlMode.HUMAN` steering is unaffected** — keyboard opposite directions remain immediate on every physics tick; hold logic applies only on the scripted **ENGINE** path. | Deterministic tie order on identical costs. **Debounced cardinal commitment:** merged `creature_motor.scripted_intent_hold_physics_ticks` (**default `5`** physics ticks). New winner must persist that many consecutive ticks before replacing sticky intent except when incumbent intent is idle (`Vector2.ZERO`), which still updates immediately so round-start motion is responsive. **Monitoring:** if rapid cardinal flips while repeatedly idle feel wrong in play, revisit that idle fast-path; otherwise leave as-is. |
| Footprint vs art mesh drift | Prefer resolving half-extents from `CollisionShape2D` when possible; JSON overrides for tuning |

---

## 8. Testing / verification

**Manual steps:**  
- AI Player → round starts (HTTP only as required for **ARMED** handshake when using default flow) → scripted movement dodges without completion spam when `creature_motor.mode` is `scripted`.

**Automated:**  
- [tests/run_all.gd](../../tests/run_all.gd) — `pick_best_move_intent`, `cost_at_prediction`, [`filtered_intent` in scripted_intent_hold.gd](../../creature/motor/scripted_intent_hold.gd), `_test_mob_avoidance_acceptance` (repo `creature_motor.mode`, `InputMap` move actions, `playing_control_mode_int_for_motor_mode_string`).

---

## 9. Resolved / tracked items

| Item | Decision |
|------|----------|
| Start trigger | AI Player HUD path for **this phase**; multi-creature start semantics **later**. |
| Auto-START / zero server | **Out of scope** for v1; list under **Deferred enhancements**. |
| Clearance geometry | Predictive **AABB footprint** (`creature_half_extents`), not bare center-only distance. |
| Oscillation | **`scripted_intent_hold_physics_ticks`** default **5** (debounced ENGINE cardinal switch); HUMAN unaffected. |

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Initial motor plan + config contract. |
| 2026-05-11 | Control modes ENGINE vs AI, footprint clearance, oscillation explanation, deferred auto-START; acceptance criteria by mode. |
| 2026-05-11 | Scripted motor `scripted_intent_hold_physics_ticks` (**5**) + `scripted_intent_hold.gd`; section 7 mitigations finalized; humans keep instant keys. |
| 2026-05-11 | Doc sync: deferred hysteresis line removed; §5 marked complete; positive half-extents + asymmetries documented; idle-hold monitoring note. |
| 2026-05-11 | **Shipped:** acceptance criteria verified via `tests/run_all.gd`; `playing_control_mode_int_for_motor_mode_string` on `AiDriver`; document archived to `Completed_Features/`. |
