#!/usr/bin/env python3
"""verify - mechanical authenticator for worker task packets (no model involved).

    python verify.py --repo <repo> --packet <tasks/T-001.md> [--base <sha>] [--commit] [--recheck]
                     [--skip-tests] [--fast] [--no-fix] [--model hk-worker]

Reads the packet's ```toml scope block, compares the repo against the packet's base commit and runs:
  scope-files     every changed file is listed (edit/add); no deletions/renames; nothing protected touched
  tab-normalize   leading tabs -> 2 spaces in changed in-scope .gd files (logged; --no-fix disables)
  scope-functions hunks only touch the functions listed for each edited file
  line-cap        total added+removed lines <= max_changed_lines
  tab-gate        no tab character anywhere in changed .gd files
  parse           `godot --check-only` on each changed .gd file
  task-tests      the packet's scope.test_scripts (acceptance scripts), if any
  tests           tests/run_all.gd headless (exit code only)
and writes <repo>/.pipeline/receipts/<id>.receipt.json. Commits on PASS only with --commit.

Optional `[[premise]]` entries in the packet's toml block (path, contains, note) are facts the packet asserts about the base
commit; they are checked first, and a false one ends the run with a [STOP] line (the packet is wrong, not the worker).
With --fast (the worker's loop) it also keeps .pipeline/runs/<id>/history.jsonl and prints, after RESULT, lines that tell the
worker when to STOP: [ROUNDS] n of 3, [HINT] for a repeated failure or an acceptance script that loads a protected file,
[STOP] when 3 fix rounds are used. A run on a tree equal to base clears the history.

Exit codes: 0 PASS, 1 FAIL, 2 NO_CHANGE, 3 INCOMPLETE (a check was skipped), 4 usage/packet error.
Only a PASS produced by running this script counts; a worker-written receipt is never trusted
(--recheck compares the receipt's diff hash to the current working tree).
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import tomllib
import urllib.request

GODOT = os.environ.get("GODOT_EXE", r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.exe")
PIPELINE_DIR = ".pipeline"  # verify-owned output; excluded from the scope diff
DEFAULT_PROTECTED = ["tests/", "project.godot", "addons/", ".godot/", "pipeline/", "tasks/", ".git/", ".pipeline/"]
TOP = "<top-level>"


# ---------------------------------------------------------------- helpers
def run(cmd, cwd, timeout=900):
  return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)


def git(repo, *args, check=True):
  p = run(["git", *args], repo)
  if check and p.returncode != 0:
    raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr.strip()}")
  return p.stdout


def sha256_bytes(b):
  return hashlib.sha256(b).hexdigest()


def sha256_file(path):
  with open(path, "rb") as fh:
    return sha256_bytes(fh.read())


def is_protected(path, protected):
  for pr in protected:
    if pr.endswith("/"):
      if path.startswith(pr):
        return True
    elif path == pr:
      return True
  return False


# ---------------------------------------------------------------- packet
def parse_packet(path):
  text = open(path, encoding="utf-8").read()
  m = re.search(r"```toml\n(.*?)```", text, re.S)
  if not m:
    raise ValueError("packet has no ```toml block")
  data = tomllib.loads(m.group(1))
  if "id" not in data or "scope" not in data:
    raise ValueError("toml block needs `id` and a [scope] table")
  sc = data["scope"]
  edit = {}
  for e in sc.get("edit", []):
    if isinstance(e, str):
      edit[e] = None
    else:
      edit[e["path"]] = set(e["functions"]) if e.get("functions") else None
  data["_edit"] = edit
  data["_add"] = set(sc.get("add", []))
  data["_protected"] = list(dict.fromkeys(DEFAULT_PROTECTED + sc.get("protected", [])))
  data["_max_lines"] = int(sc.get("max_changed_lines", 100))
  data["_test_scripts"] = list(sc.get("test_scripts", []))
  data["_premises"] = list(data.get("premise", []))
  data["_scope_protected"] = list(sc.get("protected", []))  # packet-declared only; DEFAULT_PROTECTED would flag every test helper
  return data


# ---------------------------------------------------------------- change set
def changed_files(repo, base):
  """path -> status (M, A, D, ?). Includes committed-since-base, staged, unstaged and untracked files."""
  out = {}
  for line in git(repo, "diff", "--name-status", "--no-renames", base).splitlines():
    st, _, path = line.partition("\t")
    out[path.strip()] = st.strip()[0]
  for path in git(repo, "ls-files", "--others", "--exclude-standard").splitlines():
    out.setdefault(path.strip(), "?")
  out = {p: s for p, s in out.items() if not p.startswith(PIPELINE_DIR + "/")}
  # Godot 4.4+ writes <script>.gd.uid next to every script it scans (editor, import, even a headless run).
  # An untracked sidecar whose script exists is bookkeeping, not a change; an orphan one is still reported.
  return {p: s for p, s in out.items()
          if not (p.endswith(".gd.uid") and s == "?" and os.path.exists(os.path.join(repo, p[:-4])))}


# ---------------------------------------------------------------- GDScript function map
def function_owner_map(lines):
  """Return a list: for each line index, the owning top-level function name or TOP."""
  n = len(lines)
  starts = [i for i, ln in enumerate(lines) if ln and ln[0] not in " \t)]}"]
  items = []  # (start, end_exclusive, kind, name)
  for k, s in enumerate(starts):
    e = starts[k + 1] if k + 1 < len(starts) else n
    mfunc = re.match(r"(?:static\s+)?func\s+(\w+)", lines[s])
    if mfunc:
      items.append([s, e, "func", mfunc.group(1)])
    elif lines[s].startswith("#"):
      items.append([s, e, "comment", None])
    else:
      items.append([s, e, "other", None])
  owner = [TOP] * n
  for k, (s, e, kind, name) in enumerate(items):
    if kind != "func":
      continue
    for i in range(s, e):
      owner[i] = name
    # doc-comment block directly above (no blank line between) belongs to the function
    j = k - 1
    while j >= 0 and items[j][2] == "comment" and items[j][1] == items[j + 1][0] and \
        (items[j][1] - 1 >= items[j][0]) and lines[items[j][1] - 1].strip() != "":
      for i in range(items[j][0], items[j][1]):
        owner[i] = name
      j -= 1
  return owner


def read_lines(text):
  return text.replace("\r\n", "\n").replace("\r", "\n").split("\n")


# ---------------------------------------------------------------- checks
class Result:
  def __init__(self, name, status, detail=""):
    self.name, self.status, self.detail = name, status, detail  # status: PASS FAIL SKIPPED

  def as_dict(self):
    return {"name": self.name, "status": self.status, "detail": self.detail}


def check_scope_files(changes, pk):
  bad = []
  for path, st in sorted(changes.items()):
    if is_protected(path, pk["_protected"]):
      bad.append(f"protected path touched: {path} ({st})")
    elif st == "D":
      bad.append(f"deleted: {path}")
    elif st == "M":
      if path not in pk["_edit"]:
        bad.append(f"modified but not listed in scope.edit: {path}")
    elif st in ("A", "?"):
      if path not in pk["_add"]:
        bad.append(f"new file not listed in scope.add: {path}")
  for path in pk["_add"]:
    if changes.get(path) == "M":
      bad.append(f"listed in scope.add but already exists at base: {path}")
  if bad:
    return Result("scope-files", "FAIL", "\n".join(bad))
  return Result("scope-files", "PASS", f"{len(changes)} changed file(s), all in scope")


def normalize_tabs(repo, changes, pk, fix):
  touched = []
  for path, st in sorted(changes.items()):
    if not path.endswith(".gd") or st == "D" or is_protected(path, pk["_protected"]):
      continue
    full = os.path.join(repo, path)
    if not os.path.exists(full):
      continue
    with open(full, encoding="utf-8", newline="") as fh:
      text = fh.read()
    out, n = [], 0
    for ln in text.splitlines(keepends=True):
      m = re.match(r"^[ \t]+", ln)
      if m and "\t" in m.group(0):
        ln = m.group(0).replace("\t", "  ") + ln[m.end():]
        n += 1
      out.append(ln)
    if n:
      touched.append((path, n))
      if fix:
        with open(full, "w", encoding="utf-8", newline="") as fh:
          fh.write("".join(out))
  if not touched:
    return Result("tab-normalize", "PASS", "no leading tabs found"), []
  desc = ", ".join(f"{p} ({n} line(s))" for p, n in touched)
  if fix:
    return Result("tab-normalize", "PASS", f"converted leading tabs to 2 spaces: {desc}"), [p for p, _ in touched]
  return Result("tab-normalize", "FAIL", f"leading tabs present (--no-fix): {desc}"), []


def diff_hunks(repo, base, path):
  """Yield (sign, line_no, text) for each added/removed line of one file."""
  out = git(repo, "diff", "-U0", "--no-color", "--no-renames", base, "--", path)
  old_no = new_no = 0
  for ln in out.splitlines():
    m = re.match(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", ln)
    if m:
      old_no, new_no = int(m.group(1)), int(m.group(3))
      continue
    if ln.startswith("---") or ln.startswith("+++") or ln.startswith("diff ") or ln.startswith("index "):
      continue
    if ln.startswith("-"):
      yield "-", old_no, ln[1:]
      old_no += 1
    elif ln.startswith("+"):
      yield "+", new_no, ln[1:]
      new_no += 1


def check_scope_functions(repo, base, changes, pk):
  problems, notes = [], []
  for path, allowed in pk["_edit"].items():
    if changes.get(path) != "M" or not allowed:
      continue
    old_lines = read_lines(git(repo, "show", f"{base}:{path}"))
    with open(os.path.join(repo, path), encoding="utf-8", newline="") as fh:
      new_lines = read_lines(fh.read())
    old_map, new_map = function_owner_map(old_lines), function_owner_map(new_lines)
    touched = set()
    for sign, no, text in diff_hunks(repo, base, path):
      if not text.strip():
        continue  # whitespace-only lines do not count
      mp = old_map if sign == "-" else new_map
      name = mp[no - 1] if 0 < no <= len(mp) else TOP
      touched.add(name)
      if name not in allowed:
        problems.append(f"{path}:{no}: '{sign}' line is in {name!r}, allowed only {sorted(allowed)}")
    notes.append(f"{path}: touched {sorted(touched)}")
  if problems:
    shown = problems[:12] + ([f"... and {len(problems) - 12} more"] if len(problems) > 12 else [])
    return Result("scope-functions", "FAIL", "\n".join(shown))
  return Result("scope-functions", "PASS", "; ".join(notes) if notes else "no function-scoped files changed")


def count_changed_lines(repo, base, changes):
  total = 0
  for path, st in changes.items():
    if st == "?":
      full = os.path.join(repo, path)
      if os.path.isfile(full):
        with open(full, encoding="utf-8", errors="replace") as fh:
          total += sum(1 for _ in fh)
  num = git(repo, "diff", "--numstat", "--no-renames", base)
  for line in num.splitlines():
    a, r, path = line.split("\t", 2)
    if path.startswith(PIPELINE_DIR + "/"):
      continue
    if a != "-":
      total += int(a) + int(r)
  return total


def check_line_cap(repo, base, changes, pk):
  total = count_changed_lines(repo, base, changes)
  if total > pk["_max_lines"]:
    return Result("line-cap", "FAIL", f"{total} changed lines > max_changed_lines {pk['_max_lines']}")
  return Result("line-cap", "PASS", f"{total} changed lines <= {pk['_max_lines']}")


def check_tab_gate(repo, changes):
  bad = []
  for path, st in sorted(changes.items()):
    if path.endswith(".gd") and st != "D" and os.path.exists(os.path.join(repo, path)):
      with open(os.path.join(repo, path), encoding="utf-8", errors="replace", newline="") as fh:
        n = fh.read().count("\t")
      if n:
        bad.append(f"{path}: {n} tab character(s)")
  if bad:
    return Result("tab-gate", "FAIL", "\n".join(bad))
  return Result("tab-gate", "PASS", "no tab characters in changed .gd files")


def autoload_names(repo):
  """Names in project.godot's [autoload] section. Script mode has no autoloads, so a file that merely
  mentions one (e.g. OLog) reports `Identifier not found: <name>` even though its syntax is fine."""
  names, inside = set(), False
  try:
    with open(os.path.join(repo, "project.godot"), encoding="utf-8") as fh:
      for ln in fh:
        s = ln.strip()
        if s.startswith("["):
          inside = s == "[autoload]"
        elif inside and "=" in s:
          names.add(s.split("=", 1)[0].strip())
  except OSError:
    pass
  return names


def check_parse(repo, changes):
  bad, count, deferred = [], 0, []
  autoloads = autoload_names(repo)
  for path, st in sorted(changes.items()):
    full = os.path.join(repo, path)
    if not path.endswith(".gd") or st == "D" or not os.path.exists(full):
      continue
    count += 1
    # res:// path, not the filesystem path: mixed separators make Godot report `class_name` files as
    # "hides a global script class".
    p = run([GODOT, "--headless", "--path", repo, "--check-only", "--script", "res://" + path.replace("\\", "/")], repo, timeout=180)
    if p.returncode == 0:
      continue
    out = p.stdout + p.stderr
    # Godot reports syntax problems as "Parse Error" before it resolves identifiers ("Compile Error").
    errors = re.findall(r"SCRIPT ERROR: (Parse Error|Compile Error): (.*)", out)
    real = []
    for kind, msg in errors:
      m = re.match(r"Identifier not found: (\w+)", msg)
      if kind == "Compile Error" and m and m.group(1) in autoloads:
        deferred.append(f"{path} ({m.group(1)})")
      else:
        real.append(f"{kind}: {msg[:130]}")
    if real or not errors:
      bad.append(f"{path}: exit {p.returncode}: " + ("; ".join(real) if real else "unrecognised godot output"))
  if bad:
    return Result("parse", "FAIL", "\n".join(bad))
  note = f"; autoload-dependent (syntax OK, identifiers left to the tests): {', '.join(sorted(set(deferred)))}" if deferred else ""
  return Result("parse", "PASS", f"{count} .gd file(s) parse{note}")


def check_task_tests(repo, scripts, outdir):
  """Run the packet's own acceptance scripts (`godot -s <script>`): fast feedback before the full suite."""
  os.makedirs(outdir, exist_ok=True)
  failed, ran = [], 0
  for i, script in enumerate(scripts):
    ran += 1
    p = run([GODOT, "--path", repo, "--headless", "-s", script], repo, timeout=600)
    out = p.stdout + "\n--- stderr ---\n" + p.stderr
    with open(os.path.join(outdir, f"task_test_{i}.txt"), "w", encoding="utf-8") as fh:
      fh.write(out)
    if p.returncode != 0:
      lines = [ln for ln in out.splitlines() if "ASSERT:" in ln or "SCRIPT ERROR" in ln or "ERROR:" in ln]
      failed.append(f"{script}: exit {p.returncode}" + "".join("\n    " + ln.strip()[:160] for ln in lines[:8]))
  if failed:
    return Result("task-tests", "FAIL", "\n".join(failed))
  return Result("task-tests", "PASS", f"{ran} acceptance script(s) pass")


