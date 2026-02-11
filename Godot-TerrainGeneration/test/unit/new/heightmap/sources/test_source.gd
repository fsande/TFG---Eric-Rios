## Base test class for heightmap sources providing common setup and helpers.
class_name TestSource extends TestHeightmap

var _source
var _context
var _terrain_size := 64

func before_each() -> void:
	_terrain_size = 64
	_context = ProcessingContext.new(_terrain_size, ProcessingContext.ProcessorType.CPU, ProcessingContext.ProcessorType.CPU)
	_source = null

func _ensure_image(result: Image) -> void:
	assert_not_null(result, "Resulting image should not be null")
	assert_true(result is Image, "Result should be an Image")

func source_test_not_null(context: ProcessingContext) -> void:
	var result := _source.generate(context) as Image
	_ensure_image(result)

func source_test_size(context: ProcessingContext, expected_w: int, expected_h: int) -> void:
	var result := _source.generate(context) as Image
	_ensure_image(result)
	assert_eq(result.get_width(), expected_w, "Generated width should match expected")
	assert_eq(result.get_height(), expected_h, "Generated height should match expected")

func source_test_values_in_range(context: ProcessingContext, minv: float, maxv: float) -> void:
	var result := _source.generate(context) as Image
	_ensure_image(result)
	for y in result.get_height():
		for x in result.get_width():
			var pixel_value := float(result.get_pixel(x, y).r)
			var in_range: bool = pixel_value >= minv and pixel_value <= maxv
			assert_true(in_range, "Pixel value out of range")
			if not in_range:
				return
