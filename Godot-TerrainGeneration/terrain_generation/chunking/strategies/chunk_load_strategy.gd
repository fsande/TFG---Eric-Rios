## @brief Base interface for chunk loading strategies.
##
## @details Implement this to create custom logic for determining
## which chunks should be loaded/unloaded based on camera position.
## Supports priority-based loading and configurable load budgets.
class_name ChunkLoadStrategy extends RefCounted

## Determine if a chunk should be loaded
##
## @param chunk The chunk to evaluate
## @param camera_pos Current camera position in world space
## @param context Additional context (loaded chunks, frame budget, etc.)
## @return true if chunk should be loaded, false otherwise
func should_load_chunk(chunk: ChunkMeshData, camera_pos: Vector3, context: ChunkLoadContext) -> bool:
#	push_error("ChunkLoadStrategy.should_load_chunk() must be overridden in subclass")
	return true

## Determine if a loaded chunk should be unloaded
##
## @param chunk The currently loaded chunk
## @param camera_pos Current camera position
## @param context Additional context
## @return true if chunk should be unloaded
func should_unload_chunk(chunk: ChunkMeshData, camera_pos: Vector3, context: ChunkLoadContext) -> bool:
	return false

## Calculate loading priority for a chunk (higher = load sooner)
##
## @param chunk The chunk to evaluate
## @param camera_pos Current camera position
## @return Priority value (higher = more important)
func get_load_priority(chunk: ChunkMeshData, camera_pos: Vector3) -> float:
	return 0.0

## Get maximum number of chunks to load/unload per frame
## @return Vector2i(max_loads, max_unloads)
func get_max_operations_per_frame() -> Vector2i:
	return Vector2i(2, 4)

## Called when strategy is activated (optional initialization)
func on_activated(chunk_manager: Node) -> void:
	pass

## Called when strategy is deactivated (optional cleanup)
func on_deactivated() -> void:
	pass

