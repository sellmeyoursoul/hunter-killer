# Enhancement backlog

Informal parking lot for improvements **not** committed in phase design docs. Priority is rough (**Low** / **Medium** / **High**).

---

## oLog (logging library)

| Item | Priority | Notes |
|------|----------|--------|
| Structured fields (`key=value` or JSON fragments in messages) | Medium | Easier grep and tooling than prose-only lines |
| Rate limiting per callsite / subsystem | Medium | Complements ring eviction; caps repetitive spam |
| Child loggers / fixed subsystem prefix | Medium | e.g. `OLog.child("AI")` prepends tag without passing each time |
| Deterministic `user://` root for automated tests (CI / headless) | Medium | Stable paths under Godot test harness |
| Editor-only or `logging_params.enabled` gate for shipped builds | Medium | Optional once shipping matters |
| Mirror selected levels to remote sink (HTTP, file rotation) | Medium | Out of scope for current file-only design |

---

## AI integration (Dodge the Creeps)

| Item | Priority | Notes |
|------|----------|-------|
| **Perception: cap mob list in prompt** | Medium | When many mobs are **near** the player, serializing **all** `MOB` lines grows tokens and noise. Consider a **max count** (keep **distance-sorted** nearest *K*, drop or aggregate the rest) with a deterministic rule in §4.2 — tune *K* and “near” radius after POC. |

---

## Environment & scripted motor (OBJECT follow-ups)

**Source:** Deferred `<<Comment>>` threads and “parking lot” items from [OBJECT_AVOIDANCE_PLAN.md](Completed_Features/OBJECT_AVOIDANCE_PLAN.md) §8.2.5 / §10 — duplicated here so they survive OBJECT moving to **Completed_Features**. Environment semantics stay in [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) §10.

| Item | Priority | Notes |
|------|----------|-------|
| **`env_detour_patience_ticks`** separate from **`awareness_memory_ticks`** | Medium | v1 reuses one knob for mob ghost history and env detour patience; split if coupled tuning hurts either subsystem ([ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) §10). |
| **Skill-based human HUD / tutor nudge** (safer probing, corridor use) | Low | OBJECT §8.2.5: interior env motor nudges are **ENGINE**-only for that phase; optional **human** assist stays a **separate** UX feature. |
| **Optional headless `can_enter` probes** (learn passibility without bump) | Low | OBJECT §8.2.5 comment — faster belief updates in tests or sim; not required for cardinal v1. |
| **Optional `env_threat_radius`** gate for mob-threat scoring | Low | OBJECT §8.2 v1 uses existing snapshot only; add only if tuning asks for an extra spatial gate ([ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md) §10). |

---

## Other

| Item | Priority | Notes |
|------|----------|--------|
| **`res://` repo layout migration** | Medium | Draft: [REPO_LAYOUT_PLAN.md](REPO_LAYOUT_PLAN.md) — systems vs **`assets/`**, optional **`systems/`** rename, **`scenes/app/`**, **`config/`**; aligns with [ASSET_MANAGEMENT_PLAN.md](Completed_Features/ASSET_MANAGEMENT_PLAN.md) §4 / §9; **do not apply** until draft questions resolved |
| Centralized doc path index | Low | Stable links across renames: historical **`Project Docs/`** vs **`Project_Docs/`**, completed vs active plans — reduces broken cross-references in comments and AGENTS rules |
| World-model feature index | Low | Entry: [VISION_WORLD_BUILDER_PLAN.md](VISION_WORLD_BUILDER_PLAN.md); archive table: [EARLY_SPEC_DOC](EARLY_SPEC_DOC) |

