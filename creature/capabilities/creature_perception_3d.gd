extends RefCounted
class_name CreaturePerception3D
## Perception radius/cone scaling; LoS rays live in [code]line_of_sight.gd[/code] (M4).
## Params:
## - base_radius / base_half_angle_deg: from merged [code]creature_motor[/code] or local defaults.
## - definition: [CreatureDefinition] or [code]null[/code] (duck-typed for tooling that avoids hard [code]class_name[/code] refs).

static func effective_awareness_radius(base_radius: float, definition: Variant) -> float:
  if definition == null:
    return base_radius
  var s: Variant = definition.get("perception_radius_scale")
  if s == null:
    return base_radius
  return base_radius * float(s)


static func effective_cone_half_angle_deg(base_half_angle_deg: float, definition: Variant) -> float:
  if definition == null:
    return base_half_angle_deg
  var s: Variant = definition.get("awareness_cone_half_angle_scale")
  if s == null:
    return base_half_angle_deg
  return base_half_angle_deg * float(s)
