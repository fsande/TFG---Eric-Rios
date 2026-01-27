## @brief Container for all chunks in a partitioned terrain.
##
## @details Holds reference to source terrain data and manages
## the collection of chunk mesh data instances.
class_name ChunkedTerrainData extends RefCounted

## Source terrain data that was partitioned into chunks
var terrain_data: TerrainData

## Size of each chunk in world units
var chunk_size: Vector2

## All chunks in a flat array
var chunks: Array[ChunkMeshData] = []

## Chunk lookup map (chunk_coord -> ChunkMeshData)
var _chunk_map: Dictionary = {}

## Get chunk at specific grid coordinate
func get_chunk_at(coord: Vector2i) -> ChunkMeshData:
	return _chunk_map.get(coord, null)

## Get all chunks within a certain radius (in chunk units) from a coordinate
func get_chunks_in_radius(center_coord: Vector2i, radius: int) -> Array[ChunkMeshData]:
	var result: Array[ChunkMeshData] = []
	for chunk in chunks:
		var dist := _chunk_distance(chunk.chunk_coord, center_coord)
		if dist <= radius:
			result.append(chunk)
	return result

## Calculate Manhattan distance between two chunk coordinates
func _chunk_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## Build LOD for all chunks
func build_all_chunk_lods(normal_merge_angle: float = 60.0, normal_split_angle: float = 25.0) -> void:
	for chunk in chunks:
		chunk.build_mesh_with_lod(normal_merge_angle, normal_split_angle)

## Get total memory usage estimate
func get_memory_usage() -> int:
	var total := 0
	for chunk in chunks:
		total += chunk.get_memory_usage()
	return total

## Cleanup all chunks
func cleanup() -> void:
	for chunk in chunks:
		chunk.cleanup()
	chunks.clear()
	_chunk_map.clear()

