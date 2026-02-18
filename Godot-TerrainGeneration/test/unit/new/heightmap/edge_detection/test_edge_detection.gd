## Tests for edge detection strategies.
## Verifies Sobel edge detection and strategy pattern implementation.
class_name TestEdgeDetection extends TestHeightmap

var _cpu_context: ProcessingContext
var _sobel_strategy: SobelEdgeDetectionStrategy

func before_each() -> void:
	_cpu_context = ProcessingContext.new(256, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU, 42)
	_sobel_strategy = SobelEdgeDetectionStrategy.new()

func after_each() -> void:
	if _cpu_context:
		_cpu_context.dispose()
		_cpu_context = null
	_sobel_strategy = null

## Test that Sobel detects no edges in uniform image
func test_sobel_uniform_image_no_edges() -> void:
	var input := TestHelpers.create_image(16, 16, Color(0.5, 0.5, 0.5))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	assert_eq(result.get_width(), 16, "Width should be preserved")
	assert_eq(result.get_height(), 16, "Height should be preserved")
	for y in range(2, 14):
		for x in range(2, 14):
			var edge_value := result.get_pixel(x, y).r
			assert_almost_eq(edge_value, 0.0, ERROR_TOLERANCE, 
				"Uniform image should have no edges at (%d, %d)" % [x, y])

## Test that Sobel detects vertical edge
func test_sobel_vertical_edge() -> void:
	var input := Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var value := 0.0 if x < 8 else 1.0
			input.set_pixel(x, y, Color(value, value, value))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	var edge_found := false
	for y in range(2, 14):
		for x in range(6, 10):
			var edge_value := result.get_pixel(x, y).r
			if edge_value > 0.5:
				edge_found = true
				break
		if edge_found:
			break
	assert_true(edge_found, "Should detect vertical edge")

## Test that Sobel detects horizontal edge
func test_sobel_horizontal_edge() -> void:
	var input := Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var value := 0.0 if y < 8 else 1.0
			input.set_pixel(x, y, Color(value, value, value))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	var edge_found := false
	for y in range(6, 10):
		for x in range(2, 14):
			var edge_value := result.get_pixel(x, y).r
			if edge_value > 0.5:
				edge_found = true
				break
		if edge_found:
			break
	assert_true(edge_found, "Should detect horizontal edge")

## Test that Sobel detects rectangular boundary
func test_sobel_rectangle_boundary() -> void:
	var input := Image.create(16, 16, false, Image.FORMAT_RF)
	input.fill(Color(0, 0, 0))
	for y in range(4, 12):
		for x in range(4, 12):
			input.set_pixel(x, y, Color(1, 1, 1))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	var top_edge_found := false
	for x in range(4, 12):
		if result.get_pixel(x, 4).r > 0.5 or result.get_pixel(x, 5).r > 0.5:
			top_edge_found = true
			break
	assert_true(top_edge_found, "Should detect top edge of rectangle")

## Test threshold parameter affects detection
func test_sobel_threshold_affects_detection() -> void:
	var input := Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var value := 0.3 if x < 8 else 0.5
			input.set_pixel(x, y, Color(value, value, value))
	_sobel_strategy.edge_threshold = 0.1
	var result_low := _sobel_strategy.detect_edges(input, _cpu_context)
	_sobel_strategy.edge_threshold = 1.5
	var result_high := _sobel_strategy.detect_edges(input, _cpu_context)
	var low_edge_count := 0
	var high_edge_count := 0
	for y in range(16):
		for x in range(16):
			if result_low.get_pixel(x, y).r > 0.5:
				low_edge_count += 1
			if result_high.get_pixel(x, y).r > 0.5:
				high_edge_count += 1
	assert_gt(low_edge_count, high_edge_count, 
		"Lower threshold should detect more edges. Low: %d, High: %d" % [low_edge_count, high_edge_count])

## Test edge detection with too small image
func test_sobel_too_small_image() -> void:
	var input := Image.create(2, 2, false, Image.FORMAT_RF)
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_push_error("Input image too small")
	assert_null(result, "Should return null for too small image")

## Test edge detection with null input
func test_sobel_null_input() -> void:
	var result := _sobel_strategy.detect_edges(null, _cpu_context)
	assert_push_error("Input image is null")
	assert_null(result, "Should return null for null input")

## Test edge detection preserves image dimensions
func test_sobel_preserves_dimensions() -> void:
	var input := TestHelpers.create_image(32, 24, Color(0.5, 0.5, 0.5))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	assert_eq(result.get_width(), 32, "Width should be preserved")
	assert_eq(result.get_height(), 24, "Height should be preserved")

## Test strategy name
func test_sobel_strategy_name() -> void:
	assert_eq(_sobel_strategy.get_strategy_name(), "Sobel (CPU)", 
		"Strategy name should be 'Sobel (CPU)'")

## Test GPU support flag
func test_sobel_gpu_support() -> void:
	assert_false(_sobel_strategy.supports_gpu(), 
		"CPU strategy should not support GPU")

## Test edge detection with diagonal edge
func test_sobel_diagonal_edge() -> void:
	var input := Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var value := 0.0 if x + y < 16 else 1.0
			input.set_pixel(x, y, Color(value, value, value))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	var edge_found := false
	for i in range(4, 12):
		var x := i
		var y := 16 - i
		if y >= 0 and y < 16:
			if result.get_pixel(x, y).r > 0.5:
				edge_found = true
				break
	assert_true(edge_found, "Should detect diagonal edge")

## Test edge borders are handled correctly
func test_sobel_edge_borders() -> void:
	var input := Image.create(8, 8, false, Image.FORMAT_RF)
	input.fill(Color(0.5, 0.5, 0.5))
	var result := _sobel_strategy.detect_edges(input, _cpu_context)
	assert_not_null(result, "Result should not be null")
	for x in range(8):
		assert_almost_eq(result.get_pixel(x, 0).r, 0.0, ERROR_TOLERANCE, 
			"Top border should be zero")
		assert_almost_eq(result.get_pixel(x, 7).r, 0.0, ERROR_TOLERANCE, 
			"Bottom border should be zero")
	for y in range(8):
		assert_almost_eq(result.get_pixel(0, y).r, 0.0, ERROR_TOLERANCE, 
			"Left border should be zero")
		assert_almost_eq(result.get_pixel(7, y).r, 0.0, ERROR_TOLERANCE, 
			"Right border should be zero")
