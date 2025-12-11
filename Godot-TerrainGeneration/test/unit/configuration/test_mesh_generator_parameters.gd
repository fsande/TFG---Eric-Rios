extends GutTest

## Test suite for MeshGeneratorParameters
## File: terrain_generation/configuration/mesh_generator_parameters.gd

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var test_params: MeshGeneratorParameters

func before_each():
	test_params = MeshGeneratorParameters.new()

func after_each():
	test_params = null

func test_construction_creates_valid_object():
	assert_not_null(test_params, "Should create valid MeshGeneratorParameters")

# ============================================================================
# HEIGHT SCALE TESTS
# ============================================================================

func test_height_scale_can_be_set():
	test_params.height_scale = 128.0
	assert_eq(test_params.height_scale, 128.0, "Should update height_scale")

func test_height_scale_accepts_zero():
	test_params.height_scale = 0.0
	assert_eq(test_params.height_scale, 0.0, "Should accept 0 as height_scale")

func test_height_scale_accepts_negative():
	test_params.height_scale = -50.0
	assert_eq(test_params.height_scale, -50.0, "Should accept negative height_scale")

func test_height_scale_accepts_large_values():
	test_params.height_scale = 10000.0
	assert_eq(test_params.height_scale, 10000.0, "Should accept large height_scale values")

# ============================================================================
# MESH SIZE TESTS
# ============================================================================

func test_mesh_size_can_be_set():
	test_params.mesh_size = Vector2(512.0, 512.0)
	assert_eq(test_params.mesh_size, Vector2(512.0, 512.0), "Should update mesh_size")

func test_mesh_size_can_be_non_square():
	test_params.mesh_size = Vector2(1024.0, 512.0)
	assert_eq(test_params.mesh_size.x, 1024.0, "Should set X dimension")
	assert_eq(test_params.mesh_size.y, 512.0, "Should set Y dimension")

func test_mesh_size_accepts_small_values():
	test_params.mesh_size = Vector2(1.0, 1.0)
	assert_eq(test_params.mesh_size, Vector2(1.0, 1.0), "Should accept small mesh_size")

func test_mesh_size_accepts_large_values():
	test_params.mesh_size = Vector2(10000.0, 10000.0)
	assert_eq(test_params.mesh_size, Vector2(10000.0, 10000.0), "Should accept large mesh_size")

# ============================================================================
# SUBDIVISIONS TESTS
# ============================================================================

func test_subdivisions_can_be_set():
	test_params.subdivisions = 128
	assert_eq(test_params.subdivisions, 128, "Should update subdivisions")

func test_subdivisions_accepts_small_values():
	test_params.subdivisions = 2
	assert_eq(test_params.subdivisions, 2, "Should accept small subdivision count")

func test_subdivisions_accepts_large_values():
	test_params.subdivisions = 1024
	assert_eq(test_params.subdivisions, 1024, "Should accept large subdivision count")

func test_subdivisions_accepts_one():
	test_params.subdivisions = 1
	assert_eq(test_params.subdivisions, 1, "Should accept 1 as subdivision count")

# ============================================================================
# COMBINED PARAMETER TESTS
# ============================================================================

func test_all_parameters_can_be_set_together():
	test_params.height_scale = 100.0
	test_params.mesh_size = Vector2(2048.0, 2048.0)
	test_params.subdivisions = 256
	assert_eq(test_params.height_scale, 100.0, "Should store height_scale")
	assert_eq(test_params.mesh_size, Vector2(2048.0, 2048.0), "Should store mesh_size")
	assert_eq(test_params.subdivisions, 256, "Should store subdivisions")

func test_parameters_independent_of_each_other():
	test_params.height_scale = 50.0
	var original_mesh_size := test_params.mesh_size
	var original_subdivisions := test_params.subdivisions
	assert_eq(test_params.mesh_size, original_mesh_size, "Changing height_scale shouldn't affect mesh_size")
	assert_eq(test_params.subdivisions, original_subdivisions, "Changing height_scale shouldn't affect subdivisions")

# ============================================================================
# RESOURCE BEHAVIOR TESTS
# ============================================================================

func test_is_resource_type():
	assert_true(test_params is Resource, "Should be a Resource")

func test_can_be_duplicated():
	test_params.height_scale = 150.0
	test_params.mesh_size = Vector2(1024.0, 1024.0)
	test_params.subdivisions = 64
	var duplicate := test_params.duplicate()
	assert_not_null(duplicate, "Should create duplicate")
	assert_ne(duplicate, test_params, "Duplicate should be different instance")
	assert_eq(duplicate.height_scale, 150.0, "Duplicate should have same height_scale")
	assert_eq(duplicate.mesh_size, Vector2(1024.0, 1024.0), "Duplicate should have same mesh_size")
	assert_eq(duplicate.subdivisions, 64, "Duplicate should have same subdivisions")

# ============================================================================
# PRACTICAL USE CASE TESTS
# ============================================================================

func test_low_detail_configuration():
	test_params.height_scale = 32.0
	test_params.mesh_size = Vector2(128.0, 128.0)
	test_params.subdivisions = 16
	assert_eq(test_params.height_scale, 32.0, "Low detail height_scale")
	assert_eq(test_params.mesh_size, Vector2(128.0, 128.0), "Low detail mesh_size")
	assert_eq(test_params.subdivisions, 16, "Low detail subdivisions")

func test_high_detail_configuration():
	test_params.height_scale = 200.0
	test_params.mesh_size = Vector2(4096.0, 4096.0)
	test_params.subdivisions = 512
	assert_eq(test_params.height_scale, 200.0, "High detail height_scale")
	assert_eq(test_params.mesh_size, Vector2(4096.0, 4096.0), "High detail mesh_size")
	assert_eq(test_params.subdivisions, 512, "High detail subdivisions")

func test_rectangular_terrain_configuration():
  # Not sure if we should really support this, but it does work right now
	test_params.mesh_size = Vector2(2048.0, 1024.0)
	test_params.subdivisions = 128
	assert_eq(test_params.mesh_size.x, 2048.0, "Rectangular X dimension")
	assert_eq(test_params.mesh_size.y, 1024.0, "Rectangular Y dimension")
	assert_ne(test_params.mesh_size.x, test_params.mesh_size.y, "Should support non-square meshes")
