## @brief Node that presents generated terrain in the scene and exposes editor controls.
##
## @details Binds a `TerrainConfiguration` resource, runs the generation service
## and updates MeshInstance3D / StaticBody3D nodes with the generated terrain.
## Supports auto-generation in the editor and a tool button to regenerate.
@tool
class_name TerrainPresenter extends Node3D

## Terrain configuration resource driving generation (heightmap, mesh params, etc.).
@export var configuration: TerrainConfiguration:
	set(value):
		if configuration and configuration.configuration_changed.is_connected(_on_config_changed):
			configuration.configuration_changed.disconnect(_on_config_changed)
		configuration = value
		if configuration:
			configuration.configuration_changed.connect(_on_config_changed)
		_mark_dirty()

## When true, automatically regenerate terrain when configuration changes.
@export var auto_generate: bool = true:
	set(value):
		auto_generate = value
		if auto_generate:
			_mark_dirty()

@export_group("Debug")
## Whether to print generation timings after generation.
@export var show_generation_time: bool = false
## Editor tool button that triggers terrain regeneration.
@export_tool_button("Regenerate Terrain") var regenerate_action := regenerate
## Editor tool button to apply visual changes without regenerating.
@export_tool_button("Update Visuals") var update_visuals_action := _update_visuals

var _mesh_instance: MeshInstance3D
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _agent_nodes_container: Node3D
var _generation_service: TerrainGenerationService
var _current_terrain_data: TerrainData
var _is_dirty: bool = true

func _ready() -> void:
	_generation_service = TerrainGenerationService.new()
	_setup_scene_nodes()
	
	# if auto_generate and configuration:
	if configuration:
		regenerate()

func _setup_scene_nodes() -> void:
	if not _mesh_instance:
		_mesh_instance = get_node_or_null("TerrainMesh")
		if not _mesh_instance:
			_mesh_instance = MeshInstance3D.new()
			_mesh_instance.name = "TerrainMesh"
			add_child(_mesh_instance)
			if Engine.is_editor_hint():
				_mesh_instance.owner = get_tree().edited_scene_root

	if not _collision_body:
		_collision_body = get_node_or_null("TerrainCollision")
		if not _collision_body:
			_collision_body = StaticBody3D.new()
			_collision_body.name = "TerrainCollision"
			add_child(_collision_body)
			if Engine.is_editor_hint():
				_collision_body.owner = get_tree().edited_scene_root

	if not _collision_shape:
		_collision_shape = _collision_body.get_node_or_null("CollisionShape")
		if not _collision_shape:
			_collision_shape = CollisionShape3D.new()
			_collision_shape.name = "CollisionShape"
			_collision_body.add_child(_collision_shape)
			if Engine.is_editor_hint():
				_collision_shape.owner = get_tree().edited_scene_root
	
	if not _agent_nodes_container:
		var agent_objects_name := "AgentObjects"
		_agent_nodes_container = get_node_or_null(agent_objects_name)
		if not _agent_nodes_container:
			_agent_nodes_container = Node3D.new()
			_agent_nodes_container.name = agent_objects_name
			add_child(_agent_nodes_container)
			if Engine.is_editor_hint():
				_agent_nodes_container.owner = get_tree().edited_scene_root

## Regenerate terrain from the current `configuration` and update the scene.
func regenerate() -> void:
	if not configuration:
		push_warning("TerrainPresenter: No configuration assigned")
		return
	if not configuration.is_valid():
		push_error("TerrainPresenter: Invalid configuration")
		return
	_generation_service.set_mesh_modifier_type(configuration.mesh_modifier_type)
	_current_terrain_data = _generation_service.generate(configuration)
	if not _current_terrain_data:
		push_error("TerrainPresenter: Failed to generate terrain")
		return
	_update_presentation()
	_is_dirty = false
	if show_generation_time:
		print("TerrainPresenter: Terrain displayed (generated in %.1f ms)" % _current_terrain_data.generation_time_ms)

## Update scene nodes (mesh, material, collision) from the current TerrainData.
func _update_presentation() -> void:
	if not _current_terrain_data:
		return
	_update_visuals()
	_update_collision()
	_update_agent_nodes()

## Update collision shape from the current TerrainData.
func _update_collision() -> void:
	if _collision_shape and configuration.generate_collision and _current_terrain_data:
		_collision_shape.shape = _current_terrain_data.collision_shape
		_collision_body.collision_layer = configuration.collision_layers
		_collision_body.visible = configuration.generate_collision
	else:
		_collision_body.visible = false

## Update mesh and material from the current TerrainData.
func _update_visuals() -> void:
	if _mesh_instance:
		_mesh_instance.mesh = _current_terrain_data.get_mesh()
		if configuration.terrain_material:
			_mesh_instance.material_override = configuration.terrain_material
		if configuration.terrain_material and configuration.terrain_material is ShaderMaterial:
			var shader_mat := configuration.terrain_material as ShaderMaterial
			if shader_mat.get_shader_parameter("height") != null:
				shader_mat.set_shader_parameter("height", configuration.snow_line)


func _on_config_changed() -> void:
	# TODO: Mark dirty mesh and dirty heightmap separately
	_mark_dirty()
	if auto_generate:
		regenerate()

func _mark_dirty() -> void:
	_is_dirty = true
	if configuration and _generation_service:
		_generation_service.invalidate_cache(configuration)

## Update agent-generated scene nodes from terrain metadata.
func _update_agent_nodes() -> void:
	if not _agent_nodes_container:
		return
	
	# Clear existing agent nodes
	for child in _agent_nodes_container.get_children():
		_agent_nodes_container.remove_child(child)
		child.queue_free()
	
	# Add new agent nodes if present in metadata
	if _current_terrain_data and _current_terrain_data.metadata.has("scene_root"):
		var scene_root = _current_terrain_data.metadata.get("scene_root")
		if scene_root and scene_root is Node3D:
			# Reparent all children from the pipeline's scene_root to our container
			for child in scene_root.get_children():
				scene_root.remove_child(child)
				_agent_nodes_container.add_child(child)
				if Engine.is_editor_hint():
					child.owner = get_tree().edited_scene_root
			
			print("TerrainPresenter: Added %d agent-generated objects" % _agent_nodes_container.get_child_count())

## Return the currently displayed TerrainData or null if none.
func get_terrain_data() -> TerrainData:
	return _current_terrain_data

## Return the currently displayed heightmap image or null.
func get_heightmap() -> Image:
	return _current_terrain_data.heightmap if _current_terrain_data else null

## Clear the generation service cache.
func clear_cache() -> void:
	_generation_service.clear_cache()
