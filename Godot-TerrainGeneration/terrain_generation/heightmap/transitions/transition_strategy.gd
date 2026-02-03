@abstract
class_name TransitionStrategy extends RefCounted

## Calculate the height at a given position based on base height, mask value, and blur value.
@abstract func calculate_height(_base_height: float, _mask_value: float, _blur_value: float, 
	_position: Vector2) -> float
