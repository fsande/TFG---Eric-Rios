## @brief Combines multiple heightmap images by averaging their values.
##
## @details Resizes inputs to the largest dimensions and computes the per-pixel
## average across provided images. Supports GPU compute via a shader when
## available; otherwise falls back to a CPU implementation.
@tool
class_name AverageCombiner extends HeightmapCombiner

## CPU combine implementation.
func combine_cpu(images: Array[Image], _context: ProcessingContext) -> Image:
	return _combine_average_cpu(images)

## Human-readable combiner name used in UI and logs.
func get_combiner_name() -> String:
	return "Average"

## Explicitly define the GPU shader path for this combiner
func _get_shader_path() -> String:
	return "res://terrain_generation/heightmap/combiners/shaders/average_combiner.glsl"

## Combine images by averaging their pixel values on CPU.
func _combine_average_cpu(images: Array[Image]) -> Image:
	if images.is_empty():
		return null
	var resized_images := ImageHelper.resize_images_to_largest(images)	
	var max_width := resized_images[0].get_width()
	var max_height := resized_images[0].get_height()
	var result := Image.create(max_width, max_height, false, Image.FORMAT_RF)
	for y in max_height:
		for x in max_width:
			var sum := 0.0
			for img in resized_images:
				sum += img.get_pixel(x, y).r
			result.set_pixel(x, y, Color(sum / resized_images.size(), 0, 0))
	return result
