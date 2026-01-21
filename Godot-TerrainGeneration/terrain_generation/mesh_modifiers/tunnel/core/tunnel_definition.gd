## Complete specification for a tunnel instance.
@tool
class_name TunnelDefinition extends RefCounted

enum TunnelClassification {
	FULLY_UNDERGROUND,
	FULLY_ABOVE,
	INTERSECTING,
	INVALID
}

var entry_point: TunnelEntryPoint
var shape_type: String = "Cylindrical"
var shape_parameters: Dictionary = {}

var tunnel_material: Material = null
var cast_shadows: bool = true

var generate_collision: bool = true
var collision_layers: int = 1
var collision_mask: int = 1

var debug_visualization: bool = false
var debug_color: Color = Color(1.0, 0.0, 0.0, 0.3)

func _init(
	p_entry_point: TunnelEntryPoint,
	p_shape_type: String = "Cylindrical",
	p_shape_params: Dictionary = {}
) -> void:
	entry_point = p_entry_point
	shape_type = p_shape_type
	shape_parameters = p_shape_params

func is_valid() -> bool:
	if not entry_point:
		push_error("TunnelDefinition: No entry point specified")
		return false
	if not entry_point.has_valid_direction():
		push_error("TunnelDefinition: Entry point has invalid direction")
		return false
	if shape_type.is_empty():
		push_error("TunnelDefinition: No shape type specified")
		return false
	match shape_type: # TODO: Extend for more shapes, better structure that just matching strings
		"Cylindrical":
			if not shape_parameters.has("radius") or shape_parameters["radius"] <= 0:
				push_error("TunnelDefinition: Cylindrical tunnel requires positive radius")
				return false
			if not shape_parameters.has("length") or shape_parameters["length"] <= 0:
				push_error("TunnelDefinition: Cylindrical tunnel requires positive length")
				return false
	return true

func get_position() -> Vector3:
	return entry_point.position if entry_point else Vector3.ZERO

func get_direction() -> Vector3:
	return entry_point.tunnel_direction if entry_point else Vector3.FORWARD

func get_surface_normal() -> Vector3:
	return entry_point.surface_normal if entry_point else Vector3.UP

func get_shape_param(key: String, default_value = null) -> Variant:
	return shape_parameters.get(key, default_value)

func set_shape_param(key: String, value: Variant) -> void:
	shape_parameters[key] = value

func to_dict() -> Dictionary:
	return {
		"shape_type": shape_type,
		"shape_parameters": shape_parameters,
		"position": get_position(),
		"direction": get_direction(),
		"surface_normal": get_surface_normal(),
		"generate_collision": generate_collision,
		"collision_layers": collision_layers,
		"collision_mask": collision_mask,
		"cast_shadows": cast_shadows,
		"debug_visualization": debug_visualization
	}

static func from_dict(data: Dictionary, p_entry_point: TunnelEntryPoint) -> TunnelDefinition:
	var definition := TunnelDefinition.new(
		p_entry_point,
		data.get("shape_type", "Cylindrical"),
		data.get("shape_parameters", {})
	)
	definition.generate_collision = data.get("generate_collision", true)
	definition.collision_layers = data.get("collision_layers", 1)
	definition.collision_mask = data.get("collision_mask", 1)
	definition.cast_shadows = data.get("cast_shadows", true)
	definition.debug_visualization = data.get("debug_visualization", false)
	return definition

static func create_cylindrical(
	p_entry_point: TunnelEntryPoint,
	radius: float,
	length: float
) -> TunnelDefinition:
	var params := {
		"radius": radius,
		"length": length,
		"radial_segments": 16,
		"length_segments": 8
	}
	return TunnelDefinition.new(p_entry_point, "Cylindrical", params)

static func create_debug(
	p_entry_point: TunnelEntryPoint,
	radius: float = 3.0,
	length: float = 20.0
) -> TunnelDefinition:
	var definition := create_cylindrical(p_entry_point, radius, length)
	definition.debug_visualization = true
	return definition
