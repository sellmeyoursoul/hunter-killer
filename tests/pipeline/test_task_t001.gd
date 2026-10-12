extends SceneTree
## Acceptance test for task T-001: roster-level all-frames p95 in tools/measure_nav_cost.gd.
## Run: godot --path . --headless -s res://tests/pipeline/test_task_t001.gd   (exit 0 = pass)
## Part 1 checks the pure helper `roster_frame_stats`; part 2 runs the tool headless and checks its output line.

const _TOOL := "res://tools/measure_nav_cost.gd"

var _failures: int = 0


func _init() -> void:
  _run.call_deferred()


func _run() -> void:
  _test_stats_helper()
  _test_tool_output()
  quit(0 if _failures == 0 else 1)


func _test_stats_helper() -> void:
  var tool_script := load(_TOOL) as GDScript
  _assert(tool_script != null and tool_script.has_method("roster_frame_stats"), "tool defines static roster_frame_stats")
  if tool_script == null or not tool_script.has_method("roster_frame_stats"):
    return
  var empty: Dictionary = tool_script.call("roster_frame_stats", PackedFloat32Array())
  _assert(int(empty.get("frames", -1)) == 0 and float(empty.get("p95_ms", -1.0)) == 0.0, "empty input -> frames 0, p95 0.0")
  var s := PackedFloat32Array()
  for i in 100:
    s.append(float(100 - i))  # 100..1, unsorted on purpose
  var st: Dictionary = tool_script.call("roster_frame_stats", s)
  _assert(int(st.get("frames", 0)) == 100, "frames == sample count")
  _assert(is_equal_approx(float(st.get("p50_ms", 0.0)), 50.0), "nearest-rank p50 of 1..100 is 50")
  _assert(is_equal_approx(float(st.get("p95_ms", 0.0)), 95.0), "nearest-rank p95 of 1..100 is 95")
  _assert(is_equal_approx(float(st.get("max_ms", 0.0)), 100.0), "max of 1..100 is 100")
  _assert(is_equal_approx(float(st.get("mean_ms", 0.0)), 50.5), "mean of 1..100 is 50.5")
  # Idle frames (zeros) must count: 90 zeros + 10 x 2.0 -> p95 = 2.0, mean = 0.2.
  var z := PackedFloat32Array()
  z.resize(90)
  for _i in 10:
    z.append(2.0)
  var zs: Dictionary = tool_script.call("roster_frame_stats", z)
  _assert(is_equal_approx(float(zs.get("p95_ms", 0.0)), 2.0) and is_equal_approx(float(zs.get("mean_ms", 0.0)), 0.2), "zero frames are included")
  _assert(is_equal_approx(float(zs.get("p50_ms", -1.0)), 0.0), "p50 of mostly idle frames is 0")
  # The input must not be reordered.
  var keep := PackedFloat32Array([3.0, 1.0, 2.0])
  tool_script.call("roster_frame_stats", keep)
  _assert(keep[0] == 3.0 and keep[1] == 1.0 and keep[2] == 2.0, "input array is not modified")


func _test_tool_output() -> void:
  var out: Array = []
  var args := PackedStringArray([
    "--path", ProjectSettings.globalize_path("res://"), "--headless", "-s", _TOOL,
    "--", "frames=120", "warmup=30", "rabbits=1", "wolves=1",
  ])
  var code := OS.execute(OS.get_executable_path(), args, out, true)
  var text := "\n".join(PackedStringArray(out))
  _assert(code == 0, "tool exits 0 (got %d)" % code)
  var re := RegEx.new()
  re.compile("ROSTER per-frame total \\(all frames\\) n=(\\d+) mean=([0-9.]+) p50=([0-9.]+) p95=([0-9.]+) max=([0-9.]+) ms")
  var m := re.search(text)
  _assert(m != null, "output has the ROSTER per-frame total line")
  if m == null:
    return
  var n := int(m.get_string(1))
  var mean := float(m.get_string(2))
  var p50 := float(m.get_string(3))
  var p95 := float(m.get_string(4))
  var mx := float(m.get_string(5))
  _assert(n == 120, "n equals frames=120 (got %d)" % n)
  _assert(p50 <= p95 and p95 <= mx, "p50 <= p95 <= max")
  _assert(mean >= 0.0 and mean <= mx, "0 <= mean <= max")
  _assert(text.contains("POOLED c (p95 of per-creature per-active-frame total)"), "existing pooled-c line is still printed")


func _assert(cond: bool, msg: String) -> void:
  if cond:
    return
  _failures += 1
  push_error("ASSERT: %s" % msg)
