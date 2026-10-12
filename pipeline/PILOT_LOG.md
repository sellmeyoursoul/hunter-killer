# Pilot log

One row per finished phase, appended by Claude (PILOT.md, phase rule 4). Tokens come from `claude_cost.py`; weighted is a proxy (see the script).

| Date | Task | Phase | Session id | Replies | Input | Cache read | Cache write (5m+1h) | Output | Weighted | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-10-12 | T-001 | P | 9eb21c93-663c-4585-8541-79f2690b87f6 | 19 | 38 | 1312660 | 0 + 62217 | 15427 | 332873 | Packet + acceptance test (helper unit asserts + headless tool run); validated at base (NO_CHANGE, test fails on 2 asserts); reference impl (40 lines) passed then reverted. Totals refreshed after the session ended (the first snapshot was taken before the row was written); branch task/T-001, tag task-T-001-base = 9875a7c. |
| 2026-10-12 | T-001 | R | 2e1305e7-dc3f-4396-969d-01b111661cd2 | 10 | 20 | 572870 | 0 + 37008 | 3531 | 148978 | Reviewed 51-line diff vs contract: no changes needed (placement, sort-copy nearest rank, print format, loop order all match). Doc sync: one sentence in NAVIGATION_PASSABILITY_PLAN.md tool inventory. Totals refreshed after the session ended. |

**T-001 worker run (Zoo, not a Claude phase):** 28 requests, about 692 s wall, authenticated PASS (full verify, 9/9, 51 lines). The verify loop was human-relayed because Zoo's allowed-commands list lacked the verify command; see `AI_dev_pipeline/pipeline/bakeoff/STATUS.md`, "Pilot T-001".
