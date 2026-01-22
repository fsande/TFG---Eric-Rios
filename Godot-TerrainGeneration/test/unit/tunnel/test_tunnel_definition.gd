extends GutTest

var entry_point: TunnelEntryPoint
var definition: TunnelDefinition

func before_each():
	entry_point = TunnelEntryPoint.new(
		Vector3(10, 50, 20),
		Vector3(1, 0, 0),
		deg_to_rad(45),
		Vector2(0.5, 0.5),
		128,
		128
	)
	definition = TunnelDefinition.create_cylindrical(entry_point, 3.0, 20.0)

func test_create_cylindrical():
	assert_not_null(definition, "Definition should be created")
	assert_not_null(definition.shape_parameters, "Shape parameters should be created")
	assert_true(definition.shape_parameters is CylindricalShapeParameters, "Should be cylindrical parameters")
	assert_eq(definition.get_shape_type(), TunnelShapeType.Type.CYLINDRICAL, "Shape type should be CYLINDRICAL")
	assert_eq(definition.entry_point, entry_point, "Entry point should match")

func test_create_cylindrical_sets_parameters():
	var params := definition.shape_parameters as CylindricalShapeParameters
	assert_not_null(params, "Parameters should be CylindricalShapeParameters")
	assert_eq(params.radius, 3.0, "Radius should be set")
	assert_eq(params.length, 20.0, "Length should be set")
	assert_eq(params.radial_segments, 16, "Radial segments should default")
	assert_eq(params.length_segments, 8, "Length segments should default")

func test_default_properties():
	assert_null(definition.tunnel_material, "Material should default to null")
	assert_true(definition.cast_shadows, "Cast shadows should default true")
	assert_true(definition.generate_collision, "Generate collision should default true")
	assert_eq(definition.collision_layers, 1, "Collision layers should default to 1")
	assert_eq(definition.collision_mask, 1, "Collision mask should default to 1")
	assert_false(definition.debug_visualization, "Debug visualization should default false")

func test_get_position():
	assert_eq(definition.get_position(), Vector3(10, 50, 20), "Should return entry point position")

func test_get_direction():
	assert_not_null(definition.get_direction(), "Direction should not be null")
	assert_almost_eq(definition.get_direction().length(), 1.0, 0.01, "Direction should be normalized")

func test_get_surface_normal():
	assert_eq(definition.get_surface_normal(), Vector3(1, 0, 0), "Should return surface normal")

func test_is_valid_with_valid_definition():
	assert_true(definition.is_valid(), "Valid definition should pass validation")

func test_is_valid_fails_without_entry_point():
	var invalid := TunnelDefinition.new(null)
	assert_false(invalid.is_valid(), "Should fail without entry point")
	assert_push_error("TunnelDefinition: No entry point specified")

func test_is_valid_fails_with_invalid_direction():
	var bad_entry := TunnelEntryPoint.new(
		Vector3.ZERO,
		Vector3.ZERO,
		0.0
	)
	var invalid := TunnelDefinition.create_cylindrical(bad_entry, 3.0, 20.0)
	assert_false(invalid.is_valid(), "Should fail with invalid direction")
	assert_push_error("TunnelDefinition: Entry point has invalid direction")

func test_is_valid_fails_with_invalid_radius():
	entry_point = TunnelEntryPoint.new(Vector3.ZERO, Vector3.UP, 0.0)
	var invalid := TunnelDefinition.create_cylindrical(entry_point, -1.0, 20.0)
	assert_false(invalid.is_valid(), "Should fail with negative radius")
	assert_push_error("TunnelDefinition: Radius must be positive")

func test_is_valid_fails_with_invalid_length():
	entry_point = TunnelEntryPoint.new(Vector3.ZERO, Vector3.UP, 0.0)
	var invalid := TunnelDefinition.create_cylindrical(entry_point, 3.0, 0.0)
	assert_false(invalid.is_valid(), "Should fail with zero length")
	assert_push_error("TunnelDefinition: Length must be positive")

func test_from_dict():
	# Dictionary serialization removed - test direct parameter access instead
	var params := definition.shape_parameters as CylindricalShapeParameters
	assert_not_null(params, "Should have cylindrical parameters")
	assert_eq(params.radius, 3.0, "Radius should match")
	assert_eq(params.length, 20.0, "Length should match")

func test_create_debug():
	var debug_def := TunnelDefinition.create_debug(entry_point)
	assert_true(debug_def.debug_visualization, "Debug definition should have visualization enabled")
	assert_eq(debug_def.get_shape_type(), TunnelShapeType.Type.CYLINDRICAL, "Debug definition should be cylindrical")
	var params := debug_def.shape_parameters as CylindricalShapeParameters
	assert_eq(params.radius, 3.0, "Debug definition should have default radius")

func test_create_debug_with_custom_params():
	var debug_def := TunnelDefinition.create_debug(entry_point, 5.0, 30.0)
	var params := debug_def.shape_parameters as CylindricalShapeParameters
	assert_eq(params.radius, 5.0, "Should use custom radius")
	assert_eq(params.length, 30.0, "Should use custom length")

func test_material_assignment():
	var mat := StandardMaterial3D.new()
	definition.tunnel_material = mat
	assert_eq(definition.tunnel_material, mat, "Material should be assignable")

func test_collision_layer_modification():
	definition.collision_layers = 5
	definition.collision_mask = 7
	assert_eq(definition.collision_layers, 5, "Collision layers should be modifiable")
	assert_eq(definition.collision_mask, 7, "Collision mask should be modifiable")

