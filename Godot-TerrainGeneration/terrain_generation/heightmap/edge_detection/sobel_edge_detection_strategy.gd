## @brief Sobel edge detection using CPU processing.
##
## @details Implements edge detection using the Sobel operator,
@tool
class_name SobelEdgeDetectionStrategy extends EdgeDetectionStrategy

## Threshold for edge detection (0.0 to 1.0)
## Higher values = fewer edges detected (only strong edges)
@export_range(0.0, 2.0, 0.1) var edge_threshold: float = 0.5

func detect_edges(input: Image, _context: ProcessingContext) -> Image:
	if not input:
		push_error("SobelEdgeDetectionStrategy: Input image is null")
		return null
	return _detect_edges_cpu(input)

func _detect_edges_cpu(input: Image) -> Image:
	var width := input.get_width()
	var height := input.get_height()
	if width < 3 or height < 3:
		push_error("SobelEdgeDetectionStrategy: Input image too small (minimum 3x3)")
		return null
	var edges := Image.create(width, height, false, Image.FORMAT_RF)
	edges.fill(Color(0, 0, 0, 1))
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var gx := _calculate_gx(input, x, y)
			var gy := _calculate_gy(input, x, y)
			var magnitude := sqrt(gx * gx + gy * gy)
			var edge_value := 1.0 if magnitude > edge_threshold else 0.0
			edges.set_pixel(x, y, Color(edge_value, edge_value, edge_value, 1.0))
	return edges

## Calculate horizontal gradient (Gx) at position
func _calculate_gx(img: Image, x: int, y: int) -> float:
	var gx := 0.0
	gx -= img.get_pixel(x - 1, y - 1).r * 1.0
	gx += img.get_pixel(x + 1, y - 1).r * 1.0
	gx -= img.get_pixel(x - 1, y).r * 2.0
	gx += img.get_pixel(x + 1, y).r * 2.0
	gx -= img.get_pixel(x - 1, y + 1).r * 1.0
	gx += img.get_pixel(x + 1, y + 1).r * 1.0
	return gx

## Calculate vertical gradient (Gy) at position
func _calculate_gy(img: Image, x: int, y: int) -> float:
	var gy := 0.0
	gy -= img.get_pixel(x - 1, y - 1).r * 1.0
	gy -= img.get_pixel(x, y - 1).r * 2.0
	gy -= img.get_pixel(x + 1, y - 1).r * 1.0
	gy += img.get_pixel(x - 1, y + 1).r * 1.0
	gy += img.get_pixel(x, y + 1).r * 2.0
	gy += img.get_pixel(x + 1, y + 1).r * 1.0
	return gy

func get_strategy_name() -> String:
	return "Sobel (CPU)"

func supports_gpu() -> bool:
	return false  # GPU implementation can be added later

