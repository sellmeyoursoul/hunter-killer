# Hunter Killer — Combat (draft)

> **Purpose:** Planning doc for adding direct combat mechanics between creatures. Covers the generalized creature-to-creature conflict interaction model (of which melee combat is the first instance), action/reaction queuing, damage resolution via stat pools, and the goal/motor integration points that allow conflict to be recognized and acted upon as a distinct Tier-2 goal state.
>
> **Tier:** Draft (tier II) — **no implementation begins until the V3 motor refactor ([CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)) is complete and checked in.** This doc is design-only until that gate clears. Promote to `Definitive_Features/` when design is stable and implementation starts.
>
> **Dependencies (read these first):**
> - **[CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)** — point pool schema (`max_point_*`, `curr_point_*`); stat baselines.
> - **[SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md)** — `stat_to_point` conversion that combat will use to derive point pools from stats.
> - **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)** — motivation tree, `GoalKind` registry, `fight` modality stub, trait axis meanings, `tactic_fight_active` classifier flag.
> - **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** — the active motor refactor that defines `MotorContext`, urgency channels, and the pipeline combat will integrate with. **Combat implementation is gated on this work shipping.**
> - **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** — salient write gates, locale priors; combat outcomes will produce salient writes keyed on `avoid_hostiles` / future `fight_won` `GoalKind`.
> - **[CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)** — authoritative stat pool definitions and intended mechanics. Update that file when combat wires a stat pool into code.

---

## 1. Phase summary

**Phase name:** Combat — generalized creature conflict, action/reaction system, and damage resolution

**One-line objective:** Allow two creatures with conflicting goals to exchange actions and reactions against point pools, with outcome signals that feed motor urgency, memory salient writes, and the `fight` tactic classifier.

**Implementation gate:** Combat work does not start until **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** is complete and merged. This doc exists to capture design decisions so combat can be planned in parallel with V3 without creating dependencies on the superseded V2 design.

**Out of scope (explicit non-goals):**
- Ranged or projectile attacks.
- Pack coordination or group-combat orchestration (reserved in **[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)** trait preamble).
- Trait drift or experience-driven stat change.
- Balance pass — this is a mechanical plumbing spec, not an economy spec.
- Saving or persisting combat history across sessions.
- Conspecific combat (creature vs. same species); this phase targets the existing fox-vs-rabbit duel only.
- Full action/reaction library (skill trees) — see §11.
- Graduated partial-deal resolution for barter-type interactions — explicitly deferred.

**Canonical name: Resisted Actions subsystem.** See §11.5 for naming conventions and file/class prefix rules.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot 4.6

**Main scenes / entry:**
- `res://main_3d.gd` — round lifecycle; combat round-end condition hooks go here.
- `res://creature/capabilities/creature_vitals_component.gd` — existing calorie + predation math; point pool consumption is a sibling concern.
- `res://creature/capabilities/creature_kinematic_body_3d.gd` — collision body; contact detection lives here or in a dedicated combat component.

**Key scripts (paths — planned or existing):**

| Status | Path | Role |
|--------|------|------|
| existing | `res://creature/capabilities/creature_vitals_component.gd` | Calorie burn, starvation — combat damage is additive drain on separate point pools |
| existing | `res://creature/capabilities/creature_vitals_math.gd` | Pure calorie math; combat math follows same pure-function pattern |
| planned | `res://creature/capabilities/creature_combat_component.gd` | Contact detection, action/reaction queue, damage dispatch; sibling to vitals |
| planned | `res://creature/combat/combat_math.gd` | Pure stat → damage formulas (no Node state); headless-testable |
| planned | `res://creature/stat_math.gd` | `stat_to_point()` — per [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md); may already exist |
| planned | `res://creature/motor/combat_classifier.gd` | Sets `tactic_fight_active` on `MotorContext`; feeds salient emitter |
| planned | `res://creature/combat/action_definition.gd` | Data resource: cost stat, outcome stat, target region, trait affinities, threshold, cooldown, positional criteria |
| planned | `res://creature/combat/reaction_definition.gd` | Data resource: cost stat, mitigation stat, coverage profile, trait affinities, cooldown, context set |
| planned | `res://creature/combat/combat_position_resolver.gd` | Pure function: action criteria + positions → target `Vector3` for seek planner and positional modifier float |
| planned | `res://creature/combat/combat_experience_table.gd` | Per-creature transition pair table (`prev_action_id → curr_action_id → weight`); updated from combat outcome signals |
| planned (tentative — see §11.10 `<<Question>>`) | `res://creature/combat/combat_experience_math.gd` | Pure `rank_score(weight, attempt_count, success_count, marginal_attempt_count, marginal_success_count, traits, axis_config, n_sat, n_min) -> float`; shared novelty-vs-proven ranking formula (with pair/marginal hierarchical backoff), reused by the self-experience table, opponent-observation table, and spatial overlay via a generalized `trait_rank_bias(traits, axis_config)` sub-helper — each table supplies its own `axis_config` (primary axis + optional gated modifier axes) instead of forking the formula |

**Existing patterns to follow:**
- Pure-function math modules (no Node refs) → headless unit tests in `tests/run_all.gd`.
- Sibling component pattern: `creature_vitals_component.gd` / `creature_predation_math.gd` — combat follows the same split.
- Signal-based outcome notification: vitals already emits starvation / predation signals; combat emits parallel signals.
- Config keys live in `game_config_merge.gd` defaults, never hardcoded.
- Follow [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md) and [`gdscript.mdc`](../../.cursor/rules/gdscript.mdc).

---

## 3. Requirements

### Must have

- Action/reaction queue per creature: each creature maintains one queued action (offensive, fires on cooldown) and one queued reaction (defensive, fires when triggered). Each tick, the creature's goal/AI system picks what to queue next.
- Resolution formula: determines whether a queued action lands and how much damage it deals, accounting for the queued reaction. Lives in `combat_math.gd`.
- Point pool drain: successful actions reduce one or more of the target's `curr_point_*` pools.
- Stat wheel overflow: when a pool hits 0, the creature may pay action/reaction costs from an adjacent pool at 2:1 rate.
- Engagement persistence driven by goal system: combat does not have a special end-state machine. Each creature re-evaluates goals each tick; disengagement happens naturally when the cost of continuing exceeds the expected benefit.
- Motor recognition: `tactic_fight_active` flag set on the V3 motor context struct when a combat episode is active.
- Death outcome: creature with a critical pool at 0 with no overflow path signals defeat.

### Should have

- Action cooldowns enforced per creature per action type.
- Reaction cooldown: after a reaction fires, it enters cooldown and the creature queues a replacement next tick.
- Observation-unlocked actions: a subset of actions and reactions become available only after combat has been active for a configurable duration (the creature has had time to learn the opponent's patterns).
- Composure drain via intimidation: composure pool depletion degrades action/reaction selection quality and feeds persistence logic.
- Flee urgency boost: active combat contact raises `urgency_avoid_hostiles` above baseline jeopardy levels.
- Salient write on combat outcome per **[CREATURE_GOAL_DRIVERS.md §4.1](CREATURE_GOAL_DRIVERS.md)**.

### Nice to have

- Hit reaction animation signal (visual only).
- Damage-over-time bleed stub (reserved field, no behavior).
- Context-scoped reaction sets: combat reactions vs. social reactions loaded separately based on interaction type.

---

## 4. Technical design

> **Note:** The data flow below references `MotorContext` and urgency channels as they will be defined by **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)**. Exact field names and integration points must be reconciled against V3 once it ships before this section is treated as authoritative.

---

### 4.1 Generalized conflict model

Combat is the first instance of a broader **creature-to-creature conflict** pattern: two creatures whose current goals are incompatible attempt to resolve that conflict through a sequence of actions and reactions. The same mechanical substrate will eventually cover mating contests and barter negotiations.

**Key terminology:**
- **Initiator** — the creature whose goal requires a change in the other creature's behavior (fox wants to eat the rabbit).
- **Responder** — the creature whose current goal is disrupted by the initiator (rabbit wants to not be eaten).
- These roles are not fixed. If the responder overpowers the initiator, roles may flip: the original initiator's dominant goal becomes flee, and the original responder decides whether to pursue.

**Resolution is emergent — not a state machine:**
There is no explicit "combat ends" condition. Each creature re-evaluates its goal weights every tick. When the cost of continuing (depleted pools, injury risk) exceeds the expected gain (meal, safety), the creature's goal system naturally shifts to a different dominant goal (flee, forage, etc.). The conflict ends when neither creature's dominant goal requires the other's participation.

**Engagement forcing:**
Some actions (e.g. a Dex-reducing attack) can make the responder's flee goal harder to execute even when it is dominant, by degrading the motor capability needed to carry it out. This is a natural extension — it modifies the responder's stats, which the goal system then operates on.

**Interaction types and reaction sets:**
Reaction slots are context-scoped. A combat encounter loads a combat reaction set (dodge, block, counterattack). A social encounter loads a different set. The active context is resolvable from the creature's current dominant goal and the `tactic_fight_active` (or equivalent) classifier flag.

---

### 4.2 Stat pools and the stat wheel

All eight creature stats participate in combat. Each stat has a `curr_point_*` pool derived from `stat_to_point(stat_*)` at spawn (full on spawn; spent during combat).

**Stat wheel (overflow order):**
```
Fit → End → Will → Comp → Obs → Charm → Wit → Dex → Fit (wraps)
```
When a pool hits 0, the creature may pay costs from either adjacent pool at **2:1 rate**. The creature (or action definition) chooses which neighbor to drain.

**Stat roles in conflict:**

| Stat | Pool | Combat role |
|------|------|-------------|
| `stat_fit` | `curr_point_fit` | Damage output — strength of offensive actions |
| `stat_endurance` | `curr_point_end` | Action/reaction cost — primary resource spent per exchange |
| `stat_will` | `curr_point_will` | Persistence — creature pushes through injury; high will raises the threshold before goal tips to flee |
| `stat_composure` | `curr_point_comp` | Decision quality — depleted by intimidation; low composure degrades action/reaction selection; feeds persistence logic |
| `stat_observation` | `curr_point_observ` | Unlocks advanced actions/reactions after sustained combat (creature learns opponent patterns); may gate reaction triggering (flanked = reaction blocked) |
| `stat_charm` | `curr_point_charm` | Intimidation actions — drain target's composure |
| `stat_wit` | `curr_point_wit` | Feints — actions targeting the opponent's reaction slot rather than a stat pool |
| `stat_dexterity` | `curr_point_dex` | Reaction effectiveness — mitigation stat for dodge/counter; also affects flee capability |

---

### 4.3 Action and reaction data shape

Every action and reaction is a data resource with these fields:

