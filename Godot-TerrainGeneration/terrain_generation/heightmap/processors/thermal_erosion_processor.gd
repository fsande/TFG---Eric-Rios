# Applies thermal erosion to the heightmap image.
@tool
class_name ThermalErosionProcessor extends HeightmapProcessor

enum neighbourhoodType {
	FOUR = 4,
	EIGHT = 8
}

@export var iterations: int = 15:
	set(value):
		iterations = value
		changed.emit()

@export var talus_threshold: float = 0.03:
	set(value):
		talus_threshold = value
		changed.emit()

@export var erosion_factor: float = 0.5:
	set(value):
		erosion_factor = value
		changed.emit()

@export var min_height_difference: float = 0.01:
	set(value):
		min_height_difference = value
		changed.emit()

@export var max_height_difference: float = 1.0:
	set(value):
		max_height_difference = value
		changed.emit()

@export var neighbourhood_type: neighbourhoodType = neighbourhoodType.EIGHT:
	set(value):
		neighbourhood_type = value
		changed.emit()

const OFFSETS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0),                    Vector2i(1, 0),
	Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
]

const OFFSETS_4: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, 1)
]

const WORKGROUP_SIZE: int = 8
const SHADER_PATH := "res://terrain_generation/heightmap/processors/shaders/thermal_erosion_two_pass.glsl"

## CPU implementation of thermal erosion.
func process_cpu(input: Image, _context: ProcessingContext) -> Image:
	return _apply_thermal_erosion_cpu(input)

## GPU implementation of thermal erosion.
func process_gpu(input: Image, context: ProcessingContext) -> Image:
	var rd := context.get_rendering_device()
	if not rd:
		return process_cpu(input, context)
	var shader := context.get_or_create_shader(SHADER_PATH)
	if not shader.is_valid():
		push_warning("ThermalErosionProcessor: GPU shader not available, using CPU")
		return process_cpu(input, context)
	return _apply_thermal_erosion_gpu(input, rd, shader)

## Human-readable processor name used in UI and logs.
func get_processor_name() -> String:
	return "Thermal Erosion (iter: %d, talus: %.2f)" % [iterations, talus_threshold]

## CPU implementation of thermal erosion.
func _apply_thermal_erosion_cpu(image: Image) -> Image:
	var width := image.get_width()
	var height := image.get_height()
	var offsets := OFFSETS_8 if neighbourhood_type == neighbourhoodType.EIGHT else OFFSETS_4
	var neighbour_count := offsets.size()
	var heights := PackedFloat32Array()
	heights.resize(width * height)
	var data := image.get_data()
	for pixel_index in range(width * height):
		heights[pixel_index] = data.decode_float(pixel_index * 4)
	var height_deltas := PackedFloat32Array()
	height_deltas.resize(width * height)
	var neighbour_x_list := PackedInt32Array()
	var neighbour_y_list := PackedInt32Array()
	var neighbour_height_diff_list := PackedFloat32Array()
	neighbour_x_list.resize(neighbour_count)
	neighbour_y_list.resize(neighbour_count)
	neighbour_height_diff_list.resize(neighbour_count)
	for iteration in iterations:
		height_deltas.fill(0.0)
		for y in range(height):
			for x in range(width):
				var current_index := y * width + x
				var current_height := heights[current_index]
				var valid_neighbour_count := 0
				var total_height_diff: float = 0.0
				var max_height_diff: float = 0.0
				for neighbour_offset_index in range(neighbour_count):
					var neighbour_x := x + offsets[neighbour_offset_index].x
					var neighbour_y := y + offsets[neighbour_offset_index].y
					if neighbour_x < 0 or neighbour_x >= width or neighbour_y < 0 or neighbour_y >= height:
						continue
					var neighbour_index := neighbour_y * width + neighbour_x
					var neighbour_height := heights[neighbour_index]
					var height_diff := current_height - neighbour_height
					if height_diff > talus_threshold:
						neighbour_x_list[valid_neighbour_count] = neighbour_x
						neighbour_y_list[valid_neighbour_count] = neighbour_y
						neighbour_height_diff_list[valid_neighbour_count] = height_diff
						valid_neighbour_count += 1
						total_height_diff += height_diff
						if height_diff > max_height_diff:
							max_height_diff = height_diff
				# Distribute material to valid neighbours
				if valid_neighbour_count > 0 and total_height_diff > 0.0:
					var move_amount := erosion_factor * (max_height_diff - talus_threshold)
					move_amount = clamp(move_amount, min_height_difference, max_height_difference)
					height_deltas[current_index] -= move_amount
					for neighbour_index in range(valid_neighbour_count):
						var share: float = (neighbour_height_diff_list[neighbour_index] / total_height_diff) * move_amount
						var target_index: int = neighbour_y_list[neighbour_index] * width + neighbour_x_list[neighbour_index]
						height_deltas[target_index] += share
		for pixel_index in range(width * height):
			heights[pixel_index] = clamp(heights[pixel_index] + height_deltas[pixel_index], 0.0, 1.0)
	var result := Image.create(width, height, false, Image.FORMAT_RF)
	var result_data := result.get_data()
	for pixel_index in range(width * height):
		result_data.encode_float(pixel_index * 4, heights[pixel_index])
	result.set_data(width, height, false, Image.FORMAT_RF, result_data)
	return result

