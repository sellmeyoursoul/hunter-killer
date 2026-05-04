# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** Output Logging Library (oLog)

**One-line objective:** Define a logging class for game output including Error, Debug, and Info levels.

This phase targets **early implementation** while building gameplay and AI features—**not** a shipped product polish pass. Keep behavior simple; defer shipping-only gates (e.g. disabling file I/O in release) unless needed later.

**Related:** TinyLlama **“thinking” / verbose reasoning** stays **terminal-only** per [`DtC_AI_INT_PLAN.md`](DtC_AI_INT_PLAN.md) Nice-to-have until verbosity is understood—**do not** route that stream into **`OLog`** yet (avoids accidental huge log files).

**Out of scope (explicit non-goals):** Anything not involving logging.

---

## 2. Context for agents

**Repo / project root:** `C:\Users\mikea\Documents\Git Proj\dodge-the-creeps` (authoritative for this repository clone; adjust `{projectHome}` if you open a copy elsewhere).

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** N/A

**Key scripts (paths):**  
    A. `{projectHome}/project.godot` — register **Autoload** singleton **`OLog`** **first in the Autoload list** (see §4).  
    B. `{projectHome}/oLog_lib/olog.gd` — **`OLog`** implementation (ring buffer, config load, file I/O, public API).  
    **Runtime data (not under `{projectHome}` in repo):** `user://config.json` (JSON config the game reads per §4.3).

**Instruction hub:** [`AI_INSTRUCTIONS.md`](AI_INSTRUCTIONS.md) links general rules + spokes; logging hygiene (PII, max line length) is also in [`../.cursor/rules/instructions.md`](../.cursor/rules/instructions.md).

---

**Existing patterns to follow:** (naming, signals, groups, layers, file layout)  
    **formatting**  
    A. Follow [`../.cursor/rules/instructions.md`](../.cursor/rules/instructions.md), including **Logging & sensitive data**.  
    B. Comment every function touched per that file.  
    c. Same root names across files; use `_descriptor` when differentiating (e.g. `mobVariable_gd`).

---

## 3. Requirements

### Must have

    A. Write a **`.log`** file under **`user://logs/`** (filename §4.3). Writable at runtime (development tooling).
    B. Read **`user://config.json`** at **`OLog`** startup (`_ready`). Non-logging keys may appear later; **`OLog`** reads only **`logging_params`** this phase. **`OLog`** is a **`project.godot` Autoload**, not constructed by `main.gd`.
    C. Three APIs (**§4.4**, §4.3):
        i. **`error(...)`** — always enqueued (**never** filtered by **`LOG_LEVEL`**).
        ii. **`info(...)`** — enqueued only when **`LOG_LEVEL`** is **`Info`** or **`Debug`**.
        iii. **`debug(...)`** — enqueued only when **`LOG_LEVEL`** is **`Debug`**.
    D. Missing/unreadable **`user://config.json`** → Error-only behavior + clear diagnostic (§4.3 fallbacks).

### Should have

    A. Primary log line format (single logical message): `"[timestamp dd-mm-yyyy HH:MM:SS:mmmm UTC] | [LEVEL] | [source_tag] | [text]"` — **four-digit milliseconds**, **UTC** label matches actual UTC formatting (§4.4).
    B. **One-line messages:** normalize embedded newlines in **`[text]`** to spaces (or `\n` → space) so each primary line is one row—**except** optional stack traces (Nice-to-have A).
    C. Thread-safe single entry path (§4.1–§4.2).
    D. Crash-safe: logging must not become a failure path; **flush after each written line** to the file.

### Nice to have

    A. Optional stack capture below the primary line: **each stack frame on its own line** for readability (continuation format §4.4). Stacks are **never** implicit—caller opts in.

---

## 4. Technical design

### Architecture / data flow

1. **`project.godot` → Autoloads:** Register **`OLog`** **first** (top of the Autoload list) pointing at **`res://oLog_lib/olog.gd`**. Ensures **`OLog._ready`** runs before other autoloads and most game **`_ready`** hooks so early errors can be queued or mirrored.
2. **`OLog._ready`:** ensure **`user://logs/`**; load **`user://config.json`** (§4.3); open log file; allocate ring using **`MAX_QUEUE_ENTRIES`**.
3. Callers invoke **`OLog.error` / `info` / `debug`** (§4.4 overloads). **Filter before enqueue** (§4.3).
4. **`OLog._process`** drains (§4.2), formats (§4.4), writes **`user://logs/…`**, flushes per line.
5. Shutdown: drain all + flush (§4.2).

