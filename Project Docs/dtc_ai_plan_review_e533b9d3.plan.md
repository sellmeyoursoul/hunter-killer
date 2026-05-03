---
name: DtC AI Plan Review
overview: "A read-only gap analysis of [DtC_AI_INT_PLAN.md](C:/Users/mikea/Documents/Proj%20Git%20Repo/Dodge%20the%20creeps/Project%20Docs/DtC_AI_INT_PLAN.md): contradictions, missing technical decisions, and placeholders that block implementation."
todos:
  - id: fix-requirements
    content: Align must-have keys (4 arrows + enter) and define TL observation/action contract
    status: pending
  - id: fill-technical
    content: Complete scene table, implementation order, dependencies (incl. llama module), and integration threading policy
    status: pending
  - id: external-protocol
    content: Specify or defer external party IPC and semantics for end/restart
    status: pending
  - id: doc-hygiene
    content: Fix instructions.md path/typo; tighten acceptance criteria and test scope
    status: pending
isProject: false
---

# Ambiguities in DtC_AI_INT_PLAN.md (pre-implementation)

This doc is a solid intent statement but several sections are placeholders or internally inconsistent. Below is what an implementer cannot infer without decisions or repo spelunking.

---

## Contradictions in requirements

- **Must-have C vs D / “four keys”:** Section 3 lists arrow keys for **up, down, left** only (no **right**). Section 3.D and acceptance criteria refer to **four** direction keys. You need an explicit must-have line for **right** (or state that right is out of scope for Phase 1).
- **“Collision aware” vs architecture:** Should-have A asks for mob avoidance; the architecture (section 4) only describes start → play until collision → end, with no mention of **what observations** TL receives (positions, velocities, distances, raster, etc.). Without that, “collision aware” is not implementable.

---

## Missing or broken references

- **`insctructions.md`:** Typo and **no path**. The repo has [dodge-the-creeps/.cursor/rules/instructions.md](C:/Users/mikea/Documents/Proj%20Git%20Repo/Dodge%20the%20creeps/dodge-the-creeps/.cursor/rules/instructions.md). Agents should be pointed to the real file.
- **Section 2 — Key scripts:** Empty. At minimum, cite [dodge-the-creeps/main.gd](C:/Users/mikea/Documents/Proj%20Git%20Repo/Dodge%20the%20creeps/dodge-the-creeps/main.gd), player/mob/HUD scripts, and where the llama/TinyLlama binding will live (you already have `modules/llama` / llama.cpp in-tree — the plan never mentions it under Dependencies).

---

## Integration model not specified

The plan says “main.gd calls the TL interface” and “TL passes in a value to simulate keypad enter” but does not define:

| Decision | Why it matters |
|----------|----------------|
| **Injection vs simulation** | Feed `Input.parse_input_event(...)`, call methods on `Player`, or a dedicated “AI driver” node that mimics `_physics_process` input? |
| **Threading / frame budget** | Open question 9 notes perf; you still need a policy: blocking LLM call per frame, background thread + queued action, max tokens, timeout, fallback action. |
| **Start screen** | [main.gd](C:/Users/mikea/Documents/Proj%20Git%20Repo/Dodge%20the%20creeps/dodge-the-creeps/main.gd) has no start-screen logic in `_ready`; “notify TL it is on the start screen” implies HUD/button flow — which node owns that state and which signal means “ready to press Enter”? |

---

## TinyLlama / model specifics

- **Artifact:** Which **GGUF** (or format), path on disk, quantization, context size.
- **Prompt contract:** System + user message shape; how game state is **serialized to text** (or if you avoid text and use structured logits — unlikely for TL).
- **Action parse:** How model output maps to **five** discrete actions (enter + four arrows): strict token set, JSON, or free text with parsing rules and validation.

---

## “External party” (should-have B & C)

- **Transport:** TCP, HTTP, stdin/stdout, Godot editor plugin, named pipe, file watch?
- **Semantics:** What exactly is “end the game” (same as player death? pause? kill process?) and “start again” (new game vs restart model session)?

Until these are pinned down, should-haves are not testable.

---

## Empty template sections (block “done”)

- **Scene & file changes table (section 4):** No `res://` paths for new/modified scenes, scripts, or autoloads.
- **Implementation plan (section 5):** Empty ordered list.
- **Risks & mitigations (section 7):** Empty (perf and “too good to lose” in section 9 belong here with mitigations).
- **Groups (section 4):** Empty — only matters if you rely on group queries for state export.
- **Signals (section 4):** “TL’s enter, up, … keys” — unclear if these are **new** Godot signals or **named** input actions; naming and payload need one line each.

---

## Acceptance criteria gaps

- “Interface … created” — no **API surface** (GDScript class name, methods, thread rules).
- “Collision detection logic … aware of objects” — duplicates engine collision; clarify **exposure** of mob/player positions (and whether only **nearby** mobs matter for perf).
- “TL play parameters” — learning rate? temperature? repetition penalty? **Not applicable to inference** unless you mean prompt/rules; term is ambiguous.
- Typos (“Collisiion”, “awayre”) are minor but fix for searchability.

---

## Testing (section 8)

- “Automated tests … every code path” conflicts with an LLM-in-the-loop game (nondeterministic, slow). Clarify: **unit tests** for parsing/state serialization only, **integration** optional, or **recorded** golden traces.

---

## Nice-to-have: “show its thinking”

- **Channel:** Print to console, `print_line` overlay, dedicated UI, or token stream to a file? Privacy/size limits?

---

## Summary

**Must resolve before coding:** right-key inclusion; **observation format** and **action format**; **where** TL runs and **how** input is applied; **start-screen / game flow** alignment with actual scenes; model file + prompt contract; external-control **protocol** (or defer should-haves). **Should fill from repo:** key script paths, scene table, ordered implementation steps, and pointer to real `instructions.md`.
