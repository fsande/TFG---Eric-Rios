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
	var camera_chunk := _world_to_chunk_coord(camera.global_position, context)
	var distance := _chunk_distance(coord, camera_chunk)
	return distance <= load_radius
	
func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	var camera_chunk := _world_to_chunk_coord(camera.global_position, context)
	var distance := _chunk_distance(coord, camera_chunk)
	return distance > unload_radius

func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float:
	if not camera:
		return 0
	var camera_chunk := _world_to_chunk_coord(camera.global_position, context)
	return _chunk_distance(coord, camera_chunk)

func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int:
	if not camera:
		return 0
	var local_chunk_center: Vector3 = Vector3(
		(coord.x + 0.5) * context.chunk_size.x - context.terrain_size.x / 2.0,
		0,
		(coord.y + 0.5) * context.chunk_size.y - context.terrain_size.y / 2.0
	)
	var world_chunk_center: Vector3 = local_chunk_center + context.terrain_position
	var camera_pos := camera.global_position
	var distance := Vector2(world_chunk_center.x - camera_pos.x, world_chunk_center.z - camera_pos.z).length()
	for i in range(context.lod_distances.size()):
		if distance < context.lod_distances[i]: 
			return i
	return context.lod_distances.size()

func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]:
	var camera_chunk := _world_to_chunk_coord(camera.global_position, context)
	var chunks_to_load: Array[Vector2i] = []
	for z in range(-load_radius, load_radius + 1):
		for x in range(-load_radius, load_radius + 1):
			var coord := camera_chunk + Vector2i(x, z)
			if not _is_valid_chunk_coord(coord, context):
				continue
			chunks_to_load.append(coord)
	if sorted:
		chunks_to_load.sort_custom(
			func(a: Vector2i, b: Vector2i):
			return get_load_priority(a, camera, context) < get_load_priority(b, camera, context)
		)
	return chunks_to_load
