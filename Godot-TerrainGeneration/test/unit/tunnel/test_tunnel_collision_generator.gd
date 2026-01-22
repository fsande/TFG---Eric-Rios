extends GutTest

var collision_gen: TunnelCollisionGenerator
var mock_root: Node3D

func before_each():
	collision_gen = TunnelCollisionGenerator.new()
	mock_root = Node3D.new()
	add_child_autofree(mock_root)

func after_each():
	collision_gen = null
	mock_root = null

func test_generator_initializes_with_default_values():
	assert_eq(collision_gen.collision_layer, TunnelCollisionGenerator.DEFAULT_TUNNEL_LAYER)
	assert_eq(collision_gen.collision_mask, TunnelCollisionGenerator.DEFAULT_TUNNEL_MASK)
	assert_true(collision_gen.create_static_body, "Should create static body by default")

func test_add_tunnel_collision_with_null_mesh_returns_false():
	var result := collision_gen.add_tunnel_collision(null, mock_root)
	assert_push_error("Cannot create collision for empty mesh")
	assert_false(result, "Should fail with null mesh")

func test_add_tunnel_collision_with_empty_mesh_returns_false():
	var empty_mesh := MeshData.new()
	var result := collision_gen.add_tunnel_collision(empty_mesh, mock_root)
	assert_push_error("Cannot create collision for empty mesh")
	assert_false(result, "Should fail with empty mesh")

func test_add_tunnel_collision_with_null_root_returns_false():
	var mesh := TestHelpers.create_box_mesh()
	var result := collision_gen.add_tunnel_collision(mesh, null)
	assert_push_error("collision_root is null")
	assert_false(result, "Should fail with null root")

func test_add_tunnel_collision_creates_child_node():
	var mesh := TestHelpers.create_box_mesh()
	var initial_count := mock_root.get_child_count()
	collision_gen.add_tunnel_collision(mesh, mock_root)
	assert_eq(mock_root.get_child_count(), initial_count + 1, "Should add collision node")

func test_add_tunnel_collision_creates_static_body():
	var mesh := TestHelpers.create_box_mesh()
	collision_gen.add_tunnel_collision(mesh, mock_root)
	var child := mock_root.get_child(0)
	assert_true(child is StaticBody3D, "Should create StaticBody3D node")

func test_add_tunnel_collision_creates_collision_shape_child():
	var mesh := TestHelpers.create_box_mesh()
	collision_gen.add_tunnel_collision(mesh, mock_root)
	var static_body := mock_root.get_child(0)
	assert_eq(static_body.get_child_count(), 1, "StaticBody should have one child")
	var collision_shape := static_body.get_child(0)
	assert_true(collision_shape is CollisionShape3D, "Child should be CollisionShape3D")

func test_add_tunnel_collision_increments_counter():
	var mesh := TestHelpers.create_box_mesh()
	var initial_count := collision_gen.get_collision_shapes_created()
	collision_gen.add_tunnel_collision(mesh, mock_root)
	assert_eq(collision_gen.get_collision_shapes_created(), initial_count + 1, "Should increment counter")

func test_add_tunnel_collision_returns_true_on_success():
	var mesh := TestHelpers.create_box_mesh()
	var result := collision_gen.add_tunnel_collision(mesh, mock_root)
	assert_true(result, "Should return true on success")

func test_add_batch_collision_with_empty_array():
	var meshes: Array[MeshData] = []
	var count := collision_gen.add_batch_collision(meshes, mock_root)
	assert_eq(count, 0, "Should return 0 for empty array")

func test_add_batch_collision_with_multiple_meshes():
	var mesh1 := TestHelpers.create_box_mesh()
	var mesh2 := TestHelpers.create_box_mesh()
	var meshes: Array[MeshData] = [mesh1, mesh2]
	var count := collision_gen.add_batch_collision(meshes, mock_root)
	assert_eq(count, 2, "Should return count of successful creations")
	assert_eq(mock_root.get_child_count(), 2, "Should create two collision nodes")

func test_create_collision_shape_from_mesh_with_valid_mesh():
	var mesh := TestHelpers.create_box_mesh()
	var shape := collision_gen._create_collision_shape_from_mesh(mesh)
	assert_not_null(shape, "Should create collision shape")
	assert_true(shape is ConcavePolygonShape3D, "Should be ConcavePolygonShape3D")

func test_create_collision_shape_from_mesh_with_empty_mesh():
	var empty_mesh := MeshData.new()
	var shape := collision_gen._create_collision_shape_from_mesh(empty_mesh)
	assert_push_error("Empty mesh data")
	assert_null(shape, "Should return null for empty mesh")

func test_create_collision_shape_validates_indices():
	var mesh := MeshData.new()
	mesh.vertices = PackedVector3Array([Vector3(0, 0, 0)])
	mesh.uvs = PackedVector2Array([Vector2(0, 0)])
	mesh.indices = PackedInt32Array([0, 1, 2])
	var shape := collision_gen._create_collision_shape_from_mesh(mesh)
	assert_engine_error("Invalid index in triangle 0")
	assert_push_error("Insufficient faces for collision shape")
	assert_null(shape, "Should reject mesh with invalid indices")

func test_build_collision_node_creates_static_body():
	collision_gen.create_static_body = true
	var box_shape := BoxShape3D.new()
	var node := collision_gen._build_collision_node(box_shape, 0)
	autofree(node)
	assert_true(node is StaticBody3D, "Should create StaticBody3D")
	assert_eq(node.get_child_count(), 1, "Should have collision shape child")

