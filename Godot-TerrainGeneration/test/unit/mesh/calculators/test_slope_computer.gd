#extends GutTest
#
#var test_context_cpu: ProcessingContext
#var test_context_gpu: ProcessingContext
#var test_mesh_result: MeshGenerationResult
#
#func before_each():
#	test_context_cpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.CPU)
#	test_context_gpu = ProcessingContext.new(512.0, 42, ProcessingContext.ProcessorType.GPU)
#
#func after_each():
#	if test_context_cpu and not test_context_cpu._is_disposed:
#		test_context_cpu.dispose()
#	if test_context_gpu and not test_context_gpu._is_disposed:
#		test_context_gpu.dispose()
#	test_context_cpu = null
#	test_context_gpu = null
#	test_mesh_result = null
#
#func test_compute_slope_normal_map_rejects_null_mesh_result():
#	var result := SlopeComputer.compute_slope_normal_map(null, test_context_cpu)
#	assert_push_error("SlopeComputer: mesh_result is null")
#	assert_null(result, "Should return null for null mesh_result")
#
#func test_compute_slope_normal_map_rejects_zero_width():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	test_mesh_result.width = 0
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_push_error("SlopeComputer: mesh_result has invalid dimensions (0x10)")
#	assert_null(result, "Should return null for zero width")
#
#func test_compute_slope_normal_map_rejects_zero_height():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	test_mesh_result.height = 0
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_push_error("SlopeComputer: mesh_result has invalid dimensions (10x0)")
#	assert_null(result, "Should return null for zero height")
#
#func test_compute_slope_normal_map_rejects_invalid_dimensions():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	test_mesh_result.width = 0
#	test_mesh_result.height = 0
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_push_error("SlopeComputer: mesh_result has invalid dimensions (0x0)")
#	assert_null(result, "Should return null for both dimensions zero")
#
#func test_compute_slope_normal_map_returns_image_for_valid_input():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_not_null(result, "Should return Image for valid input")
#	assert_true(result is Image, "Should return Image type")
#
#func test_returned_image_has_correct_format():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_eq(result.get_format(), Image.FORMAT_RGBAF, "Should use FORMAT_RGBAF (RGB=normal, A=slope)")
#
#func test_returned_image_matches_mesh_dimensions():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_eq(result.get_width(), 10, "Image width should match mesh width")
#	assert_eq(result.get_height(), 10, "Image height should match mesh height")
#
#func test_flat_terrain_has_zero_slope():
#	test_mesh_result = TestHelpers.create_linear_slope_mesh(5, 0.0)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var center_pixel := result.get_pixel(2, 2)
#	assert_almost_eq(center_pixel.a, 0.0, 0.01, "Flat terrain should have near-zero slope angle")
#	assert_almost_eq(center_pixel.r, 0.0, 0.1, "Normal X should be near 0 for flat terrain")
#	assert_almost_eq(center_pixel.b, 0.0, 0.1, "Normal Z should be near 0 for flat terrain")
#	assert_gt(center_pixel.g, 0.9, "Normal Y should point up for flat terrain")
#
#func test_steep_slope_has_high_angle():
#	test_mesh_result = TestHelpers.create_linear_slope_mesh(5, 10.0)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var center_pixel := result.get_pixel(2, 2)
#	assert_gt(center_pixel.a, 0.5, "Steep slope should have significant angle (>0.5 radians)")
#
#func test_steep_slope_has_same_slope_angle_across_rows():
#	test_mesh_result = TestHelpers.create_linear_slope_mesh(5, 10.0)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var first_row_angle := result.get_pixel(0, 2).a
#	for x in result.get_width():
#		var pixel := result.get_pixel(x, 2)
#		assert_almost_eq(pixel.a, first_row_angle, 0.01, "Slope angle should be consistent across row")
#
#func test_normals_are_normalized():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	for y in result.get_height():
#		for x in result.get_width():
#			var pixel := result.get_pixel(x, y)
#			var normal := Vector3(pixel.r, pixel.g, pixel.b)
#			var length := normal.length()
#			if length > 0.0:
#				assert_almost_eq(length, 1.0, 0.01, "Normal at (%d,%d) should be unit length" % [x, y])
#
#func test_slope_angles_are_valid_range():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	for y in result.get_height():
#		for x in result.get_width():
#			var pixel := result.get_pixel(x, y)
#			var slope_angle := pixel.a
#			assert_gte(slope_angle, 0.0, "Slope angle should be non-negative")
#			assert_lte(slope_angle, PI / 2.0, "Slope angle should not exceed 90 degrees (PI/2)")
#
#func test_edge_vertices_have_valid_data():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var corner_pixel := result.get_pixel(0, 0)
#	assert_not_null(corner_pixel, "Corner pixel should have data")
#	var edge_pixel := result.get_pixel(5, 0)
#	assert_not_null(edge_pixel, "Edge pixel should have data")
#
#func test_different_mesh_sizes_produce_correctly_sized_outputs():
#	var sizes := [[5, 5], [10, 10], [20, 15], [15, 20]]
#	for size in sizes:
#		test_mesh_result = TestHelpers.create_test_mesh_generation_result(size[0], size[1])
#		var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#		assert_eq(result.get_width(), size[0], "Width should match for %dx%d" % [size[0], size[1]])
#		assert_eq(result.get_height(), size[1], "Height should match for %dx%d" % [size[0], size[1]])
#
#func test_cpu_and_gpu_produce_similar_results():
#	if not test_context_gpu.heightmap_use_gpu():
#		pass_test("GPU not available, skipping GPU comparison")
#		return
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var cpu_result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var gpu_result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_gpu)
#	assert_eq(cpu_result.get_width(), gpu_result.get_width(), "CPU and GPU should produce same dimensions")
#	assert_eq(cpu_result.get_height(), gpu_result.get_height(), "CPU and GPU should produce same dimensions")
#
#func test_diagonal_slope_has_correct_normal_direction():
#	test_mesh_result = TestHelpers.create_linear_slope_mesh(5, 0.0, 0.0, 1.0)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var center_pixel := result.get_pixel(2, 2)
#	var normal := Vector3(center_pixel.r, center_pixel.g, center_pixel.b)
#	assert_gt(normal.length(), 0.9, "Normal should be non-zero for diagonal slope")
#
#func test_minimum_valid_grid_size():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(2, 2)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_not_null(result, "Should handle minimum 2x2 grid")
#	assert_eq(result.get_width(), 2, "Should produce 2x2 output")
#	assert_eq(result.get_height(), 2, "Should produce 2x2 output")
#
#func test_large_grid_completes_successfully():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(64, 64)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_not_null(result, "Should handle large 64x64 grid")
#	assert_eq(result.get_width(), 64, "Should produce correct dimensions")
#	assert_eq(result.get_height(), 64, "Should produce correct dimensions")
#
#func test_rectangular_grids_are_supported():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(20, 10)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_not_null(result, "Should handle rectangular grids")
#	assert_eq(result.get_width(), 20, "Width should match")
#	assert_eq(result.get_height(), 10, "Height should match")
#
#func test_inverted_rectangular_grids_are_supported():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 20)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	assert_not_null(result, "Should handle inverted rectangular grids")
#	assert_eq(result.get_width(), 10, "Width should match")
#	assert_eq(result.get_height(), 20, "Height should match")
#
#func test_consistent_results_across_multiple_calls():
#	test_mesh_result = TestHelpers.create_test_mesh_generation_result(10, 10)
#	var result1 := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var result2 := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var pixel1 := result1.get_pixel(5, 5)
#	var pixel2 := result2.get_pixel(5, 5)
#	assert_almost_eq(pixel1.r, pixel2.r, 0.001, "Results should be deterministic (normal X)")
#	assert_almost_eq(pixel1.g, pixel2.g, 0.001, "Results should be deterministic (normal Y)")
#	assert_almost_eq(pixel1.b, pixel2.b, 0.001, "Results should be deterministic (normal Z)")
#	assert_almost_eq(pixel1.a, pixel2.a, 0.001, "Results should be deterministic (slope angle)")
#
#func test_upward_slope_has_positive_normal_component():
#	test_mesh_result = TestHelpers.create_linear_slope_mesh(5, 2.0)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var center_pixel := result.get_pixel(2, 2)
#	assert_gt(center_pixel.g, 0.0, "Upward-facing normal should have positive Y component")
#
#func test_vertical_cliff_approaches_maximum_slope():
#	test_mesh_result = TestHelpers.create_linear_slope_mesh(5, 100.0)
#	var result := SlopeComputer.compute_slope_normal_map(test_mesh_result, test_context_cpu)
#	var center_pixel := result.get_pixel(2, 2)
#	assert_gt(center_pixel.a, 1.0, "Near-vertical slope should have angle > 1 radian (>57 degrees)")
