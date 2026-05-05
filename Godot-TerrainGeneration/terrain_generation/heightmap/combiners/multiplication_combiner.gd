## @brief Combines multiple heightmap images by multiplying their values.
##
## @details Resizes inputs to the largest dimensions and computes the per-pixel
## multiplication across provided images. Supports GPU compute via a shader when
## available; otherwise falls back to a CPU implementation.
@tool
class_name MultiplicationCombiner extends HeightmapCombiner

## CPU combine implementation.
func combine_cpu(images: Array[Image], _context: ProcessingContext) -> Image:
	if images.is_empty():
		return null
	var resized_images: Array[Image] = ImageHelper.resize_images_to_largest(images)
	var width := resized_images[0].get_width()
	var height := resized_images[0].get_height()
	var pixel_count := width * height
	var image_data: Array[PackedFloat32Array] = []
	for img in resized_images:
		image_data.append(img.get_data().to_float32_array())
	var output := PackedFloat32Array()
	output.resize(pixel_count)
	for i in pixel_count:
		var product := 1.0
		for data in image_data:
			product *= data[i]
		output[i] = product
	return Image.create_from_data(width, height, false, Image.FORMAT_RF, output.to_byte_array())

## Human-readable combiner name used in UI and logs.
func get_combiner_name() -> String:
	return "Multiplication"

## Explicitly define the GPU shader path for this combiner
func _get_shader_path() -> String:
	return "res://terrain_generation/heightmap/combiners/shaders/multiplication_combiner.glsl"
