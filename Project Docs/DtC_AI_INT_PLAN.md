# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:**  Ai Integration
**One-line objective:**  This is where we plug TinyLlama into the game and allow it to take on the role of the player

**Out of scope (explicit non-goals):**  We are not going to add any AI logic to the MOBs or change any of the fundamental game logic
-  

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
-  

**Existing patterns to follow:** (naming, signals, groups, layers, file layout)  
    **formatting** 
    A. We are following the instructions in the `{projectHome}\.cursor\rules\instructions.md` file. From there apply Godot script best practices for GDScript. **C++:** No native C++ gameplay modules are in scope for this phase; if C++ is added later for TL inference glue, apply standard C++ practices then.
    B. We are going to comment every function we touch based on the documentation instructions in the `{projectHome}\.cursor\rules\instructions.md` file.
    c. Where possible we will use the same root names for the objects in different files. If there is a need to differentiate them add an `_` and a short descriptor (for example mobVariable_cpp and mobVariable_gd)

-  

---

## 3. Requirements

### Must have
    A. TinyLlama (TL) must be able to interact with the application as a player at runtime.
    B. TL must be able to start the game when given the token to do so.
    C. TL must be able to simulate the use of the up arrow key to move up, the down arrow key to move down, the left arrow key to move left, and the right arrow key to move right.
    This simulation should return a single token for the key it chooses to press to minimize load. The token should map the following way
        i.      Right  -> Godot Input map move_right
        ii.     Left  -> Godot Input map move_left
        iii.    Up  -> Godot Input map move_up
        iv.     Down  -> Godot Input map move_down
        v.      Start -> Godot Input map start_game
    D. TL is instructed that the point of the game is to avoid collisions for as long as possible within the confines of the four available direction keys and the bounds of screen.


-  

### Should have
    A. A clear perception contract policy for TL (see **§4.2 Perception contract**): each simulation tick the Godot/AI driver builds an occupancy **grid map** of the playfield plus **kinematics computed in Godot** (positions/cells and velocities). TL consumes that snapshot (not raw scene-tree access) to choose moves. *Future enhancement:* restrict awareness to a proximity radius around the player; low priority for a small playfield.
    B. A way for human observer to end the game if TL proves to be too good at the game. It can't go on forever. This could be as simple as Ctrl+C while running under the debugger, or an **End** button outside the play area. It must end play by invoking **`Main.game_over()`** in [`main.gd`](../main.gd) (which stops timers/music and calls **`HUD.show_game_over()`** in [`hud.gd`](../hud.gd)). Do not introduce a separate `func_game_over` unless it wraps these existing calls.
    C. A way for an external party to notify TL that it is time to start again (see **§4.4 Session lifecycle & restart**).

-  

### Nice to have
    A. A way for TL to show its thinking. For this phase let's put the output into the terminal window for realtime observation. 
-  

---

## 4. Technical design

### Architecture / data flow
(Diagram in words: who calls whom, new nodes, autoloads, resources.)
    A. The game is started using the existing scenes and resources and files.
    B. An external user clicks the **AI Player** button. `main.gd` (orchestration) tells the **AI driver** that a session is armed; the driver notifies TL / loads the model as needed; TL emits the **start_game** token once.
    C. **Observation sampling:** On every Godot physics frame (`_physics_process`), the AI driver samples the playfield and writes the latest **snapshot** into a **thread-safe slot** (overwrite with newest only). Sampling is cheap; no LLM call happens on the main thread.
    D. **Inference cadence:** A **worker thread** runs TL inference on a timer **no faster than once per `INFERENCE_PERIOD_MS`** (start conservatively e.g. **250 ms**; tune by measurement). Each wake takes the **latest** snapshot only (drop intermediate frames). **Velocity** and positions in that snapshot are **computed in Godot** from scene state (RigidBody2D `linear_velocity`, player velocity from movement logic); TL does **not** infer velocity by differencing grids for this phase (that remains an optional fallback if kinematics are disabled).
    E. **Action handling:** When inference completes, the driver posts the chosen action token to the main thread (Godot `call_deferred` or a thread-safe queue drained in `_process`). Until a new token arrives, **reuse the last applied action**. If inference times out or fails, apply **fallback: noop / stay stationary** (no simulated key held unless the game already applies continuous motion—match existing player controls).
    F. TL plays until a mob–player collision triggers **`game_over()`** on `Main`; the stack calls **`HUD.show_game_over()`**. The AI driver transitions to **WAITING** (no automatic inference).
    G. To run again, the **restart contract** (§4.4) runs: scene reset via existing **`new_game()`** path, then TL is armed again.

