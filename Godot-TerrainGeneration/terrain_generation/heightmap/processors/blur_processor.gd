## Applies a simple box blur to the heightmap image.
@tool
class_name BlurProcessor extends HeightmapProcessor

@export var blur_radius: int = 3:
	set(value):
		blur_radius = value
		changed.emit()

## Set to -1 to auto-calculate based on radius (sigma = radius / 3).
@export var sigma: float = -1.0:
	set(value):
		sigma = value
		changed.emit()

const SHADER_PATH := "res://terrain_generation/heightmap/processors/shaders/blur_processor.glsl"

func process_cpu(input: Image, _context: ProcessingContext) -> Image:
	return _apply_blur_cpu(input, blur_radius)

func process_gpu(input: Image, context: ProcessingContext) -> Image:
	var rd := context.get_rendering_device()
	if not rd:
		return process_cpu(input, context)
	var shader := context.get_or_create_shader(SHADER_PATH)
	if not shader.is_valid():
		push_warning("BlurProcessor: GPU shader not available, using CPU")
		return process_cpu(input, context)
	return _apply_blur_gpu(input, blur_radius, rd, shader)

func get_processor_name() -> String:
	return "Blur (radius: %.1f)" % blur_radius

func _apply_blur_cpu(img: Image, radius: int) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var local_sigma := sigma
	if sigma <= 0:
		local_sigma = radius / 3.0
	var weights = _build_gaussian_weights(radius, local_sigma)
	var input := img.get_data().to_float32_array()
	var temp := PackedFloat32Array()
	temp.resize(width * height)
	var output := PackedFloat32Array()
	output.resize(width * height)
	for y in height:
		var row_offset := y * width
		for x in width:
			var sum := 0.0
			for k in (radius * 2 + 1):
				k -= radius
				var sx: int = clamp(x + k, 0, width - 1)
				sum += input[row_offset + sx] * weights[k + radius]
			temp[row_offset + x] = sum
	for y in height:
		for x in width:
			var sum := 0.0
			for k in (radius * 2 + 1):
				k -= radius
				var sy: int = clamp(y + k, 0, height - 1)
				sum += temp[sy * width + x] * weights[k + radius]
			output[y * width + x] = sum
	var out_bytes := output.to_byte_array()
	return Image.create_from_data(width, height, false, Image.FORMAT_RF, out_bytes)

func _build_gaussian_weights(radius: int, p_sigma: float) -> PackedFloat32Array:
	var size = radius * 2 + 1
	var weights = PackedFloat32Array()
	weights.resize(size)
	var sum := 0.0
	for i in range(size):
		var x = i - radius
		var w = exp(-(x * x) / (2.0 * p_sigma * p_sigma))
		weights[i] = w
		sum += w
	for i in range(size):
		weights[i] /= sum
	return weights

func _apply_blur_gpu(img: Image, radius: int, rd: RenderingDevice, shader: RID) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var local_sigma := sigma if sigma > 0.0 else radius / 3.0
	var weights := _build_gaussian_weights(radius, local_sigma)
	var input_texture := GpuTextureHelper.create_texture_from_image(rd, img)
	var temp_texture := GpuTextureHelper.create_empty_texture(rd, width, height)
	var output_texture := GpuTextureHelper.create_empty_texture(rd, width, height)
	var weights_buffer := _create_weights_buffer(rd, weights)
	var horizontal_params_buffer := _create_params_buffer(rd, radius, width, height, 0)
	var vertical_params_buffer := _create_params_buffer(rd, radius, width, height, 1)
	var pipeline := rd.compute_pipeline_create(shader)
	var horizontal_image_set := GpuTextureHelper.create_image_uniform_set(rd, input_texture, temp_texture, shader)
	var horizontal_params_set := GpuTextureHelper.create_params_uniform_set(rd, horizontal_params_buffer, shader, 0, 1)
	var weights_set := GpuTextureHelper.create_params_uniform_set(rd, weights_buffer, shader, 0, 2)
	var vertical_image_set := GpuTextureHelper.create_image_uniform_set(rd, temp_texture, output_texture, shader)
	var vertical_params_set := GpuTextureHelper.create_params_uniform_set(rd, vertical_params_buffer, shader, 0, 1)
	var groups_x := ceili(float(width) / 16.0)
	var groups_y := ceili(float(height) / 16.0)
	var compute_list := rd.compute_list_begin()
	# Horizontal pass
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, horizontal_image_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, horizontal_params_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, weights_set, 2)
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_add_barrier(compute_list)
	# Vertical pass
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, vertical_image_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, vertical_params_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, weights_set, 2)
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var result := GpuTextureHelper.read_texture_to_image(rd, output_texture, width, height)
	GpuResourceHelper.free_rids(rd, [
		input_texture,
		temp_texture,
		output_texture,
		weights_buffer,
		horizontal_params_buffer,
		vertical_params_buffer,
		pipeline
	])
	return result

func _create_params_buffer(rd: RenderingDevice, radius: int, width: int, height: int, pass_number: int) -> RID:
	var bytes := PackedByteArray()
	bytes.resize(16)
	bytes.encode_s32(0, radius)
	bytes.encode_s32(4, width)
	bytes.encode_s32(8, height)
	bytes.encode_s32(12, pass_number)
	return rd.storage_buffer_create(bytes.size(), bytes)

func _create_weights_buffer(rd: RenderingDevice, weights: PackedFloat32Array) -> RID:
	return rd.storage_buffer_create(weights.size() * 4, weights.to_byte_array())
