## @brief Handles chunked terrain presentation logic.
##
## @details Encapsulates all chunking-specific presentation logic including
## partitioning, chunk manager setup, and load strategy creation.
## Follows SRP by separating chunking concerns from base terrain presentation.
@tool
class_name ChunkedTerrainPresenter extends RefCounted

var _parent_node: Node3D
var _chunk_manager: ChunkManager
var _terrain_configuration: TerrainConfiguration

func _init(parent: Node3D, config: TerrainConfiguration) -> void:
	_parent_node = parent
	_terrain_configuration = config

## Check if chunking is enabled in configuration
func is_enabled() -> bool:
	return _terrain_configuration != null and \
		_terrain_configuration.chunk_configuration != null and \
		_terrain_configuration.chunk_configuration.enable_chunking

## Partition terrain data into chunks
func partition_terrain(terrain_data: TerrainData) -> ChunkedTerrainData:
	if not terrain_data:
		return null
	var chunk_config := _terrain_configuration.chunk_configuration
	if chunk_config.enable_lod and chunk_config.lod_level_count > 1:
		return _partition_terrain_with_pre_generated_lods(terrain_data, chunk_config)
	else:
		return _partition_terrain_simple(terrain_data, chunk_config)

## Simple partitioning without pre-generated LODs
func _partition_terrain_simple(terrain_data: TerrainData, chunk_config: ChunkConfiguration) -> ChunkedTerrainData:
	var chunks := MeshPartitioner.partition_mesh(terrain_data.mesh_result, chunk_config.chunk_size)
	var chunked_data := ChunkedTerrainData.new()
	for chunk in chunks:
		chunked_data.add_chunk(chunk)
	chunked_data.terrain_data = terrain_data
	chunked_data.chunk_size = chunk_config.chunk_size
	return chunked_data

## Advanced partitioning: Generate LODs before chunking for optimal quality
func _partition_terrain_with_pre_generated_lods(terrain_data: TerrainData, chunk_config: ChunkConfiguration) -> ChunkedTerrainData:
	print("ChunkedTerrainPresenter: Generating LODs before chunking for optimal quality")
	var lod_strategy: LODGenerationStrategy = chunk_config.get_lod_strategy()
	if not lod_strategy:
		push_warning("ChunkedTerrainPresenter: No LOD strategy available, falling back to simple partitioning")
		return _partition_terrain_simple(terrain_data, chunk_config)
	var full_mesh_result := terrain_data.mesh_result
	var full_mesh_data := full_mesh_result.mesh_data
	var lod_meshes := lod_strategy.generate_lod_levels(
		full_mesh_data,
		chunk_config.lod_level_count,
		chunk_config.lod_reduction_ratios
	)
	if lod_meshes.size() < 2:
		push_warning("ChunkedTerrainPresenter: Failed to generate LOD levels, falling back to simple partitioning")
		return _partition_terrain_simple(terrain_data, chunk_config)
	print("ChunkedTerrainPresenter: Generated %d LOD levels for full terrain" % lod_meshes.size())
	var lod_chunk_arrays: Array[Array] = []
	for lod_level in range(lod_meshes.size()):
		var lod_mesh_data := lod_meshes[lod_level]
		var lod_result := MeshGenerationResult.new(
			lod_mesh_data.vertices,
			lod_mesh_data.indices,
			lod_mesh_data.uvs,
			0.0,
			"LOD"
		)
		lod_result.width = lod_mesh_data.width
		lod_result.height = lod_mesh_data.height
		lod_result.mesh_size = lod_mesh_data.mesh_size
		var lod_chunks := MeshPartitioner.partition_mesh(lod_result, chunk_config.chunk_size)
		lod_chunk_arrays.append(lod_chunks)
		print("ChunkedTerrainPresenter: LOD %d partitioned into %d chunks" % [lod_level, lod_chunks.size()])
	var chunked_data := ChunkedTerrainData.new()
	chunked_data.terrain_data = terrain_data
	chunked_data.chunk_size = chunk_config.chunk_size
	var base_chunks: Array = lod_chunk_arrays[0]
	for base_chunk_idx in range(base_chunks.size()):
		var base_chunk: ChunkMeshData = base_chunks[base_chunk_idx]
		base_chunk.lod_meshes.clear()
		base_chunk.lod_meshes.append(ArrayMeshBuilder.build_mesh(base_chunk.mesh_data))
		for lod_level in range(1, lod_chunk_arrays.size()):
			var lod_chunks: Array = lod_chunk_arrays[lod_level]
			if base_chunk_idx < lod_chunks.size():
				var lod_chunk: ChunkMeshData = lod_chunks[base_chunk_idx]
				if lod_chunk.chunk_coord == base_chunk.chunk_coord:
					var lod_mesh := ArrayMeshBuilder.build_mesh(lod_chunk.mesh_data)
					if lod_mesh:
						base_chunk.lod_meshes.append(lod_mesh)
				else:
					push_warning("ChunkedTerrainPresenter: LOD chunk coordinate mismatch at index %d" % base_chunk_idx)
		base_chunk.lod_level_count = base_chunk.lod_meshes.size()
		base_chunk.lod_distances = chunk_config.lod_distances.duplicate()
		base_chunk.mesh = base_chunk.lod_meshes[0] if base_chunk.lod_meshes.size() > 0 else null
		var total_triangles := 0
		for lod_mesh in base_chunk.lod_meshes:
			if lod_mesh and lod_mesh.get_surface_count() > 0:
				var arrays := lod_mesh.surface_get_arrays(0)
				var indices_arr: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				total_triangles += int(indices_arr.size() / 3.0)
		print("ChunkedTerrainPresenter: Chunk %v has %d LOD levels (Total triangles: %d)" % [
			base_chunk.chunk_coord,
			base_chunk.lod_level_count,
			total_triangles
		])
		chunked_data.add_chunk(base_chunk)
	print("ChunkedTerrainPresenter: Created %d chunks with %d LOD levels each" % [
		chunked_data.chunks.size(),
		lod_chunk_arrays.size()
	])
	return chunked_data

