## @brief Base class for conditions used in ConditionalModifierStage.
##
## @details Enables runtime branching logic based on terrain context state.
@tool @abstract
class_name TerrainCondition extends Resource

@export var condition_name: String = ""
@export var invert: bool = false

@abstract func evaluate(_context: TerrainGenerationContext) -> bool

func get_description() -> String:
	if condition_name != "":
		return condition_name
	return get_script().get_global_name() if get_script() else "UnknownCondition"

func stringify() -> String:
	var desc := get_description()
	return ("NOT " + desc) if invert else desc

func _apply_invert(result: bool) -> bool:
	return not result if invert else result

func _get_display_name() -> String:
	return get_description()

