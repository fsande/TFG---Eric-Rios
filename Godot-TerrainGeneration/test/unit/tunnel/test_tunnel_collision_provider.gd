extends GutTest

var provider: TunnelCollisionProvider

func before_each():
	provider = TunnelCollisionProvider.new()

func test_create_collision_from_empty_mesh():
	var empty_mesh := MeshData.new()
	var shape := provider.create_collision_from_mesh(empty_mesh)
	assert_push_error("Empty mesh data, returning null shape")
	assert_null(shape, "Should return null for empty mesh")

func test_create_collision_from_valid_mesh():
	var mesh_data := MeshData.new()
	mesh_data.vertices = PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0)
	])
	mesh_data.indices = PackedInt32Array([0, 1, 2])
	mesh_data.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0, 1)
	])
	var shape := provider.create_collision_from_mesh(mesh_data)
	assert_not_null(shape, "Should create collision shape")
	assert_true(shape is ConcavePolygonShape3D, "Should be ConcavePolygonShape3D")

func test_create_collision_includes_all_triangles():
	var mesh_data := MeshData.new()
	mesh_data.vertices = PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(1, 1, 0)
	])
	mesh_data.indices = PackedInt32Array([
		0, 1, 2,
		1, 3, 2
	])
	mesh_data.uvs = PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(1, 1)
	])
	
	var shape := provider.create_collision_from_mesh(mesh_data) as ConcavePolygonShape3D
	var faces := shape.get_faces()
	assert_eq(faces.size(), 6, "Should have 6 vertices (2 triangles * 3 vertices)")

func test_get_collision_shape_abstract():
	var shape := provider.get_collision_shape()
	assert_push_error("TunnelCollisionProvider.get_collision_shape() must be overridden")
	assert_null(shape, "Abstract method should return null")

