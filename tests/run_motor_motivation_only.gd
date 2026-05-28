extends SceneTree

const _RunAll := preload("res://tests/run_all.gd")

func _init() -> void:
  var inst := _RunAll.new()
  inst._test_motor_motivation_wiring()
  print("motor_motivation_only: done failures=", inst._failures)
  quit(0 if inst._failures == 0 else 1)
