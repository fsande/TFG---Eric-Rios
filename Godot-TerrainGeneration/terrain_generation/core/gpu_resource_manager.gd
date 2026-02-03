## Singleton manager for shared GPU resources across terrain generation.
## Owns the RenderingDevice and caches shaders, pipelines, and textures
## to avoid repeated creation/destruction overhead. Provides thread-safe access.
## GPU operations must be called from the main thread. Use is_main_thread() to check.
@tool
extends Node

static var _instance: GpuResourceManager = null

var _rd: RenderingDevice = null
var _shader_cache: Dictionary[String, RID] = {}
var _pipeline_cache: Dictionary[RID, RID] = {}
var _texture_cache: Dictionary[String, RID] = {}
var _texture_sizes: Dictionary[String, int] = {}
var _mutex: Mutex = Mutex.new()
var _gpu_available: bool = false
var _initialized: bool = false
var _total_texture_memory: int = 0
var _max_texture_memory: int = 256 * 1024 * 1024
var _main_thread_id: int = -1

static func get_singleton() -> GpuResourceManager:
	return _instance

func _enter_tree() -> void:
	_instance = self
	_main_thread_id = OS.get_thread_caller_id()

func _exit_tree() -> void:
	_cleanup_all_resources()
	_instance = null

func _ready() -> void:
	_initialize_lazy()

func _initialize_lazy() -> void:
	if _initialized:
		return
	_initialized = true
	_rd = RenderingServer.create_local_rendering_device()
	_gpu_available = _rd != null
	if _gpu_available:
		print("GpuResourceManager: RenderingDevice created successfully")
	else:
		push_warning("GpuResourceManager: Failed to create RenderingDevice, GPU acceleration unavailable")

func is_gpu_available() -> bool:
	if not _initialized:
		_initialize_lazy()
	return _gpu_available

func is_main_thread() -> bool:
	return OS.get_thread_caller_id() == _main_thread_id

func get_rendering_device() -> RenderingDevice:
	if not _initialized:
		_initialize_lazy()
	return _rd

func get_or_create_shader(shader_path: String) -> RID:
	_mutex.lock()
	if _shader_cache.has(shader_path):
		var cached_rid := _shader_cache[shader_path]
		_mutex.unlock()
		return cached_rid
	_mutex.unlock()
	if not is_gpu_available():
		return RID()
	if not ResourceLoader.exists(shader_path):
		push_error("GpuResourceManager: Shader not found: %s" % shader_path)
		return RID()
	var shader_file := load(shader_path)
	if not shader_file:
		push_error("GpuResourceManager: Failed to load shader: %s" % shader_path)
		return RID()
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	if not spirv:
		push_error("GpuResourceManager: Failed to get SPIR-V from shader: %s" % shader_path)
		return RID()
	var shader_rid := _rd.shader_create_from_spirv(spirv)
	if not shader_rid.is_valid():
		push_error("GpuResourceManager: Failed to create shader from SPIR-V: %s" % shader_path)
		return RID()
	_mutex.lock()
	_shader_cache[shader_path] = shader_rid
	_mutex.unlock()
	print("GpuResourceManager: Compiled and cached shader: %s" % shader_path)
	return shader_rid

func get_or_create_pipeline(shader_rid: RID) -> RID:
	if not shader_rid.is_valid():
		return RID()
	_mutex.lock()
	if _pipeline_cache.has(shader_rid):
		var cached_rid := _pipeline_cache[shader_rid]
		_mutex.unlock()
		return cached_rid
	_mutex.unlock()
	if not is_gpu_available():
		return RID()
	var pipeline_rid := _rd.compute_pipeline_create(shader_rid)
	if not pipeline_rid.is_valid():
		push_error("GpuResourceManager: Failed to create compute pipeline")
		return RID()
	_mutex.lock()
	_pipeline_cache[shader_rid] = pipeline_rid
	_mutex.unlock()
	return pipeline_rid

func upload_texture(image: Image, key: String) -> RID:
	if not is_gpu_available() or not image:
		return RID()
	_mutex.lock()
	if _texture_cache.has(key):
		var existing := _texture_cache[key]
		_mutex.unlock()
		return existing
	_mutex.unlock()
	var format := RDTextureFormat.new()
	format.width = image.get_width()
	format.height = image.get_height()
	format.depth = 1
	format.array_layers = 1
	format.mipmaps = 1
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	match image.get_format():
		Image.FORMAT_RF:
			format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
		Image.FORMAT_RGBAF:
			format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
		Image.FORMAT_RGBA8:
			format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		_:
			var converted := image.duplicate()
			converted.convert(Image.FORMAT_RGBA8)
			format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
			image = converted
	var texture_rid := _rd.texture_create(format, RDTextureView.new(), [image.get_data()])
	if not texture_rid.is_valid():
		push_error("GpuResourceManager: Failed to create texture for key: %s" % key)
		return RID()
	var size_bytes := image.get_data().size()
	_mutex.lock()
	_texture_cache[key] = texture_rid
	_texture_sizes[key] = size_bytes
	_total_texture_memory += size_bytes
	_mutex.unlock()
	return texture_rid

func get_cached_texture(key: String) -> RID:
	_mutex.lock()
	var result: RID = _texture_cache.get(key, RID())
	_mutex.unlock()
	return result

func has_cached_texture(key: String) -> bool:
	_mutex.lock()
	var has_it := _texture_cache.has(key)
	_mutex.unlock()
	return has_it

func release_texture(key: String) -> void:
	_mutex.lock()
	if not _texture_cache.has(key):
		_mutex.unlock()
		return
	var texture_rid := _texture_cache[key]
	var size_bytes: int = _texture_sizes.get(key, 0)
	_texture_cache.erase(key)
	_texture_sizes.erase(key)
	_total_texture_memory -= size_bytes
	_mutex.unlock()
	if texture_rid.is_valid() and _rd:
		_rd.free_rid(texture_rid)

func release_textures_with_prefix(prefix: String) -> void:
	_mutex.lock()
	var keys_to_remove: Array[String] = []
	for key in _texture_cache.keys():
		if key.begins_with(prefix):
			keys_to_remove.append(key)
	_mutex.unlock()
	for key in keys_to_remove:
		release_texture(key)

func get_memory_stats() -> Dictionary:
	_mutex.lock()
	var stats := {
		"gpu_available": _gpu_available,
		"shader_count": _shader_cache.size(),
		"pipeline_count": _pipeline_cache.size(),
		"texture_count": _texture_cache.size(),
		"texture_memory_mb": _total_texture_memory / (1024.0 * 1024.0),
		"max_texture_memory_mb": _max_texture_memory / (1024.0 * 1024.0)
	}
	_mutex.unlock()
	return stats

func set_max_texture_memory_mb(mb: float) -> void:
	_max_texture_memory = int(mb * 1024 * 1024)

func _cleanup_all_resources() -> void:
	if not _rd:
		return
	_mutex.lock()
	for texture_rid in _texture_cache.values():
		if texture_rid.is_valid():
			_rd.free_rid(texture_rid)
	_texture_cache.clear()
	_texture_sizes.clear()
	_total_texture_memory = 0
	for pipeline_rid in _pipeline_cache.values():
		if pipeline_rid.is_valid():
			_rd.free_rid(pipeline_rid)
	_pipeline_cache.clear()
	for shader_rid in _shader_cache.values():
		if shader_rid.is_valid():
			_rd.free_rid(shader_rid)
	_shader_cache.clear()
	_mutex.unlock()
	_rd.free()
	_rd = null
	_gpu_available = false
	print("GpuResourceManager: All GPU resources cleaned up")
