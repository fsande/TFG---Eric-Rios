## @brief Unit tests for MeshPartitioner - Focus on chunk equivalence to original mesh
extends GutTest

var test_mesh_result: MeshGenerationResult

func before_each():
	test_mesh_result = _create_test_mesh(Vector2(200.0, 200.0), 10)

func after_each():
	test_mesh_result = null

func test_partition_with_null_or_empty_mesh():
	var chunks := MeshPartitioner.partition_mesh(null, Vector2(50.0, 50.0))
	assert_eq(chunks.size(), 0, "Null mesh should return empty array")
	var empty_mesh := MeshGenerationResult.new(PackedVector3Array(), PackedInt32Array(), PackedVector2Array(), 0.0, "CPU")
	empty_mesh.mesh_size = Vector2(100.0, 100.0)
	chunks = MeshPartitioner.partition_mesh(empty_mesh, Vector2(50.0, 50.0))
	assert_eq(chunks.size(), 0, "Empty mesh should return empty array")

func test_validate_small_mesh_large_chunks():
	var mesh := _create_test_mesh(Vector2(100.0, 100.0), 5)
	var chunk_size := Vector2(150.0, 150.0)
	var chunks := MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_partition(mesh, chunks, chunk_size)
	assert_true(validation.valid, "Partition should be valid")
	assert_true(validation.triangles.valid, "Triangles should be preserved")
	assert_true(validation.vertices.valid, "Vertices should be preserved")
	assert_true(validation.positions.valid, "World positions should be correct")
	gut.p("Small mesh: %d chunks, %.2f%% preservation, %.2fx duplication" % [chunks.size(), validation.triangles.preservation_ratio * 100.0, validation.vertices.duplication_ratio])

func test_validate_medium_mesh_medium_chunks():
	var mesh := _create_test_mesh(Vector2(300.0, 300.0), 20)
	var chunk_size := Vector2(100.0, 100.0)
	var chunks := MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_partition(mesh, chunks, chunk_size)
	assert_true(validation.valid, "Partition should be valid")
	assert_eq(validation.vertices.missing_positions, 0, "No vertex positions should be missing")
	assert_eq(validation.vertices.extra_positions, 0, "No extra vertex positions should exist")
	gut.p("Medium mesh: %d chunks, %d duplicated triangles, max pos error: %.3f" % [chunks.size(), validation.triangles.duplicate_triangles, validation.positions.max_position_error])

func test_validate_large_mesh_small_chunks():
	var mesh := _create_test_mesh(Vector2(500.0, 500.0), 50)
	var chunk_size := Vector2(50.0, 50.0)
	var chunks := MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_partition(mesh, chunks, chunk_size)
	assert_true(validation.valid, "Partition should be valid")
	assert_gt(validation.triangles.preservation_ratio, 0.99, "Should preserve >99% of triangles")
	gut.p("Large mesh: %d chunks, duplication ratio: %.2fx" % [chunks.size(), validation.vertices.duplication_ratio])

func test_validate_rectangular_mesh_and_chunks():
	var mesh := _create_test_mesh(Vector2(400.0, 200.0), 30)
	var chunk_size := Vector2(100.0, 50.0)
	var chunks := MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_partition(mesh, chunks, chunk_size)
	assert_true(validation.valid, "Partition should be valid for rectangular configuration")
	assert_eq(validation.vertices.missing_positions, 0, "All vertex positions should be preserved")
	assert_eq(validation.positions.position_errors.size(), 0, "All chunks should have correct positions")

func test_parametric_validation_suite():
	var configs := [
		{"mesh_size": Vector2(100.0, 100.0), "chunk_size": Vector2(50.0, 50.0), "subdivisions": 10},
		{"mesh_size": Vector2(200.0, 200.0), "chunk_size": Vector2(100.0, 100.0), "subdivisions": 20},
		{"mesh_size": Vector2(300.0, 300.0), "chunk_size": Vector2(75.0, 75.0), "subdivisions": 30},
		{"mesh_size": Vector2(400.0, 200.0), "chunk_size": Vector2(100.0, 50.0), "subdivisions": 25},
		{"mesh_size": Vector2(150.0, 150.0), "chunk_size": Vector2(150.0, 150.0), "subdivisions": 15},
	]
	for i in range(configs.size()):
		var config: Dictionary = configs[i]
		var mesh := _create_test_mesh(config.mesh_size, config.subdivisions)
		var chunks := MeshPartitioner.partition_mesh(mesh, config.chunk_size)
		var validation := _validate_partition(mesh, chunks, config.chunk_size)
		assert_true(validation.valid, "Config %d should be valid: mesh %v, chunks %v" % [i, config.mesh_size, config.chunk_size])
		assert_true(validation.triangles.valid, "Config %d: triangles preserved" % i)
		assert_true(validation.vertices.valid, "Config %d: vertices preserved" % i)
		assert_true(validation.positions.valid, "Config %d: positions correct" % i)
		gut.p("Config %d: %d chunks, %.2f%% preservation, %.2fx duplication" % [i, chunks.size(), validation.triangles.preservation_ratio * 100.0, validation.vertices.duplication_ratio])

