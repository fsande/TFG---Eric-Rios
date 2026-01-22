## @brief Abstract base class for type-safe tunnel shape parameters.
@tool
class_name TunnelShapeParameters extends Resource

func get_shape_type() -> TunnelShapeType.Type:
	push_error("TunnelShapeParameters.get_shape_type() must be overridden by subclass")
	return TunnelShapeType.Type.CYLINDRICAL

func get_length() -> float:
	push_error("TunnelShapeParameters.get_length() must be overridden by subclass")
	return 0.0

func is_valid() -> bool:
	push_error("TunnelShapeParameters.is_valid() must be overridden by subclass")
	return false

func to_string() -> String:
	return "TunnelShapeParameters (override in subclass)"

func duplicate_parameters() -> TunnelShapeParameters:
	push_error("TunnelShapeParameters.duplicate_parameters() must be overridden by subclass")
	return null

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not is_valid():
		errors.append("Parameters failed validation (override get_validation_errors() for details)")
	return errors