### 4.2 Perception contract — grid “vector map”

These values are normative for implementers unless a later phase revises them.

| Item | Specification |
|------|----------------|
| Playfield | Aligned to the visible game viewport (project **480×720** px in `project.godot`; if changed, derive grid from the same rectangle the player is clamped to). |
| Cell size | Constant **`CELL_SIZE`** world pixels (default **24**): grid width **`ceil(480 / CELL_SIZE)`**, height **`ceil(720 / CELL_SIZE)`** → default **20×30**. |
| Origin | Top-left of the playfield; **row index increases downward**, **column increases rightward** (matches Godot screen Y-down). |
| Cell encoding (occupancy) | Integer **0–3**: **`0`** empty, **`1`** player only (hitbox center cell), **`2`** one or more mobs and no player center in that cell, **`3`** player center and ≥1 mob center map to the **same** cell (imminent/overlap—treat as highest priority). If multiple mobs share a cell, still encode **`2`**. Entity centers map to cells via `floor(world_pos / CELL_SIZE)` clamped to grid bounds. |
| Bounds | Cells outside the playfield are not emitted; TL is instructed that the grid covers the whole playable window so **edges are walls**. |
| Kinematics block (Godot-computed) | After the grid, snapshot includes **player**: cell row/col (redundant with grid but aids parsing) and velocity **`(vx, vy)`** in **pixels per second**. Then **each mob** (no hard cap needed for Dodge phase; optional sort by distance to player for stable prompts): cell row/col and **`(vx, vy)`**. Velocities come from gameplay state (`linear_velocity` / movement), not from TL differencing past frames. |

**Serialization / tokens (minimize prompt size)**  
- **Wire format (recommended):** One UTF-8 text blob per inference: header line `tick_ms score cols rows cell_size` then **`rows` lines** of **`cols` digits** `0–3` (no spaces). Then line `PLAYER r c vx vy`. Then one line per mob: `MOB r c vx vy`.  
- **System prompt (once):** Static instructions (goal, legal tokens, encoding legend).  
- **User message (each inference):** Only the blob above plus optional one-line **`LAST_ACTION`** echo for coherence.  
- **Future:** binary or base64 grid for smaller wire size; out of scope unless TL glue supports it.

### 4.3 Inference / threading parameters (normative defaults)

| Parameter | Default | Notes |
|-----------|---------|--------|
| `INFERENCE_PERIOD_MS` | 250 | Increase if TL cannot keep up; decrease if actions feel sluggish. |
| Worker model | Background thread + `call_deferred` action | Never block `_physics_process` on LLM. |
| Snapshot selection | Latest-only | Intermediate frames discarded. |
| Max output tokens | Tight cap (set in driver, e.g. single-token or few tokens) | Forces `UP`/`DOWN`/… style answers. |
| Inference timeout | Start e.g. 2× period | On timeout → fallback noop; log in nice-to-have debug channel. |
| Action sticky | Yes | New token replaces previous; until then repeat last **simulated** intent per driver policy. |

**Blocking vs async (summary):** Blocking the main loop on TL **per frame** is rejected: it cannot match 60 FPS. Async worker + periodic inference + sticky action is the baseline; tune period, timeout, and max tokens empirically.

### 4.4 Session lifecycle & restart

**Parties:** For this phase the “external party” is **in-process**: human via HUD/debugger driving Godot.

**States (AI driver):** `IDLE` → `ARMED` (session ready, waiting for TL start token) → `PLAYING` → `WAITING` (after game over).

**Restart sequence:**  
1. **`Main.new_game()`** runs (existing flow: reposition player, timers, HUD message).  
2. Orchestration calls **`ai_driver.notify_session_reset()`** (name illustrative) with payload **`{ phase = "NEW_GAME", score = 0 }`** so TL clears stale history if any.  
3. Human clicks **AI Player** again **or** a dedicated **Restart AI** control arms **`ARMED`**; TL issues **`start_game`** token exactly once per round.

**Future extension:** A stdin/socket line protocol (e.g. `RESTART\n`) for headless harnesses—not required for this phase.

### Scene & file changes
| Action | Path | Notes |
|--------|------|-------|
| create | `res://AI_int_lib/` | Directory for TL interface, snapshot builders, and threading glue. |
| modify | `res://main.gd` | Hook `game_over()` / `new_game()` to AI driver; TL orchestration. |
| modify | `res://player.gd` | TL control path without blocking human player input. |
| modify | `res://hud.gd` | **AI Player** button; optional **End** button calling `Main.game_over()`. |

