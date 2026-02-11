## Tests for ImageBinarizer utility. Verifies image binarization operations.
class_name TestImageBinarizer extends GutTest

var ERROR_TOLERANCE := 0.001

func test_binarize_flat_white_image() -> void:
	var input := TestHelpers.create_flat_heightmap(16, 16, 1.0)
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_rgb_equal(result, 1.0, 1.0, 1.0, ERROR_TOLERANCE, "Pixel should be white")

func test_binarize_flat_black_image() -> void:
	var input := TestHelpers.create_flat_heightmap(16, 16, 0.0)
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_rgb_equal(result, 0.0, 0.0, 0.0, ERROR_TOLERANCE, "Pixel should be black")

func test_binarize_with_low_threshold() -> void:
	var input := TestHelpers.create_flat_heightmap(16, 16, 0.3)
	var result := ImageBinarizer.binarize_image(input, 0.1)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_equal(result, 1.0, ERROR_TOLERANCE, "Pixel above threshold should be white")

func test_binarize_with_high_threshold() -> void:
	var input := TestHelpers.create_flat_heightmap(16, 16, 0.3)
	var result := ImageBinarizer.binarize_image(input, 0.9)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_equal(result, 0.0, ERROR_TOLERANCE, "Pixel below threshold should be black")

func test_binarize_gradient_with_default_threshold() -> void:
	var input := TestHelpers.create_horizontal_gradient_heightmap(16, 16)
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	var black_count := 0
	var white_count := 0
	for y in result.get_height():
		for x in result.get_width():
			var pixel := result.get_pixel(x, y)
			if pixel.r < 0.5:
				black_count += 1
			else:
				white_count += 1
	assert_true(black_count > 0, "Should have some black pixels")
	assert_true(white_count > 0, "Should have some white pixels")

func test_binarize_preserves_dimensions() -> void:
	var input := TestHelpers.create_diagonal_heightmap(32, 24)
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_eq(result.get_width(), 32, "Width should be preserved")
	assert_eq(result.get_height(), 24, "Height should be preserved")

func test_binarize_at_threshold_boundary() -> void:
	var input := TestHelpers.create_flat_heightmap(8, 8, 0.5)
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_equal(result, 1.0, ERROR_TOLERANCE, "Pixel equal to threshold should be white")

func test_binarize_checkerboard_pattern() -> void:
	var input := TestHelpers.create_checkerboard_heightmap(16, 16, 2)
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	var pattern_matches := true
	for y in result.get_height():
		for x in result.get_width():
			var cell_x := int(x / 2)
			var cell_y := int(y / 2)
			var expected := 1.0 if (cell_x + cell_y) % 2 == 0 else 0.0
			var actual := result.get_pixel(x, y).r
			var ok := abs(actual - expected) <= ERROR_TOLERANCE
			assert_true(ok, "Cell does not match expected pattern")
			if not ok:
				return
	pattern_matches = pattern_matches and ok
	assert_true(pattern_matches, "Binarized checkerboard should match original pattern")