**Action definition:**
```
action_id             : StringName  # stable key used by experience table and memory writer
costs                 : Array       # [{stat: String, amount: float}, ...] — multi-stat cost support
outcome_stat          : String      # which attacker stat drives damage (e.g. "fit")
secondary_effects     : Array       # [{pool: String, amount: float}, ...] — flat pool damage on landing
                                    # target_region removed (specific point targets out of scope this phase)
trait_tags            : Array       # pole affinities — creature prefers this action when aligned (e.g. ["self_interest"])
threshold             : float       # minimum net result for the action to land
cooldown_ticks        : int         # ticks before this action can be queued again
observation_unlock_sec : float      # seconds of active combat before this action becomes available (0 = always)
outside_influence_key : String      # optional: config key for location/item modifier
preferred_range       : float       # optimal distance from opponent centre (metres); 0 = no preference
preferred_arc_deg     : float       # angular window centred on attacker's forward; 0 = any angle
arc_required          : bool        # true → not queueable until attacker is within preferred_arc_deg of opponent
requires_flanking     : bool        # true → not queueable unless attacker is outside defender's awareness arc
position_weight       : float       # urgency multiplier applied to combat positioning goal while this action is queued
```

**Reaction definition:**
```
reaction_id              : StringName  # stable key used by experience table
costs                    : Array       # [{stat: String, amount: float}, ...] — multi-stat cost support
cost_incoming_fraction   : float       # when non-zero: cost = incoming_damage × this; overrides costs entries
mitigation_stats         : Array       # stats contributing to defender_raw (may be empty)
mitigation_type          : String      # formula path: "stat_modifier" | "pool_ratio" | "stat_modifier_sum"
mitigation_cap           : float       # upper bound for "pool_ratio" type; ignored by other types
mitigation_coverage      : float       # flat 0.0–1.0 multiplier on reaction effectiveness (replaces region coverage dict)
                                       # coverage dict removed (specific point targets out of scope this phase)
secondary_effects        : Array       # [{pool: String, amount: float}, ...] — flat pool effect dealt to attacker on fire
damage_reduction_per_sec : float       # flat damage reduction per second of fight duration (0 = disabled)
damage_reduction_max     : float       # cap on the above
embeds_queued_action     : bool        # true → queued action fires as part of this reaction; both cooldown independently
trait_tags               : Array       # pole affinities for AI queuing preference
cooldown_ticks           : int
context_set              : String      # "combat", "social", etc.
trigger_predicates       : Array       # typed predicate dicts; ALL must pass for the reaction to fire
                                       # implemented this phase: "positional_awareness", "incoming_damage_nonzero"
                                       # reserved: "composure_floor", "interaction_context", negotiation predicates
```

---

### 4.4 Resolution formula

The formula determines the net impact of an action against a queued reaction. It is hybrid: stats set the range, variance determines whether it lands.

```
# Attacker side
stat_max_mod_att  = stat_to_point(action.outcome_stat_value) - stat_to_point(10)
curr_scale_att    = pool_scale(curr_point / max_point)          # curve: 0.25 at empty → 1.0 at full
outside_att       = config.get(action.outside_influence_key, 0.0)

attacker_raw = BASE(-10)
             + stat_max_mod_att
             + stat_max_mod_att * curr_scale_att                # current pool amplifies/reduces max modifier
             + outside_att

# Defender side (reaction)
coverage_mult     = reaction.coverage.get(action.target_region, 0.0)
stat_max_mod_def  = stat_to_point(reaction.mitigation_stat_value) - stat_to_point(10)
curr_scale_def    = pool_scale(curr_point_def / max_point_def)
outside_def       = config.get(reaction.outside_influence_key, 0.0)

defender_raw = (stat_max_mod_def + stat_max_mod_def * curr_scale_def + outside_def) * coverage_mult

# Positional modifier (1.0 at ideal range/arc; attenuates to combat_position_mod_floor when off-position)
# arc_required = true → action not queueable outside arc; this modifier only applies to soft-gated actions
position_mod = CombatPositionResolver.positional_modifier(attacker_pos, opponent_pos, action)

# Resolution
net       = (attacker_raw - defender_raw) * position_mod
result    = net + randf_range(-variability, variability)        # variability configured per action tier
lands     = result > action.threshold
damage    = result if lands else 0.0
```

**`pool_scale(ratio)` contract:** curve from `0.25` (pool empty) to `1.0` (pool full). Exact curve shape is a tuning parameter; the `[0.25, 1.0]` range is normative. A depleted creature is degraded, not nullified.

**`stat_to_point(10)` as zero anchor:** stat 10 is the default. A creature at stat 10 contributes 0 modifier. Above-average stats add a diminishing positive; below-average adds a negative. Diminishing returns apply symmetrically — a creature with stat 1 is at a large disadvantage vs stat 10, but only a small disadvantage vs stat 2.

**Coverage multiplier:** the action's `target_region` is looked up in the reaction's `coverage` dict. Duck covers the head fully (`1.0`) but the leg poorly (`0.4`). A reaction with no entry for the targeted region provides zero mitigation.

**No reaction queued / reaction on cooldown:** `coverage_mult = 0`, `defender_raw = 0`. Undefended hit; full attacker roll vs threshold.

**Observation check (reaction gating):** if the attacker's approach angle is outside the responder's awareness cone (flanked), the reaction does not trigger regardless of queue state. The responder's `stat_observation` governs the cone width.

**Illustrative example — fox bites rabbit (leg), rabbit has duck queued:**
```
Fox:    stat_fit=14, curr_point_fit=80%, outside=0
Rabbit: stat_dex=12, curr_point_dex=60%, outside=0, duck.coverage["leg"]=0.4

stat_max_mod_att  = stat_to_point(14) - stat_to_point(10)  →  positive delta
curr_scale_att    = pool_scale(0.80)                        →  ~0.87
attacker_raw      = -10 + delta + delta*0.87 + 0           →  some positive number

coverage_mult     = 0.4
stat_max_mod_def  = stat_to_point(12) - stat_to_point(10)  →  smaller positive delta
curr_scale_def    = pool_scale(0.60)                        →  ~0.70
defender_raw      = (def_delta + def_delta*0.70) * 0.4     →  reduced because leg duck is weak coverage

net     = attacker_raw - defender_raw                       →  positive (fox favored)
result  = net + variance
lands if result > bite_threshold
```
If rabbit had duck covering the head and fox had targeted the head, `coverage_mult = 1.0` and the defender_raw is roughly 2.5× larger — bite likely fails or deals minimal damage.

---

### 4.5 Feints and wit

A feint is an action whose `outcome_stat` is `wit` and whose effect on landing is **not** pool damage but **reaction slot burn**: the responder's queued reaction fires (spending its cost) against nothing, and enters cooldown. The responder's own `wit` or `observation` stat determines whether they read the feint and withhold their reaction.

<<Comment: The exact feint detection formula (wit vs wit check, observation modifier) is not yet specified. Define when the feint action definition is authored.>>

---

### 4.6 Observation-unlocked actions

Each action and reaction has an `observation_unlock_sec` field. Until the combat episode has been active for at least that many seconds, the action/reaction is not available for queuing. High `stat_observation` reduces the unlock time (the creature reads the opponent faster).

<<Comment: The exact formula for observation_unlock_sec reduction from stat_observation is not yet specified. First-pass: `effective_unlock = observation_unlock_sec * (stat_to_point(10) / stat_to_point(stat_observation))` — tune in play.>>

---

### 4.7 Persistence and disengagement

Each tick, each creature re-evaluates its dominant goal. A creature disengages when some combination of the following tips the goal weight away from the conflict:

- **Pool depletion:** `curr_point_end`, `curr_point_fit`, and `curr_point_will` are low. `stat_will` raises the threshold before the goal tips.
- **Composure degradation:** low `curr_point_comp` makes the creature make poorer action/reaction decisions, which in turn accelerates pool loss. Intimidation attacks target this directly.
- **Goal urgency shifts:** an external event (starvation, a higher-priority threat) raises a competing goal above the conflict's urgency weight.

The motor system does not need a "flee from combat" special path. When `avoid_hostiles` urgency rises above the combat goal weight, the creature's seek target shifts naturally. The opponent may or may not pursue based on their own goal evaluation.

---

### 4.8 Architecture / data flow

```
── Established goal→objective→action pipeline (unchanged) ──────────────────
AiDriver._physics_process()
  ├─ evaluates all goal weights each tick (urgency channels, trait modifiers,
  │   pool states, tactic_fight_active multiplier from MotorContext)
  ├─ dominant goal resolves into sub-step objectives (seek target, motor intent)
  │    └─ when fight/flight is dominant:
  │         CombatPositionResolver.resolve_combat_target(pos, opponent_pos, queued_action)
  │         → Vector3 fed to SeekPlanner as ultimate_goal this tick
  └─ sub-step objectives resolve into queued action/reaction:
       candidate actions filtered by: cooldown elapsed, observation_unlock_sec, arc_required
       selection: highest combat_rank_score(trait_affinity, experience_table entry, change_stability) — §11.10
       → action/reaction slots written to CreatureCombatComponent

── Combat mechanical resolution (reads from the above; does not drive goals) ─
CreatureKinematicBody3D._physics_process()
  └─ CreatureCombatComponent._on_physics_tick()
       ├─ contact_test(other_body) → bool
       ├─ if contact && action_cooldown_elapsed:
       │    pos_mod = CombatPositionResolver.positional_modifier(pos, opponent_pos, action)
       │    result  = CombatMath.resolve(action, reaction, attacker_stats, defender_stats, config, pos_mod)
       │    if result.lands:
       │      defender.spend_pool(result.target_pool, result.damage)
       │      experience_table.record(prev_action_id, action.action_id, result.outcome_score)
       │    set tactic_fight_active = true on MotorContext (V3 struct)
       │    emit signal: combat_hit(attacker, defender, result)
       └─ if any pool hits 0 with no overflow path:
            emit signal: creature_defeated(creature)
            → main_3d.gd._on_creature_defeated()
            → AiDriver: goal_source_memory.try_salient_write(...)
                 GoalKind: avoid_hostiles (loser) or future fight_won (winner)
                 modality_tags: [fight]
                 outcome_envelope: defeat / victory
```

---

### 4.9 Dependencies

- **V3 motor refactor ([CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)) must be complete and merged** before any combat implementation begins.
- **`stat_to_point()`** from **[SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md)** must exist before combat point pools can be initialized.
- **`tactic_fight_active`** flag — stub in **[CREATURE_GOAL_DRIVERS.md §5.1.1](CREATURE_GOAL_DRIVERS.md)**; V3 defines the struct that carries it.
- **`fight` modality** in core modality allowlist — stub in **[CREATURE_GOAL_DRIVERS.md §5 modality table](CREATURE_GOAL_DRIVERS.md)**; must be promoted to the engine core modality resource as part of or after V3.
- **[CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)** — update §3 per-stat entries to **Specified** or **Live** as each pool is wired.

---

## 5. Implementation plan (ordered)

> **Gate:** Do not begin step 1 until **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** is complete and checked in.

