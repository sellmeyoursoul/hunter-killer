#!/usr/bin/env python3
"""Read-only audit of duplicated config defaults (OPEN_BUGS.md CBD-1).

Global defaults live in code (AI_int_lib/game_config_merge.gd). This script reports:
  * inline fallback literals in .gd files that duplicate or contradict a merge default,
  * game_config.json keys that merely restate a default (or are unknown),
  * pack_resources.json creature_motor_v3 overlay keys that restate a default.

Usage:
  python tools/audit_default_duplicates.py [--json out.json]

Always exits 0 (report only). Stdlib only.

Known limits (line/regex based, not a GDScript parser):
  * Merge defaults are read from lines shaped like `"key": <scalar literal>,` inside the
    default functions; keys of multi-line nested dicts are also collected (flat),
    and list/dict values are recorded as non-scalar (never compared).
  * Fallback sites are found by `<name containing "get">("key", <literal>)` on one line.
    Expressions (`0.25 * x`), constants and multi-line calls are not seen.
  * A key may exist in several default dicts (e.g. v3 core vs explore-inventory) with different values; a
    literal is DUPLICATE_SAME if it equals ANY of them, CONFLICT only if it equals none.
  * Keys are matched by name only, so unrelated dictionaries sharing a key name (`count`,
    `seed`) show up as NO_DEFAULT/CONFLICT noise.
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MERGE_PATH = ROOT / "AI_int_lib" / "game_config_merge.gd"
SKIP_DIRS = {".git", ".godot", "addons", "tests"}

# merge function -> game_config.json section it feeds.
FUNC_SECTION = {
  "default_logging_params": "logging_params",
  "default_perception_params": "perception",
  "default_playfield_spawn_params": "playfield_spawn",
  "default_creature_motor_v3_params": "creature_motor_v3",
  "default_creature_motor_v3_explore_inventory_params": "creature_motor_v3",
}

NUM = r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"
LIT = rf'(?:{NUM}|true|false|"[^"\\]*"|\[\s*\]|\{{\s*\}})'
NONSCALAR = object()

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(")
PAIR_RE = re.compile(rf'^\s*"([^"]+)"\s*:\s*({LIT})\s*,?\s*$')
PAIR_OPEN_RE = re.compile(r'^\s*"([^"]+)"\s*:\s*[\[{]')
SITE_RE = re.compile(rf'\b\w*get\w*\(\s*&?"([^"]+)"\s*,\s*({LIT})\s*[,)]')


def strip_comment(line: str) -> str:
  """Remove a trailing `#` comment, ignoring `#` inside double-quoted strings."""
  in_str = False
  i = 0
  while i < len(line):
    c = line[i]
    if c == "\\" and in_str:
      i += 2
      continue
    if c == '"':
      in_str = not in_str
    elif c == "#" and not in_str:
      return line[:i]
    i += 1
  return line


def parse_literal(text: str):
  """Parse a GDScript scalar literal into a Python value (list/dict -> [] / {})."""
  t = text.strip()
  if t == "true":
    return True
  if t == "false":
    return False
  if t.startswith('"'):
    return t[1:-1]
  if t.startswith("["):
    return []
  if t.startswith("{"):
    return {}
  if re.fullmatch(r"-?\d+", t):
    return int(t)
  return float(t)


def is_zero_or_empty(v) -> bool:
  """True for the 'missing key' fallbacks: 0 / 0.0 / false / "" / [] / {}."""
  if isinstance(v, bool):
    return v is False
  if isinstance(v, (int, float)):
    return v == 0
  return v in ("", [], {})


def values_equal(a, b) -> bool:
  """Equality that keeps bool distinct from numbers."""
  if isinstance(a, bool) or isinstance(b, bool):
    return isinstance(a, bool) and isinstance(b, bool) and a == b
  if isinstance(a, (int, float)) and isinstance(b, (int, float)):
    return float(a) == float(b)
  return a == b


def fmt(v) -> str:
  """Compact display of a value."""
  if isinstance(v, bool):
    return "true" if v else "false"
  if isinstance(v, float) and abs(v) < 1e15 and v == int(v):
    return f"{v:.1f}"
  return json.dumps(v) if isinstance(v, str) else str(v)


def load_merge_defaults():
  """Return {func: {key: value|NONSCALAR}} and {key: [(func, value), ...]}."""
  per_func: dict[str, dict] = {}
  by_key: dict[str, list] = defaultdict(list)
  current = None
  for raw in MERGE_PATH.read_text(encoding="utf-8", errors="replace").splitlines():
    m = FUNC_RE.match(raw)
    if m:
      current = m.group(1) if m.group(1) in FUNC_SECTION else None
      if current:
        per_func[current] = {}
      continue
    if current is None:
      continue
    line = strip_comment(raw)
    pm = PAIR_RE.match(line)
    if pm:
      val = parse_literal(pm.group(2))
    elif PAIR_OPEN_RE.match(line):
      pm = PAIR_OPEN_RE.match(line)
      val = NONSCALAR
    else:
      continue
    key = pm.group(1)
    per_func[current][key] = val
    by_key[key].append((current, val))
  return per_func, by_key


def scan_gd_sites():
  """Yield (relpath, lineno, key, literal_text, value) for each inline fallback site."""
  for path in sorted(ROOT.rglob("*.gd")):
    parts = set(path.relative_to(ROOT).parts)
    if parts & SKIP_DIRS or path == MERGE_PATH:
      continue
    rel = path.relative_to(ROOT).as_posix()
    for n, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
      line = strip_comment(raw)
      for m in SITE_RE.finditer(line):
        yield rel, n, m.group(1), m.group(2), parse_literal(m.group(2))


def classify_sites(by_key):
  """Classify fallback sites; returns dict of category -> list/stat."""
  out = {
    "CONFLICT": [], "DUPLICATE_SAME": [], "NO_DEFAULT": defaultdict(list),
    "IGNORED_ZERO_OR_EMPTY": 0, "IGNORED_ZERO_WITH_NONZERO_DEFAULT": 0,
  }
  all_sites = defaultdict(list)
  for rel, n, key, lit, val in scan_gd_sites():
    all_sites[key].append((rel, n, lit, val))
    defaults = [(f, v) for f, v in by_key.get(key, []) if v is not NONSCALAR]
    if is_zero_or_empty(val):
      out["IGNORED_ZERO_OR_EMPTY"] += 1
      if any(not is_zero_or_empty(v) for _, v in defaults):
        out["IGNORED_ZERO_WITH_NONZERO_DEFAULT"] += 1
      continue
    if not defaults:
      if key not in by_key:
        out["NO_DEFAULT"][key].append((rel, n, lit))
      continue
    if any(values_equal(val, v) for _, v in defaults):
      out["DUPLICATE_SAME"].append((rel, n, key, lit, defaults))
    else:
      out["CONFLICT"].append((rel, n, key, lit, defaults))
  repeats = {}
  for key, sites in all_sites.items():
    if len(sites) > 1:
      distinct = {
        (float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else repr(v))
        for _, _, _, v in sites}
      if len(distinct) > 1:
        repeats[key] = sites
  return out, repeats


def audit_overlay(label: str, section: str, data: dict, per_func, by_key, hits):
  """Compare one overlay dict against the section's defaults; append to hits."""
  sec_keys = {}
  for f, d in per_func.items():
    if FUNC_SECTION[f] == section:
      for k, v in d.items():
        sec_keys.setdefault(k, []).append((f, v))
  for key, val in data.items():
    if key not in sec_keys:
      hits["unknown"].append((label, section, key, val))
      continue
    for f, dv in sec_keys[key]:
      if dv is not NONSCALAR and values_equal(val, dv):
        hits["restates"].append((label, section, key, val, f))
        break


