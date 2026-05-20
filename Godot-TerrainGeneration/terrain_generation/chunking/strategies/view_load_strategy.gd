## Uses the camera's frustrum to determine which chunks to load, unload, and their LOD levels. 
## Provides a more accurate view-based loading strategy
## Calculates distance from the camera to the chunk and the angle between the camera's forward direction and the direction to the chunk to determine 
## if it should be loaded or unloaded, and to calculate its LOD level.
@tool
class_name ViewLoadStrategy extends ChunkLoadStrategy

@export var view_angle: float = 90.0
@export var max_view_distance: float = 200.0

func should_load(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	return _is_in_radius(coord, camera, context)

func should_unload(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	if not camera:
		return false
	return not _is_in_radius(coord, camera, context)

func get_load_priority(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> float:
	if not camera:
		return 0
	return calculate_lod(coord, camera, context)

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
	var chunks_to_load: Array[Vector2i] = []
	var half_terrain: Vector2 = context.terrain_size / 2.0
	var min_coord := _world_to_chunk_coord(camera.global_position - Vector3(half_terrain.x, 0, half_terrain.y), context)
	var max_coord := _world_to_chunk_coord(camera.global_position + Vector3(half_terrain.x, 0, half_terrain.y), context)
	for z in range(min_coord.y, max_coord.y + 1):
		for x in range(min_coord.x, max_coord.x + 1):
			var coord := Vector2i(x, z)
			if not _is_valid_chunk_coord(coord, context):
				continue
			if should_load(coord, camera, context):
				chunks_to_load.append(coord)
	if sorted:
		chunks_to_load.sort_custom(
			func(a: Vector2i, b: Vector2i):
			return get_load_priority(a, camera, context) < get_load_priority(b, camera, context)
		)
#	print("chunks_to_load: ", chunks_to_load)
	return chunks_to_load

## Computes whether a given chunk is in radius of the camera's view based on distance and angle. 
## Used for both loading and unloading decisions.
func _is_in_radius(coord: Vector2i, camera: Camera3D, context: ChunkLoadContext) -> bool:
	var camera_pos := camera.global_position
	var camera_forward := -camera.global_transform.basis.z.normalized()
	var local_chunk_center: Vector3 = Vector3(
		(coord.x + 0.5) * context.chunk_size.x - context.terrain_size.x / 2.0,
		0,
		(coord.y + 0.5) * context.chunk_size.y - context.terrain_size.y / 2.0
	)
	var world_chunk_center: Vector3 = local_chunk_center + context.terrain_position
	var to_chunk := (world_chunk_center - camera_pos).normalized()
	var distance := Vector2(world_chunk_center.x - camera_pos.x, world_chunk_center.z - camera_pos.z).length()
	if distance >= max_view_distance:
#		print("Returning because distance ", distance, " is greater than max_view_distance ", max_view_distance)
		return false
	var angle := rad_to_deg(acos(camera_forward.dot(to_chunk)))
	return angle <= view_angle / 2.0
