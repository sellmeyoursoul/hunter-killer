---
name: go
description: Start a fresh task from chat_sum.md using the go handoff protocol
disable-model-invocation: true
---

# Slash Command: /go

When I type `/go <my new instructions>`, immediately read `chat_sum.md` from the workspace root as the current handoff context.

1. Load `chat_sum.md` with the file-reading tool.
2. Treat its **System State** and **Progress Made** as the current foundation.
3. Prioritize the instructions after `/go` over the handoff's **Last Known Trajectory** when they differ.

Acknowledge that the state is loaded, summarize the new direction in one sentence, then execute the task.
