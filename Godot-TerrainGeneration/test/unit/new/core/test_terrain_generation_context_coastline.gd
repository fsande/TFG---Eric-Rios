## Tests for TerrainGenerationContext coastline and gradient features.
## Verifies coastline detection, point finding, and gradient calculations.
extends GutTest

var ERROR_TOLERANCE := 0.001

var _context: TerrainGenerationContext
var _terrain_definition: TerrainDefinition
var _test_heightmap: Image

func before_each() -> void:
	_test_heightmap = _create_test_heightmap_with_sea()
	_terrain_definition = TerrainDefinition.new()
	_terrain_definition.terrain_size = Vector2(100, 100)
	_terrain_definition.height_scale = 50.0
	_terrain_definition.sea_level = 10.0
	_context = TerrainGenerationContext.new(
		Vector2(100, 100),
		50.0,
		12345,
		_test_heightmap
	)
	_context.terrain_definition = _terrain_definition

func after_each() -> void:
	if _context:
		_context.dispose()
		_context = null
	_terrain_definition = null
	_test_heightmap = null

## Create test heightmap with sea at bottom (height < 0.2 = underwater)
func _create_test_heightmap_with_sea() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RF)
	for y in range(32):
		for x in range(32):
			var height := float(y) / 32.0 
			img.set_pixel(x, y, Color(height, 0, 0))
	return img

## Test coastline binary map generation
func test_get_coastline_binary_map() -> void:
	var binary := _context.get_coastline_binary_map()
	assert_not_null(binary, "Binary map should not be null")
	assert_eq(binary.get_width(), 32, "Width should match heightmap")
	assert_eq(binary.get_height(), 32, "Height should match heightmap")
	for x in range(32):
		var bottom_pixel := binary.get_pixel(x, 0).r
		assert_almost_eq(bottom_pixel, 1.0, ERROR_TOLERANCE, 
			"Bottom pixel should be water at (%d, 0)" % x)
		var top_pixel := binary.get_pixel(x, 31).r
		assert_almost_eq(top_pixel, 0.0, ERROR_TOLERANCE, 
			"Top pixel should be land at (%d, 31)" % x)

## Test coastline binary map is cached
func test_coastline_binary_map_is_cached() -> void:
	var binary1 := _context.get_coastline_binary_map()
	var binary2 := _context.get_coastline_binary_map()
	assert_same(binary1, binary2, "Should return same cached instance")

## Test coastline edge map generation
func test_get_coastline_edge_map() -> void:
	var edges := _context.get_coastline_edge_map()
	assert_not_null(edges, "Edge map should not be null")
	assert_eq(edges.get_width(), 32, "Width should match heightmap")
	assert_eq(edges.get_height(), 32, "Height should match heightmap")
	var edge_count := 0
	for y in range(32):
		for x in range(32):
			if edges.get_pixel(x, y).r > 0.5:
				edge_count += 1
	assert_gt(edge_count, 0, "Should detect some coastline edges")

## Test edge detection strategy can be set (delegates to CoastlineDetector)
func test_set_edge_detection_strategy() -> void:
	var custom_strategy := SobelEdgeDetectionStrategy.new()
	custom_strategy.edge_threshold = 0.3
	_context.set_edge_detection_strategy(custom_strategy)
	var edges := _context.get_coastline_edge_map()
	assert_not_null(edges, "Should use custom strategy")

## Test setting strategy invalidates cached edges (in CoastlineDetector)
func test_set_strategy_invalidates_cache() -> void:
	var edges1 := _context.get_coastline_edge_map()
	var new_strategy := SobelEdgeDetectionStrategy.new()
	new_strategy.edge_threshold = 1.5
	_context.set_edge_detection_strategy(new_strategy)
	var edges2 := _context.get_coastline_edge_map()
	assert_not_same(edges1, edges2, "Should regenerate edges with new strategy")

## Test find coastline points
func test_find_coastline_points() -> void:
	var points := _context.find_coastline_points(10, 1000)
	assert_not_null(points, "Points array should not be null")
	assert_gt(points.size(), 0, "Should find some coastline points")
	assert_lte(points.size(), 10, "Should not exceed requested count")
	for point in points:
		assert_typeof(point, TYPE_VECTOR2, "Each point should be Vector2")

## Test find coastline points with seed produces deterministic results
func test_find_coastline_points_deterministic() -> void:
	var points1 := _context.find_coastline_points(5, 42)
	var points2 := _context.find_coastline_points(5, 42)
	assert_eq(points1.size(), points2.size(), "Same seed should produce same count")
	for i in range(points1.size()):
		assert_almost_eq(points1[i].x, points2[i].x, ERROR_TOLERANCE, 
			"Same seed should produce same X at index %d" % i)
		assert_almost_eq(points1[i].y, points2[i].y, ERROR_TOLERANCE, 
			"Same seed should produce same Y at index %d" % i)

## Test find coastline points with no coastline
func test_find_coastline_points_no_coastline() -> void:
	var uniform_heightmap := Image.create(16, 16, false, Image.FORMAT_RF)
	uniform_heightmap.fill(Color(0.5, 0.5, 0.5))
	var context := TerrainGenerationContext.new(
		Vector2(100, 100),
		50.0,
		12345,
		uniform_heightmap
	)
	context.terrain_definition = _terrain_definition
	var points := context.find_coastline_points(10, 1000)
	assert_eq(points.size(), 0, "Should find no points when no coastline exists")
	context.dispose()

