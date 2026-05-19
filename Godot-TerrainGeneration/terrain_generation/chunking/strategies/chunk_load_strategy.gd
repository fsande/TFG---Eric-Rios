@abstract @tool
class_name ChunkLoadStrategy extends Resource

## Default estimate of max loaded chunks. Subclasses should override.
const DEFAULT_MAX_LOADED_CHUNKS: int = 25

@abstract func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool
@abstract func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool
@abstract func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float
@abstract func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int
@abstract func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]

## Return the expected maximum number of simultaneously loaded chunks.
## Override in subclasses for accurate budget calculations.
func get_max_loaded_chunks() -> int:
	return DEFAULT_MAX_LOADED_CHUNKS

func _world_to_chunk_coord(world_pos: Vector3, context: ChunkLoadContext) -> Vector2i:
	var local_pos: Vector3 = world_pos - context.terrain_position
	var half_terrain: Vector2 = context.terrain_size / 2.0
	var local_x: float = local_pos.x + half_terrain.x
	var local_z: float = local_pos.z + half_terrain.y
	return Vector2i(
		int(floor(local_x / context.chunk_size.x)),
		int(floor(local_z / context.chunk_size.y))
	)

func _is_valid_chunk_coord(coord: Vector2i, context: ChunkLoadContext) -> bool:
	var chunks_x := int(ceil(context.terrain_size.x / context.chunk_size.x))
	var chunks_z := int(ceil(context.terrain_size.y / context.chunk_size.y))
	return coord.x >= 0 and coord.x < chunks_x and coord.y >= 0 and coord.y < chunks_z

func _chunk_distance(chunk1: Vector2i, chunk2: Vector2i) -> int:
	return maxi(absi(chunk1.x - chunk2.x), absi(chunk1.y - chunk2.y))
