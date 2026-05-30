@tool
class_name SlopeRangeConstraint extends PropPlacementConstraint

@export var min_slope: float = 0.0:
	set(value): 
		min_slope = value; 
		_cos_max = cos(deg_to_rad(value))
@export var max_slope: float = 45.0:
	set(value): 
		max_slope = value; 
		_cos_min = cos(deg_to_rad(value))

var _cos_min: float = cos(deg_to_rad(45.0))
var _cos_max: float = cos(deg_to_rad(0.0))

func validate(context: PropPlacementContext) -> bool:
	var cos_slope := context.terrain_sample.normal.dot(Vector3.UP)
	return cos_slope >= _cos_min and cos_slope <= _cos_max
