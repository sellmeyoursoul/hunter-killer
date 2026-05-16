extends RefCounted
class_name CreaturePredationMath
## Single definition for predator meal clamp at [param caloric_needs] (see [code]mob.gd[/code] [method add_calories_from_prey]).

static func apply_meal_to_predator(current_calories: float, caloric_needs: int, meal: int) -> float:
  return minf(float(caloric_needs), current_calories + float(maxi(0, meal)))