### 4.1 Queue & payload (thread-safe path)

Producers enqueue; **main thread** formats and writes (§4.2).

**Record shape**

| Field | Type / notes |
|-------|----------------|
| `unix_time` | `float` — **`Time.get_unix_time_from_system()`** at **enqueue** (ordering + §4.4 timestamp formatting). |
| `level` | Enum — `ERROR`, `INFO`, `DEBUG`. |
| `source_tag` | `String` — caller-supplied label for subsystem / thread role (§4.4). |
| `message` | `String` — raw text without prefix; **single-line** per §3 Should-have B. |
| `stack` | `String`, optional — non-empty only when caller requests stack capture; **multi-line** allowed (frame per line). |

**String building** — Final line(s) built **on drain**. Primary line: §3 Should-have A. Continuation lines (stack): §4.4.

**Bounded ring** — §4.2. **`MAX_QUEUE_ENTRIES`** from config (§4.3).

### 4.2 Mutex, drain, overflow

**Mutex** — Protects ring metadata; **do not** hold during file I/O.

**Drain** — **`_process`** drains up to **`MAX_LINES_PER_PROCESS`** (§4.3). Flush each line.

**Shutdown** — Full drain + flush; bounded by ring size.

**Overflow / eviction** — Tier order:

| Tier (evict first → last) | Level |
|---------------------------|--------|
| 1 | **INFO** |
| 2 | **DEBUG** |
| 3 | **ERROR** (last resort) |

**Within tier:** evict **newest** first (highest enqueue **`unix_time`**; tie-break with monotonic enqueue sequence id).

**Rationale (intentional):** When **`LOG_LEVEL`** is **`Debug`**, **DEBUG** lines are the **primary** diagnostic payload—so under pressure **INFO** is sacrificed before **DEBUG**. Revisit after implementation if field experience disagrees.

**Counters** — `drops_info_total`, `drops_debug_total`, `drops_errors_total`.

### 4.3 Configuration (`user://config.json`)

**Location:** Always **`user://config.json`**. Not in git; other top-level keys allowed for other systems.

**`logging_params` object**

| Key | Type | Meaning |
|-----|------|---------|
| `LOG_LEVEL` | `String` | Non-**`error()`** gating. Case-insensitive: **`Error`**, **`Info`**, **`Debug`**. |
| `MAX_LINES_PER_PROCESS` | `int` | Max records drained per **`_process`**. |
| `MAX_QUEUE_ENTRIES` | `int` | Ring capacity. |

**`LOG_LEVEL` filter (before enqueue)**

| Config | `error()` | `info()` | `debug()` |
|--------|-----------|----------|-----------|
| `Error` | enqueue | drop | drop |
| `Info` | enqueue | enqueue | drop |
| `Debug` | enqueue | enqueue | enqueue |

**`error()`** is not filtered by **`LOG_LEVEL`**.

**Fallbacks**

| Situation | Behavior |
|-----------|----------|
| Missing/unreadable file | **Error**-only effective level; **`MAX_LINES_PER_PROCESS=128`**; **`MAX_QUEUE_ENTRIES=1024`**; **`push_error`** until **`OLog`** exists |
| Missing **`logging_params`** | Same defaults |
| Invalid **`LOG_LEVEL`** | **`Error`** |
| **`MAX_LINES_PER_PROCESS` ≤ 0 / missing** | **128** |
| **`MAX_QUEUE_ENTRIES` ≤ 0 / missing** | **1024** |

Do **not** auto-write **`user://config.json`** this phase.

**Log path:** **`user://logs/<log_basename>.log`** — slugify **`application/config/name`** (non-alphanumeric → `_`, lower case). **`DirAccess.make_dir_recursive("user://logs")`** before open.

**Sample**

```json
{
  "logging_params": {
    "LOG_LEVEL": "Error",
    "MAX_LINES_PER_PROCESS": 128,
    "MAX_QUEUE_ENTRIES": 1024
  }
}
```

### 4.4 Timestamps, line format, source tags, editor mirror

**UTC timestamps:** Build calendar fields from **`Time.get_datetime_dict_from_unix_time(unix_time, true)`** so the stamped text matches **UTC** in §3 Should-have A. Derive **four-digit milliseconds** from the fractional part of **`unix_time`** (or equivalent—same instant as dict). *Rationale:* cleaner than ad-hoc epoch math while staying UTC-consistent (avoid **`Time.get_datetime_dict_from_system()`** alone—it reflects **local** time and would contradict the `UTC` suffix).