def check_tests(repo, outdir):
  os.makedirs(outdir, exist_ok=True)
  logf = os.path.join(outdir, "tests_output.txt")
  t0 = time.time()
  p = run([GODOT, "--path", repo, "--headless", "-s", "res://tests/run_all.gd"], repo, timeout=1200)
  with open(logf, "w", encoding="utf-8") as fh:
    fh.write(p.stdout + "\n--- stderr ---\n" + p.stderr)
  asserts = [ln for ln in (p.stdout + p.stderr).splitlines() if "ASSERT:" in ln]
  dur = int(time.time() - t0)
  if p.returncode != 0:
    return Result("tests", "FAIL", f"exit {p.returncode} after {dur}s; {len(asserts)} failed assertion(s):\n" + "\n".join(asserts[:10]) + f"\n(full output: {logf})")
  return Result("tests", "PASS", f"exit 0 in {dur}s, 0 failed assertions")


# ---------------------------------------------------------------- premises, fix rounds, STOP hints
MAX_FIX_ROUNDS = 3  # keep in step with pipeline/WORKER_RULES.md step 4


def check_premises(repo, base, pk):
  """Facts the packet asserts about the base commit (`[[premise]]` entries: path + contains). A false one means the
  packet is wrong, not the worker: no amount of editing inside the scope can fix it."""
  bad = []
  for pr in pk["_premises"]:
    path, needle = pr["path"], pr["contains"]
    try:
      text = git(repo, "show", f"{base}:{path}")
    except RuntimeError:
      bad.append(f"{path} does not exist at base (the packet says {pr.get('note', repr(needle))})")
      continue
    if needle not in text:
      bad.append(f"{path} does not contain {needle!r} (the packet says {pr.get('note', 'it does')})")
  if bad:
    return Result("premise", "FAIL", "\n".join(bad))
  return Result("premise", "PASS", f"{len(pk['_premises'])} packet claim(s) hold at base")


