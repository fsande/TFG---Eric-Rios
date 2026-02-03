## @brief Unified context for all terrain generation stages.
##
## @details Lightweight context that holds configuration and delegates GPU
## resource access to the shared GpuResourceManager singleton. Can be freely
## created and disposed without GPU resource cleanup overhead.
##
## Lifecycle:
## 1. Created at start of generation
## 2. Threaded through all generation stages
## 3. Disposed when done (lightweight, no GPU cleanup)
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

## Stage-specific parameters
var mesh_parameters: MeshGeneratorParameters

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
	mesh_generator_type = p_mesh_processor
	_creation_time_ms = Time.get_ticks_msec()
	generation_seed = p_seed
	if p_seed < 0:
		push_error("ProcessingContext: generation_seed must be non-negative, got %d" % p_seed)
		generation_seed = 0
	if heightmap_processor_type == ProcessorType.GPU or mesh_generator_type == ProcessorType.GPU:
		if not _is_gpu_available():
			push_warning("ProcessingContext: GPU requested but not available, falling back to CPU")
			heightmap_processor_type = ProcessorType.CPU
			mesh_generator_type = ProcessorType.CPU

func _is_gpu_available() -> bool:
	var manager := GpuResourceManager.get_singleton()
	if manager == null or not manager.is_gpu_available():
		return false
	return true

func _is_on_main_thread() -> bool:
	var manager := GpuResourceManager.get_singleton()
	if manager == null:
		return false
	return manager.is_main_thread()

## Check if GPU can be used for heightmap processing.
## GPU is only available when on the main thread to avoid render thread errors.
func heightmap_use_gpu() -> bool:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return false
	if heightmap_processor_type != ProcessorType.GPU:
		return false
	if not _is_on_main_thread():
		return false
	return _is_gpu_available()

## Check if GPU can be used for mesh generation.
## GPU is only available when on the main thread to avoid render thread errors.
func mesh_generator_use_gpu() -> bool:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return false
	if mesh_generator_type != ProcessorType.GPU:
		return false
	if not _is_on_main_thread():
		return false
	return _is_gpu_available()


## Get rendering device from shared GpuResourceManager.
func get_rendering_device() -> RenderingDevice:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to access disposed context")
		return null
	var manager := GpuResourceManager.get_singleton()
	if manager:
		return manager.get_rendering_device()
	return null

## Get or create a cached shader via GpuResourceManager.
func get_or_create_shader(shader_path: String) -> RID:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return RID()
	if not heightmap_use_gpu() and not mesh_generator_use_gpu():
		push_warning("ProcessingContext: Attempted to load shader without GPU")
		return RID()
	var manager := GpuResourceManager.get_singleton()
	if manager:
		return manager.get_or_create_shader(shader_path)
	return RID()

## Get or create a compute pipeline via GpuResourceManager.
func get_or_create_pipeline(shader_rid: RID) -> RID:
	if _is_disposed:
		push_error("ProcessingContext: Attempted to use disposed context")
		return RID()
	var manager := GpuResourceManager.get_singleton()
	if manager:
		return manager.get_or_create_pipeline(shader_rid)
	return RID()

## Dispose context
func dispose() -> void:
	if _is_disposed:
		return
	_is_disposed = true
	var lifetime_ms := Time.get_ticks_msec() - _creation_time_ms
	if lifetime_ms > 100:
		print("ProcessingContext: Disposed after %d ms" % lifetime_ms)

## Check if context has been disposed.
func is_disposed() -> bool:
	return _is_disposed
