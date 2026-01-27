## @brief Configuration for grid-based chunk loading strategy.
##
## @details Loads chunks in a fixed radius around the camera position.
## Simple and predictable behavior suitable for most use cases.
class_name GridLoadStrategyConfiguration extends ChunkLoadStrategyConfiguration

## Load chunks within this radius (in chunk units)
@export_range(1, 20) var load_radius: int = 3

## Unload chunks beyond this radius (in chunk units)
@export_range(1, 30) var unload_radius: int = 5

func get_strategy_type() -> String:
	return "Grid"

func is_valid() -> bool:
	return load_radius > 0 and unload_radius >= load_radius

