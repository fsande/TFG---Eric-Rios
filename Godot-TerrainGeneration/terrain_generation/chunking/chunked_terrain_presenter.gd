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
	_chunk_manager.load_strategy = _create_load_strategy(chunk_config)
	_chunk_manager.load_all_chunks()

## Create and configure chunk loading strategy from configuration
func _create_load_strategy(chunk_config: ChunkConfiguration) -> ChunkLoadStrategy:
	if not chunk_config or not chunk_config.load_strategy_config:
		return _create_default_strategy()
	var strategy_config := chunk_config.load_strategy_config
	var strategy_type := strategy_config.get_strategy_type()
	match strategy_type:
		"Grid":
			return _create_grid_strategy(strategy_config)
		"FrustumCulling":
			return _create_frustum_strategy(strategy_config)
		"QuadTree":
			return _create_quadtree_strategy(strategy_config)
		_:
			push_warning("ChunkedTerrainPresenter: Unknown strategy type '%s', using Grid" % strategy_type)
			return _create_default_strategy()

## Create grid-based load strategy
func _create_grid_strategy(config: ChunkLoadStrategyConfiguration) -> GridLoadStrategy:
	var strategy := GridLoadStrategy.new()
	return strategy

## Create frustum culling load strategy
func _create_frustum_strategy(config: ChunkLoadStrategyConfiguration) -> FrustumCullingLoadStrategy:
	var strategy := FrustumCullingLoadStrategy.new()
	return strategy

## Create quadtree load strategy
func _create_quadtree_strategy(_config: ChunkLoadStrategyConfiguration) -> QuadTreeLoadStrategy:
	return QuadTreeLoadStrategy.new()

## Create default strategy (Grid)
func _create_default_strategy() -> GridLoadStrategy:
	return GridLoadStrategy.new()

## Cleanup chunk manager
func cleanup() -> void:
	if _chunk_manager:
		_chunk_manager.queue_free()
		_chunk_manager = null

## Get chunk manager reference (for debugging/stats)
func get_chunk_manager() -> ChunkManager:
	return _chunk_manager

