# Repo layout plan — **DRAFT (do not apply)**

> **Status:** **Draft / stub only.** This document records **intent and open questions** for reorganizing **`res://`** folders beyond what [ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md) already specifies. **Agents and implementers must not treat this file as authoritative** until maintainers remove this banner and resolve the **`<<Question>>`** / **`<<Comment>>`** items below.
>
> **Companion:** Authoritative **content** (`assets/`, `pack_resources.json`, `_shared/`) rules live in **[ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md)** (archived §11 baseline implemented — **`pack_resource_resolver.gd`**). This plan focuses on **code**, **config**, **app shell**, and **optional tree renames**.

---

## 1. Objective

Produce a single, agreed **`res://`** layout so that:

- **Shippable authored content** stays under **`assets/`** (domain packages per asset plan).
- **Systems code** (motor, environment bake, AI integration, logging) has an obvious home and does not sprawl ambiguously next to scenes.
- **App shell** (**`main.tscn`**, menus) stays **outside** **`assets/`** (see asset plan §4.1 — e.g. **`scenes/app/`**).
- **Config** and autoload glue have stable paths (**`config/`**, documented exceptions).

---

## 2. Inherited logic (from ASSET_MANAGEMENT_PLAN.md)

Summarized here so this draft stands alone for discussion; **do not contradict** the asset plan without updating both docs.

| Layer | Role | Example paths (target — **not** binding until draft promoted) |
|-------|------|------------------------------------------------------------------|
| **`assets/`** | Domain packs: creatures, plants, environment, locations, ui, audio pools, `_shared/`, branding | `res://assets/creatures/...`, `res://assets/_shared/...` |
| **`scenes/app/`** | Main flow, transitions, future main menu | `res://scenes/app/main.tscn` (illustrative) |
| **`config/`** | Player-facing JSON, merge story, brand helpers | `res://config/game_config.json` (illustrative) |
| **`addons/`**, **`tests/`** | Godot addons; dev-only tests | Unchanged conventions |

**Systems today (flat):** `creature/`, `environment/`, `AI_int_lib/`, `oLog_lib/`, root scripts (`main.gd`, `game_config.gd`, …).

---

## 3. Target sketch (informative — mirrors asset plan §4.4)

```
res://assets/           # content — ASSET_MANAGEMENT_PLAN.md
res://scenes/app/       # app shell — outside assets
res://systems/          # <<Question: adopt consolidated systems/ tree?>>
  creature/
  environment/
  ai/                   # rename from AI_int_lib/ ?
  ...
res://config/
res://addons/
res://tests/
```

<<Question: Keep **`AI_int_lib/`** name vs rename to **`systems/ai/`** or **`ai/`** at repo root for shorter imports?>>

---

## 4. Decisions to resolve before promotion

### 4.1 Option A (co-locate scripts with packs) vs split (libraries only)

Asset plan **Option A** applies to **packaged content**. For **GDScript libraries**:

- **Split-friendly:** All motor/math/integration code under **`systems/`** (or today’s top-level folders).
- **Co-location-friendly:** Small helpers live **`*.gd` next to `*.tscn`** inside **`assets/<domain>/<id>/`** when they are truly pack-private.

<<Question: Where is the boundary? Must **creature/motor/** remain a shared library forever, or may pack-private motors live under **`assets/creatures/<id>/scripts/`**?>>

### 4.2 Optional **`systems/`** rename

<<Question: Do we introduce **`res://systems/`** in one migration PR, or phase folder-by-folder (`creature` → `systems/creature`) with compatibility shims?>>

<<Question: What happens to **`environment/`** vs future **`assets/environment/`** bake **inputs** — keep bake **code** under **`systems/environment/`** and **only** palette/output art under **`assets/environment/`**?>>

### 4.3 Root cleanliness

Today several scenes/scripts sit at project root (`main.tscn`, `player.tscn`, …).

<<Question: Minimal move set for v1 repo layout — only **`scenes/app/`** + **`config/`**, or full sweep including HUD/mob/player scenes into **`assets/`** or **`scenes/game/`**?>>

### 4.4 Tools

<<Comment: Optional **`tools/`** or **`addons/`**-adjacent scripts for **`pack_resources`** validation, import lint, CI — out of scope until layout stabilizes.>>

---

## 5. Agent instructions (while draft)

- **Do not** rename or move folders **based solely on this document** (see repo **AGENTS.md** — migrations are explicit tasks).
- Use **[ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md)** for **`assets/`** behavior.
- When implementing anything listed here, **update this draft** into a non-draft spec first or obtain explicit maintainer approval.

---

## 6. References

- [ASSET_MANAGEMENT_PLAN.md](../Completed_Features/ASSET_MANAGEMENT_PLAN.md) — §4.2 systems vs content, §4.4 sketch, §9 follow-on.
- [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) — backlog pointer for scheduling this work.
