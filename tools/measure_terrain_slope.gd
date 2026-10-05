extends SceneTree
## Headless terrain-slope / navmesh-coverage measuring tool (NAVIGATION_PASSABILITY_PLAN Phase 0 (g),
## §2.1, §11 "Terrain slope measurement", D8 / G11).
##
## Read-only: boots the real res://main_3d.tscn, waits for the real playfield navmesh bake, then
## reports (all numbers are tagged MEASURED / REPLICATED / UNAVAILABLE):
##   1. effective NavigationMesh bake parameters (read from the real baked mesh) + body floor_max_angle
##      / floor_snap_length (read from a real mounted body).
##   2. slope histogram of the terrain (1 m grid of terrain-only downward rays; prop colliders excluded).
##   3. per slope bin: fraction of terrain samples covered by the real baked navmesh (interior samples
##      only: away from props and the terrain edge, so agent-radius erosion does not mask the step limit).
##   4. what boulders / solid shrubs / the playfield edge do when agent_max_slope / agent_max_climb are
##      raised: REPLICATED re-bakes (same source geometry + same parameters as the real bake, only the two
##      limits changed) counted as walkable area on obstacle tops/sides and in the edge band.
##   5. live radius / capsule height / reach / floor angle of the shipped rabbit, fox, wolf bodies.
##
## Usage:
##   godot --path . --headless -s res://tools/measure_terrain_slope.gd
## Exit code: 0 when the report ran, 1 on a setup error (no navmesh, no terrain, ...).

const _BIN_EDGES: Array[float] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0, 60.0, 90.01]
const _GRID_STEP_M := 1.0
const _TRI_HASH_CELL_M := 2.0
const _COVER_Y_TOL_M := 0.5
const _EDGE_BAND_M := 2.0
## (label, agent_max_slope deg, agent_max_climb m) re-bake experiments; first entry mirrors the shipped bake.
const _VARIANTS: Array = [
  ["V0 shipped limits", -1.0, -1.0],
  ["V1 slope50 climb0.30", 50.0, 0.30],
  ["V2 slope50 climb0.45", 50.0, 0.45],
  ["V3 slope50 climb0.90", 50.0, 0.90],
  ["V4 slope85 climb1.20", 85.0, 1.20],
]
const _SPECIES: Array[String] = ["rabbit", "fox", "wolf"]
const _ARCHETYPES := {
  "rabbit": "res://creature/species/rabbit_archetype.tres",
  "fox": "res://creature/species/fox_archetype.tres",
  "wolf": "res://creature/species/wolf_archetype.tres",
}
const _Bounds3D := preload("res://environment/playfield_bounds_3d.gd")

var _main: Node3D
var _failed := false
## Terrain sample grid: Vector2i(ix, iz) -> {"y": float, "slope": float}; absent key = no ground.
var _terrain: Dictionary = {}
var _grid_min := Vector2.ZERO
var _grid_cells := Vector2i.ZERO
## Obstacles: Array of {"name", "kind", "aabb": AABB, "top": Vector3 (xz centre, top y), "has_top"}.
var _obstacles: Array[Dictionary] = []
var _prop_rids: Array[RID] = []


func _init() -> void:
  _run.call_deferred()


## Boots main, waits for the real bake, runs every section, then quits.
func _run() -> void:
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
  print("")
  print("=== measure_terrain_slope (Phase 0 g)  navmesh ready=%s after %d frames" % [_main.call("is_navigation_ready"), waited])
  var region := _main.get("_nav_region") as NavigationRegion3D
  if region == null or region.navigation_mesh == null or region.navigation_mesh.get_polygon_count() == 0:
    _fail("real bake produced no navmesh")
    return
  var nm := region.navigation_mesh
  _section_bake_params(region, nm)
  await _section_creatures()
  if not _collect_terrain_and_obstacles():
    _fail("no terrain samples")
    return
  var real_index := _build_tri_index(nm, region.global_transform)
  _section_histogram()
  _section_bin_coverage(real_index)
  await _section_variants(region, nm, real_index)
  print("")
  print("=== end of report")
  quit(1 if _failed else 0)


## Prints an error and quits non-zero.
func _fail(msg: String) -> void:
  printerr("measure_terrain_slope: " + msg)
  _failed = true
  quit(1)


