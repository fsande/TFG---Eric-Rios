@tool
class_name GridLoadStrategyV2 extends ChunkLoadStrategyV2

@export var load_radius: int = 4
@export var unload_radius: int = 6

func should_load(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> bool:
	var camera_chunk := _world_to_chunk_coord(camera_pos, context)
	var distance := _chunk_distance(coord, camera_chunk)
	return distance <= load_radius
	
func should_unload(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> bool:
	var camera_chunk := _world_to_chunk_coord(camera_pos, context)
	var distance := _chunk_distance(coord, camera_chunk)
	return distance > unload_radius


func get_load_priority(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> float:
	var camera_chunk := _world_to_chunk_coord(camera_pos, context)
	return _chunk_distance(coord, camera_chunk)

func calculate_lod(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> int:
	var local_chunk_center: Vector3 = Vector3(
		(coord.x + 0.5) * context.chunk_size.x - context.terrain_size.x / 2.0,
		0,
		(coord.y + 0.5) * context.chunk_size.y - context.terrain_size.y / 2.0
	)
	var world_chunk_center: Vector3 = local_chunk_center + context.terrain_position
	var distance := Vector2(world_chunk_center.x - camera_pos.x, world_chunk_center.z - camera_pos.z).length()
	for i in range(context.lod_distances.size()):
		if distance < context.lod_distances[i]: 
			return i
	return context.lod_distances.size()

func get_chunks_to_load(camera_pos: Vector3, context: ChunkLoadContextV2, sorted: bool = false) -> Array[Vector2i]:
	var camera_chunk := _world_to_chunk_coord(camera_pos, context)
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
			return get_load_priority(a, camera_pos, context) < get_load_priority(b, camera_pos, context)
		)
	return chunks_to_load

func _world_to_chunk_coord(world_pos: Vector3, context: ChunkLoadContextV2) -> Vector2i:
	var local_pos: Vector3 = world_pos - context.terrain_position
	var half_terrain: Vector2 = context.terrain_size / 2.0
	var local_x: float = local_pos.x + half_terrain.x
	var local_z: float = local_pos.z + half_terrain.y
	return Vector2i(
		int(floor(local_x / context.chunk_size.x)),
		int(floor(local_z / context.chunk_size.y))
	)

func _is_valid_chunk_coord(coord: Vector2i, context: ChunkLoadContextV2) -> bool:
	var chunks_x := int(ceil(context.terrain_size.x / context.chunk_size.x))
	var chunks_z := int(ceil(context.terrain_size.y / context.chunk_size.y))
	return coord.x >= 0 and coord.x < chunks_x and coord.y >= 0 and coord.y < chunks_z

func _chunk_distance(chunk1: Vector2i, chunk2: Vector2i) -> int:
	return maxi(absi(chunk1.x - chunk2.x), absi(chunk1.y - chunk2.y))
