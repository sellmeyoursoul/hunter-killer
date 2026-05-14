# Hunter Killer — Asset management plan (agent-friendly)

> **Archive:** Implemented baseline (**§11**); authoritative copy lives here under **`Project_Docs/Completed_Features/`**. Operational checklist for agents: **[`.cursor/rules/focus/asset_management.md`](../../.cursor/rules/focus/asset_management.md)**.

> **Purpose:** Decide how we author, store, and bind **2D** (current focus) and future **3D** content so defaults (import settings, collision shapes, material templates, variability) stay consistent as the repo grows.
>
> **Relationship to today’s tree:** The game already ships authored bitmaps under **`res://art/`** (e.g. environment palette convention in [ENVIRONMENT_MODEL_PLAN.md](../ENVIRONMENT_MODEL_PLAN.md)) and scenes/scripts elsewhere. This doc chooses how **`res://assets/`** complements or replaces ad-hoc paths without breaking existing features until we migrate deliberately.

---

## 1. Goals

| Goal | Success looks like |
|------|-------------------|
| **Predictable defaults** | New PNGs/GLTF land with correct filters, mipmaps, compression, and collision/material hooks without per-file tweaking in the inspector. |
| **Discoverability** | Anyone can answer “where is the rabbit walk cycle?” without grep archaeology. |
| **Scalability** | Adding creatures/plants/env props does not flatten dozens of unrelated files into one folder. |
| **Godot alignment** | Prefer **`res://`** packs, **`.import`** sidecars, and scene/instance workflows Godot expects. |
| **Cross-discipline clarity** | Art sources vs engine-ready assets vs code are distinguishable (even if co-located). |

---

## 2. Top-level layout: `res://assets/`

**Canonical folder name:** **`assets`** (standard spelling; matches common engine conventions).

**Primary domains** (game taxonomy — one package folder per logical thing under each):

```
res://assets/
  creatures/
  plants/
  environment/
```

**Secondary domains** (cross-cutting or spatial scope — same Option A rules, but scoped differently):

```
res://assets/
  locations/       # level / biome / interior packages (see §4.1)
  _shared/         # textures, audio beds, materials used by many packs (see §2.1)
```

- **`creatures/`**, **`plants/`**, **`environment/`** — authored content for those gameplay categories.
- **`locations/`** — authored **spaces** (entry scene + local props/audio hooks) when we outgrow a single main playspace. Use the folder name **`locations/`** (not **`worlds/`**): a world is a location, but not every location is logically a whole world.
- **`_shared/`** — pooled authored blobs used by many packs under **`_shared/textures/`**, **`_shared/audio/`**, etc.; plus **`_shared/default/`** — **resolver-only** fallbacks (**§2.1**). Dev builds use **obvious** missing-media cues; **release** builds use **subtle** substitutes (gray textures, silent audio) so players are not punished by debug styling. Pooled files are referenced from domain packs’ **`pack_resources.json`** via the **`shared_resources`** map; **`default/`** is never normal authoring.

Additional domains (**`ui/`**, **`audio/`**, …) remain in **§4** until adopted. **App shell** (**`main.tscn`**, main-menu flow, new game vs load — §4.1) stays **outside** **`assets/`** by default; it does not use the content-pack model.

**Legacy `res://art/`:** Treat as **grandfathered** until a migration task explicitly moves files and updates `res://` references in `.tscn` / `.gd`. New work should prefer **`assets/`** unless a live feature doc still mandates `art/` (e.g. palette PNG bake pipeline).

**Full Option A scope:** Everything that **does not** belong under `assets/` at all (systems code, config plumbing) is spelled out in **§4**.

### 2.1 `assets/_shared/` and per-pack `pack_resources.json`

**Roles:**

| Piece | Location | Purpose |
|-------|-----------|---------|
| **Pack manifest** | **`pack_resources.json` inside each domain package** (e.g. `assets/creatures/rabbit/pack_resources.json`) | Optional JSON binding file. Required shape includes a **`shared_resources`** object: **tag → `res://…`** (or small per-entry objects — finalize at implementation). Covers slots **not** satisfied by files co-located in the pack (footstep, portrait, idle_sheet, …). **Omit the file** when everything is local; if present with nothing shared, use **`"shared_resources": {}`**. |
| **Pooled shared blobs** | **`assets/_shared/`** subtree (e.g. `textures/`, `audio/`, `materials/`) | Real shared artwork/audio referenced **through** **`shared_resources`** in **`pack_resources.json`** — first-class game-ready assets reused across packs. |
| **Failed-lookup defaults** | **`assets/_shared/default/<kind>/`** | Resolver-only fallbacks per **`kind`** (`textures/`, `audio/`, …). **Media depends on build profile** — see **Dev vs release** below. In all cases, hitting **`default/`** means a bind failed; CI should still catch unintended fallbacks before ship. |