def failure_signature(results):
  """Stable text for 'what failed': FAIL check names + details with numbers masked (line numbers shift as the worker edits)."""
  return "\n".join(f"{r.name}: {re.sub(r'[0-9]+', '#', r.detail)}" for r in results if r.status == "FAIL")


def history_path(repo, task_id):
  return os.path.join(repo, PIPELINE_DIR, "runs", task_id, "history.jsonl")


def load_history(repo, task_id):
  try:
    with open(history_path(repo, task_id), encoding="utf-8") as fh:
      return [json.loads(ln) for ln in fh if ln.strip()]
  except OSError:
    return []


def append_history(repo, task_id, entry):
  path = history_path(repo, task_id)
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(entry) + "\n")


def clear_history(repo, task_id):
  try:
    os.remove(history_path(repo, task_id))
  except OSError:
    pass


def stop_messages(repo, pk, results, history, overall):
  """Lines that tell a worker, mechanically, when WORKER_RULES step 6 applies. `history` includes the current run."""
  out = []
  if overall != "FAIL":
    return out
  used = max(0, len(history) - 1)  # the first run is not a fix round
  streak = 0
  for h in reversed(history):
    if h["signature"] != history[-1]["signature"]:
      break
    streak += 1
  if any(r.name == "premise" and r.status == "FAIL" for r in results):
    out.append('[STOP] The packet states something that is not true of the repository (see the premise line above). Fixing it is not '
               'within your scope: make no edits and reply "STOP: <reason>" (rule 6).')
    return out
  if used:
    out.append(f"[ROUNDS] {min(used, MAX_FIX_ROUNDS)} of {MAX_FIX_ROUNDS} fix rounds used")
  protected = pk["_scope_protected"]
  for r in results:
    if r.name == "task-tests" and r.status == "FAIL":
      loaded = set()
      for script in pk["_test_scripts"]:
        try:
          with open(os.path.join(repo, script.replace("res://", "")), encoding="utf-8") as fh:
            src = fh.read()
        except OSError:
          continue
        loaded |= {p for p in re.findall(r'(?:preload|load)\("res://([^"]+)"\)', src) if is_protected(p, protected)}
      if loaded:
        out.append(f"[HINT] The failing acceptance script loads protected file(s): {', '.join(sorted(loaded))}. If the failing assertion needs "
                   'a change there, it cannot pass within your scope: do not edit them, reply "STOP: <reason>" (rule 6).')
  if streak >= 2:
    out.append(f"[HINT] The same failure has now appeared {streak} times in a row. If the cause is outside your scope (a protected file, "
               'or something the packet says exists but is missing), reply "STOP: <reason>" (rule 6) instead of trying again.')
  if used >= MAX_FIX_ROUNDS:
    out.append(f'[STOP] {MAX_FIX_ROUNDS} fix rounds are used and verify still reports FAIL. Make no further edits and reply "STOP: <reason>" (rule 6).')
  return out