# --------------------------------------------------------------------------------------------------
# 1. bake parameters
# --------------------------------------------------------------------------------------------------

## Section 1: NavigationMesh parameters read from the REAL baked mesh (MEASURED).
func _section_bake_params(region: NavigationRegion3D, nm: NavigationMesh) -> void:
  print("")
  print("--- 1. effective bake parameters [MEASURED from the real region's baked NavigationMesh]")
  print("  region transform origin=%s  main origin=%s" % [region.global_transform.origin, _main.global_transform.origin])
  print("  agent_max_slope = %.2f deg  (never assigned in _bake_playfield_navmesh; no .tscn/.tres/.gd override found -> engine default)" % nm.agent_max_slope)
  print("  agent_max_climb = %.3f m   agent_radius = %.3f m   agent_height = %.3f m" % [nm.agent_max_climb, nm.agent_radius, nm.agent_height])
  print("  cell_size = %.3f m   cell_height = %.3f m" % [nm.cell_size, nm.cell_height])
  print("  polygons = %d  vertices = %d  collision_mask = %d  parsed_type = %d" % [nm.get_polygon_count(), nm.get_vertices().size(), nm.geometry_collision_mask, nm.geometry_parsed_geometry_type])
  var step_deg := rad_to_deg(atan(nm.agent_max_climb / nm.cell_size))
  print("  derived step-limit slope = atan(agent_max_climb / cell_size) = atan(%.3f / %.3f) = %.2f deg  (G11 suspected ~31)" % [nm.agent_max_climb, nm.cell_size, step_deg])


# --------------------------------------------------------------------------------------------------
# 5. creatures (and floor angle part of 1)
# --------------------------------------------------------------------------------------------------

## Section 1b + 5: mounted bodies. Uses the bodies the live game spawns via new_game(); any species the
## game roster does not spawn is mounted standalone from its archetype body_scene (labelled).
func _section_creatures() -> void:
  print("")
  print("--- 1b/5. creature bodies: floor angle / snap + live radius, capsule height, reach")
  _main.call("new_game")
  for _i in 6:
    await process_frame
  var found: Dictionary = {}
  for body in _main.call("get_all_creature_bodies"):
    var sp := _species_of(body)
    if sp != "" and not found.has(sp):
      found[sp] = {"body": body, "src": "MEASURED live game body"}
  var spare: Array[Node] = []
  for sp in _SPECIES:
    if found.has(sp):
      continue
    var def := load(String(_ARCHETYPES[sp])) as CreatureDefinition
    if def == null or def.body_scene == null:
      continue
    var croot := def.body_scene.instantiate() as Node3D
    croot.set("definition", def)
    _main.add_child(croot)
    croot.global_position = Vector3(0.0, 500.0, 0.0)
    spare.append(croot)
    found[sp] = {"body": croot.get_node("Body"), "src": "MEASURED standalone mount of archetype body_scene (species not spawned by the game roster)"}
  for _i in 4:
    await process_frame
  for sp in _SPECIES:
    if not found.has(sp):
      print("  %s: UNAVAILABLE (no archetype / body)" % sp)
      continue
    var b := found[sp]["body"] as CharacterBody3D
    var cs := b.get_node_or_null("CollisionShape3D") as CollisionShape3D
    var shape_txt := "no capsule"
    if cs != null and cs.shape is CapsuleShape3D:
      var cap := cs.shape as CapsuleShape3D
      shape_txt = "shape r=%.3f h=%.3f scale=%.2f" % [cap.radius, cap.height, b.scale.x]
    print("  %-6s radius=%.3f  capsule_height=%.3f  reach=%.3f  | %s | floor_max_angle=%.2f deg (%.4f rad) floor_snap_length=%.2f  [%s]" % [
      sp, float(b.call("get_body_radius")), float(b.call("get_collision_capsule_height")),
      float(b.call("get_reach_extent")), shape_txt, rad_to_deg(b.floor_max_angle), b.floor_max_angle,
      b.floor_snap_length, found[sp]["src"],
    ])
  for n in spare:
    n.queue_free()


