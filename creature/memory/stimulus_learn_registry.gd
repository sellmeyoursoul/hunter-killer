extends RefCounted
class_name StimulusLearnRegistry
## Learn-topic registry — maps observation topics to kind-profile facets ([CREATURE_MEMORY.md §5.7](../../Project_Docs/Draft_Features/CREATURE_MEMORY.md)).

const TOPIC_NUTRITION_YIELD := &"nutrition_yield"
const TOPIC_THREAT_DANGER := &"threat_danger"

const FACET_NUTRITION_YIELD := &"nutrition_yield"
const FACET_THREAT_DANGER := &"threat_danger"

const _TOPIC_TO_FACET: Dictionary = {
  TOPIC_NUTRITION_YIELD: FACET_NUTRITION_YIELD,
  TOPIC_THREAT_DANGER: FACET_THREAT_DANGER,
}


## Returns the facet key for [param topic_id], or empty when unknown.
static func facet_for_topic(topic_id: StringName) -> StringName:
  var facet: Variant = _TOPIC_TO_FACET.get(topic_id, &"")
  if typeof(facet) == TYPE_STRING_NAME:
    return facet as StringName
  return &""
