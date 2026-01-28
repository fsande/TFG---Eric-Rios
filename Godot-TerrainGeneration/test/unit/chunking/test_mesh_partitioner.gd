## @brief Unit tests for MeshPartitioner - Focus on chunk equivalence to original mesh
extends GutTest

## Validation result data structure
class ValidationResult:
	var valid: bool
	var message: String
	
	func _init(p_valid: bool, p_message: String = "") -> void:
		valid = p_valid
		message = p_message

## Triangle validation data
class TriangleValidation:
	var valid: bool
	var original_triangles: int
	var chunk_triangles: int
	var unique_triangles: int
	var duplicate_triangles: int
	var preservation_ratio: float
	
	func _init() -> void:
		valid = false
		original_triangles = 0
		chunk_triangles = 0
		unique_triangles = 0
		duplicate_triangles = 0
		preservation_ratio = 0.0

## Vertex validation data
class VertexValidation:
	var valid: bool
	var original_vertex_count: int
	var chunk_vertex_count: int
	var original_unique_positions: int
	var chunk_unique_positions: int
	var missing_positions: int
	var extra_positions: int
	var duplication_ratio: float
	
	func _init() -> void:
		valid = false
		original_vertex_count = 0
		chunk_vertex_count = 0
		original_unique_positions = 0
		chunk_unique_positions = 0
		missing_positions = 0
		extra_positions = 0
		duplication_ratio = 0.0

## Position validation data
class PositionValidation:
	var valid: bool
	var chunk_count: int
	var position_errors: Array[Dictionary]
	var max_position_error: float
	var mesh_size: Vector2
	var chunk_size: Vector2
	
	func _init() -> void:
		valid = false
		chunk_count = 0
		position_errors = []
		max_position_error = 0.0
		mesh_size = Vector2.ZERO
		chunk_size = Vector2.ZERO

## Complete partition validation data
class PartitionValidation:
	var valid: bool
	var triangles: TriangleValidation
	var vertices: VertexValidation
	var positions: PositionValidation
	
	func _init(p_triangles: TriangleValidation, p_vertices: VertexValidation, p_positions: PositionValidation) -> void:
		triangles = p_triangles
		vertices = p_vertices
		positions = p_positions
		valid = triangles.valid and vertices.valid and positions.valid

var test_mesh_result: MeshGenerationResult

func before_each() -> void:
	test_mesh_result = _create_test_mesh(Vector2(200.0, 200.0), 10)

func after_each() -> void:
	test_mesh_result = null

func test_partition_with_null_or_empty_mesh() -> void:
	var chunks: Array[ChunkMeshData] = MeshPartitioner.partition_mesh(null, Vector2(50.0, 50.0))
	assert_eq(chunks.size(), 0, "Null mesh should return empty array")
	var empty_mesh := MeshGenerationResult.new(PackedVector3Array(), PackedInt32Array(), PackedVector2Array(), 0.0, "CPU")
	empty_mesh.mesh_size = Vector2(100.0, 100.0)
	chunks = MeshPartitioner.partition_mesh(empty_mesh, Vector2(50.0, 50.0))
	assert_engine_error(2, "Cannot partition empty mesh")
	assert_eq(chunks.size(), 0, "Empty mesh should return empty array")

func test_validate_small_mesh_large_chunks() -> void:
	var validation := _test_partition_config(Vector2(100.0, 100.0), Vector2(150.0, 150.0), 5)
	_assert_partition_valid(validation, "Small mesh with large chunks")
	gut.p("Small mesh: %d chunks, %.2f%% preservation, %.2fx duplication" % [
		validation.positions.chunk_count, 
		validation.triangles.preservation_ratio * 100.0, 
		validation.vertices.duplication_ratio
	])

