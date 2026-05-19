## Combines a grid-based loading strategy with a view-based loading strategy. 
## If either strategy determines a chunk should be loaded, it will be loaded. If both strategies determine a chunk should be unloaded, it will be unloaded.
@tool 
class_name GridAndViewLoadStrategy extends ChunkLoadStrategy

@export var load_radius: int = 4:
	set(value):
		load_radius = value
		_grid_strategy.load_radius = value
		
@export var unload_radius: int = 6:
	set(value):
		unload_radius = value
		_grid_strategy.unload_radius = value
		
@export var view_angle: float = 90.0:
	set(value):
		view_angle = value
		_view_strategy.view_angle = value
		
@export var max_view_distance: float = 200.0:
	set(value):
		max_view_distance = value
		_view_strategy.max_view_distance = value

var _grid_strategy: GridLoadStrategy = GridLoadStrategy.new()
var _view_strategy: ViewLoadStrategy = ViewLoadStrategy.new()

func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	return _grid_strategy.should_load(coord, camera, context) or _view_strategy.should_load(coord, camera, context)
	
func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	return _grid_strategy.should_unload(coord, camera, context) and _view_strategy.should_unload(coord, camera, context)
	
func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float:
	return _view_strategy.get_load_priority(coord, camera, context)
	
func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int:
	return _view_strategy.calculate_lod(coord, camera, context)

func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]:
	var grid_chunks := _grid_strategy.get_chunks_to_load(camera, context, sorted)
	var view_chunks := _view_strategy.get_chunks_to_load(camera, context, sorted)
	var combined_chunks := grid_chunks + view_chunks
	if sorted:
		combined_chunks.sort_custom(
			func(a: Vector2i, b: Vector2i):
			return get_load_priority(a, camera, context) < get_load_priority(b, camera, context)
		)
	return combined_chunks



	