**Resolution order (implementation contract):**

1. **Co-located in the pack** — e.g. `assets/creatures/rabbit/sfx/hop.wav` referenced directly by convention or relative scene deps.
2. **`pack_resources.json` → `shared_resources`** — for slot **`hop`** (or equivalent tag), entry points at **`res://assets/_shared/…`** or any valid **`res://`** path when the blob is not stored beside the pack root.
3. **`assets/_shared/default/<kind>/…`** — only when step **1** and **2** do not yield a resource (missing tag, broken path, missing file). Resolver picks the canonical default file for that **`kind`** (texture vs audio vs …), **from the active profile’s default set** (dev vs release).

**`pack_resources.json` shape (conceptual — finalize schema when implementing):**

- Root object must include **`shared_resources`**: map from **logical tag** → **`res://` path** (or `{ "path": "res://…", "notes": "…" }` per entry if needed).
- Optional additional root keys for pack-local metadata that does not belong in **`shared_resources`** — e.g. **`notes`** (string), future **`variant_id`** overrides — so routine detail lives here instead of a README <<Comment: lock allowed keys when implementing>>.
- **`shared_resources`** only lists slots that point outside co-located files or into **`_shared/`**; it may be **`{}`** when unused.

**Example (illustrative):**

```json
{
  "notes": "Optional pack-level notes; omit if empty.",
  "shared_resources": {
    "footstep_default": "res://assets/_shared/audio/footstep_grass.wav"
  }
}
```

**Dev vs release default media (chosen policy):**

| Profile | Purpose | Textures | Audio | Other kinds |
|---------|---------|----------|-------|-------------|
| **Editor / dev** | QA and developers must notice failures immediately | Loud **neon**, magenta checker, or equally unmistakable pattern | Short **alarm** or harsh placeholder tone — clearly wrong | Extend with equally obvious stubs as new **`kind`** values appear |
| **Release** | Avoid confusing or annoying players if a bad path slips through | Flat **neutral gray** (e.g. mid-gray fill — exact value fixed at implementation) | **Silence** or legally/compression-safe minimal silence for bad sound references | Neutral, boring stubs — never flashy |

**Implementation options** (pick one and document in export notes):

- Mirror subtrees **`default/dev/<kind>/`** vs **`default/release/<kind>/`** with the resolver selecting by **`OS.has_feature("editor")`** / export template / custom feature tag; or
- Same paths with **export-time replacement** of the binary files in **`default/`**; or
- Resolver maps **`kind` + profile → `res://`** path table loaded from a small JSON.

**Chosen for this repo (v1):** Fixed **`res://`** paths under **`assets/_shared/default/<kind>/`** (`missing_dev.*` / `missing_release.*`) with profile selection in **`res://pack_resource_resolver.gd`** (global class **`PackResourceResolver`**): **`OS.has_feature("editor")`** or **`OS.is_debug_build()`** → dev media; otherwise release media.

**Rules:**

- **`_shared/default/`** is **not** referenced from pack manifests under normal conditions — the resolver reaches it only after failure.
- Gameplay code does **not** hard-code arbitrary **`res://assets/_shared/...`** paths; it asks the resolver (**`PackResourceResolver.resolve_*_from_pack`**) for **`(pack_root, tag)`** per supported **`kind`**.
- **Tests:** Any load whose winner resolves to **`default/`** — whether dev or release assets — remains a **failure** in CI unless the test explicitly expects a negative/missing-data case. Subtle release media does **not** relax test policy; it only changes player-visible symptoms if something escapes.
- Validate in CI that **both** profiles’ default files exist for each supported **`kind`** (where shipping applies) and that **`pack_resources.json`** → **`shared_resources`** paths resolve.

### 2.2 Variants (multiple instances of one logical type)

Examples: one **horse** species with **riding** vs **draft** vs **racing** builds — different silhouettes, stats-facing presentation, or animation sets.

