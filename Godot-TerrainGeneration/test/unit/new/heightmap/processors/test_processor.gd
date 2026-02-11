class_name TestProcessor extends TestHeightmap

var _processor: HeightmapProcessor
var _gpu_context: ProcessingContext
var _cpu_context: ProcessingContext
var _terrain_size := 32

func after_each() -> void:
	_gpu_context.dispose()
	_cpu_context.dispose()
	_gpu_context = null
	_cpu_context = null
	_processor = null

## @brief Helper function to test a heightmap processor by comparing CPU and GPU results for a given input image.
func processor_test(input: Image, tolerance: float = 0.01, expected_value: float = -1) -> void:
	var cpu_result := _processor.process_cpu(input, _cpu_context)
	var gpu_result := _processor.process_gpu(input, _gpu_context)
	assert_true(are_images_equivalent(cpu_result, gpu_result, _terrain_size, tolerance, expected_value), "CPU and GPU results should be equivalent within tolerance")
