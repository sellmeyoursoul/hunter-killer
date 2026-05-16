extends Resource
class_name FoodIntakePolicy
## Data-only: which groups an intake / perception layer considers **plants** vs **prey**.
## Logic for overlap lives in capability scripts; policies stay reusable leaf data.

@export var plant_groups: Array = []
@export var prey_groups: Array = []
