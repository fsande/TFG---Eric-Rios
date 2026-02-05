@abstract @tool
class_name ChunkLoadStrategyV2 extends Resource

@abstract func should_load(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> bool
@abstract func should_unload(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> bool
@abstract func get_load_priority(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> float
@abstract func calculate_lod(coord: Vector2i, camera_pos: Vector3, context: ChunkLoadContextV2) -> int
@abstract func get_chunks_to_load(camera_pos: Vector3, context: ChunkLoadContextV2, sorted: bool = false) -> Array[Vector2i]

