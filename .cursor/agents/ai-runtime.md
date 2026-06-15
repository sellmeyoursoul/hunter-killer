---
name: ai-runtime
description: >-
  Activate for AiDriver session state (IDLE/ARMED/PLAYING/WAITING), LLM HTTP completions,
  perception wire/risk hints, action token parsing, bundled inference launcher, system_prompt.txt,
  agent_ndjson_sink, and game_config_merge.gd sections for inference_client, perception,
  and creature_motor. Write scope: AI_int_lib/, inference/. Follow agentic-runtime-ai.mdc and
  logging.mdc via _OLogSafe. Delegate pure motor math in creature/motor/ to creature-motor;
  do not edit main_3d or game_config.gd facade unless orchestrator expands scope.
model: inherit
readonly: false
is_background: false
---
# AI Runtime Specialist Protocol

## Directory Scope
- Restrict modifications and file reads strictly to: `AI_int_lib/`, `inference/`.

## Execution Constraints
- Always check local syntax and type definitions before declaring a task complete.
- Do not dump modified source code back to the orchestrator; provide only a functional structural diff summary and status reports.
- Follow `.cursor/rules/agentic-runtime-ai.mdc` for in-game LLM behavior and `.cursor/rules/logging.mdc` for OLog volume/PII policy.
- Prefer delegating static motor helpers in `creature/motor/` to creature-motor; keep orchestration and duel registry logic in `ai_driver.gd`.
- When merge keys or inference/perception defaults change, flag orchestrator to sync `game_config.json` (app-shell) and active Project_Docs via project-docs.
- Never log secrets, raw prompts, or PII through `_OLogSafe` or `agent_ndjson_sink.gd`.
