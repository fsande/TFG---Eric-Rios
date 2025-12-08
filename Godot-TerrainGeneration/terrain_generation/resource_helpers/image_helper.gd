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