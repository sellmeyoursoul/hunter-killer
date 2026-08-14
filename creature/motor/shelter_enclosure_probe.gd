extends RefCounted
class_name ShelterEnclosureProbe
## Enclosure/squeeze-fit ring probe for GK_SHELTER candidate nomination + STAY-evaluate confirm
## (CREATURE_MOVEMENT_V3.md §6.4).

const RING_SAMPLES := 8


## Fraction (0..1) of a full-circle ray fan at [param probe_radius] around [param center] that
## hits [param blocker_mask] — how "enclosed" this point is by whatever geometry sits on that
## mask. Mask is the THREAT's blocker layer, not the probing body's own collision_mask — this
## measures whether a predator would be stopped here, not whether the wandering creature itself is.
static func enclosure_fraction(
  space_state: PhysicsDirectSpaceState3D,
  center: Vector3,
  probe_radius: float,
  blocker_mask: int,
  probe_height: float = 1.0,
  sample_count: int = RING_SAMPLES,
  exclude_rids: Array = [],
) -> float:
  if space_state == null or probe_radius <= 0.0:
    return 0.0
  var origin := Vector3(center.x, center.y + probe_height, center.z)
  var blocked := 0
  for i in sample_count:
    var ang := TAU * float(i) / float(sample_count)
    var to := origin + Vector3(cos(ang), 0.0, sin(ang)) * probe_radius
    var query := PhysicsRayQueryParameters3D.create(origin, to)
    query.collision_mask = blocker_mask
    for rid in exclude_rids:
      if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
        query.exclude.append(rid as RID)
    if not space_state.intersect_ray(query).is_empty():
      blocked += 1
  return float(blocked) / float(maxi(1, sample_count))
