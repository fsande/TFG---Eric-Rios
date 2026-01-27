## @brief Hierarchical quadtree-based chunk loading strategy.
##
## @details Loads chunks in a hierarchical pattern, prioritizing
## closer chunks and enabling progressive detail refinement.
## Supports parent-child relationships for efficient culling.
class_name QuadTreeLoadStrategy extends ChunkLoadStrategy

## Maximum view distance for chunk loading
@export var max_view_distance: float = 400.0

## Minimum chunk size before stopping subdivision (world units)
@export var min_chunk_size: float = 25.0

## Enable hierarchical loading (load parents before children)
@export var use_hierarchical_loading: bool = true

## LOD bias - higher values load lower detail chunks sooner
@export_range(0.5, 2.0) var lod_bias: float = 1.0

func should_load_chunk(chunk: ChunkMeshData, camera_pos: Vector3, context: Dictionary) -> bool:
	var distance := chunk.distance_to(camera_pos)
	if distance > max_view_distance:
		return false
	if use_hierarchical_loading:
		var parent_coord := _get_parent_chunk_coord(chunk.chunk_coord)
		if parent_coord != chunk.chunk_coord:
			var loaded_chunks = context.get("loaded_chunks", {})
			if not loaded_chunks.has(parent_coord):
				return false
	return true

func should_unload_chunk(chunk: ChunkMeshData, camera_pos: Vector3, _context: Dictionary) -> bool:
	var distance := chunk.distance_to(camera_pos)
	return distance > max_view_distance * 1.2

func get_load_priority(chunk: ChunkMeshData, camera_pos: Vector3) -> float:
	var distance := chunk.distance_to(camera_pos)
	var level := _get_quadtree_level(chunk.chunk_coord)
	return -(distance / (level + 1)) * lod_bias

## Check if parent chunk is loaded (for hierarchical loading)
func _is_parent_loaded(coord: Vector2i, loaded_coords: Array) -> bool:
	var parent := _get_parent_chunk_coord(coord)
	if parent == coord:
		return true
	return loaded_coords.has(parent)

## Get parent chunk coordinate in quadtree hierarchy
func _get_parent_chunk_coord(coord: Vector2i) -> Vector2i:
	return Vector2i(floori(coord.x / 2.0), floori(coord.y / 2.0))

## Get quadtree level for chunk coordinate
func _get_quadtree_level(coord: Vector2i) -> int:
	var level := 0
	var max_coord: int = maxi(absi(coord.x), absi(coord.y))
	while max_coord > 0:
		max_coord /= 2
		level += 1
	return level

func get_max_operations_per_frame() -> Vector2i:
	return Vector2i(3, 5)

