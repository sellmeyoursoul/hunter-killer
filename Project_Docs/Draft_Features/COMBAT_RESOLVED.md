# Hunter Killer — Combat (resolved contract)

> **Purpose:** Current design contract for direct combat mechanics between creatures — the generalized creature-to-creature conflict interaction model (of which melee combat is the first instance), action/reaction queuing, damage resolution via stat pools, and the goal/motor integration points that let conflict be recognized and acted upon as a distinct Tier-2 goal state.
>
> **Tier:** Draft (tier II) — **no implementation begins until the V3 motor refactor ([CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)) is complete and checked in.** This doc is design-only until that gate clears. Promote to `Definitive_Features/` when design is stable and implementation starts.
>
> **Companion files (see [project-docs.mdc](../../.cursor/rules/project-docs.mdc) — Splitting large drafts):**
> - **[COMBAT_IMPLEMENTATION.md](COMBAT_IMPLEMENTATION.md)** — ordered build plan, acceptance criteria, risks, testing, blocking prep work. "What's next." Deleted once the feature ships to `main`.
> - **[COMBAT_HISTORY.md](COMBAT_HISTORY.md)** — full decision narrative and changelog. "Why we got here." Not needed for routine implementation reads — pull in only when asked why a decision was made.
>
> **Dependencies (read these first):**
> - **[CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md)** — point pool schema (`max_point_*`, `curr_point_*`); stat baselines.
> - **[SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md)** — `stat_to_point` conversion that combat will use to derive point pools from stats.
> - **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)** — motivation tree, `GoalKind` registry, `fight` modality stub, trait axis meanings, `tactic_fight_active` classifier flag.
> - **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** — the active motor refactor that defines `MotorContext`, urgency channels, and the pipeline combat will integrate with. **Combat implementation is gated on this work shipping.**
> - **[CREATURE_MEMORY.md](CREATURE_MEMORY.md)** — salient write gates, locale priors; combat outcomes will produce salient writes keyed on `avoid_hostiles` / future `fight_won` `GoalKind`; combat also extends `_kind_profile.threat_danger`'s write trigger (§11.2).
> - **[CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)** — authoritative stat pool definitions and intended mechanics. Update that file when combat wires a stat pool into code.

---

## 1. Phase summary

**Phase name:** Combat — generalized creature conflict, action/reaction system, and damage resolution

**One-line objective:** Allow two creatures with conflicting goals to exchange actions and reactions against point pools, with outcome signals that feed motor urgency, memory salient writes, and the `fight` tactic classifier.

**Canonical name: Resisted Actions subsystem.** The core mechanic (one creature's action is actively resisted by another creature's queued reaction) abstracts cleanly beyond combat — mating contests, social challenges, and future interaction types fit the same pattern. Naming conventions: file prefix `resisted_action_*` for subsystem-level scripts if the math is ever generalized beyond combat; class names `ResistableAction`/`ResistableReaction` when promoted. For this phase, combat-specific files (`combat_math.gd`, `creature_combat_component.gd`, etc.) keep the `combat_` prefix since combat is the first and only instance — the `resisted_action_*` namespace is reserved for when the substrate is lifted out of combat into a shared layer.

**Scope: 1v1 only.** This phase targets the existing fox-vs-rabbit 1v1 duel only. Multi-creature combat (XvY, pack scenarios) is out of scope for implementation. The design must not architecturally block XvY combat, but no multi-creature logic ships in this phase. Any design decision that would need revisiting or extension to support XvY (action target selection, experience table keying, combat position resolver assuming a single opponent) must be called out explicitly at the point of that decision and approved before implementation proceeds — do not silently make 1v1 assumptions that would require refactoring later.

**Out of scope (explicit non-goals):**
- Ranged or projectile attacks.
- Pack coordination or group-combat orchestration (reserved in **[CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)** trait preamble).
- Trait drift or experience-driven stat change.
- Balance pass — this is a mechanical plumbing spec, not an economy spec.
- Saving or persisting combat history across sessions.
- Conspecific combat (creature vs. same species); this phase targets the existing fox-vs-rabbit duel only.
- Full action/reaction library (skill trees) — §9 is a minimal test set only.
- Graduated partial-deal resolution for barter-type interactions — explicitly deferred.

**Implementation gate:** does not start until **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)** is complete and merged. See [COMBAT_IMPLEMENTATION.md](COMBAT_IMPLEMENTATION.md) for the ordered build plan.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot 4.6