func test_build_collision_node_creates_standalone_shape():
	collision_gen.create_static_body = false
	var box_shape := BoxShape3D.new()
	var node := collision_gen._build_collision_node(box_shape, 0)
	autofree(node)
	assert_true(node is CollisionShape3D, "Should create CollisionShape3D directly")

func test_build_collision_node_sets_collision_layers():
	collision_gen.collision_layer = 8
	collision_gen.collision_mask = 4
	var box_shape := BoxShape3D.new()
	var node := collision_gen._build_collision_node(box_shape, 0)
	autofree(node)
	assert_eq(node.collision_layer, 8, "Should set collision layer")
	assert_eq(node.collision_mask, 4, "Should set collision mask")

func test_get_collision_node_name_with_id():
	var name := collision_gen._get_collision_node_name("Body", 5)
	assert_string_contains(name, "5", "Name should include ID")
	assert_string_contains(name, "Body", "Name should include suffix")

func test_get_collision_node_name_without_id():
	var name := collision_gen._get_collision_node_name("Shape", -1)
	assert_string_contains(name, "Shape", "Name should include suffix")

func test_configure_collision_layers():
	collision_gen.configure_collision_layers(16, 32)
	assert_eq(collision_gen.collision_layer, 16, "Should set layer")
	assert_eq(collision_gen.collision_mask, 32, "Should set mask")

func test_set_collision_layer_bit_enables():
	collision_gen.collision_layer = 0
	collision_gen.set_collision_layer_bit(3, true)
	assert_eq(collision_gen.collision_layer, 1 << 3, "Should set bit 3")

func test_set_collision_layer_bit_disables():
	collision_gen.collision_layer = 0xFF
	collision_gen.set_collision_layer_bit(3, false)
	var expected := 0xFF & ~(1 << 3)
	assert_eq(collision_gen.collision_layer, expected, "Should clear bit 3")

func test_set_collision_mask_bit_enables():
	collision_gen.collision_mask = 0
	collision_gen.set_collision_mask_bit(5, true)
	assert_eq(collision_gen.collision_mask, 1 << 5, "Should set bit 5")

func test_set_collision_mask_bit_disables():
	collision_gen.collision_mask = 0xFF
	collision_gen.set_collision_mask_bit(5, false)
	var expected := 0xFF & ~(1 << 5)
	assert_eq(collision_gen.collision_mask, expected, "Should clear bit 5")

func test_set_collision_layer_bit_validates_range():
	collision_gen.set_collision_layer_bit(-1, true)
	collision_gen.set_collision_layer_bit(32, true)
	assert_push_error(2, "Invalid bit index")

func test_reset_statistics():
	var mesh := TestHelpers.create_box_mesh()
	collision_gen.add_tunnel_collision(mesh, mock_root)
	collision_gen.reset_statistics()
	assert_eq(collision_gen.get_collision_shapes_created(), 0, "Should reset counter")

func test_get_configuration_returns_dictionary():
	var config := collision_gen.get_configuration()
	assert_not_null(config, "Should return dictionary")
	assert_true(config.has("collision_layer"), "Should include layer")
	assert_true(config.has("collision_mask"), "Should include mask")
	assert_true(config.has("create_static_body"), "Should include body flag")
	assert_true(config.has("shapes_created"), "Should include counter")

func test_create_simplified_box_collision_for_cylindrical_shape():
	var shape := TestHelpers.create_test_tunnel_shape()
	var box := collision_gen.create_simplified_box_collision(shape)
	assert_not_null(box, "Should create box shape")
	assert_true(box is BoxShape3D, "Should be BoxShape3D")
	assert_eq(box.size.x, 6.0, "Width should be diameter")
	assert_eq(box.size.y, 6.0, "Height should be diameter")
	assert_eq(box.size.z, 20.0, "Depth should be length")

func test_create_simplified_box_collision_with_null_shape():
	var box := collision_gen.create_simplified_box_collision(null)
	assert_null(box, "Should return null for null shape")

func test_add_simplified_collision_creates_node():
	var shape := TestHelpers.create_test_tunnel_shape()
	var initial_count := mock_root.get_child_count()
	collision_gen.add_simplified_collision(shape, mock_root)
	assert_eq(mock_root.get_child_count(), initial_count + 1, "Should add collision node")

func test_add_simplified_collision_positions_at_tunnel_center():
	var shape := TestHelpers.create_test_tunnel_shape()
	collision_gen.add_simplified_collision(shape, mock_root)
	var static_body := mock_root.get_child(0) as StaticBody3D
	var expected_center := Vector3(0, 0, -10.0)
	assert_almost_eq(static_body.global_position.z, expected_center.z, 0.1, 
		"Should be positioned at tunnel center")

func test_compute_tunnel_transform_orients_correctly():
	var shape := TestHelpers.create_test_tunnel_shape(Vector3.ZERO, Vector3.RIGHT)
	var transform := collision_gen._compute_tunnel_transform(shape)
	assert_almost_eq(transform.origin.x, 10.0, 0.1, "Should be at half length")
	assert_almost_eq(transform.basis.z.x, 1.0, 0.1, "Should align Z with RIGHT")

func test_collision_shape_name_prefix_is_customizable():
	collision_gen.collision_shape_name_prefix = "CustomTunnel"
	var mesh := TestHelpers.create_box_mesh()
	collision_gen.add_tunnel_collision(mesh, mock_root, 7)
	var child := mock_root.get_child(0)
	var name_as_string: String = child.name;
	assert_string_contains(name_as_string, "CustomTunnel", "Name should use custom prefix")