func test_validate_medium_mesh_medium_chunks() -> void:
	var validation := _test_partition_config(Vector2(300.0, 300.0), Vector2(100.0, 100.0), 20)
	_assert_partition_valid(validation, "Medium mesh with medium chunks")
	assert_eq(validation.vertices.missing_positions, 0, "No vertex positions should be missing")
	assert_eq(validation.vertices.extra_positions, 0, "No extra vertex positions should exist")
	gut.p("Medium mesh: %d chunks, %d duplicated triangles, max pos error: %.3f" % [
		validation.positions.chunk_count, 
		validation.triangles.duplicate_triangles, 
		validation.positions.max_position_error
	])

func test_validate_large_mesh_small_chunks() -> void:
	var validation := _test_partition_config(Vector2(500.0, 500.0), Vector2(50.0, 50.0), 50)
	_assert_partition_valid(validation, "Large mesh with small chunks")
	assert_gt(validation.triangles.preservation_ratio, 0.99, "Should preserve >99% of triangles")
	gut.p("Large mesh: %d chunks, duplication ratio: %.2fx" % [
		validation.positions.chunk_count, 
		validation.vertices.duplication_ratio
	])

func test_validate_rectangular_mesh_and_chunks() -> void:
	var validation := _test_partition_config(Vector2(400.0, 200.0), Vector2(100.0, 50.0), 30)
	_assert_partition_valid(validation, "Rectangular configuration")
	assert_eq(validation.vertices.missing_positions, 0, "All vertex positions should be preserved")
	assert_eq(validation.positions.position_errors.size(), 0, "All chunks should have correct positions")

func test_parametric_validation_suite() -> void:
	var configs: Array[Dictionary] = [
		{"mesh_size": Vector2(100.0, 100.0), "chunk_size": Vector2(50.0, 50.0), "subdivisions": 10},
		{"mesh_size": Vector2(200.0, 200.0), "chunk_size": Vector2(100.0, 100.0), "subdivisions": 20},
		{"mesh_size": Vector2(300.0, 300.0), "chunk_size": Vector2(75.0, 75.0), "subdivisions": 30},
		{"mesh_size": Vector2(400.0, 200.0), "chunk_size": Vector2(100.0, 50.0), "subdivisions": 25},
		{"mesh_size": Vector2(150.0, 150.0), "chunk_size": Vector2(150.0, 150.0), "subdivisions": 15},
	]
	for i in range(configs.size()):
		var config: Dictionary = configs[i]
		var validation := _test_partition_config(
			config.mesh_size, 
			config.chunk_size, 
			config.subdivisions
		)
		_assert_partition_valid(validation, "Config %d: mesh %v, chunks %v" % [i, config.mesh_size, config.chunk_size])
		gut.p("Config %d: %d chunks, %.2f%% preservation, %.2fx duplication" % [
			i, 
			validation.positions.chunk_count, 
			validation.triangles.preservation_ratio * 100.0, 
			validation.vertices.duplication_ratio
		])

func test_no_triangles_lost() -> void:
	var mesh := _create_test_mesh(Vector2(250.0, 250.0), 25)
	var chunk_size := Vector2(62.5, 62.5)
	var chunks: Array[ChunkMeshData] = MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_triangle_preservation(mesh, chunks)
	assert_true(validation.valid, "Triangle preservation should be valid")
	assert_gte(validation.chunk_triangles, validation.original_triangles, 
		"Chunk triangles (%d) should be >= original (%d)" % [validation.chunk_triangles, validation.original_triangles])
	assert_lte(validation.preservation_ratio, 1.5, 
		"Duplication factor (%.2f) should be <= 1.5x" % validation.preservation_ratio)
	gut.p("Triangle preservation: %d original -> %d in chunks (%.2f%%)" % [
		validation.original_triangles, 
		validation.chunk_triangles, 
		validation.preservation_ratio * 100.0
	])

