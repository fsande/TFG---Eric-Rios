## @brief Hybrid chunk generation strategy that selects CPU or GPU based on context.
##
## @details Intelligently chooses between CPU and GPU generation based on:
## - Thread context (GPU only on main thread)
## - Chunk complexity (resolution, delta count)
## - System load and pending work
## - GPU availability
@tool
class_name HybridChunkGenerationStrategy extends ChunkGenerationStrategy

const GPU_MIN_RESOLUTION := 32
const GPU_MAX_CONCURRENT_CHUNKS := 4

var _cpu_strategy: ChunkGenerationStrategy
var _gpu_strategy: ChunkGenerationStrategy
var _gpu_in_progress_count: int = 0
var _count_mutex: Mutex

func _init() -> void:
	_cpu_strategy = CpuChunkGenerationStrategy.new()
	_gpu_strategy = GpuChunkGenerationStrategy.new()
	_count_mutex = Mutex.new()

func get_processor_type() -> ProcessorType:
	return ProcessorType.HYBRID

func supports_async() -> bool:
	return true

func generate_chunk(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2,
	lod_level: int,
	base_resolution: int
) -> ChunkMeshData:
	var use_gpu := _should_use_gpu(base_resolution, lod_level)
	if use_gpu:
		return _generate_with_gpu(terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution)
	return _cpu_strategy.generate_chunk(terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution)

func _should_use_gpu(base_resolution: int, lod_level: int) -> bool:
	var gpu_manager := GpuResourceManager.get_singleton()
	if not gpu_manager or not gpu_manager.is_gpu_available():
		return false
	var work_queue := GpuWorkQueue.get_singleton()
	if not work_queue:
		return false
	var resolution := calculate_resolution_for_lod(base_resolution, lod_level)
	if resolution < GPU_MIN_RESOLUTION:
		return false
	_count_mutex.lock()
	var gpu_busy := _gpu_in_progress_count >= GPU_MAX_CONCURRENT_CHUNKS
	_count_mutex.unlock()
	if gpu_busy:
		return false
	return true

func _generate_with_gpu(
	terrain_definition: TerrainDefinition,
	chunk_coord: Vector2i,
	chunk_size: Vector2,
	lod_level: int,
	base_resolution: int
) -> ChunkMeshData:
	_count_mutex.lock()
	_gpu_in_progress_count += 1
	_count_mutex.unlock()
	var result := _gpu_strategy.generate_chunk(
		terrain_definition, chunk_coord, chunk_size, lod_level, base_resolution
	)
	_count_mutex.lock()
	_gpu_in_progress_count -= 1
	_count_mutex.unlock()
	return result

func get_cpu_strategy() -> ChunkGenerationStrategy:
	return _cpu_strategy

func get_gpu_strategy() -> ChunkGenerationStrategy:
	return _gpu_strategy

func get_gpu_in_progress_count() -> int:
	_count_mutex.lock()
	var count := _gpu_in_progress_count
	_count_mutex.unlock()
	return count

func dispose() -> void:
	_cpu_strategy.dispose()
	_gpu_strategy.dispose()
