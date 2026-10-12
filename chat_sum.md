# Handoff Context

**System State:** Branch `Goal_Movement_RefactorV3`. Body-dimensions Phases 0–3 shipped; Phases 4 (HK-models) and 5 not started. Navigation Phase 0 shipped; Phase 1 scoped in docs only (`NAVIGATION_PASSABILITY_PLAN.md` §8.2, T0a–T11 plus T6b), no Phase 1 code. Decisions D11–D30 recorded. Walkable-terrain clamp, NavTiming (`creature/motor/nav_timing.gd`, default OFF) and `tools/measure_nav_cost.gd` (`godot --path . --headless -s res://tools/measure_nav_cost.gd -- frames=2000 warmup=240 [rabbits=N foxes=N wolves=N]`) are in. This session (commit eb1c1d6): (a) **rabbit "fall-through" root-caused and fixed** — it was NOT terrain tunnelling; eaten/starved (`_defeat_hidden`, collision disabled) bodies kept being ticked by `CreatureMotorStack.tick`, fell through terrain, and tripped the C10 airborne invariant (`quit(1)`). `tick()` and `_assert_motor_invariants` are now inert for defeated bodies (`_is_body_defeated`, `set_defeat_inert_enabled_for_test`; test helper `_motor_stack_test_configure` opts out because many fixtures starve bodies on purpose); C10 trip payload now includes `defeat_hidden`/`body_visible`. (b) **spawn-on-prop fixed** — `snap_creature_root_to_ground` / `settle_creature_spawn_on_floor` take `exclude_rids`; `main_3d.gd` passes `_walkable_mask_exclude_rids()` (obstacle + food roots) at all 3 call sites. Tests added for both; ENVIRONMENT_MODEL_PLAN spawn bullet added. Suite exit 0, tab check exit 0. Live bodies unchanged (rabbit r0.385/h1.4, fox 0.22/0.9, wolf 0.715/3.0). Godot is 4.7.

