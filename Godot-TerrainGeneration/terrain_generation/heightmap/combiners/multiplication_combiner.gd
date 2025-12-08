## @brief Combines multiple heightmap images by multiplying their values.
##
## @details Resizes inputs to the largest dimensions and computes the per-pixel
## multiplication across provided images. Supports GPU compute via a shader when
## available; otherwise falls back to a CPU implementation.
@tool
class_name MultiplicationCombiner extends HeightmapCombiner

## CPU combine implementation.
func combine_cpu(images: Array[Image], _context: ProcessingContext) -> Image:
	return _combine_multiplication_cpu(images)

## Human-readable combiner name used in UI and logs.
func get_combiner_name() -> String:
	return "Multiplication"

## Explicitly define the GPU shader path for this combiner
func _get_shader_path() -> String:
	return "res://terrain_generation/heightmap/combiners/shaders/multiplication_combiner.glsl"

func _combine_multiplication_cpu(images: Array[Image]) -> Image:
	if images.is_empty():
		return null
	var resized_images: Array[Image] = ImageHelper.resize_images_to_largest(images)
	var width: int = resized_images[0].get_width()
	var height: int = resized_images[0].get_height()	
	var result := Image.create(width, height, false, Image.FORMAT_RF)
	for y in height:
		for x in width:
			var product := 1.0
			for img in resized_images:
				product *= img.get_pixel(x, y).r
			result.set_pixel(x, y, Color(product, 0, 0))
	return result
