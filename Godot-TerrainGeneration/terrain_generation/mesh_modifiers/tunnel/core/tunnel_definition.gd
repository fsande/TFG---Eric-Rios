## @brief Complete specification for a tunnel instance.
@tool
class_name TunnelDefinition extends RefCounted

enum TunnelClassification {
	FULLY_UNDERGROUND,
	FULLY_ABOVE,
	INTERSECTING,
	INVALID
}

var entry_point: TunnelEntryPoint
var shape_parameters: TunnelShapeParameters
var tunnel_material: Material = null
var cast_shadows: bool = true
var generate_collision: bool = true
var collision_layers: int = 1
var collision_mask: int = 1
var debug_visualization: bool = false
var debug_color: Color = Color(1.0, 0.0, 0.0, 0.3)

func _init(p_entry_point: TunnelEntryPoint, p_shape_params: TunnelShapeParameters = null) -> void:
	entry_point = p_entry_point
	shape_parameters = p_shape_params if p_shape_params else CylindricalShapeParameters.new()

func is_valid() -> bool:
	if not entry_point:
		push_error("TunnelDefinition: No entry point specified")
		return false
	if not entry_point.has_valid_direction():
		push_error("TunnelDefinition: Entry point has invalid direction")
		return false
	if not shape_parameters:
		push_error("TunnelDefinition: No shape parameters specified")
		return false
	if not shape_parameters.is_valid():
		var errors := shape_parameters.get_validation_errors()
		for error in errors:
			push_error("TunnelDefinition: %s" % error)
		return false
	return true

func get_position() -> Vector3:
	return entry_point.position if entry_point else Vector3.ZERO

func get_direction() -> Vector3:
	return entry_point.tunnel_direction if entry_point else Vector3.FORWARD

func get_surface_normal() -> Vector3:
	return entry_point.surface_normal if entry_point else Vector3.UP

func get_shape_type() -> TunnelShapeType.Type:
	return shape_parameters.get_shape_type() if shape_parameters else TunnelShapeType.Type.CYLINDRICAL

static func create_cylindrical(p_entry_point: TunnelEntryPoint, radius: float, length: float) -> TunnelDefinition:
	var params := CylindricalShapeParameters.new()
	params.radius = radius
	params.length = length
	params.radial_segments = 16
	params.length_segments = 8
	return TunnelDefinition.new(p_entry_point, params)

static func create_debug(p_entry_point: TunnelEntryPoint, radius: float = 3.0, length: float = 20.0) -> TunnelDefinition:
	var definition := create_cylindrical(p_entry_point, radius, length)
	definition.debug_visualization = true
	return definition

