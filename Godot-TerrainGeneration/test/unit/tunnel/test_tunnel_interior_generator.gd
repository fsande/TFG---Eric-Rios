extends GutTest

var generator: TunnelInteriorGenerator
var mock_shape: CylindricalTunnelShape
var terrain_query: TerrainHeightQuerier

func before_each():
	generator = TunnelInteriorGenerator.new()
	mock_shape = TestHelpers.create_test_tunnel_shape(Vector3(0, 10, 0), Vector3.FORWARD, 3.0, 20.0)
	terrain_query = TestHelpers.create_flat_terrain_query(15.0)

func after_each():
	generator = null
	mock_shape = null

func test_generator_initializes_with_clipper():
	assert_not_null(generator._clipper, "Generator should have clipper instance")

func test_generate_with_null_shape_returns_empty_mesh():
	var result := generator.generate(null, terrain_query)
	assert_push_error("Cannot generate interior for null shape")
	assert_not_null(result, "Should return MeshData instance")
	assert_eq(result.get_vertex_count(), 0, "Should have zero vertices")

func test_generate_with_invalid_terrain_query_returns_empty_mesh():
	var invalid_query: TerrainHeightQuerier = null
	var result := generator.generate(mock_shape, invalid_query)
	assert_push_error("Invalid terrain height querier")
	assert_eq(result.get_vertex_count(), 0, "Should have zero vertices with invalid query")

func test_generate_creates_interior_mesh():
	var result := generator.generate(mock_shape, terrain_query)
	assert_not_null(result, "Should return MeshData instance")

func test_generate_sets_processor_type():
	var result := generator.generate(mock_shape, terrain_query)
	assert_eq(result.processor_type, "TunnelInteriorGenerator", "Should tag mesh with processor type")

func test_generate_respects_min_vertex_threshold():
	generator.min_vertex_threshold = 1000000
	var result := generator.generate(mock_shape, terrain_query)
	assert_engine_error("Shape generated insufficient vertices")
	assert_eq(result.get_vertex_count(), 0, "Should reject mesh below threshold")

func test_terrain_clipping_can_be_disabled():
	generator.enable_terrain_clipping = false
	var result := generator.generate(mock_shape, terrain_query)
	assert_not_null(result, "Should still generate mesh without clipping")

func test_mesh_optimization_can_be_disabled():
	generator.enable_mesh_optimization = false
	var result := generator.generate(mock_shape, terrain_query)
	assert_not_null(result, "Should still generate mesh without optimization")

func test_generate_batch_with_empty_array():
	var shapes: Array[TunnelShape] = []
	var results := generator.generate_batch(shapes, terrain_query)
	assert_eq(results.size(), 0, "Should return empty array for empty input")

func test_generate_batch_with_multiple_shapes():
	var shape1 := TestHelpers.create_test_tunnel_shape(Vector3(0, 10, 0), Vector3.FORWARD, 3.0, 20.0)
	var shape2 := TestHelpers.create_test_tunnel_shape(Vector3(50, 10, 0), Vector3.RIGHT, 2.5, 15.0)
	var shapes: Array[TunnelShape] = [shape1, shape2]
	var results := generator.generate_batch(shapes, terrain_query)
	assert_eq(results.size(), 2, "Should return result for each shape")

func test_optimize_mesh_removes_degenerate_triangles():
	var mesh := MeshData.new()
	mesh.vertices = PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(2, 0, 0)
	])
	mesh.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(1, 1)
	])
	mesh.indices = PackedInt32Array([
		0, 1, 1,
		0, 1, 2
	])
	generator._optimize_mesh(mesh)
	assert_eq(mesh.indices.size(), 3, "Should remove degenerate triangle")

func test_optimize_mesh_removes_zero_area_triangles():
	var mesh := MeshData.new()
	mesh.vertices = PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(2, 0, 0),
		Vector3(0, 1, 0)
	])
	mesh.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 0),
		Vector2(0, 1)
	])
	mesh.indices = PackedInt32Array([
		0, 1, 2,
		0, 1, 3
	])
	generator._optimize_mesh(mesh)
	assert_eq(mesh.indices.size(), 3, "Should remove collinear triangle")

func test_configure_clipper_sets_tolerance():
	var config := {"tolerance": 0.05}
	generator.configure_clipper(config)
	assert_eq(generator._clipper.edge_intersection_tolerance, 0.05, "Should update clipper tolerance")

func test_configure_clipper_sets_interpolation_quality():
	var config := {"interpolation_quality": 2}
	generator.configure_clipper(config)
	assert_eq(generator._clipper.interpolation_quality, 2, "Should update clipper quality")

func test_get_statistics_returns_dictionary():
	var stats := generator.get_statistics()
	assert_not_null(stats, "Should return statistics dictionary")
	assert_true(stats.has("terrain_clipping_enabled"), "Should include clipping status")
	assert_true(stats.has("mesh_optimization_enabled"), "Should include optimization status")

func test_generate_with_terrain_below_tunnel_keeps_geometry():
	var below_query := TestHelpers.create_flat_terrain_query(25.0)
	var result := generator.generate(mock_shape, below_query)
	assert_gt(result.get_vertex_count(), 0, "Should keep geometry when tunnel is underground")

func test_generate_with_terrain_above_tunnel_removes_geometry():
	var above_query := TestHelpers.create_flat_terrain_query(5.0)
	var result := generator.generate(mock_shape, above_query)
	assert_engine_error("Shape generated insufficient vertices")
	assert_eq(result.get_vertex_count(), 0, "Should remove geometry when tunnel is above ground")
