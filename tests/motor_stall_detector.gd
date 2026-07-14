extends RefCounted
class_name MotorStallDetector
## Generic trailing-window stall/orbit detector for headless motor smokes and replay fixtures
## ([CREATURE_MOVEMENT_V3_CLEANUP.md](../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3_CLEANUP.md)
## replay harness plan, Phase 1). Existing smokes each hand-roll their own progress signal
## (rear-hemisphere move count, `cblk` streak, …) — this gives them (and replay-driven fixtures)
## one shared "is the subject actually stuck" check: net displacement across a trailing tick
## window stays below [member epsilon].


## Samples one subject's position per tick; reports the longest run of trailing-window ticks
## with near-zero net displacement.
class Tracker:
  var window_ticks: int
  var epsilon: float
  var max_stall_streak: int = 0
  var _samples: Array[Vector3] = []
  var _stall_streak: int = 0

  func _init(p_window_ticks: int, p_epsilon: float) -> void:
    window_ticks = maxi(1, p_window_ticks)
    epsilon = p_epsilon

  ## Call once per tick with the subject's current world position.
  func sample(pos: Vector3) -> void:
    _samples.append(pos)
    if _samples.size() > window_ticks:
      _samples.remove_at(0)
    if _samples.size() < window_ticks:
      _stall_streak = 0
      return
    var net := _samples[0].distance_to(_samples[_samples.size() - 1])
    if net < epsilon:
      _stall_streak += 1
      max_stall_streak = maxi(max_stall_streak, _stall_streak)
    else:
      _stall_streak = 0

  ## True once the trailing window showed near-zero net displacement for [param max_ok_streak]
  ## consecutive ticks or more — the subject orbited / stalled rather than making progress.
  func stalled(max_ok_streak: int) -> bool:
    return max_stall_streak > max_ok_streak


## Convenience one-shot: builds a [Tracker] and feeds it [param positions] in order (e.g. from
## [method MotorReplayFixture.drive_stack]). Returns the resulting [member Tracker.max_stall_streak].
static func max_stall_streak_for(positions: Array[Vector3], window_ticks: int, epsilon: float) -> int:
  var tracker := Tracker.new(window_ticks, epsilon)
  for pos in positions:
    tracker.sample(pos)
  return tracker.max_stall_streak
