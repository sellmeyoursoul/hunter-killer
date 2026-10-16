# Assets & `res://assets/` layout

Also applies to `pack_resource_resolver.gd` and any `**/pack_resources.json`, even though those files live outside this directory.

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

**Config layering (pack authoring):** one definition per default; each layer holds only what differs from the layer above.
- **Code default** (`AI_int_lib/game_config_merge.gd`) -> **`game_config.json`** = tuning override only -> **species pack overlay** (`pack_resources.json`) = deliberate species deviations only; never restate a code default -> sub-species later (not implemented).
- Judge overlay redundancy against the **code default**, not the json-merged config: a `game_config.json` tuning pin is not a reason to drop a pack key.
- **Pack config block:** at V3 runtime only the pack's **`creature_motor_v3`** block is applied (merged over `default_creature_motor_v3_params()` via `get_creature_motor_v3_params_for_pack`). The legacy **`creature_motor`** pack block / `game_config.json` section and its dev/ship profiles were retired 2026-10-16 (CBD-1 step 6); do not add a `creature_motor` key to a pack (a test asserts none exists).
- **Where a default lives:** tunables -> `default_*_params()` in `AI_int_lib/game_config_merge.gd` (consume via `_Merge.v3_default(key)` or the merged dict); structural / cross-file constants -> ONE named const in the owning script (e.g. `MotorPlane.DEFAULT_EYE_HEIGHT`, `CreatureDefinition.DEFAULT_STAT`, `FallPhysics.DEFAULT_GRAVITY`). No inline literal fallback duplicating either.
- Audit: `python tools/audit_default_duplicates.py` (CONFLICT should be 0). Background: CBD-1 in [OPEN_BUGS.md](../Project_Docs/OPEN_BUGS.md#cbd-1).

**Pack README:** not required for routine work — use `pack_resources.json` (`notes` / `shared_resources`).

**Variants:** dotted ids at runtime (§2.2); folder patterns A/B/C per asset.

**Refactors:** explicit migration with `.tscn`/`.gd` reference updates (see root [CLAUDE.md](../CLAUDE.md)).
