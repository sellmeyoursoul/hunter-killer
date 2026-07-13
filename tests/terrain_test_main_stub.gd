extends Node3D
## Minimal main stub for headless terrain motor tests.


const _GroundSampler := preload("res://environment/playfield_ground_sampler.gd")
const _MotorPathFixture := preload("res://tests/motor_path_fixture.gd")

var ground_sampler: _GroundSampler
var _fixture_map_rid: RID = RID()


func get_ground_sampler() -> _GroundSampler:
  return ground_sampler


## Delegates to active motor path fixture when mounted ([CREATURE_MOVEMENT_V3.md §3](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).
func get_navigation_map_rid() -> RID:
  return _fixture_map_rid


func mount_motor_path_fixture(layout: String = "open") -> Dictionary:
  var built: Dictionary
  if layout == "blocked":
    built = _MotorPathFixture.build_blocked(self)
  elif layout == "pursuit_pinch":
    built = _MotorPathFixture.build_pursuit_pinch(self)
  else:
    built = _MotorPathFixture.build_open(self)
  _fixture_map_rid = built.get("map_rid", RID()) as RID
  return built


func clear_motor_path_fixture() -> void:
  _fixture_map_rid = RID()
