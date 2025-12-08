class_name TransitionStrategy extends RefCounted

func calculate_height(_base_height: float, _mask_value: float, _blur_value: float, 
	_position: Vector2) -> float:
	push_error("TransitionStrategy.calculate_height must be implemented by subclasses")
	return 0.0
