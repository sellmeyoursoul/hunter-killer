# Creature motivation traits — usage map (tier III)

> **Purpose:** **Code-facing map** for the four **`CreatureDefinition`** motivation traits (−100…+100): where scalars are read, which systems consume them today, and what remains deferred. **Semantics and survival-plan narrative** stay in draft **[CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) §3–§5** — do not duplicate pole/modality tables here except for quick lookup.
>
> **Read order:** [CREATURE_GOAL_DRIVERS.md](../Draft_Features/CREATURE_GOAL_DRIVERS.md) (why traits exist) → **this file** (where code reads them) → [CREATURE_MEMORY.md](../Draft_Features/CREATURE_MEMORY.md) §2.2 / §14 (replay projection) → [CREATURE_MOVEMENT_V2.md](../Draft_Features/CREATURE_MOVEMENT_V2.md) §A.3.1 / §A.4 (motor bands; traits pointer).
>
> **Implementation snapshot (repo):** Four `@export_range(-100, 100)` ints on [`creature_definition.gd`](../../creature/definition/creature_definition.gd). **Spawn-fixed** (copied once per body into `_goal_memory_meta_for_body` — no per-tick mutation). **Live:** Slot A replay + Slot B **`change_stability`** rank bias + salient-write trait dict passthrough. **Stub:** Tier-2 **`tier2_urgency_channels`** ([`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) zero deltas). **Not traits:** Preserve/Find bands, flee/jeopardy ticks, compassion/community motor fields.

---

## 1. The four axes

| Export | −100 pole | +100 pole | `CreatureDefinition` default |
|--------|-----------|-----------|----------------------------|
| `explorer_builder` | Explorer | Builder | `0` |
| `change_stability` | Change | Stability | `0` |
| `compassion_self_interest` | Compassion | Self-interest | `0` |
| `community_individual` | Community | Individual | `0` |

**Application order** when multiple axes influence the same pass: sort by **`abs(trait_value)`** descending; ties **`explorer_builder` → `change_stability` → `compassion_self_interest` → `community_individual`** ([CREATURE_GOAL_DRIVERS.md §3](CREATURE_GOAL_DRIVERS.md)).

**UI convention:** Slider **left (−100)** = first pole; **right (+100)** = second pole (all four fields).

### 1.1 Pole facets ↔ trait axes (replay lookup)

Slot A uses **eight global pole ids** on each `LocalePriorMap` row (`pole_facet_tag`). Each pole maps to one **`CreatureDefinition`** axis and a sign ([CREATURE_GOAL_DRIVERS.md §5.1](CREATURE_GOAL_DRIVERS.md) — full table).

| Pole id | Axis field | Sign at −100 pole | Sign at +100 pole |
|---------|------------|-------------------|-------------------|
| `explorer` | `explorer_builder` | aligned (−1) | misaligned (+1) |
| `builder` | `explorer_builder` | misaligned | aligned |
| `change` | `change_stability` | aligned | misaligned |
| `stability` | `change_stability` | misaligned | aligned |
| `compassion` | `compassion_self_interest` | aligned | misaligned |
| `self_interest` | `compassion_self_interest` | misaligned | aligned |
| `community` | `community_individual` | aligned | misaligned |
| `individual` | `community_individual` | misaligned | aligned |

**Code:** `raw_axis_for_pole(traits, pole_tag)` in [`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd) (`_POLE_AXIS`, `_POLE_SIGN`).

---

## 2. Spawn → runtime read path

| Step | Location | Behavior |
|------|----------|----------|
| Authoring | Species `.tres` under [`creature/species/`](../../creature/species/) | Four int exports; archetypes default **0** unless tuned |
| Spawn / motor tick | [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) `_goal_memory_meta_for_body` | Builds `traits` dict from `body.definition` (float copies of four fields) |
| Salient outcomes | `try_salient_write(..., traits, ...)` | Validates pole tags; does **not** re-read definition mid-episode |
| Motor consult | `_apply_believed_goal_bias_to_ctx`, `consult_threat_response` | Passes same `meta["traits"]` into [`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd) |
| Tier-2 urgency telemetry | `_build_motor_context` → `tier2_urgency_channels` | [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) — **stub** returns base channels only |

**Phase-1 vs full spec:** GOAL_DRIVERS §5.1 defines full Slot A top-3 pole blend at write and per-family top-3 modality blend at replay. **Shipped consult path** uses **rank-1 `pole_facet_tag` per row** for Slot A (sufficient for phase-1 personality tint). Write-time multi-pole episodes still validate up to one pole per continuum.

---

## 3. What is live in code today

| Consumer | Traits used | Module / hook |
|----------|-------------|---------------|
| **Slot A replay (personality pull)** | All four via **pole facet** alignment on stored `pole_facet_tag` | [`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd) — `slot_a_raw_for_pole`, `effective_slot_a`, `consult_replay_weight` |
| **Slot B rank bias (novelty vs proven)** | **`change_stability` only** | [`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd) — `_replay_rank_bundle` → `trait_rank_bias` |
| **Salient write metadata** | Passed through on outcome hooks (poles validated at write) | [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) — `_goal_memory_meta_for_body` → `try_salient_write` |
| **Believed goal pull** | Same as consult replay when `context_hash` matches | [`ai_driver.gd`](../../AI_int_lib/ai_driver.gd) — `_apply_believed_goal_bias_to_ctx` |
| **Tier-2 urgency channels** | **Stub — zero delta** | [`trait_tier2_mapper.gd`](../../creature/motor/trait_tier2_mapper.gd) — `apply_trait_urgency_channels` returns base only |
| **Preserve / Find food bands** | **Not** trait-driven | [`tier2_dominance.gd`](../../creature/motor/tier2_dominance.gd) — `preserve_find_food_seek_scale(calorie_ratio, motor_p)` |
| **Cardinal flee / jeopardy** | **Not** trait-driven (fixed `creature_motor` ticks) | [CREATURE_MOVEMENT.md](./CREATURE_MOVEMENT.md) §5 |
| **Compassion / community motor** | **Not wired** | Deferred — see §4 |

**`external_urgency`** (jeopardy + hunger subscores) caps how strong Slot A can be at replay — independent of trait sign; see [CREATURE_GOAL_DRIVERS.md §5.1.3](../Draft_Features/CREATURE_GOAL_DRIVERS.md).

### 3.1 `creature_motor` keys that touch replay (not trait exports)

Authoritative defaults: [`game_config_merge.gd`](../../AI_int_lib/game_config_merge.gd) `default_creature_motor_params()`. Traits do **not** add pack keys; replay reads **`motor_p`** + **`traits`** dict together.

| Key | Default | Trait interaction |
|-----|---------|-------------------|
| `replay_bell_k` | 1.4 | Slot B bell shape |
| `replay_w_fit` / `replay_w_store` | 0.4 / 0.6 | Slot B blend |
| `replay_n_sat` / `replay_n_min` | 10 / 3 | Confidence |
| `urgency_boost_linear_slope` | 25 | Slot A cap lift with `external_urgency` |
| `replay_urgency_slot_b_min` | 90 | Gate for urgency boost |
| `preserve_bias_food_floor` / `seek_priority_food_ceiling` | 0.90 / 0.80 | **Calorie bands only** — not trait-driven |
| `weight_believed_goal_pull` | 6.4 | Scaled by `replay_weight` at consult |

---

## 4. Slot A replay (phase-1 shipped)

Per consult row with matching `(GoalKind, context_hash)`:

```text
raw_axis(pole) = (trait_scalar / 100) * pole_sign(pole)
slot_a_raw     = clamp(abs(raw_axis) * 100, 0, 100) * sign(raw_axis)
effective_a    = sign(slot_a_raw) * min(abs(slot_a_raw), cap_final)
replay_delta   = effective_a * (slot_b_base / 100) * confidence
replay_weight  = stored_strength * (1 + replay_delta / 100)
```

- **`cap_final`** = `bell_cap(slot_b_base)` + `urgency_boost(external_urgency, slot_b_base)` ([`goal_source_memory.gd`](../../creature/motor/goal_source_memory.gd)).
- **Pole tags** on locale rows: rank-1 `pole_facet_tag` at write (eight global ids — [CREATURE_GOAL_DRIVERS.md §5.1](CREATURE_GOAL_DRIVERS.md)).

**Example:** `explorer_builder = -80` + row tagged `explorer` → positive `slot_a_raw` → higher `replay_weight` when hash matches (explorer-aligned creature favors explorer-colored episodes).

---

## 5. Deferred (backlog / future)

| Item | Doc | Notes |
|------|-----|-------|
| **Trait → Tier-2 urgency deltas** | [CREATURE_GOAL_DRIVERS.md §3.3.1](../Draft_Features/CREATURE_GOAL_DRIVERS.md), [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) | `urgency_find_food`, `urgency_avoid_hostiles`, … remain base-only |
| **Learned trait drift** | [CREATURE_GOAL_DRIVERS.md §3.4](../Draft_Features/CREATURE_GOAL_DRIVERS.md) | Success/failure nudges on pole channels — **not** in tick replay |
| **Compassion / community motor** | [CREATURE_GOAL_DRIVERS.md §3.1](../Draft_Features/CREATURE_GOAL_DRIVERS.md) | Conspecific fields, herd centering, contest — minimal today |
| **Full Slot B `current_fit` matchers** | [CREATURE_GOAL_DRIVERS.md §5.1.4](../Draft_Features/CREATURE_GOAL_DRIVERS.md) | Classifier flags only; qualitative table long-term |
| **`ExperienceRing` + map/ring disagree** | [ENHANCEMENT_BACKLOG_PLAN.md](../ENHANCEMENT_BACKLOG_PLAN.md) | Phase 1: `LocalePriorMap` only |

---

## 6. Related (not motivation traits)

| Mechanism | Distinction |
|-----------|-------------|
| **Stat pools** (`stat_fit`, `curr_point_fit`, …) | Physical RPG pools — [CREATURE_ATTRIBUTES_USAGE.md](./CREATURE_ATTRIBUTES_USAGE.md); **not** `explorer_builder` |
| **`current_fit(modality)`** | Slot B tactic applicability 0…1 — [CREATURE_GOAL_DRIVERS.md §5.1.4](../Draft_Features/CREATURE_GOAL_DRIVERS.md) |
| **`calorie_ratio`** | Vitals band for Tier-2 dominance / hunger `external_urgency` — [CREATURE_MOVEMENT_V2.md §A.3.1](../Draft_Features/CREATURE_MOVEMENT_V2.md) |

---

## 7. Maintenance

- When trait wiring changes (e.g. non-stub `apply_trait_urgency_channels`), update §2 and §4 with **file paths** and set rows to **Live**.
- Keep pole / modality vocabulary aligned with [CREATURE_GOAL_DRIVERS.md §5.1](../Draft_Features/CREATURE_GOAL_DRIVERS.md) — do not fork tag ids here.

---

## 8. Changelog

| Date | Change |
|------|--------|
| 2026-06-04 | D.4 completion: spawn read path, pole↔axis table, replay motor keys, phase-1 vs spec note; cross-links MOVEMENT §A.4. |
| 2026-06-04 | Initial tier III map (Phase D): four traits, Slot A/B live paths, Tier-2 urgency stub. |