**Recommended layouts (pick per asset; document in **`pack_resources.json`** (`notes` / **`data/`**) or optional README when non-obvious):**

| Pattern | When to use | Layout sketch |
|---------|-------------|----------------|
| **A — Subfolder variants** | Same species, shared rig/pivot conventions, moderate art overlap | `assets/creatures/horse/` → **`variants/riding/`**, **`variants/draft/`**, **`variants/racing/`**, each with entry scene or `SpriteFrames` subset |
| **B — Sibling species ids** | Variants diverge heavily (different skeleton, collision, AI profile) | Separate packages under **`assets/creatures/`**, e.g. **`horse_riding/`**, **`horse_draft/`** (folders **`snake_case`**); runtime variant ids use dots (**`horse.riding`**, …). |
| **C — Data-driven variant map** | Many skins sharing one scene | Single entry scene + **`data/variants.json`** mapping variant id → texture/atlas paths; use **`pack_resources.json`** → **`shared_resources`** when slots point into **`assets/_shared/`** |

**Rules of thumb:**

- If two variants share **most** animations and only swap meshes/textures → prefer **A** or **C**.
- If collision footprint or gameplay archetype changes → prefer **B** or separate **`variants/<id>/`** with distinct entry `.tscn`.
- Expose a **single stable variant id** to code as a **dot-separated** string (e.g. **`horse.riding`**, **`horse.draft`**) so systems do not parse folder paths — see **chosen convention** below.

**Chosen variant id convention:**

- Use **`.`** between segments **globally** for variant ids passed to code, data files, and manifests (not **`species_role`**).
- Dots allow **nested taxonomies** later without changing the pattern, e.g. **`snake.venomous.cobra.hooded_cobra`**.
- **Folder and file names** under **`assets/`** stay **`snake_case`** per **§6**; they need not mirror the full dotted id. When a folder slug differs from the id (e.g. package **`horse_riding/`** vs id **`horse.riding`**), record the canonical **`variant id`** in **`pack_resources.json`**, **`data/`**, or an optional README.

Cross-reference: naming of sprite files and atlas regions stays aligned with **§5.1** (variability).

---

## 3. Structural decision: co-location vs split vs registry

We need one coherent rule set. Three patterns:

### Option A — **Domain package (recommended baseline)**

Under each domain, use **one folder per logical asset** (e.g. `assets/creatures/rabbit/`) containing everything needed to *assemble* that asset in-engine:

- **`art/`** — raster sources or exported atlases for that asset only (when small).
- **`scenes/`** — `.tscn` entry points or parts (optional if single scene at root of folder).
- **`data/`** — JSON/`Resource` snippets, animation metadata, variation tables (optional).
- **`pack_resources.json`** *(optional)* — JSON with required **`shared_resources`** object (tag → **`res://…`**) for pooled bindings not satisfied **by** co-located files; optional root **`notes`** or other keys per §2.1. Omit file when everything is local, or use **`"shared_resources": {}`**.

**Pros:** Easy onboarding; industry-normal “asset bundle”; moves cleanly between repos.  
**Cons:** Duplicates shared textures if we are not careful — mitigate with **`assets/_shared/`** pools + per-pack **`pack_resources.json`** (§2.1).

### Option B — **Split by discipline** (keep art in `art/`, code in `creature/`, etc.)

**Pros:** Strict separation for teams that never overlap files.  
**Cons:** Harder to delete/rename one feature; references sprawl; **this repo already mixes** `environment/*.gd`, `art/env/`, and scenes at root — continuing pure split **without** a registry guarantees “where is X?” pain.

### Option C — **Thin index + scattered files**

`assets/creatures/` holds only **`manifest.json`** (or `.gd` Resource registry) pointing at files under `art/` and `scripts/`.

**Pros:** Single lookup table; works for huge pipelines.  
**Cons:** Requires discipline and **tooling**; stale manifests hurt. Best paired with a **repo-wide source layout plan** (see §9).

### **Chosen direction (v1)**

Adopt **Option A (domain package)** as the default for **new** creatures, plants, and environment props. Pool cross-pack blobs under **`assets/_shared/`**; each pack optionally carries **`pack_resources.json`** with **`shared_resources`** mapping tags → pooled **`res://`** paths; failed lookups fall through to **`assets/_shared/default/`** (§2.1).

