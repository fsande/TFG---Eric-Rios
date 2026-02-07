class_name TestBlurProcessor extends TestProcessor

var _blur_processor: BlurProcessor

func before_each() -> void:
	_terrain_size = 8
	_gpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.GPU, ProcessingContext.ProcessorType.CPU)
	_cpu_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_processor = BlurProcessor.new()
	_blur_processor = _processor as BlurProcessor
	

func test_blur_not_change_flat() -> void:
	var input_image := TestHelpers.create_flat_heightmap(_terrain_size, _terrain_size, 0.5)	
	processor_test(input_image, ERROR_TOLERANCE, 0.5)
	
func test_blur_on_gradient() -> void:
	var input_image := TestHelpers.create_horizontal_gradient_heightmap(_terrain_size, _terrain_size)
	_blur_processor.blur_radius = _terrain_size
	processor_test(input_image, ERROR_TOLERANCE)
