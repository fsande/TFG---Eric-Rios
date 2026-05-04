class_name ChunkRequestQueue extends RefCounted

signal chunk_completed(coord: Vector2i, lod: int, chunk: ChunkMeshData)
signal chunk_failed(coord: Vector2i, lod: int, error: String)

var _pending_requests: Dictionary[String, ChunkRequest] = {}
var _request_mutex: Mutex = Mutex.new()
var _max_concurrent_requests: int = 16
var _cache: ChunkCache = null
var _generator_pool: Array[ChunkGenerator] = []

var _threads: Array[Thread] = []
var _work_semaphore: Semaphore = Semaphore.new()
var _shutdown: bool = false

func _init(generator: ChunkGenerator, cache: ChunkCache, max_concurrent: int) -> void:
	_cache = cache
	_max_concurrent_requests = max_concurrent
	for i in max_concurrent:
		_generator_pool.append(generator.duplicate())
		var thread := Thread.new()
		_threads.append(thread)
		thread.start(_worker_loop.bind(i))

func request_chunk(coord: Vector2i, chunk_size: Vector2, lod_level: int, collision_lod: int, required_lod_for_collision: int, priority: float = 0.0) -> void:
	_request_mutex.lock()
	var key := _make_key(coord, lod_level)
	if _pending_requests.has(key):
		var existing: ChunkRequest = _pending_requests[key]
		if existing.is_active():
			existing.priority = minf(existing.priority, priority)
			_request_mutex.unlock()
			return
	var request := ChunkRequest.new(coord, chunk_size, lod_level, collision_lod, required_lod_for_collision, priority)
	_pending_requests[key] = request
	_request_mutex.unlock()
	_work_semaphore.post()

func _worker_loop(slot: int) -> void:
	var generator := _generator_pool[slot]
	while true:
		_work_semaphore.wait()
		if _shutdown:
			return
		_request_mutex.lock()
		var request := _get_highest_priority_pending()
		if request == null:
			_request_mutex.unlock()
			continue
		request.mark_in_progress(-1)
		_request_mutex.unlock()
		_process_request(request, generator)

func _get_highest_priority_pending() -> ChunkRequest:
	var best_request: ChunkRequest = null
	var best_priority := INF
	for key in _pending_requests.keys():
		var request: ChunkRequest = _pending_requests[key]
		if request.is_pending() and request.priority < best_priority:
			best_priority = request.priority
			best_request = request
	return best_request

func _process_request(request: ChunkRequest, generator: ChunkGenerator) -> void:
	if _cache.has_chunk_with_lod(request.coord, request.lod_level):
		_complete(request, _cache.get_chunk(request.coord), "")
		return
	var chunk := generator.update_or_generate_chunk(
		request.coord, request.chunk_size, request.lod_level, _cache
	)
	if request.lod_level <= request.required_lod_for_collision:
		generator.update_or_generate_chunk(
			request.coord, request.chunk_size, request.generated_collision_lod, _cache
		)
	if chunk:
		_complete(request, chunk, "")
	else:
		_complete(request, null, "Chunk generation failed")

func _complete(request: ChunkRequest, chunk: ChunkMeshData, error: String) -> void:
	_request_mutex.lock()
	var key := request.get_key()
	var cancelled := request.state == ChunkRequest.RequestState.CANCELLED
	_pending_requests.erase(key)
	_request_mutex.unlock()
	if cancelled:
		return
	if chunk:
		request.mark_completed()
		chunk_completed.emit.call_deferred(request.coord, request.lod_level, chunk)
	else:
		request.mark_failed()
		chunk_failed.emit.call_deferred(request.coord, request.lod_level, error)

func cancel_request(coord: Vector2i, lod: int) -> void:
	_request_mutex.lock()
	var key := _make_key(coord, lod)
	if _pending_requests.has(key) and _pending_requests[key].is_pending():
		_pending_requests[key].mark_cancelled()
		_pending_requests.erase(key)
	_request_mutex.unlock()

func cancel_all_pending() -> void:
	_request_mutex.lock()
	for key in _pending_requests.keys():
		if _pending_requests[key].is_pending():
			_pending_requests[key].mark_cancelled()
	_pending_requests.clear()
	_request_mutex.unlock()

func cancel_all() -> void:
	_request_mutex.lock()
	for key in _pending_requests.keys():
		_pending_requests[key].mark_cancelled()
	_pending_requests.clear()
	_request_mutex.unlock()
	for i in _threads.size():
		_work_semaphore.post()

func shutdown() -> void:
	_shutdown = true
	for i in _threads.size():
		_work_semaphore.post() 
	for thread in _threads:
		thread.wait_to_finish()
	_threads.clear()

func update_priority(coord: Vector2i, lod: int, new_priority: float) -> void:
	_request_mutex.lock()
	var key := _make_key(coord, lod)
	if _pending_requests.has(key) and _pending_requests[key].is_pending():
		_pending_requests[key].priority = new_priority
	_request_mutex.unlock()

func has_pending_request(coord: Vector2i, lod: int) -> bool:
	_request_mutex.lock()
	var key := _make_key(coord, lod)
	var result := _pending_requests.has(key) and _pending_requests[key].is_active()
	_request_mutex.unlock()
	return result

func get_pending_request_count() -> int:
	_request_mutex.lock()
	var count := 0
	for key in _pending_requests:
		if _pending_requests[key].is_pending():
			count += 1
	_request_mutex.unlock()
	return count

func get_active_request_count() -> int:
	_request_mutex.lock()
	var count := 0
	for key in _pending_requests:
		if _pending_requests[key].is_in_progress():
			count += 1
	_request_mutex.unlock()
	return count

func _make_key(coord: Vector2i, lod: int) -> String:
	return "%d,%d,%d" % [coord.x, coord.y, lod]
