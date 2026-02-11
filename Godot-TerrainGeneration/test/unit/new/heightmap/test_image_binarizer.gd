## Tests for ImageBinarizer utility. Verifies image binarization operations.
class_name TestImageBinarizer extends TestHeightmap

func test_binarize_flat_white_image() -> void:
	var input := TestHelpers.create_image(16, 16, Color(1, 1, 1))
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_rgb_equal(result, 1.0, 1.0, 1.0, ERROR_TOLERANCE, "Pixel should be white")

func test_binarize_flat_black_image() -> void:
	var input := TestHelpers.create_image(16, 16, Color(0, 0, 0))
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_rgb_equal(result, 0.0, 0.0, 0.0, ERROR_TOLERANCE, "Pixel should be black")

func test_binarize_with_low_threshold() -> void:
	var input := TestHelpers.create_image(16, 16, Color(0.2, 0.2, 0.2))
	var result := ImageBinarizer.binarize_image(input, 0.1)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_equal(result, 1.0, ERROR_TOLERANCE, "Pixel above threshold should be white")

func test_binarize_with_high_threshold() -> void:
	var input := TestHelpers.create_image(16, 16, Color(0.2, 0.2, 0.2))
	var result := ImageBinarizer.binarize_image(input, 0.9)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_rgb_equal(result, 0.0, 0.0, 0.0, ERROR_TOLERANCE, "Pixel below threshold should be black")

func test_binarize_preserves_dimensions() -> void:
	var input := TestHelpers.create_image(32, 24, Color(0.5, 0.5, 0.5))
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_eq(result.get_width(), 32, "Width should be preserved")
	assert_eq(result.get_height(), 24, "Height should be preserved")

func test_binarize_at_threshold_boundary() -> void:
	var input := TestHelpers.create_image(8, 8, Color(0.5, 0.5, 0.5))
	var result := ImageBinarizer.binarize_image(input, 0.5)
	assert_not_null(result, "Result should not be null")
	assert_all_pixels_rgb_equal(result, 0.0, 0.0, 0.0, ERROR_TOLERANCE, "Pixel at threshold should be black")
