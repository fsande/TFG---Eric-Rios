## @brief A helper class for image processing tasks.
## @details Provides static methods for common image operations, such as resizing.
class_name ImageHelper

## @brief Resizes a list of images to the largest width and height among them.
static func resize_images_to_largest(images: Array[Image]) -> Array[Image]:
	var max_width := 0
	var max_height := 0
	for img in images:
		max_width = maxi(max_width, img.get_width())
		max_height = maxi(max_height, img.get_height())
	var resized_images: Array[Image] = []
	for img in images:
		if img.get_width() != max_width or img.get_height() != max_height:
			var resized := img.duplicate()
			resized.resize(max_width, max_height, Image.INTERPOLATE_LANCZOS)
			resized_images.append(resized)
		else:
			resized_images.append(img)
	return resized_images

## @brief Samples a heightmap image using bilinear interpolation.
## @details Performs bilinear filtering between the 4 neighboring pixels at the given UV coordinate.
## This method matches the GPU's LINEAR texture sampling behavior for CPU-GPU equivalence.
## Uses standard texture sampling conventions where UV [0,1] maps to texture coordinate space,
## with pixel centers at (i+0.5)/width, matching OpenGL/Vulkan behavior.
## @param heightmap The image to sample from (typically a heightmap in FORMAT_RF or similar).
## @param uv The UV coordinate to sample at, in normalized [0.0, 1.0] range.
## @return The interpolated height value from the red channel.
static func sample_bilinear(heightmap: Image, uv: Vector2) -> float:
	var width := heightmap.get_width()
	var height := heightmap.get_height()
	var x_tex := uv.x * float(width) - 0.5
	var y_tex := uv.y * float(height) - 0.5
	var x0 := int(floor(x_tex))
	var y0 := int(floor(y_tex))
	var x1 := x0 + 1
	var y1 := y0 + 1
	x0 = clampi(x0, 0, width - 1)
	y0 = clampi(y0, 0, height - 1)
	x1 = clampi(x1, 0, width - 1)
	y1 = clampi(y1, 0, height - 1)
	var fx: float = x_tex - floor(x_tex)
	var fy: float = y_tex - floor(y_tex)
	var h00 := heightmap.get_pixel(x0, y0).r
	var h10 := heightmap.get_pixel(x1, y0).r
	var h01 := heightmap.get_pixel(x0, y1).r
	var h11 := heightmap.get_pixel(x1, y1).r
	var h0: float = lerp(h00, h10, fx)
	var h1: float = lerp(h01, h11, fx)
	return lerp(h0, h1, fy)
