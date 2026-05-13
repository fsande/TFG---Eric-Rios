## Uses the camera's frustrum to determine which chunks to load, unload, and their LOD levels. 
## Provides a more accurate view-based loading strategy at the cost of increased complexity and potential performance overhead from frustum calculations.
@tool
class_name ViewLoadStrategy extends ChunkLoadStrategy

@export var max_view_distance: float = 200.0

func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool


func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool
func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float
func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int
func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]