func test_no_triangles_lost():
	var mesh := _create_test_mesh(Vector2(250.0, 250.0), 25)
	var chunk_size := Vector2(62.5, 62.5)
	var chunks := MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_triangle_preservation(mesh, chunks)
	assert_true(validation.valid, "Triangle preservation should be valid")
	assert_gte(validation.chunk_triangles, validation.original_triangles, "Chunk triangles (%d) should be >= original (%d)" % [validation.chunk_triangles, validation.original_triangles])
	var duplication_factor: float = validation.preservation_ratio
	assert_lte(duplication_factor, 1.5, "Duplication factor (%.2f) should be <= 1.5x" % duplication_factor)
	gut.p("Triangle preservation: %d original -> %d in chunks (%.2f%%)" % [validation.original_triangles, validation.chunk_triangles, validation.preservation_ratio * 100.0])

func test_vertex_positions_exact_preservation():
	var mesh := _create_test_mesh(Vector2(180.0, 180.0), 18)
	var chunk_size := Vector2(60.0, 60.0)
	var chunks := MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_vertex_position_preservation(mesh, chunks)
	assert_true(validation.valid, "Vertex position preservation should be valid")
	assert_eq(validation.missing_positions, 0, "No vertex positions should be missing")
	assert_eq(validation.extra_positions, 0, "No extra vertex positions should exist")
	assert_eq(validation.chunk_unique_positions, validation.original_unique_positions, "Unique position count should match")
	gut.p("Vertex preservation: %d original -> %d in chunks, %d unique positions" % [validation.original_vertex_count, validation.chunk_vertex_count, validation.chunk_unique_positions])

func test_world_positions_various_sizes():
	var test_cases := [
		{"mesh_size": Vector2(100.0, 100.0), "chunk_size": Vector2(50.0, 50.0)},
		{"mesh_size": Vector2(200.0, 200.0), "chunk_size": Vector2(100.0, 100.0)},
		{"mesh_size": Vector2(300.0, 150.0), "chunk_size": Vector2(75.0, 50.0)},
		{"mesh_size": Vector2(512.0, 512.0), "chunk_size": Vector2(128.0, 128.0)},
	]
	for i in range(test_cases.size()):
		var test_case: Dictionary = test_cases[i]
		var mesh := _create_test_mesh(test_case.mesh_size, 10)
		var chunks := MeshPartitioner.partition_mesh(mesh, test_case.chunk_size)
		var validation := _validate_world_positions(mesh, chunks, test_case.chunk_size)
		assert_true(validation.valid, "Case %d: World positions should be valid" % i)
		assert_eq(validation.position_errors.size(), 0, "Case %d: No position errors expected" % i)
		assert_lte(validation.max_position_error, 0.1, "Case %d: Max error (%.3f) should be <= 0.1" % [i, validation.max_position_error])
		gut.p("Case %d: %d chunks, max error: %.4f" % [i, validation.chunk_count, validation.max_position_error])

func _validate_triangle_preservation(original: MeshGenerationResult, chunks: Array[ChunkMeshData]) -> Dictionary:
	var original_triangle_count := int(original.indices.size() / 3)
	var total_chunk_triangles := 0
	for chunk in chunks:
		total_chunk_triangles += chunk.mesh_data.get_triangle_count()
	var chunk_triangles := {}
	for chunk in chunks:
		for i in range(0, chunk.mesh_data.indices.size(), 3):
			var idx0 := chunk.mesh_data.indices[i]
			var idx1 := chunk.mesh_data.indices[i + 1]
			var idx2 := chunk.mesh_data.indices[i + 2]
			var v0 := chunk.mesh_data.vertices[idx0]
			var v1 := chunk.mesh_data.vertices[idx1]
			var v2 := chunk.mesh_data.vertices[idx2]
			var tri_key := _create_triangle_key(v0, v1, v2)
			chunk_triangles[tri_key] = chunk_triangles.get(tri_key, 0) + 1
	var duplicate_count := 0
	for count in chunk_triangles.values():
		if count > 1:
			duplicate_count += count - 1
	return {
		"valid": total_chunk_triangles >= original_triangle_count,
		"original_triangles": original_triangle_count,
		"chunk_triangles": total_chunk_triangles,
		"unique_triangles": chunk_triangles.size(),
		"duplicate_triangles": duplicate_count,
		"preservation_ratio": float(total_chunk_triangles) / float(original_triangle_count) if original_triangle_count > 0 else 0.0
	}

