---
name: stop
description: End session and overwrite chat_sum.md using the stop handoff protocol in .cursor/rules/stop.mdc
disable-model-invocation: true
---

Follow `.cursor/rules/stop.mdc` exactly. Overwrite `chat_sum.md` in the workspace root using the required handoff format. Use Agent/write tools; do not summarize only in chat.
