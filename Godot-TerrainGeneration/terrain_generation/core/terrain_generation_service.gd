## @brief Service that orchestrates the terrain generation pipeline (heightmap -> mesh -> collision).
##
## Uses a `TerrainConfiguration` to generate `TerrainData`. Supports caching
## and selecting CPU/GPU mesh modifiers via the configuration.
class_name TerrainGenerationService extends RefCounted

## Mesh builder used to convert heightmaps into meshes.
var mesh_builder: TerrainMeshBuilder
## Simple in-memory cache mapping configuration keys to TerrainData.
var _cache: Dictionary = {}

var last_mesh_modifier_context: MeshModifierContext = null

func _init():
	mesh_builder = TerrainMeshBuilder.new()

## Generate complete terrain data from a `TerrainConfiguration`.
## Returns a `TerrainData` object or null on failure.
func generate(config: TerrainConfiguration) -> TerrainData:
	return _generate(config)

func _generate(config: TerrainConfiguration) -> TerrainData:
	if not config or not config.is_valid():
		push_error("TerrainGenerationService: Invalid configuration")
		return null
	var cache_key := _get_cache_key(config)
	if config.enable_caching and _cache.has(cache_key):
		print("TerrainGenerationService: Using cached terrain")
		return _cache[cache_key]
	var start_time := Time.get_ticks_msec()
	var processing_context := _generate_processing_context(config)
	var heightmap := _generate_heightmap(config, processing_context)
	if not heightmap:
		processing_context.dispose()
		push_error("TerrainGenerationService: Failed to generate heightmap")
		return null
	var mesh_result := mesh_builder.build_mesh(heightmap, processing_context)
	if not mesh_result:
		processing_context.dispose()
		push_error("TerrainGenerationService: Failed to build mesh")
		return null
	_execute_mesh_modification_pipeline(config, processing_context, heightmap, mesh_result)
	processing_context.dispose()
	var collision := _generate_collision_shape(config, mesh_result)
	var total_time := Time.get_ticks_msec() - start_time
	var terrain_data := _create_terrain_data(config, heightmap, mesh_result, collision, total_time)
	_set_cache(config, terrain_data)
	print("TerrainGenerationService: Generated terrain in %s ms (%s vertices)" % [
		str(total_time),
		str(terrain_data.get_vertex_count())
	])
	return terrain_data

## Set mesh modifier based on configuration enum type.
func set_mesh_modifier_type(type: TerrainConfiguration.MeshModifierType) -> void:
	match type:
		TerrainConfiguration.MeshModifierType.CPU:
			mesh_builder.set_mesh_modifier(CPUMeshGenerator.new())
		TerrainConfiguration.MeshModifierType.GPU:
			mesh_builder.set_mesh_modifier(GpuMeshGenerator.new())

## Clear the internal generation cache.
func clear_cache() -> void:
	_cache.clear()

## Invalidate a specific cached entry derived from `config`.
func invalidate_cache(config: TerrainConfiguration) -> void:
	var key := _get_cache_key(config)
	_cache.erase(key)

func _get_cache_key(config: TerrainConfiguration) -> String:
	var key_parts := [
		str(config.get_mesh_parameters()),
		str(config.heightmap_source.get_metadata())
	]
	if config.mesh_modification_pipeline:
		key_parts.append(str(config.mesh_modification_pipeline.get_instance_id()))
	return str(hash("".join(key_parts)))

func _generate_processing_context(config: TerrainConfiguration) -> ProcessingContext:
	var processor_type := config.get_effective_processor_type()
	return ProcessingContext.new(
		config.terrain_size,
		config.generation_seed,
		processor_type
	)

func _generate_heightmap(config: TerrainConfiguration, processing_context: ProcessingContext) -> Image:
	processing_context.mesh_params = config.mesh_generator_parameters
	return config.heightmap_source.generate(processing_context)

func _execute_mesh_modification_pipeline(config: TerrainConfiguration, processing_context: ProcessingContext, heightmap: Image, mesh_result: MeshGenerationResult) -> void:
	var scene_root: Node3D = null
	if config.mesh_modification_pipeline:
		var initial_terrain_data := TerrainData.new(heightmap, mesh_result, Vector2(config.terrain_size, config.terrain_size), null, {}, 0)
		var modifier_context := config.mesh_modification_pipeline.execute(
			initial_terrain_data,
			processing_context,
			scene_root,
			processing_context.mesh_params
		)
		if modifier_context:
			last_mesh_modifier_context = modifier_context
			mesh_result = modifier_context.get_mesh_data()
			scene_root = modifier_context.scene_root			
		else:
			push_warning("TerrainGenerationService: Mesh modification pipeline failed")

func _generate_collision_shape(config: TerrainConfiguration, mesh_result: MeshGenerationResult) -> Shape3D:
	if config.generate_collision:
		return mesh_builder.build_collision(mesh_result)
	return null

func _create_terrain_data(config: TerrainConfiguration, heightmap: Image, mesh_result: MeshGenerationResult, collision: Shape3D, total_time: int) -> TerrainData:
	var metadata := {
		"heightmap_metadata": config.heightmap_source.get_metadata(),
		"configuration": {
			"size": config.mesh_generator_parameters.mesh_size,
			"subdivisions": config.mesh_generator_parameters.subdivisions,
			"max_height": config.mesh_generator_parameters.height_scale,
			"generation_seed": config.generation_seed
		},
		"mesh_modification_enabled": config.mesh_modification_pipeline != null,
	}
	return TerrainData.new(heightmap, mesh_result, Vector2(config.terrain_size, config.terrain_size), collision, metadata, total_time)

func _set_cache(config: TerrainConfiguration, terrain_data: TerrainData) -> void:
	var cache_key := _get_cache_key(config)
	if config.enable_caching:
		_cache[cache_key] = terrain_data


