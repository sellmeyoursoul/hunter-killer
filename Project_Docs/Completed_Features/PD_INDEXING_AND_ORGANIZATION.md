# Project_Docs — indexing, tiers, and organization

> **Archive:** Project_Docs **option B** reorg **completed** (2026-05-15). **Active policy** (tiers, promotion, maintenance) lives in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) and [.cursor/rules/AGENTS.md](../../.cursor/rules/AGENTS.md). Treat this file as **historical** unless a maintainer explicitly cites it.

> **Purpose (at time of writing):** How we **classified**, **stored**, and **discovered** markdown under `Project_Docs/` during the folder migration. **Inventory:** [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) (start there).

---

## 1. Why this exists

`Project_Docs/` mixes draft specs, definitive contracts, archived “completed” plans, and root-level navigation files. Agents and humans need to know:

- Whether a file is **authoritative for implementation** for an *active* feature.
- Whether **code drift** vs the doc is **acceptable** (implementation diary) or **not** (contract / runtime-adjacent truth).
- Where to **register new** docs so nothing becomes invisible.

---

## 2. Constraints from `.cursor/rules/AGENTS.md`

- **`Completed_Features/**`** is **archived**: not treated as active requirements unless a maintainer says otherwise.
- **Active feature work** treats only the **explicitly referenced** plan plus `.cursor/rules/*` as binding; other docs in `Draft_Features/` or `Definitive_Features/` are **feature drafts** unless cited for that task.
- **File moves:** Do not rename or move docs casually (breaks Cursor rule attachment). **Coordinated migrations** (folder split, link sweep, `AGENTS.md` update) are allowed when recorded in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md).

**Resolved (2026-05-15):** Folder split **option B** is **adopted**. `AGENTS.md` was updated in the same change set to list `Draft_Features/`, `Definitive_Features/`, root navigation files, and `Completed_Features/` exclusion. Future moves use the same pattern: one PR, index + links + rules.

---

## 3. Document tiers

| Tier | Working name | Drift expectation | Location |
|------|----------------|------------------|----------|
| **I** | **Implementation / ephemeral** | **Expected OK** | **Outside `Project_Docs/`** (e.g. `docs/impl/` at repo root if needed). Not indexed in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) unless we later add a tier-I policy. |
| **II** | **Draft / future feature** | **Expected** until promoted | `Project_Docs/Draft_Features/` |
| **III** | **Definitive / current contract** | **Minimize** | `Project_Docs/Definitive_Features/` (small set) |
| **—** | **Archived** | **Expected** (snapshot in time) | `Project_Docs/Completed_Features/` |
| **—** | **Navigation / process** | Low | `Project_Docs/` **root** only: [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md), [FEATURE_PLAN_TEMPLATE.md](../FEATURE_PLAN_TEMPLATE.md), [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — **no** `Meta/` subfolder. |

**Overlap is normal:** one file can contain draft and definitive sections until split or promoted.

### 3.1 Promotion (draft → definitive or archived)

| Target | When | Action |
|--------|------|--------|
| **`Definitive_Features/`** (tier III) | The doc is an **ongoing contract** that must stay aligned with code, `project.godot`, or shared schemas (e.g. physics layer table). Drift is a bug. | Move file; register in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md); remove any `Draft_Features/` copy; fix cross-links. |
| **`Completed_Features/`** (archived) | The feature **shipped** (or the plan is **superseded** / extracted into other docs). The file is a **snapshot** — drift vs current code is **expected**. | Move file; register in index; **delete** the `Draft_Features/` row/file; **no** redirect stubs at root or in `Draft_Features/`. |

**Do not** promote to tier III merely because code exists; **do not** treat `Completed_Features/` as tier III.

### 3.2 `Completed_Features/` scope (archived)

- Files here are **snapshots in time**. Drift vs the current tree is **expected** and acceptable.
- **Code comments** (or docstrings) that link to `Completed_Features/` do **not** make those files authoritative or tier III. They are convenience pointers only.
- Use archived plans for **initial design intention** when there is **no** authoritative active doc on the topic (`Draft_Features/`, `Definitive_Features/`, or an explicitly cited plan). Otherwise prefer the active spec.
- Implementation binds only what the **active task** cites (see `.cursor/rules/AGENTS.md` **Feature-doc scope guard**), not every path mentioned in code.

