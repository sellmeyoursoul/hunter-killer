## Typed hostile threat ingress ([CREATURE_MOVEMENT_V2.md §A.2](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V2.md)).
extends Object

const _MotorPlane := preload("res://creature/motor/motor_plane.gd")

const SOURCE_LIVE_MOB := &"live_mob"


## Returns a threat-sample dictionary for motor / flee / Tier-2 acute checks.
static func make(
  world_pos: Vector3,
  gate_dist: float = INF,
  in_awareness: bool = false,
  velocity: Vector3 = Vector3.ZERO,
  instance_id: int = 0,
  acute: bool = true,
  hostile: bool = true,
  source: StringName = SOURCE_LIVE_MOB,
) -> Dictionary:
  return {
    "world_pos": world_pos,
    "gate_dist": gate_dist,
    "in_awareness": in_awareness,
    "velocity": velocity,
    "instance_id": instance_id,
    "acute": acute,
    "hostile": hostile,
    "source": source,
  }


static func inactive() -> Dictionary:
  return make(Vector3.ZERO, INF, false, Vector3.ZERO, 0, false, true)


## Legacy [code]herbivore_threat[/code] shape used by flee / tactic code in [code]ai_driver.gd[/code].
static func to_legacy_herbivore_dict(sample: Dictionary) -> Dictionary:
  if sample.is_empty() or not bool(sample.get("in_awareness", false)):
    return {"in_awareness": false, "gate_dist": INF, "world_pos": Vector3.ZERO}
  return {
    "in_awareness": true,
    "gate_dist": float(sample.get("gate_dist", INF)),
    "world_pos": _MotorPlane.read_pos(sample.get("world_pos", Vector3.ZERO)),
  }


static func from_legacy_herbivore_dict(legacy: Dictionary) -> Dictionary:
  if not bool(legacy.get("in_awareness", false)):
    return inactive()
  return make(
    _MotorPlane.read_pos(legacy.get("world_pos", Vector3.ZERO)),
    float(legacy.get("gate_dist", INF)),
    true,
    Vector3.ZERO,
    0,
    true,
    true,
    SOURCE_LIVE_MOB,
  )
