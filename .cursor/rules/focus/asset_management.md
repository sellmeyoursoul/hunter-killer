# Assets & `res://assets/` layout

**Authoritative spec (archived implementation doc):** [ASSET_MANAGEMENT_PLAN.md](../../../Project_Docs/Completed_Features/ASSET_MANAGEMENT_PLAN.md). If that doc has unresolved `<<Question: …>>` markers on a topic, **stop and ask** rather than inventing layout or schema.

**New content that does not fit this paradigm:** If you add or model an **object type** (or authored bundle) that **does not** clearly belong under the domains and rules already described there (e.g. not creatures/plants/environment/locations/`_shared`/listed §4 domains, or it needs a different manifest/resolver shape), **do not assume** where it should live or how it should hook into **`pack_resources.json`**. **Stop and ask** the maintainer how to extend the plan — then update **ASSET_MANAGEMENT_PLAN.md** (same Completed path) for that case before implementing layout.

**When adding or moving authored game content:**

- Prefer **`res://assets/`** domain packages (**§2–§4** of the plan): `creatures/`, `plants/`, `environment/`, secondary **`locations/`**, **`_shared/`**, plus future **`ui/`**, **`audio/`**, etc. when adopted there.
- **`main.tscn`**, menus, and **app shell** flow stay **outside** **`assets/`** by default (**§4.1** — e.g. **`scenes/app/`**), not as a content pack.
- **`res://art/`** is **grandfathered** — do not pour new files into `art/` unless an explicit task or feature doc says so (e.g. env palette bake paths).

**Per-pack `pack_resources.json` + `assets/_shared/` (§2.1):**

- Each domain package **may** include **`pack_resources.json`** beside its art/scenes — root object includes **`shared_resources`**: tag → **`res://…`** for slots **not** satisfied by co-located files; optional root **`notes`**. Omit file when everything is local, or use **`"shared_resources": {}`**.
- **`assets/_shared/`** holds **pooled** blobs; packs reference them **through** **`shared_resources`**, not by sprinkling raw `_shared` paths in gameplay code (**`PackResourceResolver`** in **`res://pack_resource_resolver.gd`**).
- **`assets/_shared/default/<kind>/`** is **resolver-only**. **Editor/dev:** loud cues (neon textures, alarm-style SFX). **Release:** subtle substitutes (neutral gray textures, silence for bad audio). **Tests** should still **fail** if **`default/`** resolves during CI unless the test expects a missing-resource case.

**Pack README:** **Not required** for routine POC/in-house work — prefer **`pack_resources.json`** (**`notes`** / **`shared_resources`**) per plan §3.

**Variants** (e.g. `horse.riding` vs `horse.draft`): follow **§2.2** — **dotted** variant ids at runtime; folder pattern **A**, **B**, or **C** as documented per asset.

**Refactors:** Global **AGENTS.md** prohibits casual renames/moves. Asset tree changes are **explicit migration tasks** with `.tscn` / `.gd` reference updates.

**Archived docs:** Other entries under **`Project_Docs/Completed_Features/`** are historical per-feature specs and do not replace **ASSET_MANAGEMENT_PLAN.md** for **`assets/`** layout unless the user explicitly asks.
