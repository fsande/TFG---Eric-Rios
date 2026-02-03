## @brief Condition that checks if terrain has steep slopes above a threshold.
@tool
class_name SlopeCondition extends TerrainCondition

@export var min_slope_degrees: float = 30.0
@export var sample_count: int = 50
@export var required_ratio: float = 0.1

func evaluate(context: TerrainGenerationContext) -> bool:
	if not context.reference_heightmap:
		return _apply_invert(false)
	var steep_count := 0
	var rng := context.create_rng(7777)
	for i in range(sample_count):
		var uv := Vector2(rng.randf(), rng.randf())
		var world_pos := context.uv_to_world(uv)
		var slope := context.calculate_slope_at(world_pos)
		if slope >= min_slope_degrees:
			steep_count += 1
	var ratio := float(steep_count) / float(sample_count)
	var result := ratio >= required_ratio
	return _apply_invert(result)

func get_description() -> String:
	if condition_name != "":
		return condition_name
	return "HasSteepSlopes(>%.0f°, %.0f%%)" % [min_slope_degrees, required_ratio * 100]

