@tool
class_name ViewLoadStrategy extends ChunkLoadStrategy

@export var view_angle: float = 90.0:
	set(value):
		view_angle = value
		_cos_half_fov = cos(deg_to_rad(value * 0.5))

@export var max_view_distance: float = 200.0:
	set(value):
		max_view_distance = value
		_max_dist_sq = value * value

var _cos_half_fov: float = cos(deg_to_rad(45.0))
var _max_dist_sq: float = 200.0 * 200.0

func _ready() -> void:
	_cos_half_fov = cos(deg_to_rad(view_angle * 0.5))
	_max_dist_sq = max_view_distance * max_view_distance

func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	return _is_in_frustum(coord, camera, context)

func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	return not _is_in_frustum(coord, camera, context)

func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float:
	if not camera:
		return 0.0
	return _dist_sq_to_chunk(coord, camera.global_position, context)

func calculate_lod(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> int:
	if not camera:
		return 0
	return _lod_for_dist_sq(_dist_sq_to_chunk(coord, camera.global_position, context), context)

func get_chunks_to_load(camera: Camera3D, context: ChunkLoadContext, sorted: bool = false) -> Array[Vector2i]:
	var chunk_min_dim: int = min(context.chunk_size.x, context.chunk_size.y)
	var view_radius_chunks := int(ceil(max_view_distance / chunk_min_dim)) + 1
	var cam_chunk := _get_camera_chunk(camera, context)
	var chunks_to_load: Array[Vector2i] = []
	for dz in range(-view_radius_chunks, view_radius_chunks + 1):
		for dx in range(-view_radius_chunks, view_radius_chunks + 1):
			var coord := cam_chunk + Vector2i(dx, dz)
			if not _is_valid_chunk_coord(coord, context):
				continue
			if _is_in_frustum(coord, camera, context):
				chunks_to_load.append(coord)
	if sorted:
		var cam_pos := camera.global_position
		chunks_to_load.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _dist_sq_to_chunk(a, cam_pos, context) < _dist_sq_to_chunk(b, cam_pos, context)
		)
	return chunks_to_load

func _is_in_frustum(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	var world_center := _chunk_world_center(coord, context)
	var cam_pos := camera.global_position
	var to_chunk_xz := Vector2(world_center.x - cam_pos.x, world_center.z - cam_pos.z)
	if to_chunk_xz.length_squared() >= _max_dist_sq:
		return false
	var cam_fwd := -camera.global_transform.basis.z
	var to_chunk_norm := Vector3(to_chunk_xz.x, 0.0, to_chunk_xz.y).normalized()
	return cam_fwd.dot(to_chunk_norm) >= _cos_half_fov
