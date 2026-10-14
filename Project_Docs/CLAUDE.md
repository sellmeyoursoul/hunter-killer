# Project_Docs authoring

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

## Bug register (OPEN_BUGS.md)

**Applies when:** Logging, updating, or closing a bug that is `open`, `in_progress`, or `pending_recurrence`.

- **Separation:** [OPEN_BUGS.md](OPEN_BUGS.md) holds the **dense summary** (summary table plus per-bug entries: ID, status, symptom, repro with command and observed rate, ruled out, leading hypothesis, owner agent, source-doc link, last-updated date). The **messy history** stays in the feature doc (e.g. [CREATURE_MOVEMENT_V3_CLEANUP.md](Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md)), untouched, with a **one-line pointer** at the bug's entry (ID, status, link to the OPEN_BUGS.md anchor). Update **both** when a status or fact changes; at `done` / `wont_fix`, remove the entry from OPEN_BUGS.md and leave the final status in the source doc. `watch` items stay in their source docs.
- **Scope (every entry and summary-table row):** `V3` = belongs to, or blocks closing, the current Creature Movement V3 project (Active development list in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md)); `outside-V3` = not V3 scope, but **must be addressed eventually** (it does not gate V3 close-out and is not dropped). Anything not required for V3 is `outside-V3`.
- **IDs:** `<DOC_ACRONYM>-<n>`, acronym derived from the source doc's filename, registered in the prefix registry at the top of OPEN_BUGS.md before use; the number is the source doc's own item number (`C9` -> `CMV3C-9`); numbers are never reused. A bug with no source-doc number takes the prefix of the doc its pointer lives in.
- **Unbuilt features are not bugs:** they belong to their feature plan or [ENHANCEMENT_BACKLOG_PLAN.md](ENHANCEMENT_BACKLOG_PLAN.md).
- **Unclear items:** if it is unclear whether an item is a bug, which doc is in scope, or which status applies, do **not** guess. Leave it out and flag it to the caller for review.

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