## Apply chunked terrain to the scene
func apply_chunked_terrain(chunked_data: ChunkedTerrainData) -> void:
	if not chunked_data:
		push_error("ChunkedTerrainPresenter: Invalid chunked data")
		return
	_setup_or_update_chunk_manager(chunked_data)

## Update visuals for all loaded chunks with the provided material
## @param material Pre-configured material with all shader parameters set
func update_visuals(material: Material) -> void:
	if not _chunk_manager:
		return
	_chunk_manager.set_terrain_material(material)

## Enable chunk manager
func enable() -> void:
	if _chunk_manager:
		_chunk_manager.enable()

## Disable chunk manager and clear chunk data
func disable() -> void:
	if _chunk_manager:
		_chunk_manager.disable()
	clear_chunk_data(true)

## Clear all chunk data from the chunk manager
func clear_chunk_data(deep_clear: bool) -> void:
	if _chunk_manager:
		_chunk_manager.clear_all_chunks(deep_clear)

## Cleanup chunk manager
func cleanup() -> void:
	if _chunk_manager:
		_chunk_manager.queue_free()
		_chunk_manager = null

## Setup or update the chunk manager with new data
func _setup_or_update_chunk_manager(chunked_data: ChunkedTerrainData) -> void:
	var chunk_config := _terrain_configuration.chunk_configuration
	_chunk_manager = NodeCreationHelper.get_or_create_node(
		_parent_node, 
		"ChunkManager",
		ChunkManager
	) as ChunkManager
	_chunk_manager.enable()
	_chunk_manager.generate_collision = _terrain_configuration.generate_collision
	_chunk_manager.collision_layers = _terrain_configuration.collision_layers
	_chunk_manager.full_collision_distance = chunk_config.collision_distance
	_chunk_manager.debug_mode = false
	_chunk_manager.chunk_data_source = chunked_data
	_chunk_manager.load_strategy = chunk_config.get_strategy()
	_chunk_manager.load_all_chunks()
