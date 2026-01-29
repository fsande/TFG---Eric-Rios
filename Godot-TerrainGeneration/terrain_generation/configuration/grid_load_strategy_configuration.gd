## @brief Configuration for grid-based chunk loading strategy.
##
## @details Loads chunks in a fixed radius around the camera position.
## Simple and predictable behavior suitable for most use cases.
@tool
class_name GridLoadStrategyConfiguration extends ChunkLoadStrategyConfiguration

## Load chunks within this radius (in chunk units)
@export_range(1, 20) var load_radius: int = 3

## Unload chunks beyond this radius (in chunk units)
@export_range(1, 30) var unload_radius: int = 5

## Maximum chunks to load per frame (optional, overrides parent config)
@export_range(1, 10) var max_chunks_load_per_frame: int = 2

## Maximum chunks to unload per frame (optional, overrides parent config)
@export_range(1, 20) var max_chunks_unload_per_frame: int = 4

## Fallback LOD distances when chunk doesn't have configured distances (in world units)
@export var fallback_lod_distances: Array[float] = [100.0, 200.0, 400.0]

func get_strategy_type() -> String:
	return "Grid"

func is_valid() -> bool:
	return load_radius > 0 and unload_radius >= load_radius

func get_strategy() -> ChunkLoadStrategy:
	var strategy := GridLoadStrategy.new()
	strategy.load_radius = load_radius
	strategy.fallback_lod_distances = fallback_lod_distances
	strategy.unload_radius = unload_radius
	strategy.max_loads_per_frame = max_chunks_load_per_frame
	strategy.max_unloads_per_frame = max_chunks_unload_per_frame
	return strategy

