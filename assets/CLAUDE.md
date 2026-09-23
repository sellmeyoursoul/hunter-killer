# Assets & `res://assets/` layout

Migrated from `.cursor/rules/assets.mdc`. Keep the two in sync if you edit either. Also applies to `pack_resource_resolver.gd` and any `**/pack_resources.json`, even though those files live outside this directory.

**Authoritative spec:** [ASSET_MANAGEMENT_PLAN.md](../Project_Docs/Completed_Features/ASSET_MANAGEMENT_PLAN.md). Unresolved `<<Question: …>>` on a topic → **stop and ask**.

**New object types** outside listed domains (creatures/plants/environment/locations/`_shared`/§4) or needing a different manifest shape → **stop and ask**; extend ASSET_MANAGEMENT_PLAN before implementing layout.

## Layout

- Prefer **`res://assets/`** domain packages (§2–§4): `creatures/`, `plants/`, `environment/`, `locations/`, `_shared/`, future `ui/`/`audio/` when adopted.
- **`main_3d.tscn`**, menus, app shell → outside `assets/` (e.g. `scenes/app/`).
- **`res://art/`** grandfathered — no new files unless task/feature doc says so.

## `pack_resources.json` + `_shared` (§2.1)

- Per-pack **`pack_resources.json`**: `shared_resources` tag → `res://…` for non-local slots; optional `notes`. Omit or `{}` when all local.
- **`assets/_shared/`** pooled blobs; reference via **`shared_resources`**, not raw `_shared` paths in gameplay (`PackResourceResolver` in `pack_resource_resolver.gd`).
- **`assets/_shared/default/<kind>/`** resolver-only: editor/dev loud cues; release subtle substitutes; CI tests should **fail** if `default/` resolves unless testing missing-resource.

**Pack README:** not required for routine work — use `pack_resources.json` (`notes` / `shared_resources`).

**Variants:** dotted ids at runtime (§2.2); folder patterns A/B/C per asset.

**Refactors:** explicit migration with `.tscn`/`.gd` reference updates (see root [CLAUDE.md](../CLAUDE.md)).
