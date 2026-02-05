## @brief Node that presents terrain using the new V2 generation architecture.
##
## @details Uses TerrainDefinition + ChunkGenerator for on-demand chunk generation.
@tool
class_name TerrainPresenterV2 extends Node3D

signal generation_completed(terrain_definition: TerrainDefinition)
signal chunk_loaded(coord: Vector2i, lod: int)
signal chunk_unloaded(coord: Vector2i)

@export var configuration: TerrainConfigurationV2 = TerrainConfigurationV2.new():
	set(value):
		configuration = value
		if configuration:
			configuration.configuration_changed.connect(_on_config_changed)
			configuration.load_strategy_changed.connect(_on_load_strategy_changed)
		if configuration.auto_generate:
			regenerate()

@export_group("Actions")
@export_tool_button("Regenerate") var regenerate_action := regenerate
@export_tool_button("Clear Chunks") var clear_action := clear_all_chunks

var _terrain_definition: TerrainDefinition
var _generation_service: ChunkGenerationService
var _prop_manager: ChunkPropManager
var _loaded_chunks: Dictionary[Vector2i, LoadedChunkState] = {}
var _chunk_instances: Dictionary[Vector2i, MeshInstance3D] = {}
var _collision_bodies: Dictionary[Vector2i, StaticBody3D] = {}
var _pending_chunk_requests: Dictionary[Vector2i, int] = {}
var _ready_chunks_queue: Array[ChunkReadyData] = []
var _chunks_container: Node3D
var _props_container: Node3D
var _update_timer: float = 0.0
var _is_generating: bool = false
var _camera: Camera3D
var _load_context: ChunkLoadContextV2 = null

func _ready() -> void:
	if configuration.heightmap_source and configuration.auto_generate: 
		print("Auto-generating terrain on ready")
		regenerate()

func _process(delta: float) -> void:
	if not _terrain_definition or not _generation_service:
		return
	_process_ready_chunks_queue()
	_update_timer += delta
	if _update_timer >= configuration.update_interval:
		_update_timer = 0.0
		_update_visible_chunks()

func _process_ready_chunks_queue() -> void:
	if _ready_chunks_queue.is_empty():
		return
	var start_time_usec := Time.get_ticks_usec()
	var budget_ms: float = configuration.chunk_instantiation_budget_ms if configuration else 5.0
	var budget_usec: float = budget_ms * 1000.0
	while not _ready_chunks_queue.is_empty():
		var elapsed_usec := Time.get_ticks_usec() - start_time_usec
		if elapsed_usec >= budget_usec:
			break
		var data: ChunkReadyData = _ready_chunks_queue.pop_front()
		if _loaded_chunks.has(data.coord):
			continue
		if not _should_still_load_chunk(data.coord):
			continue
		_instantiate_chunk(data.coord, data.lod, data.chunk)

func regenerate() -> void:
	if _is_generating:
		return
	if not configuration.heightmap_source:
		push_warning("TerrainPresenterV2: No heightmap source assigned")
		return
	_setup_containers()
	_is_generating = true
	clear_all_chunks()
	var shared_context := ProcessingContext.new(
		configuration.terrain_size.x,
		ProcessingContext.ProcessorType.GPU if configuration.use_gpu_heightmap else ProcessingContext.ProcessorType.CPU,
		ProcessingContext.ProcessorType.GPU if configuration.use_gpu_mesh_generation else ProcessingContext.ProcessorType.CPU,
		configuration.generation_seed
	)
	var generator := TerrainDefinitionGenerator.new()
	generator.verbose = configuration.show_debug_info
	_terrain_definition = generator.generate(
		configuration.heightmap_source,
		configuration.terrain_size,
		configuration.height_scale,
		configuration.modifier_stages,
		configuration.generation_seed,
		shared_context
	)
	if not _terrain_definition:
		push_error("TerrainPresenterV2: Failed to generate terrain definition")
		shared_context.dispose()
		_is_generating = false
		return
	_terrain_definition.set_shared_processing_context(shared_context)
	_generation_service = ChunkGenerationService.new(
		_terrain_definition,
		configuration.base_chunk_resolution,
		configuration.cache_size_mb,
		configuration.use_gpu_mesh_generation
	)
	_generation_service.set_use_threading(configuration.use_async_loading)
	_generation_service.set_max_concurrent_requests(configuration.max_concurrent_chunk_requests)
	_generation_service.chunk_generated.connect(_on_async_chunk_ready, ConnectFlags.CONNECT_DEFERRED)
	_generation_service.generation_failed.connect(_on_async_chunk_failed, ConnectFlags.CONNECT_DEFERRED)
	_load_context = null
	if _props_container:
		_prop_manager = ChunkPropManager.new(_terrain_definition, _props_container)
	if configuration.show_debug_info:
		print("TerrainPresenterV2: %s" % _terrain_definition.get_summary())
	_update_visible_chunks()
	_is_generating = false
	generation_completed.emit(_terrain_definition)

