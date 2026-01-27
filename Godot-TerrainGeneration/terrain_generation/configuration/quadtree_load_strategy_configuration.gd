## @brief Configuration for quadtree-based chunk loading strategy.
##
## @details Hierarchical loading with adaptive subdivision based on distance.
## More complex but provides better performance for large view distances.
class_name QuadTreeLoadStrategyConfiguration extends ChunkLoadStrategyConfiguration

## Maximum view distance for chunk loading
@export_range(100.0, 5000.0) var max_distance: float = 400.0

## Minimum chunk size before stopping subdivision (world units)
@export_range(10.0, 200.0) var min_chunk_size: float = 25.0

## Enable hierarchical loading (load parent chunks before children)
@export var hierarchical_loading: bool = true

## LOD bias factor (higher = more aggressive LOD)
@export_range(0.5, 2.0) var lod_bias: float = 1.0

func get_strategy_type() -> String:
	return "QuadTree"

func is_valid() -> bool:
	return max_distance > 0.0 and min_chunk_size > 0.0

