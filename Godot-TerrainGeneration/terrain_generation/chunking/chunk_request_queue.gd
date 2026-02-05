## @brief Thread-safe priority queue for chunk generation requests.
##
## @details Manages async chunk generation requests with priority ordering,
## cancellation support, and concurrent task limiting.
class_name ChunkRequestQueue extends RefCounted

signal chunk_completed(coord: Vector2i, lod: int, chunk: ChunkMeshData)
signal chunk_failed(coord: Vector2i, lod: int, error: String)

var _pending_requests: Dictionary[String, ChunkRequest] = {}
var _request_mutex: Mutex = Mutex.new()
var _max_concurrent_requests: int = 16
var _active_request_count: int = 0
var _generator: ChunkGenerator = null
var _cache: ChunkCache = null
var _is_processing: bool = false

func _init(generator: ChunkGenerator, cache: ChunkCache, max_concurrent: int) -> void:
	_generator = generator
	_cache = cache
	_max_concurrent_requests = max_concurrent

func request_chunk(coord: Vector2i, chunk_size: Vector2, lod_level: int, priority: float = 0.0) -> void:
	_request_mutex.lock()
	var key := _make_key(coord, lod_level)
	if _pending_requests.has(key):
		var existing: ChunkRequest = _pending_requests[key]
		if existing.is_active():
			existing.priority = minf(existing.priority, priority)
			_request_mutex.unlock()
			return
	var request := ChunkRequest.new(coord, chunk_size, lod_level, priority)
	_pending_requests[key] = request
	_request_mutex.unlock()
	_try_process_next()

func cancel_request(coord: Vector2i, lod: int) -> void:
	_request_mutex.lock()
	var key := _make_key(coord, lod)
	if _pending_requests.has(key):
		var request: ChunkRequest = _pending_requests[key]
		if request.is_pending():
			request.mark_cancelled()
			_pending_requests.erase(key)
	_request_mutex.unlock()

func cancel_all_pending() -> void:
	_request_mutex.lock()
	var keys_to_remove: Array[String] = []
	for key in _pending_requests.keys():
		var request: ChunkRequest = _pending_requests[key]
		if request.is_pending():
			request.mark_cancelled()
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_pending_requests.erase(key)
	_request_mutex.unlock()

func update_priority(coord: Vector2i, lod: int, new_priority: float) -> void:
	_request_mutex.lock()
	var key := _make_key(coord, lod)
	if _pending_requests.has(key):
		var request: ChunkRequest = _pending_requests[key]
		if request.is_pending():
			request.priority = new_priority
	_request_mutex.unlock()

func has_pending_request(coord: Vector2i, lod: int) -> bool:
	_request_mutex.lock()
	var key := _make_key(coord, lod)
	var has_request := _pending_requests.has(key)
	if has_request:
		var request: ChunkRequest = _pending_requests[key]
		has_request = request.is_active()
	_request_mutex.unlock()
	return has_request

func get_pending_request_count() -> int:
	_request_mutex.lock()
	var count := 0
	for key in _pending_requests.keys():
		var request: ChunkRequest = _pending_requests[key]
		if request.is_pending():
			count += 1
	_request_mutex.unlock()
	return count

func get_active_request_count() -> int:
	_request_mutex.lock()
	var count := _active_request_count
	_request_mutex.unlock()
	return count

func get_total_request_count() -> int:
	_request_mutex.lock()
	var count := _pending_requests.size()
	_request_mutex.unlock()
	return count

func clear_completed() -> void:
	_request_mutex.lock()
	var keys_to_remove: Array[String] = []
	for key in _pending_requests.keys():
		var request: ChunkRequest = _pending_requests[key]
		if not request.is_active():
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_pending_requests.erase(key)
	_request_mutex.unlock()

func _try_process_next() -> void:
	while true:
		_request_mutex.lock()
		if _active_request_count >= _max_concurrent_requests:
			_request_mutex.unlock()
			return
		var next_request := _get_highest_priority_pending()
		if next_request == null:
			_request_mutex.unlock()
			return
		_active_request_count += 1
		var task_id := WorkerThreadPool.add_task(
			_generate_chunk_task.bind(next_request)
		)
		next_request.mark_in_progress(task_id)
		_request_mutex.unlock()

func _get_highest_priority_pending() -> ChunkRequest:
	var best_request: ChunkRequest = null
	var best_priority := INF
	for key in _pending_requests.keys():
		var request: ChunkRequest = _pending_requests[key]
		if request.is_pending() and request.priority < best_priority:
			best_priority = request.priority
			best_request = request
	return best_request

func _generate_chunk_task(request: ChunkRequest) -> void:
	var cached := _cache.get_chunk(request.coord, request.lod_level)
	if cached:
		_on_generation_complete(request, cached, "")
		return
	var chunk := _generator.generate_chunk(request.coord, request.chunk_size, request.lod_level)
	if chunk:
		_cache.store_chunk(request.coord, request.lod_level, chunk)
		_on_generation_complete(request, chunk, "")
	else:
		_on_generation_complete(request, null, "Chunk generation failed")

func _on_generation_complete(request: ChunkRequest, chunk: ChunkMeshData, error: String) -> void:
	_request_mutex.lock()
	_active_request_count -= 1
	var key := request.get_key()
	if request.state == ChunkRequest.RequestState.CANCELLED:
		_pending_requests.erase(key)
		_request_mutex.unlock()
		_try_process_next()
		return
	if chunk:
		request.mark_completed()
		_pending_requests.erase(key)
		_request_mutex.unlock()
		chunk_completed.emit(request.coord, request.lod_level, chunk)
	else:
		request.mark_failed()
		_pending_requests.erase(key)
		_request_mutex.unlock()
		chunk_failed.emit(request.coord, request.lod_level, error)
	_try_process_next()

func _make_key(coord: Vector2i, lod: int) -> String:
	return "%d,%d,%d" % [coord.x, coord.y, lod]