func clear_all_chunks() -> void:
	for coord in _chunk_instances.keys():
		_unload_chunk(coord)
	_chunk_instances.clear()
	_loaded_chunks.clear()
	_collision_bodies.clear()
	_pending_chunk_requests.clear()
	_ready_chunks_queue.clear()
	if _generation_service:
		_generation_service.cancel_all_pending_requests()
		_generation_service.clear_cache()
	if _prop_manager:
		_prop_manager.despawn_all_props()

func get_terrain_definition() -> TerrainDefinition:
	return _terrain_definition

func get_cache_stats() -> Dictionary:
	if _generation_service:
		return _generation_service.get_cache_stats()
	return {}
	
func _on_config_changed() -> void:
	if configuration.auto_generate and is_inside_tree():
		regenerate()
		
func _on_load_strategy_changed() -> void:
	_load_context = null

func _setup_containers() -> void:
	_chunks_container = NodeCreationHelper.get_or_create_node(self, "ChunksContainer", Node3D)
	NodeCreationHelper.remove_all_children(_chunks_container)
	_props_container = NodeCreationHelper.get_or_create_node(self, "PropsContainer", Node3D)
	NodeCreationHelper.remove_all_children(_chunks_container)

func _update_visible_chunks() -> void:
	if not _generation_service or not configuration.load_strategy or _is_generating:
		return
	var camera_pos := _get_camera_position()
	if not _load_context:
		var lod_distances := PackedFloat32Array(configuration.lod_distances)
		_load_context = ChunkLoadContextV2.new(
			configuration.terrain_size,
			configuration.chunk_size,
			_loaded_chunks,
			lod_distances,
			lod_distances.size(),
			global_position
		)
	_load_context.loaded_chunks = _loaded_chunks
	var chunks_to_unload: Array[Vector2i] = []
	for chunk in _loaded_chunks.keys():
		if configuration.load_strategy.should_unload(chunk, camera_pos, _load_context):
			chunks_to_unload.append(chunk)
	for chunk in chunks_to_unload:
		_unload_chunk(chunk)
	var chunks_to_load := configuration.load_strategy.get_chunks_to_load(camera_pos, _load_context, true)
	for chunk in chunks_to_load:
		var base_lod := configuration.load_strategy.calculate_lod(chunk, camera_pos, _load_context) if configuration.enable_lod else 0
		var lod := _apply_lod_hysteresis(chunk, base_lod, camera_pos)
		var priority := configuration.load_strategy.get_load_priority(chunk, camera_pos, _load_context)
		if _loaded_chunks.has(chunk):
			update_chunk_lod(chunk, lod, priority)
			continue
		if _pending_chunk_requests.has(chunk):
			continue
		_request_chunk_load(chunk, lod, priority)
	_cancel_out_of_range_requests(camera_pos)

