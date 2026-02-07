class_name TestWeightedCombiner extends TestCombiner

var _weighted_combiner: WeightedCombiner

func before_each() -> void:
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_combiner = WeightedCombiner.new()
	_weighted_combiner = _combiner as WeightedCombiner

func test_on_two_flats_default_weights() -> void:
	var heightmap1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var heightmap2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	var images: Array[Image] = [heightmap1, heightmap2]
	combiner_test(_terrain_size, images, 0.75, ERROR_TOLERANCE)

func test_with_custom_weights() -> void:
	var heightmap1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var heightmap2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	var images: Array[Image] = [heightmap1, heightmap2]
	_weighted_combiner.weights = [2.0, 1.0]
	combiner_test(_terrain_size, images, 5.0/6.0, ERROR_TOLERANCE)

func test_missing_weights_defaults_to_one() -> void:
	var hm1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var hm2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.0)
	var hm3 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.4)
	var images: Array[Image] = [hm1, hm2, hm3]
	_weighted_combiner.weights = [2.0, 0.0]
	combiner_test(_terrain_size, images, 2.0/3.0, ERROR_TOLERANCE)

func test_all_weights_zero_becomes_zero_result() -> void:
	var hm1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var hm2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.6)
	var images: Array[Image] = [hm1, hm2]
	_weighted_combiner.weights = [0.0, 0.0]
	combiner_test(_terrain_size, images, 0.0, ERROR_TOLERANCE)
