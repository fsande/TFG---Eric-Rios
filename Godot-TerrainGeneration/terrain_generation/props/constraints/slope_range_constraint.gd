## Constraint that checks if the slope of the terrain at the prop's position is within a specified range.
@tool
class_name SlopeRangeConstraint extends PropPlacementConstraint

@export var min_slope: float = 0.0
@export var max_slope: float = 45.0

func validate(context: PropPlacementContext) -> bool:
	var slope_degrees = rad_to_deg(acos(context.terrain_sample.normal.dot(Vector3.UP)))
	return slope_degrees >= min_slope and slope_degrees <= max_slope
