extends GutTest

## Test suite for MeshGenerationResult
## File: terrain_generation/mesh/data/mesh_generation_result.gd

# ============================================================================
# SETUP / TEARDOWN
# ============================================================================

var test_result: MeshGenerationResult
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
	test_result = null

# ============================================================================
# CONSTRUCTION TESTS
# ============================================================================

func test_construction_with_required_parameters():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 123.45, "CPU")
	assert_not_null(test_result, "Should create valid MeshGenerationResult")
	assert_not_null(test_result.mesh_data, "Should create internal mesh_data")
	assert_eq(test_result.elapsed_time_ms, 123.45, "Should store elapsed time")
	assert_eq(test_result.processor_type, "CPU", "Should store processor type")

func test_construction_creates_internal_components():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_not_null(test_result.mesh_data, "Should create mesh_data")
	assert_not_null(test_result._topology_modifier, "Should create topology modifier")
	assert_not_null(test_result._slope_provider, "Should create slope provider")

# ============================================================================
# BACKWARD COMPATIBILITY - PROPERTY ACCESS
# ============================================================================

func test_vertices_property_delegates_to_mesh_data():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.vertices.size(), 4, "Should access vertices through property")
	assert_eq(test_result.vertices, test_vertices, "Should return same vertices")

func test_indices_property_delegates_to_mesh_data():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.indices.size(), 6, "Should access indices through property")
	assert_eq(test_result.indices, test_indices, "Should return same indices")

func test_uvs_property_delegates_to_mesh_data():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.uvs.size(), 4, "Should access UVs through property")
	assert_eq(test_result.uvs, test_uvs, "Should return same UVs")

func test_vertex_count_property():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.vertex_count, 4, "Should return correct vertex count")

func test_width_and_height_properties():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	test_result.width = 10
	test_result.height = 20
	assert_eq(test_result.width, 10, "Should store width")
	assert_eq(test_result.height, 20, "Should store height")

func test_mesh_size_property():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	test_result.mesh_size = Vector2(512.0, 512.0)
	assert_eq(test_result.mesh_size, Vector2(512.0, 512.0), "Should store mesh_size")

# ============================================================================
# VERTEX ACCESS METHODS
# ============================================================================

func test_get_vertex_returns_correct_position():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var vertex := test_result.get_vertex(0)
	assert_eq(vertex, Vector3(0, 0, 0), "Should return correct vertex position")

# ============================================================================
# INDEX VALIDATION
# ============================================================================

func test_is_valid_index():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_true(test_result.is_valid_index(0), "Index 0 should be valid")
	assert_true(test_result.is_valid_index(3), "Index 3 should be valid")
	assert_false(test_result.is_valid_index(-1), "Negative index should be invalid")
	assert_false(test_result.is_valid_index(10), "Out of bounds index should be invalid")

# ============================================================================
# COUNT METHODS
# ============================================================================

func test_get_vertex_count():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.get_vertex_count(), 4, "Should return correct vertex count")

func test_get_triangle_count():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.get_triangle_count(), 2, "Should return correct triangle count")

# ============================================================================
# NORMALS AND TANGENTS
# ============================================================================

func test_get_normals_calculates_on_first_call():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var normals := test_result.get_normals()
	assert_not_null(normals, "Should calculate normals")
	assert_gt(normals.size(), 0, "Should have normals")
	assert_false(test_result._normals_dirty, "Should mark normals as clean")

func test_get_normals_returns_cached_on_second_call():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var normals1 := test_result.get_normals()
	var normals2 := test_result.get_normals()
	assert_same(normals1, normals2, "Should return cached normals")

func test_get_normal_at_vertex():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var normal := test_result.get_normal_at_vertex(0)
	assert_not_null(normal, "Should return normal")
	assert_true(normal is Vector3, "Should return Vector3")

func test_get_tangents_calculates_on_first_call():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var tangents := test_result.get_tangents()
	assert_not_null(tangents, "Should calculate tangents")
	assert_gt(tangents.size(), 0, "Should have tangents")
	assert_false(test_result._tangents_dirty, "Should mark tangents as clean")

# ============================================================================
# MARK DIRTY
# ============================================================================

func test_mark_dirty_sets_flags():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	test_result._normals_dirty = false
	test_result._tangents_dirty = false
	test_result.mark_dirty()
	assert_true(test_result._normals_dirty, "Should mark normals dirty")
	assert_true(test_result._tangents_dirty, "Should mark tangents dirty")

# ============================================================================
# TOPOLOGY MODIFICATION
# ============================================================================

func test_add_vertex_returns_new_index():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.get_vertex_count()
	var new_index := test_result.add_vertex(Vector3(5, 5, 5), Vector2(0.5, 0.5))
	assert_eq(new_index, initial_count, "Should return index of new vertex")
	assert_eq(test_result.get_vertex_count(), initial_count + 1, "Should increase vertex count")

func test_add_vertex_marks_dirty():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	test_result._normals_dirty = false
	test_result.add_vertex(Vector3(1, 2, 3))
	assert_true(test_result._normals_dirty, "Should mark normals dirty")

func test_add_vertices_batch():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.get_vertex_count()
	var new_verts := PackedVector3Array([Vector3(5, 5, 5), Vector3(6, 6, 6)])
	var new_uvs := PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.6, 0.6)])
	var base_index := test_result.add_vertices(new_verts, new_uvs)
	assert_eq(base_index, initial_count, "Should return first new vertex index")
	assert_eq(test_result.get_vertex_count(), initial_count + 2, "Should add multiple vertices")

func test_add_triangle():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.indices.size()
	test_result.add_triangle(0, 1, 2)
	assert_eq(test_result.indices.size(), initial_count + 3, "Should add 3 indices")

func test_add_triangles_batch():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.indices.size()
	var new_indices := PackedInt32Array([0, 1, 2, 2, 1, 3])
	test_result.add_triangles(new_indices)
	assert_eq(test_result.indices.size(), initial_count + 6, "Should add multiple indices")

# ============================================================================
# MESH BUILDING
# ============================================================================

func test_build_mesh_creates_array_mesh():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var mesh := test_result.build_mesh()
	assert_not_null(mesh, "Should create ArrayMesh")
	assert_true(mesh is ArrayMesh, "Should return ArrayMesh type")

func test_build_mesh_with_empty_data():
	test_result = MeshGenerationResult.new(
		PackedVector3Array(),
		PackedInt32Array(),
		PackedVector2Array(),
		0.0,
		"CPU"
	)
	var mesh := test_result.build_mesh()
	print("Built mesh with empty data.")
	assert_not_null(mesh, "Should create mesh even with empty data")

# ============================================================================
# METADATA TESTS
# ============================================================================

func test_stores_generation_metrics():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 456.78, "GPU")
	assert_eq(test_result.elapsed_time_ms, 456.78, "Should store elapsed time")
	assert_eq(test_result.processor_type, "GPU", "Should store processor type")

func test_grid_metadata():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	test_result.width = 64
	test_result.height = 64
	test_result.mesh_size = Vector2(512.0, 512.0)
	assert_eq(test_result.width, 64, "Should store width")
	assert_eq(test_result.height, 64, "Should store height")
	assert_eq(test_result.mesh_size, Vector2(512.0, 512.0), "Should store mesh_size")
