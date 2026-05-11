## Pure helpers for §4.2 perception blob header and kinematics lines (no scene tree).
class_name PerceptionWire
extends Object


## Snapshot header: [code]tick_ms score cols rows cell_size[/code] (space-separated).
static func format_header_line(tick_ms: int, score: int, cols: int, rows: int, cell_size: int) -> String:
  return "%d %d %d %d %d" % [tick_ms, score, cols, rows, cell_size]


## Kinematics line: [code]PLAYER r c vx vy vz[/code] or [code]MOB r c vx vy vz[/code].
static func format_entity_velocity_line(tag: String, r: int, c: int, vel: Vector3) -> String:
  return "%s %d %d %.6f %.6f %.6f" % [tag, r, c, vel.x, vel.y, vel.z]


## Half-extents line: [code]PLAYER_EXT hx hy hz[/code] or [code]MOB_EXT hx hy hz[/code].
static func format_entity_extents_line(tag: String, half_extents: Vector3) -> String:
  return "%s %.6f %.6f %.6f" % [tag, half_extents.x, half_extents.y, half_extents.z]


## One-line machine hint for threat salience (vector closing, creature boundary patch).
## Params:
## - idx_1: 1-based MOB list index of most urgent **closing** mob, or -1 if none.
## - t_approx_sec: estimated seconds to close along radial axis, or INF when idx_1 is -1.
## - creature_patch: `corner`, `wall`, or `interior` (grid boundary classification).
## - creature_band: `moving` or `stopped` from small velocity threshold.
## Returns:
## - Single space-separated `RISK_HINTS ...` perception line appended after snapshot header.
static func format_risk_hints_line(idx_1: int, t_approx_sec: float, creature_patch: String, creature_band: String) -> String:
  var t_str := "NONE"
  if idx_1 >= 1:
    t_str = "%.3f" % t_approx_sec
  return ("RISK_HINTS CLOSEST_CLOSING_I=%s T_APPROX_S=%s CREATURE_PATCH=%s CREATURE_BAND=%s"
    % [str(idx_1), t_str, creature_patch, creature_band])


## Short natural-language recap for tiny models that ignore dense key=value cues.
## Params:
## - idx_1: same meaning as `format_risk_hints_line` CLOSING index (1-based) or `-1`.
## - creature_patch / creature_band: same labels emitted on the `RISK_HINTS` line.
## Returns:
## - One `PLAIN_HINT …` perception line summarizing dodge priority and positional risk.
static func format_plain_hint_line(idx_1: int, creature_patch: String, creature_band: String) -> String:
  var focus: String
  if idx_1 >= 1:
    focus = (
      "Dodge perpendicular to Mob list index %d (that index is numbered from nearest MOB first). "
      + "Treat it as the top interception risk this observation."
      % idx_1
    )
  else:
    focus = (
      "No interceptor tag this tick; still drift toward emptier lanes and widen gaps from nearest MOB lines."
    )
  var posture := ""
  if creature_band == "stopped":
    match creature_patch:
      "corner":
        posture = " You are STOPPED in a CORNER — exit inward now; never freeze here."
      "wall":
        posture = " You are STOPPED hugging an EDGE — roll back toward the interior."
      _:
        posture = " You are STOPPED — keep moving next tick to avoid predictability."
  return ("PLAIN_HINT %s%s" % [focus, posture]).strip_edges()