func _apply_lod_hysteresis(coord: Vector2i, target_lod: int, camera_pos: Vector3) -> int:
	if not _loaded_chunks.has(coord):
		return target_lod
	var state: LoadedChunkState = _loaded_chunks[coord]
	var current_lod := state.lod
	if current_lod == target_lod:
		return target_lod
	var hysteresis: float = configuration.lod_hysteresis
	if hysteresis <= 0.0:
		return target_lod
	var chunk_center := _get_chunk_world_center(coord)
	var distance := camera_pos.distance_to(chunk_center)
	var lod_distances := configuration.lod_distances
	if target_lod > current_lod:
		var threshold_distance: float = lod_distances[current_lod] if current_lod < lod_distances.size() else lod_distances[-1]
		var hysteresis_distance: float = threshold_distance * (1.0 + hysteresis)
		if distance < hysteresis_distance:
			return current_lod
	elif target_lod < current_lod:
		var threshold_distance: float = lod_distances[target_lod] if target_lod < lod_distances.size() else lod_distances[-1]
		var hysteresis_distance: float = threshold_distance * (1.0 - hysteresis)
		if distance > hysteresis_distance:
			return current_lod
	return target_lod

func _get_chunk_world_center(coord: Vector2i) -> Vector3:
	var chunk_size := configuration.chunk_size
	var terrain_size := configuration.terrain_size
	var half_terrain := terrain_size / 2.0
	var x := coord.x * chunk_size.x - half_terrain.x + chunk_size.x / 2.0
	var z := coord.y * chunk_size.y - half_terrain.y + chunk_size.y / 2.0
	return global_position + Vector3(x, 0, z)

func update_chunk_lod(coord: Vector2i, new_lod: int, priority: float) -> void:
	if not _loaded_chunks.has(coord):
		return
	var state: LoadedChunkState = _loaded_chunks[coord]
	if state.lod == new_lod:
		return
	if _pending_chunk_requests.has(coord):
		return
	var lod_difference := absi(state.lod - new_lod)
	if lod_difference < 1 and new_lod != 0:
		return
	_pending_chunk_requests[coord] = new_lod
	if configuration.use_async_loading:
		_generation_service.request_chunk_async(coord, configuration.chunk_size, new_lod, priority)
	else:
		var chunk := _generation_service.get_or_generate_chunk(coord, configuration.chunk_size, new_lod)
		_pending_chunk_requests.erase(coord)
		if chunk:
			_replace_chunk_with_new_lod(coord, new_lod, chunk)

func _replace_chunk_with_new_lod(coord: Vector2i, new_lod: int, chunk: ChunkMeshData) -> void:
	_unload_chunk(coord)
	_instantiate_chunk(coord, new_lod, chunk)

func _load_chunk(coord: Vector2i, lod_level: int) -> void:
	if _loaded_chunks.has(coord):
		return
	var chunk := _generation_service.get_or_generate_chunk(coord, configuration.chunk_size, lod_level)
	if not chunk:
		return
	_instantiate_chunk(coord, lod_level, chunk)

func _request_chunk_load(coord: Vector2i, lod_level: int, priority: float) -> void:
	if _loaded_chunks.has(coord) or _pending_chunk_requests.has(coord):
		return
	_pending_chunk_requests[coord] = lod_level
	if configuration.use_async_loading:
		_generation_service.request_chunk_async(coord, configuration.chunk_size, lod_level, priority)
	else:
		var chunk := _generation_service.get_or_generate_chunk(coord, configuration.chunk_size, lod_level)
		_pending_chunk_requests.erase(coord)
		if chunk:
			_instantiate_chunk(coord, lod_level, chunk)

func _on_async_chunk_ready(coord: Vector2i, lod: int, chunk: ChunkMeshData) -> void:
	_pending_chunk_requests.erase(coord)
	var is_lod_update := _loaded_chunks.has(coord)
	if is_lod_update:
		var state: LoadedChunkState = _loaded_chunks[coord]
		if state.lod == lod:
			return
		_replace_chunk_with_new_lod(coord, lod, chunk)
		return
	if not _should_still_load_chunk(coord):
		return
	var camera_pos := _get_camera_position()
	var priority := 0.0
	if configuration.load_strategy and _load_context:
		priority = configuration.load_strategy.get_load_priority(coord, camera_pos, _load_context)
	var ready_data := ChunkReadyData.new(coord, lod, chunk, priority)
	_insert_into_ready_queue(ready_data)