## Species id string of a spawned body's creature root definition ("" when unknown).
func _species_of(body: Node) -> String:
  var def: Variant = body.get_parent().get("definition") if body.get_parent() != null else null
  if def == null:
    return ""
  return String(def.get("species_id"))


# --------------------------------------------------------------------------------------------------
# 2. terrain sampling + histogram
# --------------------------------------------------------------------------------------------------

## Casts a terrain-only (props excluded) downward ray grid over the playfield XZ bounds and records
## obstacles. Returns false when no terrain was hit.
func _collect_terrain_and_obstacles() -> bool:
  _prop_rids.clear()
  _obstacles.clear()
  var obstacles_root := _main.get("_obstacles_root") as Node3D
  var food_root := _main.get("_food_root") as Node3D
  var space := _main.get_world_3d().direct_space_state
  for prop_root in [obstacles_root, food_root]:
    if prop_root == null:
      continue
    for ch in prop_root.get_children():
      if not (ch is Node3D):
        continue
      var rids: Array[RID] = []
      _rids_under(ch, rids)
      var layer1 := false
      for n in _collision_objects_under(ch):
        if (n.collision_layer & 1) != 0:
          layer1 = true
      for r in rids:
        _prop_rids.append(r)
      if not layer1:
        continue
      var aabb_d := _Bounds3D.world_mesh_aabb(ch)
      if not bool(aabb_d.get("valid", false)):
        continue
      var mn: Vector3 = aabb_d["min"]
      var mx: Vector3 = aabb_d["max"]
      _obstacles.append({
        "name": String(ch.name),
        "kind": "boulder" if prop_root == obstacles_root else "solid_shrub",
        "perimeter": not ch.is_in_group(&"obstacles") and prop_root == obstacles_root,
        "aabb": AABB(mn, mx - mn),
        "rids": rids,
      })
  var bmin: Vector2 = _main.call("get_motor_playfield_bounds_min")
  var bmax: Vector2 = _main.call("get_motor_playfield_bounds_max")
  _grid_min = bmin
  _grid_cells = Vector2i(int((bmax.x - bmin.x) / _GRID_STEP_M), int((bmax.y - bmin.y) / _GRID_STEP_M))
  var floor_y := 0.0
  var hits := 0
  for iz in _grid_cells.y:
    for ix in _grid_cells.x:
      var xz := _grid_xz(ix, iz)
      var h := _terrain_hit(space, xz.x, xz.y, floor_y)
      if h.is_empty():
        continue
      var nrm: Vector3 = h["normal"]
      _terrain[Vector2i(ix, iz)] = {"y": float((h["position"] as Vector3).y), "slope": rad_to_deg(acos(clampf(nrm.y, -1.0, 1.0)))}
      hits += 1
  # obstacle tops: ray at the AABB XZ centre hitting only that obstacle.
  for o in _obstacles:
    var ab: AABB = o["aabb"]
    var c := ab.get_center()
    var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, ab.end.y + 5.0, c.z), Vector3(c.x, ab.position.y - 5.0, c.z))
    q.collision_mask = 1
    var hit := space.intersect_ray(q)
    o["has_top"] = false
    if not hit.is_empty() and (o["rids"] as Array).has(hit["rid"]):
      o["has_top"] = true
      o["top"] = Vector3(c.x, (hit["position"] as Vector3).y, c.z)
  print("")
  print("  [terrain samples: %d x %d grid at %.1f m, %d with ground; %d obstacle(s) found: %d boulder, %d solid shrub]" % [
    _grid_cells.x, _grid_cells.y, _GRID_STEP_M, hits, _obstacles.size(),
    _count_kind("boulder"), _count_kind("solid_shrub"),
  ])
  return hits > 0


## World XZ of grid cell centre (ix, iz).
func _grid_xz(ix: int, iz: int) -> Vector2:
  return _grid_min + Vector2((float(ix) + 0.5) * _GRID_STEP_M, (float(iz) + 0.5) * _GRID_STEP_M)


func _count_kind(kind: String) -> int:
  var n := 0
  for o in _obstacles:
    if String(o["kind"]) == kind:
      n += 1
  return n


