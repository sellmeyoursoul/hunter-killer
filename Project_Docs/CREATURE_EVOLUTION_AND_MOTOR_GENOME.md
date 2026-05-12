# Creature evolution, near-miss learning, and motor genome (design)

This is a **design discussion** only: no training or persistence code ships in the Hunter-Killer perception milestone. It maps “lived experience” and **heredity** onto the existing **`creature_motor`** parameter surface so future work can stay compatible with `CardinalAvoidance` and headless tests.

## Near-miss signal

Operational definitions that are cheap to log and correlate with outcomes:

1. **Geometric near-miss:** Minimum predicted clearance to any mob (or obstacle) over a short horizon dropped below threshold **T_miss** without a collision event that frame.
2. **Motor stress near-miss:** `CardinalAvoidance.cost_at_prediction` for the chosen cardinal spiked relative to a trailing median, but no hit occurred (indicates “barely escaped” in cost space).
3. **Wall / OOB pressure:** Edge or OOB penalty terms dominated the cost briefly while the creature remained in-bounds (scraping behavior).

Combine with episode outcomes: survival time, score, death cause (mob vs OOB if ever distinguished).

## Genome = `creature_motor` vector

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

## Learning modes (feasibility)

### A. Online adjustment (lightweight)

- Log tuples: `(snapshot_features, chosen_cardinal, near_miss_flags, next_state)`.
- Update weights with constrained steps (e.g. **bandit** on discrete cardinals, or **SGD** on continuous weights with tiny learning rate).
- **Risk:** unstable loops; mitigate with clamps, EMA baseline, and “revert if fitness drops over N rounds.”

### B. Offline evolution (generations)

- **Population:** N genomes (JSON fragments under `creature_motor`).
- **Fitness:** weighted sum of survival time, score, penalties for near-misses and wall stress, bonus for smooth intent changes.
- **Operators:** crossover on normalized vectors + Gaussian mutation + elitism.
- **Evaluation:** headless or fast-forward headless runs with fixed RNG seeds for reproducibility.

### C. Heredity

- Persist **parent genomes** and **fitness** next to saved seeds in `user://` or a `runs/` folder (not implemented here).
- **Crossover:** two parents → child weights blended per-gene with random choice or average.
- **Speciation (optional):** cluster genomes by behavior vectors (e.g. mean `weight_edge`) to preserve diversity.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Overfitting spawn RNG | Multi-seed evaluation; hold-out seeds. |
| Unstable motor | Strict clamps; penalize weight norm in fitness. |
| Non-stationary environment | Re-evaluate champions after art/obstacle edits. |

## Next implementation steps (when requested)

1. NDJSON or SQLite logger for near-miss + motor context (respect [.cursor/rules/focus/logging_instr.md](../.cursor/rules/focus/logging_instr.md) PII/volume policy).
2. Batch runner: `godot --headless` loads genome from CLI, runs K episodes, prints fitness.
3. Optional: small Python driver for GA loop calling Godot subprocesses.
