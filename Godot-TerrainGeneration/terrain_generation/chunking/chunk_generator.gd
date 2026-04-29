## @brief Generates terrain chunks from TerrainDefinition at any resolution.
##
## @details Creates chunk meshes on-demand by sampling the heightmap and
## applying height deltas and volume operations at LOD-appropriate resolution.
## Supports two strategies: CPU (async/multithreaded) or GPU (sync/main thread only).
class_name ChunkGenerator extends RefCounted

const MIN_RESOLUTION := 4
const MAX_RESOLUTION := 256

var _terrain_definition: TerrainDefinition
var _base_resolution: int = 64
var _generation_strategy: ChunkGenerationStrategy

func _init(terrain_def: TerrainDefinition, base_resolution: int, use_gpu: bool) -> void:
	_terrain_definition = terrain_def
	_base_resolution = clampi(base_resolution, MIN_RESOLUTION, MAX_RESOLUTION)
	var heightmap := terrain_def.get_base_heightmap()
	if use_gpu:
		_generation_strategy = GpuChunkGenerationStrategy.new(heightmap)
	else:
		_generation_strategy = CpuChunkGenerationStrategy.new(heightmap)

func update_or_generate_chunk(coord: Vector2i, chunk_size: Vector2, lod_level: int, cache: ChunkCache = null) -> ChunkMeshData:
	if not _terrain_definition or not _terrain_definition.is_valid():
		push_error("ChunkGenerator: Invalid terrain definition")
		return null
	if cache and cache.has_chunk_with_lod(coord, lod_level):
		return cache.get_chunk(coord)
	var chunk_bounds = _calculate_chunk_bounds(_terrain_definition, coord, chunk_size)
	var resolution = _generation_strategy.calculate_resolution_for_lod(_base_resolution, lod_level)
	var height_grid := _generation_strategy.generate_height_grid(
		_terrain_definition, chunk_bounds, resolution, 
	)
	#OS.delay_msec(25)
	#return ChunkMeshData.new(coord, Vector3(0,0, 0), chunk_size, MeshData.create(PackedVector3Array()), lod_level)
	var mesh_data = _generation_strategy.generate_chunk(
		_terrain_definition, chunk_bounds, lod_level, resolution, height_grid
	)
	var cached := cache.get_chunk(coord) if cache else null
	if cached:
		cached.add_lod_mesh(mesh_data, lod_level)
		return cached
	var world_center := Vector3(
		chunk_bounds.position.x + chunk_bounds.size.x / 2.0,
		0,
		chunk_bounds.position.z + chunk_bounds.size.z / 2.0
	)
	var chunk_mesh_data = ChunkMeshData.new(coord, world_center, chunk_size, mesh_data, lod_level)
	if cache:
		cache.store_chunk(coord, chunk_mesh_data)
	return chunk_mesh_data

func duplicate() -> ChunkGenerator:
	return ChunkGenerator.new(_terrain_definition, _base_resolution,
		_generation_strategy.get_processor_type() == ChunkGenerationStrategy.ProcessorType.GPU)

func _calculate_chunk_bounds(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2
) -> AABB:
	var terrain_size := terrain_definition.terrain_size
	var half_terrain := terrain_size / 2.0
	var chunk_origin := Vector3(
		chunk_coord.x * chunk_size.x - half_terrain.x,
		0,
		chunk_coord.y * chunk_size.y - half_terrain.y
	)
	var height_range := terrain_definition.height_scale * 2.0
	return AABB(
		Vector3(chunk_origin.x, -height_range, chunk_origin.z),
		Vector3(chunk_size.x, height_range * 2.0, chunk_size.y)
	)

## Get the underlying generation strategy (CPU or GPU).
## Used by benchmarks to connect to substep_completed signals.
func get_strategy() -> ChunkGenerationStrategy:
	return _generation_strategy
