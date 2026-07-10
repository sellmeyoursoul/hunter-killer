# Hunter Killer — Combat (implementation tracking)

> **Status:** not started — blocked on [CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3) shipping. This file is "what's next": ordered build plan, acceptance criteria, risks, testing, and blocking prep work. **Delete this file once the feature ships to `main`** — it has no historical value once superseded by shipped code.
>
> **Contract:** [COMBAT_RESOLVED.md](COMBAT_RESOLVED.md) — read that first; this file assumes its formulas/schemas as given and only tracks build order and status.
>
> **Rationale for any decision below:** [COMBAT_HISTORY.md](COMBAT_HISTORY.md).

---

## 1. Blocking prerequisite — `stat_to_point()` (`SHARED_STATTOPOINT_PLAN.md`)

`stat_math.gd` does not yet exist. Combat cannot implement pool initialization (step 2 below) or pool recovery ([COMBAT_RESOLVED.md §6](COMBAT_RESOLVED.md)) without it. Gaps to resolve in [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md) first:

1. **`stat_num < 1` edge case** — stat 1 is the design floor (stat 0 is not a valid creature state). Resolution: clamp to 1, return `132.82`. Add a debug-build assertion. Update SHARED_STATTOPOINT_PLAN.md §4 edge-cases table.
2. **`stat_num > 25` loop verification** — the pseudocode loop in SHARED_STATTOPOINT_PLAN.md §4 needs test vectors for stat 26, 30, and 40 to confirm loop order matches design intent before production use.
3. **Create `res://creature/stat_math.gd`** — implement `stat_to_point(stat_num: int) -> float` with the lookup table (indices 1–25) and the `>25` extrapolation loop. Pass golden-value headless tests for stat 1, 10, 25, 26, 30 before wiring into any other system.

Standalone deliverable; unblocks both combat and recovery.

---

## 2. Ordered implementation plan

> **Gate:** do not begin step 1 (below) until [CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3) is complete and checked in, and prerequisite §1 above is done.

