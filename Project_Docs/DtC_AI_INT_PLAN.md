# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:**  Ai Integration
**One-line objective:**  This is where we plug TinyLlama into the game and allow it to take on the role of the player

**Out of scope (explicit non-goals):**  
  - We are not going to add any AI logic to the MOBs or change any of the fundamental game logic


---

## 2. Context for agents

**Repo / project root:**  `C:\Users\mikea\Documents\Git Proj\dodge-the-creeps` (authoritative for this repository clone; adjust `{projectHome}` if you open a copy elsewhere).
**Engine & version:**  Godot 4.6.2
**Main scenes / entry:**  Only one scene for this iteration
**Key scripts (paths):**  
    A. `{projectHome}/main.gd`
    B. `{projectHome}/player.gd`
    C. `{projectHome}/mob.gd`
    D. `{projectHome}/hud.gd`
    E. **`AI_int_lib`/AI driver** — autoload singleton (see **§4.1b** / **Scene & file changes**; e.g. `ai_driver.gd` under `res://AI_int_lib/`). 

**Existing patterns to follow:** (naming, signals, groups, layers, file layout)  
    **formatting** 
    A. We are following [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md) (and referenced **focus** files under [`.cursor/rules/focus/`](../.cursor/rules/focus/)). From there apply Godot script best practices for GDScript. **C++:** No native C++ gameplay modules are in scope for this phase; if C++ is added later for TL inference glue, apply standard C++ practices then.
    B. We are going to comment every function we touch per **AGENTS.md** documenting rules.
    c. Where possible we will use the same root names for the objects in different files. If there is a need to differentiate them add an `_` and a short descriptor (for example mobVariable_cpp and mobVariable_gd)
  

---

## 3. Requirements

### Must have
    A. TinyLlama (TL) must be able to interact with the application as a player at runtime via a **remote inference service** (Godot client only — see **§4.1**).
    B. **Start round via TL:** Human presses **AI Player** → driver enters **`ARMED`** → remote inference returns token **`START`** → **`Main.new_game()`** is called **exactly once** to begin play (same effect as HUD **`start_game` → `new_game`**; no synthetic `Input`). **Duplicate** **AI Player** / duplicate **`START`** while a start is already being honored → **noop**. **AI session priority:** Once **`ARMED`**, the HUD’s normal human **Start** control (**`start_game` → `new_game`**) must **not** run — treat presses as **noop** until the session leaves **`WAITING`** after **End AI** / **game over** (see **§4.1b**). **End AI** always remains allowed and still calls **`Main.game_over()`** during **`PLAYING`**.
    C. TL chooses **one** action per inference using a **compact machine-facing token** (see **§4.2** for parsing rules): **`UP`**, **`DOWN`**, **`LEFT`**, **`RIGHT`**, or **`START`**. The driver converts tokens to **`ControlMode.AI`** behavior as follows:
        i.   **`RIGHT` / `LEFT` / `UP` / `DOWN`** → set **virtual movement intent** on the player (see **§4.1b**) so motion matches the same **speed and clamp** as human **`Input`** movement.
        ii.  **`START`** → only when **`ARMED`**, call **`Main.new_game()`** once (see **§4** architecture **B**); when not **`ARMED`**, **`START`** is **noop** (ignored).
    D. TL is instructed that the point of the game is to avoid collisions for as long as possible using only the four directional tokens (and **`START`** when arming), inside the **same axis-aligned rectangle** used to **clamp the player position** in code (viewport / playable area — see **§4.2**).

  

### Should have
    A. A clear perception contract policy for TL (see **§4.2**): on each **physics** step (subject to **`SNAPSHOT_PHYSICS_STRIDE`** in **`user://game_config.json`** → **`perception`**), the driver builds an occupancy grid + **Godot-computed** kinematics as **`Vector3(vx, vy, vz)`** with **`vz = 0`** in 2D, plus hitbox half-extents (§4.2). **Inference** still runs on **`INFERENCE_PERIOD_MS`** and always consumes the **latest** snapshot only (tunable separately — TL not overwhelmed by request rate while snapshot can be finer). *Future enhancement:* restrict awareness to a proximity radius around the player.
    B. A way for human observer to end the game if TL proves to be too good at the game. It can't go on forever. **Normative UI:** an **End AI** (or equivalent) button **below** the play viewport, **right-aligned**, using the **same size** (minimum dimensions) as the existing **Start** button so layout stays consistent. It must not sit **inside** the play window where it would block observation of TL. Ctrl+C under the debugger remains acceptable for developers. The control must end play by invoking **`Main.game_over()`** in [`main.gd`](../main.gd) (which stops timers/music and calls **`HUD.show_game_over()`** in [`hud.gd`](../hud.gd)). Do not introduce a separate `func_game_over` unless it wraps these existing calls.
    C. A way for an external party to notify TL that it is time to start again (see **§4.4 Session lifecycle & restart**).
  

### Nice to have
    A. **Developer-only “thinking” trace** (verbose model text): first pass = **`print` / `print_rich`** or **`OLog.debug(..., true)`** so it appears in the **Godot editor Output** only. No additional logging infrastructure required unless this proves insufficient later.

---

## 4. Technical design

### 4.1 LLM runtime integration — **Phase decision: remote inference**

**Selected approach:** **Option C — remote inference service** (HTTP or similar). The Godot project **does not** load `*.gguf` locally; it **calls an external API** hosted where the model weights live.

