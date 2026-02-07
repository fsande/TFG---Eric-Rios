@tool
class_name WeightedCombiner extends HeightmapCombiner

## Weights for each input image - must match number of images provided, max 8.
## If fewer weights are specified, missing weights default to 1.0.
@export var weights: Array[float] = []:
	set(value):
		if value.size() > MAX_GPU_IMAGES:
			push_warning("WeightedCombiner: Maximum %d weights supported. Using first %d." % [MAX_GPU_IMAGES, MAX_GPU_IMAGES])
			weights = value.slice(0, MAX_GPU_IMAGES)
		else:
			weights = value
		changed.emit()

## Combine images using the configured weights on CPU.
func combine_cpu(images: Array[Image], _context: ProcessingContext) -> Image:
	if images.is_empty():
		return null	
	var resized_images := ImageHelper.resize_images_to_largest(images)
	var max_width := resized_images[0].get_width()
	var max_height := resized_images[0].get_height()
	var result := Image.create(max_width, max_height, false, Image.FORMAT_RF)
	var total_weight: float = 0.0
	for i in resized_images.size():
		var weight: float = weights[i] if i < weights.size() else 1.0
		total_weight += weight
	if total_weight == 0.0:
		total_weight = 1.0
	for y in max_height:
		for x in max_width:
			var weighted_sum := 0.0
			for i in resized_images.size():
				var weight: float = weights[i] if i < weights.size() else 1.0
				weighted_sum += resized_images[i].get_pixel(x, y).r * weight
			result.set_pixel(x, y, Color(weighted_sum / total_weight, 0, 0))
	return result

## Human-readable combiner name.
func get_combiner_name() -> String:
	return "Weighted"

## Explicitly define the GPU shader path for this combiner
func _get_shader_path() -> String:
	return "res://terrain_generation/heightmap/combiners/shaders/weighted_combiner.glsl"

## Override to provide custom params buffer with weights
func _create_params_buffer(rd: RenderingDevice, width: int, height: int, num_images: int) -> RID:
	var total_weight: float = 0.0
	for i in range(num_images):
		var weight: float = weights[i] if i < weights.size() else 1.0
		total_weight += weight
	if total_weight == 0.0:
		total_weight = 1.0
	var params_bytes := PackedByteArray()
	params_bytes.resize(48)
	params_bytes.encode_s32(0, width)
	params_bytes.encode_s32(4, height)
	params_bytes.encode_s32(8, num_images)
	for i in range(8):
		var weight: float = weights[i] if i < weights.size() else 1.0
		params_bytes.encode_float(12 + i * 4, weight)
	params_bytes.encode_float(44, total_weight)
	return rd.storage_buffer_create(params_bytes.size(), params_bytes)