Use **Option C** only where we already have immovable paths (legacy `art/`) — manifest or table documents the binding until migration.

**Pack documentation (`README.md`) — chosen policy:**

- **No mandatory README** per asset folder for POC / small-team workflows and when sourcing is in-house (author is always the **project team** — do not repeat per pack).
- **World scale** is **project-wide**, not per creature: define **once** when decided (target: **`X` px = 1 ft** — **TBD**); record in this plan, `project.godot` notes, or team wiki — avoid duplicating in every pack.
- Put **binding details** in **`pack_resources.json`** (**`shared_resources`** and optional root **`notes`**). Add a **`README.md`** only when something cannot be expressed there (unusual pivot rules, one-off exceptions).

---

## 4. Beyond creatures, plants, and environment (full Option A scope)

**Team intent:** Treat **Option A** as the mental model for **everything shippable** (content packs). Refactor legacy paths to match **after** this plan stabilizes.

**Rule of thumb:** If it is **authored** (art, audio, level layout, HUD layout) and **shipped in the player build**, it belongs under **`res://assets/…`** using domain packages. If it is **logic, algorithms, integrations, or tooling**, it lives **outside** `assets/` (see §4.2).

### 4.1 Additional asset domains (under `res://assets/`)

These are **not** covered by only `creatures/`, `plants/`, and `environment/`:

| Domain | What goes here (examples) | Notes |
|--------|-----------------------------|--------|
| **`locations/`** | Entry scene per level / biome / interior, local-only props, lighting/atmosphere hooks | Use this name only (**not** **`worlds/`**): a world is a location; not every location is a whole world. Listed as **secondary** in **§2**. Today the game is largely one playspace (`Main` + path + props); each distinct area gets a package under **`assets/locations/<location_id>/`** when needed. |
| **`ui/`** | HUD, menus, themes, Control scenes, UI atlases | Fonts may live under **`ui/fonts/`** or **`_shared/fonts/`** — reference pooled fonts from that UI pack’s **`pack_resources.json`** when not local. |
| **`audio/`** | Music, SFX, UI bleeps; optional subdirs `music/`, `sfx/`, `ui/` | Domain packs *may* embed audio; **global** clips live under **`_shared/audio/`** and are addressed via each consumer pack’s **`pack_resources.json`** when needed. |
| **App shell / main flow** | **`main.tscn`**, scene transitions, future **main menu** (new game, load save, …) | **Chosen:** keep **outside** **`assets/`** — e.g. **`res://scenes/app/`** at repo root (or project root until reorganized). This layer is the game **frame**, not a domain pack; revisiting **`assets/bootstrap/`** is allowed later but **not** the default. |
| **`_shared/`** | Pooled cross-pack media + **`default/`** fallbacks | Pooled paths referenced from **`shared_resources`** in each consumer’s **`pack_resources.json`**; **`default/`** holds resolver-only media — **obvious in dev**, **subtle in release** (**§2.1**). |
| **Branding** | **`icon.svg`**, studio splash art | Prefer **`assets/branding/`** when collected as authored blobs; small items may stay at project root until migrated — avoid orphan clutter long-term. |

**Resolved naming/placement (recorded above):** **`locations/`** (not **`worlds`**); app shell / **`main.tscn`** outside **`assets/`** (e.g. **`scenes/app/`**).

### 4.2 Systems vs authored content (engine code — not asset packs)

Do **not** fold generic engine logic into `assets/` just to satisfy Option A. Treat these as **systems** / **libraries** (folder names can stay as today until **`REPO_LAYOUT_PLAN.md`** renames them):

| Area | Role today (repo) | Boundary |
|------|-------------------|----------|
| **Creature motor & perception helpers** | `creature/*.gd`, `creature/motor/*.gd` | **Logic only** — no PNGs. Creature **scenes/sprites** move under **`assets/creatures/<id>/`**. |
| **Environment runtime & bake** | `environment/*.gd`, grid bake types | **Pipeline + runtime types** — palette PNGs migrate from `art/env/` into **`assets/environment/…`** when ready; bake **code** stays under systems. |
| **AI / inference** | `AI_int_lib/*.gd`, prompts | **Integration** — not game art. Binaries (`bin/`, platform inference folders) stay outside `assets/`. |
| **Logging** | `oLog_lib/` | **Infrastructure**. |
| **Autoload glue** | `game_config.gd`, merge helpers | **Configuration plumbing** — paired with **`config/`** (see §4.3). |
| **Tests** | `tests/` | **Dev-only** — never shipped as content. |
| **Editor addons** | `addons/` | Godot convention — unchanged. |

