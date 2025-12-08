## @brief Utility helpers to binarize images (convert to black/white mask).
##
## @details Provides a small helper to convert a color image into a binary
## mask using a luminance threshold. The result is an Image with RGB channels
## set to 0 or 1 and alpha = 1.
class_name ImageBinarizer

## Convert `image` to a binary image using `threshold` on luminance.
##
## Parameters:
## - image (Image): source image to binarize.
## - threshold (float): luminance threshold in [0,1] (default 0.5).
##
## Returns: a new Image where pixels are 0 or 1 based on threshold.
static func binarize_image(image: Image, threshold: float = 0.5) -> Image:
	var binarized_image := image.duplicate()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var gray := 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
			var v := int(gray > threshold)
			binarized_image.set_pixel(x, y, Color(v, v, v, 1))
	return binarized_image
