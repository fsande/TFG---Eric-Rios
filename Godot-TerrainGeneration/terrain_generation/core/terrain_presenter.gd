## @brief Node that presents generated terrain in the scene and exposes editor controls.
##
## @details Binds a `TerrainConfiguration` resource, runs the generation service
## and updates MeshInstance3D / StaticBody3D nodes with the generated terrain.
## Supports auto-generation in the editor and a tool button to regenerate.
@tool
class_name TerrainPresenter extends Node3D

## Emitted when async generation starts.
signal generation_started()
## Emitted when async generation completes successfully.
signal generation_completed(terrain_data: TerrainData)
## Emitted when async generation fails.
signal generation_failed(error_message: String)

## Terrain configuration resource driving generation (heightmap, mesh params, etc.).
@export var terrain_configuration: TerrainConfiguration = TerrainConfiguration.new():
	set(value):
		if terrain_configuration and terrain_configuration.configuration_changed.is_connected(_on_config_changed):
			terrain_configuration.configuration_changed.disconnect(_on_config_changed)
		terrain_configuration = value
		if terrain_configuration:
			terrain_configuration.configuration_changed.connect(_on_config_changed)
		_mark_dirty()


## When true, automatically regenerate terrain when configuration changes.
@export var auto_generate: bool = true:
	set(value):
		auto_generate = value
		if auto_generate:
			_mark_dirty()

## When true, runs generation on a worker thread to prevent editor hangs.
@export var use_async_generation: bool = true

@export_group("Debug")
## Whether to print generation timings after generation.
@export var show_generation_time: bool = false
## Editor tool button that triggers terrain regeneration.
@export_tool_button("Regenerate Terrain") var regenerate_action := regenerate
## Editor tool button to apply visual changes without regenerating.
@export_tool_button("Update Visuals") var update_visuals_action := _update_visuals

var _mesh_instance: MeshInstance3D
var _terrain_collision: TerrainCollision
## TODO: Refactor agent node handling into separate component
var _agent_nodes_container: Node3D
var _generation_service: TerrainGenerationService
var _current_terrain_data: TerrainData
var _is_dirty: bool = true

## Async generation state
var _is_generating: bool = false

func _ready() -> void:
	_generation_service = TerrainGenerationService.new()
	_setup_scene_nodes()
	_setup_collision()
	if terrain_configuration and auto_generate:
		regenerate()

func _setup_scene_nodes() -> void:
	_mesh_instance = NodeCreationHelper.get_or_create_node(self, "TerrainMesh", MeshInstance3D) as MeshInstance3D
	_agent_nodes_container = NodeCreationHelper.get_or_create_node(self, "AgentGeneratedNodes", Node3D) as Node3D

func _setup_collision() -> void:
	_terrain_collision = TerrainCollision.new(self)

## Regenerate terrain from the current `configuration` and update the scene.
## Uses async generation if use_async_generation is enabled, otherwise runs synchronously.
func regenerate() -> void:
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
	_current_terrain_data = _generation_service.generate(terrain_configuration)
	if not _current_terrain_data:
		push_error("TerrainPresenter: Failed to generate terrain")
		return
	_update_presentation()
	_is_dirty = false
	if show_generation_time:
		print("TerrainPresenter: Terrain displayed (generated in %.1f ms)" % _current_terrain_data.generation_time_ms)

## Asynchronous terrain generation (runs on worker thread).
func _regenerate_async() -> void:
	if _is_generating:
		push_warning("TerrainPresenter: Generation already in progress, ignoring request")
		return
	_is_generating = true
	generation_started.emit()
	print("TerrainPresenter: Starting async terrain generation...")
	var config_copy := terrain_configuration
	WorkerThreadPool.add_task(_generate_on_worker_thread.bind(config_copy))

## Worker thread function - generates terrain data without touching scene nodes.
func _generate_on_worker_thread(config: TerrainConfiguration) -> void:
	print("TerrainPresenter: Generation running on worker thread...")
	var terrain_data := _generation_service.generate(config)
	_on_generation_complete_from_thread.call_deferred(terrain_data)

## Called on main thread when worker thread completes.
func _on_generation_complete_from_thread(terrain_data: TerrainData) -> void:
	_is_generating = false
	if not terrain_data:
		var error_msg := "Failed to generate terrain"
		push_error("TerrainPresenter: " + error_msg)
		generation_failed.emit(error_msg)
		return
	_apply_generated_terrain(terrain_data)
	if show_generation_time:
		print("TerrainPresenter: Async generation completed in %.1f ms" % terrain_data.generation_time_ms)

## Apply generated terrain to scene (must be called on main thread).
func _apply_generated_terrain(terrain_data: TerrainData) -> void:
	_current_terrain_data = terrain_data
	_update_presentation()
	_is_dirty = false
	generation_completed.emit(terrain_data)
	print("TerrainPresenter: Terrain applied to scene")

## Update scene nodes (mesh, material, collision) from the current TerrainData.
func _update_presentation() -> void:
	if not _current_terrain_data:
		print("TerrainPresenter: No terrain data to present")
		return
	_update_visuals()
	if terrain_configuration.generate_collision: 
		_terrain_collision.update_collision(_current_terrain_data, terrain_configuration.collision_layers)
	_update_agent_nodes()

## Update mesh and material from the current TerrainData.
func _update_visuals() -> void:
	if _mesh_instance:
		_mesh_instance.mesh = _current_terrain_data.get_mesh()
		if terrain_configuration.terrain_material:
			_mesh_instance.material_override = terrain_configuration.terrain_material
		if terrain_configuration.terrain_material and terrain_configuration.terrain_material is ShaderMaterial:
			var shader_mat := terrain_configuration.terrain_material as ShaderMaterial
			if shader_mat.get_shader_parameter("height") != null:
				shader_mat.set_shader_parameter("height", terrain_configuration.snow_line)

func _on_config_changed() -> void:
	# TODO: Mark dirty mesh and dirty heightmap separately
	_mark_dirty()
	if auto_generate:
		regenerate()

func _mark_dirty() -> void:
	_is_dirty = true
	if terrain_configuration and _generation_service:
		_generation_service.invalidate_cache(terrain_configuration)

## Update agent-generated scene nodes from terrain metadata.
func _update_agent_nodes() -> void:
	if not _agent_nodes_container:
		return
	for child in _agent_nodes_container.get_children():
		_agent_nodes_container.remove_child(child)
		child.queue_free()
	if _current_terrain_data and _current_terrain_data.metadata.has("scene_root"):
		var scene_root = _current_terrain_data.metadata.get("scene_root")
		if scene_root and scene_root is Node3D:
			for child in scene_root.get_children():
				scene_root.remove_child(child)
				_agent_nodes_container.add_child(child)
				if Engine.is_editor_hint():
					child.owner = get_tree().edited_scene_root
			print("TerrainPresenter: Added %d agent-generated objects" % _agent_nodes_container.get_child_count())
