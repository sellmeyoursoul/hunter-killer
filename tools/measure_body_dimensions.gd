extends SceneTree
## Headless body-dimension measuring tool (CREATURE_BODY_DIMENSIONS Phase 0, tool 4.6 (a)).
##
## Read-only. For each creature model it reports the whole-mesh rest-pose AABB (L/W/H, B7),
## the pivot offset vs the B10 convention (ground contact, XZ-centred), the long horizontal
## axis (forward-axis evidence, B22: +Z), and per-axis pass/warn/fail vs design intent (B20).
## Tolerances come from res://tools/body_dimension_spec.json (B18).
##
## Usage:
##   godot --path . --headless -s res://tools/measure_body_dimensions.gd
##   godot --path . --headless -s res://tools/measure_body_dimensions.gd -- res://path/model.tscn [species]
## Exit code is non-zero only when a production (non-placeholder) model fails.

const _SPEC_PATH := "res://tools/body_dimension_spec.json"
const _MeshWorldAabb3D := preload("res://environment/mesh_world_aabb_3d.gd")

## TODO: replace with archetype reads (body_length/width/height) once Phase 1/2 land.
## Design-intent dimensions in game units (B20). Axes: L = Z extent, W = X extent, H = Y extent.
## "placeholder" mirrors the future pack_resources.json flag (B19); TODO read it from the pack.
const _DESIGN_INTENT := {
  "rabbit": {"length": 1.7, "width": 0.7, "height": 1.4, "placeholder": true},
  "fox": {"length": 2.0, "width": 0.4, "height": 0.9, "placeholder": true},
  "wolf": {"length": 6.0, "width": 1.3, "height": 3.0, "placeholder": true},
}

## Shipped models: label, species key, scene path.
const _SHIPPED: Array = [
  ["rabbit raw", "rabbit", "res://assets/creatures/rabbit/rabbit.blend"],
  ["fox raw", "fox", "res://assets/creatures/fox/fox.blend"],
  ["wolf raw", "wolf", "res://assets/creatures/wolf/wolf.blend"],
  ["wolf as-mounted (3x wrapper)", "wolf", "res://assets/creatures/wolf/wolf_3d.tscn"],
]

var _spec: Dictionary = {}
var _production_fail := false


func _init() -> void:
  _spec = _load_spec()
  if _spec.is_empty():
    printerr("body_dims: cannot read %s" % _SPEC_PATH)
    quit(2)
    return
  var args := OS.get_cmdline_user_args()
  if args.size() > 0:
    var species := String(args[1]) if args.size() > 1 else ""
    _report("custom", species, String(args[0]))
  else:
    for entry in _SHIPPED:
      _report(String(entry[0]), String(entry[1]), String(entry[2]))
  quit(1 if _production_fail else 0)


## Loads the shared tolerance spec JSON; returns an empty Dictionary on failure.
func _load_spec() -> Dictionary:
  var f := FileAccess.open(_SPEC_PATH, FileAccess.READ)
  if f == null:
    return {}
  var parsed: Variant = JSON.parse_string(f.get_as_text())
  return parsed if parsed is Dictionary else {}


## Measures one model and prints its report block.
## [param label] display name; [param species] key into _DESIGN_INTENT ("" = no comparison);
## [param path] resource path of the model scene.
func _report(label: String, species: String, path: String) -> void:
  print("")
  print("=== %s  [%s]  %s" % [label, species if species != "" else "-", path])
  var res: Resource = load(path)
  if not (res is PackedScene):
    print("  ERROR: not loadable as PackedScene (headless import missing?)")
    return
  var root: Node = (res as PackedScene).instantiate()
  var m := measure_model(root)
  if not bool(m.get("valid", false)):
    print("  ERROR: no mesh AABB")
    root.free()
    return
  var mn: Vector3 = m["min"]
  var mx: Vector3 = m["max"]
  var size := mx - mn
  var length := size.z
  var width := size.x
  var height := size.y
  print("  AABB min=%s max=%s" % [_fmt_v(mn), _fmt_v(mx)])
  print("  raw  L(z)=%.3f  W(x)=%.3f  H(y)=%.3f" % [length, width, height])
  _report_pivot(mn, mx, length)
  _report_forward(m, size)
  if _DESIGN_INTENT.has(species):
    if width > length:
      print("  design comparison below assumes a 90 deg yaw fix: L := X extent %.3f, W := Z extent %.3f" % [width, length])
      _report_design(_DESIGN_INTENT[species], width, length, height)
    else:
      _report_design(_DESIGN_INTENT[species], length, width, height)
  else:
    print("  design intent: none (model-first proposal) body_length=%.3f body_width=%.3f body_height=%.3f" % [length, width, height])
  root.free()


