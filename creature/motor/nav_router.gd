extends RefCounted
class_name NavRouter
## Layer-2 creature-facing path service (NAVIGATION_PASSABILITY_PLAN.md D10, section 6.2; Phase 0 (b)).
## The single entry point motor code uses to ask the navigation server anything: no motor call site holds
## a raw navigation map RID or calls `NavigationServer3D.map_get_path` / `map_get_closest_point*`
## directly. Phase 0 wraps the CURRENT single shared navmesh (reached through `main.get_navigation_map_rid()`
## or an explicit map RID for headless fixtures); Phase 1 swaps [method map_for] / [method navigation_layers_for]
## onto Layer-1 per-(class, variant) handles without touching any call site.
##
## Why an instance (not static helpers like [MotorPathClear]): the router owns per-creature state — which map
## source it is bound to (main-resolved lazily, or a fixed RID), the body whose [PassabilityProfile] it answers
## for, and the telemetry counters (path queries, [code]scan_truncated_static[/code], section 7). Call sites
## that only need plain-value helpers stay static on [MotorPathClear] and delegate here.
##
## Construction seams:
## - Live game: [method for_body] (the [CreatureMotorStack] holds one router per body).
## - Headless fixtures: [method for_map] with the fixture's own map RID.
## - Planner contexts: [method from_ctx] reads `ctx["nav_router"]`, else wraps legacy `ctx["map_rid"]`.
## - Any function that used to take a `map_rid` accepts a router OR a raw RID via [method coerce].

## Self reference by path: a brand-new `class_name` is not resolvable inside its own script until the editor
## refreshes the global class cache, and headless runs may start with a stale cache.
const _Self := preload("res://creature/motor/nav_router.gd")
const _MotorPlane := preload("res://creature/motor/motor_plane.gd")
const _PassabilityProfile := preload("res://creature/capabilities/passability_profile.gd")
const _NavTiming := preload("res://creature/motor/nav_timing.gd")

## Navigation-layer bit reserved for the walkable baseline (Godot's default `navigation_layers` = 1).
const NAV_LAYER_WALK := 1
## Reserved (D8): off-mesh climb links will carry this bit. Unused until Phase 3 generates links.
const NAV_LAYER_CLIMB := 2
## Reserved (D6): swim overlay. Unused.
const NAV_LAYER_SWIM := 4
## The single place the Phase 0 query mask is defined: every creature queries the walkable baseline.
## Phase 1 replaces this with per-class masks inside [method navigation_layers_for].
const DEFAULT_QUERY_LAYERS := NAV_LAYER_WALK

## How far above / below a body's origin [method query_origin] searches for the navmesh surface under it.
## Above: the navmesh can sit slightly above a short body's origin. Below: must exceed any creature's origin
## height above the surface plus terrain slop (authored-dimension bodies have their origin at the feet).
const NAV_QUERY_ABOVE := 1.0
const NAV_QUERY_BELOW := 60.0
## [member PathResult] `reachable` is true when the path's last point is within this horizontal distance (m)
## of the requested destination. Informational in Phase 0 (no call site gates on it).
const REACHABLE_END_TOLERANCE := 1.0

## Fixed map RID (headless fixtures). When valid it wins over [member _main].
var _fixed_map: RID = RID()
## Node exposing `get_navigation_map_rid()` / `is_navigation_ready()` (main_3d). Resolved lazily every query,
## since the bake can replace the map handle.
var _main: Node = null
## Body whose profile this router answers for; null -> default profile.
var _body: Object = null
var _default_profile: RefCounted = null

## Telemetry (section 7 `scan_truncated_static`): total path queries that reached a valid map.
var path_queries: int = 0
## Route-scan truncations caused by static (ghost-layer) obstacles; see [method note_scan_truncated_static].
var scan_truncated_static: int = 0
## Per-creature timing store (D29); created lazily on the first recorded sample, only while timing is enabled.
var _timing: RefCounted = null


## Router over an explicit [param map_rid] (headless fixtures). [param body] optionally binds a profile source.
## Example: `NavRouter.for_map(built["map_rid"], body)`.
static func for_map(map_rid: RID, body: Object = null) -> _Self:
  var router := _Self.new()
  router._fixed_map = map_rid
  router._body = body
  return router


## Router bound to [param body] whose map comes from [param main] (`get_navigation_map_rid()`), re-read per
## query. [param main] may be null and set later with [method set_main].
static func for_body(body: Object, main: Node = null) -> _Self:
  var router := _Self.new()
  router._body = body
  router._main = main
  return router


