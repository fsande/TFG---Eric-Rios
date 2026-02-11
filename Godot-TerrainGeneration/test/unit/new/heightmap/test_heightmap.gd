class_name TestHeightmap extends GutTest

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
			assert_true(pixels_close, "CPU and GPU pixel values at (%d, %d) should be close" % [x, y])
			if not pixels_close:
				return false
			if expected_value >= 0:
				var matches_expected: bool = abs(cpu_value - expected_value) <= tolerance
				assert_true(matches_expected, "CPU pixel value: %f should match expected value: %f at (%d, %d)" % [cpu_value, expected_value, x, y])
				if not matches_expected:
					return false
	return true

func assert_all_pixels_equal(image: Image, expected_value: float, tolerance: float = 0.001, message: String = "Pixel value should match expected") -> void:
	"Asserts that all pixels in the image equal the expected value within tolerance."
	for y in image.get_height():
		for x in image.get_width():
			var pixel_value := image.get_pixel(x, y).r
			var matches_expected: bool = abs(pixel_value - expected_value) <= tolerance
			assert_true(matches_expected, "%s at (%d, %d)" % [message, x, y])
			if not matches_expected:
				return

func assert_all_pixels_rgb_equal(image: Image, expected_r: float, expected_g: float, expected_b: float, tolerance: float = 0.001, message: String = "RGB values should match") -> void:
	"Asserts that all RGB channels in the image equal expected values within tolerance."
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
