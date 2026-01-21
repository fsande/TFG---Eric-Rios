extends GutTest

var shape: TunnelShape

func before_each():
	shape = CylindricalTunnelShape.new(
		Vector3.ZERO,
		Vector3.FORWARD,
		5.0,
		25.0
	)

func test_tunnel_shape_is_csg_volume():
	assert_true(shape is CSGVolume, "TunnelShape should extend CSGVolume")

func test_tunnel_shape_has_signed_distance():
	assert_has_method(shape, "signed_distance", "Should have signed_distance method")
	var dist := shape.signed_distance(Vector3.ZERO)
	assert_true(is_finite(dist), "signed_distance should return finite value")

func test_tunnel_shape_has_generate_interior_mesh():
	assert_has_method(shape, "generate_interior_mesh", "Should have generate_interior_mesh")

func test_tunnel_shape_has_get_collision_shape():
	assert_has_method(shape, "get_collision_shape", "Should have get_collision_shape")

func test_tunnel_shape_has_get_origin():
	assert_has_method(shape, "get_origin", "Should have get_origin")
	var origin := shape.get_origin()
	assert_true(origin is Vector3, "get_origin should return Vector3")

func test_tunnel_shape_has_get_direction():
	assert_has_method(shape, "get_direction", "Should have get_direction")
	var direction := shape.get_direction()
	assert_true(direction is Vector3, "get_direction should return Vector3")

func test_tunnel_shape_has_get_length():
	assert_has_method(shape, "get_length", "Should have get_length")
	var length := shape.get_length()
	assert_true(is_finite(length), "get_length should return finite value")

func test_tunnel_shape_has_get_shape_type():
	assert_has_method(shape, "get_shape_type", "Should have get_shape_type")
	var type := shape.get_shape_type()
	assert_true(type is String, "get_shape_type should return String")

func test_tunnel_shape_has_get_shape_metadata():
	assert_has_method(shape, "get_shape_metadata", "Should have get_shape_metadata")
	var metadata := shape.get_shape_metadata()
	assert_true(metadata is Dictionary, "get_shape_metadata should return Dictionary")

func test_metadata_contains_required_fields():
	var metadata := shape.get_shape_metadata()
	assert_true(metadata.has("type"), "Metadata should have type field")
	assert_true(metadata.has("origin"), "Metadata should have origin field")
	assert_true(metadata.has("direction"), "Metadata should have direction field")
	assert_true(metadata.has("length"), "Metadata should have length field")

func test_can_be_used_with_csg_operator():
	var operator := CSGBooleanOperator.new()
	assert_not_null(operator, "CSGBooleanOperator should be available")
	
	var simple_mesh := MeshData.new()
	simple_mesh.vertices = PackedVector3Array([
		Vector3(-10, -10, 0),
		Vector3(10, -10, 0),
		Vector3(0, 10, 0)
	])
	simple_mesh.indices = PackedInt32Array([0, 1, 2])
	simple_mesh.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0.5, 1)
	])
	simple_mesh.width = 1
	simple_mesh.height = 1
	simple_mesh.mesh_size = Vector2(20, 20)
	
	var result := operator.subtract_volume_from_mesh(simple_mesh, shape)
	assert_not_null(result, "CSG operation should return result")
