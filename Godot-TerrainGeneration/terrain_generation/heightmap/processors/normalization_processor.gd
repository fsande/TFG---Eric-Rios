@tool
class_name NormalizationProcessor extends HeightmapProcessor

## Normalizes heightmap values to a specified range.
##
## This processor analyzes the current min/max values in the heightmap and remaps
## all values to fit within the target range [min_value, max_value]. This is useful
## for ensuring heightmaps use the full dynamic range or for constraining values
## to specific bounds.

## Minimum value of the target range.
## All heightmap values will be remapped so the lowest value becomes this.
@export var min_value: float = 0.0:
	set(value):
		min_value = value
		changed.emit()

## Maximum value of the target range.
## All heightmap values will be remapped so the highest value becomes this.
@export var max_value: float = 1.0:
	set(value):
		max_value = value
		changed.emit()

## Processes the heightmap using CPU normalization.
##
## Algorithm:
## 1. Find current min/max values in the input heightmap
## 2. Calculate normalization: normalized = (value - current_min) / (current_max - current_min)
## 3. Remap to target range: remapped = normalized * (max_value - min_value) + min_value
## If the current range is very small (to avoid division by zero), set all values to the midpoint of the target range.
##
## @param input: The input heightmap image (FORMAT_RF)
## @param _context: Processing context (unused for this processor)
## @return: A new image with normalized values
func process_cpu(input: Image, _context: ProcessingContext) -> Image:
	var data := input.get_data().to_float32_array()
	var current_min := data[0]
	var current_max := data[0]
	for v in data:
		if v < current_min: current_min = v
		if v > current_max: current_max = v
	var range_current := current_max - current_min
	var range_target := max_value - min_value
	if range_current > 0.0001:
		var inv_range := range_target / range_current
		for i in data.size():
			data[i] = (data[i] - current_min) * inv_range + min_value
	else:
		var midpoint := (min_value + max_value) * 0.5
		for i in data.size():
			data[i] = midpoint
	return Image.create_from_data(input.get_width(), input.get_height(), false, Image.FORMAT_RF, data.to_byte_array())

func process_gpu(input: Image, context: ProcessingContext) -> Image:
	var rd := context.get_rendering_device()
	if not rd:
		return process_cpu(input, context)
	var shader := context.get_or_create_shader("res://terrain_generation/heightmap/processors/shaders/normalization_processor.glsl")
	if not shader.is_valid():
		return process_cpu(input, context)
	var data := input.get_data().to_float32_array()
	var min_input := data[0]
	var max_input := data[0]
	for v in data:
		if v < min_input: min_input = v
		if v > max_input: max_input = v
	var width := input.get_width()
	var height := input.get_height()
	var input_tex := GpuTextureHelper.create_texture_from_image(rd, input)
	var output_tex := GpuTextureHelper.create_empty_texture(rd, width, height)
	var params_bytes := PackedByteArray()
	params_bytes.resize(24)
	params_bytes.encode_s32(0, width)
	params_bytes.encode_s32(4, height)
	params_bytes.encode_float(8, min_value)
	params_bytes.encode_float(12, max_value)
	params_bytes.encode_float(16, min_input)
	params_bytes.encode_float(20, max_input)
	var params_buffer := rd.storage_buffer_create(params_bytes.size(), params_bytes)
	var params_set := GpuTextureHelper.create_params_uniform_set(rd, params_buffer, shader, 0, 1)
	var image_set := GpuTextureHelper.create_image_uniform_set(rd, input_tex, output_tex, shader)
	var pipeline := rd.compute_pipeline_create(shader)
	var groups_x := ceili(float(width) / 16.0)
	var groups_y := ceili(float(height) / 16.0)
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, image_set, 0)
	rd.compute_list_bind_uniform_set(cl, params_set, 1)
	rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var result := GpuTextureHelper.read_texture_to_image(rd, output_tex, width, height)
	GpuResourceHelper.free_rids(rd, [input_tex, output_tex, params_buffer, pipeline])
	return result

## Returns a human-readable name for this processor.
##
## @return: The processor name with current min/max range
func get_processor_name() -> String:
	return "Normalize [%.2f-%.2f]" % [min_value, max_value]
