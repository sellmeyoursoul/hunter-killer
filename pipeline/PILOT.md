# Pilot: local-worker pipeline on real tasks (next 2-4 tasks)

**Question to answer:** does the architect/worker pipeline (Claude writes a packet and reviews a verified diff; local `qwen3.6:27b` in Zoo Code does the editing; `verify.py` authenticates) cost fewer Claude tokens than Claude doing the same task directly, and by how much? Everything about the pipeline itself (bake-off, verify, Zoo guard) is settled and lives in `C:\Users\mikea\Documents\Git_Proj\AI_dev_pipeline` (`AI_dev_pipeline.md`, `pipeline/bakeoff/STATUS.md`). Do not re-litigate it here; the pilot only adds real-task cost data.

## Phase rules for Claude (read this at the start of every pilot session)
Applies to any session whose task involves the pilot pipeline, however it was started (`/go` or not).
1. **Ask first:** which task (T-NNN) and which phase: `P` (packet), `R` (review), `E` (escalation) or `D` (direct baseline)? Do not guess. If this session already did a different phase for the same task, say so and ask the user to open a fresh session: phases must not share a session, because carried-over cache reads would distort the cost comparison.
2. **Stay in the phase.**
   - `P`: spec, packet, acceptance test, validation at base. Do not implement.
   - `R`: review the diff against the packet using the receipt; doc sync. Do not re-derive the solution.
   - `E`: fix what the worker could not, and record why (bad packet, worker error, spec flaw).
   - `D`: implement directly from the same starting prompt a user would give. Never read the packet or the worker's diff. The branch is discarded afterwards.
3. **Do not run `/stop`** in a P, R or E session (it overwrites `chat_sum.md`, stages everything, commits and pushes). Leave the handoff to the user.
4. **At the end of the phase, log it with the script** (one reply, no hand-written row). From this repo's root:
   `python -I -X utf8 C:\Users\mikea\Documents\Git_Proj\AI_dev_pipeline\pipeline\pilot\pilot_log.py add T-NNN <phase> --note "one line" [--tag NAME] [--session ID]`
   It sums the newest transcript of this repo's project folder (pass `--session` if two sessions of this repo are open). Rows are snapshots; `pilot_log.py refresh` re-sums them all later. Phases used so far: `P`, `P2`/`P3` (packet or test repairs), `R`, `E`, `D`.
5. Never edit `tasks/` packets after the worker has started.

## Measuring Claude tokens
- Claude Code session transcripts (`%USERPROFILE%\.claude\projects\<project>\<session>.jsonl`) carry a `usage` block per reply: `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`, `output_tokens`. `claude_cost.py` (AI_dev_pipeline repo, `pipeline/pilot/`, built 2026-10-12) sums them per session, once per message id, and prints a weighted proxy (cache read 0.1x, cache write 1.25-2x, uncached input 1x, output 5x). The weighted figure is a proxy, not what the plan quota counts; compare ratios and read the raw columns too.
- **One fresh Claude Code session per phase**, opened in this repo, so attribution is trivial. Claude records each session's id and totals in `pipeline/PILOT_LOG.md` (phase rule 4). Do not mix other work into those sessions.
- Worker cost is local and free; record it only as wall-clock and Zoo request counts (`zoo_check.py score` prints them).

## The comparison (paired baseline)
- **Pipeline cost** = `P + R + E`. **Baseline** = `D`: the same task done directly by Claude Code from the same base commit, in a fresh session, on a throwaway branch that is discarded afterwards.
- Run the baseline **for the first two tasks only** (a real measurement, not an estimate). For later tasks, estimate `D` from the two measured ratios and mark it "estimated".
- Do the pipeline run first, then the baseline, and keep the packet text out of the baseline session, so neither arm benefits from the other.
- Report per task: `P`, `R`, `E`, `D`, ratio `(P+R+E)/D`, authenticated result (first-pass PASS, PASS after worker retries, escalated, or STOP), worker wall-clock, worker verify rounds, and what Claude had to change in the diff.
- Doc sync (CLAUDE.md "Doc sync") is Claude's job in both arms; count it in `R` for the pipeline and in `D` for the baseline so it cancels out.

## Task selection (small: one or two files, objective test)
Candidates:
1. **Roster-level all-frames p95 in `tools/measure_nav_cost.gd`** (D30; one tool file; acceptance = the tool prints the new metric and a headless run exits 0). Well specified, no design questions.
2. **A small Phase 1 nav task** from `NAVIGATION_PASSABILITY_PLAN.md` section 8.2 (T0a-T11, T6b) touching one or two files, with a test Claude can write up front. Pick the smallest.
3. **Break-even probe:** the unused `_delta` removal in `_is_within_eat_range`. Expected result: packet cost exceeds direct cost. Run it once to see where the floor is.

Avoid for the pilot: investigations (C9 ping-pong), anything with an open design question or an "ASK before touching" flag (fox test-peg values), multi-system changes, and tasks whose "done" cannot be a test or a measurable tool output. Per the ambiguity protocol, if a requirement is unclear at packet time, ask the user; that conversation counts in `P`.

