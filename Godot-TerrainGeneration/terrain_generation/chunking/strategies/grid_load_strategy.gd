## @brief Simple radius-based chunk loading strategy.
##
## @details Loads all chunks within a fixed radius from the camera,
## unloads chunks beyond a larger radius. Simple and predictable behavior.
class_name GridLoadStrategy extends ChunkLoadStrategy

## Load chunks within this radius (in chunk units)
var load_radius: int = 3

## Unload chunks beyond this radius (in chunk units)
var unload_radius: int = 5

## Maximum chunks to load per frame
var max_loads_per_frame: int = 2

## Maximum chunks to unload per frame
var max_unloads_per_frame: int = 4

## Reference to chunk data source
var _chunk_data_source: ChunkedTerrainData = null

## Fallback LOD distances when chunk doesn't have configured distances
var fallback_lod_distances: Array[float] = [100.0, 200.0, 400.0]

## Called when strategy is activated
func on_activated(chunk_manager: ChunkManager) -> void:
	if chunk_manager:
		_chunk_data_source = chunk_manager.chunk_data_source

## Determine if a chunk should be loaded
func should_load_chunk(chunk: ChunkMeshData, camera_pos: Vector3, _context: ChunkLoadContext) -> bool:
#	print("Checking whether to load chunk with camera at ", camera_pos)
	var chunk_coord := _world_pos_to_chunk_coord(camera_pos)
	var distance := _chunk_distance(chunk.chunk_coord, chunk_coord)
	return distance <= load_radius

## Determine if a loaded chunk should be unloaded
func should_unload_chunk(chunk: ChunkMeshData, camera_pos: Vector3, _context: ChunkLoadContext) -> bool:
	var chunk_coord := _world_pos_to_chunk_coord(camera_pos)
	var distance := _chunk_distance(chunk.chunk_coord, chunk_coord)
	return distance > unload_radius

## Calculate loading priority for a chunk (closer = higher priority)
func get_load_priority(chunk: ChunkMeshData, camera_pos: Vector3) -> float:
	var distance := chunk.distance_to(camera_pos)
	return 1000.0 / max(distance, 1.0)

## Get maximum number of chunks to load/unload per frame
func get_max_operations_per_frame() -> Vector2i:
	return Vector2i(max_loads_per_frame, max_unloads_per_frame)

## Convert world position to chunk coordinate
func _world_pos_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	if not _chunk_data_source:
		return Vector2i.ZERO
	var chunk_size := _chunk_data_source.chunk_size
	if _chunk_data_source.terrain_data and _chunk_data_source.terrain_data.mesh_result:
		var mesh_size := _chunk_data_source.terrain_data.mesh_result.mesh_size
		var origin_offset := Vector3(-mesh_size.x / 2.0, 0, -mesh_size.y / 2.0)
		var local_pos := world_pos - origin_offset
		var x := int(floor(local_pos.x / chunk_size.x))
		var z := int(floor(local_pos.z / chunk_size.y))
		return Vector2i(x, z)
	else:
		var x := int(floor(world_pos.x / chunk_size.x))
		var z := int(floor(world_pos.z / chunk_size.y))
		return Vector2i(x, z)

## Calculate Manhattan distance between two chunk coordinates
func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## Select LOD level based on distance (simple distance-based strategy)
func select_lod_level(chunk: ChunkMeshData, camera_pos: Vector3, _camera: Camera3D) -> int:
	var distance := chunk.distance_to(camera_pos)
	var distances := chunk.lod_distances if not chunk.lod_distances.is_empty() else fallback_lod_distances
	for i in range(distances.size()):
		if distance < distances[i]:
			return i
	return min(distances.size(), max(chunk.lod_level_count - 1, 3))
