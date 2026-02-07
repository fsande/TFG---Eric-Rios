class_name TestHeightmap extends GutTest

func are_images_equivalent(cpu_image: Image, gpu_image: Image, expected_size: int, tolerance: float = 0.01, expected_value: float = -1) -> bool:
	assert_eq(cpu_image.get_width(), expected_size, "CPU result width should match expected_size")
	assert_eq(cpu_image.get_height(), expected_size, "CPU result height should match expected_size")
	assert_eq(gpu_image.get_width(), expected_size, "GPU result width should match expected_size")
	assert_eq(gpu_image.get_height(), expected_size, "GPU result height should match expected_size")
	for y in range(cpu_image.get_height()):
		for x in range(cpu_image.get_width()):
			var cpu_pixel := cpu_image.get_pixel(x, y).r
			var gpu_pixel := gpu_image.get_pixel(x, y).r
			assert_almost_eq(cpu_pixel, gpu_pixel, tolerance, "CPU and GPU pixel values at (%d, %d) should be close" % [x, y])
			if expected_value >= 0:
				assert_almost_eq(cpu_pixel, expected_value, tolerance, "CPU pixel value at (%d, %d) should be close to expected value" % [x, y])
	return true