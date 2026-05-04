# AI & tooling instructions — hub

This file is the **entry point** for context-specific guidance. **General project rules** remain in [`.cursor/rules/instructions.md`](../.cursor/rules/instructions.md).

## Spokes (add / split over time)

| Topic | Document | Status |
|-------|----------|--------|
| General agent behavior, formatting, comments, tests | [`instructions.md`](../.cursor/rules/instructions.md) | Canonical |
| Logging (`oLog`), PII, message size | [`instructions.md`](../.cursor/rules/instructions.md) — *Logging & sensitive data* | Active |
| AI integration (TinyLlama, perception contract) | [`DtC_AI_INT_PLAN.md`](DtC_AI_INT_PLAN.md) | Active |
| Deferred splits | *(none yet)* | Future |

When instructions grow large, move a vertical slice from `instructions.md` into a new spoke file and link it here—keep **one canonical rule** per concern to avoid drift.