func test_vertex_positions_exact_preservation() -> void:
	var mesh := _create_test_mesh(Vector2(180.0, 180.0), 18)
	var chunk_size := Vector2(60.0, 60.0)
	var chunks: Array[ChunkMeshData] = MeshPartitioner.partition_mesh(mesh, chunk_size)
	var validation := _validate_vertex_position_preservation(mesh, chunks)
	assert_true(validation.valid, "Vertex position preservation should be valid")
	assert_eq(validation.missing_positions, 0, "No vertex positions should be missing")
	assert_eq(validation.extra_positions, 0, "No extra vertex positions should exist")
	assert_eq(validation.chunk_unique_positions, validation.original_unique_positions, 
		"Unique position count should match")
	gut.p("Vertex preservation: %d original -> %d in chunks, %d unique positions" % [
		validation.original_vertex_count, 
		validation.chunk_vertex_count, 
		validation.chunk_unique_positions
	])

func test_world_positions_various_sizes() -> void:
	var test_cases: Array[Dictionary] = [
		{"mesh_size": Vector2(100.0, 100.0), "chunk_size": Vector2(50.0, 50.0)},
		{"mesh_size": Vector2(200.0, 200.0), "chunk_size": Vector2(100.0, 100.0)},
		{"mesh_size": Vector2(300.0, 150.0), "chunk_size": Vector2(75.0, 50.0)},
		{"mesh_size": Vector2(512.0, 512.0), "chunk_size": Vector2(128.0, 128.0)},
	]
	for i in range(test_cases.size()):
		var test_case: Dictionary = test_cases[i]
		var mesh := _create_test_mesh(test_case.mesh_size, 10)
		var chunks: Array[ChunkMeshData] = MeshPartitioner.partition_mesh(mesh, test_case.chunk_size)
		var validation := _validate_world_positions(mesh, chunks, test_case.chunk_size)
		assert_true(validation.valid, "Case %d: World positions should be valid" % i)
		assert_eq(validation.position_errors.size(), 0, "Case %d: No position errors expected" % i)
		assert_lte(validation.max_position_error, 0.1, 
			"Case %d: Max error (%.3f) should be <= 0.1" % [i, validation.max_position_error])
		gut.p("Case %d: %d chunks, max error: %.4f" % [i, validation.chunk_count, validation.max_position_error])

func _test_partition_config(mesh_size: Vector2, chunk_size: Vector2, subdivisions: int) -> PartitionValidation:
	var mesh := _create_test_mesh(mesh_size, subdivisions)
	var chunks: Array[ChunkMeshData] = MeshPartitioner.partition_mesh(mesh, chunk_size)
	return _validate_partition(mesh, chunks, chunk_size)

func _assert_partition_valid(validation: PartitionValidation, context: String) -> void:
	assert_true(validation.valid, "%s: Partition should be valid" % context)
	assert_true(validation.triangles.valid, "%s: Triangles should be preserved" % context)
	assert_true(validation.vertices.valid, "%s: Vertices should be preserved" % context)
	assert_true(validation.positions.valid, "%s: World positions should be correct" % context)

func _validate_triangle_preservation(original: MeshGenerationResult, chunks: Array[ChunkMeshData]) -> TriangleValidation:
	var result := TriangleValidation.new()
	result.original_triangles = int(original.indices.size() / 3)
	for chunk in chunks:
		result.chunk_triangles += chunk.mesh_data.get_triangle_count()
	var chunk_triangle_counts: Dictionary = {}
	for chunk in chunks:
		for i in range(0, chunk.mesh_data.indices.size(), 3):
			var idx0 := chunk.mesh_data.indices[i]
			var idx1 := chunk.mesh_data.indices[i + 1]
			var idx2 := chunk.mesh_data.indices[i + 2]
			var v0 := chunk.mesh_data.vertices[idx0] + chunk.world_position
			var v1 := chunk.mesh_data.vertices[idx1] + chunk.world_position
			var v2 := chunk.mesh_data.vertices[idx2] + chunk.world_position
			var tri_key := _create_triangle_key(v0, v1, v2)
			chunk_triangle_counts[tri_key] = chunk_triangle_counts.get(tri_key, 0) + 1
	result.unique_triangles = chunk_triangle_counts.size()
	for count in chunk_triangle_counts.values():
		if count > 1:
			result.duplicate_triangles += count - 1
	result.preservation_ratio = float(result.chunk_triangles) / float(result.original_triangles) if result.original_triangles > 0 else 0.0
	result.valid = result.chunk_triangles >= result.original_triangles
	return result

