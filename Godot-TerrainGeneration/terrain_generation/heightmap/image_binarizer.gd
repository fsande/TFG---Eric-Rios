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
static func binarize_rgb(image: Image, threshold: float = 0.5) -> Image:
	var data := image.get_data()
	var src_format := image.get_format()
	var pixel_count := image.get_width() * image.get_height()
	var output := PackedFloat32Array()
	output.resize(pixel_count)
	var working := image
	if src_format != Image.FORMAT_RGBA8:
		working = image.duplicate()
		working.convert(Image.FORMAT_RGBA8)
	var rgba := working.get_data()
	for i in pixel_count:
		var src := i * 4
		var r := rgba[src] / 255.0
		var g := rgba[src + 1] / 255.0
		var b := rgba[src + 2] / 255.0
		output[i] = 1.0 if (0.299 * r + 0.587 * g + 0.114 * b) > threshold else 0.0
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RF, output.to_byte_array())

static func white_threshold(image: Image, threshold: float = 0.5) -> Image:
	var working := image
	if image.get_format() != Image.FORMAT_RF:
		working = image.duplicate()
		working.convert(Image.FORMAT_RF)
	var data := working.get_data().to_float32_array()
	for i in data.size():
		data[i] = 1.0 if data[i] > threshold else 0.0
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RF, data.to_byte_array())
