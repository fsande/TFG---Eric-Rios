class_name MaxBlendStrategy extends HeightBlendStrategy

func blend(existing: float, delta: float, _intensity: float) -> float:
	return max(existing, delta, existing + delta)
