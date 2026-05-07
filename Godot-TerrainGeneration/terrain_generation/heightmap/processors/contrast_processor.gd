@tool
class_name ContrastProcessor extends HeightmapProcessor

## Normalizes heightmap values to a specified range.
##
## This processor analyzes the current min/max values in the heightmap and remaps
## all values to fit within the target range [min_value, max_value]. This is useful
## for ensuring heightmaps use the full dynamic range or for constraining values
## to specific bounds.

## Minimum value of the target range.
## All heightmap values will be remapped so the lowest value becomes this.
@export var target_min: float = 0.0:
	set(value):
		target_min = value
		changed.emit()

## Maximum value of the target range.
## All heightmap values will be remapped so the highest value becomes this.
@export var target_max: float = 1.0:
	set(value):
		target_max = value
		changed.emit()

## Percentile of the input range to map to target_min (0.0 = absolute min).
@export_range(0.0, 0.5, 0.001) var low_percentile: float = 0.05:
	set(value):
		low_percentile = value
		changed.emit()

## Percentile of the input range to map to target_max (1.0 = absolute max).
@export_range(0.5, 1.0, 0.001) var high_percentile: float = 0.95:
	set(value):
		high_percentile = value
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
	var sorted := data.duplicate()
	sorted.sort()
	var low_idx := int(sorted.size() * clamp(low_percentile, 0.0, 1.0))
	var high_idx := int(sorted.size() * clamp(high_percentile, 0.0, 1.0))
	high_idx = mini(high_idx, sorted.size() - 1)
	var current_min := sorted[low_idx]
	var current_max := sorted[high_idx]
	var range_current := current_max - current_min
	var range_target := target_max - target_min
	if range_current > 0.0001:
		var inv_range := range_target / range_current
		for i in data.size():
			data[i] = clampf((data[i] - current_min) * inv_range + target_min, target_min, target_max)
	else:
		var midpoint := (target_min + target_max) * 0.5
		data.fill(midpoint)
	return Image.create_from_data(input.get_width(), input.get_height(), false, Image.FORMAT_RF, data.to_byte_array())

func process_gpu(input: Image, context: ProcessingContext) -> Image:
	var rd := context.get_rendering_device()
	if not rd:
		return process_cpu(input, context)
	var shader := context.get_or_create_shader("res://terrain_generation/heightmap/processors/shaders/contrast_processor.glsl")
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
	params_bytes.encode_float(8, target_min)
	params_bytes.encode_float(12, target_max)
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
	return "ContrastProcessor [%.2f-%.2f]" % [target_min, target_max]