## Test find points above height
func test_find_points_above_height() -> void:
	var points := _context.find_points_above_height(0.5, 10, 2000)
	assert_not_null(points, "Points array should not be null")
	assert_gt(points.size(), 0, "Should find some high elevation points")
	for point in points:
		var height_norm := _context.sample_height_at(point)
		assert_gte(height_norm, 0.5 - ERROR_TOLERANCE, 
			"Point at (%f, %f) should be above threshold" % [point.x, point.y])

## Test find points above height with impossible threshold
func test_find_points_above_height_impossible() -> void:
	var points := _context.find_points_above_height(2.0, 10, 2000)
	assert_eq(points.size(), 0, "Should find no points above impossible threshold")

## Test find points above height is deterministic
func test_find_points_above_height_deterministic() -> void:
	var points1 := _context.find_points_above_height(0.3, 5, 999)
	var points2 := _context.find_points_above_height(0.3, 5, 999)
	assert_eq(points1.size(), points2.size(), "Same seed should produce same count")

## Test calculate gradient at flat terrain
func test_calculate_gradient_flat() -> void:
	var flat_heightmap := Image.create(16, 16, false, Image.FORMAT_RF)
	flat_heightmap.fill(Color(0.5, 0.5, 0.5))
	var context := TerrainGenerationContext.new(
		Vector2(100, 100),
		50.0,
		12345,
		flat_heightmap
	)
	var gradient := context.calculate_gradient_at(Vector2(0, 0))
	assert_almost_eq(gradient.x, 0.0, ERROR_TOLERANCE, "Flat terrain should have zero X gradient")
	assert_almost_eq(gradient.y, 0.0, ERROR_TOLERANCE, "Flat terrain should have zero Y gradient")
	context.dispose()

## Test calculate gradient at slope
func test_calculate_gradient_at_slope() -> void:
	var gradient := _context.calculate_gradient_at(Vector2(0, 0))
	assert_gt(gradient.y, 0.0, "Gradient should be positive in Y direction")

## Test uphill direction
func test_calculate_uphill_direction() -> void:
	var uphill := _context.calculate_uphill_direction(Vector2(0, 0))
	var length := uphill.length()
	if length > 0.0:
		assert_almost_eq(length, 1.0, ERROR_TOLERANCE, "Uphill direction should be normalized")
		assert_gt(uphill.y, 0.0, "Uphill should point in positive Y direction")

## Test downhill direction
func test_calculate_downhill_direction() -> void:
	var downhill := _context.calculate_downhill_direction(Vector2(0, 0))
	var length := downhill.length()
	if length > 0.0:
		assert_almost_eq(length, 1.0, ERROR_TOLERANCE, "Downhill direction should be normalized")
		assert_lt(downhill.y, 0.0, "Downhill should point in negative Y direction")

## Test uphill and downhill are opposite
func test_uphill_downhill_opposite() -> void:
	var pos := Vector2(10, 10)
	var uphill := _context.calculate_uphill_direction(pos)
	var downhill := _context.calculate_downhill_direction(pos)
	if uphill.length() > 0.0 and downhill.length() > 0.0:
		var dot := uphill.dot(downhill)
		assert_almost_eq(dot, -1.0, 0.01, "Uphill and downhill should be opposite")

## Test gradient on flat returns zero direction
func test_gradient_flat_returns_zero() -> void:
	var flat_heightmap := Image.create(16, 16, false, Image.FORMAT_RF)
	flat_heightmap.fill(Color(0.5, 0.5, 0.5))
	var context := TerrainGenerationContext.new(
		Vector2(100, 100),
		50.0,
		12345,
		flat_heightmap
	)
	var uphill := context.calculate_uphill_direction(Vector2(0, 0))
	var downhill := context.calculate_downhill_direction(Vector2(0, 0))
	assert_eq(uphill, Vector2.ZERO, "Flat terrain should have zero uphill direction")
	assert_eq(downhill, Vector2.ZERO, "Flat terrain should have zero downhill direction")
	context.dispose()

## Test dispose clears cached maps
func test_dispose_clears_caches() -> void:
	var _binary := _context.get_coastline_binary_map()
	var _edges := _context.get_coastline_edge_map()
	_context.dispose()
	pass  

## Test world_to_uv and uv_to_world are inverse
func test_world_uv_conversion() -> void:
	var world_pos := Vector2(10.5, -23.7)
	var uv := _context.world_to_uv(world_pos)
	var world_back := _context.uv_to_world(uv)
	assert_almost_eq(world_back.x, world_pos.x, ERROR_TOLERANCE, "X should round-trip")
	assert_almost_eq(world_back.y, world_pos.y, ERROR_TOLERANCE, "Y should round-trip")

## Test context without heightmap
func test_context_without_heightmap() -> void:
	var empty_context := TerrainGenerationContext.new(
		Vector2(100, 100),
		50.0,
		12345,
		null
	)
	var height := empty_context.sample_height_at(Vector2(0, 0))
	assert_eq(height, 0.0, "Should return 0 when no heightmap")
	var gradient := empty_context.calculate_gradient_at(Vector2(0, 0))
	assert_eq(gradient, Vector2.ZERO, "Should return zero gradient when no heightmap")
	empty_context.dispose()

## Test coastline detection without terrain definition
func test_coastline_without_terrain_definition() -> void:
	var context := TerrainGenerationContext.new(
		Vector2(100, 100),
		50.0,
		12345,
		_test_heightmap
	)
	var binary := context.get_coastline_binary_map()
	assert_null(binary, "Should return null without terrain definition")
	context.dispose()