1. **`stat_to_point()` prerequisite** — confirm `res://creature/stat_math.gd` exists and passes golden-value tests.
2. **Define action/reaction data resources** — `action_definition.gd` and `reaction_definition.gd` with fields per §4.3. Author the base fox/rabbit action set (bite, duck/dodge as illustrative minimum).
3. **Add `combat_*` config keys** to `game_config_merge.gd` defaults: base variability band, cooldown defaults, observation unlock defaults, contact radius.
4. **Create `combat_math.gd`** — pure `resolve(action, reaction, attacker_stats, defender_stats, config) -> CombatResult`; write headless unit tests covering: full coverage blocks, zero coverage, depleted pool, flanked (no reaction).
5. **Create `creature_combat_component.gd`** — contact detection, action/reaction queue slots, cooldown timers, calls `combat_math.resolve`, applies pool spend, emits signals.
6. **Wire pool spend and overflow** — implement `spend_pool(pool_id, amount)` with stat wheel overflow at 2:1.
7. **Wire `creature_defeated` signal** in `main_3d.gd` — replace or extend existing predation-based round-end path.
8. **Create `combat_classifier.gd`** — sets `tactic_fight_active` on the V3 MotorContext struct while combat contact is active; clears on timeout or defeat.
9. **Create `combat_position_resolver.gd`** — pure functions: `resolve_combat_target(creature_pos, opponent_pos, action_def) -> Vector3` (closest valid arc point); `positional_modifier(creature_pos, opponent_pos, action_def) -> float` (1.0 at ideal position, attenuates to `combat_position_mod_floor`). Wire into action queuing (hard gate for `arc_required`) and into `combat_math.resolve` as `pos_mod` argument. Unit tests: ideal position → 1.0; outside arc → floor; `arc_required` gate blocks queue.
10. **Create `combat_experience_table.gd`** — per-creature instance; `record(prev_id, curr_id, outcome_score)` via EMA; entries carry `weight` (EMA), `attempt_count`, `success_count` per §11.10. Wire `record()` call into `creature_combat_component` after each action resolves. Wire `combat_rank_score()` (§11.10, not raw `weight`) into action selection in the goal→objective→action pipeline, so novelty-vs-proven bias and confidence gate candidate ranking from the start rather than being retrofitted later. Unit tests: weight converges toward repeated outcome; unknown pair returns 1.0; rank score favors low-`attempt_count` candidates under a Change-leaning creature and favors high-`attempt_count`/high-success candidates under a Stability-leaning creature (§11.10 worked example).
11. **Enable `fight` modality salient write** — add `fight` to core modality resource; confirm `goal_source_memory.try_salient_write` emits correct `GoalKind` at episode end.
10. **Raise jeopardy urgency on active combat** — verify `URGENCY_JEOPARDY` bitmask contributor fires when `tactic_fight_active` is set (per **[CREATURE_GOAL_DRIVERS.md §5.1.3](CREATURE_GOAL_DRIVERS.md)**).
11. **Wire observation-unlocked actions** — implement `observation_unlock_sec` gating in the queue system; wire `stat_observation` reduction formula.
12. **Update `CREATURE_ATTRIBUTES_USAGE.md`** — promote each stat pool entry from Semantic/Reserved to Specified or Live as it is wired.

---

## 6. Acceptance criteria

- [ ] V3 motor refactor is complete and merged before implementation begins.
- [ ] `stat_to_point()` returns correct golden values for all eight stat pools on both archetypes.
- [ ] Fox and rabbit spawn with all `curr_point_*` pools at max.
- [ ] Fox in contact with rabbit deals non-zero damage to the correct pool after action cooldown elapses.
- [ ] Duck reaction with full `curr_point_dex` reduces damage vs undefended baseline.
- [ ] Duck coverage for leg target (`0.4`) produces less mitigation than duck coverage for head target (`1.0`).
- [ ] Pool at 0 triggers overflow into adjacent wheel neighbor at 2:1 cost.
- [ ] Pool at 0 with no overflow path emits `creature_defeated`.
- [ ] `tactic_fight_active` is `true` on V3 MotorContext during active melee contact and `false` otherwise.
- [ ] `urgency_avoid_hostiles` is elevated above non-combat jeopardy baseline while fox is in contact.
- [ ] `fight` modality salient write fires at combat episode end.
- [ ] Actions with `observation_unlock_sec > 0` are not available for queuing before that duration has elapsed.
- [ ] Headless unit tests pass: resolve with known stat/pool inputs; coverage multiplier; overflow; defeat threshold.
- [ ] No hardcoded combat constants in `*.gd` files — all tuning via `game_config.json`.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| V3 motor refactor changes `MotorContext` shape after combat design is drafted | Treat §4 data flow as provisional until V3 ships; reconcile field names before step 8 |
| `stat_to_point()` not yet merged when combat work starts | Blocked by gate in §5 |
| Contact detection false positives near walls | Directional filter: only register a hit if attacker is closing (dot product of attacker velocity and attacker→defender vector is positive) |
| Combat and starvation predation both draining creature simultaneously | Decide in step 6 whether `creature_predation_math.gd` calorie-transfer and pool drain are unified or separate; document here |
| Salient write `fight` modality not yet in engine core resource | Gate step 9 behind config flag `combat_enable_salient_write`; default `false` until ready |
| Pool overflow mechanic creates perverse incentives (creatures deliberately drain one pool to access a neighbor) | Tune 2:1 rate in play; may need a floor on overflow availability |
| Observation-unlock timer resets on disengage/reengage | Decide whether timer is per-episode or per-opponent; document in action_definition |

---

## 8. Testing / verification

**Automated:**
- Unit tests in `tests/run_all.gd` covering:
  - `resolve()` golden values (known stat pairs, pool levels, coverage → expected result).
  - Pool scale curve: 0% pool → 0.25 scale, 100% pool → 1.0 scale.
  - Coverage multiplier application (head vs leg vs no reaction).
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

---

## 9. Open questions