<<Comment: Optional consolidated **`res://systems/`** tree — see draft [REPO_LAYOUT_PLAN.md](../REPO_LAYOUT_PLAN.md); do not move folders until that plan is promoted.>>

### 4.3 Config, product identity, misc blobs

| Kind | Examples | Suggested home |
|------|----------|----------------|
| **Player-facing config** | `game_config.json`, merged defaults | **`config/`** or project root with a one-line README pointing here |
| **Brand strings** | `product_brand.gd` | **`config/`** or next to app shell under **`scenes/app/`** / project root |
| **Stray reference images / screenshots** | ad-hoc JPGs under `art/` | Move to **`Project_Docs/`** or **`assets/_reference/`** (excluded from export) |

### 4.4 Target layout sketch (post-refactor — informative)

Not mandatory immediate creation; use this when implementing migration:

```
res://assets/
  creatures/<creature_id>/
    pack_resources.json            # optional — §2.1; root includes shared_resources { }
    ...
  plants/<plant_id>/...
  environment/<prop_or_set_id>/...
  locations/<location_id>/...      # when needed
  ui/<screen_or_theme>/...
  audio/music/ ...
  audio/sfx/ ...
  _shared/
    textures/ ...
    audio/ ...
    materials/ ...
    default/                       # resolver-only — dev vs release media — §2.1
      textures/ ...
      audio/ ...

res://scenes/app/                  # outside assets — §4.1 (main.tscn, menu flow)
  ...

res://systems/                     # optional rename from scattered folders
  creature/
  environment/
  ...

res://config/
  game_config.json
  ...

res://addons/
res://tests/
```

### 4.5 Future domains (not in repo yet — reserve mentally)

When introduced, they usually **do not** live only under creatures/plants/environment:

- **Shaders / materials** — `assets/_shared/shaders/` or per-pack `materials/`.
- **VFX** — `assets/vfx/` or inside relevant location pack.
- **Localization** — `assets/l10n/` or `localization/`.
- **Narrative** — dialogue/cutscenes under `assets/narrative/` or per-location packs.

---

## 5. Binding art to default settings and variability

### 5.1 Import defaults (2D)

**2D phase policy (chosen):** **2D is a development stage**, not the intended ship mode — the **plan is 3D before release**. During this phase, **mixed DPI is acceptable** (e.g. smooth UI with higher-res or filtered sprites alongside crisp sprites). Organize paths or presets so **`2d_pixel`** vs **`2d`** / mipmap rules apply predictably per subtree (**`pixel/`** vs **`smooth/`** or equivalent). If strategy changes and the team **ships a 2D game**, treat that as a **scope change**: standardize on **pixel-crisp** art and import defaults across the board (replace mixed-DPI content or re-export).

- **World scale (authoring):** Single **project-wide** convention — **TBD** (target formulation: **`X` px = 1 ft**). When fixed, record **once** (add a sentence under §5.1 here, a `project.godot` comment, or wiki); do **not** restate per asset unless that asset is an intentional exception.
- **Project-level:** Define **default import presets** per subtree or asset class — **`2d_pixel`** (no mipmaps, nearest/neighbor-friendly) for intentional pixel art folders; **`2d`** / filtered paths for smooth or UI-heavy trees during the mixed-DPI **2D phase**.
- **Folder-level:** Use Godot **`.gdignore` / import overrides** (as supported per version) or consistent subfolders (**`pixel/`** vs **`smooth/`**, **`ui/`**) so the right preset applies without hand-editing every PNG.
- **Per-asset overrides:** Only when an asset truly differs from its subtree defaults; document in **`pack_resources.json`** (**`notes`** / **`data/`**) or an optional README — not required for routine POC packs.

**Variability (skins, seasons, damage states):**

- Prefer **`SpriteFrames`** / animation libraries or **`AtlasTexture`** regions over duplicate full PNGs when dimensions match.
- Name variants predictably: `body_idle.png`, `body_idle_winter.png`, or `variants/winter/` subfolder — pick one convention per domain and stick to it.
- **Species-style variants** (riding vs draft horse, etc.) — follow **§2.2** so folder layout and runtime ids stay aligned.

