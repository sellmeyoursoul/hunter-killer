# GDScript 4 rules (Godot 4.7) for the worker

Read before writing any `.gd` code. These are hard rules; `verify` rejects violations.

## Format
- Indent with exactly 2 spaces per level. The tab character is forbidden everywhere in `.gd` files. No trailing whitespace.
- Match the style of the file you are editing; read it first.

## Godot 4 syntax only (not Godot 3, not Python, not C#)
- `@export var`, `@onready var`, `@tool`. Never `export`, `onready`, `tool`, `setget`.
- `await x` (never `yield`). Signals: `sig.connect(callable)`, `sig.emit(args)`; never `connect("sig", obj, "method")`.
- `Time.get_ticks_msec()` (not `OS.get_ticks_msec()`); `Scene.instantiate()` (not `.instance()`).
- There are NO access keywords: never write `private`, `public`, `protected`. Private members just start with `_`.
- `extends` is the first line, then optional `class_name`. Names of methods, groups and actions are `StringName` literals: `&"name"`.

## Types and math
- Type every function parameter and return. Declare locals with an explicit type (`var x: int = 0`) or infer with `:=` ONLY when the right-hand side has a known static type (a constructor, `float(...)`, `clampf(...)`, a typed function result).
- NEVER use `:=` on a value read from a Dictionary or untyped Array (`d.get(...)`, `d[...]`, loop variables over an `Array`): it is a Variant and fails to parse. Give it an explicit type (`var p: Vector3 = s.get("pos", Vector3.ZERO)`) or wrap it (`float(d.get("k", 0.0))`).
- Typed math helpers: `clampf maxf minf lerpf absf floorf roundf` (floats), `clampi maxi mini absi` (ints). Float literals: `0.0`, `1.0`, `100.0`.
- Dictionary reads always supply a default: `float(d.get("key", 0.0))`, `int(d.get("n", 0))`, `bool(d.get("flag", false))`.

## Comments
- Put `##` doc comments on the lines directly ABOVE a `func`/`var`/`signal`, never inside the body. Order: purpose, `[param name]: ...`, what is returned, `Example: ...` when non-obvious. Use `#` for ordinary comments.
- Never use Python-style `"""docstrings"""`.

## Project conventions
- `static func` for pure helpers. Early `return`/`continue` instead of deep nesting.
- Constants and preloads at the top: `const _Name := preload("res://path/file.gd")`.
- Log through the project's logging helper, not bare `print` (see `oLog_lib/CLAUDE.md`).

## Example of correct style (2-space indent, doc comments above, typed Variants)
```gdscript
extends RefCounted
class_name ExampleScoring
## Small pure helpers for scoring. (Illustrative example; not a real project file.)

const _Helper := preload("res://example/helper.gd")

## Scales a base value by a level in [-100, 100]; never negative.
## [param traits]: dictionary; `level` in [-100, 100], missing = 0.
## [param cfg]: dictionary; `base` (default 2.0).
## Returns the scaled value.
## Example: level 0 -> 2.0.
static func scaled_value(traits: Dictionary, cfg: Dictionary) -> float:
  var base := float(cfg.get("base", 2.0))
  var level := float(traits.get("level", 0.0))
  var t := clampf((level + 100.0) / 200.0, 0.0, 1.0)
  return maxf(0.0, base * lerpf(0.5, 1.5, t))


## Positions of every dictionary sample whose `active` flag is true.
## [param samples]: array of dictionaries; non-dictionaries are skipped.
## Returns the positions.
static func active_positions(samples: Array) -> Array[Vector3]:
  var out: Array[Vector3] = []
  for s_v in samples:
    if typeof(s_v) != TYPE_DICTIONARY:
      continue
    var s: Dictionary = s_v
    if not bool(s.get("active", false)):
      continue
    var p: Vector3 = s.get("pos", Vector3.ZERO)
    out.append(p)
  return out
```

```gdscript
extends Node
class_name ExampleMarker
## Illustrative Node script: signals, exports, onready, connect.

## Emitted after the marker moves.
signal moved(new_pos: Vector3)

## Distance moved per step.
@export var step: float = 1.0

@onready var _timer: Timer = $Timer

var _steps_taken: int = 0


func _ready() -> void:
  _timer.timeout.connect(_on_timer_timeout)


## Whether at least one step has been taken.
func has_moved() -> bool:
  return _steps_taken > 0


func _on_timer_timeout() -> void:
  _steps_taken += 1
  moved.emit(Vector3(step * _steps_taken, 0.0, 0.0))
```

## Scope (applies to every task)
- Edit only the files and functions listed in the task packet's scope. Do not change function signatures, rename things, reformat untouched code, or edit tests unless the packet says so.
- If anything is ambiguous or contradictory, do not guess: stop and report `STOP: <reason>` with no edits.
- Final check before you finish: every indent in your code is spaces, never a tab.
