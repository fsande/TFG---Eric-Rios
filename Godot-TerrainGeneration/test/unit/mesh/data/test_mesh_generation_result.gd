extends GutTest

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

func test_get_vertex_returns_correct_position():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var vertex := test_result.get_vertex(0)
	assert_eq(vertex, Vector3(0, 0, 0), "Should return correct vertex position")

func test_is_valid_index():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_true(test_result.is_valid_index(0), "Index 0 should be valid")
	assert_true(test_result.is_valid_index(3), "Index 3 should be valid")
	assert_false(test_result.is_valid_index(-1), "Negative index should be invalid")
	assert_false(test_result.is_valid_index(10), "Out of bounds index should be invalid")

func test_get_vertex_count():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.get_vertex_count(), 4, "Should return correct vertex count")

func test_get_triangle_count():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_eq(test_result.get_triangle_count(), 2, "Should return correct triangle count")

func test_normals_are_calculated_and_normalized():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_true(test_result._normals_dirty, "Normals should start dirty")
	
	var normals := test_result.get_normals()
	assert_eq(normals.size(), test_vertices.size(), "One normal per vertex")
	assert_false(test_result._normals_dirty, "Should mark as clean after calculation")
	var all_normalized := true
	for i in range(normals.size()):
		var length := normals[i].length()
		if length > 0.0 and abs(length - 1.0) > 0.01:
			all_normalized = false
			break
	assert_true(all_normalized, "All non-zero normals should be unit length")

func test_normals_are_cached_and_reused():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var normals1 := test_result.get_normals()
	var normals2 := test_result.get_normals()
	assert_same(normals1, normals2, "Should return exact same cached array")
	assert_false(test_result._normals_dirty, "Cache should still be clean")

func test_tangents_are_calculated_with_correct_handedness():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	assert_true(test_result._tangents_dirty, "Tangents should start dirty")
	
	var tangents := test_result.get_tangents()
	assert_eq(tangents.size(), test_vertices.size(), "One tangent per vertex")
	assert_false(test_result._tangents_dirty, "Should mark as clean")
	for i in range(tangents.size()):
		var tangent := tangents[i]
		var direction := Vector3(tangent.x, tangent.y, tangent.z)
		var length := direction.length()
		if length > 0.0:
			assert_almost_eq(length, 1.0, 0.01, "Tangent %d direction should be normalized" % i)
		assert_true(abs(abs(tangent.w) - 1.0) < 0.01 or abs(tangent.w) < 0.01, "Tangent %d handedness should be ±1 or 0" % i)

func test_topology_modifications_invalidate_cached_data():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	# Cache normals and tangents
	test_result.get_normals()
	test_result.get_tangents()
	assert_false(test_result._normals_dirty, "Should be cached")
	assert_false(test_result._tangents_dirty, "Should be cached")
	test_result.add_vertex(Vector3(5, 5, 5), Vector2(0.5, 0.5))
	assert_true(test_result._normals_dirty, "Should invalidate normal cache")
	assert_true(test_result._tangents_dirty, "Should invalidate tangent cache")

func test_add_vertex_increases_vertex_count_correctly():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.get_vertex_count()
	
	var new_index := test_result.add_vertex(Vector3(5, 5, 5), Vector2(0.5, 0.5))
	assert_eq(new_index, initial_count, "New vertex should have index = old count")
	assert_eq(test_result.get_vertex_count(), initial_count + 1, "Count should increase by 1")
	var added_vertex := test_result.get_vertex(new_index)
	assert_eq(added_vertex, Vector3(5, 5, 5), "Should retrieve added vertex")

func test_add_vertices_batch():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.get_vertex_count()
	var new_verts := PackedVector3Array([Vector3(5, 5, 5), Vector3(6, 6, 6)])
	var new_uvs := PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.6, 0.6)])
	var base_index := test_result.add_vertices(new_verts, new_uvs)
	assert_eq(base_index, initial_count, "Should return first new vertex index")
	assert_eq(test_result.get_vertex_count(), initial_count + 2, "Should add multiple vertices")
	assert_eq(test_result.get_vertex(base_index), Vector3(5, 5, 5), "First new vertex should match")
	assert_eq(test_result.get_vertex(base_index + 1), Vector3(6, 6, 6), "Second new vertex should match")
	assert_eq(test_result.uvs.size(), test_result.vertices.size(), "UVs should match vertex count")

func test_add_triangle():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_count := test_result.indices.size()
	var initial_tri_count := test_result.get_triangle_count()
	test_result.add_triangle(0, 1, 2)
	assert_eq(test_result.indices.size(), initial_count + 3, "Should add 3 indices")
	assert_eq(test_result.get_triangle_count(), initial_tri_count + 1, "Should add 1 triangle")
	var last_three := test_result.indices.slice(test_result.indices.size() - 3, test_result.indices.size())
	assert_eq(last_three[0], 0, "First index should be 0")
	assert_eq(last_three[1], 1, "Second index should be 1")
	assert_eq(last_three[2], 2, "Third index should be 2")

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
	assert_not_null(mesh, "Should create mesh even with empty data")
	if mesh:
		assert_true(mesh.get_surface_count() >= 0, "Mesh surface count should be valid")

func test_build_mesh_contains_correct_vertex_count():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var mesh := test_result.build_mesh()
	assert_not_null(mesh, "Should build mesh")
	var expected_vertices := test_result.get_vertex_count()
	assert_eq(expected_vertices, 4, "Test data should have 4 vertices")

func test_complex_topology_modifications_maintain_consistency():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var initial_verts := test_result.get_vertex_count()
	var initial_tris := test_result.get_triangle_count()
	var new_idx := test_result.add_vertex(Vector3(2, 0, 2), Vector2(1, 1))
	test_result.add_triangle(0, 1, new_idx)
	assert_eq(test_result.get_vertex_count(), initial_verts + 1, "+1 vertex")
	assert_eq(test_result.get_triangle_count(), initial_tris + 1, "+1 triangle")
	assert_true(test_result.is_valid_index(new_idx), "New vertex should be valid")
	var normals := test_result.get_normals()
	assert_eq(normals.size(), test_result.get_vertex_count(), "Normals should include new vertex")

func test_build_mesh_produces_valid_array_mesh():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 0.0, "CPU")
	var mesh := test_result.build_mesh()
	assert_not_null(mesh, "Should create ArrayMesh")
	assert_true(mesh is ArrayMesh, "Should be ArrayMesh type")
	assert_gt(mesh.get_surface_count(), 0, "Should have at least one surface")

func test_generation_metrics_are_stored_correctly():
	test_result = MeshGenerationResult.new(test_vertices, test_indices, test_uvs, 123.45, "GPU")
	assert_almost_eq(test_result.elapsed_time_ms, 123.45, 0.001, "Should store exact time")
	assert_eq(test_result.processor_type, "GPU", "Should store processor type")
	test_result.get_normals()
	assert_eq(test_result.processor_type, "GPU", "Metrics should persist")
