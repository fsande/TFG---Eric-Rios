extends GutTest

## Test suite for TerrainData
## File: terrain_generation/core/terrain_data.gd

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var test_heightmap: Image
var test_mesh_result: MeshGenerationResult
var test_terrain_size: Vector2
var test_metadata: Dictionary

func before_each():
	# Create test fixtures
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

# ============================================================================
# CONSTRUCTION TESTS
# ============================================================================

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

# ============================================================================
# MESH RETRIEVAL TESTS
# ============================================================================

func test_get_mesh_builds_array_mesh():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	
	var mesh := terrain_data.get_mesh()
	
	assert_not_null(mesh, "Should build ArrayMesh")
	assert_true(mesh is ArrayMesh, "Should return ArrayMesh type")

func test_get_mesh_caches_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	
	var mesh1 := terrain_data.get_mesh()
	var mesh2 := terrain_data.get_mesh()
	
	assert_same(mesh1, mesh2, "Should return cached mesh on second call")

func test_get_mesh_returns_null_for_null_mesh_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		null,
		test_terrain_size
	)
	
	var mesh := terrain_data.get_mesh()
	
	assert_null(mesh, "Should return null when mesh_result is null")

# ============================================================================
# COLLISION TESTS
# ============================================================================

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

# ============================================================================
# VERTEX AND TRIANGLE COUNT TESTS
# ============================================================================

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

func test_get_triangle_count_calculates_correctly():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	
	var count := terrain_data.get_triangle_count()
	
	# 9x9 quads * 2 triangles per quad = 162 triangles
	assert_eq(count, 162, "Should calculate triangle count from indices")

func test_get_triangle_count_returns_zero_for_null_mesh_result():
	var terrain_data := TerrainData.new(
		test_heightmap,
		null,
		test_terrain_size
	)
	
	var count := terrain_data.get_triangle_count()
	
	assert_eq(count, 0, "Should return 0 when mesh_result is null")

# ============================================================================
# METADATA TESTS
# ============================================================================

func test_metadata_storage():
	var metadata := {
		"source": "noise",
		"seed": 12345,
		"size": 512
	}
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size,
		null,
		metadata
	)
	
	assert_eq(terrain_data.metadata["source"], "noise", "Should store source")
	assert_eq(terrain_data.metadata["seed"], 12345, "Should store seed")
	assert_eq(terrain_data.metadata["size"], 512, "Should store size")

func test_metadata_is_mutable():
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		test_terrain_size
	)
	
	terrain_data.metadata["new_key"] = "new_value"
	
	assert_eq(terrain_data.metadata["new_key"], "new_value", "Should allow metadata modification")

# ============================================================================
# TERRAIN SIZE TESTS
# ============================================================================

func test_terrain_size_stored_correctly():
	var size := Vector2(1024.0, 2048.0)
	var terrain_data := TerrainData.new(
		test_heightmap,
		test_mesh_result,
		size
	)
	
	assert_eq(terrain_data.terrain_size, size, "Should store terrain size")
	assert_eq(terrain_data.terrain_size.x, 1024.0, "Should store X dimension")
	assert_eq(terrain_data.terrain_size.y, 2048.0, "Should store Y dimension")