## @brief Base class for edge detection strategies.
##
## @details Provides interface for detecting edges in binary images.
## Used for coastline detection and other terrain analysis tasks.
## Implementations can use different algorithms (Sobel, Canny, etc.)
## and processing methods (CPU, GPU).
@tool @abstract
class_name EdgeDetectionStrategy extends Resource

## Detect edges in the input image.
## @param input Binary image (0=one region, 1=another region)
## @param context Processing context for GPU access if needed
## @return Edge image (1=edge pixel, 0=other)
@abstract func detect_edges(input: Image, context: ProcessingContext) -> Image

## Get the name of this edge detection strategy.
@abstract func get_strategy_name() -> String

## Check if GPU processing is supported.
func supports_gpu() -> bool:
	return false

## Check if this strategy should use GPU based on context.
func should_use_gpu(context: ProcessingContext) -> bool:
	if not supports_gpu():
		return false
	if not context:
		return false
	return context.heightmap_use_gpu()

