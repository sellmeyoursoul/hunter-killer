# Hunter Killer — Multi-predator (multiple simultaneous mobs) support

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Multi-predator scene/observability/behavior support

**Status (2026-09-15):** All four implementation steps done — see §10 Changelog. `main_3d.gd` spawn is fully species-agnostic (any archetype, any count, driven by `playfield_spawn.creatures`), not just N-carnivores; herbivore/carnivore is purely each archetype's own `feeding_mode` trait. F10 HUD shows every active creature, color-matched to its F9 awareness zone. `_flee_objective` now blends every in-awareness threat's away-vector (proximity-weighted, not nearest-only), with remint-to-remint bearing smoothing to guard the C9-class resonance risk. Not yet done: the learned evasive-turn-bias mechanism itself is tracked separately in [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) — its "closing threat" reward-signal plumbing was deliberately not built here (see §9 below), and live-eyeball verification of the F10 HUD rewrite is still outstanding (§8). Surfaced while sketching a learned evasive-turn bias for flee ([CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md), "learned evasive-turn bias from active-pursuit distance trend"), which wants to credit a fleeing creature's turn choice against *every* currently-closing threat, not just the nearest — a scenario today's 1v1 duel can never actually exercise.

**One-line objective:** Scope what it takes to run an encounter with more than one live predator (e.g. two or three foxes) at once — scene/spawn structure, live observability tooling, and the AI-level behaviors that currently assume exactly one hostile — before building anything that depends on multi-predator data or behavior.

**Out of scope (explicit non-goals):**
- Pack-hunting coordination / deliberate multi-predator tactics (surrounding, herding) — a later, separate feature; this phase is "can multiple predators exist and be observed and fled from sanely," not "do they cooperate."
- The learned evasive-turn-bias mechanism itself — tracked in [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md). This doc covers the multi-predator plumbing that mechanism's multi-threat credit assignment would need, not the learning mechanism itself.
- Multiple simultaneous *prey* (multiple herbivores) — not investigated here; may share some of the same scene-structure gaps, not confirmed.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** `main_3d.gd` / `main_3d.tscn` (duel scene; spawn is now data-driven via `playfield_spawn.creatures` — any archetype list, any counts, default reproduces the historical 1v1 rabbit-vs-fox duel).

**Key scripts (paths):**
- `res://main_3d.gd` — creature spawn (`_resolve_creature_spawn_plan`/`_spawn_configured_creatures`), round tracking, win-condition tagging. No longer structurally 1v1 or herb/carn-bucketed (see §4) — F10 HUD (step 3) and `_flee_objective` (step 4) are the remaining gaps.
- `res://creature/motor/motor_planner.gd` (`_flee_objective`) — flee bearing selection, nearest-threat-only today.
- `res://creature/motor/motor_goal_hub.gd` (`urgency_flight`) — Flight arbitration urgency, already correctly multi-threat (max over samples).
- `res://creature/motor/awareness_zone_scan.gd` — threat scanning, already generic group-based (`tree.get_nodes_in_group(&"mobs")`).
- `res://creature/motor/motor_planner_debug_hud.gd` — F10 live debug HUD, hardcoded to one carnivore.
- `res://creature/motor/creature_motor_stack.gd` (`_creature_log_label`, `get_debug_snapshot`) — tick-log labeling and the new `nearest_threat_dist`/`nearest_threat_id` fields (2026-09-15).

**Existing patterns to follow:**
- [`.cursor/rules/AGENTS.md`](../../.cursor/rules/AGENTS.md)
- Tick-log per-instance labeling already solved this exact ambiguity problem once (`species_id + "#" + get_instance_id()`, CLEANUP C2) — reuse that pattern anywhere else multiple same-species instances need to stay distinguishable, don't invent a second convention.

---

## 3. Requirements

### Must have
- [x] Spawn more than one carnivore in a single duel/encounter (data- or config-driven count, not a second hardcoded scene). **Done, and generalized further:** spawn is species-agnostic — any archetype (not just carnivores), any count, any mix, via `playfield_spawn.creatures`.
- [x] Live observability (F10 HUD or equivalent) for every active predator, not just whichever happens to be first in the `mobs` group. **Done, and generalized further:** shows every active *creature* (any species), not just carnivores — one color-matched label per creature.
- [x] Flee direction (`_flee_objective`) that accounts for multiple simultaneous closing threats, not nearest-only. **Done:** proximity-weighted blend across every in-awareness threat (not gated on "closing" — see §9), reduces to nearest-only exactly at 1 threat.

