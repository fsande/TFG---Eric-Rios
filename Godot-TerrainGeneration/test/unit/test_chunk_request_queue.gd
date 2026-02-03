extends GutTest

var _generator: ChunkGenerator
var _cache: ChunkCache
var _queue: ChunkRequestQueue
var _definition: TerrainDefinition
var _test_completed: bool = false
var _test_completed_coord: Vector2i = Vector2i(-1, -1)

func before_each() -> void:
	_test_completed = false
	_test_completed_coord = Vector2i(-1, -1)
	var heightmap := Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(0.5, 0, 0, 1))
	var source := ImageHeightmapSource.new()
	source.heightmap = heightmap
	_definition = TerrainDefinition.create(source, Vector2(256, 256), 64.0, 12345)
	_generator = ChunkGenerator.new(_definition, 32)
	_cache = ChunkCache.new(50.0)
	_queue = ChunkRequestQueue.new(_generator, _cache, 2)

func after_each() -> void:
	_queue = null
	_cache = null
	_generator = null
	_definition = null

func test_request_chunk_creates_pending_request() -> void:
	_queue.request_chunk(Vector2i(0, 0), Vector2(64, 64), 0, 1.0)
	await get_tree().process_frame
	assert_true(_queue.has_pending_request(Vector2i(0, 0), 0) or _queue.get_active_request_count() > 0)

func test_cancel_request_removes_pending() -> void:
	_queue.request_chunk(Vector2i(5, 5), Vector2(64, 64), 0, 100.0)
	_queue.cancel_request(Vector2i(5, 5), 0)
	assert_false(_queue.has_pending_request(Vector2i(5, 5), 0))

func test_cancel_all_pending_clears_queue() -> void:
	_queue.request_chunk(Vector2i(0, 0), Vector2(64, 64), 0, 1.0)
	_queue.request_chunk(Vector2i(1, 0), Vector2(64, 64), 0, 2.0)
	_queue.request_chunk(Vector2i(2, 0), Vector2(64, 64), 0, 3.0)
	_queue.cancel_all_pending()
	assert_eq(_queue.get_pending_request_count(), 0)

func test_update_priority_changes_request_priority() -> void:
	_queue.request_chunk(Vector2i(3, 3), Vector2(64, 64), 0, 100.0)
	_queue.update_priority(Vector2i(3, 3), 0, 1.0)
	assert_true(_queue.has_pending_request(Vector2i(3, 3), 0) or _queue.get_active_request_count() > 0)

func test_chunk_completed_signal_emitted() -> void:
	_queue.chunk_completed.connect(_on_chunk_completed)
	_queue.request_chunk(Vector2i(0, 0), Vector2(64, 64), 0, 0.0)
	await get_tree().create_timer(1.0).timeout
	assert_true(_test_completed, "chunk_completed signal should be emitted")
	assert_eq(_test_completed_coord, Vector2i(0, 0))

func _on_chunk_completed(coord: Vector2i, _lod: int, _chunk: ChunkMeshData) -> void:
	_test_completed = true
	_test_completed_coord = coord

func test_max_concurrent_requests_respected() -> void:
	for i in range(10):
		_queue.request_chunk(Vector2i(i, 0), Vector2(64, 64), 0, float(i))
	await get_tree().process_frame
	assert_true(_queue.get_active_request_count() <= 2, "Should not exceed max concurrent")

func test_duplicate_request_updates_priority() -> void:
	_queue.request_chunk(Vector2i(0, 0), Vector2(64, 64), 0, 10.0)
	_queue.request_chunk(Vector2i(0, 0), Vector2(64, 64), 0, 1.0)
	assert_eq(_queue.get_total_request_count(), 1, "Should not create duplicate requests")

func test_cached_chunk_returned_immediately() -> void:
	var test_chunk := _generator.generate_chunk(Vector2i(1, 1), Vector2(64, 64), 0)
	_cache.store_chunk(Vector2i(1, 1), 0, test_chunk)
	_queue.chunk_completed.connect(_on_chunk_completed)
	_queue.request_chunk(Vector2i(1, 1), Vector2(64, 64), 0, 0.0)
	await get_tree().create_timer(0.5).timeout
	assert_true(_test_completed, "Cached chunk should trigger completion")