# ---------------------------------------------------------------- hashes / receipt
def diff_hash(repo, changes):
  h = hashlib.sha256()
  for path in sorted(changes):
    full = os.path.join(repo, path)
    h.update(path.encode() + b"\0" + changes[path].encode() + b"\0")
    h.update(sha256_file(full).encode() if os.path.isfile(full) else b"DELETED")
    h.update(b"\n")
  return h.hexdigest()


def tree_hash(repo, protected):
  h = hashlib.sha256()
  for pr in sorted(protected):
    full = os.path.join(repo, pr.rstrip("/"))
    if os.path.isdir(full) and pr.endswith("/") and pr not in (".git/", ".godot/", ".pipeline/"):
      for root, dirs, files in os.walk(full):
        dirs[:] = sorted(d for d in dirs if d not in (".git", ".godot"))
        for f in sorted(files):
          fp = os.path.join(root, f)
          h.update(os.path.relpath(fp, repo).replace("\\", "/").encode() + b"\0" + sha256_file(fp).encode() + b"\n")
    elif os.path.isfile(full):
      h.update(pr.encode() + b"\0" + sha256_file(full).encode() + b"\n")
  return h.hexdigest()


def model_info(alias):
  try:
    with urllib.request.urlopen("http://localhost:11434/api/tags", timeout=5) as r:
      for m in json.load(r)["models"]:
        if m["name"] in (alias, alias + ":latest"):
          return {"alias": alias, "digest": m["digest"][:12]}
  except Exception as exc:  # noqa: BLE001 - informational only
    return {"alias": alias, "digest": f"unavailable ({exc.__class__.__name__})"}
  return {"alias": alias, "digest": "not found"}


