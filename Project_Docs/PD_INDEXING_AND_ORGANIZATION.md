# Project_Docs — indexing, tiers, and organization (working note)

> **Purpose:** Plan how we **classify**, **store**, and **discover** markdown under `Project_Docs/`. The tree is **mixed** today (draft specs, archived “completed” plans, meta/process docs). This file is a **maintainer task list and design sketch**, not yet a migration commit checklist.

---

## 1. Why this exists

`Project_Docs/` has grown without a single taxonomy. Agents and humans need to know:

- Whether a file is **authoritative for implementation** for an *active* feature.
- Whether **code drift** vs the doc is **acceptable** (implementation diary) or **not** (contract / runtime-adjacent truth).
- Where to **register new** docs so nothing becomes invisible.

[Glossary: tiers](#3-proposed-document-tiers-three-plus) below names three mental models; [§4](#4-folder-layout-options) sketches physical layout. **Resolving** tier + folder policy is an explicit review outcome.

---

## 2. Constraints from `.cursor/rules/AGENTS.md`

- **`Completed_Features/**`** is **archived**: not treated as active requirements unless a maintainer says otherwise.
- **Active feature work** should treat only the **explicitly referenced** plan plus `.cursor/rules/*` as binding; other top-level `Project_Docs/*.md` files are **feature drafts** unless we promote them.
- **Do not rename or move files** casually once created (breaks Cursor rule attachment). Any **re-home** of existing `.md` files must be a **deliberate, rare** migration with rule-path updates.

<<Question: For a future folder split (Draft_/Definitive_), do we amend AGENTS.md glob patterns (`Project_Docs/*.md` vs subfolders) and re-attach rules in one coordinated PR?>>

---

## 3. Proposed document tiers (three+)

| Tier | Working name | Drift expectation | Typical use |
|------|----------------|------------------|-------------|
| **I** | **Implementation / ephemeral** | **Expected OK** | Spike notes, one-off migration logs, “how we shipped v0.1” where the code is the truth. May be deleted or archived after TTL. |
| **II** | **Draft / future feature** | **Expected** until promoted | Active design space, `<<Question>>` markers, unimplemented behavior. **Must not** override a different active feature’s cited spec. |
| **III** | **Definitive / current contract** | **Minimize** | Stuff implementers and tools treat as **truth**: stable IDs, layer/mask tables tied to `project.godot`, enums exported to code, **data schemas** referenced from CI or codegen. <<Comment: “runtime” usually means Resource paths or generated data — rarely raw `.md` loaded in Godot; call out exceptions if any.>> |
| **—** | **Archived** | N/A | **`Completed_Features/**`** — historical; useful for archaeology, not default authority. |

**Overlap is normal:** one file can contain *draft* sections and *definitive* sections until someone splits or labels headings.

---

## 4. Folder layout options

### Option A — Minimal (today + index only)

- Keep current flat `Project_Docs/*.md` + `Completed_Features/`.
- Add **`PROJECT_DOC_INDEX.md`** (master list + tier **proposal** + links).
- **Pros:** No moves; satisfies discoverability quickly. **Cons:** Draft and definitive still share a namespace.

### Option B — Add sibling folders (no archive rename)

- `Project_Docs/Draft_Features/` — tier II  
- `Project_Docs/Definitive_Features/` — tier III (small set)  
- `Project_Docs/Completed_Features/` — unchanged archived  
- Optional: `Project_Docs/Meta/` or `Project_Docs/Process/` for templates, fork notes, backlog.  
- **Pros:** Clear shelf placement. **Cons:** Requires **moving** files (AGENTS constraint); must update globs and any links.

### Option C — Prefix / front-matter convention (no moves)

- Keep paths; each file starts with YAML or a **Tier:** line and **Owner:**.  
- **`PROJECT_DOC_INDEX.md`** generated or hand-maintained from that.  
- **Pros:** No file moves. **Cons:** Easy to forget; weaker visual browsing.

<<Comment: Option B vs C could combine: new files go under Draft_/Definitive_; legacy files stay flat until a approved migration batch.>>

---

## 5. Authoritative technical tables (example)

- **Godot 2D physics layer / mask mapping:** documented under [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) **§6** (see acceptance criteria there), kept consistent with **Project Settings** in the Godot editor / `project.godot`.

---

## 6. Review checklist (for maintainers)

1. **Inventory:** Ensure every `*.md` under `Project_Docs/` appears in [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md).  
2. **Tag tier:** For each file, assign I / II / III / Archived (or “mixed”).  
3. **Drift policy:** For tier III, note **what** must stay in sync (code paths, `project.godot`, resources).  
4. **Duplication:** Flag same *topic* in top-level vs `Completed_Features/` (e.g. two `MOB_AVOIDANCE_PLAN.md`) and record **which** is active.  
5. **AGENTS / Cursor:** If folders change, update `.cursor/rules` and `AGENTS.md` “Project Documents” definition in the **same** change set.  
6. **Link hygiene:** Prefer **relative** links from `Project_Docs/` peers.

---

## 7. Open decisions

<<Question: Should tier III live only under `Definitive_Features/`, or can a few “root canon” files stay at top level (`ENVIRONMENT_MODEL_PLAN.md`, `CREATURE_MODEL_PLAN.md`) for stable URLs?>>

<<Question: Do we want `Implementation/` or `Notes/` for tier I, or keep tier I outside `Project_Docs` entirely (e.g. `docs/impl/`)?>>

---

## 8. References

- [.cursor/rules/AGENTS.md](../.cursor/rules/AGENTS.md) — scope, `Completed_Features`, no-rename guidance.  
- [PROJECT_DOC_INDEX.md](PROJECT_DOC_INDEX.md) — file inventory (maintain alongside this plan).  
- [FEATURE_PLAN_TEMPLATE.md](FEATURE_PLAN_TEMPLATE.md) — optional front-matter for tier / status.  
