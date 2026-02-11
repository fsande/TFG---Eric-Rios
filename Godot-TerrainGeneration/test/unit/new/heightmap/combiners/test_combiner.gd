class_name TestCombiner extends TestHeightmap

var _combiner: HeightmapCombiner
var _gpu_context: ProcessingContext
var _cpu_context: ProcessingContext
var _terrain_size := 32

func after_each() -> void:
	_gpu_context.dispose()
	_cpu_context.dispose()
	_gpu_context = null
	_cpu_context = null
	_combiner = null

func combiner_test(terrain_size: int, images: Array[Image], expected_value: float, tolerance: float = 0.01) -> void:
	var cpu_result := _combiner.combine_cpu(images, _cpu_context)
	var gpu_result := _combiner.combine_gpu(images, _gpu_context)
	assert_true(are_images_equivalent(cpu_result, gpu_result, terrain_size, tolerance, expected_value), "CPU and GPU results should be equivalent within tolerance")
