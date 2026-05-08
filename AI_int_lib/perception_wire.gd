## Pure helpers for §4.2 perception blob header and kinematics lines (no scene tree).
extends Object


## Snapshot header: [code]tick_ms score cols rows cell_size[/code] (space-separated).
static func format_header_line(tick_ms: int, score: int, cols: int, rows: int, cell_size: int) -> String:
  return "%d %d %d %d %d" % [tick_ms, score, cols, rows, cell_size]


## Kinematics line: [code]PLAYER r c vx vy vz[/code] or [code]MOB r c vx vy vz[/code].
static func format_entity_velocity_line(tag: String, r: int, c: int, vel: Vector3) -> String:
  return "%s %d %d %.6g %.6g %.6g" % [tag, r, c, vel.x, vel.y, vel.z]


## Half-extents line: [code]PLAYER_EXT hx hy hz[/code] or [code]MOB_EXT hx hy hz[/code].
static func format_entity_extents_line(tag: String, half_extents: Vector3) -> String:
  return "%s %.6g %.6g %.6g" % [tag, half_extents.x, half_extents.y, half_extents.z]
