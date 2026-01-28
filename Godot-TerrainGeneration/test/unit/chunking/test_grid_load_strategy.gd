## @brief Unit tests for GridLoadStrategy
##
## @details Tests radius-based chunk loading logic, priority calculation,
## and coordinate conversion.
extends GutTest

var strategy: GridLoadStrategy
var chunk_data: ChunkedTerrainData
var mock_chunks: Array[ChunkMeshData]

func before_each():
	strategy = GridLoadStrategy.new()
	strategy.load_radius = 2
	strategy.unload_radius = 3
	chunk_data = ChunkedTerrainData.new()
	chunk_data.chunk_size = Vector2(100.0, 100.0)
	for x in range(-2, 3):
		for z in range(-2, 3):
			var coord := Vector2i(x, z)
			var world_pos := Vector3(x * 100.0, 0, z * 100.0)
			var mesh_data := MeshData.new()
			var chunk := ChunkMeshData.new(coord, world_pos, Vector2(100, 100), mesh_data)
			chunk_data.add_chunk(chunk)
			mock_chunks.append(chunk)
	strategy._chunk_data_source = chunk_data

func after_each():
	strategy = null
	chunk_data = null
	mock_chunks.clear()

func test_should_load_chunk_within_radius():
	var camera_pos := Vector3(0, 10, 0)
	var context := ChunkLoadContext.new({}, 0.016)
	var chunk_00 := chunk_data.get_chunk_at(Vector2i(0, 0))
	assert_true(strategy.should_load_chunk(chunk_00, camera_pos, context), "Chunk at origin should load")
	var chunk_11 := chunk_data.get_chunk_at(Vector2i(1, 1))
	assert_true(strategy.should_load_chunk(chunk_11, camera_pos, context), "Chunk at (1,1) should load")
	var chunk_22 := chunk_data.get_chunk_at(Vector2i(2, 2))
	assert_false(strategy.should_load_chunk(chunk_22, camera_pos, context), "Chunk at (2,2) should not load")

func test_should_unload_chunk_beyond_unload_radius():
	var camera_pos := Vector3(0, 10, 0)
	var context := ChunkLoadContext.new({}, 0.016)
	var chunk_00 := chunk_data.get_chunk_at(Vector2i(0, 0))
	assert_false(strategy.should_unload_chunk(chunk_00, camera_pos, context), "Chunk at origin should not unload")
	var chunk_21 := chunk_data.get_chunk_at(Vector2i(2, 1))
	assert_false(strategy.should_unload_chunk(chunk_21, camera_pos, context), "Chunk at (2,1) should not unload")
	var chunk_22 := chunk_data.get_chunk_at(Vector2i(2, 2))
	assert_true(strategy.should_unload_chunk(chunk_22, camera_pos, context), "Chunk at (2,2) should unload")

func test_load_priority_closer_chunks_higher():
	var camera_pos := Vector3(110, 10, 110)
	var chunk_00 := chunk_data.get_chunk_at(Vector2i(0, 0))
	var chunk_11 := chunk_data.get_chunk_at(Vector2i(1, 1))
	var priority_00 := strategy.get_load_priority(chunk_00, camera_pos)
	var priority_11 := strategy.get_load_priority(chunk_11, camera_pos)
	assert_gt(priority_11, priority_00, "Closer chunk should have higher priority")

func test_world_pos_to_chunk_coord_conversion():
	var coord_center := strategy._world_pos_to_chunk_coord(Vector3(50, 0, 50))
	assert_eq(coord_center, Vector2i(0, 0), "Center of chunk (0,0) should map to (0,0)")
	var coord_11 := strategy._world_pos_to_chunk_coord(Vector3(150, 0, 150))
	assert_eq(coord_11, Vector2i(1, 1), "Center of chunk (1,1) should map to (1,1)")
	var coord_neg := strategy._world_pos_to_chunk_coord(Vector3(-50, 0, -50))
	assert_eq(coord_neg, Vector2i(-1, -1), "Negative coords should work correctly")

func test_get_max_operations_per_frame():
	strategy.max_loads_per_frame = 5
	strategy.max_unloads_per_frame = 10
	var ops := strategy.get_max_operations_per_frame()
	assert_eq(ops.x, 5, "Should return correct max loads")
	assert_eq(ops.y, 10, "Should return correct max unloads")

func test_chunk_distance_calculation():
	var dist_1 := strategy._chunk_distance(Vector2i(0, 0), Vector2i(2, 2))
	assert_eq(dist_1, 4, "Manhattan distance from (0,0) to (2,2) should be 4")
	var dist_2 := strategy._chunk_distance(Vector2i(1, 1), Vector2i(1, 3))
	assert_eq(dist_2, 2, "Manhattan distance from (1,1) to (1,3) should be 2")
	var dist_3 := strategy._chunk_distance(Vector2i(-1, -1), Vector2i(1, 1))
	assert_eq(dist_3, 4, "Manhattan distance from (-1,-1) to (1,1) should be 4")

func test_strategy_configuration_creates_correct_strategy():
	var config := GridLoadStrategyConfiguration.new()
	config.load_radius = 5
	config.unload_radius = 7
	config.max_chunks_load_per_frame = 3
	config.max_chunks_unload_per_frame = 6
	var created_strategy := config.get_strategy()
	assert_not_null(created_strategy, "Strategy should be created")
	assert_true(created_strategy is GridLoadStrategy, "Should create GridLoadStrategy instance")
	var grid_strategy := created_strategy as GridLoadStrategy
	assert_eq(grid_strategy.load_radius, 5, "Load radius should match config")
	assert_eq(grid_strategy.unload_radius, 7, "Unload radius should match config")
	assert_eq(grid_strategy.max_loads_per_frame, 3, "Max loads should match config")
	assert_eq(grid_strategy.max_unloads_per_frame, 6, "Max unloads should match config")

func test_configuration_validation():
	var config := GridLoadStrategyConfiguration.new()
	config.load_radius = 3
	config.unload_radius = 5
	assert_true(config.is_valid(), "Valid configuration should pass validation")
	config.load_radius = 5
	config.unload_radius = 3
	assert_false(config.is_valid(), "Invalid configuration should fail validation")
	config.load_radius = 0
	config.unload_radius = 5
	assert_false(config.is_valid(), "Zero load radius should fail validation")