## Computes the rest-pose AABB (model space), plus the vertex centroid, for [param root].
## Returns {valid, min, max, centroid}.
func measure_model(root: Node) -> Dictionary:
  var out := _MeshWorldAabb3D.world_mesh_aabb(root)
  if not bool(out.get("valid", false)):
    return out
  var sum := Vector3.ZERO
  var n := 0
  var stack: Array[Node] = [root]
  while not stack.is_empty():
    var node: Node = stack.pop_back()
    for ch in node.get_children():
      stack.append(ch)
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
      var xf: Transform3D = _MeshWorldAabb3D.node_global_transform(node as MeshInstance3D)
      for v in (node as MeshInstance3D).mesh.get_faces():
        sum += xf * v
        n += 1
  out["centroid"] = sum / float(n) if n > 0 else Vector3.ZERO
  return out


## Prints the pivot offset vs the B10 convention (origin at AABB bottom-centre) with pass/fail.
func _report_pivot(mn: Vector3, mx: Vector3, length: float) -> void:
  var target := Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5)
  var tol := float(_spec.get("origin_position_tolerance_fraction", 0.02)) * length
  var ok := absf(target.x) <= tol and absf(target.y) <= tol and absf(target.z) <= tol
  print("  pivot: AABB bottom-centre relative to origin = %s (tol +/-%.3f)  -> %s" % [_fmt_v(target), tol, "PASS" if ok else "FAIL"])


## Prints the long horizontal axis and the centroid skew hint (evidence only, not a verdict).
func _report_forward(m: Dictionary, size: Vector3) -> void:
  var f: Array = _spec.get("forward_axis", [0, 0, 1])
  var long_is_z := size.z >= size.x
  var mn: Vector3 = m["min"]
  var mx: Vector3 = m["max"]
  var cen: Vector3 = m["centroid"]
  var mid := (mn + mx) * 0.5
  var skew := (cen.z - mid.z) if long_is_z else (cen.x - mid.x)
  var ext := size.z if long_is_z else size.x
  print("  forward: convention %s; long horizontal axis = %s (extent %.3f, L/W=%.2f)" % [str(f), "Z" if long_is_z else "X", ext, ext / maxf(0.0001, size.x if long_is_z else size.z)])
  print("    sign not determinable from AABB; vertex-centroid offset from AABB centre along long axis = %+.3f (%.1f%% of extent; hint only, mass bias is not proof of head direction)" % [skew, 100.0 * skew / maxf(0.0001, ext)])
  if not long_is_z:
    print("    WARN: long axis is X, not Z -> model likely rotated 90 deg vs +Z convention")


## Prints per-axis ratio vs design intent and the uniform-fit proportion check (B8, B4 step 4).
func _report_design(d: Dictionary, length: float, width: float, height: float) -> void:
  var placeholder := bool(d.get("placeholder", false))
  var dl := float(d["length"])
  var dw := float(d["width"])
  var dh := float(d["height"])
  print("  design L/W/H = %.2f / %.2f / %.2f%s" % [dl, dw, dh, "  (placeholder: fail reported as warn)" if placeholder else ""])
  print("  raw ratio model/design  L=%.3f  W=%.3f  H=%.3f" % [length / dl, width / dw, height / dh])
  var s := dl / maxf(0.0001, length)
  print("  uniform fit on length: scale s=%.4f -> L=%.3f W=%.3f H=%.3f" % [s, length * s, width * s, height * s])
  var axes := [["L", length * s, dl], ["W", width * s, dw], ["H", height * s, dh]]
  var warn_f := float(_spec.get("proportion_warn_fraction", 0.10))
  var fail_f := float(_spec.get("proportion_fail_fraction", 0.20))
  for a in axes:
    var dev := (float(a[1]) - float(a[2])) / float(a[2])
    var verdict := "PASS"
    if absf(dev) > fail_f:
      verdict = "WARN(placeholder fail)" if placeholder else "FAIL"
      if not placeholder:
        _production_fail = true
    elif absf(dev) > warn_f:
      verdict = "WARN"
    print("    axis %s: fitted %.3f vs design %.3f  dev %+.1f%%  -> %s" % [a[0], a[1], a[2], dev * 100.0, verdict])


## Formats a Vector3 with 3 decimals.
func _fmt_v(v: Vector3) -> String:
  return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]