- ~~What is the canonical name for the generalized conflict system?~~ **RESOLVED: Resisted Actions subsystem. See §11.5.**
- <<Question: Contact detection — `Area3D` child node on creature template vs. polling `get_slide_collision_count()` results? Area3D is cleaner for radius-based melee but adds a node per creature.>>
- <<Question: What happens to the existing `creature_predation_math.gd` calorie-transfer logic (predator gains calories on kill)? Should `creature_defeated` replace the predation clamp entirely, or run alongside it?>>
- <<Question: Should combat define a new pack-extension `GoalKind` (e.g. `fight_won`) for the winner's salient write, or map winning combat to `find_food` (predator ate) at the kill moment?>>
- <<Question: Once V3 ships, reconcile exact `MotorContext` field names and urgency channel API against the data flow in §4.8 before implementation begins.>>
- <<Question: Feint detection formula — when the responder can "read" a feint and withhold their reaction. Wit vs. wit check? Observation modifier? Define when feint action is authored.>>
- <<Question: Observation-unlock timer — per combat episode or per opponent pair? Resets on disengage/reengage?>>
- <<Question: Should `curr_point_will` directly modify the urgency weight calculation for `avoid_hostiles` (low will → lower threshold for fleeing), or does will act purely through the pool drain / combat math side?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-06-22 | Initial draft created. Queued behind V3 motor refactor. |
| 2026-06-22 | Removed all references to CREATURE_MOVEMENT_V2 (dead end). Updated all motor pipeline references to CREATURE_MOVEMENT_V3. Added explicit implementation gate. |
| 2026-06-22 | Major design session. Replaced placeholder formula with full resolution model. Added: generalized conflict model (initiator/responder), action/reaction queue system, stat wheel with overflow, pool_scale curve, coverage multiplier, feints, observation-unlocked actions, persistence model, illustrative fox/rabbit example. Stat role table added per CREATURE_ATTRIBUTES_USAGE.md. |
| 2026-06-24 | §11.6 resolved: test action/reaction set defined (Bite, Ankle Bite, Absorb, Dodge, Bite Back, Counter Strike). Data shape updated: costs array replaces singular cost_stat/cost_amount; target_region and coverage dict removed (out of scope); secondary_effects, requires_flanking, mitigation_type, mitigation_cap, cost_incoming_fraction, embeds_queued_action, damage_reduction_per_sec/max added. Three mitigation types defined: stat_modifier, pool_ratio, stat_modifier_sum. incoming_damage_nonzero added as new trigger predicate type. §4.3 action and reaction data shapes updated to match.
| 2026-06-24 | §11.3 resolved: continuous per-second pool recovery; 4 activity states with config multipliers; fill_time curve (exponent 0.25, base 100s at stat 10) yields 56s–126s range across stat 1–25; full rate table documented. §11.8 added: stat_to_point prep work itemized as blocking prerequisite — edge case resolution, loop verification, and stat_math.gd creation. Recovery and position resolver implementation steps added to §5.
| 2026-06-24 | §11.2 resolved: no combat motor sub-mode; positioning driven by action definitions via CombatPositionResolver feeding SeekPlanner unchanged; hard/soft arc gate design. §4.3 action definition extended with `action_id`, `preferred_range`, `preferred_arc_deg`, `arc_required`, `position_weight`. §4.4 resolution formula adds positional modifier. §4.8 data flow updated to show established goal→objective→action pipeline as primary layer; combat resolution as mechanical consumer. §11.7 added: per-creature transition pair experience table (EMA update, cold start, future inheritance via reproduction). Planned files table updated. |
| 2026-06-25 | §11.9 spatial overlay open questions resolved: update trigger is on action resolve (landed or failed, outcome score drives EMA direction); bias keys derived from action definition positional fields at runtime; initial value 0.0 for all keys. |
| 2026-06-25 | §11.9 added: opponent observation table design stub. Covers write trigger (on action resolve, not awareness-gated), per-creature-lifetime scope, 25%-rate EMA stub, action-id agnostic keying, separate-but-aligned interface with self-table, positional overlay Option B with two open questions, inheritance cross-ref. Enhancement backlog entries added for: full-rate skill gate, scalability cap, spatial overlay implementation. |
| 2026-06-23 | §11.1 expanded: gates 1–3 confirmed. Gate 4 reframed as typed positional predicates with awareness zone terminology locked (plain language: "awareness zone", "awareness arc", "flanked"). Predicate list design extended to cover non-positional gates (composure threshold, interaction context, future negotiation factors). `trigger_predicates : Array` field proposed for reaction definition; pending confirmation. |
| 2026-07-01 | §11.10 added: novelty-vs-proven exploration bias brought into scope (no longer deferred) — new/unlocked actions were at risk of being permanently starved by an already-reinforced favorite under naive argmax selection. Resolved to transplant the existing `change_stability` Slot B rank-bias + confidence formula (CREATURE_GOAL_DRIVERS.md §5.1.2) rather than invent a new mechanism; selection-rule options (ranked argmax / softmax / epsilon-greedy) evaluated, ranked argmax recommended. Same mechanism proposed for reuse across self-experience table (§11.7), opponent-observation table, and spatial overlay (§11.9), with per-table saturation constants and other differences flagged as open questions. §11.7 header/prose updated to drop stale "deferred — post first-phase" framing (contradicted §5 step 10, which already schedules it this phase). §4.8 and §5 step 10 updated to reference `combat_rank_score` instead of raw weight. Planned-files table (§2) gets a tentative shared-math-module row pending an open question on file/class shape. |
| 2026-07-01 | §11.10 tie-break resolved: reused `CREATURE_MOVEMENT_V3`'s `blocked_objective_chaos` / `goal_consideration_chaos` precedent — new `combat_rank_chaos` key applies RNG jitter on near-tied `combat_rank_score` values, not just exact ties. Explicitly scoped: chaos resolves close calls only, does not override a large persistent gap (which is what `trait_rank_bias` is meant to produce for a strongly Stability-leaning creature). Noted a high-Stability creature never trying new actions is intended personality expression, not a bug — deferred any stronger forced-exploration mechanism (decay term, wider chaos band, forced-trial floor) until playtesting shows it's actually a problem. |
| 2026-07-01 | §11.9/§11.10 saturation-constant question resolved: confirmed the opponent-observation/spatial-overlay 25%-rate throttle (§11.9) is an alpha dampener on `weight` only — `attempt_count`/`success_count` still increment 1:1 with real occurrences. Since `evidence`/`thin_cap` key off `attempt_count`, not `weight`, all three tables (self, opponent-observation, spatial overlay) share `combat_exp_n_sat` / `combat_exp_n_min` with no per-table scaled variants needed. Removed the now-resolved `<<Question>>`; the spatial overlay's remaining open question is narrowed to whether the novelty/proven lerp is meaningful for a continuous signed bias, not saturation scaling. |
| 2026-07-01 | §11.10 pair-vs-action-level tracking resolved: adopted hierarchical backoff (Option C) — pair table stays the source of truth for `weight` and ranking, but a lightweight `curr_action_id`-keyed marginal aggregate (`O(actions)`, updated incrementally alongside pair writes) supplies fallback `evidence`/`success_rate` when a pair is thin, blended via the pair's own `thin_cap` as blend weight (no new tunable). Solves the scalability fragmentation concern (a proven action reached from many priors no longer reads as permanently novel on each individual pair) while keeping sequence-specific `weight` untouched. `combat_experience_math.gd`'s planned signature (§2) updated to take marginal counts. Two new `<<Question>>`s opened: whether `weight` itself should also warm-start from the marginal, and whether the opponent-observation table needs the same marginal treatment (spatial overlay likely exempt — not pair-keyed). |
| 2026-07-01 | §11.10 two follow-up questions resolved. (1) Option C (hierarchical backoff) confirmed as the selected design, not just recommended; `weight` confirmed to stay un-blended (no marginal warm-start) — a new pair still initializes at neutral `1.0` regardless of the marginal. (2) `success_count` changed from a binary "`outcome_score > 0`" increment to a graduated `effectiveness` accumulator (`0..1`, `float` not `int`): derived from `damage_ratio` against the action's own best-case ceiling (`ceiling_damage`, reusing §4.4 resolution math, no new `action_definition` field), scaled so hitting the expected/full-strength ceiling reads as `0.75` — leaving headroom above it for outperformance from variability, position, or a depleted defender. Applied to both the pair table and the marginal aggregate. New `<<Question>>` opened on how this cost-agnostic `effectiveness` reconciles with the separately-defined, cost-adjusted `outcome_score` that feeds `weight`'s EMA. |
| 2026-07-01 | §11.10 `outcome_score` formalized as `benefit_score - cost_ratio`: `benefit_score` is a domain-specific plug-in (combat's is `effectiveness`, already defined); `cost_ratio` is domain-general, reusing the existing `costs: Array` pool-drain pattern (§4.3) — no new fields for either side. §11.7/§11.9's loose "damage dealt relative to cost paid" phrasing updated to reference this. New "Generalization beyond Resisted Actions" subsection documents the sprint-vs-walk (non-combat, non-resisted) motivating case and notes `CREATURE_MEMORY.md §14` already deliberately defers magnitude-based reward shaping (boolean/tiered `reward_scalar` only, phase-1) pending playtest, with a "hybrid" option already anticipated in that doc's own backlog comment. Decision: when Slot B eventually gains cost-awareness, add `outcome_score` as a new parallel EWMA magnitude track alongside the existing tiered `reward_scalar`/`success_count`/`success_delta` (not a replacement). Explicitly **not implemented in `CREATURE_GOAL_DRIVERS.md`/`CREATURE_MEMORY.md` now** — deferred to combat's own implementation phase so it doesn't interfere with concurrent V3 motor refactor work in those docs. One new `<<Question>>` opened (Slot B magnitude-track config shape), scoped to that future implementation step. |
| 2026-07-01 | §11.10 marginal/backoff-reuse question resolved: spatial overlay confirmed exempt (not pair-keyed). Opponent-observation table confirmed **in** — and for a stronger reason than the self-table's fragmentation concern: a reaction is queued before the opponent's action is known (§4.1), so reaction *selection* can never condition on the specific incoming `opponent_action_id` in the first place, only on the responder's overall history against this opponent. The marginal over `own_response_id` already encodes that (it implicitly reflects the opponent's real historical action mix), making it close to the primary decision-relevant signal here rather than just a thin-pair fallback. Shares the self-table's `combat_exp_n_sat`/`combat_exp_n_min` — no new constants. Flagged, not decided: the pair-level breakdown's main value for this table may end up being record-keeping / a future opponent-prediction model rather than driving today's `combat_rank_score` directly. |
| 2026-07-01 | §11.10 spatial-overlay novelty/proven-lerp question resolved: **yes**, it applies, but not via combat's `change_stability`-only formula. Generalized into a shared `trait_rank_bias(traits, config)` helper — a primary axis sets the base lerp, and optional secondary axes modulate it gated by how strongly the primary leans toward its second pole. Combat's config (`primary_axis: change_stability`, no modifiers) reproduces its existing formula unchanged; the spatial overlay's config (`primary_axis: explorer_builder`, modifier: `change_stability` gated by Builder-lean) captures the discussed intuitions: Explorer favors novelty regardless of stability; Builder+Stability favors the strongest proven bias; Builder+Change opens back up toward neutral (new methods/relocating without abandoning the optimize-in-place goal). `community_individual`/`compassion_self_interest` explicitly left unwired in both configs — the community-axis behavior discussed (leave a location with no buffer for others) is a separate stay/leave resource-margin mechanic, not this lerp — but both remain available `modifiers` slots for a future decision with an established intuition, addable via config alone. §2 planned-files row updated: `combat_experience_math.gd`'s `rank_score` now takes `traits`/`axis_config` instead of a bare `change_stability` float. New `<<Question>>`: default value for `spatial_cs_modulation`. |

---

## 11. Remaining design work (session checkpoint — 2026-06-22)

The following topics were identified during the design session but not fully resolved. Resume here in the next session.

### 11.1 Reaction trigger predicates (design in progress)

The following gates must all pass for a queued reaction to fire. Gates 1–3 are confirmed. Gate 4 and the open predicate extension point are in progress.

**Confirmed gates:**
1. The action's `target_region` is in the reaction's `coverage` dict with a non-zero value.
2. The responder has a reaction queued (chose one this tick).
3. The reaction's cooldown has expired.

**Gate 4 — positional / spatial predicates (confirmed in principle; naming pending):**
A reaction definition may declare one or more **positional predicates** that describe spatial conditions the responder must satisfy for the reaction to be valid. 

- Awareness zone terminology (config keys, debug overlay, doc references) uses plain language: "awareness zone", "awareness arc", "flanked" — not implementation terms like "observation cone" or "coverage cone".
- Positional predicates on action/reaction definitions are a **typed predicate list**, not a single hardcoded check. Each predicate has a `type` (e.g. `"positional_awareness"`) and its own config-driven parameters. This makes the gate extensible: additional spatial conditions (e.g. elevation, terrain adjacency) can be added without changing the resolution formula.

**Open extension point — non-positional reaction predicates:**
Positional predicates are one predicate type. The same typed list should accommodate non-positional gates that affect whether a reaction is valid in context. Confirmed candidates to specify as the system grows:
- **Composure threshold:** reaction fails if responder's `curr_point_comp` is below a configured floor (creature is too rattled to react reliably).
- **Interaction context match:** the reaction's `context_set` must match the active interaction type (already in the reaction definition as a string field — this is effectively a predicate already).
- **Negotiation / social predicates:** in future non-combat conflict types, additional factors (relationship state, prior concession history, etc.) could gate reactions the same way.

**Design decision:** The reaction definition's predicate list (`trigger_predicates : Array`) should be structured as typed dicts from the start, even if only `positional_awareness` is implemented in this phase. This avoids retrofitting the data shape later.

**Resolved:** `trigger_predicates : Array` confirmed. §4.3 updated.

### 11.2 Motor behavior during active combat — RESOLVED

Normal goal evaluation continues every tick unchanged. There is no combat-specific motor sub-mode. `tactic_fight_active` applies a configured urgency multiplier to fight/flight goal weights so they dominate over incidental goals (e.g. foraging) unless a competing goal reaches higher urgency (e.g. imminent starvation).

**Positioning is driven by the queued action, not by a separate motor mode:**
Each action definition carries `preferred_range`, `preferred_arc_deg`, `arc_required`, and `position_weight`. While an action is queued, `CombatPositionResolver.resolve_combat_target()` computes a target `Vector3` — the closest valid point on the preferred-range arc — and feeds it to `SeekPlanner` as the tick's `ultimate_goal`. SeekPlanner is unchanged; it moves toward a point as always.

**Hard vs. soft positioning:**
- `arc_required = true`: action is not queueable until positional criteria are met. Each tick the goal system re-evaluates: the creature repositions toward the action's target point until in position, or until a higher-urgency goal or a different action takes precedence and replaces the queued slot.
- `arc_required = false`: action can fire from any position; `CombatPositionResolver.positional_modifier()` attenuates the resolution result toward `combat_position_mod_floor` (config, default `0.5`) when off-position. A sub-optimal attack can still land.

**Flanking as emergent behavior:**
Because being outside an opponent's awareness arc degrades their reaction (§4.4), creatures have an implicit incentive to queue flanking-arc actions. No explicit "circle" motor mode is needed — the position resolver picks the closest valid arc point, which will naturally be off to the side when that is what the queued action prefers.

### 11.3 Pool recovery — RESOLVED

Recovery is continuous and per-second (not per physics tick — keeps it frame-rate independent). All pools recover at all times outside of strenuous activity; the activity state and the stat value together determine the rate.

**Activity states and rate multipliers:**

| State | Multiplier | Examples |
|-------|-----------|---------|
| Strenuous | 0.0 | Combat contact, sprinting |
| Light activity | 0.4 | Walking, social interactions |
| No activity | 1.0 | STAY action, turning in place (on watch) |
| Rest | 2.5 | REST action |

