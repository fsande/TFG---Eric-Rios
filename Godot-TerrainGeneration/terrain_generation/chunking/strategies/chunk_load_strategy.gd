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

## Select appropriate LOD level for chunk based on distance/screen-space
## @param chunk The chunk to evaluate
## @param camera_pos Current camera position
## @param camera Reference to camera (for screen-space calculations)
## @return LOD level (0 = highest detail, higher = lower detail)
func select_lod_level(chunk: ChunkMeshData, camera_pos: Vector3, camera: Camera3D) -> int:
	# Default implementation: distance-based LOD
	var distance := chunk.distance_to(camera_pos)
	for i in range(chunk.lod_distances.size()):
		if distance < chunk.lod_distances[i]:
			return i
	return min(chunk.lod_distances.size(), chunk.lod_level_count - 1)

## Check if LOD should transition (with hysteresis to prevent oscillation)
## @param chunk The chunk to check
## @param current_lod Current LOD level
## @param camera_pos Current camera position
## @param camera Camera reference
## @param hysteresis_factor Hysteresis multiplier (1.1 = 10% buffer)
## @return New LOD level (same as current_lod if no change needed)
func get_target_lod_with_hysteresis(
	chunk: ChunkMeshData,
	current_lod: int,
	camera_pos: Vector3,
	camera: Camera3D,
	hysteresis_factor: float = 1.1
) -> int:
	var new_lod := select_lod_level(chunk, camera_pos, camera)
	if new_lod > current_lod:
		var distance := chunk.distance_to(camera_pos)
		if new_lod > 0 and new_lod - 1 < chunk.lod_distances.size():
			var threshold := chunk.lod_distances[new_lod - 1] * hysteresis_factor
			if distance < threshold:
				return current_lod
	return new_lod

## Called when strategy is activated (optional initialization)
func on_activated(chunk_manager: ChunkManager) -> void:
	pass

## Called when strategy is deactivated (optional cleanup)
func on_deactivated() -> void:
	pass

