@abstract @tool
class_name ChunkLoadStrategy extends Resource

const DEFAULT_MAX_LOADED_CHUNKS: int = 25

var _cached_camera_chunk: Vector2i
var _cached_chunks_x: int = 0
var _cached_chunks_z: int = 0
var _cached_terrain_size: Vector2 = Vector2.ZERO

@abstract func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool
@abstract func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool
@abstract func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float
@abstract func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int
@abstract func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]

## Returns the expected maximum number of simultaneously loaded chunks.
func get_max_loaded_chunks() -> int:
	return DEFAULT_MAX_LOADED_CHUNKS

## Call once per terrain manager tick to invalidate the camera chunk cache.
func notify_camera_moved(camera: Camera3D, context: ChunkLoadContext) -> void:
	var current_chunk := _world_to_chunk_coord(camera.global_position, context)
	_cached_camera_chunk = current_chunk

func _get_camera_chunk(camera: Camera3D, context: ChunkLoadContext) -> Vector2i:
	var current_chunk := _world_to_chunk_coord(camera.global_position, context)
	_cached_camera_chunk = current_chunk
	return _cached_camera_chunk

func _chunk_world_center(coord: Vector2i, context: ChunkLoadContext) -> Vector3:
	return Vector3(
		(coord.x + 0.5) * context.chunk_size.x - context.terrain_size.x / 2.0 + context.terrain_position.x,
		0.0,
		(coord.y + 0.5) * context.chunk_size.y - context.terrain_size.y / 2.0 + context.terrain_position.z
	)

func _lod_for_dist_sq(dist_sq: float, context: ChunkLoadContext) -> int:
	for i in range(context.lod_distances.size()):
		if dist_sq < context.lod_distances[i] * context.lod_distances[i]:
			return i
	return context.lod_distances.size()

func _dist_sq_to_chunk(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContext) -> float:
	var world_center := _chunk_world_center(coord, context)
	return Vector2(world_center.x - camera_pos.x, world_center.z - camera_pos.z).length_squared()

func _world_to_chunk_coord(world_pos: Vector3, context: ChunkLoadContext) -> Vector2i:
	var local_pos := world_pos - context.terrain_position
	var half_terrain := context.terrain_size / 2.0
	return Vector2i(
		int(floor((local_pos.x + half_terrain.x) / context.chunk_size.x)),
		int(floor((local_pos.z + half_terrain.y) / context.chunk_size.y))
	)

func _is_valid_chunk_coord(coord: Vector2i, context: ChunkLoadContext) -> bool:
	_refresh_grid_dims(context)
	return coord.x >= 0 and coord.x < _cached_chunks_x and coord.y >= 0 and coord.y < _cached_chunks_z

func _chunk_distance(chunk1: Vector2i, chunk2: Vector2i) -> int:
	return maxi(absi(chunk1.x - chunk2.x), absi(chunk1.y - chunk2.y))

func _refresh_grid_dims(context: ChunkLoadContext) -> void:
	if context.terrain_size == _cached_terrain_size:
		return
	_cached_terrain_size = context.terrain_size
	_cached_chunks_x = int(ceil(context.terrain_size.x / context.chunk_size.x))
	_cached_chunks_z = int(ceil(context.terrain_size.y / context.chunk_size.y))
