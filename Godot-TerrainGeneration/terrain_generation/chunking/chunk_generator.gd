## @brief Generates terrain chunks from TerrainDefinition at any resolution.
##
## @details Creates chunk meshes on-demand by sampling the heightmap and
## applying height deltas and volume operations at LOD-appropriate resolution.
## Uses the Strategy pattern to support CPU, GPU, or hybrid generation.
class_name ChunkGenerator extends RefCounted

const MIN_RESOLUTION := 4
const MAX_RESOLUTION := 256

var _terrain_definition: TerrainDefinition
var _base_resolution: int = 64
var _generation_strategy: ChunkGenerationStrategy

func _init(terrain_def: TerrainDefinition, base_resolution: int, use_gpu: bool) -> void:
	_terrain_definition = terrain_def
	_base_resolution = clampi(base_resolution, MIN_RESOLUTION, MAX_RESOLUTION)
	if use_gpu:
		_generation_strategy = GpuChunkGenerationStrategy.new()
	else:
		_generation_strategy = CpuChunkGenerationStrategy.new()

func generate_chunk(chunk_coord: Vector2i, chunk_size: Vector2, lod_level: int = 0) -> ChunkMeshData:
	if not _terrain_definition or not _terrain_definition.is_valid():
		push_error("ChunkGenerator: Invalid terrain definition")
		return null
	return _generation_strategy.generate_chunk(
		_terrain_definition, chunk_coord, chunk_size, lod_level, _base_resolution
	)
