extends GutTest

var _service: ChunkGenerationService
var _definition: TerrainDefinition
var _received_chunk: ChunkMeshData = null

func before_each() -> void:
	_received_chunk = null
	var heightmap := Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(0.5, 0, 0, 1))
	var source := ImageHeightmapSource.new()
	source.heightmap = heightmap
	_definition = TerrainDefinition.create(source, Vector2(256, 256), 64.0, 12345)
	_service = ChunkGenerationService.new(_definition, 32, 50.0)

func after_each() -> void:
	_service = null
	_definition = null
	_received_chunk = null

func _on_chunk_generated(_coord: Vector2i, _lod: int, chunk: ChunkMeshData) -> void:
	_received_chunk = chunk

func test_get_or_generate_chunk_returns_chunk() -> void:
	var chunk := _service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_not_null(chunk, "Should generate chunk")
	assert_eq(chunk.chunk_coord, Vector2i(0, 0))

func test_get_or_generate_chunk_caches_result() -> void:
	_service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_true(_service.has_cached_chunk(Vector2i(0, 0), 0))

func test_request_chunk_async_without_threading() -> void:
	_service.set_use_threading(false)
	var received_chunk: ChunkMeshData = null
	_service.chunk_generated.connect(func(coord, lod, chunk):
		received_chunk = chunk
	)
	_service.request_chunk_async(Vector2i(1, 1), Vector2(64, 64), 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(received_chunk, "Should receive chunk via signal")

func test_request_chunk_async_with_threading() -> void:
	_service.set_use_threading(true)
	var received_chunk: ChunkMeshData = null
	_service.chunk_generated.connect(func(coord, lod, chunk):
		received_chunk = chunk
	)
	_service.request_chunk_async(Vector2i(2, 2), Vector2(64, 64), 0)
	await get_tree().create_timer(1.0).timeout
	assert_not_null(received_chunk, "Should receive chunk via signal with threading")

func test_cancel_request_stops_generation() -> void:
	_service.set_use_threading(true)
	_service.request_chunk_async(Vector2i(3, 3), Vector2(64, 64), 0, 100.0)
	_service.cancel_request(Vector2i(3, 3), 0)
	assert_false(_service.has_pending_request(Vector2i(3, 3), 0))

func test_cancel_all_pending_requests() -> void:
	_service.set_use_threading(true)
	for i in range(5):
		_service.request_chunk_async(Vector2i(i, 0), Vector2(64, 64), 0, float(i))
	_service.cancel_all_pending_requests()
	assert_eq(_service.get_pending_request_count(), 0)

func test_clear_cache_removes_cached_chunks() -> void:
	_service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	assert_true(_service.has_cached_chunk(Vector2i(0, 0), 0))
	_service.clear_cache()
	assert_false(_service.has_cached_chunk(Vector2i(0, 0), 0))

func test_invalidate_chunk_removes_specific_chunk() -> void:
	_service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	_service.get_or_generate_chunk(Vector2i(1, 0), Vector2(64, 64), 0)
	_service.invalidate_chunk(Vector2i(0, 0), 0)
	assert_false(_service.has_cached_chunk(Vector2i(0, 0), 0))
	assert_true(_service.has_cached_chunk(Vector2i(1, 0), 0))

func test_set_terrain_definition_clears_cache() -> void:
	_service.get_or_generate_chunk(Vector2i(0, 0), Vector2(64, 64), 0)
	var new_def := TerrainDefinition.create(_definition.heightmap_source, Vector2(128, 128), 32.0, 999)
	_service.set_terrain_definition(new_def)
	assert_false(_service.has_cached_chunk(Vector2i(0, 0), 0))

func test_is_threading_enabled_returns_correct_state() -> void:
	assert_false(_service.is_threading_enabled())
	_service.set_use_threading(true)
	assert_true(_service.is_threading_enabled())

func test_get_cache_stats_returns_dictionary() -> void:
	var stats := _service.get_cache_stats()
	assert_has(stats, "cached_chunks")
	assert_has(stats, "memory_usage_mb")
	assert_has(stats, "max_size_mb")

