# Dodge the Creeps — Design doc (agent-friendly)

> Cardinal motor for dodging mobs — foundation for future weighted utility (hunger, etc.). LLM is **not** the movement engine while `creature_motor.mode` is `scripted` ([AI_INT_CONVERSATION_SCOPE_PLAN.md](AI_INT_CONVERSATION_SCOPE_PLAN.md)).

---

## 1. Phase summary

**Phase name:** Mob avoidance — scripted cardinal motor (v1)

**One-line objective:** Each physics tick while engine-held control is active, choose a **4-way + idle** move intent by **minimizing a geometric cost** (inverse distance to mobs, closing-speed term, out-of-bounds penalty) so the playable creature steers away from threats without HTTP latency.

**Out of scope (explicit non-goals):**  
- Behavior-tree editor or third-party BT plugin.  
- Pathfinding / navmesh.  
- Changing mob spawn rules or RigidBody mob physics.  
- Removing or breaking the existing TinyLlama **ARMED** handshake / **PLAYING** `llm` path when `creature_motor.mode` is `llm`.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/dodge-the-creeps`

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** `main.tscn` → `AiDriver` autoload drives motor when AI session is **PLAYING** and mode is **scripted**.

**Key scripts (paths):**  
- [creature/motor/cardinal_avoidance.gd](../creature/motor/cardinal_avoidance.gd) — pure scoring / `pick_best_move_intent`.  
- [AI_int_lib/ai_driver.gd](../AI_int_lib/ai_driver.gd) — builds context from `Main` + `Player` scene node (`player.gd` body) + group `mobs`, calls motor, `set_creature_move_intent`; skips play-phase HTTP when scripted.
- [player.gd](../player.gd) — `set_creature_move_intent`, `ControlMode.HUMAN|ENGINE`, `speed`, `screen_size`.  
- [game_config.gd](../game_config.gd) / [AI_int_lib/game_config_merge.gd](../AI_int_lib/game_config_merge.gd) — `creature_motor` section.

**Existing patterns to follow:**  
- [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md)  
- [VISION_WORLD_BUILDER_PLAN.md](VISION_WORLD_BUILDER_PLAN.md), [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) for future weight hooks.

---

## 3. Requirements

### Must have

- `creature_motor.mode` ∈ `scripted` | `llm` (default **`scripted`** in merged defaults).  
- Pure `pick_best_move_intent(ctx: Dictionary) -> Vector2` with deterministic tie-break order: **UP, RIGHT, DOWN, LEFT**, then **ZERO**.  
- Out-of-bounds prediction uses same axis-aligned bounds as creature clamp (`bounds_min`, `bounds_max` in context).  
- When **scripted** + **PLAYING** + the playable creature is in **`ControlMode.ENGINE`**: no `/v1/completions` traffic for movement ticks; intent updated on physics cadence.  
- When **llm** + **PLAYING**: existing inference cadence unchanged.

### Should have

- Tunable weights and `lookahead_sec` via `creature_motor` JSON.

### Nice to have

- Second utility term (e.g. plant gradient) added to the same cost sum in a later phase.

---

## 4. Technical design

### Architecture / data flow

1. `AiDriver._physics_process` (when `PLAYING`, scripted, creature in `ControlMode.ENGINE`): gather mob `{ position, velocity }`, creature center `global_position`, `speed`, `screen_size`, merged motor params → `CardinalAvoidance.pick_best_move_intent(ctx)` → `set_creature_move_intent`.    
2. `AiDriver._process`: if `PLAYING` and scripted, **do not** `_enqueue_inference_request`; if `ARMED`, still enqueue handshake (START) so existing **AI Player** flow works when inference URL is configured.  
3. Optional: scripted users who want zero server can be a future doc (`scripted` auto-START); not v1.

### Context dictionary (`ctx`) — normative keys

| Key | Type | Meaning |
|-----|------|---------|
| `creature_position` | `Vector2` | World center used for prediction (typically `global_position` of the `Player` node / `player.gd`). |
| `creature_speed` | `float` | Max speed (px/s); matches `speed` on that body. |
| `lookahead_sec` | `float` | Horizons `speed * lookahead * dir`. |
| `bounds_min` | `Vector2` | Usually `(0, 0)`. |
| `bounds_max` | `Vector2` | Viewport size / clamp max. |
| `mobs` | `Array` | Elements `{ "position": Vector2, "velocity": Vector2 }` in world space. |
| `weight_dist` | `float` | Scale inverse-distance sum (default `1.0`). |
| `weight_closing` | `float` | Scale mob velocity component toward predicted point (default `0.5`). |
| `penalty_oob` | `float` | Cost if predicted center outside bounds (default `1e7`). |
| `distance_eps` | `float` | Floor for distance divisor (default `8.0` px). |

### Cost model (v1)

For candidate direction unit `d` (including `ZERO`):

- `predicted = creature_position + d * creature_speed * lookahead_sec`.  
- If `predicted` outside axis-aligned `[bounds_min, bounds_max]`, cost = `penalty_oob`.  
- Else: sum over mobs:  
  - `inv = 1 / max(distance_eps, distance(predicted, mob.position))`  
  - `cost += weight_dist * inv`  
  - Let `u = normalize(predicted - mob.position)`. If `mob.velocity.dot(u) > 0`, add `weight_closing * (mob.velocity.dot(u)) * inv` (mob moving toward predicted point).

Pick **minimum** cost; ties keep **earlier** direction in tie order.

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create | `res://creature/motor/cardinal_avoidance.gd` | Static API |
| modify | `res://AI_int_lib/game_config_merge.gd` | `creature_motor` defaults + merge |
| modify | `res://game_config.gd` | `get_creature_motor_params()` |
| modify | `res://AI_int_lib/ai_driver.gd` | Scripted branch + context build |
| modify | `res://game_config.json` | Document `creature_motor` keys |

### Collision / input / signals (if relevant)

- Uses same collision outcome as today (Area2D player vs mob bodies); motor only changes **intent**, not layers.

### Dependencies

- Mobs in group `mobs` ([mob.gd](../mob.gd)).

---

## 5. Implementation plan (ordered)

1. Land `cardinal_avoidance.gd` + unit tests.  
2. Merge `creature_motor` + `GameConfig.get_creature_motor_params()`.  
3. Wire `AiDriver` scripted path + skip play HTTP when scripted.  
4. Manual playtest: AI Player with inference for START only; movement scripted.

---

## 6. Acceptance criteria

- [ ] Default merged config has `creature_motor.mode` = `scripted`.  
- [ ] With `llm` mode, behavior matches pre-change inference cadence for PLAYING.  
- [ ] Headless tests cover east-approach mob, OOB penalty, tie order.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Oscillation at equal costs | Tie order + optional hysteresis later |
| Prediction ignores hitbox half-size | v1 uses center; refine with sampling AABB later |

---

## 8. Testing / verification

**Manual steps:**  
- AI Player → round starts → player dodges without completion spam when scripted.

**Automated (if any):**  
- [tests/run_all.gd](../tests/run_all.gd) — `pick_best_move_intent` pure cases.

---

## 9. Open questions

- <<Question: Scripted auto-START without llama-server for true offline AI demo?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Initial motor plan + config contract. |