### Should have
- [x] Round-end / win-condition logic generalized beyond a single tracked carnivore body — **done**: each non-player creature's own outcome (`win`/`active`) is logged independently (§9 decision), not a flat "carnivore" aggregate.

### Nice to have
- [x] Configurable predator count for smoke-testing — **done via `playfield_spawn.creatures`** (config-driven, no debug const needed; live-smoke-tested at 1 and 3 carnivores, and at a 2-rabbit + 2-fox mix).

---

## 4. Technical design

### Architecture / data flow

**Confirmed already multi-predator-safe (no changes needed):**
- `awareness_zone_scan.gd`'s threat scan is a generic loop over `tree.get_nodes_in_group(&"mobs")` — picks up any number of predators with zero changes.
- `motor_goal_hub.gd::urgency_flight` ([motor_goal_hub.gd:173-194](../../creature/motor/motor_goal_hub.gd#L173-L194)) already takes the **max urgency across every threat sample** in `threat_samples`, not a single hardcoded threat — "should I flee, how urgently" is already correct for N predators.
- Tick-log labeling (`_creature_log_label`, [creature_motor_stack.gd:480](../../creature/motor/creature_motor_stack.gd#L480)) already differentiates same-species instances by `species_id + "#" + get_instance_id()` (CLEANUP C2) — three foxes log as three distinct prefixes. The new `nearest_threat_dist`/`nearest_threat_id` debug fields (2026-09-15, added for the flee gate/evaluation-window data-collection pass) use the same raw instance id, so a fleeing creature's log line can be cross-referenced against whichever specific predator it's nearest to.

**Confirmed gaps, each independent of the others:**

1. ~~**`_flee_objective` is nearest-only**~~ **Fixed (2026-09-15).** Now sums every in-awareness threat's away-unit-vector, weighted `1 / max(gate_dist, flee_threat_weight_min_dist)`, normalized — with exactly one threat this reduces to the historical nearest-only bearing exactly (a single vector's own weight cancels out on normalize), so 1v1 flee is bit-identical to before. Added `flee_bearing_smoothing` (angle-space lerp toward the previous remint's chosen bearing, new `state["flee_blend_dir_prev"]`/`_set`) — only engages with 2+ contributing threats, targeting the exact C9-class resonance risk (two similar-weight threats on opposite/adjacent sides flipping the seed bearing) the risk table below calls out. `_mint_flee_waypoint`'s downstream 6-candidate reachability scoring is untouched — it still just receives whatever seed bearing `_flee_objective` hands it, including a degenerate/near-cancelled one when threats roughly surround the creature (falls back to a valid horizontal direction, verified by regression test, not just assumed safe).
2. ~~**F10 debug HUD is hardcoded to one carnivore**~~ **Fixed (2026-09-15).** `_resolve_creature_root(&"carnivore")`/`&"herbivore"` and the two fixed `HerbivoreLabel`/`CarnivoreLabel` nodes are gone. `motor_planner_debug_hud.gd` now calls `main_3d.gd::get_all_creature_roots()` and pools one `Label` per active creature under a new `CreatureLabels` `HFlowContainer` (`hud.tscn`), wrapping to fit any count. Display stripped to a creature-id title (`species #instance_id`, same id `nearest_threat_id`/tick-log use) plus `src=`/`gk=` only — full field set stays available via `_ExploreLog.format_explore_tick_hud`/the tick log, referenced in a code comment for fast opt-back-in. Each label's font color and that creature's F9 awareness-zone fill now derive from a shared `creature/creature_debug_color.gd` (`CreatureDebugColor.color_for_instance_id`, golden-ratio hue hashing) so a zone in the 3D view and its HUD entry are visually matched with no cross-node wiring. Panel visibility no longer depends on "round active" — `_refresh_labels()` only overwrites a label when it finds live creature+stack data, so the last tick before creatures were freed stays on screen through round-end instead of blanking or hiding.
3. ~~**`main_3d.gd` is structurally 1v1, not just tuned that way.**~~ **Fixed (2026-09-15), and generalized beyond N-carnivores to full species-agnostic spawn.** `_herbivore_root`/`_herb_body`/`_carnivore_root`/`_carn_body` singular/typed-array variables are gone, replaced by generic `_creature_roots`/`_creature_bodies` arrays plus an explicit `_player_body` reference (the one spawn entry flagged `player_controlled`, not "the herbivore"). `_spawn_configured_creatures()` walks `playfield_spawn.creatures` — a flat `{archetype, count, player_controlled}` list — and instantiates each archetype's own `body_scene` (new `CreatureDefinition.body_scene` field); `_creature_groups_for()` derives group membership (`mobs`/`prey`/`herbivores`/`player`) purely from `feeding_mode` and `player_controlled`, never from a spawn-time bucket. Round-end win tagging now credits the specific `winning_predator` body and logs every other creature's own outcome independently (§9 decision). Live-smoke-tested at 1v1 (unchanged), 1 rabbit + 3 foxes, and 2 rabbits + 2 foxes — all ran 3600 physics ticks clean.

**Note (2026-09-15):** the diet/threat AI layer itself (`DietRegistry.default_food_intake_policy`'s shared per-feeding-mode `prey_groups` lists, and `awareness_zone_scan._is_threat_to_subject`'s strict hostile-vs-non-hostile two-faction test) still assumes a flat two-faction world, not per-species relationships — a genuine "lion + tiger + bear, no herbivore at all" or "rabbit + fox + hawk" encounter will *spawn* fine but the AI's who-eats-whom/who's-a-threat-to-whom logic won't distinguish species within a faction. That's a separate, larger investigation, not part of this phase's scope (which is spawn/observability/flee plumbing, §1) — flagged here so it isn't mistaken for solved.

### Scene & file changes
| Action | Path | Notes |
|--------|------|--------|
| done | `res://main_3d.gd` | Generic `_creature_spawn_plan`/`_creature_roots`/`_creature_bodies`/`_player_body`; `_spawn_configured_creatures()` replaces `_spawn_duel_pair()`; round-end logic credits/logs per-creature outcomes. |
| done | `res://creature/definition/creature_definition.gd` | New `body_scene: PackedScene` field — archetype now names its own spawn template instead of `main_3d.gd` switching on species. |
| done | `res://creature/motor/motor_planner_debug_hud.gd` | Dynamic per-creature label pool via `main_3d.gd::get_all_creature_roots()`; minimal `src`/`gk` fields; color-matched to F9 overlay; frozen on round end. |
| done | `res://creature/creature_debug_color.gd` | New shared deterministic-color helper (instance id → hue) used by both the F10 HUD and the F9 awareness overlay. |
| modify | `res://creature/awareness_debug_overlay_3d.gd` | Zone fill color now per-creature via `CreatureDebugColor` instead of one fixed cyan for everyone. |
| modify | `res://hud.tscn` | `HerbivoreLabel`/`CarnivoreLabel` replaced with a `CreatureLabels` `HFlowContainer` populated at runtime. |
| done | `res://creature/motor/motor_planner.gd` | `_flee_objective` — proximity-weighted multi-threat blend + `state`-carried remint-to-remint bearing smoothing; both call sites (`_mint_flee_waypoint`, the `GK_AVOID_HOSTILES` live-refresh path) updated to pass `state`. New `_threat_world_pos` helper factored out of the old single-nearest lookup. |

### Collision / input / signals (if relevant)
- Groups: `&"mobs"` already generic — no change needed there.

### Dependencies
- None external.

---

## 5. Implementation plan (ordered)

1. ~~**Scene/spawn structural change first**~~ **Done (2026-09-15)** — and generalized to a fully species-agnostic spawn list, not just an N-carnivore collection.
2. ~~**Round-end/win-condition redefinition**~~ **Done (2026-09-15)** — per-creature independent outcome logging, per §9 decision below.
3. ~~**F10 HUD**~~ **Done (2026-09-15)** — shows every active creature, color-matched to its F9 zone, frozen on round end.
4. ~~**`_flee_objective` multi-threat blending**~~ **Done (2026-09-15)** — proximity-weighted blend (per DESIGNREVIEW.md §9's own answer for bearing selection, not the separate "closing threats" reward-signal question) plus remint smoothing for resonance safety.
5. **Learned evasive-turn bias** (out of scope here, tracked in DESIGNREVIEW.md §9) is now buildable against real multi-predator data — steps 1-4 are all done. Its own reward-signal plumbing (a per-threat "closing" distance-trend tracker) was deliberately **not** built as part of step 4 — a distinct concern (reward attribution, not bearing selection) with its own unresolved open questions (gate window, evaluation window), left for whenever that slice is actually scoped rather than built speculatively now.

---

## 6. Acceptance criteria

- [x] A duel/encounter can spawn a configurable number of carnivores (tested with at least 3) without scene-file duplication. **Exceeded:** any archetype, any count, any mix — tested at 3 foxes and at 2 rabbits + 2 foxes.
- [x] F10 HUD shows every active predator, or provides a way to cycle through them. **Exceeded:** shows every active creature (any species), one color-matched label each, no cycling needed.
- [x] `_flee_objective` demonstrably reacts to more than the single nearest threat (regression test with 2+ threats at different bearings). **Done:** 4 new regression tests (`tests/run_all.gd`) cover single-threat bit-identical output, multi-threat blend divergence from nearest-only, surrounded/degenerate cancellation, and smoothing's damping effect; plus a live 1-rabbit-vs-3-fox smoke run confirmed `thr=2`+ flee ticks actually occur.
- [x] Round-end win condition has an explicit, documented definition for the multi-carnivore case — each non-player creature's own outcome logged independently.
- [x] Existing 1v1 duel behavior and full headless test suite remain unchanged — headless suite green (only the pre-existing non-deterministic ObjectDB flake), 1v1 smoke run byte-identical in behavior to before.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Destabilizing the well-tested 1v1 duel loop while generalizing spawn/tracking | Keep 1v1 as the default count; add regression coverage for both 1v1 and N-predator paths before/after the change, same acceptance-bar discipline as §1's continuous-controller migration (headless + live re-runs of historical repros). |
| Round-end ambiguity with multiple carnivores (first to eat wins? all must fail for herbivore win? shared win?) | Explicit design decision needed before step 2 — see open questions below, not assumed. |
| Performance at N predators | Expected non-issue — threat scanning and `urgency_flight` are already O(threats-in-awareness) loops over data structures sized for this; this is a small local-encounter game, not a scale concern. Confirm with a headless smoke run at the target N once built, not assumed. |
| `_flee_objective` multi-threat blending reintroducing a C9-style resonance/oscillation bug (recall the flee-waypoint family's history — 7 fix iterations) | **Addressed:** left `_mint_flee_waypoint`'s geometry/reachability-scored candidate machinery untouched (blending only changes the seed bearing it works from); added remint-to-remint bearing smoothing specifically for the 2+-threat case, gated off entirely at 1 threat so it can't touch the already-hardened single-threat path. Verified via regression test (smoothing measurably dampens a forced bearing swing) and a live 3-fox smoke run — not yet stress-tested against an adversarial multi-predator scenario designed to hunt for a limit cycle the way C9's historical repros did. |

---

## 8. Testing / verification

**Manual steps:**
- Live duel with 2-3 foxes, F10 HUD open, confirm all are observable. **Confirmed (2026-09-15) by user** — HUD live-tested and looked good.
- **Not yet manually eyeballed (2026-09-15):** the `_flee_objective` blending/smoothing rewrite — verified via regression tests, a live 1-rabbit-vs-3-fox headless smoke run (confirmed `thr=2`+ flee ticks actually occurred via `motor_explore_tick.log`), and reasoning about the math, but not watched live in an editor session for visible waypoint-choice sanity (does a rabbit between two foxes actually pick a sensible escape gap, does the smoothing look natural rather than sluggish). Do that before calling step 4 fully closed.

**Automated:**
- Headless smoke (`tests/smoke_ai_player.gd`) at the target predator count, watched for the same invariant classes already tracked (C9 stuck, C10 airborne) plus any new resonance from multi-threat flee blending — run clean at 1 rabbit + 3 foxes, 3600 ticks, no errors.
- Regression tests for `_flee_objective` with 2+ simultaneous threats at different bearings/distances — **done**, 4 tests added: `_test_motor_planner_flee_objective_single_threat_matches_nearest_only`, `_test_motor_planner_flee_objective_blends_multiple_threats`, `_test_motor_planner_flee_objective_surrounded_threats_degrade_gracefully`, `_test_motor_planner_flee_objective_smoothing_dampens_bearing_swing`.

---

## 9. Open questions

**Answered (2026-09-15):** "Carnivore wins" tracks each predator's own success independently — `end_round`/`_log_round_outcome` credit the specific `winning_predator` body and log every other still-live creature as `active`, not a flat aggregate.

**Answered (2026-09-15), and broadened:** spawn is not just "uniform vs. mixed carnivore species" — it's a fully generic `{archetype, count, player_controlled}` list, so any mix (including non-carnivore species, e.g. 2 rabbits + 2 foxes) is a config change, not a code change. Live-smoke-tested. **Still unresolved:** whether per-species threat/diet *relationships* (as opposed to spawn) need validation — see the §4 note above. `kind_threat_for_sample` referenced in the original write-up was not found under that name; the live equivalent is `awareness_zone_scan.gd`'s `_is_threat_to_subject`, which still assumes a strict two-faction hostile/non-hostile world (not per-species pairs) — flagged, not fixed, by this phase.

**Answered (2026-09-15):** a simpler "weighted average of away-vectors" first cut, refined later — with remint smoothing folded in from the start (not deferred) specifically because the risk table above already named the exact resonance failure mode this shape is prone to; re-read DESIGNREVIEW.md §9 mid-discussion and confirmed it already answers "proximity-weighted" for bearing selection specifically (distinct from that section's separate "closing threats" question, which is about reward-signal gating for the *future* learned-bias mechanism, not about picking a flee direction now) — see the resolved verification item in DESIGNREVIEW.md §9.

**Answered (2026-09-15):** carnivore-only framing is retired along with the spawn refactor — `playfield_spawn.creatures` already supports multiple prey (herbivores) in the same list as multiple predators; there's no separate "prey-side" spawn path left to fold in. What's *not* covered: the diet/threat AI relationship work flagged in the §4 note (same caveat as the answer above).

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-09-15 | Created from the investigation surfaced while sketching CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9's learned evasive-turn-bias slice candidate. Three gaps confirmed (`_flee_objective` nearest-only, F10 HUD single-carnivore, `main_3d.gd` structurally 1v1); two areas confirmed already multi-predator-safe (threat scanning, `urgency_flight`). No code changed — investigation only. |
| 2026-09-15 | **Step 1 implemented as N-carnivore spawn** (`_carnivore_roots`/`_carn_bodies` arrays, `playfield_spawn.carnivore_count`), then **immediately generalized further** per user direction: spawn is fully species-agnostic (`playfield_spawn.creatures` list of `{archetype, count, player_controlled}`, new `CreatureDefinition.body_scene` field, `_creature_roots`/`_creature_bodies`/`_player_body`, `_creature_groups_for()` deriving groups from `feeding_mode`/`player_controlled` traits only). Round-end/win-condition generalized alongside it (per-creature independent outcome logging). `hit` signal gained a `predator: Node` param so round-end can credit the specific catcher. Headless suite green (pre-existing flake only); live-smoke-tested 1v1 (byte-identical behavior), 1 rabbit + 3 foxes, and 2 rabbits + 2 foxes (3600 ticks each, no crashes). Flagged, not fixed: `DietRegistry`/`awareness_zone_scan` diet-threat logic still assumes a flat two-faction world, not per-species relationships (§4 note) — a separate future investigation, confirmed out of scope for now (user: a future faction system will carry positive/negative interactions; today's boolean hostile/non-hostile threat test stays as-is). Steps 2 (round-end) and the carnivore-count "must have" are done; steps 3 (F10 HUD) and 4 (`_flee_objective` blending) remain. |
| 2026-09-15 | **Step 3 (F10 HUD) done**, per explicit user request. Replaced the two fixed `HerbivoreLabel`/`CarnivoreLabel` nodes with a dynamic per-creature label pool (`CreatureLabels` `HFlowContainer`, `hud.tscn`) driven by `get_all_creature_roots()` — any species, any count. Display stripped to a creature-id title (`species #instance_id`) plus `src=`/`gk=` only, with the full field set left in `_ExploreLog.format_explore_tick_hud`/the tick log for fast opt-back-in when troubleshooting needs more. New shared `creature/creature_debug_color.gd` (`CreatureDebugColor`, golden-ratio hue hashing off `creature_instance_id`) colors each HUD label to match that creature's F9 awareness-zone fill (`awareness_debug_overlay_3d.gd`), so a zone and its readout can be matched at a glance with N creatures live. Panel visibility decoupled from "round active"; `_refresh_labels()` now only overwrites a label when it finds live data, so the last tick before creatures are freed stays on screen through round-end instead of blanking to "(no creature)" or hiding. Headless suite green (pre-existing flake only, confirmed non-deterministic across 3 reruns); live-smoke-tested 3600 ticks with both F9/F10 debug flags on, no errors. **Not yet eyeballed live** — see §8. |
| 2026-09-15 | **Step 4 (`_flee_objective` multi-threat blending) done**, closing this phase's original 4-step plan. Before implementing, re-read [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md) at the user's request, which resolved its own stale "pre-implementation verification item" (written on the mistaken assumption `_flee_objective` might already blend) and clarified that section's "closing threats" answer is scoped to the *future* learned-bias mechanism's reward-signal gating, not to bearing selection here — bearing selection is proximity-weighted, per that section's own text. Two design decisions locked with the user before coding: (1) blend against all in-awareness threats, proximity-weighted, not filtered to "closing" — no new per-threat trend-tracking state needed for this step; (2) add remint-to-remint bearing smoothing from the start rather than wait to discover oscillation live, given the explicit C9 history (7 fix iterations) in the risk table. Deliberately deferred: the closing-threat distance-trend tracker itself (needed later for §9's reward signal) — left for when that slice is actually scoped, not built speculatively now. Implementation: `_flee_objective` sums every in-awareness threat's away-unit-vector weighted `1 / max(gate_dist, flee_threat_weight_min_dist)` (new tunable, default 1.0); with exactly one threat this is bit-identical to the historical nearest-only bearing (a single vector's own weight cancels out on normalize). New `flee_bearing_smoothing` tunable (default 0.35) lerps each remint's raw blend toward the previous remint's chosen bearing in angle-space (not vector slerp — avoids the anti-parallel-vector degeneracy, matches how the rest of this file already reasons about XZ-plane bearings) — gated to only engage with 2+ contributing threats, so 1v1 flee stays untouched. New `state["flee_blend_dir_prev"]`/`"flee_blend_dir_prev_set"` fields (cleared in `clear_flee_waypoint_latch` on Flight-episode exit, per the `step_goal_set`-sentinel convention C9 established). `_flee_objective` gained a `state` parameter threaded through both call sites (`_mint_flee_waypoint`, the `GK_AVOID_HOSTILES` live-refresh path in `_sync_step_objective`). Caught and fixed one bug during test-writing: an `if not state.is_empty()` guard on the state-write was backwards (skipped writing precisely for a fresh `{}`, the normal starting case) — removed, since writing into a throwaway dict is harmless. 4 new regression tests added (single-threat bit-identical, multi-threat divergence, surrounded/degenerate cancellation, smoothing damping — the last one caught the bug above via a failing assertion, not inspection). Headless suite green (pre-existing flake only, reconfirmed stable across 3 reruns); live-smoke-tested 1-rabbit-vs-3-fox for 3600 ticks with no errors, and confirmed via `motor_explore_tick.log` (`thr=2` on live flee ticks) that multi-threat blending actually engaged during the run, not just in unit tests. **Not yet eyeballed live** for waypoint-choice sanity (see §8) — all four of this phase's implementation steps are otherwise complete. |
