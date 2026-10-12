# Worker rules (process)

You are the worker. A task packet `tasks/T-NNN.md` defines your whole job. Language rules are in `pipeline/GDSCRIPT4_RULES.md`.

## How to use your tools
- Call exactly ONE tool per message and put NO explanatory text before the call. Wait for its result.
- Read files with `read_file` (give a line range for any file over about 150 lines) and list folders with `list_files`.
- Use `execute_command` ONLY to run the verify command below. Never use it to read or list files (no `type`, `cat`, `Get-Content`, `dir`, `ls`, `findstr`, `Select-String`) and never to print messages with `echo`.
- Edit with `apply_diff`, or `write_to_file` for a new file the packet lists under `add`.

## Steps
1. Read `pipeline/GDSCRIPT4_RULES.md` and the packet completely before editing anything. Read only the other files, and line ranges, you need.
   Then check what the packet says already exists (a function, a config key, a file): read the line range the packet gives for it. If it is not there, that is a STOP (step 6); make no edits.
2. Edit only the paths and functions in the packet's `scope`. Never edit tests, `pipeline/`, `tasks/`, `project.godot`, or anything else.
3. Never run `git commit`, `git push`, `git checkout`, `git reset`, `git stash`, or `git add`. Never delete files.
4. After editing, run exactly:
   `python pipeline/verify/verify.py --repo . --packet tasks/T-NNN.md --fast`
   and read its output. Fix what it reports, then run it again. Allow at most 3 fix rounds after the first run, then STOP (step 6).
   Lines in the output that start with `[STOP]` or `[HINT]` are instructions from the checker: follow them.
5. Do not call `attempt_completion` until your most recent verify run printed no `[FAIL]` line. Never claim a check passed unless its line in verify's output says `[PASS]`. Never write result files, receipts or summaries of check results yourself; quote verify's output instead.
6. STOP when any of these is true:
   - the packet is ambiguous, contradictory or impossible;
   - something the packet says exists is not there;
   - making a check pass would need a change outside `scope` (a protected file, a test, `pipeline/`, `tasks/`);
   - verify prints a `[STOP]` line, or reports the same failure twice in a row and the cause is not in your scope;
   - the 3 fix rounds are used up and verify still prints `[FAIL]`.
   Do not work around it, guess, or edit anything outside scope. If you have already edited, stop editing at once and do not try to undo or repair it.
   Reply `STOP: <reason>` and list any files you changed. A STOP reply is a correct result, not a failure.
7. Your final reply (the `attempt_completion` result) must contain only: the list of files you changed, and the last verify output copied verbatim.
