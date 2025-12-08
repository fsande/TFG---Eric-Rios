## @brief Service that orchestrates the terrain generation pipeline (heightmap -> mesh -> collision).
##
## Uses a `TerrainConfiguration` to generate `TerrainData`. Supports caching
## and selecting CPU/GPU mesh modifiers via the configuration.
class_name TerrainGenerationService extends RefCounted

## Mesh builder used to convert heightmaps into meshes.
var mesh_builder: TerrainMeshBuilder
## Simple in-memory cache mapping configuration keys to TerrainData.
var _cache: Dictionary = {}

func _init():
	mesh_builder = TerrainMeshBuilder.new()

## Generate complete terrain data from a `TerrainConfiguration`.
## Returns a `TerrainData` object or null on failure.
## TODO: Refactor this 
func generate(config: TerrainConfiguration) -> TerrainData:
	if not config or not config.is_valid():
		push_error("TerrainGenerationService: Invalid configuration")
		return null
	var start_time := Time.get_ticks_msec()
	var cache_key := _get_cache_key(config)
	if config.enable_caching and _cache.has(cache_key):
		print("TerrainGenerationService: Using cached terrain")
		return _cache[cache_key]
	var processor_type := config.get_effective_processor_type()
	var processing_context := ProcessingContext.new(
		config.terrain_size,
		config.generation_seed,
		processor_type
	)
	processing_context.mesh_params = config.mesh_generator_parameters
	var type_str := "GPU" if processor_type == ProcessingContext.ProcessorType.GPU else "CPU"
	print("TerrainGenerationService: Created ProcessingContext (type: %s, seed: %s)" % [type_str, str(config.generation_seed)])
	var heightmap := config.heightmap_source.generate(processing_context)
	if not heightmap:
		processing_context.dispose()
		push_error("TerrainGenerationService: Failed to generate heightmap")
		return null
	var mesh_result := mesh_builder.build_mesh(heightmap, processing_context)
	if not mesh_result:
		processing_context.dispose()
		push_error("TerrainGenerationService: Failed to build mesh")
		return null
	var scene_root: Node3D = null
	if config.mesh_modification_pipeline:
		var pipeline_start := Time.get_ticks_msec()
		print("TerrainGenerationService: Executing mesh modification pipeline...")
		var initial_terrain_data := TerrainData.new(heightmap, mesh_result, Vector2(config.terrain_size, config.terrain_size), null, {}, 0)
		var modifier_context := config.mesh_modification_pipeline.execute(
			initial_terrain_data,
			processing_context,
			scene_root,
			processing_context.mesh_params
		)
		
		if modifier_context:
			mesh_result = modifier_context.get_mesh_data()
			scene_root = modifier_context.scene_root
			
			var pipeline_time := Time.get_ticks_msec() - pipeline_start
			print("TerrainGenerationService: Mesh modification complete in %d ms" % pipeline_time)
		else:
			push_warning("TerrainGenerationService: Mesh modification pipeline failed, using unmodified mesh")
	
	var collision: Shape3D = null
	if config.generate_collision:
		collision = mesh_builder.build_collision(mesh_result)
	processing_context.dispose()
	var total_time := Time.get_ticks_msec() - start_time
	var metadata := {
		"heightmap_metadata": config.heightmap_source.get_metadata(),
		"configuration": {
			"size": config.mesh_generator_parameters.mesh_size,
			"subdivisions": config.mesh_generator_parameters.subdivisions,
			"max_height": config.mesh_generator_parameters.height_scale,
			"generation_seed": config.generation_seed
		},
		"mesh_modification_enabled": config.mesh_modification_pipeline != null,
		"scene_root": scene_root
	}
	var terrain_data := TerrainData.new(heightmap, mesh_result, Vector2(config.terrain_size, config.terrain_size), collision, metadata, total_time)
	if config.enable_caching:
		_cache[cache_key] = terrain_data
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
