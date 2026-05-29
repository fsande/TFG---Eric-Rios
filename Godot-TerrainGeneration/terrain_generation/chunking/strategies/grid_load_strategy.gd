@tool
class_name GridLoadStrategy extends ChunkLoadStrategy

@export var load_radius: int = 4
@export var unload_radius: int = 6

func get_max_loaded_chunks() -> int:
	var diameter := 2 * load_radius + 1
	return diameter * diameter

func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	return _chunk_distance(coord, _get_camera_chunk(camera, context)) <= load_radius

func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	return _chunk_distance(coord, _get_camera_chunk(camera, context)) > unload_radius

func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float:
	if not camera:
		return 0.0
	return _chunk_distance(coord, _get_camera_chunk(camera, context))

func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int:
	if not camera:
		return 0
	return _lod_for_dist_sq(_dist_sq_to_chunk(coord, camera.global_position, context), context)

func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]:
	var camera_chunk := _get_camera_chunk(camera, context)
	var chunks_to_load: Array[Vector2i] = []
	for dz in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var coord := camera_chunk + Vector2i(dx, dz)
			if _is_valid_chunk_coord(coord, context):
				chunks_to_load.append(coord)
	if sorted:
		chunks_to_load.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _chunk_distance(a, camera_chunk) < _chunk_distance(b, camera_chunk)
		)
	return chunks_to_load
