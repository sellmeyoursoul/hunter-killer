#!/usr/bin/env python3
"""Fail if any .gd file under the repo root contains a tab character."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", ".godot", "addons"}


def main() -> int:
  bad: list[str] = []
  for path in ROOT.rglob("*.gd"):
    if any(part in SKIP_DIRS for part in path.parts):
      continue
    text = path.read_text(encoding="utf-8", errors="replace")
    if "\t" in text:
      count = text.count("\t")
      rel = path.relative_to(ROOT).as_posix()
      bad.append(f"{rel} ({count} tab(s))")
  if bad:
    print("GDScript must use spaces only (see .editorconfig). Tab characters found in:")
    for line in sorted(bad):
      print(f"  - {line}")
    return 1
  print("OK: no tab characters in .gd files")
  return 0


if __name__ == "__main__":
  sys.exit(main())
