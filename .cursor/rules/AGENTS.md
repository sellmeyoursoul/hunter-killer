# Compatibility pointer

This file remains for existing references (Project_Docs, workspace rules).

**Current source of truth:** [`core.mdc`](./core.mdc) (`alwaysApply: true`)

**Scoped rules:** `gdscript.mdc`, `logging.mdc`, `agentic-runtime-ai.mdc`, `assets.mdc`, `project-docs.mdc`, `subagent-governance.mdc`, `subagent-provisioning.mdc` in this folder.

**Doc sync:** Policy in [`core.mdc`](./core.mdc) **Doc sync**; playbook in [`project-docs.mdc`](./project-docs.mdc).

**Legacy focus stubs:** [`focus/`](./focus/) — each `*.md` points to the matching `.mdc`.

**Subagent governance:** Full orchestration protocol in [`subagent-governance.mdc`](./subagent-governance.mdc). Provisioning template in [`subagent-provisioning.mdc`](./subagent-provisioning.mdc) and [`.cursor/agents/_TEMPLATE.md`](../agents/_TEMPLATE.md).

## Path → agent routing

Route by **primary write-target directory**. When a task spans multiple known domains with an explicit path list, use `code-executor`. When a path is wholly unmapped, provision a new agent per `subagent-governance.mdc`.

| Primary write path | Agent |
|--------------------|-------|
| `creature/motor/` | `creature-motor` |
| `creature/definition/`, `creature/capabilities/`, `creature/species/`, `creature/templates/`, `creature/memory/`, `creature/creature_root_3d.gd`, `creature/awareness_debug_overlay_3d.gd` | `creature-entity` |
| `AI_int_lib/`, `inference/` | `ai-runtime` |
| `environment/`, `assets/locations/`, `assets/environment/`, `assets/plants/` | `environment-world` |
| `main_3d.gd`, `main_3d.tscn`, `hud.gd`, `hud.tscn`, `game_config.gd`, `game_config.json`, `oLog_lib/`, `pack_resource_resolver.gd`, `product_brand.gd`, `project.godot`, `art/` | `app-shell` |
| `assets/creatures/`, `assets/_shared/` | `assets-pack` |
| `tests/`, `tools/` | `test-harness` |
| `Project_Docs/`, `.cursor/rules/` (contract sync) | `project-docs` |
| `Project_Docs/Draft_Features/` (design only, pre-implementation) | `feature-designer` |
| Explicit multi-domain path list from orchestrator | `code-executor` |

All specialist definitions live in [`.cursor/agents/`](../agents/).
