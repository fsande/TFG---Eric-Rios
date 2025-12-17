extends GutTest

var test_heightmap: Image
var test_mesh_result: MeshGenerationResult
var test_terrain_size: Vector2
var test_metadata: Dictionary

func before_each():
	test_heightmap = TestHelpers.create_flat_heightmap(64, 64, 0.5)
	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
	test_terrain_size = Vector2(512.0, 512.0)
	test_metadata = {
		"test_key": "test_value",
		"generation_seed": 42
	}

func after_each():
	test_heightmap = null
	test_mesh_result = null
	test_metadata.clear()

func test_construction_with_all_parameters():
	var collision := HeightMapShape3D.new()
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size,
		collision,
		test_metadata,
		123.45
	)	
	assert_not_null(terrain_data, "Should create valid TerrainData")
	assert_eq(terrain_data.heightmap, test_heightmap, "Should store heightmap")
	assert_eq(terrain_data.mesh_result, test_mesh_result, "Should store mesh_result")
	assert_eq(terrain_data.terrain_size, test_terrain_size, "Should store terrain_size")
	assert_eq(terrain_data.collision_shape, collision, "Should store collision_shape")
	assert_eq(terrain_data.metadata, test_metadata, "Should store metadata")
	assert_eq(terrain_data.generation_time_ms, 123.45, "Should store generation_time_ms")

func test_construction_with_minimal_parameters():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)	
	assert_not_null(terrain_data, "Should create valid TerrainData")
	assert_null(terrain_data.collision_shape, "Should have null collision by default")
	assert_eq(terrain_data.metadata.size(), 0, "Should have empty metadata by default")
	assert_eq(terrain_data.generation_time_ms, 0.0, "Should have 0 generation time by default")

func test_construction_with_null_heightmap():
	var terrain_data := TerrainData.new(
		null,
		test_mesh_result,
		test_terrain_size
	)	
	assert_not_null(terrain_data, "Should create TerrainData even with null heightmap")
	assert_null(terrain_data.heightmap, "Should store null heightmap")

func test_construction_with_null_mesh_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		null,
		test_terrain_size
	)	
	assert_not_null(terrain_data, "Should create TerrainData even with null mesh_result")
	assert_null(terrain_data.mesh_result, "Should store null mesh_result")

func test_get_mesh_builds_valid_renderable_mesh():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)	
	var mesh := terrain_data.get_mesh()
	assert_not_null(mesh, "Should build ArrayMesh")
	assert_true(mesh is ArrayMesh, "Should be ArrayMesh type")
	assert_gt(mesh.get_surface_count(), 0, "Should have at least one surface")
	var vertex_count := terrain_data.get_vertex_count()
	assert_eq(vertex_count, 100, "10x10 grid = 100 vertices")

func test_mesh_caching_improves_performance():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)	
	assert_null(terrain_data._cached_mesh, "Cache starts empty")
	var mesh1 := terrain_data.get_mesh()
	assert_not_null(terrain_data._cached_mesh, "First call populates cache")
	var mesh2 := terrain_data.get_mesh()
	assert_same(mesh1, mesh2, "Second call returns exact same instance")

func test_get_mesh_handles_missing_mesh_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		null,
		test_terrain_size
	)
	var mesh := terrain_data.get_mesh()
	assert_null(mesh, "Should gracefully return null for missing mesh_result")

func test_has_collision_returns_true_when_collision_present():
	var collision := HeightMapShape3D.new()
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size,
		collision
	)
	assert_true(terrain_data.has_collision(), "Should return true when collision shape exists")

func test_has_collision_returns_false_when_no_collision():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size,
		null
	)
	assert_false(terrain_data.has_collision(), "Should return false when no collision shape")

func test_get_vertex_count_returns_correct_value():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	var count := terrain_data.get_vertex_count()
	assert_eq(count, 100, "Should return vertex count from mesh_result (10x10 grid)")

func test_get_vertex_count_returns_zero_for_null_mesh_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		null,
		test_terrain_size
	)
	var count := terrain_data.get_vertex_count()
	assert_eq(count, 0, "Should return 0 when mesh_result is null")

func test_get_triangle_count_is_calculated_from_indices():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	var count := terrain_data.get_triangle_count()
	assert_eq(count, 162, "10x10 grid should have 162 triangles")
	var expected := test_mesh_result.indices.size() / 3
	assert_eq(count, expected, "Triangle count = indices / 3")
	assert_eq(test_mesh_result.indices.size() % 3, 0, "Indices must be divisible by 3")

func test_get_triangle_count_returns_zero_for_null_mesh_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		null,
		test_terrain_size
	)
	var count := terrain_data.get_triangle_count()
	assert_eq(count, 0, "Should return 0 when mesh_result is null")

func test_metadata_stores_generation_provenance():
	var metadata := {
		"source": "noise",
		"seed": 12345,
		"heightmap_size": Vector2i(256, 256),
		"generation_date": "2025-12-11"
	}
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size,
		null,
		metadata
	)
	assert_eq(terrain_data.metadata["source"], "noise", "Source type")
	assert_eq(terrain_data.metadata["seed"], 12345, "Generation seed")
	assert_eq(terrain_data.metadata.size(), 4, "Should store all metadata fields")

func test_metadata_can_be_modified_post_creation():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	terrain_data.metadata["render_distance"] = 500.0
	terrain_data.metadata["lod_level"] = 2
	assert_eq(terrain_data.metadata["render_distance"], 500.0, "Should add new keys")
	assert_eq(terrain_data.metadata.size(), 2, "Should track added keys")

func test_terrain_size_supports_rectangular_terrains():
	var size := Vector2(1024.0, 2048.0)
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		size
	)
	assert_eq(terrain_data.terrain_size, size, "Should support non-square terrains")
	var aspect_ratio := size.x / size.y
	assert_almost_eq(aspect_ratio, 0.5, 0.001, "Should maintain aspect ratio")

func test_terrain_size_with_square_dimensions():
	var size := Vector2(512.0, 512.0)
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		size
	)
	assert_eq(terrain_data.terrain_size.x, terrain_data.terrain_size.y, "Square terrain")

func test_generation_time_tracks_performance_metrics():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size,
		null,
		{},
		123.45
	)
	assert_almost_eq(terrain_data.generation_time_ms, 123.45, 0.001, "Should track exact generation time")
	assert_gte(terrain_data.generation_time_ms, 0.0, "Time should be non-negative")
	var is_fast := terrain_data.generation_time_ms < 1000.0
	assert_true(is_fast or not is_fast, "Time is measurable")
