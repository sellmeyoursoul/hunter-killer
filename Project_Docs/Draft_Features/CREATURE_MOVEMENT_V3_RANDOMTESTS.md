# CREATURE_MOVEMENT_V3 — Randomized spawn stress-test log

> **Role:** Tracks bugs/issues surfaced specifically by the **randomized playfield spawn** stress test ([ENVIRONMENT_MODEL_PLAN.md §6.4](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)) — interior boulders, food shrubs, and the herbivore/carnivore duel pair now spawn randomized each run (deliberately allowed to overlap for boulders/food), which is expected to surface realistic clutter/placement edge cases the movement, memory, and goals engines have to cope with. **Not** a replacement for [CREATURE_MOVEMENT_V3_CLEANUP.md](CREATURE_MOVEMENT_V3_CLEANUP.md) — that file remains the general V3 bug/gap backlog. If an item logged here turns out to be a pre-existing bug unrelated to spawn randomization (i.e. it would have reproduced under the old fixed layout too), move it to `CLEANUP.md` instead so each bug has one canonical home.
>
> **Authority:** Items here are **tier II draft** until promoted into [CREATURE_MOVEMENT_V3_CLEANUP.md](CREATURE_MOVEMENT_V3_CLEANUP.md) (general fix backlog), merged into [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md), or closed as *won't fix*. Code changes ship with doc updates per [project-docs.mdc](../../.cursor/rules/project-docs.mdc).
>
> **Related:** [CREATURE_MOVEMENT_V3.md](CREATURE_MOVEMENT_V3.md) (main spec), [CREATURE_MOVEMENT_V3_CLEANUP.md](CREATURE_MOVEMENT_V3_CLEANUP.md) (general bug/gap backlog — sibling log, not a duplicate), [ENVIRONMENT_MODEL_PLAN.md §6.4](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) (spawn randomizer design, config, lock workflow), [`environment/playfield_spawn_randomizer.gd`](../../environment/playfield_spawn_randomizer.gd).

---

## How to use this file

| Field | Meaning |
|-------|---------|
| **ID** | `RT#` — stable reference in commits / PRs (separate numbering from `CLEANUP.md`'s `C#`) |
| **Status** | `open` → `design` → `ready` → `in_progress` → `done` / `wont_fix` / `watch` / `pending_recurrence` — vocabulary defined in [project-docs.mdc](../../.cursor/rules/project-docs.mdc) |
| **Evidence** | Repro steps, log excerpt, or failing test name — **include the locked layout path + seed** (see below) so the exact spawn arrangement is reproducible |

**Reproducing a randomized-spawn bug:** per [ENVIRONMENT_MODEL_PLAN.md §6.4](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md)'s lock workflow — copy the run's `spawn_layout_last_run.json` aside (e.g. `spawn_layout_locked_rt1.json`), point `playfield_spawn.locked_layout_path` at it, and commit the locked file alongside the item's entry below so anyone can replay the exact layout until it's root-caused.

When an item is **done**, note the fix (commit / test) here and, if the underlying bug wasn't spawn-randomization-specific, consider whether the fix itself belongs in `CLEANUP.md` acceptance criteria instead.

---

## Inventory

| ID | Title | Status | Evidence |
|----|-------|--------|----------|
| _none yet_ | First randomized-spawn test pass pending | — | — |

---

## Items

_(Add one `### RT# — <title>` section per item below, following the `CLEANUP.md` item format: Status, Repro/Evidence including locked layout path + seed, Root cause once known, Fix.)_
