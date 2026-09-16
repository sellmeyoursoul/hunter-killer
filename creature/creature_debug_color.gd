extends RefCounted
class_name CreatureDebugColor
## Deterministic per-creature debug color, shared by the F9 awareness-zone overlay
## (`awareness_debug_overlay_3d.gd`) and the F10 motor debug HUD (`motor_planner_debug_hud.gd`) —
## both derive it independently from `creature_instance_id` alone, so a creature's awareness zone
## and its HUD entry always match with no cross-node wiring needed
## ([CM_V3_MULTI_MOBS.md](../Project_Docs/Draft_Features/CM_V3_MULTI_MOBS.md)).

const _FALLBACK_RGB := Color(0.25, 0.82, 1.0)
## Golden ratio conjugate — multiplicative hashing that spreads sequential/clustered instance ids
## (spawn order tends to assign nearby ids) across well-separated hues instead of similar ones.
const _GOLDEN_CONJUGATE := 0.6180339887498949


static func color_for_instance_id(iid: int, alpha: float = 1.0) -> Color:
  if iid == 0:
    return Color(_FALLBACK_RGB.r, _FALLBACK_RGB.g, _FALLBACK_RGB.b, alpha)
  ## `iid % 1_000_000` keeps the multiply in a float-precision-safe range before hashing — Godot
  ## instance ids can be large 64-bit values that would lose fractional precision otherwise.
  var h := fposmod(float(iid % 1000000) * _GOLDEN_CONJUGATE, 1.0)
  return Color.from_hsv(h, 0.85, 1.0, alpha)
