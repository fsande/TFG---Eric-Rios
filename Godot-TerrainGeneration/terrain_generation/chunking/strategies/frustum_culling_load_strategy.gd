## @brief Frustum culling-based chunk loading strategy.
##
## @details Only loads chunks visible in the camera frustum with a preload margin.
## Most efficient for performance but requires careful tuning to avoid pop-in.
class_name FrustumCullingLoadStrategy extends ChunkLoadStrategy

func _init():
	push_error("FrustumCullingLoadStrategy: NOT IMPLEMENTED - Use GridLoadStrategy instead")