## Accepts a [NavRouter] (returned as is), a raw [RID] (wrapped, legacy / fixture seam) or anything else
## (an invalid-map router: every query degrades to its no-map fallback). Never returns null.
static func coerce(value: Variant) -> _Self:
  if value is _Self:
    return value as _Self
  if typeof(value) == TYPE_RID:
    return for_map(value as RID)
  return _Self.new()


## Router for a planner context: `ctx["nav_router"]` when present; else wraps legacy `ctx["map_rid"]` (and
## binds `ctx["body"]`) and caches the wrapper back into [param ctx] as `"nav_router"` so counters persist
## across the tick. Example: `var nav := NavRouter.from_ctx(ctx)`.
static func from_ctx(ctx: Dictionary) -> _Self:
  var existing: Variant = ctx.get("nav_router")
  if existing is _Self:
    return existing as _Self
  var legacy: Variant = ctx.get("map_rid", RID())
  var router := for_map(legacy if typeof(legacy) == TYPE_RID else RID(), ctx.get("body"))
  ctx["nav_router"] = router
  return router


## (Re)binds the node that exposes `get_navigation_map_rid()`. Cheap; the stack calls it each tick.
func set_main(main: Node) -> void:
  _main = main


## The profile queries are answered for: the bound body's cached profile, else an all-default profile.
func profile() -> RefCounted:
  if _body != null and is_instance_valid(_body) and _body.has_method(&"get_passability_profile"):
    var p: Variant = _body.call(&"get_passability_profile")
    if p != null:
      return p as RefCounted
  if _default_profile == null:
    _default_profile = _PassabilityProfile.from_body(null)
  return _default_profile


## The navigation map [param profile] queries. Phase 0: always the one shared map (profile ignored).
## Phase 1: resolves the (size class, variant) handle from Layer 1. Invalid RID when no map is available.
func map_for(_profile: RefCounted = null) -> RID:
  if _fixed_map.is_valid():
    return _fixed_map
  if _main != null and is_instance_valid(_main) and _main.has_method(&"get_navigation_map_rid"):
    return _main.call(&"get_navigation_map_rid") as RID
  return RID()


## True when [method map_for] yields a valid map and, for a main-bound router, the bake has finished
## (`is_navigation_ready()`). Fixed-map routers are ready when their RID is valid (fixtures await readiness
## themselves, e.g. `await_nav_ready`).
func is_ready() -> bool:
  if _fixed_map.is_valid():
    return true
  if _main == null or not is_instance_valid(_main):
    return false
  if _main.has_method(&"is_navigation_ready") and not bool(_main.call(&"is_navigation_ready")):
    return false
  return map_for().is_valid()


## True when a valid map handle exists (ignores bake readiness). Call sites use this where they used
## `map_rid.is_valid()`: queries against a not-yet-baked map just return empty paths.
func has_map() -> bool:
  return map_for().is_valid()


## Navigation-layer mask for [param profile] (Phase 0: [constant DEFAULT_QUERY_LAYERS]; adds
## [constant NAV_LAYER_CLIMB] when the profile carries the reserved CLIMB capability, which no link uses yet).
## Phase 1 adds per-size-class masks here, so call sites never pass a mask.
func navigation_layers_for(profile_in: RefCounted) -> int:
  var layers := DEFAULT_QUERY_LAYERS
  if profile_in != null and profile_in.has_method(&"has_capability"):
    if bool(profile_in.call(&"has_capability", _PassabilityProfile.CAP_CLIMB)):
      layers |= NAV_LAYER_CLIMB
  return layers


## Path from [param from] to [param to] on the map for [param profile_in] (null -> [method profile]).
## [param from] is first snapped to the surface under the body with [method query_origin]; pass
## [code]snap_origin=false[/code] when [param from] is already a navmesh point. Returns a Dictionary:
## - points: PackedVector3Array (empty when no map or no path; otherwise the funnel-optimised path)
## - reachable: bool (path non-empty and ends within [constant REACHABLE_END_TOLERANCE] of [param to])
## - link_segments: PackedInt32Array, indices i where segment points[i] -> points[i+1] crosses an off-mesh
##   link (always empty until climb links exist, D8.5)
## Example: `var r := nav.path(null, pos, goal); if r["points"].size() >= 2: ...`
func path(profile_in: RefCounted, from: Vector3, to: Vector3, snap_origin: bool = true) -> Dictionary:
  var result := {
    "points": PackedVector3Array(),
    "reachable": false,
    "link_segments": PackedInt32Array(),
  }
  var p := profile_in if profile_in != null else profile()
  var map := map_for(p)
  if not map.is_valid():
    return result
  path_queries += 1
  var t0 := timing_begin()
  var start := query_origin(p, from) if snap_origin else from
  var pts: PackedVector3Array = NavigationServer3D.map_get_path(
    map, start, to, true, navigation_layers_for(p)
  )
  timing_end(_NavTiming.COMP_PATH_QUERY, t0)
  result["points"] = pts
  if pts.size() >= 1:
    result["reachable"] = (
      pts.size() >= 2
      and _MotorPlane.horizontal_distance(pts[pts.size() - 1], to) <= REACHABLE_END_TOLERANCE
    )
  return result


