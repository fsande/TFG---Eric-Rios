## Tests for BlurProcessor. Ensures correct blur operations and GPU/CPU equivalence.
class_name TestBlurProcessor extends TestProcessor

var _blur_processor: BlurProcessor

func before_each() -> void:
	_terrain_size = 8
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_processor = BlurProcessor.new()
	_blur_processor = _processor as BlurProcessor

func test_blur_preserves_flat_heightmap() -> void:
	var input_image := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)	
	processor_test(input_image, ERROR_TOLERANCE, 0.5)

func test_blur_smooths_horizontal_gradient() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	_blur_processor.blur_radius = _terrain_size
	processor_test(input_image, ERROR_TOLERANCE)

func test_blur_with_small_radius() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	_blur_processor.blur_radius = 1.0
	processor_test(input_image, ERROR_TOLERANCE)

func test_blur_with_large_radius() -> void:
	var input_image := TestHelpers.create_diagonal_heightmap(_terrain_size, _terrain_size)
	_blur_processor.blur_radius = 5.0
	processor_test(input_image, ERROR_TOLERANCE)

func test_blur_on_diagonal_pattern() -> void:
	var input_image := TestHelpers.create_diagonal_heightmap(_terrain_size, _terrain_size)
	_blur_processor.blur_radius = 2.0
	processor_test(input_image, ERROR_TOLERANCE)

func test_blur_with_zero_radius() -> void:
	var input_image := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.7)
	_blur_processor.blur_radius = 0.0
	processor_test(input_image, ERROR_TOLERANCE, 0.7)