**Progress Made:**
- Verified with a 0.5 m ray scan that terrain collision has no real holes (only (-10,40) walkable-but-no-ground); 3 of 4 C10 repro trips were defeated rabbits, 4th was a rabbit spawned on a tall prop (y≈12.8) walking off.
- Nav-cost baseline after fixes (single run each, no MOTOR_INVARIANT trips): mean total nav ms/physics frame 0.553 @4 creatures (2/1/1), 0.627 @8 (4/2/2), 1.227 @12 (6/3/3) vs B_nav 1.5 ms; per-creature/frame 0.138/0.078/0.102. Pooled active-frame p95 c = 0.73/1.26/1.11 ms (tool's N_active_est = 2/1/1 is the misleading metric per D30). `path_query` dominates; worst single-creature frame 3.2 ms path_query, 1.1 ms ghost_scan @12.
- D26–D30 (earlier): scan_truncated split, T6b terrain step probe, per-class MAX climb bake, B_nav 1.5 ms/frame using p95, N_active definition (roster-level all-frames p95 <= B_nav at N=4/8/12). Phase 4+ note: C++/GDExtension tuning deferred.
- Terrain-edge void-fall fix + docs (earlier session).

**Last Known Trajectory:** Needs D30's real metric: add a **roster-level all-frames p95** (per-physics-frame total across all creatures) to `tools/measure_nav_cost.gd` (it currently prints only the all-frames mean), then re-run at 4/8/12 (ideally several runs per size) to pick N_active — 12 creatures looks near the 1.5 ms limit. Remaining open: **C9 flee-waypoint ping-pong** (seen in some earlier runs, e.g. (-2.3,7.3) and near -z edge (27.8,-98.6); planner unaware of walkable inset, V3 §7.4 comment; hand to `creature-motor`; none seen in the last 9 runs but not proven gone); optional one-line note in `CREATURE_MOVEMENT_V3.md` that a defeated body gets an empty tick outcome; Q13 stacked-levels spike (partial unverified `tools/spike_navmesh_stacked_levels.gd`, T0b); D28 climb-spread threshold; CREATURE_BODY_HULL HQ1–HQ8; fox "remove test pegs" replacement values undecided — ASK before touching; wolf catch-rate re-judge in varied scenarios; user to confirm repo config applies in a fresh play session; CRLF/LF normalization (agreed, not done); optional unused `_delta` removal in `_is_within_eat_range`; `ENVIRONMENT_MODEL_PLAN.md` line ~155 sync when T4 ships; nav plan still says "Godot 4.6" in D25/Q17 history (4.7 actual).


## Pilot: local-worker pipeline on real tasks (next 2-4 tasks)

**Question to answer:** does the architect/worker pipeline (Claude writes a packet and reviews a verified diff; local `qwen3.6:27b` in Zoo Code does the editing; `verify.py` authenticates) cost fewer Claude tokens than Claude doing the same task directly, and by how much? Everything about the pipeline itself (bake-off, verify, Zoo guard) is settled and lives in `C:\Users\mikea\Documents\Git_Proj\AI_dev_pipeline` (`AI_dev_pipeline.md`, `pipeline/bakeoff/STATUS.md`). Do not re-litigate it here; the pilot only adds real-task cost data.

### Measuring Claude tokens
- Claude Code session transcripts (`%USERPROFILE%\.claude\projects\<project>\<session>.jsonl`) carry a `usage` block per reply: `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`. Sum them per session, de-duplicating by message id (a reply can be written more than once while streaming).
- **Step 0 (do before task 1):** write `pipeline/pilot/claude_cost.py` in the AI_dev_pipeline repo: input = session id(s), output = the four sums plus one weighted number (approximate API-price equivalents: cache read 0.1x, cache write 1.25-2x, uncached input 1x, output 5x). Report the raw sums too; the weighted figure is a proxy, not what the plan quota actually counts.
- **One fresh Claude Code session per phase** so attribution is trivial: `P` (spec + packet + acceptance test), `R` (review of the verified diff + doc sync), `E` (escalation, only if the worker fails), `D` (the direct baseline, below). Name each session `T-NNN-<phase>`. Do not mix other work into those sessions.
- Worker cost is local and free; record it only as wall-clock and Zoo request counts (`zoo_check.py score` prints them).

### The comparison (paired baseline)
- **Pipeline cost** = `P + R + E`. **Baseline** = `D`: the same task done directly by Claude Code from the same base commit, in a fresh session with the prompt a user would give ("implement X per <spec>"), on a throwaway branch that is discarded afterwards.
- Run the baseline **for the first two tasks only** (a real measurement, not an estimate). For later tasks, estimate `D` from the two measured ratios and mark it "estimated".
- Do the pipeline run first, then the baseline, and keep the packet text out of the baseline session, so neither arm benefits from the other.
- Report per task: `P`, `R`, `E`, `D`, ratio `(P+R+E)/D`, authenticated result (first-pass PASS, PASS after worker retries, escalated, or STOP), worker wall-clock, worker verify rounds, and what Claude had to change in the diff.
- Doc sync (CLAUDE.md "Doc sync") is Claude's job in both arms; count it in `R` for the pipeline and in `D` for the baseline so it cancels out.

### Task selection (small: one or two files, objective test)
Candidates from the trajectory above:
1. **Roster-level all-frames p95 in `tools/measure_nav_cost.gd`** (D30; one tool file; acceptance = the tool prints the new metric and a headless run exits 0). Well specified, no design questions.
2. **A small Phase 1 nav task** from `NAVIGATION_PASSABILITY_PLAN.md` section 8.2 (T0a-T11, T6b) touching one or two files, with a test Claude can write up front. Pick the smallest.
3. **Break-even probe:** the unused `_delta` removal in `_is_within_eat_range`. Expected result: packet cost exceeds direct cost. Run it once to see where the floor is.

Avoid for the pilot: investigations (C9 ping-pong), anything with an open design question or an "ASK before touching" flag (fox test-peg values), multi-system changes, and tasks whose "done" cannot be a test or a measurable tool output. Per the ambiguity protocol, if a requirement is unclear at packet time, ask the user; that conversation counts in `P`.

### One-time setup in this repo (before task 1)
1. Confirm the suite is green at the base: `godot --path . --headless -s res://tests/run_all.gd` exit 0 and `python tools/check_gdscript_no_tabs.py` exit 0. Commit or stash the three untracked `.gd.uid` files so the tree is clean.
2. Add `pipeline/verify/verify.py` (the worker's retry loop runs `python pipeline/verify/verify.py --repo . --packet tasks/T-NNN.md --fast`, the one command on Zoo's allowlist), `pipeline/GDSCRIPT4_RULES.md` and `pipeline/WORKER_RULES.md` (copy all three from `AI_dev_pipeline/pipeline/`), a `tasks/` folder, and `.pipeline/` to `.gitignore`. Commit these before taking the base sha. `verify` protects `pipeline/ tasks/ .pipeline/` by default, so the worker cannot edit them.
3. Work on a branch `task/T-NNN` from the current branch head; the base sha goes in the packet. Do not edit the repo yourself while Zoo runs on it.
4. Zoo (window opened on this repo): provider Ollama, model `hk-worker` (now `qwen3.6:27b`), context 49152, temperature 0.6, thinking on, todo tool on. Settings > Auto-Approve > Execute: execute on, destructive command guard **off**, "Auto-deny unapproved commands" on; the allow/deny lists are already in the user `settings.json`. Approve reads and edits by hand; nothing else should prompt.
5. Authenticate with the AI_dev_pipeline copy, not the repo copy: `python <AI_dev_pipeline>\pipeline\verify\verify.py --repo . --packet tasks/T-NNN.md` (full suite, no `--fast`).

### Per-task procedure
1. Session `T-NNN-P`: spec check, then the packet from the template (`AI_dev_pipeline.md` section 5): goal, non-goals, scope toml (functions where possible, `max_changed_lines`), a `[[premise]]` for every "already exists" claim, exact line ranges to read, and an acceptance test written by Claude. Validate the packet before the worker sees it: `verify` at base reports NO_CHANGE and the acceptance script fails for the right reason.
2. Worker: in Zoo, "Do the task in tasks/T-NNN.md." Note start and end time. Stop it at the retry cap; do not coach it.
3. Authenticate (setup step 5). Only a script PASS counts.
4. Session `T-NNN-R`: give Claude only the packet, the diff and the receipt. Ask for a review against the packet, not a re-derivation. Doc sync happens here.
5. If the worker failed or the diff needs real changes, session `T-NNN-E` does the fix; record why (bad packet, worker error, spec flaw).
6. Baseline session `T-NNN-D` (tasks 1-2 only), then discard its branch.
7. Run `claude_cost.py` for each session; add a row to `AI_dev_pipeline/pipeline/pilot/RUN_LOG.md` (with the `zoo_check.py score` output) and a short note on what surprised you.

### Decision rules (set now, so the result is not argued afterwards)
- **Saves tokens:** across the pilot tasks, total `P+R+E` is clearly below total `D` (target: ratio <= 0.5 on tasks that finish without escalation; the ratio including escalations must still be below 1).
- **Reliable enough:** at least 2 of the first 3 real tasks authenticate without Claude rewriting the worker's code. A STOP caused by a wrong packet counts against packet quality, not the worker.
- **If the ratio is poor, find the dominant term.** Large `P`: the packet template or spec reading is too heavy (shrink packets, reuse acceptance-test patterns). Large `R`: Claude is reviewing more than the diff. Large `E`: task selection or a worker limit (record the failure mode).
- **Break-even:** after 3-4 tasks, write down the smallest task size (changed lines, files) where the ratio drops below 1. Below it, Claude just does the work directly.
- **Stop the pilot early** if two tasks in a row need escalation: fix the cause before spending more tokens.

### Not covered by the bake-off; watch for these
Thinking-off on false-premise tasks (not used here), Zoo's handling of an Ollama HTTP 500 (malformed tool-call XML, about 3 in 20 trials in the harness), Zoo's Godot language-server "problems" feedback after edits (absent from the harness), a larger real codebase than the pilot snapshot, and `apply_diff` loops that run to the context limit. Record any of these in RUN_LOG.md when they occur.