func _validate_vertex_position_preservation(original: MeshGenerationResult, chunks: Array[ChunkMeshData]) -> Dictionary:
	var original_vertex_count := original.vertices.size()
	var total_chunk_vertices := 0
	var original_positions := {}
	for v in original.vertices:
		var key := _create_vertex_key(v)
		original_positions[key] = true
	var chunk_positions := {}
	for chunk in chunks:
		total_chunk_vertices += chunk.mesh_data.vertices.size()
		for v in chunk.mesh_data.vertices:
			var key := _create_vertex_key(v)
			chunk_positions[key] = true
	var missing_positions := 0
	for pos_key in original_positions.keys():
		if not chunk_positions.has(pos_key):
			missing_positions += 1
	var extra_positions := 0
	for pos_key in chunk_positions.keys():
		if not original_positions.has(pos_key):
			extra_positions += 1
	return {
		"valid": missing_positions == 0 and extra_positions == 0,
		"original_vertex_count": original_vertex_count,
		"chunk_vertex_count": total_chunk_vertices,
		"original_unique_positions": original_positions.size(),
		"chunk_unique_positions": chunk_positions.size(),
		"missing_positions": missing_positions,
		"extra_positions": extra_positions,
		"duplication_ratio": float(total_chunk_vertices) / float(original_vertex_count) if original_vertex_count > 0 else 0.0
	}

func _validate_world_positions(original: MeshGenerationResult, chunks: Array[ChunkMeshData], chunk_size: Vector2) -> Dictionary:
	var mesh_size := original.mesh_size
	var origin_offset := Vector3(-mesh_size.x / 2.0, 0, -mesh_size.y / 2.0)
	var position_errors := []
	var max_position_error := 0.0
	for chunk in chunks:
		var coord := chunk.chunk_coord
		var actual_pos := chunk.world_position
		var expected_pos := origin_offset + Vector3(coord.x * chunk_size.x + chunk_size.x / 2.0, 0.0, coord.y * chunk_size.y + chunk_size.y / 2.0)
		var error := actual_pos.distance_to(expected_pos)
		max_position_error = max(max_position_error, error)
		if error > 0.1:
			position_errors.append({"coord": coord, "expected": expected_pos, "actual": actual_pos, "error": error})
	return {
		"valid": position_errors.size() == 0,
		"chunk_count": chunks.size(),
		"position_errors": position_errors,
		"max_position_error": max_position_error,
		"mesh_size": mesh_size,
		"chunk_size": chunk_size
	}

func _validate_partition(original: MeshGenerationResult, chunks: Array[ChunkMeshData], chunk_size: Vector2) -> Dictionary:
	var triangle_validation := _validate_triangle_preservation(original, chunks)
	var vertex_validation := _validate_vertex_position_preservation(original, chunks)
	var position_validation := _validate_world_positions(original, chunks, chunk_size)
	return {
		"valid": triangle_validation.valid and vertex_validation.valid and position_validation.valid,
		"triangles": triangle_validation,
		"vertices": vertex_validation,
		"positions": position_validation
	}

func _create_triangle_key(v0: Vector3, v1: Vector3, v2: Vector3) -> String:
	var vertices := [v0, v1, v2]
	vertices.sort_custom(func(a, b): 
		if abs(a.x - b.x) > 0.001: return a.x < b.x
		if abs(a.y - b.y) > 0.001: return a.y < b.y
		return a.z < b.z
	)
	return "%s_%s_%s" % [_create_vertex_key(vertices[0]), _create_vertex_key(vertices[1]), _create_vertex_key(vertices[2])]

func _create_vertex_key(v: Vector3, precision: int = 3) -> String:
	var multiplier := pow(10, precision)
	return "%d_%d_%d" % [int(round(v.x * multiplier)), int(round(v.y * multiplier)), int(round(v.z * multiplier))]

func _create_test_mesh(mesh_size: Vector2, subdivisions: int) -> MeshGenerationResult:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var step_x := mesh_size.x / float(subdivisions)
	var step_z := mesh_size.y / float(subdivisions)
	var offset_x := -mesh_size.x / 2.0
	var offset_z := -mesh_size.y / 2.0
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var pos := Vector3(offset_x + x * step_x, 0.0, offset_z + z * step_z)
			vertices.append(pos)
			var uv := Vector2(float(x) / float(subdivisions), float(z) / float(subdivisions))
			uvs.append(uv)
	for z in range(subdivisions):
		for x in range(subdivisions):
			var base_idx := z * (subdivisions + 1) + x
			indices.append(base_idx)
			indices.append(base_idx + subdivisions + 1)
			indices.append(base_idx + 1)
			indices.append(base_idx + 1)
			indices.append(base_idx + subdivisions + 1)
			indices.append(base_idx + subdivisions + 2)
	var result := MeshGenerationResult.new(vertices, indices, uvs, 0.0, "CPU")
	result.mesh_size = mesh_size
	result.width = subdivisions + 1
	result.height = subdivisions + 1
	return result

