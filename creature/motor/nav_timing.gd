extends RefCounted
class_name NavTiming
## Per-creature navigation timing store (NAVIGATION_PASSABILITY_PLAN.md D29 / section 8.2.7 baseline).
##
## One instance per creature (owned by its [NavRouter]). Accumulates microseconds per component inside the
## current physics frame; when the physics frame advances (or on read) the frame is flushed into fixed-size
## ring buffers, one per component plus one for the per-frame total. Percentiles (p50 / p95 / max) are
## computed on read only, so recording stays O(1) and memory stays bounded by [constant WINDOW_FRAMES].
##
## Disabled by default: [member enabled] is a process-wide switch, and [method NavRouter.timing_begin] returns
## 0 without touching the clock when it is off, so the live game pays one static-bool read per call site.
## Tools / tests: `NavTiming.enabled = true`, run, `NavTiming.snapshot_all()`, `NavTiming.reset_all()`.
## Budget statistic is p95 (user decision 2026-10-08): read `snapshot()["total"]["p95_ms"]`.

## Self reference by path (a new class_name is not resolvable inside its own script on a stale class cache).
const _Self := preload("res://creature/motor/nav_timing.gd")

## Component slots. step_probe (T6b) and replan (T7) are reserved: nothing records into them yet.
const COMP_PATH_QUERY := &"path_query"
const COMP_GHOST_SCAN := &"ghost_scan"
const COMP_STEP_PROBE := &"step_probe"
const COMP_REPLAN := &"replan"
const COMPONENTS: Array[StringName] = [COMP_PATH_QUERY, COMP_GHOST_SCAN, COMP_STEP_PROBE, COMP_REPLAN]

## Ring-buffer length in physics frames (about 17 s at 60 Hz). Per creature: (components + 1) * N floats.
const WINDOW_FRAMES := 1024

## Process-wide switch. Default OFF in the live game; tests / tools set it true.
static var enabled: bool = false
## Registry of timing stores keyed by creature id; only populated while [member enabled] is true.
static var _registry: Dictionary = {}

## Stable creature id this store belongs to (body instance id, else router instance id).
var creature_id: int = 0
## Physics frame currently being accumulated (-1 = none).
var _frame: int = -1
## Microseconds accumulated this frame per component.
var _pending: PackedFloat64Array = PackedFloat64Array()
## Ring buffers of per-frame milliseconds, one per component (same order as [constant COMPONENTS]).
var _rings: Array[PackedFloat32Array] = []
## Ring buffer of per-frame total milliseconds (all components).
var _total_ring: PackedFloat32Array = PackedFloat32Array()
## Frames flushed so far (monotonic); the ring holds min(this, WINDOW_FRAMES) samples.
var _flushed: int = 0
## Lifetime sums in microseconds per component, and call counts (for call-rate context).
var _sum_us: PackedFloat64Array = PackedFloat64Array()
var _calls: PackedInt32Array = PackedInt32Array()


## Creates an empty store for [param id].
func _init(id: int = 0) -> void:
  creature_id = id
  _alloc()


## Returns the registered store for [param id], creating it on first use. Only call while [member enabled].
## Example: `NavTiming.for_creature(body.get_instance_id())`.
static func for_creature(id: int) -> _Self:
  var existing: Variant = _registry.get(id)
  if existing is _Self:
    return existing as _Self
  var created := _Self.new(id)
  _registry[id] = created
  return created


## Records [param usec] microseconds for [param component] on the current physics frame. Unknown components
## are ignored. Flushes the previous frame first when the physics frame advanced.
## Example: `timing.add(NavTiming.COMP_PATH_QUERY, Time.get_ticks_usec() - t0)`.
func add(component: StringName, usec: int) -> void:
  var idx := COMPONENTS.find(component)
  if idx < 0:
    return
  var frame := Engine.get_physics_frames()
  if frame != _frame:
    _flush_pending()
    _frame = frame
  _pending[idx] += float(usec)
  _sum_us[idx] += float(usec)
  _calls[idx] += 1


## Clears all samples and counters for this store.
func reset() -> void:
  _frame = -1
  _flushed = 0
  _alloc()


