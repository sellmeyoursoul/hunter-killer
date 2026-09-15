# Hunter Killer — Multi-predator (multiple simultaneous mobs) support

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Multi-predator scene/observability/behavior support

**Status (2026-09-15):** Investigation only — no code changed. Surfaced while sketching a learned evasive-turn bias for flee ([CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md), "learned evasive-turn bias from active-pursuit distance trend"), which wants to credit a fleeing creature's turn choice against *every* currently-closing threat, not just the nearest — a scenario today's 1v1 duel can never actually exercise.

**One-line objective:** Scope what it takes to run an encounter with more than one live predator (e.g. two or three foxes) at once — scene/spawn structure, live observability tooling, and the AI-level behaviors that currently assume exactly one hostile — before building anything that depends on multi-predator data or behavior.

**Out of scope (explicit non-goals):**
- Pack-hunting coordination / deliberate multi-predator tactics (surrounding, herding) — a later, separate feature; this phase is "can multiple predators exist and be observed and fled from sanely," not "do they cooperate."
- The learned evasive-turn-bias mechanism itself — tracked in [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md). This doc covers the multi-predator plumbing that mechanism's multi-threat credit assignment would need, not the learning mechanism itself.
- Multiple simultaneous *prey* (multiple herbivores) — not investigated here; may share some of the same scene-structure gaps, not confirmed.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`).

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** `main_3d.gd` / `main_3d.tscn` (duel scene, currently spawns exactly one herbivore + one carnivore).

**Key scripts (paths):**
- `res://main_3d.gd` — duel spawn, round tracking, win-condition tagging. Structurally 1v1 today (see §4).
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
- Spawn more than one carnivore in a single duel/encounter (data- or config-driven count, not a second hardcoded scene).
- Live observability (F10 HUD or equivalent) for every active predator, not just whichever happens to be first in the `mobs` group.
- Flee direction (`_flee_objective`) that accounts for multiple simultaneous closing threats, not nearest-only.

### Should have
- Round-end / win-condition logic generalized beyond a single tracked carnivore body (`_carn_body`) — needs an explicit decision on what "carnivore wins" means with more than one predator (see §9).

