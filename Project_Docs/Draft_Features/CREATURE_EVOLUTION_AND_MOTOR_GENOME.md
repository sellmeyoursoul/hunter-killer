# Creature evolution, near-miss learning, and motor genome (design)

This is a **design discussion** only: no training or persistence code ships in the Hunter-Killer perception milestone. It maps “lived experience” and **heredity** onto the existing **`creature_motor`** parameter surface so future work can stay compatible with `CardinalAvoidance` and headless tests.

**Creature model alignment:** [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §4 defines **motivation traits** (outlook sliders) as inputs to a **future utility layer**, not LLM movement tokens; that doc’s **field catalog** is authoritative for names and semantics. **This doc** treats those traits as a **second heritable vector** that will **modulate** motor and fitness once multiple motivations exist, and it specifies **heredity / evolution** usage plus **phased coupling** to `creature_motor`. Until those motivation systems land, only **survival-relevant** couplings should be wired, and the rest stay **explicitly reserved** so evolution tooling does not fork the field catalog.

## Near-miss signal

Operational definitions that are cheap to log and correlate with outcomes:

1. **Geometric near-miss:** Minimum predicted clearance to any mob (or obstacle) over a short horizon dropped below threshold **T_miss** without a collision event that frame.
2. **Motor stress near-miss:** `CardinalAvoidance.cost_at_prediction` for the chosen cardinal spiked relative to a trailing median, but no hit occurred (indicates “barely escaped” in cost space).
3. **Wall / OOB pressure:** Edge or OOB penalty terms dominated the cost briefly while the creature remained in-bounds (scraping behavior).

Combine with episode outcomes: survival time, score, death cause (mob vs OOB if ever distinguished).

## Genome surface

Heredity and evolution operate on a **stack** of parameters: **motor genes** (movement scoring) and **motivation genes** (behavioral outlook). Cross the same operators (normalize → crossover → mutate → clamp → denormalize) on each sub-vector independently unless a future spec introduces **linked** loci (e.g. pleiotropy between `explorer_builder` and `weight_interior`).

### Motor parameters (`creature_motor`)

Treat each tunable float (and a few ints/bools with fixed enums) as a **gene** with hard **clamp ranges** for stability:

| Gene group | Examples | Notes |
|------------|----------|--------|
| Distance / crowding | `weight_dist`, `weight_dist_sq`, `distance_eps` | `distance_eps` should stay small but positive. |
| Closing | `weight_closing` | Large values favor fleeing incoming mobs. |
| Posture | `weight_interior`, `weight_edge` | Trade center-seeking vs wall avoidance. |
| Horizon | `lookahead_sec`, `scripted_intent_hold_physics_ticks` | Affects reactivity vs oscillation. |
| Awareness | `awareness_radius`, `awareness_cone_extra`, `awareness_cone_half_angle_deg`, `awareness_memory_ticks`, `awareness_memory_weight`, `awareness_memory_horizon_sec` | Controls spatial attention and ghost influence. |
| Obstacles | `weight_obstacle` | Static repulsion strength. |
| Mode | `mode` | Keep `scripted` vs `llm` as discrete; evolution typically fixes `scripted`. |

**Normalization for crossover:** map each gene to `[0,1]` via `(x - min) / (max - min)` inside clamps; denormalize after mutation.

### Motivation traits (outlook; [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §4)

These sliders are **first-class genes** for evolution and parent→child copy, even when the **runtime motor** does not yet read them. Scale at implementation time follows the creature model (`-100..100` vs `0..100` — open question there); evolution clamps must match whatever `CreatureStats` (or successor) uses.

| Field | High pole | Low pole | Framework note |
|-------|-----------|----------|------------------|
| `explorer_builder` | Favor exploring the world | Favor improving “home” / settled ground | Becomes a **fitness / objective** axis once exploration vs base-building is simulated; **no motor coupling** in survival-only POC unless a phase explicitly maps it (e.g. interior vs edge posture as a weak proxy — **TBD**, avoid guessing). |
| `change_stability` | Seek novelty / variety | Prefer routine / predictable paths | Natural hook for **horizon**, **intent hold**, **oscillation penalties**, and **near-miss stress** weighting once defined; **primary** survival-era candidate for a **small** documented mapping. |
| `compassion_self_interest` | Weight others’ needs | Self-maximization | Reserved until **multi-agent** or **altruism** objectives exist in fitness or utility. |
| `community_individual` | Collective / support seeking | Self-reliance | Reserved until **social** or **pack** mechanics feed the motor or fitness layer. |

`initialize_outlook()` (creature model) is the **authoritative seed** for this vector; evolution **overwrites** population slots the same way it does for `creature_motor` when breeding from champions.

## Trait–motor coupling (phased)

**Invariant:** Physics and `can_enter` stay authoritative; traits never invent illegal moves. They only **scale**, **blend**, or **re-rank** terms inside existing cardinal / utility math.

| Phase | Traits with a defined read path | Traits reserved (genes still heritable) |
|-------|----------------------------------|----------------------------------------|
| **Survival-only** (current design target) | Prefer **`change_stability`** first when adding any coupling (e.g. tighter `lookahead_sec` vs longer `scripted_intent_hold_physics_ticks`, or fitness penalty for flip-flopping). Other traits: **no** default mapping until a feature doc names one. | `explorer_builder`, `compassion_self_interest`, `community_individual` — store, mutate, crossover for **lineage continuity**; document **neutral** effect in sim until their motivation systems exist. |
| **Multi-motivation** (future) | Add explicit rows to a feature plan: each trait maps to **utility weights**, **motor multipliers** on named `creature_motor` genes, and/or **fitness components** (e.g. builder score from home quality). | — |

**Interior motor + `explorer_builder` (deferred, OBJECT §8.2.5):** Once **multi-motivation** reads outlook in the same pipeline as **interior env / slow vs unknown** scoring ([OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2.5 when archived), **high `explorer_builder`** should **scale up** unknown / explore attraction and **scale down** slow-terrain aversion so exploration wins more often **without** breaking the **mob > object** invariant. Name the exact gene multipliers in the implementing feature plan; until then traits stay **reserved** per the survival-only row above.

**Fitness composition (future):** When objectives beyond survival exist, treat **motivation genes as priors**: a creature with high `explorer_builder` might gain fitness from map coverage while one low on that axis is scored on defensive positioning—**only** after those signals are implemented. Until then, **single-objective** fitness (survival, score, near-miss penalties) ignores trait-specific bonuses on purpose.

## Learning modes (feasibility)

### A. Online adjustment (lightweight)

- Log tuples: `(snapshot_features, chosen_cardinal, near_miss_flags, next_state)`.
- Update weights with constrained steps (e.g. **bandit** on discrete cardinals, or **SGD** on continuous weights with tiny learning rate).
- **Risk:** unstable loops; mitigate with clamps, EMA baseline, and “revert if fitness drops over N rounds.”

### B. Offline evolution (generations)

- **Population:** N individuals, each carrying **`creature_motor`** plus **`motivation_traits`** (same serialization shape as future `CreatureStats` exports—**TBD** path).
- **Fitness:** weighted sum of survival time, score, penalties for near-misses and wall stress, bonus for smooth intent changes. **Optional later terms** keyed off motivation traits only when the sim exposes the corresponding signals (see **Trait–motor coupling**).
- **Operators:** crossover on normalized **motor** and **motivation** sub-vectors + Gaussian mutation + elitism.
- **Evaluation:** headless or fast-forward headless runs with fixed RNG seeds for reproducibility.

### C. Heredity

- Persist **parent genomes** (motor + motivation vectors) and **fitness** next to saved seeds in `user://` or a `runs/` folder (not implemented here).
- **Crossover:** two parents → child: per-gene blend on **`creature_motor`** and independently on **motivation traits** (same operators; no mandatory correlation until a spec adds one).
- **Speciation (optional):** cluster genomes by behavior vectors (e.g. mean `weight_edge`, principal components of motivation traits) to preserve diversity.

**Combat experience tables (deferred — cross-ref [COMBAT.md](COMBAT.md) §11.7 and §11.9):**
When the combat experience system ships, two per-creature-lifetime tables are candidates for hereditary inheritance:

1. **Self-experience table** (§11.7) — keyed on `prev_action_id → curr_action_id → weight`. Child inherits a diluted blend of both parents' tables at a configured dilution factor (`combat_exp_inherit_dilution`, default TBD). Over generations, populations develop locally distinct action-chain tendencies without explicit encoding.

2. **Opponent observation table** (§11.9) — keyed on `opponent_action_id → own_response_id → weight`, plus a **spatial preference overlay** (named positional bias dict). Child inherits a blend of parents' opponent tables and overlay values. Populations in fox-heavy areas may accumulate elevated `maintain_awareness_arc` bias across generations — an emergent population-level tactical memory.

Both tables use the same per-gene EMA-blend crossover operator as the motor genome (normalize → blend → clamp). The dilution factor is a separate config key from `combat_exp_ema_alpha` since it governs cross-generation transfer, not within-lifetime learning.

**Inheritance is deferred** until the base table implementations (§11.7, §11.9) are stable. Do not implement the inheritance path before the tables themselves are wired and unit-tested.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Overfitting spawn RNG | Multi-seed evaluation; hold-out seeds. |
| Unstable motor | Strict clamps; penalize weight norm in fitness. |
| Non-stationary environment | Re-evaluate champions after art/obstacle edits. |
| Trait–motor coupling drift | Any new mapping must be named in a **feature plan** and versioned in saved genomes so old lineages remain interpretable. |

## Next implementation steps (when requested)

1. NDJSON or SQLite logger for near-miss + motor context (respect [.cursor/rules/focus/logging_instr.md](../../.cursor/rules/focus/logging_instr.md) PII/volume policy).
2. Batch runner: `godot --headless` loads genome from CLI, runs K episodes, prints fitness.
3. Optional: small Python driver for GA loop calling Godot subprocesses.
4. When `CreatureStats` exists: extend CLI / JSON schema to load and persist **motivation traits** alongside `creature_motor`; log them with episode outcomes for later correlation.

## Changelog

| Date | Change |
|------|--------|
| 2026-06-25 | §C Heredity extended: combat self-experience table and opponent observation table (including spatial overlay) added as heritable structures. Dilution factor config key stubbed. Deferred until base table implementations stable. Cross-ref COMBAT.md §11.7 / §11.9. |
| 2026-05-12 | Trait–motor: deferred **`explorer_builder`** scaling for interior slow vs unknown ([OBJECT_AVOIDANCE_PLAN.md](../Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2.5); multi-motivation hook. |
| 2026-05-12 | Motivation traits ([CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md) §4): dual genome, phased trait–motor coupling, heredity/fitness; bidirectional cross-links. |
