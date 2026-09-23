# Project_Docs authoring

Migrated from `.cursor/rules/project-docs.mdc`. Keep the two in sync if you edit either.

**Applies when:** Writing or revising design docs agents implement from.

## Embedded markers

- `<<Question: …>>` — ask for clarification on next read.
- `<<Comment: …>>` — area needing author/agent resolution.

## Tiers (see [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md))

- **Draft_Features/** — work in progress; questions/comments expected.
- **Definitive_Features/** — minimize drift vs code / `project.godot`.
- **Completed_Features/** — snapshots; not default authority unless explicitly cited.

When moving or adding docs, update **only** `PROJECT_DOC_INDEX.md` for path registry changes.

## Status vocabulary (per-item tracking tables, e.g. bug/cleanup logs)

Use for any doc that tracks discrete items (bugs, risks, follow-on slices) with a **Status** field:

- `open` — logged, no work started.
- `design` → `ready` → `in_progress` — normal implementation pipeline.
- `done` — shipped; move acceptance criteria into the authoritative spec or archive note.
- `wont_fix` — decided against; leave the reasoning in place, don't delete the item.
- `watch` — an accepted trade-off, not itself a bug, monitored for a **specific named trigger condition** (e.g. a recurring regression class) that would justify escalating; not scheduled otherwise.
- `pending_recurrence` — a repro was genuinely attempted (hypotheses tested, not just asserted) but nothing reproduced or root-caused. Neither provably fixed nor actionable — there is no next step until new evidence (a fresh repro, a new failure mode) shows up. When asked what's left to work on, treat `pending_recurrence` items as **not** investable time, same as `done`/`wont_fix` — unlike `open`, which always has a next step.

`watch` vs `pending_recurrence`: `watch` is proactive (a known risk, waiting on a defined trigger); `pending_recurrence` is reactive (an already-observed problem that stopped reproducing before it was pinned down).

## Code ↔ doc sync playbook

**Applies when:** Syncing active Project_Docs after a code or config change (see root [CLAUDE.md](../CLAUDE.md) **Doc sync**).

### Find the doc

| Signal | Action |
|--------|--------|
| `## …` link in changed `.gd` / `.tscn` header | Primary target + section |
| Task cites `Draft_Features/FOO.md` | That file is authoritative for the task |
| Index "Notes" column names a canonical doc for the topic | Use that path |
| Definitive "usage map" exists for the subsystem | Update map tables / snapshot paragraph |

### What to update (minimum useful sync)

- Renamed/moved scripts → path tables and cross-links in the doc
- New/changed `@export`, `pack_resources.json` keys, `project.godot` layers → definitive tables (e.g. [ENVIRONMENT_MODEL_PLAN.md §6](Definitive_Features/ENVIRONMENT_MODEL_PLAN.md))
- New consumer of a trait/stat/config → row in usage-map docs ([CREATURE_TRAIT_USAGE.md](Definitive_Features/CREATURE_TRAIT_USAGE.md), [CREATURE_ATTRIBUTES_USAGE.md](Definitive_Features/CREATURE_ATTRIBUTES_USAGE.md))
- Shipped acceptance criterion → check box in draft §6 or definitive checklist
- V3 ENGINE motor behavior (planner, explore, debug) → [CREATURE_MOVEMENT_V3.md](Draft_Features/CREATURE_MOVEMENT_V3.md) §7+ only; link from [CREATURE_MOVEMENT.md](Definitive_Features/CREATURE_MOVEMENT.md), do **not** duplicate prose there
- Legacy 2D motor inventory rows / config keys in definitive [CREATURE_MOVEMENT.md](Definitive_Features/CREATURE_MOVEMENT.md) when those sections are affected

### What not to do

- Don't paste large code blocks — keep path + contract summaries (match existing definitive style)
- Don't update `Completed_Features/` to reflect new behavior
- Don't create duplicate topics — one canonical path per index row

### Promotion

When a draft feature becomes an ongoing contract, promote per index **Promotion** table in the same change set as the shipping code (move file, index row, delete draft copy, fix links).

### Verification before finishing

Grep changed symbols/paths against `Project_Docs/` for stale references; confirm linked section still describes behavior.
