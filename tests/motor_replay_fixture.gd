extends RefCounted
class_name MotorReplayFixture
## Headless replay harness for [code]MotorPlannerReplayCapture[/code] JSONL traces
## ([CREATURE_MOVEMENT_V3_CLEANUP.md](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md)
## replay harness plan, Phase 1). Feeds a captured **external stimulus** trajectory (what
## prey/food/threats were doing) into a freshly spawned [code]CreatureMotorStack[/code] — the
## subject's own position evolves from real [code]tick()[/code] output rather than being pinned
## to the logged trajectory, so a post-fix planner can legitimately diverge from the original
## (buggy) path while still facing the exact stimulus sequence that produced a real duel
## incident. Static obstacle geometry is not captured per tick (it doesn't move); pair a
## replay with an existing [MotorPathFixture] layout when the incident needs one.

const _CreatureMotorStack := preload("res://creature/motor/creature_motor_stack.gd")

## Ticks to drop [param body] onto the floor before the capture loop runs (see [method drive_stack]).
const _SETTLE_MAX_TICKS := 60


## Reads a [code]MotorPlannerReplayCapture[/code] JSONL file ([code]res://[/code] or
## [code]user://[/code]) and returns tick-ordered rehydrated records (Vector3 / Vector2 /
## StringName restored from their JSON-safe array/string form).
static func load_capture(path: String) -> Array:
  var f := FileAccess.open(path, FileAccess.READ)
  if f == null:
    push_warning(
      "MotorReplayFixture: cannot open capture %s (err=%s)" % [path, FileAccess.get_open_error()]
    )
    return []
  var records: Array = []
  while not f.eof_reached():
    var line := f.get_line()
    if line.strip_edges().is_empty():
      continue
    var parsed: Variant = JSON.parse_string(line)
    if typeof(parsed) != TYPE_DICTIONARY:
      continue
    records.append(_rehydrate_record(parsed))
  f.close()
  return records


## Restores the known Vector3 / Vector2 / StringName fields a captured record carries. This is
## schema-specific (matches [code]CreatureMotorStack._replay_capture_record[/code]) rather than a
## generic inverse of [code]MotorPlannerReplayCapture._sanitize[/code] — JSON round-trips
## everything as arrays/strings, so the reader has to know what each field means.
static func _rehydrate_record(raw: Dictionary) -> Dictionary:
  var out := raw.duplicate(true)
  if out.has("pos"):
    out["pos"] = _to_vector3(out["pos"])
  if out.has("facing"):
    out["facing"] = _to_vector3(out["facing"])
  var food_split: Variant = out.get("food_split", {})
  if typeof(food_split) == TYPE_DICTIONARY:
    out["food_split"] = _rehydrate_food_split(food_split)
  var threats: Variant = out.get("threat_samples", [])
  if typeof(threats) == TYPE_ARRAY:
    out["threat_samples"] = _rehydrate_threat_samples(threats)
  return out


static func _rehydrate_food_split(food_split: Dictionary) -> Dictionary:
  var out := {}
  for bucket in ["ready", "unready"]:
    var entries: Array = food_split.get(bucket, [])
    var out_entries: Array = []
    for entry_v in entries:
      if typeof(entry_v) != TYPE_DICTIONARY:
        continue
      var entry: Dictionary = (entry_v as Dictionary).duplicate(true)
      if entry.has("pos"):
        entry["pos"] = _to_vector3(entry["pos"])
      if entry.has("stimulus_kind_id"):
        entry["stimulus_kind_id"] = StringName(str(entry["stimulus_kind_id"]))
      out_entries.append(entry)
    out[bucket] = out_entries
  return out


