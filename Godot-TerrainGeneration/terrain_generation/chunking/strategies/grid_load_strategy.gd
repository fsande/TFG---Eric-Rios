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

func should_load_chunk(chunk: ChunkMeshData, camera_pos: Vector3, _context: Dictionary) -> bool:
	var camera_chunk_pos := _world_to_chunk_coord(camera_pos)
	var distance := _chunk_distance(chunk.chunk_coord, camera_chunk_pos)
	return distance <= load_radius_chunks

func should_unload_chunk(chunk: ChunkMeshData, camera_pos: Vector3, _context: Dictionary) -> bool:
	var camera_chunk_pos := _world_to_chunk_coord(camera_pos)
	var distance := _chunk_distance(chunk.chunk_coord, camera_chunk_pos)
	return distance > unload_radius_chunks

func get_load_priority(chunk: ChunkMeshData, camera_pos: Vector3) -> float:
	var distance := chunk.distance_to(camera_pos)
	return -distance

func on_activated(chunk_manager: Node) -> void:
	if chunk_manager.chunk_data_source:
		chunk_size_world = chunk_manager.chunk_data_source.chunk_size

## Convert world position to chunk coordinate
func _world_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	if chunk_size_world.x <= 0 or chunk_size_world.y <= 0:
		return Vector2i.ZERO
	var x := floori(world_pos.x / chunk_size_world.x)
	var z := floori(world_pos.z / chunk_size_world.y)
	return Vector2i(x, z)

## Calculate Manhattan distance between chunk coordinates
func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