**Primary line**

`[timestamp … UTC] | [LEVEL] | [source_tag] | [message]`

**`source_tag`:** Short identifier for origin—**`Main`**, **`AIInference`**, **`Player`**, **`HUD`**, etc. Callers pass **`source_tag`** on API methods (default **`"Main"`**). Free-form strings allowed; keep stable conventions in code reviews.

**Editor mirror (`push_to_editor`):** Each of **`error` / `info` / `debug`** exposes the equivalent of **two overloads**: **`(message)`** and **`(message, push_to_editor: bool)`**. Only the literal value **`true`** enables mirroring; **`false`**, omitted, or any other value → **file only**.

**Recommended GDScript shape (single implementation):**  
`func error(message: String, push_to_editor := false, source_tag := "Main")`  
(and the same parameter pattern for **`info`** / **`debug`**). That covers “overload” ergonomics without duplicate bodies.

**Mirroring:** **`push_to_editor == true`** → also emit to editor **Output**: **`error` → `push_error`**, **`info` → `push_warning`**, **`debug` → `print`** (same **`message`** text as queued, before prefix—implementer choice documented in code comments).

**Stacks (Nice-to-have):** After the primary line, emit **one line per frame**, same **`[timestamp] | [LEVEL] | [source_tag] |`** prefix for alignment **or** a fixed continuation indent—pick one style in code and apply consistently; each frame text on its own line.

**PII / size:** Follow [`../.cursor/rules/instructions.md`](../.cursor/rules/instructions.md) — **Logging & sensitive data** (`MAX_LOG_LINE_CHARS`, no secrets, truncate large text).

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| create | `res://oLog_lib/` | **`olog.gd`** (+ helpers). |
| modify | `res://project.godot` | Autoload **`OLog`** → **`res://oLog_lib/olog.gd`**, **first** in list. |

### Dependencies

- Writable **`user://`**.  
- **`OLog`** Autoload **before** other autoloads that might log during **`_ready`**.  
- **`main.gd` does not** construct **`OLog`**.

---

## 5. Implementation plan (ordered)

1. Autoload **`OLog`** **first** in **`project.godot`** → stub **`res://oLog_lib/olog.gd`**.  
2. Config load **`user://config.json`**, **`logging_params`**, §4.3 fallbacks.  
3. Ring + mutex + enqueue + §4.2 eviction + §4.3 filter-before-enqueue.  
4. Formatter §4.4 (UTC dict from unix time, **`source_tag`**, one-line message).  
5. Public API: **`error` / `info` / `debug`** with **`(msg)`** and **`(msg, push_to_editor: bool)`**; **`source_tag`** parameter (default **`Main`**); optional **`with_stack`** variant per Nice-to-have.  
6. Shutdown drain + flush.  
7. Automated tests: encoding, overload, config fallbacks, **`push_to_editor`** branches.

---

## 6. Acceptance criteria

- [ ] All level methods + **`push_to_editor`** overloads  
- [ ] Filtering before enqueue per §4.3  
- [ ] Log lines match §3/§4.4 (UTC, **`source_tag`**, one-line body; stacks multi-line)  
- [ ] Multi-thread enqueue safe  
- [ ] §4.2 overload eviction + counters  
- [ ] Drain batch + shutdown flush  
- [ ] **`OLog`** Autoload **first**; **`main.gd`** does not own logger construction  

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Disk fills | Keep entries small; at **~1 GB** log size emit a failure line and stop writing (current policy). |

---

## 8. Testing / verification

**Manual:** Run at multiple **`LOG_LEVEL`** values; confirm **`user://logs/`** output and optional editor mirror when **`push_to_editor`** is **true**.

**Automated:** Drive **`user://config.json`** / **`logging_params`**; assert file content and suppression rules.

---

## 9. Open questions

-  

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 5/4/26 | initial creation |
| 5/4/26 | §4.1 ring + §4.2 eviction |
| 5/4/26 | §4.3 `user://config.json`; Autoload |
| 5/4/26 | §4.3 expanded; Scene & Dependencies |
| 5/4/26 | Final review: Autoload **first**; §4.4 UTC/`Time.get_datetime_dict_from_unix_time(..., true)`, **`source_tag`**, **`push_to_editor`** overloads; eviction rationale; TL terminal-only; PII rules in **instructions.md**; **`AI_INSTRUCTIONS.md`**, **`ENHANCEMENT_BACKLOG.md`** |
