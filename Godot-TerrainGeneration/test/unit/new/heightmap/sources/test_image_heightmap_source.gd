## Tests for ImageHeightmapSource. Verifies image-based heightmap generation.
class_name TestImageHeightmapSource extends TestSource

var _image_source: ImageHeightmapSource

func before_each() -> void:
	_terrain_size = 64
	_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_source = ImageHeightmapSource.new()
	_image_source = _source as ImageHeightmapSource

func test_generates_null_without_image() -> void:
	_image_source.heightmap_image = null
	var result := _image_source.generate(_context)
	assert_null(result, "Should return null when no image is set")

func test_returns_duplicate_of_input_image() -> void:
	var input_image := TestHelpers.create_flat_heightmap(32, 32, 0.5)
	_image_source.heightmap_image = input_image
	var result := _image_source.generate(_context)
	assert_not_null(result, "Should return valid image")
	assert_true(are_images_equivalent(input_image, result, 32, ERROR_TOLERANCE), "Should return an image equivalent to the input")

func test_preserves_image_dimensions() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(64, 32)
	_image_source.heightmap_image = input_image
	source_test_size(_context, 64, 32)

func test_with_gradient_image() -> void:
	var input_image := TestHelpers.create_diagonal_heightmap(48, 48)
	_image_source.heightmap_image = input_image
	var result := _image_source.generate(_context)
	assert_true(are_images_equivalent(input_image, result, 48, ERROR_TOLERANCE), "Should preserve gradient values")

func test_with_flat_image() -> void:
	var input_image := TestHelpers.create_flat_heightmap(32, 32, 0.7)
	_image_source.heightmap_image = input_image
	var result := _image_source.generate(_context)
	assert_all_pixels_equal(result, 0.7, ERROR_TOLERANCE, "All pixels should be 0.7")

func test_metadata_contains_required_fields() -> void:
	var input_image := TestHelpers.create_flat_heightmap(64, 32, 0.5)
	_image_source.heightmap_image = input_image
	var metadata := _image_source.get_metadata()
	assert_true(metadata.has("type"), "Metadata should contain type")
	assert_eq(metadata["type"], "image", "Type should be image")
	assert_true(metadata.has("width"), "Metadata should contain width")
	assert_eq(metadata["width"], 64, "Width should be 64")
	assert_true(metadata.has("height"), "Metadata should contain height")
	assert_eq(metadata["height"], 32, "Height should be 32")

func test_metadata_with_null_image() -> void:
	_image_source.heightmap_image = null
	var metadata := _image_source.get_metadata()
	assert_eq(metadata["width"], 0, "Width should be 0 for null image")
	assert_eq(metadata["height"], 0, "Height should be 0 for null image")
