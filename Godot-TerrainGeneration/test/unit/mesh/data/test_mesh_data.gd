extends GutTest

var test_mesh_data: MeshData
var test_vertices: PackedVector3Array
var test_indices: PackedInt32Array
var test_uvs: PackedVector2Array

func before_each():
	test_vertices = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(1, 0, 0),
		Vector3(0, 0, 1), Vector3(1, 0, 1)
	])
	test_indices = PackedInt32Array([0, 2, 1, 1, 2, 3])
	test_uvs = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),
		Vector2(0, 1), Vector2(1, 1)
	])

func after_each():
	test_mesh_data = null

func test_construction_with_empty_arrays():
	test_mesh_data = MeshData.new()
	assert_not_null(test_mesh_data, "Should create valid MeshData")
	assert_eq(test_mesh_data.vertices.size(), 0, "Should have empty vertices")
	assert_eq(test_mesh_data.indices.size(), 0, "Should have empty indices")
	assert_eq(test_mesh_data.uvs.size(), 0, "Should have empty uvs")

func test_construction_with_valid_data():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_not_null(test_mesh_data, "Should create valid MeshData")
	assert_eq(test_mesh_data.vertices.size(), 4, "Should have 4 vertices")
	assert_eq(test_mesh_data.indices.size(), 6, "Should have 6 indices")
	assert_eq(test_mesh_data.uvs.size(), 4, "Should have 4 UVs")

func test_construction_stores_arrays():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.vertices, test_vertices, "Should store vertices")
	assert_eq(test_mesh_data.indices, test_indices, "Should store indices")
	assert_eq(test_mesh_data.uvs, test_uvs, "Should store UVs")
	assert_eq(test_mesh_data.vertices.size(), test_vertices.size(), "Vertex count should match")
	assert_eq(test_mesh_data.indices.size(), test_indices.size(), "Index count should match")
	assert_eq(test_mesh_data.uvs.size(), test_uvs.size(), "UV count should match")
	assert_eq(test_mesh_data.vertices.size(), test_mesh_data.uvs.size(), "Should have one UV per vertex")

func test_default_values():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.width, 0, "Should default width to 0")
	assert_eq(test_mesh_data.height, 0, "Should default height to 0")
	assert_eq(test_mesh_data.mesh_size, Vector2.ZERO, "Should default mesh_size to ZERO")
	assert_eq(test_mesh_data.elapsed_time_ms, 0.0, "Should default elapsed_time_ms to 0")
	assert_eq(test_mesh_data.processor_type, "", "Should default processor_type to empty string")

func test_get_vertex_count():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.get_vertex_count(), 4, "Should return correct vertex count")

func test_get_vertex_count_empty():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.get_vertex_count(), 0, "Should return 0 for empty mesh")

func test_get_triangle_count():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.get_triangle_count(), 2, "Should return correct triangle count")
	var expected := test_indices.size() / 3
	assert_eq(test_mesh_data.get_triangle_count(), expected, "Should equal indices.size() / 3")
	assert_eq(test_indices.size() % 3, 0, "Indices should form complete triangles")

func test_get_triangle_count_empty():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.get_triangle_count(), 0, "Should return 0 for empty mesh")

func test_is_valid_index_with_valid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_true(test_mesh_data.is_valid_index(0), "Index 0 should be valid")
	assert_true(test_mesh_data.is_valid_index(3), "Index 3 should be valid")

func test_is_valid_index_with_negative_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_false(test_mesh_data.is_valid_index(-1), "Negative index should be invalid")

func test_is_valid_index_with_out_of_bounds_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_false(test_mesh_data.is_valid_index(4), "Out of bounds index should be invalid")
	assert_false(test_mesh_data.is_valid_index(100), "Large out of bounds index should be invalid")
	var last_valid := test_vertices.size() - 1
	assert_true(test_mesh_data.is_valid_index(last_valid), "Last index should be valid")
	assert_false(test_mesh_data.is_valid_index(last_valid + 1), "Index just past end should be invalid")

func test_get_vertex_with_valid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var vertex := test_mesh_data.get_vertex(0)
	assert_eq(vertex, Vector3(0, 0, 0), "Should return correct vertex")

func test_get_vertex_with_invalid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var vertex := test_mesh_data.get_vertex(10)
	assert_engine_error("MeshData: Invalid vertex index")
	assert_eq(vertex, Vector3.ZERO, "Should return ZERO for invalid index")

func test_get_vertex_all_vertices():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.get_vertex(0), Vector3(0, 0, 0), "Vertex 0")
	assert_eq(test_mesh_data.get_vertex(1), Vector3(1, 0, 0), "Vertex 1")
	assert_eq(test_mesh_data.get_vertex(2), Vector3(0, 0, 1), "Vertex 2")
	assert_eq(test_mesh_data.get_vertex(3), Vector3(1, 0, 1), "Vertex 3")
	var v0 := test_mesh_data.get_vertex(0)
	var v1 := test_mesh_data.get_vertex(1)
	var v2 := test_mesh_data.get_vertex(2)
	var v3 := test_mesh_data.get_vertex(3)
	assert_eq(v0.y, 0.0, "Vertex 0 Y should be 0")
	assert_eq(v1.y, 0.0, "Vertex 1 Y should be 0")
	assert_eq(v2.y, 0.0, "Vertex 2 Y should be 0")
	assert_eq(v3.y, 0.0, "Vertex 3 Y should be 0")