# ---------------------------------------------------------------- main
def main():
  ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  ap.add_argument("--repo", required=True)
  ap.add_argument("--packet", required=True)
  ap.add_argument("--base", help="base commit (default: `base` in the packet toml, else HEAD)")
  ap.add_argument("--commit", action="store_true", help="commit the in-scope files if the result is PASS")
  ap.add_argument("--recheck", action="store_true", help="also require the existing receipt's diff hash to match")
  ap.add_argument("--skip-tests", action="store_true", help="skip all test runs (result becomes INCOMPLETE)")
  ap.add_argument("--fast", action="store_true", help="run the packet's acceptance scripts but not the full suite (result becomes INCOMPLETE; for the worker's retry loop)")
  ap.add_argument("--no-fix", action="store_true", help="do not normalise leading tabs")
  ap.add_argument("--model", help="worker alias to record in the receipt (e.g. hk-worker)")
  args = ap.parse_args()
  repo = os.path.abspath(args.repo)
  t_start = time.time()

  try:
    pk = parse_packet(args.packet)
  except Exception as exc:  # noqa: BLE001
    print(f"[ERROR] packet: {exc}")
    return 4
  task_id = pk["id"]
  base = args.base or pk.get("base") or "HEAD"
  try:
    base_sha = git(repo, "rev-parse", base).strip()
    head_sha = git(repo, "rev-parse", "HEAD").strip()
  except RuntimeError as exc:
    print(f"[ERROR] {exc}")
    return 4

  print(f"verify {task_id}: base {base_sha[:10]} head {head_sha[:10]} repo {repo}")
  changes = changed_files(repo, base_sha)
  results = []
  if pk["_premises"]:
    pr = check_premises(repo, base_sha, pk)
    if pr.status == "FAIL":
      print(f"[FAIL] {pr.name}: {pr.detail.splitlines()[0]}")
      for extra in pr.detail.splitlines()[1:]:
        print(f"        {extra}")
      print("RESULT: FAIL")
      if args.fast:
        hist = load_history(repo, task_id) + [{"result": "FAIL", "signature": failure_signature([pr])}]
        append_history(repo, task_id, hist[-1])
        for line in stop_messages(repo, pk, [pr], hist, "FAIL"):
          print(line)
      return 1
    results.append(pr)
  if not changes:
    clear_history(repo, task_id)  # a tree equal to base is a fresh start
    print("RESULT: NO_CHANGE (no files changed relative to base; if the worker stopped, it should have said STOP: <reason>)")
    return 2

  r = check_scope_files(changes, pk)
  results.append(r)
  cheap_ok = r.status == "PASS"
  fixed = []
  if cheap_ok:
    r2, fixed = normalize_tabs(repo, changes, pk, not args.no_fix)
    results.append(r2)
    cheap_ok &= r2.status == "PASS"
    if fixed:
      changes = changed_files(repo, base_sha)  # content changed; recompute (same paths, same statuses)
  if cheap_ok:
    r = check_scope_functions(repo, base_sha, changes, pk)
    results.append(r)
    cheap_ok &= r.status == "PASS"
    r = check_line_cap(repo, base_sha, changes, pk)
    results.append(r)
    cheap_ok &= r.status == "PASS"
    r = check_tab_gate(repo, changes)
    results.append(r)
    cheap_ok &= r.status == "PASS"
  if cheap_ok:
    r = check_parse(repo, changes)
    results.append(r)
    cheap_ok &= r.status == "PASS"
  else:
    results.append(Result("parse", "SKIPPED", "an earlier check failed"))
  rundir = os.path.join(repo, PIPELINE_DIR, "runs", task_id)
  if cheap_ok and not args.skip_tests and pk["_test_scripts"]:
    r = check_task_tests(repo, pk["_test_scripts"], rundir)
    results.append(r)
    cheap_ok &= r.status == "PASS"
  if cheap_ok and not args.skip_tests and not args.fast:
    results.append(check_tests(repo, rundir))
  elif args.skip_tests:
    results.append(Result("tests", "SKIPPED", "--skip-tests"))
  elif args.fast and cheap_ok:
    results.append(Result("tests", "SKIPPED", "--fast: full suite not run"))
  else:
    results.append(Result("tests", "SKIPPED", "an earlier check failed"))

  dh = diff_hash(repo, changes)
  if args.recheck:
    rp = os.path.join(repo, PIPELINE_DIR, "receipts", f"{task_id}.receipt.json")
    try:
      old = json.load(open(rp, encoding="utf-8"))
      same = old.get("diff_hash") == dh
      results.append(Result("receipt-match", "PASS" if same else "FAIL",
                            "receipt diff hash matches the working tree" if same else
                            f"receipt diff hash {str(old.get('diff_hash'))[:12]} != current {dh[:12]} (changed after verification, or forged)"))
    except FileNotFoundError:
      results.append(Result("receipt-match", "FAIL", f"no receipt at {rp}"))

  any_fail = any(r.status == "FAIL" for r in results)
  skipped_tests = any(r.name == "tests" and r.status == "SKIPPED" for r in results) and not any_fail and (args.skip_tests or args.fast)
  overall = "FAIL" if any_fail else ("INCOMPLETE" if skipped_tests else "PASS")
  for r in results:
    print(f"[{r.status}] {r.name}: {r.detail.splitlines()[0] if r.detail else ''}")
    for extra in r.detail.splitlines()[1:]:
      print(f"        {extra}")
  print(f"RESULT: {overall}")
  if args.fast and not args.recheck:  # fix rounds are the worker's --fast loop; authenticating runs do not count
    entry = {"result": overall, "diff_hash": dh, "signature": failure_signature(results)}
    hist = load_history(repo, task_id) + [entry]
    append_history(repo, task_id, entry)
    for line in stop_messages(repo, pk, results, hist, overall):
      print(line)

  gv =run([GODOT, "--version"], repo).stdout.strip()
  receipt = {
    "id": task_id, "title": pk.get("title", ""), "result": overall,
    "time_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "duration_s": int(time.time() - t_start),
    "base": base_sha, "head": head_sha, "diff_hash": dh,
    "changed_files": changes, "tab_normalized": fixed,
    "protected_tree_hash": tree_hash(repo, pk["_protected"]),
    "verify_sha256": sha256_file(os.path.abspath(__file__)),
    "packet_sha256": sha256_file(args.packet), "godot": gv,
    "worker_model": model_info(args.model) if args.model else None,
    "checks": [r.as_dict() for r in results],
  }
  rdir = os.path.join(repo, PIPELINE_DIR, "receipts")
  os.makedirs(rdir, exist_ok=True)
  with open(os.path.join(rdir, f"{task_id}.receipt.json"), "w", encoding="utf-8") as fh:
    json.dump(receipt, fh, indent=2)

  if overall == "PASS" and args.commit:
    paths = sorted(p for p, s in changes.items() if s != "D")
    paths += [p + ".uid" for p in list(paths) if p.endswith(".gd") and os.path.exists(os.path.join(repo, p + ".uid"))]
    git(repo, "add", "--", *paths)
    msg = f"{task_id}: {pk.get('title', '').strip()}\n\nVerified by pipeline/verify (diff {dh[:12]}, base {base_sha[:10]})."
    git(repo, "commit", "-q", "-m", msg)
    print(f"committed {len(paths)} file(s): {git(repo, 'rev-parse', '--short', 'HEAD').strip()}")
  return {"PASS": 0, "FAIL": 1, "INCOMPLETE": 3}[overall]


if __name__ == "__main__":
  sys.exit(main())
