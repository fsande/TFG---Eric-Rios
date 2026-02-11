class_name TestHeightmap extends GutTest
var ERROR_TOLERANCE := 0.001

func are_images_equivalent(cpu_image: Image, gpu_image: Image, expected_size: int, tolerance: float = 0.01, expected_value: float = -1) -> bool:
	assert_eq(cpu_image.get_width(), expected_size, "CPU result width should match expected_size")
	assert_eq(cpu_image.get_height(), expected_size, "CPU result height should match expected_size")
	assert_eq(gpu_image.get_width(), expected_size, "GPU result width should match expected_size")
	assert_eq(gpu_image.get_height(), expected_size, "GPU result height should match expected_size")
	for y in range(cpu_image.get_height()):
		for x in range(cpu_image.get_width()):
			var cpu_value := cpu_image.get_pixel(x, y).r
			var gpu_value := gpu_image.get_pixel(x, y).r
			var pixels_close: bool = abs(cpu_value - gpu_value) <= tolerance
			assert_true(pixels_close, "CPU and GPU pixel values at (%d, %d) should be close. Actual CPU: %f, GPU: %f" % [x, y, cpu_value, gpu_value])
			if not pixels_close:
				return false
			if expected_value >= 0:
				var matches_expected: bool = abs(cpu_value - expected_value) <= tolerance
				assert_true(matches_expected, "CPU pixel value: %f should match expected value: %f at (%d, %d)" % [cpu_value, expected_value, x, y])
				if not matches_expected:
					return false
	return true

func assert_all_pixels_in_range(image: Image, min_value: float, max_value: float, message: String = "Pixel value should be in range") -> void:
	var eps := ERROR_TOLERANCE
	for y in image.get_height():
		for x in image.get_width():
			var pixel_value := image.get_pixel(x, y).r
			var in_range: bool = pixel_value >= (min_value - eps) and pixel_value <= (max_value + eps)
			assert_true(in_range, "%s [%.2f, %.2f] at (%d, %d), got %.6f" % [message, min_value, max_value, x, y, pixel_value])
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
			assert_true(r_matches, "%s (R) at (%d, %d). Actual: %.6f, Expected: %.6f" % [message, x, y, pixel.r, expected_r])
			if not r_matches:
				return
			var g_matches: bool = abs(pixel.g - expected_g) <= tolerance
			assert_true(g_matches, "%s (G) at (%d, %d). Actual: %.6f, Expected: %.6f" % [message, x, y, pixel.g, expected_g])
			if not g_matches:
				return
			var b_matches: bool = abs(pixel.b - expected_b) <= tolerance
			assert_true(b_matches, "%s (B) at (%d, %d). Actual: %.6f, Expected: %.6f" % [message, x, y, pixel.b, expected_b])
			if not b_matches:
				return

## New helper: returns true when more than `percent_threshold` percent of pixels differ by more than `tolerance`.
func are_images_different(cpu_image: Image, gpu_image: Image, expected_size: int, percent_threshold: float, tolerance: float = 0.01) -> bool:
	assert_eq(cpu_image.get_width(), expected_size, "CPU result width should match expected_size")
	assert_eq(cpu_image.get_height(), expected_size, "CPU result height should match expected_size")
	assert_eq(gpu_image.get_width(), expected_size, "GPU result width should match expected_size")
	assert_eq(gpu_image.get_height(), expected_size, "GPU result height should match expected_size")
	if percent_threshold < 0.0:
		percent_threshold = 0.0
	if percent_threshold > 100.0:
		percent_threshold = 100.0
	var width := cpu_image.get_width()
	var height := cpu_image.get_height()
	var total := width * height
	if total == 0:
		return false
	var diff_count := 0
	for y in range(height):
		for x in range(width):
			var cpu_value := cpu_image.get_pixel(x, y).r
			var gpu_value := gpu_image.get_pixel(x, y).r
			if abs(cpu_value - gpu_value) > tolerance:
				diff_count += 1
				if float(diff_count) * 100.0 / float(total) > percent_threshold:
					return true
	return false
