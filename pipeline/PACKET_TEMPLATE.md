# Packet template and toml reference

For phase P. Copy the skeleton, fill it, validate with `verify` at the base (expect `NO_CHANGE`, acceptance fails only on the new code). Do not read `verify.py` to learn the format; this file is the reference. Worked example: `tasks/T-002.md` in the replay repo (the repaired packet). Rules behind the budget and read sections: `AI_dev_pipeline/pipeline/pilot/PACKET_LESSONS.md`. Test fixtures: `pipeline/TEST_FIXTURES.md` (hunter-killer).

## Toml block (machine-read; keep exact syntax, one block per packet, first ```toml fence)
```toml
id = "T-NNN"                       # required
title = "<short title>"            # shown in the receipt
base = "<sha>"                     # optional; default HEAD; --base overrides

[scope]                            # required table
edit = [                           # files the worker may modify (status M only: no deletes, renames, adds)
  { path = "creature/x.gd", functions = ["f", "g"] },   # functions optional: if present, every changed line must fall in one of them
]
add = []                           # new files allowed, by exact path
protected = []                     # extra protected paths, prefix match; defaults always apply (below)
max_changed_lines = 120            # added + removed, whole diff; default 100
test_scripts = ["res://tests/pipeline/test_tNNN.gd"]   # acceptance scripts, run before the full suite; exit 0 = pass

[[premise]]                        # repeatable; every "already exists" claim in the packet
path = "creature/x.gd"
contains = "static func f("        # exact substring of the file at the base commit (watch quotes and escapes)
note = "what the packet claims"    # shown if false
```
Defaults always protected: `tests/ project.godot addons/ .godot/ pipeline/ tasks/ .git/ .pipeline/`. So acceptance tests go in `tests/pipeline/` and are committed with the packet; the worker cannot edit them.

## What the function scope means
- A "function" is a top-level `func` / `static func` (the doc-comment block directly above it belongs to it). Everything else (consts, preloads, `var`s, other top-level lines) belongs to the pseudo-function `<top-level>`; whitespace-only changes are ignored. A new function must be listed by name too. If the worker legitimately needs a top-level line (e.g. a new `const`), list `"<top-level>"` for that file or the gate fails.
- Leading tabs are converted to 2 spaces automatically; a tab anywhere else fails `tab-gate`.
- The line cap counts every added and removed line in all edited files (a replaced line counts twice). Budget about 2x the net new lines when editing existing lines.

## Packet skeleton
```markdown
# T-NNN: <title>
Spec: <path#section> (do not open unless this packet is ambiguous). Language rules: pipeline/GDSCRIPT4_RULES.md.

## Goal
<2-4 sentences. For every choice among several items (largest/smallest/first/any/all), state which and why (worst case for whom).>

## Non-goals
- <files, call sites, features the worker must not touch>

## Scope
<toml block above>

## Contract
<numbered items: exact signatures, behavior, defaults, config keys; each says where it goes>

## Reads (context window 49k; planned reads total ~N tokens, limit 20k)
| # | read_file call | lines | ~tokens | why |
|---|---|---|---|---|
| 1 | path="creature/x.gd", offset=1, limit=112 | 112 | 1.7k | <why> |
(offsets are first lines, limits are line counts; every range stops at a function boundary; never call read_file without offset and limit on a file over 150 lines)

## Do not open
- <file>: <one-line reason>   (always: the acceptance test, the spec doc, big config files)

## What the acceptance test checks (one line each; do not open the test)
| assertion (as printed) | if it fails, check |
|---|---|
| "<text>" | <function / value / call site to look at> |

## Acceptance
- `tests/pipeline/test_tNNN.gd` must exit 0 (PRE assertions already pass at the base). `tests/run_all.gd` must stay green (verify runs it).
- Gate: `python pipeline/verify/verify.py --repo . --packet tasks/T-NNN.md --fast`

## Limits
- Max 3 gate retries, then stop and report. Do not modify tests. 2-space indentation, never tabs.
- Do not re-read a range already read; edit one function per apply_diff and run the gate after each file.
- If a file or range is missing, stop and report; do not search for a packet or spec.
- Finish: when the full verify (the command without `--fast`) prints `RESULT: PASS`, your very next action is the completion tool (`attempt_completion`) with a two-line summary. After a PASS do not re-read files or run anything else: the context window is nearly full by then.
```

## P checklist (tick before committing the packet)
1. Every "already exists" claim has a `[[premise]]`.
2. Planned reads sum to 20k tokens or fewer (characters / 3.5; use `wc -c` on the ranges).
3. A "do not open" list and an assertion table with failure hints exist.
4. The acceptance test has a case where each multi-item choice (min/max/first) gives a different answer.
5. The test passes against a reference solution (apply it, run the script, revert), and every fixture value comes from the same call the code under test uses, read after any `await`.
6. `verify --fast` at base reports `NO_CHANGE` and the acceptance script fails only on the new code.
7. `max_changed_lines` is about 1.3x the reference diff; ask for no more than about 100 changed lines for a 49k window (split larger tasks).
8. Log the phase with `pilot_log.py` (one reply).

## Worker profile (Zoo)
Todo tool OFF. With it on, eight todo updates cost about 5k tokens per run, and with the closing line above they were the difference between runs that ended with the window full and runs that finished with 1-9k to spare (T-002 bench, 2026-10-13: peaks 48.9-49.1k before, 40.3-47.8k after). The worker may still skip the full verify before completing, so Claude's authentication step (`verify.py` without `--fast`) is always run separately.
