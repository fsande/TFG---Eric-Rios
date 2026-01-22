## @brief Type-safe parameters for natural cave-like tunnel shapes.
@tool
class_name NaturalCaveParameters extends TunnelShapeParameters

@export_range(2.0, 20.0, 0.5, "suffix:m") var base_radius: float = 5.0
@export_range(0.0, 1.0, 0.05) var radius_variation: float = 0.3
@export_range(1.0, 200.0, 1.0, "suffix:m") var length: float = 30.0
@export var noise_seed: int = 0
@export_range(0.5, 5.0, 0.1) var noise_frequency: float = 1.0
@export_range(6, 64, 1) var radial_segments: int = 24
@export_range(10, 100, 1) var length_segments: int = 30

func get_shape_type() -> TunnelShapeType.Type:
	return TunnelShapeType.Type.NATURAL_CAVE

func get_length() -> float:
	return length

func is_valid() -> bool:
	return base_radius > 0.0 and length > 0.0 and radius_variation >= 0.0 and radius_variation <= 1.0 and radial_segments >= 3 and length_segments >= 2

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if base_radius <= 0.0:
		errors.append("Base radius must be positive (got %.2f)" % base_radius)
	if length <= 0.0:
		errors.append("Length must be positive (got %.2f)" % length)
	if radius_variation < 0.0 or radius_variation > 1.0:
		errors.append("Radius variation must be between 0 and 1 (got %.2f)" % radius_variation)
	if radial_segments < 3:
		errors.append("Radial segments must be at least 3 (got %d)" % radial_segments)
	if length_segments < 2:
		errors.append("Length segments must be at least 2 (got %d)" % length_segments)
	return errors

func duplicate_parameters() -> TunnelShapeParameters:
	var dup := NaturalCaveParameters.new()
	dup.base_radius = base_radius
	dup.radius_variation = radius_variation
	dup.length = length
	dup.noise_seed = noise_seed
	dup.noise_frequency = noise_frequency
	dup.radial_segments = radial_segments
	dup.length_segments = length_segments
	return dup