### 5.2 Import defaults (3D) — future-ready

Treat **3D** assets differently from **2D** at the pipeline layer. **2D** here is the **transitional** dev pipeline (**§5.1** — mixed DPI OK until 3D); **3D** is the **intended ship target** before release.

| Aspect | 2D (transitional) | 3D |
|--------|----|-----|
| Primary unit | Sprite / texture region | Mesh + skin + materials |
| Scale authority | Pixels per unit in scene | **Export scale** from DCC + root scene scale **1** |
| Collision | Shapes authored in `.tscn` or TileMap | **Convex/simple** child scenes; document tris budget |
| Materials | Often implicit or CanvasItem | **StandardMaterial3D** templates under `assets/_shared/materials/` |

Store authored **`*.blend`** / **`*.gltf`** sources under **`assets/<domain>/<name>/source/`** (optional, gitignored if huge) or document external **Art repo / LFS** policy — **do not** duplicate ambiguous “final” mesh paths.

<<Comment: Until a 3D milestone exists, keep §5.2 as policy only; no mandatory folder creation.>>

### 5.3 Scene binding contract

Every gameplay-ready asset should expose:

- **One clear entry scene** (e.g. `rabbit.tscn`) at a stable path, OR a documented factory in code that loads by ID.
- **Documented collision layer/mask** expectations (link to physics table in [ENVIRONMENT_MODEL_PLAN.md](../ENVIRONMENT_MODEL_PLAN.md) when extended).
- **Pivot / footprint**: where “feet” are for `CharacterBody2D` vs prop anchor for `StaticBody2D`.

---

## 6. Naming conventions

- **Folders:** `snake_case`, single logical name (`grey_wolf`, `fern_01`, `rock_pile_large`).
- **Variant ids** (strings used at runtime / in JSON): **dot-separated** segments per **§2.2** (e.g. `horse.racing`, `snake.venomous.cobra.hooded_cobra`) — not `species_role` underscores.
- **Per-pack manifest:** filename **`pack_resources.json`** at the root of each domain package when used — contains **`shared_resources`** (§2.1).
- **Files:** prefer **`snake_case`** for Godot-native consistency; avoid spaces.
- **Scenes:** `{asset}.tscn` for root entry; parts `{asset}_{part}.tscn`.
- **Godot UIDs:** Never hand-edit; moving files requires editor refactor or planned batch — tracked as migration work, not drive-by renames (see repo **AGENTS.md** rule on renames).

---

## 7. Version control and binaries

- Prefer **Git LFS** (or binary Art repo) for heavy PNG/mesh/audio; document limits in [FORK_HUNTER_KILLER.md](../FORK_HUNTER_KILLER.md) or a short **`docs/contributing-assets.md`** when added.
- Commit **`.import`** files for stable CI/editor parity unless team policy says otherwise.
- Avoid committing **generated** bake outputs if reproducible from palette sources — align with environment bake docs.

---

## 8. Industry norms checklist (practical)

1. **Single source of truth** — One canonical mesh/sprite per variant; derivatives are generated or referenced, not copied blindly.
2. **LOD / performance budgets** — Even for 2D: max texture size per category (creature vs UI vs env decal).
3. **Naming + folder mirrors gameplay taxonomy** — creatures/plants/environment match design docs ([CREATURE_MODEL_PLAN.md](../CREATURE_MODEL_PLAN.md), [PLANTS_PLAN.md](../PLANTS_PLAN.md), env plans).
4. **Ownership** — Each asset folder has an obvious “maintainer” note when cross-team.
5. **Deprecations** — If replaced, `deprecated/` or Git delete with PR reference; no zombie paths in manifests.
6. **Legal** — License file per third-party pack (`LICENSE_THIRD_PARTY.txt` in pack folder).

---

## 9. Follow-on: repo-wide structure task

**Stub:** [REPO_LAYOUT_PLAN.md](../REPO_LAYOUT_PLAN.md) (**draft** — do not apply until promoted). It expands:

- Where **systems** (`environment/`, `creature/`, `AI_int_lib/`) vs **content** (`assets/`) live (aligned with §4.2 / §4.4).
- Rules for **when** new scripts land next to scenes vs in shared libraries.
- Optional **`systems/`** consolidation and **`tools/`** for bake/import validators.