**Main scenes / entry:**
- `res://main_3d.gd` — round lifecycle; combat round-end condition hooks go here.
- `res://creature/capabilities/creature_vitals_component.gd` — existing calorie + predation math; point pool consumption is a sibling concern.
- `res://creature/capabilities/creature_kinematic_body_3d.gd` — collision body; existing `MobHitbox` `Area3D` predation trigger lives here (herbivore-only, out of scope for combat's own contact/range checks — see §4.4).

**Key scripts (paths — planned or existing):**

| Status | Path | Role |
|--------|------|------|
| existing | `res://creature/capabilities/creature_vitals_component.gd` | Calorie burn, starvation — combat damage is additive drain on separate point pools |
| existing | `res://creature/capabilities/creature_vitals_math.gd` | Pure calorie math; combat math follows same pure-function pattern |
| planned | `res://creature/capabilities/creature_combat_component.gd` | Action/reaction queue, damage dispatch; sibling to vitals |
| planned | `res://creature/combat/combat_math.gd` | Pure stat → damage formulas (no Node state); headless-testable |
| planned | `res://creature/stat_math.gd` | `stat_to_point()` — per [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md); may already exist |
| planned | `res://creature/motor/combat_classifier.gd` | Sets `tactic_fight_active` on the salient-write carrier at combat episode outcome; feeds salient emitter |
| planned | `res://creature/combat/action_definition.gd` | Data resource: cost stat, outcome stat, target region, trait affinities, threshold, cooldown, positional criteria |
| planned | `res://creature/combat/reaction_definition.gd` | Data resource: cost stat, mitigation stat, coverage profile, trait affinities, cooldown, context set |
| planned | `res://creature/combat/combat_position_resolver.gd` | Pure function: action criteria + positions → target `Vector3` for seek planner and positional modifier float; also the contact/range check combat uses instead of physics collision events (§4.4) |
| planned | `res://creature/combat/combat_experience_table.gd` | Per-creature transition pair table (`prev_action_id → curr_action_id → weight`); updated from combat outcome signals |
| planned | `res://creature/combat/combat_experience_math.gd` | Pure `rank_score(weight, attempt_count, success_count, marginal_attempt_count, marginal_success_count, traits, axis_config, n_sat, n_min) -> float`; shared novelty-vs-proven ranking formula, reused by three separately-shaped table classes (self-experience, opponent-observation, spatial overlay) via a generalized `trait_rank_bias(traits, axis_config)` sub-helper — see §10 |
| planned | `res://creature/combat/combat_threat_assessment.gd` | Pure `relative_threat_mod(...) -> float`; composes banded perceived-condition weight, size-ratio incidental threat, visible danger-sign score, `creature_behavior` placeholder, and `compassion_self_interest` disposition bias into V3's `urgency_flight` threat term. Deliberately excludes species-level experience — that's already `kind_threat`/`_kind_profile` (existing MEMORY infra). See §11.2. |

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
- Motor recognition: `tactic_fight_active` flag set at combat episode outcome (§11.5).
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

> **Note:** The data flow below references urgency channels as they will be defined by **[CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)**. Exact field names must be reconciled against V3 once it ships before this section is treated as authoritative.

### 4.1 Generalized conflict model

Combat is the first instance of a broader **creature-to-creature conflict** pattern: two creatures whose current goals are incompatible attempt to resolve that conflict through a sequence of actions and reactions. The same mechanical substrate will eventually cover mating contests and barter negotiations.

**Key terminology:**
- **Initiator** — the creature whose goal requires a change in the other creature's behavior (fox wants to eat the rabbit).
- **Responder** — the creature whose current goal is disrupted by the initiator (rabbit wants to not be eaten).
- These roles are not fixed. If the responder overpowers the initiator, roles may flip: the original initiator's dominant goal becomes flee, and the original responder decides whether to pursue.

**Resolution is emergent — not a state machine:**
There is no explicit "combat ends" condition. Each creature re-evaluates its goal weights every tick. When the cost of continuing (depleted pools, injury risk) exceeds the expected gain (meal, safety), the creature's goal system naturally shifts to a different dominant goal (flee, forage, etc.). The conflict ends when neither creature's dominant goal requires the other's participation. This same principle extends to *entry* into combat/flight, not just exit — see §11.4.

**Engagement forcing:**
Some actions (e.g. a Dex-reducing attack) can make the responder's flee goal harder to execute even when it is dominant, by degrading the motor capability needed to carry it out. This is a natural extension — it modifies the responder's stats, which the goal system then operates on.

**Interaction types and reaction sets:**
Reaction slots are context-scoped. A combat encounter loads a combat reaction set (dodge, block, counterattack). A social encounter loads a different set. The active context is resolvable from the creature's current dominant goal and the `tactic_fight_active` (or equivalent) classifier flag.

### 4.2 Stat pools and the stat wheel

All eight creature stats participate in combat. Each stat has a `curr_point_*` pool derived from `stat_to_point(stat_*)` at spawn (full on spawn; spent during combat).

**Stat wheel (overflow order):**
```
Fit → End → Will → Comp → Obs → Charm → Wit → Dex → Fit (wraps)
```
When a pool hits 0, the creature may pay costs from either adjacent pool at **2:1 rate**. The creature (or action definition) chooses which neighbor to drain.

**Overflow affects cost payment only — never the depleted pool's own reading.** Once a pool is at 0 and a cost is being paid from a neighbor at 2:1, the depleted pool's `curr_point_*` stays locked at `0` for every other calculation that reads it — `pool_scale()` in §4.4's resolution formula, mitigation math, `relative_threat_mod`'s condition bands (§11.2), anywhere else `curr_point/max_point` is sampled. Overflow only moves points out of the *neighbor*; it never restores, credits, or otherwise blends into the empty pool's own value. A creature with `curr_point_fit = 0` deals damage at `pool_scale(0) = 0.25` (the floor) regardless of how many `curr_point_end` points are being spent to keep queuing Fit-costing actions — there is no mechanism to buy back into a higher `curr_scale` band by drawing on a neighbor.

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

### 4.3 Action and reaction data shape

Every action and reaction is a data resource with these fields:

**Action definition:**
```
action_id             : StringName  # stable key used by experience table and memory writer
costs                 : Array       # [{stat: String, amount: float}, ...] — multi-stat cost support
outcome_stat          : String      # which attacker stat drives damage (e.g. "fit")
secondary_effects     : Array       # [{pool: String, amount: float}, ...] — flat pool damage on landing
trait_tags            : Array       # pole affinities — creature prefers this action when aligned (e.g. ["self_interest"])
threshold             : float       # minimum net result for the action to land
cooldown_ticks        : int         # ticks before this action can be queued again
observation_unlock_sec : float      # seconds of active combat before this action becomes available (0 = always) — see §4.6
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
cost_incoming_fraction   : float       # when non-zero: cost = incoming_damage × this (applies to all incoming damage from the action being reacted to); overrides costs entries
mitigation_stats         : Array       # stats contributing to defender_raw (may be empty)
mitigation_type          : String      # formula path: "stat_modifier" | "pool_ratio" | "stat_modifier_sum"
mitigation_cap           : float       # upper bound for "pool_ratio" type; ignored by other types
mitigation_coverage      : float       # flat 0.0–1.0 multiplier on reaction effectiveness
secondary_effects        : Array       # [{pool: String, amount: float}, ...] — flat pool effect dealt to attacker on fire
damage_reduction_per_sec : float       # flat damage reduction per second of fight duration (0 = disabled)
damage_reduction_max     : float       # cap on the above
embeds_queued_action     : bool        # true → queued action fires as part of this reaction; both cooldown independently
trait_tags               : Array       # pole affinities for AI queuing preference
cooldown_ticks           : int
context_set              : String      # "combat", "social", etc.
trigger_predicates       : Array       # typed predicate dicts; ALL must pass for the reaction to fire — see below
```

**`trigger_predicates` — typed predicate list, not a single hardcoded check.** Each predicate has a `type` (e.g. `"positional_awareness"`) and its own config-driven parameters, so additional gates (elevation, terrain adjacency, composure threshold, interaction-context match, future negotiation factors) can be added without changing the resolution formula. Implemented this phase: `"positional_awareness"`, `"incoming_damage_nonzero"`. Awareness-zone terminology (config keys, debug overlay, doc references) uses plain language — "awareness zone", "awareness arc", "flanked" — not implementation terms like "observation cone."

**Base gates, always checked before `trigger_predicates`:**
1. The responder has a reaction queued (chose one this tick).
2. The reaction's cooldown has expired.

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
stat_max_mod_def  = stat_to_point(reaction.mitigation_stat_value) - stat_to_point(10)
curr_scale_def    = pool_scale(curr_point_def / max_point_def)
outside_def       = config.get(reaction.outside_influence_key, 0.0)

defender_raw = (stat_max_mod_def + stat_max_mod_def * curr_scale_def + outside_def) * reaction.mitigation_coverage

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

**`stat_to_point(10)` as zero anchor:** stat 10 is the default. A creature at stat 10 contributes 0 modifier. Above-average stats add a diminishing positive; below-average adds a negative, symmetric diminishing returns.

**Contact / range check — reuses `CombatPositionResolver`'s pure `Vector3` distance/arc math, not a physics event.** `positional_modifier()` and the arc/range gates above are plain distance/angle comparisons against `action.preferred_range`/`preferred_arc_deg`, fed by positions already threaded through the motor pipeline each tick — the same continuous position-comparison pattern every other motor function uses (`cardinal_avoidance.gd`, `seek_planner.gd`). No `Area3D` child node, no `get_slide_collision_count()` polling — both are Node-coupled and conflict with the project's "motor logic must be pure, headlessly testable" convention. The existing herbivore-only `MobHitbox` `Area3D` (`creature_kinematic_body_3d.gd`) is a separate, already-shipped, single-purpose predation/round-end trigger and is not reused or extended here.

**Observation check (reaction gating):** if the attacker's approach angle is outside the responder's awareness cone (flanked), the reaction does not trigger regardless of queue state. The responder's `stat_observation` governs the cone width.

**No reaction queued / reaction on cooldown:** `defender_raw = 0`. Undefended hit; full attacker roll vs threshold.

**Illustrative example — fox bites rabbit, rabbit has a duck-type reaction queued:**
```
Fox:    stat_fit=14, curr_point_fit=80%, outside=0
Rabbit: stat_dex=12, curr_point_dex=60%, outside=0, mitigation_coverage=0.4

stat_max_mod_att  = stat_to_point(14) - stat_to_point(10)  →  positive delta
curr_scale_att    = pool_scale(0.80)                        →  ~0.87
attacker_raw      = -10 + delta + delta*0.87 + 0           →  some positive number

stat_max_mod_def  = stat_to_point(12) - stat_to_point(10)  →  smaller positive delta
curr_scale_def    = pool_scale(0.60)                        →  ~0.70
defender_raw      = (def_delta + def_delta*0.70) * 0.4     →  reduced because coverage is weak

net     = attacker_raw - defender_raw                       →  positive (fox favored)
result  = net + variance
lands if result > bite_threshold
```
Higher `mitigation_coverage` (e.g. `1.0` for a well-aimed duck) roughly doubles `defender_raw` in this example — bite likely fails or deals minimal damage.

### 4.5 Feints and wit

A feint is an action whose `outcome_stat` is `wit` and whose effect on landing is **not** pool damage but **reaction slot burn**: the responder's queued reaction fires (spending its cost) against nothing, and enters cooldown.

**Feint detection — `stat_wit` vs. `stat_wit` opposed contest.** The responder's own `wit` (or `observation`) stat determines whether they read the feint and withhold their reaction. Exact formula shape (reusing §4.4's resolve() pattern vs. a simpler opposed-roll check) is left to whenever the definitive feint action is authored — deferred like every other numeric constant in this doc, not decided here.

