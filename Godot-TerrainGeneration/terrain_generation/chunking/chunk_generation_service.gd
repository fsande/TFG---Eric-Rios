## @brief Service that manages chunk generation with caching and async support.
##
## @details Provides a high-level interface for generating chunks from
## a TerrainDefinition, with LRU caching and optional multithreaded generation.
## GPU generation is ALWAYS synchronous (main thread only).
## CPU generation supports async (multithreaded via WorkerThreadPool).
##
## Threading is opt-in. Call set_use_threading(true) before using.
class_name ChunkGenerationService extends RefCounted

signal chunk_generated(coord: Vector2i, lod: int, chunk: ChunkMeshData)
signal generation_failed(coord: Vector2i, lod: int, error: String)

var _terrain_definition: TerrainDefinition
var _terrain_configuration: TerrainConfiguration
var _generator: ChunkGenerator
var _cache: ChunkCache
var _request_queue: ChunkRequestQueue
var _base_resolution: int = 64
var _use_threading: bool = false
var _max_concurrent_requests: int = 4
var _use_gpu: bool = false

func _init(terrain_def: TerrainDefinition, terrain_config: TerrainConfiguration) -> void:
	_terrain_definition = terrain_def
	_terrain_configuration = terrain_config
	_base_resolution = terrain_config.base_chunk_resolution
	_use_gpu = terrain_config.use_gpu_mesh_generation
	_generator = ChunkGenerator.new(terrain_def, _base_resolution, _use_gpu)
	_cache = ChunkCache.new(terrain_config.cache_size_mb)
	if _use_gpu:
		push_warning("ChunkGenerationService: GPU mode — async loading disabled (GPU requires main thread)")
	else:
		_request_queue = _make_queue()

func get_or_generate_chunk(coord: Vector2i, chunk_size: Vector2, lod_level: int = 0) -> ChunkMeshData:
	if _cache.has_chunk_with_lod(coord, lod_level):
		return _cache.get_chunk(coord)
	var chunk := _generator.update_or_generate_chunk(coord, chunk_size, lod_level, _cache)
	if chunk:
		chunk_generated.emit(coord, lod_level, chunk)
	else:
		generation_failed.emit(coord, lod_level, "Generation failed")
	return chunk

func request_chunk_async(coord: Vector2i, chunk_size: Vector2, lod_level: int = 0, priority: float = 0.0) -> void:
	if _use_gpu or not _use_threading:
		if not _use_gpu:
			push_warning(
				"ChunkGenerationService.request_chunk_async: threading is disabled. " +
				"falling back to synchronous generation. Call set_use_threading(true) to enable async."
			)
		if _use_threading:
			push_warning(
				"ChunkGenerationService.request_chunk_async: threading is incompatible with GPU mode. " +
				"falling back to synchronous generation with GPU. Call set_use_threading(false) to disable async."
			)
		var chunk := get_or_generate_chunk(coord, chunk_size, lod_level)
		if chunk:
			chunk_generated.emit.call_deferred(coord, lod_level, chunk)
		else:
			generation_failed.emit.call_deferred(coord, lod_level, "GPU generation failed")
		return
	if _cache.has_chunk_with_lod(coord, lod_level):
		chunk_generated.emit.call_deferred(coord, lod_level, _cache.get_chunk(coord))
		return
	_request_queue.request_chunk(coord, chunk_size, lod_level, priority)

func cancel_request(coord: Vector2i, lod_level: int) -> void:
	if _request_queue:
		_request_queue.cancel_request(coord, lod_level)

func cancel_all_pending_requests() -> void:
	if _request_queue:
		_request_queue.cancel_all_pending()

func update_request_priority(coord: Vector2i, lod_level: int, new_priority: float) -> void:
	if _request_queue:
		_request_queue.update_priority(coord, lod_level, new_priority)

func has_pending_request(coord: Vector2i, lod_level: int) -> bool:
	if _request_queue:
		return _request_queue.has_pending_request(coord, lod_level)
	return false

func set_terrain_definition(terrain_def: TerrainDefinition) -> void:
	_terrain_definition = terrain_def
	_generator = ChunkGenerator.new(terrain_def, _base_resolution, _use_gpu)
	_cache.clear()
	if not _use_gpu:
		_replace_queue()

func set_use_threading(enabled: bool) -> void:
	if enabled and _use_gpu:
		push_error("ChunkGenerationService: cannot enable threading in GPU mode (GPU requires main thread)")
		return
	_use_threading = enabled
	_replace_queue()

func set_max_concurrent_requests(count: int) -> void:
	_max_concurrent_requests = maxi(1, count)
	if not _use_gpu and _request_queue:
		_replace_queue()

func invalidate_chunk(coord: Vector2i) -> void:
	_cache.invalidate_chunk(coord)

func invalidate_all_lods(coord: Vector2i) -> void:
	_cache.invalidate_coord(coord)

func invalidate_region(bounds: AABB) -> void:
	_cache.invalidate_region(bounds)

func clear_cache() -> void:
	_cache.clear()

func get_cache_stats() -> Dictionary:
	return _cache.get_stats()

func get_pending_request_count() -> int:
	if _request_queue:
		return _request_queue.get_pending_request_count()
	return 0

func get_active_request_count() -> int:
	if _request_queue:
		return _request_queue.get_active_request_count()
	return 0

func get_generator() -> ChunkGenerator:
	return _generator

func get_cache() -> ChunkCache:
	return _cache

func _make_queue() -> ChunkRequestQueue:
	var queue := ChunkRequestQueue.new(_generator, _cache, _max_concurrent_requests)
	queue.chunk_completed.connect(_on_queue_chunk_completed, ConnectFlags.CONNECT_DEFERRED)
	queue.chunk_failed.connect(_on_queue_chunk_failed, ConnectFlags.CONNECT_DEFERRED)
	return queue

## Cancels all requests on the current queue. Safe to call at any time.
func _replace_queue() -> void:
	if _request_queue:
		_request_queue.shutdown()
	_request_queue = _make_queue()

func _on_queue_chunk_completed(coord: Vector2i, lod: int, chunk: ChunkMeshData) -> void:
	chunk_generated.emit(coord, lod, chunk)

func _on_queue_chunk_failed(coord: Vector2i, lod: int, error: String) -> void:
	generation_failed.emit(coord, lod, error)
