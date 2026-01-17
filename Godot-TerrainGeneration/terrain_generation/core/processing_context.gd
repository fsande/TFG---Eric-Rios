## @brief Unified context for all terrain generation stages.
##
## @details Manages GPU resources, parameters, and state across heightmap generation,
## mesh generation, and mesh modification pipeline. Ensures RenderingDevice is created
## once and reused across all stages for optimal performance.
##
## Lifecycle:
## 1. Created at start of TerrainGenerationService.generate()
## 2. Threaded through all generation stages
## 3. Disposed at end of generation to cleanup GPU resources
class_name ProcessingContext extends RefCounted

enum ProcessorType {
	CPU,
	GPU
}

## Core configuration
var terrain_size: float
var generation_seed: int
var heightmap_processor_type: ProcessorType = ProcessorType.CPU
var mesh_generator_type: ProcessorType = ProcessorType.CPU

## GPU resources (shared across all stages)
var rendering_device: RenderingDevice = null
var _gpu_initialized: bool = false

## Stage-specific parameters
var mesh_parameters: MeshGeneratorParameters

## Resource tracking (for debugging/profiling)
var _gpu_memory_allocated: int = 0
var _shader_cache: Dictionary = {}

## Lifecycle management
var _creation_time_ms: int = 0
var _is_disposed: bool = false

## Construct context with terrain configuration.
func _init(p_terrain_size: float, p_heightmap_processor: ProcessorType, p_mesh_processor: ProcessorType, p_seed: int = 0):
	if p_terrain_size <= 0.0:
		push_error("ProcessingContext: terrain_size must be positive, got %f" % p_terrain_size)
		p_terrain_size = 256.0
	terrain_size = p_terrain_size
	heightmap_processor_type = p_heightmap_processor
	_creation_time_ms = Time.get_ticks_msec()
	if heightmap_processor_type == ProcessorType.GPU:
		_initialize_gpu()
	mesh_generator_type = p_mesh_processor
	if mesh_generator_type == ProcessorType.GPU and not _gpu_initialized:
		_initialize_gpu()
	generation_seed = p_seed
	if p_seed < 0:
		push_error("ProcessingContext: generation_seed must be non-negative, got %d" % p_seed)
		generation_seed = 0

## Initialize GPU resources once.
## Returns true if successful, false if GPU unavailable.
## Falls back to CPU automatically if GPU initialization fails.
func _initialize_gpu() -> bool:
	if _gpu_initialized:
		return rendering_device != null
	_gpu_initialized = true
	rendering_device = RenderingServer.create_local_rendering_device()
	if not rendering_device:
		push_warning("ProcessingContext: Failed to create RenderingDevice, falling back to CPU")
		heightmap_processor_type = ProcessorType.CPU
		return false
	return true

## Check if GPU is available and ready.
func heightmap_use_gpu() -> bool:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return false
	return heightmap_processor_type == ProcessorType.GPU and rendering_device != null
	
func mesh_generator_use_gpu() -> bool:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return false
	return mesh_generator_type == ProcessorType.GPU and rendering_device != null

## Get rendering device (lazy initialization).
func get_rendering_device() -> RenderingDevice:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to access disposed context")
		return null
	if heightmap_processor_type == ProcessorType.GPU and not _gpu_initialized:
		_initialize_gpu()
	return rendering_device

## Get or create a cached shader for reuse across stages.
## Returns cached shader if already loaded, otherwise loads and caches it.
func get_or_create_shader(shader_path: String) -> RID:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return RID()
	if _shader_cache.has(shader_path):
		return _shader_cache[shader_path]
	if not heightmap_use_gpu() and not mesh_generator_use_gpu():
		push_warning("ProcessingContext: Attempted to load shader without GPU")
		return RID()
	if not ResourceLoader.exists(shader_path):
		push_error("ProcessingContext: Shader not found: %s" % shader_path)
		return RID()
	var shader_file := load(shader_path)
	if not shader_file:
		push_error("ProcessingContext: Failed to load shader: %s" % shader_path)
		return RID()
	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader_rid := rendering_device.shader_create_from_spirv(spirv)
	_shader_cache[shader_path] = shader_rid
	return shader_rid

## Clean up GPU resources. Must be called at end of generation.
func dispose() -> void:
	if _is_disposed:
		return
	_is_disposed = true
	if rendering_device:
		var rids: Array[RID] = []
		for shader_rid in _shader_cache.values():
			rids.append(shader_rid)
		GpuResourceHelper.free_rids(rendering_device, rids)
	_shader_cache.clear()
	rendering_device = null
	var lifetime_ms := Time.get_ticks_msec() - _creation_time_ms
	print("ProcessingContext: Disposed after %s ms" % [str(lifetime_ms)])

## Track GPU memory allocation for profiling.
func track_gpu_allocation(bytes: int) -> void:
	_gpu_memory_allocated += bytes

## Get total GPU memory allocated through this context.
func get_gpu_memory_usage() -> int:
	return _gpu_memory_allocated

## Check if context has been disposed.
func is_disposed() -> bool:
	return _is_disposed