**Default server implementation (POC):** **`llama-server`** from **[llama.cpp](https://github.com/ggml-org/llama.cpp)** (`examples/server`), loading the same **TinyLlama GGUF** on the host. It exposes **OpenAI-compatible** `POST /v1/chat/completions`, matches this doc’s **`INFERENCE_BASE_URL`** + **`CHAT_COMPLETIONS_PATH`** shape, and supports **many parallel clients** (continuous batching / multi-user), which aligns with **stateless** Godot clients (§4.2).

**Gaps / caveats (llama.cpp server vs. “perfect” OpenAI parity)** — expanded below with **concrete mitigations** so implementers are not guessing.

| Topic | What can go wrong | Mitigation (normative for this repo’s client) |
|--------|------------------|-----------------------------------------------|
| **`model` field** | Server loads **one** GGUF at startup; `model` in JSON is often a **dummy** label. | Client still sends **`MODEL_ID`** from config for OpenAI-shaped bodies. Server may ignore it; operators document the loaded file separately. |
| **Chat template / TinyLlama** | `/v1/chat/completions` requires a **supported chat template** for best results; mismatches yield odd formatting. | Use a **TinyLlama** (or compatible) GGUF and a **matching** `llama-server` / template (see [wiki](https://github.com/ggml-org/llama.cpp/wiki/Templates-supported-by-llama_chat_apply_template)); validate once with a manual `curl`. If output is garbage, fix **server flags** (`--jinja`, template file) before touching gameplay. |
| **Output shape** | Small models emit **extra words**, newlines, or markdown; `content` is not always a single token. | Set **`max_tokens`** low in client + server; **always** run **`ai_action_tokens`** normalizer (first line or first whitespace-delimited token → §3 map); unknown → `noop`. Optionally add JSON `stop` (e.g. newline) **if** your server build honors it for chat — verify; not required if normalizer is solid. |
| **`stream`** | Streaming responses use **SSE**, not the same JSON shape as non-stream. | Client sends **`"stream": false`** explicitly. |
| **Empty / malformed JSON** | Network glitches, proxy strips body. | No `choices` / missing `message.content` → treat as **noop**; same as HTTP error. |
| **Auth header** | Docs show **`Authorization: Bearer …`** for OpenAI chat; server also supports **`--api-key`** / **`--api-key-file`**. | If **`API_KEY`** non-empty in config, send **`Authorization: Bearer <API_KEY>`**; start `llama-server` with the matching **`--api-key`** (or file) for non-localhost. Localhost dev may omit both. |
| **TLS** | Raw `llama-server` is usually **HTTP**. | Non-local **`INFERENCE_BASE_URL`** uses **`https://`** only when a **reverse proxy** terminates TLS; document the operator’s URL in README/setup, not in-game. |
| **Context size** | Huge prompts (future grids) can exceed **`ctx-size`**. | Server **`--ctx-size` / `-c`** must be **≥** worst-case tokenized prompt; POC grid is small; revisit if grid grows. |
| **Strong “one token only”** | Text parsing is heuristic; model can still fail. | **Future:** `llama-server` **grammar** / **JSON schema** constraints (see server README); **out of scope** for first client unless needed. |

**Operator quick-start (reference — not automated by Godot):**

```text
llama-server -m <path-to-tinyllama.gguf> --port 8080 -c 2048 [ -ngl 99 ... ] [ --api-key <secret> ]
```

Match **`INFERENCE_BASE_URL`** to `http://host:8080` (no path) and **`CHAT_COMPLETIONS_PATH`** to `/v1/chat/completions`.

**Alternatives if llama.cpp is not enough later:**

- **[vLLM](https://github.com/vllm-project/vllm)** — strong multi-tenant serving, OpenAI API; heavier ops, typically **CUDA**-centric.
- **[Ollama](https://ollama.com/)** — simple local/dev workflow; API surface differs (often not drop-in for `/v1/chat/completions` without adapter); good for humans, less ideal for **strict** automation unless you standardize on its HTTP API.
- **`llama-cpp-python` [OpenAI-compatible server](https://llama-cpp-python.readthedocs.io/en/latest/server/)** — Python stack; another way to serve GGUF with chat-completions-shaped routes.
- **Managed APIs** (OpenAI, Groq, etc.) — drop-in for protocol, but **not** TinyLlama-on-your-GPU unless you change model/provider policy.

**Conclusion:** Prefer **`llama-server`** for this project unless you hit a concrete gap (e.g. missing deployment platform, required feature only in another stack); if so, pick from the table above by **ops constraints** (GPU, latency, team familiarity), not by prompt format — the **client** stays **OpenAI-shaped**.

**Rationale:** Minimizes heavyweight native glue in the game process, keeps **main thread clean**, and scales toward **many logical players / sessions** sharing **one GPU cluster** behind a single endpoint.

**AI driver autoload:** Implement the driver as an **autoload singleton** (recommended name: e.g. **`AiDriver`**) registered in [`project.godot`](../project.godot) **after** **`GameConfig`** and **before** **`OLog`** so it can read inference settings and log via **`OLog`**. It owns session state (**`IDLE`/`ARMED`/`PLAYING`/`WAITING`**), **`HTTPRequest`** orchestration pattern **C**, **`request_id`**, and hooks from **`Main`**.

**Client responsibilities (Godot, `AI_int_lib` + autoload driver):**

- Hold config at runtime: **base URL**, **request timeout** (start ≥ inference timeout in §4.3), optional **`Authorization`** / API key header (placeholder for POC).
- On each inference tick (worker thread): build an API request payload carrying **system prompt** (§4.1d) + **user** content (**§4.2 ARMED vs PLAYING**); **never** touch the scene tree off-thread. **HTTP dispatch (pattern C):** worker prepares payload; **main thread** performs **`HTTPRequest`**; response text is queued back with a **monotonic request ID** (see below).
- **Request ordering (latest enqueued wins):** Assign each outbound inference an incrementing **`request_id`** and track **`latest_enqueued_request_id`** at enqueue time. When a response arrives, apply it **only if** `response_id == latest_enqueued_request_id`; otherwise **discard** as stale. On driver **shutdown** / scene exit, **clear pending queues** and cancel/ignore in-flight callbacks so no late responses mutate intent.
- Parse **only** the **action token** from the response (§4.2); on **HTTP error**, **timeout**, or **malformed body** → **noop** (ignored for intent; see architecture **E**).
- **TLS:** Use HTTPS in any non-local deployment; tolerates plain HTTP only for **`localhost`** dev.

**Service responsibilities (out of repo for POC unless you add a small reference server):**

- Run **`llama-server`** (or compatible) hosting **TinyLlama** GGUF and expose **`/v1/chat/completions`** (or the path configured in **`CHAT_COMPLETIONS_PATH`**).
- Enforce **`max_tokens`** server-side as defense in depth.

**API shape (POC — document the exact paths in code):**

- Prefer an **OpenAI-compatible** `POST …/v1/chat/completions` body: `messages[]` with **`system`** (§4.1d) + **`user`** (content depends on phase — **§4.2 “User message by phase”**), **`max_tokens`** small, **`temperature`** low, **`"stream": false`** explicitly.
- Response: read `choices[0].message.content` (or equivalent) and run the **token normalizer** (§4.2).

### 4.1d System prompt (what it is, why it is not pasted here, what to put in code)

The **system** message is the **stable instruction layer** of every chat request. It tells the model **who it is playing as**, **what output shape is legal**, and **how to read the user blob** (grid legend, line order, token vocabulary). It does **not** change frame-to-frame; the **user** message carries **live** observations (only **after** **`Main.new_game()`** — §4.2).

**Why this doc does not include the full verbatim string**

- The exact wording is tuned alongside **`llama-server`**, the GGUF, and the chat template; pasting a frozen paragraph here would **drift** from what you ship in the autoload driver within days.
- Operators may shorten or expand it (e.g. stricter “reply with only one word”) without a design-doc edit cycle.
- The **contract** is the combination of **§4.2** (blob format + parser) + **§3.C** (actions); the prose in the system prompt is how you **teach** the model that contract.

**What the implementation must include (checklist for `AiDriver` or a `const` / resource next to it)**

1. **Role:** You are the player in Dodge the Creeps; survive by dodging mobs inside the playfield.
2. **Output contract:** Reply with **exactly one** token per completion: **`UP`**, **`DOWN`**, **`LEFT`**, **`RIGHT`**, or **`START`** (uppercase). No punctuation or extra words (best effort; parser still enforced in code).
3. **`START` rule:** Output **`START`** **only** while the session is waiting to begin the round (driver is **`ARMED`**); during play use only the four directions for movement intent.
4. **User blob legend:** Describe the header (`tick_ms score cols rows cell_size`), digit grid lines (**0–3** meanings), then **`PLAYER` / `PLAYER_EXT`**, then **`MOB` / `MOB_EXT`** lines and **distance sort** — keep the prompt self-contained enough for a small model; **§4.2** remains authoritative for implementers.
5. **Coordinates:** Rows increase downward; columns rightward; playfield matches player clamp rect.

<<Comment: Optional future tweak — duplicate the digit meanings in a one-line cheat in the system prompt if TinyLlama ignores long legends.>>

**Where it lives:** Default copy: **[`AI_int_lib/system_prompt.txt`](../AI_int_lib/system_prompt.txt)** — load at runtime (e.g. `FileAccess.get_file_as_string()` from `res://AI_int_lib/system_prompt.txt`) in **`AiDriver`**, or paste into a **`const`** if you prefer a single file. Not in **`user://game_config.json`** for this phase (keeps prompts in version control).

**HTTP client threading (normative for implementation):**

| Pattern | Pros | Cons |
|--------|------|------|
| **A. Main-thread `HTTPRequest` only** | Native TLS; simple lifecycle | Easy to block the frame if mis-scheduled |
| **B. Worker thread blocking `HTTPClient`** | Familiar threading model | SSL / thread safety footguns |
| **C. Worker prepares payload; main thread `HTTPRequest`, result queued back** | No scene tree off the worker; main thread does I/O safely | More queue/boilerplate |

**This phase chooses C.**

**Logging (this phase):** Do **not** log full HTTP bodies or full grids to `OLog` / `print`. Per [`.cursor/rules/focus/logging_instr.md`](../.cursor/rules/focus/logging_instr.md), log only **status**, **sizes**, and **short truncated** snippets when needed for debugging.

**GGUF file (`{projectHome}/models/tinyllama-Q4_K_M.gguf`):** Deployment artifact for the **inference server**, not loaded by the Godot client. **`models/`** may remain **gitignored**; operators place weights on the server host.

**Options A/B** (in-process / subprocess) remain documented below for context only; **this phase implements C only.**

| Option | Pros | Cons | Fit for scaling many agents |
|--------|------|------|------------------------------|
| **A. In-process (GDExtension / native binding, e.g. llama.cpp)** | Lowest **IPC** overhead per call; tight control; single deployable; good **latency** for one agent | Native build/packaging per platform; native crashes can take down the editor/game; worker threads must never touch the scene tree | Prefer **one shared inference runtime** inside the extension plus a **request queue** — not one full model load per logical player |
| **B. Subprocess (helper executable; stdin/stdout or local socket)** | Strong **isolation** (runner hangs don’t kill Godot); swap the runner without rebuilding the game | **Serialization + pipe** overhead; higher baseline latency; *N* heavy processes is costly unless consolidated | Medium: one **multi-session** subprocess or small local **service** scales better than *N* separate processes |
| **C. Remote service (HTTP/WebSocket/gRPC to a GPU host)** | **Best horizontal scaling** — many clients or many “players” can share one **inference cluster**; decoupled release cycle | **Network latency**; auth, retries, offline story | Strong default when you foresee **many** agents or centralized GPU |

### 4.1b Control mode: Human vs AI (exclusive) — **virtual intent**

- **No merged / competing input:** Either **`ControlMode.HUMAN`** or **`ControlMode.AI`**, never both driving `Player` at once.
- **AI session priority (HUD Start suppressed):** While the driver is **`ARMED`** (waiting for **`START`**) or **`PLAYING`**, the usual human **Start** button path that calls **`Main.new_game()`** must be a **noop**—the armed AI session owns starting the round via TL’s **`START`** → **`new_game()`**. **Exception:** **End AI** (**`Main.game_over()`**) remains **always** wired and is **not** suppressed.
- **State transition clarification (normative):**
  - `IDLE` + Human **Start** => normal human round start path (outside AI flow).
  - `IDLE` + **AI Player** => `ARMED`.
  - `ARMED` + Human **Start** => **noop** (remain `ARMED`).
  - `ARMED` + TL `START` => call `Main.new_game()` once, then `PLAYING`.
  - `PLAYING` + Human **Start** => **noop** (remain `PLAYING`).
  - `PLAYING` + **End AI** or collision => `Main.game_over()` => `WAITING`.
  - `WAITING` + **AI Player** => `ARMED` for next AI round.
  - `WAITING` + Human **Start** => normal human round start path, and AI driver returns to `IDLE` (or equivalent non-armed human mode).
- **No mid-game mode switch:** While **`PLAYING`** under **`ControlMode.AI`**, the human must **not** take over movement or flip back to human input until the round ends (**`Main.game_over()`** or **`new_game()`** path). The only human action during AI play is **early termination** via **§3 Should have B** (**`Main.game_over()`**). Switching to human control again happens only after that flow (e.g. from **game over** UI or an explicit future “human round” entry point), not as an instantaneous toggle mid-round.
- **Human mode:** Read **`Input`** for `move_*` actions exactly as today (refactored into **`_physics_process`** — see **§4.1c**).
- **AI mode:** The driver maintains **sticky** directional intent per §4 architecture **E** and writes it into **`Player`** fields (e.g. normalized `ai_move_dir: Vector2` or separate `ai_wants_*` booleans). **`player.gd`** applies **movement from virtual intent only** — **no** `Input.action_press` simulation for movement.
- **`START` in AI mode:** When **`ARMED`**, a parsed **`START`** token causes **`Main.new_game()`** to run **once** (same runtime effect as HUD **`start_game` → `new_game`**). **`START`** when not **`ARMED`** is **noop** (ignored). Do not inject synthetic `Input` for **`START`**.
- **`noop` tokens / failed HTTP / timeouts:** **Always ignored** for intent updates — **do not** change **virtual movement** intent; previously sticky intent stays until a **valid** directional token arrives.
- **Who decides the first move (and idle strategy):** The **model** decides. The driver does **not** implement game-side heuristics such as “wait until mobs exist,” “drift toward center when the field is empty,” or other scripted tactics—those would hide how TinyLlama behaves on its own. **Implementation baseline only (not a design mandate):** until the first **valid** directional token, keep **virtual movement intent at zero** (stand still); `noop` / errors keep that baseline. First motion is whatever the first valid **`UP`/`DOWN`/`LEFT`/`RIGHT`** is after TL sees the snapshots—could still be “no move” for a long time if the model keeps emitting `noop` or non-actions, which is acceptable for observation.
- **Future player features (non-movement):** When the human gains actions beyond cardinal movement (abilities, menus, etc.), extend the **virtual intent** model (or a small `PlayerIntent` resource) so the AI path can express those intents without relying on synthetic keyboard events. The remote service token vocabulary and parser would grow in lockstep.

### 4.1c Movement tick: **`_physics_process` (mandatory for this phase)**

- **Refactor as part of AI integration:** Move **`player.gd`** movement (**human + AI**) from **`_process`** to **`_physics_process`** so motion, mob physics, and **§4.2 snapshot sampling** share the **same physics step**.
- **Sampling rule:** Build the perception snapshot in **`_physics_process`** at a defined point relative to player motion (document in code: e.g. **after** integrating player velocity for that tick).
- **Input:** Human **`Input.is_action_pressed`** is still read in **`_physics_process`** (same frame as movement). **Do not** split human input in `_process` and movement in `_physics_process` once this lands.

### Architecture / data flow
(Diagram in words: who calls whom, new nodes, autoloads, resources.)
    A. The game is started using the existing scenes and resources and files.
    B. **Human flow (normative):** Human presses **AI Player** → driver **`ARMED`** → TL returns **`START`** → **`Main.new_game()`** runs once → **`PLAYING`**. There is **no dual control** (see **§4.1b**). **Duplicate** **`START`** before transition to **`PLAYING`** / duplicate **AI Player** presses → **noop**. While **`ARMED`** or **`PLAYING`**, HUD **Start** is **noop** (§3.B, §4.1b); **End AI** still calls **`game_over()`**.
    C. **Observation sampling:** After **`PLAYING`** begins (i.e. **`Main.new_game()`** has run for this round), on each physics frame when **`physics_ticks % SNAPSHOT_PHYSICS_STRIDE == 0`**, the driver samples the playfield and overwrites the latest **§4.2 snapshot** in a **thread-safe slot**. **No** full §4.2 grid blob exists before that — there is no valid playfield context to serialize (§4.2 **User message by phase**).
    D. **Inference cadence:** A **worker thread** schedules **remote HTTP requests** on **`INFERENCE_PERIOD_MS`**. Each request uses **`system`** + **`user`** (§4.1d, §4.2): while **`ARMED`**, **`user`** is the minimal **arm handshake** string only; once **`PLAYING`**, **`user`** is the **latest** §4.2 blob (first such blob only after **`new_game()`**). **`Velocity`** and positions in that snapshot are **computed in Godot** from scene state (`RigidBody2D` `linear_velocity`, player velocity from movement logic); TL does **not** infer velocity by differencing grids for this phase (that remains an optional fallback if kinematics are disabled).
    E. **Action handling:** When the HTTP response is parsed, the driver posts results to the main thread (`call_deferred` / queue) **with `request_id`**. **Discard** results whose id is not the **latest enqueued** id (§4.1). **Valid** directional tokens update **virtual intent** (sticky until replaced). **`noop`**, errors, and timeouts **do not** change intent. **`START`** when **`ARMED`** triggers **`Main.new_game()`** once (then **`PLAYING`**). **Do not** leave phantom `Input` actions pressed in AI mode.
    F. TL plays until a mob–player collision triggers **`game_over()`** on `Main`; the stack calls **`HUD.show_game_over()`**. The AI driver transitions to **WAITING** (no automatic inference).
    G. To run again, the **restart contract** (§4.4) runs: scene reset via existing **`new_game()`** path, then TL is armed again.

### 4.2 Perception contract — grid “vector map”

These values are normative for implementers unless a later phase revises them.

| Item | Specification |
|------|----------------|
| Playfield | **Derive from code**, not hardcoded literals: use the **same size vector** the player uses for **`position.clamp(Vector2.ZERO, …)`** (typically `get_viewport_rect().size` at runtime). If `project.godot` window size changes, the grid tracks that clamp rectangle. |
| Cell size | Constant **`CELL_SIZE`** world pixels (default **24**): grid width **`ceil(playfield_width / CELL_SIZE)`**, height **`ceil(playfield_height / CELL_SIZE)`** (with `playfield_*` from the row above). |
| Origin | Top-left of the playfield; **row index increases downward**, **column increases rightward** (matches Godot screen Y-down). |
| Cell encoding (occupancy) | Integer **0–3**: **`0`** empty, **`1`** player only (**hitbox** center cell — §4.2 sampling point), **`2`** one or more mobs and no player center in that cell, **`3`** player center and ≥1 mob center map to the **same** cell (imminent/overlap—treat as highest priority). If multiple mobs share a cell, still encode **`2`**. Entity **sampling points** map to cells via `floor(world_pos / CELL_SIZE)` clamped to grid bounds (`world_pos` is **2D** center from §4.2 sampling). |
| Bounds | Cells outside the playfield are not emitted; TL is instructed that the grid covers the **full clamp rectangle** so **edges behave like walls** (anything outside the clamp range is unreachable). |
| Kinematics block (Godot-computed) | After the grid: **`PLAYER r c vx vy vz`** (**Vector3**, world units/sec; **`vz = 0`** in 2D) — velocity from **explicit** movement intent × speed (player) or **`linear_velocity`** (mobs) — then **`PLAYER_EXT hx hy hz`** (axis-aligned **half-extents** in world units; **`hz = 0`** in 2D). Per mob: **`MOB r c vx vy vz`** then **`MOB_EXT hx hy hz`**. All positions, cell indices `(r,c)`, velocities, and half-extents use one **documented world-space sampling point** per entity (see **Sampling point** below). |
| Mob listing order | After **`PLAYER`** / **`PLAYER_EXT`**, emit **`MOB`** lines in **ascending Euclidean distance** from the **player’s sampling point** to each mob’s sampling point. **Tie-break:** lower **`instance_id`** (or stable node path string) so order is reproducible across frames. **Why:** nearest threats appear first in the text, which matches **collision-avoidance** salience without changing the grid math. |

**Sampling point & half-extents (normative):** Use **[`AI_int_lib/perception_sampling.gd`](../AI_int_lib/perception_sampling.gd)**. For each **`Area2D`** / **`RigidBody2D`** body, take **every enabled** child **`CollisionShape2D`** with a non-null **`shape`**, build each shape’s **world-space axis-aligned bounding box** from **`Shape2D.get_rect()`** transformed by **`CollisionShape2D.global_transform`**, **union** those AABBs, then:

- **Sampling point** = **center** of the union AABB (world `Vector2`).
- **`PLAYER_EXT` / `MOB_EXT`** = **half the union’s width and height** as **`Vector3(hx, hy, 0)`**.

If **no** usable collision shape exists, fall back to **`body.global_position`** and **`Vector3.ZERO`** half-extents — implementors should **`push_error`** in debug; production scenes (`player`/`mob`) must keep a **Capsule** (or equivalent) enabled.

*(Rationale vs. node origin alone: aligns occupancy and extents with **physics collisions**, including rotation.)*

**Serialization / tokens (minimize prompt size)**  
- **Wire format (full §4.2 blob — `PLAYING` only):** One UTF-8 text blob per inference: header line `tick_ms score cols rows cell_size` then **`rows` lines** of **`cols` digits** `0–3` (no spaces). Then **`PLAYER r c vx vy vz`**, then **`PLAYER_EXT hx hy hz`**, then for each mob (in **§4.2 Mob listing order**): **`MOB r c vx vy vz`** and **`MOB_EXT hx hy hz`** on the following line.
  - **`tick_ms`:** `Time.get_ticks_msec()` (uint64 truncated/sent as decimal) at snapshot time — monotonic, comparable across frames.
  - **`score`:** **`Main.score`** in [`main.gd`](../main.gd) (typed **`int`**); HUD is updated via **`HUD.update_score(score)`** from **`Main`** (push contract).  
- **User message by phase**
  - **`ARMED`** (waiting for **`START`**): **`user`** is **not** the grid blob. Use this exact fixed handshake string: **`ARMED`** (single line, uppercase) so TL can respond with **`START`** without fabricating a playfield. **Inference may run** on the same **`INFERENCE_PERIOD_MS`** cadence as **`PLAYING`**.
  - **`PLAYING`:** **`user`** is **only** the full §4.2 blob from the **latest** snapshot. The **first** such blob is produced **after** **`Main.new_game()`** has run for that round (Get Ready / initial state is valid context); **do not** send a full grid before that.
- **TL action tokens (machine parsing):** The completion must normalize to **exactly one** of **`UP` `DOWN` `LEFT` `RIGHT` `START`** (ASCII upper case). The driver trims whitespace, takes the **first line** or **first token**, upper-cases, then maps via §3.C. **Any other string** → **`noop`** (**ignored**; does not update virtual intent).
- **System prompt:** §4.1d (same **`system`** string every request; stateless serving).

<<Comment: **Future option (not this phase):** embed a **`LAST_ACTION …`** line in **`user`** so the model sees the previous command without multi-turn chat history. Revisit if TinyLlama needs explicit action echoing; adds tokens.**

- **Future:** binary or base64 grid for smaller wire size; out of scope unless TL glue supports it.

**Chat API vs. §4.2 blob (what is different):**  
- **§4.2 wire format** is **what the model reads about the game** once **`PLAYING`**: digit grid, `tick_ms`, `score`, `PLAYER` / `MOB` lines — **domain encoding** of observations.  
- **Stateless chat** is **how** messages are sent: each call sends `messages: [{ role: system, content: … }, { role: user, content: … }]` with **no** prior `assistant` turns on the server. While **`ARMED`**, **`user`** is the **handshake** only; while **`PLAYING`**, **`user`** is the blob. That scales to **many agents** behind one `llama-server` because each request is independent.  
- If you later need **multi-turn reasoning**, you either (a) **embed** prior actions/outcomes in the **user** string, or (b) refactor to **stateful** chat (larger prompts, harder scaling) — this phase chooses **(a)** only when explicitly added; observation-only **user** blobs otherwise.

**Outstanding / closed:** This split is **fully specified** for the POC; no open design items unless you add **streaming**, non–chat-completions backends, or **binary** observation blobs (all out of scope until explicitly scheduled).

### 4.3 Inference / threading parameters (normative defaults)

| Parameter | Default | Notes |
|-----------|---------|--------|
| `INFERENCE_PERIOD_MS` | 250 | Increase if TL cannot keep up; decrease if actions feel sluggish. |
| Worker model | Pattern **C**: worker prepares payload; **main** `HTTPRequest`; queue results back | Never block `_physics_process` on network I/O; marshal **virtual intent** on the main thread. |
| Snapshot selection | Latest-only | Intermediate frames discarded. |
| Max output tokens | Tight cap (set in driver; target **one** output token if runtime allows) | Forces **`UP`/`DOWN`/…**-style answers per §4.2 token contract. |
| Inference timeout | Start e.g. 2× period | **noop** (no intent change); dev-only truncated log per §4.1 logging rules. |
| Action sticky | Yes | New **valid** directional token replaces previous virtual intent; **`noop`** leaves intent unchanged. |

**Blocking vs async (summary):** Blocking the main loop on **HTTP/inference** **per frame** is rejected: it cannot match 60 FPS. Async worker + periodic inference + sticky **virtual intent** is the baseline; tune period, HTTP timeout, and max tokens empirically.

### 4.4 Session lifecycle & restart

**Parties:** For this phase the “external party” is **in-process**: human via HUD/debugger driving Godot.

**States (AI driver):** `IDLE` → `ARMED` (session ready, waiting for TL start token) → `PLAYING` → `WAITING` (after game over).

**Restart sequence:**  
1. **`Main.new_game()`** runs and must return the session to the **same full initial playfield state every time** (not merely incrementing score or moving the player): authoritative **`score`**, player at **`StartPosition`**, **`Get Ready`** / timer cadence, audio as today, **`MobTimer`/`ScoreTimer`/`StartTimer` stopped then restarted in the intended order, and **every spawned mob removed** so no carry-over from the previous round. The **AI driver** resets any **client-side** state tied to the round (**virtual intent**, **request_id** sequence / pending response handling, internal queues per §4.1) here or immediately after — **no** “clear LLM conversation history” step because inference is **stateless** (§4.2).  
2. Human clicks **AI Player** again **or** a dedicated **Restart AI** control arms **`ARMED`**; TL issues **`START`** token exactly once per round (then **`PLAYING`**).

**Future extension:** A stdin/socket line protocol (e.g. `RESTART\n`) for headless harnesses—not required for this phase.

### Scene & file changes
| Action | Path | Notes |
|--------|------|-------|
| create | `res://AI_int_lib/` | Directory for TL interface, snapshot builders, and threading glue. |
| create | `res://AI_int_lib/ai_driver.gd` (name illustrative) | **Autoload** AI driver singleton (see **`project.godot`**): pattern **C** HTTP, session state, **`request_id`**. |
| create | `res://AI_int_lib/system_prompt.txt` | Default **§4.1d** system prompt; **`AiDriver`** loads from `res://`. |
| create | `res://AI_int_lib/perception_sampling.gd` | §4.2 **sampling point** / **`_EXT`** from **union** of **`CollisionShape2D`** AABBs. |
| modify | [`project.godot`](../project.godot) | Register autoload **`AiDriver`** (or chosen name) **after** **`GameConfig`**, **before** **`OLog`**. |
| modify | `res://main.gd` | Hook `game_over()` / `new_game()` to AI driver; TL orchestration. |
| modify | `res://player.gd` | Refactor movement to **`_physics_process`**; **exclusive** Human (`Input`) vs **AI** (**virtual intent** from driver). |
| modify | `res://hud.gd` | **AI Player** button; **End AI** button (**§3**): **below** viewport, **right-aligned**, **same size** as **Start**; calls `Main.game_over()`; **`Main`** keeps `score` authoritative and calls **`HUD.update_score(score)`** (existing contract). |

### Collision / input / signals (if relevant)
- Layers/masks: Defined in `mob.gd` and `player.gd`.
- **Action surface:** Human: **`InputMap`** `move_*`. AI: **virtual intent** on `Player` (§4.1b). **`START`** while **`ARMED`:** driver calls **`Main.new_game()`** once (not synthetic `Input`).
- **Observation surface:** Main thread fills the latest §4.2 snapshot into a **thread-safe slot**; the worker thread **copies** that slot into the HTTP request body (no scene-tree access off-thread).
- **Lifecycle hooks:** `Main.game_over()` notifies driver → `WAITING`; `Main.new_game()` notifies driver → reset **client** driver state (intent, request IDs, queues) per §4.4.
- **Optional signals** (emit from driver if useful): `ai_session_state_changed(state_enum)`, `ai_inference_started`, `ai_inference_finished(action_token)`.

### Dependencies
- **Config:** Autoload **[`game_config.gd`](../game_config.gd)** (**`GameConfig`**, before **`OLog`**) merges **`user://game_config.json`** with defaults; **[`AI_int_lib/game_config_merge.gd`](../AI_int_lib/game_config_merge.gd)** holds merge helpers and defaults.
- **AI driver:** Autoload **`AiDriver`** (see **Scene & file changes**) **after** **`GameConfig`**, **before** **`OLog`**.
- **Inference:** **`llama-server`** (llama.cpp) or compatible **OpenAI-shaped** HTTP(S) API; Godot client uses `AI_int_lib` + **`GameConfig.get_inference_client()`**. Exact paths and quirks documented in code (§4.1).
- **Model weights:** TinyLlama **GGUF** (e.g. `tinyllama-Q4_K_M.gguf`) lives on the **server**; **`{projectHome}/models/`** may hold a copy for server setup only and may be **gitignored** — not loaded by the game client. Visual/audio under `{projectHome}/art`.
- **Prompt contract:** Per **§4.2** and **§4.1d** — system prompt in code + **`user`** per phase (handshake vs blob); structured logits bypassing text are **not** in scope unless the TL runtime supports them later.
- Plugins: HTTP client (Godot built-in **`HTTPRequest`** or equivalent); no GGUF loader in-game.
- External APIs: **LLM inference HTTP API** (required).

### 4.5 Runtime configuration — `user://game_config.json`

**Loader:** Autoload **`GameConfig`** ([`game_config.gd`](../game_config.gd)), registered **before** **`OLog`** in [`project.godot`](../project.godot), reads and **merges** this file with hardcoded defaults ([`AI_int_lib/game_config_merge.gd`](../AI_int_lib/game_config_merge.gd)). **`OLog`** consumes **`GameConfig.get_logging_params()`** only (no direct JSON parse in `OLog`).

**Location:** **`user://game_config.json`**. Repo template: [`game_config.json`](../game_config.json). Do **not** commit real API keys.

#### `logging_params`

Passed through to **`OLog`** after merge. Missing file or invalid JSON still yields usable defaults; **`GameConfig.get_config_load_diagnostic()`** records a human-readable reason for **`push_error`**.

#### `inference_client`

| Key | Type | Required | Default (if omitted) | Meaning |
|-----|------|----------|----------------------|---------|
| `INFERENCE_BASE_URL` | string | **yes** | `""` | Scheme + host + optional port, **no trailing slash**. URL = **`INFERENCE_BASE_URL` + `CHAT_COMPLETIONS_PATH`**. Empty → AI cannot arm. |
| `CHAT_COMPLETIONS_PATH` | string | no | `"/v1/chat/completions"` | Path for OpenAI-style chat (leading slash). |
| `MODEL_ID` | string | **yes** | `""` | Model name the **server** expects. Empty → AI cannot arm. |
| `API_KEY` | string | no | `""` | **`Authorization: Bearer …`** when non-empty; omit header when empty. |
| `HTTP_TIMEOUT_MS` | int | no | `500` | Full HTTP request timeout. |
| `INFERENCE_PERIOD_MS` | int | no | `250` | Min interval between inference requests. |
| `MAX_OUTPUT_TOKENS` | int | no | `8` | Client/server cap for short replies. |
| `TEMPERATURE` | number | no | `0.0` | Low variance. |

#### `perception`

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `SNAPSHOT_PHYSICS_STRIDE` | int | `1` | Build a new grid snapshot every **N** physics frames (`N >= 1`). **Inference** still uses **`INFERENCE_PERIOD_MS`** and the **latest** snapshot only. |

**Missing `inference_client` / invalid AI keys:** AI mode must **refuse to arm** (`OLog.error` / `push_error`) — see acceptance criteria.

**Sample (repository template):**

```json
{
  "logging_params": {
    "LOG_LEVEL": "Debug",
    "MAX_LINES_PER_PROCESS": 128,
    "MAX_QUEUE_ENTRIES": 1024
  },
  "inference_client": {
    "INFERENCE_BASE_URL": "http://127.0.0.1:8080",
    "CHAT_COMPLETIONS_PATH": "/v1/chat/completions",
    "MODEL_ID": "tinyllama",
    "API_KEY": "",
    "HTTP_TIMEOUT_MS": 500,
    "INFERENCE_PERIOD_MS": 250,
    "MAX_OUTPUT_TOKENS": 8,
    "TEMPERATURE": 0.0
  },
  "perception": {
    "SNAPSHOT_PHYSICS_STRIDE": 1
  }
}
```

---

## 5. Implementation plan (ordered)

1. **`GameConfig`** autoload + merge helpers (**done** in [`game_config.gd`](../game_config.gd), [`AI_int_lib/game_config_merge.gd`](../AI_int_lib/game_config_merge.gd)); **`OLog`** reads logging via **`GameConfig`** only.
2. Refactor **`player.gd`**: move movement + human **`Input`** reads to **`_physics_process`** (§4.1c).
3. Define **§4.2 perception contract** (constants + serializer) and implement snapshot builder on the **main** thread / physics step (**`SNAPSHOT_PHYSICS_STRIDE`**); **first** full blob only **after** **`new_game()`** (**§4.2**).
4. Implement **AI driver** autoload (**Scene & file changes**): pattern **C** HTTP, **`INFERENCE_PERIOD_MS`**, **`stream: false`**, timeout, sticky **virtual intent**, **`noop`** ignored, **`ARMED`** handshake **`user`** string, **`START`** → **`Main.new_game()`** when **`ARMED`**, HUD **Start** suppressed per §4.1b.
5. Wire **`main.gd` / `player.gd` / `hud.gd`**: AI Player button, **End AI** (**§3** placement), session ARMED/PLAYING/WAITING, **no mid-game human control** (**§4.1b**), `game_over()` / `new_game()` hooks + driver state reset per **§4.4**.
6. Tune **period, max tokens, HTTP timeout** using runtime measurement.

---

## 6. Acceptance criteria

(Checklist — agent treats unchecked items as incomplete.)

- [ ] **`GameConfig`** autoload (**before** **`OLog`**) loads merged **`user://game_config.json`**; **`OLog`** uses **`get_logging_params()`** only.
- [ ] **`AiDriver`** (or chosen name) **autoload** registered **after** **`GameConfig`**, **before** **`OLog`** in **`project.godot`**.
- [ ] **Remote inference client** in Godot: HTTP pattern **C**, config via **`GameConfig.get_inference_client()`**; **no** local model load; **stateless** `messages` (`system` + `user` only); **`"stream": false`**; **monotonic `request_id`** with **latest-enqueued-wins** stale response drop and **queue purge on shutdown** (§4.1).
- [ ] Snapshot pipeline: §4.2 grid + **`Vector3`** kinematics + **`_EXT`** half-extents; stride from **`GameConfig.get_perception_params()`**; **first** full §4.2 **`user`** blob only **after** **`Main.new_game()`**; **`ARMED`** uses exact handshake **`user = "ARMED"`** only (§4.2).
- [ ] **§4.1d** system prompt in code; **no** `LAST_ACTION` in **`user`** this phase.
- [ ] **HUD Start** noop while **`ARMED`** or **`PLAYING`**; **End AI** still **`game_over()`** (§3.B, §4.1b).
- [ ] TL static system prompt + correct **`user`** per phase (no full scene dumps).
- [ ] **Virtual intent** + **`noop`** rules; **`START`** when **`ARMED`** → **`Main.new_game()`** once.
- [ ] **`inference_client`** valid URL + model or AI refuses to arm.
- [ ] **Automated:** `godot --path . --headless -s res://tests/run_all.gd` exits **0** (see §8).

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Remote service down / slow | Timeouts / errors → **noop** (intent unchanged); truncated dev log only (§4.1). |
| TL cannot keep up with Godot | **§4.3**: worker thread, bounded inference rate, latest snapshot, sticky **virtual intent**; measure and adjust `INFERENCE_PERIOD_MS`, HTTP timeout, max tokens. |
| TL never loses | Keep gameplay rules unchanged; tune timers/spawn if needed for fairness (design-only—still no mob AI changes per §1). |
| TL “cheats” outside keys | Interface exposes only action tokens + §4.2 snapshots; no unrestricted scene access from TL code paths. |
| Regression for human players | **Exclusive** control mode toggle; human path unchanged when `ControlMode.HUMAN`; automated checks per **§8**. |

**Residual risks to monitor:** Model nondeterminism / hallucinated tokens → validate parser maps unknown strings to noop; **network partitions**; memory growth from queues → latest-only snapshot + **purge on shutdown**; **late HTTP responses** → **`request_id`** stale-drop; threading bugs → stress-test start/stop/restart.

---

## 8. Testing / verification

**Automated (headless, this phase):** From the repo root (Godot on `PATH`):

`godot --path . --headless -s res://tests/run_all.gd`

Exit code **0** means tests passed. Tests cover **`GameConfigMerge`**, **action token normalization**, **perception header** formatting (**§4.2** helpers), and **`perception_sampling`** AABB helpers.

**Automated (future AI driver):**
- Snapshot grid integration from known fake positions/velocities.
- Human vs AI mode integration smoke.
- **HUD Start suppression test:** when driver is `ARMED` or `PLAYING`, human Start press is noop and does not call `Main.new_game()`.
- **End AI path test:** while `PLAYING`, End AI still calls `Main.game_over()` and transitions to `WAITING`.
- **Handshake contract test:** in `ARMED`, outbound `user` message is exactly `ARMED`; no grid blob is sent.
- **First-blob timing test:** first full §4.2 blob is not sent until after `Main.new_game()` for that round.
- **Latest-enqueued request ordering test:** if responses arrive out of order, only response with `request_id == latest_enqueued_request_id` is applied.

**Manual steps:**  
    A. Run in debugger so a user can watch TL play  
    B. Verify **End AI** calls `Main.game_over()` and driver enters WAITING  
    C. Restart round via **§4.4** (new_game + arm TL + **START**)

---

## 9. Open questions

*Deferred:* Revisit after POC integration lands—likely still relevant for tuning and CI, but not blocking initial implementation.

    A. Whether **`INFERENCE_PERIOD_MS`** should synchronize with `MobTimer` spawn cadence for fairness experiments.
    B. Headless **stdin/socket restart** protocol for CI vs keeping everything HUD-driven.

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 5/8/26 | **`AI_int_lib/system_prompt.txt`** default **§4.1d** prompt. §3.B / §4.1b: AI session priority — HUD **Start** noop while **ARMED/PLAYING**; **End AI** retained; explicit state-transition table. §4.2: first full blob after **`new_game()`**; exact handshake **`user = "ARMED"`**; **no** `LAST_ACTION` (future `<<Comment>>`). §4.1 request ordering clarified as **latest enqueued wins**; §8 future tests expanded. **§4.1d** explainer + **`AiDriver`** autoload + §6. |
| 5/2/26 | Initial Plan doc written |
| 5/4/26 | Closed perception/async gaps: §4.2 grid + kinematics contract, §4.3 threading defaults, §4.4 restart; aligned paths (`player.gd`, repo root), `game_over`/`show_game_over`, signals/deps; implementation plan reordered; §6–8 tightened; questions moved to §9. |
| 5/6/26 | **Remote inference locked in** (§4.1); **virtual intent** for AI movement + **`START`** via `main`/driver; **mandatory `player.gd` → `_physics_process`**; dependencies + acceptance criteria updated; dev trace = Godot Output first pass. |
| 5/6/26 | **§4.5** `inference_client` in `user://game_config.json` (template in repo `game_config.json`). |
| 5/7/26 | **GameConfig**-first bootstrap (`game_config.gd`, `game_config_merge.gd`); **§4.2** **Vector3** kinematics + **`_EXT`** lines; **§4.1** HTTP pattern **C** table; **`perception`/`SNAPSHOT_PHYSICS_STRIDE`**; **ARMED** → **`START`** → **`Main.new_game()`**; **`noop`** rules; **`user` doc sample JSON** + §§5–8 acceptance / headless **`tests/run_all.gd`**. |