### 3.3 Historical scratch

- [EARLY_SPEC_DOC](EARLY_SPEC_DOC) — pre-split World Builder notes; content was extracted into draft/definitive/completed plans. **Reference only.**

---

## 4. Adopted folder layout (option B)

```
Project_Docs/
  PROJECT_DOC_INDEX.md          ← start here (inventory + active policy)
  FEATURE_PLAN_TEMPLATE.md
  ENHANCEMENT_BACKLOG_PLAN.md
  Draft_Features/               ← tier II
  Definitive_Features/          ← tier III
  Completed_Features/           ← archived (includes this file after migration)
```

**Not used:** `Meta/` or `Process/` subfolders — root navigation files above serve that role.

**Legacy:** Flat `Project_Docs/*.md` feature plans were migrated into `Draft_Features/`, `Definitive_Features/`, or `Completed_Features/` (2026-05-15). Do not add new feature plans at `Project_Docs/` root.

**Draft_Features/ policy:** Only **work-in-progress** plans live here. **No redirect stubs** for shipped features — register the real path in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) under `Completed_Features/` or `Definitive_Features/` instead (e.g. mob avoidance: `Completed_Features/MOB_AVOIDANCE_PLAN.md` only).

### Option A — Minimal (superseded for feature plans)

Keep flat `Project_Docs/*.md` + index only — **replaced by B** for feature specs; root index files remain.

---

## 5. Authoritative technical tables (example)

- **Godot 2D physics layer / mask mapping:** [Definitive_Features/ENVIRONMENT_MODEL_PLAN.md](../Definitive_Features/ENVIRONMENT_MODEL_PLAN.md) **§6**, kept consistent with `project.godot`.

---

## 6. Review checklist (for maintainers)

1. **Inventory:** Every `*.md` under `Project_Docs/` appears in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) — **that file is the sole canonical path registry**; update it alone when moving docs, then grep-fix cross-links.  
2. **Tag tier:** Assign I / II / III / Archived / root per §3; use §3.1 when promoting.  
3. **Drift policy:** For tier III, note what must stay in sync (code, `project.godot`, resources).  
4. **Duplication:** Flag same topic in `Draft_Features/` vs `Completed_Features/` (e.g. two mob-avoidance docs) and record **which** is active.  
5. **AGENTS / Cursor:** Folder or glob changes → update `.cursor/rules/AGENTS.md` in the **same** change set.  
6. **Link hygiene:** Use **relative** links from each file’s directory (`../` when crossing folders).

---

## 7. Resolved policy (formerly open questions)

**Tier III location — resolved:** Definitive / contract specs live under **`Definitive_Features/`** as the default. Do **not** place tier III plans at `Project_Docs/` root for “stable URLs.” If a rare exception is justified (e.g. a cross-cutting contract that is not a feature plan), document it explicitly in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) with an **exception** note and rationale — treat it as an exception, not a new default.

**Tier I location — resolved:** Keep tier I (**implementation / ephemeral** notes) **outside `Project_Docs/`** for now (e.g. under a future `docs/impl/` or similar at repo root). Do not add `Project_Docs/Implementation/` until a maintainer opens a dedicated feature to reconsider. Tier I material is **not** listed in [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md) unless we later extend the index policy.

---

## 8. References

- [.cursor/rules/AGENTS.md](../../.cursor/rules/AGENTS.md)  
- [PROJECT_DOC_INDEX.md](../PROJECT_DOC_INDEX.md)  
- [FEATURE_PLAN_TEMPLATE.md](../FEATURE_PLAN_TEMPLATE.md)

---

## 9. Changelog

| Date | Change |
|------|--------|
| 2026-05-15 | Option B adopted; §3.1 promotion, §3.2 archived scope, tier I/III decisions resolved. |
| 2026-05-15 | Reorg executed; file archived under `Completed_Features/`; active policy consolidated into `PROJECT_DOC_INDEX.md`. |
