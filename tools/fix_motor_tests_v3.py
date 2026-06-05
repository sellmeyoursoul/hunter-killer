#!/usr/bin/env python3
"""Fix incorrect Vector3 conversions in motor tests (bounds/footprint must stay Vector2)."""
import re
import sys
from pathlib import Path

TARGET = Path(__file__).resolve().parents[1] / "tests" / "run_all.gd"

# bounds_max / bounds_min literals wrongly promoted to Vector3
BOUNDS_FIXES = {
  "Vector3(480.0, 0.0, 720.0)": "Vector2(480.0, 720.0)",
  "Vector3(2000.0, 0.0, 2000.0)": "Vector2(2000.0, 2000.0)",
  "Vector3(1000.0, 0.0, 1000.0)": "Vector2(1000.0, 1000.0)",
  "Vector3(800.0, 0.0, 800.0)": "Vector2(800.0, 800.0)",
}

# footprint half-extents (half_x, half_z)
HALF_FIXES = {
  "Vector3(20.0, 0.0, 20.0)": "Vector2(20.0, 20.0)",
  "Vector3(10.0, 0.0, 10.0)": "Vector2(10.0, 10.0)",
  "Vector3(8.0, 0.0, 8.0)": "Vector2(8.0, 8.0)",
  "Vector3(18.0, 0.0, 44.0)": "Vector2(18.0, 44.0)",
  "Vector3(13.5, 0.0, 30.5)": "Vector2(13.5, 30.5)",
}

# strategic_obstacle_cost: disabled threat/prey pins use Vector3.ZERO
STRAT_ZERO_FIXES = [
  (
    "Vector3(400.0, 0.0, 300.0), Vector3(600.0, 0.0, 300.0), Vector2.ZERO, pts",
    "Vector3(400.0, 0.0, 300.0), Vector3(600.0, 0.0, 300.0), Vector3.ZERO, pts",
  ),
  (
    "Vector3(200.0, 0.0, 300.0), Vector2.ZERO, Vector3(350.0, 0.0, 300.0), pts",
    "Vector3(200.0, 0.0, 300.0), Vector3.ZERO, Vector3(350.0, 0.0, 300.0), pts",
  ),
]


def main() -> int:
  text = TARGET.read_text(encoding="utf-8")
  for old, new in BOUNDS_FIXES.items():
    text = text.replace(old, new)
  for old, new in HALF_FIXES.items():
    text = text.replace(old, new)
  for old, new in STRAT_ZERO_FIXES:
    text = text.replace(old, new)

  # var he footprint
  text = text.replace("var he := Vector3(13.5, 30.5)", "var he := Vector2(13.5, 30.5)")

  # jeopardy / seek: facing dirs
  text = text.replace(
    "Vector3(240.0, 0.0, 200.0), Vector2.ZERO, Vector2.RIGHT, mobs",
    "Vector3(240.0, 0.0, 200.0), Vector2.ZERO, Vector3(1.0, 0.0, 0.0), mobs",
  )
  text = text.replace(
    'pick_fn.call(Vector3(1.0, 0.0, 0.0), Vector2.UP, 2, 0)',
    'pick_fn.call(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), 2, 0)',
  )
  text = text.replace(
    'seek_backtrack_step_cost").call(Vector3(0.0, 0.0, 1.0), Vector2.UP, 10.0)',
    'seek_backtrack_step_cost").call(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0), 10.0)',
  )
  text = text.replace(
    "Vector3(500.0, 0.0, 500.0), he, Vector2.RIGHT, 60.0",
    "Vector3(500.0, 0.0, 500.0), he, Vector3(1.0, 0.0, 0.0), 60.0",
  )
  text = text.replace(
    "Vector3(500.0, 0.0, 500.0), he, Vector2.UP, 60.0",
    "Vector3(500.0, 0.0, 500.0), he, Vector3(0.0, 0.0, -1.0), 60.0",
  )

  # kinematic intent test
  text = text.replace(
    '_assert(typeof(stored) == TYPE_VECTOR3, "kinematic stores Vector2 intent")',
    '_assert(typeof(stored) == TYPE_VECTOR3, "kinematic stores Vector3 intent")',
  )
  text = text.replace(
    "var sv := stored as Vector2\n  _assert(sv.is_equal_approx(Vector3(0.0, 0.0, 1.0))",
    "var sv := stored as Vector3\n  _assert(sv.is_equal_approx(Vector3(0.0, 0.0, 1.0))",
  )

  # cost_at_prediction static obstacle position at 689 - check if half was wrong
  # Vector3(100,0,120) with Vector2(8,8) half - position is Vector3, half Vector2 - OK after fix

  TARGET.write_text(text, encoding="utf-8")
  print(f"Fixed {TARGET}")
  return 0


if __name__ == "__main__":
  sys.exit(main())
