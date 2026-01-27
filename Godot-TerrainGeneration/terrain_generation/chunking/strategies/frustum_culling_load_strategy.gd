## @brief Frustum culling-based chunk loading strategy.
##
## @details Only loads chunks visible in the camera frustum with a preload margin.
## Most efficient for performance but requires careful tuning to avoid pop-in.
class_name FrustumCullingLoadStrategy extends ChunkLoadStrategy

## Extra margin beyond frustum to preload chunks (world units)
@export var preload_margin: float = 50.0

## Maximum chunks to keep loaded outside frustum
@export var max_outside_frustum: int = 10

## Enable hybrid mode with grid fallback
@export var use_grid_fallback: bool = true

## Grid fallback radius when hybrid mode is enabled
@export var fallback_radius: int = 2

var _camera: Camera3D = null

func should_load_chunk(chunk: ChunkMeshData, camera_pos: Vector3, _context: Dictionary) -> bool:
	if not _camera:
		return false
	if use_grid_fallback:
		var chunk_coord := chunk.chunk_coord
		var camera_chunk_coord := _world_to_chunk_coord(camera_pos, chunk.chunk_size)
		var distance: int = abs(chunk_coord.x - camera_chunk_coord.x) + abs(chunk_coord.y - camera_chunk_coord.y)
		if distance <= fallback_radius:
			return true
	var expanded_aabb := chunk.aabb.grow(preload_margin)
	return _camera.is_position_in_frustum(expanded_aabb.get_center())

func should_unload_chunk(chunk: ChunkMeshData, _camera_pos: Vector3, _context: Dictionary) -> bool:
	if not _camera:
		return false
	var expanded_aabb := chunk.aabb.grow(preload_margin * 1.5)
	return not _camera.is_position_in_frustum(expanded_aabb.get_center())

func get_load_priority(chunk: ChunkMeshData, camera_pos: Vector3) -> float:
	var distance := chunk.distance_to(camera_pos)
	return -distance

func on_activated(chunk_manager: Node) -> void:
	_camera = chunk_manager.camera
	if not _camera:
		_camera = chunk_manager.get_viewport().get_camera_3d()

func _world_to_chunk_coord(world_pos: Vector3, chunk_size: Vector2) -> Vector2i:
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		return Vector2i.ZERO
	var x := floori(world_pos.x / chunk_size.x)
	var z := floori(world_pos.z / chunk_size.y)
	return Vector2i(x, z)

