## @brief LRU cache for generated chunk meshes.
##
## @details Stores recently generated chunks to avoid regeneration.
## Uses memory budget to limit cache size with LRU eviction.
class_name ChunkCache extends RefCounted

var _cache: Dictionary[String, ChunkMeshData] = {}
var _access_order: Array[String] = []
var _mutex: Mutex = Mutex.new()
var _max_size_mb: float = 200.0
var _current_size_bytes: int = 0

func _init(max_size_mb: float = 200.0) -> void:
	_max_size_mb = max_size_mb

func get_chunk(coord: Vector2i) -> ChunkMeshData:
	_mutex.lock()
	var key := _make_key(coord)
	if not _cache.has(key):
		_mutex.unlock()
		return null
	_touch(key)
	var result: ChunkMeshData = _cache[key]
	_mutex.unlock()
	return result

func store_chunk(coord: Vector2i, chunk: ChunkMeshData) -> void:
	if not chunk:
		return
	_mutex.lock()
	var key := _make_key(coord)
	if _cache.has(key):
		_remove(key)
	var chunk_size := _estimate_chunk_size(chunk)
	var max_bytes := int(_max_size_mb * 1024 * 1024)
	while _current_size_bytes + chunk_size > max_bytes and not _access_order.is_empty():
		_evict_oldest()
	_cache[key] = chunk
	_access_order.append(key)
	_current_size_bytes += chunk_size
	_mutex.unlock()

func has_chunk(coord: Vector2i) -> bool:
	_mutex.lock()
	var result := _cache.has(_make_key(coord))
	_mutex.unlock()
	return result

func has_chunk_with_lod(coord: Vector2i, lod_level: int) -> bool:
	_mutex.lock()
	var key := _make_key(coord)
	if not _cache.has(key):
		_mutex.unlock()
		return false
	var chunk: ChunkMeshData = _cache[key]
	var result := chunk and chunk.lod_level_count > lod_level
	_mutex.unlock()
	return result

func invalidate_chunk(coord: Vector2i) -> void:
	_mutex.lock()
	var key := _make_key(coord)
	if _cache.has(key):
		_remove(key)
	_mutex.unlock()

func invalidate_coord(coord: Vector2i) -> void:
	_mutex.lock()
	var keys_to_remove: Array[String] = []
	for key in _cache.keys():
		if key.begins_with("%d,%d," % [coord.x, coord.y]):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_remove(key)
	_mutex.unlock()

func invalidate_region(bounds: AABB) -> void:
	_mutex.lock()
	var keys_to_remove: Array[String] = []
	for key in _cache.keys():
		var chunk: ChunkMeshData = _cache[key]
		if chunk and chunk.aabb.intersects(bounds):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_remove(key)
	_mutex.unlock()

func clear() -> void:
	_mutex.lock()
	_cache.clear()
	_access_order.clear()
	_current_size_bytes = 0
	_mutex.unlock()

func get_cached_count() -> int:
	_mutex.lock()
	var count := _cache.size()
	_mutex.unlock()
	return count

func get_memory_usage_mb() -> float:
	_mutex.lock()
	var usage := _current_size_bytes / (1024.0 * 1024.0)
	_mutex.unlock()
	return usage

func get_stats() -> Dictionary:
	_mutex.lock()
	var cached_count := _cache.size()
	var memory_mb := _current_size_bytes / (1024.0 * 1024.0)
	var max_mb := _max_size_mb
	_mutex.unlock()
	return {
		"cached_chunks": cached_count,
		"memory_usage_mb": memory_mb,
		"max_size_mb": max_mb,
		"utilization": memory_mb / max_mb if max_mb > 0 else 0.0
	}

func _make_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _touch(key: String) -> void:
	var idx := _access_order.find(key)
	if idx >= 0:
		_access_order.remove_at(idx)
		_access_order.append(key)

func _remove(key: String) -> void:
	if not _cache.has(key):
		return
	var chunk: ChunkMeshData = _cache[key]
	_current_size_bytes -= _estimate_chunk_size(chunk)
	_cache.erase(key)
	var idx := _access_order.find(key)
	if idx >= 0:
		_access_order.remove_at(idx)

func _evict_oldest() -> void:
	if _access_order.is_empty():
		return
	var oldest_key := _access_order[0]
	_remove(oldest_key)

## Really rough estimation of chunk memory usage based on mesh data sizes and overhead.
## Could be improved with more accurate measurements or by tracking actual memory usage when storing chunks.
func _estimate_chunk_size(chunk: ChunkMeshData) -> int:
	var size := 0
	for lod_mesh in chunk.lod_meshes:
		if lod_mesh:
			size += lod_mesh.get_surface_count() * 100000
	size += 1000
	return size