## Terrain-only downward ray (layer 1, prop colliders excluded) at (x, z). Empty Dictionary = no ground.
func _terrain_hit(space: PhysicsDirectSpaceState3D, x: float, z: float, hint_y: float) -> Dictionary:
  var q := PhysicsRayQueryParameters3D.create(
    Vector3(x, hint_y + _Bounds3D.GROUND_RAY_HEIGHT, z), Vector3(x, hint_y - _Bounds3D.GROUND_RAY_DEPTH, z)
  )
  q.collision_mask = 1
  q.exclude = _prop_rids
  return space.intersect_ray(q)


func _rids_under(node: Node, out: Array[RID]) -> void:
  if node is CollisionObject3D:
    out.append((node as CollisionObject3D).get_rid())
  for ch in node.get_children():
    _rids_under(ch, out)


func _collision_objects_under(node: Node) -> Array[CollisionObject3D]:
  var out: Array[CollisionObject3D] = []
  var stack: Array[Node] = [node]
  while not stack.is_empty():
    var n: Node = stack.pop_back()
    if n is CollisionObject3D:
      out.append(n as CollisionObject3D)
    for ch in n.get_children():
      stack.append(ch)
  return out


## Index of [constant _BIN_EDGES] bin holding [param slope_deg].
func _bin_of(slope_deg: float) -> int:
  for i in range(_BIN_EDGES.size() - 1):
    if slope_deg >= _BIN_EDGES[i] and slope_deg < _BIN_EDGES[i + 1]:
      return i
  return _BIN_EDGES.size() - 2


func _bin_label(i: int) -> String:
  return "%2d-%2d deg" % [int(_BIN_EDGES[i]), mini(90, int(_BIN_EDGES[i + 1]))]


## Section 2: slope histogram (counts = m^2 at 1 m sampling).
func _section_histogram() -> void:
  print("")
  print("--- 2. terrain slope histogram [MEASURED: terrain-only face normals from rays, 1 sample = %.0f m^2]" % (_GRID_STEP_M * _GRID_STEP_M))
  var counts: Array[int] = []
  counts.resize(_BIN_EDGES.size() - 1)
  counts.fill(0)
  var smax := 0.0
  for k in _terrain:
    var s: float = _terrain[k]["slope"]
    counts[_bin_of(s)] += 1
    smax = maxf(smax, s)
  var total := _terrain.size()
  for i in counts.size():
    print("  %s  %7d m^2  %5.1f%%  %s" % [_bin_label(i), counts[i], 100.0 * counts[i] / float(total), "#".repeat(int(60.0 * counts[i] / float(total)))])
  print("  max sampled slope = %.1f deg over %d samples" % [smax, total])


# --------------------------------------------------------------------------------------------------
# 3. per-bin coverage of the real bake
# --------------------------------------------------------------------------------------------------

## True when terrain cell (ix, iz) is "interior": no ground-less cell within [constant _EDGE_BAND_M] and
## outside every obstacle AABB expanded by the bake agent radius + 0.5 m.
func _is_interior(ix: int, iz: int, clearance: float) -> bool:
  var r := int(ceil(_EDGE_BAND_M / _GRID_STEP_M))
  for dz in range(-r, r + 1):
    for dx in range(-r, r + 1):
      if not _terrain.has(Vector2i(ix + dx, iz + dz)):
        return false
  var xz := _grid_xz(ix, iz)
  for o in _obstacles:
    var ab: AABB = (o["aabb"] as AABB).grow(clearance)
    if xz.x >= ab.position.x and xz.x <= ab.end.x and xz.y >= ab.position.z and xz.y <= ab.end.z:
      return false
  return true


## True when [param xz] / height [param y] lies on a triangle of [param index] within [constant _COVER_Y_TOL_M].
func _covered(index: Dictionary, xz: Vector2, y: float) -> bool:
  var key := Vector2i(int(floor(xz.x / _TRI_HASH_CELL_M)), int(floor(xz.y / _TRI_HASH_CELL_M)))
  var bucket: Variant = (index["grid"] as Dictionary).get(key)
  if bucket == null:
    return false
  var tris: PackedVector3Array = index["tris"]
  for t in (bucket as PackedInt32Array):
    var a := tris[t * 3]
    var b := tris[t * 3 + 1]
    var c := tris[t * 3 + 2]
    var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
    if absf(d) < 1e-9:
      continue
    var l1 := ((b.z - c.z) * (xz.x - c.x) + (c.x - b.x) * (xz.y - c.z)) / d
    var l2 := ((c.z - a.z) * (xz.x - c.x) + (a.x - c.x) * (xz.y - c.z)) / d
    var l3 := 1.0 - l1 - l2
    if l1 < -0.001 or l2 < -0.001 or l3 < -0.001:
      continue
    if absf(l1 * a.y + l2 * b.y + l3 * c.y - y) <= _COVER_Y_TOL_M:
      return true
  return false


