## Tests for HeightmapProcessorDecorator. Verifies decorating sources with processors.
class_name TestHeightmapProcessorDecorator extends TestSource

var _decorator: HeightmapProcessorDecorator

func before_each() -> void:
	_terrain_size = 32
	_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_source = HeightmapProcessorDecorator.new()
	_decorator = _source as HeightmapProcessorDecorator

func test_generates_null_without_source() -> void:
	_decorator.source = null
	_decorator.processor = NormalizationProcessor.new()
	var result := _decorator.generate(_context)
	assert_null(result, "Should return null when no source provided")

func test_generates_null_without_processor() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.5)
	_decorator.source = img_source
	_decorator.processor = null
	var result := _decorator.generate(_context)
	assert_null(result, "Should return null when no processor provided")

func test_with_normalization_processor() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_horizontal_gradient_heightmap(32, 32)
	var normalizer := NormalizationProcessor.new()
	normalizer.min_value = 0.0
	normalizer.max_value = 1.0
	_decorator.source = img_source
	_decorator.processor = normalizer
	source_test_not_null(_context)
	source_test_values_in_range(_context, 0.0, 1.0)

func test_with_blur_processor() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.6)
	var blur := BlurProcessor.new()
	blur.blur_radius = 2.0
	_decorator.source = img_source
	_decorator.processor = blur
	var result := _decorator.generate(_context)
	assert_not_null(result, "Should return valid image")
	assert_all_pixels_equal(result, 0.6, 0.001, "Blurred flat should remain flat")

func test_with_noise_source_and_normalization() -> void:
	var noise_source := NoiseHeightmapSource.new()
	noise_source.resolution = 32
	var normalizer := NormalizationProcessor.new()
	normalizer.min_value = 0.25
	normalizer.max_value = 0.75
	_decorator.source = noise_source
	_decorator.processor = normalizer
	source_test_not_null(_context)
	source_test_values_in_range(_context, 0.25, 0.75)

func test_preserves_source_dimensions() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_diagonal_heightmap(48, 48)
	var normalizer := NormalizationProcessor.new()
	_decorator.source = img_source
	_decorator.processor = normalizer
	source_test_size(_context, 48, 48)

func test_metadata_includes_processor_name() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.5)
	var normalizer := NormalizationProcessor.new()
	_decorator.source = img_source
	_decorator.processor = normalizer
	var metadata := _decorator.get_metadata()
	assert_true(metadata.has("processor"), "Metadata should contain processor")
	assert_true(metadata["processor"].contains("Normalize"), "Processor name should mention Normalize")

func test_chaining_decorators() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_horizontal_gradient_heightmap(32, 32)
	var blur := BlurProcessor.new()
	blur.blur_radius = 1.0
	var decorator1 := HeightmapProcessorDecorator.new()
	decorator1.source = img_source
	decorator1.processor = blur
	var normalizer := NormalizationProcessor.new()
	normalizer.min_value = 0.2
	normalizer.max_value = 0.8
	var decorator2 := HeightmapProcessorDecorator.new()
	decorator2.source = decorator1
	decorator2.processor = normalizer
	var result := decorator2.generate(_context)
	assert_not_null(result, "Chained decorators should return valid image")
	assert_all_pixels_in_range(result, 0.2, 0.8, "Values should be in normalized range")