func _validate_vertex_position_preservation(original: MeshGenerationResult, chunks: Array[ChunkMeshData]) -> VertexValidation:
	var result := VertexValidation.new()
	result.original_vertex_count = original.vertices.size()
	var original_positions: Dictionary = {}
	for v in original.vertices:
		var key := _create_vertex_key(v)
		original_positions[key] = true
	result.original_unique_positions = original_positions.size()
	var chunk_positions: Dictionary = {}
	for chunk in chunks:
		result.chunk_vertex_count += chunk.mesh_data.vertices.size()
		for v in chunk.mesh_data.vertices:
			var world_pos := v + chunk.world_position
			var key := _create_vertex_key(world_pos)
			chunk_positions[key] = true
	result.chunk_unique_positions = chunk_positions.size()
	for pos_key in original_positions.keys():
		if not chunk_positions.has(pos_key):
			result.missing_positions += 1
	for pos_key in chunk_positions.keys():
		if not original_positions.has(pos_key):
			result.extra_positions += 1
	result.duplication_ratio = float(result.chunk_vertex_count) / float(result.original_vertex_count) if result.original_vertex_count > 0 else 0.0
	result.valid = result.missing_positions == 0 and result.extra_positions == 0
	if not result.valid:
		push_warning("Vertex position validation failed: Missing: %d, Extra: %d" % [result.missing_positions, result.extra_positions])
	return result

func _validate_world_positions(original: MeshGenerationResult, chunks: Array[ChunkMeshData], chunk_size: Vector2) -> PositionValidation:
	var result := PositionValidation.new()
	result.mesh_size = original.mesh_size
	result.chunk_size = chunk_size
	result.chunk_count = chunks.size()
	var origin_offset := Vector3(-result.mesh_size.x / 2.0, 0, -result.mesh_size.y / 2.0)
	for chunk in chunks:
		var coord := chunk.chunk_coord
		var actual_pos := chunk.world_position
		var expected_pos := origin_offset + Vector3(
			coord.x * chunk_size.x + chunk_size.x / 2.0, 
			0.0, 
			coord.y * chunk_size.y + chunk_size.y / 2.0
		)
		var error := actual_pos.distance_to(expected_pos)
		result.max_position_error = max(result.max_position_error, error)
		if error > 0.1:
			result.position_errors.append({
				"coord": coord, 
				"expected": expected_pos, 
				"actual": actual_pos, 
				"error": error
			})
	result.valid = result.position_errors.size() == 0
	return result

func _validate_partition(original: MeshGenerationResult, chunks: Array[ChunkMeshData], chunk_size: Vector2) -> PartitionValidation:
	var triangle_validation := _validate_triangle_preservation(original, chunks)
	var vertex_validation := _validate_vertex_position_preservation(original, chunks)
	var position_validation := _validate_world_positions(original, chunks, chunk_size)
	return PartitionValidation.new(triangle_validation, vertex_validation, position_validation)

func _create_triangle_key(v0: Vector3, v1: Vector3, v2: Vector3) -> String:
	var vertices: Array[Vector3] = [v0, v1, v2]
	vertices.sort_custom(func(a: Vector3, b: Vector3) -> bool: 
		if abs(a.x - b.x) > 0.001: return a.x < b.x
		if abs(a.y - b.y) > 0.001: return a.y < b.y
		return a.z < b.z
	)
	return "%s_%s_%s" % [
		_create_vertex_key(vertices[0]), 
		_create_vertex_key(vertices[1]), 
		_create_vertex_key(vertices[2])
	]

func _create_vertex_key(v: Vector3, precision: int = 3) -> String:
	var multiplier := pow(10, precision)
	return "%d_%d_%d" % [
		int(round(v.x * multiplier)), 
		int(round(v.y * multiplier)), 
		int(round(v.z * multiplier))
	]

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

