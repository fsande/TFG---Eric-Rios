extends GutTest

## Test suite for MeshData
## File: terrain_generation/mesh/data/mesh_data.gd

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

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

# ============================================================================
# CONSTRUCTION TESTS
# ============================================================================
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

func test_default_values():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.width, 0, "Should default width to 0")
	assert_eq(test_mesh_data.height, 0, "Should default height to 0")
	assert_eq(test_mesh_data.mesh_size, Vector2.ZERO, "Should default mesh_size to ZERO")
	assert_eq(test_mesh_data.elapsed_time_ms, 0.0, "Should default elapsed_time_ms to 0")
	assert_eq(test_mesh_data.processor_type, "", "Should default processor_type to empty string")

# ============================================================================
# VERTEX COUNT TESTS
# ============================================================================

func test_get_vertex_count():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.get_vertex_count(), 4, "Should return correct vertex count")

func test_get_vertex_count_empty():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.get_vertex_count(), 0, "Should return 0 for empty mesh")

# ============================================================================
# TRIANGLE COUNT TESTS
# ============================================================================

func test_get_triangle_count():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.get_triangle_count(), 2, "Should return correct triangle count (6 indices / 3)")

func test_get_triangle_count_empty():
	test_mesh_data = MeshData.new()
	assert_eq(test_mesh_data.get_triangle_count(), 0, "Should return 0 for empty mesh")

# ============================================================================
# VERTEX INDEX VALIDATION TESTS
# ============================================================================

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

# ============================================================================
# GET VERTEX TESTS
# ============================================================================

func test_get_vertex_with_valid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var vertex := test_mesh_data.get_vertex(0)
	assert_eq(vertex, Vector3(0, 0, 0), "Should return correct vertex")

func test_get_vertex_with_invalid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var vertex := test_mesh_data.get_vertex(10)
	assert_engine_error("MeshData: Invalid vertex index 10")
	assert_eq(vertex, Vector3.ZERO, "Should return ZERO for invalid index")

func test_get_vertex_all_vertices():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	assert_eq(test_mesh_data.get_vertex(0), Vector3(0, 0, 0), "Vertex 0")
	assert_eq(test_mesh_data.get_vertex(1), Vector3(1, 0, 0), "Vertex 1")
	assert_eq(test_mesh_data.get_vertex(2), Vector3(0, 0, 1), "Vertex 2")
	assert_eq(test_mesh_data.get_vertex(3), Vector3(1, 0, 1), "Vertex 3")

# ============================================================================
# GET HEIGHT TESTS
# ============================================================================

func test_get_height_returns_y_component():
	var vertices := PackedVector3Array([Vector3(0, 5.5, 0)])
	test_mesh_data = MeshData.new(vertices, PackedInt32Array(), PackedVector2Array())
	var height := test_mesh_data.get_height(0)
	assert_eq(height, 5.5, "Should return Y component as height")

func test_get_height_with_invalid_index():
	test_mesh_data = MeshData.new(test_vertices, test_indices, test_uvs)
	var height := test_mesh_data.get_height(100)
	assert_eq(height, 0.0, "Should return 0 for invalid index")

# ============================================================================
# METADATA TESTS
# ============================================================================

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

# ============================================================================
# CACHED NORMALS AND TANGENTS TESTS
# ============================================================================

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
