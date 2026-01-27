## @brief Simple radius-based chunk loading strategy.
##
## @details Loads all chunks within a fixed radius from the camera,
## unloads chunks beyond a larger radius. Simple and predictable behavior.
class_name GridLoadStrategy extends ChunkLoadStrategy

## Load chunks within this many chunk units from camera
@export var load_radius_chunks: int = 3

## Unload chunks beyond this many chunk units (should be > load_radius)
@export var unload_radius_chunks: int = 5

## Chunk size in world units (set by ChunkManager)
var chunk_size_world: Vector2 = Vector2(100, 100)

func should_load_chunk(chunk: ChunkMeshData, camera_pos: Vector3, context: Dictionary) -> bool:
	# TODO: Implement radius-based load check
	return false

func should_unload_chunk(chunk: ChunkMeshData, camera_pos: Vector3, context: Dictionary) -> bool:
	# TODO: Implement radius-based unload check
	return false

func get_load_priority(chunk: ChunkMeshData, camera_pos: Vector3) -> float:
	# TODO: Implement distance-based priority
	return 0.0

func on_activated(chunk_manager: Node) -> void:
	# TODO: Initialize chunk size from manager
	pass

