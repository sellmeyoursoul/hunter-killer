extends SceneTree
## Headless per-creature navigation cost baseline (NAVIGATION_PASSABILITY_PLAN D29 / section 8.2.7).
##
## Boots the real res://main_3d.tscn, waits for the playfield navmesh bake, starts a round (new_game),
## warms up, resets [NavTiming], runs N physics frames and prints per-creature p50 / p95 / max / mean ms
## per component (path_query, ghost_scan, step_probe, replan) plus total, the pooled p95 `c`, and
## N_active_est = floor(B_NAV_MS / c). Dev-machine estimate, NOT Min spec (D29).
##
## Usage (user args after `--`, all optional):
##   godot --path . --headless -s res://tools/measure_nav_cost.gd -- frames=2000 warmup=240 rabbits=1 foxes=0 wolves=1
##   frames   physics frames measured (default 2000; ring window is NavTiming.WINDOW_FRAMES, so percentiles
##            cover at most the last 1024 frames WITH activity; calls / sum_ms are lifetime over all frames)
##   warmup   physics frames run before reset (default 240)
##   rabbits / foxes / wolves   roster override (default: game config roster, normally 1 rabbit + 1 wolf).
##            Any of the three given -> the roster is exactly those counts (first non-empty species is the
##            "player" entry; new_game puts every creature in ENGINE mode anyway).
## Exit code: 0 when the report ran, 1 on a setup error.

const _B_NAV_MS := 1.5
const _NavTiming := preload("res://creature/motor/nav_timing.gd")
const _ARCHETYPES := {
  "rabbit": "res://creature/species/rabbit_archetype.tres",
  "fox": "res://creature/species/fox_archetype.tres",
  "wolf": "res://creature/species/wolf_archetype.tres",
}
const _COMPONENT_COLS: Array[String] = ["path_query", "ghost_scan", "step_probe", "replan", "total"]

var _main: Node3D
var _frames := 2000
var _warmup := 240
var _roster: Dictionary = {}
var _restarts := 0


func _init() -> void:
  _parse_args()
  _run.call_deferred()


## Parses `key=value` user args (after `--`) into frames / warmup / roster counts.
func _parse_args() -> void:
  for a in OS.get_cmdline_user_args():
    var kv := String(a).split("=", false, 1)
    if kv.size() != 2:
      continue
    var v := int(kv[1])
    match kv[0]:
      "frames":
        _frames = maxi(1, v)
      "warmup":
        _warmup = maxi(0, v)
      "rabbits":
        _roster["rabbit"] = maxi(0, v)
      "foxes":
        _roster["fox"] = maxi(0, v)
      "wolves":
        _roster["wolf"] = maxi(0, v)


## Boots main, warms up, measures, prints, quits.
func _run() -> void:
  _NavTiming.enabled = true
  var scene := load("res://main_3d.tscn") as PackedScene
  if scene == null:
    _fail("cannot load res://main_3d.tscn")
    return
  _main = scene.instantiate() as Node3D
  root.add_child(_main)
  await process_frame
  await process_frame
  var waited := 0
  while not bool(_main.call("is_navigation_ready")) and waited < 1200:
    await process_frame
    waited += 1
  if not bool(_main.call("is_navigation_ready")):
    _fail("navmesh never became ready")
    return
  if not _roster.is_empty() and not _apply_roster_override():
    return
  _main.call("new_game")
  for _i in 6:
    await physics_frame
  var bodies: Array = _main.call("get_all_creature_bodies")
  if bodies.is_empty():
    _fail("new_game spawned no creatures")
    return
  for _i in _warmup:
    await physics_frame
    _restart_if_round_ended()
  _NavTiming.reset_all()
  var started_restarts := _restarts
  var t0 := Time.get_ticks_msec()
  for _i in _frames:
    await physics_frame
    _restart_if_round_ended()
  var wall_s := float(Time.get_ticks_msec() - t0) / 1000.0
  _report(wall_s, _restarts - started_restarts)
  quit(0)