## Closest navmesh point to [param point] for [param profile_in] (null -> [method profile]). Returns
## [param point] unchanged with no valid map or when the server answers its empty-map `Vector3.ZERO`
## sentinel. Example: `nav.closest_point(null, Vector3(3, 0, 40))` -> nearest walkable point.
func closest_point(profile_in: RefCounted, point: Vector3) -> Vector3:
  var map := map_for(profile_in if profile_in != null else profile())
  if not map.is_valid():
    return point
  var t0 := timing_begin()
  var on_mesh := NavigationServer3D.map_get_closest_point(map, point)
  timing_end(_NavTiming.COMP_PATH_QUERY, t0)
  if on_mesh == Vector3.ZERO and point.length_squared() > 1e-6:
    return point
  return on_mesh


## Navmesh point to use as the START of a path query for a body at [param body_pos]: the surface directly
## beneath the body, or the nearest navmesh point to that vertical line when off-mesh. A body's origin is
## its feet for authored bodies (Stage A), so the surface is just under it; legacy centred bodies sit higher
## ([constant NAV_QUERY_BELOW] covers them). Tall-capsule fix (2026-09-25): snapping by 3D distance from an
## elevated centre lands on the wrong surface on slopes. Returns [param body_pos] unchanged with no map or
## the server's empty-map `Vector3.ZERO` sentinel.
func query_origin(profile_in: RefCounted, body_pos: Vector3) -> Vector3:
  var map := map_for(profile_in)
  if not map.is_valid():
    return body_pos
  var hit := NavigationServer3D.map_get_closest_point_to_segment(
    map,
    body_pos + Vector3.UP * NAV_QUERY_ABOVE,
    body_pos + Vector3.DOWN * NAV_QUERY_BELOW,
    false,
  )
  if hit == Vector3.ZERO and _MotorPlane.horizontal_distance(body_pos, hit) > 1e-3:
    return body_pos
  return hit


## Records one route-scan truncation caused by a static (ghost-layer) obstacle. The scan sweeps only the
## ghost layer, which holds static object-scale obstacles, so every truncation it reports counts here
## (a high ratio means pathing truth and enforcement truth disagree, plan section 7).
func note_scan_truncated_static() -> void:
  scan_truncated_static += 1


## [member scan_truncated_static] / [member path_queries] (0.0 before the first query).
func scan_truncated_static_ratio() -> float:
  if path_queries <= 0:
    return 0.0
  return float(scan_truncated_static) / float(path_queries)


## Telemetry snapshot: `{path_queries, scan_truncated_static, ratio}` plus, only while
## [member NavTiming.enabled] and at least one sample exists, `timing` (see [method NavTiming.snapshot]).
func telemetry_snapshot() -> Dictionary:
  var out := {
    "path_queries": path_queries,
    "scan_truncated_static": scan_truncated_static,
    "ratio": scan_truncated_static_ratio(),
  }
  if _timing != null:
    out["timing"] = _timing.call(&"snapshot")
  return out


## Start stamp for a timed section: [code]Time.get_ticks_usec()[/code] when [member NavTiming.enabled], else 0
## (no clock read). Pair with [method timing_end]. Example: `var t0 := nav.timing_begin()`.
func timing_begin() -> int:
  if not _NavTiming.enabled:
    return 0
  return Time.get_ticks_usec()


## Adds the time since [param t0] (from [method timing_begin]) to [param component] (a `NavTiming.COMP_*`
## name) for this router's creature. No-op when [param t0] is 0 (timing was off at begin).
## Example: `nav.timing_end(NavTiming.COMP_GHOST_SCAN, t0)`.
func timing_end(component: StringName, t0: int) -> void:
  if t0 == 0:
    return
  timing_store().call(&"add", component, Time.get_ticks_usec() - t0)


## This creature's timing store (registered in the static [NavTiming] registry), created on first use.
## Key = bound body instance id, else this router's instance id.
func timing_store() -> RefCounted:
  if _timing == null:
    var id := get_instance_id()
    if _body != null and is_instance_valid(_body):
      id = _body.get_instance_id()
    _timing = _NavTiming.for_creature(id)
  return _timing
