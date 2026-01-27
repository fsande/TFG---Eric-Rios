## @brief Manages runtime loading and unloading of terrain chunks.
##
## @details Uses a ChunkLoadStrategy to determine which chunks should be
## visible based on camera position. Handles mesh instancing, collision
## generation, and memory management with per-frame budgets.
class_name ChunkManager extends Node3D

## Source data containing all chunks
var chunk_data_source: ChunkedTerrainData:
	set(value):
		chunk_data_source = value
		if chunk_data_source:
			_on_chunk_data_changed()

## Strategy for determining which chunks to load
var load_strategy: ChunkLoadStrategy:
	set(value):
		if load_strategy:
			load_strategy.on_deactivated()
		load_strategy = value
		if load_strategy:
			load_strategy.on_activated(self)

## Camera to track (auto-detected if null)
var camera: Camera3D = null

## Currently loaded chunks (chunk_coord -> MeshInstance3D)
var loaded_chunks: Dictionary = {}

## Enable collision generation for chunks
@export var generate_collision: bool = true

## Collision layers for chunk collision bodies
@export_flags_3d_physics var collision_layers: int = 1

## Maximum distance for full collision (beyond this, use simplified)
@export var full_collision_distance: float = 100.0

## Update frequency for chunk visibility checks
@export var update_interval: float = 0.1

## Enable debug mode (shows chunk load/unload events)
@export var debug_mode: bool = false

var _update_timer: float = 0.0
var _total_loads: int = 0
var _total_unloads: int = 0

func _ready() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if chunk_data_source and load_strategy:
		_update_chunk_visibility()

func _process(delta: float) -> void:
	if not chunk_data_source or not load_strategy:
		return
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_chunk_visibility()

## Load a single chunk into the scene
func _load_chunk(chunk: ChunkMeshData, camera_pos: Vector3) -> void:
	if loaded_chunks.has(chunk.chunk_coord):
		return
	if not chunk.mesh:
		var chunk_config := _get_chunk_configuration()
		if chunk_config:
			chunk.build_mesh_with_lod(
				chunk_config.lod_normal_merge_angle,
				chunk_config.lod_normal_split_angle
			)
		else:
			chunk.build_mesh_with_lod()
	if not chunk.mesh:
		push_warning("ChunkManager: Failed to build mesh for chunk %v" % chunk.chunk_coord)
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Chunk_%d_%d" % [chunk.chunk_coord.x, chunk.chunk_coord.y]
	mesh_instance.mesh = chunk.mesh
	mesh_instance.position = chunk.world_position
	if generate_collision:
		_add_chunk_collision(mesh_instance, chunk, camera_pos)
	add_child(mesh_instance)
	loaded_chunks[chunk.chunk_coord] = mesh_instance
	chunk.is_loaded = true
	_total_loads += 1
	if debug_mode:
		print("ChunkManager: Loaded chunk %v at %v" % [chunk.chunk_coord, chunk.world_position])

## Get chunk configuration from parent presenter
func _get_chunk_configuration() -> ChunkConfiguration:
	var presenter := get_parent()
	if presenter and presenter.has_method("get") and presenter.get("terrain_configuration"):
		var terrain_config = presenter.terrain_configuration
		if terrain_config and terrain_config.chunk_configuration:
			return terrain_config.chunk_configuration
	return null

## Unload a single chunk from the scene
func _unload_chunk(chunk_coord: Vector2i) -> void:
	if not loaded_chunks.has(chunk_coord):
		return
	var mesh_instance: MeshInstance3D = loaded_chunks[chunk_coord]
	if mesh_instance:
		remove_child(mesh_instance)
		mesh_instance.queue_free()
	loaded_chunks.erase(chunk_coord)
	var chunk := chunk_data_source.get_chunk_at(chunk_coord)
	if chunk:
		chunk.is_loaded = false
	_total_unloads += 1
	if debug_mode:
		print("ChunkManager: Unloaded chunk %v" % chunk_coord)

## Clear all loaded chunks
func _clear_all_chunks() -> void:
	for coord in loaded_chunks.keys():
		_unload_chunk(coord)

## Add collision to a chunk's mesh instance
func _add_chunk_collision(mesh_instance: MeshInstance3D, chunk: ChunkMeshData, camera_pos: Vector3) -> void:
	var distance := chunk.distance_to(camera_pos)
	var use_simplified := distance > full_collision_distance
	if not chunk.has_collision:
		chunk.build_collision(use_simplified)
	if not chunk.collision_shape:
		return
	var body := StaticBody3D.new()
	body.name = "CollisionBody"
	body.collision_layer = collision_layers
	body.collision_mask = 0
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = chunk.collision_shape
	if use_simplified:
		collision_shape.position = Vector3.ZERO
	body.add_child(collision_shape)
	mesh_instance.add_child(body)

## Called when chunk data source changes
func _on_chunk_data_changed() -> void:
	_clear_all_chunks()
	if chunk_data_source and load_strategy:
		_update_chunk_visibility()

## Update which chunks should be visible based on camera position
func _update_chunk_visibility() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
		if not camera:
			return
	var camera_pos := camera.global_position
	var context := {
		"loaded_chunks": loaded_chunks,
		"frame_time": get_process_delta_time()
	}
	var budgets := load_strategy.get_max_operations_per_frame()
	var max_loads := budgets.x
	var max_unloads := budgets.y
	var loads_this_frame := 0
	var unloads_this_frame := 0
	var chunks_to_unload := []
	for coord in loaded_chunks.keys():
		var chunk := chunk_data_source.get_chunk_at(coord)
		if chunk and load_strategy.should_unload_chunk(chunk, camera_pos, context):
			chunks_to_unload.append(coord)
	for coord in chunks_to_unload:
		if unloads_this_frame >= max_unloads:
			break
		_unload_chunk(coord)
		unloads_this_frame += 1
	var chunks_to_load := []
	for chunk in chunk_data_source.chunks:
		if not loaded_chunks.has(chunk.chunk_coord):
			if load_strategy.should_load_chunk(chunk, camera_pos, context):
				var priority := load_strategy.get_load_priority(chunk, camera_pos)
				chunks_to_load.append({"chunk": chunk, "priority": priority})
	chunks_to_load.sort_custom(func(a, b): return a.priority > b.priority)
	for item in chunks_to_load:
		if loads_this_frame >= max_loads:
			break
		_load_chunk(item.chunk, camera_pos)
		loads_this_frame += 1

## Get debug statistics
func get_stats() -> Dictionary:
	return {
		"loaded_chunks": loaded_chunks.size(),
		"total_loads": _total_loads,
		"total_unloads": _total_unloads,
		"memory_usage": _calculate_memory_usage()
	}

## Calculate total memory usage of loaded chunks
func _calculate_memory_usage() -> int:
	var total := 0
	for coord in loaded_chunks.keys():
		var chunk := chunk_data_source.get_chunk_at(coord)
		if chunk:
			total += chunk.get_memory_usage()
	return total