Multipliers are config keys (`recovery_mult_strenuous`, `recovery_mult_light`, `recovery_mult_idle`, `recovery_mult_rest`). Strenuous may go negative in a future phase (active drain beyond pool spend) but defaults to 0 for this implementation.

**Recovery rate formula:**

```
fill_time(stat)   = recovery_base_fill_sec × (stat / 10.0) ^ recovery_time_exponent
recovery_rate     = stat_to_point(stat) / fill_time(stat)          # pts/sec at full activity multiplier
actual_rate       = recovery_rate × activity_multiplier
```

Config keys: `recovery_base_fill_sec` (default `100.0`), `recovery_time_exponent` (default `0.25`).

**What this produces at key stat values (no-activity state, multiplier 1.0):**

| stat | stat_to_point | fill_time | pts/sec |
|------|--------------|-----------|---------|
| 1    | 132.82       | 56s       | 2.37    |
| 5    | 254.54       | 84s       | 3.03    |
| 10   | 500.00       | 100s      | 5.00    |
| 15   | 745.46       | 111s      | 6.71    |
| 20   | 890.40       | 119s      | 7.48    |
| 25   | 975.99       | 126s      | 7.75    |

Higher stat → more absolute points per second, but pool grows faster than rate, so fill time increases. The curve is intentionally shallow (stat 1 fills in ~56s, stat 25 in ~126s) — a strong creature is not punished harshly for having large pools.

**Recovery scope:** applies between combat episodes within a round, not only between rounds. A creature that disengages and rests mid-round recovers. In-combat recovery is zero (strenuous state). No cross-session persistence of pool state in this phase.

**Dependency:** `stat_to_point(stat)` from `res://creature/stat_math.gd` must exist before recovery can be implemented. See §11.8.

### 11.4 Scope: 1v1 only — RESOLVED

This phase targets the existing fox-vs-rabbit 1v1 duel only. Multi-creature combat (XvY, pack scenarios) is out of scope for implementation.

The design must not architecturally block XvY combat, but no multi-creature logic ships in this phase. Any design decision that would need revisiting or extension to support XvY (e.g. action target selection, experience table keying, combat position resolver assuming a single opponent) must be called out explicitly at the point of that decision and approved or addressed before implementation proceeds. Do not silently make 1v1 assumptions that would require refactoring later.

### 11.5 System name — RESOLVED

The generalized conflict system is named the **Resisted Actions** subsystem. This name captures the core mechanic (one creature's action is actively resisted by another creature's queued reaction) and abstracts cleanly beyond combat — mating contests, social challenges, and future interaction types all fit the same pattern of one creature attempting an action that another creature can resist.

**Naming conventions flowing from this decision:**
- File prefix: `resisted_action_*` for subsystem-level scripts (e.g. `resisted_action_resolver.gd` if the combat math is ever generalized beyond combat)
- Class names: `ResistableAction`, `ResistableReaction` when promoted from combat-specific resources
- Doc references: use "Resisted Actions subsystem" in headers and cross-references

For this phase, combat-specific files (`combat_math.gd`, `creature_combat_component.gd`, etc.) retain the `combat_` prefix since they are the first and only instance. The `resisted_action_*` namespace is reserved for when the substrate is lifted out of combat into a shared layer.

### 11.8 stat_to_point prerequisite prep (blocking)

`stat_math.gd` does not yet exist. Combat cannot implement pool initialization (§5 step 1) or pool recovery (§11.3) without it. The following gaps in [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md) must be resolved before combat implementation begins:

1. **`stat_num < 1` edge case** — current creature design has stat 1 as the floor (stat 0 is not a valid creature state). Resolution: clamp to 1 and return `132.82`. Add an assertion in debug builds. Update SHARED_STATTOPOINT_PLAN.md §4 edge cases table.
2. **`stat_num > 25` loop verification** — the pseudocode loop in SHARED_STATTOPOINT_PLAN.md §4 needs test vectors for stat 26, 30, and 40 to confirm loop order matches design intent before the function is used in production paths.
3. **Create `res://creature/stat_math.gd`** — implement `stat_to_point(stat_num: int) -> float` with the lookup table (indices 1–25) and the `>25` extrapolation loop. Pass golden-value headless tests for stat 1, 10, 25, 26, 30 before wiring into any other system.

This work is captured as step 1 of the §5 implementation plan. It should be treated as a standalone deliverable that unblocks both combat and recovery.

### 11.9 Opponent observation table (design stub)

A symmetric counterpart to the self-referential experience table (§11.7): each creature maintains a per-creature-lifetime record of what its opponent has done and what response the creature used in reply. The goal is to let a creature learn response tendencies against observed opponent action patterns — without any explicit encoding of strategy.

**Write trigger:**
An observation record is written whenever an opponent action resolves (landed or not), using `outcome_score` (`benefit_score - cost_ratio` — §11.10) as the EMA signal. Positional awareness of the attacker is not required — a creature does not need to see an attack to experience its outcome. The `trigger_predicates` system governs *reaction firing*; observation writes have their own simpler trigger.

**Scope — per-creature-lifetime, per action (not per species):**
The table is keyed on `opponent_action_id → own_response_id → weight`, scoped per creature instance. A creature that dies takes its table with it.

**Observation stat gating — 25% rate stub:**
In the base implementation the EMA update rate is set at **25% of `combat_exp_ema_alpha`**. Full-rate observation learning is deferred to the skill system (see enhancement backlog). `stat_observation` is the natural stat to gate that unlock, but the exact mechanism is not specified here.

**Resolved — the 25% rate is an alpha dampener, not a sampling gate:** `record()` still fires on every opponent-action resolve — `attempt_count` / `success_count` increment 1:1 with real occurrences, same as the self-table. The 25% figure only scales how far `weight` moves per event (secondhand outcome data should shift the outcome-magnitude estimate more cautiously than a self-attempted action would). It does **not** mean this table "sees" a pattern less often — only that it trusts each individual data point's contribution to `weight` less. See §11.10 for why this means `combat_exp_n_sat` / `combat_exp_n_min` (the confidence/evidence constants) are shared across all three tables rather than needing separate scaled versions.

**Action-id agnostic:**
The table works with any `action_id` StringName regardless of interaction context (combat, social, mating). Context-class flags are deferred; the `context_set` field already on reaction definitions provides scoping when needed.

**Separate tables, aligned interface:**
The self-experience table (§11.7) and the opponent observation table are separate data structures. Both expose the same `record(prev_id, curr_id, outcome_score)` / `weight(prev_id, curr_id) -> float` contract so they can be merged in a future refactor without breaking call sites.

**Positional response overlay — Option B (open):**
The action table covers action/reaction id responses only. Positional learning ("I should stay face-to-face more") is handled by a separate spatial preference overlay — a per-creature dict of named positional biases updated via EMA when opponent actions with positional criteria resolve. CombatPositionResolver reads these as additive weights on top of the queued action's `position_weight`. The overlay is a distinct data structure with the same per-creature-lifetime scoping and 25%-rate rule.

**Resolved — spatial overlay update trigger:** Bias updates fire on action resolve regardless of outcome (landed or failed). Outcome score is used as the EMA signal, so a failed attack contributes a negative signal and a landed attack contributes a positive one — no separate landed/failed branching needed.

**Resolved — spatial overlay bias keys:** Keys are derived at runtime from the positional fields on action definitions (e.g. `requires_flanking = true` → `maintain_awareness_arc` key; future positional fields map to their own keys). All biases initialize to `0.0`. Tuning of initial values is deferred to a balance pass.

**Inheritance:**
The opponent observation table and spatial overlay are heritable. See [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) §Heredity. Deferred to the same timeline as self-table inheritance.

---

### 11.7 Combat experience table

**Goal:** Let creatures learn which action sequences are effective without ever hardcoding "do B after A." The full action set (A–E) remains available; experience shifts selection weights so discovered effective transitions become more probable over time.

**Data shape — transition pair table:**
Each creature instance owns a `CombatExperienceTable`: a dictionary keyed on `prev_action_id → curr_action_id → { weight, attempt_count, success_count }` (fields beyond `weight` added by §11.10). Weights are initialized to `1.0` (neutral) for all pairs at spawn. Only transition pairs the creature has actually attempted accumulate meaningful signal.

**Recording:** After each action resolves, `experience_table.record(prev_action_id, curr_action_id, outcome_score)` updates the weight using a configurable exponential moving average (`combat_exp_ema_alpha`, default `0.2`): `weight = (1 - alpha) * weight + alpha * outcome_score`. `outcome_score = benefit_score - cost_ratio` (§11.10) — positive when the exchange was favorable, negative when costly. `attempt_count` and `success_count` are updated the same tick per §11.10.

**Consumption:** During action queuing (§4.8 goal→objective→action pipeline), candidates are ranked by `combat_rank_score` (§11.10) — not raw `trait_affinity_score + weight`. This is **in scope for this phase, not deferred**: see §11.10 for why selecting on raw weight alone risks starving newly-available actions, and for the selection-rule options considered.

**Cold start:** New creatures start with all weights at `1.0`, `attempt_count = 0`, `success_count = 0`. No prior is inherited at spawn. Experience is per-creature-instance and persists only for the creature's lifetime.

**Future — inheritance via reproduction (deferred):**
When the reproduction subsystem ships, a child creature's starting experience table will be seeded from a blend of its parents' tables at a configured dilution factor. Over generations, populations will develop regionally distinct action-chain tendencies reflecting their local opponents and terrain — without any explicit encoding of "which chain is best." Populations in different regions of the map may converge on entirely different strategies even for the same species pairing.

**Scope boundary:** This phase implements only the per-instance table and EMA update. Inheritance, persistence across sessions, and cross-creature comparison are explicitly deferred.

### 11.6 Test action/reaction set

The full action/reaction library for fox and rabbit is deferred to a separate design project. The following minimal set is defined for this phase to validate the mechanical plumbing. These are test examples only and are not guaranteed to ship in the final implementation.

---

#### Data shape revisions (driven by this example set)

These examples collectively require the following changes to the data shapes in §4.3:

**Action definition changes:**
- `cost_stat / cost_amount` (singular) → `costs: Array` of `{stat: String, amount: float}` pairs — multi-stat action costs
- `target_region: String` — **removed from this phase** (specific point targets are out of scope; reserved as a future extension)
- `secondary_effects: Array` added — list of `{pool: String, amount: float}`; additional pools drained on landing, applied as flat amounts after the primary resolution
- `requires_flanking: bool` added — hard gate: action is not queueable unless the attacker is outside the defender's awareness arc; distinct from `arc_required` (which governs the attacker's own facing to the opponent)