## Triangulates [param nm] (fan per polygon, vertices moved to world space by [param xf]) and builds a
## 2 m spatial hash over triangle XZ bounds. Returns {tris: PackedVector3Array, grid: Dictionary, area: float}.
func _build_tri_index(nm: NavigationMesh, xf: Transform3D) -> Dictionary:
  var verts := nm.get_vertices()
  var tris := PackedVector3Array()
  var grid: Dictionary = {}
  var area := 0.0
  for p in nm.get_polygon_count():
    var poly := nm.get_polygon(p)
    for k in range(1, poly.size() - 1):
      var a := xf * verts[poly[0]]
      var b := xf * verts[poly[k]]
      var c := xf * verts[poly[k + 1]]
      var ti := int(tris.size() / 3.0)
      tris.append(a)
      tris.append(b)
      tris.append(c)
      area += absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
      var x0 := int(floor(minf(a.x, minf(b.x, c.x)) / _TRI_HASH_CELL_M))
      var x1 := int(floor(maxf(a.x, maxf(b.x, c.x)) / _TRI_HASH_CELL_M))
      var z0 := int(floor(minf(a.z, minf(b.z, c.z)) / _TRI_HASH_CELL_M))
      var z1 := int(floor(maxf(a.z, maxf(b.z, c.z)) / _TRI_HASH_CELL_M))
      for gz in range(z0, z1 + 1):
        for gx in range(x0, x1 + 1):
          var key := Vector2i(gx, gz)
          var bucket: PackedInt32Array = grid.get(key, PackedInt32Array())
          bucket.append(ti)
          grid[key] = bucket
  return {"tris": tris, "grid": grid, "area": area}


## Fraction of each slope bin's interior samples covered by [param index]; returns the per-bin
## [covered, total] pairs.
func _coverage_by_bin(index: Dictionary, clearance: float) -> Array:
  var out: Array = []
  for _i in _BIN_EDGES.size() - 1:
    out.append([0, 0])
  for k in _terrain:
    var key: Vector2i = k
    if not _is_interior(key.x, key.y, clearance):
      continue
    var s: float = _terrain[k]["slope"]
    var bi := _bin_of(s)
    out[bi][1] += 1
    if _covered(index, _grid_xz(key.x, key.y), float(_terrain[k]["y"])):
      out[bi][0] += 1
  return out


## Section 3: coverage of the REAL bake per slope bin.
func _section_bin_coverage(real_index: Dictionary) -> void:
  var region := _main.get("_nav_region") as NavigationRegion3D
  var nm := region.navigation_mesh
  var clearance := nm.agent_radius + 0.5
  print("")
  print("--- 3. per-slope-bin coverage of the REAL bake [MEASURED]")
  print("  interior samples only (>= %.1f m from the ground edge, outside obstacle AABB + %.2f m); covered = point on a baked triangle within %.1f m height" % [_EDGE_BAND_M, clearance, _COVER_Y_TOL_M])
  var cov := _coverage_by_bin(real_index, clearance)
  var step_deg := rad_to_deg(atan(nm.agent_max_climb / nm.cell_size))
  for i in cov.size():
    var c: int = cov[i][0]
    var t: int = cov[i][1]
    var note := ""
    if t > 0 and float(c) / float(t) < 0.5 and _BIN_EDGES[i] >= step_deg - 5.0:
      note = "  <- mostly uncovered"
    print("  %s  interior samples %6d  covered %6d  = %5.1f%%%s" % [_bin_label(i), t, c, 100.0 * c / maxf(1.0, t), note])
  print("  step limit atan(climb/cell) = %.1f deg; engine agent_max_slope = %.1f deg; physics floor_max_angle = 50.0 deg (see 1b)" % [step_deg, nm.agent_max_slope])
  print("  verdict: %s" % _verdict(cov, step_deg))


