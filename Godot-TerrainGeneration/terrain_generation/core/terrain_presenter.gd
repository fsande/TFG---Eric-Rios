## @brief Node that presents generated terrain in the scene and exposes editor controls.
##
## @details Binds a `TerrainConfiguration` resource, runs the generation service
## and updates MeshInstance3D / StaticBody3D nodes with the generated terrain.
## Supports auto-generation in the editor and a tool button to regenerate.
## Supports optional chunking via ChunkConfiguration in the terrain configuration.
@tool
class_name TerrainPresenter extends Node3D

## Terrain configuration resource driving generation (heightmap, mesh params, etc.).
@export var terrain_configuration: TerrainConfiguration = TerrainConfiguration.new():
	set(value):
		if terrain_configuration and terrain_configuration.configuration_changed.is_connected(_on_config_changed):
			terrain_configuration.configuration_changed.disconnect(_on_config_changed)
		terrain_configuration = value
		if terrain_configuration:
			terrain_configuration.configuration_changed.connect(_on_config_changed)

## When true, automatically regenerate terrain when configuration changes.
@export var auto_generate: bool = true:
	set(value):
		auto_generate = value
		if auto_generate:
			regenerate()

## When true, runs generation on a worker thread to prevent editor hangs.
@export var use_async_generation: bool = true

@export_group("Debug")
## Whether to print generation timings after generation.
@export var show_generation_time: bool = false
## Editor tool button that triggers terrain regeneration.
@export_tool_button("Regenerate Terrain") var regenerate_action := regenerate
## Editor tool button to apply visual changes without regenerating.
@export_tool_button("Update Visuals") var update_visuals_action := _update_visuals

static var current_presenter: TerrainPresenter = null

var _mesh_instance: MeshInstance3D
var _terrain_collision: TerrainCollision
## TODO: Refactor agent node handling into separate component
var _agent_nodes_container: Node3D
var _generation_service: TerrainGenerationService
## Chunk manager (only used when chunking is enabled)
var _chunk_manager: ChunkManager


## Current terrain data (tracked for cleanup)
var _current_terrain_data: TerrainData = null

## Async generation state
var _is_generating: bool = false

func _ready() -> void:
	_generation_service = TerrainGenerationService.new()
	_setup_scene_nodes()
	_setup_collision()
	if terrain_configuration and auto_generate:
		regenerate()

## Setup required scene nodes (MeshInstance3D, agent nodes container).
## Check if chunking mode is enabled in configuration
func _is_chunking_enabled() -> bool:
	return terrain_configuration != null and \
		terrain_configuration.chunk_configuration != null and \
		terrain_configuration.chunk_configuration.enable_chunking

func _setup_scene_nodes() -> void:
	_mesh_instance = NodeCreationHelper.get_or_create_node(self, "TerrainMesh", MeshInstance3D) as MeshInstance3D
	_agent_nodes_container = NodeCreationHelper.get_or_create_node(self, "AgentGeneratedNodes", Node3D) as Node3D

## Setup terrain collision handler.
func _setup_collision() -> void:
	_terrain_collision = TerrainCollision.new(self)

## Regenerate terrain from the current `configuration` and update the scene.
## Uses async generation if use_async_generation is enabled, otherwise runs synchronously.
func regenerate() -> void:
	current_presenter = self
	if not terrain_configuration:
		push_warning("TerrainPresenter: No configuration assigned")
		return
	if not terrain_configuration.is_valid():
		push_error("TerrainPresenter: Invalid configuration")
		return
	if use_async_generation:
		_regenerate_async()
	else:
		_regenerate_sync()

## Synchronous terrain generation (blocks the main thread).
func _regenerate_sync() -> void:
	if _is_chunking_enabled():
		_regenerate_chunked_sync()
	else:
		var terrain_data := _generation_service.generate(terrain_configuration)
		_apply_generated_terrain(terrain_data)

## Asynchronous terrain generation (runs on worker thread).
func _regenerate_async() -> void:
	if _is_generating:
		push_warning("TerrainPresenter: Generation already in progress, ignoring request")
		return
	_is_generating = true
	var config_copy := terrain_configuration.duplicate()
	if _is_chunking_enabled():
		WorkerThreadPool.add_task(_generate_chunked_on_worker_thread.bind(config_copy))
	else:
		WorkerThreadPool.add_task(_generate_on_worker_thread.bind(config_copy))

## Worker thread function - generates terrain data without touching scene nodes.
func _generate_on_worker_thread(config: TerrainConfiguration) -> void:
	var terrain_data := _generation_service.generate(config)
	_on_generation_complete_from_thread.call_deferred(terrain_data)

## Called on main thread when worker thread completes.
func _on_generation_complete_from_thread(terrain_data: TerrainData) -> void:
	_is_generating = false
	_apply_generated_terrain(terrain_data)

## Apply generated terrain to scene (must be called on main thread).
func _apply_generated_terrain(terrain_data: TerrainData) -> void:
	if not terrain_data:
		push_error("TerrainPresenter: Generation failed")
		return
	if show_generation_time:
		print("TerrainPresenter: Async generation completed in %.1f ms" % terrain_data.generation_time_ms)
	_update_presentation(terrain_data)