**Reaction definition changes:**
- `coverage: Dictionary` (region → multiplier) — **removed from this phase**; replaced by `mitigation_coverage: float` (flat 0.0–1.0 multiplier on the reaction's effectiveness applied to all incoming damage)
- `mitigation_stat: String` → `mitigation_stats: Array` — supports multiple stats contributing to `defender_raw`
- `mitigation_type: String` added — controls which formula path is used:
  - `"stat_modifier"` — standard §4.4 formula (sum of stat modifiers × pool scale × coverage)
  - `"pool_ratio"` — mitigation = `(curr_pool / max_pool) × mitigation_cap` (Absorb); costs applied before the ratio is sampled
  - `"stat_modifier_sum"` — sum of all `mitigation_stats` modifiers and pool scales × coverage (Dodge)
- `mitigation_cap: float` — upper bound for `"pool_ratio"` mitigation type
- `cost_incoming_fraction: float` added — when non-zero, cost = `incoming_damage × cost_incoming_fraction`; overrides static cost entries (Bite Back)
- `embeds_queued_action: bool` added — when true, the creature's currently queued action fires as part of this reaction; both the reaction and the embedded action enter cooldown independently (Counter Strike)
- `damage_reduction_per_sec: float` added — flat damage reduction applied per second of fight duration before resolution; applies when this reaction fires (Counter Strike)
- `damage_reduction_max: float` added — cap on the above

---

#### Actions

**Bite**
```
action_id             : &"bite"
costs                 : [{stat: "end", amount: 5}]
outcome_stat          : "fit"
secondary_effects     : [{pool: "comp", amount: 3}]
threshold             : 0.0                        # TBD during balance pass
cooldown_ticks        : 120                        # 2 seconds at 60 ticks/sec
preferred_range       : 0.0                        # no positional preference
preferred_arc_deg     : 0.0
arc_required          : false
requires_flanking     : false
position_weight       : 0.0
observation_unlock_sec: 0.0
```
*Tests:* primary stat damage (Fit pool), secondary flat damage (Composure), no positional requirement, basic cooldown.

---

**Ankle Bite**
```
action_id             : &"ankle_bite"
costs                 : [{stat: "end", amount: 5}]
outcome_stat          : "dex"
secondary_effects     : [{pool: "comp", amount: 5}]
threshold             : 0.0
cooldown_ticks        : 180                        # 3 seconds
preferred_range       : 0.0
preferred_arc_deg     : 0.0
arc_required          : false
requires_flanking     : true                       # hard gate: must be outside defender's awareness arc
position_weight       : 1.5                        # strong incentive to seek flanking position
observation_unlock_sec: 0.0
```
*Tests:* flanking hard gate (`requires_flanking`), secondary flat damage, Dex as primary outcome stat.

---

#### Reactions

**Absorb** *(renamed from Dodge)*
```
reaction_id           : &"absorb"
costs                 : [{stat: "end", amount: 3}, {stat: "dex", amount: 2}]
mitigation_stats      : ["dex"]
mitigation_type       : "pool_ratio"               # (curr_point_dex / max_point_dex) × mitigation_cap
mitigation_cap        : 0.9                        # max 90% reduction at full pool
mitigation_coverage   : 1.0
cost_incoming_fraction: 0.0
cooldown_ticks        : 120                        # 2 seconds
context_set           : "combat"
trigger_predicates    : []
```
*Cost applied first, then ratio sampled — so mitigation is always slightly below 90% and degrades as the Dex pool depletes from use.*

*Tests:* pool-ratio mitigation type, multi-stat cost, mitigation degradation under repeated use.

---

**Dodge** *(new)*
```
reaction_id           : &"dodge"
costs                 : [{stat: "dex", amount: 3}, {stat: "wit", amount: 3}]
mitigation_stats      : ["dex", "wit"]
mitigation_type       : "stat_modifier_sum"        # both stat modifiers contribute to defender_raw
mitigation_coverage   : 1.0
cost_incoming_fraction: 0.0
cooldown_ticks        : 120                        # TBD
context_set           : "combat"
trigger_predicates    : []
```
*By combining Dex and Wit modifiers, a creature with high scores in both stats can raise `defender_raw` enough that the net result falls below the action threshold — a clean miss rather than reduced damage.*

*Tests:* multi-stat mitigation (`stat_modifier_sum`), chance of complete miss via high defender_raw.

---

**Bite Back**
```
reaction_id           : &"bite_back"
costs                 : []
cost_incoming_fraction: 0.2                        # cost = incoming_damage × 0.2; pool TBD (see open question)
mitigation_stats      : []
mitigation_type       : "stat_modifier"
mitigation_coverage   : 0.0                        # does not reduce incoming damage
secondary_effects     : [{pool: "comp", amount: 10}]   # deals 10 Composure to attacker on firing
cooldown_ticks        : 180                        # 3 seconds
context_set           : "combat"
trigger_predicates    : [{type: "positional_awareness"}]   # attacker must be within defender's awareness arc (face-to-face)
```
*Tests:* dynamic cost (`cost_incoming_fraction`), zero damage mitigation, secondary effect dealt to attacker, positional trigger predicate (face-to-face — inverse of flanking).*

<<Question: Which pool does `cost_incoming_fraction` drain from for Bite Back? Suggest Endurance as the primary action resource — confirm before implementation.>> <<Answer: This modifier should apply to all incoming damage from the action this is reacting to. >>

---

**Counter Strike**
```
reaction_id              : &"counter_strike"
costs                    : [{stat: "wit", amount: 2}]
                           # queued action's cost also applies if it fires (via embeds_queued_action)
mitigation_stats         : []
mitigation_type          : "stat_modifier"
mitigation_coverage      : 0.0
damage_reduction_per_sec : 0.1                      # reduces incoming damage 0.1 per second of fight duration
damage_reduction_max     : 0.5                      # capped at 50%
embeds_queued_action     : true                     # queued action fires; both cooldowns activate independently
cooldown_ticks           : 60                       # 1 second for Counter Strike itself
context_set              : "combat"
trigger_predicates       : [{type: "incoming_damage_nonzero"}]   # only fires when opponent action would deal damage
```
*The embedded action fires using its own cooldown. If the queued action is on cooldown when Counter Strike triggers, the action does not fire but Counter Strike's Wit cost and damage reduction still apply.*

*Tests:* time-based damage reduction, embedded action mechanic, dual cooldown, `incoming_damage_nonzero` trigger predicate (new predicate type — add to predicate registry before implementation).

---

#### Coverage by this test set

| Mechanic | Covered by |
|----------|-----------|
| Basic stat damage | Bite |
| Secondary flat damage | Bite, Ankle Bite |
| Multi-stat cost | Absorb, Dodge |
| Flanking hard gate (`requires_flanking`) | Ankle Bite |
| Pool-ratio mitigation | Absorb |
| Mitigation degrades under use | Absorb (cost applied before ratio sampled) |
| Multi-stat defender_raw / chance of clean miss | Dodge |
| Dynamic reactive cost | Bite Back |
| Face-to-face trigger predicate | Bite Back |
| Time-based damage reduction | Counter Strike |
| Embedded action fires as reaction | Counter Strike |
| Dual independent cooldown | Counter Strike |

| Mechanic | **Not covered — explicitly noted** |
|----------|-----------------------------------|
| `observation_unlock_sec > 0` | Timed action-unlock untested in this set |
| Feint (wit vs wit, reaction slot burn) | §4.5 — deferred |
| Stat wheel overflow (2:1 neighbor drain) | Needs a scenario that drives a pool to 0 |

---

### 11.10 Selection-rule / novelty-vs-proven exploration bias — in scope this phase

**Problem:** `combat_experience_table` (§11.7) initializes every `prev_action_id → curr_action_id` pair to a neutral weight of `1.0` and only moves via EMA on pairs actually attempted. A newly unlocked action (future skill-tree growth, out of scope for this phase but not for this design) enters at the same neutral `1.0` as any other untried pair, while an already-reinforced favorite sits above it. If selection is a naive argmax on `trait_affinity_score + weight`, a large action pool risks permanently starving new options — the incumbent keeps winning, and the gap never closes because EMA only updates on use, never on disuse. This is addressed now rather than deferred, since it shapes how the transition-pair table and its two siblings (§11.9) select and reinforce behavior from the first tick they exist.

**Resolved direction:** Do not invent a new mechanism. `goal_source_memory.gd`'s Slot B replay already solves the identical class of problem — ranking competing candidate records by blending a sample-count confidence term with a `change_stability`-driven novelty-vs-proven lerp (CREATURE_GOAL_DRIVERS.md §5.1.2, "Slot B — confidence" and "`change_stability` rank bias"). Combat reuses that formula shape rather than forking a second exploration paradigm.

#### Selection-rule options considered

| Option | Mechanism | Fit with existing engine pattern | Trade-offs |
|--------|-----------|-----------------------------------|------------|
| **A — Ranked argmax (recommended)** | Compute a `combat_rank_score` per candidate (confidence × novelty/proven bias, same shape as `replay_rank_score`); pick the highest-scoring queueable candidate | **Direct transplant** of the shipped, tested Slot B formula; stays pure/deterministic, matching the project convention that motor/selection logic be headlessly unit-testable with golden values | Still deterministic: on a genuine tie, or for a Stability-leaning creature whose `novelty_score` never clears the incumbent, a candidate can go unpicked indefinitely. This may be *correct* for a Stability creature, but needs an explicit tie-break rule |
| **B — Softmax / weighted-random over rank score** | Convert `combat_rank_score` into a probability distribution and sample | Guarantees nonzero trial probability for every candidate, even under a Stability-heavy creature | **Breaks from precedent** — Slot B is pure ranking, never stochastic sampling. Introduces RNG into a subsystem the project otherwise keeps pure and deterministic; existing test style ("weight converges toward repeated outcome", golden values) would need to become seeded/statistical — a real testing-cost regression |
| **C — Epsilon-greedy bolt-on** | Argmax normally; with probability ε pick uniformly at random | Simple, well-understood bandit pattern | **Least reuse** — a third exploration paradigm alongside Slot B's lerp and Option A's rank score; needs its own tunable (ε) and its own trait-scaling rule, duplicating work Option A already does via `novelty_score` |

**Recommendation: Option A.** It answers the starvation concern (new actions get a `novelty_score` boost from low `attempt_count`, scaled by how Change-leaning the creature is) using a formula already shipped, already trait-aware, and already fitting this codebase's pure-function/headless-test convention (`CLAUDE.md`: "Motor and vitals logic must be pure ... to remain unit-testable headlessly"). Revisit Option B only if playtesting shows a Stability-leaning creature never tries a candidate even once across its lifetime — that is a tuning problem to observe first, not a reason to abandon Option A up front.

#### Adapted formula (transplanted from CREATURE_GOAL_DRIVERS.md §5.1.2)

Each transition-pair table entry gains two fields alongside the existing EMA `weight`:

```
weight         : float   # existing EMA of outcome_score — unchanged meaning, init 1.0
attempt_count  : int     # times this pair has been recorded — init 0
success_count  : float   # graduated landing-quality accumulator (see "Resolved — landing-quality mapping" below) — init 0.0
```

```
evidence        = 1 - exp(-attempt_count / combat_exp_n_sat)     # config; mirrors replay_n_sat
success_rate    = success_count / max(attempt_count, 1)
thin_cap        = min(1.0, attempt_count / combat_exp_n_min)     # config; mirrors replay_n_min
mixed_penalty   = 4 * success_rate * (1 - success_rate)
failures        = attempt_count - success_count
streak_bonus    = (failures == 0 && attempt_count > 0) ? (1 - evidence) : 0
novelty_score   = (1 - evidence) * (1 - mixed_penalty) + streak_bonus
proven_score    = evidence * (0.5 + 0.5 * success_rate)

t               = (change_stability + 100) / 200.0    # 0 = Change ... 1 = Stability — same axis, same read as Slot B
trait_rank_bias = lerp(novelty_score, proven_score, t)
confidence      = clamp(evidence * (0.5 + 0.5 * success_rate) * thin_cap, 0, 1)

combat_rank_score = (trait_affinity_score + weight) * confidence * trait_rank_bias
```

Candidate selection: among actions passing the existing cooldown / `observation_unlock_sec` / arc gates (§4.8), pick the highest `combat_rank_score`. This replaces the plain `trait_affinity_score + weight` selection previously described in §4.8 and §5 step 10 — `weight` still carries the outcome signal as magnitude, but confidence and trait-driven novelty now gate *which* candidate that magnitude gets to compete with.

Slot B's `delta_factor` (recent-trend term from `success_delta`) is dropped from this transplant — there is no windowed trend signal at the pair level yet. See `<<Question>>` below.

#### Reuse across the self-table, opponent-observation table, and spatial overlay

§11.9's opponent-observation table and spatial-position overlay already commit to the same `record()` / `weight()` interface as the self-experience table, so extending both to carry `attempt_count` / `success_count` and compute `combat_rank_score` the same way is a natural fit — but not a drop-in without adjustment:

- **Opponent-observation table:** `attempt_count` here means "times I've faced this specific opponent action," bounded by the *opponent's* behavior rather than the creature's own choices. `novelty_score` still means something coherent ("I've rarely seen this move — try a different response").
- **Spatial overlay:** the overlay already updates via EMA "regardless of outcome" (§11.9) and initializes biases to `0.0`, not `1.0` — a different neutral point than the tables. The `success_rate` term assumes a `[0,1]`-bounded quantity derived from discrete success/attempt counts; the overlay's signal is a continuous, possibly-negative bias. The confidence/evidence gate is unaffected by sign and should transplant cleanly, but whether the *novelty/proven lerp specifically* is meaningful for positioning (vs. just gating on confidence with no lerp) is a genuine open design question, not just a mechanical one.

**Resolved — shared saturation constants, no per-table scaling:** The 25%-rate throttle on the opponent-observation table and spatial overlay is an alpha dampener on `weight` only (§11.9) — `attempt_count` still increments 1:1 with real occurrences, exactly like the self-table. Since `evidence`/`thin_cap` are driven by `attempt_count`, not `weight`, all three tables read genuine, unthrottled exposure counts and share the same `combat_exp_n_sat` / `combat_exp_n_min`. No separate `combat_obs_n_sat` / `combat_spatial_n_sat` family is needed. The remaining open question for the spatial overlay is not saturation scaling but whether the novelty/proven lerp applies to a continuous signed bias at all (previous bullet) — the confidence/evidence gate itself transplants unchanged.

#### Pair-level vs. action-level tracking — resolved via hierarchical backoff

**Problem:** Pure pair-level `attempt_count`/`success_count` (keyed on the exact `(prev_action_id, curr_action_id)` combination) fragments evidence as the action pool grows — a `curr_action_id` that's genuinely proven overall, but reachable from five different `prev_action_id`s, may never clear `combat_exp_n_min` on any *single* pair, permanently reading as thin/novel even though the creature has effectively tried it many times. Pure action-level tracking (drop `prev_action_id` from the key entirely) converges fast and sidesteps the fragmentation, but throws away the sequence-specific learning that's the entire point of a transition-pair table — "B works well after A, but poorly after C" collapses to a single number.

**Options considered:**

| Option | Mechanism | Trade-offs |
|--------|-----------|------------|
| **A — Pure pair-level (status quo)** | Key strictly on `(prev_action_id, curr_action_id)` | Full sequence specificity; fragments badly as the pool grows — the exact scalability concern this question raises |
| **B — Pure action-level** | Drop `prev_action_id`; key on `curr_action_id` only | Scales cleanly, converges fast; loses sequence learning entirely — defeats the purpose of a transition-pair table |
| **C — Hierarchical backoff (selected)** | Keep the pair table as the source of truth for `weight` and ranking, but maintain a lightweight marginal `curr_action_id → {attempt_count, success_count}` aggregate alongside it. When a pair is thin, blend its `evidence`/`success_rate` toward the marginal's — using the pair's own `thin_cap` as the blend weight, so evidence gracefully backs off to "how proven is this action in general" instead of resetting to "totally novel" every time it's reached from a new prior | Keeps full specificity where data supports it and degrades gracefully where it doesn't; the one genuinely new piece of math in this transplant — no existing precedent in this codebase (unlike the rest of §11.10, which reuses Slot B outright). It's a standard statistical pattern (hierarchical shrinkage / n-gram backoff), just new to this project |

**Selected: Option C.** It directly answers the scalability concern (marginal table is `O(actions)`, not `O(actions²)`, and is cheap to maintain incrementally) without giving up the sequence-specific signal that motivated a pair table in the first place.

**Adapted formula (extends §11.10's existing formula):**

```
# per creature, maintained alongside the existing pair table:
marginal_table : curr_action_id -> { attempt_count, success_count }

# on every record(prev_action_id, curr_action_id, outcome_score, effectiveness):
pair.attempt_count      += 1
pair.success_count      += effectiveness                         # graduated 0..1, not binary — see "landing-quality mapping" below
marginal[curr_action_id].attempt_count += 1                      # same tick, O(1)
marginal[curr_action_id].success_count += effectiveness

# at read time, for a candidate (prev_action_id, curr_action_id):
pair_evidence      = 1 - exp(-pair.attempt_count / combat_exp_n_sat)
marginal_evidence  = 1 - exp(-marginal.attempt_count / combat_exp_n_sat)
backoff_weight     = min(1.0, pair.attempt_count / combat_exp_n_min)   # reuses thin_cap, no new tunable
evidence           = lerp(marginal_evidence, pair_evidence, backoff_weight)

pair_success_rate     = pair.success_count / max(pair.attempt_count, 1)
marginal_success_rate = marginal.success_count / max(marginal.attempt_count, 1)
success_rate          = lerp(marginal_success_rate, pair_success_rate, backoff_weight)

# thin_cap, mixed_penalty, novelty_score, proven_score, trait_rank_bias, confidence
# all unchanged downstream — they just consume the blended evidence/success_rate above
# instead of pure pair-level values.
```

`weight` (the EMA outcome-magnitude estimate feeding `combat_rank_score` directly) is **not** blended — it stays pair-specific and initializes at `1.0` regardless of the marginal. Backoff only affects *how much the creature trusts* the confidence/novelty read for a thin pair, not the outcome estimate itself, which should only ever reflect what actually happened on that specific pair.

**Resolved — `weight` stays un-blended.** No warm-start from the marginal. A brand-new pair for an otherwise well-proven action still initializes `weight` at the flat neutral `1.0`; only `evidence`/`success_rate` (via the backoff above) benefit from the marginal's data. `weight` continues to reflect only what actually happened on that specific pair. Revisit only if playtesting shows new pairs of an already-proven action are picked too rarely even with the evidence backoff in place.

**Resolved — landing-quality mapping (`success_count` is graduated, not binary):** A hit doing little-to-no damage should read close to a failure, a moderate hit partial credit, and a large hit close to full success — a hard `outcome_score > 0` threshold collapses that whole spectrum to a single bit and was rejected. Instead, `success_count` accumulates a graduated `effectiveness` value in `[0, 1]` per attempt, derived from damage relative to the action's own best-case ceiling, reusing the existing §4.4 resolution math rather than adding a new field to `action_definition`:

```
# ceiling_damage: same §4.4 formula, evaluated at this action's best case —
# full attacker pool (curr_scale_att = 1.0), undefended (defender_raw = 0), no variability roll.
# Pure function of action + attacker stats; no new action_definition fields needed.
expected_max_damage = ceiling_damage(action, attacker_stats)

damage_ratio  = damage / max(expected_max_damage, EPSILON)   # `damage` = §4.4's `result if lands else 0.0`
effectiveness = clamp(damage_ratio * 0.75, 0.0, 1.0)          # hitting the expected/full-strength ceiling reads as 0.75, not 1.0 —
                                                               # leaves headroom above 0.75 for outperformance (depleted defender,
                                                               # favorable position, a lucky variability roll)

success_count += effectiveness   # float accumulator (see field-type update above), not a binary +1
```

A non-landing action (`damage = 0`) contributes `effectiveness = 0` — a full failure, consistent with the original binary proposal's floor case. `success_rate = success_count / max(attempt_count, 1)` (§11.10's existing formula) needs no further change: it already treats `success_count` generically as an accumulator, so making it graduated instead of binary is a drop-in swap.

#### Resolved — `outcome_score` formula (benefit minus cost, domain-general shape)

`outcome_score` (feeding `weight`'s EMA) was loosely defined as "damage dealt relative to cost paid" (§11.9). Formalized now as a two-part split so the same shape can eventually generalize beyond Resisted Actions (see below), rather than being combat-specific math:

```
outcome_score = benefit_score - cost_ratio
```

- **`benefit_score`** — domain-specific plug-in, `[0, 1]`-ish. For combat, this **is** `effectiveness` (above) — the graduated damage-ratio-to-ceiling quality signal.
- **`cost_ratio`** — domain-general, reuses the existing pool/stat pattern already on every action (`costs: Array` of `{stat, amount}`, §4.3): `cost_ratio = sum_over_costs(amount / max_pool_for_stat)`. No new fields — every action already declares its costs this way.

For combat specifically: `outcome_score = effectiveness - cost_ratio`, where `effectiveness` already reuses §4.4's resolution math and `cost_ratio` reuses the existing `costs` array — both sides of the formula are transplants of existing machinery, nothing net-new is invented for combat's own use.

A costly action that completely fails (`effectiveness = 0`, `cost_ratio > 0`) correctly nets a strongly negative `outcome_score`, discouraging that pair via `weight`'s EMA — while `success_count`'s `effectiveness` accumulation (above) stays cost-agnostic by design, since "was this pair worth trying at all" (confidence/novelty) and "was this specific attempt worth its cost" (`weight`) are deliberately separate questions.

#### Generalization beyond Resisted Actions (documented now, not built now)

This `benefit_score - cost_ratio` shape was deliberately generalized past combat because the *action-id agnostic* design of the opponent-observation table (§11.9: "works with any `action_id`... combat, social, mating") already anticipates non-combat use, and the same tradeoff shows up outside any resisted/opponent context too — e.g. a creature choosing to sprint vs. walk toward a food source: sprinting costs more calories per tick (`cost_ratio`, same pool-drain shape) but may arrive sooner (a `benefit_score` proxy — e.g. a `time_to_goal_ratio` against a baseline pace). Note that "arriving sooner enables visiting a second food source" is a multi-step, downstream benefit that can't be scored at the moment a single action resolves — any future `benefit_score` for movement should stick to something measurable immediately (time-to-goal), not compound opportunity value, which is a separate credit-assignment problem this formula does not solve.

**Sprint-vs-walk is not a Resisted Action** (§11.5 — no opponent resisting), so this generalization sits outside combat's own scope. `CREATURE_GOAL_DRIVERS.md`'s Slot B already has a conceptually equivalent experience mechanism for goal-pursuit tactics (`current_fit` × `stored_strength`, `attempt_count`/`success_count`/`success_delta` confidence stats) — but `CREATURE_MEMORY.md §14` currently uses a **boolean/tiered `reward_scalar` ∈ {-1, 0, +1}** only, and explicitly defers magnitude-based reward shaping until after playtest (`CREATURE_MEMORY.md:568` "Resolved (Outcome → reward shaping — phase 1)", plus the standing `<<Comment>>` at line 588 naming a **"hybrid (tier for counts + bounded magnitude for EWMA)"** as the anticipated future option).

**Decision: hybrid, deferred to combat-implementation time.** When Slot B eventually gains cost-awareness, it should be additive, not a replacement of the tiered system: keep `reward_scalar`/`success_count`/`success_delta` exactly as they are today (driving confidence/counts, unchanged), and add this `outcome_score` shape as a new, parallel EWMA magnitude track (`stored_magnitude`) that modulates ranking alongside — not instead of — `confidence`. This is intentionally **not** designed or implemented in `CREATURE_GOAL_DRIVERS.md`/`CREATURE_MEMORY.md` as part of this combat design pass — those docs are active ground for the concurrent V3 motor refactor work, and this generalization idea should only be picked up as its own step within combat's implementation phase (§5), once V3 has landed, rather than edited speculatively now.

<<Question: When combat implementation reaches the point of wiring Slot B's hybrid magnitude track, does `stored_magnitude`'s EWMA use the same `combat_exp_ema_alpha`-style config key, or its own? And does `f(stored_magnitude)` in `replay_rank_score = slot_b_base * confidence * trait_rank_bias * f(stored_magnitude)` need its own saturation/clamping shape, or a straight linear scale? Deferred until that implementation step — not a decision for this design pass.>>

**Resolved — marginal/backoff applies to the opponent-observation table; spatial overlay is exempt.**

**Spatial overlay: does not apply.** It isn't pair-keyed at all — a flat dict of positional bias keys (`maintain_awareness_arc`, etc.), not `prev → curr`. There is no pair-fragmentation problem to back off against.

**Opponent-observation table: applies, and the marginal here carries more weight than in the self-table, not less.** The key mechanical detail: a reaction is queued *before* the opponent's action is known — the responder commits `own_response_id` each tick and it fires "when triggered" (§4.1), not in reaction to a specific, already-observed `opponent_action_id`. That means reaction *selection* can never condition on the specific incoming move — only on what the creature has learned about this opponent overall. The marginal over `own_response_id` (summed across every past encounter with this opponent, regardless of which move preceded it) already **is** that: since it aggregates over the opponent's actual historical action mix, a marginal built from real encounters implicitly reflects "how often does this opponent do each thing" without needing a separate predictive model of opponent behavior. A response that fares well against an opponent who mostly throws headshots will show that in the marginal even though the marginal was never told the opponent's tendency directly.

This is a different (and stronger) justification than the self-table's: there, backoff is a *fallback* for when the pair is thin. Here, the pair dimension is largely unusable at decision time anyway (the opponent's move isn't known yet), so the marginal is close to the primary decision-relevant signal, not just a compensating mechanism for sparse data. Apply the same `marginal_table : curr_key -> {attempt_count, success_count}` shape as the self-table, keyed on `own_response_id`. Per the earlier saturation-constant resolution (§11.9/§11.10 above), this table already shares `combat_exp_n_sat`/`combat_exp_n_min` with the self-table — no new constants needed for the marginal either.

**A related note, not a decision:** since selection can't act on the pair-specific `(opponent_action_id, own_response_id)` dimension until the opponent's move is revealed, the pair-level breakdown's main value for this table is record-keeping (and any future opponent-prediction model), rather than driving today's `combat_rank_score` directly. That's a bigger architectural question than this one and isn't being decided here — just flagged so a future reader isn't surprised the marginal ends up doing most of the practical work for this particular table.

**Resolved — the novelty/proven lerp applies to the spatial overlay, via a generalized `trait_rank_bias` helper (not a spatial-specific formula).**

Combat's existing `t = (change_stability + 100) / 200` (above) turns out to be a single-axis case of a more general pattern: a **primary trait axis** sets a base lerp position, and zero or more **secondary axes** modulate it, gated by how strongly the primary already leans toward its second pole. Generalizing to that shape — rather than writing bespoke math per table every time a new decision needs this bias — means combat and the spatial overlay share one function and differ only in configuration:

```
trait_rank_bias(traits: Dictionary, config: Dictionary, novelty_score: float, proven_score: float) -> float

config = {
    primary_axis : String   # e.g. "change_stability" or "explorer_builder"
    modifiers    : Array    # [{axis: String, strength: float}, ...] — [] = none
}

primary    = traits[config.primary_axis] / 100.0   # -1 (first pole) .. +1 (second pole)
base_t     = (primary + 1.0) / 2.0                  # 0 = first pole, 1 = second pole
gate       = max(primary, 0.0)                       # only a second-pole lean gates modifiers — see rationale below

modulation = 0.0
for m in config.modifiers:
    modulation += (traits[m.axis] / 100.0) * gate * m.strength

t = clamp(base_t + modulation, 0.0, 1.0)
return lerp(novelty_score, proven_score, t)
```

**Combat's config reproduces its existing formula exactly — nothing about combat's already-resolved behavior changes:** `{primary_axis: "change_stability", modifiers: []}` collapses `gate`/`modulation` to `0`, leaving `t = (change_stability + 100) / 200`.

**Spatial overlay's config:** `{primary_axis: "explorer_builder", modifiers: [{axis: "change_stability", strength: spatial_cs_modulation}]}`. Walking the four cases discussed:
- **Full Explorer** (`explorer_builder = -100`): `base_t = 0`, `gate = 0` → `t = 0` (full novelty) regardless of `change_stability` — an explorer's pull toward covering new ground isn't tempered by stability.
- **Full Builder + full Stability**: `base_t = 1`, `gate = 1`; the modifier pushes further positive but clamps at `1` — the strongest proven/"tried-and-true" bias, matching a high-builder high-stability creature sticking with a known (even suboptimal) location and methods.
- **Full Builder + full Change**: `base_t = 1`, `gate = 1`, `change_stability = -100` → `t = clamp(1 - spatial_cs_modulation, 0, 1)`. With a default like `0.5`, `t` lands near neutral — more proven-leaning than a pure explorer, but genuinely open to new optimization methods or relocating if a fundamentally better spot is found.
- **Neutral `explorer_builder = 0`**: `gate = 0` → `t = 0.5` regardless of `change_stability` — stability alone doesn't move a creature with no explore/build lean.

**`community_individual` and `compassion_self_interest` are not wired into either table's config.** The community-axis behavior raised in discussion — biasing toward leaving a location that only meets basic needs with no buffer for others — is a stay/leave resource-margin threshold, not a bias about *how* to engage with a known-vs-new position, so it doesn't belong in this lerp; it's flagged as a separate, out-of-scope mechanic. Both axes remain valid `modifiers` slots for some future decision that does have an established intuition for them — adding one later is a new `axis_config`, not a code change.

<<Question: Default value for `spatial_cs_modulation` (strength of `change_stability`'s gated modulation on the spatial overlay's `explorer_builder`-primary lerp). TBD during a balance pass — `0.5` used above for illustration only.>>

<<Question: Shared implementation shape — one pure module (`combat_experience_math.gd`, tentative row added to §2 planned-files table) exposing `rank_score(weight, attempt_count, success_count, marginal_attempt_count, marginal_success_count, change_stability, n_sat, n_min) -> float`, called by three separate table classes — or one generic table class parameterized per use (self / opponent / spatial)? Should be settled before §5 step 10 is implemented.>>

**Resolved — tie-break / near-tie chaos (reuses V3 precedent):** `CREATURE_MOVEMENT_V3` already solves this class of problem for `blocked_objective_chaos` and `goal_consideration_chaos` (both default `0.15`, `0.0` disables) — "break symmetry with RNG" when scores tie **or are within a small epsilon after rounding." That's broader than a strict tie-break, and is reused here rather than inventing a new mechanism. Add `combat_rank_chaos` (config key, same naming convention as its V3 siblings): when two or more candidates' `combat_rank_score` values fall within an epsilon band of each other, apply light RNG jitter to decide among them instead of always resolving to the same winner.

**Scope of what this does and does not fix:** `combat_rank_chaos` only perturbs choices between near-equal candidates — it does not help when the gap is large and persistent, which is exactly what a strongly Stability-leaning creature's `trait_rank_bias` is designed to produce (a wide, deliberate gap favoring the proven action over an untried one). `novelty_score` / `trait_rank_bias` narrows that gap; `combat_rank_chaos` only decides the outcome once the gap is already narrow.

**A high-Stability creature persistently avoiding new actions is not, on its face, a bug.** Resistance to novelty is the intended personality expression of that trait axis, not an oversight. Do not add a stronger forced-exploration mechanism (Option B/C, or widening the chaos band to cover large gaps) preemptively. If playtesting shows this becomes a real problem (e.g. a newly-available action never gets exercised across a creature's entire lifetime, or populations never discover an objectively better tactic), address it then with a targeted mechanism — candidates include a decay term that erodes `weight`/`proven_score` over time when a pair goes unused, a wider or `stat_observation`-gated chaos band, or a hard floor forcing at least N trials of any newly-available action regardless of trait. Do not build any of these speculatively now.

<<Question: Epsilon-band width for "near-tie" (e.g. within X% of the higher score, or an absolute delta?) and whether `combat_rank_chaos` shares the `0.15` default with `blocked_objective_chaos` / `goal_consideration_chaos` or is tuned independently, since `combat_rank_score` has a different scale/shape than motor cost or goal-weight scores. Default TBD during a balance pass.>>

<<Question: Slot B's `delta_factor` (recent-trend bonus/penalty from `success_delta`) was dropped from this transplant for simplicity — no windowed trend signal exists at the pair level yet. Add a rolling-window trend term later, or intentionally omit it from the combat variant?>>
