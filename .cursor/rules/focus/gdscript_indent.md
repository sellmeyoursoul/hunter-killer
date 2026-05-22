# GDScript indentation (agents)

**Scope:** Any edit to `*.gd` in this repo. Godot **rejects** files that mix tab characters with space indentation in the same file.

## Rules

1. **Spaces only** — 2 spaces per indent level ([`.editorconfig`](../../../.editorconfig) `[*.gd]`).
2. **Never paste tab-indented blocks** from Godot Editor, chat snippets, or other repos without re-indenting to spaces first.
3. **Match the open file** — if the file already uses spaces, every new/changed line must use spaces (no `\t`).
4. **Do not “fix tabs” by a blind `\t` → two-spaces replace** on the whole file; that breaks blocks where one tab and `tab + spaces` meant different depths. Prefer `line.expandtabs(2)` on the **original tabbed text**, or re-indent by hand / from git.

## Before marking a coding task done

Run from repo root (PowerShell):

```powershell
python tools/check_gdscript_no_tabs.py
```

Exit code must be `0`. If it fails, fix listed paths before finishing.

## Editor alignment

- **Cursor / VS Code:** [`.vscode/settings.json`](../../../.vscode/settings.json) — `editor.insertSpaces`, `editor.detectIndentation: false`, `[gdscript]` same.
- **Godot Editor:** Editor Settings → Text Editor → Indent → **Space**, size **2** (not Tab).

## When an agent introduces tabs

Common causes: applying a patch copied from tab-indented source; using tools that default to tabs; merging without normalizing.

Recovery:

1. `git checkout HEAD -- path/to/file.gd` if the committed version is space-clean.
2. Re-apply logic changes with space indentation only, or run `expandtabs(2)` on a **tabbed backup** of that file, then verify with the check script and Godot parse.
