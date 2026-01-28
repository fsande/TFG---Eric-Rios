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
	var chunks := MeshPartitioner.partition_mesh(terrain_data.mesh_result, chunk_config.chunk_size)
	var chunked_data := ChunkedTerrainData.new()
	for chunk in chunks:
		chunked_data.add_chunk(chunk)
	chunked_data.terrain_data = terrain_data
	chunked_data.chunk_size = chunk_config.chunk_size
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
	for chunk_coord in _chunk_manager.loaded_chunks:
		var mesh_instance: MeshInstance3D = _chunk_manager.loaded_chunks[chunk_coord]
		if mesh_instance:
			mesh_instance.material_override = material

## Setup or update the chunk manager with new data
func _setup_or_update_chunk_manager(chunked_data: ChunkedTerrainData) -> void:
	var chunk_config := _terrain_configuration.chunk_configuration
	_chunk_manager = NodeCreationHelper.get_or_create_node(
		_parent_node, 
		"ChunkManager",
		ChunkManager
	) as ChunkManager
	_chunk_manager.generate_collision = _terrain_configuration.generate_collision
	_chunk_manager.collision_layers = _terrain_configuration.collision_layers
	_chunk_manager.full_collision_distance = chunk_config.collision_distance
	_chunk_manager.debug_mode = false
	_chunk_manager.chunk_data_source = chunked_data
	_chunk_manager.load_strategy = chunk_config.get_strategy()
	_chunk_manager.load_all_chunks()

## Cleanup chunk manager
func cleanup() -> void:
	if _chunk_manager:
		_chunk_manager.queue_free()
		_chunk_manager = null

## Get chunk manager reference (for debugging/stats)
func get_chunk_manager() -> ChunkManager:
	return _chunk_manager
