extends GutTest

var clipper: TunnelInteriorClipper
var terrain_query: TerrainHeightQuerier

func before_each():
	clipper = TunnelInteriorClipper.new()
	terrain_query = TestHelpers.create_flat_terrain_query(10.0)

func after_each():
	clipper = null

func test_clipper_initializes_with_default_values():
	assert_eq(clipper.edge_intersection_tolerance, 0.01, "Should have default tolerance")
	assert_eq(clipper.interpolation_quality, 1, "Should have default quality")

func test_clip_empty_mesh_returns_empty():
	var empty_mesh := MeshData.new()
	var result := clipper.clip_to_terrain(empty_mesh, terrain_query)
	assert_eq(result.get_triangle_count(), 0, "Should return empty mesh")

func test_clip_fully_underground_triangle_is_kept():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_eq(result.get_triangle_count(), 1, "Underground triangle should be kept")

func test_clip_fully_above_ground_triangle_is_removed():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 15, 0),
		Vector3(1, 15, 0),
		Vector3(0.5, 15, 1)
	)
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_eq(result.get_triangle_count(), 0, "Above-ground triangle should be removed")

func test_clip_intersecting_triangle_creates_new_geometry():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 15, 0),
		Vector3(0.5, 5, 1)
	)
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_gt(result.get_vertex_count(), 0, "Should create clipped geometry")

func test_classify_triangle_fully_underground():
	var vertices := [
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	]
	var heights := [10.0, 10.0, 10.0]
	var classification := clipper._classify_triangle_vs_terrain(vertices, heights)
	assert_eq(classification, TunnelInteriorClipper.TriangleClass.FULLY_UNDERGROUND)

func test_classify_triangle_fully_above():
	var vertices := [
		Vector3(0, 15, 0),
		Vector3(1, 15, 0),
		Vector3(0.5, 15, 1)
	]
	var heights := [10.0, 10.0, 10.0]
	var classification := clipper._classify_triangle_vs_terrain(vertices, heights)
	assert_eq(classification, TunnelInteriorClipper.TriangleClass.FULLY_ABOVE)

func test_classify_triangle_intersecting():
	var vertices := [
		Vector3(0, 5, 0),
		Vector3(1, 15, 0),
		Vector3(0.5, 5, 1)
	]
	var heights := [10.0, 10.0, 10.0]
	var classification := clipper._classify_triangle_vs_terrain(vertices, heights)
	assert_eq(classification, TunnelInteriorClipper.TriangleClass.INTERSECTING)

func test_add_triangle_creates_three_vertices():
	var mesh := MeshData.new()
	clipper._add_triangle(
		mesh,
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0, 1)
	)
	assert_eq(mesh.get_vertex_count(), 3, "Should add three vertices")
	assert_eq(mesh.indices.size(), 3, "Should add three indices")

func test_compute_edge_terrain_intersection_finds_midpoint():
	var v0 := Vector3(0, 5, 0)
	var v1 := Vector3(0, 15, 0)
	var uv0 := Vector2(0, 0)
	var uv1 := Vector2(1, 1)
	var h0 := 10.0
	var h1 := 10.0
	var result := clipper._compute_edge_terrain_intersection(v0, v1, uv0, uv1, h0, h1)
	var intersection_pos: Vector3 = result[0]
	var intersection_uv: Vector2 = result[1]
	assert_almost_eq(intersection_pos.y, 10.0, 0.1, "Y should be at terrain height")
	assert_gt(intersection_uv.x, 0.0, "UV should be interpolated")

func test_compute_edge_terrain_intersection_handles_parallel_edge():
	var v0 := Vector3(0, 10, 0)
	var v1 := Vector3(0, 10, 10)
	var uv0 := Vector2(0, 0)
	var uv1 := Vector2(1, 1)
	var h0 := 10.0
	var h1 := 10.0
	var result := clipper._compute_edge_terrain_intersection(v0, v1, uv0, uv1, h0, h1)
	assert_not_null(result, "Should handle parallel edge case")

func test_statistics_track_processed_triangles():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	clipper.clip_to_terrain(mesh, terrain_query)
	var stats := clipper.get_statistics()
	assert_eq(stats["triangles_processed"], 1, "Should track processed count")

func test_statistics_track_kept_triangles():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	clipper.clip_to_terrain(mesh, terrain_query)
	var stats := clipper.get_statistics()
	assert_eq(stats["triangles_kept"], 1, "Should track kept count")

func test_statistics_track_discarded_triangles():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 15, 0),
		Vector3(1, 15, 0),
		Vector3(0.5, 15, 1)
	)
	clipper.clip_to_terrain(mesh, terrain_query)
	var stats := clipper.get_statistics()
	assert_eq(stats["triangles_discarded"], 1, "Should track discarded count")

func test_statistics_track_clipped_triangles():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 15, 0),
		Vector3(0.5, 5, 1)
	)
	clipper.clip_to_terrain(mesh, terrain_query)
	var stats := clipper.get_statistics()
	assert_eq(stats["triangles_clipped"], 1, "Should track clipped count")

func test_statistics_reset_between_operations():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	clipper.clip_to_terrain(mesh, terrain_query)
	clipper.clip_to_terrain(mesh, terrain_query)
	var stats := clipper.get_statistics()
	assert_eq(stats["triangles_processed"], 1, "Should reset stats for each operation")

func test_get_summary_string_returns_readable_format():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	clipper.clip_to_terrain(mesh, terrain_query)
	var summary := clipper.get_summary_string()
	assert_string_contains(summary, "kept", "Summary should mention kept triangles")

func test_clipped_mesh_preserves_mesh_size():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	mesh.mesh_size = Vector2(100, 100)
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_eq(result.mesh_size, Vector2(100, 100), "Should preserve mesh_size metadata")

func test_clipped_mesh_preserves_grid_dimensions():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1)
	)
	mesh.width = 10
	mesh.height = 10
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_eq(result.width, 10, "Should preserve width")
	assert_eq(result.height, 10, "Should preserve height")

func test_tolerance_affects_classification():
	clipper.edge_intersection_tolerance = 5.0
	var vertices := [
		Vector3(0, 10.1, 0),
		Vector3(1, 10.1, 0),
		Vector3(0.5, 10.1, 1)
	]
	var heights := [10.0, 10.0, 10.0]
	clipper.edge_intersection_tolerance = 0.5
	var classification := clipper._classify_triangle_vs_terrain(vertices, heights)
	assert_eq(classification, TunnelInteriorClipper.TriangleClass.FULLY_UNDERGROUND, 
		"Large tolerance should classify near-surface as underground")

func test_clip_multiple_triangles_mesh():
	var mesh := MeshData.new()
	mesh.vertices = PackedVector3Array([
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1),
		Vector3(2, 15, 0),
		Vector3(3, 15, 0),
		Vector3(2.5, 15, 1)
	])
	mesh.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0.5, 1),
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0.5, 1)
	])
	mesh.indices = PackedInt32Array([0, 1, 2, 3, 4, 5])
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_eq(result.get_triangle_count(), 1, "Should keep only underground triangle")

func test_clip_preserves_uv_coordinates():
	var mesh := TestHelpers.create_triangle_mesh(
		Vector3(0, 5, 0),
		Vector3(1, 5, 0),
		Vector3(0.5, 5, 1),
		Vector2(0.1, 0.2),
		Vector2(0.3, 0.4),
		Vector2(0.5, 0.6)
	)
	var result := clipper.clip_to_terrain(mesh, terrain_query)
	assert_eq(result.uvs.size(), result.vertices.size(), "UVs should match vertex count")


