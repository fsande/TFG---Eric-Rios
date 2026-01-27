## @brief Configuration for frustum culling-based chunk loading strategy.
##
## @details Only loads chunks visible in the camera frustum.
## Most efficient for performance but can cause pop-in if not tuned properly.
class_name FrustumCullingStrategyConfiguration extends ChunkLoadStrategyConfiguration

## Extra margin beyond frustum to preload chunks (world units)
@export_range(0.0, 200.0) var preload_margin: float = 50.0

## Maximum chunks to keep loaded outside frustum
@export_range(0, 50) var max_outside_frustum: int = 10

## Enable hybrid mode with grid fallback
@export var use_grid_fallback: bool = true

## Grid fallback radius when hybrid mode is enabled
@export_range(1, 10) var fallback_radius: int = 2

func get_strategy_type() -> String:
	return "FrustumCulling"

func is_valid() -> bool:
	return preload_margin >= 0.0 and (not use_grid_fallback or fallback_radius > 0)