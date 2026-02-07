## Applies a simple box blur to the heightmap image.
@tool
class_name BlurProcessor extends HeightmapProcessor

@export var blur_radius: float = 3.0:
	set(value):
		blur_radius = value
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

func _apply_blur_cpu(img: Image, radius: float) -> Image:
	var half_size := int(radius)
	var temp := _blur_pass_cpu(img, half_size, true)
	return _blur_pass_cpu(temp, half_size, false)

func _blur_pass_cpu(img: Image, half_size: int, is_horizontal: bool) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var result := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var sum := 0.0
			var count := 0
			if is_horizontal:
				for kx in range(-half_size, half_size + 1):
					var sample_x: int = clamp(x + kx, 0, width - 1)
					sum += img.get_pixel(sample_x, y).r
					count += 1
			else:
				for ky in range(-half_size, half_size + 1):
					var sample_y: int = clamp(y + ky, 0, height - 1)
					sum += img.get_pixel(x, sample_y).r
					count += 1
			result.set_pixel(x, y, Color(sum / float(count), 0, 0))
	return result

func _apply_blur_gpu(img: Image, radius: float, rd: RenderingDevice, shader: RID) -> Image:
	var pipeline := rd.compute_pipeline_create(shader)
	var width := img.get_width()
	var height := img.get_height()
	var input_texture := GpuTextureHelper.create_texture_from_image(rd, img)
	var temp_texture := GpuTextureHelper.create_empty_texture(rd, width, height)
	var output_texture := GpuTextureHelper.create_empty_texture(rd, width, height)
	_execute_blur_pass_gpu(rd, pipeline, shader, input_texture, temp_texture, radius, width, height, 0)  # Horizontal
	_execute_blur_pass_gpu(rd, pipeline, shader, temp_texture, output_texture, radius, width, height, 1)  # Vertical
	var result := GpuTextureHelper.read_texture_to_image(rd, output_texture, width, height)
	GpuResourceHelper.free_rids(rd, [input_texture, temp_texture, output_texture, pipeline])
	return result

func _execute_blur_pass_gpu(rd: RenderingDevice, pipeline: RID, shader: RID, input_tex: RID, output_tex: RID, radius: float, width: int, height: int, pass_number: int) -> void:
	var uniform_set := GpuTextureHelper.create_image_uniform_set(rd, input_tex, output_tex, shader)
	var params_buffer := _create_params_buffer(rd, radius, width, height, pass_number)
	var params_uniform_set := GpuTextureHelper.create_params_uniform_set(rd, params_buffer, shader)
	
	var groups_x := ceili(float(width) / 8.0)
	var groups_y := ceili(float(height) / 8.0)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, params_uniform_set, 1)
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	GpuResourceHelper.free_rids(rd, [uniform_set, params_uniform_set, params_buffer])

func _create_params_buffer(rd: RenderingDevice, radius: float, width: int, height: int, pass_number: int) -> RID:
	var params_bytes := PackedByteArray()
	params_bytes.resize(16)
	params_bytes.encode_float(0, radius)
	params_bytes.encode_s32(4, width)
	params_bytes.encode_s32(8, height)
	params_bytes.encode_s32(12, pass_number)
	return rd.storage_buffer_create(params_bytes.size(), params_bytes)
