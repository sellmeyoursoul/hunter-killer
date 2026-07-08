extends RefCounted
class_name BlockedObjectiveResolver
## §9 blocked-objective persist / switch / seek scoring ([CREATURE_MOVEMENT_V3.md §9](../../Project_Docs/Draft_Features/CREATURE_MOVEMENT_V3.md)).

const ACTION_PERSIST := &"persist"
const ACTION_SWITCH := &"switch"
const ACTION_SEEK := &"seek"

const _LearnReg := preload("res://creature/memory/stimulus_learn_registry.gd")


## Scores persist / switch / seek from locale + instance + kind layers; returns winning action.
static func resolve(
  ctx: Dictionary,
  incumbent_instance_id: int,
  incumbent_kind_id: StringName,
  motor_v3: Dictionary,
) -> Dictionary:
  var adapter: RefCounted = ctx.get("memory_adapter")
  var creature_pos: Vector3 = ctx.get("creature_pos", Vector3.ZERO)
  var env_grid: Variant = ctx.get("environment_grid", null)
  var neutral := float(motor_v3.get("kind_profile_neutral_prior", 0.5))
  var switch_thresh := int(motor_v3.get("passibility_fail_switch_threshold", 2))

  var locale_score := 0.5
  if adapter != null and adapter.has_method(&"consult_locale_seek"):
    var locale: Dictionary = adapter.consult_locale_seek(creature_pos, motor_v3, env_grid, {})
    locale_score = clampf(float(locale.get("replay_rank_score", 0.0)), 0.0, 1.0)
    if not bool(locale.get("active", false)):
      locale_score = 0.25

  var instance_score := 1.0
  var pass_fail := 0
  if adapter != null and incumbent_instance_id != 0:
    var beliefs: Dictionary = adapter.get_beliefs() if adapter.has_method(&"get_beliefs") else {}
    var row: Variant = beliefs.get(incumbent_instance_id, {})
    if typeof(row) == TYPE_DICTIONARY:
      pass_fail = int((row as Dictionary).get("passibility_fail_count", 0))
      if not bool((row as Dictionary).get("consumable_now", true)):
        instance_score = 0.2
      elif pass_fail >= switch_thresh:
        instance_score = 0.15
      else:
        instance_score = 1.0 - float(pass_fail) * 0.25

  var kind_score := neutral
  if adapter != null and adapter.has_method(&"consult_kind_facet") and incumbent_kind_id != &"":
    kind_score = float(
      adapter.consult_kind_facet(_LearnReg.FACET_NUTRITION_YIELD, incumbent_kind_id, motor_v3)
    )

  var persist_score := locale_score * instance_score * kind_score
  var switch_score := _switch_score(ctx, incumbent_instance_id, incumbent_kind_id, motor_v3, neutral)
  var seek_score := 1.0 - persist_score

  var chaos := clampf(float(motor_v3.get("goal_consideration_chaos", 0.15)), 0.0, 1.0)
  var best_action := ACTION_PERSIST
  var best_val := persist_score
  for action in [ACTION_SWITCH, ACTION_SEEK]:
    var val := switch_score if action == ACTION_SWITCH else seek_score
    if val > best_val:
      best_val = val
      best_action = action
    elif chaos > 0.0 and abs(val - best_val) <= chaos * maxf(abs(best_val), 1e-6):
      if randf() < 0.5:
        best_val = val
        best_action = action

  return {
    "action": best_action,
    "persist_score": persist_score,
    "switch_score": switch_score,
    "seek_score": seek_score,
    "locale_score": locale_score,
    "instance_score": instance_score,
    "kind_score": kind_score,
    "passibility_fail_count": pass_fail,
  }


static func _switch_score(
  ctx: Dictionary,
  incumbent_instance_id: int,
  incumbent_kind_id: StringName,
  motor_v3: Dictionary,
  neutral: float,
) -> float:
  var adapter: RefCounted = ctx.get("memory_adapter")
  if adapter == null:
    return 0.0
  var creature_pos: Vector3 = ctx.get("creature_pos", Vector3.ZERO)
  var food_split: Dictionary = ctx.get("food_split", {})
  var best_alt := 0.0
  for key in ["ready", "unready"]:
    for entry_v in food_split.get(key, []) as Array:
      if typeof(entry_v) != TYPE_DICTIONARY:
        continue
      var entry: Dictionary = entry_v
      var iid := int(entry.get("instance_id", 0))
      if iid == incumbent_instance_id:
        continue
      var kind_id: StringName = entry.get("stimulus_kind_id", &"")
      var yield_v := neutral
      if adapter.has_method(&"consult_kind_facet"):
        yield_v = float(adapter.consult_kind_facet(_LearnReg.FACET_NUTRITION_YIELD, kind_id, motor_v3))
      var incumbent_yield := neutral
      if incumbent_kind_id != &"":
        incumbent_yield = float(
          adapter.consult_kind_facet(_LearnReg.FACET_NUTRITION_YIELD, incumbent_kind_id, motor_v3)
        )
      if yield_v > incumbent_yield + 0.05:
        best_alt = maxf(best_alt, yield_v)
  if best_alt > 0.0:
    return best_alt
  var now_ms := int(ctx.get("now_ms", Time.get_ticks_msec()))
  if adapter.has_method(&"consult_precise_food"):
    var precise: Dictionary = adapter.consult_precise_food(
      creature_pos, motor_v3, food_split, now_ms
    )
    if bool(precise.get("active", false)):
      var alt_iid := int(precise.get("instance_id", 0))
      if alt_iid != incumbent_instance_id:
        return 0.6
  return 0.2
