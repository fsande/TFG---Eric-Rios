## @brief Abstract base class for combining multiple heightmap images.
##
## Subclasses must implement:
## - combine_cpu(): CPU-based combination logic
## - get_combiner_name(): Human-readable name for the combiner
## - _get_shader_path(): Absolute path to GPU shader (return "" for CPU-only combiners)
##
## Subclasses may optionally override:
## - _create_params_buffer(): Custom GPU parameters (default provides width, height, num_images)
##
## The base class handles:
## - GPU/CPU dispatching based on context
## - GPU shader initialization and pipeline creation
## - Image resizing to common dimensions
## - GPU texture management and cleanup
## - Compute shader execution and result retrieval
@tool @abstract
class_name HeightmapCombiner extends Resource

## Maximum number of images supported for GPU processing
const MAX_GPU_IMAGES := 8 # Arbitrary limit 

## Main entry point - automatically dispatches to CPU or GPU
func combine(images: Array[Image], context: ProcessingContext) -> Image:
	if images.is_empty():
		push_error("HeightmapCombiner: No images provided")
		return null
	if context.heightmap_use_gpu() and images.size() > MAX_GPU_IMAGES:
		push_warning("HeightmapCombiner: GPU supports max %d images, got %d. Truncating to first %d images." % [MAX_GPU_IMAGES, images.size(), MAX_GPU_IMAGES])
		var truncated_images: Array[Image] = []
		for i in range(MAX_GPU_IMAGES):
			truncated_images.append(images[i])
		return combine_gpu(truncated_images, context)	
	if context.heightmap_use_gpu():
		return combine_gpu(images, context)
	else:
		return combine_cpu(images, context)

## CPU implementation - must be overridden
@abstract func combine_cpu(_images: Array[Image], _context: ProcessingContext) -> Image


## GPU implementation - uses generalized execution pipeline
func combine_gpu(images: Array[Image], context: ProcessingContext) -> Image:
	var rd := context.get_rendering_device()
	if not rd:
		return combine_cpu(images, context)
	var shader_path := _get_shader_path()
	if shader_path.is_empty():
		push_warning("%s: No GPU shader path provided" % get_combiner_name())
		return combine_cpu(images, context)
	var shader := context.get_or_create_shader(shader_path)
	if not shader.is_valid():
		push_warning("%s: GPU shader not available, using CPU" % get_combiner_name())
		return combine_cpu(images, context)
	return _execute_gpu_combine(images, rd, shader)

## Returns a human-readable name for this combiner (for logging/UI)
@abstract func get_combiner_name() -> String


## Returns the absolute path to the GPU compute shader for this combiner.
## Must be overridden by subclasses that support GPU processing.
## Return an empty string to indicate no GPU support.
func _get_shader_path() -> String:
	push_error("_get_shader_path() must be implemented by subclass: %s" % get_script().resource_path)
	return ""

## Creates a parameters buffer for the GPU shader.
## Override this to provide combiner-specific parameters.
## Default implementation provides basic parameters: width, height, num_images
func _create_params_buffer(rd: RenderingDevice, width: int, height: int, num_images: int) -> RID:
	return _create_default_params_buffer(rd, width, height, num_images)

## Helper method to create the standard params buffer layout
func _create_default_params_buffer(rd: RenderingDevice, width: int, height: int, num_images: int) -> RID:
	var params_bytes := PackedByteArray()
	params_bytes.resize(12)
	params_bytes.encode_s32(0, width)
	params_bytes.encode_s32(4, height)
	params_bytes.encode_s32(8, num_images)
	return rd.storage_buffer_create(params_bytes.size(), params_bytes)

## Generalized GPU combine execution - resizes images, creates textures, executes shader
func _execute_gpu_combine(images: Array[Image], rd: RenderingDevice, shader: RID) -> Image:
	var pipeline := rd.compute_pipeline_create(shader)
	if images.is_empty():
		return null
	var resized_images: Array[Image] = ImageHelper.resize_images_to_largest(images)
	var max_width := resized_images[0].get_width()
	var max_height := resized_images[0].get_height()
	var input_textures: Array[RID] = []
	for img in resized_images:
		input_textures.append(GpuTextureHelper.create_texture_from_image(rd, img))
	var num_actual_images := resized_images.size()
	if input_textures.size() > 0:
		while input_textures.size() < MAX_GPU_IMAGES:
			input_textures.append(input_textures[0])
	var output_texture := GpuTextureHelper.create_empty_texture(rd, max_width, max_height)
	_dispatch_compute_shader(rd, pipeline, shader, input_textures, output_texture, max_width, max_height, num_actual_images)
	var result := GpuTextureHelper.read_texture_to_image(rd, output_texture, max_width, max_height)
	var rids: Array[RID] = [output_texture, pipeline]
	for i in range(num_actual_images):
		rids.append(input_textures[i])
	GpuResourceHelper.free_rids(rd, rids)
	return result

## Dispatch compute shader with uniform sets
func _dispatch_compute_shader(rd: RenderingDevice, pipeline: RID, shader: RID, input_textures: Array[RID], output_tex: RID, width: int, height: int, num_images: int) -> void:
	var uniform_output := GpuResourceHelper.create_image_uniform(0, output_tex)
	var uniform_inputs := GpuResourceHelper.create_image_uniform(1, input_textures[0])
	for i in range(1, input_textures.size()):
		uniform_inputs.add_id(input_textures[i])
	var texture_uniform_set := rd.uniform_set_create([uniform_output, uniform_inputs], shader, 0)
	var params_buffer := _create_params_buffer(rd, width, height, num_images)
	var params_uniform_set := GpuTextureHelper.create_params_uniform_set(rd, params_buffer, shader)
	var groups_x := ceili(float(width) / 8.0)
	var groups_y := ceili(float(height) / 8.0)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, texture_uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, params_uniform_set, 1)
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var rids: Array[RID] = [texture_uniform_set, params_uniform_set, params_buffer]
	GpuResourceHelper.free_rids(rd, rids)
