extends GutTest

var shape: CylindricalTunnelShape

func before_each():
	shape = CylindricalTunnelShape.new(
		Vector3(0, 0, 0),
		-Vector3.FORWARD,
		3.0,
		20.0
	)

func test_constructor_sets_properties():
	assert_eq(shape.origin, Vector3(0, 0, 0), "Origin should match constructor")
	assert_eq(shape.direction, -Vector3.FORWARD, "Direction should be normalized")
	assert_eq(shape.radius, 3.0, "Radius should match constructor")
	assert_eq(shape.length, 20.0, "Length should match constructor")

func test_get_origin():
	assert_eq(shape.get_origin(), Vector3(0, 0, 0), "get_origin should return origin")

func test_get_direction():
	assert_eq(shape.get_direction(), -Vector3.FORWARD, "get_direction should return direction")

func test_get_length():
	assert_eq(shape.get_length(), 20.0, "get_length should return length")

func test_get_shape_type():
	assert_eq(shape.get_shape_type(), "Cylindrical", "Shape type should be Cylindrical")

func test_signed_distance_inside_cylinder():
	var point_inside := Vector3(0, 0, 10)
	var distance := shape.signed_distance(point_inside)
	assert_lt(distance, 0.0, "Point inside cylinder should have negative distance")

func test_signed_distance_outside_cylinder():
	var point_outside := Vector3(10, 0, 10)
	var distance := shape.signed_distance(point_outside)
	assert_gt(distance, 0.0, "Point outside cylinder should have positive distance")

func test_signed_distance_on_surface():
	var point_on_surface := Vector3(3.0, 0, 10)
	var distance := shape.signed_distance(point_on_surface)
	assert_almost_eq(distance, 0.0, 0.1, "Point on surface should have near-zero distance")

func test_signed_distance_before_cylinder_start():
	var point_before := Vector3(0, 0, -5)
	var distance := shape.signed_distance(point_before)
	assert_gt(distance, 0.0, "Point before cylinder should have positive distance")

func test_signed_distance_after_cylinder_end():
	var point_after := Vector3(0, 0, 25)
	var distance := shape.signed_distance(point_after)
	assert_gt(distance, 0.0, "Point after cylinder should have positive distance")

func test_get_debug_mesh():
	var debug_data := shape.get_debug_mesh()
	assert_eq(debug_data.size(), 2, "Debug mesh should return [mesh, transform]")
	assert_not_null(debug_data[0], "Debug mesh should not be null")
	assert_true(debug_data[0] is CylinderMesh, "Debug mesh should be CylinderMesh")
	assert_true(debug_data[1] is Transform3D, "Debug transform should be Transform3D")

func test_generate_interior_mesh_creates_vertices():
	var mock_terrain_query := func(xz: Vector2) -> float: return 50.0
	var mesh_data := shape.generate_interior_mesh(mock_terrain_query)
	assert_not_null(mesh_data, "Interior mesh should not be null")
	assert_gt(mesh_data.vertices.size(), 0, "Interior mesh should have vertices")
	assert_eq(mesh_data.vertices.size(), mesh_data.uvs.size(), "Vertices and UVs should match")

func test_generate_interior_mesh_creates_indices():
	var mock_terrain_query := func(xz: Vector2) -> float: return 50.0
	var mesh_data := shape.generate_interior_mesh(mock_terrain_query)
	
	assert_gt(mesh_data.indices.size(), 0, "Interior mesh should have indices")
	assert_eq(mesh_data.indices.size() % 3, 0, "Indices should form triangles")

func test_generate_interior_mesh_skips_above_ground():
	var mock_terrain_query := func(xz: Vector2) -> float: return -10.0
	var mesh_data := shape.generate_interior_mesh(mock_terrain_query)
	assert_eq(mesh_data.vertices.size(), 0, "Should skip above-ground geometry")

func test_get_collision_shape():
	var collision := shape.get_collision_shape()
	assert_not_null(collision, "Collision shape should not be null")
	assert_true(collision is Shape3D, "Collision should be Shape3D")

func test_get_shape_metadata():
	var metadata := shape.get_shape_metadata()
	assert_eq(metadata["type"], "Cylindrical", "Metadata should include type")
	assert_eq(metadata["origin"], Vector3.ZERO, "Metadata should include origin")
	assert_eq(metadata["direction"], -Vector3.FORWARD, "Metadata should include direction")
	assert_eq(metadata["length"], 20.0, "Metadata should include length")
	assert_eq(metadata["radius"], 3.0, "Metadata should include radius")

func test_non_vertical_tunnel():
	var angled_shape := CylindricalTunnelShape.new(
		Vector3(0, 0, 0),
		Vector3(1, 0, 1).normalized(),
		2.0,
		15.0
	)
	assert_almost_eq(angled_shape.direction.length(), 1.0, 0.01, "Direction should be normalized")

func test_vertical_tunnel():
	var vertical_shape := CylindricalTunnelShape.new(
		Vector3(0, 0, 0),
		Vector3.UP,
		2.0,
		15.0
	)
	assert_eq(vertical_shape.direction, Vector3.UP, "Vertical direction should be preserved")

