## @brief Factory for creating tunnel shapes based on configuration.
@tool
class_name TunnelShapeFactory extends RefCounted

const DEFAULT_RADIAL_SEGMENTS: int = 16
const DEFAULT_LENGTH_SEGMENTS: int = 8
const DEFAULT_RADIUS: float = 3.0
const DEFAULT_LENGTH: float = 20.0

static func create_from_definition(definition: TunnelDefinition) -> TunnelShape:
	if definition == null or not definition.is_valid():
		push_error("TunnelShapeFactory: Invalid definition")
		return null
	match definition.get_shape_type():
		TunnelShapeType.Type.CYLINDRICAL:
			return _create_cylindrical_from_definition(definition)
		_:
			push_error("TunnelShapeFactory: Unsupported shape type: %s" % 
				TunnelShapeType.get_display_name(definition.get_shape_type()))
			return null

static func _create_cylindrical_from_definition(definition: TunnelDefinition) -> CylindricalTunnelShape:
	var params := definition.shape_parameters as CylindricalShapeParameters
	if params == null:
		push_error("TunnelShapeFactory: Expected CylindricalShapeParameters but got null")
		return null
	if params.radius <= 0 or params.length <= 0:
		push_error("TunnelShapeFactory: Invalid dimensions (radius: %.2f, length: %.2f)" % 
			[params.radius, params.length])
		return null
	var shape := CylindricalTunnelShape.new(
		definition.get_position(),
		definition.get_direction(),
		params.radius,
		params.length
	)
	shape.radial_segments = params.radial_segments
	shape.length_segments = params.length_segments
	return shape

static func create_cylindrical(
	entry_point: TunnelEntryPoint,
	radius: float = DEFAULT_RADIUS,
	length: float = DEFAULT_LENGTH,
	radial_segments: int = DEFAULT_RADIAL_SEGMENTS,
	length_segments: int = DEFAULT_LENGTH_SEGMENTS
) -> CylindricalTunnelShape:
	if entry_point == null or not entry_point.has_valid_direction():
		push_error("TunnelShapeFactory: Invalid entry point")
		return null
	var shape := CylindricalTunnelShape.new(
		entry_point.position,
		entry_point.tunnel_direction,
		radius,
		length
	)
	shape.radial_segments = radial_segments
	shape.length_segments = length_segments
	return shape

