extends RefCounted
class_name CreatureControlMode
## Shared control-mode ints for duel creatures (human / ENGINE / AI).
## Used by 3D kinematic bodies and [code]AiDriver[/code] when arming rounds.


enum Mode {
  HUMAN,
  ENGINE,
  AI,
}


static func human_as_int() -> int:
  return Mode.HUMAN


static func engine_as_int() -> int:
  return Mode.ENGINE


static func ai_as_int() -> int:
  return Mode.AI
