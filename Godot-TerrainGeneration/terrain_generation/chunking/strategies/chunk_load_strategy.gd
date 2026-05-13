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
