## Combines grid-based and view-based loading strategies.
## A chunk loads if either strategy wants it, and unloads only when both agree.
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

func notify_camera_moved(camera: Camera3D, context: ChunkLoadContext) -> void:
	_grid_strategy.notify_camera_moved(camera, context)
	_view_strategy.notify_camera_moved(camera, context)

func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]:
	var grid_chunks := _grid_strategy.get_chunks_to_load(camera, context, sorted)
	var view_chunks := _view_strategy.get_chunks_to_load(camera, context, sorted)
	if grid_chunks.is_empty():
		return view_chunks
	if view_chunks.is_empty():
		return grid_chunks
	if sorted:
		return _merge_sorted(grid_chunks, view_chunks, camera, context)
	var seen := {}
	var combined: Array[Vector2i] = []
	combined.resize(grid_chunks.size() + view_chunks.size())
	var write_idx := 0
	for chunk in grid_chunks:
		if not seen.has(chunk):
			seen[chunk] = true
			combined[write_idx] = chunk
			write_idx += 1
	for chunk in view_chunks:
		if not seen.has(chunk):
			seen[chunk] = true
			combined[write_idx] = chunk
			write_idx += 1
	combined.resize(write_idx)
	return combined

## Merges two sorted chunk arrays into one sorted array.
func _merge_sorted(a: Array[Vector2i], b: Array[Vector2i], camera: Camera3D, context: ChunkLoadContext) -> Array[Vector2i]:
	var merged: Array[Vector2i] = []
	merged.resize(a.size() + b.size())
	var ai := 0
	var bi := 0
	var wi := 0
	var seen := {}
	while ai < a.size() and bi < b.size():
		if seen.has(a[ai]):
			ai += 1
			continue
		if seen.has(b[bi]):
			bi += 1
			continue
		var use_a := get_load_priority(a[ai], camera, context) <= get_load_priority(b[bi], camera, context)
		var chosen := a[ai] if use_a else b[bi]
		seen[chosen] = true
		merged[wi] = chosen
		wi += 1
		if use_a:
			ai += 1
		else:
			bi += 1
	while ai < a.size():
		if not seen.has(a[ai]):
			seen[a[ai]] = true
			merged[wi] = a[ai]
			wi += 1
		ai += 1
	while bi < b.size():
		if not seen.has(b[bi]):
			seen[b[bi]] = true
			merged[wi] = b[bi]
			wi += 1
		bi += 1
	merged.resize(wi)
	return merged