## One-line confirm / deny of the G11 suspicion from the coverage table.
func _verdict(cov: Array, step_deg: float) -> String:
  var low_c := 0
  var low_t := 0
  var hi_c := 0
  var hi_t := 0
  for i in cov.size():
    if _BIN_EDGES[i + 1] <= step_deg - 1.0:
      low_c += cov[i][0]
      low_t += cov[i][1]
    elif _BIN_EDGES[i] >= step_deg + 1.0 and _BIN_EDGES[i] < 50.0:
      hi_c += cov[i][0]
      hi_t += cov[i][1]
  if hi_t == 0:
    return "INCONCLUSIVE: no interior terrain samples with slope in (%.0f, 50) deg (terrain never gets that steep at 1 m sampling)" % step_deg
  var lo_pct := 100.0 * low_c / maxf(1.0, low_t)
  var hi_pct := 100.0 * hi_c / float(hi_t)
  var word := "CONFIRMED (step-limit cap)" if hi_pct < lo_pct - 30.0 else "DENIED (steep bins covered about as well as shallow ones)"
  return "%s: below %.0f deg %.1f%% covered (%d samples), %.0f-50 deg %.1f%% covered (%d samples)" % [word, step_deg, lo_pct, low_t, step_deg, hi_pct, hi_t]


# --------------------------------------------------------------------------------------------------
# 4. replicated re-bakes with raised limits
# --------------------------------------------------------------------------------------------------

## Section 4: re-bakes the same source geometry with raised limits (REPLICATED) and counts walkable area
## on obstacle tops / sides / the edge band. V0 uses the shipped limits and is checked against the real bake.
func _section_variants(region: NavigationRegion3D, real_nm: NavigationMesh, real_index: Dictionary) -> void:
  print("")
  print("--- 4. raised agent_max_slope / agent_max_climb [REPLICATED: NavigationServer3D parse+bake of the real source group with the real bake's parameters; only the two limits change]")
  var space := _main.get_world_3d().direct_space_state
  var data := NavigationMeshSourceGeometryData3D.new()
  var tmpl := _clone_params(real_nm, real_nm.agent_max_slope, real_nm.agent_max_climb)
  NavigationServer3D.parse_source_geometry_data(tmpl, data, _main)
  if not data.has_data():
    print("  UNAVAILABLE: parse_source_geometry_data returned no geometry")
    return
  var clearance := real_nm.agent_radius + 0.5
  for v in _VARIANTS:
    var label: String = v[0]
    var slope: float = real_nm.agent_max_slope if float(v[1]) < 0.0 else float(v[1])
    var climb: float = real_nm.agent_max_climb if float(v[2]) < 0.0 else float(v[2])
    var nm := _clone_params(real_nm, slope, climb)
    var t0 := Time.get_ticks_msec()
    NavigationServer3D.bake_from_source_geometry_data(nm, data)
    var ms := Time.get_ticks_msec() - t0
    var idx := _build_tri_index(nm, region.global_transform)
    print("")
    print("  %s  (slope=%.1f climb=%.2f)  polys=%d tri_area=%.0f m^2  bake=%d ms  [real bake: polys=%d area=%.0f m^2]" % [
      label, slope, climb, nm.get_polygon_count(), float(idx["area"]), ms, real_nm.get_polygon_count(), float(real_index["area"]),
    ])
    var cov := _coverage_by_bin(idx, clearance)
    var parts: PackedStringArray = []
    for i in cov.size():
      if cov[i][1] > 0 and _BIN_EDGES[i] >= 20.0:
        parts.append("%d-%d:%.0f%%(n=%d)" % [int(_BIN_EDGES[i]), mini(90, int(_BIN_EDGES[i + 1])), 100.0 * cov[i][0] / float(cov[i][1]), cov[i][1]])
    print("    interior coverage 20+ deg bins: %s" % ", ".join(parts))
    _report_obstacles_and_edge(idx, space)
    await process_frame