static func _rehydrate_threat_samples(threats: Array) -> Array:
  var out: Array = []
  for sample_v in threats:
    if typeof(sample_v) != TYPE_DICTIONARY:
      continue
    var sample: Dictionary = (sample_v as Dictionary).duplicate(true)
    if sample.has("world_pos"):
      sample["world_pos"] = _to_vector2(sample["world_pos"])
    if sample.has("velocity"):
      sample["velocity"] = _to_vector2(sample["velocity"])
    if sample.has("stimulus_kind_id"):
      sample["stimulus_kind_id"] = StringName(str(sample["stimulus_kind_id"]))
    if sample.has("source"):
      sample["source"] = StringName(str(sample["source"]))
    out.append(sample)
  return out


static func _to_vector3(value: Variant) -> Vector3:
  if typeof(value) != TYPE_ARRAY:
    return Vector3.ZERO
  var arr: Array = value
  if arr.size() < 3:
    return Vector3.ZERO
  return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func _to_vector2(value: Variant) -> Vector2:
  if typeof(value) != TYPE_ARRAY:
    return Vector2.ZERO
  var arr: Array = value
  if arr.size() < 2:
    return Vector2.ZERO
  return Vector2(float(arr[0]), float(arr[1]))


## Gives [param body] a deterministic run-up before the capture loop starts (CLEANUP C7 fix,
## 2026-08-06). Root cause: a freshly-added collider (this fixture's floor, or the body itself)
## isn't visible to physics broadphase queries until the physics server has actually processed a
## step, and whether that happened yet by the time the caller's setup `await` resolves is a race
## in headless/uncapped-FPS runs — confirmed as [C7](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md#c7-flaky-headless-assertions-nondeterministic-across-identical-runs)'s
## cause for this fixture: a body that falls through the ungrounded floor for the whole capture
## drifts further from the (grounded) prey in 3D, degrading the closing-distance margin the drive
## loop's assertions depend on — sometimes enough to flip pass/fail.
##
## Two full [code]physics_frame[/code] cycles up front (confirmed empirically: one is not reliably
## enough headroom, and calling [code]move_and_slide()[/code] synchronously without yielding to
## the engine at all does not force the sync either) make the outcome **deterministic** run to
## run — verified via 5 separate `--headless` process invocations, byte-identical result each
## time. It does not fully resolve floor contact within [const _SETTLE_MAX_TICKS] every run, but a
## deterministic outcome (consistently a healthy closing-distance margin) is what actually matters
## for this fixture's assertions; not chasing full grounding further to keep the fix minimal.
static func _settle_on_floor(body: CharacterBody3D, delta: float) -> void:
  var tree := body.get_tree()
  if tree == null or not body.has_method(&"apply_horizontal_move_intent"):
    return
  await tree.physics_frame
  await tree.physics_frame
  var ticks := 0
  while not body.is_on_floor() and ticks < _SETTLE_MAX_TICKS:
    body.call(&"apply_horizontal_move_intent", Vector3.ZERO, delta)
    ticks += 1


## Drives [param stack] tick-by-tick using the captured external stimulus (`food_split` /
## `threat_samples`) from [param records]. Sets the subject's *initial* position/facing from the
## first record only — subsequent ticks let [param body]'s position evolve from
## [code]stack.tick()[/code] output. Returns one world-position sample per tick for stall /
## progress assertions (e.g. [MotorStallDetector]).
static func drive_stack(
  stack: _CreatureMotorStack,
  body: CharacterBody3D,
  records: Array,
  delta: float = 1.0 / 60.0,
) -> Array[Vector3]:
  var positions: Array[Vector3] = []
  if records.is_empty():
    return positions
  var first: Dictionary = records[0]
  if first.has("pos"):
    body.global_position = first["pos"]
  if first.has("facing"):
    var facing: Vector3 = first["facing"]
    if facing.length_squared() > 1e-6:
      body.set("last_move_direction", facing.normalized())
  await _settle_on_floor(body, delta)
  for record_v in records:
    var record: Dictionary = record_v
    stack.set_live_scan_for_test(record)
    stack.tick(delta)
    positions.append(body.global_position)
  return positions
