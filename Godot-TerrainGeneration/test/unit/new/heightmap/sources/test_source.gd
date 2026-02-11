## Base test class for heightmap sources providing common setup and helpers.
class_name TestSource extends GutTest

var ERROR_TOLERANCE := 0.001
var _source
var _context
var _terrain_size := 64

func before_each() -> void:
	_terrain_size = 64
	_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_source = null

func _ensure_image(result: Image) -> void:
	assert_not_null(result, "Resulting image should not be null")
	assert_true(result is Image, "Result should be an Image")

func source_test_not_null(context: ProcessingContext) -> void:
	var result := _source.generate(context) as Image
	_ensure_image(result)

func source_test_size(context: ProcessingContext, expected_w: int, expected_h: int) -> void:
	var result := _source.generate(context) as Image
	_ensure_image(result)
	assert_eq(result.get_width(), expected_w, "Generated width should match expected")
	assert_eq(result.get_height(), expected_h, "Generated height should match expected")

func source_test_values_in_range(context: ProcessingContext, minv: float, maxv: float) -> void:
	var result := _source.generate(context) as Image
	_ensure_image(result)
	for y in result.get_height():
		for x in result.get_width():
			var pixel_value := float(result.get_pixel(x, y).r)
			var in_range: bool = pixel_value >= minv and pixel_value <= maxv
			assert_true(in_range, "Pixel value out of range")
			if not in_range:
				return

func assert_all_pixels_equal(image: Image, expected_value: float, tolerance: float = ERROR_TOLERANCE, message: String = "Pixel value should match expected") -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel_value := image.get_pixel(x, y).r
			var matches_expected: bool = abs(pixel_value - expected_value) <= tolerance
			assert_true(matches_expected, "%s at (%d, %d)" % [message, x, y])
			if not matches_expected:
				return

func assert_all_pixels_rgb_equal(image: Image, expected_r: float, expected_g: float, expected_b: float, tolerance: float = ERROR_TOLERANCE, message: String = "RGB values should match") -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var r_matches: bool = abs(pixel.r - expected_r) <= tolerance
			assert_true(r_matches, "%s (R) at (%d, %d)" % [message, x, y])
			if not r_matches:
				return
			var g_matches: bool = abs(pixel.g - expected_g) <= tolerance
			assert_true(g_matches, "%s (G) at (%d, %d)" % [message, x, y])
			if not g_matches:
				return
			var b_matches: bool = abs(pixel.b - expected_b) <= tolerance
			assert_true(b_matches, "%s (B) at (%d, %d)" % [message, x, y])
			if not b_matches:
				return

func assert_all_pixels_in_range(image: Image, min_value: float, max_value: float, message: String = "Pixel value should be in range") -> void:
	var eps := ERROR_TOLERANCE
	for y in image.get_height():
		for x in image.get_width():
			var pixel_value := image.get_pixel(x, y).r
			var in_range: bool = pixel_value >= (min_value - eps) and pixel_value <= (max_value + eps)
			assert_true(in_range, "%s [%.2f, %.2f] at (%d, %d), got %.6f" % [message, min_value, max_value, x, y, pixel_value])
			if not in_range:
				return