func test_get_height_returns_y_component():
	var vertices := PackedVector3Array([Vector3(0, 5.5, 0)])
	test_mesh_data = MeshData.new(vertices, PackedInt32Array(), PackedVector2Array())
	var height := test_mesh_data.get_height(0)
	assert_eq(height, 5.5, "Should return Y component as height")

func test_get_height_with_invalid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var height := test_mesh_data.get_height(100)
	assert_eq(height, 0.0, "Should return 0 for invalid index")

func test_grid_metadata_can_be_set():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	test_mesh_data.width = 10
	test_mesh_data.height = 20
	assert_eq(test_mesh_data.width, 10, "Should store width")
	assert_eq(test_mesh_data.height, 20, "Should store height")

func test_mesh_size_can_be_set():
	test_mesh_data = MeshData.new()
	test_mesh_data.mesh_size = Vector2(512.0, 1024.0)
	assert_eq(test_mesh_data.mesh_size, Vector2(512.0, 1024.0), "Should store mesh_size")

func test_generation_metadata_can_be_set():
	test_mesh_data = MeshData.new()
	test_mesh_data.elapsed_time_ms = 123.45
	test_mesh_data.processor_type = "GPU"
	assert_eq(test_mesh_data.elapsed_time_ms, 123.45, "Should store elapsed_time_ms")
	assert_eq(test_mesh_data.processor_type, "GPU", "Should store processor_type")

func test_cached_normals_defaults_to_empty():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.cached_normals.size(), 0, "Should default to empty cached_normals")

func test_cached_tangents_defaults_to_empty():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.cached_tangents.size(), 0, "Should default to empty cached_tangents")

func test_cached_normals_can_be_set():
	test_mesh_data = MeshData.new()
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP])
	test_mesh_data.cached_normals = normals
	assert_eq(test_mesh_data.cached_normals.size(), 2, "Should store cached_normals")
	assert_eq(test_mesh_data.cached_normals[0], Vector3.UP, "Should preserve normal values")

func test_cached_tangents_can_be_set():
	test_mesh_data = MeshData.new()
	var tangents := PackedVector4Array([Vector4(1, 0, 0, 1)])
	test_mesh_data.cached_tangents = tangents
	assert_eq(test_mesh_data.cached_tangents.size(), 1, "Should store cached_tangents")

func test_mismatched_vertex_uv_count_is_handled():
	# This is a potential bug - UVs and vertices should match
	var vertices := PackedVector3Array([Vector3.ZERO, Vector3.ONE])
	var uvs := PackedVector2Array([Vector2.ZERO])  # Only 1 UV for 2 vertices!
	var indices := PackedInt32Array([0, 1, 0])
	test_mesh_data = MeshData.new(vertices, indices, uvs)
	assert_ne(test_mesh_data.vertices.size(), test_mesh_data.uvs.size(), "Mismatch should be detectable")
	# This configuration may cause rendering issues

func test_indices_reference_valid_vertices():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var max_valid_index := test_vertices.size() - 1
	var all_indices_valid := true
	for idx in test_indices:
		if idx < 0 or idx > max_valid_index:
			all_indices_valid = false
			break
	assert_true(all_indices_valid, "All indices should reference valid vertices")

func test_height_values_are_correctly_extracted():
	var vertices_with_heights := PackedVector3Array([
		Vector3(0, 10.5, 0),   # Height = 10.5
		Vector3(1, 25.3, 1),   # Height = 25.3
		Vector3(2, -5.7, 2),   # Height = -5.7 (below sea level)
		Vector3(3, 0.0, 3)     # Height = 0.0 (sea level)
	])
	test_mesh_data = MeshData.new(vertices_with_heights, PackedInt32Array(), PackedVector2Array())
	
	assert_almost_eq(test_mesh_data.get_height(0), 10.5, 0.001, "Positive height")
	assert_almost_eq(test_mesh_data.get_height(1), 25.3, 0.001, "Higher terrain")
	assert_almost_eq(test_mesh_data.get_height(2), -5.7, 0.001, "Below sea level")
	assert_eq(test_mesh_data.get_height(3), 0.0, "Sea level")

func test_triangle_data_is_complete():
	# Every triangle needs exactly 3 indices
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_indices.size() % 3, 0, "Indices should form complete triangles")
	var triangle_count := test_indices.size() / 3
	assert_eq(test_mesh_data.get_triangle_count(), triangle_count, "Triangle count should match")
