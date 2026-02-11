## Tests for MaskProcessor. Verifies masking operations with and without transitions.
class_name TestMaskProcessor extends TestProcessor

var _mask_processor: MaskProcessor

func before_each() -> void:
	_terrain_size = 16
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_processor = MaskProcessor.new()
	_mask_processor = _processor as MaskProcessor
	_mask_processor.use_transitions = false

func test_mask_with_full_white_mask() -> void:
	var input := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var mask := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	_mask_processor.mask_image = mask
	processor_test(input, ERROR_TOLERANCE, 0.8)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_mask_with_full_black_mask() -> void:
	var input := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var mask := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.0)
	_mask_processor.mask_image = mask
	processor_test(input, ERROR_TOLERANCE, 0.0)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_mask_with_checkerboard_pattern() -> void:
	var input := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var mask := TestHelpers.create_checkerboard_heightmap(_terrain_size, _terrain_size, 2)
	_mask_processor.mask_image = mask
	processor_test(input, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_mask_with_gradient_input() -> void:
	var input := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	var mask := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	_mask_processor.mask_image = mask
	processor_test(input, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_mask_without_mask_image_returns_unchanged() -> void:
	var input := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.6)
	_mask_processor.mask_image = null
	var cpu_result := _mask_processor.process_cpu(input, _cpu_context)
	assert_engine_error("MaskProcessor: No mask image provided, returning input unchanged")
	assert_true(TestHelpers.images_are_similar(input, cpu_result, ERROR_TOLERANCE), "Should return unchanged input when no mask")

func test_mask_with_diagonal_gradient() -> void:
	var input := TestHelpers.create_diagonal_heightmap(_terrain_size, _terrain_size)
	var mask := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	_mask_processor.mask_image = mask
	processor_test(input, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

func test_mask_with_sparse_peaks() -> void:
	var input := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.9)
	var peaks: Array[Vector2i] = [Vector2i(4, 4), Vector2i(12, 12), Vector2i(8, 8)]
	var mask := TestHelpers.create_sparse_heightmap(_terrain_size, _terrain_size, peaks)
	_mask_processor.mask_image = mask
	processor_test(input, ERROR_TOLERANCE)
	assert_engine_error("HeightmapProcessor: GPU processing not implemented, falling back to CPU")

