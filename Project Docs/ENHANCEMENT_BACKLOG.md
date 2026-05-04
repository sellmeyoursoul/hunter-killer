# Enhancement backlog

Informal parking lot for improvements **not** committed in phase design docs. Priority is rough (**Low** / **Medium** / **High**).

---

## oLog (logging library)

| Item | Priority | Notes |
|------|----------|--------|
| Structured fields (`key=value` or JSON fragments in messages) | Medium | Easier grep and tooling than prose-only lines |
| Rate limiting per callsite / subsystem | Medium | Complements ring eviction; caps repetitive spam |
| Child loggers / fixed subsystem prefix | Medium | e.g. `OLog.child("AI")` prepends tag without passing each time |
| Deterministic `user://` root for automated tests (CI / headless) | Medium | Stable paths under Godot test harness |
| Editor-only or `logging_params.enabled` gate for shipped builds | Medium | Optional once shipping matters |
| Mirror selected levels to remote sink (HTTP, file rotation) | Medium | Out of scope for current file-only design |

---

## Other

*(None yet.)*