### 4.6 Observation-unlocked actions

Each action and reaction has an `observation_unlock_sec` field. Until the combat episode has been active for at least that many seconds, the action/reaction is not available for queuing. High `stat_observation` reduces the unlock time (the creature reads the opponent faster).

<<Comment: The exact formula for `observation_unlock_sec` reduction from `stat_observation` is not yet specified. First-pass: `effective_unlock = observation_unlock_sec * (stat_to_point(10) / stat_to_point(stat_observation))` — tune in play.>>

**Timer scope — per opponent instance, not per episode.** The unlock timer is fed by `combat_observation_sec` (§11.1), which is scoped to the specific opponent's `instance_id` and persists across disengage/reengage with that same opponent — it does not reset just because the current combat episode ends. It expires only when that opponent falls out of memory entirely, i.e. whenever its awareness-ledger row (§11.1) is evicted/forgotten (exact eviction rule is an open dependency — §13).

### 4.7 Persistence and disengagement

Each tick, each creature re-evaluates its dominant goal. A creature disengages when some combination of the following tips the goal weight away from the conflict:

- **Pool depletion:** `curr_point_end`, `curr_point_fit`, and `curr_point_will` are low. `stat_will` raises the threshold before the goal tips.
- **Composure degradation:** low `curr_point_comp` makes the creature make poorer action/reaction decisions, which in turn accelerates pool loss. Intimidation attacks target this directly.
- **Goal urgency shifts:** an external event (starvation, a higher-priority threat) raises a competing goal above the conflict's urgency weight.

The motor system does not need a "flee from combat" special path. When `avoid_hostiles` urgency rises above the combat goal weight, the creature's seek target shifts naturally. The opponent may or may not pursue based on their own goal evaluation.

### 4.8 Architecture / data flow

```
── Established goal→objective→action pipeline (unchanged) ──────────────────
AiDriver._physics_process()
  ├─ evaluates all goal weights each tick (urgency channels, trait modifiers,
  │   pool states, tactic_fight_active urgency multiplier)
  ├─ dominant goal resolves into sub-step objectives (seek target, motor intent)
  │    └─ when fight/flight is dominant:
  │         CombatPositionResolver.resolve_combat_target(pos, opponent_pos, queued_action)
  │         → Vector3 fed to SeekPlanner as ultimate_goal this tick
  └─ sub-step objectives resolve into queued action/reaction:
       candidate actions filtered by: cooldown elapsed, observation_unlock_sec, arc_required
       selection: highest combat_rank_score (§10) — not raw trait_affinity + weight
       → action/reaction slots written to CreatureCombatComponent

── Combat mechanical resolution (reads from the above; does not drive goals) ─
CreatureKinematicBody3D._physics_process()
  └─ CreatureCombatComponent._on_physics_tick()
       ├─ in_range_test(other_body) → bool   # CombatPositionResolver distance/arc check, §4.4 — no Area3D
       ├─ if in_range && action_cooldown_elapsed:
       │    pos_mod = CombatPositionResolver.positional_modifier(pos, opponent_pos, action)
       │    result  = CombatMath.resolve(action, reaction, attacker_stats, defender_stats, config, pos_mod)
       │    if result.lands:
       │      defender.spend_pool(result.target_pool, result.damage)
       │      experience_table.record(prev_action_id, action.action_id, result.outcome_score)
       │    emit signal: combat_hit(attacker, defender, result)
       └─ if any pool hits 0 with no overflow path:
            emit signal: creature_defeated(creature)
            → main_3d.gd._on_creature_defeated()
              — runs alongside (not replacing) the existing predation calorie-transfer path;
                placeholder until objects land (meat-drop) — see §4.9
            → AiDriver: goal_source_memory.try_salient_write(...)
                 GoalKind: avoid_hostiles (loser) or fight_won (winner) — resolved, §12
                 modality_tags: [fight]
                 outcome_envelope: defeat / victory
            → combat_threat_assessment: extend _kind_profile.threat_danger write trigger
                 to fire at combat episode end too, fed by effectiveness/outcome_score (§11.2, §10)
```

### 4.9 Dependencies