<<Comment: Resolve **`<<Question>>`** items in REPO_LAYOUT_PLAN.md, remove draft banner, then execute moves as explicit migration tasks — not drive-by renames.>>

---

## 10. Agent rules placement (implementation)

**Decision:** Do **not** paste full asset-layout rules into **[`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)**. Keep **`AGENTS.md`** as the global behavioral brief plus a **Focus areas** index entry only.

**Where agents load operational rules:**

| Layer | Path | Role |
|-------|------|------|
| **Index** | [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md) → Focus areas | Points to the short operational checklist. |
| **Operational summary** | [`.cursor/rules/focus/asset_management.md`](../../.cursor/rules/focus/asset_management.md) | Checklist agents follow while coding (paths, `pack_resources.json`, variants, refactor caution). |
| **Authoritative design** | **This file** (`Project_Docs/Completed_Features/ASSET_MANAGEMENT_PLAN.md`) | Full structure, schemas, open **`<<Question>>`** / **`<<Comment>>`** markers. |

**Maintenance:** When asset policy changes, update **this plan first**, then tighten **`asset_management.md`** so it stays a one-screen summary. Add cross-links only; avoid duplicating long tables in **`AGENTS.md`**.

---

## 11. Adoption checklist (implementation)

1. **Agent rules (done):** Focus-area pointer in **[`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)** + **[`.cursor/rules/focus/asset_management.md`](../../.cursor/rules/focus/asset_management.md)**; layered policy recorded in **§10**.
2. **Baseline (done):** **`res://assets/creatures/`**, **`plants/`**, **`environment/`**, **`locations/`**, **`_shared/`** exist; **`_shared/default/textures/`** and **`…/audio/`** hold committed placeholder binaries + **`.import`** sidecars per §2.1.
3. **Resolver + tests (done):** **`res://pack_resource_resolver.gd`** (global class **`PackResourceResolver`**); headless coverage in **`res://tests/run_all.gd`** (`_test_pack_resource_resolver`). CI treats **`used_default`** on gameplay paths as a bug — tests only assert fallback on intentional negative cases (same policy as §2.1).
4. **Import presets (deferred):** Add subtree import presets / wiki notes for mixed DPI (**§5.1**); optional **`pixel/`** vs **`smooth/`** under **`assets/`** when art volume warrants it.
5. **§4 domain folders / app shell (deferred):** Add **`ui/`**, **`audio/`**, **`config/`**, optional **`systems/`** rename only as agreed ([REPO_LAYOUT_PLAN.md](../REPO_LAYOUT_PLAN.md)); migrate app shell to **`res://scenes/app/`** when doing that pass.
6. **Pilot migration (done):** Obstacle texture **`pile-of-rocks.png`** moved **`art/env/` → `assets/environment/obstacle_rocks/`**; **`obstacle_field.tscn`** / **`obstacle_field_root.gd`** updated.
7. **Doc drift (partial):** Palette bake docs still cite **`res://art/env/`** where grid authoring lives; update when those PNGs migrate — obstacle path no longer uses **`art/env`**.

---

## 12. Open decisions summary

| Topic | Status |
|-------|--------|
| 3D source storage (in-repo vs LFS vs external) | <<Question: …>> (see §5.2) |
| Per-pack **`pack_resources.json`** schema (required **`shared_resources`** root key; optional root **`notes`**; per-entry string **`res://…`** or `{ "path", "notes?" }`) | Implemented — see **`load_shared_resources_map`** / **`resolve_*_from_pack`** in **`pack_resource_resolver.gd`** |
| Promote **[REPO_LAYOUT_PLAN.md](../REPO_LAYOUT_PLAN.md)** from draft → executable spec | <<Comment: …>> (see §9 — stub exists; resolve questions then migrate) |

---

## 13. References

- [ENVIRONMENT_MODEL_PLAN.md](../ENVIRONMENT_MODEL_PLAN.md) — existing `art/env` palette / bake assumptions.
- [CREATURE_MODEL_PLAN.md](../CREATURE_MODEL_PLAN.md) — creature abstraction.
- [PLANTS_PLAN.md](../PLANTS_PLAN.md), [PLANT_ECOLOGY_PLAN.md](../PLANT_ECOLOGY_PLAN.md) — plant content direction.
- [REPO_LAYOUT_PLAN.md](../REPO_LAYOUT_PLAN.md) — **draft** repo-wide code/config layout (systems vs `assets/`); follow-on to §9.
