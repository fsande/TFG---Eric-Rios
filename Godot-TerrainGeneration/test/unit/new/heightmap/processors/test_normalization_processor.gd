## Tests for NormalizationProcessor. Verifies heightmap normalization to specified ranges.
class_name TestNormalizationProcessor extends TestProcessor

var _normalization_processor: NormalizationProcessor

func before_each() -> void:
	_terrain_size = 8
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_processor = NormalizationProcessor.new()
	_normalization_processor = _processor as NormalizationProcessor

func test_normalize_flat_default_range() -> void:
	var input_image := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)	
	processor_test(input_image, ERROR_TOLERANCE, 0.5)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_normalize_flat_high_max() -> void:
	var input_image := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	_normalization_processor.max_value = 2.0
	processor_test(input_image, ERROR_TOLERANCE, 1.0)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_normalize_flat_high_min() -> void:
	var input_image := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	_normalization_processor.min_value = 0.25
	processor_test(input_image, ERROR_TOLERANCE, 0.75)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_normalize_gradient_to_full_range() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	_normalization_processor.min_value = 0.0
	_normalization_processor.max_value = 1.0
	processor_test(input_image, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_normalize_gradient_to_narrow_range() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	_normalization_processor.min_value = 0.4
	_normalization_processor.max_value = 0.6
	processor_test(input_image, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_normalize_gradient_to_inverted_range() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	_normalization_processor.min_value = 1.0
	_normalization_processor.max_value = 0.0
	processor_test(input_image, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_normalize_diagonal_pattern() -> void:
	var input_image := TestHelpers.create_diagonal_heightmap(_terrain_size, _terrain_size)
	_normalization_processor.min_value = 0.2
	_normalization_processor.max_value = 0.8
	processor_test(input_image, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

