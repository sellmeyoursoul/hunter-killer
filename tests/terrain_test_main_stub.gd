extends Node
## Minimal main stub for headless terrain motor tests.


const _GroundSampler := preload("res://environment/playfield_ground_sampler.gd")


var ground_sampler: _GroundSampler


func get_ground_sampler() -> _GroundSampler:
  return ground_sampler
