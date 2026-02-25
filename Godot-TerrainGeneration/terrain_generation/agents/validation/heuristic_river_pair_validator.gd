## @brief Heuristic validator using straight-line sampling.
##
## @details Quick validation by sampling heights along straight line between
## coast and mountain. If too many samples are underwater, the pair is likely
## from different landmasses. Fast but not 100% accurate.
@tool
class_name HeuristicRiverPairValidator extends RiverPairValidator

## Number of samples along the line between points
@export_range(5, 100) var sample_count: int = 20

## Maximum allowed underwater percentage (0-1)
@export_range(0.0, 1.0) var max_underwater_ratio: float = 0.5

## Minimum height above sea level to count as land (adds buffer)
@export var land_buffer_height: float = 0.5

func is_pair_valid(
	coast_point: Vector2,
	mountain_point: Vector2,
	context: TerrainGenerationContext
) -> bool:
	if not context.reference_heightmap or not context.terrain_definition:
		return true
	var sea_level_normalized := context.terrain_definition.sea_level / context.height_scale
	var land_threshold := sea_level_normalized + (land_buffer_height / context.height_scale)
	var underwater_count := 0
	for i in range(sample_count):
		var t := float(i) / float(sample_count - 1)
		var sample_pos := coast_point.lerp(mountain_point, t)
		var height_norm := context.sample_height_at(sample_pos)
		if height_norm < land_threshold:
			underwater_count += 1

	var underwater_ratio := float(underwater_count) / float(sample_count)
	var is_valid := underwater_ratio <= max_underwater_ratio
	return is_valid

func get_strategy_name() -> String:
	return "Heuristic (Straight-line sampling)"
