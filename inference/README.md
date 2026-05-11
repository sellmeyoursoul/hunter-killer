# Bundled inference (llama.cpp–style server)

Ship an **OpenAI-compatible** HTTP server next to the exported game so players do not start it manually. The game probes `INFERENCE_BASE_URL`, and when `INFERENCE_AUTO_START_ENABLED` is true and the URL is loopback (`http://127.0.0.1` or `http://localhost`), it can spawn the bundled executable from this folder.

## Layout (next to the player `.exe`)

Use per-OS folders under the project for editor/dev; the same structure should sit **next to the exported binary** after export:

- `inference/windows/` — Windows: `llama-server.exe` (or your build) and `models/*.gguf`
- `inference/macos/` — macOS binary + models
- `inference/linux/` — Linux binary + models

Paths in `game_config.json` → `inference_client` are **relative to**:

- **Exported game:** folder containing the game executable (`OS.get_executable_path().get_base_dir()`).
- **Editor:** if `BUNDLE_ROOT_OVERRIDE` is empty, the project root + `inference/<os>/` when that directory exists.

## `game_config.json` keys

| Key | Purpose |
|-----|---------|
| `INFERENCE_AUTO_START_ENABLED` | If true, spawn the bundled server when the probe fails (loopback URLs only). |
| `BUNDLED_SERVER_EXE` | Path relative to bundle root, e.g. `inference/windows/llama-server.exe`. |
| `BUNDLED_MODEL_GGUF` | Path relative to bundle root, e.g. `inference/windows/models/model.gguf`. |
| `BUNDLED_SERVER_ARGS` | JSON array of extra CLI args (e.g. `["-ngl", "99"]`). The game always adds `-m <model>`, `--host 127.0.0.1`, and `--port <parsed from URL>`. |
| `INFERENCE_PROBE_PATH` | HTTP GET path for readiness (default `/v1/models`). |
| `INFERENCE_START_TIMEOUT_MS` | Max wait after spawn before failing (default 60000). |
| `BUNDLE_ROOT_OVERRIDE` | Absolute path to a folder that mirrors the export layout (for testing). |

Set `INFERENCE_AUTO_START_ENABLED` to **false** during development if you run the server yourself; set it to **true** for release builds that include the binaries and model.

## Export

Godot does not automatically copy `inference/` into the export folder. Either:

- Add these files via **Export → Resources → Filters to export non-resource files**, or  
- Run a post-export script that copies `inference/<platform>/` next to the executable.

## Developer workflow (no bundle)

1. Start your OpenAI-compatible server on the host/port in `INFERENCE_BASE_URL` (e.g. `http://127.0.0.1:8080`).
2. Keep `INFERENCE_AUTO_START_ENABLED` false, or omit `BUNDLED_SERVER_EXE` / `BUNDLED_MODEL_GGUF`.

## CLI compatibility

The spawn logic targets **llama.cpp**-style servers: arguments are `-m <absolute_model_path>`, optional `BUNDLED_SERVER_ARGS`, then `--host 127.0.0.1` and `--port <port>`. If your server uses different flags, adjust `BUNDLED_SERVER_ARGS` or change [`bundled_inference_launcher.gd`](../AI_int_lib/bundled_inference_launcher.gd) for your stack.

## Legal

Redistribute **llama.cpp**, model weights, and dependencies only in compliance with their licenses and terms.
