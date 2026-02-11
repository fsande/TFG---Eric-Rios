## Tests for NoiseHeightmapSource. Verifies noise-based heightmap generation.
class_name TestNoiseHeightmapSource extends TestSource

var _noise_source: NoiseHeightmapSource

func before_each() -> void:
	_terrain_size = 64
	_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_source = NoiseHeightmapSource.new()
	_noise_source = _source as NoiseHeightmapSource

func test_generates_valid_heightmap() -> void:
	source_test_not_null(_context)

func test_generates_correct_size() -> void:
	_noise_source.resolution = 32
	source_test_size(_context, 32, 32)

func test_generates_values_in_valid_range() -> void:
	_noise_source.resolution = 32
	source_test_values_in_range(_context, 0.0, 1.0)

func test_different_seeds_produce_different_results() -> void:
	_noise_source.resolution = 32
	var context1 := ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 123)
	var context2 := ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 456)
	var result1 := _noise_source.generate(context1)
	var result2 := _noise_source.generate(context2)
	assert_false(TestHelpers.images_are_similar(result1, result2, 0.01), "Different seeds should produce different results")
	context1.dispose()
	context2.dispose()

func test_same_seed_produces_same_results() -> void:
	_noise_source.resolution = 32
	var context1 := ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 789)
	var context2 := ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 789)
	var result1 := _noise_source.generate(context1)
	var result2 := _noise_source.generate(context2)
	assert_true(TestHelpers.images_are_similar(result1, result2, ERROR_TOLERANCE), "Same seed should produce same results")
	context1.dispose()
	context2.dispose()

func test_different_resolutions() -> void:
	_noise_source.resolution = 64
	source_test_size(_context, 64, 64)
	_noise_source.resolution = 128
	source_test_size(_context, 128, 128)

func test_different_frequencies() -> void:
	_noise_source.resolution = 32
	_noise_source.frequency = 2.0
	var result1 := _noise_source.generate(_context)
	_noise_source.frequency = 10.0
	var result2 := _noise_source.generate(_context)
	assert_false(TestHelpers.images_are_similar(result1, result2, 0.1), "Different frequencies should produce different results")

func test_metadata_contains_required_fields() -> void:
	var metadata := _noise_source.get_metadata()
	assert_true(metadata.has("type"), "Metadata should contain type")
	assert_eq(metadata["type"], "noise", "Type should be noise")
	assert_true(metadata.has("resolution"), "Metadata should contain resolution")
	assert_true(metadata.has("noise_type"), "Metadata should contain noise_type")