## Copy of the real bake's parameter set with the two limits overridden.
func _clone_params(src: NavigationMesh, slope_deg: float, climb_m: float) -> NavigationMesh:
  var nm := NavigationMesh.new()
  nm.geometry_parsed_geometry_type = src.geometry_parsed_geometry_type
  nm.geometry_source_geometry_mode = src.geometry_source_geometry_mode
  nm.geometry_source_group_name = src.geometry_source_group_name
  nm.geometry_collision_mask = src.geometry_collision_mask
  nm.cell_size = src.cell_size
  nm.cell_height = src.cell_height
  nm.agent_radius = src.agent_radius
  nm.agent_height = src.agent_height
  nm.agent_max_slope = slope_deg
  nm.agent_max_climb = floorf(climb_m / src.cell_height + 0.001) * src.cell_height
  nm.region_min_size = src.region_min_size
  nm.region_merge_size = src.region_merge_size
  nm.edge_max_length = src.edge_max_length
  nm.edge_max_error = src.edge_max_error
  nm.vertices_per_polygon = src.vertices_per_polygon
  nm.detail_sample_distance = src.detail_sample_distance
  nm.detail_sample_max_error = src.detail_sample_max_error
  return nm


## Counts, for the triangles of [param idx]: area elevated on obstacle tops/sides (centroid inside an
## obstacle AABB footprint, > 0.4 m above the terrain-only ground there), obstacle tops reached, and area
## in the terrain-edge band. Prints one compact block per kind.
func _report_obstacles_and_edge(idx: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
  var tris: PackedVector3Array = idx["tris"]
  var elev_area := {"boulder": 0.0, "solid_shrub": 0.0}
  var elev_obstacles := {"boulder": {}, "solid_shrub": {}}
  var edge_area := 0.0
  var edge_tris := 0
  for t in range(int(tris.size() / 3.0)):
    var a := tris[t * 3]
    var b := tris[t * 3 + 1]
    var c := tris[t * 3 + 2]
    var cen := (a + b + c) / 3.0
    var area := absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
    var ix := int(floor((cen.x - _grid_min.x) / _GRID_STEP_M))
    var iz := int(floor((cen.z - _grid_min.y) / _GRID_STEP_M))
    if not _is_edge_free(ix, iz):
      edge_area += area
      edge_tris += 1
    for oi in _obstacles.size():
      var o: Dictionary = _obstacles[oi]
      var ab: AABB = (o["aabb"] as AABB).grow(0.1)
      if cen.x < ab.position.x or cen.x > ab.end.x or cen.z < ab.position.z or cen.z > ab.end.z:
        continue
      if cen.y < ab.position.y + 0.4:
        continue
      var h := _terrain_hit(space, cen.x, cen.z, 0.0)
      var ground_y := float((h["position"] as Vector3).y) if not h.is_empty() else ab.position.y
      if cen.y > ground_y + 0.4:
        elev_area[o["kind"]] += area
        (elev_obstacles[o["kind"]] as Dictionary)[oi] = true
  var tops := {"boulder": [0, 0], "solid_shrub": [0, 0]}
  for o in _obstacles:
    if not bool(o["has_top"]):
      continue
    var top: Vector3 = o["top"]
    var k: String = o["kind"]
    tops[k][1] += 1
    if _covered(idx, Vector2(top.x, top.z), top.y):
      tops[k][0] += 1
  for kind in ["boulder", "solid_shrub"]:
    print("    %-11s n=%2d  elevated navmesh area on tops/sides = %7.1f m^2 across %d obstacle(s); centre-of-top covered %d/%d" % [
      kind, _count_kind(kind), float(elev_area[kind]), (elev_obstacles[kind] as Dictionary).size(), tops[kind][0], tops[kind][1],
    ])
  print("    playfield edge band (<= %.1f m from a ground-less cell): %.1f m^2 in %d tris" % [_EDGE_BAND_M, edge_area, edge_tris])


## True when no ground-less grid cell lies within the edge band of (ix, iz) (inverse of "near edge"; cells
## outside the grid count as ground-less).
func _is_edge_free(ix: int, iz: int) -> bool:
  var r := int(ceil(_EDGE_BAND_M / _GRID_STEP_M))
  for dz in range(-r, r + 1):
    for dx in range(-r, r + 1):
      if not _terrain.has(Vector2i(ix + dx, iz + dz)):
        return false
  return true
