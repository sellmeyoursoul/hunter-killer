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

<<Question: What is the canonical name for the generalized conflict system of which combat is one instance? Candidates: "conflict resolution", "goal negotiation", "interaction contest". This name will appear in file names, class names, and doc section headers — resolve before implementation begins.>>

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
| planned | `res://creature/combat/action_definition.gd` | Data resource: cost stat, outcome stat, target region, trait affinities, threshold, cooldown |
| planned | `res://creature/combat/reaction_definition.gd` | Data resource: cost stat, mitigation stat, coverage profile, trait affinities, cooldown, context set |

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
cost_stat        : String    # which pool is spent to perform this action (e.g. "end")
cost_amount      : float     # base pool cost before modifiers
outcome_stat     : String    # which attacker stat drives damage (e.g. "fit")
target_region    : String    # body region targeted (e.g. "head", "leg", "body")
trait_tags       : Array     # pole affinities — creature prefers this action when aligned (e.g. ["self_interest"])
threshold        : float     # hardcoded minimum net result for the action to land
cooldown_ticks   : int       # ticks before this action can be queued again
observation_unlock_sec : float  # seconds of active combat before this action becomes available (0 = always)
outside_influence_key : String  # optional: config key for location/item modifier
```

**Reaction definition:**
```
cost_stat           : String     # pool spent to execute this reaction
cost_amount         : float      # base pool cost
mitigation_stat     : String     # which defender stat drives damage reduction (e.g. "dex")
coverage            : Dictionary # target_region → mitigation_multiplier (e.g. {"head": 1.0, "leg": 0.4})
trait_tags          : Array      # pole affinities for AI queuing preference
cooldown_ticks      : int
context_set         : String     # "combat", "social", etc. — which interaction type loads this reaction
trigger_predicates  : Array      # typed predicate dicts; ALL must pass for the reaction to fire
                                 # e.g. [{"type": "positional_awareness"}, {"type": "composure_floor", "min": 0.2}]
                                 # first-phase only implements "positional_awareness"; others reserved
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

# Resolution
net       = attacker_raw - defender_raw
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
CreatureKinematicBody3D._physics_process()
  └─ CreatureCombatComponent._on_physics_tick()
       ├─ contact_test(other_body) → bool
       ├─ if contact && initiator.action_cooldown_elapsed:
       │    result = CombatMath.resolve(action, reaction, attacker_stats, defender_stats, config)
       │    if result.lands:
       │      defender.spend_pool(result.target_pool, result.damage)
       │    set tactic_fight_active = true on MotorContext (V3 struct)
       │    emit signal: combat_hit(attacker, defender, result)
       ├─ each creature queues next action/reaction this tick (AI/goal system decides)
       └─ if any pool hits 0 with no overflow path:
            emit signal: creature_defeated(creature)
            → main_3d.gd._on_creature_defeated()

AiDriver._physics_process()
  ├─ reads tactic_fight_active from MotorContext (V3)
  ├─ raises urgency_avoid_hostiles via trait_tier2_mapper
  └─ on combat episode end → goal_source_memory.try_salient_write(...)
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
9. **Enable `fight` modality salient write** — add `fight` to core modality resource; confirm `goal_source_memory.try_salient_write` emits correct `GoalKind` at episode end.
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

- <<Question: What is the canonical name for the generalized conflict system? (See §1 — blocking for file/class naming.)>>
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
| 2026-06-23 | §11.1 expanded: gates 1–3 confirmed. Gate 4 reframed as typed positional predicates with awareness zone terminology locked (plain language: "awareness zone", "awareness arc", "flanked"). Predicate list design extended to cover non-positional gates (composure threshold, interaction context, future negotiation factors). `trigger_predicates : Array` field proposed for reaction definition; pending confirmation. |

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
A reaction definition may declare one or more **positional predicates** that describe spatial conditions the responder must satisfy for the reaction to be valid. The first concrete instance is the **awareness check**: the attacker must be within the responder's **awareness zone** (a configurable arc — config key `awareness_zone_arc_deg`, label "Awareness Arc") for the reaction to trigger. Outside that zone the responder is considered flanked and the reaction does not fire.

- Awareness zone terminology (config keys, debug overlay, doc references) uses plain language: "awareness zone", "awareness arc", "flanked" — not implementation terms like "observation cone" or "coverage cone".
- Positional predicates on action/reaction definitions are a **typed predicate list**, not a single hardcoded check. Each predicate has a `type` (e.g. `"positional_awareness"`) and its own config-driven parameters. This makes the gate extensible: additional spatial conditions (e.g. elevation, terrain adjacency) can be added without changing the resolution formula.

**Open extension point — non-positional reaction predicates:**
Positional predicates are one predicate type. The same typed list should accommodate non-positional gates that affect whether a reaction is valid in context. Confirmed candidates to specify as the system grows:
- **Composure threshold:** reaction fails if responder's `curr_point_comp` is below a configured floor (creature is too rattled to react reliably).
- **Interaction context match:** the reaction's `context_set` must match the active interaction type (already in the reaction definition as a string field — this is effectively a predicate already).
- **Negotiation / social predicates:** in future non-combat conflict types, additional factors (relationship state, prior concession history, etc.) could gate reactions the same way.

**Design decision:** The reaction definition's predicate list (`trigger_predicates : Array`) should be structured as typed dicts from the start, even if only `positional_awareness` is implemented in this phase. This avoids retrofitting the data shape later.

**Resolved:** `trigger_predicates : Array` confirmed. §4.3 updated.

### 11.2 Motor behavior during active combat

When `tactic_fight_active` is set, what does the motor system actually do?
- Does normal seek/avoidance pause?
- Does the creature hold position, circle, close distance?
- Is there a combat-specific motor sub-mode, or do existing urgency channels handle it naturally?

This needs to be defined before `combat_classifier.gd` can be fully specified.

### 11.3 Pool recovery

No decisions were made on pool recovery:
- Do pools recover between combat episodes (rest) or only across rounds?
- Is there in-combat recovery (slow endurance regen while not actively attacking)?
- What rate governs recovery, and which config key controls it?

### 11.4 Scope: 1v1 only confirmation

The fox-vs-rabbit duel is 1v1. Confirm explicitly: **multi-creature combat (2v1, pack scenarios) is out of scope for this implementation.** The design should not block it architecturally, but no multi-creature logic ships in this phase.

### 11.5 System name (blocking)

The generalized conflict system needs a canonical name before file and class names are locked (see §1 and §9 first question). This blocks implementation naming.

### 11.6 Action/reaction library (separate project)

The full skill tree and action/reaction definitions for fox and rabbit are explicitly deferred to a separate design project. The minimum needed for this phase is one illustrative action/reaction pair (bite + duck/dodge) to validate the formula and component plumbing. That minimum set can be authored as hardcoded data resources for the first pass.
