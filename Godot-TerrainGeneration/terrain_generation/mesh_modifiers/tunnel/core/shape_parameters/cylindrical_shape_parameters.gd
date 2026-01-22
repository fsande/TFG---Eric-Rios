## @brief Type-safe parameters for cylindrical tunnel shapes.
@tool
class_name CylindricalShapeParameters extends TunnelShapeParameters

@export_range(0.5, 50.0, 0.5, "suffix:m") var radius: float = 3.0
@export_range(1.0, 200.0, 1.0, "suffix:m") var length: float = 20.0
@export_range(6, 64, 1) var radial_segments: int = 16
@export_range(2, 100, 1) var length_segments: int = 8

func get_shape_type() -> TunnelShapeType.Type:
	return TunnelShapeType.Type.CYLINDRICAL

func get_length() -> float:
	return length

func is_valid() -> bool:
	return radius > 0.0 and length > 0.0 and radial_segments >= 3 and length_segments >= 1

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if radius <= 0.0:
		errors.append("Radius must be positive (got %.2f)" % radius)
	if length <= 0.0:
		errors.append("Length must be positive (got %.2f)" % length)
	if radial_segments < 3:
		errors.append("Radial segments must be at least 3 (got %d)" % radial_segments)
	if length_segments < 1:
		errors.append("Length segments must be at least 1 (got %d)" % length_segments)
	return errors

func to_string() -> String:
	return "Cylindrical(r=%.1fm, l=%.1fm, segs=%d/%d)" % [radius, length, radial_segments, length_segments]

func duplicate_parameters() -> TunnelShapeParameters:
	var dup := CylindricalShapeParameters.new()
	dup.radius = radius
	dup.length = length
	dup.radial_segments = radial_segments
	dup.length_segments = length_segments
	return dup

