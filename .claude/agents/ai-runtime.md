---
name: ai-runtime
description: >-
  Activate for AiDriver session state (IDLE/ARMED/PLAYING/WAITING), LLM HTTP completions,
  perception wire/risk hints, action token parsing, bundled inference launcher, system_prompt.txt,
  agent_ndjson_sink, and game_config_merge.gd sections for inference_client, perception,
  and creature_motor. Write scope: AI_int_lib/, inference/. Follow the AI_int_lib/CLAUDE.md
  runtime priorities and OLog hygiene via _OLogSafe. Delegate pure motor math in
  creature/motor/ to creature-motor; do not edit main_3d or game_config.gd facade unless
  scope is explicitly expanded.
tools: Read, Grep, Glob, Edit, Write, Bash
model: inherit
---
# AI Runtime Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `AI_int_lib/`, `inference/`.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the caller; provide only a functional structural diff summary and status reports.
- Follow [AI_int_lib/CLAUDE.md](../../AI_int_lib/CLAUDE.md) for in-game LLM behavior and OLog volume/PII policy.
- Prefer delegating static motor helpers in `creature/motor/` to `creature-motor`; keep orchestration and duel registry logic in `ai_driver.gd`.
- When merge keys or inference/perception defaults change, flag the caller to sync `game_config.json` (`app-shell`) and active Project_Docs (`project-docs`).
- Never log secrets, raw prompts, or PII through `_OLogSafe` or `agent_ndjson_sink.gd`.
