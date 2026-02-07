## @brief Tests for the AverageCombiner class. Ensures correct averaging of images as well as GPU and CPU equivalence.
class_name TestAverageCombiner extends TestCombiner

func before_each() -> void:
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_combiner = AverageCombiner.new()
		
func test_on_two_flats() -> void:
	var sloped_heightmap := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 1.0)
	var flat_heightmap := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)
	var images: Array[Image] = [sloped_heightmap, flat_heightmap]
	combiner_test(_terrain_size, images, 0.75, ERROR_TOLERANCE)
	
func test_on_multiple_flats() -> void:
	var heightmaps: Array[Image] = []
	for i in range(5):
		var height := float(i) / 4.0
		heightmaps.append(TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, height))
	combiner_test(_terrain_size, heightmaps, 0.5, ERROR_TOLERANCE)
	
func test_zero_does_not_affect_average() -> void:
	var heightmap1 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.8)
	var heightmap2 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.0)
	var heightmap3 := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.4)
	var images: Array[Image] = [heightmap1, heightmap2, heightmap3]
	combiner_test(_terrain_size, images, 0.4, ERROR_TOLERANCE)
	
