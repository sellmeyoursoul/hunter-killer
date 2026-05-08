# Logging & sensitive data (oLog / game output)

- **PII & secrets:** Do not log personally identifiable information, credentials, API keys, session tokens, or secrets. If diagnostic output might include paths, redact usernames in home-directory paths when feasible.
- **Volume:** Do not log huge payloads (full model prompts, entire perception grids, raw binary). Prefer short summaries, counts, or bounded excerpts; large debug blobs belong behind explicit dev-only flags and truncation.
- **Line length:** Treat **`MAX_LOG_LINE_CHARS`** (default **2048** characters per logical line of user-visible message text) as a soft cap in implementation; truncate long strings with a suffix such as ` [truncated]` rather than writing megabytes to disk.