## Update scene nodes (mesh, material, collision) from the current TerrainData.
func _update_presentation(terrain_data: TerrainData) -> void:
	if _current_terrain_data and _current_terrain_data != terrain_data:
		_current_terrain_data.cleanup_orphaned_nodes()
	_current_terrain_data = terrain_data
	if not terrain_data:
		push_warning("TerrainPresenter: No terrain data to present")
		return
	if not _is_chunking_enabled():
		if _mesh_instance:
			_mesh_instance.mesh = terrain_data.get_mesh()
			_mesh_instance.visible = true
		_update_visuals()
		if terrain_configuration.generate_collision: 
			_terrain_collision.update_collision(terrain_data, terrain_configuration.collision_layers)
	else:
		if _mesh_instance:
			_mesh_instance.visible = false
	_update_agent_nodes(terrain_data)

## Update material from terrain configuration parameters.
func _update_visuals() -> void:
	if terrain_configuration.terrain_material:
		_mesh_instance.material_override = terrain_configuration.terrain_material
	if terrain_configuration.terrain_material and terrain_configuration.terrain_material is ShaderMaterial:
		var shader_mat := terrain_configuration.terrain_material as ShaderMaterial
		# TODO: better configurable parameter mapping
		var parameter_name := "height"
		if shader_mat.get_shader_parameter(parameter_name) != null:
			shader_mat.set_shader_parameter(parameter_name, terrain_configuration.snow_line)

## Called when the terrain configuration changes.
func _on_config_changed() -> void:
	if auto_generate:
		regenerate()

## Update agent-generated scene nodes from terrain data.
func _update_agent_nodes(terrain_data: TerrainData) -> void:
	if not _agent_nodes_container:
		return
	for child in _agent_nodes_container.get_children():
		_agent_nodes_container.remove_child(child)
		child.queue_free()
	if terrain_data and terrain_data.agent_node_root:
		var agent_root := terrain_data.agent_node_root
		for child in agent_root.get_children():
			agent_root.remove_child(child)
			_agent_nodes_container.add_child(child)
			if Engine.is_editor_hint():
				_set_owner_recursive(child, get_tree().edited_scene_root)
		print("TerrainPresenter: Added %d agent-generated objects" % _agent_nodes_container.get_child_count())
		agent_root.queue_free()
		terrain_data.agent_node_root = null

## Recursively set owner for node and all descendants (needed for editor visibility).
func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)

## Synchronous chunked terrain generation
func _regenerate_chunked_sync() -> void:
	var terrain_data := _generation_service.generate(terrain_configuration)
	var chunked_data := _partition_terrain_into_chunks(terrain_data)
	_apply_chunked_terrain(terrain_data, chunked_data)

## Worker thread function for chunked terrain generation
func _generate_chunked_on_worker_thread(config: TerrainConfiguration) -> void:
	var terrain_data := _generation_service.generate(config)
	var chunked_data := _partition_terrain_into_chunks(terrain_data)
	_on_chunked_generation_complete_from_thread.call_deferred(terrain_data, chunked_data)

## Called on main thread when chunked worker thread completes
func _on_chunked_generation_complete_from_thread(terrain_data: TerrainData, chunked_data: ChunkedTerrainData) -> void:
	_is_generating = false
	_apply_chunked_terrain(terrain_data, chunked_data)

## Partition generated terrain into chunks
func _partition_terrain_into_chunks(terrain_data: TerrainData) -> ChunkedTerrainData:
	if not terrain_data:
		return null
	var chunk_config := terrain_configuration.chunk_configuration
	var chunked_data := ChunkedTerrainData.new()
	chunked_data.terrain_data = terrain_data
	chunked_data.chunk_size = chunk_config.chunk_size
	# TODO: Implement actual terrain partitioning logic
	# This would slice the terrain mesh into chunks based on chunk_size
	# For now, return empty chunked data structure
	return chunked_data

## Apply chunked terrain to scene
func _apply_chunked_terrain(terrain_data: TerrainData, chunked_data: ChunkedTerrainData) -> void:
	if not terrain_data or not chunked_data:
		push_error("TerrainPresenter: Chunked generation failed")
		return
	if show_generation_time:
		print("TerrainPresenter: Chunked terrain generation completed in %.1f ms" % terrain_data.generation_time_ms)
	_update_presentation(terrain_data)
	_setup_chunk_manager(chunked_data)

## Setup or update chunk manager with chunked terrain data
func _setup_chunk_manager(chunked_data: ChunkedTerrainData) -> void:
	var chunk_config := terrain_configuration.chunk_configuration
	if not _chunk_manager:
		_chunk_manager = NodeCreationHelper.get_or_create_node(self, "ChunkManager", ChunkManager) as ChunkManager
		_chunk_manager.generate_collision = terrain_configuration.generate_collision
		_chunk_manager.collision_layers = terrain_configuration.collision_layers
		_chunk_manager.full_collision_distance = chunk_config.collision_distance
	_chunk_manager.chunk_data_source = chunked_data
	_chunk_manager.load_strategy = _create_load_strategy(chunk_config)

## Create chunk loading strategy from configuration
func _create_load_strategy(_chunk_config: ChunkConfiguration) -> ChunkLoadStrategy:
	# TODO: Implement strategy factory based on _chunk_config.loading_strategy
	# For now return null, implementation pending
	return null