## Replaces the main scene's spawn plan with [member _roster] counts (tool-side write of a private var;
## no production edit). Returns false and fails when nothing resolvable was requested.
func _apply_roster_override() -> bool:
  var plan: Array[Dictionary] = []
  for sp in ["rabbit", "fox", "wolf"]:
    var n := int(_roster.get(sp, 0))
    if n <= 0:
      continue
    var def := load(String(_ARCHETYPES[sp])) as CreatureDefinition
    if def == null or def.body_scene == null:
      _fail("archetype for %s unavailable" % sp)
      return false
    plan.append({"definition": def, "body_scene": def.body_scene, "count": n, "player_controlled": plan.is_empty()})
  if plan.is_empty():
    _fail("roster override requested zero creatures")
    return false
  _main.set("_creature_spawn_plan", plan)
  return true


## Starts a fresh round when the previous one ended (catch / starvation) so creatures keep pathing.
## Stores from earlier rounds stay in the NavTiming registry (their samples still count).
func _restart_if_round_ended() -> void:
  if bool(_main.get("_round_ended")):
    _restarts += 1
    _main.call("new_game")


## Species id of a body's creature root definition.
func _species_of(body: Node) -> String:
  var def: Variant = body.get_parent().get("definition") if body.get_parent() != null else null
  return String(def.get("species_id")) if def != null else "?"


func _fail(msg: String) -> void:
  printerr("measure_nav_cost: " + msg)
  quit(1)


func _report(wall_s: float, restarts_in_window: int) -> void:
  var snaps: Dictionary = _NavTiming.snapshot_all()
  var species_by_id: Dictionary = {}
  for b in _main.call("get_all_creature_bodies"):
    species_by_id[(b as Node).get_instance_id()] = _species_of(b)
  var counts: Dictionary = {}
  for b in _main.call("get_all_creature_bodies"):
    var s := _species_of(b)
    counts[s] = int(counts.get(s, 0)) + 1
  print("")
  print("=== measure_nav_cost  frames=%d warmup=%d wall=%.1fs roster=%s round_restarts_in_window=%d" % [
    _frames, _warmup, wall_s, counts, restarts_in_window,
  ])
  print("    NavTiming.WINDOW_FRAMES=%d; percentiles are over active frames only (frames with >=1 timed call); B_nav=%.1f ms" % [
    _NavTiming.WINDOW_FRAMES, _B_NAV_MS,
  ])
  print("    ms/frame (p50 / p95 / max / mean) per component, then lifetime calls per component")
  var ids: Array = snaps.keys()
  ids.sort()
  var live_ids: Array = species_by_id.keys()
  for id in ids:
    var s: Dictionary = snaps[id]
    var tag := "%s#%d%s" % [String(species_by_id.get(id, "prev-round")), int(id) % 100000, "" if live_ids.has(id) else "(old)"]
    var parts: PackedStringArray = []
    for c in _COMPONENT_COLS:
      var st: Dictionary = s[c]
      parts.append("%s %.3f/%.3f/%.3f/%.3f" % [c, st["p50_ms"], st["p95_ms"], st["max_ms"], st["mean_ms"]])
    var calls: PackedStringArray = []
    for c in ["path_query", "ghost_scan", "step_probe", "replan"]:
      calls.append("%s=%d" % [c, int((s[c] as Dictionary)["calls"])])
    print("  %-14s active_frames=%4d | %s | calls: %s | sum_ms=%.2f" % [
      tag, int(s["frames"]), " | ".join(parts), ", ".join(calls), float((s["total"] as Dictionary)["sum_ms"]),
    ])
  var c_p95: float = _NavTiming.pooled_total_p95_ms()
  var n_est := int(floor(_B_NAV_MS / c_p95)) if c_p95 > 0.0 else -1
  print("  %s" % _NavTiming.summary_line())
  print("  POOLED c (p95 of per-creature per-active-frame total) = %.4f ms  ->  N_active_est = floor(%.1f / c) = %s" % [
    c_p95, _B_NAV_MS, str(n_est) if n_est >= 0 else "n/a (no samples)",
  ])
  var total_sum_ms := 0.0
  for id in ids:
    total_sum_ms += float(((snaps[id] as Dictionary)["total"] as Dictionary)["sum_ms"])
  var live := maxi(1, species_by_id.size())
  print("  amortised: total nav ms over run = %.2f -> %.4f ms per physics frame across %d live creature(s) (%.4f per creature per frame, all frames)" % [
    total_sum_ms, total_sum_ms / float(_frames), live, total_sum_ms / float(_frames) / float(live),
  ])
  print("  (dev-machine headless estimate; not Min spec)")
