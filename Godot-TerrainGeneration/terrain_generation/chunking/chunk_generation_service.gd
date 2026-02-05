## @brief Service that manages chunk generation with caching and async support.
##
## @details Provides a high-level interface for generating chunks from
## a TerrainDefinition, with LRU caching and multithreaded background generation.
class_name ChunkGenerationService extends RefCounted

signal chunk_generated(coord: Vector2i, lod: int, chunk: ChunkMeshData)
signal generation_failed(coord: Vector2i, lod: int, error: String)

var _terrain_definition: TerrainDefinition
var _generator: ChunkGenerator
var _cache: ChunkCache
var _request_queue: ChunkRequestQueue
var _base_resolution: int = 64
var _use_threading: bool = false
var _max_concurrent_requests: int = 4
var _use_gpu: bool = false

func _init(terrain_def: TerrainDefinition, base_resolution: int = 64, cache_size_mb: float = 200.0, use_gpu: bool = false) -> void:
	_terrain_definition = terrain_def
	_base_resolution = base_resolution
	_use_gpu = use_gpu
	_generator = ChunkGenerator.new(terrain_def, base_resolution, _use_gpu)
	_cache = ChunkCache.new(cache_size_mb)
	_request_queue = ChunkRequestQueue.new(_generator, _cache, _max_concurrent_requests)
	_request_queue.chunk_completed.connect(_on_queue_chunk_completed, ConnectFlags.CONNECT_DEFERRED)
	_request_queue.chunk_failed.connect(_on_queue_chunk_failed, ConnectFlags.CONNECT_DEFERRED)

func get_or_generate_chunk(coord: Vector2i, chunk_size: Vector2, lod_level: int = 0) -> ChunkMeshData:
	var cached := _cache.get_chunk(coord, lod_level)
	if cached:
		return cached
	var chunk := _generator.generate_chunk(coord, chunk_size, lod_level)
	if chunk:
		_cache.store_chunk(coord, lod_level, chunk)
		chunk_generated.emit(coord, lod_level, chunk)
	else:
		generation_failed.emit(coord, lod_level, "Generation failed")
	return chunk

func request_chunk_async(coord: Vector2i, chunk_size: Vector2, lod_level: int = 0, priority: float = 0.0) -> void:
	if not _use_threading:
		var chunk := get_or_generate_chunk(coord, chunk_size, lod_level)
		if chunk:
			chunk_generated.emit.call_deferred(coord, lod_level, chunk)
		else:
			generation_failed.emit.call_deferred(coord, lod_level, "Generation failed")
		return
	var cached := _cache.get_chunk(coord, lod_level)
	if cached:
		chunk_generated.emit.call_deferred(coord, lod_level, cached)
		return
	_request_queue.request_chunk(coord, chunk_size, lod_level, priority)

func cancel_request(coord: Vector2i, lod_level: int) -> void:
	_request_queue.cancel_request(coord, lod_level)

func cancel_all_pending_requests() -> void:
	_request_queue.cancel_all_pending()

func update_request_priority(coord: Vector2i, lod_level: int, new_priority: float) -> void:
	_request_queue.update_priority(coord, lod_level, new_priority)

func has_pending_request(coord: Vector2i, lod_level: int) -> bool:
	return _request_queue.has_pending_request(coord, lod_level)

func _on_queue_chunk_completed(coord: Vector2i, lod: int, chunk: ChunkMeshData) -> void:
	chunk_generated.emit(coord, lod, chunk)

func _on_queue_chunk_failed(coord: Vector2i, lod: int, error: String) -> void:
	generation_failed.emit(coord, lod, error)

func has_cached_chunk(coord: Vector2i, lod_level: int) -> bool:
	return _cache.has_chunk(coord, lod_level)

func invalidate_chunk(coord: Vector2i, lod_level: int) -> void:
	_cache.invalidate_chunk(coord, lod_level)

func invalidate_all_lods(coord: Vector2i) -> void:
	_cache.invalidate_coord(coord)

func invalidate_region(bounds: AABB) -> void:
	_cache.invalidate_region(bounds)

func clear_cache() -> void:
	_cache.clear()

func get_cache_stats() -> Dictionary:
	return _cache.get_stats()

func set_terrain_definition(terrain_def: TerrainDefinition) -> void:
	_terrain_definition = terrain_def
	_generator = ChunkGenerator.new(terrain_def, _base_resolution, _use_gpu)
	_cache.clear()
	_request_queue.cancel_all_pending()
	_request_queue = ChunkRequestQueue.new(_generator, _cache, _max_concurrent_requests)
	_request_queue.chunk_completed.connect(_on_queue_chunk_completed, ConnectFlags.CONNECT_DEFERRED)
	_request_queue.chunk_failed.connect(_on_queue_chunk_failed, ConnectFlags.CONNECT_DEFERRED)

func set_use_threading(enabled: bool) -> void:
	_use_threading = enabled

func set_max_concurrent_requests(count: int) -> void:
	_max_concurrent_requests = maxi(1, count)
	_request_queue = ChunkRequestQueue.new(_generator, _cache, _max_concurrent_requests)
	_request_queue.chunk_completed.connect(_on_queue_chunk_completed, ConnectFlags.CONNECT_DEFERRED)
	_request_queue.chunk_failed.connect(_on_queue_chunk_failed, ConnectFlags.CONNECT_DEFERRED)

func is_threading_enabled() -> bool:
	return _use_threading

func get_pending_request_count() -> int:
	return _request_queue.get_pending_request_count()

func get_active_request_count() -> int:
	return _request_queue.get_active_request_count()

func get_generator() -> ChunkGenerator:
	return _generator

func get_cache() -> ChunkCache:
	return _cache
