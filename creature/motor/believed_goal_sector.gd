## Egocentric 8-way sector helpers for habitual goal bias ([CREATURE_MEMORY.md §14.1](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).
extends Object


## Unit step direction [param d] → sector index 0..7 (N, NE, E, SE, S, SW, W, NW; **−Z = N** in world space).
static func sector_index_for_step(d: Vector3) -> int:
  if d.length_squared() < 1e-8:
    return 0
  var u := d.normalized()
  var angle := atan2(u.x, -u.z)
  if angle < 0.0:
    angle += TAU
  return int(floor((angle + PI / 8.0) / (PI / 4.0))) % 8


## Phase-1 [code]align(d, sector_s)[/code]: **1.0** if [param d] falls in [param sector_s]'s 45° arc, else **0.0**.
static func align_step_with_sector(d: Vector3, sector_s: int) -> float:
  if sector_s < 0 or sector_s > 7:
    return 0.0
  return 1.0 if sector_index_for_step(d) == sector_s else 0.0