## One-time setup in this repo
Done 2026-10-12 (commit 054b0e1): suite and tab check green at the base; `pipeline/verify/verify.py`, `pipeline/GDSCRIPT4_RULES.md`, `pipeline/WORKER_RULES.md`, `tasks/` and the `.pipeline/` ignore line added. `verify` protects `pipeline/ tasks/ .pipeline/` by default, so the worker cannot edit them. Still true for every task:
1. Work on a branch `task/T-NNN` from the current branch head; the base sha goes in the packet. Do not edit the repo yourself while Zoo runs on it.
2. Zoo (window opened on this repo): provider Ollama, base URL `http://localhost:11434`, model `hk-worker` (now `qwen3.6:27b`), context 49152, temperature 0.6, thinking on, todo tool on, Code mode. Settings > Auto-Approve > Execute: execute on, destructive command guard **off**, "Auto-deny unapproved commands" on; the allow/deny lists are in the user `settings.json`. Approve reads and edits by hand; nothing else should prompt. **Before every task, open Settings > Auto-Approve > Execute and confirm the allowed-commands list contains `python pipeline/verify/verify.py` (and the denied list is intact).** Zoo uses its own saved list, not `settings.json`; on T-001 it had lost the entry, every verify attempt was refused, and the human had to relay the output. If the worker ever asks you to run verify for it, stop: that is a setup defect; fix the list, reset the repo to the base and re-run, or record the run as human-relayed. (First-request check done 2026-10-12: temperature 0.6, `think: 'medium'`, `num_ctx` 49152, 13 tools, ~10.5k-token first prompt.)
3. Authenticate with the AI_dev_pipeline copy, not the repo copy: `python C:\Users\mikea\Documents\Git_Proj\AI_dev_pipeline\pipeline\verify\verify.py --repo . --packet tasks/T-NNN.md` (full suite, no `--fast`).

## Per-task procedure
1. Phase `P`: read `pipeline/PACKET_TEMPLATE.md` (toml reference, packet skeleton, P checklist) and `pipeline/TEST_FIXTURES.md` (copy-paste test helpers and pitfalls) first; do not read `verify.py` or study `tests/run_all.gd`. Lessons behind them: `AI_dev_pipeline/pipeline/pilot/PACKET_LESSONS.md`. Spec check, then the packet from the template (`AI_dev_pipeline.md` section 5): goal, non-goals, scope toml (functions where possible, `max_changed_lines`), a `[[premise]]` for every "already exists" claim, exact line ranges to read, and an acceptance test written by Claude. Validate the packet before the worker sees it: `verify` at base reports NO_CHANGE and the acceptance script fails for the right reason, **and the acceptance script passes against a reference solution (apply, run, revert)**. Keep planned reads under 20k tokens (Zoo's window is 49k) and tasks under about 100 changed lines; the acceptance test needs a discriminating case for every largest/smallest/first-of-many choice (`PACKET_LESSONS.md` rules 9-16).
2. Worker: in Zoo, "Do the task in tasks/T-NNN.md." Note start and end time. Stop it at the retry cap; do not coach it.
3. Authenticate (setup step 3). Only a script PASS counts.
4. Phase `R`: give Claude only the packet, the diff and the receipt. Ask for a review against the packet, not a re-derivation. Doc sync happens here.
5. If the worker failed or the diff needs real changes, phase `E` does the fix; record why.
6. Phase `D` (tasks 1-2 only), then discard its branch.
7. After each phase Claude logs it (phase rule 4). When the task is done, score the Zoo run with `zoo_check.py score` and add a row to `AI_dev_pipeline/pipeline/pilot/RUN_LOG.md` with a short note on what surprised you.

## Decision rules (set now, so the result is not argued afterwards)
- **Saves tokens:** across the pilot tasks, total `P+R+E` is clearly below total `D` (target: ratio <= 0.5 on tasks that finish without escalation; the ratio including escalations must still be below 1).
- **Reliable enough:** at least 2 of the first 3 real tasks authenticate without Claude rewriting the worker's code. A STOP caused by a wrong packet counts against packet quality, not the worker.
- **If the ratio is poor, find the dominant term.** Large `P`: the packet template or spec reading is too heavy (shrink packets, reuse acceptance-test patterns). Large `R`: Claude is reviewing more than the diff. Large `E`: task selection or a worker limit (record the failure mode).
- **Break-even:** after 3-4 tasks, write down the smallest task size (changed lines, files) where the ratio drops below 1. Below it, Claude just does the work directly.
- **Stop the pilot early** if two tasks in a row need escalation: fix the cause before spending more tokens.

## Not covered by the bake-off; watch for these
Thinking-off on false-premise tasks (not used here), Zoo's handling of an Ollama HTTP 500 (malformed tool-call XML, about 3 in 20 trials in the harness), Zoo's Godot language-server "problems" feedback after edits (absent from the harness), a larger real codebase than the pilot snapshot, and `apply_diff` loops that run to the context limit. Record any of these in `RUN_LOG.md` when they occur.

## Cleanup when the pilot is over
Do this once the decision rules above have been applied and the result is written up in `AI_dev_pipeline/pipeline/pilot/RUN_LOG.md`.
1. **Update the default `CLAUDE.md`.** Remove the "Pilot pipeline (temporary)" line under Behavioral instructions. If the pipeline is adopted, replace it with a short permanent entry instead: when a task is suited to the worker (size and break-even from the write-up), write a packet per `AI_dev_pipeline.md` section 5, run the worker, authenticate with `verify`, and review only the verified diff; keep a one-line path to the packet template and the rules files. If it is not adopted, just remove the line. Either way, `CLAUDE.md` must no longer ask for phase rules or `PILOT.md`.
2. **Update this file:** change the title to "Pilot (finished <date>): <one-line result>" and keep it as the record, or move it to `Project_Docs/Completed_Features/` and register that in `PROJECT_DOC_INDEX.md` per the repo's doc rules.
3. **Remove the "Pilot in progress" paragraph from `chat_sum.md`** (it is kept alive across `/stop` rewrites only while the pilot runs).
4. **Summarise `pipeline/PILOT_LOG.md`** into the AI_dev_pipeline `RUN_LOG.md` (one row per task: P, R, E, D, ratio, result), then keep or delete the log.
5. Decide whether `pipeline/`, `tasks/` and the `.pipeline/` ignore line stay in the repo (they do if the pipeline is adopted).
6. Commit with a message naming the pilot result.
