extends RefCounted
class_name ShelterEnclosureProbe
## Enclosure/squeeze-fit ring probe for GK_SHELTER candidate nomination + STAY-evaluate confirm
## (CREATURE_MOVEMENT_V3.md §6.4).

const _GhostObstacleQuery := preload("res://creature/motor/ghost_obstacle_query.gd")

const RING_SAMPLES := 8


## Fraction (0..1) of a full-circle fan at [param probe_radius] around [param center] that's
## blocked on [param blocker_mask] — how "enclosed" this point is by whatever geometry sits on
## that mask. Mask is the THREAT's blocker layer, not the probing body's own collision_mask — this
## measures whether a predator would be stopped here, not whether the wandering creature itself is.
##
## PHYSICS_SQUEEZE.md §3 decision 13 (Stage A) / decision 33 (2026-09-21): when [param agent_radius]
## is positive, each sample sweeps a capsule of that radius/[param agent_height] outward
## ([GhostObstacleQuery.sweep_capsule_along_segment]) instead of casting a zero-width ray. A bare
## ray can slip straight through a gap that's real geometry but too narrow for a body of
## [param agent_radius] to actually pass — exactly the blind spot decision 25's investigation found
## in the rabbit's own per-step passability experience (a gap it never perceives as solid because
## its own capsule always clears it). Passing the *occupant's own* live capsule radius here is
## Stage A candidate nomination (self-radius only, no threat involved); Stage B's threat-radius
## disqualify gate is a separate, not-yet-built call site (§9 slice 9/10) using this same primitive.
## [param agent_radius] `<= 0.0` (the default) keeps the original zero-width raycast behavior,
## unchanged, for any caller not yet opted into the shape-cast sweep.
static func enclosure_fraction(
  space_state: PhysicsDirectSpaceState3D,
  center: Vector3,
  probe_radius: float,
  blocker_mask: int,
  probe_height: float = 1.0,
  sample_count: int = RING_SAMPLES,
  exclude_rids: Array = [],
  agent_radius: float = 0.0,
  agent_height: float = 0.0,
) -> float:
  if space_state == null or probe_radius <= 0.0:
    return 0.0
  var origin := Vector3(center.x, center.y + probe_height, center.z)
  if agent_radius > 0.0:
    ## A capsule that already overlaps the blocker mask right at `origin` can't be swept outward
    ## meaningfully — `cast_motion` only reports collisions found *along* the requested motion, and
    ## an already-overlapping start can come back as "no collision" (fully clear) depending on the
    ## engine's own handling, which would misread a pocket too tight for this body to even stand in
    ## as wide open. Short-circuit to fully enclosed instead: a body that doesn't fit at its own
    ## center clearly can't escape in every direction either.
    var overlap_shape := CapsuleShape3D.new()
    overlap_shape.radius = agent_radius
    overlap_shape.height = maxf(agent_height, agent_radius * 2.0)
    var overlap_query := PhysicsShapeQueryParameters3D.new()
    overlap_query.shape = overlap_shape
    overlap_query.collision_mask = blocker_mask
    overlap_query.transform = Transform3D(Basis(), origin)
    for rid in exclude_rids:
      if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
        overlap_query.exclude.append(rid as RID)
    if not space_state.intersect_shape(overlap_query, 1).is_empty():
      return 1.0
  var blocked := 0
  for i in sample_count:
    var ang := TAU * float(i) / float(sample_count)
    var to := origin + Vector3(cos(ang), 0.0, sin(ang)) * probe_radius
    var hit := false
    if agent_radius > 0.0:
      var reach := _GhostObstacleQuery.sweep_capsule_along_segment(
        space_state, origin, to, agent_radius, agent_height, exclude_rids, blocker_mask,
      )
      hit = reach < 0.999
    else:
      var query := PhysicsRayQueryParameters3D.create(origin, to)
      query.collision_mask = blocker_mask
      for rid in exclude_rids:
        if typeof(rid) == TYPE_RID and (rid as RID).is_valid():
          query.exclude.append(rid as RID)
      hit = not space_state.intersect_ray(query).is_empty()
    if hit:
      blocked += 1
  return float(blocked) / float(maxi(1, sample_count))