- **V3 motor refactor ([CREATURE_MOVEMENT_V3](CREATURE_MOVEMENT_V3)) must be complete and merged** before any combat implementation begins.
- **`stat_to_point()`** from **[SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md)** must exist before combat point pools can be initialized.
- **`tactic_fight_active`** flag — stub in **[CREATURE_GOAL_DRIVERS.md §5.1.1](CREATURE_GOAL_DRIVERS.md)**; carried by V3's salient-write context (renamed from `MotorContext` — see §11.5).
- **`fight` modality** in core modality allowlist — stub in **[CREATURE_GOAL_DRIVERS.md §5 modality table](CREATURE_GOAL_DRIVERS.md)**; must be promoted to the engine core modality resource as part of or after V3.
- **`fight_won` `GoalKind`** — new pack-extension entry needed in **[CREATURE_GOAL_DRIVERS.md](CREATURE_GOAL_DRIVERS.md)**'s `GoalKind` registry; unlike `tactic_fight_active`/`fight` modality above, it does not yet exist there even as a stub. Winner's salient write on defeat (§4.8) is blocked on this registry entry landing.
- **[CREATURE_ATTRIBUTES_USAGE.md](../Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md)** — update §3 per-stat entries to **Specified** or **Live** as each pool is wired.
- **Predation/`creature_defeated` interaction:** kill still triggers round-win, and the predator still gets calories via the existing `creature_predation_math.gd` transfer — `creature_defeated` is the new trigger point for that path, not a replacement of it. Explicitly placeholder until objects land (a defeated creature should drop an edible meat object instead of an instant transfer). Once actions/reactions ship, `creature_defeated` fires from pool depletion (§4.7), not from `MobHitbox`'s current instant-touch trigger.
- **`fight_won` vs. `find_food` once meat-drop objects land:** flagged, not designed — once a kill drops a lootable meat object instead of an instant calorie transfer, "predator ate" becomes multi-step (find prey → win fight → loot corpse), and `find_food`'s process likely needs refinement to represent that chain. `fight_won` is intended as the mid-point `GoalKind` between locating prey and looting the corpse, not a replacement for either. Out of scope for this phase; revisit once the meat-drop system is designed.

---

## 5. Motor behavior during active combat

Normal goal evaluation continues every tick unchanged. There is no combat-specific motor sub-mode. `tactic_fight_active` applies a configured urgency multiplier to fight/flight goal weights so they dominate over incidental goals (e.g. foraging) unless a competing goal reaches higher urgency (e.g. imminent starvation).

**Positioning is driven by the queued action, not by a separate motor mode:** each action definition carries `preferred_range`, `preferred_arc_deg`, `arc_required`, and `position_weight`. While an action is queued, `CombatPositionResolver.resolve_combat_target()` computes a target `Vector3` — the closest valid point on the preferred-range arc — and feeds it to `SeekPlanner` as the tick's `ultimate_goal`. SeekPlanner is unchanged; it moves toward a point as always.

**Hard vs. soft positioning:**
- `arc_required = true`: action is not queueable until positional criteria are met. Each tick the goal system re-evaluates: the creature repositions toward the action's target point until in position, or until a higher-urgency goal or a different action takes precedence and replaces the queued slot.
- `arc_required = false`: action can fire from any position; `CombatPositionResolver.positional_modifier()` attenuates the resolution result toward `combat_position_mod_floor` (config, default `0.5`) when off-position. A sub-optimal attack can still land.

**Flanking as emergent behavior:** because being outside an opponent's awareness arc degrades their reaction (§4.4), creatures have an implicit incentive to queue flanking-arc actions. No explicit "circle" motor mode is needed — the position resolver picks the closest valid arc point, which will naturally be off to the side when that is what the queued action prefers.

---

## 6. Pool recovery

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

Higher stat → more absolute points per second, but pool grows faster than rate, so fill time increases. The curve is intentionally shallow — a strong creature is not punished harshly for having large pools.

**Recovery scope:** applies between combat episodes within a round, not only between rounds. A creature that disengages and rests mid-round recovers. In-combat recovery is zero (strenuous state). No cross-session persistence of pool state in this phase.

**Dependency:** `stat_to_point(stat)` from `res://creature/stat_math.gd` must exist before recovery can be implemented — blocking prep work tracked in [COMBAT_IMPLEMENTATION.md](COMBAT_IMPLEMENTATION.md).

---

## 7. Test action/reaction set

The full action/reaction library for fox and rabbit is deferred to a separate design project. The following minimal set validates the mechanical plumbing only — not guaranteed to ship in the final implementation.

#### Actions

**Bite**
```
action_id             : &"bite"
costs                 : [{stat: "end", amount: 5}]
outcome_stat          : "fit"
secondary_effects     : [{pool: "comp", amount: 3}]
threshold             : 0.0                        # TBD during balance pass
cooldown_ticks        : 120                        # 2 seconds at 60 ticks/sec
preferred_range       : 0.0
preferred_arc_deg     : 0.0
arc_required          : false
requires_flanking     : false
position_weight       : 0.0
observation_unlock_sec: 0.0
```
*Tests:* primary stat damage (Fit pool), secondary flat damage (Composure), no positional requirement, basic cooldown.

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

#### Reactions

**Absorb**
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

**Dodge**
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

**Bite Back**
```
reaction_id           : &"bite_back"
costs                 : []
cost_incoming_fraction: 0.2                        # cost = incoming_damage × 0.2, applied to all incoming damage from the action being reacted to
mitigation_stats      : []
mitigation_type       : "stat_modifier"
mitigation_coverage   : 0.0                        # does not reduce incoming damage
secondary_effects     : [{pool: "comp", amount: 10}]   # deals 10 Composure to attacker on firing
cooldown_ticks        : 180                        # 3 seconds
context_set           : "combat"
trigger_predicates    : [{type: "positional_awareness"}]   # attacker must be within defender's awareness arc (face-to-face)
```
*Tests:* dynamic cost (`cost_incoming_fraction`), zero damage mitigation, secondary effect dealt to attacker, positional trigger predicate (face-to-face — inverse of flanking).

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
*Tests:* time-based damage reduction, embedded action mechanic, dual cooldown, `incoming_damage_nonzero` trigger predicate.

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
| Feint (wit vs wit, reaction slot burn) | §4.5 |
| Stat wheel overflow (2:1 neighbor drain) | Needs a scenario that drives a pool to 0 |

---

## 8. Combat experience table

**Goal:** Let creatures learn which action sequences are effective without ever hardcoding "do B after A." The full action set remains available; experience shifts selection weights so discovered effective transitions become more probable over time.

**Data shape — transition pair table:** each creature instance owns a `CombatExperienceTable`: a dictionary keyed on `prev_action_id → curr_action_id → { weight, fast_weight, attempt_count, success_count }` (fields beyond `weight` — §10). `weight` and `fast_weight` both initialize to `1.0` (neutral) for all pairs at spawn. Only transition pairs the creature has actually attempted accumulate meaningful signal.

