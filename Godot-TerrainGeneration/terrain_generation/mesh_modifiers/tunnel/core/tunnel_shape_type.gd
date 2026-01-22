## @brief Type enumeration for tunnel shapes.
##
## @details Provides compile-time type safety for tunnel shape selection.
## Replaces string-based type matching with enum-based dispatch.
@tool
class_name TunnelShapeType extends RefCounted

## Available tunnel shape types
enum Type {
	CYLINDRICAL,
	SPLINE,
	NATURAL_CAVE
}

## Get human-readable display name for a shape type
static func get_display_name(type: Type) -> String:
	match type:
		Type.CYLINDRICAL:
			return "Cylindrical"
		Type.SPLINE:
			return "Spline"
		Type.NATURAL_CAVE:
			return "Natural Cave"
	return "Unknown"

## Get all available shape types
static func get_all_types() -> Array[Type]:
	return [
		Type.CYLINDRICAL,
		Type.SPLINE,
		Type.NATURAL_CAVE
	]
