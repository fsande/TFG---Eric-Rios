## @brief Condition that checks if terrain size is within a range.
@tool
class_name TerrainSizeCondition extends TerrainCondition

@export var min_size: float = 0.0
@export var max_size: float = 10000.0

func evaluate(context: TerrainGenerationContext) -> bool:
	var size := context.terrain_size.x
	var result := size >= min_size and size <= max_size
	return _apply_invert(result)

func get_description() -> String:
	if condition_name != "":
		return condition_name
	return "TerrainSize in [%.0f, %.0f]" % [min_size, max_size]