func _insert_into_ready_queue(data: ChunkReadyData) -> void:
	var insert_idx := 0
	for i in range(_ready_chunks_queue.size()):
		if data.priority < _ready_chunks_queue[i].priority:
			break
		insert_idx = i + 1
	_ready_chunks_queue.insert(insert_idx, data)

func _on_async_chunk_failed(coord: Vector2i, lod: int, error: String) -> void:
	_pending_chunk_requests.erase(coord)
	if configuration.show_debug_info:
		push_warning("TerrainPresenterV2: Failed to load chunk %s LOD %d: %s" % [coord, lod, error])

func _should_still_load_chunk(coord: Vector2i) -> bool:
	if not configuration.load_strategy or not _load_context:
		return true
	var camera_pos := _get_camera_position()
	return configuration.load_strategy.should_load(coord, camera_pos, _load_context)

func _cancel_out_of_range_requests(camera_pos: Vector3) -> void:
	var coords_to_cancel: Array[Vector2i] = []
	for coord in _pending_chunk_requests.keys():
		if configuration.load_strategy.should_unload(coord, camera_pos, _load_context):
			coords_to_cancel.append(coord)
	for coord in coords_to_cancel:
		var lod: int = _pending_chunk_requests[coord]
		_generation_service.cancel_request(coord, lod)
		_pending_chunk_requests.erase(coord)

func _instantiate_chunk(coord: Vector2i, lod_level: int, chunk: ChunkMeshData) -> void:
	if _loaded_chunks.has(coord):
		return
	var mesh := ArrayMeshBuilder.build_mesh(chunk.mesh_data)
	if not mesh:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "Chunk_%d_%d" % [coord.x, coord.y]
	mesh_instance.position = chunk.world_position
	if configuration.terrain_material:
		mesh_instance.material_override = configuration.terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_chunks_container.add_child(mesh_instance)
	if Engine.is_editor_hint():
		mesh_instance.owner = get_tree().edited_scene_root
	_chunk_instances[coord] = mesh_instance
	_loaded_chunks[coord] = LoadedChunkState.new(lod_level, chunk)
	if configuration.generate_collision and lod_level == 0:
		_create_collision_for_chunk(coord, chunk, mesh_instance)
	if _prop_manager and lod_level <= 1:
		_prop_manager.spawn_props_for_chunk(chunk, lod_level)
	chunk_loaded.emit(coord, lod_level)

func _unload_chunk(coord: Vector2i) -> void:
	if _chunk_instances.has(coord):
		var instance: MeshInstance3D = _chunk_instances[coord]
		if is_instance_valid(instance):
			instance.queue_free()
		_chunk_instances.erase(coord)
	if _collision_bodies.has(coord):
		var body: StaticBody3D = _collision_bodies[coord]
		if is_instance_valid(body):
			body.queue_free()
		_collision_bodies.erase(coord)
	if _prop_manager:
		_prop_manager.despawn_props_for_chunk(coord)
	_loaded_chunks.erase(coord)
	chunk_unloaded.emit(coord)

func _create_collision_for_chunk(coord: Vector2i, chunk: ChunkMeshData, mesh_instance: MeshInstance3D) -> void:
	var shape := chunk.build_collision(false)
	if not shape:
		return
	var body := StaticBody3D.new()
	body.name = "Collision_%d_%d" % [coord.x, coord.y]
	body.collision_layer = configuration.collision_layers
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	body.add_child(collision_shape)
	mesh_instance.add_child(body)
	if Engine.is_editor_hint():
		body.owner = get_tree().edited_scene_root
		collision_shape.owner = get_tree().edited_scene_root
	_collision_bodies[coord] = body

func _get_camera_position() -> Vector3:
	if configuration.track_camera:
		if not _camera or not is_instance_valid(_camera):
			var viewport = get_viewport()
			if viewport:
				_camera = viewport.get_camera_3d()
		if _camera:
			return _camera.global_position
	return Vector3.ZERO
