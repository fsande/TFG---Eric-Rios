## Tests for CompositeHeightmapSource. Verifies combining multiple sources.
class_name TestCompositeHeightmapSource extends TestSource

var _composite_source: CompositeHeightmapSource

func before_each() -> void:
	_terrain_size = 32
	_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_source = CompositeHeightmapSource.new()
	_composite_source = _source as CompositeHeightmapSource

func test_generates_null_without_sources() -> void:
	_composite_source.sources = []
	var result := _composite_source.generate(_context)
	assert_push_error("CompositeHeightmapSource: No sources provided")
	assert_null(result, "Should return null when no sources provided")

func test_with_single_source() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.6)
	_composite_source.sources = [img_source]
	var result := _composite_source.generate(_context)
	assert_not_null(result, "Should return valid image with single source")

func test_with_multiple_sources_and_average_combiner() -> void:
	var img_source1 := ImageHeightmapSource.new()
	img_source1.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 1.0)
	var img_source2 := ImageHeightmapSource.new()
	img_source2.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.5)
	_composite_source.sources = [img_source1, img_source2]
	_composite_source.combiner = AverageCombiner.new()
	var result := _composite_source.generate(_context)
	assert_not_null(result, "Should return valid image")
	assert_all_pixels_equal(result, 0.75, ERROR_TOLERANCE, "Average should be 0.75")

func test_with_multiple_sources_and_multiplication_combiner() -> void:
	var img_source1 := ImageHeightmapSource.new()
	img_source1.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.8)
	var img_source2 := ImageHeightmapSource.new()
	img_source2.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.5)
	_composite_source.sources = [img_source1, img_source2]
	_composite_source.combiner = MultiplicationCombiner.new()
	var result := _composite_source.generate(_context)
	assert_not_null(result, "Should return valid image")
	assert_all_pixels_equal(result, 0.4, ERROR_TOLERANCE, "Product should be 0.4")

func test_with_noise_sources() -> void:
	var noise_source1 := NoiseHeightmapSource.new()
	noise_source1.resolution = 32
	var noise_source2 := NoiseHeightmapSource.new()
	noise_source2.resolution = 32
	_composite_source.sources = [noise_source1, noise_source2]
	_composite_source.combiner = AverageCombiner.new()
	source_test_not_null(_context)
	source_test_size(_context, 32, 32)

func test_without_combiner_returns_first_source() -> void:
	var img_source1 := ImageHeightmapSource.new()
	img_source1.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.9)
	var img_source2 := ImageHeightmapSource.new()
	img_source2.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.1)
	_composite_source.sources = [img_source1, img_source2]
	_composite_source.combiner = null
	var result := _composite_source.generate(_context)
	assert_not_null(result, "Should return valid image")
	assert_all_pixels_equal(result, 0.9, ERROR_TOLERANCE, "Should return first source")

func test_metadata_contains_required_fields() -> void:
	var img_source := ImageHeightmapSource.new()
	img_source.heightmap_image = TestHelpers.create_flat_heightmap(32, 32, 0.5)
	_composite_source.sources = [img_source]
	_composite_source.combiner = AverageCombiner.new()
	var metadata := _composite_source.get_metadata()
	assert_true(metadata.has("type"), "Metadata should contain type")
	assert_eq(metadata["type"], "composite", "Type should be composite")
	assert_true(metadata.has("source_count"), "Metadata should contain source_count")
	assert_true(metadata.has("combiner"), "Metadata should contain combiner")