**Recording:** after each action resolves, `experience_table.record(prev_action_id, curr_action_id, outcome_score)` updates two parallel EMAs of the same `outcome_score` signal at different decay rates: `weight` (the long-run estimate, `combat_exp_ema_alpha` default `0.2`) and `fast_weight` (a faster-moving companion, `combat_exp_fast_ema_alpha` default `0.5`, feeding §10's `delta_factor`) — `weight = (1 - alpha) * weight + alpha * outcome_score`, same update for `fast_weight` at its own faster `alpha`. `outcome_score = benefit_score - cost_ratio` (§10) — positive when the exchange was favorable, negative when costly.

**Consumption:** during action queuing (§4.8), candidates are ranked by `combat_rank_score` (§10) — not raw `trait_affinity_score + weight`.

**Cold start:** new creatures start with all weights at `1.0`, `attempt_count = 0`, `success_count = 0`. No prior is inherited at spawn. Experience is per-creature-instance and persists only for the creature's lifetime.

**Inheritance (deferred):** when the reproduction subsystem ships, a child creature's starting experience table will be seeded from a blend of its parents' tables at a configured dilution factor. See [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) §Heredity.

**Scope boundary:** this phase implements only the per-instance table and EMA update. Inheritance, persistence across sessions, and cross-creature comparison are explicitly deferred.

---

## 9. Opponent observation table

A symmetric counterpart to §8: each creature maintains a per-creature-lifetime record of what its opponent has done and what response the creature used in reply, so it can learn response tendencies against observed opponent action patterns without any explicit encoding of strategy.

**Write trigger:** written whenever an opponent action resolves (landed or not), using `outcome_score` (§10) as the EMA signal. Positional awareness of the attacker is not required — a creature does not need to see an attack to experience its outcome. `trigger_predicates` governs *reaction firing* only; observation writes have their own, simpler trigger.

**Scope — per-creature-lifetime, per action (not per species):** keyed on `opponent_action_id → own_response_id → { weight, fast_weight }`, scoped per creature instance. A creature that dies takes its table with it.

**Observation-rate dampening — 25% of `combat_exp_ema_alpha` (and `combat_exp_fast_ema_alpha` for `fast_weight`), not a sampling gate.** `record()` still fires on every opponent-action resolve — `attempt_count`/`success_count` increment 1:1 with real occurrences, same as the self-table. The 25% figure only scales how far `weight`/`fast_weight` move per event (secondhand outcome data shifts the estimate more cautiously than a self-attempted action would); it does not affect confidence/evidence, which is why `combat_exp_n_sat`/`combat_exp_n_min` are shared across all three tables (self, opponent-observation, spatial overlay) rather than needing separate scaled versions. Full-rate observation learning via a `stat_observation`-gated skill is deferred (`ENHANCEMENT_BACKLOG_PLAN.md`).

**Action-id agnostic:** the table works with any `action_id` StringName regardless of interaction context (combat, social, mating). Context-class flags are deferred; the `context_set` field on reaction definitions provides scoping when needed.

**Separate tables, aligned interface:** the self-experience table (§8) and the opponent observation table are separate data structures, both exposing the same `record(prev_id, curr_id, outcome_score)` / `weight(prev_id, curr_id) -> float` contract so they can be merged in a future refactor without breaking call sites.

**Positional response overlay:** positional learning ("stay face-to-face more") is a separate per-creature dict of named positional biases updated via EMA when opponent actions with positional criteria resolve, regardless of outcome (landed or failed) — `outcome_score` is the EMA signal. `CombatPositionResolver` reads these as additive weights on top of the queued action's `position_weight`. Keys are derived at runtime from positional fields on action definitions (e.g. `requires_flanking = true` → `maintain_awareness_arc`); all biases initialize to `0.0` (tuning deferred to a balance pass). Each bias key also carries a `fast_bias` companion EMA (`combat_exp_fast_ema_alpha`, same as the pair tables) feeding §10's `delta_factor` — same mechanism, applied per bias key instead of per pair. Same per-creature-lifetime scoping and 25%-rate rule as above; shares `combat_exp_n_sat`/`combat_exp_n_min` — no separate saturation constants.

**Inheritance:** heritable, same deferred timeline as §8. See [CREATURE_EVOLUTION_AND_MOTOR_GENOME.md](CREATURE_EVOLUTION_AND_MOTOR_GENOME.md) §Heredity.

---

## 10. Selection-rule ranking — novelty vs. proven

Reuses `goal_source_memory.gd`'s Slot B replay formula shape (`CREATURE_GOAL_DRIVERS.md §5.1.2` — confidence × `change_stability`-driven novelty/proven lerp) rather than a new mechanism, so a newly-available action isn't permanently starved by an already-reinforced favorite under naive argmax selection.

**Fields (per transition-pair entry, alongside `weight`):**
```
weight         : float   # existing EMA of outcome_score — init 1.0
fast_weight    : float   # faster-decaying companion EMA of the same outcome_score — init 1.0; feeds delta_factor below
attempt_count  : int     # times this pair has been recorded — init 0
success_count  : float   # graduated landing-quality accumulator (see below) — init 0.0
```

**Rank score formula (extends the pair table with a marginal `curr_action_id`-keyed aggregate for hierarchical backoff — keeps sequence-specific learning while avoiding fragmentation as the action pool grows):**
```
# maintained alongside the pair table, per creature:
marginal_table : curr_action_id -> { attempt_count, success_count }

# on every record(prev_action_id, curr_action_id, outcome_score, effectiveness):
pair.attempt_count      += 1
pair.success_count      += effectiveness
marginal[curr_action_id].attempt_count += 1
marginal[curr_action_id].success_count += effectiveness
# fast_weight update (see §8's Recording) happens alongside weight's, same record() call

# at read time, for a candidate (prev_action_id, curr_action_id):
pair_evidence      = 1 - exp(-pair.attempt_count / combat_exp_n_sat)
marginal_evidence  = 1 - exp(-marginal.attempt_count / combat_exp_n_sat)
backoff_weight     = min(1.0, pair.attempt_count / combat_exp_n_min)     # reuses thin_cap, no new tunable
evidence           = lerp(marginal_evidence, pair_evidence, backoff_weight)

pair_success_rate     = pair.success_count / max(pair.attempt_count, 1)
marginal_success_rate = marginal.success_count / max(marginal.attempt_count, 1)
success_rate          = lerp(marginal_success_rate, pair_success_rate, backoff_weight)

thin_cap        = backoff_weight
mixed_penalty   = 4 * success_rate * (1 - success_rate)
failures        = pair.attempt_count - pair.success_count
streak_bonus    = (failures == 0 && pair.attempt_count > 0) ? (1 - evidence) : 0
novelty_score   = (1 - evidence) * (1 - mixed_penalty) + streak_bonus
proven_score    = evidence * (0.5 + 0.5 * success_rate)

# recent-trend confidence modifier — mirrors CREATURE_GOAL_DRIVERS.md's Slot B delta_factor,
# but derived from a fast/slow EMA pair instead of a windowed success_delta (no window buffer needed)
delta_sign      = sign(pair.fast_weight - pair.weight)      # fast EMA pulling above/below the slow trend
delta_factor    = clamp(1 + combat_exp_delta_strength * delta_sign,
                         1 - combat_exp_delta_strength, 1 + combat_exp_delta_strength)

confidence      = clamp(evidence * (0.5 + 0.5 * success_rate) * thin_cap * delta_factor, 0, 1)
trait_rank_bias = trait_rank_bias(traits, axis_config, novelty_score, proven_score)   # below

combat_rank_score = (trait_affinity_score + weight) * confidence * trait_rank_bias
```
`weight` and `fast_weight` are **not** blended with the marginal — a new pair for an otherwise well-proven action still initializes both at flat neutral `1.0`; only the confidence/novelty read benefits from the marginal's data. `combat_exp_delta_strength` (default `0.1`, mirrors `CREATURE_GOAL_DRIVERS.md`'s bound) is its own independently-tunable constant, same reasoning as `combat_rank_chaos` (§12) — not assumed to share a value with Slot B's. Candidate selection: among actions passing cooldown/`observation_unlock_sec`/arc gates (§4.8), pick the highest `combat_rank_score`.

