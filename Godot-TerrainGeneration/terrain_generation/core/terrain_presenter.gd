## @brief Node that presents generated terrain in the scene and exposes editor controls.
##
## @details Binds a `TerrainConfiguration` resource, runs the generation service
## and updates MeshInstance3D / StaticBody3D nodes with the generated terrain.
## Supports auto-generation in the editor and a tool button to regenerate.
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

## Async generation state
var _is_generating: bool = false

func _ready() -> void:
	_generation_service = TerrainGenerationService.new()
	_setup_scene_nodes()
	_setup_collision()
	if terrain_configuration and auto_generate:
		regenerate()

## Setup required scene nodes (MeshInstance3D, agent nodes container).
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
	var terrain_data := _generation_service.generate(terrain_configuration)
	_apply_generated_terrain(terrain_data)

## Asynchronous terrain generation (runs on worker thread).
func _regenerate_async() -> void:
	if _is_generating:
		push_warning("TerrainPresenter: Generation already in progress, ignoring request")
		return
	_is_generating = true
	var config_copy := terrain_configuration
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
	if not terrain_data:
		push_warning("TerrainPresenter: No terrain data to present")
		return
	if _mesh_instance:
		_mesh_instance.mesh = terrain_data.get_mesh()
	_update_visuals()
	if terrain_configuration.generate_collision: 
		_terrain_collision.update_collision(terrain_data, terrain_configuration.collision_layers)
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

## Update agent-generated scene nodes from terrain metadata.
func _update_agent_nodes(terrain_data: TerrainData) -> void:
	if not _agent_nodes_container:
		return
	for child in _agent_nodes_container.get_children():
		_agent_nodes_container.remove_child(child)
		child.queue_free()
	if terrain_data and terrain_data.metadata.has("scene_root"):
		var scene_root = terrain_data.metadata.get("scene_root")
		if scene_root and scene_root is Node3D:
			for child in scene_root.get_children():
				scene_root.remove_child(child)
				_agent_nodes_container.add_child(child)
				if Engine.is_editor_hint():
					child.owner = get_tree().edited_scene_root
			print("TerrainPresenter: Added %d agent-generated objects" % _agent_nodes_container.get_child_count())
