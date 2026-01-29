## @brief Configuration for grid decimation LOD generation.
##
## @details Configures the grid-based mesh decimation strategy for terrain LOD generation.
## This strategy is optimal for heightmap-based terrain with regular grid structure.
@tool
class_name GridDecimationLODStrategyConfiguration extends LODGenerationStrategyConfiguration

func get_strategy_type() -> String:
	return "GridDecimation"

func is_valid() -> bool:
	return true

func get_strategy() -> LODGenerationStrategy:
	return GridDecimationLODStrategy.new()