**Scope — applies uniformly to all three tables (self-experience, opponent-observation, spatial overlay).** Unlike the marginal/backoff mechanism below (which depends on pair-vs-flat-dict storage shape and exempts spatial overlay), `delta_factor` only needs a value's own fast/slow EMA pair — every table already tracks one (`weight`/`fast_weight` for the pair tables, `bias`/`fast_bias` for the spatial overlay), so there is no exemption case here.

**`trait_rank_bias` — shared, generalized helper (not combat-specific math):**
```
trait_rank_bias(traits: Dictionary, config: Dictionary, novelty_score: float, proven_score: float) -> float

config = {
    primary_axis : String   # e.g. "change_stability" or "explorer_builder"
    modifiers    : Array    # [{axis: String, strength: float}, ...] — [] = none
}

primary    = traits[config.primary_axis] / 100.0   # -1 (first pole) .. +1 (second pole)
base_t     = (primary + 1.0) / 2.0                  # 0 = first pole, 1 = second pole
gate       = max(primary, 0.0)                       # only a second-pole lean gates modifiers

modulation = 0.0
for m in config.modifiers:
    modulation += (traits[m.axis] / 100.0) * gate * m.strength

t = clamp(base_t + modulation, 0.0, 1.0)
return lerp(novelty_score, proven_score, t)
```
Combat's config: `{primary_axis: "change_stability", modifiers: []}` — collapses to `t = (change_stability + 100) / 200`. Spatial overlay's config: `{primary_axis: "explorer_builder", modifiers: [{axis: "change_stability", strength: spatial_cs_modulation}]}` (`spatial_cs_modulation` default TBD — balance pass). `community_individual`/`compassion_self_interest` are not wired into either config — both remain available `modifiers` slots for a future decision.

**Landing-quality mapping (`success_count` is graduated, not binary):**
```
# ceiling_damage: §4.4's formula evaluated at this action's best case —
# full attacker pool, undefended, no variability roll. Pure function of action + attacker stats.
expected_max_damage = ceiling_damage(action, attacker_stats)
damage_ratio  = damage / max(expected_max_damage, EPSILON)
effectiveness = clamp(damage_ratio * 0.75, 0.0, 1.0)   # hitting the expected ceiling reads as 0.75, leaving
                                                        # headroom above it for outperformance
success_count += effectiveness   # float accumulator, not binary +1
```
A non-landing action (`damage = 0`) contributes `effectiveness = 0`.

**`outcome_score` (feeds `weight`'s EMA, domain-general shape):**
```
outcome_score = benefit_score - cost_ratio
```
- `benefit_score` — domain-specific plug-in; for combat, this **is** `effectiveness` above.
- `cost_ratio` — domain-general: `sum_over_costs(amount / max_pool_for_stat)`, reusing the existing `costs: Array` pattern (§4.3). No new fields.

**Tie-break / near-tie chaos:** reuses `CREATURE_MOVEMENT_V3`'s `blocked_objective_chaos`/`goal_consideration_chaos` precedent. New `combat_rank_chaos` config key: when two or more candidates' `combat_rank_score` fall within an epsilon band, apply light RNG jitter to decide among them. This only perturbs near-equal candidates — it does not override a large, persistent gap, which is `trait_rank_bias`'s intended effect for a strongly Stability-leaning creature (not a bug to be "fixed" with a forced-exploration mechanism).

**Resolved:** `combat_rank_chaos` is its own independent config key — it does not share `0.15` (or any other value) with V3's `blocked_objective_chaos`/`goal_consideration_chaos` defaults, since `combat_rank_score` sits on a different scale. `0.15` is only a starting point for tuning, not a shared constant; expected to trend larger in practice since combat is intended to read as more chaotic than ordinary goal selection. A stat/skill-driven modulation of `combat_rank_chaos` (e.g. `stat_observation`/`stat_wit`/`stat_composure` narrowing the epsilon band to reflect experience or discipline) is a plausible future extension but explicitly out of scope for this implementation — tracked in [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md).

**Marginal/backoff applies to the opponent-observation table (§9) the same way**, keyed on `own_response_id` — and for a stronger reason than the self-table's fragmentation concern: a reaction is queued before the opponent's action is known, so reaction selection can never condition on the specific incoming move anyway, only on the responder's overall history against this opponent; the marginal already **is** that signal. **Spatial overlay is exempt** — it isn't pair-keyed (a flat dict of bias keys), so it calls the shared math with `marginal_attempt_count = attempt_count` / `marginal_success_count = success_count` (its own values standing in for both slots — the backoff lerp collapses to a no-op).

**Shared pure module, not a generic table class:** `combat_experience_math.gd` exposes stateless `rank_score(...)` (plus `trait_rank_bias(...)`), called by three separately-shaped table classes (self-experience, opponent-observation, spatial overlay) — the math is identical, but storage shape differs (pair+marginal vs. flat dict; `1.0` vs `0.0` init), so a single generic class would entangle stateful per-table concerns with the one piece of this design meant to stay pure and headlessly testable.

**Resolved:** carried forward, via a cheaper mechanism than Slot B's windowed `success_delta`. Rather than a rolling-window buffer, each tracked value (`weight`/pair, `bias`/spatial-overlay key) gains a single faster-decaying companion EMA (`fast_weight`/`fast_bias`, `combat_exp_fast_ema_alpha`) of the same underlying signal, and `delta_factor` reads the sign of their divergence instead of a windowed trend — same shape and same bounded ±`combat_exp_delta_strength` effect on `confidence` as `CREATURE_GOAL_DRIVERS.md`'s original, one new float per tracked value instead of a window/buffer. Motivating case: combat is adversarial in a way Slot B's location replay isn't — an opponent that starts reading a previously-effective action's timing should knock that pair's `confidence` down before the flat lifetime `success_rate` catches up, so a creature isn't re-queuing a losing pattern for several more attempts than necessary. See [COMBAT_HISTORY.md](COMBAT_HISTORY.md).

---

## 11. `Fight` hub goal and urgency integration

Two integration points for V3's motor hub: a **salient-write carrier** (memory-write gating at combat episode outcome — V3 resolves this concretely, renaming `MotorContext` → a salient-write context; combat's remaining task is a mechanical field sweep, tracked in [COMBAT_IMPLEMENTATION.md](COMBAT_IMPLEMENTATION.md)) and **hub urgency / goal-weight** (live, per-tick — V3 does not resolve this; combat defines it below).

### 11.1 Live engagement ledger

Live engagement/threat state is a **per-instance awareness ledger**, not a single bool — each creature holds a per-instance record keyed by the other creature's `instance_id`, one entry per creature currently relevant to it. Mirrors existing per-instance patterns in the codebase (`motor_target_builder.gd`'s `collect_prey_entries()`; V3's own `_goal_belief`) rather than inventing a new idiom.

