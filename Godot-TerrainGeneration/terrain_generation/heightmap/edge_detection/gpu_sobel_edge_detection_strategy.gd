## @brief GPU-accelerated Sobel edge detection (placeholder for future implementation).
##
## @details This will use a compute shader to perform Sobel edge detection on GPU.
## Currently falls back to CPU implementation.
@tool
class_name GpuSobelEdgeDetectionStrategy extends EdgeDetectionStrategy

## Threshold for edge detection
@export_range(0.0, 2.0, 0.1) var edge_threshold: float = 0.5

const SHADER_PATH := "res://terrain_generation/heightmap/edge_detection/shaders/sobel_edge_detector.glsl"

func detect_edges(input: Image, context: ProcessingContext) -> Image:
	if not input:
		push_error("GpuSobelEdgeDetectionStrategy: Input image is null")
		return null
	
	if should_use_gpu(context):
		return _detect_edges_gpu(input, context)
	else:
		return _detect_edges_cpu(input)

func _detect_edges_gpu(input: Image, context: ProcessingContext) -> Image:
	# TODO: Implement GPU version using compute shader
	push_warning("GpuSobelEdgeDetectionStrategy: GPU implementation not yet available, falling back to CPU")
	return _detect_edges_cpu(input)

func _detect_edges_cpu(input: Image) -> Image:
	var cpu_strategy := SobelEdgeDetectionStrategy.new()
	cpu_strategy.edge_threshold = edge_threshold
	return cpu_strategy._detect_edges_cpu(input)

func get_strategy_name() -> String:
	return "Sobel (GPU)"

func supports_gpu() -> bool:
	return true