def main() -> int:
  args = sys.argv[1:]
  json_out = None
  if "--json" in args:
    i = args.index("--json")
    json_out = args[i + 1] if i + 1 < len(args) else None

  per_func, by_key = load_merge_defaults()
  sites, repeats = classify_sites(by_key)

  cfg_hits = {"restates": [], "unknown": []}
  cfg_path = ROOT / "game_config.json"
  if cfg_path.exists():
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    for section, body in cfg.items():
      if section not in set(FUNC_SECTION.values()):
        cfg_hits["unknown"].append(("game_config.json", "<root>", section, "<section>"))
      elif isinstance(body, dict):
        audit_overlay("game_config.json", section, body, per_func, by_key, cfg_hits)

  pack_hits = {"restates": [], "unknown": []}
  for p in sorted((ROOT / "assets" / "creatures").glob("*/pack_resources.json")):
    rel = p.relative_to(ROOT).as_posix()
    try:
      data = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
      print(f"WARN: cannot parse {rel}: {exc}")
      continue
    for section in ("creature_motor_v3",):
      if isinstance(data.get(section), dict):
        audit_overlay(rel, section, data[section], per_func, by_key, pack_hits)

  n_defaults = sum(len(d) for d in per_func.values())
  print("=== Default-duplicate audit (CBD-1) ===")
  print(f"merge default functions parsed: {len(per_func)}  keys: {n_defaults}")
  print("--- counts ---")
  print(f"CONFLICT:               {len(sites['CONFLICT'])}")
  print(f"DUPLICATE_SAME:         {len(sites['DUPLICATE_SAME'])}")
  print(f"NO_DEFAULT (sites):     {sum(len(v) for v in sites['NO_DEFAULT'].values())}"
        f"  ({len(sites['NO_DEFAULT'])} keys)")
  print(f"IGNORED_ZERO_OR_EMPTY:  {sites['IGNORED_ZERO_OR_EMPTY']}"
        f"  (of which key has a non-zero default: {sites['IGNORED_ZERO_WITH_NONZERO_DEFAULT']})")
  print(f"RESTATES_DEFAULT (game_config.json): {len(cfg_hits['restates'])}")
  print(f"UNKNOWN_KEY (game_config.json):      {len(cfg_hits['unknown'])}")
  print(f"PACK_RESTATES_DEFAULT:  {len(pack_hits['restates'])}")
  print(f"PACK_UNKNOWN_KEY:       {len(pack_hits['unknown'])}")
  print(f"REPEATED_KEY_DIFFERING_LITERALS: {len(repeats)}")

  def defs(d):
    return ", ".join(f"{fmt(v)} [{f}]" for f, v in d)

  print("\n--- CONFLICT (literal differs from merge default) ---")
  for rel, n, key, lit, d in sites["CONFLICT"]:
    print(f"{rel}:{n} {key} {lit} vs {defs(d)}")
  print("\n--- DUPLICATE_SAME (literal equals merge default) ---")
  for rel, n, key, lit, d in sites["DUPLICATE_SAME"]:
    print(f"{rel}:{n} {key} {lit} vs {defs(d)}")
  print("\n--- RESTATES_DEFAULT (game_config.json) ---")
  for label, sec, key, val, f in cfg_hits["restates"]:
    print(f"{label} {sec}.{key} {fmt(val)} vs default in {f}")
  print("\n--- UNKNOWN_KEY (game_config.json) ---")
  for label, sec, key, val in cfg_hits["unknown"]:
    print(f"{label} {sec}.{key}")
  print("\n--- PACK_RESTATES_DEFAULT ---")
  for label, sec, key, val, f in pack_hits["restates"]:
    print(f"{label} {sec}.{key} {fmt(val)} vs default in {f}")
  print("\n--- PACK_UNKNOWN_KEY (no global default; pack-only knob) ---")
  by_pack_key = defaultdict(list)
  for label, sec, key, val in pack_hits["unknown"]:
    by_pack_key[(sec, key)].append(label.split("/")[2])
  for (sec, key), packs in sorted(by_pack_key.items()):
    print(f"{sec}.{key} packs={','.join(packs)}")
  print("\n--- REPEATED key with differing inline literals ---")
  for key, ss in sorted(repeats.items()):
    lits = sorted({fmt(v) for _, _, _, v in ss})
    print(f"{key}: {len(ss)} sites, literals {', '.join(lits)}")
  print("\n--- NO_DEFAULT grouped by key (non-zero literals; sites) ---")
  for key, ss in sorted(sites["NO_DEFAULT"].items(), key=lambda kv: (-len(kv[1]), kv[0])):
    lits = sorted({lit for _, _, lit in ss})
    first = f"{ss[0][0]}:{ss[0][1]}"
    print(f"{key}: {len(ss)} site(s), literals {', '.join(lits)}  e.g. {first}")

  if json_out:
    report = {
      "conflict": [
        {"file": r, "line": n, "key": k, "literal": l, "defaults": [[f, fmt(v)] for f, v in d]}
        for r, n, k, l, d in sites["CONFLICT"]],
      "duplicate_same": [
        {"file": r, "line": n, "key": k, "literal": l} for r, n, k, l, _ in sites["DUPLICATE_SAME"]],
      "no_default": {k: [{"file": r, "line": n, "literal": l} for r, n, l in v]
                     for k, v in sites["NO_DEFAULT"].items()},
      "ignored_zero_or_empty": sites["IGNORED_ZERO_OR_EMPTY"],
      "config_restates": [list(map(str, h)) for h in cfg_hits["restates"]],
      "config_unknown": [list(map(str, h)) for h in cfg_hits["unknown"]],
      "pack_restates": [list(map(str, h)) for h in pack_hits["restates"]],
      "pack_unknown": [list(map(str, h)) for h in pack_hits["unknown"]],
      "repeated_differing": {k: [[r, n, l] for r, n, l, _ in v] for k, v in repeats.items()},
    }
    Path(json_out).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nJSON written to {json_out}")
  return 0


if __name__ == "__main__":
  sys.exit(main())