**Fields, this phase:**
- `threat_trigger : bool` — this specific other creature is perceived as an active threat.
- `engaged : bool` — self's own goal system has locked onto this specific instance as a live target it is actively pursuing.
- `combat_observation_sec : float` — accumulator feeding §4.6's `observation_unlock_sec` gating for actions targeting this specific opponent.
- Reserved, not designed this phase: fields for other pair-relationship concepts (e.g. mate suitability) that will want the same per-instance shape later.

**Two distinct trigger moments, on two different entries:**
- **Aggressor's `engaged` flips true at goal-commit, not at first attack** — the moment the aggressor's own goal system locks onto this instance as its live target (urgency × feasibility wins consideration), independent of physical range. This is what lets positioning/stalking begin before any action has resolved.
- **Target's `threat_trigger` flips true either by ordinary awareness, or by a hard override on any attempted action** — normal case: the target's own awareness-zone perception (V3 §8.1's cone + LoS, unchanged) notices the aggressor first. Override: the moment any action resolution is attempted against this target — landed or missed — `threat_trigger` flips true regardless of awareness/LoS state at that instant, since attempting a strike is itself detectable independent of whether it connects. Stealth exceptions to this override are a reserved, not-designed extension point for a future stealth-mechanics pass.

**Generalizes beyond Fight — `engaged` is a general target-lock primitive.** Any goal that requires selecting a live target *agent* (not a static resource) from the awareness zone populates this same field the same way: Eat via live prey today, and (not designed now, not blocked) a future `find_people_to_rob` or mating-contest goal. The mechanism is "a goal locked onto a live instance" — Fight is just its first consumer.

**`combat_observation_sec` accumulates whenever self has awareness/LoS of the other *and* the other is resolving any combat action, against anyone** — not only when self is the target. Watching two other creatures fight from cover ticks the same accumulator as fighting them directly.

**Detection is treated as omniscient in phase 1** — a creature may directly read whether it has been detected (consult the target's own `threat_trigger` entry about itself) rather than maintaining a separate, possibly-wrong belief. Matches V3's own v1 simplification elsewhere (§8.1). Full stealth mechanics are explicitly deferred.

<<Comment: Ledger storage/ownership does **not** extend V3's `_goal_belief` — schema and eviction-policy mismatch (see [COMBAT_HISTORY.md](COMBAT_HISTORY.md) for why). Needs a sibling per-instance store using the same `instance_id` keying idiom; needs sign-off from whoever implements V3's memory adapter.>>

<<Comment: The aggressor-side target-lock mechanism this depends on is still unbuilt in V3 — prey chase/pursuit is explicitly deferred in V3's own doc audit. This section defines what populates `engaged` once such a mechanism exists; it does not build that mechanism.>>

### 11.2 `relative_threat_mod`

Feeds V3's `urgency_flight = clamp(urgency_dist × kind_threat × threat_disposition_mod × relative_threat_mod, 0..1)`, stubbed at `1.0` there and earmarked for combat.

**Perceived opponent condition — banded, not exact.** The perceiver never reads the opponent's exact pool ratio, only which band it falls in:
```
opponent_condition_ratio = avg(curr_point_fit_ratio_opp, curr_point_end_ratio_opp)   # ground truth, unknown to perceiver

band_weight = band_table(opponent_condition_ratio):
    ratio == 100%        → 1.00   # Full
    80.0–99.9%           → 0.90   # Minor wounds/fatigue
    50.0–79.9%           → 0.75   # Moderate
    20.0–49.9%           → 0.50   # Heavy
    0.1–19.9%            → 0.25   # Critical
    0% (incapacitated)   → 0.00   # not a band — a downed/incapacitated opponent simply isn't a threat
```
Self's own condition stays exact (self-aware) and feeds `urgency_flight`'s other terms elsewhere — this term is specifically about what the perceiver can *tell* about the opponent.

**Relative size — incidental threat, independent of the opponent's wounds or intent.** Reuses the existing `creature_size` field on `CreatureDefinition`:
```
size_ratio        = opponent.creature_size / self.creature_size
incidental_threat = clamp((size_ratio - combat_size_threat_floor) / (combat_size_threat_ceiling - combat_size_threat_floor), 0, 1)
```
New config constants `combat_size_threat_floor`/`combat_size_threat_ceiling` (defaults TBD — balance pass). A same-or-smaller opponent contributes ~0 here; a much larger opponent (rabbit/elephant case) ramps this up independent of the opponent's own aggression or condition — bulk alone is the danger.

**Visible danger signs — new static per-species field:**
```
@export_range(0.0, 1.0) var natural_weapon_display: float = 0.0   # authored per archetype/species .tres; rabbit ~0, fox higher
```
Always visible on sight (appearance, not condition) — no perception banding on this one.

**Species-level experience is *not* a term here — it's already `kind_threat`.** `_kind_profile.threat_danger` (`CREATURE_MEMORY.md` §5.7 — per-creature, not global; neutral prior `0.5`; EWMA via `record_observation`) already feeds `urgency_flight`'s `kind_threat` term at the top level, sibling to `relative_threat_mod`, not inside it — see [COMBAT_HISTORY.md](COMBAT_HISTORY.md) for why a species-experience term was originally proposed here and removed. Combat's actual contribution is extending `threat_danger`'s write trigger (currently "Flight episode end; near-death tier" only) to also fire at **combat episode end**, fed by the existing `effectiveness`/`outcome_score` signal (§10) — a write-path extension on existing memory infrastructure, not new combat-owned state.

**`creature_behavior` — reserved placeholder, no logic this phase.** A future "determine intent from behavior" skill will feed this; for now:
```
behavior_factor = creature_behavior_placeholder   # config default 0.5; not wired to anything yet
```

**Combine — wounds gate the soft evidence** (rather than everything multiplying together, letting any single weak signal crush the result to near-zero):
```
perceived_capability = clamp(
    w_danger * natural_weapon_display + w_behavior * behavior_factor + w_base,
    0, 1)   # weights config-driven, sum to 1.0 (w_base is a floor — "any creature is somewhat capable")
combative_threat = band_weight * perceived_capability
```

**Combine combative + incidental via probabilistic OR** (either channel alone can drive threat up; both must be low for the result to stay low):
```
composite_threat = 1 - (1 - combative_threat) * (1 - incidental_threat)
```

**`compassion_self_interest` disposition bias — final multiplier**, reusing the established `(trait+100)/200` mapping:
```
disposition_t     = (compassion_self_interest + 100) / 200   # 0 = full compassion, 1 = full self-interest
disposition_bias  = lerp(compassion_dampen, self_interest_amplify, disposition_t)   # config, e.g. lerp(0.7, 1.3, t)
relative_threat_mod = clamp(composite_threat * disposition_bias, 0.0, 1.0)
```
High compassion assumes less hostile intent and dampens the read; high self-interest assumes more and amplifies it — applied last, so it colors interpretation rather than the underlying (still banded/imperfect) evidence.

<<Comment: All new config constants introduced here (`combat_size_threat_floor`/`ceiling`, `w_danger`/`w_behavior`/`w_base`, `compassion_dampen`/`self_interest_amplify`) are placeholders — exact defaults TBD during a balance pass. The formula shape is the resolution here, not the constants.>>

### 11.3 `Fight` hub goal — eligibility, config, feasibility, urgency

**Eligibility — no contact/range requirement, mirrors Eat's step-chain pattern.** `Fight` enters the goal table the moment either of §11.1's ledger conditions holds for at least one instance: `engaged = true` as aggressor, or `threat_trigger = true` as target/responder. Contact or being in range is **not** a precondition — positioning toward the locked target is itself the first step of pursuing the goal, not a gate before it can appear.

**`goal_base_fight`** — new config key, same pattern as the other five hub goals. Default TBD — balance pass.

**`goal_feasibility_floor_fight`** — same epsilon pattern as the other five (ship default `0.05` elsewhere). `feasibility` scales with whether the creature currently has any actionable option against its locked target — reuses `CombatPositionResolver`'s positional-modifier machinery (§4.9): full feasibility when positional criteria are already met, degrading (not zeroing) toward the floor while closing/repositioning.

**Competes via the same `weight` comparison every other goal uses** — no special-cased "Fight always wins when eligible" rule, entered either at ordinary cadence or via §11.4's acute re-eval.

**`urgency_fight` (responder role) — shares `urgency_dist`, inverts the threat product against its own ceiling, drops `threat_disposition_mod`:**
```
urgency_fight = clamp(urgency_dist * (1.0 - kind_threat * relative_threat_mod), 0.0, 1.0)
```
`urgency_dist` is reused verbatim (V3's own directive — same proximity ramp, not novel geometry). `kind_threat` and `relative_threat_mod` are each already clamped to `[0,1]`, so their product's ceiling is exactly `1.0`. A weak/wounded opponent drives fight-worthiness *up* toward `urgency_dist`'s ceiling; a dangerous opponent drives it toward `0`, ceding to Flight's own high urgency in the same scenario.

`threat_disposition_mod` is deliberately **not** reused — it's calibrated specifically as a flee/skittishness scalar with no fight-relevant meaning to invert. The responder's own risk appetite is already represented via `relative_threat_mod`'s `compassion_self_interest` bias.

**`stat_will` feeds the urgency weight directly, not only the persistence threshold in §4.7.** A depleting `curr_point_will` should raise the creature's own `urgency_flight` and dampen its own `urgency_fight` as the fight wears on — the same qualitative direction §4.7 already describes for goal-tipping ("`stat_will` raises the threshold before the goal tips to flee"), expressed here as a live per-tick urgency term rather than only a threshold effect on disengagement.

<<Comment: exact `will`-urgency modifier shape is left to the balance pass — not decided this phase. First-pass candidate, reusing existing machinery rather than inventing new: `will_persistence_mod = pool_scale(curr_point_will / max_point_will)` (§4.4's curve, `[0.25, 1.0]`), applied as `urgency_fight *= will_persistence_mod` and `urgency_flight *= (1.25 - will_persistence_mod)` — full will dampens flee/boosts fight persistence, depleted will does the reverse. Needs balance-pass sign-off before treating as contract.>>

**Scope — this resolves the responder path only** (`threat_trigger = true`). The aggressor path — a predator's own hunt drive committing `engaged = true` against a target it is pursuing, not responding to — is a different calculus (closer to Eat's target-lock than a threat-response) and remains deferred, consistent with §11.1's unbuilt prey-chase/pursuit dependency. See §13.

### 11.4 Acute fast-path re-evaluation

Generalizes V3's "attack triggers fight/flight immediately" forward-reference into a **timing mechanism, not a hardcoded goal-winner rule.** The acute trigger forces the **same full hub `weight` comparison** used every ordinary consideration cycle to run immediately (off-cadence) instead of waiting for the next scheduled tick. `Fight` and `Flight` are expected to dominate the result in the overwhelming majority of cases *because their inputs are large* in this situation — not because every other candidate is excluded from being scored. Extends this doc's §4.1/§4.7 "no special combat-ends state machine" philosophy to *entry*, not just exit.

**Trigger condition — reuses §11.1's `threat_trigger` flip, no new detection concept.** Fires the instant a creature's own ledger entry gets `threat_trigger = true` for any instance. The aggressor side needs no symmetric acute trigger — its own `engaged` flip already happens through an ordinary, scheduled consideration-cycle goal-commit, so it is never "surprised" by its own decision to engage.

**Existing hard overrides still apply, unconditionally.** `calorie_ratio < starvation_override_food_ceiling` already forces Eat to dominate over everything (V3 §1) regardless of how the current consideration cycle was entered — this is the "something that weighs pretty heavy" exception a pure re-eval model needs, already built by V3.

**Two existing rules survive with a broadened trigger condition, not removed:**
- **Find shelter's "fully suppressed during acute threat" exclusion** stays categorical, not weight-based — standing still to `STAY`-evaluate a shelter candidate is unsafe regardless of which goal wins the re-eval. Gating condition broadens from "Flight fast-path active" to "an acute fast-path trigger is active" (either goal).
- **§7.3's "acute Flight preempts in-progress turn sequences" execution-layer interrupt** broadens the same way — `Fight` winning an acute re-eval needs the same ability to cut off a stale multi-tick turn sequence that `Flight` winning already has.

No added computational cost — the hub already scores every goal's `weight` every ordinary cycle; the acute path reuses that exact evaluation, just triggered early.

### 11.5 Salient-write carrier (mechanical)

V3 explicitly resolves the memory-write-gating integration point: carrier renamed `MotorContext` → a salient-write context (name TBD in code), flag ids preserved, caller becomes a hub/planner outcome hook rather than a per-tick setter. Combat's remaining work here is a mechanical rename/timing sweep across this doc and the codebase — tracked as a task in [COMBAT_IMPLEMENTATION.md](COMBAT_IMPLEMENTATION.md), not additional design.

### 11.6 `URGENCY_JEOPARDY` bitmask retirement

The V2-era `URGENCY_JEOPARDY` bitmask referenced by an old implementation-plan step does not exist in V3 — urgency there is a continuous `clamp(..., 0, 1)` product (§11.3's `urgency_fight`, V3's `urgency_flight`). That step needs rewriting against the resolved formulas above — tracked as a task in [COMBAT_IMPLEMENTATION.md](COMBAT_IMPLEMENTATION.md).

---

## 12. Open questions

None currently open — the two prior entries (`fight_won` `GoalKind`; `stat_will` feeding urgency directly) are resolved and folded into §4.8/§4.9 and §11.3 respectively. See [COMBAT_HISTORY.md](COMBAT_HISTORY.md) for rationale.

---

## 13. Deferred dependencies (blocked on other unshipped work)

- **Aggressor-side live-target-lock / prey-chase-pursuit mechanism** — §11.1's `engaged` field for an aggressor depends on a live-agent-targeting equivalent of V3's Eat goal, which V3 itself defers ("mark prey chase / carnivore pursuit deferred unless already shipped elsewhere"). Blocks: the aggressor-role half of §11.3's `urgency_fight`.
- **Awareness-ledger storage/ownership sign-off** — §11.1's per-instance ledger should not reuse V3's `_goal_belief` storage/eviction machinery (schema and eviction-policy mismatch); needs a sibling store, pending sign-off from whoever implements V3's memory adapter.
