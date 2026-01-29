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
var _agent_nodes_container: Node3D
var _generation_service: TerrainGenerationService
var _chunked_presenter: ChunkedTerrainPresenter

## Current terrain data (tracked for cleanup)
var _current_terrain_data: TerrainData = null

## Async generation state
var _is_generating: bool = false

func _ready() -> void:
	_generation_service = TerrainGenerationService.new()
	_chunked_presenter = ChunkedTerrainPresenter.new(self, terrain_configuration)
	_setup_scene_nodes()
	_setup_collision()
	if terrain_configuration:
		regenerate()

## Setup required scene nodes (MeshInstance3D, agent nodes container).
func _setup_scene_nodes() -> void:
	_mesh_instance = NodeCreationHelper.get_or_create_node(self, "TerrainMesh", MeshInstance3D) as MeshInstance3D
	_agent_nodes_container = NodeCreationHelper.get_or_create_node(self, "AgentGeneratedNodes", Node3D) as Node3D

## Check if chunking mode is enabled in configuration
func _is_chunking_enabled() -> bool:
	return _chunked_presenter and _chunked_presenter.is_enabled()

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
	var terrain_data := _generation_service.generate(terrain_configuration)
	_apply_generated_terrain(terrain_data)

## Asynchronous terrain generation (runs on worker thread).
func _regenerate_async() -> void:
	if _is_generating:
		push_warning("TerrainPresenter: Generation already in progress, ignoring request")
		return
	_is_generating = true
	var config_copy := terrain_configuration.duplicate()
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
	if _is_chunking_enabled():
		var chunked_data := _chunked_presenter.partition_terrain(terrain_data)
		if not chunked_data:
			push_error("TerrainPresenter: Chunked generation failed")
			return
		_chunked_presenter.apply_chunked_terrain(chunked_data)
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
		_chunked_presenter.disable()
		if _mesh_instance:
			_mesh_instance.mesh = terrain_data.get_mesh()
			_mesh_instance.visible = true
		if terrain_configuration.generate_collision: 
			_terrain_collision.update_collision(terrain_data, terrain_configuration.collision_layers)
	else:
		_chunked_presenter.enable()
		if _mesh_instance:
			_mesh_instance.visible = false
	_update_visuals()
	_update_agent_nodes(terrain_data)

## Update material from terrain configuration parameters.
func _update_visuals() -> void:
	if not terrain_configuration.terrain_material:
		return
	var material := terrain_configuration.terrain_material
	if material is ShaderMaterial:
		var shader_mat := material as ShaderMaterial
		# TODO: better configurable parameter mapping
		var parameter_name := "height"
		if shader_mat.get_shader_parameter(parameter_name) != null:
			shader_mat.set_shader_parameter(parameter_name, terrain_configuration.snow_line)
	if _is_chunking_enabled():
		_chunked_presenter.update_visuals(material)
	else:
		if _mesh_instance:
			_mesh_instance.material_override = material

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
				NodeCreationHelper.set_node_owner_recursive(child, get_tree().edited_scene_root)
		print("TerrainPresenter: Added %d agent-generated objects" % _agent_nodes_container.get_child_count())
		agent_root.queue_free()
		terrain_data.agent_node_root = null

