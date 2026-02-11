## Tests for MultiplicationCombiner. Ensures correct multiplication of images and GPU/CPU equivalence.
class_name TestMultiplicationCombiner extends TestCombiner

func before_each() -> void:
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_combiner = MultiplicationCombiner.new()

func test_multiply_two_flat_heightmaps() -> void:
	var heightmap1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var heightmap2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	var images: Array[Image] = [heightmap1, heightmap2]
	combiner_test(_terrain_size, images, 0.4, ERROR_TOLERANCE)

func test_multiply_multiple_flat_heightmaps() -> void:
	var heightmaps: Array[Image] = []
	var expected_product := 1.0
	for i in range(4):
		var height := 0.2 + i
		expected_product *= height
		heightmaps.append(TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, height))
	combiner_test(_terrain_size, heightmaps, expected_product, ERROR_TOLERANCE)

func test_multiplies_to_zero() -> void:
	var heightmap1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var heightmap2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.0)
	var images: Array[Image] = [heightmap1, heightmap2]
	combiner_test(_terrain_size, images, 0.0, ERROR_TOLERANCE)

func test_multiply_with_one() -> void:
	var heightmap1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.6)
	var heightmap2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var images: Array[Image] = [heightmap1, heightmap2]
	combiner_test(_terrain_size, images, 0.6, ERROR_TOLERANCE)

func test_multiply_single_image() -> void:
	var heightmap := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.75)
	var images: Array[Image] = [heightmap]
	combiner_test(_terrain_size, images, 0.75, ERROR_TOLERANCE)

func test_multiply_with_gradients() -> void:
	var grad := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	var flat := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	var images: Array[Image] = [grad, flat]
	combiner_test(_terrain_size, images, -1, ERROR_TOLERANCE)

func test_multiply_all_ones() -> void:
	var hm1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var hm2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var images: Array[Image] = [hm1, hm2]
	combiner_test(_terrain_size, images, 1.0, ERROR_TOLERANCE)