### Nice to have
- Configurable predator count for smoke-testing (e.g. a debug const like `_DEBUG_FORCE_EDGE_CHASE_SPAWN`'s existing pattern), so headless runs can sweep predator counts without scene edits.

---

## 4. Technical design

### Architecture / data flow

**Confirmed already multi-predator-safe (no changes needed):**
- `awareness_zone_scan.gd`'s threat scan is a generic loop over `tree.get_nodes_in_group(&"mobs")` — picks up any number of predators with zero changes.
- `motor_goal_hub.gd::urgency_flight` ([motor_goal_hub.gd:173-194](../../creature/motor/motor_goal_hub.gd#L173-L194)) already takes the **max urgency across every threat sample** in `threat_samples`, not a single hardcoded threat — "should I flee, how urgently" is already correct for N predators.
- Tick-log labeling (`_creature_log_label`, [creature_motor_stack.gd:480](../../creature/motor/creature_motor_stack.gd#L480)) already differentiates same-species instances by `species_id + "#" + get_instance_id()` (CLEANUP C2) — three foxes log as three distinct prefixes. The new `nearest_threat_dist`/`nearest_threat_id` debug fields (2026-09-15, added for the flee gate/evaluation-window data-collection pass) use the same raw instance id, so a fleeing creature's log line can be cross-referenced against whichever specific predator it's nearest to.

**Confirmed gaps, each independent of the others:**

1. **`_flee_objective` is nearest-only** ([motor_planner.gd:2842-2878](../../creature/motor/motor_planner.gd#L2842-L2878)). Picks the single nearest in-awareness threat (`gate_dist` comparison) and flees directly away from it — every other visible threat is ignored when choosing a bearing. `_mint_flee_waypoint`'s 6-candidate reach-scoring works from that one base direction, so the gap is upstream of the candidate scoring, not in it.
2. **F10 debug HUD is hardcoded to one carnivore** ([motor_planner_debug_hud.gd:89-109](../../creature/motor/motor_planner_debug_hud.gd#L89-L109)). `_resolve_creature_root(&"carnivore")` falls back to `get_tree().get_nodes_in_group(&"mobs")[0]` when the scene doesn't name a specific root — always the first predator in that group, no selector, no way to see the others live.
3. **`main_3d.gd` is structurally 1v1, not just tuned that way.** `_carnivore_root` ([main_3d.gd:85](../../main_3d.gd#L85)) and `_carn_body` are singular typed variables (`Node3D`/`CharacterBody3D`), not arrays or a group-backed collection. `_spawn_duel_pair` ([main_3d.gd:853](../../main_3d.gd#L853)) spawns exactly one of each. Round-end win tagging (`predation_carn_win`, [main_3d.gd:1125](../../main_3d.gd#L1125)) is written against that assumption. **This means "add two more foxes" cannot be done as a data/config change today** — it requires real code changes to the scene's spawn, tracking, and round-management layer before any AI-level multi-predator question becomes live-testable at all.

### Scene & file changes
| Action | Path | Notes |
|--------|------|--------|
| modify | `res://main_3d.gd` | `_carnivore_root`/`_carn_body` → array or group-backed collection; `_spawn_duel_pair` → spawn loop over a configurable count; win-condition logic redefined for N carnivores (see §9). |
| modify | `res://creature/motor/motor_planner_debug_hud.gd` | Show every active predator, or add a cycle/selector control instead of `mobs[0]`. |
| modify | `res://creature/motor/motor_planner.gd` | `_flee_objective` — blend or select across multiple threats, not nearest-only. Exact scoring shape not designed yet (see §9). |

### Collision / input / signals (if relevant)
- Groups: `&"mobs"` already generic — no change needed there.

### Dependencies
- None external.

---

## 5. Implementation plan (ordered)

1. **Scene/spawn structural change first** — `main_3d.gd`'s `_carnivore_root`/`_carn_body` → collection, `_spawn_duel_pair` → configurable-count spawn loop. Nothing else in this doc is testable without this.
2. **Round-end/win-condition redefinition** — depends on step 1's shape and on §9's open question below.
3. **F10 HUD** — extend to show all active predators (or a cycle control) once step 1 makes more than one exist to show.
4. **`_flee_objective` multi-threat blending** — once real multi-predator encounters can actually run, design and validate the bearing-selection weighting (proximity-weighted, but a bearing appeasing several medium threats can beat one that's only good against the closest — sketched in [CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9](CREATURE_MOVEMENT_V3_DESIGNREVIEW.md), not designed in detail there since this doc's step 1 wasn't done yet).
5. **Learned evasive-turn bias** (out of scope here, tracked in DESIGNREVIEW.md §9) becomes buildable against real multi-predator data once steps 1-4 land.

---

## 6. Acceptance criteria

- [ ] A duel/encounter can spawn a configurable number of carnivores (tested with at least 3) without scene-file duplication.
- [ ] F10 HUD shows every active predator, or provides a way to cycle through them.
- [ ] `_flee_objective` demonstrably reacts to more than the single nearest threat (regression test with 2+ threats at different bearings).
- [ ] Round-end win condition has an explicit, documented definition for the multi-carnivore case.
- [ ] Existing 1v1 duel behavior and full headless test suite remain unchanged (1v1 stays the default/simplest case, not a special case bolted on top of N-predator code).

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Destabilizing the well-tested 1v1 duel loop while generalizing spawn/tracking | Keep 1v1 as the default count; add regression coverage for both 1v1 and N-predator paths before/after the change, same acceptance-bar discipline as §1's continuous-controller migration (headless + live re-runs of historical repros). |
| Round-end ambiguity with multiple carnivores (first to eat wins? all must fail for herbivore win? shared win?) | Explicit design decision needed before step 2 — see open questions below, not assumed. |
| Performance at N predators | Expected non-issue — threat scanning and `urgency_flight` are already O(threats-in-awareness) loops over data structures sized for this; this is a small local-encounter game, not a scale concern. Confirm with a headless smoke run at the target N once built, not assumed. |
| `_flee_objective` multi-threat blending reintroducing a C9-style resonance/oscillation bug (recall the flee-waypoint family's history — 7 fix iterations) | Don't design this blind — follow the same discipline that closed C9: geometry/reachability-scored candidates, not just bearing math; live + headless repro before calling it done. |

---

## 8. Testing / verification

**Manual steps:**
- Live duel with 2-3 foxes, F10 HUD open, confirm all are observable.

**Automated (if any):**
- Headless smoke (`tests/smoke_ai_player.gd`) at the target predator count, watched for the same invariant classes already tracked (C9 stuck, C10 airborne) plus any new resonance from multi-threat flee blending.
- Regression tests for `_flee_objective` with 2+ simultaneous threats at different bearings/distances.

---

## 9. Open questions

<<Question: what does "carnivore wins" mean with more than one predator — first to eat, or does the round track each predator's own success independently?>>

<<Question: should predator count be uniform (all foxes) or mixed species per encounter — does anything in threat scoring (`kind_threat_for_sample`) already assume same-species threats scored consistently, or would mixed species need separate validation?>>

<<Question: does `_flee_objective`'s multi-threat blending get its own full design pass (candidate scoring, resonance risk) before this ships, or is a simpler "weighted average of away-vectors" acceptable for a first cut, refined later?>>

<<Question: is this phase's scope bounded to carnivores only, or does prey-side multiplicity (multiple herbivores) share enough of the same gaps to fold in now rather than as a separate later investigation?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-09-15 | Created from the investigation surfaced while sketching CREATURE_MOVEMENT_V3_DESIGNREVIEW.md §9's learned evasive-turn-bias slice candidate. Three gaps confirmed (`_flee_objective` nearest-only, F10 HUD single-carnivore, `main_3d.gd` structurally 1v1); two areas confirmed already multi-predator-safe (threat scanning, `urgency_flight`). No code changed — investigation only. |