func _apply_thermal_erosion_gpu(input_image: Image, rd: RenderingDevice, shader: RID) -> Image:
	var pipeline := rd.compute_pipeline_create(shader)
	var width := input_image.get_width()
	var height := input_image.get_height()
	var current_heightmap := GpuTextureHelper.create_texture_from_image(rd, input_image)
	var next_heightmap := GpuTextureHelper.create_texture_from_image(rd, input_image)
	for iteration_index in iterations:
		var input_texture := current_heightmap if iteration_index % 2 == 0 else next_heightmap
		var output_texture := next_heightmap if iteration_index % 2 == 0 else current_heightmap
		var erosion_buffer := GpuTextureHelper.create_empty_texture(rd, width, height)
		# Pass 0: Calculate erosion amounts
		_execute_thermal_erosion_pass(rd, pipeline, shader, input_texture, erosion_buffer, input_texture, width, height, 0)
		# Pass 1: Apply erosion and deposition
		_execute_thermal_erosion_pass(rd, pipeline, shader, input_texture, erosion_buffer, output_texture, width, height, 1)
		rd.free_rid(erosion_buffer)
	var final_texture := next_heightmap if iterations % 2 == 1 else current_heightmap
	var result := GpuTextureHelper.read_texture_to_image(rd, final_texture, width, height)
	var max_in_output: float = 0;
	for y in height:
		for x in width:
			var pixel_value: float = result.get_pixel(x, y).r
			if pixel_value > max_in_output:
				max_in_output = pixel_value
	print("ThermalErosionProcessor: Max height after erosion: %f" % max_in_output)
	GpuResourceHelper.free_rids(rd, [current_heightmap, next_heightmap, pipeline])	
	return result

## Executes a single pass of the thermal erosion compute shader.
func _execute_thermal_erosion_pass(rd: RenderingDevice, pipeline: RID, shader: RID, input_tex: RID, erosion_buffer: RID, output_tex: RID, width: int, height: int, pass_number: int) -> void:
	var uniforms := [
		GpuResourceHelper.create_image_uniform(0, input_tex),
		GpuResourceHelper.create_image_uniform(1, erosion_buffer),
		GpuResourceHelper.create_image_uniform(2, output_tex),
	]
	var uniform_set := rd.uniform_set_create(uniforms, shader, 0)
	
	var params_buffer := _create_params_buffer(rd, width, height, pass_number)
	var params_uniform_set := GpuTextureHelper.create_params_uniform_set(rd, params_buffer, shader, 3)
	
	var groups_x := ceili(float(width) / float(WORKGROUP_SIZE))
	var groups_y := ceili(float(height) / float(WORKGROUP_SIZE))
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, params_uniform_set, 1)
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	GpuResourceHelper.free_rids(rd, [uniform_set, params_uniform_set, params_buffer])

## Creates the parameters buffer for the thermal erosion shader.
func _create_params_buffer(rd: RenderingDevice, width: int, height: int, pass_number: int) -> RID:
	var params_bytes := PackedByteArray()
	params_bytes.resize(32)
	params_bytes.encode_s32(0, width)
	params_bytes.encode_s32(4, height)
	params_bytes.encode_float(8, talus_threshold)
	params_bytes.encode_float(12, erosion_factor)
	params_bytes.encode_float(16, min_height_difference)
	params_bytes.encode_float(20, max_height_difference)
	params_bytes.encode_s32(24, pass_number)
	params_bytes.encode_s32(28, neighbourhood_type)
	return rd.storage_buffer_create(params_bytes.size(), params_bytes)