### Collision / input / signals (if relevant)
- Layers/masks: Defined in `mob.gd` and `player.gd`.
- **Action surface:** TL output maps to Godot **InputMap** actions (`move_*`, `start_game`) via the driver (same token contract as §3 Must-have C).
- **Observation surface:** Driver builds §4.2 snapshots on the main thread; worker reads snapshots (no direct scene queries from TL).
- **Lifecycle hooks:** `Main.game_over()` notifies driver → `WAITING`; `Main.new_game()` notifies driver → reset session payload.
- **Optional signals** (emit from driver if useful): `ai_session_state_changed(state_enum)`, `ai_inference_started`, `ai_inference_finished(action_token)`.

### Dependencies
- Assets: TinyLlama (`{projectHome}/models/tinyllama-Q4_K_M.gguf`) quantized 4-bit; visual/audio under `{projectHome}/art`.
- Prompt contract is resolved for this phase by **§4.2**: static system prompt + compact per-tick user blob (grid + kinematics). Structured logits bypassing text are **not** in scope unless the TL runtime supports them later.
- Plugins: —
- External APIs: —

---

## 5. Implementation plan (ordered)

1. Define **§4.2 perception contract** (constants + serializer) and implement snapshot builder on the main thread.
2. Implement **AI driver**: thread/worker, `INFERENCE_PERIOD_MS`, timeout, sticky action, fallback noop.
3. Implement **TL runtime interface** (load model, system prompt, parse single action token from completion).
4. Wire **`main.gd` / `player.gd` / `hud.gd`**: AI Player button, session ARMED/PLAYING/WAITING, `game_over()` / `new_game()` hooks per **§4.4**.
5. Tune **period, max tokens, timeout** using runtime measurement.

---

## 6. Acceptance criteria

(Checklist — agent treats unchecked items as incomplete.)

- [ ] Interface between Godot and TL is created (driver + model load + thread boundary).
- [ ] Snapshot pipeline implemented: occupancy grid per **§4.2** plus **Godot-computed** velocities for player and each mob; communicated to TL each inference tick (not full scene dumps). Collision **effects** remain as today in `main.gd`; this criterion is perception only.
- [ ] TL receives a **static** system prompt at session start (avoid collisions, legal keys/tokens, encoding legend); per-tick user messages use the compact serialization from **§4.2**.
- [ ] Key bindings or equivalent mechanism maps TL output tokens to Godot **InputMap** actions.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| TL cannot keep up with Godot | **§4.3**: worker thread, bounded inference rate, latest snapshot, sticky actions; measure and adjust `INFERENCE_PERIOD_MS`, timeout, max tokens. |
| TL never loses | Keep gameplay rules unchanged; tune timers/spawn if needed for fairness (design-only—still no mob AI changes per §1). |
| TL “cheats” outside keys | Interface exposes only action tokens + §4.2 snapshots; no unrestricted scene access from TL code paths. |
| Regression for human players | Dual-input path in `player.gd`; automated checks per **§8**. |

**Residual risks to monitor:** Model nondeterminism / hallucinated tokens → validate parser maps unknown strings to noop; memory growth from queues → latest-only snapshot; threading bugs → stress-test start/stop/restart.

---

## 8. Testing / verification

**Manual steps:**  
    A. Run in debugger so a user can watch TL play  
    B. Verify **End** control calls `Main.game_over()` and driver enters WAITING  
    C. Restart round via **§4.4** (new_game + arm TL + start token)

**Automated (minimal for this phase):**  
    A. Unit-test **snapshot encoding**: known fake positions/velocities produce deterministic grid + kinematics lines.  
    B. Integration smoke: toggle AI vs human input flag does not break existing movement tests if present; otherwise manual checklist above suffices until test harness exists.

---

## 9. Open questions

    A. Exact **`CELL_SIZE`** / grid dimensions if art or viewport aspect changes—derive mechanically from viewport settings.
    B. Whether **`INFERENCE_PERIOD_MS`** should synchronize with `MobTimer` spawn cadence for fairness experiments.
    C. Headless **stdin/socket restart** protocol for CI vs keeping everything HUD-driven.

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 5/2/26 | Initial Plan doc written |
| 5/4/26 | Closed perception/async gaps: §4.2 grid + kinematics contract, §4.3 threading defaults, §4.4 restart; aligned paths (`player.gd`, repo root), `game_over`/`show_game_over`, signals/deps; implementation plan reordered; §6–8 tightened; questions moved to §9. |