1. **`stat_to_point()` prerequisite** — see §1 above.
2. **Define action/reaction data resources** — `action_definition.gd` and `reaction_definition.gd` per [COMBAT_RESOLVED.md §4.3](COMBAT_RESOLVED.md). Author the base fox/rabbit action set ([COMBAT_RESOLVED.md §7](COMBAT_RESOLVED.md)).
3. **Add `combat_*` config keys** to `game_config_merge.gd` defaults: base variability band, cooldown defaults, observation unlock defaults, position-mod floor, size-threat floor/ceiling, disposition-bias constants ([COMBAT_RESOLVED.md §11.2](COMBAT_RESOLVED.md)); `combat_exp_ema_alpha`, `combat_exp_fast_ema_alpha`, `combat_exp_delta_strength`, `combat_exp_n_sat`, `combat_exp_n_min`, `combat_rank_chaos` ([COMBAT_RESOLVED.md §8, §10](COMBAT_RESOLVED.md)).
4. **Create `combat_math.gd`** — pure `resolve(action, reaction, attacker_stats, defender_stats, config) -> CombatResult` per [COMBAT_RESOLVED.md §4.4](COMBAT_RESOLVED.md); headless unit tests: full coverage blocks, zero coverage, depleted pool, flanked (no reaction).
5. **Create `creature_combat_component.gd`** — in-range check (§4.4's distance/arc math, no `Area3D`), action/reaction queue slots, cooldown timers, calls `combat_math.resolve`, applies pool spend, emits signals.
6. **Wire pool spend and overflow** — `spend_pool(pool_id, amount)` with stat wheel overflow at 2:1 ([COMBAT_RESOLVED.md §4.2](COMBAT_RESOLVED.md)).
7. **Wire `creature_defeated` signal** in `main_3d.gd` — fires from pool depletion, running alongside (not replacing) the existing `creature_predation_math.gd` calorie-transfer/round-end path ([COMBAT_RESOLVED.md §4.9](COMBAT_RESOLVED.md)).
8. **Sweep the salient-write carrier rename** — mechanical pass across the codebase and this doc set: rename the `MotorContext` carrier to whatever V3's salient-write-context ships as; change the producer from "sets a flag every tick" to "combat's outcome hook snapshots it once, at episode end"; keep the flag id `tactic_fight_active` itself unchanged ([COMBAT_RESOLVED.md §11.5](COMBAT_RESOLVED.md)). No new formula work — a rename plus a producer-timing correction.
9. **Create `combat_classifier.gd`** — sets `tactic_fight_active` on the (renamed) salient-write carrier at combat episode outcome.
10. **Create `combat_position_resolver.gd`** — pure functions: `resolve_combat_target(creature_pos, opponent_pos, action_def) -> Vector3` (closest valid arc point); `positional_modifier(creature_pos, opponent_pos, action_def) -> float` (1.0 at ideal position, attenuates to `combat_position_mod_floor`); in-range/arc test used in place of physics contact detection ([COMBAT_RESOLVED.md §4.4](COMBAT_RESOLVED.md)). Wire into action queuing (hard gate for `arc_required`) and into `combat_math.resolve` as `pos_mod`. Unit tests: ideal position → 1.0; outside arc → floor; `arc_required` gate blocks queue.
11. **Create `combat_experience_table.gd`** — per-creature instance; `record(prev_id, curr_id, outcome_score, effectiveness)` per [COMBAT_RESOLVED.md §8, §10](COMBAT_RESOLVED.md), updating both `weight` and `fast_weight` each call. Wire `record()` after each action resolves. Wire `combat_rank_score()` (§10, not raw `weight`) into action selection so novelty-vs-proven bias and confidence gate candidate ranking from the start. Unit tests: weight converges toward repeated outcome; unknown pair returns neutral; rank score favors low-`attempt_count` candidates under a Change-leaning creature and high-`attempt_count`/high-success candidates under a Stability-leaning creature; `delta_factor` pulls `confidence` down while `fast_weight` trends below `weight` (recent string of failures) even before lifetime `success_rate` moves.
12. **Enable `fight` modality salient write** — add `fight` to core modality resource; add the `fight_won` `GoalKind` to `CREATURE_GOAL_DRIVERS.md`'s registry (not yet present even as a stub — [COMBAT_RESOLVED.md §4.9](COMBAT_RESOLVED.md)); confirm `goal_source_memory.try_salient_write` emits `fight_won` (winner) / `avoid_hostiles` (loser) at episode end ([COMBAT_RESOLVED.md §4.8](COMBAT_RESOLVED.md)).
13. **Rewrite the jeopardy-urgency verification step against `urgency_flight`/`urgency_fight`'s actual resolved formulas** — the original step cited a V2-era `URGENCY_JEOPARDY` bitmask that does not exist in V3; verify instead against the continuous formulas in [COMBAT_RESOLVED.md §11.3](COMBAT_RESOLVED.md) and V3's `urgency_flight`.
14. **Wire observation-unlocked actions** — implement `observation_unlock_sec` gating in the queue system, scoped per opponent `instance_id` via `combat_observation_sec` ([COMBAT_RESOLVED.md §4.6, §11.1](COMBAT_RESOLVED.md)); wire the `stat_observation` reduction formula.
15. **Update `CREATURE_ATTRIBUTES_USAGE.md`** — promote each stat pool entry from Semantic/Reserved to Specified or Live as it is wired.

---

## 3. Acceptance criteria

- [ ] V3 motor refactor is complete and merged before implementation begins.
- [ ] `stat_to_point()` returns correct golden values for all eight stat pools on both archetypes.
- [ ] Fox and rabbit spawn with all `curr_point_*` pools at max.
- [ ] Fox in range of rabbit deals non-zero damage to the correct pool after action cooldown elapses.
- [ ] Reaction with full mitigation stat pool reduces damage vs undefended baseline.
- [ ] Lower `mitigation_coverage` produces less mitigation than higher coverage for the same reaction.
- [ ] Pool at 0 triggers overflow into adjacent wheel neighbor at 2:1 cost.
- [ ] Pool at 0 with no overflow path emits `creature_defeated`.
- [ ] `tactic_fight_active` is `true` on the salient-write carrier during active melee contact and `false` otherwise.
- [ ] `urgency_avoid_hostiles` is elevated above non-combat jeopardy baseline while fox is in contact.
- [ ] `fight` modality salient write fires at combat episode end.
- [ ] Actions with `observation_unlock_sec > 0` are not available for queuing before that duration has elapsed.
- [ ] Headless unit tests pass: resolve with known stat/pool inputs; mitigation coverage; overflow; defeat threshold.
- [ ] No hardcoded combat constants in `*.gd` files — all tuning via `game_config.json`.

---

## 4. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Distance/arc range check ([COMBAT_RESOLVED.md §4.4](COMBAT_RESOLVED.md)) doesn't account for walls/obstacles between combatants | Reuse V3 §8.1's line-of-sight check (same one awareness zones already use) as a gate before allowing an action to resolve |
| `stat_to_point()` not yet merged when combat work starts | Blocked by gate in §1/§2 above |
| Salient write `fight` modality not yet in engine core resource | Gate step 12 behind config flag `combat_enable_salient_write`; default `false` until ready |
| Pool overflow mechanic creates perverse incentives (creatures deliberately drain one pool to access a neighbor) | Tune 2:1 rate in play; may need a floor on overflow availability |
| Implementer reads a depleted pool's `curr_point_*` as something other than locked `0` (e.g. blends in overflow activity) when computing `pool_scale`/mitigation/band lookups | **Clarified** — overflow only changes which neighbor pool loses points to cover a cost; the depleted pool's own value stays `0` for every other calculation. See [COMBAT_RESOLVED.md §4.2](COMBAT_RESOLVED.md). Add a unit test asserting `pool_scale(0) == 0.25` still holds while a neighbor is being drained via overflow (step 4/6 in §2 above). |
| ~~V3 motor refactor changes `MotorContext` shape~~ | **Resolved** — V3 renames the carrier itself (§12.3.4); see [COMBAT_RESOLVED.md §11.5](COMBAT_RESOLVED.md), tracked as implementation step 8 above |
| ~~Combat and starvation predation both draining creature simultaneously~~ | **Resolved** — runs alongside, not unified; see [COMBAT_RESOLVED.md §4.9](COMBAT_RESOLVED.md) |
| ~~Observation-unlock timer resets on disengage/reengage~~ | **Resolved** — scoped per opponent instance, not per episode; see [COMBAT_RESOLVED.md §4.6, §11.1](COMBAT_RESOLVED.md) |

---

## 5. Testing / verification

**Automated:**
- Unit tests in `tests/run_all.gd` covering:
  - `resolve()` golden values (known stat pairs, pool levels, mitigation coverage → expected result).
  - Pool scale curve: 0% pool → 0.25 scale, 100% pool → 1.0 scale.
  - Mitigation coverage application (full vs partial vs no reaction).
  - Overflow spend: pool at 0 drains neighbor at 2:1.
  - Defeat fires when pool hits 0 with no overflow available.
  - Observation unlock gating: action not queueable before timer.

**Manual steps:**
- Open `main_3d.gd` scene; set `creature_motor.mode = "scripted"`.
- Confirm fox's action pool (endurance) visibly decreases on each attack attempt.
- Confirm rabbit's target pool decreases on successful hits.
- Confirm rabbit with higher `stat_dex` takes less damage from same fox attack than rabbit with lower `stat_dex`.
- Confirm round ends when critical pool reaches 0 with no overflow.
- Confirm `tactic_fight_active` flag visible in debug overlay during contact.
