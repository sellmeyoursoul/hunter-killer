# Pilot log

One row per finished phase, appended by Claude (PILOT.md, phase rule 4). Tokens come from `claude_cost.py`; weighted is a proxy (see the script).

| Date | Task | Phase | Session id | Replies | Input | Cache read | Cache write (5m+1h) | Output | Weighted | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 2026-10-12 | T-001 | P | 9eb21c93-663c-4585-8541-79f2690b87f6 | 16 | 32 | 1048107 | 0 + 60942 | 13535 | 294402 | Packet + acceptance test (helper unit asserts + headless tool run); validated at base (NO_CHANGE, test fails on 2 asserts); reference impl (40 lines) passed then reverted. Snapshot taken before this row; branch task/T-001, tag task-T-001-base = 9875a7c. |

**T-001 worker run (Zoo, not a Claude phase):** 28 requests, about 692 s wall, authenticated PASS (full verify, 9/9, 51 lines). The verify loop was human-relayed because Zoo's allowed-commands list lacked the verify command; see `AI_dev_pipeline/pipeline/bakeoff/STATUS.md`, "Pilot T-001". Phase R still pending.
