## @brief Base configuration for LOD generation strategies.
##
## @details Abstract base class for LOD generation strategy configurations.
## Follows the same factory pattern as ChunkLoadStrategyConfiguration.
@tool
class_name LODGenerationStrategyConfiguration extends Resource

## Validate if this configuration is valid
func is_valid() -> bool:
	return false

## Get the strategy type name
func get_strategy_type() -> String:
	return "Base"

## Create and configure the actual LOD generation strategy
func get_strategy() -> LODGenerationStrategy:
	return null
