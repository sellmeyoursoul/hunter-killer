extends Resource
class_name LocomotionProfile
## Tunable locomotion tuning for 3D creatures ([member CreatureDefinition.locomotion_profile]).
## Units: Godot 3D world space per second / per second² unless a phase fixes real-world scale.

@export var max_speed: float = 5.0
## Horizontal acceleration toward target velocity (units/s²).
@export var acceleration: float = 20.0
## When intent is zero, blend velocity toward rest (units/s²).
@export var friction: float = 12.0
## First-hop assist only; full jump rules belong in a later phase.
@export var jump_velocity: float = 4.5
## Multiplier on project default gravity when not on floor.
@export var gravity_multiplier: float = 1.0