## Snapshot: `{creature_id, frames, window, <component>: stats..., total: stats}` where each stats dict is
## `{p50_ms, p95_ms, max_ms, mean_ms, calls, sum_ms}` (calls / sum_ms are lifetime; percentiles are over the
## rolling window of physics frames; frames with no activity are not sampled). Flushes the pending frame.
func snapshot() -> Dictionary:
  _flush_pending()
  var out := {
    "creature_id": creature_id,
    "frames": mini(_flushed, WINDOW_FRAMES),
    "window": WINDOW_FRAMES,
  }
  for i in COMPONENTS.size():
    var stats := _stats(_rings[i])
    stats["calls"] = _calls[i]
    stats["sum_ms"] = _sum_us[i] / 1000.0
    out[String(COMPONENTS[i])] = stats
  var total := _stats(_total_ring)
  total["calls"] = 0
  for c in _calls:
    total["calls"] += c
  var sum_all := 0.0
  for s in _sum_us:
    sum_all += s
  total["sum_ms"] = sum_all / 1000.0
  out["total"] = total
  return out


## Snapshot of every registered creature: `{creature_id (int): snapshot()}`.
static func snapshot_all() -> Dictionary:
  var out := {}
  for id in _registry:
    out[id] = (_registry[id] as _Self).snapshot()
  return out


## Clears every registered store's samples (keeps the registry and the [member enabled] flag).
static func reset_all() -> void:
  for id in _registry:
    (_registry[id] as _Self).reset()


## Drops all registered stores (frees memory for despawned creatures). Does not change [member enabled].
static func clear_registry() -> void:
  _registry.clear()


## Pooled p95 of the per-creature-per-frame total across all registered stores, in ms (0.0 when empty).
## This is the `c` candidate for `N_active = floor(B_nav / c)` (D29).
static func pooled_total_p95_ms() -> float:
  var pooled := PackedFloat32Array()
  for id in _registry:
    var t := _registry[id] as _Self
    t._flush_pending()
    pooled.append_array(t._valid_slice(t._total_ring))
  return _percentile(pooled, 0.95)


## One-line summary for an explicit, tool-requested log: `nav_timing creatures=N total p50/p95/max ms`.
## Never logs by itself.
static func summary_line() -> String:
  var pooled := PackedFloat32Array()
  for id in _registry:
    var t := _registry[id] as _Self
    t._flush_pending()
    pooled.append_array(t._valid_slice(t._total_ring))
  return "nav_timing creatures=%d samples=%d total_ms p50=%.3f p95=%.3f max=%.3f" % [
    _registry.size(), pooled.size(), _percentile(pooled, 0.5), _percentile(pooled, 0.95), _percentile(pooled, 1.0),
  ]


## Allocates (or zeroes) all buffers.
func _alloc() -> void:
  var n := COMPONENTS.size()
  _pending = PackedFloat64Array()
  _pending.resize(n)
  _sum_us = PackedFloat64Array()
  _sum_us.resize(n)
  _calls = PackedInt32Array()
  _calls.resize(n)
  _rings = []
  for i in n:
    var ring := PackedFloat32Array()
    ring.resize(WINDOW_FRAMES)
    _rings.append(ring)
  _total_ring = PackedFloat32Array()
  _total_ring.resize(WINDOW_FRAMES)


## Moves the pending frame (if any activity) into the rings and zeroes it.
func _flush_pending() -> void:
  var total_us := 0.0
  for v in _pending:
    total_us += v
  if total_us <= 0.0:
    return
  var slot := _flushed % WINDOW_FRAMES
  for i in _pending.size():
    _rings[i][slot] = float(_pending[i] / 1000.0)
    _pending[i] = 0.0
  _total_ring[slot] = float(total_us / 1000.0)
  _flushed += 1


## The populated portion of [param ring] (order not significant).
func _valid_slice(ring: PackedFloat32Array) -> PackedFloat32Array:
  var n := mini(_flushed, WINDOW_FRAMES)
  return ring.slice(0, n)


## `{p50_ms, p95_ms, max_ms, mean_ms}` over the populated part of [param ring].
func _stats(ring: PackedFloat32Array) -> Dictionary:
  var s := _valid_slice(ring)
  var mean := 0.0
  if s.size() > 0:
    for v in s:
      mean += v
    mean /= float(s.size())
  return {
    "p50_ms": _percentile(s, 0.5),
    "p95_ms": _percentile(s, 0.95),
    "max_ms": _percentile(s, 1.0),
    "mean_ms": mean,
  }


## Nearest-rank percentile of [param samples] for [param q] in [0, 1]; 0.0 when empty.
static func _percentile(samples: PackedFloat32Array, q: float) -> float:
  if samples.is_empty():
    return 0.0
  var sorted := samples.duplicate()
  sorted.sort()
  var rank := clampi(int(ceil(q * float(sorted.size()))) - 1, 0, sorted.size() - 1)
  return sorted[rank]
