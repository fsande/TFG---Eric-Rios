extends GutTest

var test_params: MeshGeneratorParameters

func before_each():
	test_params = MeshGeneratorParameters.new()

func after_each():
	test_params = null

func test_height_scale_rejects_negative_values():
	test_params.height_scale = -50.0
	assert_push_error("height_scale cannot be negative")
	assert_eq(test_params.height_scale, 64.0, "Should reset to default when negative")

func test_height_scale_accepts_zero_for_flat_terrain():
	test_params.height_scale = 0.0
	assert_eq(test_params.height_scale, 0.0, "Should accept 0 for flat terrain generation")

func test_height_scale_accepts_valid_positive_values():
	test_params.height_scale = 128.0
	assert_eq(test_params.height_scale, 128.0, "Should accept positive values")
	test_params.height_scale = 0.001
	assert_eq(test_params.height_scale, 0.001, "Should accept small positive values")

func test_mesh_size_rejects_non_positive_values():
	test_params.mesh_size = Vector2.ZERO
	assert_eq(test_params.mesh_size, Vector2(256.0, 256.0), "Should reset to default for zero")
	test_params.mesh_size = Vector2(-100.0, 512.0)
	assert_eq(test_params.mesh_size, Vector2(256.0, 256.0), "Should reject negative X")
	test_params.mesh_size = Vector2(512.0, -100.0)
	assert_push_error(3, "mesh_size components must be positive")
	assert_eq(test_params.mesh_size, Vector2(256.0, 256.0), "Should reject negative Y")

func test_mesh_size_accepts_valid_dimensions():
	test_params.mesh_size = Vector2(512.0, 512.0)
	assert_eq(test_params.mesh_size, Vector2(512.0, 512.0), "Should accept square terrain")
	test_params.mesh_size = Vector2(1024.0, 512.0)
	assert_eq(test_params.mesh_size, Vector2(1024.0, 512.0), "Should accept rectangular terrain")

func test_subdivisions_rejects_invalid_values():
	test_params.subdivisions = 0
	assert_eq(test_params.subdivisions, 32, "Should reset to default for zero")
	test_params.subdivisions = -10
	assert_push_error(2, "subdivisions must be at least 1")
	assert_eq(test_params.subdivisions, 32, "Should reject negative subdivisions")

func test_subdivisions_accepts_valid_values():
	test_params.subdivisions = 1
	assert_eq(test_params.subdivisions, 1, "Should accept minimum value 1")
	test_params.subdivisions = 128
	assert_eq(test_params.subdivisions, 128, "Should accept common values")
	for power in [2, 4, 8, 16, 32, 64, 128, 256]:
		test_params.subdivisions = power
		assert_eq(test_params.subdivisions, power, "Should accept power-of-2: %d" % power)

func test_can_be_duplicated_with_valid_values():
	test_params.height_scale = 150.0
	test_params.mesh_size = Vector2(1024.0, 1024.0)
	test_params.subdivisions = 64
	var duplicate := test_params.duplicate()
	assert_not_null(duplicate, "Should create duplicate")
	assert_ne(duplicate, test_params, "Duplicate should be different instance")
	assert_eq(duplicate.height_scale, 150.0, "Duplicate should copy height_scale")
	assert_eq(duplicate.mesh_size, Vector2(1024.0, 1024.0), "Duplicate should copy mesh_size")
	assert_eq(duplicate.subdivisions, 64, "Duplicate should copy subdivisions")

func test_duplicate_modifications_are_independent():
	test_params.height_scale = 100.0
	test_params.mesh_size = Vector2(512.0, 512.0)
	test_params.subdivisions = 32
	var duplicate := test_params.duplicate()
	duplicate.height_scale = 200.0
	assert_eq(test_params.height_scale, 100.0, "Original should not be affected by duplicate changes")
	assert_eq(duplicate.height_scale, 200.0, "Duplicate changes should be isolated")

func test_typical_terrain_configurations():
	test_params.mesh_size = Vector2(128.0, 128.0)
	test_params.subdivisions = 16
	test_params.height_scale = 32.0
	var verts_low := (test_params.subdivisions + 1) * (test_params.subdivisions + 1)
	assert_eq(verts_low, 289, "Low detail should have 289 vertices")
	test_params.mesh_size = Vector2(2048.0, 2048.0)
	test_params.subdivisions = 256
	test_params.height_scale = 150.0
	var verts_high := (test_params.subdivisions + 1) * (test_params.subdivisions + 1)
	assert_eq(verts_high, 66049, "High detail should have 66049 vertices")

func test_aspect_ratio_calculations():
	test_params.mesh_size = Vector2(2048.0, 1024.0)
	var aspect := test_params.mesh_size.x / test_params.mesh_size.y
	assert_almost_eq(aspect, 2.0, 0.001, "2:1 aspect ratio")
	var cell_size_x := test_params.mesh_size.x / float(test_params.subdivisions)
	var cell_size_y := test_params.mesh_size.y / float(test_params.subdivisions)
	assert_almost_eq(cell_size_x / cell_size_y, aspect, 0.001, "Cell aspect should match terrain aspect")
	test_params.mesh_size = Vector2(256.0, 4096.0)
	aspect = test_params.mesh_size.y / test_params.mesh_size.x
	assert_gt(aspect, 10.0, "Should support extreme aspect ratios in both directions")
